local MOS = BootyGuild

MOS.Services.Roster = MOS.Services.Roster or {}
local RosterService = MOS.Services.Roster

function RosterService.IsInGuild()
    if type(IsInGuild) == "function" then
        local value = IsInGuild()
        return value ~= nil and value ~= false and value ~= 0
    end
    if type(GetGuildInfo) == "function" then
        local name = GetGuildInfo("player")
        return type(name) == "string" and name ~= ""
    end
    return false
end

local function SortByName(a, b)
    return string.lower(a.name or "") < string.lower(b.name or "")
end

local function SortText(a, b)
    return string.lower(a) < string.lower(b)
end

local function ReadMember(index)
    local name, rank, rankIndex, level, class, zone, publicNote, officerNote, online, status = GetGuildRosterInfo(index)
    if not name then return nil end
    local years, months, days, hours = 0, 0, 0, 0
    if not online and type(GetGuildRosterLastOnline) == "function" then
        years, months, days, hours = GetGuildRosterLastOnline(index)
    end
    return {
        name = name, level = level or 0, class = class or "", rank = rank or "", rankIndex = rankIndex,
        publicNote = publicNote or "", officerNote = officerNote or "", online = online and true or false,
        zone = zone or "", status = status,
        lastOnlineYears = tonumber(years) or 0, lastOnlineMonths = tonumber(months) or 0,
        lastOnlineDays = tonumber(days) or 0, lastOnlineHours = tonumber(hours) or 0,
    }
end

local function SnapshotData(members, guildName, realmName, scanStartedAt)
    local scanTimestamp = time()
    local scanDuration = 0
    if scanStartedAt then scanDuration = GetTime() - scanStartedAt end
    return {
        guildName = guildName, realmName = realmName, addonVersion = MOS.version,
        scannedAt = scanTimestamp, scannedAtText = date("%Y-%m-%d %H:%M:%S", scanTimestamp),
        scanDurationSeconds = scanDuration, updatedAt = scanTimestamp, updatedBy = UnitName("player"),
        members = members,
    }
end

function RosterService.BuildSnapshot(scanStartedAt)
    MOS.Diagnostics.Count("scans")
    MOS.Database.Ensure()
    local key, guildName, realmName = MOS.Database.GetGuildIdentity()
    if not key then return nil, "not-in-guild" end

    local total = GetNumGuildMembers(true)
    if not total or total < 1 then return nil, "not-ready" end
    local members = {}
    local index
    for index = 1, total do
        local member = ReadMember(index)
        if member then table.insert(members, member) end
    end
    if table.getn(members) < total then return nil, "not-ready" end
    table.sort(members, SortByName)
    return SnapshotData(members, guildName, realmName, scanStartedAt)
end

-- Deterministic engineering limits, not measured millisecond budgets. API
-- capture and cached-key merge placements have separate per-step caps.
RosterService.SNAPSHOT_WORK_LIMIT = 32
RosterService.SNAPSHOT_MERGE_WORK_LIMIT = 256

function RosterService.StartSnapshot(scanStartedAt, generation)
    -- Caller-owned generation tracks roster-cache events. Identity/count are
    -- additional guards, not a native transaction/revision guarantee.
    MOS.Diagnostics.Count("scans")
    MOS.Database.Ensure()
    local key, guildName, realmName = MOS.Database.GetGuildIdentity()
    if not key then return nil, "not-in-guild" end
    local total = GetNumGuildMembers(true)
    if not total or total < 1 then return nil, "not-ready" end
    return {
        state = "working", phase = "capture", generation = generation,
        guildKey = key, guildName = guildName, realmName = realmName,
        total = total, startedAt = scanStartedAt, captureIndex = 1,
        members = {}, scratch = {}, scratchFilled = 0, sortNames = {}, seenNames = {},
    }
end

function RosterService.CancelSnapshot(job, reason)
    if not job or job.state == "finished" then return end
    job.state, job.error = "failed", reason or "cancelled"
    job.members, job.scratch, job.sortNames, job.seenNames = nil, nil, nil, nil
end

local function SnapshotContext(job, generation)
    if not job then return false, "not-ready" end
    if job.state == "failed" or job.state == "finished" then return false, job.error or job.state end
    if job.generation ~= generation then return false, "generation-changed" end
    local key = MOS.Database.GetGuildIdentity()
    if key ~= job.guildKey then return false, "guild-changed" end
    if GetNumGuildMembers(true) ~= job.total then return false, "roster-changed" end
    return true
end

local function BeginMerge(job)
    job.mergeStart = 1
    job.leftIndex = 1
    job.leftEnd = math.min(job.total, job.mergeWidth)
    job.rightIndex = job.leftEnd + 1
    job.rightEnd = math.min(job.total, job.mergeWidth * 2)
    job.outputIndex = 1
end

local function MergePlacement(job)
    local left, right = job.leftIndex, job.rightIndex
    local takeLeft = right > job.rightEnd or (left <= job.leftEnd
        and job.sortNames[job.members[left]] <= job.sortNames[job.members[right]])
    local member
    if takeLeft then
        member = job.members[left]
        job.leftIndex = left + 1
    else
        member = job.members[right]
        job.rightIndex = right + 1
    end
    -- Initial fill uses insert so Lua5.0's stored sequence length advances.
    -- Later merge passes overwrite the already full buffer in place.
    if job.outputIndex > job.scratchFilled then
        table.insert(job.scratch, member)
        job.scratchFilled = job.outputIndex
    else
        job.scratch[job.outputIndex] = member
    end
    job.outputIndex = job.outputIndex + 1
    if job.outputIndex > job.rightEnd then
        job.mergeStart = job.mergeStart + job.mergeWidth * 2
        if job.mergeStart > job.total then
            job.members, job.scratch = job.scratch, job.members
            job.scratchFilled = job.total
            job.mergeWidth = job.mergeWidth * 2
            if job.mergeWidth >= job.total then job.state = "ready"; return end
            BeginMerge(job)
        else
            job.leftIndex = job.mergeStart
            job.leftEnd = math.min(job.total, job.mergeStart + job.mergeWidth - 1)
            job.rightIndex = job.leftEnd + 1
            job.rightEnd = math.min(job.total, job.mergeStart + job.mergeWidth * 2 - 1)
        end
    end
end

function RosterService.StepSnapshot(job, workLimit, generation)
    local valid, failure = SnapshotContext(job, generation)
    if not valid then
        RosterService.CancelSnapshot(job, failure)
        return "failed", failure, 0
    end
    if job.state == "ready" then return "ready", nil, 0 end
    local captureLimit, mergeLimit
    if type(workLimit) == "table" then captureLimit, mergeLimit = workLimit.capture, workLimit.merge
    else captureLimit, mergeLimit = workLimit, workLimit end
    captureLimit = math.min(RosterService.SNAPSHOT_WORK_LIMIT,
        math.max(1, math.floor(tonumber(captureLimit) or RosterService.SNAPSHOT_WORK_LIMIT)))
    mergeLimit = math.min(RosterService.SNAPSHOT_MERGE_WORK_LIMIT,
        math.max(1, math.floor(tonumber(mergeLimit) or RosterService.SNAPSHOT_MERGE_WORK_LIMIT)))
    local units, captured, merged = 0, 0, 0
    while job.state == "working" do
        if job.phase == "capture" then
            if captured >= captureLimit then break end
            local member = ReadMember(job.captureIndex)
            units = units + 1
            captured = captured + 1
            if not member then
                RosterService.CancelSnapshot(job, "not-ready")
                return "failed", "not-ready", units
            end
            local normalizedName = string.lower(member.name)
            if job.seenNames[normalizedName] then
                RosterService.CancelSnapshot(job, "roster-changed")
                return "failed", "roster-changed", units
            end
            job.seenNames[normalizedName] = true
            job.sortNames[member] = normalizedName
            table.insert(job.members, member)
            job.captureIndex = job.captureIndex + 1
            if job.captureIndex > job.total then
                job.seenNames = nil
                if job.total == 1 then job.state = "ready"
                else job.phase, job.mergeWidth = "sort", 1; BeginMerge(job) end
            end
        else
            if merged >= mergeLimit then break end
            MergePlacement(job)
            units = units + 1
            merged = merged + 1
        end
    end
    return job.state, nil, units
end

function RosterService.FinishSnapshot(job, generation)
    local valid, failure = SnapshotContext(job, generation)
    if not valid then RosterService.CancelSnapshot(job, failure); return nil, failure end
    if job.state ~= "ready" then return nil, "not-ready" end
    local snapshot = SnapshotData(job.members, job.guildName, job.realmName, job.startedAt)
    job.state = "finished"
    job.members, job.scratch, job.sortNames, job.seenNames = nil, nil, nil, nil
    return snapshot
end

function RosterService.StoreSnapshot(snapshot)
    MOS.Database.StoreRosterSnapshot(snapshot)
end

function RosterService.GetUniqueMemberValues(data, field)
    local values = {}
    local found = {}
    if data and data.members then
        local memberIndex
        for memberIndex = 1, table.getn(data.members) do
            local value = tostring(data.members[memberIndex][field] or "Unknown")
            if value == "" then value = "Unknown" end
            if not found[value] then
                found[value] = true
                table.insert(values, value)
            end
        end
    end
    table.sort(values, SortText)
    return values
end

function RosterService.FindMember(data, name)
    if not name or not data or not data.members then return nil end
    local memberIndex
    for memberIndex = 1, table.getn(data.members) do
        if data.members[memberIndex].name == name then return data.members[memberIndex] end
    end
    return nil
end

function RosterService.FindRankName(data, rankIndex)
    if not data or not data.members then return nil end
    local memberIndex
    for memberIndex = 1, table.getn(data.members) do
        if data.members[memberIndex].rankIndex == rankIndex then return data.members[memberIndex].rank end
    end
    return nil
end

function RosterService.GetLowestRankIndex(data)
    local lowest = 0
    if data and data.members then
        local memberIndex
        for memberIndex = 1, table.getn(data.members) do
            local rankIndex = tonumber(data.members[memberIndex].rankIndex) or 0
            if rankIndex > lowest then lowest = rankIndex end
        end
    end
    return lowest
end
local function Allowed(api)
    if type(api) ~= "function" then return false end
    local value = api()
    return value ~= nil and value ~= false and value ~= 0
end

-- The visible management watcher compares this fixed tuple before laying out
-- controls. Reading permission changes does not allocate a state/fingerprint.
function RosterService.ReadManagementState()
    local flags = 0
    if Allowed(IsGuildLeader) then flags = flags + 1 end
    if Allowed(CanGuildInvite) then flags = flags + 2 end
    if Allowed(CanEditPublicNote) then flags = flags + 4 end
    local canEditOfficer = Allowed(CanEditOfficerNote)
    if canEditOfficer then flags = flags + 8 end
    if Allowed(CanViewOfficerNote) or canEditOfficer then flags = flags + 16 end
    if Allowed(CanGuildPromote) then flags = flags + 32 end
    if Allowed(CanGuildDemote) then flags = flags + 64 end
    if Allowed(CanGuildRemove) then flags = flags + 128 end
    local playerRank, rankCount, playerName
    if type(GetGuildInfo) == "function" then local _, _, rank = GetGuildInfo("player"); playerRank = tonumber(rank) end
    if type(GuildControlGetNumRanks) == "function" then rankCount = tonumber(GuildControlGetNumRanks()) end
    if type(UnitName) == "function" then playerName = UnitName("player") end
    return flags, playerRank, rankCount, playerName
end

function RosterService.CanManage(action, member)
    if action == "control" then return Allowed(IsGuildLeader) end
    if action == "invite" then return Allowed(CanGuildInvite) end
    if action == "publicNote" then return Allowed(CanEditPublicNote) end
    if action == "officerNote" then return Allowed(CanEditOfficerNote) end
    if action == "viewOfficerNote" then return Allowed(CanViewOfficerNote) or Allowed(CanEditOfficerNote) end
    if not member or not member.name then return false end
    if action == "whisper" or action == "group" then return member.online and member.name ~= UnitName("player") end
    local _, _, playerRank = GetGuildInfo("player")
    local rank = tonumber(member.rankIndex)
    if not rank or not playerRank or rank <= playerRank or member.name == UnitName("player") then return false end
    if action == "promote" then return Allowed(CanGuildPromote) and rank > playerRank + 1 end
    if action == "demote" then return Allowed(CanGuildDemote) and type(GuildControlGetNumRanks) == "function" and rank < GuildControlGetNumRanks() - 1 end
    if action == "remove" then return Allowed(CanGuildRemove) end
    return false
end

local function GuildInviteAPI()
    -- The original 1.12 guild popup uses GuildInviteByName.
    if type(GuildInviteByName) == "function" then return GuildInviteByName end
    if type(GuildInvite) == "function" then return GuildInvite end
end

function RosterService.CanInviteMember()
    return RosterService.CanManage("invite") and GuildInviteAPI() ~= nil
end

function RosterService.InviteMember(name)
    if type(name) ~= "string" then return false end
    name = string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
    if name == "" or not RosterService.CanManage("invite") then return false end
    local invite = GuildInviteAPI()
    if not invite then return false end
    invite(name)
    return true
end

function RosterService.FindLiveMember(name)
    if type(GetNumGuildMembers) ~= "function" then return nil end
    local index
    for index = 1, GetNumGuildMembers(true) do
        local current, rank, rankIndex, level, class, zone, publicNote, officerNote, online = GetGuildRosterInfo(index)
        if current == name then return index, { name = current, rankIndex = rankIndex, online = online and true or false } end
    end
end

function RosterService.PerformMemberAction(action, name, value)
    local index, member = RosterService.FindLiveMember(name)
    if not index or not RosterService.CanManage(action, member) then return false end
    if action == "publicNote" and type(GuildRosterSetPublicNote) == "function" then GuildRosterSetPublicNote(index, string.sub(value or "", 1, 31))
    elseif action == "officerNote" and type(GuildRosterSetOfficerNote) == "function" then GuildRosterSetOfficerNote(index, string.sub(value or "", 1, 31))
    elseif action == "promote" and type(GuildPromoteByName) == "function" then GuildPromoteByName(name)
    elseif action == "demote" and type(GuildDemoteByName) == "function" then GuildDemoteByName(name)
    elseif action == "remove" and type(GuildUninvite) == "function" then GuildUninvite(name)
    elseif action == "group" and type(InviteByName) == "function" then InviteByName(name)
    elseif action == "whisper" and type(ChatFrame_SendTell) == "function" then ChatFrame_SendTell(name)
    else return false end
    return true
end

function RosterService.PerformSocialAction(action, name, reason)
    if not name or name == "" or (name == UnitName("player") and action ~= "target") then return false end
    if action == "whisper" and type(ChatFrame_SendTell) == "function" then ChatFrame_SendTell(name)
    elseif action == "group" and type(InviteByName) == "function" then InviteByName(name)
    elseif action == "target" and type(TargetByName) == "function" then TargetByName(name, true)
    elseif action == "ignore" and type(AddIgnore) == "function" then AddIgnore(name)
    elseif action == "report" and reason and string.find(reason, "%S") and type(NewGMTicket) == "function" then
        NewGMTicket("Player report: " .. name .. "\n" .. reason)
    else return false end
    return true
end

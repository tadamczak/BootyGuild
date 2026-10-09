local Booty = BootyGuild

Booty.Core = Booty.Core or {}
local GuildScanController = {}
Booty.Core.GuildScanController = GuildScanController

local LIVE_ORIGIN = "roster_live"
local TRAILING_DELAY, MAX_TRAILING_DELAY = 0.15, 1
local READINESS_TIMEOUT, JOB_TIMEOUT = 15, 60

local function CancelJob(controller, reason)
    if controller.job and controller.cancelSnapshot then controller.cancelSnapshot(controller.job, reason) end
    controller.job, controller.jobStartedAt = nil, nil
end

local function Fail(controller, reason)
    controller.failureReason = reason
    GuildScanController.Finish(controller)
    controller.onFailure()
end

local function Retry(controller, now)
    if controller.deadline and now >= controller.deadline then Fail(controller, "timeout"); return end
    if controller.attempts < 6 then
        controller.attempts = controller.attempts + 1
        controller.frame.delay = 2.5
        if controller.origin ~= LIVE_ORIGIN then
            controller.printMessage("Guild roster is still loading. Request " .. controller.attempts .. "/6...")
        end
        controller.requestRoster()
    else controller.frame.delay = 0.5 end
end

local function OnScanUpdate()
    local controller = this.controller
    if not controller.mode then
        this.delay = nil; this:SetScript("OnUpdate", nil); this:Hide()
        return
    end
    this.delay = math.max(0, (this.delay or 0) - arg1)
    if this.delay > 0 then return end
    local now = GetTime()
    if controller.raidOnly then
        -- Raid membership does not depend on the guild cache. This one-shot
        -- path never requests or retries guild data for a guildless character.
        if not controller.tryComplete() then Fail(controller, "raid_unavailable") end
        return
    end
    if not controller.startSnapshot then
        -- Explicit legacy factories remain supported; the composition root injects staged APIs.
        if controller.tryComplete() then return end
        Retry(controller, now)
        return
    end
    if not controller.job then
        -- Readiness and invalidated restarts share the original request deadline.
        -- A stable job can continue beyond it, bounded by the separate 60s timeout.
        if controller.deadline and now >= controller.deadline then Fail(controller, "timeout"); return end
        local job, reason = controller.startSnapshot(controller.startedAt, controller.generation)
        if not job then controller.lastError = reason; Retry(controller, now); return end
        controller.job, controller.jobStartedAt = job, now
        controller.burstStartedAt = nil
    end
    if now - controller.jobStartedAt >= JOB_TIMEOUT then Fail(controller, "job_timeout"); return end
    -- The service bounds captured roster rows and cached-key merge moves separately (32 / 256).
    local status, reason = controller.stepSnapshot(controller.job, nil, controller.generation)
    if status == "working" then return end
    if status ~= "ready" then
        controller.lastError = reason
        CancelJob(controller, reason)
        Retry(controller, now)
        return
    end
    local snapshot
    snapshot, reason = controller.finishSnapshot(controller.job, controller.generation)
    controller.job, controller.jobStartedAt = nil, nil
    if not snapshot then controller.lastError = reason; Retry(controller, now); return end
    if not controller.tryComplete(snapshot) then
        controller.lastError = "commit_rejected"
        Retry(controller, now)
    end
end

function GuildScanController.Create(options)
    local controller = options
    controller.mode, controller.startedAt, controller.deadline = nil, nil, nil
    controller.attempts, controller.generation = 0, 0
    controller.frame = CreateFrame("Frame", "BootyGuildRosterRequestFrame", UIParent)
    controller.frame.controller = controller
    controller.frame.delay = nil
    controller.frame:Hide()
    controller.frame:SetScript("OnUpdate", nil)
    Booty.guildScanController = controller
    return controller
end

local function Begin(controller, mode, delay)
    if controller.mode then
        controller.printMessage("A guild data scan is already in progress.")
        return false
    end
    local inGuild = controller.isInGuild()
    inGuild = inGuild ~= nil and inGuild ~= false and inGuild ~= 0
    if not inGuild and mode ~= "raid" then
        controller.printMessage("This character is not in a guild.")
        return false
    end
    controller.mode = mode or "manual"
    controller.raidOnly = mode == "raid" and not inGuild or false
    controller.startedAt = GetTime()
    controller.attempts = 1
    controller.deadline = controller.startedAt + READINESS_TIMEOUT
    controller.lastError, controller.failureReason = nil, nil
    controller.frame.delay = delay
    controller.frame:SetScript("OnUpdate", OnScanUpdate)
    controller.frame:Show()
    controller.onStart(controller.mode, controller)
    return true
end

function GuildScanController.Request(controller, mode)
    if not Begin(controller, mode, 1) then return false end
    if controller.raidOnly then controller.frame.delay = 0; return true end
    controller.requestRoster()
    controller.printMessage((mode == "reload" or mode == "csr_reload") and
        "Requesting guild roster. Save confirmation will appear when the scan completes..." or
        "Requesting guild roster...")
    return true
end

function GuildScanController.RequestShared(controller, origin)
    if controller.mode then return false end
    controller.origin = origin
    if GuildScanController.Request(controller, "shared") then return true end
    controller.origin = nil
    return false
end

function GuildScanController.Queue(controller)
    return Begin(controller, "quiet", 0.75)
end

local function ScheduleTrailing(controller)
    local now = GetTime()
    controller.burstStartedAt = controller.burstStartedAt or now
    controller.frame.delay = math.max(0, math.min(now + TRAILING_DELAY, controller.burstStartedAt + MAX_TRAILING_DELAY) - now)
end

function GuildScanController.QueueLive(controller)
    if controller.mode then
        if controller.origin ~= LIVE_ORIGIN then return false end
        ScheduleTrailing(controller)
        return true
    end
    controller.origin = LIVE_ORIGIN
    if not Begin(controller, "quiet", TRAILING_DELAY) then controller.origin = nil; return false end
    controller.burstStartedAt = controller.startedAt
    return true
end

function GuildScanController.HandleRosterUpdate(controller)
    controller.generation = controller.generation + 1
    if not controller.mode then return false end
    if controller.raidOnly then return false end
    CancelJob(controller, "roster_changed")
    ScheduleTrailing(controller)
    return true
end

function GuildScanController.CancelLive(controller)
    if controller.origin ~= LIVE_ORIGIN then return false end
    GuildScanController.Finish(controller)
    controller.origin = nil
    return true
end

function GuildScanController.Finish(controller)
    CancelJob(controller, "finished")
    controller.mode, controller.startedAt, controller.deadline = nil, nil, nil
    controller.raidOnly = false
    controller.attempts, controller.burstStartedAt = 0, nil
    controller.frame.delay = nil
    controller.frame:SetScript("OnUpdate", nil)
    controller.frame:Hide()
end

function GuildScanController.GetMode(controller)
    return controller.mode
end

function GuildScanController.GetStartedAt(controller)
    return controller.startedAt
end

function GuildScanController.GetOrigin(controller)
    return controller.origin
end

function GuildScanController.ClearOrigin(controller)
    controller.origin = nil
end

function GuildScanController.IsPending(controller)
    return controller.mode ~= nil
end

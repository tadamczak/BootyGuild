local Guild = BootyGuild
local Database = {}
Guild.Database = Database
local defaults = {
    rosterHideSectionHeader = false, rosterClassColors = true, rosterLiveTrackingEnabled = false,
    rosterShowClass = true, rosterShowLevel = true, rosterShowZone = true, rosterShowRank = false,
    rosterShowPublicNote = false, rosterShowOfficerNote = false, rosterShowLastOnline = false,
    rosterShowClassFilter = true, rosterShowRankFilter = true, rosterShowSearch = true,
    rosterShowOffline = true, rosterShowColumnHeaders = true, showOfflineMembers = true,
    playerDetailsStyle = "collapsible", rosterSortKey = "rank", rosterSortAscending = true,
    rosterBackgroundColor = {0.025,0.025,0.025}, rosterTextColor = {1,1,1},
    rosterHoverColor = {0.13,0.13,0.13}, rosterOddLightness = 5,
}

function Database.OwnsField(key)
    return type(key) == "string" and (string.find(key, "^roster") ~= nil
        or key == "guilds" or key == "lastScanAt" or key == "lastScanAtText"
        or key == "lastScanDurationSeconds" or key == "playerDetailsStyle" or key == "showOfflineMembers")
end

local function Defaults(store)
    local key, value
    for key, value in pairs(defaults) do
        if store[key] == nil then
            if type(value) == "table" then store[key] = {value[1],value[2],value[3]} else store[key] = value end
        end
    end
    if store.playerDetailsStyle ~= "window" then store.playerDetailsStyle = "collapsible" end
    store.rosterOddLightness = math.max(0,math.min(100,tonumber(store.rosterOddLightness) or 5))
    for _, key in ipairs({"rosterBackgroundColor","rosterTextColor","rosterHoverColor"}) do
        if type(store[key]) ~= "table" then local value=defaults[key];store[key]={value[1],value[2],value[3]} end
    end
    if type(store.presentation) ~= "table" then store.presentation = {} end
    if type(store.presentation.windows) ~= "table" then store.presentation.windows = {} end
    if type(store.presentation.minimap) ~= "table" then store.presentation.minimap = {angle=315,hidden=false} end
    if store.presentation.minimap.angle == nil then store.presentation.minimap.angle = 315 end
    if store.presentation.minimap.hidden == nil then store.presentation.minimap.hidden = false end
    store.addonVersion = Guild.version
end

BootyLib.Data.RegisterOwner("guild", "BootyGuildDB", Database.OwnsField, Defaults)

function Database.Ensure()
    local store, failure = BootyLib.Data.Ensure("guild")
    if not store then return nil, failure end
    return store
end

function Database.GetGuildIdentity()
    local guildName = type(GetGuildInfo) == "function" and GetGuildInfo("player")
    if not guildName or guildName == "" then return nil end
    local realmName = type(GetRealmName) == "function" and GetRealmName() or "UnknownRealm"
    return realmName .. " - " .. guildName, guildName, realmName
end

function Database.GetSetting(key) local store=Database.Ensure();return store and store[key] end
function Database.SetSetting(key,value) local store=Database.Ensure();if not store then return nil end;store[key]=value;return value end
function Database.GetRosterData()
    local store=Database.Ensure()
    if not store then return nil end
    if store.rosterData then return store.rosterData end
    -- Older exports can contain historical guild entries. Select a read-only
    -- fallback without persisting a second alias of the same member table.
    local key=Database.GetGuildIdentity()
    return key and type(store.guilds)=="table" and store.guilds[key] or nil
end
function Database.CountRosterMembers() local data=Database.GetRosterData();return table.getn(data and data.members or {}) end
function Database.StoreRosterSnapshot(snapshot)
    local store=Database.Ensure()
    if not store or type(snapshot)~="table" then return false end
    store.rosterData=snapshot
    store.lastScanAt,store.lastScanAtText,store.lastScanDurationSeconds=snapshot.scannedAt,snapshot.scannedAtText,snapshot.scanDurationSeconds
    if BootyLib.GuildDirectory then BootyLib.GuildDirectory.Publish(snapshot) end
    return true
end

Database.Defaults = defaults

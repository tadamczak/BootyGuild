local Guild = BootyGuild
local Controller = Guild.Controller
local function Available() return Controller.IsAvailable() end
local function MenuEntry(text,icon,action,enabled,children) return {text=text,icon=icon,action=action,enabled=enabled,children=children} end

function Guild.GetQuickMenu(host)
    local available=Available()
    local function Open(id) return function() if Available() then host.OpenView(id) end end end
    local function GuildAction(key)
        return function()
            if not Available() then return false end
            local view=host.GetView("roster")
            if view and view.controls and view.controls[key] then return view.controls[key]() end
            return false
        end
    end
    local children={
        MenuEntry("Set GMOTD","rules",GuildAction("OpenGMOTD"),available),
        MenuEntry("Guild Stats","guild_stats",Open("statistics"),available),
        MenuEntry("Guild info","info",GuildAction("OpenGuildInformation"),available),
    }
    local entries={MenuEntry("Guild","roster",Open("roster"),available,children)}
    if not host.integrated then table.insert(entries,MenuEntry("Guild Stats","guild_stats",Open("statistics"),available)) end
    return entries
end

Guild.Product={
    id="guild",name="BootyGuild",version=Guild.version,apiVersion=1,namespace=Guild,
    Initialize=Controller.Initialize,
    OnHostReady=Controller.Initialize,
    GetDatabase=Guild.Database.Ensure,
    views={
        {id="roster",label="Guild",icon="roster",create=Controller.CreateRoster,IsAvailable=Available},
        {id="statistics",label="Guild Statistics",icon="guild_stats",create=Controller.CreateStatistics,IsAvailable=Available},
    },
    GetQuickMenu=Guild.GetQuickMenu,GetSettings=Guild.GetSettings,
    BeginSettingsBatch=Controller.BeginSettingsBatch,EndSettingsBatch=Controller.EndSettingsBatch,
    OnSettingsProfileApplied=Controller.OnSettingsProfileApplied,
    Stop=Controller.Stop,Start=Controller.Start,IsBusy=Controller.IsBusy,
}
BootyLib.RegisterProduct(Guild.Product)

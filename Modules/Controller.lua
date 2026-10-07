local Guild = BootyGuild
local UI, Roster, Statistics = Guild.UI.Components, Guild.Modules.RosterManagement, Guild.Modules.GuildStatistics
local Scan = Guild.Core.GuildScanController
local Controller = {}
Guild.Controller = Controller
local runtime
local eventNames={"GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","PLAYER_ENTERING_WORLD"}
local function Message(value,fallback)
    if type(value)=="table" then value=value.message or value.code end
    return tostring(value or fallback or "BootyGuild operation failed.")
end
local function RegisterEvents()
    for _,name in ipairs(eventNames) do runtime.events:RegisterEvent(name) end
end

local function GuildPromptOwner()
    local host = runtime and runtime.host
    return host and (host.windows and host.windows.roster or host.window)
end

local function WrapOperations()
    local diagnostics = Guild.Diagnostics
    if not diagnostics or not diagnostics.Wrap then return end
    local service = Guild.Services.Roster
    service.BuildSnapshot = diagnostics.Wrap("Guild roster scan", service.BuildSnapshot, 1)
    service.StepSnapshot = diagnostics.Wrap("Guild roster scan step", service.StepSnapshot, 3)
    service.FinishSnapshot = diagnostics.Wrap("Guild roster scan finish", service.FinishSnapshot, 2)
    Roster.RefreshView = diagnostics.Wrap("Roster refresh", Roster.RefreshView, 6)
end

local function Print(message)
    if runtime and runtime.host and runtime.host.Print then runtime.host.Print(message)
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("BootyGuild: "..tostring(message)) end
end

local function ReloadGuildExport()
    local shared = BootyLib.Core and BootyLib.Core.Runtime
    if not shared or type(shared.CanReload) ~= "function" then Print("Reload guard is unavailable.");return false end
    local ok, ready, reason = pcall(shared.CanReload)
    if not ok or ready~=true then
        local failure=reason
        if not ok then failure=ready end
        Print(Message(failure,"Reload is currently blocked."));return false
    end
    local reload = type(ReloadUI)=="function" and ReloadUI or type(ConsoleExec)=="function" and ConsoleExec
    if not reload then Print("Reload is unavailable.");return false end
    local success, result
    if reload==ReloadUI then success,result=pcall(reload) else success,result=pcall(reload,"reloadui") end
    if not success or result==false or result==0 then Print(Message(not success and result or nil,"Reload failed."));return false end
    return true
end

local function CurrentData()
    local _, name, realm = Guild.Database.GetGuildIdentity()
    if not name or not Guild.Services.Roster.IsInGuild() then return nil, name end
    local data = Guild.Database.GetRosterData()
    if data and (data.guildName ~= name or data.realmName and data.realmName ~= realm) then data = nil end
    return data, name
end

function Controller.IsAvailable()
    if runtime and runtime.stopped then return false, "BootyGuild is stopped." end
    if not Guild.Services.Roster.IsInGuild() then return false, "Join a guild to open Guild." end
    return true
end

local function StopProgress()
    local _, view
    for _, view in pairs(runtime.views) do if view.progress then UI.ProgressBar.Stop(view.progress) end end
end

local function Complete(snapshot)
    if not Scan.IsPending(runtime.scan) or not snapshot then return false end
    local mode = Scan.GetMode(runtime.scan)
    if not Guild.Database.StoreRosterSnapshot(snapshot) then return false end
    Scan.Finish(runtime.scan)
    StopProgress()
    local roster, statistics = runtime.views.roster, runtime.views.statistics
    if roster then Roster.SetReady(roster.page.dataController,true);Roster.SetRefreshPending(roster.page.dataController,false);roster:Refresh() end
    if statistics then Statistics.SetReady(statistics.controller,true);statistics:Refresh() end
    if mode == "reload" then UI.ShowOpaquePopup("BOOTY_GUILD_RELOAD")
    elseif mode ~= "quiet" then Print("Guild data loaded successfully. Members: "..Guild.Database.CountRosterMembers()..".") end
    Scan.ClearOrigin(runtime.scan)
    return true
end

local function ScanFailed()
    StopProgress()
    local roster, statistics = runtime.views.roster, runtime.views.statistics
    if roster then Roster.SetRefreshPending(roster.page.dataController,false);roster:Refresh() end
    if statistics then Statistics.HandleScanFailure(statistics.controller) end
    Scan.ClearOrigin(runtime.scan)
    Print("Guild scan could not finish. Join a guild and try again.")
end

function Controller.RequestScan(mode)
    if not Controller.IsAvailable() then Print("Join a guild to scan guild data.");return false end
    return Scan.Request(runtime.scan,mode)
end

function Controller.RequestShared(origin)
    if not Controller.IsAvailable() then return false end
    if not Scan.RequestShared(runtime.scan,origin) then return false end
    local roster, statistics = runtime.views.roster, runtime.views.statistics
    if roster then Roster.SetRefreshPending(roster.page.dataController,true) end
    if statistics then Statistics.BeginScan(statistics.controller) end
    return true
end

function Controller.Initialize(host)
    if runtime then
        if runtime.cleanupPending then return false,"BootyGuild cleanup is incomplete. Retry Stop before resuming." end
        if host then runtime.host=host end
        if runtime.initialized then
            if runtime.stopped then return Controller.Start() end
            return true
        end
    else
        if not Guild.Database.Ensure() then return false end
        runtime = {views={},host=host,stopped=true}
    end
    if not runtime.operationsWrapped then WrapOperations();runtime.operationsWrapped=true end
    if not runtime.scan then runtime.scan = Scan.Create({
        isInGuild=Guild.Services.Roster.IsInGuild,
        requestRoster=function() if type(GuildRoster)=="function" then GuildRoster() end end,
        printMessage=Print,
        startSnapshot=Guild.Services.Roster.StartSnapshot,
        stepSnapshot=Guild.Services.Roster.StepSnapshot,
        finishSnapshot=Guild.Services.Roster.FinishSnapshot,
        cancelSnapshot=Guild.Services.Roster.CancelSnapshot,
        tryComplete=Complete,
        onStart=function(_,controller)
            for _,view in pairs(runtime.views) do
                if view.progress and view.frame:IsVisible() then UI.ProgressBar.Start(view.progress,"Scanning guild data",controller.startedAt,7,94) end
            end
        end,
        onFailure=ScanFailed,
    }) end
    runtime.events=runtime.events or UI.CreateContainer("BootyGuildEventFrame",UIParent)
    runtime.events:SetScript("OnEvent",function() Controller.HandleEvent(event,arg1) end)
    RegisterEvents()
    StaticPopupDialogs.BOOTY_GUILD_RELOAD = {
        mosProjectTitle="Export guild roster",mosProjectOwner=GuildPromptOwner,text="The guild roster scan is complete. Reload the UI now to write it to disk?",
        button1="Reload now",button2="Later",
        OnAccept=ReloadGuildExport,
        OnCancel=function() Print("Guild data remains in memory. Use /reload before closing the game to save it.") end,
        timeout=0,whileDead=1,hideOnEscape=1,
    }
    runtime.initialized,runtime.stopped=true,false
    return true
end

function Controller.HandleEvent(name,unit)
    if not runtime or runtime.stopped then return end
    if name == "GUILD_ROSTER_UPDATE" then
        Scan.HandleRosterUpdate(runtime.scan)
        local roster=runtime.views.roster
        if roster then Roster.HandleGuildRosterUpdate(roster.page.dataController,false,Scan.IsPending(runtime.scan)) end
    elseif name == "PLAYER_GUILD_UPDATE" and (unit==nil or unit=="player") then
        if not Guild.Services.Roster.IsInGuild() then
            Scan.Finish(runtime.scan);StopProgress()
            for _,view in pairs(runtime.views) do view:Hide() end
        end
    elseif name == "PLAYER_ENTERING_WORLD" then Scan.CancelLive(runtime.scan) end
end

local function NewPage(parent,host)
    local page=UI.CreateContainer(nil,parent)
    page:SetAllPoints(parent);page.host=host
    return page
end

local function Progress(page)
    local progress=UI.ProgressBar.Create(page,280,16)
    progress:SetPoint("CENTER",page,"CENTER",0,0)
    progress:SetFrameLevel(page:GetFrameLevel()+20)
    return progress
end

function Controller.CreateRoster(parent,host)
    Controller.Initialize(host)
    local page=NewPage(parent,host)
    local shell=Roster.CreateShell(page,parent)
    local controls=Roster.CreateGuildControls(page)
    controls.exportButton:Hide()
    local filter=Roster.CreateFilterView(page)
    local selectedClasses,selectedRanks,visibleMembers={},{},{}
    local sortKey=Guild.Database.GetSetting("rosterSortKey") or "rank"
    if sortKey=="none" then sortKey=nil end
    local ascending=Guild.Database.GetSetting("rosterSortAscending")~=false
    local selectedName,renderer,requestAction,view
    local function Refresh(reset)
        local data,name=CurrentData()
        if not page:IsVisible() then Roster.InvalidateView(renderer,reset);return end
        Guild.Diagnostics.Count("uiRefreshes")
        Roster.RefreshView(renderer,data,name,reset,sortKey,selectedName)
    end
    local list=Roster.MountList(page,filter,{
        selectedClasses=selectedClasses,selectedRanks=selectedRanks,rowHeight=20,
        getUniqueValues=Guild.Services.Roster.GetUniqueMemberValues,
        refreshFilters=function() Refresh(false) end,
        onSort=function(key)
            if sortKey~=key then sortKey=key;ascending=true elseif ascending then ascending=false else sortKey=nil;ascending=true end
            Guild.Database.SetSetting("rosterSortKey",sortKey or "none");Guild.Database.SetSetting("rosterSortAscending",ascending);Refresh(true)
        end,
        onAction=function(action,member) requestAction(action,member) end,
        onSelect=function(member) if selectedName==member.name then selectedName=nil else selectedName=member.name end;Refresh(false) end,
        isSelected=function(member) return selectedName==member.name end,
    })
    Roster.BuildLayoutControls(page,shell,filter,controls)
    Roster.MountControllers(page,{
        guildControls=controls,contentPanel=parent,sortHint=filter.sortHint,
        startSharedScan=Controller.RequestShared,requestScan=Controller.RequestScan,printMessage=Print,
        buildSnapshot=Guild.Services.Roster.BuildSnapshot,storeSnapshot=Guild.Services.Roster.StoreSnapshot,
        requestLiveScan=function() return not runtime.stopped and Scan.QueueLive(runtime.scan) end,
        cancelLiveScan=function() return Scan.CancelLive(runtime.scan) end,
        refresh=Refresh,
    })
    renderer=Roster.CreateRenderer({page=page,scanButton=controls.scanButton,statusText=shell.status,summaryText=shell.lastScan,
        searchBox=shell.searchBox,visibleMembers=visibleMembers,selectedClasses=selectedClasses,selectedRanks=selectedRanks,
        sortMembers=function(a,b) return Roster.CompareMembers(a,b,sortKey,ascending) end,
        getLowestRankIndex=Guild.Services.Roster.GetLowestRankIndex,
        getMotd=function() return type(GetGuildRosterMOTD)=="function" and GetGuildRosterMOTD() or "Guild Message of the Day" end,
    })
    requestAction=Roster.CreateGuildActionHandler({
        owner=page,
        getData=CurrentData,getSelectedName=function() return selectedName end,
        findMember=Guild.Services.Roster.FindMember,findRankName=Guild.Services.Roster.FindRankName,
        queueRefresh=function() Scan.Queue(runtime.scan) end,printMessage=Print,
    })
    Roster.AttachInteractions({page=page,exportButton=controls.exportButton,searchBox=shell.searchBox,listController=list,
        contentPanel=parent,ensureDatabase=Guild.Database.Ensure,requestScan=Controller.RequestScan,
        clearSelection=function() selectedName=nil end,refresh=Refresh,
    })
    view=Roster.CreateLifecycle(page,page.dataController,Refresh)
    local show,hide=view.Show,view.Hide
    function view:Show()
        local available,message=Controller.IsAvailable()
        if not available then Print(message);return false end
        show(self);return true
    end
    function view:Hide()
        hide(self)
        for _,key in ipairs({"guildInfoEditor","guildMotdEditor","guildInviteDialog","detailsWindow"}) do if page[key] then page[key]:Hide() end end
        UI.ProgressBar.Stop(self.progress)
    end
    view.frame,view.page,view.controls,view.progress=page,page,controls,Progress(page)
    runtime.views.roster=view
    Roster.SetReady(page.dataController,CurrentData()~=nil)
    page:Hide()
    return view
end

function Controller.CreateStatistics(parent,host)
    Controller.Initialize(host)
    local owner=NewPage(parent,host)
    local controller
    local function Refresh() if controller then Statistics.Refresh(controller) end end
    local content=Statistics.CreateView(owner,UI.StyleButton,Refresh)
    controller=Statistics.CreateController({page=owner,view=content,getData=CurrentData,startScan=Controller.RequestShared})
    local export=UI.CreateButton(content.page,nil,"Export Guild",100,26)
    Statistics.AttachExport(content,export)
    export:SetScript("OnClick",function() Controller.RequestScan("reload") end)
    local view=Statistics.CreateLifecycle(controller)
    local show,hide=view.Show,view.Hide
    function view:Show()
        local available,message=Controller.IsAvailable()
        if not available then Print(message);return false end
        show(self);return true
    end
    function view:Hide() hide(self);UI.ProgressBar.Stop(self.progress) end
    view.frame,view.page,view.controller,view.progress=owner,content.page,controller,Progress(content.page)
    runtime.views.statistics=view
    Statistics.SetReady(controller,CurrentData()~=nil)
    owner:Hide()
    return view
end

function Controller.SettingsChanged(key)
    if not runtime then return end
    if (runtime.settingsBatchDepth or 0) > 0 then runtime.settingsBatchDirty=true;return end
    local roster=runtime.views.roster
    if roster then
        if key=="rosterLiveTrackingEnabled" then
            if roster.frame:IsVisible() and not runtime.stopped then Roster.ActivateDataController(roster.page.dataController,false)
            else Roster.DeactivateDataController(roster.page.dataController) end
        end
        roster:Refresh()
    end
    local statistics=runtime.views.statistics
    if statistics then statistics:Refresh() end
end

function Controller.BeginSettingsBatch()
    if runtime then runtime.settingsBatchDepth=(runtime.settingsBatchDepth or 0)+1 end
end
function Controller.EndSettingsBatch(success)
    if not runtime then return end
    runtime.settingsBatchDepth=math.max(0,(runtime.settingsBatchDepth or 0)-1)
    if runtime.settingsBatchDepth==0 then
        local dirty=runtime.settingsBatchDirty;runtime.settingsBatchDirty=nil
        if success~=false and dirty then Controller.SettingsChanged("rosterLiveTrackingEnabled") end
    end
end
function Controller.OnSettingsProfileApplied()
    Controller.SettingsChanged("rosterLiveTrackingEnabled")
end

function Controller.Stop()
    if not runtime then return true end
    runtime.stopped=true
    local failures={}
    local function Attempt(callback,owner)
        local ok,result,reason=pcall(callback,owner)
        if not ok or result==false then table.insert(failures,Message(reason or result,"BootyGuild cleanup refused.")) end
    end
    if runtime.scan then Attempt(Scan.Finish,runtime.scan);Attempt(Scan.ClearOrigin,runtime.scan) end
    if runtime.events then Attempt(runtime.events.UnregisterAllEvents,runtime.events) end
    for _,view in pairs(runtime.views) do
        if view.progress then Attempt(UI.ProgressBar.Stop,view.progress) end
        if view.Hide then Attempt(view.Hide,view) end
    end
    runtime.cleanupPending=table.getn(failures)>0 or nil
    if runtime.cleanupPending then return false,table.concat(failures," ") end
    return true
end

function Controller.Start()
    if not runtime or not runtime.initialized then return Controller.Initialize() end
    if runtime.cleanupPending then return false,"BootyGuild cleanup is incomplete. Retry Stop before resuming." end
    local called,failure=pcall(RegisterEvents)
    if not called then
        local cleaned,reason=Controller.Stop()
        failure=Message(failure)
        if not cleaned then failure=failure.." Resume cleanup failed: "..reason end
        return false,failure
    end
    runtime.stopped=false
    return true
end

function Controller.IsBusy() return runtime and runtime.scan and Scan.IsPending(runtime.scan) or false end
function Controller.GetRuntime() return runtime end

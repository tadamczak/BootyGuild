local MOS = BootyGuild

MOS.Modules.RosterManagement = MOS.Modules.RosterManagement or {}
local RosterManagement = MOS.Modules.RosterManagement

local function RosterSpan(page)
    return MOS.UI.Components.GetFrameSpan(page)
end

function RosterManagement.CreateSections(page)
    if page.tablePanel then return end
    local C = MOS.UI.Components
    local backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
    page.tablePanel = C.CreateContainer(nil, page)
    page.actionsPanel = C.CreateContainer(nil, page)
    local _, panel
    for _, panel in ipairs({page.tablePanel, page.actionsPanel}) do
        panel:EnableMouse(false); panel:SetBackdrop(backdrop)
        C.RegisterSkinnedSurface(panel, "content", backdrop, {0.025, 0.022, 0.018, 0.99}, {0.36, 0.36, 0.34, 1})
    end
    C.JoinSurfaceEdges(page.tablePanel, true, true)
    C.JoinSurfaceEdges(page.actionsPanel, true, false)
    page.filterToolbar = C.CreateToolbarSurface(page.tablePanel, false, true)
    page.filterToolbar:SetPoint("TOPLEFT", page.tablePanel, "TOPLEFT", 0, 0)
    page.filterToolbar:SetPoint("TOPRIGHT", page.tablePanel, "TOPRIGHT", 0, 0)
    page.filterToolbar:Hide()
    page.actionsPanel:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.actionsPanel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.actionsPanel:SetHeight(34)
end

function RosterManagement.CreateShell(page, contentPanel)
    RosterManagement.CreateSections(page)
    page.detailsOwner = contentPanel:GetParent()
    local title = MOS.UI.Components.CreateHeading(page, "", 1, "gold", "roster")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -10)
    title:SetText("Guild"); page.sectionTitle = title

    local searchLabel = MOS.UI.Components.CreateLabel(page.tablePanel or page, nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -192, -87)
    searchLabel:SetText("");searchLabel:Hide()
    local searchBox = MOS.UI.Components.CreateFramedEditBox(page.tablePanel or page, "BootyGuildRosterSearch", 178)
    searchBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -81)
    MOS.UI.Components.AttachPlaceholder(searchBox,"Search...")

    local status = MOS.UI.Components.CreateLabel(page, nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -40)
    status:SetWidth(565)
    status:SetJustifyH("LEFT")
    local lastScan = MOS.UI.Components.CreateLabel(page.tablePanel or page, nil, "OVERLAY", "GameFontDisableSmall")
    lastScan:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -58)
    lastScan:SetWidth(330)
    lastScan:SetJustifyH("LEFT")

    -- This panel follows the full content area; row capacity must not depend on
    -- the fitted visual panel height calculated during the preceding refresh.
    page.fittedPanel = MOS.UI.Components.CreateContainer(nil, contentPanel)
    page.fittedPanel:SetFrameLevel(contentPanel:GetFrameLevel())
    page.fittedPanel:SetAllPoints(contentPanel)
    -- An unstyled host page can return no values from the native getter.
    -- Keep an explicit nil argument: SetBackdrop() is not SetBackdrop(nil).
    local contentBackdrop = contentPanel:GetBackdrop()
    page.fittedPanel:SetBackdrop(contentBackdrop)
    page.fittedPanel:SetBackdropColor(0.025, 0.022, 0.018, 0.99)
    page.fittedPanel:SetBackdropBorderColor(0.36, 0.36, 0.34, 1)
    page.fittedPanel:Hide()
    return { searchLabel = searchLabel, searchBox = searchBox, status = status, lastScan = lastScan }
end

function RosterManagement.CreateGuildControls(page)
    local scanButton = MOS.UI.Components.CreateButton(page, nil, "Scan Guild Data", 140, 24)
    scanButton:SetPoint("CENTER", page, "CENTER", 0, 12)
    local refreshButton = MOS.UI.Components.CreateIconButton(page.actionsPanel or page, nil, "Interface\\Buttons\\UI-RotationRight-Button-Up", 24)
    refreshButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -48)
    MOS.UI.Components.AttachTooltip(refreshButton, "Refresh guild data", "Refresh the saved guild roster. Hidden while Live tracking is active.")
    refreshButton:Hide()
    local exportButton = MOS.UI.Components.CreateButton(page, nil, "Export Guild", 120, 22)
    exportButton:SetPoint("CENTER", page, "CENTER", 96, 12)

    page.guildInfoEditor = MOS.UI.Components.CreateTextEditor("BootyGuildGuildInfoEditor", "Guild Information", 500, function(value)
        if type(SetGuildInfoText) == "function" then SetGuildInfoText(value) end
    end)
    page.guildInfoEditor.title:SetTextColor(unpack(MOS.UI.Components.Theme.colors.goldText))
    page.guildMotdEditor = MOS.UI.Components.CreateTextEditor("BootyGuildGuildMotdEditor", "Guild Message of the Day", 128, function(value)
        if type(GuildSetMOTD) == "function" then GuildSetMOTD(value) end
    end)
    page.guildInfoButton = MOS.UI.Components.CreateButton(page.actionsPanel or page, nil, "Guild Information", 108, 22)
    page.guildAddButton = MOS.UI.Components.CreateButton(page.actionsPanel or page, nil, "Add Member", 84, 22)
    page.guildControlButton = MOS.UI.Components.CreateButton(page.actionsPanel or page, nil, "Guild Control", 88, 22)
    local _, button
    for _, button in ipairs({ page.guildInfoButton, page.guildAddButton, exportButton, page.guildControlButton }) do
        MOS.UI.Components.SetClassicButtonVariant(button, "red")
        MOS.UI.Components.SetClassicButtonGold(button, true)
    end
    page.guildInfoButton:Hide(); page.guildAddButton:Hide(); page.guildControlButton:Hide()
    RosterManagement.BindPermissionEvents(page)

    local controls = { scanButton = scanButton, refreshButton = refreshButton, exportButton = exportButton }
    function controls.OpenGMOTD()
        page.guildMotdEditor:Open(type(GetGuildRosterMOTD) == "function" and GetGuildRosterMOTD() or "")
        return true
    end
    function controls.OpenGuildInformation()
        page.guildInfoEditor:Open(type(GetGuildInfoText) == "function" and GetGuildInfoText() or "")
        return true
    end
    function controls.OpenAddMember()
        if not MOS.Services.Roster.CanInviteMember() then return false end
        if page.guildInviteDialog and page.guildInviteDialog:IsShown() then
            page.guildInviteDialog:Hide(); return true
        end
        if not page.guildInviteDialog then
            local C = MOS.UI.Components
            local dialog = C.Window.CreateProjectConfirmation("BootyGuildGuildInvite", "Add Member", "Invite", "roster", {modal=false})
            dialog:SetWidth(320)
            dialog.memberName = C.CreateFramedEditBox(dialog, "BootyGuildGuildInviteName", 304)
            dialog.memberName:SetPoint("TOPLEFT", dialog, "TOPLEFT", 8, -62); dialog.memberName:SetMaxLetters(24)
            dialog.memberName:SetScript("OnEscapePressed", function() dialog:Hide() end)
            dialog.memberName:SetScript("OnEnterPressed", function() dialog.yes:GetScript("OnClick")() end)
            local hidden=dialog:GetScript("OnHide")
            dialog:SetScript("OnHide", function() if hidden then hidden() end;dialog.memberName:ClearFocus() end)
            page.guildInviteDialog = dialog
        end
        local dialog = page.guildInviteDialog
        dialog:Open("Character name", function()
            MOS.Services.Roster.InviteMember(dialog.memberName:GetText())
        end)
        dialog.label:SetHeight(18); dialog:SetHeight(128)
        dialog.memberName:SetText(""); dialog.memberName:SetFocus()
        return true
    end
    function controls.GetQuickState()
        return { gmotd = true, guildInformation = true, addMember = MOS.Services.Roster.CanInviteMember() }
    end
    page.guildInfoButton:SetScript("OnClick", controls.OpenGuildInformation)
    page.guildAddButton:SetScript("OnClick", controls.OpenAddMember)
    page.guildControlButton:SetScript("OnClick", function() if not MOS.Services.Roster.CanManage("control") then return end; if type(GuildControlPopupFrame_Toggle) == "function" then GuildControlPopupFrame_Toggle() elseif type(ToggleGuildFrame) == "function" then ToggleGuildFrame() end end)

    page.footer = MOS.UI.Components.CreateControl(nil, page)
    page.footer:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 4, 4); page.footer:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 4); page.footer:SetHeight(38)
    page.footer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    MOS.UI.Components.RegisterSkinnedSurface(page.footer, "content", { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 }, {0.025, 0.022, 0.018, 0.99}, {0.36, 0.36, 0.34, 1})
    page.footer.guild = MOS.UI.Components.CreateLabel(page.footer, nil, "OVERLAY", "GameFontNormalSmall"); page.footer.guild:SetPoint("TOPLEFT", page.footer, "TOPLEFT", 8, -4)
    page.footer.motd = MOS.UI.Components.CreateLabel(page.footer, nil, "OVERLAY", "GameFontHighlightSmall"); page.footer.motd:SetPoint("BOTTOMLEFT", page.footer, "BOTTOMLEFT", 8, 6); page.footer.motd:SetJustifyH("LEFT")
    page.footer:SetScript("OnClick", controls.OpenGMOTD)
    MOS.UI.Components.AttachTooltip(page.footer, "Guild Message of the Day", "Click to edit the guild message of the day.")
    page.footer:Hide()
    local font, size, flags = page.footer.guild:GetFont()
    page.footer.guild:SetFont(font, size, flags)
    MOS.UI.Components.JoinSurfaceEdges(page.footer, false, true)
    font, size, flags = page.footer.motd:GetFont()
    page.footer.motd:SetFont(font, size + 1, flags)
    page.footer.rule = MOS.UI.Components.CreateTexture(page, nil, "ARTWORK")
    page.footer.rule:SetPoint("TOPLEFT", page.footer, "BOTTOMLEFT", 8, -8)
    page.footer.rule:SetPoint("TOPRIGHT", page.footer, "BOTTOMRIGHT", 0, -8)
    page.footer.rule:SetHeight(1); page.footer.rule:SetTexture(0.55, 0.42, 0.16, 0.75)
    return controls
end

function RosterManagement.CreateGuildActionHandler(options)
    local pendingAction
    local function Finish(apiFunction, verb)
        if pendingAction and type(apiFunction) == "function" then
            local memberName = pendingAction.name
            if not MOS.Services.Roster.PerformMemberAction(pendingAction.action, memberName) then pendingAction = nil; return end
            options.printMessage(verb .. " requested for " .. memberName .. ".")
            options.queueRefresh()
        end
        pendingAction = nil
    end
    StaticPopupDialogs["BOOTY_GUILD_PROMOTE"] = {
        mosProjectTitle = "Promote Guild Member", mosProjectOwner = options.owner,
        text = "%s", button1 = "Promote", button2 = "Cancel",
        OnAccept = function() Finish(GuildPromoteByName, "Promotion") end,
        OnCancel = function() pendingAction = nil end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    StaticPopupDialogs["BOOTY_GUILD_DEMOTE"] = {
        mosProjectTitle = "Demote Guild Member", mosProjectOwner = options.owner,
        text = "%s", button1 = "Demote", button2 = "Cancel",
        OnAccept = function() Finish(GuildDemoteByName, "Demotion") end,
        OnCancel = function() pendingAction = nil end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    StaticPopupDialogs["BOOTY_GUILD_REMOVE"] = {
        mosProjectTitle = "Remove Guild Member", mosProjectOwner = options.owner,
        text = "%s", button1 = "Remove", button2 = "Cancel",
        OnAccept = function() Finish(GuildUninvite, "Removal") end,
        OnCancel = function() pendingAction = nil end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    return function(action, requestedMember)
        if action == "refresh" then options.queueRefresh(); return end
        local data = options.getData()
        local member = requestedMember or options.findMember(data, options.getSelectedName())
        if not member or not MOS.Services.Roster.CanManage(action, member) then return end
        if action == "group" then
            MOS.Services.Roster.PerformMemberAction("group", member.name); return
        elseif action == "remove" then
            pendingAction = { name = member.name, action = action }
            MOS.UI.Components.ShowOpaquePopup("BOOTY_GUILD_REMOVE", "Remove " .. member.name .. " from the guild?")
            return
        end
        local direction = action == "promote" and -1 or 1
        local targetRank = options.findRankName(data, (tonumber(member.rankIndex) or 0) + direction) or "the next rank"
        if action == "promote" or action == "demote" then
            pendingAction = { name = member.name, action = action }
            local label = action == "promote" and "Promote" or "Demote"
            MOS.UI.Components.ShowOpaquePopup(action == "promote" and "BOOTY_GUILD_PROMOTE" or "BOOTY_GUILD_DEMOTE", label .. " " .. member.name .. "?\n" .. (member.rank or "Unknown") .. " -> " .. targetRank)
        end
    end
end

function RosterManagement.CreateFilterView(page)
    local sortHint = MOS.UI.Components.CreateLabel(page.tablePanel or page, nil, "OVERLAY", "GameFontDisableSmall")
    sortHint:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -114)
    sortHint:SetText("Click a column header to sort")
    sortHint:Hide()
    local label = MOS.UI.Components.CreateLabel(page.tablePanel or page, nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -112)
    label:SetText("")

    local classToggle = MOS.UI.Components.CreateDropdownButton(page.tablePanel or page, nil, "Class", 84)
    classToggle:SetPoint("TOPLEFT", page, "TOPLEFT", 50, -106)
    local rankToggle = MOS.UI.Components.CreateDropdownButton(page.tablePanel or page, nil, "Rank", 84)
    rankToggle:SetPoint("TOPLEFT", page, "TOPLEFT", 142, -106)

    page.showOfflineCheck = MOS.UI.Components.CreateCheckButton("BootyGuildShowOffline", page.tablePanel or page, "UICheckButtonTemplate")
    page.showOfflineCheck:SetPoint("TOPLEFT", page, "TOPLEFT", 232, -104)
    page.showOfflineCheck:SetWidth(22); page.showOfflineCheck:SetHeight(22)
    page.showOfflineCheck.label = MOS.UI.Components.CreateLabel(page.showOfflineCheck, nil, "OVERLAY", "GameFontHighlightSmall")
    page.showOfflineCheck.label:SetPoint("LEFT", page.showOfflineCheck, "RIGHT", 2, 0)
    page.showOfflineCheck.label:SetText("Show offline")

    page.modeButton = MOS.UI.Components.CreateControl(nil, page.tablePanel or page)
    page.modeButton:SetWidth(22); page.modeButton:SetHeight(22)
    -- Spellbook artwork has transparent right padding; align its visible edge with the scrollbar arrows.
    page.modeButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -6, -102)
    page.modeButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    page.modeButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    page.modeButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    page.modeButton.label = MOS.UI.Components.CreateLabel(page.modeButton, nil, "OVERLAY", "GameFontNormalSmall")
    page.modeButton.label:SetPoint("RIGHT", page.modeButton, "LEFT", -4, 0)
    page.modeButton.label:SetText("Show Player Status")
    MOS.UI.Components.AttachTooltip(page.modeButton, "Show player status", "Switch between guild notes and player status columns.")

    local classPanel = MOS.UI.Components.CreateDropdownPanel(page.tablePanel or page, classToggle, 130, 230, 20)
    local rankPanel = MOS.UI.Components.CreateDropdownPanel(page.tablePanel or page, rankToggle, 130, 230, 20)
    local dismiss = classPanel.dismiss
    return { sortHint = sortHint, label = label, classToggle = classToggle, rankToggle = rankToggle, classPanel = classPanel, rankPanel = rankPanel, dismiss = dismiss }
end

function RosterManagement.MountList(page, filterView, options)
    RosterManagement.CreateFilterController({
        page = page,
        classToggle = filterView.classToggle,
        rankToggle = filterView.rankToggle,
        classPanel = filterView.classPanel,
        rankPanel = filterView.rankPanel,
        dismiss = filterView.dismiss,
        selectedClasses = options.selectedClasses,
        selectedRanks = options.selectedRanks,
        getUniqueValues = options.getUniqueValues,
        refresh = options.refreshFilters,
    })
    RosterManagement.CreateHeaders(page, options.onSort)
    page.rowController = {
        page = page,
        onAction = options.onAction,
        onSelect = options.onSelect,
        isSelected = options.isSelected,
    }
    return RosterManagement.CreateListController(page, options.rowHeight, page.rowController)
end

function RosterManagement.BuildLayoutControls(page, shell, filterView, guildControls)
    page.layoutControls = {
        footer = page.footer,
        filtersLabel = filterView.label,
        classFilter = filterView.classToggle,
        rankFilter = filterView.rankToggle,
        searchLabel = shell.searchLabel,
        searchBox = shell.searchBox,
        showOffline = page.showOfflineCheck,
        refreshButton = guildControls.refreshButton,
        status = shell.lastScan,
        modeButton = page.modeButton,
        actions = {
            { button = page.guildInfoButton, width = 118 },
            { button = page.guildAddButton, width = 90, permission = "invite" },
            { button = page.guildControlButton, width = 100, permission = "control" },
        },
    }
    return page.layoutControls
end

local rosterHeaderSpecs = {
    { "Name", 12, 132, "name" },
    { "Lvl", 149, 38, "level" },
    { "Class", 197, 82, "class" },
    { "Rank", 289, 100, "rank" },
}

local function CreateHeaderButton(page, controller, text, x, width, key, sortable)
    return MOS.UI.Components.Table.CreateHeader(page.tablePanel or page, controller, text, x, -130, width, key, sortable)
end

-- Pure layout calculation. Keeping this outside the view prevents accidental
-- frame-to-frame feedback loops when the roster page is resized.
function RosterManagement.CalculateVisibleRows(viewportHeight, rowHeight, hasExpandedRow)
    local height = math.max(0, tonumber(viewportHeight) or 0)
    local step = math.max(1, tonumber(rowHeight) or 1)
    local expandedReserve = hasExpandedRow and 208 or 0
    return math.max(hasExpandedRow and height >= step and 1 or 0, math.floor((height - expandedReserve) / step))
end

function RosterManagement.NeedsLayout(width, height, previousWidth, previousHeight, forced)
    if forced then return true end
    return math.abs((tonumber(width) or 0) - (tonumber(previousWidth) or 0)) > 0.5
        or math.abs((tonumber(height) or 0) - (tonumber(previousHeight) or 0)) > 0.5
end

function RosterManagement.MatchesFilters(member, selectedClasses, selectedRanks, showOffline)
    local className = tostring(member.class or "Unknown")
    local rankName = tostring(member.rank or "Unknown")
    if className == "" then className = "Unknown" end
    if rankName == "" then rankName = "Unknown" end
    if not showOffline and not member.online then return false end
    return (not selectedClasses or selectedClasses[className]) and (not selectedRanks or selectedRanks[rankName])
end

function RosterManagement.MatchesSearch(member, query)
    if query == "" then return true end
    local searchable = string.lower(
        tostring(member.name or "") .. " " .. tostring(member.level or "") .. " " ..
        tostring(member.class or "") .. " " .. tostring(member.rank or "") .. " " ..
        tostring(member.rankIndex or "") .. " " .. tostring(member.publicNote or "") .. " " ..
        tostring(member.officerNote or "") .. " " .. tostring(member.zone or "") .. " " ..
        tostring(member.status or "") .. " " .. tostring(member.online)
    )
    return string.find(searchable, query, 1, true) ~= nil
end

function RosterManagement.FilterMembers(target, data, query, selectedClasses, selectedRanks, showOffline)
    local targetIndex
    for targetIndex = table.getn(target), 1, -1 do table.remove(target, targetIndex) end
    if not data or not data.members then return target end
    local memberIndex
    for memberIndex = 1, table.getn(data.members) do
        local member = data.members[memberIndex]
        if RosterManagement.MatchesSearch(member, query)
            and RosterManagement.MatchesFilters(member, selectedClasses, selectedRanks, showOffline) then
            table.insert(target, member)
        end
    end
    return target
end

function RosterManagement.CreateFilterController(options)
    local controller = {
        page = options.page,
        classToggle = options.classToggle,
        rankToggle = options.rankToggle,
        classPanel = options.classPanel,
        rankPanel = options.rankPanel,
        dismiss = options.dismiss,
        selectedClasses = options.selectedClasses,
        selectedRanks = options.selectedRanks,
        getUniqueValues = options.getUniqueValues,
        refresh = options.refresh,
        classInitialized = false,
        rankInitialized = false,
    }

    function controller:Hide()
        self.classPanel:Hide(); self.rankPanel:Hide(); self.dismiss:Hide()
    end

    function controller:Build(data)
        if self.page.filterData == data then return end
        local classes = self.getUniqueValues(data, "class")
        local ranks = self.getUniqueValues(data, "rank")
        local index
        if not self.classInitialized then
            for index = 1, table.getn(classes) do self.selectedClasses[classes[index]] = true end
            self.classInitialized = true
        end
        if not self.rankInitialized then
            for index = 1, table.getn(ranks) do self.selectedRanks[ranks[index]] = true end
            self.rankInitialized = true
        end
        MOS.UI.Components.FilterPanel.Refresh(self.classPanel, classes, self.selectedClasses, self.refresh)
        MOS.UI.Components.FilterPanel.Refresh(self.rankPanel, ranks, self.selectedRanks, self.refresh)
        self.page.filterData = data
    end

    controller.dismiss:SetScript("OnClick", function() controller:Hide() end)
    controller.classToggle:SetScript("OnClick", function()
        local show = not controller.classPanel:IsVisible()
        controller:Hide()
        if show then controller.classPanel:Show() end
    end)
    controller.rankToggle:SetScript("OnClick", function()
        local show = not controller.rankPanel:IsVisible()
        controller:Hide()
        if show then controller.rankPanel:Show() end
    end)
    options.page.filterController = controller
    return controller
end

function RosterManagement.CreateHeaders(page, onSort)
    local ui = { buttons = {}, controller = { onSort = onSort } }
    local index
    for index = 1, table.getn(rosterHeaderSpecs) do
        local spec = rosterHeaderSpecs[index]
        ui.buttons[index] = CreateHeaderButton(page, ui.controller, spec[1], spec[2], spec[3], spec[4], true)
    end
    ui.zone = CreateHeaderButton(page, ui.controller, "Zone", 149, 150, "zone", true)
    ui.lastOnline = CreateHeaderButton(page, ui.controller, "Last online", 430, 140, "lastOnlineHours", true)
    ui.zone:Hide(); ui.lastOnline:Hide()
    ui.notes = CreateHeaderButton(page, ui.controller, "Public note", 399, 174, "publicNote", false)
    ui.officer = CreateHeaderButton(page, ui.controller, "Officer note", 399, 100, "officerNote", false); ui.officer:Hide()
    page.tableViewport = MOS.UI.Components.CreateContainer(nil, page.tablePanel or page)
    page.tableViewport:SetPoint("TOPLEFT", ui.buttons[1], "BOTTOMLEFT", 0, -2); page.tableViewport:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 32)
    page.officerHeader = ui.officer
    page.guildColumns = {
        { key = "name", header = ui.buttons[1], fraction = 0.28 },
        { key = "zone", header = ui.zone, fraction = 0.34 },
        { key = "level", header = ui.buttons[2], fraction = 0.10 },
        { key = "class", header = ui.buttons[3], fraction = 0.28 },
    }
    page.playerColumns = {
        { key = "name", header = ui.buttons[1], fraction = 0.20 },
        { key = "rank", header = ui.buttons[4], fraction = 0.16 },
        { key = "notes", header = ui.notes, fraction = 0.23 },
        { key = "officer", header = ui.officer, fraction = 0.23 },
        { key = "lastOnline", header = ui.lastOnline, fraction = 0.18 },
    }
    page.listHeaderUI = ui
    return ui
end

function RosterManagement.CompareMembers(a, b, sortKey, ascending)
    if not sortKey then return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or "")) end
    local aValue, bValue
    if sortKey == "level" then
        aValue, bValue = tonumber(a.level) or 0, tonumber(b.level) or 0
    elseif sortKey == "rank" then
        aValue, bValue = tonumber(a.rankIndex) or 999, tonumber(b.rankIndex) or 999
    else
        aValue, bValue = string.lower(tostring(a[sortKey] or "")), string.lower(tostring(b[sortKey] or ""))
    end
    if aValue == bValue then aValue, bValue = string.lower(tostring(a.name or "")), string.lower(tostring(b.name or "")) end
    if ascending then return aValue < bValue end
    return aValue > bValue
end

function RosterManagement.FormatLastOnline(member)
    if member.online then return "Online" end
    local years = tonumber(member.lastOnlineYears) or 0
    local months = tonumber(member.lastOnlineMonths) or 0
    local days = tonumber(member.lastOnlineDays) or 0
    local hours = tonumber(member.lastOnlineHours) or 0
    if years > 0 then return years .. " year" .. (years == 1 and "" or "s") end
    if months > 0 then return months .. " month" .. (months == 1 and "" or "s") end
    if days > 0 then return days .. " day" .. (days == 1 and "" or "s") end
    return hours .. " hour" .. (hours == 1 and "" or "s")
end

local function OnActionClick()
    local row = this.ownerRow
    if row and row.controller and row.controller.onAction then row.controller.onAction(this.action, row.displayedMember) end
end

local function OnRowClick()
    if arg1 == "RightButton" and this.displayedMember then RosterManagement.OpenMemberMenu(this); return end
    if this.displayedMember and this.controller and this.controller.onSelect then
        this.controller.onSelect(this.displayedMember)
    end
end

local function OnRowEnter()
    if this.displayedMember and not this.expanded and not this.controller.isSelected(this.displayedMember) then
        this.hover:Show()
    end
end

local function OnRowLeave()
    this.hover:Hide()
    if this.displayedMember and this.controller and not this.controller.isSelected(this.displayedMember) then
        if this.memberBackground then MOS.UI.Components.SetRowColor(this, this.memberBackground, 1) end
        this:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function CreateActionButton(row, text, action, x)
    local button = MOS.UI.Components.CreateArrowButton(row.actionPanel, action == "promote" and "up" or "down")
    button:SetPoint("TOPRIGHT", row.actionPanel, "TOPRIGHT", x, -6)
    MOS.UI.Components.AttachTooltip(button, text, text .. " this guild member.")
    button.action = action
    button.ownerRow = row
    button:SetScript("OnClick", OnActionClick)
    return button
end

local function AddCell(row, key, x, width)
    row[key] = MOS.UI.Components.CreateLabel(row, nil, "OVERLAY", "GameFontHighlightSmall")
    row[key]:SetPoint("TOPLEFT", row, "TOPLEFT", x, -1)
    row[key]:SetWidth(width)
    row[key]:SetHeight(18)
    row[key]:SetJustifyH("LEFT")
end

function RosterManagement.CreateRow(parent, index, rowHeight, controller)
    local row = MOS.UI.Components.CreateControl(nil, parent)
    row.controller = controller
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -134 - (index * rowHeight))
    row:SetWidth(560)
    row:SetHeight(rowHeight)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hover = MOS.UI.Components.CreateTexture(row, nil, "ARTWORK")
    row.hover:SetAllPoints(row); row.hover:SetTexture(0.65, 0.65, 0.65, 0.16); row.hover:Hide()
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    row:SetBackdropColor(0, 0, 0, 0)
    row:SetBackdropBorderColor(0, 0, 0, 0)
    MOS.UI.Components.RegisterSkinnedSurface(row, "row", { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    row.selection = MOS.UI.Components.CreateTexture(row, nil, "ARTWORK")
    row.selection:SetAllPoints(row)
    row.selection:SetTexture(0.65, 0.65, 0.65, 0.16)
    row.selection:Hide()

    AddCell(row, "name", 7, 125)
    AddCell(row, "level", 137, 38)
    AddCell(row, "class", 185, 82)
    AddCell(row, "rank", 277, 100)
    AddCell(row, "notes", 387, 173)
    AddCell(row, "officer", 0, 1)
    AddCell(row, "zone", 0, 1)
    AddCell(row, "lastOnline", 0, 1)
    row.zone:Hide()
    row.lastOnline:Hide()

    row.actionViewport, row.actionPanel = MOS.UI.Components.CreateClippedContent(row, 204)
    row.actionViewport:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -20)
    row.actionViewport:SetWidth(640)
    row.actionViewport:SetHeight(204)
    row.actionPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    row.actionPanel:SetBackdropColor(0, 0, 0, 0)
    row.actionPanel:SetBackdropBorderColor(0.30, 0.34, 0.30, 1)
    row.actionPanel:Hide()
    row.promoteButton = CreateActionButton(row, "Promote", "promote", -28)
    row.demoteButton = CreateActionButton(row, "Demote", "demote", -4)
    row:SetScript("OnHide", function() this.hover:Hide() end)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    return row
end

local function HideColumns(rows, columns)
    local columnIndex
    for columnIndex = 1, table.getn(columns) do
        local column = columns[columnIndex]
        column.header:Hide()
        local rowIndex
        for rowIndex = 1, table.getn(rows) do rows[rowIndex][column.key]:Hide() end
    end
end

local rosterFieldNames = { notes = "publicNote", officer = "officerNote" }
function RosterManagement.MeasureColumns(page, columns, members, available)
    if not page.columnMeasure then
        page.columnMeasure = MOS.UI.Components.CreateLabel(page, nil, "OVERLAY", "GameFontHighlightSmall")
        page.columnMeasure:Hide()
        page.columnMeasureFont, page.columnMeasureSize, page.columnMeasureFlags = page.columnMeasure:GetFont()
    end
    local measure = page.columnMeasure
    measure:SetWidth(0)
    local rows = page.listController and page.listController.rows
    local body = rows and rows[1]
    local index, memberIndex, gaps = nil, nil, 0
    for index = 1, table.getn(columns) do
        local column = columns[index]
        column.leftInset = column.key == "name" and 7 or 0
        column.rightInset = column.key == "name" and 7 or column.key == "level" and 4 or 6
        column.gapAfter = column.key == "level" and columns[index + 1] and columns[index + 1].key == "class" and 8 or 0
        gaps = gaps + column.gapAfter
        local padding = column.leftInset + column.rightInset
        local font, size, flags = (column.header.label or column.header):GetFont()
        measure:SetFont(font, size, flags)
        measure:SetText(column.header.baseText or "")
        local headerWidth = math.ceil(measure:GetStringWidth()) + padding
        if body and body[column.key] then font, size, flags = body[column.key]:GetFont()
        else font, size, flags = page.columnMeasureFont, page.columnMeasureSize, page.columnMeasureFlags end
        measure:SetFont(font, size, flags)
        local desired = headerWidth
        for memberIndex = 1, table.getn(members) do
            local member = members[memberIndex]
            local value = column.key == "lastOnline" and RosterManagement.FormatLastOnline(member) or member[rosterFieldNames[column.key] or column.key]
            measure:SetText(value or ""); measure:SetWidth(0)
            desired = math.max(desired, math.ceil(measure:GetStringWidth()) + padding)
        end
        if column.key == "notes" or column.key == "officer" then desired = math.min(240, desired) end
        if column.key == "class" then desired = math.max(headerWidth, math.min(130, desired)) end
        column.growthWeight = (column.key == "name" or column.key == "zone") and desired
            or (column.key == "notes" or column.key == "officer") and column.fraction or 0
        column.desiredWidth = desired
        column.minimumWidth = column.key == "class" and headerWidth
            or column.growthWeight == 0 and desired or math.min(desired, column.key == "name" and 80 or 36)
    end
    local growth = 0
    for index = 1, table.getn(columns) do growth = growth + columns[index].growthWeight end
    if growth == 0 then for index = 1, table.getn(columns) do columns[index].growthWeight = columns[index].fraction end end
    MOS.UI.Components.Table.AllocateColumnWidths(columns, math.max(1, available - gaps))
end

function RosterManagement.ApplyRowColumns(row, columns, tableWidth)
    local columnX = 0
    local columnIndex
    for columnIndex = 1, table.getn(columns) do
        local column = columns[columnIndex]
        local width = column.width or math.floor(tableWidth * column.fraction)
        local cell = row[column.key]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", row, "TOPLEFT", columnX + (column.leftInset or (column.key == "name" and 7 or 0)), -1)
        cell:SetWidth(math.max(1, width - (column.leftInset or 0) - (column.rightInset or (column.key == "name" and 14 or 6))))
        cell:Show()
        columnX = columnX + width + (column.gapAfter or 0)
    end
end

local rosterColumnSettings = { class = "Class", level = "Level", zone = "Zone", rank = "Rank", notes = "PublicNote", officer = "OfficerNote", lastOnline = "LastOnline" }
function RosterManagement.GetVisibleColumns(page, settings)
    local visible = page.visibleColumns or {}; page.visibleColumns = visible
    local count, total = 0, 0
    local group, index
    for group = 1, 2 do
        local source = group == 1 and page.guildColumns or page.playerColumns
        for index = 1, table.getn(source) do
            local column = source[index]
            if ((page.statusMode and group == 2) or (not page.statusMode and group == 1)) and (column.key == "name" or settings["rosterShow" .. rosterColumnSettings[column.key]] ~= false) and (column.key ~= "officer" or MOS.Services.Roster.CanManage("viewOfficerNote")) then
                count = count + 1
                local target = visible[count]
                if not target then target = {}; table.insert(visible, target) end
                target.key = column.key; target.header = column.header; target.fraction = column.fraction
                total = total + column.fraction
            end
        end
    end
    for index = table.getn(visible), count + 1, -1 do table.remove(visible, index) end
    for index = 1, count do visible[index].fraction = visible[index].fraction / total end
    return visible
end

function RosterManagement.LayoutColumns(page, rows, columns, tableWidth, headerY)
    HideColumns(rows, page.guildColumns)
    HideColumns(rows, page.playerColumns)
    local columnX = 0
    local columnIndex
    for columnIndex = 1, table.getn(columns) do
        local column = columns[columnIndex]
        local width = column.width or math.floor(tableWidth * column.fraction)
        column.header:ClearAllPoints()
        column.header:SetPoint("TOPLEFT", page.tablePanel or page, "TOPLEFT", 6 + columnX, headerY)
        column.header:SetWidth(math.max(1, width - (column.rightInset or 6)))
        if BootyGuildDB.rosterShowColumnHeaders ~= false then column.header:Show() end
        local rowIndex
        for rowIndex = 1, table.getn(rows) do
            local cell = rows[rowIndex][column.key]
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", rows[rowIndex], "TOPLEFT", columnX + (column.leftInset or (column.key == "name" and 7 or 0)), -1)
            cell:SetWidth(math.max(1, width - (column.leftInset or 0) - (column.rightInset or (column.key == "name" and 14 or 6))))
            cell:Show()
        end
        columnX = columnX + width + (column.gapAfter or 0)
    end
end

local function SetRowTextColor(row, shade, color)
    local r, g, b = color[1] * shade, color[2] * shade, color[3] * shade
    row.officer:SetTextColor(r, g, b)
    row.name:SetTextColor(r, g, b)
    row.level:SetTextColor(r, g, b)
    row.class:SetTextColor(r, g, b)
    row.rank:SetTextColor(r, g, b)
    row.notes:SetTextColor(r, g, b)
    row.zone:SetTextColor(r, g, b)
    row.lastOnline:SetTextColor(r, g, b)
end

local defaultBackground = {0.025, 0.025, 0.025}
local defaultText = {1, 1, 1}
local defaultHover = {0.13, 0.13, 0.13}

function RosterManagement.ApplyMemberColors(row, visibleIndex)
    local settings = BootyGuildDB or {}
    local background = settings.rosterBackgroundColor or defaultBackground
    local hover = settings.rosterHoverColor or defaultHover
    MOS.UI.Components.SetAlternatingRowColor(row, background, visibleIndex, settings.rosterOddLightness)
    row.hover:SetTexture(hover[1], hover[2], hover[3], 1)
    row.selection:SetTexture(hover[1], hover[2], hover[3], 1)
end

function RosterManagement.BindRow(row, member, visibleIndex, selectedName, rowHeight, lowestRankIndex, useClassColors)
    row.name:SetText(member.name or "")
    row.level:SetText(member.level or "")
    row.class:SetText(member.class or "")
    row.rank:SetText(MOS.Services.RankPolicy.GetDisplayName(member.rank or ""))
    row.notes:SetText(member.publicNote or "")
    row.officer:SetText(MOS.Services.Roster.CanManage("viewOfficerNote") and (member.officerNote or "") or "")
    row.zone:SetText(member.zone or "")
    row.lastOnline:SetText(RosterManagement.FormatLastOnline(member))
    row.hover:Hide()
    row.displayedMember = member
    row.visibleIndex = visibleIndex
    local shade = member.online and 1 or 0.48
    SetRowTextColor(row, shade, BootyGuildDB.rosterTextColor or defaultText)
    RosterManagement.ApplyMemberColors(row, visibleIndex)
    if useClassColors then
        local classKey = string.upper(member.classFile or member.class or "")
        local classColor = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]) or MOS.UI.Components.Theme.classColors[classKey]
        if classColor then
            row.name:SetTextColor(classColor.r * shade, classColor.g * shade, classColor.b * shade)
            row.class:SetTextColor(classColor.r * shade, classColor.g * shade, classColor.b * shade)
        end
    end
    row.expanded = member.name == selectedName and BootyGuildDB.playerDetailsStyle ~= "window"
    if row.expanded then
        row.selection:Show()
        row:SetBackdropBorderColor(0, 0, 0, 0)
        row.actionPanel:Show()
        local expandedHeight = math.min(rowHeight + 208, row.availableHeight or (rowHeight + 208))
        row.actionViewport:SetHeight(math.max(1, expandedHeight - rowHeight - 4))
        local detailWidth = row.detailWidth or math.max(1, math.min(640, row:GetWidth() - 8))
        row.actionViewport:SetWidth(detailWidth); row.actionPanel:SetWidth(detailWidth)
        if row.actionViewport.memberName ~= member.name then row.actionViewport:SetVerticalScroll(0) end
        row.actionViewport.memberName = member.name
        row.actionViewport:Show()
        row:SetHeight(expandedHeight)
        RosterManagement.BindMemberDetails(row, member)
        row:Show()
        MOS.UI.Components.RefreshClippedContent(row.actionViewport)
        return expandedHeight
    end
    if member.name == selectedName then row.selection:Show() else row.selection:Hide() end
    row:SetBackdropBorderColor(0, 0, 0, 0)
    row.actionPanel:Hide(); row.actionViewport:Hide()
    row:SetHeight(rowHeight)
    row:Show()
    return rowHeight
end

function RosterManagement.HideRow(row)
    row.displayedMember = nil
    row.expanded = false
    row.selection:Hide()
    row:SetBackdropColor(0, 0, 0, 0)
    row:SetBackdropBorderColor(0, 0, 0, 0)
    row.actionPanel:Hide()
    row:Hide()
end

local function OnListScroll()
    if this.listController and this.listController.rendering then return end
    FauxScrollFrame_OnVerticalScroll(this.rowHeight, this.refreshCallback)
end

function RosterManagement.CreateListController(page, rowHeight, rowController)
    local controller = {
        page = page,
        rows = {},
        rowCount = 0,
        rowHeight = rowHeight,
        rowController = rowController,
    }
    controller.scrollFrame = MOS.UI.Components.CreateScrollFrame("BootyGuildRosterScrollFrame", page.tablePanel or page, "FauxScrollFrameTemplate")
    controller.scrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", -4, -145)
    controller.scrollFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -6, 18)
    controller.scrollFrame.rowHeight = rowHeight
    controller.scrollFrame.listController = controller
    controller.scrollFrame:SetScript("OnVerticalScroll", OnListScroll)
    MOS.UI.Components.RegisterSkinnedScrollBar(getglobal("BootyGuildRosterScrollFrameScrollBar"))
    page.listController = controller
    return controller
end

function RosterManagement.SetListRefreshCallback(controller, refreshCallback)
    controller.scrollFrame.refreshCallback = refreshCallback
end

function RosterManagement.EnsureRowPool(controller, requiredCount, columns, tableWidth)
    while controller.rowCount < requiredCount do
        controller.rowCount = controller.rowCount + 1
        local row = RosterManagement.CreateRow(controller.page.tablePanel or controller.page, controller.rowCount, controller.rowHeight, controller.rowController)
        controller.rows[controller.rowCount] = row
        row.name:Hide(); row.zone:Hide(); row.level:Hide(); row.class:Hide()
        row.rank:Hide(); row.notes:Hide(); row.officer:Hide(); row.lastOnline:Hide()
        RosterManagement.ApplyRowColumns(row, columns, tableWidth)
    end
end

local function OnModeToggle()
    local page = this.rosterPage
    page.statusMode = not page.statusMode
    this.label:SetText(page.statusMode and "Show Guild Status" or "Show Player Status")
    this.modeChangedCallback()
end

function RosterManagement.AttachModeToggle(page, button, modeChangedCallback)
    page.statusMode = false
    button.rosterPage = page
    button.modeChangedCallback = modeChangedCallback
    button:SetScript("OnClick", OnModeToggle)
end

function RosterManagement.CreateVisibilityController(options)
    local controller = options
    options.page.visibilityController = controller
    return controller
end

function RosterManagement.SetDataVisible(controller, visible)
    local method = visible and "Show" or "Hide"
    local page = controller.page
    if not visible and page.detailsWindow then page.detailsWindow.displayedMember = nil; page.detailsWindow:Hide() end
    local controls = controller.controls
    page.fittedPanel:Hide()
    if page.tablePanel then page.tablePanel[method](page.tablePanel); page.actionsPanel[method](page.actionsPanel) end
    controls.footer.rule:Hide()
    controls.filtersLabel[method](controls.filtersLabel)
    controls.searchLabel[method](controls.searchLabel)
    controls.searchBox[method](controls.searchBox)
    controls.classFilter[method](controls.classFilter)
    controls.rankFilter[method](controls.rankFilter)
    controls.showOffline[method](controls.showOffline)
    controls.showOffline.label[method](controls.showOffline.label)
    controls.modeButton[method](controls.modeButton)
    page.listHeaderUI.notes[method](page.listHeaderUI.notes)
    page.listController.scrollFrame[method](page.listController.scrollFrame)
    controller.sortHint:Hide()
    controller.refreshButton[method](controller.refreshButton)
    if BootyGuildDB and BootyGuildDB.rosterLiveTrackingEnabled then controller.refreshButton:Hide() end
    controller.infoButton[method](controller.infoButton)
    controller.addButton[method](controller.addButton)
    controller.controlButton[method](controller.controlButton)
    if not MOS.Services.Roster.CanManage("invite") then controller.addButton:Hide()
    else MOS.UI.Components.SetButtonEnabled(controller.addButton, true) end
    if not MOS.Services.Roster.CanManage("control") then controller.controlButton:Hide() end
    controls.footer[method](controls.footer)
    local i
    for i = 1, table.getn(page.listHeaderUI.buttons) do
        local header = page.listHeaderUI.buttons[i]
        header[method](header)
    end
    if not visible then
        page.listHeaderUI.zone:Hide()
        page.listHeaderUI.lastOnline:Hide()
        page.officerHeader:Hide()
        -- Export belongs to Guild Statistics.
        page.filterController:Hide()
        for i = 1, table.getn(page.listController.rows) do page.listController.rows[i]:Hide() end
    end
end

function RosterManagement.RenderList(page, visibleMembers, columns, selectedName, lowestRankIndex, useClassColors, resetScroll, headerY)
    local controller = page.listController
    if controller.rendering then return end
    controller.rendering = true
    local rows = controller.rows
    local rowHeight = controller.rowHeight
    local body = page.tablePanel or page
    local panelWidth = RosterSpan(page)
    page.rowsHeaderY = headerY
    local rowsTop = headerY - (BootyGuildDB.rosterShowColumnHeaders == false and 2 or 24)
    local bottom = 34 + (page.summaryWrap and 22 or 0)
    local panelHeight = page.tablePanelHeight or 0
    if page.tablePanel and page.tablePanel.GetTop and page.tablePanel.GetBottom then
        local top, bottomEdge = page.tablePanel:GetTop(), page.tablePanel:GetBottom()
        if top and bottomEdge and top > bottomEdge then panelHeight = top - bottomEdge end
    end
    local availableHeight = page.tablePanel and math.max(0, panelHeight + rowsTop - bottom) or math.max(0, page.tableViewport:GetHeight())
    local visibleRowCount = RosterManagement.CalculateVisibleRows(availableHeight, rowHeight, selectedName ~= nil and BootyGuildDB.playerDetailsStyle ~= "window")
    local needsScroll = table.getn(visibleMembers) > visibleRowCount
    local rightInset = needsScroll and 24 or 6
    controller.viewportRightInset = rightInset
    local tableWidth = math.max(1, panelWidth - 6 - rightInset)
    if page.viewportBody ~= body or page.viewportTop ~= rowsTop or page.viewportInset ~= rightInset then
        page.viewportBody = body; page.viewportTop = rowsTop; page.viewportInset = rightInset
        page.tableViewport:ClearAllPoints()
        page.tableViewport:SetPoint("TOPLEFT", body, "TOPLEFT", 6, rowsTop)
        page.tableViewport:SetPoint("TOPRIGHT", body, "TOPRIGHT", -rightInset, rowsTop)
    end
    -- Measure settled native edges, not a width captured before parent anchors resolve.
    if page.tableViewport.GetLeft and page.tableViewport.GetRight then
        local left, right = page.tableViewport:GetLeft(), page.tableViewport:GetRight()
        if left and right and right > left then tableWidth = right - left end
    end
    if resetScroll == true then
        controller.scrollFrame.offset = 0
        controller.scrollFrame:SetVerticalScroll(0)
    end
    RosterManagement.MeasureColumns(page, columns, visibleMembers, tableWidth)
    RosterManagement.LayoutColumns(page, rows, columns, tableWidth, headerY)
    RosterManagement.EnsureRowPool(controller, visibleRowCount, columns, tableWidth)
    controller.scrollFrame:ClearAllPoints()
    controller.scrollFrame:SetPoint("TOPLEFT", page.tableViewport, "TOPLEFT", 0, 0)
    controller.scrollFrame:SetPoint("TOPRIGHT", page.tableViewport, "TOPRIGHT", 0, 0)
    local scrollbar = getglobal("BootyGuildRosterScrollFrameScrollBar")
    if scrollbar then
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -6, rowsTop - 16)
        scrollbar:SetPoint("BOTTOMRIGHT", page.tableViewport, "BOTTOMRIGHT", rightInset - 6, 16)
    end
    if selectedName and (selectedName ~= controller.lastSelectedName or visibleRowCount ~= controller.lastVisibleRowCount or availableHeight ~= controller.lastViewportHeight or tableWidth ~= controller.lastTableWidth) then
        local memberIndex
        for memberIndex = 1, table.getn(visibleMembers) do
            if visibleMembers[memberIndex].name == selectedName then
                local current = controller.scrollFrame.offset or 0
                controller.scrollFrame.offset = math.max(0, math.min(current, memberIndex - 1))
                if memberIndex > controller.scrollFrame.offset + visibleRowCount then
                    controller.scrollFrame.offset = math.max(0, memberIndex - visibleRowCount)
                end
                break
            end
        end
    end
    controller.lastViewportHeight = availableHeight; controller.lastTableWidth = tableWidth
    controller.lastSelectedName = selectedName
    controller.lastVisibleRowCount = visibleRowCount
    local offset = MOS.UI.Components.UpdateScrollFrame(controller.scrollFrame, table.getn(visibleMembers), visibleRowCount, rowHeight)
    MOS.UI.Components.SetScrollBarVisible(scrollbar, needsScroll and availableHeight >= 48)
    page.measuredCapacity = visibleRowCount
    page.measuredOffset = offset
    page.measuredCount = table.getn(visibleMembers)
    page.measuredWidth = tableWidth
    page.measuredShown = 0
    local rowY = 0
    local i
    for i = 1, controller.rowCount do
        local member = visibleMembers[offset + i]
        local row = rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", page.tableViewport, "TOPLEFT", 0, rowY)
        row:SetPoint("TOPRIGHT", page.tableViewport, "TOPRIGHT", 0, rowY)
        row.detailWidth = math.max(1, math.min(640, tableWidth - 8))
        row.availableHeight = math.max(rowHeight, availableHeight + rowY)
        if member and i <= visibleRowCount and -rowY + rowHeight <= availableHeight then
            page.measuredShown = page.measuredShown + 1
            rowY = rowY - RosterManagement.BindRow(row, member, offset + i, selectedName, rowHeight, lowestRankIndex, useClassColors)
        else
            RosterManagement.HideRow(row)
        end
    end
    page.renderedRowsHeight = -rowY
    page.measuredHeight = page.tablePanel and -rowY or availableHeight
    if page.tablePanel then page.tableViewport:SetHeight(-rowY) end
    controller.scrollFrame:SetHeight(page.measuredHeight)
    controller.rendering = nil
end

function RosterManagement.UpdateSortHeaders(page, sortKey)
    local i
    for i = 1, table.getn(page.listHeaderUI.buttons) do
        local button = page.listHeaderUI.buttons[i]
        button.label:SetText(button.baseText)
        button.label:SetTextColor(1, 0.82, 0)
    end
end

local function OnDataScanClick()
    if this.inactive then return end
    this.dataController.startSharedScan("roster")
end

function RosterManagement.CreateDataController(options)
    local controller = options
    controller.ready = false
    controller.liveTracking = false
    options.page.dataController = controller
    options.scanButton.dataController = controller
    options.refreshButton.dataController = controller
    options.scanButton:SetScript("OnClick", OnDataScanClick)
    options.refreshButton:SetScript("OnClick", OnDataScanClick)
    return controller
end

function RosterManagement.MountControllers(page, options)
    local guildControls = options.guildControls
    RosterManagement.CreateVisibilityController({
        page = page,
        controls = page.layoutControls,
        contentPanel = options.contentPanel,
        contentShade = options.contentShade,
        sortHint = options.sortHint,
        refreshButton = guildControls.refreshButton,
        infoButton = page.guildInfoButton,
        addButton = page.guildAddButton,
        controlButton = page.guildControlButton,
        scanSaveButton = guildControls.exportButton,
    })
    return RosterManagement.CreateDataController({
        page = page,
        scanButton = guildControls.scanButton,
        refreshButton = guildControls.refreshButton,
        startSharedScan = options.startSharedScan,
        requestScan = options.requestScan,
        requestLiveScan = options.requestLiveScan,
        cancelLiveScan = options.cancelLiveScan,
        printMessage = options.printMessage,
        buildSnapshot = options.buildSnapshot,
        storeSnapshot = options.storeSnapshot,
        refresh = options.refresh,
    })
end

function RosterManagement.CreateRenderer(options)
    return options
end

local function IsRosterVisible(page)
    if page.IsVisible then return page:IsVisible() end
    return page:IsShown()
end

function RosterManagement.InvalidateView(renderer, resetScroll)
    renderer.viewInvalidated = true
    if resetScroll then renderer.resetScrollRequested = true end
end

function RosterManagement.RefreshView(renderer, data, guildName, resetScroll, sortKey, selectedMemberName)
    local page = renderer.page
    if not IsRosterVisible(page) then
        RosterManagement.InvalidateView(renderer, resetScroll)
        return false
    end
    resetScroll = resetScroll or renderer.resetScrollRequested
    renderer.viewInvalidated, renderer.resetScrollRequested = nil, nil
    RosterManagement.UpdateSectionHeader(page)
    if not RosterManagement.IsReady(page.dataController) then
        RosterManagement.SetDataVisible(page.visibilityController, false)
        renderer.scanButton:Show()
        renderer.statusText:Show(); renderer.summaryText:Show()
        renderer.statusText:SetText("")
        renderer.summaryText:SetText("")
        return
    end

    renderer.scanButton:Hide()
    RosterManagement.SetDataVisible(page.visibilityController, true)
    renderer.statusText:Hide(); renderer.summaryText:Hide()
    local onlineCount = 0
    local memberCount = data and data.members and table.getn(data.members) or 0
    if data and data.members then
        local memberIndex
        for memberIndex = 1, memberCount do
            if data.members[memberIndex].online then onlineCount = onlineCount + 1 end
        end
    end
    renderer.summaryText:SetWidth(0)
    renderer.summaryText:SetText("|cffffffff" .. memberCount .. "|r |cffffd100Guild Members|r  |  |cffffffff" .. onlineCount .. "|r |cffffd100Online|r")
    renderer.summaryText:Show()
    -- Captions must be current before their natural widths determine layout.
    page.filterController:Build(data)
    local rosterShift = RosterManagement.LayoutChrome(page, page.layoutControls, renderer.getMotd())
    local query = string.lower(renderer.searchBox:GetText() or "")
    query = string.gsub(query, "^%s*(.-)%s*$", "%1")
    if BootyGuildDB.rosterShowSearch == false then query = "" end

    RosterManagement.FilterMembers(renderer.visibleMembers, data, query, BootyGuildDB.rosterShowClassFilter ~= false and renderer.selectedClasses or nil, BootyGuildDB.rosterShowRankFilter ~= false and renderer.selectedRanks or nil, BootyGuildDB.showOfflineMembers)
    table.sort(renderer.visibleMembers, renderer.sortMembers)

    if not guildName then
        renderer.statusText:SetText("No guild found.")
    elseif not data then
        renderer.statusText:SetText(guildName .. " - no saved roster. Use Refresh Data to scan.")
    elseif query ~= "" or table.getn(renderer.visibleMembers) ~= memberCount then
        renderer.statusText:SetText(guildName .. " - showing " .. table.getn(renderer.visibleMembers) .. " of " .. memberCount .. " members")
    else
        renderer.statusText:SetText(guildName .. " - " .. memberCount .. " members")
    end

    page.showOfflineCheck:SetChecked(BootyGuildDB.showOfflineMembers and 1 or nil)
    page.summaryWrap = false
    local columns = RosterManagement.GetVisibleColumns(page, BootyGuildDB)
    local lowestRankIndex = renderer.getLowestRankIndex(data)
    RosterManagement.RenderList(page, renderer.visibleMembers, columns, selectedMemberName, lowestRankIndex, BootyGuildDB.rosterClassColors, resetScroll, rosterShift)
    if RosterManagement.UpdateDetailsWindow then
        local selected
        if BootyGuildDB.playerDetailsStyle == "window" then
            local index
            for index = 1, table.getn(renderer.visibleMembers) do
                if renderer.visibleMembers[index].name == selectedMemberName then selected = renderer.visibleMembers[index]; break end
            end
        end
        RosterManagement.UpdateDetailsWindow(page, selected)
    end
    RosterManagement.LayoutSummary(page, renderer.summaryText)
    RosterManagement.UpdateSortHeaders(page, sortKey)
end

function RosterManagement.LayoutSummary(page, summary)
    local panel = page.tablePanel or page
    local width = RosterSpan(page)
    page.summaryWrap = false
    local label = page.modeButton.label
    if not page.summaryFontSize then
        local font, size, flags = summary:GetFont(); page.summaryFont = font; page.summaryFontSize = size; page.summaryFontFlags = flags
        font, size, flags = label:GetFont(); page.statusFont = font; page.statusFontSize = size; page.statusFontFlags = flags
    end
    summary:SetFont(page.summaryFont, page.summaryFontSize, page.summaryFontFlags)
    label:SetFont(page.statusFont, page.statusFontSize, page.statusFontFlags)
    local textWidth = summary:GetStringWidth() + label:GetStringWidth()
    local scale = math.min(1, math.max(0.01, (width - page.modeButton:GetWidth() - 16) / math.max(1, textWidth)))
    summary:SetFont(page.summaryFont, math.max(8, page.summaryFontSize * scale), page.summaryFontFlags)
    label:SetFont(page.statusFont, math.max(8, page.statusFontSize * scale), page.statusFontFlags)
    summary:ClearAllPoints()
    summary:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 10 + (page.summaryWrap and 22 or 0))
    summary:SetHeight(14); summary:SetJustifyV("MIDDLE")
    summary:SetWidth(math.max(1, width - (page.summaryWrap and 12 or page.modeButton.label:GetStringWidth() + page.modeButton:GetWidth() + 16)))
    page.modeButton:ClearAllPoints()
    page.modeButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 6)
end

function RosterManagement.SetReady(controller, ready)
    controller.ready = ready and true or false
end

function RosterManagement.IsReady(controller)
    return controller.ready
end

function RosterManagement.SetRefreshPending(controller, pending)
    controller.refreshPending = pending and true or false
    controller.refreshButton:SetInactive(controller.refreshPending)
    if BootyGuildDB and BootyGuildDB.rosterLiveTrackingEnabled then controller.refreshButton:Hide() end
end

function RosterManagement.HandleGuildRosterUpdate(controller, scanCompleted, scanPending)
    if not controller.liveTracking then return false end
    if not BootyGuildDB.rosterLiveTrackingEnabled or not IsRosterVisible(controller.page) then
        RosterManagement.DeactivateDataController(controller)
        return false
    end
    if scanCompleted or scanPending or not controller.requestLiveScan then return false end
    if not controller.requestLiveScan() then return false end
    RosterManagement.SetRefreshPending(controller, true)
    return true
end

function RosterManagement.DeactivateDataController(controller)
    if controller.cancelLiveScan and controller.cancelLiveScan() then
        RosterManagement.SetRefreshPending(controller, false)
    end
    controller.liveTracking = false
    if controller.refreshButton then controller.refreshButton:SetInactive(controller.refreshPending) end
end

function RosterManagement.ActivateDataController(controller, scanAlreadyStarted)
    MOS.Database.Ensure()
    if not BootyGuildDB.rosterLiveTrackingEnabled then
        RosterManagement.DeactivateDataController(controller)
        return
    end
    controller.liveTracking = true
    if not scanAlreadyStarted then
        if controller.requestLiveScan then
            if controller.requestLiveScan() then RosterManagement.SetRefreshPending(controller, true) end
        elseif not controller.requestScan("quiet") then controller.liveTracking = false end
    end
    controller.refreshButton:SetInactive(controller.refreshPending)
    controller.refreshButton:Hide()
end

function RosterManagement.CreateLifecycle(page, dataController, refresh)
    RosterManagement.RefreshLayout = function() if page:IsVisible() then refresh(false) end end
    RosterManagement.TrackingChanged = function()
        if page:IsVisible() then RosterManagement.ActivateDataController(dataController, dataController.refreshPending)
        else RosterManagement.DeactivateDataController(dataController) end
        if BootyGuildDB.rosterLiveTrackingEnabled then dataController.refreshButton:Hide() end
        RosterManagement.RefreshLayout()
    end
    return {
        Hide = function(self)
            RosterManagement.DeactivateDataController(dataController)
            page.filterController:Hide()
            page:Hide()
        end,
        Show = function(self)
            page:Show()
            refresh(false)
            local scanStarted = dataController.startSharedScan("roster")
            RosterManagement.ActivateDataController(dataController, scanStarted)
        end,
        Refresh = function(self) refresh(false) end,
        OnResize = function(self) refresh(false) end,
    }
end

function RosterManagement.AttachInteractions(options)
    local page = options.page
    options.exportButton:SetScript("OnClick", function() options.requestScan("reload") end)
    page.showOfflineCheck:SetScript("OnClick", function()
        options.ensureDatabase()
        MOS.Database.SetSetting("showOfflineMembers", this:GetChecked() and true or false)
        options.clearSelection()
        options.refresh(true)
    end)
    RosterManagement.AttachModeToggle(page, page.modeButton, function()
        options.clearSelection()
        options.refresh(false)
    end)
    options.searchBox:SetScript("OnTextChanged", function() options.refresh(true) end)
    MOS.UI.Components.AttachPlaceholder(options.searchBox,"Search...")
    RosterManagement.SetListRefreshCallback(options.listController, options.refresh)

    page.layoutElapsed = 0; page.layoutWidth = 0; page.layoutHeight = 0
    page.tableViewport:SetScript("OnSizeChanged", function()
        if page:IsVisible() and (math.abs(this:GetHeight() - (page.measuredHeight or 0)) > 0.5 or math.abs(this:GetWidth() - (page.measuredWidth or 0)) > 0.5) then
            page.viewportChanged = true
            page:SetScript("OnUpdate", page.finishLayout)
        end
    end)
    local function QueueSectionLayout()
        if page:IsVisible() then
            page.viewportChanged = true
            page:SetScript("OnUpdate", page.finishLayout)
        end
    end
    page:SetScript("OnSizeChanged", QueueSectionLayout)
    page:SetScript("OnShow", QueueSectionLayout)
    page.tablePanel:SetScript("OnSizeChanged", QueueSectionLayout)
    page.actionsPanel:SetScript("OnSizeChanged", QueueSectionLayout)
    page.footer:SetScript("OnSizeChanged", QueueSectionLayout)
    page.finishLayout = function()
        this:SetScript("OnUpdate", nil)
        if not IsRosterVisible(this) then return end
        local currentWidth, currentHeight = this:GetWidth(), this:GetHeight()
        if RosterManagement.NeedsLayout(currentWidth, currentHeight, this.layoutWidth, this.layoutHeight, this.viewportChanged) then
            this.viewportChanged = nil
            this.layoutWidth = currentWidth; this.layoutHeight = currentHeight
            options.refresh(false)
        end
    end
    page:SetScript("OnHide", function()
        this:SetScript("OnUpdate", nil); this.fittedPanel:Hide()
        if this.dataController then RosterManagement.DeactivateDataController(this.dataController) end
        if this.memberMenu then this.memberMenu:Hide() end
        if this.memberReport then this.memberReport:Hide() end
        if this.noteEditor then this.noteEditor:Hide() end
    end)
end

local function PlaceRosterFilter(page, control, visible, controlWidth, x, y)
    if not visible then control:Hide(); return x end
    control:Show(); control:ClearAllPoints(); control:SetPoint("TOPLEFT", page.filterToolbar or page.tablePanel or page, "TOPLEFT", x, y)
    if controlWidth then control:SetWidth(controlWidth) end
    return x + (controlWidth or control:GetWidth()) + 8
end

local function RosterCaptionWidth(page, control, padding, minimum)
    local label = control.label or control
    local caption = control:GetText() or ""
    local font, size, flags = label:GetFont()
    if control.mosRosterCaption == caption and control.mosRosterFont == font
        and control.mosRosterSize == size and control.mosRosterFlags == flags then
        return control.mosRosterWidth
    end
    local measure = page.rosterFilterMeasure
    if not measure then
        measure = MOS.UI.Components.CreateLabel(page, nil, "OVERLAY", "GameFontHighlightSmall")
        measure:SetWidth(0); measure:Hide(); page.rosterFilterMeasure = measure
    end
    measure:SetFont(font, size, flags); measure:SetText(caption)
    local width = math.max(minimum, math.ceil(measure:GetStringWidth()) + padding)
    control.mosRosterCaption, control.mosRosterFont = caption, font
    control.mosRosterSize, control.mosRosterFlags, control.mosRosterWidth = size, flags, width
    return width
end

function RosterManagement.UpdateSectionHeader(page)
    local shift = BootyGuildDB.rosterHideSectionHeader and 42 or 0
    if page.sectionTitle then if shift > 0 then page.sectionTitle:Hide() else page.sectionTitle:Show() end end
    return shift
end

function RosterManagement.LayoutChrome(page, controls, motdText)
    local getPresentation = page.host and page.host.GetPresentationSetting
    local menuStyle = getPresentation and getPresentation("menuStyle") or "buttons"
    local tabs = menuStyle == "tabs" or menuStyle == "bottomTabs"
    local leftOutset = 1.5 + (tabs and (MOS.UI.Components.IsClassicSkin() and 0 or 5) or 0)
    if page.tablePanel then MOS.UI.Components.JoinSurfaceEdges(page.tablePanel, true, true, leftOutset, 1.5) end
    if page.actionsPanel then MOS.UI.Components.JoinSurfaceEdges(page.actionsPanel, true, false, leftOutset, 1.5) end
    local actionBottom = getPresentation and getPresentation("hideStatusVersionBar") and 3.5 or 6
    if page.actionsPanel then page.actionsPanel:SetHeight(28 + actionBottom) end
    local width, height = RosterSpan(page)
    local headerShift = RosterManagement.UpdateSectionHeader(page)
    controls.footer.guild:SetText("Guild Message Of The Day:")
    controls.footer.guild:SetPoint("TOPRIGHT", controls.footer, "TOPRIGHT", -8, -4)
    controls.footer.guild:SetJustifyH("LEFT")
    controls.footer.guild:SetHeight(0)
    controls.footer.motd:ClearAllPoints()
    controls.footer.motd:SetPoint("TOPLEFT", controls.footer.guild, "BOTTOMLEFT", 0, -6)
    controls.footer.motd:SetWidth(math.max(1, width - 16))
    if controls.footer.motd.SetWordWrap then controls.footer.motd:SetWordWrap(true) end
    if controls.footer.motd.SetNonSpaceWrap then controls.footer.motd:SetNonSpaceWrap(true) end
    controls.footer.motd:SetHeight(0)
    controls.footer.motd:SetText(motdText or "Guild Message of the Day")
    if controls.footer.layoutHeaderShift ~= headerShift then
        controls.footer.layoutHeaderShift = headerShift
        controls.footer:ClearAllPoints()
        controls.footer:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -42 + headerShift)
        controls.footer:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -42 + headerShift)
    end
    controls.footer:SetHeight(17 + MOS.UI.Components.MeasureTextHeight(controls.footer.guild, math.max(1, width - 16)) + MOS.UI.Components.MeasureTextHeight(controls.footer.motd, math.max(1, width - 16), true))

    if controls.footer.rule then controls.footer.rule:Hide() end
    if page.tablePanel then
        local top = 42 - headerShift + controls.footer:GetHeight()
        if not page.sectionsAnchored then
            page.sectionsAnchored = true
            page.tablePanel:ClearAllPoints()
            page.tablePanel:SetPoint("TOPLEFT", controls.footer, "BOTTOMLEFT", 0, 0)
            page.tablePanel:SetPoint("BOTTOMRIGHT", page.actionsPanel, "TOPRIGHT", 0, 0)
        end
        page.tablePanelHeight = math.max(0, height - top - page.actionsPanel:GetHeight())
    end
    width = math.max(1, width)
    local settings = BootyGuildDB or {}
    local x, y = 6, -8
    local hasFilters = settings.rosterShowClassFilter ~= false or settings.rosterShowRankFilter ~= false
    local available = math.max(1, width - 12)
    local flow = page.rosterFilterFlow
    if not flow then flow = {}; page.rosterFilterFlow = flow end
    for index = table.getn(flow), 1, -1 do table.remove(flow, index) end
    controls.filtersLabel:Hide()
    controls.classFilter:SetHeight(24); controls.rankFilter:SetHeight(24)
    if settings.rosterShowClassFilter ~= false then
        controls.classFilter.mosFlowWidth = RosterCaptionWidth(page, controls.classFilter, 30, 84)
        controls.classFilter:Show(); table.insert(flow, controls.classFilter)
    else controls.classFilter:Hide() end
    if settings.rosterShowRankFilter ~= false then
        controls.rankFilter.mosFlowWidth = RosterCaptionWidth(page, controls.rankFilter, 30, 84)
        controls.rankFilter:Show(); table.insert(flow, controls.rankFilter)
    else controls.rankFilter:Hide() end
    local filterBottom = MOS.UI.Components.LayoutFlow(page.filterToolbar or page.tablePanel or page, flow, 6, 8, available, 8)
    if table.getn(flow) > 0 then
        local last = flow[table.getn(flow)]
        local _, _, _, lastX, lastY = last:GetPoint(1)
        x, y = lastX + math.min(available, last.mosFlowWidth) + 8, lastY
        MOS.UI.Components.ReflowControlText(controls.classFilter); MOS.UI.Components.ReflowControlText(controls.rankFilter)
    end
    local offlineLabelWidth = settings.rosterShowOffline ~= false and RosterCaptionWidth(page, controls.showOffline.label, 2, 70) or 0
    local offlineWidth = settings.rosterShowOffline ~= false and offlineLabelWidth + 26 or 0
    local searchShown, offlineShown = settings.rosterShowSearch ~= false, settings.rosterShowOffline ~= false
    local groupMinimum = (searchShown and 40 or 0) + (searchShown and offlineShown and 8 or 0) + offlineWidth
    if hasFilters and groupMinimum > width - 6 - x then x, y = 6, -filterBottom - 4 end
    controls.searchLabel:Hide()
    local searchAvailable = math.max(1, width - 6 - x - offlineWidth - (offlineShown and 8 or 0))
    x = PlaceRosterFilter(page, controls.searchBox, searchShown, math.min(218, searchAvailable), x, y)
    offlineLabelWidth = math.min(offlineLabelWidth, math.max(1, width - 6 - x - 26))
    x = PlaceRosterFilter(page, controls.showOffline.label, offlineShown, offlineLabelWidth, x, y)
    if offlineShown then x = x - 6 end
    x = PlaceRosterFilter(page, controls.showOffline, offlineShown, 24, x, y)
    controls.classFilter:SetHeight(24); controls.rankFilter:SetHeight(24); controls.searchBox:SetHeight(24); controls.showOffline:SetWidth(24); controls.showOffline:SetHeight(24)
    controls.showOffline.label:SetTextColor(1, 1, 1)
    controls.showOffline.label:SetHeight(24); controls.showOffline.label:SetJustifyV("MIDDLE")
    if page.filterController and ((settings.rosterShowClassFilter == false and page.filterController.classPanel:IsVisible()) or (settings.rosterShowRankFilter == false and page.filterController.rankPanel:IsVisible())) then page.filterController:Hide() end
    controls.modeButton.label:ClearAllPoints()
    controls.modeButton.label:SetPoint("RIGHT", controls.modeButton, "LEFT", -4, 0)

    controls.modeButton:Show(); controls.modeButton.label:Show()
    local actionCount = table.getn(controls.actions)
    local baseWidth, visibleCount = 0, 0
    local actionIndex
    for actionIndex = 1, actionCount do
        local action = controls.actions[actionIndex]
        action.available = not action.permission or MOS.Services.Roster.CanManage(action.permission)
        if action.available then baseWidth = baseWidth + action.width; visibleCount = visibleCount + 1 end
    end
    baseWidth = math.max(1, baseWidth + math.max(0, visibleCount - 1) * 6)
    local availableWidth = math.max(1, width - 12 - 28)
    local widthScale = math.min(1, math.max(0.01, (availableWidth - math.max(0, visibleCount - 1) * 6) / math.max(1, baseWidth - math.max(0, visibleCount - 1) * 6)))
    local actionX = 6
    for actionIndex = 1, actionCount do
        local action = controls.actions[actionIndex]
        if action.available then
            if action.permission then MOS.UI.Components.SetButtonEnabled(action.button, true) end
            action.button:Show()
            action.button:ClearAllPoints()
            action.button:SetScale(1)
            action.button:SetWidth(math.floor(action.width * widthScale))
            action.button:SetHeight(22)
            MOS.UI.Components.FitButtonLabel(action.button, action.button:GetWidth() - 16)
            action.button:SetPoint("BOTTOMLEFT", page.actionsPanel or page, "BOTTOMLEFT", actionX, actionBottom)
            actionX = actionX + math.floor(action.width * widthScale) + 6
        else action.button:Hide() end
    end
    if BootyGuildDB.rosterLiveTrackingEnabled then controls.refreshButton:Hide() else controls.refreshButton:Show() end
    controls.refreshButton:ClearAllPoints()
    controls.refreshButton:SetWidth(22); controls.refreshButton:SetHeight(22)
    controls.refreshButton:SetPoint("BOTTOMLEFT", page.actionsPanel or page, "BOTTOMLEFT", actionX, actionBottom)
    local hasFilterRow = hasFilters or settings.rosterShowSearch ~= false or settings.rosterShowOffline ~= false
    if page.filterToolbar then
        if hasFilterRow then
            page.filterToolbar:SetHeight(-y + 28); page.filterToolbar:Show()
        else page.filterToolbar:Hide() end
    end
    RosterManagement.LayoutSummary(page, controls.status)
    return y - (hasFilterRow and 28 or 0)
end

function RosterManagement.CreateMemberDetails(row)
    local C, panel = MOS.UI.Components, row.actionPanel
    row.details = {}
    local function Text(key, y, color, small)
        local label = small and C.CreateColumnLabel(panel, "", color) or C.CreateComponentLabel(panel, "", color)
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
        label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, y); label:SetJustifyH("LEFT")
        row.details[key] = label
        return label
    end
    Text("name", -10, "orange")
    Text("level", -29, "white", true)
    Text("rank", -47, "orange")
    Text("lastOnline", -67, "orange")
    local function Note(key, title)
        local field = C.CreateNoteDisplay(panel, 82)
        field.title = C.CreateComponentLabel(panel, title, "orange")
        field.title:SetPoint("BOTTOMLEFT", field, "TOPLEFT", 0, 6)
        field:SetScript("OnClick", function() RosterManagement.OpenNoteEditor(row, key) end)
        row[key .. "Field"] = field
    end
    Note("publicNote", "Public Note:")
    Note("officerNote", "Officer's Note:")
end

function RosterManagement.OpenNoteEditor(row, key)
    local page, C, service = row.controller.page or row:GetParent(), MOS.UI.Components, MOS.Services.Roster
    local member = row.displayedMember
    if not member or not service.CanManage(key) then return end
    if not page.noteEditor then
        page.noteEditor = C.CreateTextEditor("BootyGuildRosterNoteEditor", "", 31, function(value)
            local target = page.noteTarget
            if not target or not service.PerformMemberAction(target.key, target.name, value) then
                page.noteEditor:SetMessage("You cannot edit this note.", true); return false
            end
            target.member[target.key] = value
            if target.row.displayedMember == target.member then
                RosterManagement.BindMemberDetails(target.row, target.member)
                target.row.notes:SetText(target.member.publicNote or "")
            end
            if target.row.controller.onAction then target.row.controller.onAction("refresh") end
            return true
        end)
        page.noteEditor.save:SetText("Accept")
    end
    page.noteTarget = { name = member.name, member = member, row = row, key = key }
    page.noteEditor.title:SetText(key == "publicNote" and "Set Player Note" or "Set Officer Note")
    page.noteEditor:Open(member[key] or ""); page.noteEditor:BringToFront(600)
end

function RosterManagement.BindMemberDetails(row, member)
    local C, service = MOS.UI.Components, MOS.Services.Roster
    if not row.details then RosterManagement.CreateMemberDetails(row) end
    local officerVisible = service.CanManage("viewOfficerNote")
    row.officer:SetText(officerVisible and (member.officerNote or "") or "")
    row.details.name:SetText(member.name or "")
    row.details.level:SetText("Level " .. tostring(member.level or 0) .. " " .. (member.class or ""))
    row.details.rank:SetText("Rank: |cffffffff" .. MOS.Services.RankPolicy.GetDisplayName(member.rank or "Unknown") .. "|r")
    row.details.lastOnline:SetText("Last online: " .. (member.online and "|cffffffffOnline|r" or "|cff808080" .. RosterManagement.FormatLastOnline(member) .. " ago|r"))
    local public, officer = row.publicNoteField, row.officerNoteField
    public:ClearAllPoints(); public:SetPoint("TOPLEFT", row.actionPanel, "TOPLEFT", 12, -110)
    public:SetPoint("TOPRIGHT", row.actionPanel, officerVisible and "TOP" or "TOPRIGHT", officerVisible and -6 or -12, -110)
    public:SetText(member.publicNote and member.publicNote ~= "" and member.publicNote or "Click to set a public note.")
    public:EnableMouse(service.CanManage("publicNote"))
    officer:ClearAllPoints(); officer:SetPoint("TOPLEFT", row.actionPanel, "TOP", 6, -110)
    officer:SetPoint("TOPRIGHT", row.actionPanel, "TOPRIGHT", -12, -110)
    if officerVisible then
        officer:Show(); officer.title:Show()
        officer:SetText(member.officerNote and member.officerNote ~= "" and member.officerNote or "Click to set an officer note.")
        officer:EnableMouse(service.CanManage("officerNote"))
    else officer:SetText(""); officer:Hide(); officer.title:Hide() end
    local arrowX = -12
    local _, action
    for _, action in ipairs({ "demote", "promote" }) do
        local button = row[action .. "Button"]
        if service.CanManage(action, member) then
            button:ClearAllPoints(); button:SetPoint("TOPRIGHT", row.actionPanel, "TOPRIGHT", arrowX, -10)
            button:Enable(); button:Show(); arrowX = arrowX - 24
        else button:Hide() end
    end
    row.details.name:ClearAllPoints()
    row.details.name:SetPoint("TOPLEFT", row.actionPanel, "TOPLEFT", 12, -10)
    row.details.name:SetPoint("TOPRIGHT", row.actionPanel, "TOPRIGHT", arrowX - 4, -10)
    if row.detailsWindow then RosterManagement.LayoutDetailsWindow(row, member) end
end

function RosterManagement.OpenMemberMenu(row)
    local page, C = row:GetParent(), MOS.UI.Components
    if not page.memberMenu then
        page.memberMenu = C.CreateContextMenu(page, {
            { "Whisper", "whisper" }, { "Invite", "group" }, { "Target", "target" },
            { "Report", "report" }, { "Ignore Player", "ignore" },
        }, function(action)
            local name = page.contextMemberName
            if action == "report" then
                if not page.memberReport then
                    page.memberReport = C.CreateTextEditor("BootyGuildRosterReport", "Report player", 1000, function(reason)
                        if MOS.Services.Roster.PerformSocialAction("report", page.reportMemberName, reason) then page.memberReport:Hide()
                        else page.memberReport:SetMessage("Enter a reason; reporting requires GM ticket support.", true); return false end
                    end)
                    page.memberReport.save:SetText("Submit")
                end
                page.reportMemberName = name
                page.memberReport:Open(""); page.memberReport:BringToFront(600); page.memberReport:SetMessage("Report " .. name .. ": describe the issue for a GM.", false)
            else MOS.Services.Roster.PerformSocialAction(action, name) end
        end)
    end
    page.memberMenu.title:SetText(row.displayedMember.name)
    page.contextMemberName = row.displayedMember.name
    page.memberMenu:Open(row)
end

function RosterManagement.BindPermissionEvents(page)
    local watcher = MOS.UI.Components.CreateContainer(nil, page)
    local function Refresh(force)
        if not IsRosterVisible(page) then return end
        local C, service = MOS.UI.Components, MOS.Services.Roster
        if service.ReadManagementState then
            local flags, rank, rankCount, playerName = service.ReadManagementState()
            if not force and watcher.managementFlags == flags and watcher.managementRank == rank
                and watcher.managementRankCount == rankCount and watcher.managementPlayer == playerName then return end
            watcher.managementFlags, watcher.managementRank = flags, rank
            watcher.managementRankCount, watcher.managementPlayer = rankCount, playerName
        end
        if service.CanManage("invite") then C.SetButtonEnabled(page.guildAddButton, true); page.guildAddButton:Show() else page.guildAddButton:Hide() end
        if service.CanManage("control") then page.guildControlButton:Show() else page.guildControlButton:Hide() end
        if page.layoutControls then RosterManagement.LayoutChrome(page, page.layoutControls, page.footer.motd:GetText()) end
        if page.noteTarget and not service.CanManage(page.noteTarget.key) and page.noteEditor then page.noteEditor:Hide(); page.noteTarget = nil end
        if page.detailsWindow and page.detailsWindow:IsVisible() and page.detailsWindow.displayedMember then
            RosterManagement.BindMemberDetails(page.detailsWindow, page.detailsWindow.displayedMember)
        end
        if page.listController then
            local _, row
            for _, row in ipairs(page.listController.rows) do
                if row.displayedMember and row.actionPanel:IsVisible() and row.details then RosterManagement.BindMemberDetails(row, row.displayedMember) end
            end
        end
    end
    watcher:SetScript("OnEvent", function() Refresh(false) end)
    watcher:SetScript("OnShow", function() watcher:RegisterEvent("GUILD_ROSTER_UPDATE"); watcher:RegisterEvent("PLAYER_GUILD_UPDATE"); Refresh(true) end)
    watcher:SetScript("OnHide", function() watcher:UnregisterEvent("GUILD_ROSTER_UPDATE"); watcher:UnregisterEvent("PLAYER_GUILD_UPDATE") end)
    page.permissionWatcher = watcher
end

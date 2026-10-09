local Booty = BootyGuild
local Roster = Booty.Modules.RosterManagement
local C = Booty.UI.Components

local function Place(window, label, y)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", window, "TOPLEFT", 12, y)
    label:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, y)
end

local function MatchSmallLabel(label, reference)
    local font, size, flags = reference:GetFont()
    label:SetFont(font, size, flags)
    label:SetJustifyH("LEFT")
end

local function MatchDetailValue(label, reference)
    local font, size, flags = reference:GetFont()
    label:SetFont(font, size + 2, flags)
    label:SetJustifyH("LEFT")
end

local function PlaceDetailValue(window, label, value, y, text)
    label:ClearAllPoints(); label:SetPoint("TOPLEFT", window, "TOPLEFT", 12, y); label:SetText(text)
    label:SetWidth(82); label:SetHeight(18); label:SetJustifyH("LEFT")
    if label.SetWordWrap then label:SetWordWrap(false) end
    value:ClearAllPoints(); value:SetPoint("LEFT", label, "RIGHT", 4, 0); value:SetPoint("RIGHT", window, "RIGHT", -12, 0); value:SetHeight(18); value:SetJustifyH("LEFT")
    if value.SetWordWrap then value:SetWordWrap(false) end
end

function Roster.LayoutDetailsWindow(window, member)
    window:SetWidth(224)
    Place(window, window.details.name, -12)
    window.details.name:SetPoint("TOPRIGHT", window, "TOPRIGHT", -34, -12)
    Place(window, window.details.level, -29)
    MatchSmallLabel(window.zoneLabel, window.details.level)
    MatchSmallLabel(window.details.rank, window.details.level)
    MatchSmallLabel(window.details.lastOnline, window.details.level)
    MatchDetailValue(window.zoneValue, window.details.level)
    MatchDetailValue(window.rankValue, window.details.level)
    MatchDetailValue(window.lastOnlineValue, window.details.level)
    PlaceDetailValue(window, window.zoneLabel, window.zoneValue, -48, "Zone:")
    window.zoneValue:SetText(member.zone or "Unknown")
    PlaceDetailValue(window, window.details.rank, window.rankValue, -66, "Rank:")
    window.rankValue:SetText(Booty.Services.RankPolicy.GetDisplayName(member.rank or "Unknown"))
    PlaceDetailValue(window, window.details.lastOnline, window.lastOnlineValue, -84, "Last online:")
    window.lastOnlineValue:SetText(member.online and "Online" or (Roster.FormatLastOnline(member) .. " ago"))
    if member.online then window.lastOnlineValue:SetTextColor(1,1,1) else window.lastOnlineValue:SetTextColor(0.5,0.5,0.5) end
    window.promoteButton:ClearAllPoints(); window.promoteButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -34, -62)
    window.demoteButton:ClearAllPoints(); window.demoteButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -10, -62)
    local canPromote = Booty.Services.Roster.CanManage("promote", member)
    local canDemote = Booty.Services.Roster.CanManage("demote", member)
    window.promoteButton:SetInactive(not canPromote); window.promoteButton:Show()
    window.demoteButton:SetInactive(not canDemote); window.demoteButton:Show()
    if canPromote then window.promoteButton:Enable() else window.promoteButton:Disable() end
    if canDemote then window.demoteButton:Enable() else window.demoteButton:Disable() end
    local public, officer = window.publicNoteField, window.officerNoteField
    public.title:SetText("Note:")
    MatchSmallLabel(public.title, window.details.level)
    MatchSmallLabel(officer.title, window.details.level)
    MatchSmallLabel(public.label, window.details.level); public.label:SetJustifyV("TOP")
    MatchSmallLabel(officer.label, window.details.level); officer.label:SetJustifyV("TOP")
    public:ClearAllPoints(); public:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -116)
    public:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -116); public:SetHeight(36)
    public.label:ClearAllPoints(); public.label:SetPoint("TOPLEFT", public, "TOPLEFT", 5, -5); public.label:SetPoint("BOTTOMRIGHT", public, "BOTTOMRIGHT", -5, 5)
    public.title:ClearAllPoints(); public.title:SetPoint("BOTTOMLEFT", public, "TOPLEFT", 0, 4)
    officer:ClearAllPoints(); officer:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -178)
    officer:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -178); officer:SetHeight(36)
    officer.label:ClearAllPoints(); officer.label:SetPoint("TOPLEFT", officer, "TOPLEFT", 5, -5); officer.label:SetPoint("BOTTOMRIGHT", officer, "BOTTOMRIGHT", -5, 5)
    officer.title:ClearAllPoints(); officer.title:SetPoint("BOTTOMLEFT", officer, "TOPLEFT", 0, 4)
    local canSeeOfficer = Booty.Services.Roster.CanManage("viewOfficerNote")
    window:SetHeight(canSeeOfficer and 258 or 196)
    window.removeButton:SetWidth(94); window.inviteButton:SetWidth(100)
    if Booty.Services.Roster.CanManage("remove", member) then window.removeButton:Enable() else window.removeButton:Disable() end
    if Booty.Services.Roster.CanManage("group", member) then window.inviteButton:Enable() else window.inviteButton:Disable() end
end

function Roster.UpdateDetailsWindow(page, member)
    if not member or BootyGuildDB.playerDetailsStyle ~= "window" then
        if page.detailsWindow then page.detailsWindow.displayedMember = nil; page.detailsWindow:Hide() end
        return
    end
    local window = page.detailsWindow
    if not window then
        window = C.Window.CreateAttached(page, page.detailsOwner or page:GetParent(), 224, 258, function()
            local selected = page.detailsWindow.displayedMember
            if selected then page.rowController.onSelect(selected) end
        end)
        page.detailsWindow = window
        window.detailsWindow = true; window.actionPanel = window; window.controller = page.rowController
        -- The shared note editor and permission binding use these reusable value labels.
        window.notes = C.CreateLabel(window, nil, "OVERLAY", "GameFontHighlightSmall"); window.notes:Hide()
        window.officer = C.CreateLabel(window, nil, "OVERLAY", "GameFontHighlightSmall"); window.officer:Hide()
        local function Action(button, action)
            button:SetScript("OnClick", function()
                if window.displayedMember then window.controller.onAction(action, window.displayedMember) end
            end)
        end
        window.promoteButton = C.CreateArrowButton(window, "up"); Action(window.promoteButton, "promote")
        window.demoteButton = C.CreateArrowButton(window, "down"); Action(window.demoteButton, "demote")
        window.removeButton = C.CreateButton(window, nil, "Remove", 112, 22)
        window.removeButton:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 12, 10); Action(window.removeButton, "remove")
        window.inviteButton = C.CreateButton(window, nil, "Group Invite", 118, 22)
        window.inviteButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 10); Action(window.inviteButton, "group")
        window.zoneLabel = C.CreateComponentLabel(window, "", "orange")
        window.zoneValue = C.CreateComponentLabel(window, "", "white")
        window.rankValue = C.CreateComponentLabel(window, "", "white")
        window.lastOnlineValue = C.CreateComponentLabel(window, "", "white")
        window:SetScript("OnHide", function()
            if page.noteTarget and page.noteTarget.row == window and page.noteEditor then page.noteEditor:Hide(); page.noteTarget = nil end
        end)
    end
    window.displayedMember = member
    Roster.BindMemberDetails(window, member)
    window:Show()
end

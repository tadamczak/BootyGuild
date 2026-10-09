local Booty = BootyGuild
local UI = Booty.UI.Components

Booty.Modules = Booty.Modules or {}
local GuildStatistics = {}
Booty.Modules.GuildStatistics = GuildStatistics

local function Lower(value) return string.lower(tostring(value or "")) end
local function SortNames(a,b) return Lower(a)<Lower(b) end
local guildGroupRowColor={0.13,0.10,0.03}
local guildStripeColor={1,1,1}
local whiteClassColor={r=1,g=1,b=1}
local RefreshPresentation
local function IsPresentationVisible(controller)
    local page=controller.page
    if page.IsVisible then return page:IsVisible() end
    return not page.IsShown or page:IsShown()
end
local function ClearMap(values)
    local key
    for key in pairs(values) do values[key] = nil end
end
local function AddUniqueMember(groups, groupName, memberName)
    local group=groups[groupName]
    if not group then group={};groups[groupName]=group end
    if group[memberName] then return 0 end
    group[memberName]=true
    return 1
end
local function DisplayRank(value)
    if value == nil or value == "" then return "Unknown" end
    return tostring(Booty.Services.RankPolicy.GetDisplayName(value))
end
local function DisplayClass(value) return value and value ~= "" and value or "Unknown" end
local function OnTableScroll() FauxScrollFrame_OnVerticalScroll(24, this.refreshCallback) end

local function ClearArray(values)
    local index
    -- Lua 5.0 remembers lengths written by insert/remove. Every cleared
    -- sequence below is refilled with insert, so remove keeps that length valid.
    for index = table.getn(values), 1, -1 do table.remove(values,index) end
end

local function ClassColor(className)
    local key = string.upper(tostring(className or ""))
    return (RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]) or UI.Theme.classColors[key] or whiteClassColor
end

local function CreateFilterGroup(parent, buttonText, width)
    local group = UI.CreateContainer(nil, parent); group:SetWidth(width); group:SetHeight(24); group.bootyFlowWidth = width
    group.button = UI.CreateDropdownButton(group, nil, buttonText, width); group.button:SetAllPoints(group); group.button:SetHeight(24)
    group.panel = UI.CreateDropdownPanel(parent, group.button, 150, 80, 50); UI.StyleProjectPopup(group.panel)
    group.button:SetScript("OnClick", function() if group.panel:IsVisible() then group.panel:Hide() else group.panel:Show() end end)
    return group
end

local function OnGuildRowClick()
    local row = this
    if not row.entry then return end
    local controller = row.tableController.controller
    if not IsPresentationVisible(controller) then return end
    if row.entry.kind == "group" then
        controller.expandedGroups[row.entry.value] = not controller.expandedGroups[row.entry.value]
    elseif row.entry.kind == "rawHeader" then
        controller.expandedRawSections[row.entry.rawKey] = not controller.expandedRawSections[row.entry.rawKey]
    else return end
    controller.projectionDirty = true
    RefreshPresentation(controller, false)
end

local function CreateMemberTable(page, refresh)
    local tableView = { rows = {}, headers = {}, entries = {}, memberScratch = {}, columns = {
        { key = "name", text = "Name", desiredWidth = 210, minimumWidth = 72, fraction = 0.36 },
        { key = "class", text = "Class", desiredWidth = 130, minimumWidth = 48, fraction = 0.22 },
        { key = "rank", text = "Rank", desiredWidth = 180, minimumWidth = 60, fraction = 0.31 },
        { key = "level", text = "Lvl", desiredWidth = 46, minimumWidth = 30, fraction = 0.11 },
    } }
    tableView.scroll = UI.CreateScrollFrame("BootyGuildGuildStatisticsScroll", page, "FauxScrollFrameTemplate")
    tableView.scroll.refreshCallback = refresh; tableView.scroll:SetScript("OnVerticalScroll", OnTableScroll)
    UI.RegisterSkinnedScrollBar(getglobal("BootyGuildGuildStatisticsScrollScrollBar"))
    local index
    for index = 1, table.getn(tableView.columns) do
        local column = tableView.columns[index]
        tableView.headers[index] = UI.Table.CreateHeader(page, tableView, column.text, 0, 0, column.desiredWidth, column.key, true)
    end
    for index = 1, 30 do
        local row = UI.CreateControl(nil, page); row:SetHeight(23)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }); row:SetBackdropColor(0, 0, 0, 0)
        UI.RegisterSkinnedSurface(row, "row", { bgFile = "Interface\\Buttons\\WHITE8X8" }, {0,0,0,0}, {0,0,0,0})
        row.name = UI.CreateLabel(row, nil, "OVERLAY", "GameFontHighlightSmall")
        row.class = UI.CreateLabel(row, nil, "OVERLAY", "GameFontHighlightSmall")
        row.rank = UI.CreateLabel(row, nil, "OVERLAY", "GameFontHighlightSmall")
        row.level = UI.CreateLabel(row, nil, "OVERLAY", "GameFontHighlightSmall")
        row.classIcon = UI.CreateClassIcon(row,16)
        row.hover = UI.AttachSubtleRowHover(row,0.07)
        UI.SetProjectButtonOutline(row, false)
        row.childBorder=UI.CreateProjectLeftAccent(row); row.tableController = tableView; row:SetScript("OnClick", OnGuildRowClick)
        row:Hide(); tableView.rows[index] = row
    end
    return tableView
end

local function MemberGroupValue(member, groupBy)
    if groupBy == "class" then return DisplayClass(member.class) end
    if groupBy == "rank" then return DisplayRank(member.rank) end
    if groupBy == "level" then return tostring(tonumber(member.level) or 0) end
    return ""
end

local function SortMembers(a, b)
    local aGroup, bGroup = a.group or "", b.group or ""
    if aGroup ~= bGroup then
        if a.groupNumber and b.groupNumber then return a.groupNumber < b.groupNumber end
        return Lower(aGroup) < Lower(bGroup)
    end
    if a.sortNumber ~= b.sortNumber then return a.sortAscending and a.sortNumber < b.sortNumber or (not a.sortAscending and a.sortNumber > b.sortNumber) end
    if a.sortText ~= b.sortText then return a.sortAscending and a.sortText < b.sortText or (not a.sortAscending and a.sortText > b.sortText) end
    local aName,bName=a.sortName,b.sortName
    if aName==bName then return false end
    return a.sortAscending and aName<bName or (not a.sortAscending and aName>bName)
end

local function UpdateWrappedMember(wrapped,member,group,groupNumber,controller)
    local number,text=0,""
    if controller.sortKey=="level" then number=tonumber(member.level) or 0
    elseif controller.sortKey=="rank" then number=tonumber(member.rankIndex) or 999;text=Lower(DisplayRank(member.rank))
    elseif controller.sortKey=="class" then text=Lower(DisplayClass(member.class))
    else text=Lower(member.name) end
    wrapped.kind="member";wrapped.member=member;wrapped.group=group;wrapped.groupNumber=groupNumber
    wrapped.sortNumber=number;wrapped.sortText=text;wrapped.sortAscending=controller.sortAscending;wrapped.sortName=Lower(member.name)
    return wrapped
end

local function ClearWrappedMembers(pool, first)
    local index
    for index=first,table.getn(pool) do
        local wrapped=pool[index]
        wrapped.member=nil;wrapped.group=nil;wrapped.groupNumber=nil;wrapped.sortText=nil;wrapped.sortName=nil
    end
end

local function ResetUniqueGroups(groups)
    local _,members
    for _,members in pairs(groups) do ClearMap(members) end
end

local function DropUnusedGroups(groups, counts)
    local name
    for name in pairs(groups) do if not counts[name] or counts[name]==0 then groups[name]=nil end end
end

local function SortRawRanks(a,b)
    if a.index==b.index then return a.sortName<b.sortName end
    return a.index>b.index
end
local function SortRawClasses(a,b) return a.sortName<b.sortName end
local rawSectionKeys={"rank","class","level"}
local rawSectionTitles={"Members by Rank","Members by Class","Members by Level"}
local rawLevelLabels={"1 - 30lvl","31 - 59lvl","60lvl"}

local function UpdateRawRow(rows, pool, index, name, count, rankIndex, className)
    local row=pool[index]
    if not row then row={};pool[index]=row end
    row.kind=className and "rawClass" or "raw";row.label=name;row.count=count;row.index=rankIndex
    row.className=className;row.countText="- "..count.." members";row.sortName=Lower(name)
    table.insert(rows,row)
end

local function ReleaseRawRows(model)
    local sectionIndex,rowIndex
    for sectionIndex=1,3 do
        local key=rawSectionKeys[sectionIndex]
        ClearArray(model.rawRows[key])
        local pool=model.rawPools[key]
        for rowIndex=1,table.getn(pool) do
            pool[rowIndex].label=nil;pool[rowIndex].className=nil;pool[rowIndex].countText=nil;pool[rowIndex].sortName=nil
        end
    end
end

local function ClearDerivedModel(controller)
    local model=controller.model
    ClearArray(model.fullEntries);ClearArray(controller.table.memberScratch);ClearArray(controller.table.entries);ClearWrappedMembers(model.wrapperPool,1)
    ClearArray(model.ranks);ClearArray(model.classes);ClearMap(model.rankSeen);ClearMap(model.classSeen)
    ClearMap(controller.rawRanks);ClearMap(controller.rawRankOrder);ClearMap(controller.rawClasses)
    ClearMap(controller.rawRankMembers);ClearMap(controller.rawClassMembers);ClearMap(controller.rawLevelMembers)
    controller.rawLevels[1]=0;controller.rawLevels[2]=0;controller.rawLevels[3]=0
    ReleaseRawRows(model)
    local index
    for index=1,table.getn(model.groupHeaders) do model.groupHeaders[index].value=nil;model.groupHeaders[index].count=0 end
    model.count=0;model.builtRaw=false;controller.projectionDirty=false
end

local function BuildRawEntries(controller)
    local model=controller.model
    local rankRows,classRows,levelRows=model.rawRows.rank,model.rawRows.class,model.rawRows.level
    ClearArray(rankRows);ClearArray(classRows);ClearArray(levelRows)
    local name,count
    local index=0
    for name,count in pairs(controller.rawRanks) do
        index=index+1;UpdateRawRow(rankRows,model.rawPools.rank,index,name,count,controller.rawRankOrder[name] or 999)
    end
    table.sort(rankRows,SortRawRanks)
    index=0
    for name,count in pairs(controller.rawClasses) do
        index=index+1;UpdateRawRow(classRows,model.rawPools.class,index,name,count,nil,name)
    end
    table.sort(classRows,SortRawClasses)
    index=0
    local band
    for band=1,3 do
        if controller.rawLevels[band]>0 then
            index=index+1;UpdateRawRow(levelRows,model.rawPools.level,index,rawLevelLabels[band],controller.rawLevels[band])
        end
    end
    local sectionIndex,rowIndex
    for sectionIndex=1,3 do
        local key=rawSectionKeys[sectionIndex]
        local rows=model.rawRows[key]
        local header=model.rawHeaders[sectionIndex]
        header.kind="rawHeader";header.value=rawSectionTitles[sectionIndex];header.rawKey=key;header.count=0
        table.insert(model.fullEntries,header)
        for rowIndex=1,table.getn(rows) do
            local row=rows[rowIndex]
            row.rawIndex=rowIndex;row.rawKey=key;header.count=header.count+row.count
            table.insert(model.fullEntries,row)
        end
        local pool=model.rawPools[key]
        for rowIndex=table.getn(rows)+1,table.getn(pool) do
            pool[rowIndex].label=nil;pool[rowIndex].className=nil;pool[rowIndex].countText=nil;pool[rowIndex].sortName=nil
        end
    end
end

local function BuildTableEntries(controller)
    local model,scratch=controller.model,controller.table.memberScratch
    table.sort(scratch,SortMembers)
    local previousGroup,groupEntry,groupIndex=nil,nil,0
    local index
    for index=1,table.getn(scratch) do
        local wrapped=scratch[index]
        if controller.groupBy~="none" and wrapped.group~=previousGroup then
            groupIndex=groupIndex+1;groupEntry=model.groupHeaders[groupIndex]
            if not groupEntry then groupEntry={kind="group"};model.groupHeaders[groupIndex]=groupEntry end
            groupEntry.value=wrapped.group;groupEntry.count=0
            table.insert(model.fullEntries,groupEntry);previousGroup=wrapped.group
        end
        if groupEntry then groupEntry.count=groupEntry.count+1 end
        wrapped.child=controller.groupBy~="none";wrapped.rowIndex=groupEntry and groupEntry.count or index
        table.insert(model.fullEntries,wrapped)
    end
    for index=groupIndex+1,table.getn(model.groupHeaders) do model.groupHeaders[index].value=nil;model.groupHeaders[index].count=0 end
end

local function BuildModel(controller, data)
    local model=controller.model
    ClearArray(controller.table.memberScratch);ClearArray(model.fullEntries)
    local ranks,classes,rankSeen,classSeen=model.ranks,model.classes,model.rankSeen,model.classSeen
    ClearArray(ranks);ClearArray(classes);ClearMap(rankSeen);ClearMap(classSeen)
    if controller.rawMode or model.builtRaw then
        ClearMap(controller.rawRanks);ClearMap(controller.rawRankOrder);ClearMap(controller.rawClasses)
        controller.rawLevels[1]=0;controller.rawLevels[2]=0;controller.rawLevels[3]=0
        ResetUniqueGroups(controller.rawRankMembers);ResetUniqueGroups(controller.rawClassMembers);ResetUniqueGroups(controller.rawLevelMembers)
    end
    local rankHasSelection,classHasSelection=false,false
    local selectedName
    for selectedName in pairs(controller.selectedRanks) do if controller.selectedRanks[selectedName] then rankHasSelection=true;break end end
    for selectedName in pairs(controller.selectedClasses) do if controller.selectedClasses[selectedName] then classHasSelection=true;break end end
    local query = Lower(controller.search:GetText())
    local level = tonumber(controller.level:GetText())
    local count,index=0,nil
    for index = 1, table.getn(data.members) do
        local member = data.members[index]
        local rank, className = DisplayRank(member.rank), DisplayClass(member.class)
        if not rankSeen[rank] then rankSeen[rank] = true; table.insert(ranks, rank) end
        if not classSeen[className] then classSeen[className] = true; table.insert(classes, className) end
        if controller.knownRanks[rank] == nil then controller.knownRanks[rank] = true; controller.selectedRanks[rank] = true end
        if controller.knownClasses[className] == nil then controller.knownClasses[className] = true; controller.selectedClasses[className] = true end
        local matchesQuery = query == "" or string.find(Lower(member.name), query, 1, true) or string.find(Lower(rank), query, 1, true) or string.find(Lower(className), query, 1, true)
        local rankMatches = not controller.rankGroup.panel.selectionTouched or not rankHasSelection or controller.selectedRanks[rank]
        local classMatches = not controller.classGroup.panel.selectionTouched or not classHasSelection or controller.selectedClasses[className]
        if rankMatches and classMatches and (not level or tonumber(member.level) == level) and matchesQuery then
            count=count+1
            if controller.rawMode then
                local memberKey=Lower(member.name)
                controller.rawRanks[rank]=(controller.rawRanks[rank] or 0)+AddUniqueMember(controller.rawRankMembers,rank,memberKey)
                controller.rawClasses[className]=(controller.rawClasses[className] or 0)+AddUniqueMember(controller.rawClassMembers,className,memberKey)
                controller.rawRankOrder[rank]=math.min(controller.rawRankOrder[rank] or 999,tonumber(member.rankIndex) or 999)
                local memberLevel=tonumber(member.level) or 0
                local levelBand=memberLevel<=30 and 1 or (memberLevel<60 and 2 or 3)
                controller.rawLevels[levelBand]=controller.rawLevels[levelBand]+AddUniqueMember(controller.rawLevelMembers,levelBand,memberKey)
            else
                local wrapped=model.wrapperPool[count]
                if not wrapped then wrapped={};model.wrapperPool[count]=wrapped end
                table.insert(controller.table.memberScratch,UpdateWrappedMember(wrapped,member,MemberGroupValue(member,controller.groupBy),controller.groupBy=="level" and tonumber(member.level) or nil,controller))
            end
        end
    end
    table.sort(ranks,SortNames);table.sort(classes,SortNames)
    UI.FilterPanel.Refresh(controller.rankGroup.panel, ranks, controller.selectedRanks, controller.filterChanged, true)
    UI.FilterPanel.Refresh(controller.classGroup.panel, classes, controller.selectedClasses, controller.filterChanged, true)
    ClearWrappedMembers(model.wrapperPool,controller.rawMode and 1 or count+1)
    DropUnusedGroups(controller.rawRankMembers,controller.rawRanks);DropUnusedGroups(controller.rawClassMembers,controller.rawClasses);DropUnusedGroups(controller.rawLevelMembers,controller.rawLevels)
    if controller.rawMode then
        BuildRawEntries(controller)
        for index=1,table.getn(model.groupHeaders) do model.groupHeaders[index].value=nil;model.groupHeaders[index].count=0 end
    else
        BuildTableEntries(controller)
        if model.builtRaw then ReleaseRawRows(model) end
    end
    model.builtRaw=controller.rawMode;model.count=count
    controller.modelDirty=false;controller.projectionDirty=true
end

local function ProjectEntries(controller)
    local entries,full=controller.table.entries,controller.model.fullEntries
    ClearArray(entries)
    local index
    for index=1,table.getn(full) do
        local entry=full[index]
        if entry.kind=="group" or entry.kind=="rawHeader"
            or (entry.kind=="member" and (not entry.child or controller.expandedGroups[entry.group]))
            or (entry.kind~="member" and controller.expandedRawSections[entry.rawKey]) then
            table.insert(entries,entry)
        end
    end
    controller.projectionDirty=false
end

if Booty.Diagnostics.Wrap then BuildModel=Booty.Diagnostics.Wrap("Guild Statistics model",BuildModel,2) end

local function LayoutTable(controller, rowWidth)
    UI.Table.AllocateColumnWidths(controller.table.columns, rowWidth)
    local x, index = 0, nil
    for index = 1, table.getn(controller.table.columns) do
        local column, header = controller.table.columns[index], controller.table.headers[index]
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", controller.page, "TOPLEFT", controller.tableRect.x + x, -controller.tableRect.y)
        header:SetWidth(column.width); header:SetHeight(20); x = x + column.width
    end
    UI.Table.FitHeaders(controller.table.headers, 12)
end

local function SetClassIcon(texture, className)
    local coordinates = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[string.upper(tostring(className or ""))]
    texture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    if coordinates then texture:SetTexCoord(coordinates[1],coordinates[2],coordinates[3],coordinates[4]) else texture:SetTexCoord(0,1,0,1) end
end

local function SetRowDecorations(row, kind, child, stripeIndex)
    UI.SetProjectButtonOutline(row, kind=="group" or kind=="rawHeader")
    row.childBorder:Hide();row.classIcon:Hide()
    if kind=="group" or kind=="rawHeader" then
        UI.SetRowColor(row,guildGroupRowColor,0.9)
    elseif stripeIndex and math.mod(stripeIndex,2)==0 then
        UI.SetRowColor(row,guildStripeColor,0.14)
    else UI.SetRowColor(row,guildStripeColor,0.025) end
    if child then
        row.childBorder:ClearAllPoints();row.childBorder:SetPoint("TOPLEFT",row,"TOPLEFT",12,0);row.childBorder:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",12,0);row.childBorder:Show()
    end
end

local function RenderTable(controller)
    local rect, entries = controller.tableRect, controller.table.entries
    local headerHeight=controller.rawMode and 0 or 22
    local offset, visible, rowWidth = UI.Table.LayoutViewport(controller.table.scroll, controller.page, rect.x, rect.y + headerHeight, rect.width, rect.height - headerHeight, table.getn(entries), 24, table.getn(controller.table.rows))
    LayoutTable(controller, rowWidth)
    local index
    for index = 1, table.getn(controller.table.rows) do
        local row, entry = controller.table.rows[index], entries[offset + index]
        if entry and index <= visible then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", controller.page, "TOPLEFT", rect.x, -rect.y - headerHeight - (index - 1) * 24); row:SetWidth(rowWidth);row.entry=entry
            SetRowDecorations(row,entry.kind,entry.child,entry.rawIndex or entry.rowIndex)
            if entry.kind == "group" then
                local marker=controller.expandedGroups[entry.value] and "- " or "+ "
                UI.Table.Cell(row.name, row, 6, rowWidth - 12, 23, marker..entry.value .. "  (" .. entry.count .. ")")
                row.name:SetTextColor(unpack(UI.Theme.colors.goldText)); row.class:Hide(); row.rank:Hide(); row.level:Hide()
            elseif entry.kind=="rawHeader" then
                local marker=controller.expandedRawSections[entry.rawKey] and "- " or "+ "
                UI.Table.Cell(row.name,row,6,rowWidth-12,23,marker..entry.value.."  ("..entry.count..")");row.name:SetTextColor(unpack(UI.Theme.colors.goldText));row.class:Hide();row.rank:Hide();row.level:Hide()
            elseif entry.kind=="raw" or entry.kind=="rawClass" then
                local left=entry.kind=="rawClass" and 28 or 12
                local valueX=math.min(190,math.max(110,math.floor(rowWidth*0.42)))
                UI.Table.Cell(row.name,row,left,valueX-left-6,23,entry.label);UI.Table.Cell(row.class,row,valueX,rowWidth-valueX-6,23,entry.countText);row.rank:Hide();row.level:Hide();row.class:Show()
                if entry.kind=="rawClass" then local rawColor=ClassColor(entry.className);row.name:SetTextColor(rawColor.r or rawColor[1],rawColor.g or rawColor[2],rawColor.b or rawColor[3]) else row.name:SetTextColor(1,1,1) end
                if entry.kind=="rawClass" then row.classIcon:ClearAllPoints();row.classIcon:SetPoint("LEFT",row,"LEFT",8,0);SetClassIcon(row.classIcon,entry.className);row.classIcon:Show() end
            else
                local member, columns = entry.member, controller.table.columns
                local x = 0
                local iconInset=entry.child and 18 or 6
                local nameInset=iconInset+20
                row.classIcon:ClearAllPoints();row.classIcon:SetPoint("LEFT",row,"LEFT",iconInset,0);SetClassIcon(row.classIcon,member.class);row.classIcon:Show()
                UI.Table.Cell(row.name, row, x + nameInset, columns[1].width - nameInset - 4, 23, member.name); x = x + columns[1].width
                local color = ClassColor(member.class); row.name:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
                UI.Table.Cell(row.class, row, x, columns[2].width - 4, 23, DisplayClass(member.class)); row.class:SetTextColor(color.r or color[1],color.g or color[2],color.b or color[3]); x = x + columns[2].width
                UI.Table.Cell(row.rank, row, x, columns[3].width - 4, 23, DisplayRank(member.rank)); x = x + columns[3].width
                UI.Table.Cell(row.level, row, x, columns[4].width - 2, 23, member.level or "")
                row.class:Show(); row.rank:Show(); row.level:Show()
            end
            row:Show()
        else row.entry=nil;row:Hide() end
    end
end

if Booty.Diagnostics.Wrap then RenderTable=Booty.Diagnostics.Wrap("Guild Statistics rows",RenderTable,1) end

function GuildStatistics.AttachExport(view, button)
    button:SetParent(view.actionPanel or view.page); button:ClearAllPoints(); button:SetWidth(100); button:SetHeight(26); button:Show()
    button:SetText("Export Guild")
    UI.StyleActionButton(button); UI.SetClassicButtonIcon(button, "save", 13, 7, 0); UI.SetClassicButtonLabelOffset(button, 2)
    view.exportButton = button
end

function GuildStatistics.CreateView(host, styleButton, refresh)
    local page = UI.CreateResponsiveCanvas(host, "BootyGuildStatisticsPage")
    local view = { page = page, host = host, onFilterChanged = refresh }
    view.title = UI.CreateHeading(page, "", 1, "gold", "guild_stats"); view.title:SetText("Guild Statistics")
    view.titleSeparator = UI.CreateHeading(page, "", 1, "white"); view.titleSeparator:SetText("|"); view.titleSeparator:SetTextColor(1,1,1)
    view.guildTitle = UI.CreateHeading(page, "", 1, "orange", "roster"); view.guildTitle:SetText("Guild")
    local headingFont,_,headingFlags=view.guildTitle:GetFont();view.titleSeparator:SetFont(headingFont,13,headingFlags);view.guildTitle:SetFont(headingFont,13,headingFlags)
    view.actionPanel=UI.CreateToolbarSurface(page,true,true);UI.AddToolbarBackground(view.actionPanel,0.42)
    view.refreshButton = UI.CreateControl(nil, view.actionPanel); view.refreshButton:SetWidth(108); view.refreshButton:SetHeight(26); styleButton(view.refreshButton, "Refresh Data"); view.refreshButton:Hide()
    UI.SetClassicButtonIcon(view.refreshButton, "reset", 13, 7, 0); UI.SetClassicButtonLabelOffset(view.refreshButton, 2)
    view.rawButton=UI.CreateControl(nil,view.actionPanel);view.rawButton:SetWidth(92);view.rawButton:SetHeight(26);styleButton(view.rawButton,"Raw Data");view.rawButton:Hide()
    UI.SetClassicButtonIcon(view.rawButton,"list",13,7,0);UI.SetClassicButtonLabelOffset(view.rawButton,2)
    view.showingLabel = UI.CreateLabel(view.actionPanel, nil, "OVERLAY", "GameFontHighlightSmall"); view.showingLabel:SetText("Showing members:"); view.showingLabel:SetTextColor(unpack(UI.Theme.colors.goldText)); view.showingLabel:SetJustifyH("RIGHT"); view.showingLabel:Hide()
    view.showing = UI.CreateLabel(view.actionPanel, nil, "OVERLAY", "GameFontHighlightSmall"); view.showing:SetTextColor(1,1,1); view.showing:SetJustifyH("RIGHT"); view.showing:Hide()
    view.lastScan = UI.CreateLabel(page, nil, "OVERLAY", "GameFontDisableSmall"); view.lastScan:Hide()
    view.scanButton = UI.CreateControl(nil, page); view.scanButton:SetWidth(160); view.scanButton:SetHeight(26); styleButton(view.scanButton, "Scan Guild Statistics")
    view.empty = UI.CreateLabel(page, nil, "OVERLAY", "GameFontDisableSmall"); view.empty:SetJustifyH("CENTER"); view.empty:Hide()
    view.filterPanel = UI.CreateToolbarSurface(page, false, true)
    view.rankGroup = CreateFilterGroup(view.filterPanel, "Rank", 88);view.rankGroup.panel.allSelectedCaption="Rank";view.rankGroup.panel.emptyMeansAll=true;view.rankGroup.button.bootyLabelJustify="LEFT"
    view.classGroup = CreateFilterGroup(view.filterPanel, "Class", 96);view.classGroup.panel.allSelectedCaption="Class";view.classGroup.panel.emptyMeansAll=true;view.classGroup.button.bootyLabelJustify="LEFT"
    view.groupGroup = UI.CreateContainer(nil, view.filterPanel); view.groupGroup:SetWidth(112); view.groupGroup:SetHeight(24); view.groupGroup.bootyFlowWidth=112
    local groupChoices={{value="none",text="None"},{value="class",text="Class"},{value="rank",text="Rank"},{value="level",text="Level"}}
    view.groupLabel=UI.CreateLabel(view.groupGroup,nil,"OVERLAY","GameFontHighlightSmall");view.groupLabel:SetPoint("LEFT",view.groupGroup,"LEFT",0,0);view.groupLabel:SetText("Group by:")
    view.groupButton=UI.CreateDropdownButton(view.groupGroup,nil,"None",52);view.groupButton:SetPoint("RIGHT",view.groupGroup,"RIGHT",0,0);view.groupButton:SetHeight(24)
    view.groupPanel=UI.CreateDropdownPanel(view.filterPanel,view.groupButton,104,88,50)
    local choiceIndex
    for choiceIndex=1,table.getn(groupChoices) do
        local choice=UI.CreateButton(view.groupPanel,nil,groupChoices[choiceIndex].text,96,18);UI.StyleDropdownChoice(choice)
        choice:SetPoint("TOPLEFT",view.groupPanel,"TOPLEFT",4,-4-(choiceIndex-1)*20);choice.choiceValue=groupChoices[choiceIndex].value;choice.choiceText=groupChoices[choiceIndex].text
        choice:SetScript("OnClick",function() view.groupBy=this.choiceValue;view.groupButton:SetText(this.choiceText);view.groupPanel:Hide();view.onFilterChanged() end)
        table.insert(view.groupPanel.options,choice)
    end
    view.groupButton:SetScript("OnClick",function() if view.groupPanel:IsVisible() then view.groupPanel:Hide() else view.groupPanel:Show() end end)
    UI.StyleProjectPopup(view.groupPanel)
    view.levelGroup=UI.CreateContainer(nil,view.filterPanel);view.levelGroup:SetWidth(72);view.levelGroup:SetHeight(24);view.levelGroup.bootyFlowWidth=72
    view.levelLabel=UI.CreateLabel(view.levelGroup,nil,"OVERLAY","GameFontHighlightSmall");view.levelLabel:SetPoint("LEFT",view.levelGroup,"LEFT",0,0);view.levelLabel:SetText("Level:")
    view.level=UI.CreateFramedEditBox(view.levelGroup,nil,32);view.level:SetPoint("RIGHT",view.levelGroup,"RIGHT",0,0);view.level:SetMaxLetters(2);view.level:SetScript("OnTextChanged",function() view.onFilterChanged() end)
    view.searchGroup=UI.CreateContainer(nil,view.filterPanel);view.searchGroup:SetWidth(132);view.searchGroup:SetHeight(24);view.searchGroup.bootyFlowWidth=132
    view.searchLabel=UI.CreateLabel(view.searchGroup,nil,"OVERLAY","GameFontHighlightSmall");view.searchLabel:SetText("");view.searchLabel:Hide()
    view.search=UI.CreateFramedEditBox(view.searchGroup,nil,132);view.search:SetPoint("LEFT",view.searchGroup,"LEFT",0,0);view.search:SetScript("OnTextChanged",function() view.onFilterChanged() end);UI.AttachPlaceholder(view.search,"Search...")
    view.flow={view.rankGroup,view.classGroup,view.groupGroup,view.levelGroup,view.searchGroup}
    view.table=CreateMemberTable(page,refresh)
    return view
end

local function OnStatisticsScan() this.statisticsController.startScan("statistics") end
local function SetControlText(control,text) if control.label then control.label:SetText(text) else control:SetText(text) end end
local function SetGroupByEnabled(view,enabled)
    if enabled then view.groupButton:Enable();view.groupButton.label:SetTextColor(1,1,1);view.groupButton.arrow:SetVertexColor(1,1,1)
    else view.groupPanel:Hide();view.groupButton:Disable();view.groupButton.label:SetTextColor(0.45,0.45,0.45);view.groupButton.arrow:SetVertexColor(0.45,0.45,0.45) end
    if UI.SetClassicButtonDisabled then UI.SetClassicButtonDisabled(view.groupButton,not enabled) end
end

function GuildStatistics.CreateController(options)
    local view=options.view
    options.page=view.page;options.view=view;options.rankGroup=view.rankGroup;options.classGroup=view.classGroup;options.level=view.level;options.search=view.search;options.table=view.table
    options.ready=false;options.groupBy="none";options.selectedRanks={};options.selectedClasses={};options.knownRanks={};options.knownClasses={};options.expandedGroups={};options.expandedRawSections={rank=false,class=false,level=false};options.sortKey="name";options.sortAscending=true;options.rawMode=false
    options.model={ranks={},classes={},rankSeen={},classSeen={},wrapperPool={},fullEntries={},groupHeaders={},rawRows={rank={},class={},level={}},rawPools={rank={},class={},level={}},rawHeaders={{},{},{}}}
    options.rawRanks={};options.rawRankOrder={};options.rawClasses={};options.rawLevels={0,0,0};options.rawRankMembers={};options.rawClassMembers={};options.rawLevelMembers={}
    options.modelDirty=true;options.projectionDirty=true
    view.groupBy="none";options.filterChanged=function() ClearMap(options.expandedGroups);GuildStatistics.Refresh(options) end;view.onFilterChanged=options.filterChanged
    options.table.scroll.refreshCallback=function() RefreshPresentation(options,false) end
    options.table.controller=options;options.table.onSort=function(key)
        if options.rawMode then return end
        if options.sortKey==key then options.sortAscending=not options.sortAscending else options.sortKey=key;options.sortAscending=true end
        GuildStatistics.Refresh(options)
    end
    view.rawButton.statisticsController=options;view.rawButton:SetScript("OnClick",function()
        local controller=this.statisticsController;controller.rawMode=not controller.rawMode;SetControlText(this,controller.rawMode and "Table Data" or "Raw Data");SetGroupByEnabled(controller.view,not controller.rawMode);GuildStatistics.Refresh(controller)
    end)
    options.page.statisticsController=options;view.host.statisticsController=options;view.scanButton.statisticsController=options;view.refreshButton.statisticsController=options
    view.scanButton:SetScript("OnClick",OnStatisticsScan);view.refreshButton:SetScript("OnClick",OnStatisticsScan)
    return options
end

function GuildStatistics.SetReady(controller,ready) controller.ready=ready and true or false;controller.modelDirty=true end
function GuildStatistics.IsReady(controller) return controller.ready end

local function HideResults(controller)
    controller.view.showingLabel:Hide();controller.view.showing:Hide();controller.view.lastScan:Hide();controller.view.actionPanel:Hide();controller.view.rawButton:Hide();controller.view.filterPanel:Hide();controller.table.scroll:Hide()
    local index
    for index=1,table.getn(controller.table.headers) do controller.table.headers[index]:Hide() end
    for index=1,table.getn(controller.table.rows) do controller.table.rows[index]:Hide() end
    UI.SetScrollBarVisible(getglobal("BootyGuildGuildStatisticsScrollScrollBar"),false)
end

function GuildStatistics.BeginScan(controller)
    controller.ready=false;controller.modelDirty=true
    if not IsPresentationVisible(controller) then return end
    HideResults(controller);controller.view.refreshButton:Hide();controller.view.scanButton:Hide();controller.view.empty:Hide()
end
function GuildStatistics.HandleScanFailure(controller)
    if not IsPresentationVisible(controller) then return end
    controller.view.scanButton:Show()
end

local function LayoutContent(width,height,controller)
    local view,page=controller.view,controller.page
    local available=math.max(80,width-16)
    local font,size,flags=view.title:GetFont()
    view.title.bootyFitFontSize=view.title.bootyFitFontSize or size
    view.title:SetFont(font,view.title.bootyFitFontSize,flags);view.title:SetWidth(0)
    local titleWidth=math.min(view.title:GetStringWidth()+(view.title.bootyHeadingIconInset or 0)+2,available*0.55)
    view.title:ClearAllPoints();view.title:SetPoint("TOPLEFT",page,"TOPLEFT",8,-8);view.title:SetWidth(titleWidth)
    UI.FitButtonLabel(view.title,titleWidth)
    view.titleSeparator:ClearAllPoints();view.titleSeparator:SetPoint("BOTTOMLEFT",view.title,"BOTTOMRIGHT",8,0);view.titleSeparator:SetWidth(8);view.titleSeparator:SetHeight(16)
    local guildWidth=math.max(1,available-titleWidth-32)
    view.guildTitle:ClearAllPoints();view.guildTitle:SetPoint("BOTTOMLEFT",view.titleSeparator,"BOTTOMRIGHT",8,0);view.guildTitle:SetWidth(guildWidth);view.guildTitle:SetHeight(16);UI.FitButtonLabel(view.guildTitle,guildWidth)
    local top=36
    if controller.ready then
        local showingLabelWidth=112
        local showingCountWidth=math.max(32,math.ceil(view.showing:GetStringWidth())+10)
        local showingWidth=showingLabelWidth+4+showingCountWidth
        local actionAvailable=math.max(72,available-showingWidth-12)
        local baseActionWidth=(view.exportButton and 100 or 0)+104+92+(view.exportButton and 16 or 8)
        local actionScale=math.min(1,math.max(0.52,actionAvailable/math.max(1,baseActionWidth)))
        local actionHeight=38
        if baseActionWidth*actionScale>actionAvailable+1 then actionAvailable=available;actionScale=math.min(1,actionAvailable/math.max(1,baseActionWidth));actionHeight=68 end
        view.actionPanel:ClearAllPoints();view.actionPanel:SetPoint("TOPLEFT",page,"TOPLEFT",0,-top);view.actionPanel:SetWidth(width);view.actionPanel:SetHeight(actionHeight);view.actionPanel:Show()
        local actionX=8
        UI.SizeClassicButton(view.rawButton,math.floor(92*actionScale),26,actionScale);view.rawButton:ClearAllPoints();view.rawButton:SetPoint("TOPLEFT",view.actionPanel,"TOPLEFT",actionX,-6)
        actionX=actionX+view.rawButton:GetWidth()+8
        UI.SizeClassicButton(view.refreshButton,math.floor(104*actionScale),26,actionScale);view.refreshButton:ClearAllPoints();view.refreshButton:SetPoint("TOPLEFT",view.actionPanel,"TOPLEFT",actionX,-6);actionX=actionX+view.refreshButton:GetWidth()+8
        if view.exportButton then UI.SizeClassicButton(view.exportButton,math.floor(100*actionScale),26,actionScale);view.exportButton:ClearAllPoints();view.exportButton:SetPoint("TOPLEFT",view.actionPanel,"TOPLEFT",actionX,-6) end
        view.showing:ClearAllPoints();view.showing:SetPoint("TOPRIGHT",view.actionPanel,"TOPRIGHT",-8,actionHeight==38 and -10 or -44);view.showing:SetWidth(showingCountWidth);view.showing:SetHeight(18)
        view.showingLabel:ClearAllPoints();view.showingLabel:SetPoint("RIGHT",view.showing,"LEFT",-4,0);view.showingLabel:SetWidth(math.max(1,showingWidth-showingCountWidth-4));view.showingLabel:SetHeight(18)
        top=top+actionHeight
        view.filterPanel:ClearAllPoints();view.filterPanel:SetPoint("TOPLEFT",page,"TOPLEFT",0,-top);view.filterPanel:SetWidth(width)
        local flowWidth=math.max(1,width-16)
        local groupLabelWidth=math.ceil(view.groupLabel:GetStringWidth())
        local levelLabelWidth=math.ceil(view.levelLabel:GetStringWidth())
        view.groupGroup.bootyFlowWidth=groupLabelWidth+4+64
        view.levelGroup.bootyFlowWidth=levelLabelWidth+4+32
        local searchMinimum=66
        local searchMaximum=132
        local precedingWidth=view.rankGroup.bootyFlowWidth+view.classGroup.bootyFlowWidth+view.groupGroup.bootyFlowWidth+view.levelGroup.bootyFlowWidth+24
        local sameRowWidth=flowWidth-precedingWidth
        local searchGroupWidth
        if sameRowWidth>=searchMinimum then searchGroupWidth=math.min(searchMaximum,sameRowWidth)
        else searchGroupWidth=math.min(searchMaximum,math.max(searchMinimum,flowWidth)) end
        view.searchGroup.bootyFlowWidth=searchGroupWidth
        local filterBottom=UI.LayoutFlow(view.filterPanel,view.flow,8,6,flowWidth,6)+6;view.filterPanel:SetHeight(filterBottom)
        view.rankGroup.button:SetWidth(view.rankGroup:GetWidth());view.classGroup.button:SetWidth(view.classGroup:GetWidth())
        view.groupButton:SetWidth(64);view.groupButton:ClearAllPoints();view.groupButton:SetPoint("LEFT",view.groupLabel,"RIGHT",4,0)
        view.level:SetWidth(32);view.level:ClearAllPoints();view.level:SetPoint("LEFT",view.levelLabel,"RIGHT",4,0)
        view.search:SetWidth(math.max(66,math.min(132,view.searchGroup:GetWidth())));view.search:ClearAllPoints();view.search:SetPoint("LEFT",view.searchGroup,"LEFT",0,0)
        top=top+filterBottom+8
        controller.tableRect=controller.tableRect or {};controller.tableRect.x=8;controller.tableRect.y=top;controller.tableRect.width=available;controller.tableRect.height=math.max(24,height-top-8)
        return controller.tableRect.y+controller.tableRect.height+8
    end
    view.empty:ClearAllPoints();view.empty:SetPoint("TOPLEFT",page,"TOPLEFT",8,-64);view.empty:SetWidth(available)
    view.scanButton:ClearAllPoints();view.scanButton:SetPoint("TOP",view.empty,"BOTTOM",0,-12);view.scanButton:SetWidth(math.min(160,available))
    return 130
end

function GuildStatistics.Layout(controller) UI.LayoutResponsiveCanvas(controller.page,LayoutContent,controller) end
if Booty.Diagnostics.Wrap then GuildStatistics.Layout=Booty.Diagnostics.Wrap("Guild Statistics layout",GuildStatistics.Layout,1) end

RefreshPresentation=function(controller,relayout)
    if not IsPresentationVisible(controller) then return end
    if controller.refreshing then return end
    controller.refreshing=true;Booty.Diagnostics.Count("uiRefreshes")
    if not controller.ready then
        if relayout then HideResults(controller);GuildStatistics.Layout(controller) end
        controller.refreshing=false;return
    end
    if controller.modelDirty then
        local data,guildName=controller.getData();guildName=guildName or "Guild";controller.view.guildTitle:SetText(guildName)
        controller.model.hasData=data and type(data.members)=="table" and true or false
        if not controller.model.hasData then
            controller.modelDirty=false;ClearDerivedModel(controller)
            HideResults(controller);controller.view.empty:SetText(guildName.." has no saved roster. Scan Guild Statistics to begin.");controller.view.empty:Show();controller.view.scanButton:Show()
        else
            controller.groupBy=controller.view.groupBy or "none"
            BuildModel(controller,data)
            controller.view.showing:SetText(tostring(controller.model.count));controller.view.showingLabel:Show();controller.view.showing:Show()
            controller.view.lastScan:SetText("Last scan: "..(data.scannedAtText or "Unknown"))
            controller.view.empty:Hide();controller.view.scanButton:Hide();controller.view.refreshButton:Show();controller.view.rawButton:Show();controller.view.actionPanel:Show();controller.view.filterPanel:Show()
        end
        relayout=true
    end
    if relayout then GuildStatistics.Layout(controller) end
    if not controller.model.hasData then controller.refreshing=false;return end
    if controller.projectionDirty then ProjectEntries(controller) end
    RenderTable(controller)
    local index
    for index=1,table.getn(controller.table.headers) do if controller.rawMode then controller.table.headers[index]:Hide() else controller.table.headers[index]:Show() end end
    controller.refreshing=false
end

-- External roster mutations explicitly invalidate the derived model, even
-- while hidden. Scroll, resize and accordion projection reuse its rows.
function GuildStatistics.Refresh(controller)
    controller.modelDirty=true;controller.projectionDirty=true
    RefreshPresentation(controller,true)
end

function GuildStatistics.CreateLifecycle(controller)
    return {
        Hide=function() controller.view.rankGroup.panel:Hide();controller.view.classGroup.panel:Hide();controller.view.groupPanel:Hide();controller.page:Hide();controller.view.host:Hide();UI.SetScrollBarVisible(getglobal("BootyGuildGuildStatisticsScrollScrollBar"),false) end,
        Show=function() controller.view.host:Show();controller.page:Show();GuildStatistics.Refresh(controller) end,
        Refresh=function() GuildStatistics.Refresh(controller) end,
        OnResize=function() RefreshPresentation(controller,true) end,
    }
end

local Guild = BootyGuild
local fields = {}
local function Changed(key)
    if Guild.Controller then Guild.Controller.SettingsChanged(key) end
end
local function Field(key,label,kind,path,extra)
    local field = {key=key,label=label,type=kind,path=path,onChange=function() Changed(key) end}
    if extra then local name,value;for name,value in pairs(extra) do field[name]=value end end
    table.insert(fields,field)
end

Field("playerDetailsStyle","Player details style","choice",{"Addon UI","Guild","General"},
    {choices={{value="collapsible",label="Collapsible"},{value="window",label="Window"}}})
Field("rosterLiveTrackingEnabled","Live tracking","checkbox",{"Addon UI","Guild","General"},
    {tooltip="Refresh guild data while the Guild page is visible. Hidden pages do not track guild updates."})
Field("rosterHideSectionHeader","Hide section header","checkbox",{"Addon UI","Guild","Layout","Display"})
local display = {
    {"Class","Show class"},{"Level","Show lvl"},{"Zone","Show zone"},{"Rank","Show rank"},
    {"PublicNote","Show public note"},{"OfficerNote","Show officer note"},{"LastOnline","Show last online"},
    {"ClassFilter","Show class filter"},{"RankFilter","Show rank filter"},{"Search","Show search"},
    {"Offline","Show offline filter"},{"ColumnHeaders","Show column headers"},
}
for _, item in ipairs(display) do
    Field("rosterShow"..item[1],item[2],"checkbox",{"Addon UI","Guild","Layout","Display"},
        item[1]=="OfficerNote" and {enabled=function() return Guild.Services.Roster.CanManage("viewOfficerNote") end} or nil)
end
Field("rosterClassColors","Use class colors","checkbox",{"Addon UI","Guild","Layout","Member tile color"})
Field("rosterBackgroundColor","Background color","color",{"Addon UI","Guild","Layout","Member tile color"})
Field("rosterTextColor","Text color","color",{"Addon UI","Guild","Layout","Member tile color"})
Field("rosterHoverColor","Hover color","color",{"Addon UI","Guild","Layout","Member tile color"})
Field("rosterOddLightness","Odd record lightness (%)","slider",{"Addon UI","Guild","Layout","Member tile color"},{min=0,max=100,step=1})
-- This preference already belongs to the visible Guild filter bar. Keep it in
-- named profile snapshots without duplicating that checkbox in Settings.
Field("showOfflineMembers","Show offline members","checkbox",{"Addon UI","Guild","General"},{profileOnly=true,default=true})

function Guild.GetSettings() return {db=Guild.Database.Ensure(),fields=fields} end

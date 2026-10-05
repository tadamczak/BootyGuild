local Policy = {}
BootyGuild.Services.RankPolicy = Policy

-- Presentation naming is independent of BootyRaider's loot-rights policies.
function Policy.GetDisplayName(value)
    if string.lower(tostring(value or "")) == "officer wukong" then return "Officer (Chimp)" end
    return value
end

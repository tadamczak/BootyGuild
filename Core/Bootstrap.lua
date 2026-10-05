BootyGuild = BootyGuild or {}
local Guild = BootyGuild
Guild.version = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("BootyGuild", "Version") or "0.1.0-dev.2"
Guild.version = Guild.version or "0.1.0-dev.2"
Guild.UI = BootyLib.UI
Guild.Diagnostics = BootyLib.Diagnostics
Guild.Core = Guild.Core or { Compatibility = BootyLib.Core and BootyLib.Core.Compatibility }
Guild.Modules = Guild.Modules or {}
Guild.Services = Guild.Services or {}

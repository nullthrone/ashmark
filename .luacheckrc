-- luacheck configuration for Ashmark (Lua 5.1, World of Warcraft Forever).
std = "lua51"
max_line_length = 120
unused_args = false
ignore = { "211/ADDON" }        -- every file starts with `local ADDON, ns = ...`
exclude_files = { ".luarocks", "lua_modules" }

-- The only globals Ashmark writes (ARCHITECTURE 3.1).
globals = {
  "AshmarkDB",
  "Ashmark_OnAddonCompartmentClick", "Ashmark_OnAddonCompartmentEnter", "Ashmark_OnAddonCompartmentLeave",
  "SLASH_ASHMARK1", "SLASH_ASHMARK2",
  "AshmarkMapPinMixin",
  "AshmarkFrame", "AshmarkDialog", "AshmarkNoticeFrame", "AshmarkTestTooltip",
  SlashCmdList = { fields = { ASHMARK = { read_only = false } }, other_fields = true, read_only = true },
}

-- Everything the spec reads from the client. A unit that needs more declares it at the top of its
-- own file with `-- luacheck: read globals X, Y`.
read_globals = {
  -- Lua extensions of the WoW environment
  "tinsert", "tremove", "wipe", "sort", "strsplit", "strtrim", "strjoin", "format", "strlower", "strupper",
  "strsub", "strlen", "strfind", "strmatch", "gsub", "gmatch", "strrep", "strbyte", "strchar",
  "floor", "ceil", "abs", "max", "min", "sqrt", "mod", "random",
  "tContains", "tIndexOf", "CopyTable", "Round", "Clamp", "Mixin", "CreateFromMixins",
  "time", "date", "GetTime", "GetServerTime", "debugstack", "geterrorhandler", "seterrorhandler",
  "securecallfunction", "issecure", "hooksecurefunc",
  -- Secret values
  "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable", "secretwrap",
  -- Client, build and game state
  "GetBuildInfo", "GetLocale", "WOW_PROJECT_ID", "WOW_PROJECT_CAMELOT", "WOW_PROJECT_MAINLINE",
  "WOW_PROJECT_CLASSIC", "GetRealmName", "GetNormalizedRealmName", "IsLoggedIn", "InCombatLockdown",
  "IsTrialAccount", "IsVeteranTrialAccount", "GetMoney", "IsResting", "IsOutdoors", "GetQuestID",
  "Screenshot", "PlaySound", "GetCVar", "GetCVarBool", "GetText", "GetClassAtlas", "GetInventoryItemID",
  "GetZoneText", "GetRealZoneText", "GetSubZoneText", "IsInInstance", "GetInstanceInfo",
  -- Units and groups
  "UnitGUID", "UnitExists", "UnitIsUnit", "UnitName", "UnitNameUnmodified", "UnitFullName", "UnitClass",
  "UnitRace", "UnitSex", "UnitFactionGroup", "UnitLevel", "UnitIsPlayer", "UnitIsDead", "UnitIsTapDenied",
  "UnitIsAFK", "UnitPlayerControlled", "UnitReaction", "UnitCreatureType", "UnitHealth", "UnitHealthMax",
  "UnitAffectingCombat", "UnitInParty", "UnitInRaid", "IsInRaid", "IsInGroup", "GetNumSubgroupMembers",
  "GetNumGroupMembers",
  -- C_ namespaces and enums
  "C_AddOns", "C_ChatInfo", "C_ClassColor", "C_CombatLog", "C_Container", "C_CreatureInfo", "C_CVar",
  "C_EventUtils", "C_GameRules", "C_Item", "C_MajorFactions", "C_Map", "C_PlayerInfo", "C_QuestLog",
  "C_Reputation", "C_RestrictedActions", "C_Secrets", "C_Spell", "C_Texture", "C_Timer", "C_TooltipInfo",
  "C_UnitAuras", "C_XMLUtil", "Enum",
  -- Strings, colours, sounds and constants
  "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE",
  "FACTION_STANDING_LABEL1", "FACTION_STANDING_LABEL2", "FACTION_STANDING_LABEL3", "FACTION_STANDING_LABEL4",
  "FACTION_STANDING_LABEL5", "FACTION_STANDING_LABEL6", "FACTION_STANDING_LABEL7", "FACTION_STANDING_LABEL8",
  "ERR_UNINVITE_YOU", "ITEM_LEVEL", "FACTION_ALLIANCE", "FACTION_HORDE",
  "ACCEPT", "CANCEL", "YES", "NO", "OKAY", "CLOSE",
  "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR", "GRAY_FONT_COLOR", "ChatTypeInfo",
  "FACTION_BAR_COLORS", "SOUNDKIT", "NUM_TOTAL_EQUIPPED_BAG_SLOTS", "INVSLOT_FIRST_EQUIPPED",
  "INVSLOT_LAST_EQUIPPED",
  -- Frames, templates and FrameXML
  "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "UISpecialFrames", "WorldMapFrame", "QuestFrame",
  "QuestFrameDetailPanel", "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
  "TooltipDataProcessor", "TooltipUtil", "MapCanvasDataProviderMixin", "MapCanvasPinMixin",
  "Settings", "SettingsPanel", "CreateSettingsListSectionHeaderInitializer",
  "CreateScrollBoxListLinearView", "CreateDataProvider", "ScrollUtil",
  "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize", "PanelTemplates_UpdateTabs",
  "QuestTitleFont", "QuestFont", "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall",
  "GameFontDisable", "GameFontNormalHuge",
}

-- Specs and their helpers run under busted and build the mock client through _G.
files["tests/"] = { std = "+busted" }

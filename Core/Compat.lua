local ADDON, ns = ...

local Compat = { Has = {}, disabled = {}, loggedIn = false }
ns.Compat = Compat

local function isFn(f)
  return type(f) == "function"
end

do
  local version, build, date, interface = GetBuildInfo()
  Compat.build = { version = version, build = build, date = date, interface = interface }
end
Compat.tocVariant = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "X-TocVariant")

function Compat.IsForever()
  if WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then return true end
  local iface = select(4, GetBuildInfo())
  return type(iface) == "number" and iface >= 16000 and iface < 20000
end

local function addonMessages()
  return C_ChatInfo and isFn(C_ChatInfo.SendAddonMessage) and isFn(C_ChatInfo.RegisterAddonMessagePrefix)
end

local function hasData(fn, id)
  local ok, data = ns.Safe.Call(fn, id)
  return ok and data ~= nil
end

local detectors = {
  questLog = function()
    return C_QuestLog and isFn(C_QuestLog.GetTitleForQuestID) and isFn(C_QuestLog.GetLogIndexForQuestID)
      and isFn(C_QuestLog.RequestLoadQuestByID)
  end,
  questFrame = function()
    return QuestFrame ~= nil and QuestFrameDetailPanel ~= nil
  end,
  abandonHooks = function()
    return C_QuestLog and isFn(C_QuestLog.SetAbandonQuest) and isFn(C_QuestLog.GetAbandonQuest)
      and isFn(C_QuestLog.AbandonQuest)
  end,
  reputation = function()
    return C_Reputation and isFn(C_Reputation.GetFactionDataByID)
  end,
  map = function()
    return C_Map and isFn(C_Map.GetBestMapForUnit) and isFn(C_Map.GetPlayerMapPosition) and isFn(C_Map.GetMapInfo)
  end,
  mapPins = function()
    return WorldMapFrame and isFn(WorldMapFrame.AddDataProvider) and MapCanvasDataProviderMixin ~= nil
      and MapCanvasPinMixin ~= nil and C_Map and isFn(C_Map.GetMapRectOnMap)
  end,
  tooltipProcessor = function()
    return TooltipDataProcessor and isFn(TooltipDataProcessor.AddTooltipPostCall) and Enum
      and Enum.TooltipDataType ~= nil
  end,
  auras = function()
    return C_UnitAuras and isFn(C_UnitAuras.GetPlayerAuraBySpellID)
  end,
  addonMessages = addonMessages,
  canSend = function()
    if not addonMessages() then return false end
    if isFn(IsTrialAccount) and IsTrialAccount() == true then return false end
    if isFn(IsVeteranTrialAccount) and IsVeteranTrialAccount() == true then return false end
    return true
  end,
  secrets = function()
    return isFn(issecretvalue) or isFn(canaccessvalue)
  end,
  eventCheck = function()
    return C_EventUtils and isFn(C_EventUtils.IsEventValid)
  end,
  settingsApi = function()
    return Settings and isFn(Settings.RegisterVerticalLayoutCategory) and isFn(Settings.RegisterAddOnSetting)
      and isFn(Settings.CreateCheckbox) and isFn(Settings.RegisterAddOnCategory)
  end,
  scrollBox = function()
    return isFn(CreateScrollBoxListLinearView) and isFn(CreateDataProvider) and ScrollUtil
      and isFn(ScrollUtil.InitScrollBoxListWithScrollBar)
  end,
  xmlInfo = function()
    return C_XMLUtil and isFn(C_XMLUtil.GetTemplateInfo)
  end,
  container = function()
    return C_Container and isFn(C_Container.GetContainerItemID) and isFn(C_Container.GetContainerNumSlots)
  end,
  itemCache = function()
    return C_Item and isFn(C_Item.IsItemDataCachedByID) and isFn(C_Item.GetItemInfoInstant)
  end,
  encounters = function()
    if C_EventUtils and isFn(C_EventUtils.IsEventValid) then
      return C_EventUtils.IsEventValid("ENCOUNTER_END") == true
    end
    return true
  end,
  critterType = function()
    local ok, info = ns.Safe.Call(C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo, 8)
    if not ok then return false end
    local name, readable = ns.Safe.Field(info, "name")
    return readable and type(name) == "string" and name ~= ""
  end,
  legacy = function()
    if not Compat.loggedIn then return false end
    return hasData(C_Reputation and C_Reputation.GetFactionDataByID, 2802)
      or hasData(C_MajorFactions and C_MajorFactions.GetMajorFactionData, 2802)
  end,
  screenshot = function()
    return isFn(Screenshot)
  end,
  rulesets = function()
    return C_GameRules and isFn(C_GameRules.IsGameRuleActive) and Enum and Enum.GameRule ~= nil
  end,
}

Compat.KEYS = {
  "questLog", "questFrame", "abandonHooks", "reputation", "map", "mapPins", "tooltipProcessor", "auras",
  "addonMessages", "canSend", "secrets", "eventCheck", "settingsApi", "scrollBox", "xmlInfo", "container",
  "itemCache", "encounters", "critterType", "legacy", "screenshot", "rulesets",
}

function Compat.Check(cap)
  local detect = detectors[cap]
  if Compat.disabled[cap] or not detect then
    Compat.Has[cap] = false
    return false
  end
  local ok, value = pcall(detect)
  Compat.Has[cap] = (ok and value) and true or false
  return Compat.Has[cap]
end

-- At ADDON_LOADED (atLogin false) and again at PLAYER_LOGIN, before any OnEnable.
function Compat.Refresh(atLogin)
  if atLogin then Compat.loggedIn = true end
  for _, cap in ipairs(Compat.KEYS) do
    Compat.Check(cap)
  end
end

-- Runtime demotion for the session; Check keeps the capability off.
function Compat.Disable(cap, reason)
  Compat.disabled[cap] = reason or true
  Compat.Has[cap] = false
end

local ADDON, ns = ...

-- /ashmark probe (7.10): raw facts for the open platform questions, appended to AshmarkDB.dev.probes.
-- Every return is kept as a string: "<secret>", "<nil>" or tostring(v); tables one level deep.
local Probe = ns:NewService("Probe")

local Safe = ns.Safe
local TestMode = ns.TestMode
local L = ns.L

local MAX_PROBES = 20
local MAX_FIELDS = 40
local PULL_BEFORE = 2             -- seconds of UNIT_FLAGS kept from before PLAYER_REGEN_DISABLED
local PULL_AFTER = 2              -- seconds recorded after it
local PULL_KEEP = 8               -- UNIT_FLAGS events buffered while waiting for the pull
local ECHO_WAIT = 30
local LEGACY_FACTION = 2802
local TOOLTIP_ITEM = 6948         -- Hearthstone

local RULES = { "HardcoreRuleset", "RPRuleset", "PvPRuleset", "RPPvPRuleset" }
local RESTRICTION_CALLS = { "IsAddOnRestrictionActive", "GetAddOnRestrictionState" }

-- Every game event the architecture names. The combat log is deliberately absent: Ashmark never
-- touches it, not even through a validity check.
local EVENTS = {
  "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "ADDON_LOADED", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED",
  "CHAT_MSG_ADDON", "CHAT_MSG_SYSTEM", "ENCOUNTER_END", "GAME_RULES_CHANGED", "GET_ITEM_INFO_RECEIVED",
  "GROUP_LEFT", "GROUP_ROSTER_UPDATE", "ITEM_DATA_LOAD_RESULT", "LOOT_CLOSED", "LOOT_OPENED", "MAIL_CLOSED",
  "MAIL_SHOW", "MERCHANT_CLOSED", "MERCHANT_SHOW", "PLAYER_DEAD", "PLAYER_ENTERING_WORLD",
  "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_MONEY",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "QUEST_ACCEPTED", "QUEST_COMPLETE",
  "QUEST_DATA_LOAD_RESULT", "QUEST_DETAIL", "QUEST_FINISHED", "QUEST_LOG_UPDATE", "QUEST_PROGRESS",
  "QUEST_REMOVED", "QUEST_TURNED_IN", "SCREENSHOT_FAILED", "SCREENSHOT_SUCCEEDED", "TRADE_CLOSED", "TRADE_SHOW",
  "UNIT_AURA", "UNIT_FLAGS", "UNIT_HEALTH", "UNIT_PORTRAIT_UPDATE", "UPDATE_FACTION", "ZONE_CHANGED_NEW_AREA",
}

-- Strings --------------------------------------------------------------------

local function scalar(v)
  if Safe.IsSecret(v) then return "<secret>" end
  if v == nil then return "<nil>" end
  return tostring(v)
end

local function str(v)
  if type(v) ~= "table" or Safe.IsSecret(v) then return scalar(v) end
  local parts = {}
  for k, x in pairs(v) do
    local nested = type(x) == "table" and not Safe.IsSecret(x)
    parts[#parts + 1] = scalar(k) .. "=" .. (nested and "<table>" or scalar(x))
  end
  table.sort(parts)
  if #parts > MAX_FIELDS then
    for i = #parts, MAX_FIELDS + 1, -1 do parts[i] = nil end
    parts[#parts + 1] = "..."
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function strings(...)
  local out = {}
  for i = 1, select("#", ...) do out[i] = str((select(i, ...))) end
  return out
end

-- "C_Secrets.ShouldAurasBeSecret" -> the value, or nil; every level is type-checked.
local function lookup(path)
  local v = _G
  for part in path:gmatch("[^.]+") do
    if type(v) ~= "table" then return nil end
    v = v[part]
  end
  return v
end

local function need(path)
  local v = lookup(path)
  if v == nil then error("<missing>", 0) end
  return v
end

local function label(path, ...)
  local args = {}
  for i = 1, select("#", ...) do
    local a = select(i, ...)
    args[i] = type(a) == "string" and ('"' .. a .. '"') or scalar(a)
  end
  return path .. "(" .. table.concat(args, ", ") .. ")"
end

-- ok, every return as a string; or false and the error (or "<missing>").
local function capture(fn, ...)
  if type(fn) ~= "function" then return false, { "<missing>" } end
  local args, n = { ... }, select("#", ...)
  local ok, r = pcall(function() return strings(fn(unpack(args, 1, n))) end)
  if not ok then return false, { scalar(r) } end
  return true, r
end

-- Facts ----------------------------------------------------------------------

local function add(facts, what, ok, r)
  facts[#facts + 1] = { call = what, ok = ok, r = r }
end

local function call(facts, path, ...)
  add(facts, label(path, ...), capture(lookup(path), ...))
end

local function value(facts, path)
  add(facts, path, true, { str(lookup(path)) })
end

-- fn returns the list of strings itself.
local function custom(facts, what, fn)
  local ok, r = pcall(fn)
  add(facts, what, ok, ok and r or { scalar(r) })
end

local function pairsList(t)
  local out = {}
  for k, v in pairs(t) do out[#out + 1] = scalar(k) .. "=" .. scalar(v) end
  table.sort(out)
  return out
end

local function enum(facts, path)
  custom(facts, path, function()
    local t = need(path)
    if type(t) ~= "table" then return { scalar(t) } end
    return pairsList(t)
  end)
end

local function secrecy(facts, what, read)
  custom(facts, "issecretvalue(" .. what .. ")", function()
    return { scalar(need("issecretvalue")((read()))) }
  end)
end

local function restrictions(facts)
  custom(facts, "C_RestrictedActions", function()
    local keys = {}
    for k in pairs(need("C_RestrictedActions")) do keys[#keys + 1] = scalar(k) end
    table.sort(keys)
    return keys
  end)
  enum(facts, "Enum.AddOnRestrictionType")
  local api, types = lookup("C_RestrictedActions"), lookup("Enum.AddOnRestrictionType")
  if type(api) ~= "table" or type(types) ~= "table" then return end
  local names = {}
  for k in pairs(types) do names[#names + 1] = k end
  table.sort(names, function(a, b) return scalar(a) < scalar(b) end)
  for _, name in ipairs(names) do
    for _, fn in ipairs(RESTRICTION_CALLS) do
      if type(api[fn]) == "function" then
        add(facts, "C_RestrictedActions." .. fn .. "(Enum.AddOnRestrictionType." .. scalar(name) .. ")",
          capture(api[fn], types[name]))
      end
    end
  end
end

local function auras(facts)
  local list = ns.Campfire and ns.Campfire.AURAS
  if type(list) ~= "table" then
    add(facts, "ns.Campfire.AURAS", false, { "<missing>" })
    return
  end
  local get = lookup("C_UnitAuras.GetPlayerAuraBySpellID")
  local names = {}
  for name in pairs(list) do names[#names + 1] = name end
  table.sort(names, function(a, b) return scalar(a) < scalar(b) end)
  for _, name in ipairs(names) do
    local ids = type(list[name]) == "table" and list[name] or { list[name] }
    for _, id in ipairs(ids) do
      add(facts, scalar(name) .. " " .. label("C_UnitAuras.GetPlayerAuraBySpellID", id), capture(get, id))
    end
  end
end

-- Every zone and anchor map of the shipped conflicts once, in data order, with all of C_Map.GetMapInfo's
-- returns, so the record shows whether the client knows Shen'dralas (2652) and the pilot zones.
local function conflictMaps(facts)
  local data = ns.Data and ns.Data.Conflicts
  local list = type(data) == "table" and data.list
  if type(list) ~= "table" then
    add(facts, "ns.Data.Conflicts", false, { "<missing>" })
    return
  end
  local get, seen = lookup("C_Map.GetMapInfo"), {}
  for _, conflict in ipairs(list) do
    local anchor = type(conflict) == "table" and conflict.anchor
    local maps = { type(conflict) == "table" and conflict.zone, type(anchor) == "table" and anchor.m }
    for i = 1, 2 do
      local m = maps[i]
      if type(m) == "number" and not seen[m] then
        seen[m] = true
        add(facts, label("C_Map.GetMapInfo", m), capture(get, m))
      end
    end
  end
end

local function fieldText(t, key)
  local v, ok = Safe.Field(t, key)
  if not ok then return "<secret>" end
  return scalar(v)
end

local function tooltipLines(facts)
  custom(facts, "line types of " .. label("C_TooltipInfo.GetItemByID", TOOLTIP_ITEM), function()
    local data = need("C_TooltipInfo.GetItemByID")(TOOLTIP_ITEM)
    if type(data) ~= "table" or Safe.IsSecret(data) then return { scalar(data) } end
    local lines, ok = Safe.Field(data, "lines")
    if not ok then return { "<secret>" } end
    if type(lines) ~= "table" then return { scalar(lines) } end
    local out = {}
    for i, line in ipairs(lines) do
      out[i] = fieldText(line, "type") .. " " .. fieldText(line, "leftText")
    end
    return out
  end)
end

local function eventValidity(facts)
  custom(facts, "C_EventUtils.IsEventValid", function()
    local valid = need("C_EventUtils.IsEventValid")
    local out = {}
    for i, event in ipairs(EVENTS) do
      local ok, v = pcall(valid, event)
      out[i] = event .. "=" .. (ok and scalar(v) or "<error>")
    end
    return out
  end)
end

local function collect(facts)
  call(facts, "GetBuildInfo")
  value(facts, "WOW_PROJECT_ID")
  value(facts, "WOW_PROJECT_CAMELOT")
  call(facts, "C_AddOns.GetAddOnMetadata", ADDON, "X-TocVariant")
  call(facts, "GetLocale")

  call(facts, "UnitName", "player")
  call(facts, "UnitNameUnmodified", "player")
  call(facts, "UnitFullName", "player")
  call(facts, "GetRealmName")
  call(facts, "GetNormalizedRealmName")
  call(facts, "C_PlayerInfo.ShouldDisplaySurname")
  call(facts, "UnitGUID", "player")

  call(facts, "C_Secrets.ShouldUnitIdentityBeSecret", "party1")
  call(facts, "C_Secrets.ShouldAurasBeSecret", "player")
  secrecy(facts, 'UnitName("party1")', function() return need("UnitName")("party1") end)
  call(facts, "C_ChatInfo.InChatMessagingLockdown")
  restrictions(facts)
  call(facts, "C_CombatLog.IsCombatLogRestricted")
  call(facts, "C_Map.GetBestMapForUnit", "player")
  secrecy(facts, 'C_Map.GetBestMapForUnit("player")', function()
    return need("C_Map.GetBestMapForUnit")("player")
  end)

  call(facts, "IsTrialAccount")
  call(facts, "IsVeteranTrialAccount")
  -- Whether a battleground puts the player into an instance group, which Identity never counts (5.3).
  custom(facts, "IsInGroup, GetNumGroupMembers (home, instance)", function()
    local out = {}
    for _, key in ipairs({ "LE_PARTY_CATEGORY_HOME", "LE_PARTY_CATEGORY_INSTANCE" }) do
      local category = lookup(key)
      local okGroup, grouped = pcall(IsInGroup, category)
      local okSize, size = pcall(GetNumGroupMembers, category)
      out[#out + 1] = string.format("%s=%s: %s %s", key, scalar(category), okGroup and scalar(grouped) or "<error>",
        okSize and scalar(size) or "<error>")
    end
    return out
  end)

  for _, key in ipairs(RULES) do
    local path = "Enum.GameRule." .. key
    value(facts, path)
    add(facts, "C_GameRules.IsGameRuleActive(" .. path .. ")",
      capture(lookup("C_GameRules.IsGameRuleActive"), lookup(path)))
  end
  call(facts, "C_GameRules.GetForeverExperiencePreset")

  auras(facts)
  for _, f in ipairs({ 92, 93, LEGACY_FACTION }) do
    call(facts, "C_Reputation.GetFactionDataByID", f)
  end
  call(facts, "C_MajorFactions.GetMajorFactionData", LEGACY_FACTION)
  conflictMaps(facts)

  call(facts, "UnitCreatureType", "target")
  call(facts, "C_CreatureInfo.GetCreatureTypeInfo", 8)
  -- Whether UnitRace names a race for the unit's sex where C_CreatureInfo gives the masculine form
  -- (Names.Race, 5.7): target a female character of another race, e.g. a dwarf in deDE.
  call(facts, "UnitRace", "target")
  call(facts, "UnitSex", "target")
  custom(facts, "C_CreatureInfo.GetRaceInfo(<target race>)", function()
    local ok, _, _, id = pcall(UnitRace, "target")
    if not ok or Safe.IsSecret(id) or type(id) ~= "number" then return { scalar(id) } end
    local got, info = Safe.Call(C_CreatureInfo and C_CreatureInfo.GetRaceInfo, id)
    return { got and str(info) or "<missing>" }
  end)

  enum(facts, "Enum.BagIndex")
  tooltipLines(facts)
  eventValidity(facts)
end

local function flag(fn)
  local ok, v = Safe.Call(fn)
  if ok then return v and true or false end
end

local function context()
  local w = ns.Where()
  return {
    map = w.m, zone = ns.Where.Zone(w.m), instance = w.i,
    party = flag(IsInGroup), raid = flag(IsInRaid), combat = flag(InCombatLockdown),
  }
end

-- Facts that arrive later --------------------------------------------------------

local current, currentStored     -- the newest probe record; later facts land in it

local function late(what, ok, r)
  if not current then return end
  add(current.facts, what, ok, r)
  if not currentStored then ns.Print(what .. ": " .. table.concat(r, ", ")) end
end

local function onQuestAccepted(self, event, ...)
  self:UnregisterEvent(event)
  late(event, true, strings(...))
end

-- The pull (7.2): UNIT_FLAGS for target and player around PLAYER_REGEN_DISABLED, in dispatch order.
local buffered = {}
local pulling = false

local function moment()
  return { scalar(GetTime()), scalar(UnitAffectingCombat("player")), scalar(UnitAffectingCombat("target")) }
end

local function onFlags(_, event, unit)
  local what = "pull " .. event .. " " .. scalar(unit)
  if pulling then
    late(what, true, moment())
    return
  end
  local now = GetTime()
  buffered[#buffered + 1] = { at = now, what = what, r = moment() }
  while buffered[1] and (now - buffered[1].at > PULL_BEFORE or #buffered > PULL_KEEP) do
    table.remove(buffered, 1)
  end
end

local function endPull()
  pulling = false
  Probe:UnregisterEvent("UNIT_FLAGS", "target")
  Probe:UnregisterEvent("UNIT_FLAGS", "player")
  Probe:UnregisterEvent("PLAYER_REGEN_DISABLED")
end

local function onRegenDisabled(_, event)
  local now = GetTime()
  for _, item in ipairs(buffered) do
    if now - item.at <= PULL_BEFORE then late(item.what, true, item.r) end
  end
  buffered = {}
  late("pull " .. event, true, moment())
  pulling = true
  Probe:UnregisterEvent("PLAYER_REGEN_DISABLED")
  C_Timer.After(PULL_AFTER, function() ns:Call(Probe, "probe:pull", endPull) end)
end

local function watchNext()
  Probe:RegisterEvent("QUEST_ACCEPTED", onQuestAccepted)
  if pulling then return end
  buffered = {}
  Probe:RegisterUnitEvent("UNIT_FLAGS", "target", onFlags)
  Probe:RegisterUnitEvent("UNIT_FLAGS", "player", onFlags)
  Probe:RegisterEvent("PLAYER_REGEN_DISABLED", onRegenDisabled)
end

-- One HI through Comm and the raw sender string of its own echo (5.6).
local ECHO = "CHAT_MSG_ADDON own HI"
local echoMark = 0

local function onAddonMessage(self, event, prefix, text, channel, sender)
  if Safe.IsSecret(prefix) or prefix ~= ns.Comm.PREFIX then return end
  local kind, values = ns.Comm:Decode(text)
  if kind ~= "HI" or values[1] ~= Safe.UnitGUID("player") then return end
  self:UnregisterEvent(event)
  echoMark = echoMark + 1
  late(ECHO, true, { scalar(sender), scalar(channel) })
end

local function awaitEcho()
  echoMark = echoMark + 1
  local mark = echoMark
  Probe:RegisterEvent("CHAT_MSG_ADDON", onAddonMessage)
  C_Timer.After(ECHO_WAIT, function()
    if echoMark ~= mark then return end
    ns:Call(Probe, "probe:echo", function()
      Probe:UnregisterEvent("CHAT_MSG_ADDON")
      late(ECHO, false, { "<none>" })
    end)
  end)
end

-- A public service of a unit that may not be loaded; nil when it is missing or fails.
local function service(unit, method, ...)
  local fn = unit and unit[method]
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, unit, ...)
  if ok then return v end
end

local function hello()
  local char = ns.DB:Char()
  local archetype = service(ns.Profile, "Archetype", char) or "PRAGMATIST"
  local origin = service(ns.Profile, "Origin", char) or 0
  local version = tostring(ns.version or ""):gsub("[^%w.%-]", ""):sub(1, 20)
  return { Safe.UnitGUID("player"), archetype, origin, ns.Identity:Ruleset(), version ~= "" and version or "dev" }
end

local function sayHello(facts)
  local what = 'ns.Comm:Send("HI")'
  if not ns.Identity:InGroup() then
    add(facts, what, false, { "<not grouped>" })
    return
  end
  -- The HI is Fiction's (7.9): switched off, it never leaves; off for any reason after Fiction had been on,
  -- Comm would drop it unsent, which would read as a missing echo.
  local fiction = ns:GetModule("Fiction")
  if fiction and not fiction.enabled then
    local why = ns.Settings:Get("Fiction.enabled") ~= true and "off"
      or "unavailable: " .. table.concat(fiction.unavailable or {}, ", ")
    add(facts, what, false, { "<Shared fiction " .. why .. ">" })
    return
  end
  local before = {}
  for code, n in pairs(ns.Comm.stats.results) do before[code] = n end
  local ok, reason = ns.Comm:Send("HI", hello(), "PARTY")
  local r = { scalar(ok), scalar(reason) }
  local codes = {}
  for code, n in pairs(ns.Comm.stats.results) do
    local sent = n - (before[code] or 0)
    if sent > 0 then codes[#codes + 1] = "result " .. scalar(code) .. "=" .. sent end
  end
  table.sort(codes)
  for _, c in ipairs(codes) do r[#r + 1] = c end
  if ok and #codes == 0 then r[#r + 1] = "queued " .. ns.Comm:Queued() end
  add(facts, what, ok == true, r)
  if ok then awaitEcho() end
end

-- Running ----------------------------------------------------------------------

function Probe:Run()
  local facts = {}
  local record = { t = time(), context = context(), facts = facts }
  current, currentStored = record, false
  collect(facts)
  sayHello(facts)
  watchNext()
  currentStored = TestMode:Keep("probes", record, MAX_PROBES)
  if not currentStored then
    ns.Print(TestMode:NotStoredText())
    for _, fact in ipairs(facts) do ns.Print(fact.call .. ": " .. table.concat(fact.r, ", ")) end
  end
  ns.Print(ns.Format(L.TEST_PROBE_DONE, { count = #facts }))
  ns.Print(L.TEST_PROBE_NEXT)
  TestMode:SaveHint(currentStored)
  return record
end

ns.Slash:Register("probe", function() Probe:Run() end, "TEST_HELP_PROBE")

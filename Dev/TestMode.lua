local ADDON, ns = ...
-- luacheck: read globals C_Console

-- /ashmark test (7.10): runs every registered check, stores the record, takes the screenshot.
local TestMode = ns:NewService("TestMode")

local Safe = ns.Safe
local L = ns.L

local MAX_TESTS = 10
local LISTEN = 10                 -- seconds a run keeps collecting screenshot and blocked-action events
local MAX_DETAIL = 400
local LOCALE_KEYS_SHOWN = 10
local TEST_KIND = "test.secret"   -- never written: the secret check proves Log:Add drops it

local TEMPLATES = {
  "ButtonFrameTemplate", "PanelTabButtonTemplate", "WowScrollBoxList", "MinimalScrollBar",
  "UIPanelButtonTemplate", "InputBoxTemplate", "DialogBorderTemplate", "TooltipBackdropTemplate",
}
local FONTS = {
  "QuestTitleFont", "QuestFont", "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall",
  "GameFontDisable", "GameFontNormalHuge",
}
local SOUNDS = { "IG_QUEST_LOG_OPEN", "IG_QUEST_LOG_CLOSE", "IG_ABILITY_PAGE_TURN" }
local PARCHMENT = { "QuestBG-Parchment" }
local SERVICES = { "Core", "Combat", "Identity", "Names", "Watch", "Comm", "TestMode", "Probe" }
-- Read when C_Console cannot list them; names from the 12.0.5 CVar list, unverified on Forever.
local RESTRICTION_CVARS = {
  "addonChatRestrictionsForced", "addonCombatRestrictionsForced", "addonEncounterRestrictionsForced",
  "addonChallengeModeRestrictionsForced", "addonPvPMatchRestrictionsForced", "addonMapRestrictionsForced",
}
local LATE_EVENTS = { "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }

ns.Log:RegisterKind(TEST_KIND, { fields = { "v" } })

-- Saved data ---------------------------------------------------------------

local mine = setmetatable({}, { __mode = "k" })   -- records stored this session

local function saved()
  local db = AshmarkDB
  return type(db) == "table" and db or {}
end

local function devList(key)
  local dev = saved().dev
  local list = type(dev) == "table" and dev[key]
  if type(list) == "table" then return list end
end

-- Appends to AshmarkDB.dev[key]; false in read-only mode, where nothing is stored (4.4).
function TestMode:Keep(key, record, cap)
  local list = devList(key)
  if ns.DB.readOnly or not list then return false end
  ns.DB:Append(list, record, cap)
  mine[record] = true
  return true
end

-- A reload is a save that moves the files, so a fresh record warns instead (4.4).
function TestMode:SaveHint(stored)
  if stored then ns.Print(ns.DB.fresh and L.CORE_SV_NEW or L.TEST_RELOAD) end
end

local function dbState()
  local db = saved()
  local char = ns.DB:Char()
  return {
    created = type(db.created) == "number" and db.created or nil,
    fresh = ns.DB.fresh,
    readOnly = ns.DB.readOnly,
    recovered = db.recovered ~= nil and type(db.recovered) or nil,
    entries = ns.Log:Count(char),
    seq = ns.Log:Seq(char),
  }
end

local function commStats()
  local stats = ns.Comm.stats
  local results = {}
  for code, n in pairs(stats.results) do results[code] = n end
  return { sent = stats.sent, rejected = stats.rejected, dropped = stats.dropped, results = results }
end

-- The newest record that came through SavedVariables rather than from this session.
local function previousSession()
  local tests = devList("tests") or {}
  for i = #tests, 1, -1 do
    local record = tests[i]
    if type(record) == "table" and not mine[record] then return record end
  end
end

-- Core checks ----------------------------------------------------------------

local function join(list)
  return table.concat(list, ", ")
end

local function str(v)
  if Safe.IsSecret(v) then return "<secret>" end
  return tostring(v)
end

local function check(id, fn)
  ns.Test:Register(id, fn)
end

check("Core.forever", function()
  local build = ns.Compat.build
  return ns.Compat.IsForever(), string.format("project=%s camelot=%s interface=%s",
    str(WOW_PROJECT_ID), str(WOW_PROJECT_CAMELOT), str(build.interface))
end)

check("Core.toc", function()
  local variant = ns.Compat.tocVariant
  return variant == "Forever" or variant == "Camelot", str(variant)
end)

check("Core.build", function()
  local b = ns.Compat.build
  return true, string.format("%s.%s %s interface %s", str(b.version), str(b.build), str(b.date), str(b.interface))
end)

for _, cap in ipairs(ns.Compat.KEYS) do
  check("Compat." .. cap, function()
    local reason = ns.Compat.disabled[cap]
    if reason then return false, "disabled: " .. str(reason) end
    return ns.Compat.Has[cap] == true, str(ns.Compat.Has[cap])
  end)
end

-- Frames cannot be destroyed, so each template is built once per session.
local built = {}

local function buildTemplate(name)
  if not ns.Compat.Has.xmlInfo then return nil, "no C_XMLUtil.GetTemplateInfo" end
  local ok, info = Safe.Call(C_XMLUtil.GetTemplateInfo, name)
  if not ok or type(info) ~= "table" then return false, "missing" end
  local kind = Safe.Field(info, "type")
  if type(kind) ~= "string" then return false, "no type" end
  local made, frame = pcall(CreateFrame, kind, nil, UIParent, name)
  if not made then return false, kind .. ": " .. str(frame) end
  frame:Hide()
  return true, kind
end

for _, name in ipairs(TEMPLATES) do
  check("Template." .. name, function()
    built[name] = built[name] or { buildTemplate(name) }
    return built[name][1], built[name][2]
  end)
end

check("Core.parchment", function()
  local atlases = ns.UI and type(ns.UI.PARCHMENT_ATLASES) == "table" and ns.UI.PARCHMENT_ATLASES or PARCHMENT
  local found, parts = false, {}
  for _, atlas in ipairs(atlases) do
    local ok, info = Safe.Call(C_Texture and C_Texture.GetAtlasInfo, atlas)
    local has = ok and info ~= nil
    found = found or has
    parts[#parts + 1] = atlas .. "=" .. tostring(has)
  end
  return found, join(parts)
end)

local function missingOf(names, present)
  local missing = {}
  for _, name in ipairs(names) do
    if not present(name) then missing[#missing + 1] = name end
  end
  if #missing == 0 then return true, "all " .. #names end
  return false, "missing: " .. join(missing)
end

check("Core.fonts", function()
  return missingOf(FONTS, function(name)
    local font = _G[name]
    local ok, kind = pcall(function() return font:GetObjectType() end)
    return ok and kind == "Font"
  end)
end)

check("Core.sounds", function()
  return missingOf(SOUNDS, function(name)
    return type(SOUNDKIT) == "table" and type(SOUNDKIT[name]) == "number"
  end)
end)

check("Core.locale", function()
  local code = GetLocale()
  local missing = ns.Locale:Missing(code)
  if #missing == 0 then return true, code .. ": complete" end
  local shown = {}
  for i = 1, math.min(#missing, LOCALE_KEYS_SHOWN) do shown[i] = missing[i] end
  return false, string.format("%s: %d missing: %s%s", code, #missing, join(shown),
    #missing > LOCALE_KEYS_SHOWN and ", ..." or "")
end)

check("Core.identity", function()
  local p = ns.Identity:Player()
  local detail = string.format("guid=%s name=%s surname=%s source=%s class=%s race=%s sex=%s faction=%s "
    .. "level=%s ruleset=%s", str(p.guid), str(p.name), str(p.surname), str(p.surnameSource), str(p.class),
    str(p.race), str(p.sex), str(p.faction), str(p.level), str(p.ruleset))
  return p.guid ~= nil and p.name ~= nil and p.surname ~= nil, detail
end)

check("Core.savedVariables", function()
  local s = dbState()
  local detail = string.format("created=%s fresh=%s readOnly=%s recovered=%s entries=%s seq=%s",
    str(s.created), str(s.fresh), str(s.readOnly), str(s.recovered), str(s.entries), str(s.seq))
  local previous = previousSession()
  if previous then return true, detail .. " previous=" .. str(previous.t) end
  return nil, detail .. " previous=none: /reload, then run /ashmark test again"
end)

-- Each probe returns true, false, or nil when it cannot run here.
local function secretProbes(s, t)
  local holder = { a = s }
  return {
    { "IsSecret", function() return Safe.IsSecret(s) == true and Safe.IsSecret(t) == true end },
    { "Value", function() local v, ok = Safe.Value(s) return v == nil and ok == false end },
    { "Bool", function() return Safe.Bool(s) == nil end },
    { "Call", function() return Safe.Call(function() return s end) == false end },
    { "Field", function()
      local v1, ok1 = Safe.Field(t, "a")
      local v2, ok2 = Safe.Field(holder, "a")
      return v1 == nil and ok1 == false and v2 == nil and ok2 == false
    end },
    { "Fields", function() return Safe.Fields(t, "a") == nil and Safe.Fields(holder, "a") == nil end },
    { "Clean", function() return Safe.Clean(t) == nil and Safe.Clean(holder) == nil end },
    { "Surname", function() return Safe.Surname(s) == nil end },
    { "Log:Add", function()
      if not ns.ready or ns.DB.readOnly then return nil end
      local before = ns.Core:Stat("secretDropped")
      local entry = ns.Log:Add(TEST_KIND, { v = s }, { noWhere = true })
      local dropped = ns.Core:Stat("secretDropped") - before
      -- The test's own drop is not a finding.
      if dropped > 0 then ns.Core:Stat("secretDropped", -dropped) end
      return entry == nil and dropped == 1
    end },
    { "Comm:Decode", function() return ns.Comm:Decode(secretwrap("1|PR|Player-1-00000001|0|0|0")) == nil end },
  }
end

check("Core.secrets", function()
  if type(secretwrap) ~= "function" then return nil, "no secretwrap" end
  local ok, s, t = pcall(function() return secretwrap("Ashmark"), secretwrap({ a = 1 }) end)
  if not ok then return false, "secretwrap: " .. str(s) end
  local failed, skipped = {}, {}
  for _, probe in ipairs(secretProbes(s, t)) do
    local done, result = pcall(probe[2])
    if not done or result == false then
      failed[#failed + 1] = probe[1]
    elseif result == nil then
      skipped[#skipped + 1] = probe[1]
    end
  end
  local detail = #failed == 0 and "every Safe function, Log:Add and Comm:Decode refuse secrets"
    or ("not refused: " .. join(failed))
  if #skipped > 0 then detail = detail .. "; skipped: " .. join(skipped) end
  return #failed == 0, detail
end)

local function restrictionNames()
  local names, seen = {}, {}
  local function add(name)
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  local ok, commands = Safe.Call(C_Console and C_Console.GetAllCommands)
  if ok and type(commands) == "table" then
    for _, command in ipairs(commands) do
      local name = Safe.Field(command, "command")
      if type(name) == "string" and name:match("^addon%w*RestrictionsForced$") then add(name) end
    end
  end
  for _, name in ipairs(RESTRICTION_CVARS) do add(name) end
  table.sort(names)
  return names
end

local function cvar(name)
  local ok, value = Safe.Call(C_CVar and C_CVar.GetCVar, name)
  if not ok then ok, value = Safe.Call(GetCVar, name) end
  if ok then return value end
end

check("Core.restrictionCVars", function()
  local parts = {}
  for _, name in ipairs(restrictionNames()) do
    local value = cvar(name)
    if value ~= nil then parts[#parts + 1] = name .. "=" .. str(value) end
  end
  if #parts == 0 then return nil, "none of these CVars exist" end
  return true, join(parts)
end)

check("Core.comm", function()
  local stats = ns.Comm.stats
  local codes = {}
  for code, n in pairs(stats.results) do codes[#codes + 1] = str(code) .. ":" .. str(n) end
  table.sort(codes)
  local reason = ns.Compat.disabled.canSend
  return ns.Compat.Has.canSend == true, string.format(
    "canSend=%s%s addonMessages=%s share=%s sent=%s rejected=%s dropped=%s queued=%s results=%s",
    str(ns.Compat.Has.canSend), reason and (" (" .. str(reason) .. ")") or "", str(ns.Compat.Has.addonMessages),
    str(ns.Settings:Get("Comm.share")), str(stats.sent), str(stats.rejected), str(stats.dropped),
    str(ns.Comm:Queued()), #codes > 0 and join(codes) or "none")
end)

check("Core.blocked", function()
  local tests = devList("tests")
  local last = tests and tests[#tests]
  local since = type(last) == "table" and type(last.t) == "number" and last.t or nil
  local hits = {}
  for _, b in ipairs(devList("blocked") or {}) do
    if type(b) == "table" and (not since or (type(b.t) == "number" and b.t >= since)) then
      hits[#hits + 1] = str(b.event) .. " " .. str(b.fn)
    end
  end
  if #hits > 0 then return false, join(hits) end
  return true, since and "none since the last run" or "none"
end)

check("Core.events", function()
  local missing = {}
  for _, name in ipairs(SERVICES) do
    local service = ns[name]
    for _, event in ipairs(service and service.missingEvents or {}) do
      missing[#missing + 1] = name .. ":" .. event
    end
  end
  if #missing > 0 then return false, "missing: " .. join(missing) end
  return true, "every Core event is valid"
end)

-- Modules can be created after this file loads (specs do), so their checks are built per run.
local function moduleCheck(M)
  return function()
    local missing = type(M.missingEvents) == "table" and #M.missingEvents > 0
      and ("; missing events: " .. join(M.missingEvents)) or ""
    if M.unavailable then return false, "unavailable: " .. join(M.unavailable) .. missing end
    if not M.enabled then return nil, "off" .. missing end
    return missing == "", "enabled" .. missing
  end
end

-- Running ----------------------------------------------------------------------

local function trace(err)
  if debugstack then return tostring(err) .. "\n" .. debugstack(2) end
  return tostring(err)
end

local function detailText(v)
  if v == nil then return nil end
  local s = str(v)
  if #s > MAX_DETAIL then s = s:sub(1, MAX_DETAIL) .. "..." end
  return s
end

-- The error wrapper (3.6) with the message kept for the record; the report counts against TestMode,
-- so a failing check never disables a module.
local function runCheck(id, fn)
  local done, ok, detail = xpcall(fn, trace)
  if not done then
    ns:Report(TestMode, "test:" .. id, ok)
    return { id = id, ok = false, detail = detailText("error: " .. (tostring(ok):match("^[^\n]*") or "")) }
  end
  if Safe.IsSecret(ok) then return { id = id, ok = false, detail = "<secret>" } end
  if ok ~= nil then ok = ok == true end
  return { id = id, ok = ok, detail = detailText(detail) }
end

local function runAll()
  local list = {}
  for _, c in ipairs(ns.Test.checks) do list[#list + 1] = { id = c.id, fn = c.fn } end
  for M in ns:Modules() do list[#list + 1] = { id = "Module." .. M.name, fn = moduleCheck(M) } end
  local results = {}
  for i, c in ipairs(list) do results[i] = runCheck(c.id, c.fn) end
  return results
end

local function line(result)
  local state = result.ok == true and L.TEST_PASS or result.ok == false and L.TEST_FAIL or L.TEST_SKIP
  return ns.Format(L.TEST_LINE, { state = state, id = result.id, detail = result.detail or "-" })
end

-- Failed checks, or every check when nothing is stored, then the counts.
local function report(results, stored)
  if not stored then ns.Print(L.TEST_NOT_STORED) end
  local passed, failed, skipped = 0, 0, 0
  for _, result in ipairs(results) do
    if result.ok == true then
      passed = passed + 1
    elseif result.ok == false then
      failed = failed + 1
    else
      skipped = skipped + 1
    end
    if not stored or result.ok == false then ns.Print(line(result)) end
  end
  ns.Print(ns.Format(L.TEST_SUMMARY, { passed = passed, failed = failed, skipped = skipped }))
end

-- The chronicle next to the real quest dialog; Ashmark never opens Blizzard windows itself.
local function showFrame()
  local questShown = QuestFrame ~= nil and Safe.Bool(QuestFrame:IsShown()) == true
  local main = ns.UI and ns.UI.MainFrame
  if main then
    ns.Combat.Run("test:frame", function()
      main:Show("chronicle")
      if questShown and AshmarkFrame then
        AshmarkFrame:ClearAllPoints()
        AshmarkFrame:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", 0, 0)
      end
    end)
  end
  if not questShown then ns.Print(L.TEST_OPEN_QUEST_DIALOG) end
  return questShown
end

-- Late events ------------------------------------------------------------------

local watched, watchedAt, watchedStored
local generation = 0

local function late(what)
  if not watchedStored then ns.Print(ns.Format(L.TEST_LATE, { what = what })) end
end

local function onScreenshot(_, event)
  if not watched then return end
  watched.screenshot = event == "SCREENSHOT_SUCCEEDED" and "succeeded" or "failed"
  late("screenshot " .. watched.screenshot)
end

local function onBlocked(_, event, addon, fn)
  if not watched or Safe.Value(addon) ~= ADDON then return end
  fn = Safe.Value(fn)
  fn = type(fn) == "string" and fn or nil
  watched.blocked = watched.blocked or {}
  table.insert(watched.blocked, { event = event, fn = fn, after = math.floor(GetTime() - watchedAt) })
  late(event .. " " .. str(fn))
end

local function stopListening()
  watched = nil
  for _, event in ipairs(LATE_EVENTS) do TestMode:UnregisterEvent(event) end
end

local function listen(record, stored)
  watched, watchedAt, watchedStored = record, GetTime(), stored
  generation = generation + 1
  local mark = generation
  TestMode:RegisterEvent("SCREENSHOT_SUCCEEDED", onScreenshot)
  TestMode:RegisterEvent("SCREENSHOT_FAILED", onScreenshot)
  TestMode:RegisterEvent("ADDON_ACTION_BLOCKED", onBlocked)
  TestMode:RegisterEvent("ADDON_ACTION_FORBIDDEN", onBlocked)
  C_Timer.After(LISTEN, function()
    if generation == mark then ns:Call(TestMode, "test:listen", stopListening) end
  end)
end

-- The slash handler runs on the key press, the hardware event Screenshot() needs.
local function screenshot(record)
  if not ns.Compat.Has.screenshot then
    record.screenshot = "missing"
    return
  end
  local ok, err = pcall(Screenshot)
  record.screenshot = ok and "called" or ("error: " .. str(err))
end

function TestMode:Run()
  if InCombatLockdown() then
    ns.Print(L.TEST_NOT_IN_COMBAT)
    return nil
  end
  local build = {}
  for k, v in pairs(ns.Compat.build) do build[k] = v end
  local record = {
    t = time(), build = build, locale = GetLocale(), project = WOW_PROJECT_ID, tocVariant = ns.Compat.tocVariant,
    db = dbState(), comm = commStats(), results = runAll(),
  }
  local stored = self:Keep("tests", record, MAX_TESTS)
  report(record.results, stored)
  record.questDialog = showFrame()
  screenshot(record)
  listen(record, stored)
  self:SaveHint(stored)
  return record
end

ns.Slash:Register("test", function() TestMode:Run() end, "TEST_HELP")

local _, ns = ...

-- Module 6 (7.6): a rest at a camp. Sitting down at a camp (WELCOME) starts a rest; its benefit
-- (BENEFITS) after a minute completes it, writes rest.camp and may close the chapter, with a notice
-- in the middle of the screen and the page-turn sound.
local M = ns:NewModule("Campfire", {
  requires = { "auras" },
  locale = "CAMP",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

-- Wowhead Forever spell IDs, unverified until the probe confirms them.
M.AURAS = {
  NEARBY = 1283391,     -- passive, 100 yd
  WELCOME = 1289723,    -- while sitting at a camp
  BENEFITS = 1229741,   -- after one minute at a camp
  BOOSTED = 1229451,    -- Camp Tent debuff
  BEDROLL = {},         -- Cozy Sleeping Bag "Well-Rested"; filled from the probe, empty until verified
}

local NAMED = { "NEARBY", "WELCOME", "BENEFITS", "BOOSTED" }
local STALE = 600                -- seconds a rest waits for its benefit
local CHAPTER_ENTRIES = 20
local CHAPTER_AGE = 1800
local EMPTY = {}

local tracked, bedrolls = {}, {}  -- spell IDs, built from AURAS in OnInitialize
local WELCOME, BENEFITS
local present, now = {}, {}      -- [spellID] = bool; swapped after every complete read
local seeded = false             -- present holds a complete read

-- State -----------------------------------------------------------------------------

local function fresh(rest)
  return type(rest) == "table" and type(rest.started) == "number" and time() - rest.started <= STALE
end

local function charState()
  local char = M:Char()
  local state = char and char.state
  if type(state) == "table" then return char, state end
end

-- The open chapter is due when it holds CHAPTER_ENTRIES entries or its first entry is CHAPTER_AGE old, aged
-- by the realm's clock that stamped it (ns.Util.Now, 4.2).
local function chapterDue(char)
  local chapters = type(char.chapters) == "table" and char.chapters or EMPTY
  local last = chapters[#chapters]
  local to = last and last.to or 0
  if ns.Log:Seq(char) - to >= CHAPTER_ENTRIES then return true end
  local first = ns.Log:Iter(char, to + 1)()
  return first ~= nil and ns.Util.Now() - first.t >= CHAPTER_AGE
end

local function party()
  local guids = {}
  for guid in pairs(ns.Identity:Group("party")) do guids[#guids + 1] = guid end
  table.sort(guids)
  return guids
end

local function closeChapter(char)
  if not chapterDue(char) then return end
  local chapter = ns.Log:CloseChapter(party())
  if not chapter then return end
  local place = chapter.m and (ns.Where.Zone(chapter.m) or chapter.m)
  ns.UI.Notice:Show(ns.Format(L.CAMP_CHAPTER_CLOSED, {
    roman = ns.Util.Roman(chapter.no), place = ns.Names.Map(place),
  }))
  ns.UI:Sound("IG_ABILITY_PAGE_TURN")
end

-- Check (7.6) ------------------------------------------------------------------------

local function appeared(id)
  return now[id] and not present[id]
end

local function vanished(id)
  return present[id] and not now[id]
end

-- A bedroll aura is there now and none was before: one swapped for another is the same rest.
local function bedrollBegins()
  local before, after = false, false
  for i = 1, #bedrolls do
    local id = bedrolls[i]
    before = before or present[id] == true
    after = after or now[id] == true
  end
  return after and not before
end

-- Fills `now` for every tracked ID; false as soon as a read fails or comes back secret.
local function read()
  local get = C_UnitAuras.GetPlayerAuraBySpellID
  for i = 1, #tracked do
    local id = tracked[i]
    local ok, aura = Safe.Call(get, id)
    if not ok then return false end
    now[id] = aura ~= nil
  end
  return true
end

local function transitions(char, state)
  if appeared(BENEFITS) and state.rest then
    local entry = ns.Log:Add("rest.camp", {})
    state.rest = nil
    if entry then closeChapter(char) end
  end
  if vanished(WELCOME) and state.rest then state.rest = nil end
  if appeared(WELCOME) then state.rest = { started = time() } end
  if bedrollBegins() and ns.Log:Add("rest.bedroll", {}) then closeChapter(char) end
end

-- No allocation on the way through: UNIT_AURA fires often (3.9). The first complete read after a
-- login, a reload or enabling only seeds `present`, so a reload at a camp writes nothing.
local function check()
  if InCombatLockdown() or Safe.AurasRestricted("player") == true then return end
  local char, state = charState()
  if not state or not read() then return end
  if not fresh(state.rest) then state.rest = nil end
  if seeded then
    transitions(char, state)
  else
    seeded = true
    if not now[WELCOME] then state.rest = nil end
  end
  present, now = now, present
end

-- Public services (3.8) ------------------------------------------------------------------

function M:IsResting()
  local _, state = charState()
  return (state and fresh(state.rest)) or present[WELCOME] == true
end

-- Test checks (7.10) -----------------------------------------------------------------------

local function checkAuras()
  local get = C_Spell and C_Spell.GetSpellName
  if type(get) ~= "function" then return nil, "no C_Spell.GetSpellName" end
  local named, missing = {}, {}
  local function resolve(label, id)
    local ok, name = Safe.Call(get, id)
    if ok and type(name) == "string" and name ~= "" then
      named[#named + 1] = string.format("%s %d %s", label, id, name)
    else
      missing[#missing + 1] = string.format("%s %d", label, id)
    end
  end
  for _, key in ipairs(NAMED) do resolve(key, M.AURAS[key]) end
  for _, id in ipairs(M.AURAS.BEDROLL) do resolve("BEDROLL", id) end
  if #M.AURAS.BEDROLL == 0 then named[#named + 1] = "BEDROLL none verified" end
  local detail = table.concat(named, ", ")
  if #missing > 0 then return false, "unresolved: " .. table.concat(missing, ", ") .. "; " .. detail end
  return true, detail
end

local function checkPresent()
  if M.unavailable then return false, "unavailable: " .. table.concat(M.unavailable, ", ") end
  if not M.enabled then return nil, "off" end
  if not seeded then return nil, "not read yet: in combat, restricted or secret" end
  local parts = {}
  for _, key in ipairs(NAMED) do parts[#parts + 1] = key .. "=" .. tostring(present[M.AURAS[key]] == true) end
  for _, id in ipairs(bedrolls) do parts[#parts + 1] = "BEDROLL " .. id .. "=" .. tostring(present[id] == true) end
  local _, state = charState()
  local rest = state and state.rest
  parts[#parts + 1] = fresh(rest) and string.format("rest %d s", time() - rest.started) or "rest none"
  parts[#parts + 1] = "resting " .. tostring(M:IsResting())
  return true, table.concat(parts, ", ")
end

-- Lifecycle ----------------------------------------------------------------------------------

function M:OnInitialize()
  local auras = self.AURAS
  WELCOME, BENEFITS = auras.WELCOME, auras.BENEFITS
  for _, key in ipairs(NAMED) do tracked[#tracked + 1] = auras[key] end
  for _, id in ipairs(auras.BEDROLL) do
    tracked[#tracked + 1] = id
    bedrolls[#bedrolls + 1] = id
  end
  ns.Log:RegisterKind("rest.camp", { fields = {} })
  ns.Log:RegisterKind("rest.bedroll", { fields = {} })
  ns.Test:Register("Campfire.auras", checkAuras)
  ns.Test:Register("Campfire.present", checkPresent)
end

function M:OnEnable()
  self:RegisterUnitEvent("UNIT_AURA", "player", check)
  self:RegisterEvent("PLAYER_REGEN_ENABLED", check)
end

-- A UNIT_AURA between PLAYER_LOGIN and the world being ready may have seeded already; the seed
-- that counts is this one.
function M:OnWorldReady()
  seeded = false
  check()
end

function M:OnDisable()
  seeded = false
  for id in pairs(present) do present[id] = nil end
end

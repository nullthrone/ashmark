local _, ns = ...

-- Module 2 (7.2): who the character is, read from what it does. Three axes in [-100, 100], kept as
-- incremental accumulators in char.profile that halve every 30 days; nothing is rebuilt from the log.
-- Positive habitat is wild, positive mercy merciful. The combat log is closed, so Mercy is an
-- approximation: a calm neutral target the player was fighting when it died.
local M = ns:NewModule("Profile", {
  optional = { "map", "critterType" },
  locale = "PROFILE",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local WEIGHTS = {
  fidelity = {
    turnin = 2,             -- a turn-in on the side this character was allied with before it
    kept = 5,               -- an alliance held 7 days since it began or since its last award
    violation = -25,
    switched = -15,         -- a violation written with o == 1 (the opportunist wording)
    abandon = -2,
    loot = -1,              -- per 10 gold of loot beyond quest gold in a day ...
    lootMax = -5,           -- ... at most this much
  },
  habitat = {
    rest = 6,               -- rest.camp, rest.bedroll
    wild = 1,               -- per 600 s outdoors and not resting
    civil = -1,             -- per 600 s resting
    capital = -1,           -- a turn-in in one of CAPITAL_MAPS
  },
  mercy = {
    calmDay = 1,            -- a played day without a kill
    neutral = -3,
    critter = -2,
  },
}
local W = WEIGHTS

-- Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity
local CAPITAL_MAPS = { 1453, 1454, 1455, 1456, 1457, 1458 }

local AXES = { "fidelity", "habitat", "mercy" }       -- also the archetype tie order
local ARCHETYPES = {
  fidelity = { "OATHKEEPER", "OPPORTUNIST" },
  habitat = { "WANDERER", "TOWNSFOLK" },
  mercy = { "GENTLE", "RUTHLESS" },
}
local ARCHETYPE_AT = 34
local HALF_LIFE = 30 * 86400
local TICKER = "Profile"
local TICK = 60
local BLOCK = 600                 -- seconds of wild or civil time per habitat point
local KEPT_AFTER = 7 * 86400
local ORIGIN_UNTIL = 72000        -- Core.playedSec: the first 20 hours decide the origin
local GOLD_STEP = 100000          -- 10 gold in copper
local NEUTRAL = 4                 -- UnitReaction
local CRITTER = 8                 -- creature type ID
local DAY_COUNTS = { "kills", "loot", "quest" }

local capital = {}
for _, m in ipairs(CAPITAL_MAPS) do capital[m] = true end

-- State ---------------------------------------------------------------------------

local function newDay()
  return { key = date("%Y-%m-%d"), kills = 0, loot = 0, quest = 0 }
end

local function number(t, key)
  local v = t[key]
  if type(v) ~= "number" or v ~= v then t[key] = 0 end
end

-- char.profile (4.1), repaired field by field on every use, so a wiped or partial record starts over.
local function record(char)
  local p = char.profile
  if type(p) ~= "table" then
    p = {}
    char.profile = p
  end
  if type(p.raw) ~= "table" then p.raw = {} end
  for _, axis in ipairs(AXES) do
    number(p, axis)
    number(p.raw, axis)
  end
  number(p, "wild")
  number(p, "civil")
  if type(p.asOf) ~= "number" then p.asOf = time() end
  if type(p.kept) ~= "table" then p.kept = {} end
  if type(p.day) ~= "table" or type(p.day.key) ~= "string" then p.day = newDay() end
  for _, key in ipairs(DAY_COUNTS) do number(p.day, key) end
  return p
end

local function decay(asOf, now)
  if type(asOf) ~= "number" or now <= asOf then return 1 end
  return 0.5 ^ ((now - asOf) / HALF_LIFE)
end

local function shown(raw)
  if raw ~= raw then return 0 end
  return ns.Util.Clamp(ns.Util.Round(raw), -100, 100)
end

-- Decays every raw value to now: before every change (7.2).
local function begin(char)
  local p = record(char)
  local now = time()
  local f = decay(p.asOf, now)
  if f < 1 then
    for _, axis in ipairs(AXES) do p.raw[axis] = p.raw[axis] * f end
    p.asOf = now
  end
  return p
end

local function bump(p, axis, delta)
  p.raw[axis] = p.raw[axis] + delta
end

-- Stores the displayed integers; PROFILE_CHANGED fires when one of them moved.
local function commit(p)
  local moved = false
  for _, axis in ipairs(AXES) do
    local v = shown(p.raw[axis])
    if v ~= p[axis] then
      p[axis] = v
      moved = true
    end
  end
  if moved then M:Fire("PROFILE_CHANGED", { fidelity = p.fidelity, habitat = p.habitat, mercy = p.mercy }) end
end

-- Public services (3.8) ---------------------------------------------------------------
-- Pure reads: they decay a copy and never write, so the House tab, Fiction and Rumours can call them for
-- any character, in read-only mode and while the module is off.

function M:Axes(char)
  local axes = { fidelity = 0, habitat = 0, mercy = 0 }
  local p = type(char) == "table" and char.profile
  local raw = type(p) == "table" and p.raw
  if type(raw) ~= "table" then return axes end
  local f = decay(p.asOf, time())
  for _, axis in ipairs(AXES) do
    if type(raw[axis]) == "number" then axes[axis] = shown(raw[axis] * f) end
  end
  return axes
end

-- The axis with the largest absolute value of at least 34; ties keep the earlier axis.
function M:Archetype(char)
  local axes = M:Axes(char)
  local key, best = "PRAGMATIST", ARCHETYPE_AT - 1
  for _, axis in ipairs(AXES) do
    local v = axes[axis]
    if math.abs(v) > best then
      best = math.abs(v)
      key = ARCHETYPES[axis][v > 0 and 1 or 2]
    end
  end
  return key
end

function M:IsOpportunist(char)
  return M:Axes(char).fidelity <= -ARCHETYPE_AT
end

-- The zone with the most seconds; ties go to the lower map ID, so the answer never depends on pairs().
local function leader(seconds)
  if type(seconds) ~= "table" then return nil end
  local best, most
  for zone, s in pairs(seconds) do
    if type(zone) == "number" and type(s) == "number" and (not most or s > most or (s == most and zone < best)) then
      best, most = zone, s
    end
  end
  return best
end

function M:Origin(char)
  local p = type(char) == "table" and char.profile
  if type(p) ~= "table" then return nil end
  if type(p.origin) == "number" then return p.origin end
  return leader(p.originSec)
end

-- Log inputs --------------------------------------------------------------------------

-- Another unit's public service (3.8), looked up at call time; nothing if the unit or the call is missing.
local function ask(unit, method, ...)
  local service = ns[unit]
  return select(2, Safe.Call(service and service[method], service, ...))
end

-- The side held before this turn-in. Conflicts handles LOG_ADDED first, so a violation or an alliance
-- formed by the turn-in already holds the side here, but began at a later n (3.7).
local function forHeldSide(char, entry)
  local id, side = ask("Conflicts", "SideOf", entry.q)
  if not id then return false end
  local held, began = ask("Conflicts", "Alliance", char, id)
  return held == side and type(began) == "number" and began < entry.n
end

local function inCapital(entry)
  local zone = ns.Where.Zone(entry.m)
  return zone ~= nil and capital[zone] == true
end

local function rest(p)
  bump(p, "habitat", W.habitat.rest)
end

local function kill(weight)
  return function(p)
    bump(p, "mercy", weight)
    p.day.kills = p.day.kills + 1
  end
end

local RULES = {
  ["quest.turnin"] = function(p, entry, char)
    if forHeldSide(char, entry) then bump(p, "fidelity", W.fidelity.turnin) end
    if inCapital(entry) then bump(p, "habitat", W.habitat.capital) end
  end,
  ["quest.abandon"] = function(p)
    bump(p, "fidelity", W.fidelity.abandon)
  end,
  violation = function(p, entry)
    bump(p, "fidelity", entry.o == 1 and W.fidelity.switched or W.fidelity.violation)
  end,
  ["rest.camp"] = rest,
  ["rest.bedroll"] = rest,
  ["kill.neutral"] = kill(W.mercy.neutral),
  ["kill.critter"] = kill(W.mercy.critter),
  gold = function(p, entry)
    if (entry.src == "loot" or entry.src == "quest") and type(entry.c) == "number" then
      p.day[entry.src] = p.day[entry.src] + entry.c
    end
  end,
}

local function onLogAdded(_, _, entry, char)
  local rule = RULES[entry.k]
  if not rule then return end
  local p = begin(char)
  rule(p, entry, char)
  commit(p)
end

-- Days and the ticker -------------------------------------------------------------------

-- Alliances held 7 days since since[C] or the last award, whichever is later; at most one award each per day.
-- kept[C] marks the end of the 7 days awarded, not the roll, so a late day roll never stretches the next ones.
local function keptAlliances(char, p, now)
  local rec = type(char.conflicts) == "table" and char.conflicts
  local allied = rec and type(rec.allied) == "table" and rec.allied
  local since = rec and type(rec.since) == "table" and rec.since
  if not (allied and since) then return 0 end
  local count = 0
  for id, side in pairs(allied) do
    local from = since[id]
    if (side == "A" or side == "B") and type(from) == "number" then
      local last = p.kept[id]
      if type(last) == "number" and last > from then from = last end
      if now - from >= KEPT_AFTER then
        p.kept[id] = from + math.floor((now - from) / KEPT_AFTER) * KEPT_AFTER
        count = count + 1
      end
    end
  end
  return count
end

-- A new calendar day settles the finished one: loot gold beyond quest gold, a calm day, kept alliances.
local function rollDay(char)
  local p = begin(char)
  local day = p.day
  if day.key == date("%Y-%m-%d") then return p end
  local beyond = day.loot - day.quest
  if beyond >= GOLD_STEP then
    bump(p, "fidelity", math.max(W.fidelity.loot * math.floor(beyond / GOLD_STEP), W.fidelity.lootMax))
  end
  if day.kills == 0 then bump(p, "mercy", W.mercy.calmDay) end
  bump(p, "fidelity", W.fidelity.kept * keptAlliances(char, p, time()))
  p.day = newDay()
  return p
end

local function sampleHabitat(p)
  local resting = Safe.Bool(IsResting())
  if resting == true then
    p.civil = p.civil + TICK
  elseif resting == false and Safe.Bool(IsOutdoors()) == true then
    p.wild = p.wild + TICK
  end
  if p.wild >= BLOCK then
    p.wild = p.wild - BLOCK
    bump(p, "habitat", W.habitat.wild)
  end
  if p.civil >= BLOCK then
    p.civil = p.civil - BLOCK
    bump(p, "habitat", W.habitat.civil)
  end
end

-- Seconds per zone over the first 20 played hours; then the leader becomes the origin for good.
local function sampleOrigin(char, p)
  if p.origin ~= nil then return end
  local played = type(char.stats) == "table" and tonumber(char.stats["Core.playedSec"]) or 0
  if played < ORIGIN_UNTIL then
    local zone = ns.Where.Zone(ns.Where().m)
    if zone then
      local seconds = type(p.originSec) == "table" and p.originSec or {}
      p.originSec = seconds
      seconds[zone] = (tonumber(seconds[zone]) or 0) + TICK
    end
  elseif p.originSec ~= nil then
    p.origin = leader(p.originSec)
    p.originSec = nil
  end
end

local function tick()
  local char = M:Char()
  if not char or Safe.Bool(UnitIsAFK("player")) ~= false then return end
  local p = rollDay(char)
  if ns.Compat.Has.map then
    sampleHabitat(p)
    sampleOrigin(char, p)
  end
  commit(p)
end

local ticker = M:Wrap(TICKER, tick)

-- Kill approximation (no combat log) ---------------------------------------------------

local cand                        -- { critter } while the target is a kill candidate
local frozen = false              -- PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED: no new samples
local watching = false            -- UNIT_HEALTH for target is registered
local critterName                 -- C_CreatureInfo.GetCreatureTypeInfo(8).name, with critterType
local typeIds                     -- nil until a creature type was read; then whether it came with its ID

local function readCritterName()
  if not ns.Compat.Has.critterType then return nil end
  local _, info = Safe.Call(C_CreatureInfo.GetCreatureTypeInfo, CRITTER)
  local name = Safe.Field(info, "name")
  if type(name) == "string" and name ~= "" then return name end
end

-- Creature type 8: the second return of UnitCreatureType when it is a number, otherwise the first return
-- against the client's own name for type 8. True, false, or nil when a return is secret.
local function isCritter(unit)
  local ok, name, id = pcall(UnitCreatureType, unit)
  if not ok then return false end
  if Safe.IsSecret(name) or Safe.IsSecret(id) then return nil end
  if type(id) == "number" then
    typeIds = true
    return id == CRITTER
  end
  if type(name) == "string" and typeIds == nil then typeIds = false end
  return critterName ~= nil and name == critterName
end

local onHealth

local function watch(on)
  if on == watching then return end
  watching = on
  if on then
    M:RegisterUnitEvent("UNIT_HEALTH", "target", onHealth)
  else
    M:UnregisterEvent("UNIT_HEALTH", "target")
  end
end

-- Any secret read clears the candidate and is counted.
local function drop(secret)
  if secret then M:Stat("killSecret", 1) end
  cand = nil
  watch(false)
end

-- Live combat of the player, never InCombatLockdown() or a REGEN flag; nil (secret) counts as in combat.
local function playerInCombat()
  return Safe.Bool(UnitAffectingCombat("player"))
end

-- A candidate from the target: it exists, lives, is neutral, out of combat and not player-controlled.
-- Returns the candidate or nil, and true when a read was secret.
local function sample()
  local exists = Safe.Bool(UnitExists("target"))
  if exists ~= true then return nil, exists == nil end
  local dead = Safe.Bool(UnitIsDead("target"))
  if dead ~= false then return nil, dead == nil end
  local reaction, readable = Safe.Value(UnitReaction("target", "player"))
  if not readable then return nil, true end
  if reaction ~= NEUTRAL then return nil end
  local combat = Safe.Bool(UnitAffectingCombat("target"))
  if combat ~= false then return nil, combat == nil end
  local controlled = Safe.Bool(UnitPlayerControlled("target"))
  if controlled ~= false then return nil, controlled == nil end
  local critter = isCritter("target")
  if critter == nil then return nil, true end
  return { critter = critter }
end

local function resample()
  local found, secret = sample()
  if secret then M:Stat("killSecret", 1) end
  cand = found
end

-- With a candidate, UNIT_FLAGS only rechecks the reaction: the target entering combat is expected.
local function refresh()
  local reaction, readable = Safe.Value(UnitReaction("target", "player"))
  if not readable then
    drop(true)
  elseif reaction ~= NEUTRAL then
    drop()
  end
end

-- The target attacked when combat began died, and no one else tapped it.
local function checkDeath()
  local dead = Safe.Bool(UnitIsDead("target"))
  if dead == false then return end
  local denied = dead and Safe.Bool(UnitIsTapDenied("target"))
  if denied == nil then
    drop(true)
    return
  end
  if not denied then
    local critter = cand.critter
    if ns.Log:Add(critter and "kill.critter" or "kill.neutral", {}) then
      M:Stat(critter and "killCritter" or "killNeutral", 1)
    end
  end
  drop()
end

function onHealth()
  if frozen and cand then checkDeath() end
end

-- In combat the attacked target is gone; out of combat the new target is sampled from scratch.
local function onTargetChanged()
  local combat = frozen or playerInCombat()
  if combat == false then
    resample()
  else
    drop(combat == nil)
  end
end

-- UNIT_FLAGS(target) can arrive in the same server update as combat, before PLAYER_REGEN_DISABLED:
-- while the player is in combat but not yet frozen, the candidate stays.
local function onFlags()
  if frozen then
    if cand then checkDeath() end
    return
  end
  local combat = playerInCombat()
  if combat == nil then
    drop(true)
  elseif combat == false then
    if cand then refresh() else resample() end
  end
end

local function onCombatStart()
  frozen = true
  if cand then
    M:Stat("killCand", 1)
    watch(true)
  end
end

local function onCombatEnd()
  frozen = false
  drop()
end

-- Test checks (7.10) -----------------------------------------------------------------------

local function checkAxes()
  local char = M:Char()
  if not char then return nil, "no character record" end
  local axes = M:Axes(char)
  return true, string.format("fidelity %d, habitat %d, mercy %d, %s, origin %s", axes.fidelity, axes.habitat,
    axes.mercy, M:Archetype(char), tostring(M:Origin(char) or "none"))
end

local function checkCritter()
  if Safe.Bool(UnitExists("target")) then isCritter("target") end
  if typeIds then return true, "creature type ID" end
  local name = critterName or readCritterName()
  if name then return true, "critterType: " .. name end
  if typeIds == false then return false, L.PROFILE_TEST_CRITTER_OFF end
  return nil, L.PROFILE_TEST_CRITTER_TARGET
end

-- The counters feed the accuracy check: the tester compares them with the kills made between two runs.
local function checkMercy()
  local neutral, critter = M:Stat("killNeutral"), M:Stat("killCritter")
  local detail = string.format("candidates %d, secret reads %d, neutral kills %d, critter kills %d. %s",
    M:Stat("killCand"), M:Stat("killSecret"), neutral, critter, L.PROFILE_TEST_MERCY_HOWTO)
  if neutral + critter == 0 then return nil, detail end
  return true, detail
end

-- Lifecycle ---------------------------------------------------------------------------------

function M:OnInitialize()
  ns.Log:RegisterKind("kill.neutral", { fields = {} })
  ns.Log:RegisterKind("kill.critter", { fields = {} })
  ns.Test:Register("Profile.axes", checkAxes)
  ns.Test:Register("Profile.critter", checkCritter)
  ns.Test:Register("Profile.mercy", checkMercy)
end

function M:OnEnable()
  critterName = readCritterName()
  self:Subscribe("LOG_ADDED", onLogAdded)
  self:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
  self:RegisterUnitEvent("UNIT_FLAGS", "target", onFlags)
  self:RegisterEvent("PLAYER_REGEN_DISABLED", onCombatStart)
  self:RegisterEvent("PLAYER_REGEN_ENABLED", onCombatEnd)
end

function M:OnWorldReady()
  local char = self:Char()
  if not char then return end
  commit(rollDay(char))
  ns.Util.Ticker(TICKER, TICK, ticker)
end

-- Core has removed every event already, UNIT_HEALTH included.
function M:OnDisable()
  ns.Util.StopTicker(TICKER)
  cand, frozen, watching = nil, false, false
end

local ADDON, ns = ...

local Identity = ns:NewService("Identity")

local Safe = ns.Safe
local ruleset

local function ruleActive(key)
  local rule = Enum and Enum.GameRule and Enum.GameRule[key]
  if rule == nil then return false end
  local ok, on = Safe.Call(C_GameRules and C_GameRules.IsGameRuleActive, rule)
  return ok and on == true
end

local function computeRuleset()
  if not ns.Compat.Has.rulesets then return "Normal" end
  if ruleActive("HardcoreRuleset") then return "Hardcore" end
  local rp, pvp = ruleActive("RPRuleset"), ruleActive("PvPRuleset")
  if ruleActive("RPPvPRuleset") or (rp and pvp) then return "RPPvP" end
  if rp then return "RP" end
  if pvp then return "PvP" end
  return "Normal"
end

function Identity:Ruleset()
  ruleset = ruleset or computeRuleset()
  return ruleset
end

local function read(fn, unit, index)
  local ok, a, b, c = pcall(fn, unit)
  if not ok then return nil end
  local v = index == 3 and c or index == 2 and b or a
  return (Safe.Value(v))
end

local function person(unit, guid, name, surname)
  return {
    guid = guid,
    name = name,
    surname = surname,
    full = surname and (name .. " " .. surname) or name,
    class = read(UnitClass, unit, 2),
    race = read(UnitRace, unit, 3),
    raceName = read(UnitRace, unit, 1),    -- the client's name for the unit's sex (Names.Race, 5.7)
    sex = read(UnitSex, unit, 1),
    faction = read(UnitFactionGroup, unit, 1),
    level = read(UnitLevel, unit, 1),
    ruleset = Identity:Ruleset(),
    unit = unit,
  }
end

function Identity:Unit(unit)
  local guid = Safe.UnitGUID(unit)
  local name, surname = Safe.UnitName(unit)
  if not guid or not name then return nil end
  return person(unit, guid, name, surname)
end

-- The player's surname adds step 3, UnitFullName, and reports its source.
function Identity:Player()
  local guid = Safe.UnitGUID("player")
  local name, surname, source = Safe.UnitName("player")
  if not surname and type(UnitFullName) == "function" then
    local ok, _, full = pcall(UnitFullName, "player")
    surname = ok and Safe.Surname(full) or nil
    source = surname and "UnitFullName" or nil
  end
  local p = person("player", guid, name, surname)
  p.surnameSource = source
  return p
end

-- Ashmark's group is the home group, the party or raid the player formed. Without a category the client
-- answers for the instance group while there is one, and a battleground puts every player into one.
local function home()
  return type(LE_PARTY_CATEGORY_HOME) == "number" and LE_PARTY_CATEGORY_HOME or nil
end

local function inInstanceGroup()
  if type(LE_PARTY_CATEGORY_INSTANCE) ~= "number" then return false end
  local ok, grouped = Safe.Call(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
  return ok and grouped == true
end

-- The home group's unit tokens, "party", 4 or (scope "all" in a raid) "raid", 40; nil while the tokens
-- name an instance group, which leaves the home group without tokens of its own.
function Identity:Tokens(scope)
  if inInstanceGroup() then return nil end
  if scope == "all" then
    local ok, raid = Safe.Call(IsInRaid, home())
    if ok and raid == true then return "raid", 40 end
  end
  return "party", 4
end

function Identity:Group(scope)
  local out = {}
  local prefix, count = self:Tokens(scope)
  if not prefix then return out end
  local me = Safe.UnitGUID("player")
  for i = 1, count do
    local p = self:Unit(prefix .. i)
    if p and p.guid ~= me then out[p.guid] = p end
  end
  return out
end

function Identity:InGroup()
  local ok, grouped = Safe.Call(IsInGroup, home())
  if not (ok and grouped == true) then return false end
  local counted, n = Safe.Call(GetNumGroupMembers, home())
  return counted and type(n) == "number" and n > 1 or false
end

local function ensure(t, key, value)
  if type(t[key]) ~= type(value) then t[key] = value end
end

-- PLAYER_LOGIN: creates or updates chars[guid] (4.1). Read-only mode only learns the GUID.
function Identity:Refresh()
  ns.playerGUID = Safe.UnitGUID("player")
  ruleset = computeRuleset()
  self:RegisterEvent("GAME_RULES_CHANGED", function()
    ruleset = computeRuleset()
    local char = ns.DB:Char()
    if char and not ns.DB.readOnly then char.ruleset = ruleset end
  end)
  if ns.DB.readOnly or not ns.playerGUID then return end
  local chars = AshmarkDB.chars
  local char = chars[ns.playerGUID]
  if type(char) ~= "table" then
    char = { firstSeen = time() }
    chars[ns.playerGUID] = char
  end
  local p = self:Player()
  char.guid, char.name, char.surname, char.surnameSource = p.guid, p.name, p.surname, p.surnameSource
  char.ruleset, char.faction, char.race, char.class, char.sex, char.level =
    p.ruleset, p.faction, p.race, p.class, p.sex, p.level
  ensure(char, "firstSeen", time())
  ensure(char, "seq", 0)
  ensure(char, "log", {})
  ensure(char, "chapters", {})
  ensure(char, "zones", {})
  ensure(char, "stats", {})
  ensure(char, "state", {})
  ensure(char.state, "inGroup", false)
  ensure(char.state, "senders", {})
end

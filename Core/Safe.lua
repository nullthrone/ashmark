local ADDON, ns = ...

local Safe = {}
ns.Safe = Safe

-- The one secrecy predicate (5.2). The client globals are read at call time.
local function IsSecret(v)
  if canaccessvalue and not canaccessvalue(v) then return true end
  if issecretvalue and issecretvalue(v) then return true end
  if type(v) == "table" then
    if canaccesstable and not canaccesstable(v) then return true end
    if issecrettable and issecrettable(v) then return true end
  end
  return false
end
Safe.IsSecret = IsSecret

function Safe.Value(v)
  if IsSecret(v) then return nil, false end
  return v, true
end

function Safe.Bool(v)
  if IsSecret(v) then return nil end
  return v and true or false
end

local function checked(ok, ...)
  if not ok then return false end
  for i = 1, select("#", ...) do
    if IsSecret((select(i, ...))) then return false end
  end
  return true, ...
end

function Safe.Call(fn, ...)
  if type(fn) ~= "function" then return false end
  return checked(pcall(fn, ...))
end

function Safe.Field(t, k)
  if type(t) ~= "table" or IsSecret(t) then return nil, false end
  local v = t[k]
  if IsSecret(v) then return nil, false end
  return v, true
end

function Safe.Fields(t, ...)
  if type(t) ~= "table" or IsSecret(t) then return nil end
  local out = {}
  for i = 1, select("#", ...) do
    local k = select(i, ...)
    local v = t[k]
    if IsSecret(v) then return nil end
    out[k] = v
  end
  return out
end

local PLAIN = { number = true, string = true, boolean = true }

function Safe.Clean(t)
  if type(t) ~= "table" or IsSecret(t) then return nil end
  local copy = {}
  for k, v in pairs(t) do
    if IsSecret(k) or IsSecret(v) or not PLAIN[type(v)] then return nil end
    copy[k] = v
  end
  return copy
end

local function realm(name)
  local ok, a = Safe.Call(GetRealmName)
  if ok and name == a then return true end
  local okN, b = Safe.Call(GetNormalizedRealmName)
  return okN and name == b
end

-- A surname candidate: a plain non-empty string without "-" that is not the realm name.
function Safe.Surname(v)
  if IsSecret(v) or type(v) ~= "string" or v == "" or v:find("-", 1, true) or realm(v) then
    return nil
  end
  return v
end

-- The first two returns; each is checked on its own, so a secret surname keeps the name.
local function two(fn, unit)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, unit)
  if ok then return a, b end
end

-- name, surname, surnameSource; steps 1 and 2 of the surname order (5.3).
function Safe.UnitName(unit)
  local name = two(UnitName, unit)
  if IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
  local _, surname = two(UnitNameUnmodified, unit)
  surname = Safe.Surname(surname)
  if surname then return name, surname, "UnitNameUnmodified" end
  _, surname = two(UnitName, unit)
  surname = Safe.Surname(surname)
  if surname then return name, surname, "UnitName" end
  return name
end

function Safe.UnitGUID(unit)
  local ok, guid = Safe.Call(UnitGUID, unit)
  if ok and type(guid) == "string" then return guid end
end

local function predicate(name, unit)
  local api = C_Secrets and C_Secrets[name]
  local ok, value = Safe.Call(api, unit)
  if ok and type(value) == "boolean" then return value end
end

function Safe.UnitIdentityRestricted(unit)
  return predicate("ShouldUnitIdentityBeSecret", unit)
end

function Safe.AurasRestricted(unit)
  return predicate("ShouldAurasBeSecret", unit)
end

function Safe.InLockdown()
  local api = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  if type(api) ~= "function" then return false end
  local ok, locked = Safe.Call(api)
  if not ok then return true end
  return locked == true
end

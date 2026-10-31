local _, ns = ...

-- Module 5 (7.5): characters on this account who share a surname form a house. The house key is
-- the surname, or a name chosen with /ashmark house; the House tab (UI/Tabs/House.lua) shows the
-- members, the feuds they hold, the family chronicle and the people they know.
local M = ns:NewModule("House", {
  optional = { "legacy" },
  locale = "HOUSE",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local LEGACY_FACTION = 2802
local FAMILY_KINDS = { alliance = true, violation = true, houseturn = true, chapter = true, level = true }
local EMPTY = {}

-- Keys and members ----------------------------------------------------------------

local function clean(v)
  if type(v) ~= "string" then return nil end
  v = ns.Util.Trim(v)
  if v ~= "" then return v end
end

local function houseKey(char)
  if type(char) ~= "table" then return nil end
  return clean(char.houseOverride) or clean(char.surname)
end

local function records()
  local db = AshmarkDB
  local chars = type(db) == "table" and db.chars
  return type(chars) == "table" and chars or EMPTY
end

-- Highest level first; name and GUID keep the order stable for equal levels.
local function byLevel(a, b)
  local la, lb = tonumber(a.level) or 0, tonumber(b.level) or 0
  if la ~= lb then return la > lb end
  local na, nb = tostring(a.name or ""), tostring(b.name or "")
  if na ~= nb then return na < nb end
  return tostring(a.guid or "") < tostring(b.guid or "")
end

local function members(char)
  local key = houseKey(char)
  if not key then return {} end
  local out, found = {}, false
  for _, other in pairs(records()) do
    if type(other) == "table" and houseKey(other) == key then
      out[#out + 1] = other
      found = found or other == char
    end
  end
  if not found then out[#out + 1] = char end
  table.sort(out, byLevel)
  return out
end

local function isSibling(member, char)
  return member ~= char and type(member.guid) == "string" and member.guid ~= char.guid
end

-- Public services (3.8) -----------------------------------------------------------

function M:Key(char)
  return houseKey(char)
end

function M:Members(char)
  return members(char)
end

-- list: what House:Members(char) returned, when the caller holds it already (the tab).
function M:SiblingAlliances(char, list)
  local out = {}
  for _, member in ipairs(list or members(char)) do
    local rec = isSibling(member, char) and type(member.conflicts) == "table" and member.conflicts.allied
    if type(rec) == "table" then
      for id, side in pairs(rec) do
        if type(id) == "string" and (side == "A" or side == "B") then
          local split = out[id]
          if not split then
            split = { A = {}, B = {} }
            out[id] = split
          end
          split[side][#split[side] + 1] = member.guid
        end
      end
    end
  end
  return out
end

local function familyKind(entry)
  if type(entry) ~= "table" or not FAMILY_KINDS[entry.k] then return false end
  return entry.k ~= "level" or (type(entry.l) == "number" and entry.l % 10 == 0)
end

-- A kind's renderer is looked up when the entry is told, not when it is read.
local function worthTelling(entry)
  local spec = ns.Log:Kind(entry.k)
  return spec ~= nil and spec.render ~= nil
end

local function newestFirst(a, b)
  local ta, tb = tonumber(a.entry.t) or 0, tonumber(b.entry.t) or 0
  if ta ~= tb then return ta > tb end
  if a.char ~= b.char then return tostring(a.char.guid) < tostring(b.char.guid) end
  return (tonumber(a.entry.n) or 0) > (tonumber(b.entry.n) or 0)
end

-- The family entries of each log read so far, oldest first, and the newest sequence number read.
-- Logs only grow at their end, so a later call reads just the entries after that number. Compaction
-- and /ashmark reset put a new table in char.log, which is read afresh; the old one is let go.
local readLogs = setmetatable({}, { __mode = "k" })

local function familyEntries(log)
  local read = readLogs[log]
  if not read then
    read = { entries = {} }
    readLogs[log] = read
  end
  local fresh, newest = {}, read.last
  for i = #log, 1, -1 do
    local entry = log[i]
    local n = type(entry) == "table" and tonumber(entry.n)
    if read.last and not (n and n > read.last) then break end
    if n and (newest == nil or n > newest) then newest = n end
    if familyKind(entry) then fresh[#fresh + 1] = entry end
  end
  local entries = read.entries
  for i = #fresh, 1, -1 do entries[#entries + 1] = fresh[i] end
  read.last = newest
  return entries
end

-- Each item also carries its rendered sentence (text), so the tab renders nothing twice. A member
-- contributes at most `limit` candidates, its newest. list: as in SiblingAlliances.
function M:FamilyChronicle(char, limit, list)
  limit = tonumber(limit) or math.huge
  local found = {}
  for _, member in ipairs(list or members(char)) do
    local entries = type(member.log) == "table" and familyEntries(member.log) or EMPTY
    local taken = 0
    for i = #entries, 1, -1 do
      if taken >= limit then break end
      if worthTelling(entries[i]) then
        found[#found + 1] = { entry = entries[i], char = member }
        taken = taken + 1
      end
    end
  end
  table.sort(found, newestFirst)
  local out = {}
  for _, item in ipairs(found) do
    if #out >= limit then break end
    item.text = ns.Chronicle:Render(item.entry, { char = item.char, own = item.char == char })
    if item.text then out[#out + 1] = item end
  end
  return out
end

-- For this unit's tab ---------------------------------------------------------------

-- True when a new log entry of the character changes what the tab shows: a family kind (every
-- level, for the member list) or a standing change of the Legacy faction.
function M:Concerns(entry)
  if type(entry) ~= "table" then return false end
  return FAMILY_KINDS[entry.k] == true or (entry.k == "rep" and entry.f == LEGACY_FACTION)
end

-- The Legacy line (7.5): the renown level of faction 2802, else its standing label; nil without
-- the legacy capability or when nothing readable comes back.
function M:Legacy(char)
  if not ns.Compat.Has.legacy then return nil end
  local okMajor, major = Safe.Call(C_MajorFactions and C_MajorFactions.GetMajorFactionData, LEGACY_FACTION)
  local fields = okMajor and Safe.Fields(major, "name", "renownLevel")
  local name = fields and type(fields.name) == "string" and fields.name ~= "" and fields.name
    or ns.Names.Faction(LEGACY_FACTION)
  if fields and type(fields.renownLevel) == "number" then
    return ns.Format(L.HOUSE_LEGACY_LEVEL, { faction = name, level = fields.renownLevel })
  end
  local okRep, rep = Safe.Call(C_Reputation and C_Reputation.GetFactionDataByID, LEGACY_FACTION)
  local reaction = okRep and Safe.Field(rep, "reaction")
  if type(reaction) ~= "number" then return nil end
  local token = "FACTION_STANDING_LABEL" .. reaction
  local sex = type(char) == "table" and char.sex or nil
  local label = type(GetText) == "function" and GetText(token, sex) or _G[token]
  if type(label) ~= "string" then return nil end
  return ns.Format(L.HOUSE_LEGACY_STANDING, { faction = name, standing = label })
end

-- /ashmark house (5.9) ---------------------------------------------------------------

local fold = ns.Util.Fold

-- The house name already on the account that equals name ignoring case (fold): the stored surname
-- of any character, or the override of another one, so two alts that type the same house in
-- different case share it. An exact match wins, otherwise the first in byte order. nil without a
-- match.
local function knownHouse(name, self)
  local folded, match = fold(name)
  local function consider(key)
    if not key then return false end
    if key == name then return true end
    if fold(key) == folded and (not match or key < match) then match = key end
    return false
  end
  for _, char in pairs(records()) do
    if type(char) == "table" then
      if consider(clean(char.surname)) then return name end
      local other = char ~= self and char.guid ~= self.guid
      if other and consider(clean(char.houseOverride)) then return name end
    end
  end
  return match
end

local function report(key, keyIfHouse, keyIfNone)
  if key then
    ns.Print(ns.Format(L[keyIfHouse], { house = key }))
  else
    ns.Print(L[keyIfNone])
  end
end

local function house(args)
  local char = M:Char()
  if not char then return end
  args = ns.Util.Trim(args)
  if args == "" then
    return report(houseKey(char), "HOUSE_SLASH_CURRENT", "HOUSE_SLASH_NONE")
  end
  if args:lower() == "reset" then
    char.houseOverride = nil
    report(houseKey(char), "HOUSE_SLASH_RESET", "HOUSE_SLASH_RESET_NONE")
  else
    char.houseOverride = knownHouse(args, char) or args
    ns.Print(ns.Format(L.HOUSE_SLASH_SET, { house = char.houseOverride }))
  end
  M:Fire("HOUSE_CHANGED", houseKey(char))
end

local command = M:Wrap("slash:house", house)

-- Test checks (7.10) -----------------------------------------------------------------

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function checkKey()
  local char = M:Char()
  if not char then return nil, "no character record" end
  local key = houseKey(char)
  local source = clean(char.houseOverride) and "override" or tostring(char.surnameSource or "none")
  if not key then return nil, "no surname (" .. source .. "). " .. L.HOUSE_SLASH_NONE end
  return true, string.format("House %s from %s, %d members, %d sibling conflicts", key, source,
    #members(char), count(M:SiblingAlliances(char)))
end

local function checkLegacy()
  if not ns.Compat.Has.legacy then return nil, "no data for faction " .. LEGACY_FACTION end
  local line = M:Legacy(M:Char())
  if not line then return false, "faction " .. LEGACY_FACTION .. " has data but no level or standing" end
  return true, line
end

-- Lifecycle ----------------------------------------------------------------------------

function M:OnInitialize()
  ns.Slash:Register("house", function(args)
    if not M.enabled then return ns.Print(L.HOUSE_SLASH_OFF) end
    command(args)
  end, "HOUSE_HELP")
  ns.Test:Register("House.key", checkKey)
  ns.Test:Register("House.legacy", checkLegacy)
end

local ADDON, ns = ...

local Names = ns:NewService("Names")

local Safe = ns.Safe
local L = ns.L

local cache = { quest = {}, item = {}, faction = {}, map = {}, race = {} }
local requested = { quest = {}, item = {} }

local function text(v)
  if type(v) == "string" and v ~= "" and not Safe.IsSecret(v) then return v end
end

local function field(fn, id, key)
  local ok, data = Safe.Call(fn, id)
  if not ok then return nil end
  return text((Safe.Field(data, key)))
end

local function lookup(kind, id, read)
  if id == nil or Safe.IsSecret(id) then return nil end
  local known = cache[kind][id]
  if known then return known end
  local name = read(id)
  if name then cache[kind][id] = name end
  return name
end

local function request(kind, id, fn)
  if type(id) ~= "number" or requested[kind][id] then return end
  requested[kind][id] = true
  Safe.Call(fn, id)
end

local function readQuest(id)
  local ok, title = Safe.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, id)
  return ok and text(title) or nil
end

local function readItem(id)
  local ok, name = Safe.Call(C_Item and C_Item.GetItemNameByID, id)
  return ok and text(name) or nil
end

local function readFaction(id)
  return field(C_Reputation and C_Reputation.GetFactionDataByID, id, "name")
end

local function readMap(id)
  return field(C_Map and C_Map.GetMapInfo, id, "name")
end

local function readRace(id)
  return field(C_CreatureInfo and C_CreatureInfo.GetRaceInfo, id, "raceName")
end

function Names.Quest(id)
  local name = lookup("quest", id, readQuest)
  if name then return name end
  request("quest", id, C_QuestLog and C_QuestLog.RequestLoadQuestByID)
  return L.CORE_UNKNOWN_QUEST
end

function Names.Item(id)
  local name = lookup("item", id, readItem)
  if name then return name end
  request("item", id, C_Item and C_Item.RequestLoadItemDataByID)
  return L.CORE_UNKNOWN_ITEM
end

function Names.Faction(id)
  return lookup("faction", id, readFaction) or L.CORE_UNKNOWN_FACTION
end

function Names.Map(id)
  return lookup("map", id, readMap) or L.CORE_UNKNOWN_PLACE
end

function Names.Race(raceID)
  return lookup("race", raceID, readRace) or L.CORE_UNKNOWN_RACE
end

function Names.Class(classFile, sex)
  if type(classFile) ~= "string" then return L.CORE_UNKNOWN_CLASS end
  local female = sex == 3 and type(LOCALIZED_CLASS_NAMES_FEMALE) == "table" and LOCALIZED_CLASS_NAMES_FEMALE[classFile]
  local male = type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[classFile]
  return text(female) or text(male) or L.CORE_UNKNOWN_CLASS
end

-- Contact or character record name; not cached, because both stores change during a session.
function Names.Player(guid)
  local db = AshmarkDB
  if type(guid) == "string" and type(db) == "table" then
    local contact = type(db.contacts) == "table" and db.contacts[guid]
    local name = type(contact) == "table" and text(contact.name)
    if name then return name end
    local char = type(db.chars) == "table" and db.chars[guid]
    name = type(char) == "table" and text(char.name)
    if name then return name end
  end
  return L.CORE_UNKNOWN_PLAYER
end

local function loaded(kind)
  return function(_, _, id, success)
    id = Safe.Value(id)
    if id ~= nil and requested[kind][id] and Safe.Value(success) == true then
      ns.Bus:Fire("NAMES_UPDATED", kind, id)
    end
  end
end

function Names:Start()
  self:RegisterEvent("QUEST_DATA_LOAD_RESULT", loaded("quest"))
  self:RegisterEvent("ITEM_DATA_LOAD_RESULT", loaded("item"))
end

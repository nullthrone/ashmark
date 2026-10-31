local _, ns = ...

-- Module 1 (7.1): quests that set one side against another, the alliance a character forms in each
-- conflict and the word it breaks. The data is Data/Conflicts.lua; the quest-dialog line lives in
-- QuestDialog.lua, the Decisions tab in UI/Tabs/Decisions.lua.
local M = ns:NewModule("Conflicts", {
  requires = { "questLog", "reputation" },
  optional = { "questFrame" },
  locale = "CONFLICT",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local SIDES = { "A", "B" }
local OTHER = { A = "B", B = "A" }
local QUEST_KINDS = { ["quest.accept"] = true, ["quest.turnin"] = true }
local STORES = { "allied", "since", "began", "broken", "turned" }

-- Indices -------------------------------------------------------------------

local idx                        -- { list, byId, byQuest = { [q] = { id, side } }, byZone }; never edits the data

local function validSide(side)
  return type(side) == "table" and type(side.faction) == "number" and type(side.quests) == "table"
end

local function valid(conflict)
  return type(conflict) == "table" and type(conflict.id) == "string" and type(conflict.zone) == "number"
    and validSide(conflict.A) and validSide(conflict.B)
end

local function build()
  local t = { list = {}, byId = {}, byQuest = {}, byZone = {} }
  local function addZone(m, conflict)
    if type(m) ~= "number" then return end
    local zone = t.byZone[m] or {}
    zone[#zone + 1] = conflict
    t.byZone[m] = zone
  end
  local data = ns.Data and ns.Data.Conflicts
  local list = type(data) == "table" and type(data.list) == "table" and data.list or {}
  for _, conflict in ipairs(list) do
    if valid(conflict) and not t.byId[conflict.id] then
      t.list[#t.list + 1] = conflict
      t.byId[conflict.id] = conflict
      for _, side in ipairs(SIDES) do
        for _, q in ipairs(conflict[side].quests) do
          -- The validator keeps a quest in one conflict; should it slip, the first one wins.
          if not t.byQuest[q] then t.byQuest[q] = { id = conflict.id, side = side } end
        end
      end
      addZone(conflict.zone, conflict)
      local anchor = type(conflict.anchor) == "table" and conflict.anchor.m
      if anchor ~= conflict.zone then addZone(anchor, conflict) end
    end
  end
  return t
end

-- Built in OnInitialize; a public call before that builds it on first use.
local function index()
  if not idx then idx = build() end
  return idx
end

-- Old id -> current id for conflicts the dataset renamed (data/conflicts/renamed.csv). The generator
-- only names targets that are in the data, so one step always reaches the current id.
local function renames()
  local data = ns.Data and ns.Data.Conflicts
  local t = type(data) == "table" and data.renamed
  if type(t) == "table" then return t end
end

-- Every character's stored state follows a renamed conflict, so House reads siblings' alliances by the
-- current id. A current id already stored keeps its value; the old key goes either way.
local function follow()
  local r, chars = renames(), type(AshmarkDB) == "table" and AshmarkDB.chars
  if not r or ns.DB.readOnly or type(chars) ~= "table" then return end
  for _, char in pairs(chars) do
    local rec = type(char) == "table" and char.conflicts
    for _, key in ipairs(STORES) do
      local t = type(rec) == "table" and rec[key]
      if type(t) == "table" then
        for old, new in pairs(r) do
          if t[old] ~= nil and type(new) == "string" then
            if t[new] == nil then t[new] = t[old] end
            t[old] = nil
          end
        end
      end
    end
  end
end

-- Public services (3.8) --------------------------------------------------------

function M:All()
  local out = {}
  for i, conflict in ipairs(index().list) do out[i] = conflict end
  return out
end

-- Old log entries name a renamed conflict by its old id; they resolve to the current one.
function M:Get(id)
  local byId, r = index().byId, renames()
  return byId[id] or (r and type(id) == "string" and byId[r[id]]) or nil
end

function M:SideOf(questId)
  local hit = index().byQuest[questId]
  if hit then return hit.id, hit.side end
end

function M:InZone(mapId)
  local out = {}
  for i, conflict in ipairs(index().byZone[mapId] or {}) do out[i] = conflict end
  return out
end

local function stored(char, key)
  local rec = type(char) == "table" and char.conflicts
  local t = type(rec) == "table" and rec[key]
  if type(t) == "table" then return t end
end

function M:Alliance(char, id)
  local allied = stored(char, "allied")
  local side = allied and allied[id]
  if side ~= "A" and side ~= "B" then return nil end
  local began = stored(char, "began")
  return side, began and began[id]
end

-- For this unit's dialog line, renderers and tab ---------------------------------

-- A conflict's title: the client's title of the first quest on side A. The data gives conflicts no
-- name, and one zone can hold several conflicts between the same two factions.
function M:Title(conflict)
  local s = type(conflict) == "table" and conflict.A
  local quests = type(s) == "table" and s.quests
  return ns.Names.Quest(type(quests) == "table" and quests[1] or nil)
end

-- A side's faction name from the client, or CONFLICT_UNNAMED for a side without a faction.
function M:SideName(conflict, side)
  local s = type(conflict) == "table" and conflict[side]
  local f = type(s) == "table" and s.faction or nil
  if f == 0 then return L.CONFLICT_UNNAMED end
  return ns.Names.Faction(f)
end

-- The side taken in conflict id, when it was taken, and how often the word was broken there.
function M:Decision(char, id)
  local side = self:Alliance(char, id)
  local since, broken = stored(char, "since"), stored(char, "broken")
  local count = broken and broken[id]
  return side, side and since and since[id] or nil, type(count) == "number" and count or 0
end

function M:Violations(char)
  local rec = type(char) == "table" and char.conflicts
  local n = type(rec) == "table" and rec.violations
  return type(n) == "number" and n or 0
end

-- State ---------------------------------------------------------------------------

-- char.conflicts (4.1); created on the first write, so a wiped record starts over cleanly.
local function record(char)
  local rec = char.conflicts
  if type(rec) ~= "table" then
    rec = {}
    char.conflicts = rec
  end
  for _, key in ipairs(STORES) do
    if type(rec[key]) ~= "table" then rec[key] = {} end
  end
  if type(rec.violations) ~= "number" then rec.violations = 0 end
  return rec
end

-- Another unit's public service (3.8), looked up at call time; nil if the unit or the call is missing.
local function ask(unit, method, ...)
  local service = ns[unit]
  local ok, result = Safe.Call(service and service[method], service, ...)
  if ok then return result end
end

local function holdsOther(guids, own)
  if type(guids) ~= "table" then return false end
  for _, guid in ipairs(guids) do
    if guid ~= own then return true end
  end
  return false
end

-- The house key when the character's siblings hold conflict id only on the side opposing `side`
-- (rules 5 and 6); siblings on both sides, or none, give nil.
local function houseAgainst(char, id, side)
  local alliances = ask("House", "SiblingAlliances", char)
  local split = type(alliances) == "table" and alliances[id]
  if type(split) ~= "table" then return nil end
  if not holdsOther(split[OTHER[side]], char.guid) or holdsOther(split[side], char.guid) then return nil end
  local key = ask("House", "Key", char)
  if type(key) == "string" and key ~= "" then return key end
end

-- Rules 1, 2 and 5: the first alliance in each conflict of `group` ({ { conflict, side }, ... }, one
-- zone and one faction taken), by quest (q) or by reputation. One alliance entry and at most one
-- houseturn tell of the whole group, so the chronicle and the rumours say it once.
local function form(char, group, q, viaRep)
  local rec = record(char)
  local houses, turn = {}, nil
  for i, hit in ipairs(group) do
    houses[i] = not rec.turned[hit.conflict.id] and houseAgainst(char, hit.conflict.id, hit.side)
    if houses[i] and not turn then turn = i end
  end
  local first = group[1]
  local entry = ns.Log:Add("alliance", { c = first.conflict.id, side = first.side, rep = viaRep or nil })
  if not entry then return end
  for _, hit in ipairs(group) do
    local id = hit.conflict.id
    rec.allied[id], rec.since[id], rec.began[id] = hit.side, entry.t, entry.n
  end
  local by = turn and group[turn]
  if by and ns.Log:Add("houseturn", { c = by.conflict.id, side = by.side, q = q, h = houses[turn] }) then
    for i, hit in ipairs(group) do
      if houses[i] then rec.turned[hit.conflict.id] = true end
    end
  end
  for _, hit in ipairs(group) do M:Fire("ALLIANCE_FORMED", hit.conflict.id, hit.side, viaRep) end
end

-- Rule 4: a turn-in for the other side breaks the alliance; the violation is the record.
local function violate(char, conflict, side, q)
  local id = conflict.id
  local rec = record(char)
  -- Read before the write: the violation itself moves the profile (7.2).
  local o = ask("Profile", "IsOpportunist", char) == true and 1 or nil
  local entry = ns.Log:Add("violation", { c = id, side = side, q = q, o = o })
  if not entry then return end
  rec.violations = rec.violations + 1
  rec.broken[id] = (tonumber(rec.broken[id]) or 0) + 1
  rec.allied[id], rec.since[id], rec.began[id] = side, entry.t, entry.n
  M:Fire("ALLIANCE_BROKEN", id, side, q)
end

local function onLogAdded(_, _, entry, char)
  if not QUEST_KINDS[entry.k] then return end
  local hit = index().byQuest[entry.q]
  if not hit then return end
  local conflict = index().byId[hit.id]
  local side = M:Alliance(char, hit.id)
  if not side then
    form(char, { { conflict = conflict, side = hit.side } }, entry.q, false)
  elseif side ~= hit.side and entry.k == "quest.turnin" then
    violate(char, conflict, hit.side, entry.q)
  end
end

-- Reaction (standing ID 1..8) of faction f; false for a side without a faction, nil while unreadable.
-- Never currentStanding, which holds raw points.
local function reaction(f)
  if f == 0 then return false end
  local ok, data = Safe.Call(C_Reputation and C_Reputation.GetFactionDataByID, f)
  local fields = ok and Safe.Fields(data, "reaction")
  local value = fields and fields.reaction
  if type(value) == "number" then return value end
end

local onFaction                  -- the retry, defined below

-- Rule 2: exactly one side at or above `honored` forms the alliance; both at it form none. The
-- conflicts one pass decides for the same faction in the same zone form together (see form).
local function checkReputation()
  local char = M:Char()
  if not char then return end
  local unread, groups, order = false, {}, {}
  for _, conflict in ipairs(index().list) do
    local honored = conflict.honored
    if type(honored) == "number" and not M:Alliance(char, conflict.id) then
      local a, b = reaction(conflict.A.faction), reaction(conflict.B.faction)
      if a == nil or b == nil then
        unread = true
      else
        local reachA, reachB = a and a >= honored, b and b >= honored
        if reachA ~= reachB then
          local side = reachA and "A" or "B"
          local key = conflict.zone .. ":" .. conflict[side].faction
          if not groups[key] then
            groups[key] = {}
            order[#order + 1] = groups[key]
          end
          table.insert(groups[key], { conflict = conflict, side = side })
        end
      end
    end
  end
  for _, group in ipairs(order) do form(char, group, nil, true) end
  -- A faction read as nil is retried on the next UPDATE_FACTION (3.3); Core's REP_CHANGED stays
  -- silent for it, because Core takes its first read as a baseline.
  if unread then
    M:RegisterEvent("UPDATE_FACTION", onFaction)
  else
    M:UnregisterEvent("UPDATE_FACTION")
  end
end

local retry = M:Wrap("UPDATE_FACTION", checkReputation)

function onFaction()
  ns.Util.Debounce("Conflicts.faction", 1, retry)
end

-- Rules 3 and 6: the quest-dialog line for questId, and its kind ("contradicts" or "house"), or nil.
function M:DialogLine(questId, char)
  local hit = index().byQuest[questId]
  if not (hit and type(char) == "table") then return nil end
  local conflict = index().byId[hit.id]
  local side = self:Alliance(char, hit.id)
  if side == hit.side then return nil end
  if side then
    if conflict[side].faction == 0 then return L.CONFLICT_CONTRADICTS_NOFACTION, "contradicts" end
    return ns.Format(L.CONFLICT_CONTRADICTS, { faction = self:SideName(conflict, side) }), "contradicts"
  end
  local house = houseAgainst(char, hit.id, hit.side)
  if house then
    return ns.Format(L.CONFLICT_HOUSE_STANDS_AGAINST, { house = house, faction = self:SideName(conflict, hit.side) }),
      "house"
  end
end

-- Chronicle ---------------------------------------------------------------------------

local function zoneName(conflict)
  return ns.Names.Map(conflict.zone)
end

-- An entry of a retired id (7.1) renders nothing, as a forgotten contact does (7.4): its sides and zone
-- no longer ship, and a line of placeholders would stay in the chronicle for good. A rule-1 entry stands
-- for one conflict and names its title, so conflicts of one faction pair in one zone read apart; a rule-2
-- entry stands for every conflict its pass formed in the zone and names none.
local function renderAlliance(entry, ctx)
  local conflict = M:Get(entry.c)
  if not conflict then return nil end
  local args = { faction = M:SideName(conflict, entry.side), zone = zoneName(conflict) }
  if entry.rep then return ns.Chronicle:Text("CONFLICT_ALLIED_REP", ctx, args) end
  args.title = M:Title(conflict)
  return ns.Chronicle:Text("CONFLICT_ALLIED", ctx, args)
end

-- The wording was decided at write time (o), never from the current profile.
local function renderViolation(entry, ctx)
  local conflict = M:Get(entry.c)
  if not conflict then return nil end
  return ns.Chronicle:Text(entry.o == 1 and "CONFLICT_SWITCHED" or "CONFLICT_BROKE_WORD", ctx, {
    faction = M:SideName(conflict, entry.side), broken = M:SideName(conflict, OTHER[entry.side]),
    quest = ns.Names.Quest(entry.q),
  })
end

local function renderHouseturn(entry, ctx)
  local conflict = M:Get(entry.c)
  if not conflict then return nil end
  return ns.Chronicle:Text("CONFLICT_HOUSETURN", ctx, {
    house = entry.h, faction = M:SideName(conflict, entry.side), zone = zoneName(conflict),
  })
end

-- Test check (7.10) -------------------------------------------------------------------

local requested = {}             -- quest ids this check asked the client to load, this session

local function hasTitle(q)
  local ok, title = Safe.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, q)
  return ok and type(title) == "string" and title ~= ""
end

local function hasName(f)
  local ok, data = Safe.Call(C_Reputation and C_Reputation.GetFactionDataByID, f)
  local name = ok and Safe.Field(data, "name")
  return type(name) == "string" and name ~= ""
end

-- Factions of both sides, each once; and those without a name from the client.
local function factionGaps(list)
  local seen, count, missing = {}, 0, {}
  for _, conflict in ipairs(list) do
    for _, side in ipairs(SIDES) do
      local f = conflict[side].faction
      if f ~= 0 and not seen[f] then
        seen[f] = true
        count = count + 1
        if not hasName(f) then missing[#missing + 1] = tostring(f) end
      end
    end
  end
  return count, missing
end

-- Zones and anchor maps, each once in data order, as "<id> <client name>" so the tester can compare them
-- with the dataset; and those the client has no map for (Rumours drops a rumour placed there).
local function mapGaps(list)
  local seen, named, missing = {}, {}, {}
  local function check(m)
    if type(m) ~= "number" or seen[m] then return end
    seen[m] = true
    local ok, info = Safe.Call(C_Map and C_Map.GetMapInfo, m)
    local name = ok and Safe.Field(info, "name")
    if type(name) == "string" and name ~= "" then
      named[#named + 1] = m .. " " .. name
    else
      missing[#missing + 1] = tostring(m)
    end
  end
  for _, conflict in ipairs(list) do
    check(conflict.zone)
    check(type(conflict.anchor) == "table" and conflict.anchor.m or nil)
  end
  return named, missing
end

-- A quest without a title is requested first (pending); still without one on a later run, it is missing.
local function questGaps(list)
  local count, pending, missing = 0, {}, {}
  for _, conflict in ipairs(list) do
    for _, side in ipairs(SIDES) do
      for _, q in ipairs(conflict[side].quests) do
        count = count + 1
        local known = hasTitle(q)
        if not known and requested[q] then
          missing[#missing + 1] = tostring(q)
        elseif not known then
          requested[q] = true
          Safe.Call(C_QuestLog and C_QuestLog.RequestLoadQuestByID, q)
          pending[#pending + 1] = tostring(q)
        end
      end
    end
  end
  return count, pending, missing
end

-- Every quest yields a title, every faction a name and every zone and anchor map its map info, so
-- unverified entries can be checked in the client.
local function checkData()
  local list = index().list
  local factions, noName = factionGaps(list)
  local quests, pending, noTitle = questGaps(list)
  local maps, noMap = mapGaps(list)
  local verified = 0
  for _, conflict in ipairs(list) do
    if conflict.verified == true then verified = verified + 1 end
  end
  local detail = string.format("%d conflicts, %d quests, %d factions, %d maps, verified %d/%d", #list, quests,
    factions, #maps + #noMap, verified, #list)
  if #maps > 0 then detail = detail .. "; maps: " .. table.concat(maps, ", ") end
  if #noMap > 0 then detail = detail .. "; no map info: " .. table.concat(noMap, ", ") end
  if #noName > 0 then detail = detail .. "; no faction name: " .. table.concat(noName, ", ") end
  if #noTitle > 0 then detail = detail .. "; no quest title: " .. table.concat(noTitle, ", ") end
  if #pending > 0 then detail = detail .. "; pending, run again: " .. table.concat(pending, ", ") end
  if #noMap > 0 or #noName > 0 or #noTitle > 0 then return false, detail end
  if #pending > 0 then return nil, detail end
  return true, detail
end

-- Lifecycle -----------------------------------------------------------------------------

function M:OnInitialize()
  idx = build()
  follow()
  ns.Log:RegisterKind("alliance", { fields = { "c", "side", "rep" }, keep = true, render = renderAlliance })
  ns.Log:RegisterKind("violation", { fields = { "c", "side", "q", "o" }, keep = true, render = renderViolation })
  ns.Log:RegisterKind("houseturn", { fields = { "c", "side", "q", "h" }, keep = true, render = renderHouseturn })
  ns.Test:Register("Conflicts.data", checkData)
  self.QuestDialog:Initialize()
end

function M:OnEnable()
  self:Subscribe("LOG_ADDED", onLogAdded)
  self:Subscribe("REP_CHANGED", checkReputation)
  self.QuestDialog:Enable()
end

function M:OnWorldReady()
  local char = self:Char()
  if char then record(char) end
  checkReputation()
end

function M:OnDisable()
  self.QuestDialog:Hide()
end

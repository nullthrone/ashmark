local ADDON, ns = ...

-- Core watchers (5.10): the core kinds, the group boundary, played time and blocked actions.
local Watch = ns:NewService("Watch")

local Safe, Log = ns.Safe, ns.Log

local LEGACY_FACTION = 2802
local QUEST_GOLD_WINDOW = 2      -- seconds a quest's money waits for its PLAYER_MONEY
local ABANDON_WINDOW = 2         -- a turn-in this close to a removal is not an abandon
local OTHER_GOLD_EVERY = 600
local PLAYED_EVERY = 300
local MAX_BLOCKED = 20

-- Kinds ------------------------------------------------------------------

local function say(key, values)
  return function(entry, ctx) return ns.Chronicle:Text(key, ctx, values and values(entry, ctx)) end
end

local function quest(entry)
  return { quest = ns.Names.Quest(entry.q) }
end

local function standing(reaction, sex)
  local key = "FACTION_STANDING_LABEL" .. tostring(reaction)
  local label = GetText and GetText(key, sex) or _G[key]
  return type(label) == "string" and label or tostring(reaction)
end

Log:RegisterKind("quest.accept", { fields = { "q" } })
Log:RegisterKind("quest.turnin", { fields = { "q" }, render = say("CORE_LOG_TURNIN", quest) })
Log:RegisterKind("quest.abandon", { fields = { "q" }, render = say("CORE_LOG_ABANDON", quest) })
Log:RegisterKind("zone", {
  fields = { "z", "first" },
  shown = function(entry) return entry.first == true end,
  render = function(entry, ctx)
    if entry.first then
      return ns.Chronicle:Text("CORE_LOG_ZONE_FIRST", ctx, { zone = ns.Names.Map(entry.z) })
    end
  end,
})
Log:RegisterKind("level", { fields = { "l" }, keep = true, render = say("CORE_LOG_LEVEL", function(entry)
  return { level = entry.l }
end) })
Log:RegisterKind("death", { fields = {}, render = say("CORE_LOG_DEATH", function(entry)
  return { place = ns.Names.Map(entry.m and (ns.Where.Zone(entry.m) or entry.m)) }
end) })
Log:RegisterKind("rep", { fields = { "f", "s", "d" }, render = say("CORE_LOG_REP", function(entry, ctx)
  return { faction = ns.Names.Faction(entry.f), standing = standing(entry.s, ctx.char and ctx.char.sex) }
end) })
Log:RegisterKind("gold", { fields = { "src", "c" } })

-- Quests -----------------------------------------------------------------

local turnedIn = {}              -- [questID] = GetTime() of its QUEST_TURNED_IN
local abandoning
local questMoney                 -- defined with the gold contexts below

local function onAccepted(_, _, ...)
  local n = select("#", ...)
  if n == 0 then return end
  local questID = Safe.Value((select(n, ...)))
  if type(questID) ~= "number" then return end
  local ok, index = Safe.Call(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, questID)
  if ok and index ~= nil then
    Log:Add("quest.accept", { q = questID })
  end
end

local function onTurnedIn(_, _, questID, _, money)
  questID, money = Safe.Value(questID), Safe.Value(money)
  if type(questID) ~= "number" then return end
  turnedIn[questID] = GetTime()
  Log:Add("quest.turnin", { q = questID })
  if type(money) == "number" and money > 0 then
    Log:Add("gold", { src = "quest", c = money })
    questMoney(money)
  end
end

local function abandonedAfterRemoval(questID, removedAt)
  local t = turnedIn[questID]
  if t and math.abs(t - removedAt) <= ABANDON_WINDOW then return end
  local ok, done = Safe.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, questID)
  if not ok or done then return end
  if C_QuestLog and C_QuestLog.IsQuestTask then
    local okTask, task = Safe.Call(C_QuestLog.IsQuestTask, questID)
    if not okTask or task then return end
  end
  Log:Add("quest.abandon", { q = questID })
end

-- Waits the whole window, so a turn-in that arrives after the removal is still seen.
local function onRemoved(_, _, questID)
  questID = Safe.Value(questID)
  if type(questID) ~= "number" then return end
  local removedAt = GetTime()
  C_Timer.After(ABANDON_WINDOW, function()
    ns:Call(Watch, "QUEST_REMOVED", abandonedAfterRemoval, questID, removedAt)
  end)
end

local function hookAbandon()
  hooksecurefunc(C_QuestLog, "SetAbandonQuest", Watch:Wrap("SetAbandonQuest", function()
    local ok, questID = Safe.Call(C_QuestLog.GetAbandonQuest)
    abandoning = ok and type(questID) == "number" and questID ~= 0 and questID or nil
  end))
  hooksecurefunc(C_QuestLog, "AbandonQuest", Watch:Wrap("AbandonQuest", function()
    local questID = abandoning
    abandoning = nil
    if questID then Log:Add("quest.abandon", { q = questID }) end
  end))
end

-- Zone and group ----------------------------------------------------------

function Watch:CheckZone()
  local char = ns.DB:Char()
  if not char or ns.DB.readOnly then return end
  local z = ns.Where.Zone(ns.Where().m)
  if not z then return end
  local last = Log:Last(char, "zone")
  if last and last.z == z then return end
  local first = char.zones[z] == nil
  local entry = Log:Add("zone", { z = z, first = first or nil })
  if entry and first then char.zones[z] = entry.t end
end

function Watch:CheckGroup()
  local state = ns.DB:State()
  if not state then return end
  local inGroup = ns.Identity:InGroup()
  if inGroup == (state.inGroup == true) then return end
  state.inGroup = inGroup
  ns.Bus:Fire("GROUP_CHANGED", inGroup)
end

local function checkGroup()
  Watch:CheckGroup()
end

local function onRoster()
  ns.Util.Debounce("Core.group", 1, checkGroup)
end

-- Level and death ----------------------------------------------------------

local function onLevel(_, _, level)
  level = Safe.Value(level)
  if type(level) ~= "number" then return end
  local char = ns.DB:Char()
  if char and not ns.DB.readOnly then char.level = level end
  Log:Add("level", { l = level })
end

local function onDead()
  Log:Add("death", {})
end

-- Reputation ---------------------------------------------------------------

local tracked                    -- faction ids, built at Start
local seen = {}                  -- [f] = { reaction, standing } of the last read
local atEntry = {}               -- [f] = standing at the last rep entry (or the baseline)

local function trackedFactions()
  local list, known = {}, {}
  local function add(f)
    if type(f) == "number" and f ~= 0 and not known[f] then
      known[f] = true
      list[#list + 1] = f
    end
  end
  local data = ns.Data and ns.Data.Conflicts
  for _, conflict in ipairs(type(data) == "table" and data.list or {}) do
    add(conflict.A and conflict.A.faction)
    add(conflict.B and conflict.B.faction)
  end
  add(LEGACY_FACTION)
  return list
end

local function readFaction(f)
  local ok, data = Safe.Call(C_Reputation and C_Reputation.GetFactionDataByID, f)
  if not ok then return nil end
  local values = Safe.Fields(data, "reaction", "currentStanding")
  if values and type(values.reaction) == "number" and type(values.currentStanding) == "number" then
    return values.reaction, values.currentStanding
  end
end

local function baseline(f, reaction, value)
  seen[f] = { reaction, value }
  atEntry[f] = value
end

local function factionsChanged()
  ns.Compat.Check("legacy")
  for _, f in ipairs(tracked or {}) do
    local reaction, value = readFaction(f)
    local last = seen[f]
    if reaction and not last then
      baseline(f, reaction, value)
    elseif reaction and (reaction ~= last[1] or value ~= last[2]) then
      local delta, changed = value - last[2], reaction ~= last[1]
      last[1], last[2] = reaction, value
      if changed then
        Log:Add("rep", { f = f, s = reaction, d = value - atEntry[f] })
        atEntry[f] = value
      end
      ns.Bus:Fire("REP_CHANGED", f, reaction, delta)
    end
  end
end

local function onFaction()
  ns.Util.Debounce("Core.faction", 1, factionsChanged)
end

-- Gold ---------------------------------------------------------------------

local lastMoney
local open = {}                  -- open contexts, most recent last
local sums = {}                  -- [src] = copper gathered while that context is open
local other = 0

-- Quest money is logged from QUEST_TURNED_IN. Its PLAYER_MONEY can come up to QUEST_GOLD_WINDOW
-- before or after it and is not counted a second time.
local questGold, questGoldUntil = 0, 0              -- logged, PLAYER_MONEY not seen yet
local gained, gainedSrc, gainedUntil = 0, nil, 0    -- seen, QUEST_TURNED_IN not yet; nil source: other

function questMoney(money)
  local now = GetTime()
  if gained > 0 and now <= gainedUntil then
    local used = math.min(gained, money)
    gained, money = gained - used, money - used
    if not gainedSrc then
      other = other - used
    elseif sums[gainedSrc] then
      sums[gainedSrc] = sums[gainedSrc] - used
    end
  end
  if now > questGoldUntil then questGold = 0 end
  questGold = questGold + money
  questGoldUntil = now + QUEST_GOLD_WINDOW
end

local function readMoney()
  local ok, money = Safe.Call(GetMoney)
  if ok and type(money) == "number" then return money end
end

local function flushOther()
  if other ~= 0 then
    Log:Add("gold", { src = "other", c = other })
    other = 0
  end
end

local function onMoney()
  local money = readMoney()
  if not money then return end
  if not lastMoney then
    lastMoney = money
    return
  end
  local delta = money - lastMoney
  lastMoney = money
  if delta > 0 and questGold > 0 and GetTime() <= questGoldUntil then
    local used = math.min(questGold, delta)
    questGold, delta = questGold - used, delta - used
  end
  if delta == 0 then return end
  local src = open[#open]
  if src then
    sums[src] = (sums[src] or 0) + delta
  else
    other = other + delta
    ns.Util.Debounce("Core.goldOther", OTHER_GOLD_EVERY, flushOther)
  end
  if delta > 0 then
    local now = GetTime()
    if now > gainedUntil or gainedSrc ~= src then gained = 0 end
    gained, gainedSrc, gainedUntil = gained + delta, src, now + QUEST_GOLD_WINDOW
  end
end

local function opener(src)
  return function()
    for _, known in ipairs(open) do
      if known == src then return end
    end
    open[#open + 1] = src
  end
end

local function closer(src)
  return function()
    for i = #open, 1, -1 do
      if open[i] == src then
        table.remove(open, i)
        local c = sums[src] or 0
        sums[src] = nil
        if c ~= 0 then Log:Add("gold", { src = src, c = c }) end
        return
      end
    end
  end
end

local CONTEXTS = {
  loot = { "LOOT_OPENED", "LOOT_CLOSED" },
  vendor = { "MERCHANT_SHOW", "MERCHANT_CLOSED" },
  trade = { "TRADE_SHOW", "TRADE_CLOSED" },
  mail = { "MAIL_SHOW", "MAIL_CLOSED" },
}

-- Played time and blocked actions ------------------------------------------

local playedMark

local function played()
  local char = ns.DB:Char()
  if not char or ns.DB.readOnly or not playedMark then return end
  local whole = math.floor(GetTime() - playedMark)
  playedMark = playedMark + whole
  ns.Core:Stat("playedSec", whole)
  char.lastSeen = time()
end

local function onBlocked(_, event, addon, fn)
  if Safe.Value(addon) ~= ADDON or ns.DB.readOnly then return end
  fn = Safe.Value(fn)
  ns.DB:Append(AshmarkDB.dev.blocked, { t = time(), event = event, fn = type(fn) == "string" and fn or nil },
    MAX_BLOCKED)
end

-- Lifecycle ----------------------------------------------------------------

-- PLAYER_LOGIN
function Watch:Start()
  tracked = trackedFactions()
  self:RegisterEvent("QUEST_ACCEPTED", onAccepted)
  self:RegisterEvent("QUEST_TURNED_IN", onTurnedIn)
  if ns.Compat.Has.abandonHooks then
    self:Hook("abandon", hookAbandon)
  else
    self:RegisterEvent("QUEST_REMOVED", onRemoved)
  end
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Watch:CheckZone() end)
  self:RegisterEvent("GROUP_ROSTER_UPDATE", onRoster)
  self:RegisterEvent("GROUP_LEFT", onRoster)
  self:RegisterEvent("PLAYER_LEVEL_UP", onLevel)
  self:RegisterEvent("PLAYER_DEAD", onDead)
  self:RegisterEvent("UPDATE_FACTION", onFaction)
  self:RegisterEvent("PLAYER_MONEY", onMoney)
  for src, events in pairs(CONTEXTS) do
    self:RegisterEvent(events[1], opener(src))
    self:RegisterEvent(events[2], closer(src))
  end
  self:RegisterEvent("ADDON_ACTION_BLOCKED", onBlocked)
  self:RegisterEvent("ADDON_ACTION_FORBIDDEN", onBlocked)
  if not ns.DB.readOnly then
    playedMark = GetTime()
    ns.Util.Ticker("Core.played", PLAYED_EVERY, played)
  end
end

-- Start of lifecycle step 3: silent baselines.
function Watch:Baseline()
  lastMoney = readMoney()
  for _, f in ipairs(tracked or {}) do
    local reaction, value = readFaction(f)
    if reaction then baseline(f, reaction, value) end
  end
end

-- End of lifecycle step 3, after every OnWorldReady.
function Watch:WorldReady()
  self:CheckZone()
  self:CheckGroup()
end

-- PLAYER_LOGOUT
function Watch:Logout()
  played()
  flushOther()
end

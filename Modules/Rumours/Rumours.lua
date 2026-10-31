local _, ns = ...

-- Rumours (7.8): what this character does in a conflict becomes a rumour that travels from one Ashmark party to
-- the next, weaker and vaguer with every hop. A rumour names an archetype, a place and a faction, never a
-- character, and its id is random; but party members who hear an own rumour first (hops 0) know whose deed it is,
-- as they know the sender of every addon message. Whoever knows that can read a later copy too: it keeps the id,
-- the content and the age, and its hops (and the zone, continent, faction ladder) give its distance from the
-- source, so its sender grouped with that character (hops 1) or sits that many groups away. A fresh id per hop or
-- a vaguer hop count would not hide this, as content, age and ladder identify the rumour and its hop range anyway;
-- RUMOUR_MODULE_DESC tells the player. Without canSend the module only listens.
local M = ns:NewModule("Rumours", {
  requires = { "addonMessages" },
  optional = { "canSend" },
  modules = { "Fiction" },
  locale = "RUMOUR",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local HALF_LIFE = 3 * 86400
local MIN_STRENGTH = 20
local HOP_KEEP = 70              -- percent of its strength a copy keeps per hop; integer maths keeps floor exact
local CONTINENT_AT = 2           -- hops from which the place is the continent
local VAGUE_AT = 3               -- hops from which the faction is gone
local MAX_HOPS = 9               -- the wire's limit: a copy beyond it travels no further
local MAX_AGE = 2160             -- hours, the wire's limit
local MAX_HEARD = 200
local MAX_TOLD = 50              -- peers per rumour
local TOLD_FOR = 30 * 86400
local PEER_DELAY = 5
local ROUND_EVERY = 120
local PER_ROUND = 3
local NEW_PER_SENDER = 2 * PER_ROUND   -- new rumours one sender may bring per ROUND_EVERY: an honest client sends
                                       -- one round at most, the second absorbs queue delays
local SHOWN_FOR = 86400
local LINES_PER_HOUR = 5
local HOUR = 3600
local ID_TRIES = 10

local SEEDS = { alliance = "ALLIANCE", violation = "BROKE", houseturn = "TURNED" }
local OTHER = { A = "B", B = "A" }

local lastRound                  -- ns.Util.Now() of the last round that sent something
local fresh = {}                 -- [senderGuid] = { start, count }: new rumours in the sender's current window

-- Stores --------------------------------------------------------------------------------

-- heard and told (4), or nil if the store is missing.
local function stores()
  local db = AshmarkDB
  local rumours = type(db) == "table" and db.rumours
  if type(rumours) == "table" and type(rumours.heard) == "table" and type(rumours.told) == "table" then
    return rumours.heard, rumours.told
  end
end

local function valid(r)
  return type(r) == "table" and type(r.id) == "string" and type(r.tpl) == "string" and type(r.a) == "string"
    and type(r.f) == "number" and type(r.m) == "number" and type(r.hops) == "number" and type(r.t) == "number"
end

-- A copy decays from `heard`, the moment it got its strength; for an own rumour that is t. A received copy's
-- strength has already lost the rumour's age on the sender's side, so decaying it from t would count that twice.
local function strength(r, now)
  local s, since = r.strength, r.heard
  if type(s) ~= "number" or type(since) ~= "number" then return 0 end
  return ns.Util.Clamp(math.floor(s * 0.5 ^ (math.max(now - since, 0) / HALF_LIFE)), 0, 100)
end

local function pruneTold(peers, now)
  local list = {}
  for guid, t in pairs(peers) do
    if type(t) ~= "number" or now - t > TOLD_FOR then
      peers[guid] = nil
    else
      list[#list + 1] = { guid = guid, t = t }
    end
  end
  if #list <= MAX_TOLD then return end
  table.sort(list, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return tostring(a.guid) < tostring(b.guid)
  end)
  for i = 1, #list - MAX_TOLD do peers[list[i].guid] = nil end
end

-- Rumours below MIN_STRENGTH go, then the weakest beyond MAX_HEARD, received copies before own rumours, so what
-- others send can never push out this character's own; each takes its told list with it.
local function prune(now)
  local heard, told = stores()
  if not heard then return end
  local alive = {}
  for id, r in pairs(heard) do
    local s = valid(r) and strength(r, now) or 0
    if s < MIN_STRENGTH then
      heard[id] = nil
    else
      alive[#alive + 1] = { id = id, s = s, own = r.own == true }
    end
  end
  if #alive > MAX_HEARD then
    table.sort(alive, function(a, b)
      if a.own ~= b.own then return b.own end
      if a.s ~= b.s then return a.s < b.s end
      return tostring(a.id) < tostring(b.id)
    end)
    for i = 1, #alive - MAX_HEARD do heard[alive[i].id] = nil end
  end
  for id, peers in pairs(told) do
    if heard[id] == nil or type(peers) ~= "table" then
      told[id] = nil
    else
      pruneTold(peers, now)
    end
  end
end

local function tell(told, id, guid, now)
  if type(guid) ~= "string" then return end
  local peers = told[id]
  if type(peers) ~= "table" then
    peers = {}
    told[id] = peers
  end
  peers[guid] = now
end

-- Public services (3.8) ---------------------------------------------------------------------

function M:Get(id)
  local heard = stores()
  local r = heard and type(id) == "string" and heard[id]
  if type(r) == "table" then return r end
end

function M:Strength(rumour)
  if type(rumour) ~= "table" then return 0 end
  return strength(rumour, ns.Util.Now())
end

-- Seeds ---------------------------------------------------------------------------------------

-- Another unit's public service (3.8), looked up at call time; nil if the unit or the call is missing.
local function ask(unit, method, ...)
  local service = ns[unit]
  local ok, result = Safe.Call(service and service[method], service, ...)
  if ok then return result end
end

-- 8 random hex characters, never derived from a GUID; drawn again on a collision.
local function newId(heard)
  for _ = 1, ID_TRIES do
    local id = ns.Util.Token()
    if heard[id] == nil then return id end
  end
end

-- An own rumour that already says this and is still alive, or nil.
local function ownAlive(heard, tpl, a, f, m, now)
  for _, r in pairs(heard) do
    if valid(r) and r.own == true and r.tpl == tpl and r.a == a and r.f == f and r.m == m
      and strength(r, now) >= MIN_STRENGTH then
      return r
    end
  end
end

-- An own alliance, violation or house turn; f is the faction allied with, broken with or taken. An own rumour
-- with the same template, archetype, faction and zone that is still alive stands in for the new one, so the
-- conflicts of one faction pair in one zone make one rumour, not one per conflict.
local function seed(entry, char)
  local heard = stores()
  local conflict = heard and ask("Conflicts", "Get", entry.c)
  if type(conflict) ~= "table" or type(conflict.zone) ~= "number" then return end
  local side = conflict[entry.k == "violation" and OTHER[entry.side] or entry.side]
  if not (type(side) == "table" and type(side.faction) == "number") then return end
  -- Stamped by the same clock that decays it (ns.Util.Now), not the entry's system time.
  local now = ns.Util.Now()
  local tpl, a = SEEDS[entry.k], ask("Profile", "Archetype", char) or "PRAGMATIST"
  if ownAlive(heard, tpl, a, side.faction, conflict.zone, now) then return end
  local id = newId(heard)
  if not id then return end
  heard[id] = {
    id = id, tpl = tpl, a = a, f = side.faction,
    m = conflict.zone, hops = 0, strength = 100, t = now, heard = now, own = true,
  }
  prune(now)
end

local function onLogAdded(_, _, entry, char)
  if SEEDS[entry.k] then seed(entry, char) end
end

-- Chat lines ----------------------------------------------------------------------------------

local function text(r)
  local vague = r.f == 0
  return ns.Format(L["RUMOUR_HEARD_" .. r.tpl .. (vague and "_VAGUE" or "")], {
    archetype = L["PROFILE_" .. r.a],
    place = ns.Names.Map(r.m),
    faction = not vague and ns.Names.Faction(r.f) or nil,
  })
end

-- One rumour line within the limits: LINES_PER_HOUR in total, and a rumour shown rests SHOWN_FOR before it is
-- picked again. True if the line was printed.
local function say(r, now)
  local char = M:Char()
  local state = char and char.state
  local chat = ns.UI and ns.UI.ChatLine
  if type(state) ~= "table" or not chat then return false end
  local shown, lines = {}, {}
  for id, t in pairs(type(state.shown) == "table" and state.shown or {}) do
    if type(t) == "number" and now - t < SHOWN_FOR then shown[id] = t end
  end
  for _, t in ipairs(type(state.lines) == "table" and state.lines or {}) do
    if type(t) == "number" and now - t < HOUR then lines[#lines + 1] = t end
  end
  state.shown, state.lines = shown, lines
  if #lines >= LINES_PER_HOUR or not chat:Print(text(r), "rumour") then return false end
  lines[#lines + 1] = now
  shown[r.id] = now
  return true
end

-- Re-print: the strongest heard rumour of the zone just entered or its continent, unless it was shown in the last
-- 24 hours. Own rumours were never printed, so they are not printed again.
local function onZone()
  if not ns.ready then return end
  local heard = stores()
  local m = ns.Where().m
  local zone, continent = ns.Where.Zone(m), ns.Where.Continent(m)
  if not (heard and (zone or continent)) then return end
  local char = M:Char()
  local state = char and char.state
  local shown = type(state) == "table" and type(state.shown) == "table" and state.shown or {}
  local now = ns.Util.Now()
  local best, most
  for id, r in pairs(heard) do
    local last = shown[id]
    if valid(r) and not r.own and (r.m == zone or r.m == continent)
      and not (type(last) == "number" and now - last < SHOWN_FOR) then
      local s = strength(r, now)
      if s >= MIN_STRENGTH and (not most or s > most or (s == most and id < best.id)) then best, most = r, s end
    end
  end
  if best then say(best, now) end
end

-- Receiving -----------------------------------------------------------------------------------

local function knownMap(m)
  local ok, info = Safe.Call(C_Map and C_Map.GetMapInfo, m)
  return ok and type(info) == "table"
end

-- The copy this client keeps of a rumour from the wire, or nil if it is too weak or its place is unknown.
local function fromWire(fields, now)
  local id, tpl, hops, s, age, a, f, m = unpack(fields, 1, 8)
  hops = hops + 1
  s = math.floor(s * HOP_KEEP / 100)
  if hops >= CONTINENT_AT then m = ns.Where.Continent(m) end
  if hops >= VAGUE_AT then f = 0 end
  if s < MIN_STRENGTH or not knownMap(m) then return nil end
  return Safe.Clean({ id = id, tpl = tpl, a = a, f = f, m = m, hops = hops, strength = s, t = now - age * HOUR,
                      heard = now })
end

-- True if this new rumour is beyond what one sender may bring: NEW_PER_SENDER per ROUND_EVERY. Starting a window
-- also forgets the windows of other senders that have ended.
local function flooding(guid, now)
  local window = fresh[guid]
  if not window or now - window.start >= ROUND_EVERY then
    for other, w in pairs(fresh) do
      if now - w.start >= ROUND_EVERY then fresh[other] = nil end
    end
    window = { start = now, count = 0 }
    fresh[guid] = window
  end
  window.count = window.count + 1
  return window.count > NEW_PER_SENDER
end

-- RU, which Comm accepts only from senders an HI has validated. A known id keeps the stronger copy and prints
-- nothing; either way the sender knows it, so it is never told back. A new rumour beyond the sender's budget
-- (flooding) is dropped; otherwise it is stored, then RUMOUR_HEARD and one chat line within the line limits
-- follow, and the rumour entry is written only with a printed line, so other players can add at most
-- LINES_PER_HOUR entries an hour to this character's log.
local function onRumour(from, fields)
  local heard, told = stores()
  if not heard or type(from.guid) ~= "string" then return end
  local now = ns.Util.Now()
  local r = fromWire(fields, now)
  if not r then return end
  local known = heard[r.id]
  if type(known) == "table" then
    if not known.own and r.strength > strength(known, now) then heard[r.id] = r end
    tell(told, r.id, from.guid, now)
    return
  end
  if flooding(from.guid, now) then return end
  heard[r.id] = r
  tell(told, r.id, from.guid, now)
  M:Fire("RUMOUR_HEARD", r)
  if say(r, now) then ns.Log:Add("rumour", { r = r.id }) end
  prune(now)
end

-- Exchange --------------------------------------------------------------------------------------

local function untold(knows, present)
  for guid in pairs(present) do
    if not (type(knows) == "table" and knows[guid]) then return true end
  end
  return false
end

-- Strong enough, able to travel, and new to some present peer: newest first, then strongest.
local function candidates(heard, told, present, now)
  local list = {}
  for id, r in pairs(heard) do
    local s = valid(r) and r.hops <= MAX_HOPS and strength(r, now) or 0
    if s >= MIN_STRENGTH and untold(told[id], present) then list[#list + 1] = { r = r, s = s } end
  end
  table.sort(list, function(a, b)
    if a.r.t ~= b.r.t then return a.r.t > b.r.t end
    if a.s ~= b.s then return a.s > b.s end
    return a.r.id < b.r.id
  end)
  return list
end

local round

-- One exchange round; a round due within ROUND_EVERY of the last one waits for the window to end.
local function exchange()
  if not ns.Compat.Has.canSend then return end
  local heard, told = stores()
  local present = ask("Fiction", "PresentPeers")
  if not (heard and type(present) == "table" and next(present)) then return end
  local now = ns.Util.Now()
  local list = candidates(heard, told, present, now)
  if #list == 0 then return end
  local wait = lastRound and lastRound + ROUND_EVERY - now or 0
  if wait > 0 then
    ns.Util.Debounce("Rumours.round", wait, round)
    return
  end
  for i = 1, math.min(PER_ROUND, #list) do
    local r, s = list[i].r, list[i].s
    local age = ns.Util.Clamp(math.floor((now - r.t) / HOUR), 0, MAX_AGE)
    if ns.Comm:Send("RU", { r.id, r.tpl, r.hops, s, age, r.a, r.f, r.m }, "PARTY") then
      lastRound = now
      for guid in pairs(present) do tell(told, r.id, guid, now) end
    end
  end
end
round = M:Wrap("round", exchange)

local function onPeerSeen()
  ns.Util.Debounce("Rumours.peer", PEER_DELAY, round)
end

local function onChapterClosed(_, _, _, members)
  if type(members) == "table" and #members > 0 then round() end
end

-- Test checks (7.10) -----------------------------------------------------------------------------

local function checkRumours()
  if M.unavailable then return false, "unavailable: " .. table.concat(M.unavailable, ", ") end
  if not M.enabled then return nil, "off" end
  local heard, told = stores()
  local now = ns.Util.Now()
  local own, others, strong, toldTo = 0, 0, 0, 0
  for _, r in pairs(heard or {}) do
    if type(r) == "table" and r.own then own = own + 1 else others = others + 1 end
    if valid(r) and strength(r, now) >= MIN_STRENGTH then strong = strong + 1 end
  end
  for _, peers in pairs(told or {}) do
    for _ in pairs(type(peers) == "table" and peers or {}) do toldTo = toldTo + 1 end
  end
  local detail = string.format("rumours %d (own %d, heard %d, strong enough to pass on %d), told %d times, %s",
    own + others, own, others, strong, toldTo, ns.Compat.Has.canSend and "send and receive" or "receive only")
  if own + others == 0 then return nil, detail .. ". " .. L.RUMOUR_TEST_HOWTO end
  return true, detail
end

-- Lifecycle --------------------------------------------------------------------------------------

function M:OnInitialize()
  ns.Log:RegisterKind("rumour", { fields = { "r" } })
  ns.Test:Register("Rumours.counts", checkRumours)
end

function M:OnEnable()
  ns.Comm:Register("RU", onRumour, self)
  self:Subscribe("LOG_ADDED", onLogAdded)
  self:Subscribe("PEER_SEEN", onPeerSeen)
  self:Subscribe("CHAPTER_CLOSED", onChapterClosed)
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", onZone)
end

function M:OnWorldReady()
  prune(ns.Util.Now())
end

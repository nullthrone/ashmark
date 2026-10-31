local _, ns = ...

-- Silent shared fiction (7.9): Ashmark users in one party tell each other who they are, an archetype, an origin
-- and a profile, over addon messages and nothing else. Every client greets on its own roster change, so nobody
-- replies and nothing loops. Without canSend the module only listens.
local M = ns:NewModule("Fiction", {
  requires = { "addonMessages" },
  optional = { "canSend" },
  locale = "FICTION",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local MAX_PEERS = 500
local ROSTER_DELAY = 2
local GREET_EVERY = 30
local VERSION_MAX = 20

local lastGreet                  -- time() of the last greeting; after a /reload, seeded from state.greeted

-- Stores ------------------------------------------------------------------------------

local function peers()
  local db = AshmarkDB
  local all = type(db) == "table" and db.peers
  if type(all) == "table" then return all end
end

local function greetedOf(char)
  local state = type(char) == "table" and char.state
  if type(state) ~= "table" then return nil end
  if type(state.greeted) ~= "table" then state.greeted = {} end
  return state.greeted
end

local function count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

-- Oldest `last` first; ties by GUID, so the result never depends on pairs().
local function prune(all)
  local excess = count(all) - MAX_PEERS
  if excess <= 0 then return end
  local list = {}
  for guid, peer in pairs(all) do
    list[#list + 1] = { guid = guid, last = type(peer) == "table" and tonumber(peer.last) or 0 }
  end
  table.sort(list, function(a, b)
    if a.last ~= b.last then return a.last < b.last end
    return tostring(a.guid) < tostring(b.guid)
  end)
  for i = 1, excess do all[list[i].guid] = nil end
end

-- Public services (3.8) ---------------------------------------------------------------

function M:Peer(guid)
  local all = peers()
  local peer = all and type(guid) == "string" and all[guid]
  if type(peer) == "table" then return peer end
end

function M:PresentPeers()
  local out = {}
  for guid in pairs(ns.Identity:Group("party")) do
    local peer = M:Peer(guid)
    if peer then out[guid] = peer end
  end
  return out
end

-- Greeting ----------------------------------------------------------------------------

-- Another unit's public service (3.8), looked up at call time; nil if the unit or the call is missing.
local function ask(unit, method, ...)
  local service = ns[unit]
  local ok, result = Safe.Call(service and service[method], service, ...)
  if ok then return result end
end

-- ns.version stripped to the characters the wire allows, or "dev".
local function version()
  local v = (tostring(ns.version or ""):gsub("[^%w.%-]", "")):sub(1, VERSION_MAX)
  if v == "" then return "dev" end
  return v
end

-- HI, then PR right after it; false if Comm refused the HI (sharing off, cannot send, not grouped).
local function greet(char, guid)
  local hi = { guid, ask("Profile", "Archetype", char) or "PRAGMATIST", ask("Profile", "Origin", char) or 0,
               ns.Identity:Ruleset(), version() }
  if not ns.Comm:Send("HI", hi, "PARTY") then return false end
  local axes = ask("Profile", "Axes", char) or {}
  ns.Comm:Send("PR", { guid, axes.fidelity or 0, axes.habitat or 0, axes.mercy or 0 }, "PARTY")
  return true
end

local check

-- The roster check (7.9): forget members who left, then greet once if someone in the party is new to us.
local function rosterCheck()
  local char = M:Char()
  local greeted = greetedOf(char)
  if not greeted then return end
  local party = ns.Identity:Group("party")
  for guid in pairs(greeted) do
    if not party[guid] then greeted[guid] = nil end
  end
  local due = false
  for guid in pairs(party) do
    if not greeted[guid] then
      due = true
      break
    end
  end
  if not due or not ns.Compat.Has.canSend then return end
  local now = time()
  local wait = lastGreet and lastGreet + GREET_EVERY - now or 0
  if wait > 0 then
    -- Due inside the window: it waits instead of being dropped.
    ns.Util.Debounce("Fiction.greet", wait, check)
    return
  end
  local me = Safe.UnitGUID("player")
  if not (me and greet(char, me)) then return end
  lastGreet = now
  for guid in pairs(party) do greeted[guid] = now end
end
check = M:Wrap("greet", rosterCheck)

local function onRoster()
  ns.Util.Debounce("Fiction.roster", ROSTER_DELAY, check)
end

local function onGroupChanged(_, _, inGroup)
  if inGroup then return end
  local char = M:Char()
  if char and type(char.state) == "table" then char.state.greeted = {} end
end

-- Receiving ---------------------------------------------------------------------------

local function seenByOf(old)
  local out = {}
  local list = old and old.seenBy
  if type(list) == "table" then
    for guid, archetype in pairs(list) do out[guid] = archetype end
  end
  return out
end

-- HI (validated by Comm against the party units): the whole record is built, then stored, then the peer entry
-- on first sight by this character or an archetype change, then PEER_SEEN.
local function onHello(from, fields)
  local guid = fields[1]
  if from.guid ~= guid then return end
  local seen = Safe.Clean({ guid = guid, archetype = fields[2], origin = fields[3], ruleset = fields[4],
                            version = fields[5] })
  local char, all = M:Char(), peers()
  if not (seen and char and type(char.guid) == "string" and all) then return end
  local old = M:Peer(guid)
  local now = time()
  local seenBy = seenByOf(old)
  local before = seenBy[char.guid]
  seenBy[char.guid] = seen.archetype
  local peer = {
    guid = guid, archetype = seen.archetype, origin = seen.origin, ruleset = seen.ruleset, version = seen.version,
    profile = old and type(old.profile) == "table" and old.profile or nil,
    first = old and type(old.first) == "number" and old.first or now,
    last = now,
    seenBy = seenBy,
  }
  all[guid] = peer
  if not old then prune(all) end
  if before ~= seen.archetype then ns.Log:Add("peer", { p = guid, a = seen.archetype }) end
  M:Fire("PEER_SEEN", guid, peer, old == nil)
end

-- PR updates the profile of a peer that has said HI; one that arrives first is dropped.
local function onProfile(from, fields)
  local guid = fields[1]
  local peer = from.guid == guid and M:Peer(guid)
  if not peer then return end
  local profile = Safe.Clean({ fidelity = fields[2], habitat = fields[3], mercy = fields[4] })
  if profile then peer.profile = profile end
end

-- Test checks (7.10) -------------------------------------------------------------------------

local function mode()
  if not ns.Compat.Has.canSend then return "receive only" end
  if ns.Settings:Get("Comm.share") ~= true then return "receive only (sharing off)" end
  return "send and receive"
end

local function checkPeers()
  if M.unavailable then return false, "unavailable: " .. table.concat(M.unavailable, ", ") end
  if not M.enabled then return nil, "off" end
  local char = M:Char()
  local own = char and char.guid
  local total, mine = 0, 0
  for _, peer in pairs(peers() or {}) do
    total = total + 1
    if type(peer) == "table" and type(peer.seenBy) == "table" and own and peer.seenBy[own] then mine = mine + 1 end
  end
  local detail = string.format("peers %d (met by this character %d), present %d, greeted %d, %s, version %s",
    total, mine, count(M:PresentPeers()), count(greetedOf(char)), mode(), version())
  if total == 0 then return nil, detail .. ". " .. L.FICTION_TEST_HOWTO end
  return true, detail
end

-- Lifecycle ------------------------------------------------------------------------------------

function M:OnInitialize()
  ns.Log:RegisterKind("peer", { fields = { "p", "a" }, keep = true })
  ns.Test:Register("Fiction.peers", checkPeers)
end

function M:OnEnable()
  ns.Comm:Register("HI", onHello, self)
  ns.Comm:Register("PR", onProfile, self)
  self:RegisterEvent("GROUP_ROSTER_UPDATE", onRoster)
  self:Subscribe("GROUP_CHANGED", onGroupChanged)
end

function M:OnWorldReady()
  for _, t in pairs(greetedOf(self:Char()) or {}) do
    if type(t) == "number" and (not lastGreet or t > lastGreet) then lastGreet = t end
  end
  check()
end

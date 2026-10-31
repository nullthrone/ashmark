-- Fixtures for the Encounters specs (not shipped): group members as unit fixtures, roster changes through the
-- events Core coalesces into GROUP_CHANGED, a log-in after an offline gap, stored contacts, and a stand-in for
-- Fiction's Peer service (3.8).
local mock = {}

mock.FILES = { "UI/ChatLine.lua", "Modules/Encounters" }

mock.ME = "Player-1-00000001"
mock.ALT = "Player-1-0000000b"

mock.PEOPLE = {
  thalen = { guid = "Player-1-00000002", name = "Thalen", surname = "Brightwood", classFile = "PALADIN",
             className = "Paladin", raceID = 1, sex = 2, faction = "Alliance", level = 20, isPlayer = true },
  mira = { guid = "Player-1-00000003", name = "Mira", classFile = "MAGE", className = "Mage", raceID = 7, sex = 3,
           faction = "Alliance", level = 21, isPlayer = true },
  kel = { guid = "Player-1-00000004", name = "Kel", classFile = "ROGUE", className = "Rogue", raceID = 3, sex = 2,
          faction = "Alliance", level = 19, isPlayer = true },
  orla = { guid = "Player-1-00000005", name = "Orla", classFile = "PRIEST", className = "Priest", raceID = 4,
           sex = 3, faction = "Alliance", level = 22, isPlayer = true },
}

-- The alt that logs in on the same account in the per-character specs.
mock.BRYN = { guid = mock.ALT, name = "Bryn", surname = "Ashvale", classFile = "HUNTER", className = "Hunter",
              classID = 3, raceID = 3, raceFile = "Dwarf", raceName = "Dwarf", sex = 3, faction = "Alliance",
              level = 12, isPlayer = true }

function mock.guid(key)
  return mock.PEOPLE[key].guid
end

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

-- party1..n become the named people (or fixture tables); the other party slots are emptied.
function mock.party(wow, ...)
  for i = 1, 4 do wow.unit("party" .. i, nil) end
  for i = 1, select("#", ...) do
    local who = select(i, ...)
    wow.unit("party" .. i, type(who) == "table" and who or copy(mock.PEOPLE[who]))
  end
end

-- A roster change: the event, then the second in which Core and Encounters coalesce it.
function mock.roster(wow)
  wow.fire("GROUP_ROSTER_UPDATE")
  wow.advance(1)
end

function mock.join(wow, ...)
  mock.party(wow, ...)
  mock.roster(wow)
end

function mock.leave(wow)
  mock.party(wow)
  wow.fire("GROUP_LEFT")
  mock.roster(wow)
end

-- One whole session with the named people: join, opts.during(), leave.
function mock.session(wow, ns, people, during)
  mock.join(wow, unpack(people))
  local session = ns.Encounters:OpenSession()
  if during then during(session) end
  mock.leave(wow)
  return session
end

-- Core, Locales, ChatLine and the Encounters files (plus opts.files), opts.setup(ns), then login.
function mock.boot(wow, opts)
  opts = opts or {}
  local files = {}
  for _, f in ipairs(mock.FILES) do files[#files + 1] = f end
  for _, f in ipairs(opts.files or {}) do files[#files + 1] = f end
  local ns = wow.load(files)
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

-- A new client session after `gap` seconds offline, with the saved data and world of the last one.
-- opts.crash skips the logout, so lastSeen keeps its last ticker value; opts.player and opts.party change
-- who logs in and the group they find; opts.files and opts.setup as for boot.
function mock.relog(wow, gap, opts)
  opts = opts or {}
  if not opts.crash then wow.logout() end
  local saved = wow.deepcopy(_G.AshmarkDB)
  local units = wow.deepcopy(wow.state.units)
  local epoch, map = wow.state.epoch, wow.state.map
  wow.reset()
  wow.state.units = units
  wow.state.epoch = epoch + (gap or 0)
  wow.state.map = map
  if opts.player then wow.unit("player", copy(opts.player)) end
  if opts.party then mock.party(wow, unpack(opts.party)) end
  wow.saved(saved)
  return mock.boot(wow, opts)
end

-- A stored contact: fields over a default record met `count` times by `char`, last at `last`.
function mock.contact(guid, fields)
  local contact = { guid = guid, name = "Someone", note = "", byChar = {} }
  for k, v in pairs(fields or {}) do contact[k] = v end
  return contact
end

function mock.met(count, last, extra)
  local rec = { count = count, first = last - 1000, last = last, outcomes = { travel = count }, sessions = {} }
  for k, v in pairs(extra or {}) do rec[k] = v end
  return rec
end

-- ns.Fiction with the Peer call Encounters makes; peers = { [guid] = Peer }.
function mock.fiction(ns, peers)
  ns.Fiction = { Peer = function(_, guid) return peers[guid] end }
  return ns.Fiction
end

-- Kinds of the character's log entries, in order, without Core's zone entries.
function mock.kinds(char)
  local out = {}
  for _, entry in ipairs(char.log) do
    if entry.k ~= "zone" then out[#out + 1] = entry.k end
  end
  return out
end

-- Records every topic in `topics` as { topic, ... } in `into`.
function mock.listen(ns, topics, into)
  for _, topic in ipairs(topics) do
    ns.Core:Subscribe(topic, function(_, t, ...) into[#into + 1] = { t, ... } end)
  end
  return into
end

return mock

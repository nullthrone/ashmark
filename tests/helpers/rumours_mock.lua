-- Fixtures for the Rumours specs (not shipped): stand-ins for the Conflicts and Profile services (3.8) and the
-- kinds Conflicts registers, party members who have said HI, RU messages from them, stored rumours and the RU
-- messages this client sent. Fiction is the real module, so PEER_SEEN comes from a real HI.
local fiction = require("tests.helpers.fiction_mock")

local mock = {}

mock.FILES = { "UI/ChatLine.lua", "Modules/Fiction", "Modules/Rumours" }

mock.ME = fiction.ME
mock.MIRA, mock.THALEN, mock.KEL = fiction.guid("mira"), fiction.guid("thalen"), fiction.guid("kel")

-- Desolace (1443, on Kalimdor 1414) with both sides' factions; Stranglethorn (1434) with a side without one.
mock.CONFLICTS = {
  gelkis = { id = "gelkis", zone = 1443, A = { faction = 92, quests = { 1382 } },
             B = { faction = 93, quests = { 1385 } } },
  bloodsail = { id = "bloodsail", zone = 1434, A = { faction = 87, quests = { 4621 } },
                B = { faction = 0, quests = { 608 } } },
}

mock.archetype = "OATHKEEPER"

-- After the Fiction mock's Profile stand-in, whose archetype this one replaces.
function mock.stubs(ns)
  ns.Conflicts = { Get = function(_, id) return mock.CONFLICTS[id] end }
  ns.Profile.Archetype = function() return mock.archetype end
  ns.Log:RegisterKind("alliance", { fields = { "c", "side", "rep" }, keep = true })
  ns.Log:RegisterKind("violation", { fields = { "c", "side", "q", "o" }, keep = true })
  ns.Log:RegisterKind("houseturn", { fields = { "c", "side", "q", "h" }, keep = true })
end

-- Core, Locales, ChatLine, Fiction and Rumours, the stand-ins, opts.setup(ns), then login. The party (opts.party,
-- names from the Fiction mock) is in place at login.
function mock.boot(wow, opts)
  opts = opts or {}
  mock.archetype = "OATHKEEPER"
  if opts.party then fiction.party(wow, unpack(opts.party)) end
  local ns = wow.load(mock.FILES)
  fiction.profile(ns)
  mock.stubs(ns)
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

-- AshmarkDB before login with these heard rumours and told lists.
function mock.saved(wow, heard, told)
  return wow.saved({ schema = 1, rumours = { heard = heard or {}, told = told or {} } })
end

-- A stored rumour: fields over a received default at full strength heard at `at`.
function mock.rumour(id, at, fields)
  local r = { id = id, tpl = "ALLIANCE", a = "WANDERER", f = 92, m = 1443, hops = 1, strength = 70, t = at,
              heard = at }
  for k, v in pairs(fields or {}) do r[k] = v end
  return r
end

-- party members join; each of the named people then says HI (Fiction stores them as peers).
function mock.peers(wow, ...)
  fiction.join(wow, ...)
  for i = 1, select("#", ...) do fiction.hi(wow, (select(i, ...))) end
end

-- An RU message from a party member: { id, tpl, hops, strength, age, archetype, faction, map } with defaults.
function mock.ru(wow, who, fields)
  local f = fields or {}
  fiction.receive(wow, who, table.concat({ "1", "RU", f.id or "deadbeef", f.tpl or "ALLIANCE",
    tostring(f.hops or 0), tostring(f.strength or 100), tostring(f.age or 0), f.a or "OATHKEEPER",
    tostring(f.f or 92), tostring(f.m or 1443) }, "|"))
end

-- The RU messages this client sent, decoded: { id, tpl, hops, strength, age, a, f, m } each.
function mock.sentRU(wow)
  local out = {}
  for _, m in ipairs(wow.sent) do
    local id, tpl, hops, s, age, a, f, map = m.text:match("^1|RU|(%x+)|(%u+)|(%d+)|(%d+)|(%d+)|(%u+)|(%d+)|(%d+)$")
    if id then
      out[#out + 1] = { id = id, tpl = tpl, hops = tonumber(hops), strength = tonumber(s), age = tonumber(age),
                        a = a, f = tonumber(f), m = tonumber(map), text = m.text }
    end
  end
  return out
end

function mock.ids(list)
  local out = {}
  for i, r in ipairs(list) do out[i] = r.id end
  return out
end

-- The ids of the rumours in AshmarkDB.rumours.heard, sorted.
function mock.heardIds()
  local out = {}
  for id in pairs(_G.AshmarkDB.rumours.heard) do out[#out + 1] = id end
  table.sort(out)
  return out
end

-- Rumour lines (in the monster say colour), without Ashmark's prefix.
function mock.lines(wow)
  local out, say = {}, ChatTypeInfo.MONSTER_SAY
  for i, line in ipairs(wow.chat) do
    local c = wow.chatColors[i]
    local text = line:match("^|c%x+Ashmark|r: (.*)$")
    if text and c and c[1] == say.r and c[2] == say.g and c[3] == say.b then out[#out + 1] = text end
  end
  return out
end

mock.entries = fiction.entries
mock.hi = fiction.hi
mock.listen = fiction.listen
mock.check = fiction.check
mock.join = fiction.join
mock.party = fiction.party

return mock

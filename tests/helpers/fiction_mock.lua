-- Fixtures for the Fiction specs (not shipped): party members as unit fixtures, roster changes through the events
-- Core and Fiction coalesce, addon messages from party members, the messages this client sent, and a stand-in
-- for Profile's public services (3.8).
local mock = {}

mock.FILES = { "Modules/Fiction" }

mock.ME = "Player-1-00000001"

mock.PEOPLE = {
  mira = { guid = "Player-1-00000002", name = "Mira", classFile = "MAGE", className = "Mage", raceID = 7, sex = 3,
           faction = "Alliance", level = 21, isPlayer = true, sender = "Mira-Forever" },
  thalen = { guid = "Player-1-00000003", name = "Thalen", classFile = "PALADIN", className = "Paladin", raceID = 1,
             sex = 2, faction = "Alliance", level = 20, isPlayer = true, sender = "Thalen-Forever" },
  kel = { guid = "Player-1-00000004", name = "Kel", classFile = "ROGUE", className = "Rogue", raceID = 3, sex = 2,
          faction = "Alliance", level = 19, isPlayer = true, sender = "Kel-Forever" },
}

-- What the stand-in Profile answers for the player.
mock.PROFILE = { archetype = "OATHKEEPER", origin = 1443, axes = { fidelity = 41, habitat = -7, mercy = 12 } }

function mock.guid(key)
  return mock.PEOPLE[key].guid
end

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

-- ns.Profile with the calls Fiction makes, answering from mock.PROFILE (edit it to change the answers).
function mock.profile(ns)
  ns.Profile = {
    Archetype = function() return mock.PROFILE.archetype end,
    Origin = function() return mock.PROFILE.origin end,
    Axes = function() return copy(mock.PROFILE.axes) end,
  }
  return ns.Profile
end

-- party1..n become the named people; the other party slots are emptied.
function mock.party(wow, ...)
  for i = 1, 4 do wow.unit("party" .. i, nil) end
  for i = 1, select("#", ...) do
    wow.unit("party" .. i, copy(mock.PEOPLE[select(i, ...)]))
  end
end

-- A roster change: the event, then the 2 s in which Core and Fiction coalesce it.
function mock.roster(wow)
  wow.fire("GROUP_ROSTER_UPDATE")
  wow.advance(2)
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

-- Core, Locales and Fiction (plus opts.files), the Profile stand-in, opts.setup(ns), then login.
function mock.boot(wow, opts)
  opts = opts or {}
  local files = {}
  for _, f in ipairs(mock.FILES) do files[#files + 1] = f end
  for _, f in ipairs(opts.files or {}) do files[#files + 1] = f end
  local ns = wow.load(files)
  mock.profile(ns)
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

-- An addon message from a party member on PARTY, as the client delivers it.
function mock.receive(wow, who, text)
  wow.fire("CHAT_MSG_ADDON", "Ashmark", text, "PARTY", mock.PEOPLE[who].sender)
end

function mock.hi(wow, who, archetype, origin, ruleset, version)
  mock.receive(wow, who, table.concat({ "1", "HI", mock.guid(who), archetype or "WANDERER",
    tostring(origin or 1429), ruleset or "RP", version or "1.0.0" }, "|"))
end

function mock.pr(wow, who, fidelity, habitat, mercy)
  mock.receive(wow, who, table.concat({ "1", "PR", mock.guid(who), tostring(fidelity or 0), tostring(habitat or 0),
    tostring(mercy or 0) }, "|"))
end

-- The types of the messages this client sent, in order ("HI", "PR", ...).
function mock.sent(wow)
  local out = {}
  for _, m in ipairs(wow.sent) do out[#out + 1] = m.text:match("^1|(%u+)|") end
  return out
end

-- Entries of a kind in the current character's log.
function mock.entries(ns, kind)
  local out = {}
  for entry in ns.Log:Iter(ns.DB:Char(), 1) do
    if entry.k == kind then out[#out + 1] = entry end
  end
  return out
end

-- Records every topic in `topics` as { topic, ... } in `into`.
function mock.listen(ns, topics, into)
  local spy = ns.FictionSpec or ns:NewService("FictionSpec")
  for _, topic in ipairs(topics) do
    spy:Subscribe(topic, function(_, t, ...) into[#into + 1] = { t, ... } end)
  end
  return into
end

function mock.check(ns, id)
  for _, c in ipairs(ns.Test.checks) do
    if c.id == id then return c.fn() end
  end
  error("no test check " .. id)
end

return mock

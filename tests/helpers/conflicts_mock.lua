-- Fixtures for the Conflicts specs (not shipped): a small dataset in the shape of 7.1, so the specs
-- never depend on Data/Conflicts.lua, and stand-ins for the House and Profile services (3.8).
local mock = {}

mock.FILES = { "Modules/Conflicts" }

-- clan_choice: both sides with factions and a reputation trigger, anchored in its own zone.
-- coast_raid: no reputation trigger, verified. grove: side B without a faction, anchored in Desolace.
function mock.data()
  return {
    count = 3,
    list = {
      { id = "clan_choice", zone = 1443, theme = "feud",
        A = { faction = 92, quests = { 1001, 1002 } },
        B = { faction = 93, quests = { 2001, 2002 } },
        honored = 6, anchor = { m = 1443, x = 0.55, y = 0.45 }, verified = false },
      { id = "coast_raid", zone = 1434, theme = "trade",
        A = { faction = 21, quests = { 3001 } },
        B = { faction = 87, quests = { 4001 } },
        verified = true },
      { id = "grove", zone = 2652, theme = "nature",
        A = { faction = 92, quests = { 5001 } },
        B = { faction = 0, quests = { 6001 } },
        honored = 7, anchor = { m = 1443, x = 0.2, y = 0.8 }, verified = false },
    },
  }
end

-- The fixture plus two conflicts between the same two factions as others in their zones, as the shipped
-- data has them: clan_raid beside clan_choice in Desolace, and far_raid in Shen'dralas with Gelkis on
-- side B and a lower threshold than grove.
function mock.twins()
  local data = mock.data()
  table.insert(data.list, { id = "clan_raid", zone = 1443, theme = "feud",
    A = { faction = 92, quests = { 1003 } }, B = { faction = 93, quests = { 2003 } }, honored = 6, verified = false })
  table.insert(data.list, { id = "far_raid", zone = 2652, theme = "feud",
    A = { faction = 93, quests = { 5101 } }, B = { faction = 92, quests = { 6101 } }, honored = 5, verified = false })
  data.count = #data.list
  return data
end

-- Titles for every fixture quest, so renderers and the data check find them.
mock.TITLES = {
  [1001] = "Gelkis Alliance", [1002] = "Stones of Binding", [2001] = "Magram Alliance", [2002] = "Broken Tears",
  [3001] = "Bloodsail Correspondence", [4001] = "Pirate Hats Ahoy", [5001] = "Grove Keepers",
  [6001] = "Ash in the Grove", [1003] = "Raid on the Kolkar", [2003] = "Assault on the Kolkar",
  [5101] = "Saving Our Own", [6101] = "No Mercy for the Weak",
}

function mock.titles(wow)
  for q, title in pairs(mock.TITLES) do
    local quest = wow.data.quests[q] or {}
    quest.title = title
    wow.data.quests[q] = quest
  end
end

-- ns.House with the two calls Conflicts makes. siblings = { [conflictId] = { A = { guid, ... }, B = { ... } } }.
function mock.house(ns, key, siblings)
  ns.House = {
    Key = function() return key end,
    SiblingAlliances = function() return siblings or {} end,
  }
  return ns.House
end

-- ns.Profile:IsOpportunist answering `answer` (a value, or a function of the character). Returns the
-- list of log sequence numbers at which it was asked.
function mock.profile(ns, answer)
  local asked = {}
  ns.Profile = {
    IsOpportunist = function(_, char)
      asked[#asked + 1] = ns.Log:Seq(char)
      if type(answer) == "function" then return answer(char) end
      return answer
    end,
  }
  return asked
end

-- Core, Locales and the Conflicts files (plus opts.files), the fixture data, opts.setup(ns), then login.
function mock.boot(wow, opts)
  opts = opts or {}
  local files = {}
  for _, f in ipairs(mock.FILES) do files[#files + 1] = f end
  for _, f in ipairs(opts.files or {}) do files[#files + 1] = f end
  local ns = wow.load(files)
  ns.Data = { Conflicts = opts.data or mock.data() }
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

-- Accepts quest q (it must be in the log for Core's quest.accept), or turns it in.
function mock.accept(wow, q)
  local quest = wow.data.quests[q] or {}
  quest.inLog = true
  wow.data.quests[q] = quest
  wow.fire("QUEST_ACCEPTED", q)
end

function mock.turnIn(wow, q)
  wow.fire("QUEST_TURNED_IN", q, 0, 0)
end

-- Kinds of the character's log entries, in order.
function mock.kinds(char)
  local out = {}
  for _, entry in ipairs(char.log) do out[#out + 1] = entry.k end
  return out
end

return mock

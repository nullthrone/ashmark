local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.conflicts_mock")

local ME = "Player-1-00000001"
local SISTER = "Player-1-00000009"
local COUSIN = "Player-1-0000000a"

describe("Conflicts", function()
  local ns, topics

  local function boot(setup)
    ns = mock.boot(wow, { setup = function(n)
      ns = n
      topics = {}
      for _, topic in ipairs({ "ALLIANCE_FORMED", "ALLIANCE_BROKEN" }) do
        n.Core:Subscribe(topic, function(_, t, ...) topics[#topics + 1] = { t, ... } end)
      end
      if setup then setup(n) end
    end })
    return ns.DB:Char()
  end

  local function last(kind)
    return ns.Log:Last(ns.DB:Char(), kind)
  end

  local function render(entry, own, name)
    return ns.Chronicle:Render(entry, { char = { name = name or "Aren", sex = 2 }, own = own ~= false })
  end

  local function faction(id, reaction)
    wow.data.factions[id].reaction = reaction
    wow.data.factions[id].currentStanding = reaction * 3000
  end

  local function repChange()
    wow.fire("UPDATE_FACTION")
    wow.advance(1)
  end

  before_each(function()
    wow.reset()
    mock.titles(wow)
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("data", function()
    it("indexes the conflicts by id, quest and zone", function()
      boot()
      local C = ns.Conflicts
      local ids = {}
      for i, conflict in ipairs(C:All()) do ids[i] = conflict.id end
      assert.same({ "clan_choice", "coast_raid", "grove" }, ids)
      assert.equal(1434, C:Get("coast_raid").zone)
      assert.is_nil(C:Get("nothing"))
      assert.same({ "clan_choice", "B" }, { C:SideOf(2002) })
      assert.same({ "grove", "A" }, { C:SideOf(5001) })
      assert.is_nil(C:SideOf(9999))
      local inDesolace = {}
      for i, conflict in ipairs(C:InZone(1443)) do inDesolace[i] = conflict.id end
      assert.same({ "clan_choice", "grove" }, inDesolace)
      assert.equal("grove", C:InZone(2652)[1].id)
      assert.same({}, C:InZone(1411))
    end)

    it("hands out copies of its lists and never edits the data", function()
      local data = mock.data()
      ns = mock.boot(wow, { data = data })
      local all = ns.Conflicts:All()
      table.remove(all, 1)
      ns.Conflicts:InZone(1443)[1] = nil
      assert.equal(3, #ns.Conflicts:All())
      assert.equal(2, #ns.Conflicts:InZone(1443))
      assert.same(mock.data(), data)
    end)

    it("skips malformed conflicts and keeps a quest in its first conflict", function()
      local data = mock.data()
      table.insert(data.list, { id = "broken", zone = 1443, A = { faction = 92 }, B = { faction = 93, quests = {} } })
      table.insert(data.list, "not a table")
      table.insert(data.list, { id = "twice", zone = 1411, A = { faction = 21, quests = { 1001 } },
                                B = { faction = 87, quests = { 7001 } } })
      ns = mock.boot(wow, { data = data })
      assert.is_nil(ns.Conflicts:Get("broken"))
      assert.equal(4, #ns.Conflicts:All())
      assert.same({ "clan_choice", "A" }, { ns.Conflicts:SideOf(1001) })
      assert.same({ "twice", "B" }, { ns.Conflicts:SideOf(7001) })
    end)

    it("answers without data and without a character", function()
      ns = wow.load(mock.FILES)
      wow.login()
      assert.same({}, ns.Conflicts:All())
      assert.is_nil(ns.Conflicts:SideOf(1001))
      assert.is_nil(ns.Conflicts:Alliance(nil, "clan_choice"))
      assert.is_nil(ns.Conflicts:Alliance({ conflicts = { allied = { clan_choice = "C" } } }, "clan_choice"))
    end)

    it("keeps its services while the module is unavailable", function()
      boot(function() wow.stub("C_Reputation.GetFactionDataByID", nil) end)
      assert.same({ "reputation" }, ns.Conflicts.unavailable)
      assert.same({ "clan_choice", "B" }, { ns.Conflicts:SideOf(2001) })
      mock.accept(wow, 1001)
      assert.same({ "quest.accept" }, mock.kinds(ns.DB:Char()))
    end)
  end)

  describe("alliance by quest", function()
    it("forms on accepting a quest of one side", function()
      local char = boot()
      mock.accept(wow, 1001)
      assert.same({ "quest.accept", "alliance" }, mock.kinds(char))
      local accept, alliance = char.log[1], char.log[2]
      assert.same({ "clan_choice", "A" }, { alliance.c, alliance.side })
      assert.is_nil(alliance.rep)
      assert.equal("A", char.conflicts.allied.clan_choice)
      assert.equal(alliance.t, char.conflicts.since.clan_choice)
      assert.equal(alliance.n, char.conflicts.began.clan_choice)
      assert.equal(accept.n + 1, alliance.n)
      assert.same({ "A", alliance.n }, { ns.Conflicts:Alliance(char, "clan_choice") })
      assert.same({ { "ALLIANCE_FORMED", "clan_choice", "A", false } }, topics)
    end)

    it("forms on turning in a quest when none was accepted", function()
      local char = boot()
      mock.turnIn(wow, 2002)
      assert.same({ "quest.turnin", "alliance" }, mock.kinds(char))
      assert.equal("B", char.conflicts.allied.clan_choice)
      assert.equal(char.log[2].n, char.conflicts.began.clan_choice)
    end)

    it("forms once: later quests of the same side, and accepting one of the other, add nothing", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 1001)
      mock.accept(wow, 1002)
      mock.accept(wow, 2001)
      assert.same({ "quest.accept", "alliance", "quest.turnin", "quest.accept", "quest.accept" }, mock.kinds(char))
      assert.equal("A", char.conflicts.allied.clan_choice)
      assert.equal(1, #topics)
    end)

    it("keeps each conflict apart and ignores quests of no conflict", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 4001)
      mock.turnIn(wow, 9999)
      assert.same({ clan_choice = "A", coast_raid = "B" }, char.conflicts.allied)
      assert.is_nil(ns.Conflicts:Alliance(char, "grove"))
      assert.equal(0, char.conflicts.violations)
    end)

    it("creates the record at world ready and writes nothing while disabled", function()
      local char = boot()
      assert.same({ allied = {}, since = {}, began = {}, broken = {}, turned = {}, violations = 0 }, char.conflicts)
      ns.Settings:Set("Conflicts.enabled", false)
      mock.accept(wow, 1001)
      assert.same({ "quest.accept" }, mock.kinds(char))
    end)

    it("rebuilds the record after it was wiped", function()
      local char = boot()
      char.conflicts = nil
      mock.accept(wow, 2001)
      assert.equal("B", char.conflicts.allied.clan_choice)
      assert.equal(0, char.conflicts.violations)
    end)
  end)

  describe("alliance by reputation", function()
    it("forms at world ready when exactly one side is at the threshold", function()
      local char = boot(function() faction(93, 6) end)
      assert.same({ "alliance" }, mock.kinds(char))
      assert.same({ "clan_choice", "B", true }, { char.log[1].c, char.log[1].side, char.log[1].rep })
      assert.equal(char.log[1].n, char.conflicts.began.clan_choice)
      assert.same({ { "ALLIANCE_FORMED", "clan_choice", "B", true } }, topics)
    end)

    it("compares the reaction, never the raw standing", function()
      local char = boot(function()
        wow.data.factions[92].reaction = 5
        wow.data.factions[92].currentStanding = 999999
      end)
      assert.same({}, mock.kinds(char))
    end)

    it("forms no alliance when both sides are at the threshold", function()
      local char = boot(function()
        faction(92, 8)
        faction(93, 6)
      end)
      assert.is_nil(ns.Conflicts:Alliance(char, "clan_choice"))
      -- grove's other side has no faction: Gelkis at Exalted alone decides it.
      assert.equal("A", ns.Conflicts:Alliance(char, "grove"))
      assert.same({ "alliance" }, mock.kinds(char))
    end)

    it("forms on a later standing change and never for a conflict without a threshold", function()
      local char = boot()
      faction(21, 8)
      faction(92, 6)
      repChange()
      -- Core's rep entry for Gelkis, its REP_CHANGED, then Booty Bay's entry.
      assert.same({ "rep", "alliance", "rep" }, mock.kinds(char))
      assert.same({ "clan_choice", "A", true }, { char.log[2].c, char.log[2].side, char.log[2].rep })
      assert.is_nil(ns.Conflicts:Alliance(char, "coast_raid"))
      faction(92, 7)
      repChange()
      assert.equal("A", ns.Conflicts:Alliance(char, "grove"))
      assert.same({ "rep", "alliance", "rep", "rep", "alliance" }, mock.kinds(char))
    end)

    it("leaves a conflict that already has an alliance alone", function()
      local char = boot()
      mock.accept(wow, 2001)
      faction(92, 6)
      repChange()
      assert.equal("B", char.conflicts.allied.clan_choice)
      assert.equal(1, #topics)
    end)

    it("retries a faction it cannot read on the next UPDATE_FACTION", function()
      local magram = wow.data.factions[93]
      local char = boot(function()
        wow.data.factions[93] = nil
        faction(92, 6)
      end)
      assert.same({}, mock.kinds(char))
      assert.equal(2, ns.Events:Count("UPDATE_FACTION"))
      wow.data.factions[93] = magram
      repChange()
      assert.equal("A", ns.Conflicts:Alliance(char, "clan_choice"))
      assert.equal(1, ns.Events:Count("UPDATE_FACTION"))
    end)

    it("treats a secret faction table as unreadable", function()
      local char = boot(function()
        wow.data.factions[93] = wow.lock({ reaction = 8 })
        faction(92, 6)
      end)
      assert.same({}, mock.kinds(char))
      assert.equal(2, ns.Events:Count("UPDATE_FACTION"))
    end)
  end)

  describe("violation", function()
    it("breaks the alliance on turning in a quest of the other side", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 2001)
      assert.same({ "quest.accept", "alliance", "quest.turnin", "violation" }, mock.kinds(char))
      local v = last("violation")
      assert.same({ "clan_choice", "B", 2001 }, { v.c, v.side, v.q })
      assert.is_nil(v.o)
      local rec = char.conflicts
      assert.same({ 1, 1, "B" }, { rec.violations, rec.broken.clan_choice, rec.allied.clan_choice })
      assert.equal(v.t, rec.since.clan_choice)
      assert.equal(v.n, rec.began.clan_choice)
      assert.same({ { "ALLIANCE_FORMED", "clan_choice", "A", false }, { "ALLIANCE_BROKEN", "clan_choice", "B", 2001 } },
                  topics)
    end)

    it("counts every switch, per conflict and in total", function()
      local char = boot()
      mock.turnIn(wow, 1001)
      mock.turnIn(wow, 2001)
      mock.turnIn(wow, 1002)
      mock.turnIn(wow, 3001)
      mock.turnIn(wow, 4001)
      local rec = char.conflicts
      assert.same({ 3, 2, 1 }, { rec.violations, rec.broken.clan_choice, rec.broken.coast_raid })
      assert.same({ clan_choice = "A", coast_raid = "B" }, rec.allied)
      assert.equal(last("violation").n, rec.began.coast_raid)
    end)

    it("reads the opportunist wording before writing the violation", function()
      local asked
      local char = boot(function(n)
        asked = mock.profile(n, function(c) return ns.Log:Last(c, "violation") == nil end)
      end)
      mock.accept(wow, 1001)
      mock.turnIn(wow, 2001)
      local v = last("violation")
      assert.equal(1, v.o)
      assert.same({ v.n - 1 }, asked)
      assert.equal(1, char.conflicts.violations)
    end)

    it("uses the plain wording without Profile or when it says no", function()
      boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 2001)
      assert.is_nil(last("violation").o)
      mock.profile(ns, false)
      mock.turnIn(wow, 1002)
      assert.is_nil(last("violation").o)
    end)
  end)

  describe("chronicle", function()
    it("registers its kinds as keep kinds", function()
      boot()
      for _, kind in ipairs({ "alliance", "violation", "houseturn" }) do
        assert.is_true(ns.Log:Kind(kind).keep, kind)
      end
    end)

    it("tells of an alliance by quest and by standing, in both persons", function()
      local char = boot(function() faction(93, 6) end)
      local byRep = char.log[1]
      mock.accept(wow, 3001)
      local byQuest = last("alliance")
      assert.equal("You sided with Booty Bay in Stranglethorn Vale.", render(byQuest))
      assert.equal("Mira sided with Booty Bay in Stranglethorn Vale.", render(byQuest, false, "Mira"))
      assert.equal("Your standing with Magram Clan Centaur decided your side in Desolace.", render(byRep))
      assert.equal("Standing with Magram Clan Centaur decided Mira's side in Desolace.", render(byRep, false, "Mira"))
    end)

    it("tells of a broken word in the wording stored with it", function()
      boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 2001)
      local plain = last("violation")
      assert.equal("You broke faith with Gelkis Clan Centaur and finished Magram Alliance for Magram Clan Centaur.",
                   render(plain))
      assert.equal("Mira broke faith with Gelkis Clan Centaur and finished Magram Alliance for Magram Clan Centaur.",
                   render(plain, false, "Mira"))
      mock.profile(ns, true)
      mock.turnIn(wow, 1002)
      local switched = last("violation")
      assert.equal("You changed sides once more: Stones of Binding for Gelkis Clan Centaur, and Magram Clan Centaur "
                   .. "left behind.", render(switched))
      mock.profile(ns, false)
      assert.equal("You changed sides once more: Stones of Binding for Gelkis Clan Centaur, and Magram Clan Centaur "
                   .. "left behind.", render(switched))
    end)

    it("names a side without a faction and survives a conflict the data no longer has", function()
      boot()
      mock.turnIn(wow, 6001)
      assert.equal("You sided with those without a banner in Shen'dralas.", render(last("alliance")))
      local gone = { n = 99, t = time(), k = "violation", c = "removed", side = "A", q = 1 }
      assert.equal("You broke faith with a faction and finished a quest for a faction.", render(gone))
    end)
  end)

  describe("data check", function()
    local function run()
      for _, c in ipairs(ns.Test.checks) do
        if c.id == "Conflicts.data" then return c.fn() end
      end
    end

    it("passes when every quest has a title and every faction a name", function()
      boot()
      assert.same({ true, "3 conflicts, 8 quests, 4 factions, verified 1/3" }, { run() })
      assert.same({}, wow.requests.quest)
    end)

    it("asks for missing titles once, then fails on those still missing", function()
      wow.data.quests[2002].title = nil
      wow.data.quests[6001].title = nil
      boot()
      local ok, detail = run()
      assert.is_nil(ok)
      assert.matches("pending, run again: 2002, 6001$", detail)
      assert.same({ 2002, 6001 }, wow.requests.quest)
      wow.data.quests[2002].title = "Broken Tears"
      ok, detail = run()
      assert.is_false(ok)
      assert.matches("no quest title: 6001$", detail)
      assert.same({ 2002, 6001 }, wow.requests.quest)
    end)

    it("fails on a faction without a name", function()
      wow.data.factions[87] = nil
      boot()
      local ok, detail = run()
      assert.is_false(ok)
      assert.matches("; no faction name: 87$", detail)
    end)
  end)

  describe("turning from the house", function()
    it("records turning from the house after the alliance, never as a violation", function()
      local char = boot(function(n) mock.house(n, "Ashvale", { clan_choice = { A = {}, B = { SISTER } } }) end)
      mock.accept(wow, 1001)
      assert.same({ "quest.accept", "alliance", "houseturn" }, mock.kinds(char))
      local turn = last("houseturn")
      assert.same({ "clan_choice", "A", 1001, "Ashvale" }, { turn.c, turn.side, turn.q, turn.h })
      assert.is_true(char.conflicts.turned.clan_choice)
      assert.equal(0, char.conflicts.violations)
      assert.equal(last("alliance").n, char.conflicts.began.clan_choice)
      assert.same({ { "ALLIANCE_FORMED", "clan_choice", "A", false } }, topics)
      assert.equal("You turned from House Ashvale and sided with Gelkis Clan Centaur in Desolace.", render(turn))
      assert.equal("Mira turned from House Ashvale and sided with Gelkis Clan Centaur in Desolace.",
                   render(turn, false, "Mira"))
    end)

    it("records it for an alliance by standing, without a quest", function()
      local char = boot(function(n)
        mock.house(n, "Ashvale", { clan_choice = { A = { SISTER, COUSIN } } })
        faction(93, 6)
      end)
      assert.same({ "alliance", "houseturn" }, mock.kinds(char))
      assert.is_nil(last("houseturn").q)
    end)

    it("records nothing when the siblings are split, agree, or the house has no key", function()
      local siblings = { clan_choice = { A = { SISTER }, B = { COUSIN } }, coast_raid = { A = { SISTER } } }
      local char = boot(function(n) mock.house(n, "Ashvale", siblings) end)
      mock.accept(wow, 2001)
      mock.accept(wow, 3001)
      assert.same({ "quest.accept", "alliance", "quest.accept", "alliance" }, mock.kinds(char))
      mock.house(ns, nil, { grove = { A = { SISTER } } })
      mock.accept(wow, 6001)
      assert.is_nil(last("houseturn"))
      assert.same({}, char.conflicts.turned)
    end)

    it("does not count the character among its own siblings", function()
      local char = boot(function(n) mock.house(n, "Ashvale", { clan_choice = { A = { ME }, B = { SISTER } } }) end)
      mock.accept(wow, 1001)
      assert.is_true(char.conflicts.turned.clan_choice)
    end)
  end)
end)

local wow = require("tests.helpers.wow")

local GUID = "Player-1-00000001"

describe("Core watchers", function()
  local ns, Log, topics

  local function boot(setup)
    ns = wow.load({ "Data" })
    Log = ns.Log
    topics = {}
    ns.Core:Subscribe("REP_CHANGED", function(_, _, f, reaction, delta)
      topics[#topics + 1] = { "REP_CHANGED", f, reaction, delta }
    end)
    ns.Core:Subscribe("GROUP_CHANGED", function(_, _, inGroup) topics[#topics + 1] = { "GROUP_CHANGED", inGroup } end)
    if setup then setup() end
    wow.login()
    return ns.DB:Char()
  end

  local function last(kind)
    return Log:Last(ns.DB:Char(), kind)
  end

  local function count(kind)
    local c = 0
    for _, e in ipairs(ns.DB:Char().log) do
      if e.k == kind then c = c + 1 end
    end
    return c
  end

  before_each(function()
    wow.reset()
  end)

  describe("quests", function()
    it("takes the quest ID from the last QUEST_ACCEPTED argument and needs a log index", function()
      boot()
      wow.data.quests[1382] = { inLog = true }
      wow.data.quests[1385] = { inLog = true }
      wow.fire("QUEST_ACCEPTED", 1382)
      wow.fire("QUEST_ACCEPTED", 7, 1385)
      wow.fire("QUEST_ACCEPTED", 1386)
      wow.fire("QUEST_ACCEPTED")
      wow.fire("QUEST_ACCEPTED", wow.secret(1382))
      assert.equal(2, count("quest.accept"))
      assert.equal(1385, last("quest.accept").q)
    end)

    it("logs a turn-in and its money as quest gold", function()
      boot()
      wow.fire("QUEST_TURNED_IN", 1382, 500, 1500)
      wow.fire("QUEST_TURNED_IN", 1383, 500, 0)
      assert.equal(2, count("quest.turnin"))
      assert.same({ "quest", 1500 }, { last("gold").src, last("gold").c })
      assert.equal(1, count("gold"))
    end)

    it("writes abandons through the abandon hooks and ignores QUEST_REMOVED", function()
      boot()
      wow.data.quests[1382] = { inLog = true }
      C_QuestLog.SetSelectedQuest(1382)
      C_QuestLog.SetAbandonQuest()
      C_QuestLog.AbandonQuest()
      wow.fire("QUEST_REMOVED", 1382)
      wow.advance(2)
      assert.equal(1, count("quest.abandon"))
      assert.equal(1382, last("quest.abandon").q)
      C_QuestLog.AbandonQuest()
      assert.equal(1, count("quest.abandon"))
    end)

    describe("without the abandon hooks", function()
      before_each(function()
        boot(function() wow.stub("C_QuestLog.SetAbandonQuest", nil) end)
      end)

      it("writes an abandon two seconds after QUEST_REMOVED", function()
        wow.fire("QUEST_REMOVED", 1382)
        wow.advance(1.9)
        assert.equal(0, count("quest.abandon"))
        wow.advance(0.1)
        assert.equal(1382, last("quest.abandon").q)
      end)

      it("writes none when the turn-in came first", function()
        wow.fire("QUEST_TURNED_IN", 1382, 0, 0)
        wow.advance(1.5)
        wow.fire("QUEST_REMOVED", 1382)
        wow.advance(2)
        assert.equal(0, count("quest.abandon"))
      end)

      it("writes none when the turn-in comes after the removal", function()
        wow.fire("QUEST_REMOVED", 1382)
        wow.advance(0.5)
        wow.fire("QUEST_TURNED_IN", 1382, 0, 0)
        wow.advance(2)
        assert.equal(0, count("quest.abandon"))
      end)

      it("writes none when the turn-in comes up to two seconds after the removal", function()
        wow.fire("QUEST_REMOVED", 1382)
        wow.advance(1.5)
        wow.fire("QUEST_TURNED_IN", 1382, 0, 0)
        wow.advance(1)
        assert.equal(0, count("quest.abandon"))
      end)

      it("writes none for completed and task quests", function()
        wow.data.quests[1] = { completed = true }
        wow.data.quests[2] = { task = true }
        wow.fire("QUEST_REMOVED", 1)
        wow.fire("QUEST_REMOVED", 2)
        wow.advance(2)
        assert.equal(0, count("quest.abandon"))
      end)
    end)
  end)

  describe("gold", function()
    local function money(delta)
      wow.state.money = wow.state.money + delta
      wow.fire("PLAYER_MONEY")
    end

    before_each(function()
      wow.state.money = 10000
      boot()
    end)

    it("sums each context and writes one entry when it closes", function()
      wow.fire("LOOT_OPENED")
      money(120)
      money(30)
      wow.fire("LOOT_CLOSED")
      wow.fire("MERCHANT_SHOW")
      money(-500)
      money(200)
      wow.fire("MERCHANT_CLOSED")
      wow.fire("MERCHANT_CLOSED")
      wow.fire("TRADE_SHOW")
      wow.fire("TRADE_CLOSED")
      local golds = {}
      for _, e in ipairs(ns.DB:Char().log) do
        if e.k == "gold" then golds[#golds + 1] = e.src .. ":" .. e.c end
      end
      assert.same({ "loot:150", "vendor:-300" }, golds)
    end)

    it("attributes money to the most recent open context", function()
      wow.fire("MAIL_SHOW")
      wow.fire("MERCHANT_SHOW")
      money(10)
      wow.fire("MERCHANT_CLOSED")
      money(5)
      wow.fire("MAIL_CLOSED")
      local golds = {}
      for _, e in ipairs(ns.DB:Char().log) do
        if e.k == "gold" then golds[#golds + 1] = e.src .. ":" .. e.c end
      end
      assert.same({ "vendor:10", "mail:5" }, golds)
    end)

    it("consumes quest money that was already logged", function()
      wow.fire("QUEST_TURNED_IN", 1382, 0, 1500)
      money(1500)
      wow.fire("QUEST_TURNED_IN", 1383, 0, 1000)
      wow.advance(3)
      money(1000)
      wow.advance(600)
      local golds = {}
      for _, e in ipairs(ns.DB:Char().log) do
        if e.k == "gold" then golds[#golds + 1] = e.src .. ":" .. e.c end
      end
      assert.same({ "quest:1500", "quest:1000", "other:1000" }, golds)
    end)

    it("does not count quest money twice when PLAYER_MONEY comes first", function()
      money(1500)
      wow.fire("QUEST_TURNED_IN", 1382, 0, 1500)
      money(200)
      wow.fire("LOOT_OPENED")
      money(700)
      wow.advance(1)
      wow.fire("QUEST_TURNED_IN", 1383, 0, 500)
      wow.fire("LOOT_CLOSED")
      money(400)
      wow.advance(3)
      money(50)
      wow.fire("QUEST_TURNED_IN", 1384, 0, 50)
      wow.advance(600)
      local golds = {}
      for _, e in ipairs(ns.DB:Char().log) do
        if e.k == "gold" then golds[#golds + 1] = e.src .. ":" .. e.c end
      end
      assert.same({ "quest:1500", "quest:500", "loot:200", "quest:50", "other:600" }, golds)
    end)

    it("collects changes outside a context as other, every 10 minutes and at logout", function()
      money(7)
      wow.advance(300)
      money(3)
      assert.equal(0, count("gold"))
      wow.advance(300)
      assert.equal(10, last("gold").c)
      money(-4)
      wow.logout()
      assert.same({ "other", -4 }, { last("gold").src, last("gold").c })
    end)
  end)

  describe("reputation", function()
    it("takes the baseline silently and writes rep only when the standing changes", function()
      local char = boot()
      local gelkis = wow.data.factions[92]
      assert.equal(0, count("rep"))
      gelkis.currentStanding = 400
      wow.fire("UPDATE_FACTION")
      wow.fire("UPDATE_FACTION")
      wow.advance(1)
      assert.same({ { "REP_CHANGED", 92, 4, 400 } }, topics)
      assert.equal(0, count("rep"))
      gelkis.currentStanding, gelkis.reaction = 3100, 5
      wow.fire("UPDATE_FACTION")
      wow.advance(1)
      assert.same({ "REP_CHANGED", 92, 5, 2700 }, topics[2])
      local e = last("rep")
      assert.same({ 92, 5, 3100 }, { e.f, e.s, e.d })
      gelkis.currentStanding = 3200
      wow.fire("UPDATE_FACTION")
      wow.advance(1)
      gelkis.currentStanding, gelkis.reaction = 9000, 6
      wow.fire("UPDATE_FACTION")
      wow.advance(1)
      assert.equal(5900, last("rep").d)
      assert.equal(2, count("rep"))
      assert.equal(char, ns.DB:Char())
    end)

    it("baselines a faction at its first readable value", function()
      wow.data.factions[93].reaction = wow.secret(4)
      boot()
      wow.data.factions[93].reaction = 4
      wow.fire("UPDATE_FACTION")
      wow.advance(1)
      assert.same({}, topics)
      wow.data.factions[93].currentStanding = 50
      wow.fire("UPDATE_FACTION")
      wow.advance(1)
      assert.same({ { "REP_CHANGED", 93, 4, 50 } }, topics)
    end)
  end)

  describe("zones", function()
    it("writes the first visit, skips repeats and nil zones", function()
      wow.state.map = 9002
      local char = boot()
      local e = last("zone")
      assert.same({ 1443, true }, { e.z, e.first })
      assert.equal(e.t, char.zones[1443])
      wow.fire("ZONE_CHANGED_NEW_AREA")
      assert.equal(1, count("zone"))
      wow.state.map = 1414
      wow.fire("ZONE_CHANGED_NEW_AREA")
      wow.state.map = nil
      wow.fire("ZONE_CHANGED_NEW_AREA")
      assert.equal(1, count("zone"))
      wow.state.map = 1411
      wow.fire("ZONE_CHANGED_NEW_AREA")
      wow.state.map = 1443
      wow.advance(60)
      wow.fire("ZONE_CHANGED_NEW_AREA")
      assert.equal(3, count("zone"))
      assert.is_nil(last("zone").first)
      assert.equal(time() - 60, char.zones[1443])
    end)
  end)

  describe("the group boundary", function()
    it("fires GROUP_CHANGED only on a change, coalesced", function()
      local char = boot()
      assert.same({}, topics)
      wow.unit("party1", { guid = "Player-1-2", name = "Mira" })
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(1)
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(1)
      assert.same({ { "GROUP_CHANGED", true } }, topics)
      assert.is_true(char.state.inGroup)
      wow.unit("party1", nil)
      wow.fire("GROUP_LEFT")
      wow.advance(1)
      assert.same({ "GROUP_CHANGED", false }, topics[2])
    end)

    it("fires GROUP_CHANGED(false) after logging in outside the stored group", function()
      wow.saved({ schema = 1, created = 1, chars = { [GUID] = {
        guid = GUID, seq = 0, log = {}, chapters = {}, zones = {}, stats = {},
        state = { inGroup = true, senders = {} },
      } } })
      boot()
      assert.same({ { "GROUP_CHANGED", false } }, topics)
      assert.is_false(ns.DB:Char().state.inGroup)
    end)

    it("fires nothing at login when the stored flag matches", function()
      wow.unit("party1", { guid = "Player-1-2", name = "Mira" })
      wow.saved({ schema = 1, created = 1, chars = { [GUID] = {
        guid = GUID, seq = 0, log = {}, chapters = {}, zones = {}, stats = {},
        state = { inGroup = true, senders = {} },
      } } })
      boot()
      assert.same({}, topics)
    end)
  end)

  it("writes level and death entries and keeps the level", function()
    local char = boot()
    wow.fire("PLAYER_LEVEL_UP", 21)
    wow.fire("PLAYER_DEAD")
    assert.equal(21, last("level").l)
    assert.equal(21, char.level)
    assert.equal(1, count("death"))
  end)

  it("records blocked actions of this addon only, capped at 20", function()
    boot()
    for i = 1, 25 do wow.fire("ADDON_ACTION_BLOCKED", "Ashmark", "Fn" .. i) end
    wow.fire("ADDON_ACTION_FORBIDDEN", "Other", "Fn")
    wow.fire("ADDON_ACTION_FORBIDDEN", wow.secret("Ashmark"), "Fn")
    local blocked = _G.AshmarkDB.dev.blocked
    assert.equal(20, #blocked)
    assert.same({ t = time(), event = "ADDON_ACTION_BLOCKED", fn = "Fn25" }, blocked[20])
  end)

  it("never writes lastSeen at login", function()
    local char = boot()
    assert.is_nil(char.lastSeen)
    wow.advance(299)
    assert.is_nil(char.lastSeen)
    wow.advance(1)
    assert.equal(time(), char.lastSeen)
  end)

  it("renders the core kinds", function()
    wow.state.map = 1443
    local char = boot()
    wow.data.quests[1382] = { title = "Strange Alliance" }
    wow.fire("QUEST_TURNED_IN", 1382, 0, 0)
    wow.fire("PLAYER_LEVEL_UP", 21)
    wow.fire("PLAYER_DEAD")
    wow.data.factions[92].reaction = 5
    wow.fire("UPDATE_FACTION")
    wow.advance(1)
    local lines = {}
    for _, line in ipairs(ns.Chronicle:Lines(char, ns.Chronicle:Chapters(char)[1])) do lines[#lines + 1] = line.text end
    assert.same({
      "You set foot in Desolace for the first time.", "You completed Strange Alliance.", "You reached level 21.",
      "You died in Desolace.", "You are now Friendly with Gelkis Clan Centaur.",
    }, lines)
    local ctx = { char = char, own = false }
    assert.equal("Aren reached level 21.", ns.Chronicle:Render(last("level"), ctx))
  end)
end)

local wow = require("tests.helpers.wow")

describe("Core Names", function()
  local ns, Names, updates
  before_each(function()
    wow.reset()
    ns = wow.load()
    Names = ns.Names
    updates = {}
    wow.login()
    ns.Core:Subscribe("NAMES_UPDATED", function(_, _, kind, id) updates[#updates + 1] = kind .. ":" .. id end)
  end)

  it("names quests and requests uncached ones once per id", function()
    wow.data.quests[1382] = { title = "Strange Alliance" }
    assert.equal("Strange Alliance", Names.Quest(1382))
    assert.equal("a quest", Names.Quest(1385))
    assert.equal("a quest", Names.Quest(1385))
    assert.same({ 1385 }, wow.requests.quest)
    wow.data.quests[1385] = { title = "Hidden Enemies" }
    wow.fire("QUEST_DATA_LOAD_RESULT", 1385, true)
    wow.fire("QUEST_DATA_LOAD_RESULT", 1382, true)
    wow.fire("QUEST_DATA_LOAD_RESULT", 1385, false)
    assert.same({ "quest:1385" }, updates)
    assert.equal("Hidden Enemies", Names.Quest(1385))
  end)

  it("names items and requests uncached ones once per id", function()
    wow.data.items[6948] = { name = "Hearthstone" }
    wow.data.items[19019] = { name = "Thunderfury", cached = false }
    assert.equal("Hearthstone", Names.Item(6948))
    assert.equal("an item", Names.Item(19019))
    assert.equal("an item", Names.Item(19019))
    assert.same({ 19019 }, wow.requests.item)
    wow.fire("ITEM_DATA_LOAD_RESULT", 19019, true)
    assert.same({ "item:19019" }, updates)
  end)

  it("caches names for the session", function()
    wow.data.quests[1] = { title = "First" }
    assert.equal("First", Names.Quest(1))
    wow.data.quests[1].title = "Changed"
    assert.equal("First", Names.Quest(1))
  end)

  it("names factions, maps and races with placeholders", function()
    assert.equal("Gelkis Clan Centaur", Names.Faction(92))
    assert.equal("a faction", Names.Faction(0))
    assert.equal("Desolace", Names.Map(1443))
    assert.equal("an unknown place", Names.Map(nil))
    assert.equal("Orc", Names.Race(2))
    assert.equal("unknown folk", Names.Race(99))
    wow.data.factions[93].name = wow.secret("Magram")
    assert.equal("a faction", Names.Faction(93))
    assert.equal("a faction", Names.Faction(wow.secret(92)))
  end)

  it("names classes by sex", function()
    wow.stub("LOCALIZED_CLASS_NAMES_FEMALE.WARRIOR", "Kriegerin")
    assert.equal("Kriegerin", Names.Class("WARRIOR", 3))
    assert.equal("Warrior", Names.Class("WARRIOR", 2))
    assert.equal("adventurer", Names.Class("NOPE", 2))
    assert.equal("adventurer", Names.Class(nil))
    assert.same({ "Warrior", true }, { Names.Class("WARRIOR", 2) })
    assert.same({ "adventurer", false }, { Names.Class("NOPE", 2) })
  end)

  it("prefers a race name stored in the active locale, which UnitRace gave for the unit's sex", function()
    local active = ns.Locale.active
    assert.same({ "Zwergin", true }, { Names.Race(3, "Zwergin", active) })
    assert.same({ "Dwarf", true }, { Names.Race(3, "Zwergin", "deDE") })
    assert.same({ "Dwarf", true }, { Names.Race(3, nil, active) })
    assert.same({ "Dwarf", true }, { Names.Race(3, "", active) })
    assert.same({ "Dwarf", true }, { Names.Race(3, wow.secret("Zwergin"), active) })
    assert.same({ "unknown folk", false }, { Names.Race(99) })
    assert.same({ "Zwergin", true }, { Names.Race(99, "Zwergin", active) })
  end)

  it("names players from contacts, then character records", function()
    _G.AshmarkDB.contacts["Player-1-2"] = { name = "Mira" }
    assert.equal("Mira", Names.Player("Player-1-2"))
    assert.equal("Aren", Names.Player("Player-1-00000001"))
    assert.equal("someone", Names.Player("Player-1-404"))
    assert.equal("someone", Names.Player(nil))
  end)

  it("never returns nil", function()
    wow.stub("C_QuestLog", nil)
    wow.stub("C_Item", nil)
    wow.stub("C_Reputation", nil)
    wow.stub("C_Map", nil)
    wow.stub("C_CreatureInfo", nil)
    for _, fn in ipairs({ Names.Quest, Names.Item, Names.Faction, Names.Map, Names.Race, Names.Player }) do
      assert.is_string(fn(777))
    end
  end)
end)

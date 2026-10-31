local wow = require("tests.helpers.wow")

describe("Core Identity", function()
  local ns, Identity, player
  before_each(function()
    wow.reset()
    player = wow.state.units.player
    ns = wow.load()
    Identity = ns.Identity
  end)

  describe("the player's surname", function()
    local function names(api, ...)
      player.nameReturns = player.nameReturns or {}
      player.nameReturns[api] = { n = select("#", ...) + 1, "Aren", ... }
    end

    it("comes from UnitNameUnmodified first", function()
      names("UnitNameUnmodified", "Emberly")
      names("UnitName", "Other")
      local p = Identity:Player()
      assert.equal("Emberly", p.surname)
      assert.equal("UnitNameUnmodified", p.surnameSource)
      assert.equal("Aren Emberly", p.full)
    end)

    it("falls back to UnitName, then UnitFullName", function()
      names("UnitNameUnmodified", nil)
      names("UnitName", "Second")
      assert.equal("UnitName", Identity:Player().surnameSource)
      names("UnitName", "")
      names("UnitFullName", "Third")
      local p = Identity:Player()
      assert.equal("Third", p.surname)
      assert.equal("UnitFullName", p.surnameSource)
    end)

    it("rejects empty, hyphenated, realm and secret candidates", function()
      names("UnitNameUnmodified", "Forever")
      names("UnitName", "Some-Realm")
      names("UnitFullName", wow.secret("Hidden"))
      local p = Identity:Player()
      assert.is_nil(p.surname)
      assert.is_nil(p.surnameSource)
      assert.equal("Aren", p.full)
    end)
  end)

  it("builds a Person from a unit", function()
    local p = Identity:Player()
    assert.same({
      guid = "Player-1-00000001", name = "Aren", surname = "Ashvale", full = "Aren Ashvale", class = "WARRIOR",
      race = 1, raceName = "Human", sex = 2, faction = "Alliance", level = 20, ruleset = "Normal", unit = "player",
      surnameSource = "UnitNameUnmodified",
    }, p)
  end)

  it("keeps the race name the client gives for the unit's sex, and no secret one", function()
    wow.unit("party1", { guid = "Player-1-2", name = "Mira", raceID = 3, raceName = "Zwergin", sex = 3 })
    wow.unit("party2", { guid = "Player-1-3", name = "Thalen", raceID = 3, raceName = wow.secret("Zwerg") })
    assert.same({ 3, "Zwergin" }, { Identity:Unit("party1").race, Identity:Unit("party1").raceName })
    assert.is_nil(Identity:Unit("party2").raceName)
  end)

  it("returns nil for a unit with a missing or secret GUID or name", function()
    wow.unit("party1", { guid = wow.secret("Player-1-2"), name = "Mira" })
    wow.unit("party2", { guid = "Player-1-3", name = wow.secret("Thalen") })
    assert.is_nil(Identity:Unit("party1"))
    assert.is_nil(Identity:Unit("party2"))
    assert.is_nil(Identity:Unit("party3"))
  end)

  it("takes no Person from a member whose name has not arrived, so the group skips it", function()
    wow.unit("party1", { guid = "Player-1-2", name = "Mira", classFile = "DRUID", loading = true })
    wow.unit("party2", { guid = "Player-1-3", name = "Thalen" })
    assert.is_nil(Identity:Unit("party1"))
    local group = Identity:Group("party")
    assert.is_nil(group["Player-1-2"])
    assert.equal("Thalen", group["Player-1-3"].name)
  end)

  it("keeps the stored name and surname while the player's own name has not arrived", function()
    wow.login()
    local char = ns.DB:Char()
    player.nameReturns = { UnitName = { "Unknown" }, UnitNameUnmodified = { "Unknown" },
                           UnitFullName = { "Unknown", "Other" } }
    Identity:Refresh()
    assert.same({ "Aren", "Ashvale", "UnitNameUnmodified" }, { char.name, char.surname, char.surnameSource })
    local p = Identity:Player()
    assert.same({ "Other", "UnitFullName" }, { p.surname, p.surnameSource })
    assert.is_nil(p.name)
    assert.is_nil(p.full)
  end)

  it("keeps a Person whose class is secret, without the class", function()
    wow.unit("party1", { guid = "Player-1-2", name = "Mira", classFile = wow.secret("MAGE"), sex = 3 })
    local p = Identity:Unit("party1")
    assert.is_nil(p.class)
    assert.equal(3, p.sex)
  end)

  it("lists group members without the player and skips secret ones", function()
    wow.unit("party1", { guid = "Player-1-2", name = "Mira" })
    wow.unit("party2", { guid = "Player-1-3", name = wow.secret("Hidden") })
    wow.unit("party3", { guid = "Player-1-4", name = "Thalen" })
    local group = Identity:Group("party")
    assert.same({ "Player-1-2", "Player-1-4" }, (function()
      local keys = {}
      for guid in pairs(group) do keys[#keys + 1] = guid end
      table.sort(keys)
      return keys
    end)())
    assert.equal("party3", group["Player-1-4"].unit)
  end)

  it("reads raid1..40 for scope all in a raid, party1..4 otherwise", function()
    wow.unit("party1", { guid = "Player-1-2", name = "Mira" })
    wow.unit("raid1", wow.state.units.player)
    wow.unit("raid2", { guid = "Player-1-2", name = "Mira" })
    wow.unit("raid7", { guid = "Player-1-9", name = "Far" })
    local all = Identity:Group("all")
    assert.is_nil(all["Player-1-00000001"])
    assert.equal("raid7", all["Player-1-9"].unit)
    assert.is_nil(Identity:Group("party")["Player-1-9"])
  end)

  describe("in a battleground", function()
    -- The unit tokens name the battleground's raid, an instance group; the home group stands behind it.
    local function battleground(home)
      wow.state.instanceGroup, wow.state.homeGroup = true, home
      wow.unit("raid1", wow.state.units.player)
      for i = 2, 15 do wow.unit("raid" .. i, { guid = "Player-1-1" .. i, name = "Fighter" .. i }) end
      for i = 1, 4 do wow.unit("party" .. i, wow.state.units["raid" .. (i + 1)]) end
    end

    it("counts no group for a player who queued alone, and names no members", function()
      battleground(nil)
      assert.is_false(Identity:InGroup())
      assert.same({}, Identity:Group("all"))
      assert.same({}, Identity:Group("party"))
      assert.is_nil(Identity:Tokens("all"))
    end)

    it("keeps the home party as the group, but never takes the battleground's members for it", function()
      battleground({ size = 3 })
      assert.is_true(Identity:InGroup())
      assert.same({}, Identity:Group("all"))
      assert.same({}, Identity:Group("party"))
      wow.state.instanceGroup, wow.state.homeGroup = false, nil
      for i = 1, 15 do wow.unit("raid" .. i, nil) end
      wow.unit("party3", nil)
      wow.unit("party4", nil)
      assert.is_true(Identity:InGroup())
      assert.same({ "party", 4 }, { Identity:Tokens("all") })
      assert.equal("party1", Identity:Group("all")["Player-1-12"].unit)
    end)
  end)

  it("asks for the home group even where the client lacks the category constants", function()
    wow.stub("LE_PARTY_CATEGORY_HOME", nil)
    wow.stub("LE_PARTY_CATEGORY_INSTANCE", nil)
    wow.unit("raid1", wow.state.units.player)
    wow.unit("raid2", { guid = "Player-1-2", name = "Mira" })
    assert.is_true(Identity:InGroup())
    assert.equal("raid2", Identity:Group("all")["Player-1-2"].unit)
  end)

  it("treats a group of one as no group", function()
    assert.is_false(Identity:InGroup())
    wow.unit("party1", { guid = "Player-1-2", name = "Mira" })
    assert.is_true(Identity:InGroup())
    wow.stub("GetNumGroupMembers", function() return 1 end)
    assert.is_false(Identity:InGroup())
  end)

  describe("ruleset", function()
    local function rules(...)
      ns = wow.load()
      for i = 1, select("#", ...) do wow.state.rules[Enum.GameRule[select(i, ...)]] = true end
      wow.login()
      return ns.Identity:Ruleset()
    end

    before_each(function() wow.reset() end)

    it("maps the active rules to a key", function()
      assert.equal("Normal", rules())
    end)
    it("RP", function() assert.equal("RP", rules("RPRuleset")) end)
    it("PvP", function() assert.equal("PvP", rules("PvPRuleset")) end)
    it("RPPvP from its rule", function() assert.equal("RPPvP", rules("RPPvPRuleset")) end)
    it("RPPvP from RP and PvP", function() assert.equal("RPPvP", rules("RPRuleset", "PvPRuleset")) end)
    it("Hardcore wins", function() assert.equal("Hardcore", rules("HardcoreRuleset", "RPRuleset")) end)

    it("is Normal without the rules API and follows GAME_RULES_CHANGED", function()
      wow.stub("C_GameRules", nil)
      assert.equal("Normal", rules("RPRuleset"))
      wow.reset()
      assert.equal("Normal", rules())
      wow.state.rules[Enum.GameRule.PvPRuleset] = true
      wow.fire("GAME_RULES_CHANGED")
      assert.equal("PvP", ns.Identity:Ruleset())
      assert.equal("PvP", ns.DB:Char().ruleset)
    end)
  end)

  it("creates and updates the character record at login", function()
    wow.login()
    local char = _G.AshmarkDB.chars["Player-1-00000001"]
    assert.equal(char, ns.DB:Char())
    assert.equal("Aren", char.name)
    assert.equal("Ashvale", char.surname)
    assert.equal(time(), char.firstSeen)
    assert.equal(0, char.seq)
    assert.same({ inGroup = false, senders = {} }, char.state)
    assert.is_nil(char.lastSeen)
    for _, key in ipairs({ "log", "chapters", "zones", "stats" }) do assert.is_table(char[key]) end
  end)
end)

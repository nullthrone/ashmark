local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.house_mock")

describe("House", function()
  local ns, char

  local function boot(opts)
    ns, char = mock.boot(wow, opts)
    return char
  end

  local function slash(args)
    SlashCmdList.ASHMARK("house" .. (args and (" " .. args) or ""))
  end

  local function said()
    return (wow.chat[#wow.chat] or ""):match(": (.*)$")
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("key", function()
    it("is the override, else the surname as stored and trimmed, else nothing", function()
      boot()
      local House = ns.House
      assert.equal("Ashvale", House:Key(char))
      assert.equal("Ashvale", House:Key({ surname = "  Ashvale " }))
      assert.equal("Stormhollow", House:Key({ surname = "Ashvale", houseOverride = " Stormhollow" }))
      assert.equal("Ashvale", House:Key({ surname = "Ashvale", houseOverride = "   " }))
      assert.is_nil(House:Key({ surname = "" }))
      assert.is_nil(House:Key(mock.char(mock.NYM)))
      assert.is_nil(House:Key(nil))
      assert.is_nil(House:Key("Ashvale"))
    end)

    it("keeps surnames that differ only in case apart", function()
      boot({ extra = { [mock.TOBIN] = { surname = "ashvale" } } })
      assert.same({ "Mira", "Aren" }, mock.names(ns.House:Members(char)))
    end)
  end)

  describe("members", function()
    it("are the account's characters with the same key, highest level first, the character included", function()
      boot()
      assert.same({ "Mira", "Aren", "Tobin" }, mock.names(ns.House:Members(char)))
      assert.same({ "Kel" }, mock.names(ns.House:Members(mock.char(mock.KEL))))
      assert.same({}, ns.House:Members(mock.char(mock.NYM)))
      assert.same({}, ns.House:Members(nil))
    end)

    it("break level ties by name", function()
      boot({ extra = { [mock.TOBIN] = { level = 20, name = "Abel" } } })
      assert.same({ "Mira", "Abel", "Aren" }, mock.names(ns.House:Members(char)))
    end)

    it("include a character that has no stored record", function()
      boot()
      local guest = { guid = "Player-1-00000099", name = "Guest", surname = "Ashvale", level = 99 }
      assert.same({ "Guest", "Mira", "Aren", "Tobin" }, mock.names(ns.House:Members(guest)))
    end)

    it("are read in read-only mode, while the module is unavailable", function()
      local stored = mock.siblings()
      stored[mock.AREN] = { guid = mock.AREN, name = "Aren", surname = "Ashvale", level = 20, log = {} }
      wow.saved({ schema = 99, chars = stored })
      ns = wow.load(mock.FILES)
      wow.login()
      assert.same({ "schema" }, ns.House.unavailable)
      assert.same({ "Mira", "Aren", "Tobin" }, mock.names(ns.House:Members(ns.DB:Char())))
    end)
  end)

  describe("/ashmark house", function()
    it("joins the house of a stored surname matched ignoring ASCII case", function()
      boot()
      local changes = mock.changes(ns)
      slash("  iRONHOLD ")
      assert.equal("Ironhold", char.houseOverride)
      assert.equal("Ironhold", ns.House:Key(char))
      assert.same({ "Kel", "Aren" }, mock.names(ns.House:Members(char)))
      assert.equal("You now belong to House Ironhold.", said())
      assert.same({ "Ironhold" }, changes)
    end)

    it("takes any other name as typed and trimmed; only A to Z fold", function()
      boot({ extra = { [mock.NYM] = { surname = "Élanor" } } })
      slash("  Stormhollow  ")
      assert.equal("Stormhollow", char.houseOverride)
      slash("élanor")
      assert.equal("élanor", char.houseOverride)
      slash("ÉLANOR")
      assert.equal("Élanor", char.houseOverride)
    end)

    it("prefers a surname that matches exactly over one that differs in case", function()
      boot({ extra = { [mock.TOBIN] = { surname = "IRONHOLD" } } })
      slash("IRONHOLD")
      assert.equal("IRONHOLD", char.houseOverride)
      slash("ironhold")
      assert.equal("IRONHOLD", char.houseOverride)
      slash("Ironhold")
      assert.equal("Ironhold", char.houseOverride)
    end)

    it("reset follows the surname again; set and reset both fire HOUSE_CHANGED", function()
      boot()
      local changes = mock.changes(ns)
      slash("Stormhollow")
      slash("RESET")
      assert.is_nil(char.houseOverride)
      assert.equal("Your house follows your surname again: House Ashvale.", said())
      char.surname = nil
      slash("reset")
      assert.equal(ns.L.HOUSE_SLASH_RESET_NONE, said())
      assert.same({ "Stormhollow", "Ashvale", "<nil>" }, changes)
    end)

    it("names the current house without arguments and fires nothing", function()
      boot()
      local changes = mock.changes(ns)
      slash()
      assert.equal("You belong to House Ashvale.", said())
      char.surname = nil
      slash("   ")
      assert.equal(ns.L.HOUSE_SLASH_NONE, said())
      assert.same({}, changes)
    end)

    it("is listed in the help", function()
      boot()
      SlashCmdList.ASHMARK("help")
      local found = false
      for _, line in ipairs(wow.chat) do
        if line:find("/ashmark house - " .. ns.L.HOUSE_HELP, 1, true) then found = true end
      end
      assert.is_true(found)
    end)

    it("changes nothing while the module is off", function()
      boot()
      ns.Settings:Set("House.enabled", false)
      local changes = mock.changes(ns)
      slash("Stormhollow")
      assert.is_nil(char.houseOverride)
      assert.equal(ns.L.HOUSE_SLASH_OFF, said())
      assert.same({}, changes)
    end)
  end)

  describe("sibling alliances", function()
    it("group the siblings' sides per conflict, without the character or other houses", function()
      local function allied(t) return { conflicts = { allied = t } } end
      boot({ extra = {
        [mock.MIRA] = allied({ clan_choice = "A", coast = "B" }),
        [mock.TOBIN] = allied({ clan_choice = "B", bogus = "C" }),
        [mock.KEL] = allied({ clan_choice = "A" }),
      } })
      char.conflicts = { allied = { clan_choice = "A", grove = "B" } }
      assert.same({
        clan_choice = { A = { mock.MIRA }, B = { mock.TOBIN } },
        coast = { A = {}, B = { mock.MIRA } },
      }, ns.House:SiblingAlliances(char))
      assert.same({}, ns.House:SiblingAlliances(mock.char(mock.KEL)))
      assert.same({}, ns.House:SiblingAlliances(mock.char(mock.NYM)))
    end)

    it("list every sibling on a side", function()
      local function allied(t) return { conflicts = { allied = t } } end
      boot({ extra = { [mock.MIRA] = allied({ grove = "B" }), [mock.TOBIN] = allied({ grove = "B" }) } })
      assert.same({ grove = { A = {}, B = { mock.MIRA, mock.TOBIN } } }, ns.House:SiblingAlliances(char))
    end)
  end)

  describe("family chronicle", function()
    local T = 1790000000

    local function lines(list)
      local out = {}
      for i, item in ipairs(list) do out[i] = item.text end
      return out
    end

    local function seed()
      local mira, tobin, kel = mock.char(mock.MIRA), mock.char(mock.TOBIN), mock.char(mock.KEL)
      mock.entry(mira, "alliance", T - 900, { c = "clan_choice", side = "A" })
      mock.entry(mira, "level", T - 800, { l = 30 })
      mock.entry(mira, "level", T - 790, { l = 31 })
      mock.entry(mira, "quest.turnin", T - 780, { q = 1382 })
      mock.entry(mira, "rep", T - 770, { f = 92, s = 6, d = 10 })
      mock.entry(mira, "chapter", T - 700, { no = 1, m = 1443 })
      mock.entry(tobin, "houseturn", T - 600, { c = "grove", side = "B", h = "Ashvale" })
      mock.entry(tobin, "violation", T - 500, { c = "coast", side = "B", q = 4001 })
      mock.entry(kel, "alliance", T - 100, { c = "coast", side = "A" })
      return mira, tobin
    end

    it("tells the members' decisions, chapters and every tenth level, newest first", function()
      boot()
      seed()
      wow.state.map = 1443
      ns.Log:Add("level", { l = 20 })
      ns.Log:Add("alliance", { c = "coast", side = "B" })
      ns.Log:Add("level", { l = 21 })
      assert.same({
        "You sided in coast.",
        "You reached level 20.",
        "Tobin broke faith in coast.",
        "Tobin turned in grove.",
        "Mira's chapter I closes in Desolace.",
        "Mira reached level 30.",
        "Mira sided in clan_choice.",
      }, lines(ns.House:FamilyChronicle(char)))
    end)

    it("hands back each entry with its member and stops at the limit", function()
      boot()
      local _, tobin = seed()
      local list = ns.House:FamilyChronicle(char, 2)
      assert.equal(2, #list)
      assert.equal(tobin, list[1].char)
      assert.equal("violation", list[1].entry.k)
      assert.same({}, ns.House:FamilyChronicle(char, 0))
    end)

    it("orders entries of the same second by member, then newest first within one", function()
      boot()
      local mira, tobin = mock.char(mock.MIRA), mock.char(mock.TOBIN)
      mock.entry(tobin, "level", T - 10, { l = 10 })
      mock.entry(mira, "level", T - 10, { l = 10 })
      mock.entry(mira, "level", T - 10, { l = 20 })
      assert.same({ "Mira reached level 20.", "Mira reached level 10.", "Tobin reached level 10." },
        lines(ns.House:FamilyChronicle(char)))
    end)

    it("is the character's own chronicle without siblings, and empty without a house", function()
      boot()
      ns.Log:Add("level", { l = 30 })
      assert.same({ "You reached level 30." }, lines(ns.House:FamilyChronicle(char)))
      local nym = mock.char(mock.NYM)
      mock.entry(nym, "level", T, { l = 10 })
      assert.same({}, ns.House:FamilyChronicle(nym))
    end)

    it("skips kinds that have no renderer in this load", function()
      boot({ kinds = false })
      seed()
      assert.same({ "Mira's chapter I closes in Desolace.", "Mira reached level 30." },
        lines(ns.House:FamilyChronicle(char)))
    end)
  end)

  describe("legacy", function()
    it("is the renown level of the Legacy faction, named by the client", function()
      boot()
      wow.data.majorFactions[2802].renownLevel = 4
      assert.equal("Legacy: level 4", ns.House:Legacy(char))
    end)

    it("falls back to the standing label, in the character's form", function()
      wow.data.majorFactions[2802] = nil
      wow.data.factions[2802] = { factionID = 2802, name = "Legacy of the Ages", reaction = 5 }
      boot()
      _G.FACTION_STANDING_LABEL5_FEMALE = "Friendly (f)"
      char.sex = 3
      assert.equal("Legacy of the Ages: Friendly (f)", ns.House:Legacy(char))
    end)

    it("is absent without the legacy capability or with secret data", function()
      wow.data.majorFactions[2802] = nil
      boot()
      assert.is_false(ns.Compat.Has.legacy)
      assert.is_nil(ns.House:Legacy(char))
      -- Compat itself reads secret data as absent; the line checks again on its own.
      ns.Compat.Has.legacy = true
      wow.data.majorFactions[2802] = wow.secret({ name = "Legacy", renownLevel = 2 })
      assert.is_nil(ns.House:Legacy(char))
      wow.data.majorFactions[2802] = { name = "Legacy", renownLevel = wow.secret(2) }
      wow.data.factions[2802] = { name = "Legacy", reaction = wow.secret(5) }
      assert.is_nil(ns.House:Legacy(char))
    end)
  end)

  describe("test checks", function()
    it("report the house and its members, or how to choose one", function()
      boot()
      char.surnameSource = "UnitNameUnmodified"
      local ok, detail = mock.check(ns, "House.key")
      assert.is_true(ok)
      assert.equal("House Ashvale from UnitNameUnmodified, 3 members, 0 sibling conflicts", detail)
      char.surname = nil
      ok, detail = mock.check(ns, "House.key")
      assert.is_nil(ok)
      assert.truthy(detail:find(ns.L.HOUSE_SLASH_NONE, 1, true))
    end)

    it("report the Legacy line, skipped without the capability", function()
      boot()
      assert.same({ true, "Legacy: level 1" }, { mock.check(ns, "House.legacy") })
      ns.Compat.Has.legacy = false
      assert.is_nil((mock.check(ns, "House.legacy")))
    end)
  end)
end)

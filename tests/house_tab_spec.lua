local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.house_mock")

local CONFLICTS = {
  clan_choice = { id = "clan_choice", zone = 1443, A = { faction = 92 }, B = { faction = 93 } },
  grove = { id = "grove", zone = 2652, A = { faction = 92 }, B = { faction = 0 } },
  coast = { id = "coast", zone = 1434, A = { faction = 21 }, B = { faction = 87 } },
}
local THALEN, ODA = "Player-1-00000010", "Player-1-00000011"

describe("UI House tab", function()
  local ns, char, lists, bars, known

  -- ns.UI:List, ns.UI:StatusBar and ns.UI:ClassColored as 6.1 describes them, recording what the tab hands
  -- over; the real widgets have their own spec.
  local function fakeWidgets()
    lists, bars = {}, {}
    ns.UI.List = function(_, parent, opts)
      local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
      function box:SetDataProvider(provider, retain) self.provider, self.retain = provider, retain end
      local provider = CreateDataProvider()
      box:SetDataProvider(provider)
      lists[#lists + 1] = { parent = parent, opts = opts, box = box }
      return box, provider
    end
    ns.UI.StatusBar = function(_, parent)
      local bar = CreateFrame("StatusBar", nil, parent)
      bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      function bar:SetValue(v) self.value = v end
      function bar:SetMinMaxValues(lo, hi) self.range = { lo, hi } end
      bars[#bars + 1] = bar
      return bar
    end
    ns.UI.ClassColored = function(_, text, class) return "[" .. tostring(class) .. ":" .. tostring(text) .. "]" end
  end

  -- The public calls of Profile, Conflicts and Encounters the tab makes (3.8).
  local function fakeServices()
    ns.Profile = {
      Axes = function() return { fidelity = 40, habitat = -12, mercy = 0 } end,
      Archetype = function() return "OATHKEEPER" end,
    }
    ns.Conflicts = {
      Get = function(_, id) return CONFLICTS[id] end,
      Alliance = function(_, c, id)
        local allied = c and c.conflicts and c.conflicts.allied
        return allied and allied[id]
      end,
    }
    known = {}
    ns.Encounters = {
      Known = function(_, c, min)
        assert.equal(3, min)
        return known[c.guid] or {}
      end,
      Contact = function(_, guid) return _G.AshmarkDB.contacts[guid] end,
    }
  end

  local function boot(opts)
    opts = opts or {}
    opts.files = { "UI/Widgets.lua", "UI/MainFrame.lua", "UI/Tabs/House.lua" }
    opts.setup = function(loaded)
      ns = loaded
      fakeWidgets()
      fakeServices()
    end
    wow.stub("ScrollBoxConstants", { RetainScrollPosition = true })
    ns, char = mock.boot(wow, opts)
    return char
  end

  local function tab()
    ns.UI.MainFrame:Show("house")
    return lists[1].parent:GetParent()
  end

  local function rows()
    return lists[1].box.provider.items
  end

  local function texts()
    local out = {}
    for _, row in ipairs(rows()) do out[#out + 1] = (row.header and "# " or "") .. row.text end
    return out
  end

  local function allied(t) return { conflicts = { allied = t } } end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("registers the House tab with a list of single-line rows", function()
    boot()
    tab()
    assert.equal(ns.L.HOUSE_TAB, AshmarkFrame.Tabs[1]:GetText())
    assert.equal(20, lists[1].opts.extent)
    assert.is_true(lists[1].box.retain)
  end)

  it("names the house and the Legacy, and shows the axes under the archetype", function()
    boot()
    wow.data.majorFactions[2802].renownLevel = 3
    local t = tab()
    assert.equal("House Ashvale", t.Heading:GetText())
    assert.equal("Legacy: level 3", t.Legacy:GetText())
    assert.equal("Archetype: Oathkeeper", t.Archetype:GetText())
    assert.equal(3, #bars)
    assert.same({ 40, -12, 0 }, { bars[1].value, bars[2].value, bars[3].value })
    assert.same({ "40", "-12", "0" }, { bars[1].Text:GetText(), bars[2].Text:GetText(), bars[3].Text:GetText() })
    assert.same({ -100, 100 }, bars[1].range)
    assert.same({ "Opportunist", "Oathkeeper" }, { bars[1].Low:GetText(), bars[1].High:GetText() })
    assert.same({ "Town-dweller", "Wanderer" }, { bars[2].Low:GetText(), bars[2].High:GetText() })
    assert.same({ "Ruthless soul", "Gentle soul" }, { bars[3].Low:GetText(), bars[3].High:GetText() })
    assert.is_false(t.Empty:IsShown())
  end)

  it("labels the archetypes in the form for the character's sex", function()
    wow.state.units.player.sex = 3
    boot()
    local base = ns.Locale:Base()
    base.PROFILE_OATHKEEPER_F, base.PROFILE_OPPORTUNIST_F = "Oathkeeper (f)", "Opportunist (f)"
    local t = tab()
    assert.equal("Archetype: Oathkeeper (f)", t.Archetype:GetText())
    assert.same({ "Opportunist (f)", "Oathkeeper (f)" }, { bars[1].Low:GetText(), bars[1].High:GetText() })
    assert.same({ "Town-dweller", "Wanderer" }, { bars[2].Low:GetText(), bars[2].High:GetText() })
    char.sex = 2
    t = tab()
    assert.equal("Archetype: Oathkeeper", t.Archetype:GetText())
    assert.same({ "Opportunist", "Oathkeeper" }, { bars[1].Low:GetText(), bars[1].High:GetText() })
  end)

  it("lists the members by level with their class icons", function()
    boot()
    tab()
    assert.same({
      "# Members",
      "[MAGE:Mira Ashvale], level 35",
      "[WARRIOR:Aren Ashvale], level 20",
      "[ROGUE:Tobin Ashvale], level 12",
    }, texts())
    assert.same({ "members", "classicon-mage" }, { rows()[1].key, rows()[2].atlas })
  end)

  it("tags the rulesets only when the members' rulesets differ", function()
    boot({ extra = { [mock.TOBIN] = { ruleset = "RPPvP" } } })
    tab()
    assert.equal("[MAGE:Mira Ashvale], level 35 · Normal", rows()[2].text)
    assert.equal("[ROGUE:Tobin Ashvale], level 12 · Roleplay PvP", rows()[4].text)
  end)

  it("lists the feuds the siblings took up that the character does not share", function()
    boot({ extra = {
      [mock.MIRA] = allied({ clan_choice = "A", coast = "B" }),
      [mock.TOBIN] = allied({ clan_choice = "B", grove = "B", gone = "A" }),
      [mock.KEL] = allied({ coast = "A" }),
    } })
    char.conflicts = { allied = { clan_choice = "A" } }
    tab()
    local list = texts()
    assert.same({
      "# Inherited feuds",
      "[ROGUE:Tobin] sided with Magram Clan Centaur in Desolace.",
      "[ROGUE:Tobin] sided with those without a banner in Shen'dralas.",
      "[MAGE:Mira] sided with Bloodsail Buccaneers in Stranglethorn Vale.",
    }, { list[5], list[6], list[7], list[8] })
    assert.equal(8, #list)
  end)

  it("tells the family chronicle and the people the siblings keep meeting", function()
    boot()
    local mira, tobin = mock.char(mock.MIRA), mock.char(mock.TOBIN)
    mock.entry(mira, "level", 1789990000, { l = 30 })
    mock.entry(tobin, "alliance", 1789980000, { c = "coast", side = "A" })
    _G.AshmarkDB.contacts[THALEN] = { guid = THALEN, name = "Thalen", class = "HUNTER" }
    _G.AshmarkDB.contacts[ODA] = { guid = ODA, name = "Oda", class = "SHAMAN" }
    known[mock.MIRA] = { [THALEN] = { count = 4 }, [ODA] = { count = 3 } }
    known[mock.TOBIN] = { [THALEN] = { count = 3 } }
    known[mock.AREN] = { [ODA] = { count = 9 } }
    tab()
    local list = texts()
    assert.same({
      "# Family chronicle",
      "Mira reached level 30.",
      "Tobin sided in coast.",
      "# Family memory",
      "[MAGE:Mira] knows [SHAMAN:Oda].",
      "[MAGE:Mira] knows [HUNTER:Thalen].",
      "[ROGUE:Tobin] knows [HUNTER:Thalen].",
    }, { unpack(list, 5) })
  end)

  it("shows how to choose a house when the character has none, with the axes still there", function()
    boot()
    char.surname = nil
    local t = tab()
    assert.equal(ns.L.HOUSE_TAB_NO_HOUSE, t.Heading:GetText())
    assert.is_true(t.Empty:IsShown())
    assert.equal(ns.L.HOUSE_TAB_NONE, t.Empty:GetText())
    assert.same({}, rows())
    assert.is_true(t.Archetype:IsShown())
    assert.is_true(bars[1]:IsShown())
  end)

  it("hides the axes and leaves out the sections whose units are missing", function()
    boot({ extra = { [mock.MIRA] = allied({ coast = "B" }) } })
    ns.Profile, ns.Conflicts, ns.Encounters = nil, nil, nil
    ns.Compat.Has.legacy = false
    local t = tab()
    assert.is_false(t.Archetype:IsShown())
    assert.is_false(bars[2]:IsShown())
    assert.equal("", t.Legacy:GetText())
    assert.equal("# Members", texts()[1])
    assert.equal(4, #rows())
  end)

  it("follows a change of house while it is shown", function()
    boot()
    local t = tab()
    SlashCmdList.ASHMARK("house ironhold")
    wow.advance(0.5)
    assert.equal("House Ironhold", t.Heading:GetText())
    assert.same({ "# Members", "[PALADIN:Kel Ironhold], level 50", "[WARRIOR:Aren Ashvale], level 20" }, texts())
  end)

  it("is hidden while the module is off", function()
    boot()
    tab()
    ns.Settings:Set("House.enabled", false)
    wow.advance(0.5)
    assert.is_false(AshmarkFrame.Tabs[1]:IsShown())
  end)

  describe("rows", function()
    local function draw(data)
      local button = CreateFrame("Button")
      lists[1].opts.init(button, data)
      return button
    end

    it("draw members with the class icon and other rows indented as text", function()
      boot()
      tab()
      local member = draw(rows()[2])
      assert.equal("classicon-mage", member.icon:GetAtlas())
      assert.is_true(member.icon:IsShown())
      assert.equal(rows()[2].text, member.label:GetText())
      local line = draw({ text = "Mira reached level 30." })
      assert.is_false(line.icon:IsShown())
      assert.equal("Mira reached level 30.", line.label:GetText())
      draw(rows()[2])
      local again = draw({ text = "x" })
      assert.is_false(again.icon:IsShown())
    end)

    it("show a truncated sentence in full in the tooltip", function()
      boot()
      tab()
      local button = draw({ text = "A very long sentence." })
      button.label.IsTruncated = function() return true end
      wow.script(button, "OnEnter")
      assert.equal(button, GameTooltip:GetOwner())
      assert.equal("A very long sentence.", _G.GameTooltipTextLeft1:GetText())
      wow.script(button, "OnLeave")
    end)
  end)
end)

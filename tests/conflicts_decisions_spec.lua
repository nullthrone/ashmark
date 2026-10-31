local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.conflicts_mock")

local FILES = { "UI/MainFrame.lua", "UI/Tabs/Chronicle.lua", "UI/Tabs/Decisions.lua" }

describe("Conflicts Decisions tab", function()
  local ns, lists

  -- ns.UI:List and ns.UI:Parchment as 6.1 describes them, recording what the tabs hand over; the
  -- real widgets (which draw and collapse the header rows) have their own spec.
  local function fakeWidgets(n)
    lists = {}
    n.UI.List = function(_, parent, opts)
      local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
      function box:SetDataProvider(provider, retain) self.provider, self.retain = provider, retain end
      local provider = CreateDataProvider()
      box:SetDataProvider(provider)
      lists[#lists + 1] = { parent = parent, opts = opts, box = box }
      return box, provider
    end
    n.UI.Parchment = function() return false end
  end

  local function boot(opts)
    opts = opts or {}
    ns = mock.boot(wow, { files = FILES, data = opts.data, setup = function(n)
      fakeWidgets(n)
      wow.stub("ScrollBoxConstants", { RetainScrollPosition = "retain", DiscardScrollPosition = "discard" })
      if opts.setup then opts.setup(n) end
    end })
    return ns.DB:Char()
  end

  local function show()
    ns.UI.MainFrame:Show("decisions")
    return lists[1].parent:GetParent()
  end

  local function rows()
    return lists[1].box.provider.items
  end

  local function row(id)
    for _, data in ipairs(rows()) do
      if data.id == id then return data end
    end
  end

  local function headers()
    local out = {}
    for _, data in ipairs(rows()) do
      if data.header then out[#out + 1] = { data.key, data.text } end
    end
    return out
  end

  local function since(char, id)
    return os.date("%Y-%m-%d", char.conflicts.since[id])
  end

  before_each(function()
    wow.reset()
    mock.titles(wow)
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("is the second tab of the main window and belongs to the module", function()
    boot()
    show()
    local frame = _G.AshmarkFrame
    assert.equal("Decisions", frame.Tabs[2]:GetText())
    assert.equal(2, frame.selectedTab)
    assert.equal(34, lists[1].opts.extent)
    ns.Settings:Set("Conflicts.enabled", false)
    wow.advance(0.5)
    assert.is_false(frame.Tabs[2]:IsShown())
    assert.equal(1, frame.selectedTab)
  end)

  it("lists the zones by name, each header followed by its conflicts, all open at first", function()
    boot()
    local tab = show()
    assert.same({ { 1443, "Desolace" }, { 2652, "Shen'dralas" }, { 1434, "Stranglethorn Vale" } }, headers())
    local ids = {}
    for _, data in ipairs(rows()) do ids[#ids + 1] = data.header and "-" or data.id end
    assert.same({ "-", "clan_choice", "-", "grove", "-", "coast_raid" }, ids)
    assert.same({ sides = "Gelkis Alliance: Gelkis Clan Centaur or Magram Clan Centaur", status = "Open", open = true,
                  broken = "", id = "clan_choice" }, row("clan_choice"))
    assert.equal("Grove Keepers: Gelkis Clan Centaur or those without a banner", row("grove").sides)
    assert.equal("You have not broken your word.", tab.Total:GetText())
    assert.is_false(tab.Empty:IsShown())
    assert.equal("retain", lists[1].box.retain)
  end)

  it("tells conflicts between the same two factions in one zone apart by the title of their first quest", function()
    boot({ data = mock.twins() })
    show()
    local ids = {}
    for _, data in ipairs(rows()) do ids[#ids + 1] = data.header and "-" or data.id end
    assert.same({ "-", "clan_choice", "clan_raid", "-", "grove", "far_raid", "-", "coast_raid" }, ids)
    assert.equal("Gelkis Alliance: Gelkis Clan Centaur or Magram Clan Centaur", row("clan_choice").sides)
    assert.equal("Raid on the Kolkar: Gelkis Clan Centaur or Magram Clan Centaur", row("clan_raid").sides)
    assert.equal("Saving Our Own: Magram Clan Centaur or Gelkis Clan Centaur", row("far_raid").sides)
  end)

  it("joins the sides with CONFLICT_TAB_SIDES_VOWEL when the second begins with the sound /o/", function()
    boot({ setup = function(n) n.Locale:Base().CONFLICT_TAB_SIDES_VOWEL = "{title}: {a} u {b}" end })
    wow.data.factions[93].name = "Hordas de Magram"
    show()
    assert.equal("Gelkis Alliance: Gelkis Clan Centaur u Hordas de Magram", row("clan_choice").sides)
    assert.equal("Bloodsail Correspondence: Booty Bay or Bloodsail Buccaneers", row("coast_raid").sides)
  end)

  it("names a conflict whose first quest the client has not loaded yet, and asks for it", function()
    wow.data.quests[3001].title = nil
    boot()
    show()
    assert.equal("a quest: Booty Bay or Bloodsail Buccaneers", row("coast_raid").sides)
    assert.same({ 3001 }, wow.requests.quest)
  end)

  it("shows the side taken and since when, the broken count per conflict and the total", function()
    local char = boot()
    local tab = show()
    mock.accept(wow, 1001)
    wow.advance(0.5)
    assert.same({ "Sided with Gelkis Clan Centaur since " .. since(char, "clan_choice"), false, "" },
                { row("clan_choice").status, row("clan_choice").open, row("clan_choice").broken })
    mock.turnIn(wow, 2001)
    mock.turnIn(wow, 4001)
    wow.advance(0.5)
    assert.equal("Sided with Magram Clan Centaur since " .. since(char, "clan_choice"), row("clan_choice").status)
    assert.equal("Broken 1×", row("clan_choice").broken)
    assert.equal("", row("coast_raid").broken)
    assert.equal("Words broken: 1", tab.Total:GetText())
  end)

  it("dates a decision with the client's short date when there is one", function()
    local char = boot()
    wow.stub("FormatShortDate", function(d, m, y) return table.concat({ d, m, y }, ".") end)
    mock.turnIn(wow, 3001)
    show()
    local d = os.date("*t", char.conflicts.since.coast_raid)
    assert.equal("Sided with Booty Bay since " .. table.concat({ d.day, d.month, d.year % 100 }, "."),
                 row("coast_raid").status)
  end)

  it("draws a conflict row once per pooled button, decided rows bright and open ones grey", function()
    boot()
    mock.turnIn(wow, 1001)
    mock.turnIn(wow, 2001)
    show()
    local button = CreateFrame("Button")
    lists[1].opts.init(button, row("coast_raid"))
    local sides, status, broken = button.sides, button.status, button.broken
    assert.same({ "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightSmall" },
                { sides.__template, status.__template, broken.__template })
    assert.equal("Bloodsail Correspondence: Booty Bay or Bloodsail Buccaneers", sides:GetText())
    assert.same({ GRAY_FONT_COLOR:GetRGB() }, { status:GetTextColor() })
    lists[1].opts.init(button, row("clan_choice"))
    assert.equal(sides, button.sides)
    assert.equal(row("clan_choice").status, status:GetText())
    assert.same({ HIGHLIGHT_FONT_COLOR:GetRGB() }, { status:GetTextColor() })
    assert.equal("Broken 1×", broken:GetText())
    assert.same({ RED_FONT_COLOR:GetRGB() }, { broken:GetTextColor() })
  end)

  it("shows every conflict open without a character record", function()
    boot()
    ns.playerGUID = nil
    local tab = show()
    assert.equal("Open", row("clan_choice").status)
    assert.equal("You have not broken your word.", tab.Total:GetText())
  end)

  it("says so when it knows no conflicts", function()
    boot({ data = { count = 0, list = {} } })
    local tab = show()
    assert.same({}, rows())
    assert.is_true(tab.Empty:IsShown())
    assert.equal(ns.L.CONFLICT_TAB_EMPTY, tab.Empty:GetText())
  end)
end)

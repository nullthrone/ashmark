local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.encounters_mock")

local ME, ALT = mock.ME, mock.ALT
local THALEN, MIRA, KEL, ORLA = mock.guid("thalen"), mock.guid("mira"), mock.guid("kel"), mock.guid("orla")
local DESOLACE, ELWYNN = 1443, 1429

local FILES = { "UI/Widgets.lua", "UI/MainFrame.lua", "UI/Tabs/Chronicle.lua", "UI/Tabs/Encounters.lua" }

describe("Encounters tab", function()
  local ns, lists, dialog
  local now

  -- ns.UI:List and ns.UI.Dialog as 6.1 and 6.2 describe them, recording what the tab hands over; the real
  -- widgets and dialog have their own specs.
  local function fakeUI(n)
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
    n.UI.Dialog = { Show = function(_, opts) dialog = opts end }
  end

  -- Thalen recurring with a note, Mira met once more recently, Kel only by the alt, Orla met long ago.
  local function stored()
    return {
      schema = 1,
      contacts = {
        [THALEN] = mock.contact(THALEN, { name = "Thalen", surname = "Brightwood", class = "PALADIN", race = 1, sex = 2,
          note = "Tanked the Deadmines", byChar = { [ME] = mock.met(3, now - 7200, { lastPlace = DESOLACE }) } }),
        [MIRA] = mock.contact(MIRA, { name = "Mira", class = "MAGE", race = 7, sex = 3,
          byChar = { [ME] = mock.met(1, now - 600, { lastPlace = ELWYNN }), [ALT] = mock.met(4, now) } }),
        [KEL] = mock.contact(KEL, { name = "Kel", class = "ROGUE", byChar = { [ALT] = mock.met(2, now) } }),
        [ORLA] = mock.contact(ORLA, { name = "Orla", class = "PRIEST", race = 4, sex = 3,
          byChar = { [ME] = mock.met(1, now - 86400) } }),
      },
    }
  end

  local function boot(db)
    wow.saved(db or stored())
    ns = mock.boot(wow, { files = FILES, setup = function(n)
      fakeUI(n)
      wow.stub("ScrollBoxConstants", { RetainScrollPosition = "retain", DiscardScrollPosition = "discard" })
    end })
    return ns
  end

  local function show()
    ns.UI.MainFrame:Show("encounters")
    for _, list in ipairs(lists) do
      if list.opts.extent == 34 then return list.parent:GetParent(), list end
    end
  end

  local function rows()
    local _, list = show()
    return list.box.provider.items
  end

  -- The tab's data provider now, without showing the tab again.
  local function provider()
    for _, list in ipairs(lists) do
      if list.opts.extent == 34 then return list.box.provider end
    end
  end

  -- A row as the list draws it: its texts are made in init (lazily, for the rows on screen only).
  local function drawn(data)
    for _, list in ipairs(lists) do
      if list.opts.extent == 34 then list.opts.init(CreateFrame("Button"), data) end
    end
    return data
  end

  -- The rows on screen now, without showing the tab again (which refreshes it).
  local function current(guid)
    for _, list in ipairs(lists) do
      if list.opts.extent == 34 then
        for _, row in ipairs(list.box.provider.items) do
          if row.guid == guid then return drawn(row) end
        end
      end
    end
  end

  local function guids()
    local out = {}
    for i, row in ipairs(rows()) do out[i] = row.guid end
    return out
  end

  local function find(guid)
    for _, row in ipairs(rows()) do
      if row.guid == guid then return drawn(row) end
    end
  end

  local function button(data)
    local _, list = show()
    local b = CreateFrame("Button")
    list.opts.init(b, data)
    return b
  end

  before_each(function()
    wow.reset()
    now = wow.state.epoch
    dialog = nil
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("is a tab of the main window behind the Chronicle and belongs to the module", function()
    boot()
    show()
    local frame = _G.AshmarkFrame
    assert.equal("Encounters", frame.Tabs[2]:GetText())
    assert.equal(2, frame.selectedTab)
    ns.Settings:Set("Encounters.enabled", false)
    wow.advance(0.5)
    assert.is_false(frame.Tabs[2]:IsShown())
    assert.equal(1, frame.selectedTab)
  end)

  it("lists this character's contacts, the most recent meeting first", function()
    boot()
    assert.same({ MIRA, THALEN, ORLA }, guids())
    local tab = show()
    assert.equal("People you have met: 3 · familiar faces: 1", tab.Total:GetText())
    assert.is_false(tab.Empty:IsShown())
    assert.equal("retain", tab.List.retain)
  end)

  it("shows name in class colour, the recurring marker, the note and the last meeting", function()
    boot()
    local thalen = find(THALEN)
    assert.equal(ns.UI:ClassColored("Thalen Brightwood", "PALADIN"), thalen.name)
    assert.is_true(thalen.recurring)
    assert.equal("Tanked the Deadmines", thalen.note)
    assert.equal("Met 3× · last in Desolace · " .. os.date("%Y-%m-%d", now - 7200), thalen.info)
    assert.equal("Human Paladin", thalen.who)
    local b = button(thalen)
    assert.equal(thalen.name, b.name:GetText())
    assert.equal("Familiar face", b.marker:GetText())
    assert.equal("Tanked the Deadmines", b.note:GetText())
    assert.equal(thalen.info, b.info:GetText())
    assert.equal("classicon-paladin", b.icon:GetAtlas())
    assert.equal("Note", b.noteButton:GetText())
    local mira = button(find(MIRA))
    assert.equal("", mira.marker:GetText())
    assert.equal("", mira.note:GetText())
    assert.equal("Met 1× · last in Elwynn Forest · " .. os.date("%Y-%m-%d", now - 600), mira.info:GetText())
  end)

  it("reuses a pooled row for another contact", function()
    boot()
    local b = button(find(THALEN))
    local icon = b.icon
    ns.Encounters:Contact(ORLA).class = nil
    local orla = find(ORLA)
    local _, list = show()
    list.opts.init(b, orla)
    assert.equal(icon, b.icon)
    assert.is_false(b.icon:IsShown())
    assert.equal("", b.marker:GetText())
    assert.equal("Met 1× · " .. os.date("%Y-%m-%d", now - 86400), b.info:GetText())
  end)

  it("opens the note editor from the row's button and shows the new note", function()
    boot()
    local b = button(find(THALEN))
    wow.script(b.noteButton, "OnClick")
    assert.equal("Your note on Thalen Brightwood:", dialog.text)
    assert.same({ text = "Tanked the Deadmines", max = 120 }, dialog.edit)
    local before = provider()
    dialog.onAccept("Healed us through Gnomeregan")
    assert.equal("Healed us through Gnomeregan", ns.Encounters:Contact(THALEN).note)
    assert.equal(before, provider())
    wow.advance(0.5)
    assert.is_not.equal(before, provider())
    assert.equal("Healed us through Gnomeregan", current(THALEN).note)
  end)

  it("redraws for contacts, a reset and module toggles, not for every log entry", function()
    boot()
    show()
    local before = provider()
    ns.Log:Add("gold", { src = "loot", c = 5 })
    ns.Bus:Fire("PROFILE_CHANGED")
    ns.Bus:Fire("HOUSE_CHANGED")
    wow.advance(0.5)
    assert.equal(before, provider())
    ns.Encounters:SetNote(THALEN, "Owes me a drink")
    wow.advance(0.5)
    assert.is_not.equal(before, provider())
    before = provider()
    ns.Bus:Fire("LOG_COMPACTED", ns.DB:Char())
    wow.advance(0.5)
    assert.is_not.equal(before, provider())
  end)

  it("makes a row's texts only when the list draws it", function()
    boot()
    local calls, race = 0, ns.Names.Race
    ns.Names.Race = function(...)
      calls = calls + 1
      return race(...)
    end
    local list = rows()
    assert.equal(3, #list)
    assert.equal(0, calls)
    drawn(list[2])
    assert.equal(1, calls)
    assert.equal("Human Paladin", list[2].who)
    drawn(list[2])
    assert.equal(1, calls)
  end)

  it("leaves a race or class the client does not know out of the who line", function()
    local db = stored()
    db.contacts[THALEN].race = 999
    db.contacts[MIRA].class = nil
    db.contacts[ORLA].race, db.contacts[ORLA].class = nil, nil
    boot(db)
    assert.equal("Paladin", find(THALEN).who)
    assert.equal("Gnome", find(MIRA).who)
    local orla = find(ORLA)
    assert.is_nil(orla.who)
    local b = button(orla)
    wow.script(b, "OnEnter")
    local texts = {}
    for i = 1, GameTooltip:NumLines() do texts[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    assert.same({ orla.name, orla.info, orla.first }, texts)
  end)

  it("follows new meetings", function()
    boot()
    show()
    mock.session(wow, ns, { "kel" })
    wow.advance(0.5)
    assert.is_not_nil(current(KEL))
    assert.same({ KEL, MIRA, THALEN, ORLA }, guids())
  end)

  it("shows the whole contact in the row's tooltip", function()
    boot()
    local b = button(find(THALEN))
    wow.script(b, "OnEnter")
    local texts = {}
    for i = 1, GameTooltip:NumLines() do texts[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    assert.same({ find(THALEN).name, "Human Paladin", find(THALEN).info,
                  "First met " .. os.date("%Y-%m-%d", now - 8200), "Tanked the Deadmines" }, texts)
    assert.equal(b, GameTooltip:GetOwner())
    wow.script(b, "OnLeave")
    assert.is_false(GameTooltip:IsShown())
  end)

  it("says so when this character has met nobody", function()
    local db = stored()
    db.contacts[THALEN].byChar[ME] = nil
    db.contacts[MIRA].byChar[ME] = nil
    db.contacts[ORLA] = nil
    boot(db)
    local tab = show()
    assert.same({}, rows())
    assert.is_true(tab.Empty:IsShown())
    assert.equal("People you have met: 0 · familiar faces: 0", tab.Total:GetText())
  end)
end)

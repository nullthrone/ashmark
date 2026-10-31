local wow = require("tests.helpers.wow")

local FILES = { "UI/Widgets.lua", "UI/MainFrame.lua", "UI/Tabs/Chronicle.lua" }

describe("UI Chronicle tab", function()
  local ns, lists, parchment

  -- ns.UI:List and ns.UI:Parchment as 6.1 describes them, recording what the tab hands over;
  -- the real widgets have their own spec.
  local function fakeWidgets()
    lists = {}
    ns.UI.List = function(_, parent, opts)
      local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
      function box:SetDataProvider(provider, retain) self.provider, self.retain = provider, retain end
      local provider = CreateDataProvider()
      box:SetDataProvider(provider)
      lists[#lists + 1] = { parent = parent, opts = opts, box = box }
      return box, provider
    end
    ns.UI.Parchment = function(_, texture)
      if parchment then texture:SetAtlas("QuestBG-Parchment") end
      return parchment
    end
  end

  -- lists[1] is the chapter column, lists[2] the page.
  local function rows(i)
    return lists[i].box.provider.items
  end

  local function texts(i)
    local out = {}
    for _, row in ipairs(rows(i)) do out[#out + 1] = row.text end
    return out
  end

  local function tab()
    return lists[1].parent:GetParent()
  end

  local function show()
    ns.UI.MainFrame:Show("chronicle")
    return tab()
  end

  local function button(i, row)
    local b = CreateFrame("Button")
    b.LockHighlight = function(self) self.locked = true end
    b.UnlockHighlight = function(self) self.locked = false end
    lists[i].opts.init(b, row)
    return b
  end

  before_each(function()
    wow.reset()
    ns = wow.load(FILES)
    parchment = true
    fakeWidgets()
    wow.stub("ScrollBoxConstants", { RetainScrollPosition = true, DiscardScrollPosition = false })
    wow.login()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("registers as the first tab of the main window", function()
    show()
    local frame = _G.AshmarkFrame
    assert.equal(ns.L.CORE_TAB_CHRONICLE, frame.Tabs[1]:GetText())
    assert.equal(1, frame.selectedTab)
    assert.same({ 20, 34 }, { lists[1].opts.extent, lists[2].opts.extent })
  end)

  it("lists the chapters newest first and opens on the current one", function()
    ns.Log:Add("level", { l = 2 })
    ns.Log:CloseChapter({})
    ns.Log:Add("level", { l = 3 })
    local t = show()
    assert.same({ "Chapter II (current)", "Chapter I" }, texts(1))
    assert.same({ true, false }, { rows(1)[1].current, rows(1)[2].current })
    assert.same({ "You reached level 3." }, texts(2))
    assert.equal("Chapter II", t.Heading:GetText())
    assert.is_false(t.Empty:IsShown())
  end)

  it("turns to a chapter on click, with the page-turn sound, and keeps it while the log grows", function()
    ns.Log:Add("level", { l = 2 })
    ns.Log:CloseChapter({})
    ns.Log:Add("level", { l = 3 })
    show()
    local first = button(1, rows(1)[2])
    assert.equal("Chapter I", first:GetText())
    assert.is_false(first.locked)
    wow.sounds = {}
    wow.script(first, "OnClick")
    assert.same({ SOUNDKIT.IG_ABILITY_PAGE_TURN }, wow.sounds)
    assert.same({ "You reached level 2.", "Chapter I closes in an unknown place." }, texts(2))
    assert.is_false(lists[2].box.retain)
    assert.is_true(button(1, rows(1)[2]).locked)

    ns.Log:Add("level", { l = 4 })
    wow.advance(0.5)
    assert.equal("Chapter I", tab().Heading:GetText())
    assert.is_true(lists[2].box.retain)
    wow.script(first, "OnClick")
    assert.equal(1, #wow.sounds)
  end)

  it("turns the page and plays the sound together once combat ends", function()
    ns.Log:Add("level", { l = 2 })
    ns.Log:CloseChapter({})
    ns.Log:Add("level", { l = 3 })
    local t = show()
    local first = button(1, rows(1)[2])
    wow.sounds = {}
    wow.combat(true)
    wow.script(first, "OnClick")
    wow.script(first, "OnClick")
    assert.same({}, wow.sounds)
    assert.equal("Chapter II", t.Heading:GetText())
    wow.combat(false)
    assert.equal("Chapter I", t.Heading:GetText())
    assert.same({ SOUNDKIT.IG_ABILITY_PAGE_TURN }, wow.sounds)

    wow.combat(true)
    wow.script(button(1, rows(1)[1]), "OnClick")
    wow.script(first, "OnClick")
    wow.combat(false)
    assert.equal("Chapter I", t.Heading:GetText())
    assert.equal(1, #wow.sounds)
  end)

  it("redraws for entries it shows and for the one that begins the open chapter, not for the rest", function()
    local t = show()
    local box = lists[2].box
    local fills = 0
    local set = box.SetDataProvider
    box.SetDataProvider = function(self, ...)
      fills = fills + 1
      return set(self, ...)
    end
    ns.Log:Add("quest.accept", { q = 1 })
    wow.advance(0.5)
    assert.equal(1, fills)
    assert.matches("^Begun ", t.Subtitle:GetText())
    ns.Log:Add("gold", { src = "loot", c = 5 })
    ns.Log:Add("quest.accept", { q = 2 })
    ns.Log:Add("zone", { z = 1443 })
    wow.advance(0.5)
    assert.equal(1, fills)
    ns.Log:Add("level", { l = 5 })
    wow.advance(0.5)
    assert.equal(2, fills)
    assert.same({ "You reached level 5." }, texts(2))
  end)

  it("redraws nothing when the profile or the house changes, which no line reads", function()
    show()
    local box = lists[2].box
    local fills = 0
    local set = box.SetDataProvider
    box.SetDataProvider = function(self, ...)
      fills = fills + 1
      return set(self, ...)
    end
    ns.Bus:Fire("PROFILE_CHANGED")
    ns.Bus:Fire("HOUSE_CHANGED")
    wow.advance(1)
    assert.equal(0, fills)
    ns.Bus:Fire("LOG_COMPACTED", ns.DB:Char())
    wow.advance(1)
    assert.equal(1, fills)
  end)

  it("plays no page-turn sound with Core.sounds off", function()
    ns.Log:Add("level", { l = 2 })
    ns.Log:CloseChapter({})
    show()
    ns.Settings:Set("Core.sounds", false)
    wow.sounds = {}
    wow.script(button(1, rows(1)[2]), "OnClick")
    assert.same({}, wow.sounds)
    assert.equal("Chapter I", tab().Heading:GetText())
  end)

  it("follows the open chapter until the reader picks one", function()
    ns.Log:Add("level", { l = 2 })
    local t = show()
    ns.Log:CloseChapter({})
    wow.advance(0.5)
    assert.equal("Chapter II", t.Heading:GetText())
    assert.equal(ns.L.CORE_CHRONICLE_OPEN, t.Subtitle:GetText())
    assert.same({}, texts(2))
  end)

  it("dates a closed chapter with its place and an open one with its first entry", function()
    wow.state.map = 9002
    ns.Log:Add("level", { l = 2 })
    local closed = ns.Log:CloseChapter({})
    local t = show()
    assert.equal(ns.L.CORE_CHRONICLE_OPEN, t.Subtitle:GetText())
    wow.script(button(1, rows(1)[2]), "OnClick")
    assert.equal("Closed " .. os.date("%Y-%m-%d", closed.closed) .. " · Desolace", t.Subtitle:GetText())

    local opened = ns.Log:Add("level", { l = 3 })
    wow.stub("FormatShortDate", function(d, m, y) return table.concat({ d, m, y }, ".") end)
    wow.script(button(1, rows(1)[1]), "OnClick")
    local d = os.date("*t", opened.t)
    assert.equal("Begun " .. table.concat({ d.day, d.month, d.year % 100 }, ".") .. " · still being written",
                 t.Subtitle:GetText())
  end)

  it("says so when a chapter has nothing worth telling", function()
    ns.Log:Add("quest.accept", { q = 1 })
    local t = show()
    assert.same({}, texts(2))
    assert.is_true(t.Empty:IsShown())
    assert.equal(ns.L.CORE_CHRONICLE_EMPTY, t.Empty:GetText())
  end)

  it("says so when there is no record for the character", function()
    ns.playerGUID = nil
    local t = show()
    assert.same({}, texts(1))
    assert.same({}, texts(2))
    assert.equal("", t.Heading:GetText())
    assert.equal(ns.L.CORE_CHRONICLE_NO_RECORD, t.Empty:GetText())
  end)

  it("falls back to the selected open chapter after the record is wiped", function()
    ns.Log:Add("level", { l = 2 })
    ns.Log:CloseChapter({})
    ns.Log:Add("level", { l = 3 })
    show()
    wow.script(button(1, rows(1)[2]), "OnClick")
    _G.AshmarkDB.chars[ns.playerGUID].chapters = {}
    ns.UI.MainFrame:Refresh("chronicle")
    assert.same({ "Chapter I (current)" }, texts(1))
  end)

  it("draws the page on the client's parchment with the quest fonts", function()
    local t = show()
    assert.equal("QuestBG-Parchment", t.Parchment:GetAtlas())
    assert.is_true(t.Parchment:IsShown())
    assert.equal("QuestTitleFont", t.Heading.__template)
    assert.equal("QuestFont", t.Subtitle.__template)
    assert.is_nil(t.Heading.__color)
    local line = button(2, { text = "You reached level 3." })
    assert.equal("QuestFont", line.text.__template)
    assert.is_nil(line.text.__color)
  end)

  it("leaves the Inset background and uses light text when the client lacks the parchment", function()
    parchment = false
    local t = show()
    assert.is_false(t.Parchment:IsShown())
    assert.is_true(_G.AshmarkFrame.Inset.Bg:IsShown())
    assert.same({ NORMAL_FONT_COLOR:GetRGB() }, { t.Heading:GetTextColor() })
    assert.same({ HIGHLIGHT_FONT_COLOR:GetRGB() }, { t.Subtitle:GetTextColor() })
    local line = button(2, { text = "You reached level 3." })
    assert.same({ HIGHLIGHT_FONT_COLOR:GetRGB() }, { line.text:GetTextColor() })
  end)

  it("initialises a recycled row once and shows a cut-off sentence in the tooltip", function()
    show()
    local line = button(2, { text = "Short." })
    local text = line.text
    lists[2].opts.init(line, { text = "A sentence too long for two lines." })
    assert.equal(text, line.text)
    assert.equal("A sentence too long for two lines.", text:GetText())
    wow.script(line, "OnEnter")
    assert.is_false(GameTooltip:IsShown())
    text.IsTruncated = function() return true end
    wow.script(line, "OnEnter")
    assert.is_true(GameTooltip:IsShown())
    assert.equal("A sentence too long for two lines.", _G.GameTooltipTextLeft1:GetText())
    wow.script(line, "OnLeave")
    assert.is_false(GameTooltip:IsShown())
  end)

  it("refreshes with the log while visible", function()
    show()
    ns.Log:Add("level", { l = 5 })
    assert.same({}, texts(2))
    wow.advance(0.5)
    assert.same({ "You reached level 5." }, texts(2))
  end)
end)

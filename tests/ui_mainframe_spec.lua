local wow = require("tests.helpers.wow")

local FILES = { "UI/Widgets.lua", "UI/MainFrame.lua" }
local TOPICS = { "LOG_ADDED", "LOG_COMPACTED", "NAMES_UPDATED", "CONTACT_UPDATED", "HOUSE_CHANGED", "PROFILE_CHANGED" }

describe("UI MainFrame", function()
  local ns, main, trace, built

  -- A tab that records its build and refresh calls.
  local function tab(id, order, module)
    main:AddTab(id, {
      label = "TAB_" .. id:upper(),
      order = order,
      module = module,
      build = function(parent)
        trace[#trace + 1] = id .. ":build"
        local t = { parent = parent }
        function t.Refresh() trace[#trace + 1] = id .. ":refresh" end
        built[id] = t
        return t
      end,
    })
  end

  before_each(function()
    wow.reset()
    ns = wow.load(FILES)
    main = ns.UI.MainFrame
    trace, built = {}, {}
  end)

  it("creates AshmarkFrame from ButtonFrameTemplate on the first Show", function()
    wow.login()
    assert.is_nil(_G.AshmarkFrame)
    main:Show()
    local frame = _G.AshmarkFrame
    assert.equal("ButtonFrameTemplate", frame.__template)
    assert.same({ 640, 500 }, { frame:GetSize() })
    assert.is_true(frame:IsShown())
    assert.is_true(tContains(UISpecialFrames, "AshmarkFrame"))
  end)

  it("names the installed version, in grey, after the title", function()
    wow.login()
    main:Show()
    assert.equal("Ashmark " .. GRAY_FONT_COLOR:WrapTextInColorCode("1.0.0-test"),
                 _G.AshmarkFrame.TitleContainer.TitleText:GetText())
  end)

  it("orders the tabs, maps ids to indices and builds a tab once, when it is first shown", function()
    tab("b", 20)
    tab("a", 10)
    tab("c", 30)
    wow.login()
    main:Show()
    local frame = _G.AshmarkFrame
    assert.equal(3, frame.numTabs)
    assert.same({ "TAB_A", "TAB_B", "TAB_C" }, { frame.Tabs[1]:GetText(), frame.Tabs[2]:GetText(),
                                                 frame.Tabs[3]:GetText() })
    assert.same({ 1, 2, 3 }, { frame.Tabs[1]:GetID(), frame.Tabs[2]:GetID(), frame.Tabs[3]:GetID() })
    assert.equal("PanelTabButtonTemplate", frame.Tabs[1].__template)
    assert.equal(1, frame.selectedTab)
    assert.same({ "a:build", "a:refresh" }, trace)

    main:Show("c")
    assert.equal(3, frame.selectedTab)
    assert.is_false(built.a.parent:IsShown())
    assert.is_true(built.c.parent:IsShown())
    main:Show("a")
    assert.same({ "a:build", "a:refresh", "c:build", "c:refresh", "a:refresh" }, trace)
    assert.equal(frame.Inset, built.a.parent:GetParent())
  end)

  it("selects a tab when its button is clicked", function()
    tab("a", 10)
    tab("b", 20)
    wow.login()
    main:Show()
    wow.script(_G.AshmarkFrame.Tabs[2], "OnClick")
    assert.equal(2, _G.AshmarkFrame.selectedTab)
    assert.equal("b:refresh", trace[#trace])
  end)

  it("gives a tab added after the window exists its button", function()
    tab("a", 10)
    wow.login()
    main:Show()
    tab("z", 5)
    local frame = _G.AshmarkFrame
    assert.equal(2, frame.numTabs)
    assert.equal("TAB_Z", frame.Tabs[1]:GetText())
    assert.equal(2, frame.selectedTab)
  end)

  it("refuses a tab id twice", function()
    tab("a", 10)
    assert.has_error(function() tab("a", 20) end)
  end)

  it("hides the tabs of disabled modules and leaves a tab whose module goes away", function()
    local M = ns:NewModule("Fake", { locale = "FAKE" })
    tab("a", 10)
    tab("fake", 20, "Fake")
    tab("z", 30)
    wow.login()
    main:Show("fake")
    local frame = _G.AshmarkFrame
    assert.equal(2, frame.selectedTab)

    ns.Settings:Set("Fake.enabled", false)
    assert.is_false(M.enabled)
    wow.advance(0.5)
    assert.is_false(frame.Tabs[2]:IsShown())
    assert.equal(frame.Tabs[1], select(2, frame.Tabs[3]:GetPoint(1)))
    assert.equal(1, frame.selectedTab)
    assert.is_false(built.fake.parent:IsShown())
    main:Show("fake")
    assert.equal(1, frame.selectedTab)

    ns.Settings:Set("Fake.enabled", true)
    wow.advance(0.5)
    assert.is_true(frame.Tabs[2]:IsShown())
    assert.equal(frame.Tabs[2], select(2, frame.Tabs[3]:GetPoint(1)))
  end)

  it("hides the tab of a module that is unavailable from the start", function()
    ns:NewModule("Needy", { locale = "NEEDY", requires = { "nothingLikeThis" } })
    tab("a", 10)
    tab("needy", 20, "Needy")
    wow.login()
    main:Show("needy")
    assert.is_false(_G.AshmarkFrame.Tabs[2]:IsShown())
    assert.equal(1, _G.AshmarkFrame.selectedTab)
    assert.is_nil(built.needy)
  end)

  it("refreshes the visible tab at most every 0.5 s on each listed topic", function()
    tab("a", 10)
    tab("b", 20)
    wow.login()
    main:Show("b")
    main:Show("a")
    for _, topic in ipairs(TOPICS) do
      trace = {}
      ns.Bus:Fire(topic)
      ns.Bus:Fire(topic)
      assert.same({}, trace)
      wow.advance(0.5)
      assert.same({ "a:refresh" }, trace, topic)
    end
  end)

  it("does not refresh a closed window", function()
    tab("a", 10)
    wow.login()
    main:Show()
    _G.AshmarkFrame:Hide()
    trace = {}
    ns.Log:Add("death", {})
    wow.advance(1)
    assert.same({}, trace)
  end)

  it("refreshes a tab on Refresh(id) only while it is the visible one", function()
    tab("a", 10)
    tab("b", 20)
    wow.login()
    main:Show("a")
    trace = {}
    main:Refresh("b")
    assert.same({}, trace)
    main:Refresh("a")
    main:Refresh()
    assert.same({ "a:refresh", "a:refresh" }, trace)
    _G.AshmarkFrame:Hide()
    main:Refresh("a")
    assert.same({ "a:refresh", "a:refresh" }, trace)
  end)

  it("toggles the window", function()
    tab("a", 10)
    wow.login()
    main:Toggle()
    assert.is_true(_G.AshmarkFrame:IsShown())
    main:Toggle()
    assert.is_false(_G.AshmarkFrame:IsShown())
  end)

  it("shows, hides and refreshes only out of combat", function()
    tab("a", 10)
    wow.login()
    wow.combat(true)
    main:Show()
    assert.is_nil(_G.AshmarkFrame)
    wow.combat(false)
    assert.is_true(_G.AshmarkFrame:IsShown())

    wow.combat(true)
    main:Toggle()
    assert.is_true(_G.AshmarkFrame:IsShown())
    wow.combat(false)
    assert.is_false(_G.AshmarkFrame:IsShown())

    main:Show()
    trace = {}
    wow.combat(true)
    ns.Log:Add("death", {})
    wow.advance(0.5)
    main:Refresh("a")
    assert.same({}, trace)
    wow.combat(false)
    assert.same({ "a:refresh", "a:refresh" }, trace)
  end)

  it("plays the quest log sounds on open and close if Core.sounds is on", function()
    wow.login()
    main:Show()
    main:Toggle()
    assert.same({ SOUNDKIT.IG_QUEST_LOG_OPEN, SOUNDKIT.IG_QUEST_LOG_CLOSE }, wow.sounds)
    ns.Settings:Set("Core.sounds", false)
    main:Show()
    assert.equal(2, #wow.sounds)
  end)

  it("plays nothing when the client lacks a sound constant", function()
    wow.stub("SOUNDKIT.IG_QUEST_LOG_OPEN", nil)
    wow.login()
    assert.has_no.errors(function() main:Show() end)
    assert.same({}, wow.sounds)
    assert.same({}, wow.errors)
  end)

  it("shows the player's portrait on show and on UNIT_PORTRAIT_UPDATE for the player", function()
    wow.login()
    main:Show()
    local frame, units = _G.AshmarkFrame, {}
    frame.SetPortraitToUnit = function(_, unit) units[#units + 1] = unit end
    wow.fire("UNIT_PORTRAIT_UPDATE", "player")
    wow.fire("UNIT_PORTRAIT_UPDATE", "target")
    assert.same({ "player" }, units)
    frame:Hide()
    wow.fire("UNIT_PORTRAIT_UPDATE", "player")
    assert.same({ "player" }, units)
    frame:Show()
    assert.same({ "player", "player" }, units)
  end)

  it("moves by its title bar, but never starts moving in combat", function()
    wow.login()
    main:Show()
    local frame, moves, stops = _G.AshmarkFrame, 0, 0
    frame.StartMoving = function() moves = moves + 1 end
    frame.StopMovingOrSizing = function() stops = stops + 1 end
    wow.script(frame.TitleContainer, "OnDragStart")
    wow.script(frame.TitleContainer, "OnDragStop")
    wow.combat(true)
    wow.script(frame.TitleContainer, "OnDragStart")
    wow.script(frame.TitleContainer, "OnDragStop")
    assert.same({ 1, 2 }, { moves, stops })
  end)

  it("reports a failing build against the tab's module and keeps the window working", function()
    ns:NewModule("Fake", { locale = "FAKE" })
    main:AddTab("bad", { label = "TAB_BAD", order = 10, module = "Fake", build = function() error("boom") end })
    tab("a", 20)
    wow.login()
    assert.has_no.errors(function() main:Show("bad") end)
    assert.is_true(_G.AshmarkFrame:IsShown())
    assert.equal(1, #wow.errors)
    assert.truthy(wow.errors[1]:find("Fake (tab:bad:build)", 1, true))
    main:Show("a")
    assert.same({ "a:build", "a:refresh" }, trace)
  end)

  it("disables a module whose tab keeps failing and moves to another tab", function()
    local M = ns:NewModule("Fake", { locale = "FAKE" })
    local function fails() error("boom") end
    main:AddTab("bad", { label = "TAB_BAD", order = 10, module = "Fake",
                         build = function() return { Refresh = fails } end })
    tab("a", 20)
    wow.login()
    main:Show("bad")
    for _ = 2, 10 do main:Refresh("bad") end
    assert.is_false(M.enabled)
    assert.same({ "error" }, M.unavailable)
    assert.equal(1, #wow.errors)
    main:Show("bad")
    assert.is_false(_G.AshmarkFrame.Tabs[1]:IsShown())
    assert.equal(2, _G.AshmarkFrame.selectedTab)
  end)
end)

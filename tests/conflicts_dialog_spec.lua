local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.conflicts_mock")

local SISTER = "Player-1-00000009"
local COUSIN = "Player-1-0000000a"

describe("Conflicts quest-dialog line", function()
  local ns

  local function boot(setup)
    ns = mock.boot(wow, { setup = setup })
    return ns.DB:Char()
  end

  local function strip()
    for _, child in ipairs(QuestFrameDetailPanel.__children) do
      if child.__template == "TooltipBackdropTemplate" then return child end
    end
  end

  local function detail(q)
    wow.state.questDetail = q
    wow.fire("QUEST_DETAIL")
    return strip()
  end

  local function shown()
    local s = strip()
    return s ~= nil and s:IsShown()
  end

  local function check(id)
    for _, c in ipairs(ns.Test.checks) do
      if c.id == id then return c.fn() end
    end
  end

  before_each(function()
    wow.reset()
    mock.titles(wow)
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("is one Ashmark strip under the dialog, as wide as it, and touches no Blizzard region", function()
    boot()
    mock.accept(wow, 1001)
    local s = detail(2001)
    assert.equal(QuestFrameDetailPanel, s:GetParent())
    assert.same({ "TOPLEFT", QuestFrame, "BOTTOMLEFT" }, { s:GetPoint(1) })
    assert.same({ "TOPRIGHT", QuestFrame, "BOTTOMRIGHT" }, { s:GetPoint(2) })
    assert.equal(2, s:GetNumPoints())
    assert.equal("FontString", s.Text:GetObjectType())
    assert.equal("GameFontNormal", s.Text.__template)
    assert.equal(1, #QuestFrameDetailPanel.__children)
    detail(2002)
    assert.equal(1, #QuestFrameDetailPanel.__children)
    for _, frame in ipairs({ QuestFrame, QuestFrameDetailPanel }) do
      assert.equal(0, frame:GetNumPoints())
      assert.same({}, frame.__scripts)
    end
    assert.equal(1, #QuestFrame.__hooks.OnHide)
  end)

  it("marks a quest that contradicts the alliance, in red", function()
    boot()
    mock.accept(wow, 1001)
    local s = detail(2001)
    assert.is_true(s:IsShown())
    assert.equal("Contradicts your alliance with Gelkis Clan Centaur.", s.Text:GetText())
    assert.same({ RED_FONT_COLOR:GetRGB() }, { s.Text:GetTextColor() })
  end)

  it("says nothing for the allied side, an open conflict or a quest of no conflict", function()
    boot()
    assert.is_nil(detail(2001))
    mock.accept(wow, 1001)
    detail(2001)
    detail(1002)
    assert.is_false(shown())
    detail(2001)
    detail(9999)
    assert.is_false(shown())
    detail(3001)
    assert.is_false(shown())
  end)

  it("names no faction when the allied side has none", function()
    boot()
    mock.turnIn(wow, 6001)
    assert.equal("Contradicts the side you have taken.", detail(5001).Text:GetText())
  end)

  it("hints that the house stands against a quest while the character has not chosen", function()
    boot()
    mock.house(ns, "Ashvale", { clan_choice = { B = { SISTER } }, coast_raid = { A = { SISTER }, B = { COUSIN } } })
    local s = detail(1001)
    assert.is_true(s:IsShown())
    assert.equal("Your house, Ashvale, stands against Gelkis Clan Centaur.", s.Text:GetText())
    assert.same({ NORMAL_FONT_COLOR:GetRGB() }, { s.Text:GetTextColor() })
    detail(2001)
    assert.is_false(shown())
    -- Siblings on both sides: no hint.
    detail(3001)
    assert.is_false(shown())
    -- Once the character has chosen, only the contradiction rule speaks.
    mock.accept(wow, 1001)
    detail(1002)
    assert.is_false(shown())
    assert.equal("Contradicts your alliance with Gelkis Clan Centaur.", detail(2002).Text:GetText())
  end)

  it("gives no hint without a house key", function()
    boot()
    mock.house(ns, nil, { clan_choice = { B = { SISTER } } })
    detail(1001)
    assert.is_false(shown())
  end)

  it("hides on the other quest pages, at the end of the dialog and when the dialog closes", function()
    boot()
    mock.accept(wow, 1001)
    for _, event in ipairs({ "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
      detail(2001)
      assert.is_true(shown(), event)
      wow.fire(event)
      assert.is_false(shown(), event)
    end
    QuestFrame:Show()
    detail(2001)
    QuestFrame:Hide()
    assert.is_false(shown())
  end)

  it("shows at once in combat", function()
    boot()
    mock.accept(wow, 1001)
    wow.combat(true)
    assert.is_true(detail(2001):IsShown())
    wow.fire("QUEST_FINISHED")
    assert.is_false(shown())
  end)

  it("hides for a secret quest ID without touching it", function()
    boot()
    mock.accept(wow, 1001)
    detail(2001)
    detail(wow.secret(2001))
    assert.is_false(shown())
  end)

  it("stops with the module and keeps its hook quiet", function()
    boot()
    mock.accept(wow, 1001)
    QuestFrame:Show()
    detail(2001)
    ns.Settings:Set("Conflicts.enabled", false)
    assert.is_false(shown())
    detail(2001)
    assert.is_false(shown())
    QuestFrame:Hide()
    assert.equal(0, wow.registered("QUEST_DETAIL"))
  end)

  it("leaves the line out without QuestFrame and keeps the rules", function()
    local char = boot(function() wow.stub("QuestFrameDetailPanel", nil) end)
    assert.is_false(ns.Compat.Has.questFrame)
    assert.equal(0, wow.registered("QUEST_DETAIL"))
    mock.accept(wow, 1001)
    assert.equal("A", ns.Conflicts:Alliance(char, "clan_choice"))
    assert.same({ false, "QuestFrame or QuestFrameDetailPanel is missing" }, { check("Conflicts.questDialog") })
  end)

  describe("test check", function()
    it("waits for an open quest dialog, then shows a sample line for the screenshot", function()
      boot()
      assert.same({ nil, "talk to a quest giver first" }, { check("Conflicts.questDialog") })
      QuestFrame:Show()
      assert.same({ true, "shown under the quest details" }, { check("Conflicts.questDialog") })
      local s = strip()
      assert.is_true(s:IsShown())
      assert.equal(ns.L.CONFLICT_TEST_DIALOG, s.Text:GetText())
      wow.fire("QUEST_FINISHED")
      assert.is_false(s:IsShown())
    end)

    it("leaves a real line in place and reports a hidden details page", function()
      boot()
      mock.accept(wow, 1001)
      QuestFrame:Show()
      detail(2001)
      QuestFrameDetailPanel:Hide()
      assert.same({ true, "shown; it is visible on a quest's details page" }, { check("Conflicts.questDialog") })
      assert.equal("Contradicts your alliance with Gelkis Clan Centaur.", strip().Text:GetText())
    end)

    it("skips while the module is off", function()
      boot()
      ns.Settings:Set("Conflicts.enabled", false)
      QuestFrame:Show()
      assert.same({ nil, "Conflicts is off" }, { check("Conflicts.questDialog") })
      assert.is_nil(strip())
    end)
  end)
end)

local wow = require("tests.helpers.wow")

describe("Core Compat", function()
  local ns
  before_each(function()
    wow.reset()
    ns = wow.load()
  end)

  it("finds every capability in the mock client", function()
    ns.Compat.Refresh(true)
    for _, cap in ipairs(ns.Compat.KEYS) do
      assert.is_true(ns.Compat.Has[cap], cap)
    end
  end)

  it("reads the build and the TOC variant", function()
    assert.same({ version = "1.60.1", build = "70532", date = "Oct 20 2026", interface = 16001 }, ns.Compat.build)
    assert.equal("Forever", ns.Compat.tocVariant)
  end)

  it("sets a capability false when its API is missing", function()
    wow.stub("C_QuestLog.RequestLoadQuestByID", nil)
    wow.stub("QuestFrameDetailPanel", nil)
    wow.stub("WorldMapFrame.AddDataProvider", nil)
    wow.stub("TooltipDataProcessor", nil)
    wow.stub("Settings.CreateCheckbox", nil)
    ns.Compat.Refresh(true)
    for _, cap in ipairs({ "questLog", "questFrame", "mapPins", "tooltipProcessor", "settingsApi" }) do
      assert.is_false(ns.Compat.Has[cap], cap)
    end
    assert.is_true(ns.Compat.Has.reputation)
  end)

  it("isolates a failing detector", function()
    wow.stub("C_CreatureInfo.GetCreatureTypeInfo", function() error("boom") end)
    wow.stub("IsTrialAccount", function() error("boom") end)
    ns.Compat.Refresh(true)
    assert.is_false(ns.Compat.Has.critterType)
    assert.is_false(ns.Compat.Has.canSend)
    assert.is_true(ns.Compat.Has.addonMessages)
  end)

  it("cannot send on trial and veteran accounts", function()
    wow.state.veteran = true
    assert.is_false(ns.Compat.Check("canSend"))
    wow.state.veteran = false
    assert.is_true(ns.Compat.Check("canSend"))
  end)

  it("checks legacy only from PLAYER_LOGIN and rechecks it on UPDATE_FACTION", function()
    ns.Compat.Refresh(false)
    assert.is_false(ns.Compat.Has.legacy)
    wow.data.majorFactions[2802] = nil
    wow.login()
    assert.is_false(ns.Compat.Has.legacy)
    wow.data.factions[2802] = { factionID = 2802, name = "Legacy", reaction = 4, currentStanding = 0 }
    wow.fire("UPDATE_FACTION")
    wow.advance(1)
    assert.is_true(ns.Compat.Has.legacy)
  end)

  it("knows encounters by event validity, and assumes them without the check", function()
    wow.invalidEvents.ENCOUNTER_END = true
    assert.is_false(ns.Compat.Check("encounters"))
    wow.stub("C_EventUtils", nil)
    assert.is_true(ns.Compat.Check("encounters"))
    assert.is_false(ns.Compat.Check("eventCheck"))
  end)

  it("keeps a demoted capability off for the session", function()
    ns.Compat.Disable("canSend", "why")
    assert.is_false(ns.Compat.Has.canSend)
    assert.is_false(ns.Compat.Check("canSend"))
    assert.equal("why", ns.Compat.disabled.canSend)
    assert.is_false(ns.Compat.Check("unknownCapability"))
  end)
end)

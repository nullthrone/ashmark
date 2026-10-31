local wow = require("tests.helpers.wow")

describe("UI Compartment", function()
  local ns, menuButton

  before_each(function()
    wow.reset()
    ns = wow.load({ "UI/MainFrame.lua", "UI/Compartment.lua" })
    menuButton = CreateFrame("Button")
  end)

  it("defines the three functions the TOC names", function()
    assert.is_function(_G.Ashmark_OnAddonCompartmentClick)
    assert.is_function(_G.Ashmark_OnAddonCompartmentEnter)
    assert.is_function(_G.Ashmark_OnAddonCompartmentLeave)
  end)

  it("toggles the main window on a click, with either argument form", function()
    wow.login()
    _G.Ashmark_OnAddonCompartmentClick("Ashmark", "LeftButton")
    assert.is_true(_G.AshmarkFrame:IsShown())
    _G.Ashmark_OnAddonCompartmentClick("Ashmark", { buttonName = "LeftButton" })
    assert.is_false(_G.AshmarkFrame:IsShown())
  end)

  it("opens the settings category on a right-click", function()
    wow.login()
    _G.Ashmark_OnAddonCompartmentClick("Ashmark", { buttonName = "RightButton" })
    assert.equal(ns.Settings.category:GetID(), wow.panel.opened)
    assert.is_nil(_G.AshmarkFrame)
    wow.panel.opened = nil
    _G.Ashmark_OnAddonCompartmentClick("Ashmark", "RightButton")
    assert.equal(ns.Settings.category:GetID(), wow.panel.opened)
  end)

  it("shows a tooltip on its own menu button and hides only that one", function()
    wow.login()
    _G.Ashmark_OnAddonCompartmentEnter("Ashmark", menuButton)
    assert.is_true(GameTooltip:IsShown())
    assert.equal(menuButton, GameTooltip:GetOwner())
    assert.same({ "Ashmark", ns.L.CORE_COMPARTMENT_CLICK, ns.L.CORE_COMPARTMENT_RIGHT_CLICK },
                { _G.GameTooltipTextLeft1:GetText(), _G.GameTooltipTextLeft2:GetText(),
                  _G.GameTooltipTextLeft3:GetText() })
    _G.Ashmark_OnAddonCompartmentLeave("Ashmark", CreateFrame("Button"))
    assert.is_true(GameTooltip:IsShown())
    _G.Ashmark_OnAddonCompartmentLeave("Ashmark", menuButton)
    assert.is_false(GameTooltip:IsShown())
  end)

  it("only says that Ashmark is off on other clients", function()
    wow.data.build[4] = 110000
    wow.stub("WOW_PROJECT_ID", 1)
    wow.login()
    wow.chat = {}
    _G.Ashmark_OnAddonCompartmentClick("Ashmark", "LeftButton")
    assert.is_nil(_G.AshmarkFrame)
    assert.equal(1, #wow.chat)
    assert.truthy(wow.chat[1]:find(ns.L.CORE_NOT_FOREVER, 1, true))
  end)
end)

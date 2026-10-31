local wow = require("tests.helpers.wow")

describe("Core Settings", function()
  local ns, changes

  local function boot(setup)
    ns = wow.load()
    if setup then setup() end
    wow.login()
    changes = {}
    ns.Core:Subscribe("SETTINGS_CHANGED", function(_, _, key, value) changes[#changes + 1] = { key, value } end)
  end

  before_each(function()
    wow.reset()
  end)

  it("registers Core's settings with their defaults", function()
    boot()
    assert.is_true(ns.Settings:Get("Core.chatLines"))
    assert.is_true(ns.Settings:Get("Core.sounds"))
    assert.is_true(ns.Settings:Get("Comm.share"))
    assert.is_nil(ns.Settings:Get("Nope.nothing"))
  end)

  it("stores values in AshmarkDB.settings and fires SETTINGS_CHANGED once", function()
    boot()
    assert.is_true(ns.Settings:Set("Core.sounds", false))
    assert.is_false(ns.Settings:Get("Core.sounds"))
    assert.is_false(_G.AshmarkDB.settings["Core.sounds"])
    assert.same({ { "Core.sounds", false } }, changes)
    assert.is_false(wow.panel.settings["Ashmark_Core.sounds"]:GetValue())
  end)

  it("refuses unknown keys and values of the wrong type", function()
    boot()
    assert.is_false(ns.Settings:Set("Nope.nothing", true))
    assert.is_false(ns.Settings:Set("Core.sounds", "no"))
    assert.same({}, changes)
  end)

  it("falls back to the default for a stored value of the wrong type", function()
    wow.saved({ schema = 1, created = 1, settings = { ["Core.sounds"] = "x" } })
    boot()
    assert.is_true(ns.Settings:Get("Core.sounds"))
  end)

  it("builds the panel with one checkbox per setting and follows panel changes", function()
    boot(function()
      ns:NewModule("Alpha", { locale = "ALPHA", requires = { "nothing" } })
    end)
    local category = wow.panel.categories[1]
    assert.equal("Ashmark", category.name)
    assert.is_true(category.registered)
    local names = {}
    for _, box in ipairs(wow.panel.checkboxes) do names[#names + 1] = box.setting.key end
    assert.same({ "Core.chatLines", "Core.sounds", "Comm.share", "Alpha.enabled" }, names)
    local alpha = wow.panel.checkboxes[4]
    assert.equal("ALPHA_MODULE_DESC\nThis client lacks a feature it needs.", alpha.tooltip)
    assert.equal("Lines in chat", wow.panel.checkboxes[1].setting.name)
    assert.equal(_G.AshmarkDB.settings, alpha.setting.tbl)
    wow.panel.settings["Ashmark_Core.chatLines"]:SetValue(false)
    assert.same({ { "Core.chatLines", false } }, changes)
    assert.is_false(ns.Settings:Get("Core.chatLines"))
  end)

  it("names an unavailable module's reasons in the player's words", function()
    boot(function()
      ns:NewModule("Alpha", { locale = "ALPHA", requires = { "nothing", "nothing2" }, modules = { "Beta" } })
      ns:NewModule("Beta", { locale = "BETA", requires = { "nothing" } })
      ns.Locale:Base().BETA_MODULE_NAME = "Beta stories"
      ns.Locale:Base().ALPHA_MODULE_NAME = "Alpha tales"
    end)
    assert.same({ "nothing", "nothing2", "Beta" }, ns:GetModule("Alpha").unavailable)
    assert.equal("ALPHA_MODULE_DESC\nThis client lacks a feature it needs.\nNeeds Beta stories",
      wow.panel.checkboxes[4].tooltip)
  end)

  it("names a module stopped by errors or a newer record in the player's words", function()
    boot(function()
      ns.Locale:Base().ALPHA_MODULE_NAME = "Alpha tales"
      local M = ns:NewModule("Alpha", { locale = "ALPHA" })
      function M:OnEnable()
        for _ = 1, 10 do ns:Report(self, "x", "boom") end
      end
    end)
    assert.same({ "error" }, ns:GetModule("Alpha").unavailable)
    assert.equal("ALPHA_MODULE_DESC\nAlpha tales stopped after repeated errors and stays off until the next reload.",
      wow.panel.checkboxes[4].tooltip)
  end)

  it("nests a module under the first module it needs, greyed out while any of them is off", function()
    boot(function()
      ns:NewModule("Beta", { locale = "BETA" })
      ns:NewModule("Gamma", { locale = "GAMMA" })
      ns:NewModule("Alpha", { locale = "ALPHA", modules = { "Beta", "Gamma" } })
    end)
    local boxes = {}
    for _, box in ipairs(wow.panel.checkboxes) do boxes[box.setting.key] = box end
    local alpha = boxes["Alpha.enabled"]
    assert.equal(boxes["Beta.enabled"], alpha.parent)
    assert.is_nil(boxes["Beta.enabled"].parent)
    assert.is_true(alpha:EvaluateModifyPredicates())
    wow.panel.settings["Ashmark_Beta.enabled"]:SetValue(false)
    assert.is_false(alpha:EvaluateModifyPredicates())
    assert.is_false(ns:GetModule("Alpha").enabled)
    wow.panel.settings["Ashmark_Beta.enabled"]:SetValue(true)
    ns.Settings:Set("Gamma.enabled", false)
    assert.is_false(alpha:EvaluateModifyPredicates())
    ns.Settings:Set("Gamma.enabled", true)
    assert.is_true(alpha:EvaluateModifyPredicates())
    assert.is_true(ns:GetModule("Alpha").enabled)
  end)

  it("nests nothing where the Settings API has no parent initializers", function()
    local create = Settings.CreateCheckbox
    wow.stub("Settings.CreateCheckbox", function(...)
      local init = create(...)
      init.SetParentInitializer = nil
      return init
    end)
    boot(function()
      ns:NewModule("Beta", { locale = "BETA" })
      ns:NewModule("Alpha", { locale = "ALPHA", modules = { "Beta" } })
    end)
    assert.same({}, wow.errors)
    assert.equal(5, #wow.panel.checkboxes)
  end)

  it("names in the sharing setting every kind of value the protocol sends", function()
    boot()
    for _, word in ipairs({ "archetype", "origin", "fidelity", "habitat", "mercy", "ruleset", "version", "rumours" }) do
      assert.truthy(ns.L.CORE_SETTING_SHARE_DESC:find(word, 1, true), word)
    end
  end)

  it("names missing events in a module's tooltip", function()
    wow.invalidEvents.NOT_AN_EVENT = true
    boot(function()
      local M = ns:NewModule("Alpha", { locale = "ALPHA" })
      function M:OnEnable() self:RegisterEvent("NOT_AN_EVENT", function() end) end
    end)
    assert.equal("ALPHA_MODULE_DESC\nEvents this client lacks: NOT_AN_EVENT", wow.panel.checkboxes[4].tooltip)
  end)

  it("opens the category through Combat.Run", function()
    boot()
    wow.combat(true)
    ns.Settings:Open()
    assert.is_nil(wow.panel.opened)
    wow.combat(false)
    assert.equal(1, wow.panel.opened)
  end)

  it("builds no panel without the Settings API", function()
    boot(function() wow.stub("Settings", nil) end)
    assert.same({}, wow.panel.categories)
    assert.is_true(ns.Settings:Set("Core.sounds", false))
  end)
end)

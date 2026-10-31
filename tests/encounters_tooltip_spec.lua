local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.encounters_mock")

local ME, ALT = mock.ME, mock.ALT
local THALEN, MIRA, KEL, ORLA = mock.guid("thalen"), mock.guid("mira"), mock.guid("kel"), mock.guid("orla")
local DESOLACE = 1443

describe("Encounters tooltip", function()
  local ns, M

  -- Thalen met three times by this character, Orla once somewhere unknown, Mira only by the alt, Kel never.
  local function stored()
    local now = wow.state.epoch
    return {
      schema = 1,
      contacts = {
        [THALEN] = mock.contact(THALEN, { name = "Thalen", class = "PALADIN",
                                          byChar = { [ME] = mock.met(3, now - 600, { lastPlace = DESOLACE }) } }),
        [MIRA] = mock.contact(MIRA, { name = "Mira", byChar = { [ALT] = mock.met(1, now - 600) } }),
        [ORLA] = mock.contact(ORLA, { name = "Orla", byChar = { [ME] = mock.met(1, now - 600) } }),
      },
    }
  end

  local function boot(setup)
    wow.saved(stored())
    ns = mock.boot(wow, { setup = setup })
    M = ns.Encounters
    return ns
  end

  local function texts(tip)
    local out = {}
    for i = 1, tip:NumLines() do out[i] = _G[tip:GetName() .. "TextLeft" .. i]:GetText() end
    return out
  end

  local function hover(data, tip)
    tip = tip or GameTooltip
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:AddLine("Thalen")
    wow.tooltip(Enum.TooltipDataType.Unit, tip, data)
    return texts(tip)
  end

  local function check(id)
    for _, c in ipairs(ns.Test.checks) do
      if c.id == id then return c.fn() end
    end
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("adds the meeting line for a contact this character has met and resizes the tooltip", function()
    boot()
    GameTooltip:Hide()
    assert.same({ "Thalen", "Met: 3× · last Desolace" }, hover({ type = Enum.TooltipDataType.Unit, guid = THALEN }))
    assert.is_true(GameTooltip:IsShown())
  end)

  it("leaves out the place when none is known", function()
    boot()
    assert.same({ "Thalen", "Met: 1×" }, hover({ guid = ORLA }))
  end)

  it("adds the archetype Fiction knows", function()
    boot(function(n) mock.fiction(n, { [THALEN] = { guid = THALEN, archetype = "OATHKEEPER", origin = 0 } }) end)
    assert.same({ "Thalen", "Met: 3× · last Desolace", "Oathkeeper" }, hover({ guid = THALEN }))
  end)

  it("labels the archetype in the form for the contact's sex, and leaves out a key without a label", function()
    boot(function(n)
      n.Locale:Base().PROFILE_OATHKEEPER_F = "Oathkeeper (f)"
      mock.fiction(n, { [THALEN] = { guid = THALEN, archetype = "OATHKEEPER", origin = 0 },
                        [ORLA] = { guid = ORLA, archetype = "NOPE", origin = 0 } })
    end)
    assert.same({ "Thalen", "Met: 3× · last Desolace", "Oathkeeper" }, hover({ guid = THALEN }))
    M:Contact(THALEN).sex = 3
    assert.same({ "Thalen", "Met: 3× · last Desolace", "Oathkeeper (f)" }, hover({ guid = THALEN }))
    assert.same({ "Thalen", "Met: 1×" }, hover({ guid = ORLA }))
  end)

  it("adds nothing for strangers, for contacts met only by another character, or on other tooltips", function()
    boot()
    assert.same({ "Thalen" }, hover({ guid = KEL }))
    assert.same({ "Thalen" }, hover({ guid = MIRA }))
    assert.same({ "Thalen" }, hover({ guid = THALEN }, ItemRefTooltip))
    assert.same({ "Thalen" }, hover({ guid = 42 }))
  end)

  it("adds nothing to a forbidden tooltip", function()
    boot()
    wow.stub("GameTooltip.IsForbidden", function() return true end)
    assert.same({ "Thalen" }, hover({ guid = THALEN }))
  end)

  it("returns at once on secret data", function()
    boot()
    local before = wow.deepcopy(_G.AshmarkDB)
    assert.same({ "Thalen" }, hover(wow.secret({ guid = THALEN })))
    assert.same({ "Thalen" }, hover({ guid = wow.secret(THALEN) }))
    assert.same({ "Thalen" }, hover(wow.lock({ guid = THALEN })))
    GameTooltip:SetUnit("party1")
    wow.unit("party1", { guid = THALEN, name = "Thalen" })
    assert.same({ "Thalen" }, hover({ guid = wow.secret(THALEN) }))
    assert.same(before, wow.deepcopy(_G.AshmarkDB))
  end)

  it("falls back to the displayed unit when the data has no GUID", function()
    boot()
    wow.unit("party1", { guid = THALEN, name = "Thalen" })
    local tip = GameTooltip
    tip:SetUnit("party1")
    tip:AddLine("Thalen")
    wow.tooltip(Enum.TooltipDataType.Unit, tip, {})
    assert.same({ "Thalen", "Met: 3× · last Desolace" }, texts(tip))
    wow.unit("party1", { guid = wow.secret(THALEN), name = "Thalen" })
    tip:SetUnit("party1")
    tip:AddLine("Thalen")
    wow.tooltip(Enum.TooltipDataType.Unit, tip, {})
    assert.same({ "Thalen" }, texts(tip))
  end)

  it("writes nothing and requests nothing", function()
    boot()
    local before = wow.deepcopy(_G.AshmarkDB)
    hover({ guid = THALEN })
    hover({ guid = KEL })
    assert.same(before, wow.deepcopy(_G.AshmarkDB))
    assert.same({ quest = {}, item = {} }, wow.requests)
  end)

  it("is silent while the module is off and installs its post-call once", function()
    boot()
    assert.equal(1, #wow.postCalls[Enum.TooltipDataType.Unit])
    ns.Settings:Set("Encounters.enabled", false)
    assert.same({ "Thalen" }, hover({ guid = THALEN }))
    ns.Settings:Set("Encounters.enabled", true)
    assert.equal(1, #wow.postCalls[Enum.TooltipDataType.Unit])
    assert.same({ "Thalen", "Met: 3× · last Desolace" }, hover({ guid = THALEN }))
  end)

  it("needs the tooltip processor only for the line", function()
    boot(function() wow.stub("TooltipDataProcessor.AddTooltipPostCall", nil) end)
    assert.is_true(M.enabled)
    assert.is_false(ns.Compat.Has.tooltipProcessor)
    assert.is_nil(wow.postCalls[Enum.TooltipDataType.Unit])
    local ok, detail = check("Encounters.tooltip")
    assert.is_true(ok)
    assert.matches("post%-call not installed", detail)
  end)

  describe("test check", function()
    it("passes when secret input changes nothing and a known contact gets the line", function()
      boot()
      local ok, detail = check("Encounters.tooltip")
      assert.is_true(ok)
      assert.equal("secret table and secret guid change nothing; a known contact gets the line; post-call installed",
        detail)
      assert.is_false(AshmarkTestTooltip:IsShown())
      assert.is_false(GameTooltip:IsShown())
    end)

    it("skips the known contact without one and the whole check without secretwrap", function()
      wow.saved({ schema = 1 })
      ns = mock.boot(wow)
      local ok, detail = check("Encounters.tooltip")
      assert.is_true(ok)
      assert.equal("secret table and secret guid change nothing; post-call installed", detail)
      wow.stub("secretwrap", nil)
      assert.same({ nil, "no secretwrap" }, { check("Encounters.tooltip") })
    end)

    it("fails when the line goes through on secret input", function()
      boot()
      wow.stub("secretwrap", function(v) return v end)
      local ok, detail = check("Encounters.tooltip")
      assert.is_false(ok)
      assert.matches("changed or raised on secret table, guid", detail)
    end)
  end)
end)

local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.knowledge_mock")

local SPEAR, HAUBERK, STONE = mock.SPEAR, mock.HAUBERK, mock.STONE
local SHORTSWORD, DAGGER = mock.SHORTSWORD, mock.DAGGER
local UNKNOWN = "Your character has never held this."

local SPEAR_LINES = {
  "Gelkis Spear", "Binds when equipped", "Two-Hand", "21 - 32 Damage", "(8.3 damage per second)", "+4 Strength",
  "Item Level 22", "Requires Level 17", "Sell Price:",
}
local SPEAR_HIDDEN = {
  "Gelkis Spear", "Binds when equipped", "Two-Hand", "", "", "", "Item Level 22", "Requires Level 17", "Sell Price:",
  UNKNOWN,
}

describe("Knowledge tooltip", function()
  local ns

  -- The spear and the hauberk are revealed and never held; the hearthstone is in the backpack unless a spec
  -- filled it.
  local function boot(setup)
    mock.item(wow, SPEAR)
    mock.item(wow, HAUBERK)
    if not wow.data.bags[mock.BACKPACK] then mock.bag(wow, mock.BACKPACK, 16, STONE) end
    ns = mock.boot(wow, { setup = setup })
    return ns
  end

  local function hover(id, opts)
    return mock.hover(wow, id, opts)
  end

  -- The spear's tooltip as the game shows it: nothing blanked, nothing added.
  local function untouched(lines)
    assert.equal(lines or #SPEAR_LINES, GameTooltip:NumLines())
    assert.equal("21 - 32 Damage", _G.GameTooltipTextLeft4:GetText())
    assert.equal("Speed 3.20", _G.GameTooltipTextRight4:GetText())
    assert.equal("+4 Strength", _G.GameTooltipTextLeft6:GetText())
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("a revealed item this character has never held", function()
    it("keeps the name, binding, slot, item level, requirements and sell price, and says why", function()
      boot()
      assert.same(SPEAR_HIDDEN, hover(SPEAR))
      local rights = mock.rights(GameTooltip)
      assert.equal("Polearm", rights[3])
      assert.equal("", rights[4])
      assert.is_true(GameTooltip:IsShown())
    end)

    it("keeps every Restricted line type", function()
      boot()
      assert.same({ "Magram Hauberk", "Binds when picked up", "Chest", "", "", "Item Level 20", "Classes: Warrior",
                    UNKNOWN }, hover(HAUBERK))
    end)

    it("falls back to the item level pattern, type and subtype once another addon has added a line", function()
      boot()
      assert.same({ "Magram Hauberk", "", "Chest", "", "", "Item Level 20", "", "Armor", UNKNOWN },
        hover(HAUBERK, { extra = "Armor" }))
      assert.equal("Plate", mock.rights(GameTooltip)[3])
    end)

    it("matches the item level only as a whole line", function()
      boot()
      wow.data.tooltips[SPEAR].lines[6].leftText = "Item Level 22 of 30"
      local texts = hover(SPEAR)
      assert.same({ "", "Item Level 22" }, { texts[6], texts[7] })
    end)

    it("turns the client's ITEM_LEVEL into a pattern with its magic characters escaped", function()
      wow.stub("ITEM_LEVEL", "Item Level: %d (%s)")
      boot()
      local lines = wow.data.tooltips[SPEAR].lines
      lines[6].leftText = "Item Level: 22"
      lines[7].leftText = "Item Level: 22 (Heroic)"
      local texts = hover(SPEAR)
      assert.same({ "", "Item Level: 22 (Heroic)" }, { texts[6], texts[7] })
    end)

    it("is marked on ItemRefTooltip and the shopping tooltips, and on no other tooltip", function()
      boot()
      for _, tip in ipairs({ ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        assert.same(SPEAR_HIDDEN, hover(SPEAR, { tip = tip }), tip:GetName())
      end
      local other = CreateFrame("GameTooltip", "OtherTooltip", UIParent, "GameTooltipTemplate")
      assert.same(SPEAR_LINES, hover(SPEAR, { tip = other }))
      assert.same(SPEAR_LINES, hover(SPEAR, { tip = ns.Test:Tooltip() }))
    end)

    it("is left alone on a forbidden tooltip", function()
      boot()
      wow.stub("GameTooltip.IsForbidden", function() return true end)
      hover(SPEAR)
      untouched()
    end)

    it("is left alone on an unnamed tooltip", function()
      boot()
      GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
      GameTooltip:SetItemByID(SPEAR)
      wow.stub("GameTooltip.GetName", function() return nil end)
      wow.tooltip(Enum.TooltipDataType.Item, GameTooltip, C_TooltipInfo.GetItemByID(SPEAR))
      untouched()
    end)
  end)

  describe("left as the game shows it", function()
    it("for an item this character holds", function()
      mock.bag(wow, 1, 10, SPEAR)
      boot()
      assert.same(SPEAR_LINES, hover(SPEAR))
      assert.is_false(GameTooltip:IsShown())
    end)

    it("for an item the server still hides, asking the client cache once per item until its data arrives", function()
      boot(function()
        wow.data.items[SPEAR].cached = false
        wow.data.items[HAUBERK].cached = false
      end)
      local calls, cached = 0, C_Item.IsItemDataCachedByID
      wow.stub("C_Item.IsItemDataCachedByID", function(id)
        calls = calls + 1
        return cached(id)
      end)
      assert.same(SPEAR_LINES, hover(SPEAR))
      assert.same(SPEAR_LINES, hover(SPEAR))
      local hauberk = hover(HAUBERK)
      assert.equal(2, calls)
      wow.data.items[SPEAR].cached = true
      wow.data.items[HAUBERK].cached = true
      assert.same(SPEAR_LINES, hover(SPEAR))
      assert.same(hauberk, hover(HAUBERK))
      wow.fire("GET_ITEM_INFO_RECEIVED", wow.secret(SPEAR), true)
      wow.fire("GET_ITEM_INFO_RECEIVED", SPEAR, true)
      wow.fire("ITEM_DATA_LOAD_RESULT", HAUBERK, true)
      assert.same(SPEAR_HIDDEN, hover(SPEAR))
      assert.equal(UNKNOWN, hover(HAUBERK)[8])
    end)

    it("for a reward in the quest dialog while the setting is on", function()
      boot()
      local reward = CreateFrame("Button", nil, QuestFrameDetailPanel)
      assert.same(SPEAR_LINES, hover(SPEAR, { owner = reward }))
      assert.same(SPEAR_HIDDEN, hover(SPEAR, { owner = CreateFrame("Button", nil, UIParent) }))
      ns.Settings:Set("Knowledge.questRewards", false)
      assert.same(SPEAR_HIDDEN, hover(SPEAR, { owner = reward }))
    end)

    it("on secret input, without a change", function()
      boot()
      local function data()
        return wow.deepcopy(C_TooltipInfo.GetItemByID(SPEAR))
      end
      local cases = {
        wow.secret(data()),
        wow.lock(data()),
        { id = wow.secret(SPEAR), lines = data().lines },
      }
      local d = data()
      d.lines = wow.lock(d.lines)
      cases[#cases + 1] = d
      d = data()
      d.lines[4] = wow.lock(d.lines[4])
      cases[#cases + 1] = d
      d = data()
      d.lines[4].type = wow.secret(0)
      cases[#cases + 1] = d
      for _, input in ipairs(cases) do
        hover(SPEAR, { data = input })
        untouched()
      end
      hover(SPEAR, { extra = wow.secret("Ashmark") })
      untouched(#SPEAR_LINES + 1)
      wow.data.tooltips[SPEAR].lines[5].rightText = wow.secret("hidden")
      hover(SPEAR)
      untouched()
    end)

    it("while the module is off; the post-call is installed once", function()
      boot()
      ns.Settings:Set("Knowledge.enabled", false)
      assert.same(SPEAR_LINES, hover(SPEAR))
      ns.Settings:Set("Knowledge.enabled", true)
      assert.equal(1, #wow.postCalls[Enum.TooltipDataType.Item])
      assert.same(SPEAR_HIDDEN, hover(SPEAR))
    end)
  end)

  it("writes nothing, requests nothing and never calls GetItemInfo", function()
    wow.stub("C_Item.GetItemInfo", function() error("GetItemInfo called") end)
    boot(function() wow.data.items[HAUBERK].cached = false end)
    local before = wow.deepcopy(_G.AshmarkDB)
    hover(SPEAR)
    hover(HAUBERK)
    hover(STONE)
    assert.same(before, wow.deepcopy(_G.AshmarkDB))
    assert.same({ quest = {}, item = {} }, wow.requests)
  end)

  describe("test checks", function()
    local function check(id)
      return mock.check(ns, id)
    end

    it("hide lines on the test tooltip for the first revealed sample this character has not held", function()
      mock.item(wow, SHORTSWORD)
      boot()
      local ok, detail = check("Knowledge.sample")
      assert.is_true(ok)
      assert.equal("item 25: 3 of 6 lines hidden, kept Worn Shortsword | Main Hand / Sword | Item Level 2 | "
        .. "Sell Price:; held 1, bags scanned true, bank scanned false", detail)
      assert.is_false(AshmarkTestTooltip:IsShown())
      assert.is_false(GameTooltip:IsShown())
    end)

    it("pass over samples this character holds", function()
      mock.item(wow, SHORTSWORD)
      mock.item(wow, DAGGER)
      mock.bag(wow, mock.BACKPACK, 16, STONE, SHORTSWORD)
      boot()
      local ok, detail = check("Knowledge.sample")
      assert.is_true(ok)
      assert.matches("^item 2092: 1 of 3 lines hidden", detail)
    end)

    it("skip without a revealed sample and fail when the sample keeps every line", function()
      boot()
      assert.same({ nil, "no revealed sample this character has not held; held 1, bags scanned true, "
        .. "bank scanned false" }, { check("Knowledge.sample") })
      local data = mock.item(wow, SHORTSWORD)
      data.lines = { data.lines[1], data.lines[2] }
      wow.fire("ITEM_DATA_LOAD_RESULT", SHORTSWORD, true)
      local ok, detail = check("Knowledge.sample")
      assert.is_false(ok)
      assert.matches("^item 25: 0 of 1 lines hidden", detail)
    end)

    it("find secret table, id and line text change nothing", function()
      mock.item(wow, SHORTSWORD)
      boot()
      assert.same({ true, "secret table, id, line change nothing; post-call installed" },
        { check("Knowledge.secret") })
      assert.is_false(AshmarkTestTooltip:IsShown())
    end)

    it("skip the secret line without a sample and the whole check without secretwrap", function()
      boot()
      assert.same({ true, "secret table, id change nothing; no revealed sample for a secret line; "
        .. "post-call installed" }, { check("Knowledge.secret") })
      wow.stub("secretwrap", nil)
      assert.same({ nil, "no secretwrap" }, { check("Knowledge.secret") })
    end)

    it("fail when secret input goes through", function()
      mock.item(wow, SHORTSWORD)
      boot()
      wow.stub("secretwrap", function(v) return v end)
      local ok, detail = check("Knowledge.secret")
      assert.is_false(ok)
      assert.equal("changed or raised on secret table, id, line; post-call installed", detail)
    end)

    it("report a missing post-call", function()
      wow.stub("TooltipDataProcessor.AddTooltipPostCall", nil)
      boot()
      assert.same({ true, "secret table, id change nothing; no revealed sample for a secret line; "
        .. "post-call not installed" }, { check("Knowledge.secret") })
    end)
  end)
end)

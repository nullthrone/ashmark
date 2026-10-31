local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.knowledge_mock")

local ME = "Player-1-00000001"
local SPEAR, HAUBERK, STONE, CLOTH, MACE = mock.SPEAR, mock.HAUBERK, mock.STONE, mock.CLOTH, mock.MACE

describe("Knowledge", function()
  local ns

  local function boot(setup)
    ns = mock.boot(wow, { setup = setup })
    return ns.DB:Char()
  end

  local function knowledge()
    return ns.DB:Char().knowledge
  end

  local function bagUpdate()
    wow.fire("BAG_UPDATE_DELAYED")
    wow.advance(1)
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("the module", function()
    for cap, path in pairs({
      tooltipProcessor = "TooltipDataProcessor.AddTooltipPostCall",
      container = "C_Container.GetContainerItemID",
      itemCache = "C_Item.IsItemDataCachedByID",
    }) do
      it("needs " .. cap, function()
        wow.reset()
        wow.stub(path, nil)
        mock.bag(wow, mock.BACKPACK, 16, STONE)
        local char = boot()
        local M = ns.Knowledge
        assert.is_false(M.enabled)
        assert.same({ cap }, M.unavailable)
        assert.is_nil(char.knowledge)
        assert.is_nil(wow.postCalls[Enum.TooltipDataType.Item])
      end)
    end

    it("registers item.held without a chronicle line and the quest reward setting, on by default", function()
      local char = boot()
      assert.same({ "it" }, ns.Log:Kind("item.held").fields)
      assert.is_falsy(ns.Log:Kind("item.held").keep)
      assert.is_nil(ns.Chronicle:Render({ k = "item.held", n = 1, t = 0, it = STONE }, { char = char, own = true }))
      assert.is_true(ns.Settings:Get("Knowledge.questRewards"))
      local def = ns.Settings.defs["Knowledge.questRewards"]
      assert.same({ "KNOW_SETTING_QUEST_REWARDS", "KNOW_SETTING_QUEST_REWARDS_DESC" }, { def.label, def.tooltip })
      for _, key in ipairs({ "KNOW_MODULE_NAME", "KNOW_MODULE_DESC", def.label, def.tooltip, "KNOW_UNKNOWN" }) do
        assert.is_string(ns.Locale:Base()[key], key)
      end
      local listed = {}
      for _, c in ipairs(ns.Test.checks) do listed[c.id] = true end
      assert.is_true(listed["Knowledge.secret"] and listed["Knowledge.sample"])
    end)

    it("watches bag updates, equipment, the bank and item data", function()
      boot()
      for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED",
                               "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
        assert.is_true(ns.Events:Count(event) >= 1, event)
      end
      assert.equal(1, #wow.postCalls[Enum.TooltipDataType.Item])
    end)
  end)

  describe("bags and equipment", function()
    it("fill held silently on the first full scan and set the bags flag", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE, CLOTH)
      mock.bag(wow, 1, 10, SPEAR)
      wow.data.inventory[5] = HAUBERK
      boot()
      local now = wow.state.epoch
      assert.same({ [STONE] = now, [CLOTH] = now, [SPEAR] = now, [HAUBERK] = now }, knowledge().held)
      assert.same({ bags = true, bank = false }, knowledge().scanned)
      assert.same({}, mock.entries(ns))
    end)

    it("write item.held once for a new item, a second after a burst of bag updates", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      boot()
      local counted, slots = 0, C_Container.GetContainerNumSlots
      wow.stub("C_Container.GetContainerNumSlots", function(bag)
        counted = counted + 1
        return slots(bag)
      end)
      wow.advance(30)
      mock.put(wow, mock.BACKPACK, CLOTH)
      mock.put(wow, mock.BACKPACK, CLOTH)
      for _ = 1, 3 do wow.fire("BAG_UPDATE_DELAYED") end
      wow.advance(0.5)
      assert.same({}, mock.entries(ns))
      wow.advance(0.5)
      assert.same({ CLOTH }, mock.entries(ns))
      assert.equal(6, counted)
      assert.equal(wow.state.epoch, knowledge().held[CLOTH])
      local entry = ns.Log:Last(ns.DB:Char(), "item.held")
      assert.same({ CLOTH, wow.state.epoch }, { entry.it, entry.t })
      bagUpdate()
      assert.same({ CLOTH }, mock.entries(ns))
    end)

    it("read the backpack to the reagent bag and equipment slots 1 to 19, not the bank", function()
      mock.bag(wow, mock.BACKPACK, 16)
      mock.bag(wow, mock.BAG_4, 10, CLOTH)
      mock.bag(wow, mock.REAGENT, 20, MACE)
      mock.bag(wow, mock.BANK, 28, SPEAR)
      mock.bag(wow, mock.BANK_BAG, 10, HAUBERK)
      wow.data.inventory[1], wow.data.inventory[19], wow.data.inventory[20] = 101, 119, 120
      boot()
      local held = knowledge().held
      for _, id in ipairs({ CLOTH, MACE, 101, 119 }) do assert.is_number(held[id], id) end
      for _, id in ipairs({ SPEAR, HAUBERK, 120 }) do assert.is_nil(held[id], id) end
    end)

    it("write item.held at once for a newly equipped item", function()
      boot()
      wow.data.inventory[16] = SPEAR
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
      assert.same({ SPEAR }, mock.entries(ns))
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
      assert.same({ SPEAR }, mock.entries(ns))
    end)

    it("keep the first scan silent until the backpack reports its slots", function()
      mock.bag(wow, mock.BACKPACK, 0)
      wow.data.inventory[5] = HAUBERK
      boot()
      assert.same({ bags = false, bank = false }, knowledge().scanned)
      assert.is_number(knowledge().held[HAUBERK])
      wow.data.inventory[16] = SPEAR
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
      mock.bag(wow, mock.BACKPACK, 16, STONE, CLOTH)
      bagUpdate()
      assert.is_true(knowledge().scanned.bags)
      assert.is_number(knowledge().held[SPEAR])
      assert.is_number(knowledge().held[CLOTH])
      assert.same({}, mock.entries(ns))
      mock.put(wow, mock.BACKPACK, MACE)
      bagUpdate()
      assert.same({ MACE }, mock.entries(ns))
    end)

    it("scan nothing before the world is ready", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      ns = wow.load(mock.FILES)
      wow.fire("ADDON_LOADED", wow.ADDON)
      wow.state.loggedIn = true
      wow.fire("PLAYER_LOGIN")
      wow.fire("BAG_UPDATE_DELAYED")
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
      wow.advance(1)
      assert.is_nil(ns.DB:Char().knowledge)
      wow.fire("PLAYER_ENTERING_WORLD", true, false)
      assert.is_true(knowledge().scanned.bags)
      assert.same({}, mock.entries(ns))
    end)

    it("write entries after a /reload for items that arrived meanwhile, never a second silent scan", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      boot()
      mock.put(wow, mock.BACKPACK, CLOTH)
      ns = wow.reload()
      assert.same({ CLOTH }, mock.entries(ns))
      assert.same({ bags = true, bank = false }, knowledge().scanned)
    end)

    it("skip secret, missing and failing reads", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE, CLOTH, MACE)
      mock.bag(wow, 1, 4, SPEAR)
      local get, slots = C_Container.GetContainerItemID, C_Container.GetContainerNumSlots
      wow.stub("C_Container.GetContainerItemID", function(bag, slot)
        if bag == 0 and slot == 2 then return wow.secret(CLOTH) end
        if bag == 0 and slot == 3 then error("boom") end
        return get(bag, slot)
      end)
      wow.stub("C_Container.GetContainerNumSlots", function(bag)
        if bag == 1 then return wow.secret(4) end
        return slots(bag)
      end)
      wow.stub("GetInventoryItemID", function(_, slot) if slot == 1 then return wow.secret(HAUBERK) end end)
      boot()
      assert.same({ [STONE] = wow.state.epoch }, knowledge().held)
    end)

    it("repair a broken record and start over on a wiped one", function()
      wow.saved({ schema = 1, chars = { [ME] = { knowledge = { held = "broken", scanned = { bags = "yes" } } } } })
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      boot()
      assert.same({ [STONE] = wow.state.epoch }, knowledge().held)
      assert.same({ bags = true, bank = false }, knowledge().scanned)
      assert.same({}, mock.entries(ns))
      ns.DB:Char().knowledge = nil
      bagUpdate()
      assert.same({ bags = true, bank = false }, knowledge().scanned)
      assert.same({}, mock.entries(ns))
    end)
  end)

  describe("the bank", function()
    local function openBank()
      wow.fire("BANKFRAME_OPENED")
    end

    it("is read on BANKFRAME_OPENED, silently the first time, without the account bank or empty containers", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      mock.bag(wow, mock.BANK, 28, SPEAR)
      mock.bag(wow, mock.BANK_BAG, 10, HAUBERK)
      mock.bag(wow, mock.BANK_BAG_2, 0)
      mock.bag(wow, mock.ACCOUNT, 98, CLOTH)
      boot()
      mock.put(wow, mock.BACKPACK, MACE)
      bagUpdate()
      assert.same({ MACE }, mock.entries(ns))
      assert.is_nil(knowledge().held[SPEAR])
      openBank()
      assert.is_true(knowledge().scanned.bank)
      assert.is_number(knowledge().held[SPEAR])
      assert.is_number(knowledge().held[HAUBERK])
      assert.is_nil(knowledge().held[CLOTH])
      assert.same({ MACE }, mock.entries(ns))
      mock.put(wow, mock.BANK_BAG, 777)
      openBank()
      assert.same({ MACE, 777 }, mock.entries(ns))
    end)

    it("stays silent on a visit where no bank container reports slots", function()
      boot()
      openBank()
      assert.is_false(knowledge().scanned.bank)
      mock.bag(wow, mock.BANK, 28, SPEAR)
      openBank()
      assert.is_true(knowledge().scanned.bank)
      assert.same({}, mock.entries(ns))
    end)

    it("takes every key with Bank but not Account from Enum.BagIndex, in either spelling", function()
      wow.stub("Enum.BagIndex", { Backpack = 0, ReagentBag = 5, CharacterBankTab_1 = 6, Reagentbank = -3,
                                  Bankbag = -4, AccountBankTab_1 = 12, Accountbanktab = -5 })
      mock.bag(wow, 6, 98, SPEAR)
      mock.bag(wow, -3, 98, HAUBERK)
      mock.bag(wow, -4, 7, MACE)
      mock.bag(wow, 12, 98, CLOTH)
      mock.bag(wow, -5, 98, 777)
      boot()
      openBank()
      local held = knowledge().held
      for _, id in ipairs({ SPEAR, HAUBERK, MACE }) do assert.is_number(held[id], id) end
      assert.is_nil(held[CLOTH])
      assert.is_nil(held[777])
    end)
  end)

  describe("Held", function()
    it("returns when this character first held an item, and nil otherwise", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      local char = boot()
      local K = ns.Knowledge
      assert.equal(wow.state.epoch, K:Held(char, STONE))
      assert.is_nil(K:Held(char, SPEAR))
      assert.is_nil(K:Held(char, wow.secret(STONE)))
      assert.is_nil(K:Held(char, nil))
      assert.is_nil(K:Held(nil, STONE))
      assert.is_nil(K:Held({}, STONE))
      assert.is_nil(K:Held({ knowledge = { held = { [STONE] = "x" } } }, STONE))
      assert.equal(5, K:Held({ knowledge = { held = { [SPEAR] = 5 } } }, SPEAR))
    end)

    it("answers while the module is unavailable", function()
      wow.saved({ schema = 1, chars = { [ME] = { knowledge = { held = { [STONE] = 123 } } } } })
      wow.stub("C_Container.GetContainerNumSlots", nil)
      local char = boot()
      assert.same({ "container" }, ns.Knowledge.unavailable)
      assert.equal(123, ns.Knowledge:Held(char, STONE))
    end)
  end)

  describe("switched off", function()
    it("scans nothing, drops a pending scan and catches up when switched on", function()
      mock.bag(wow, mock.BACKPACK, 16, STONE)
      boot()
      wow.fire("BAG_UPDATE_DELAYED")
      ns.Settings:Set("Knowledge.enabled", false)
      mock.put(wow, mock.BACKPACK, CLOTH)
      wow.data.inventory[16] = SPEAR
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
      bagUpdate()
      assert.is_nil(knowledge().held[CLOTH])
      assert.is_nil(knowledge().held[SPEAR])
      ns.Settings:Set("Knowledge.enabled", true)
      assert.same({ CLOTH, SPEAR }, mock.entries(ns))
    end)
  end)
end)

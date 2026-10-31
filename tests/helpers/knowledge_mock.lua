-- Fixtures for the Knowledge specs (not shipped): items with their tooltip data, bags, bank and equipment as
-- container fixtures, an item tooltip shown through the post-calls as the client would, and the test checks
-- run by id.
local mock = {}

mock.FILES = { "Modules/Knowledge" }

mock.BACKPACK, mock.BAG_4, mock.REAGENT = 0, 4, 5
mock.BANK, mock.BANK_BAG, mock.BANK_BAG_2, mock.ACCOUNT = -1, 6, 7, 13

mock.SPEAR, mock.HAUBERK = 9101, 9102
mock.STONE, mock.CLOTH, mock.MACE = 6948, 2589, 36
mock.SHORTSWORD, mock.DAGGER = 25, 2092          -- the first two samples of the test check

-- [id] = { item = wow.data.items fields, lines = { { line type key, left text, right text }, ... } }
local ITEMS = {
  [mock.SPEAR] = {
    item = { name = "Gelkis Spear", itemType = "Weapon", itemSubType = "Polearms", equipLoc = "INVTYPE_2HWEAPON",
             classID = 2, subclassID = 6 },
    lines = {
      { "ItemName", "Gelkis Spear" },
      { "ItemBinding", "Binds when equipped" },
      { "EquipSlot", "Two-Hand", "Polearm" },
      { "None", "21 - 32 Damage", "Speed 3.20" },
      { "None", "(8.3 damage per second)" },
      { "None", "+4 Strength" },
      { "None", "Item Level 22" },
      { "RestrictedLevel", "Requires Level 17" },
      { "SellPrice", "Sell Price:" },
    },
  },
  [mock.HAUBERK] = {
    item = { name = "Magram Hauberk", itemType = "Armor", itemSubType = "Plate", equipLoc = "INVTYPE_CHEST",
             classID = 4, subclassID = 4 },
    lines = {
      { "ItemName", "Magram Hauberk" },
      { "ItemBinding", "Binds when picked up" },
      { "EquipSlot", "Chest", "Plate" },
      { "None", "350 Armor" },
      { "None", "+5 Stamina" },
      { "None", "Item Level 20" },
      { "RestrictedRaceClass", "Classes: Warrior" },
    },
  },
  [mock.SHORTSWORD] = {
    item = { name = "Worn Shortsword", itemType = "Weapon", itemSubType = "One-Handed Swords",
             equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, subclassID = 7 },
    lines = {
      { "ItemName", "Worn Shortsword" },
      { "EquipSlot", "Main Hand", "Sword" },
      { "None", "1 - 3 Damage", "Speed 1.90" },
      { "None", "(1.1 damage per second)" },
      { "None", "Durability 16 / 16" },
      { "None", "Item Level 2" },
      { "SellPrice", "Sell Price:" },
    },
  },
  [mock.DAGGER] = {
    item = { name = "Worn Dagger", itemType = "Weapon", itemSubType = "Daggers", equipLoc = "INVTYPE_WEAPON",
             classID = 2, subclassID = 15 },
    lines = {
      { "ItemName", "Worn Dagger" },
      { "EquipSlot", "One-Hand", "Dagger" },
      { "None", "1 - 2 Damage", "Speed 1.60" },
      { "None", "Item Level 2" },
    },
  },
}

-- Client strings the tooltip falls back to that the mock client lacks: binding, requirements and the INVTYPE_*
-- slot names of the fixture items. mock.boot installs each one a spec has not set.
mock.STRINGS = {
  ITEM_BIND_ON_EQUIP = "Binds when equipped", ITEM_BIND_ON_PICKUP = "Binds when picked up",
  ITEM_MIN_LEVEL = "Requires Level %d", ITEM_CLASSES_ALLOWED = "Classes: %s",
  INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONMAINHAND = "Main Hand", INVTYPE_WEAPON = "One-Hand",
  INVTYPE_CHEST = "Chest",
}

-- Puts a fixture item into the client: its item data (revealed unless opts.cached is false) and its tooltip
-- data. Returns the tooltip data, which specs may edit.
function mock.item(wow, id, opts)
  opts = opts or {}
  local def = ITEMS[id]
  local item = {}
  for k, v in pairs(def.item) do item[k] = v end
  item.cached = opts.cached ~= false
  wow.data.items[id] = item
  local types, lines = Enum.TooltipDataLineType, {}
  for i, line in ipairs(def.lines) do
    lines[i] = { type = types[line[1]], leftText = line[2], rightText = line[3] }
  end
  wow.data.tooltips[id] = { id = id, type = Enum.TooltipDataType.Item, lines = lines }
  return wow.data.tooltips[id]
end

-- A container with `slots` slots holding the given item IDs from slot 1 on.
function mock.bag(wow, bag, slots, ...)
  local b = { size = slots }
  for i = 1, select("#", ...) do b[i] = select(i, ...) end
  wow.data.bags[bag] = b
  return b
end

-- Puts an item into the first free slot of a container fixture.
function mock.put(wow, bag, id)
  local b = wow.data.bags[bag]
  for slot = 1, b.size do
    if b[slot] == nil then
      b[slot] = id
      return slot
    end
  end
  error("no free slot in bag " .. tostring(bag))
end

-- Core, Locales and Knowledge, opts.setup(ns), then login. The backpack has 16 slots unless a spec set it.
function mock.boot(wow, opts)
  opts = opts or {}
  if not wow.data.bags[mock.BACKPACK] then mock.bag(wow, mock.BACKPACK, 16) end
  for key, text in pairs(mock.STRINGS) do
    if _G[key] == nil then wow.stub(key, text) end
  end
  local ns = wow.load(mock.FILES)
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

local function side(tip, which)
  local out = {}
  for i = 1, tip:NumLines() do out[i] = _G[tip:GetName() .. which .. i]:GetText() end
  return out
end

function mock.texts(tip)
  return side(tip, "TextLeft")
end

function mock.rights(tip)
  return side(tip, "TextRight")
end

-- Shows an item on opts.tip (GameTooltip) owned by opts.owner (UIParent) and runs the post-calls with
-- opts.data (the client's tooltip data); opts.extra is a line another addon added first. Returns the left texts.
function mock.hover(wow, id, opts)
  opts = opts or {}
  local tip = opts.tip or GameTooltip
  tip:Hide()
  tip:SetOwner(opts.owner or UIParent, "ANCHOR_NONE")
  tip:SetItemByID(id)
  if opts.extra ~= nil then tip:AddLine(opts.extra) end
  local data = opts.data
  if data == nil then data = C_TooltipInfo.GetItemByID(id) end
  wow.tooltip(Enum.TooltipDataType.Item, tip, data)
  return mock.texts(tip)
end

-- Item IDs of the item.held entries in the current character's log, in order.
function mock.entries(ns)
  local out = {}
  for entry in ns.Log:Iter(ns.DB:Char(), 1) do
    if entry.k == "item.held" then out[#out + 1] = entry.it end
  end
  return out
end

function mock.check(ns, id)
  for _, c in ipairs(ns.Test.checks) do
    if c.id == id then return c.fn() end
  end
  error("no test check " .. id)
end

return mock

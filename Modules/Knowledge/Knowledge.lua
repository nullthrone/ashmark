local _, ns = ...

-- Module 7 (7.7): what this character knows about items. Every item ID that passes through its bags,
-- bank or equipment is held. The tooltip of an item the server has revealed but this character has
-- never held keeps its name, binding, slot, item level, type and requirements, and says so; items the
-- server still hides and items this character has held stay as the game shows them.
local M = ns:NewModule("Knowledge", {
  requires = { "tooltipProcessor", "container", "itemCache" },
  locale = "KNOW",
  default = true,
})

ns.Settings:Register("Knowledge.questRewards", true, "KNOW_SETTING_QUEST_REWARDS", "KNOW_SETTING_QUEST_REWARDS_DESC")

local Safe = ns.Safe
local L = ns.L

local SCAN_DELAY = 1
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local KEEP_TYPES = { ItemName = true, ItemBinding = true, EquipSlot = true, SellPrice = true }   -- and Restricted*
local SIDES = { "TextLeft", "TextRight" }
-- Starter gear and common goods every client has revealed, for the test check; weapons first, so the
-- sample has stat lines to hide.
local SAMPLES = { 25, 2092, 36, 12282, 2362, 2589, 159, 117 }

-- A client format string as an anchored pattern: magic characters escaped, %d a number, %s any text.
local function formatPattern(fmt)
  local p = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
  p = p:gsub("%%d", "%%d+"):gsub("%%s", ".+")
  return "^" .. p .. "$"
end

local LEVEL = type(ITEM_LEVEL) == "string" and formatPattern(ITEM_LEVEL) or nil

local FIRST_BAG, LAST_BAG = 0, 0
local BANK = {}                   -- bank container IDs, from Enum.BagIndex in OnInitialize
local keepType = {}               -- [Enum.TooltipDataLineType value] = true
local revealed = {}               -- [itemID] = bool: C_Item.IsItemDataCachedByID, read once per session
local allowed = {}                -- [tooltip] = true for the tooltips of step 1
local regions = {}                -- [tooltip] = { TextLeft = { [i] = FontString }, TextRight = { ... } }
local hooked = false

-- Held items -------------------------------------------------------------------------------

-- char.knowledge (4.1), created on the first scan and repaired field by field, so a wiped record starts over.
local function record(char)
  local k = char.knowledge
  if type(k) ~= "table" then
    k = {}
    char.knowledge = k
  end
  if type(k.held) ~= "table" then k.held = {} end
  if type(k.scanned) ~= "table" then k.scanned = {} end
  local scanned = k.scanned
  if scanned.bags ~= true then scanned.bags = false end
  if scanned.bank ~= true then scanned.bank = false end
  return k
end

local function heldAt(char, id)
  local k = type(char) == "table" and char.knowledge
  local held = type(k) == "table" and k.held
  local t = type(held) == "table" and held[id]
  if type(t) == "number" then return t end
end

-- The current character's record once the world is ready, when entries can be written (3.3).
local function current()
  local char = ns.ready and M:Char()
  if char then return record(char) end
end

local function number(ok, v)
  if ok and type(v) == "number" then return v end
end

-- A new item ID is held from now on; outside a silent first scan it also writes item.held.
local function note(k, id, silent, now)
  if not id or k.held[id] then return end
  k.held[id] = now
  if not silent then ns.Log:Add("item.held", { it = id }) end
end

-- Every item in a container; returns the container's number of slots.
local function scanContainer(k, bag, silent, now)
  local slots = number(Safe.Call(C_Container.GetContainerNumSlots, bag)) or 0
  for slot = 1, slots do
    note(k, number(Safe.Call(C_Container.GetContainerItemID, bag, slot)), silent, now)
  end
  return slots
end

local function scanEquipment(k, silent, now)
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    note(k, number(Safe.Call(GetInventoryItemID, "player", slot)), silent, now)
  end
end

-- Bags and equipment. The first full scan is silent. It counts only once the backpack reports its
-- slots, so a login before the inventory has loaded cannot turn the next scan into a burst of entries.
local function scanCarried()
  local k = current()
  if not k then return end
  local silent, now = not k.scanned.bags, time()
  local loaded = scanContainer(k, FIRST_BAG, silent, now) > 0
  for bag = FIRST_BAG + 1, LAST_BAG do scanContainer(k, bag, silent, now) end
  scanEquipment(k, silent, now)
  if loaded then k.scanned.bags = true end
end

local function onEquipment()
  local k = current()
  if k then scanEquipment(k, not k.scanned.bags, time()) end
end

-- The first visit on which a bank container reports slots is silent.
local function scanBank()
  local k = current()
  if not k then return end
  local silent, now, any = not k.scanned.bank, time(), false
  for _, bag in ipairs(BANK) do
    if scanContainer(k, bag, silent, now) > 0 then any = true end
  end
  if any then k.scanned.bank = true end
end

local scanLater = M:Wrap("scan:carried", scanCarried)

local function queueCarried()
  ns.Util.Debounce("Knowledge.carried", SCAN_DELAY, scanLater)
end

-- Every Enum.BagIndex value whose key names the character's bank (Bank, BankBag_n, CharacterBankTab_n),
-- without the account bank.
local function bankContainers(index)
  local list = {}
  for key, value in pairs(index) do
    if type(key) == "string" and type(value) == "number" and key:find("Bank", 1, true)
      and not key:find("Account", 1, true) then
      list[#list + 1] = value
    end
  end
  table.sort(list)
  return list
end

-- Item tooltip (7.7) --------------------------------------------------------------------------

local function isRevealed(id)
  local known = revealed[id]
  if known == nil then
    local cached, ok = Safe.Value(C_Item.IsItemDataCachedByID(id))
    if not ok then return false end
    known = cached == true
    revealed[id] = known
  end
  return known
end

-- Once an item's data arrives or is refused, the next tooltip asks the client cache again.
local function onItemData(_, _, id)
  id = Safe.Value(id)
  if id ~= nil then revealed[id] = nil end
end

-- Step 4: rewards shown in the quest dialog stay whole while Knowledge.questRewards is on.
local function questReward(tooltip)
  if not (QuestFrame and M:Setting("questRewards")) then return false end
  local frame = tooltip:GetOwner()
  while frame do
    if frame == QuestFrame then return true end
    frame = frame:GetParent()
  end
  return false
end

-- Font strings are looked up once per tooltip and line, so the post-call builds no names.
local function fontString(tooltip, name, side, i)
  local cache = regions[tooltip]
  if not cache then
    cache = { TextLeft = {}, TextRight = {} }
    regions[tooltip] = cache
  end
  local fs = cache[side][i]
  if not fs then
    fs = _G[name .. side .. i]
    cache[side][i] = fs
  end
  return fs
end

-- A line's text: nil when there is none, false when it is secret.
local function textAt(tooltip, name, side, i)
  local fs = fontString(tooltip, name, side, i)
  if not fs then return nil end
  local text = fs:GetText()
  if Safe.IsSecret(text) then return false end
  return text
end

-- The type of data line i: nil, ok; ok is false when the line or its type is secret.
local function lineType(lines, i)
  local line, ok = Safe.Field(lines, i)
  if not ok then return nil, false end
  if type(line) ~= "table" then return nil, true end
  return Safe.Field(line, "type")
end

local function same(text, a, b)
  return text ~= nil and text ~= "" and (text == a or text == b)
end

local function keep(left, right, kind, itemType, subType)
  if kind ~= nil and keepType[kind] then return true end
  if LEVEL and type(left) == "string" and left:find(LEVEL) then return true end
  return same(left, itemType, subType) or same(right, itemType, subType)
end

local kept = {}                   -- scratch for one tooltip, reused: the post-call allocates nothing per line

-- Steps 2 to 8, on a tooltip that passed step 1 or on the test tooltip. Returns the number of lines it
-- blanked, or nil when it left the tooltip as it was.
local function conceal(tooltip, data)
  local id, ok = Safe.Field(data, "id")
  if not ok or type(id) ~= "number" then return nil end
  if heldAt(M:Char(), id) or questReward(tooltip) or not isRevealed(id) then return nil end
  local n, name = Safe.Value(tooltip:NumLines()), tooltip:GetName()
  local lines, readable = Safe.Field(data, "lines")
  if type(n) ~= "number" or type(name) ~= "string" or not readable then return nil end
  -- Line types match tooltip lines only while no other addon has added lines.
  local typed = type(lines) == "table" and #lines == n
  local _, _, itemType, subType = Safe.Call(C_Item.GetItemInfoInstant, id)
  for i = 2, n do
    local left, right = textAt(tooltip, name, "TextLeft", i), textAt(tooltip, name, "TextRight", i)
    if left == false or right == false then return nil end
    local kind, known = nil, true
    if typed then kind, known = lineType(lines, i) end
    if not known then return nil end
    kept[i] = keep(left, right, kind, itemType, subType)
  end
  local hidden = 0
  for i = 2, n do
    if not kept[i] then
      hidden = hidden + 1
      for _, side in ipairs(SIDES) do
        local fs = fontString(tooltip, name, side, i)
        if fs then fs:SetText("") end
      end
    end
  end
  tooltip:AddLine(L.KNOW_UNKNOWN, NORMAL_FONT_COLOR:GetRGB())
  -- Ground rule 11: Knowledge may resize the tooltip after its edits.
  tooltip:Show()
  return hidden
end

local function onItem(tooltip, data)
  if not allowed[tooltip] or tooltip:IsForbidden() or tooltip:GetName() == nil then return end
  conceal(tooltip, data)
end

-- Public services (3.8) ------------------------------------------------------------------------

function M:Held(char, itemId)
  if Safe.IsSecret(itemId) then return nil end
  return heldAt(char, itemId)
end

-- Test checks (7.10) ---------------------------------------------------------------------------

local function str(v)
  if Safe.IsSecret(v) then return "<secret>" end
  return tostring(v)
end

-- The first sample this character has not held whose data the client has revealed.
local function sample()
  local char = M:Char()
  for _, id in ipairs(SAMPLES) do
    if not heldAt(char, id) and isRevealed(id) then return id end
  end
end

local function itemData(id)
  local ok, data = Safe.Call(C_TooltipInfo.GetItemByID, id)
  if ok then return data end
end

local function summary()
  local char = M:Char()
  local k = type(char) == "table" and type(char.knowledge) == "table" and char.knowledge or {}
  local count = 0
  for _ in pairs(type(k.held) == "table" and k.held or {}) do count = count + 1 end
  local scanned = type(k.scanned) == "table" and k.scanned or {}
  return string.format("held %d, bags scanned %s, bank scanned %s", count, str(scanned.bags), str(scanned.bank))
end

-- Every line's left and right text as one string, secret ones as a marker, to compare before and after.
local function snapshot(tip)
  local name, parts = tip:GetName(), { tip:NumLines() }
  for i = 1, parts[1] do
    for _, side in ipairs(SIDES) do
      local fs = _G[name .. side .. i]
      parts[#parts + 1] = str(fs and fs:GetText())
    end
  end
  return table.concat(parts, "\n")
end

-- true when conceal left the filled test tooltip as it was and raised nothing; nil when it could not be filled.
local function unchanged(fill, data)
  local tip = ns.Test:Tooltip()
  local intact
  if pcall(fill, tip) then
    local before = snapshot(tip)
    local done, result = pcall(conceal, tip, data)
    intact = done and result == nil and snapshot(tip) == before
  end
  tip:Hide()
  return intact
end

local function hasTooltipInfo()
  return C_TooltipInfo ~= nil and type(C_TooltipInfo.GetItemByID) == "function"
end

-- Secret data, a secret item ID and, with a revealed sample, a secret line text change nothing.
local function checkSecret()
  if type(secretwrap) ~= "function" then return nil, "no secretwrap" end
  if not ns.Compat.Has.itemCache then return nil, "no item cache API" end
  local id = sample()
  local probe = id or SAMPLES[1]
  -- The test tooltip shows the sample, or stays empty: an item the client has not revealed would be requested.
  local function show(tip)
    if id then tip:SetItemByID(id) end
  end
  local made, cases = pcall(function()
    local list = {
      { name = "table", data = secretwrap({ id = probe }), fill = show },
      { name = "id", data = { id = secretwrap(probe) }, fill = show },
    }
    if id and hasTooltipInfo() then
      local text = secretwrap("Ashmark")
      list[3] = { name = "line", data = itemData(id), fill = function(tip)
        show(tip)
        tip:AddLine(text)
      end }
    end
    return list
  end)
  if not made then return false, "secretwrap: " .. str(cases) end
  local passed, failed, skipped = {}, {}, {}
  for _, case in ipairs(cases) do
    local result = unchanged(case.fill, case.data)
    local into = result == true and passed or result == false and failed or skipped
    into[#into + 1] = case.name
  end
  local parts = {}
  if #passed > 0 then parts[#parts + 1] = "secret " .. table.concat(passed, ", ") .. " change nothing" end
  if #failed > 0 then parts[#parts + 1] = "changed or raised on secret " .. table.concat(failed, ", ") end
  if #skipped > 0 then parts[#parts + 1] = "could not set up secret " .. table.concat(skipped, ", ") end
  if #cases < 3 then parts[#parts + 1] = "no revealed sample for a secret line" end
  parts[#parts + 1] = "post-call " .. (hooked and "installed" or "not installed")
  return #failed == 0, table.concat(parts, "; ")
end

-- The texts of the lines conceal kept, with the right text after a slash.
local function keptLines(tip, last)
  local name, out = tip:GetName(), {}
  for i = 1, last do
    local left, right = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
    local l, r = left and left:GetText(), right and right:GetText()
    if (l ~= nil and l ~= "") or Safe.IsSecret(l) then
      out[#out + 1] = (r ~= nil and r ~= "") and (str(l) .. " / " .. str(r)) or str(l)
    end
  end
  return table.concat(out, " | ")
end

-- Lines hidden on the test tooltip for a revealed sample this character has not held. Never shows a
-- Blizzard tooltip: the sample goes onto AshmarkTestTooltip, which step 1 ignores.
local function checkSample()
  if not hasTooltipInfo() then return nil, "no C_TooltipInfo.GetItemByID" end
  if not ns.Compat.Has.itemCache then return nil, "no item cache API" end
  local id = sample()
  if not id then return nil, "no revealed sample this character has not held; " .. summary() end
  local tip = ns.Test:Tooltip()
  tip:SetItemByID(id)
  local done, hidden = pcall(conceal, tip, itemData(id))
  local n = tip:NumLines()
  local last = _G[tip:GetName() .. "TextLeft" .. n]
  local marked = done and hidden ~= nil and last ~= nil and last:GetText() == L.KNOW_UNKNOWN
  local detail = marked and string.format("item %d: %d of %d lines hidden, kept %s", id, hidden, n - 2,
    keptLines(tip, n - 1)) or string.format("item %d: %s", id, done and "left untouched" or ("raised " .. str(hidden)))
  tip:Hide()
  return marked and hidden > 0, detail .. "; " .. summary()
end

-- Lifecycle ----------------------------------------------------------------------------------

function M:OnInitialize()
  local index = Enum and Enum.BagIndex or {}
  FIRST_BAG = index.Backpack or 0
  LAST_BAG = index.ReagentBag or NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
  BANK = bankContainers(index)
  for key, value in pairs(Enum and Enum.TooltipDataLineType or {}) do
    if KEEP_TYPES[key] or (type(key) == "string" and key:find("^Restricted")) then keepType[value] = true end
  end
  ns.Log:RegisterKind("item.held", { fields = { "it" } })
  ns.Test:Register("Knowledge.secret", checkSecret)
  ns.Test:Register("Knowledge.sample", checkSample)
end

function M:OnEnable()
  -- Item data may have arrived while the module was off, unseen by its events.
  revealed = {}
  self:RegisterEvent("BAG_UPDATE_DELAYED", queueCarried)
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", onEquipment)
  self:RegisterEvent("BANKFRAME_OPENED", scanBank)
  self:RegisterEvent("ITEM_DATA_LOAD_RESULT", onItemData)
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", onItemData)
  self:Hook("tooltip:item", function()
    for _, tipName in ipairs(TOOLTIPS) do
      local tip = _G[tipName]
      if tip then allowed[tip] = true end
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, self:Wrap("tooltip:item", onItem))
    hooked = true
  end)
end

function M:OnWorldReady()
  scanCarried()
end

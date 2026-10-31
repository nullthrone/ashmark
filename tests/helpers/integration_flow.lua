-- The integration flow (not shipped), shared by integration_load_spec and integration_locales_spec: the whole
-- addon loaded in TOC order into one ns and logged in, every module's main events played with every tab open,
-- each module switched off and on, and the test mode run.
local assert = require("luassert")

local flow = {}

-- With Core and Locales, which wow.load always takes, these are every folder the TOC loads from.
flow.ALL = { "UI", "Data", "Modules", "Dev" }

flow.TAB_IDS = { "chronicle", "decisions", "encounters", "house" }
flow.MIRA = "Player-1-00000002"

-- The globals of section 3.1, the only ones Ashmark may create.
flow.GLOBALS = {
  AshmarkDB = true, Ashmark_OnAddonCompartmentClick = true, Ashmark_OnAddonCompartmentEnter = true,
  Ashmark_OnAddonCompartmentLeave = true, SLASH_ASHMARK1 = true, SLASH_ASHMARK2 = true, AshmarkMapPinMixin = true,
  AshmarkFrame = true, AshmarkDialog = true, AshmarkNoticeFrame = true, AshmarkTestTooltip = true,
}

-- The names in _G now. Take it when the spec file loads, before any test of it loads the addon: wow.reset only
-- clears globals named Ashmark*.
function flow.baseline()
  local names = {}
  for name in pairs(_G) do names[name] = true end
  return names
end

-- A tooltip names its line font strings after itself (GameTooltipTemplate in the client, the mock's regions
-- here): AshmarkTestTooltipTextLeft1 belongs to AshmarkTestTooltip, GameTooltipTextLeft1 to the client.
local function tooltipLine(baseline, name)
  local owner = type(name) == "string" and name:match("^(.-)Text[LR][a-z]+%d+$")
  return owner ~= nil and (baseline[owner] or flow.GLOBALS[owner]) == true
end

-- Globals created since the baseline, other than those of section 3.1.
function flow.newGlobals(baseline)
  local out = {}
  for name in pairs(_G) do
    if not baseline[name] and not flow.GLOBALS[name] and not tooltipLine(baseline, name) then
      out[#out + 1] = tostring(name)
    end
  end
  table.sort(out)
  return out
end

function flow.start(wow)
  local ns = wow.load(flow.ALL)
  wow.login()
  return ns
end

-- Ids of the results of one /ashmark test run whose detail reports an error.
local function raisedChecks()
  local raised = {}
  SlashCmdList.ASHMARK("test")
  local tests = _G.AshmarkDB.dev.tests
  for _, r in ipairs(tests[#tests].results) do
    if type(r.detail) == "string" and r.detail:match("^error") then raised[#raised + 1] = r.id end
  end
  return raised
end

-- Plays every module's main events with every tab open, then switches each module off and on and runs the test
-- mode. Asserts along the way; returns ns. The caller checks wow.errors and the globals.
function flow.play(wow)
  local MIRA, TAB_IDS = flow.MIRA, flow.TAB_IDS
  wow.data.quests[1382] = { title = "Centaur Bounty", inLog = true }
  wow.data.quests[1385] = { title = "Brutal Politics", inLog = true }
  wow.data.items[2589] = { name = "Linen Cloth", itemType = "Tradeskill", itemSubType = "Cloth" }
  wow.data.items[2592] = { name = "Wool Cloth", itemType = "Tradeskill", itemSubType = "Cloth" }
  wow.data.items[6948] = { name = "Hearthstone", itemType = "Miscellaneous", itemSubType = "Junk" }
  wow.data.tooltips[2592] = { id = 2592, type = Enum.TooltipDataType.Item, lines = {
    { type = Enum.TooltipDataLineType.ItemName, leftText = "Wool Cloth" },
    { type = Enum.TooltipDataLineType.None, leftText = "Spun from the fibres of the land." },
    { type = Enum.TooltipDataLineType.SellPrice, leftText = "Sell Price: 13" },
  } }
  wow.data.bags[0] = { size = 16, 6948 }
  wow.data.bags[-1] = { size = 28 }
  wow.state.map, wow.state.pos = 1443, { x = 0.42, y = 0.61 }
  local ns = flow.start(wow)
  local AURAS = ns.Campfire.AURAS
  local function aura(key, on)
    local id = AURAS[key]
    wow.state.auras[id] = on and { spellId = id, name = key } or nil
    wow.fire("UNIT_AURA", "player", { isFullUpdate = true })
  end
  local char = ns.DB:Char()
  SlashCmdList.ASHMARK("")

  -- Conflicts and Profile: an alliance by accepting, the other side's dialog line, then a violation.
  wow.fire("QUEST_ACCEPTED", 1382)
  QuestFrame:Show()
  wow.state.questDetail = 1385
  wow.fire("QUEST_DETAIL")
  local strip = QuestFrameDetailPanel.__children[1]
  assert.is_true(strip:IsShown())
  assert.truthy(strip.Text:GetText():find("Gelkis Clan Centaur", 1, true))
  wow.fire("QUEST_FINISHED")
  assert.is_false(strip:IsShown())
  QuestFrame:Hide()
  wow.fire("QUEST_TURNED_IN", 1385, 0, 0)
  wow.fire("UPDATE_FACTION")
  wow.advance(2)

  -- Map: the zone's map with the violation pin, and its tooltip.
  wow.state.worldMapShown, wow.state.worldMapID = true, 1443
  for provider in pairs(WorldMapFrame.providers) do provider:RefreshAllData(true) end
  local pin = WorldMapFrame.pins[#WorldMapFrame.pins]
  assert.is_table(pin)
  pin:OnMouseEnter()
  pin:OnMouseLeave()

  -- Profile: a calm neutral beast attacked out of combat dies.
  local beast = wow.unit("target", { guid = "Creature-0-1-1-1-3233-000000001", name = "Plainstrider",
    reaction = 4, combat = false, creatureType = "Beast", creatureTypeID = 1, health = 100, healthMax = 100 })
  wow.fire("PLAYER_TARGET_CHANGED")
  beast.combat, wow.state.inCombat = true, true
  wow.fire("UNIT_FLAGS", "target")
  wow.combat(true)
  beast.dead, beast.health = true, 0
  wow.fire("UNIT_HEALTH", "target")
  wow.combat(false)
  wow.advance(60)

  -- Encounters, Fiction, Rumours: Mira joins, greets back, tells a rumour, and fights a boss with us.
  wow.unit("party1", { guid = MIRA, name = "Mira", classFile = "MAGE", className = "Mage", raceID = 7, sex = 3,
                       faction = "Alliance", level = 21, isPlayer = true })
  wow.fire("GROUP_ROSTER_UPDATE")
  wow.advance(2)
  local function receive(...)
    wow.fire("CHAT_MSG_ADDON", "Ashmark", table.concat({ "1", ... }, "|"), "PARTY", "Mira-Forever")
  end
  receive("HI", MIRA, "WANDERER", "1429", "Normal", "1.0.0")
  receive("PR", MIRA, "10", "40", "0")
  receive("RU", "deadbeef", "BROKE", "0", "90", "5", "OPPORTUNIST", "93", "1443")
  wow.fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
  wow.fire("CHAT_MSG_SYSTEM", "Mira has joined the party.")
  wow.advance(6)

  -- Campfire: half an hour later the player sits at a camp until its benefit comes; the chapter closes.
  wow.advance(1800)
  aura("WELCOME", true)
  wow.advance(60)
  aura("BENEFITS", true)
  aura("WELCOME", false)
  wow.advance(5)

  -- Knowledge: a new item in the bags, an equipment change, the bank, and the tooltip of an unheld item.
  wow.data.bags[0][2] = 2589
  wow.fire("BAG_UPDATE_DELAYED")
  wow.advance(1)
  wow.data.bags[0][2] = nil
  wow.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
  wow.fire("BANKFRAME_OPENED")
  GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  GameTooltip:SetItemByID(2592)
  wow.tooltip(Enum.TooltipDataType.Item, GameTooltip, C_TooltipInfo.GetItemByID(2592))
  assert.equal("", _G.GameTooltipTextLeft2:GetText())

  -- House: a chosen name, then the surname again.
  SlashCmdList.ASHMARK("house Stormhollow")
  SlashCmdList.ASHMARK("house reset")

  -- Mira leaves: the session ends and she becomes a contact; her tooltip and a note follow.
  wow.unit("party1", nil)
  wow.fire("GROUP_LEFT")
  wow.fire("GROUP_ROSTER_UPDATE")
  wow.advance(2)
  wow.unit("mouseover", { guid = MIRA, name = "Mira", isPlayer = true })
  GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  GameTooltip:SetUnit("mouseover")
  wow.tooltip(Enum.TooltipDataType.Unit, GameTooltip, { guid = MIRA })
  assert.equal(2, GameTooltip:NumLines())
  ns.Encounters:EditNote(MIRA)
  AshmarkDialog.EditBox:SetText("Kept us alive")
  wow.script(AshmarkDialog.Accept, "OnClick")

  -- Rumours: a zone change may repeat one rumour line.
  wow.state.map = 1414
  wow.fire("ZONE_CHANGED_NEW_AREA")
  wow.state.map = 1443
  wow.fire("ZONE_CHANGED_NEW_AREA")

  for _, id in ipairs(TAB_IDS) do
    ns.UI.MainFrame:Show(id)
    wow.advance(1)
  end

  local kinds = {}
  for entry in ns.Log:Iter(char, 1) do kinds[entry.k] = true end
  for _, kind in ipairs({ "quest.accept", "alliance", "violation", "kill.neutral", "rest.camp", "chapter",
                          "group.end", "contact", "peer", "rumour", "item.held" }) do
    assert.is_true(kinds[kind], kind)
  end
  assert.equal("Kept us alive", ns.Encounters:Contact(MIRA).note)
  local sent = {}
  for _, m in ipairs(wow.sent) do sent[m.text:match("^1|(%u+)|")] = true end
  assert.same({ HI = true, PR = true, RU = true }, sent)
  assert.is_true(#WorldMapFrame.pins > 0)

  for M in ns:Modules() do ns.Settings:Set(M.name .. ".enabled", false) end
  wow.advance(1)
  for M in ns:Modules() do assert.is_false(M.enabled, M.name) end
  for _, id in ipairs(TAB_IDS) do ns.UI.MainFrame:Show(id) end
  for M in ns:Modules() do ns.Settings:Set(M.name .. ".enabled", true) end
  wow.advance(1)
  for M in ns:Modules() do
    assert.is_true(M.enabled, M.name)
    assert.is_nil(M.unavailable, M.name)
  end
  for _, id in ipairs(TAB_IDS) do ns.UI.MainFrame:Show(id) end

  local raised = raisedChecks()
  wow.advance(11)
  assert.same({}, raised)
  return ns
end

return flow

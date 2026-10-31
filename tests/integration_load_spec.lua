local wow = require("tests.helpers.wow")

-- Integration of every unit's files: the two TOCs against section 2 of docs/ARCHITECTURE.md, and the
-- whole addon loaded in TOC order into one ns and run through its lifecycle in the mock client.

-- Section 2, in TOC load order.
local SECTION_2 = {
  "Core/Init.lua", "Core/Util.lua",
  "Locales/Locale.lua",
  "Locales/enUS/Core.lua", "Locales/enUS/Test.lua", "Locales/enUS/Conflicts.lua", "Locales/enUS/Profile.lua",
  "Locales/enUS/Map.lua", "Locales/enUS/Encounters.lua", "Locales/enUS/House.lua", "Locales/enUS/Campfire.lua",
  "Locales/enUS/Knowledge.lua", "Locales/enUS/Fiction.lua", "Locales/enUS/Rumours.lua",
  "Locales/deDE.lua", "Locales/frFR.lua", "Locales/esES.lua", "Locales/esMX.lua", "Locales/ptBR.lua",
  "Locales/ruRU.lua", "Locales/koKR.lua", "Locales/zhTW.lua", "Locales/zhCN.lua",
  "Core/Compat.lua", "Core/Safe.lua", "Core/Combat.lua", "Core/Events.lua", "Core/Bus.lua", "Core/DB.lua",
  "Core/Identity.lua", "Core/Where.lua", "Core/Names.lua", "Core/Log.lua", "Core/Watch.lua", "Core/Chronicle.lua",
  "Core/Comm.lua", "Core/Settings.lua", "Core/Slash.lua",
  "UI/Widgets.lua", "UI/MainFrame.lua", "UI/Dialog.lua", "UI/Notice.lua", "UI/ChatLine.lua", "UI/Compartment.lua",
  "Data/Conflicts.lua",
  "Modules/Conflicts/Conflicts.lua", "Modules/Conflicts/QuestDialog.lua",
  "Modules/Profile/Profile.lua",
  "Modules/Map/Map.lua", "Modules/Map/MapPins.xml",
  "Modules/Encounters/Encounters.lua", "Modules/Encounters/Tooltip.lua",
  "Modules/House/House.lua",
  "Modules/Campfire/Campfire.lua",
  "Modules/Knowledge/Knowledge.lua",
  "Modules/Fiction/Fiction.lua",
  "Modules/Rumours/Rumours.lua",
  "Modules/Traces/Traces.lua",
  "UI/Tabs/Chronicle.lua", "UI/Tabs/Decisions.lua", "UI/Tabs/Encounters.lua", "UI/Tabs/House.lua",
  "Dev/TestMode.lua", "Dev/Probe.lua",
}

-- With Core and Locales, which wow.load always takes, these are every folder the TOC loads from.
local ALL = { "UI", "Data", "Modules", "Dev" }
local SHIPPED = "Core Locales UI Data Modules Dev"

-- The globals of section 3.1, the only ones Ashmark may create.
local GLOBALS = {
  AshmarkDB = true, Ashmark_OnAddonCompartmentClick = true, Ashmark_OnAddonCompartmentEnter = true,
  Ashmark_OnAddonCompartmentLeave = true, SLASH_ASHMARK1 = true, SLASH_ASHMARK2 = true, AshmarkMapPinMixin = true,
  AshmarkFrame = true, AshmarkDialog = true, AshmarkNoticeFrame = true, AshmarkTestTooltip = true,
}

local TAB_IDS = { "chronicle", "decisions", "encounters", "house" }
local MIRA = "Player-1-00000002"

local function exists(path)
  local f = io.open(wow.ROOT .. path, "r")
  if f then f:close() end
  return f ~= nil
end

-- Header lines and file entries ("/" separated) of a TOC.
local function readToc(name)
  local headers, files = {}, {}
  for line in io.lines(wow.ROOT .. name) do
    line = line:gsub("\r", ""):gsub("%s+$", "")
    if line:match("^##") then
      headers[#headers + 1] = line
    elseif line ~= "" and not line:match("^#") then
      files[#files + 1] = (line:gsub("\\", "/"))
    end
  end
  return headers, files
end

local function withoutVariant(headers)
  local out = {}
  for _, line in ipairs(headers) do
    if not line:match("^## X%-TocVariant:") then out[#out + 1] = line end
  end
  return out
end

-- Every .lua and .xml file under the shipped folders, or nil where the shell cannot list them.
local function shippedFiles()
  if not io.popen then return nil end
  local cd = wow.ROOT ~= "" and ('cd "' .. wow.ROOT .. '" && ') or ""
  local pipe = io.popen(cd .. "find " .. SHIPPED .. ' -type f \\( -name "*.lua" -o -name "*.xml" \\) 2>/dev/null')
  if not pipe then return nil end
  local files = {}
  for line in pipe:lines() do files[#files + 1] = line end
  pipe:close()
  table.sort(files)
  return files
end

-- Taken before any test of this file loads the addon: wow.reset only clears globals named Ashmark*.
local BASELINE = {}
for name in pairs(_G) do BASELINE[name] = true end

-- A tooltip names its line font strings after itself (GameTooltipTemplate in the client, the mock's regions
-- here): AshmarkTestTooltipTextLeft1 belongs to AshmarkTestTooltip, GameTooltipTextLeft1 to the client.
local function tooltipLine(name)
  local owner = type(name) == "string" and name:match("^(.-)Text[LR][a-z]+%d+$")
  return owner ~= nil and (BASELINE[owner] or GLOBALS[owner]) == true
end

local function newGlobals()
  local out = {}
  for name in pairs(_G) do
    if not BASELINE[name] and not GLOBALS[name] and not tooltipLine(name) then out[#out + 1] = tostring(name) end
  end
  table.sort(out)
  return out
end

local function start()
  local ns = wow.load(ALL)
  wow.login()
  return ns
end

local function testRecord(id)
  SlashCmdList.ASHMARK("test")
  local tests = _G.AshmarkDB.dev.tests
  for _, r in ipairs(tests[#tests].results) do
    if r.id == id then return r end
  end
end

describe("Integration", function()
  before_each(function()
    wow.reset()
  end)

  describe("TOC files", function()
    it("list the files of section 2 in its order", function()
      local _, files = readToc("Ashmark_Forever.toc")
      assert.same(SECTION_2, files)
    end)

    it("differ only in X-TocVariant", function()
      local h1, f1 = readToc("Ashmark_Forever.toc")
      local h2, f2 = readToc("Ashmark_Camelot.toc")
      assert.same(f1, f2)
      assert.same(withoutVariant(h1), withoutVariant(h2))
      assert.is_true(tContains(h1, "## X-TocVariant: Forever"))
      assert.is_true(tContains(h2, "## X-TocVariant: Camelot"))
    end)

    it("are what the spec loader reads", function()
      assert.same(SECTION_2, wow.tocFiles())
    end)

    it("draw every file from Core, Locales or the folders the integration loads", function()
      for _, file in ipairs(SECTION_2) do
        local top = file:match("^([^/]+)/")
        assert.is_true(top == "Core" or top == "Locales" or tContains(ALL, top), file)
      end
    end)

    local listed = shippedFiles()
    if listed then
      it("list every file that exists in the shipped folders", function()
        local toc, unlisted = {}, {}
        for _, file in ipairs(SECTION_2) do toc[file] = true end
        for _, file in ipairs(listed) do
          if not toc[file] then unlisted[#unlisted + 1] = file end
        end
        assert.same({}, unlisted)
      end)
    else
      pending("listing the shipped folders needs io.popen")
    end
  end)

  describe("loader", function()
    it("loads every existing file in TOC order into one ns without error", function()
      local ns, failures, count = wow.ns, {}, 0
      for _, file in ipairs(wow.tocFiles()) do
        if not file:match("%.xml$") and exists(file) then
          local chunk, err = loadfile(wow.ROOT .. file)
          local ok = chunk ~= nil
          if ok then ok, err = pcall(chunk, wow.ADDON, ns) end
          if not ok then failures[#failures + 1] = file .. ": " .. tostring(err) end
          count = count + 1
        end
      end
      assert.same({}, failures)
      assert.is_true(count > 0)
      for _, name in ipairs({ "Compat", "Safe", "Combat", "Events", "Bus", "DB", "Identity", "Names", "Log",
                              "Watch", "Chronicle", "Comm", "Settings", "Slash", "Locale", "L", "Util", "Test" }) do
        assert.is_not_nil(ns[name], name)
      end
      assert.is_function(getmetatable(ns.Where).__call)
      for _, name in ipairs({ "MainFrame", "Notice", "ChatLine" }) do assert.is_table(ns.UI[name], name) end
      assert.is_table(ns.Data.Conflicts)
      assert.is_table(ns.TestMode)
      assert.is_table(ns.Probe)
    end)

    it("keeps every module in TOC order with its setting registered", function()
      local ns = wow.load(ALL)
      for M in ns:Modules() do
        assert.equal(M, ns[M.name])
        assert.equal(M, ns:GetModule(M.name))
        assert.is_not_nil(ns.Settings.defs[M.name .. ".enabled"], M.name)
      end
    end)
  end)

  describe("with every file loaded", function()
    it("runs the lifecycle, the watchers and the slash commands without an error", function()
      local ns = start()
      assert.is_true(ns.ready)
      assert.is_table(ns.DB:Char())
      assert.is_not_nil(ns.Settings.category)
      for M in ns:Modules() do
        assert.is_nil(M.unavailable, M.name)
        assert.is_true(M.enabled, M.name)
        assert.same({}, M.missingEvents or {}, M.name)
      end
      wow.data.quests[1382] = { inLog = true }
      wow.fire("QUEST_ACCEPTED", 1382)
      wow.state.map = 1443
      wow.fire("ZONE_CHANGED_NEW_AREA")
      wow.state.money = wow.state.money + 100
      wow.fire("QUEST_TURNED_IN", 1382, 0, 100)
      wow.fire("PLAYER_MONEY")
      wow.fire("PLAYER_LEVEL_UP", 21)
      SlashCmdList.ASHMARK("help")
      SlashCmdList.ASHMARK("probe")
      wow.advance(60)
      ns.UI.Notice:Show("Chapter I closes")
      ns.UI.ChatLine:Print("A line", "rumour")
      wow.advance(5)
      assert.same({}, wow.errors)
      assert.is_true(ns.Log:Seq(ns.DB:Char()) >= 4)
    end)

    it("keeps its record through a /reload", function()
      local ns = start()
      wow.state.map = 1443
      wow.fire("ZONE_CHANGED_NEW_AREA")
      local seq = ns.Log:Seq(ns.DB:Char())
      ns = wow.reload()
      assert.equal(seq, ns.Log:Seq(ns.DB:Char()))
      assert.same({}, wow.errors)
    end)

    it("creates no globals beyond those of section 3.1", function()
      start()
      SlashCmdList.ASHMARK("probe")
      wow.advance(60)
      assert.same({}, newGlobals())
    end)

    it("opens every tab, toggles the window and runs the test mode across a /reload without an error", function()
      local ns = start()
      SlashCmdList.ASHMARK("")
      assert.is_true(AshmarkFrame:IsShown())
      for _, id in ipairs(TAB_IDS) do ns.UI.MainFrame:Show(id) end
      wow.fire("QUEST_TURNED_IN", 1382, 0, 0)
      wow.advance(1)
      SlashCmdList.ASHMARK("")
      assert.is_false(AshmarkFrame:IsShown())
      assert.is_nil(testRecord("Core.savedVariables").ok)
      wow.advance(11)
      wow.reload()
      assert.is_true(testRecord("Core.savedVariables").ok)
      wow.advance(11)
      assert.same({}, wow.errors)
      assert.same({}, newGlobals())
    end)

    it("plays every module's main events with every tab open, then switches each module off and on", function()
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
      local ns = start()
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

      local raised = {}
      SlashCmdList.ASHMARK("test")
      local tests = _G.AshmarkDB.dev.tests
      for _, r in ipairs(tests[#tests].results) do
        if type(r.detail) == "string" and r.detail:match("^error") then raised[#raised + 1] = r.id end
      end
      wow.advance(11)
      assert.same({}, raised)
      assert.same({}, wow.errors)
      assert.same({}, newGlobals())
    end)
  end)
end)

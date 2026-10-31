local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.map_mock")

local DESOLACE, MICRO, DUNGEON, DUROTAR = 1443, 9002, 9001, 1411
local KALIMDOR, EASTERN_KINGDOMS, AZEROTH, COSMIC = 1414, 1415, 947, 946

describe("Map", function()
  local ns

  local function boot(opts)
    ns = mock.boot(wow, opts)
    return ns.DB:Char()
  end

  local function at(m, x, y)
    wow.state.map = m
    wow.state.pos = x and { x = x, y = y } or nil
  end

  local function violation(c)
    return ns.Log:Add("violation", { c = c or "clan_choice", side = "B", q = 2001 })
  end

  local function kinds()
    local out = {}
    for i, pin in ipairs(mock.pins()) do out[i] = pin.kind .. (pin.state and (":" .. pin.state) or "") end
    return out
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("provider", function()
    it("is added at login and removed and added again with the setting", function()
      boot()
      local provider = mock.provider()
      assert.is_table(provider)
      assert.equal(WorldMapFrame, provider:GetMap())
      ns.Settings:Set("Map.enabled", false)
      assert.is_nil(mock.provider())
      assert.is_nil(provider:GetMap())
      ns.Settings:Set("Map.enabled", true)
      assert.equal(provider, mock.provider())
    end)

    it("is added and removed only out of combat", function()
      boot()
      wow.combat(true)
      ns.Settings:Set("Map.enabled", false)
      assert.is_table(mock.provider())
      wow.combat(false)
      assert.is_nil(mock.provider())
    end)

    it("keeps the module off without a map canvas, and the file loads without one", function()
      wow.stub("WorldMapFrame.AddDataProvider", nil)
      wow.stub("MapCanvasPinMixin", nil)
      wow.stub("MapCanvasDataProviderMixin", nil)
      boot()
      assert.same({ "mapPins" }, ns.Map.unavailable)
      assert.is_false(ns.Map.enabled)
      assert.is_table(AshmarkMapPinMixin)
      assert.is_nil(next(WorldMapFrame.providers))
    end)

    it("removes its pins before it draws and draws nothing while off", function()
      boot()
      mock.open(wow, DESOLACE)
      mock.open(wow, DESOLACE)
      assert.equal(2, #mock.pins())
      local provider = mock.provider()
      ns.Map.enabled = false
      provider:RefreshAllData()
      assert.same({}, mock.pins())
    end)
  end)

  describe("zone and smaller maps", function()
    it("pin the conflicts anchored on the map, in their state", function()
      local char = boot()
      mock.open(wow, DESOLACE)
      assert.same({
        { kind = "anchor", state = "open", atlas = ns.Map.ATLAS.open, x = 0.55, y = 0.45 },
        { kind = "anchor", state = "open", atlas = ns.Map.ATLAS.open, x = 0.2, y = 0.8 },
      }, mock.pins())
      mock.ally(char, "clan_choice", "A")
      mock.ally(char, "grove", "B", 1)
      mock.open(wow, DESOLACE)
      assert.same({ "anchor:allied", "anchor:broken" }, kinds())
      assert.equal(ns.Map.ATLAS.allied, mock.pins()[1].atlas)
      assert.equal(ns.Map.ATLAS.broken, mock.pins()[2].atlas)
    end)

    it("pin violations and closed chapters on their zone, translating those from maps inside it", function()
      boot()
      at(DESOLACE, 0.25, 0.75)
      violation()
      at(MICRO, 0.5, 0.5)
      ns.Log:Add("level", { l = 21 })
      ns.Log:CloseChapter({})
      at(DUROTAR, 0.1, 0.1)
      violation()
      mock.open(wow, DESOLACE)
      local pins = mock.pins()
      assert.same({ "anchor:open", "anchor:open", "violation", "chapter" }, kinds())
      assert.same({ 0.25, 0.75, ns.Map.ATLAS.violation }, { pins[3].x, pins[3].y, pins[3].atlas })
      assert.same({ 0.55, 0.25, ns.Map.ATLAS.chapter }, { pins[4].x, pins[4].y, pins[4].atlas })
      mock.open(wow, MICRO)
      assert.same({ { kind = "chapter", atlas = ns.Map.ATLAS.chapter, x = 0.5, y = 0.5 } }, mock.pins())
      mock.open(wow, DUROTAR)
      assert.same({ "violation" }, kinds())
    end)

    it("skip entries without a position and those inside instances", function()
      boot()
      at(DESOLACE)
      violation()
      wow.state.instance = { name = "Maraudon", type = "party", instanceID = 349 }
      at(DESOLACE, 0.4, 0.4)
      violation()
      wow.state.instance = nil
      mock.open(wow, DESOLACE)
      assert.same({ "anchor:open", "anchor:open" }, kinds())
    end)

    it("include dungeon and orphan maps", function()
      boot()
      at(DUNGEON, 0.3, 0.3)
      violation()
      mock.open(wow, DUNGEON)
      assert.same({ "violation" }, kinds())
    end)

    it("leave out maps inside the zone the client cannot place", function()
      boot()
      wow.data.mapRects[MICRO] = { [DESOLACE] = { 0, 0, 0, 0 } }
      at(MICRO, 0.5, 0.5)
      violation()
      mock.open(wow, DESOLACE)
      assert.same({ "anchor:open", "anchor:open" }, kinds())
    end)
  end)

  describe("continent maps", function()
    it("pin conflict anchors through GetMapRectOnMap and skip zones the client cannot place", function()
      local char = boot()
      at(DESOLACE, 0.25, 0.75)
      violation()
      mock.ally(char, "clan_choice", "A")
      mock.open(wow, KALIMDOR)
      assert.same({
        { kind = "anchor", state = "allied", atlas = ns.Map.ATLAS.allied, x = 0.41, y = 0.635 },
        { kind = "anchor", state = "open", atlas = ns.Map.ATLAS.open, x = 0.34, y = 0.74 },
      }, mock.pins())
      mock.open(wow, EASTERN_KINGDOMS)
      assert.same({ { kind = "anchor", state = "open", atlas = ns.Map.ATLAS.open, x = 0.46, y = 0.78 } }, mock.pins())
    end)
  end)

  describe("world and cosmic maps", function()
    it("show no pins, nor maps the client does not know or keeps secret", function()
      boot()
      at(DESOLACE, 0.25, 0.75)
      violation()
      for _, m in ipairs({ AZEROTH, COSMIC, 123456 }) do
        mock.open(wow, m)
        assert.same({}, mock.pins(), tostring(m))
      end
      mock.open(wow, wow.secret(DESOLACE))
      assert.same({}, mock.pins())
      wow.stub("C_Map.GetMapInfo", function() return wow.secret({ mapType = 3 }) end)
      mock.open(wow, DESOLACE)
      assert.same({}, mock.pins())
    end)
  end)

  describe("refreshes", function()
    local acquired

    local function countAcquires()
      acquired = 0
      local acquire = WorldMapFrame.AcquirePin
      wow.stub("WorldMapFrame.AcquirePin", function(...)
        acquired = acquired + 1
        return acquire(...)
      end)
    end

    it("redraw a shown map after a new violation or chapter, at most once per half second", function()
      boot()
      mock.open(wow, DESOLACE)
      at(DESOLACE, 0.25, 0.75)
      violation()
      ns.Log:Add("level", { l = 21 })
      ns.Log:CloseChapter({})
      assert.equal(2, #mock.pins())
      countAcquires()
      wow.advance(0.5)
      assert.same({ "anchor:open", "anchor:open", "violation", "chapter" }, kinds())
      assert.equal(4, acquired)
    end)

    it("redraw a shown map on ALLIANCE_FORMED and ALLIANCE_BROKEN", function()
      local char = boot()
      mock.open(wow, DESOLACE)
      mock.ally(char, "clan_choice", "A")
      ns.Bus:Fire("ALLIANCE_FORMED", "clan_choice", "A", false)
      wow.advance(0.5)
      assert.same({ "anchor:allied", "anchor:open" }, kinds())
      mock.ally(char, "clan_choice", "B", 1)
      ns.Bus:Fire("ALLIANCE_BROKEN", "clan_choice", "B", 2001)
      wow.advance(0.5)
      assert.same({ "anchor:broken", "anchor:open" }, kinds())
    end)

    it("leave a hidden map alone and ignore other entries", function()
      boot()
      mock.open(wow, DESOLACE)
      countAcquires()
      ns.Log:Add("level", { l = 21 })
      wow.advance(1)
      assert.equal(0, acquired)
      mock.close(wow)
      at(DESOLACE, 0.25, 0.75)
      violation()
      wow.advance(1)
      assert.equal(0, acquired)
      mock.open(wow, DESOLACE)
      assert.same({ "anchor:open", "anchor:open", "violation" }, kinds())
    end)

    it("acquire no pins in combat and catch up on a shown map when combat ends", function()
      boot()
      wow.combat(true)
      mock.open(wow, DESOLACE)
      assert.same({}, mock.pins())
      assert.is_true(mock.provider().dirty)
      wow.combat(false)
      assert.equal(2, #mock.pins())
      assert.is_nil(mock.provider().dirty)
    end)

    it("wait for combat to end before a queued redraw, and skip it once the map is closed", function()
      boot()
      mock.open(wow, DESOLACE)
      wow.combat(true)
      at(DESOLACE, 0.25, 0.75)
      violation()
      wow.advance(1)
      assert.equal(2, #mock.pins())
      wow.combat(false)
      assert.equal(3, #mock.pins())
      wow.combat(true)
      mock.open(wow, DESOLACE)
      mock.close(wow)
      countAcquires()
      wow.combat(false)
      assert.equal(0, acquired)
    end)

    it("rebuild the positions after LOG_COMPACTED and after a /reload", function()
      local char = boot()
      at(DESOLACE, 0.25, 0.75)
      violation()
      at(DESOLACE, 0.6, 0.6)
      violation()
      mock.open(wow, DESOLACE)
      assert.equal(4, #mock.pins())
      table.remove(char.log, 1)
      ns.Bus:Fire("LOG_COMPACTED", char)
      mock.open(wow, DESOLACE)
      assert.equal(3, #mock.pins())
      ns = wow.reload()
      mock.conflicts(ns)
      mock.open(wow, DESOLACE)
      assert.same({ "anchor:open", "anchor:open", "violation" }, kinds())
      assert.same({ 0.6, 0.6 }, { mock.pins()[3].x, mock.pins()[3].y })
    end)

    it("count an error while drawing against Map without breaking the canvas", function()
      boot()
      wow.stub("WorldMapFrame.AcquirePin", function() error("boom") end)
      assert.has_no.errors(function() mock.open(wow, DESOLACE) end)
      assert.equal(1, #wow.errors)
      assert.truthy(wow.errors[1]:find("Map", 1, true))
      wow.errors = {}
    end)
  end)

  describe("pins", function()
    it("inherit the canvas pin", function()
      boot()
      assert.equal(MapCanvasPinMixin.SetPosition, AshmarkMapPinMixin.SetPosition)
      assert.is_true(AshmarkMapPinMixin:DisableInheritedMotionScriptsWarning())
      mock.open(wow, DESOLACE)
      local pin = mock.pin(1)
      assert.equal("PIN_FRAME_LEVEL_AREA_POI", pin.frameLevelType)
      assert.equal("clan_choice", pin.info.conflict.id)
    end)

    it("let right clicks through to the canvas, set up out of combat only, so the map still zooms out", function()
      local passed = mock.passthrough(wow)
      boot()
      assert.is_nil(AshmarkMapPinMixin.SetPassThroughButtons)
      mock.open(wow, DESOLACE)
      assert.same({ { "RightButton", false }, { "RightButton", false } }, passed)
      wow.combat(true)
      mock.open(wow, DESOLACE)
      assert.equal(2, #passed)
      wow.combat(false)
      assert.equal(2, #mock.pins())
      assert.same({ { "RightButton", false }, { "RightButton", false } }, { passed[3], passed[4] })
    end)

    it("name both sides and the state of a conflict in the tooltip", function()
      local char = boot()
      mock.open(wow, DESOLACE)
      local pin = mock.pin(1)
      pin:OnMouseEnter()
      assert.equal(pin, GameTooltip:GetOwner())
      assert.is_true(GameTooltip:IsShown())
      assert.same({ "Gelkis Alliance: Gelkis Clan Centaur or Magram Clan Centaur", "You have taken no side here." },
        mock.tooltip())
      pin:OnMouseLeave()
      assert.is_false(GameTooltip:IsShown())
      mock.ally(char, "clan_choice", "A")
      mock.ally(char, "grove", "B", 2)
      mock.open(wow, DESOLACE)
      mock.pin(1):OnMouseEnter()
      assert.same({ "Gelkis Alliance: Gelkis Clan Centaur or Magram Clan Centaur",
                    "You stand with Gelkis Clan Centaur." }, mock.tooltip())
      mock.pin(2):OnMouseEnter()
      assert.same({ "Grove Keepers: Gelkis Clan Centaur or those without a banner",
                    "You stand with those without a banner, and broke your word here 2×." }, mock.tooltip())
    end)

    it("join the sides with MAP_PIN_SIDES_VOWEL before the sound /o/, and name an untitled conflict", function()
      boot({ setup = function(n) n.Locale:Base().MAP_PIN_SIDES_VOWEL = "{title}: {a} u {b}" end })
      wow.data.factions[93].name = "Orden de Magram"
      ns.Conflicts.Title = function(_, c) if c.id ~= "grove" then return mock.TITLES[c.id] end end
      mock.open(wow, DESOLACE)
      mock.pin(1):OnMouseEnter()
      assert.equal("Gelkis Alliance: Gelkis Clan Centaur u Orden de Magram", mock.tooltip()[1])
      mock.pin(2):OnMouseEnter()
      assert.equal("a quest: Gelkis Clan Centaur or those without a banner", mock.tooltip()[1])
    end)

    it("tell the chronicle's sentence for a violation and the date for a chapter", function()
      boot()
      at(DESOLACE, 0.25, 0.75)
      local entry = violation()
      ns.Log:CloseChapter({})
      mock.open(wow, DESOLACE)
      mock.pin(3):OnMouseEnter()
      assert.same({ "Here you broke your word", "Broke faith in clan_choice.", date("%Y-%m-%d", entry.t) },
        mock.tooltip())
      mock.pin(4):OnMouseEnter()
      assert.same({ "Chapter I", "Closed here on " .. date("%Y-%m-%d", entry.t) }, mock.tooltip())
    end)

    it("show no tooltip while the module is off", function()
      boot()
      mock.open(wow, DESOLACE)
      local pin = mock.pin(1)
      ns.Settings:Set("Map.enabled", false)
      pin:OnMouseEnter()
      assert.is_false(GameTooltip:IsShown())
    end)
  end)

  describe("test checks", function()
    it("find the atlases, the pin template and the provider, and count the anchored conflicts", function()
      mock.template(wow)
      boot()
      assert.same({ true, "all 5" }, { mock.check(ns, "Map.atlases") })
      assert.same({ true, "Frame" }, { mock.check(ns, "Map.template") })
      assert.same({ true, "3 of 4 conflicts have an anchor" }, { mock.check(ns, "Map.anchors") })
      assert.same({ true, "added to WorldMapFrame" }, { mock.check(ns, "Map.provider") })
    end)

    it("skip the anchor count when no conflict has an anchor, as in the shipped data so far", function()
      boot({ files = { "Modules/Map", "Data" }, setup = function(n) mock.conflicts(n, n.Data.Conflicts.list) end })
      local count = ns.Data.Conflicts.count
      assert.is_true(count > 0)
      -- Fails once the data gets anchors: then MAP_MODULE_DESC promises conflict marks again.
      assert.same({ nil, "0 of " .. count .. " conflicts have an anchor" }, { mock.check(ns, "Map.anchors") })
      ns.Conflicts = nil
      assert.same({ nil, "no conflicts" }, { mock.check(ns, "Map.anchors") })
    end)

    it("name what is missing", function()
      wow.data.missingAtlases.XMarksTheSpot = true
      wow.data.missingTemplates[mock.TEMPLATE] = true
      boot()
      assert.same({ false, "missing: broken XMarksTheSpot" }, { mock.check(ns, "Map.atlases") })
      assert.same({ false, "missing" }, { mock.check(ns, "Map.template") })
      ns.Settings:Set("Map.enabled", false)
      assert.same({ nil, "off" }, { mock.check(ns, "Map.provider") })
    end)

    it("fail a template that comes without the mixin", function()
      boot()
      assert.same({ false, "Frame without the mixin or its icon" }, { mock.check(ns, "Map.template") })
    end)
  end)

  describe("MapPins.xml", function()
    local function read()
      local f = assert(io.open(wow.ROOT .. "Modules/Map/MapPins.xml", "r"))
      local text = f:read("*a")
      f:close()
      return text
    end

    it("declares the pin template on the mixin and calls only methods the mixin has", function()
      boot()
      local xml = read()
      assert.truthy(xml:find('<Ui xmlns="http://www.blizzard.com/wow/ui/"', 1, true))
      assert.truthy(xml:find('name="AshmarkMapPinTemplate" mixin="AshmarkMapPinMixin" virtual="true"', 1, true))
      assert.truthy(xml:find('parentKey="Icon"', 1, true))
      local methods = {}
      for method in xml:gmatch('method="(%w+)"') do
        methods[#methods + 1] = method
        assert.is_function(AshmarkMapPinMixin[method], method)
      end
      assert.same({ "OnLoad", "OnMouseEnter", "OnMouseLeave" }, methods)
    end)
  end)
end)

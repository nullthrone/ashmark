local _, ns = ...

-- Module 3 (7.3): a private layer on the world map, drawn through a map data provider. Conflict anchors
-- in the state this character left them, the places where it broke its word and where its chapters
-- closed. The pin template is MapPins.xml; it names AshmarkMapPinMixin, so the TOC loads this file first.
local M = ns:NewModule("Map", {
  requires = { "map", "mapPins" },
  locale = "MAP",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local TEMPLATE = "AshmarkMapPinTemplate"
local CONTINENT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
local REFRESH_DELAY = 0.5
local EMPTY = {}

-- Blizzard atlases; the test mode checks that the client has them (7.10).
M.ATLAS = {
  open = "worldquest-icon-pvp-ffa",       -- a conflict without a side taken
  allied = "CrossedFlags",                -- a side taken and kept
  broken = "XMarksTheSpot",               -- a side taken after the word was broken there
  violation = "poi-graveyard-neutral",    -- where the word was broken
  chapter = "VignetteEvent",              -- where a chapter closed
}
local ATLAS_KEYS = { "open", "allied", "broken", "violation", "chapter" }

-- Another unit's public service (3.8), looked up at call time; nil if the unit or the call is missing.
local function conflicts(method, ...)
  local service = ns.Conflicts
  local ok, a, b = Safe.Call(service and service[method], service, ...)
  if ok then return a, b end
end

-- Tooltips -------------------------------------------------------------------
-- Filled from the pin's info, stored data and ns.Names only.

local function day(t)
  if type(t) ~= "number" then return nil end
  local d = date("*t", t)
  if type(FormatShortDate) == "function" then return FormatShortDate(d.day, d.month, d.year % 100) end
  return date("%Y-%m-%d", t)
end

local function sideName(conflict, side)
  local s = type(conflict) == "table" and conflict[side]
  local f = type(s) == "table" and s.faction or nil
  if f == 0 then return L.CONFLICT_UNNAMED end
  return ns.Names.Faction(f)
end

local function title(text, colour)
  GameTooltip:SetText(text, colour:GetRGB())
end

local function line(text, colour)
  local r, g, b = colour:GetRGB()
  GameTooltip:AddLine(text, r, g, b, true)
end

local function anchorTooltip(info, char)
  local conflict, sex = info.conflict, char and char.sex
  title(ns.Format(L.MAP_PIN_SIDES, { a = sideName(conflict, "A"), b = sideName(conflict, "B") }), HIGHLIGHT_FONT_COLOR)
  if info.state == "open" then
    line(ns.Gender("MAP_PIN_OPEN", sex), NORMAL_FONT_COLOR)
    return
  end
  local broken = info.state == "broken"
  line(ns.Format(ns.Gender(broken and "MAP_PIN_BROKEN" or "MAP_PIN_ALLIED", sex), {
    faction = sideName(conflict, info.side), count = info.broken,
  }), broken and RED_FONT_COLOR or NORMAL_FONT_COLOR)
end

-- The chronicle's own sentence for the violation, so the wording decided at write time (o) is kept.
local function violationTooltip(info, char)
  title(L.MAP_PIN_VIOLATION, RED_FONT_COLOR)
  local text = ns.Chronicle:Render(info.source, { char = char, own = true })
  if text then line(text, HIGHLIGHT_FONT_COLOR) end
  local when = day(info.source.t)
  if when then line(when, GRAY_FONT_COLOR) end
end

local function chapterTooltip(info)
  title(ns.Format(L.MAP_PIN_CHAPTER, { roman = ns.Util.Roman(info.source.no) }), HIGHLIGHT_FONT_COLOR)
  local when = day(info.source.closed)
  if when then line(ns.Format(L.MAP_PIN_CHAPTER_CLOSED, { date = when }), NORMAL_FONT_COLOR) end
end

local TOOLTIPS = { anchor = anchorTooltip, violation = violationTooltip, chapter = chapterTooltip }

local function showTooltip(pin)
  local info = pin.info
  local fill = type(info) == "table" and TOOLTIPS[info.kind]
  if not fill then return end
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  fill(info, M:Char())
  GameTooltip:Show()
end

-- Pins -----------------------------------------------------------------------

-- Without the map canvas (no mapPins) the module stays off; the mixin only has to exist for the XML.
AshmarkMapPinMixin = CreateFromMixins(MapCanvasPinMixin or {})

function AshmarkMapPinMixin:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function AshmarkMapPinMixin:OnAcquired(info)
  self.info = info
  self.Icon:SetAtlas(info.atlas)
  self:SetPosition(info.x, info.y)
end

-- The template sets OnEnter and OnLeave itself. The canvas asserts that a new pin has no motion scripts
-- unless the pin opts out here, and then installs these same two methods.
function AshmarkMapPinMixin:DisableInheritedMotionScriptsWarning()
  return true
end

AshmarkMapPinMixin.OnMouseEnter = M:Wrap("pin:tooltip", showTooltip)

function AshmarkMapPinMixin:OnMouseLeave()
  GameTooltip:Hide()
end

-- Empty override: the real call is restricted in combat.
function AshmarkMapPinMixin:SetPassThroughButtons() end

-- Positions ------------------------------------------------------------------

-- [mapId] = { { kind, m, x, y, source }, ... }: violation entries and chapter records that have a
-- position, filed under their own map and under its zone; x, y are 0..1 on m. Built on first use.
local cache

local function positioned(kind, source)
  if type(source) ~= "table" then return nil end
  local m, x, y = source.m, source.x, source.y
  if type(m) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
  return { kind = kind, m = m, x = x / 100, y = y / 100, source = source }
end

local function file(t, m, item)
  local list = t[m]
  if not list then
    list = {}
    t[m] = list
  end
  list[#list + 1] = item
end

local function remember(t, kind, source)
  local item = positioned(kind, source)
  if not item then return end
  file(t, item.m, item)
  local zone = ns.Where.Zone(item.m)
  if zone and zone ~= item.m then file(t, zone, item) end
end

local function build(char)
  local t = {}
  if type(char) ~= "table" then return t end
  for entry in ns.Log:Iter(char, 1) do
    if entry.k == "violation" then remember(t, "violation", entry) end
  end
  for _, chapter in ipairs(type(char.chapters) == "table" and char.chapters or EMPTY) do
    remember(t, "chapter", chapter)
  end
  return t
end

local function positions()
  if not cache then cache = build(M:Char()) end
  return cache
end

-- Placement ------------------------------------------------------------------

-- x, y (0..1 on map m) on map shown; nil where the client places m nowhere on it.
local function onMap(m, shown, x, y)
  if m == shown then return x, y end
  local ok, minX, maxX, minY, maxY = Safe.Call(C_Map.GetMapRectOnMap, m, shown)
  if ok and type(minX) == "number" and type(maxX) == "number" and type(minY) == "number"
    and type(maxY) == "number" and maxX > minX and maxY > minY then
    return minX + x * (maxX - minX), minY + y * (maxY - minY)
  end
end

local function mapType(shown)
  local ok, info = Safe.Call(C_Map.GetMapInfo, shown)
  local kind = ok and Safe.Field(info, "mapType")
  if type(kind) == "number" then return kind end
end

local function anchorOf(conflict)
  local a = type(conflict) == "table" and conflict.anchor
  if type(a) == "table" and type(a.m) == "number" and type(a.x) == "number" and type(a.y) == "number" then
    return a
  end
end

local function brokenCount(char, id)
  local rec = type(char) == "table" and char.conflicts
  local broken = type(rec) == "table" and rec.broken
  local n = type(broken) == "table" and broken[id]
  return type(n) == "number" and n or 0
end

-- Anchor states: open without an alliance, broken once the word was broken there, allied otherwise.
local function anchorPin(char, conflict, x, y)
  local side = conflicts("Alliance", char, conflict.id)
  local broken = brokenCount(char, conflict.id)
  local state = broken > 0 and "broken" or side and "allied" or "open"
  return { x = x, y = y, atlas = M.ATLAS[state], kind = "anchor", conflict = conflict, state = state, side = side,
           broken = broken }
end

-- Continent maps: conflict anchors, placed through their map's rectangle. Zone and smaller maps: anchors
-- on this map, and violations and chapters on it or on maps inside it. World and cosmic maps: nothing.
local function pinsFor(shown)
  local out = {}
  local kind = mapType(shown)
  if not kind or kind < CONTINENT then return out end
  local char = M:Char()
  local continent = kind == CONTINENT
  local list = continent and conflicts("All") or conflicts("InZone", shown)
  for _, conflict in ipairs(type(list) == "table" and list or EMPTY) do
    local a = anchorOf(conflict)
    if a and (continent or a.m == shown) then
      local x, y = onMap(a.m, shown, a.x, a.y)
      if x then out[#out + 1] = anchorPin(char, conflict, x, y) end
    end
  end
  if continent then return out end
  for _, item in ipairs(positions()[shown] or EMPTY) do
    local x, y = onMap(item.m, shown, item.x, item.y)
    if x then out[#out + 1] = { x = x, y = y, atlas = M.ATLAS[item.kind], kind = item.kind, source = item.source } end
  end
  return out
end

-- Provider -------------------------------------------------------------------

local provider = CreateFromMixins(MapCanvasDataProviderMixin or {})

function provider:RemoveAllData()
  self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

-- Wrapped, so an error counts against Map and never breaks the canvas' refresh of other providers.
local acquire = M:Wrap("map:pins", function(map)
  local shown = Safe.Value(map:GetMapID())
  if type(shown) ~= "number" then return end
  for _, info in ipairs(pinsFor(shown)) do
    map:AcquirePin(TEMPLATE, info)
  end
end)

function provider:RefreshAllData()
  self:RemoveAllData()
  if not M.enabled then return end
  -- Pins are never acquired in combat (1.5); PLAYER_REGEN_ENABLED catches up on a shown map.
  if InCombatLockdown() then
    self.dirty = true
    return
  end
  self.dirty = nil
  acquire(self:GetMap())
end

local function attach(on)
  ns.Combat.Run("map:provider", function()
    if (provider:GetMap() ~= nil) == on then return end
    if on then
      WorldMapFrame:AddDataProvider(provider)
    else
      WorldMapFrame:RemoveDataProvider(provider)
    end
  end)
end

local function redraw()
  if provider:GetMap() and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local queueRedraw = M:Wrap("map:refresh", function() ns.Combat.Run("map:refresh", redraw) end)

-- A shown map only, at most once per REFRESH_DELAY (3.9).
local function refresh()
  ns.Util.Debounce("Map.refresh", REFRESH_DELAY, queueRedraw)
end

local function onRegen()
  if provider.dirty and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function onLogAdded(_, _, entry, char)
  local kind = entry.k
  if kind ~= "violation" and kind ~= "chapter" then return end
  -- Without a cache the next build reads the entry from the log.
  if cache then
    remember(cache, kind, kind == "violation" and entry or (char.chapters or EMPTY)[entry.no])
  end
  refresh()
end

local function onCompacted(_, _, char)
  cache = build(char)
end

-- Test checks (7.10) ---------------------------------------------------------------

local function checkAtlases()
  local missing = {}
  for _, key in ipairs(ATLAS_KEYS) do
    local ok, info = Safe.Call(C_Texture and C_Texture.GetAtlasInfo, M.ATLAS[key])
    if not (ok and info) then missing[#missing + 1] = key .. " " .. M.ATLAS[key] end
  end
  if #missing > 0 then return false, "missing: " .. table.concat(missing, ", ") end
  return true, "all " .. #ATLAS_KEYS
end

-- A pin outside the map proves the XML loaded with the mixin; frames cannot be destroyed, so it is built
-- once per session.
local template

local function buildTemplate()
  local ok, info = Safe.Call(C_XMLUtil.GetTemplateInfo, TEMPLATE)
  local kind = ok and Safe.Field(info, "type")
  if type(kind) ~= "string" then return false, "missing" end
  local made, pin = pcall(CreateFrame, kind, nil, UIParent, TEMPLATE)
  if not made then return false, kind .. ": " .. tostring(pin) end
  pin:Hide()
  if pin.OnAcquired ~= AshmarkMapPinMixin.OnAcquired or not pin.Icon then
    return false, kind .. " without the mixin or its icon"
  end
  return true, kind
end

local function checkTemplate()
  if not ns.Compat.Has.xmlInfo then return nil, "no C_XMLUtil.GetTemplateInfo" end
  template = template or { buildTemplate() }
  return template[1], template[2]
end

local function checkProvider()
  if M.unavailable then return false, "unavailable: " .. table.concat(M.unavailable, ", ") end
  if not M.enabled then return nil, "off" end
  local added = provider:GetMap() == WorldMapFrame
  return added, added and "added to WorldMapFrame" or "not added"
end

-- Lifecycle ------------------------------------------------------------------------

function M:OnInitialize()
  ns.Test:Register("Map.atlases", checkAtlases)
  ns.Test:Register("Map.template", checkTemplate)
  ns.Test:Register("Map.provider", checkProvider)
end

function M:OnEnable()
  self:Subscribe("LOG_ADDED", onLogAdded)
  self:Subscribe("LOG_COMPACTED", onCompacted)
  self:Subscribe("ALLIANCE_FORMED", refresh)
  self:Subscribe("ALLIANCE_BROKEN", refresh)
  self:RegisterEvent("PLAYER_REGEN_ENABLED", onRegen)
  attach(true)
end

function M:OnWorldReady()
  cache = build(self:Char())
end

function M:OnDisable()
  attach(false)
end

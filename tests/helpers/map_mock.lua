-- Fixtures for the Map specs (not shipped): a stand-in for the Conflicts service (3.8) with a small
-- dataset in the shape of 7.1, map rectangles, the pin template as MapPins.xml builds it, and the world
-- map canvas calling the provider the way Blizzard's does.
local mock = {}

mock.FILES = { "Modules/Map" }
mock.TEMPLATE = "AshmarkMapPinTemplate"

-- clan_choice and grove are anchored in Desolace (grove belongs to Shen'dralas), coast in Stranglethorn
-- Vale on the other continent; bare has no anchor.
function mock.data()
  return {
    { id = "clan_choice", zone = 1443, theme = "feud",
      A = { faction = 92, quests = { 1001 } }, B = { faction = 93, quests = { 2001 } },
      anchor = { m = 1443, x = 0.55, y = 0.45 } },
    { id = "grove", zone = 2652, theme = "nature",
      A = { faction = 92, quests = { 5001 } }, B = { faction = 0, quests = { 6001 } },
      anchor = { m = 1443, x = 0.2, y = 0.8 } },
    { id = "coast", zone = 1434, theme = "trade",
      A = { faction = 21, quests = { 3001 } }, B = { faction = 87, quests = { 4001 } },
      anchor = { m = 1434, x = 0.3, y = 0.6 } },
    { id = "bare", zone = 1411, theme = "other",
      A = { faction = 21, quests = { 7001 } }, B = { faction = 87, quests = { 8001 } } },
  }
end

-- Rectangles [child][parent] = { minX, maxX, minY, maxY }: Desolace on Kalimdor, Stranglethorn on the
-- Eastern Kingdoms, the micro map 9002 inside Desolace.
function mock.rects(wow)
  wow.data.mapRects[1443] = { [1414] = { 0.3, 0.5, 0.5, 0.8 } }
  wow.data.mapRects[1434] = { [1415] = { 0.4, 0.6, 0.6, 0.9 } }
  wow.data.mapRects[9002] = { [1443] = { 0.5, 0.6, 0.2, 0.3 } }
end

-- ns.Conflicts with the public calls Map makes, reading alliances from char.conflicts as Conflicts does.
function mock.conflicts(ns, list)
  list = list or mock.data()
  local byId = {}
  for _, c in ipairs(list) do byId[c.id] = c end
  ns.Conflicts = {
    All = function() return list end,
    Get = function(_, id) return byId[id] end,
    InZone = function(_, m)
      local out = {}
      for _, c in ipairs(list) do
        if c.zone == m or (c.anchor and c.anchor.m == m) then out[#out + 1] = c end
      end
      return out
    end,
    Alliance = function(_, char, id)
      local rec = char and char.conflicts
      local side = rec and rec.allied and rec.allied[id]
      if side then return side, rec.began and rec.began[id] end
    end,
  }
  return ns.Conflicts
end

-- Sets a conflict's stored state on the character as Conflicts would write it (4.1).
function mock.ally(char, id, side, broken)
  char.conflicts = char.conflicts or { allied = {}, since = {}, began = {}, broken = {}, turned = {}, violations = 0 }
  char.conflicts.allied[id] = side
  char.conflicts.broken[id] = broken
end

-- CreateFrame with the pin template gives what the XML gives: the mixin, the Icon texture, OnLoad.
function mock.template(wow)
  local create = CreateFrame
  wow.stub("CreateFrame", function(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    if template == mock.TEMPLATE then
      for k, v in pairs(AshmarkMapPinMixin) do rawset(frame, k, v) end
      frame.Icon = create("Texture", nil, frame)
      frame:OnLoad()
    end
    return frame
  end)
end

-- Blizzard's MapCanvasMixin:AcquirePin ends with pin:CheckMouseButtonPassthrough("RightButton"), so a right
-- click on a pin reaches the canvas, which zooms out. MapCanvasPinMixin has no SetPassThroughButtons of its
-- own: the call reaches the pin frame's method, restricted in combat. Call before boot; the list returned
-- gets { button, InCombatLockdown() } for each call that reaches the frame.
function mock.passthrough(wow)
  local calls = {}
  wow.stub("MapCanvasPinMixin.SetPassThroughButtons", nil)
  local acquire = WorldMapFrame.AcquirePin
  wow.stub("WorldMapFrame.AcquirePin", function(self, template, ...)
    local pin = acquire(self, template, ...)
    if rawget(pin, "SetPassThroughButtons") == nil then
      rawset(pin, "SetPassThroughButtons", function(_, button) calls[#calls + 1] = { button, InCombatLockdown() } end)
    end
    pin:SetPassThroughButtons("RightButton")
    return pin
  end)
  return calls
end

-- The violation kind as Conflicts registers it (Conflicts is not loaded), with a sentence for tooltips.
function mock.kinds(ns)
  ns.Log:RegisterKind("violation", {
    fields = { "c", "side", "q", "o" }, keep = true,
    render = function(entry) return "Broke faith in " .. entry.c .. "." end,
  })
end

-- Core, Locales and Map (or opts.files), the Conflicts stand-in, opts.setup(ns), then login.
function mock.boot(wow, opts)
  opts = opts or {}
  mock.rects(wow)
  local ns = wow.load(opts.files or mock.FILES)
  mock.conflicts(ns, opts.data)
  mock.kinds(ns)
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

function mock.provider()
  return next(WorldMapFrame.providers)
end

-- The canvas: shows the map on mapId and refreshes every provider, as on OnShow or a map change.
function mock.open(wow, mapId)
  wow.state.worldMapShown = true
  wow.state.worldMapID = mapId
  for provider in pairs(WorldMapFrame.providers) do provider:RefreshAllData(true) end
end

function mock.close(wow)
  wow.state.worldMapShown = false
end

-- Ashmark's pins on the map, as { kind, state, atlas, x, y } rounded to 3 places, in acquisition order.
function mock.pins()
  local out = {}
  for _, pin in ipairs(WorldMapFrame.pins) do
    if pin.template == mock.TEMPLATE then
      local info = pin.info
      out[#out + 1] = {
        kind = info.kind, state = info.state, atlas = pin.Icon:GetAtlas(),
        x = math.floor(pin.normalizedX * 1000 + 0.5) / 1000, y = math.floor(pin.normalizedY * 1000 + 0.5) / 1000,
      }
    end
  end
  return out
end

function mock.pin(i)
  local n = 0
  for _, pin in ipairs(WorldMapFrame.pins) do
    if pin.template == mock.TEMPLATE then
      n = n + 1
      if n == i then return pin end
    end
  end
end

-- Text of the GameTooltip's lines.
function mock.tooltip()
  local out = {}
  for i = 1, GameTooltip:NumLines() do out[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
  return out
end

-- Runs the registered test check id.
function mock.check(ns, id)
  for _, c in ipairs(ns.Test.checks) do
    if c.id == id then return c.fn() end
  end
  error("no test check " .. id)
end

return mock

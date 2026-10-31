-- Mock World of Warcraft Forever client for busted specs (Lua 5.1). Not shipped.
--
--   local wow = require("tests.helpers.wow")
--   wow.reset()                          -- fresh globals, frames, timers, world fixtures and an empty ns
--   wow.unit("party1", { guid = "Player-1-00000002", name = "Mira" })
--   local ns = wow.load({ "Modules/Conflicts" })   -- Core and Locale files, then the named ones, in TOC order
--   wow.login()                          -- ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD(true, false)
--   wow.fire("QUEST_ACCEPTED", 1382); wow.advance(1); wow.combat(true)
--   wow.reload()                         -- logout, SavedVariables round trip, same files, login as a /reload
--   wow.saved({ schema = 1 })            -- AshmarkDB before ADDON_LOADED (specs have their own globals: use _G)
--   wow.secret(v), wow.lock(t)           -- an opaque secret value; a real table made inaccessible
--   wow.tooltip(Enum.TooltipDataType.Item, GameTooltip, data)   -- runs the registered post-calls
--   wow.invalidEvents.X = true           -- RegisterEvent("X") raises and C_EventUtils.IsEventValid("X") is false
--
-- World fixtures live in wow.state (units, map, money, auras, ...) and wow.data (quests, items, factions,
-- maps, ...); edit them directly or replace any API with wow.stub("C_Map.GetMapInfo", fn). Records of what
-- the addon did: wow.chat, wow.errors, wow.sent, wow.prefixes, wow.requests, wow.sounds, wow.panel,
-- wow.postCalls, wow.screenshots.

local wow = {}

local ADDON = "Ashmark"
local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)tests[/\\]helpers[/\\]wow%.lua$") or "")
local TOC = "Ashmark_Forever.toc"

wow.ADDON = ADDON
wow.ROOT = ROOT

local installed = {}

local function pack(...)
  return { n = select("#", ...), ... }
end

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function deepcopy(v, seen)
  if type(v) ~= "table" then
    if type(v) == "function" or type(v) == "userdata" or type(v) == "thread" then return nil end
    return v
  end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local out = {}
  seen[v] = out
  for k, x in pairs(v) do
    local key = deepcopy(k, seen)
    if key ~= nil then out[key] = deepcopy(x, seen) end
  end
  return out
end
wow.deepcopy = deepcopy

-- Secret values ----------------------------------------------------------

local secrets = setmetatable({}, { __mode = "k" })

local function raise()
  error("attempt to use a secret value", 2)
end

local SECRET_EVENTS = {
  "__index", "__newindex", "__lt", "__le", "__concat", "__len", "__call",
  "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
}

-- An opaque proxy: every operator raises; the mocked secret predicates recognise it.
-- Lua 5.1 calls __eq only between two userdata, so `secret == "x"` cannot be caught.
function wow.secret(v)
  local proxy = newproxy(true)
  local mt = getmetatable(proxy)
  for _, event in ipairs(SECRET_EVENTS) do mt[event] = raise end
  mt.__tostring = function() return "<secret>" end
  secrets[proxy] = { value = v, table = type(v) == "table" }
  return proxy
end

-- Marks a real table as inaccessible (canaccesstable false, issecrettable true).
function wow.lock(t)
  secrets[t] = { value = t, table = true }
  return t
end

function wow.isSecret(v)
  return v ~= nil and secrets[v] ~= nil
end

-- Clock and timers -------------------------------------------------------

local timers, timerSeq = {}, 0

local function moveClock(to)
  local delta = to - wow.state.uptime
  wow.state.uptime = to
  wow.state.epoch = wow.state.epoch + delta
end

local function schedule(delay, fn, ticker)
  timerSeq = timerSeq + 1
  timers[#timers + 1] = { due = wow.state.uptime + math.max(delay or 0, 0), seq = timerSeq, fn = fn, ticker = ticker }
end

local function newTicker(interval, iterations)
  local ticker = { interval = interval, remaining = iterations, cancelled = false }
  function ticker:Cancel() self.cancelled = true end
  function ticker:IsCancelled() return self.cancelled end
  return ticker
end

-- Runs due C_Timer callbacks in time order; time() and GetTime() move with them.
function wow.advance(seconds)
  local target = wow.state.uptime + (seconds or 0)
  for _ = 1, 100000 do
    local best
    for i, t in ipairs(timers) do
      if t.due <= target then
        local b = best and timers[best]
        if not b or t.due < b.due or (t.due == b.due and t.seq < b.seq) then best = i end
      end
    end
    if not best then
      moveClock(math.max(target, wow.state.uptime))
      return
    end
    local t = table.remove(timers, best)
    moveClock(t.due)
    local ticker = t.ticker
    if not (ticker and ticker.cancelled) then
      t.fn(ticker)
      if ticker and ticker.interval and not ticker.cancelled then
        if ticker.remaining then ticker.remaining = ticker.remaining - 1 end
        if not ticker.remaining or ticker.remaining > 0 then schedule(ticker.interval, t.fn, ticker) end
      end
    end
  end
  error("wow.advance: timers keep rescheduling themselves")
end

function wow.pendingTimers()
  return #timers
end

-- Frames -----------------------------------------------------------------

local registry = {}              -- [event] = { frame, ... } in registration order

local methods = {}
local frameMeta = {}

-- Named children of the Blizzard templates the UI inherits ([key] = { kind, children }).
local TEMPLATE_CHILDREN = {
  ButtonFrameTemplate = {
    Inset = { "Frame", { Bg = { "Texture" } } }, Bg = { "Texture" }, NineSlice = { "Frame" },
    TitleContainer = { "Frame", { TitleText = { "FontString" } } }, CloseButton = { "Button" },
    PortraitContainer = { "Frame", { portrait = { "Texture" } } },
  },
  PortraitFrameTemplate = {
    Bg = { "Texture" }, NineSlice = { "Frame" }, CloseButton = { "Button" },
    TitleContainer = { "Frame", { TitleText = { "FontString" } } },
    PortraitContainer = { "Frame", { portrait = { "Texture" } } },
  },
  PanelTabButtonTemplate = { Text = { "FontString" }, Left = { "Texture" }, Middle = { "Texture" },
                             Right = { "Texture" } },
  UIPanelButtonTemplate = { Text = { "FontString" }, Left = { "Texture" }, Middle = { "Texture" },
                            Right = { "Texture" } },
  InputBoxTemplate = { Left = { "Texture" }, Middle = { "Texture" }, Right = { "Texture" } },
  DialogBorderTemplate = { Bg = { "Texture" }, NineSlice = { "Frame" } },
  TooltipBackdropTemplate = { NineSlice = { "Frame" } },
  WowScrollBoxList = { ScrollTarget = { "Frame" } },
  MinimalScrollBar = { Track = { "Frame", { Thumb = { "Button" } } }, Back = { "Button" }, Forward = { "Button" } },
}

local newFrame

local function addChildren(f, children)
  for key, spec in pairs(children) do
    local child = newFrame(spec[1], nil, f)
    rawset(f, key, child)
    if spec[2] then addChildren(child, spec[2]) end
  end
end

function newFrame(kind, name, parent, template)
  local f = setmetatable({
    __kind = kind or "Frame", __name = name, __parent = parent, __template = template, __shown = true,
    __scripts = {}, __hooks = {}, __events = {}, __units = {}, __points = {}, __lines = {}, __regions = {},
    __attributes = {}, __width = 0, __height = 0, __id = 0, __alpha = 1, __level = 1, __children = {},
  }, frameMeta)
  if parent and type(parent) == "table" and rawget(parent, "__children") then
    table.insert(parent.__children, f)
  end
  if name then
    installed[name] = true
    _G[name] = f
  end
  table.insert(wow.frames, f)
  for t in tostring(template or ""):gmatch("[^,%s]+") do
    if TEMPLATE_CHILDREN[t] then addChildren(f, TEMPLATE_CHILDREN[t]) end
  end
  return f
end
wow.newFrame = newFrame

-- Unknown PascalCase keys are no-op methods (Create* ones return new stub frames); other keys are
-- data fields and read as nil until set.
frameMeta.__index = function(self, key)
  local removed = rawget(self, "__removed")
  if removed and removed[key] then return nil end
  local m = methods[key]
  if m then return m end
  if type(key) ~= "string" or not key:match("^%u") then return nil end
  local stub
  if key == "CreateAnimation" then
    -- CreateAnimation(animationType, name, template): the first argument is the kind, not a name.
    stub = function(owner, kind, name, template) return newFrame(kind or "Animation", name, owner, template) end
  elseif key:match("^Create") then
    stub = function(owner, name, _, template) return newFrame(key:sub(7), name, owner, template) end
  else
    stub = function() end
  end
  rawset(self, key, stub)
  return stub
end

local function unregister(frame, event)
  local list = registry[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == frame then table.remove(list, i) end
  end
end

local function register(frame, event)
  if wow.invalidEvents[event] then
    error(string.format('Attempt to register unknown event "%s"', tostring(event)), 3)
  end
  if not frame.__events[event] then
    frame.__events[event] = true
    registry[event] = registry[event] or {}
    table.insert(registry[event], frame)
  end
end

function methods:RegisterEvent(event)
  register(self, event)
  self.__units[event] = nil
end

function methods:RegisterUnitEvent(event, ...)
  register(self, event)
  local units = {}
  for i = 1, select("#", ...) do units[select(i, ...)] = true end
  self.__units[event] = units
end

function methods:UnregisterEvent(event)
  self.__events[event] = nil
  self.__units[event] = nil
  unregister(self, event)
end

function methods:UnregisterAllEvents()
  for event in pairs(self.__events) do unregister(self, event) end
  self.__events, self.__units = {}, {}
end

function methods:IsEventRegistered(event)
  return self.__events[event] == true
end

function methods:SetScript(kind, fn)
  self.__scripts[kind] = fn
  self.__hooks[kind] = nil
end

function methods:GetScript(kind)
  return self.__scripts[kind]
end

function methods:HookScript(kind, fn)
  local hooks = self.__hooks[kind] or {}
  self.__hooks[kind] = hooks
  hooks[#hooks + 1] = fn
end

function methods:HasScript()
  return true
end

-- Runs a frame's script and its hooks, as the client would.
function wow.script(frame, kind, ...)
  local fn = frame.__scripts[kind]
  if fn then fn(frame, ...) end
  for _, hook in ipairs(frame.__hooks[kind] or {}) do hook(frame, ...) end
end

function methods:Show()
  local was = self.__shown
  self.__shown = true
  if not was then wow.script(self, "OnShow") end
end

function methods:Hide()
  local was = self.__shown
  self.__shown = false
  if was then wow.script(self, "OnHide") end
end

function methods:SetShown(shown)
  if shown then self:Show() else self:Hide() end
end

function methods:IsShown()
  return self.__shown
end

function methods:IsVisible()
  local f = self
  while type(f) == "table" and rawget(f, "__shown") ~= nil do
    if not f.__shown then return false end
    f = f.__parent
  end
  return true
end

function methods:GetName() return self.__name end
function methods:GetParent() return self.__parent end
function methods:SetParent(parent) self.__parent = parent end
function methods:GetObjectType() return self.__kind end
function methods:IsObjectType(kind) return self.__kind == kind end
function methods:IsForbidden() return false end
function methods:GetID() return self.__id end
function methods:SetID(id) self.__id = id end
function methods:GetChildren() return unpack(self.__children) end
function methods:SetWidth(w) self.__width = w end
function methods:SetHeight(h) self.__height = h end
function methods:SetSize(w, h) self.__width, self.__height = w, h end
function methods:GetWidth() return self.__width end
function methods:GetHeight() return self.__height end
function methods:GetSize() return self.__width, self.__height end
function methods:GetScale() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:SetAlpha(a) self.__alpha = a end
function methods:GetAlpha() return self.__alpha end
function methods:SetFrameLevel(l) self.__level = l end
function methods:GetFrameLevel() return self.__level end
function methods:GetStringWidth() return 0 end
function methods:GetStringHeight() return 0 end
function methods:GetNumPoints() return #self.__points end
function methods:SetPoint(...) table.insert(self.__points, pack(...)) end
function methods:ClearAllPoints() self.__points = {} end
function methods:SetAllPoints(target) self.__points = { pack("ALL", target) } end
function methods:GetPoint(i) local p = self.__points[i or 1]; if p then return unpack(p, 1, p.n) end end
function methods:IsMouseOver() return false end
function methods:SetAttribute(k, v) self.__attributes[k] = v end
function methods:GetAttribute(k) return self.__attributes[k] end
function methods:GetText() return self.__text end
function methods:SetFormattedText(fmt, ...) self:SetText(string.format(fmt, ...)) end
function methods:SetTextColor(r, g, b) self.__color = { r, g, b } end
function methods:GetTextColor() local c = self.__color or { 1, 1, 1 }; return c[1], c[2], c[3] end
function methods:SetAtlas(atlas) self.__atlas = atlas end
function methods:GetAtlas() return self.__atlas end
function methods:SetTexture(texture) self.__texture = texture end
function methods:GetTexture() return self.__texture end
function methods:SetMaxLetters(n) self.__maxLetters = n end
function methods:GetMaxLetters() return self.__maxLetters or 0 end

-- Tooltips: lines are named font strings, <name>TextLeft<i> and <name>TextRight<i>.
local function region(tip, side, i)
  local key = side .. i
  local r = tip.__regions[key]
  if not r then
    r = newFrame("FontString", tip.__name and (tip.__name .. key) or nil, tip)
    tip.__regions[key] = r
  end
  return r
end

function methods:SetText(text, ...)
  if self.__kind == "GameTooltip" then
    self:ClearLines()
    self:AddLine(text, ...)
  else
    self.__text = text
  end
end

function methods:AddLine(text)
  local i = #self.__lines + 1
  self.__lines[i] = true
  region(self, "TextLeft", i).__text = text
  region(self, "TextRight", i).__text = nil
end

function methods:AddDoubleLine(left, right)
  self:AddLine(left)
  region(self, "TextRight", #self.__lines).__text = right
end

function methods:NumLines()
  return #self.__lines
end

function methods:ClearLines()
  for i = 1, #self.__lines do
    region(self, "TextLeft", i).__text = nil
    region(self, "TextRight", i).__text = nil
  end
  self.__lines = {}
end

function methods:SetOwner(owner, anchor)
  self.__owner, self.__anchor = owner, anchor
  self:ClearLines()
end

function methods:GetOwner()
  return self.__owner
end

function methods:SetItemByID(id)
  self:ClearLines()
  self.__item = id
  local data = wow.data.tooltips[id]
  for _, line in ipairs(data and data.lines or {}) do
    self:AddDoubleLine(line.leftText, line.rightText)
  end
end

function methods:SetUnit(unit)
  self:ClearLines()
  self.__unit = unit
end

-- Event firing -------------------------------------------------------------

-- Dispatches to every frame registered for the event, in registration order.
function wow.fire(event, ...)
  local list = registry[event]
  if not list then return end
  local unit = ...
  for _, frame in ipairs(copy(list)) do
    if frame.__events[event] then
      local units = frame.__units[event]
      if not units or units[unit] then
        local fn = frame.__scripts.OnEvent
        if fn then fn(frame, event, ...) end
        for _, hook in ipairs(frame.__hooks.OnEvent or {}) do hook(frame, event, ...) end
      end
    end
  end
end

-- Runs the TooltipDataProcessor post-calls registered for a data type, then those for AllTypes.
function wow.tooltip(kind, tooltip, data)
  for _, list in ipairs({ wow.postCalls[kind] or {}, wow.postCalls.ALL or {} }) do
    for _, fn in ipairs(list) do fn(tooltip, data) end
  end
end

-- Frames registered for an event (unit frames included).
function wow.registered(event)
  return registry[event] and #registry[event] or 0
end

-- Combat: PLAYER_REGEN_DISABLED fires before lockdown begins, PLAYER_REGEN_ENABLED after it ends.
function wow.combat(on)
  if on then
    wow.state.inCombat = true
    wow.fire("PLAYER_REGEN_DISABLED")
    wow.state.combatLockdown = true
  else
    wow.state.combatLockdown = false
    wow.state.inCombat = false
    wow.fire("PLAYER_REGEN_ENABLED")
  end
end

-- World fixtures -----------------------------------------------------------

local function color(r, g, b)
  local c = { r = r, g = g, b = b, a = 1 }
  function c:GetRGB() return self.r, self.g, self.b end
  function c:GetRGBA() return self.r, self.g, self.b, self.a end
  function c:GenerateHexColor()
    return string.format("ff%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
  end
  function c:WrapTextInColorCode(text) return "|c" .. self:GenerateHexColor() .. tostring(text) .. "|r" end
  return c
end

local CLASSES = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local function defaultState()
  return {
    epoch = 1790000000,          -- GetServerTime(), the realm's clock
    skew = 0,                    -- seconds the system clock (time(), date()) runs ahead of the realm's
    uptime = 5000,               -- GetTime()
    locale = "enUS",
    loggedIn = false,
    inCombat = false,            -- UnitAffectingCombat("player")
    combatLockdown = false,      -- InCombatLockdown()
    chatLockdown = false,        -- C_ChatInfo.InChatMessagingLockdown()
    units = {
      player = {
        guid = "Player-1-00000001", name = "Aren", surname = "Ashvale", classFile = "WARRIOR",
        className = "Warrior", classID = 1, raceID = 1, raceFile = "Human", raceName = "Human", sex = 2,
        faction = "Alliance", level = 20, isPlayer = true,
      },
    },
    map = nil,                   -- C_Map.GetBestMapForUnit("player")
    pos = nil,                   -- { x = 0..1, y = 0..1 } or a secret
    instance = nil,              -- { name, type = "party", instanceID = 389 } while inside
    instanceGroup = false,       -- the unit tokens name an instance group (a battleground's raid)
    homeGroup = nil,             -- { size, raid } of the home group behind an instance group
    money = 0,
    resting = false,
    outdoors = true,
    auras = {},                  -- [spellID] = aura data
    rules = {},                  -- [Enum.GameRule value] = true
    trial = false,
    veteran = false,
    sendResult = 0,              -- C_ChatInfo.SendAddonMessage result, or function(prefix, text, channel)
    questDetail = nil,           -- GetQuestID()
    selectedQuest = 0,
    abandonQuest = 0,
    worldMapShown = false,
    worldMapID = nil,
    identitySecret = {},         -- [unit] = true for C_Secrets.ShouldUnitIdentityBeSecret
    aurasSecret = false,
  }
end

local function mapInfo(id, name, mapType, parent)
  return { mapID = id, name = name, mapType = mapType, parentMapID = parent }
end

local function defaultData()
  local maps = {}
  for _, m in ipairs({
    mapInfo(946, "Cosmic", 0, 0), mapInfo(947, "Azeroth", 1, 946),
    mapInfo(1414, "Kalimdor", 2, 947), mapInfo(1415, "Eastern Kingdoms", 2, 947),
    mapInfo(1411, "Durotar", 3, 1414), mapInfo(1443, "Desolace", 3, 1414), mapInfo(2652, "Shen'dralas", 3, 1414),
    mapInfo(1454, "Orgrimmar", 3, 1414), mapInfo(1456, "Thunder Bluff", 3, 1414), mapInfo(1457, "Darnassus", 3, 1414),
    mapInfo(1429, "Elwynn Forest", 3, 1415), mapInfo(1434, "Stranglethorn Vale", 3, 1415),
    mapInfo(1453, "Stormwind City", 3, 1415), mapInfo(1455, "Ironforge", 3, 1415), mapInfo(1458, "Undercity", 3, 1415),
    mapInfo(9001, "Test Dungeon", 4, 1443), mapInfo(9002, "Test Micro", 5, 1443), mapInfo(9003, "Test Orphan", 6, 0),
  }) do maps[m.mapID] = m end
  local races = {}
  for id, race in ipairs({ "Human", "Orc", "Dwarf", "Night Elf", "Undead", "Tauren", "Gnome", "Troll" }) do
    races[id] = { raceID = id, raceName = race, clientFileString = race:gsub(" ", "") }
  end
  local function faction(id, name)
    return { factionID = id, name = name, reaction = 4, currentStanding = 0, currentReactionThreshold = 0,
             nextReactionThreshold = 3000 }
  end
  return {
    build = { "1.60.1", "70532", "Oct 20 2026", 16001 },
    project = 18,
    realm = "Forever",
    metadata = { Title = "Ashmark", Version = "1.0.0-test", ["X-TocVariant"] = "Forever" },
    quests = {},                 -- [id] = { title, inLog, completed, task }
    items = {},                  -- [id] = { name, cached, itemType, itemSubType, equipLoc, icon, classID, subclassID }
    factions = {
      [21] = faction(21, "Booty Bay"), [87] = faction(87, "Bloodsail Buccaneers"),
      [92] = faction(92, "Gelkis Clan Centaur"), [93] = faction(93, "Magram Clan Centaur"),
    },
    majorFactions = { [2802] = { factionID = 2802, name = "Legacy", renownLevel = 1 } },
    maps = maps,
    mapRects = {},               -- [childMap][parentMap] = { minX, maxX, minY, maxY }
    races = races,
    creatureTypes = { [8] = { name = "Critter" } },
    spells = {},                 -- [id] = name
    bags = {},                   -- [bag] = { [slot] = itemID, size = n }
    inventory = {},              -- [slot] = itemID
    tooltips = {},               -- [itemID] = { id, lines = { { type, leftText, rightText }, ... } }
    templates = {},              -- [name] = { type = "Frame" }; unknown names count as Frame templates
    missingTemplates = {},
    missingAtlases = {},
    cvars = {},
  }
end

-- Sets (fields) or removes (nil) a unit fixture.
function wow.unit(token, fields)
  wow.state.units[token] = fields
  return fields
end

-- Globals ------------------------------------------------------------------

-- A unit token, or, as in the client, the name of a group member ("Name" on the player's realm,
-- "Name-Realm" for a fixture with a realm field).
local function unitOf(token)
  if type(token) ~= "string" then return nil end
  local units = wow.state.units
  if units[token] then return units[token] end
  for _, group in ipairs({ { "party", 4 }, { "raid", 40 } }) do
    for i = 1, group[2] do
      local u = units[group[1] .. i]
      if u and type(u.name) == "string" and token == (u.realm and u.name .. "-" .. u.realm or u.name) then
        return u
      end
    end
  end
  return nil
end

-- A fixture with loading = true has no name yet: the name APIs return UNKNOWNOBJECT, as the client's do until
-- the unit's name has arrived.
local function nameReturns(u, api)
  if u.loading then return _G.UNKNOWNOBJECT end
  local r = u.nameReturns and u.nameReturns[api]
  if r then return unpack(r, 1, r.n or #r) end
  return u.name, u.surname
end

local function count(prefix, n)
  local c = 0
  for i = 1, n do
    if wow.state.units[prefix .. i] then c = c + 1 end
  end
  return c
end

-- Globals read wow.state and wow.data through these, so a test may replace either table.
local state = setmetatable({}, {
  __index = function(_, k) return wow.state[k] end,
  __newindex = function(_, k, v) wow.state[k] = v end,
})
local data = setmetatable({}, { __index = function(_, k) return wow.data[k] end })

local function buildGlobals()
  local G = {}

  -- Lua extensions of the WoW environment
  G.tinsert, G.tremove, G.sort = table.insert, table.remove, table.sort
  G.format, G.strlower, G.strupper = string.format, string.lower, string.upper
  G.strsub, G.strlen = string.sub, string.len
  G.strfind, G.strmatch, G.gsub, G.strrep, G.strbyte, G.strchar = string.find, string.match, string.gsub,
    string.rep, string.byte, string.char
  G.gmatch = string.gmatch
  G.floor, G.ceil, G.abs, G.max, G.min, G.sqrt, G.mod = math.floor, math.ceil, math.abs, math.max, math.min,
    math.sqrt, math.fmod
  G.random = math.random
  G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
  G.strsplit = function(sep, s, limit)
    local out, start = {}, 1
    while true do
      if limit and #out == limit - 1 then break end
      local i, j = s:find(sep, start, true)
      if not i then break end
      out[#out + 1] = s:sub(start, i - 1)
      start = j + 1
    end
    out[#out + 1] = s:sub(start)
    return unpack(out)
  end
  G.tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
  G.tIndexOf = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
  G.CopyTable = function(t) return deepcopy(t) end
  G.Round = function(v) return math.floor(v + 0.5) end
  G.Clamp = function(v, lo, hi) return math.min(math.max(v, lo), hi) end
  G.time = function(t) if t then return os.time(t) end return math.floor(state.epoch + (state.skew or 0)) end
  G.date = function(fmt, t) return os.date(fmt, t or math.floor(state.epoch + (state.skew or 0))) end
  G.GetTime = function() return state.uptime end
  G.GetServerTime = function() return math.floor(state.epoch) end
  G.debugstack = function() return debug.traceback("", 2) end
  local errorHandler = function(msg) table.insert(wow.errors, tostring(msg)) end
  G.geterrorhandler = function() return errorHandler end
  G.seterrorhandler = function(fn) errorHandler = fn end
  G.securecallfunction = function(fn, ...) return fn(...) end
  G.issecure = function() return true end
  G.hooksecurefunc = function(a, b, c)
    local t, name, hook = a, b, c
    if type(a) == "string" then t, name, hook = _G, a, b end
    local original = t[name]
    assert(type(original) == "function", "hooksecurefunc: no function " .. tostring(name))
    t[name] = function(...)
      local results = pack(original(...))
      hook(...)
      return unpack(results, 1, results.n)
    end
  end
  G.Mixin = function(object, ...)
    for i = 1, select("#", ...) do
      for k, v in pairs((select(i, ...))) do object[k] = v end
    end
    return object
  end
  G.CreateFromMixins = function(...) return G.Mixin({}, ...) end

  -- Secret values
  G.issecretvalue = function(v) return v ~= nil and secrets[v] ~= nil end
  G.canaccessvalue = function(v) return v == nil or secrets[v] == nil end
  G.issecrettable = function(t) return t ~= nil and secrets[t] ~= nil and secrets[t].table end
  G.canaccesstable = function(t) return t == nil or secrets[t] == nil or not secrets[t].table end
  G.secretwrap = function(v) return wow.secret(v) end

  -- Client and build
  G.GetBuildInfo = function() return unpack(data.build) end
  G.WOW_PROJECT_MAINLINE, G.WOW_PROJECT_CLASSIC, G.WOW_PROJECT_CAMELOT = 1, 2, 18
  G.WOW_PROJECT_ID = data.project
  G.GetLocale = function() return state.locale end
  G.GetRealmName = function() return data.realm end
  G.GetNormalizedRealmName = function() return data.realm end
  G.IsLoggedIn = function() return state.loggedIn end
  G.InCombatLockdown = function() return state.combatLockdown end
  G.IsTrialAccount = function() return state.trial end
  G.IsVeteranTrialAccount = function() return state.veteran end
  G.GetMoney = function() return state.money end
  G.IsResting = function() return state.resting end
  G.IsOutdoors = function() return state.outdoors end
  G.GetQuestID = function() return state.questDetail end
  G.Screenshot = function() table.insert(wow.screenshots, state.uptime) end
  G.PlaySound = function(id) table.insert(wow.sounds, id) return true end
  G.GetCVar = function(name) return data.cvars[name] end
  G.GetCVarBool = function(name) local v = data.cvars[name] return v == "1" or v == true end
  G.GetText = function(token, sex)
    if sex == 3 and _G[token .. "_FEMALE"] then return _G[token .. "_FEMALE"] end
    return _G[token]
  end
  G.GetClassAtlas = function(classFile) return "classicon-" .. tostring(classFile):lower() end
  G.GetInventoryItemID = function(unit, slot) if unit == "player" then return data.inventory[slot] end end
  G.GetZoneText = function() local m = state.map and data.maps[state.map] return m and m.name or "" end
  G.GetRealZoneText = G.GetZoneText
  G.GetSubZoneText = function() return "" end

  -- Units and groups
  G.UnitGUID = function(t) local u = unitOf(t) return u and u.guid end
  G.UnitExists = function(t) return unitOf(t) ~= nil end
  G.UnitIsUnit = function(a, b) local x, y = unitOf(a), unitOf(b) return x ~= nil and y ~= nil and x.guid == y.guid end
  G.UnitName = function(t) local u = unitOf(t) if u then return nameReturns(u, "UnitName") end end
  G.UnitNameUnmodified = function(t) local u = unitOf(t) if u then return nameReturns(u, "UnitNameUnmodified") end end
  G.UnitFullName = function(t) local u = unitOf(t) if u then return nameReturns(u, "UnitFullName") end end
  G.UnitClass = function(t) local u = unitOf(t) if u then return u.className, u.classFile, u.classID end end
  G.UnitRace = function(t) local u = unitOf(t) if u then return u.raceName, u.raceFile, u.raceID end end
  G.UnitSex = function(t) local u = unitOf(t) if u then return u.sex or 1 end end
  G.UnitFactionGroup = function(t) local u = unitOf(t) if u then return u.faction, u.faction end end
  G.UnitLevel = function(t) local u = unitOf(t) return u and u.level or 0 end
  G.UnitIsPlayer = function(t) local u = unitOf(t) return u ~= nil and u.isPlayer == true end
  G.UnitIsDead = function(t) local u = unitOf(t) if u then return u.dead or false end return false end
  G.UnitIsTapDenied = function(t) local u = unitOf(t) if u then return u.tapDenied or false end return false end
  G.UnitIsAFK = function(t) local u = unitOf(t) if u then return u.afk or false end return false end
  G.UnitPlayerControlled = function(t)
    local u = unitOf(t)
    return u ~= nil and (u.playerControlled or u.isPlayer or false)
  end
  G.UnitReaction = function(t) local u = unitOf(t) return u and u.reaction end
  G.UnitCreatureType = function(t) local u = unitOf(t) if u then return u.creatureType, u.creatureTypeID end end
  G.UnitHealth = function(t) local u = unitOf(t) return u and u.health or 0 end
  G.UnitHealthMax = function(t) local u = unitOf(t) return u and u.healthMax or 0 end
  G.UnitAffectingCombat = function(t)
    local u = unitOf(t)
    if not u then return false end
    if u.combat ~= nil then return u.combat end
    if t == "player" then return state.inCombat end
    return false
  end
  G.UnitInParty = function(t) return unitOf(t) ~= nil and (t == "player" or count("party", 4) > 0) end
  G.UnitInRaid = function(t) return unitOf(t) ~= nil and count("raid", 40) > 0 or nil end
  -- The unit tokens name the active group: the instance group while state.instanceGroup is set (a
  -- battleground), else the home group. Without a category the client answers for the active group.
  G.LE_PARTY_CATEGORY_HOME, G.LE_PARTY_CATEGORY_INSTANCE = 1, 2
  local function group(category)
    local raid, party = count("raid", 40), count("party", 4)
    local size, isRaid = raid > 0 and raid or (party > 0 and party + 1 or 0), raid > 0
    if state.instanceGroup then
      if category ~= G.LE_PARTY_CATEGORY_HOME then return size, isRaid end
      local home = state.homeGroup
      return home and home.size or 0, home and home.raid == true or false
    end
    if category == G.LE_PARTY_CATEGORY_INSTANCE then return 0, false end
    return size, isRaid
  end
  G.IsInRaid = function(category) local _, raid = group(category) return raid end
  G.IsInGroup = function(category)
    if category == nil then
      return group(G.LE_PARTY_CATEGORY_HOME) > 0 or group(G.LE_PARTY_CATEGORY_INSTANCE) > 0
    end
    return group(category) > 0
  end
  G.GetNumSubgroupMembers = function() return count("party", 4) end
  -- "Name-Realm" to "Name" for the player's realm; "short" drops any realm.
  G.Ambiguate = function(name, context)
    if type(name) ~= "string" then return name end
    local base, realm = name:match("^([^%-]+)%-(.+)$")
    if base and (context == "short" or realm == data.realm) then return base end
    return name
  end
  G.GetNumGroupMembers = function(category) return (group(category)) end

  -- Places
  G.IsInInstance = function()
    if state.instance then return true, state.instance.type or "party" end
    return false, "none"
  end
  G.GetInstanceInfo = function()
    local i = state.instance
    if not i then return "", "none", 0, "", 0, 0, false, 0, 0 end
    return i.name or "Instance", i.type or "party", 1, "Normal", 5, 0, false, i.instanceID or 0, 5
  end
  G.C_Map = {
    GetBestMapForUnit = function(unit) if unit == "player" then return state.map end end,
    GetPlayerMapPosition = function(_, unit)
      if unit ~= "player" or state.pos == nil then return nil end
      if wow.isSecret(state.pos) then return state.pos end
      local pos = { x = state.pos.x, y = state.pos.y }
      function pos:GetXY() return self.x, self.y end
      return pos
    end,
    GetMapInfo = function(id) return data.maps[id] end,
    GetMapRectOnMap = function(child, parent)
      local r = data.mapRects[child] and data.mapRects[child][parent]
      if r then return unpack(r) end
    end,
  }

  -- Quests, reputation, items
  G.C_QuestLog = {
    GetTitleForQuestID = function(id) local q = data.quests[id] return q and q.title end,
    GetLogIndexForQuestID = function(id) local q = data.quests[id] if q and q.inLog then return q.index or 1 end end,
    RequestLoadQuestByID = function(id) table.insert(wow.requests.quest, id) end,
    IsQuestFlaggedCompleted = function(id) local q = data.quests[id] return q ~= nil and q.completed == true end,
    IsQuestTask = function(id) local q = data.quests[id] return q ~= nil and q.task == true end,
    SetSelectedQuest = function(id) state.selectedQuest = id end,
    GetSelectedQuest = function() return state.selectedQuest end,
    SetAbandonQuest = function() state.abandonQuest = state.selectedQuest end,
    GetAbandonQuest = function() return state.abandonQuest end,
    AbandonQuest = function()
      local q = data.quests[state.abandonQuest]
      if q then q.inLog = false end
      state.abandonQuest = 0
    end,
  }
  G.C_Reputation = {
    GetFactionDataByID = function(id) return data.factions[id] end,
  }
  G.C_MajorFactions = {
    GetMajorFactionData = function(id) return data.majorFactions[id] end,
  }
  G.C_Item = {
    GetItemNameByID = function(id) local i = data.items[id] if i and i.cached ~= false then return i.name end end,
    IsItemDataCachedByID = function(id) local i = data.items[id] return i ~= nil and i.cached ~= false end,
    RequestLoadItemDataByID = function(id) table.insert(wow.requests.item, id) end,
    GetItemInfoInstant = function(id)
      local i = data.items[id]
      if i then return id, i.itemType, i.itemSubType, i.equipLoc, i.icon, i.classID, i.subclassID end
    end,
    GetItemIconByID = function(id) local i = data.items[id] return i and i.icon end,
  }
  G.C_Container = {
    GetContainerNumSlots = function(bag) local b = data.bags[bag] return b and (b.size or #b) or 0 end,
    GetContainerItemID = function(bag, slot) local b = data.bags[bag] return b and b[slot] end,
  }
  G.C_TooltipInfo = {
    GetItemByID = function(id) return data.tooltips[id] or { id = id, lines = {} } end,
  }
  G.C_Spell = {
    GetSpellName = function(id) return data.spells[id] end,
  }
  G.C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id) return state.auras[id] end,
  }
  G.C_CreatureInfo = {
    GetCreatureTypeInfo = function(id) return data.creatureTypes[id] end,
    GetRaceInfo = function(id) return data.races[id] end,
  }
  G.C_ClassColor = {
    GetClassColor = function() return color(1, 1, 1) end,
  }
  G.C_PlayerInfo = {
    ShouldDisplaySurname = function() return true end,
  }

  -- Restrictions and messaging
  G.C_Secrets = {
    ShouldUnitIdentityBeSecret = function(unit) return state.identitySecret[unit] == true end,
    ShouldAurasBeSecret = function() return state.aurasSecret == true end,
  }
  G.C_RestrictedActions = {
    IsAddOnRestrictionActive = function() return false end,
  }
  G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) wow.prefixes[prefix] = true return true end,
    IsAddonMessagePrefixRegistered = function(prefix) return wow.prefixes[prefix] == true end,
    InChatMessagingLockdown = function() return state.chatLockdown end,
    SendAddonMessage = function(prefix, text, channel, target)
      local result = state.sendResult
      if type(result) == "function" then result = result(prefix, text, channel, target) end
      table.insert(wow.sent, { prefix = prefix, text = text, channel = channel, target = target, result = result })
      return result
    end,
  }
  G.C_EventUtils = {
    IsEventValid = function(event) return not wow.invalidEvents[event] end,
  }
  G.C_GameRules = {
    IsGameRuleActive = function(rule) return state.rules[rule] == true end,
    GetForeverExperiencePreset = function() return 1 end,
  }
  G.C_AddOns = {
    GetAddOnMetadata = function(addon, field) if addon == ADDON then return data.metadata[field] end end,
  }
  G.C_Texture = {
    GetAtlasInfo = function(name)
      if type(name) == "string" and name ~= "" and not data.missingAtlases[name] then
        return { width = 16, height = 16, file = name }
      end
    end,
  }
  G.C_XMLUtil = {
    GetTemplateInfo = function(name)
      if data.missingTemplates[name] then return nil end
      return data.templates[name] or { type = "Frame", width = 0, height = 0 }
    end,
  }
  G.C_CVar = {
    GetCVar = function(name) return data.cvars[name] end,
  }
  G.C_Timer = {
    After = function(seconds, fn) schedule(seconds, fn) end,
    NewTimer = function(seconds, fn)
      local t = newTicker(nil, 1)
      schedule(seconds, fn, t)
      return t
    end,
    NewTicker = function(seconds, fn, iterations)
      local t = newTicker(seconds, iterations)
      schedule(seconds, fn, t)
      return t
    end,
  }

  -- Enums
  G.Enum = {
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
    TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, Macro = 25 },
    TooltipDataLineType = {
      None = 0, Blank = 1, UnitName = 2, GemSocket = 3, AzeriteEssenceSlot = 4, AzeriteEssencePower = 5,
      LearnableSpell = 6, UnitThreat = 7, QuestObjective = 8, AzeriteItemPowerDescription = 9,
      RuneforgeLegendaryPowerDescription = 10, SellPrice = 11, ProfessionCraftingQuality = 12,
      SpellName = 13, CurrencyTotal = 14, ItemEnchantmentPermanent = 15, UnitOwner = 16, QuestTitle = 17,
      QuestPlayer = 18, NestedBlock = 19, ItemBinding = 20, RestrictedRaceClass = 21,
      RestrictedFaction = 22, RestrictedSkill = 23, RestrictedPvPMedal = 24, RestrictedReputation = 25,
      RestrictedSpellKnown = 26, RestrictedLevel = 27, EquipSlot = 28, ItemName = 29, Separator = 30,
      ToyName = 31, ToyText = 32, ToyEffect = 33, ToyDuration = 34, RestrictedArena = 35, RestrictedBg = 36,
    },
    SendAddonMessageResult = {
      Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4,
      NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9,
      NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12,
    },
    GameRule = { HardcoreRuleset = 101, RPRuleset = 102, PvPRuleset = 103, RPPvPRuleset = 104 },
    BagIndex = {
      Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5, Bank = -1,
      BankBag_1 = 6, BankBag_2 = 7, BankBag_3 = 8, BankBag_4 = 9, BankBag_5 = 10, BankBag_6 = 11,
      BankBag_7 = 12, AccountBankTab_1 = 13,
    },
  }

  -- Strings and colours
  G.LOCALIZED_CLASS_NAMES_MALE = copy(CLASSES)
  G.LOCALIZED_CLASS_NAMES_FEMALE = copy(CLASSES)
  local standings = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
  for i, label in ipairs(standings) do
    G["FACTION_STANDING_LABEL" .. i] = label
    G["FACTION_STANDING_LABEL" .. i .. "_FEMALE"] = label
  end
  G.ERR_UNINVITE_YOU = "You have been removed from the group."
  G.UNKNOWNOBJECT = "Unknown"         -- UnitName's placeholder until a unit's name has arrived
  G.UKNOWNBEING = "Unknown Being"     -- (sic) the client's other stand-in for a name
  G.ITEM_LEVEL = "Item Level %d"
  G.FACTION_ALLIANCE, G.FACTION_HORDE = "Alliance", "Horde"
  G.ACCEPT, G.CANCEL, G.YES, G.NO, G.OKAY, G.CLOSE = "Accept", "Cancel", "Yes", "No", "Okay", "Close"
  G.NORMAL_FONT_COLOR = color(1, 0.82, 0)
  G.HIGHLIGHT_FONT_COLOR = color(1, 1, 1)
  G.RED_FONT_COLOR = color(1, 0.1, 0.1)
  G.GRAY_FONT_COLOR = color(0.5, 0.5, 0.5)
  G.ChatTypeInfo = { SYSTEM = color(1, 1, 0), MONSTER_SAY = color(1, 1, 0.62) }
  G.FACTION_BAR_COLORS = {}
  for i = 1, 8 do G.FACTION_BAR_COLORS[i] = color(i / 8, i / 8, 0) end
  G.SOUNDKIT = { IG_QUEST_LOG_OPEN = 844, IG_QUEST_LOG_CLOSE = 845, IG_ABILITY_PAGE_TURN = 836,
                 IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
  G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
  G.INVSLOT_FIRST_EQUIPPED, G.INVSLOT_LAST_EQUIPPED = 1, 19

  -- Frames and FrameXML
  G.CreateFrame = function(kind, name, parent, template) return newFrame(kind, name, parent, template) end
  G.UISpecialFrames = {}
  G.SlashCmdList = {}
  G.PanelTemplates_SetNumTabs = function(frame, n) frame.numTabs = n end
  G.PanelTemplates_SetTab = function(frame, id) frame.selectedTab = id end
  G.PanelTemplates_TabResize = function() end
  G.PanelTemplates_UpdateTabs = function() end
  G.CreateScrollBoxListLinearView = function() return newFrame("ScrollBoxListLinearView") end
  G.CreateDataProvider = function(list)
    local p = { items = list and copy(list) or {} }
    function p:Insert(...) for i = 1, select("#", ...) do table.insert(self.items, (select(i, ...))) end end
    function p:Flush() self.items = {} end
    function p:GetSize() return #self.items end
    function p:Enumerate() return ipairs(self.items) end
    return p
  end
  G.ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, bar, view) box.view, box.bar = view, bar end }
  G.MapCanvasDataProviderMixin = {
    OnAdded = function(self, map) self.owningMap = map end,
    OnRemoved = function(self) self.owningMap = nil end,
    GetMap = function(self) return self.owningMap end,
    RemoveAllData = function() end,
    RefreshAllData = function() end,
    OnShow = function() end,
    OnHide = function() end,
    OnMapChanged = function(self) self:RefreshAllData() end,
  }
  G.MapCanvasPinMixin = {
    OnLoad = function() end,
    OnAcquired = function() end,
    OnReleased = function() end,
    SetPosition = function(self, x, y) self.normalizedX, self.normalizedY = x, y end,
    UseFrameLevelType = function(self, kind) self.frameLevelType = kind end,
    SetPassThroughButtons = function() end,
  }
  G.TooltipDataProcessor = {
    AllTypes = "ALL",
    AddTooltipPostCall = function(kind, fn)
      wow.postCalls[kind] = wow.postCalls[kind] or {}
      table.insert(wow.postCalls[kind], fn)
    end,
  }
  G.TooltipUtil = {
    GetDisplayedUnit = function(tooltip) local u = tooltip.__unit return UnitName(u), u, UnitGUID(u) end,
  }
  G.CreateSettingsListSectionHeaderInitializer = function(text) return { header = text } end
  G.Settings = {
    RegisterVerticalLayoutCategory = function(name)
      local category = { name = name, id = #wow.panel.categories + 1 }
      function category:GetID() return self.id end
      local layout = { initializers = {} }
      function layout:AddInitializer(i) table.insert(self.initializers, i) end
      category.layout = layout
      table.insert(wow.panel.categories, category)
      return category, layout
    end,
    RegisterAddOnSetting = function(category, variable, key, tbl, vtype, name, default)
      local setting = { category = category, variable = variable, key = key, tbl = tbl, vtype = vtype,
                        name = name, default = default, callbacks = {} }
      function setting:GetValue()
        local v = self.tbl[self.key]
        if v == nil then return self.default end
        return v
      end
      function setting:SetValue(v)
        if self:GetValue() == v then return end
        self.tbl[self.key] = v
        for _, cb in ipairs(self.callbacks) do cb(self, v) end
        for _, cb in ipairs(wow.panel.callbacks[self.variable] or {}) do cb(self, v) end
      end
      function setting:SetValueChangedCallback(cb) table.insert(self.callbacks, cb) end
      wow.panel.settings[variable] = setting
      return setting
    end,
    SetOnValueChangedCallback = function(variable, cb)
      wow.panel.callbacks[variable] = wow.panel.callbacks[variable] or {}
      table.insert(wow.panel.callbacks[variable], cb)
    end,
    CreateCheckbox = function(category, setting, tooltip)
      local initializer = { category = category, setting = setting, tooltip = tooltip, predicates = {} }
      -- A child sits under its parent; the panel greys it out unless every modify predicate holds.
      function initializer:SetParentInitializer(parent, predicate)
        self.parent = parent
        if predicate then table.insert(self.predicates, predicate) end
      end
      function initializer:EvaluateModifyPredicates()
        for _, predicate in ipairs(self.predicates) do
          if not predicate() then return false end
        end
        return true
      end
      table.insert(wow.panel.checkboxes, initializer)
      return initializer
    end,
    RegisterAddOnCategory = function(category) category.registered = true end,
    OpenToCategory = function(id) wow.panel.opened = id end,
  }

  return G
end

-- Blizzard frames the addon reads or hooks; created after the globals so CreateFrame exists.
local function buildFrames()
  local ui = newFrame("Frame", "UIParent")
  newFrame("Frame", "DEFAULT_CHAT_FRAME", ui).AddMessage = function(_, text, r, g, b)
    table.insert(wow.chat, text)
    wow.chatColors[#wow.chat] = { r, g, b }
  end
  local map = newFrame("Frame", "WorldMapFrame", ui)
  map.__shown = false
  map.providers, map.pins = {}, {}
  function map.AddDataProvider(self, provider)
    self.providers[provider] = true
    if provider.OnAdded then provider:OnAdded(self) end
  end
  function map.RemoveDataProvider(self, provider)
    self.providers[provider] = nil
    if provider.OnRemoved then provider:OnRemoved(self) end
  end
  function map.GetMapID() return wow.state.worldMapID end
  function map.IsShown() return wow.state.worldMapShown end
  function map.AcquirePin(self, template, ...)
    local pin = newFrame("Frame", nil, self, template)
    pin.template = template
    local mixin = _G[(template:gsub("Template$", "Mixin"))]
    if type(mixin) == "table" then
      for k, v in pairs(mixin) do rawset(pin, k, v) end
    end
    pin.Icon = newFrame("Texture", nil, pin)
    table.insert(self.pins, pin)
    if pin.OnLoad then pin:OnLoad() end
    if pin.OnAcquired then pin:OnAcquired(...) end
    return pin
  end
  function map.RemoveAllPinsByTemplate(self, template)
    for i = #self.pins, 1, -1 do
      if self.pins[i].template == template then table.remove(self.pins, i) end
    end
  end
  local quest = newFrame("Frame", "QuestFrame", ui)
  quest.__shown = false
  newFrame("Frame", "QuestFrameDetailPanel", quest)
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
    newFrame("GameTooltip", name, ui).__shown = false
  end
  for _, name in ipairs({ "QuestTitleFont", "QuestFont", "GameFontNormal", "GameFontHighlight",
                          "GameFontHighlightSmall", "GameFontDisable", "GameFontNormalHuge" }) do
    newFrame("Font", name)
  end
end

-- Reset ----------------------------------------------------------------------

local function clearAddonGlobals()
  for name in pairs(installed) do _G[name] = nil end
  installed = {}
  for name in pairs(_G) do
    if type(name) == "string" and (name:match("^Ashmark") or name:match("^SLASH_ASHMARK")) then
      _G[name] = nil
    end
  end
end

local function resetClient()
  clearAddonGlobals()
  timers, timerSeq = {}, 0
  registry = {}
  wow.frames = {}
  wow.chat, wow.chatColors, wow.errors, wow.sent, wow.screenshots, wow.sounds = {}, {}, {}, {}, {}, {}
  wow.prefixes = {}
  wow.requests = { quest = {}, item = {} }
  wow.postCalls = {}
  wow.panel = { categories = {}, settings = {}, checkboxes = {}, callbacks = {} }
  wow.invalidEvents = {}         -- [event] = true: RegisterEvent raises, IsEventValid returns false
  for name, value in pairs(buildGlobals()) do
    installed[name] = true
    _G[name] = value
  end
  buildFrames()
  wow.ns = {}
end

-- Fresh world fixtures, globals, frames and timers, and an empty ns.
function wow.reset()
  wow.state = defaultState()
  wow.data = defaultData()
  resetClient()
  wow.loaded = nil
  return wow.ns
end

-- Sets the SavedVariable before ADDON_LOADED. Busted gives each spec file its own global
-- environment, so a plain `AshmarkDB = x` in a spec never reaches the addon: use this or _G.
function wow.saved(db)
  _G.AshmarkDB = db
  return db
end

-- Replaces a global or a field of a global table ("UnitReaction", "C_Map.GetMapInfo").
function wow.stub(path, value)
  local t, parts = _G, {}
  for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
  for i = 1, #parts - 1 do
    local key = parts[i]
    if type(rawget(t, key)) ~= "table" then
      t[key] = {}
      if i == 1 then installed[key] = true end
    end
    t = rawget(t, key)
  end
  local key = parts[#parts]
  if #parts == 1 then installed[key] = true end
  if getmetatable(t) == frameMeta then
    -- A frame answers every method; a removed one must read as nil for feature detection.
    local removed = rawget(t, "__removed") or {}
    removed[key] = value == nil or nil
    rawset(t, "__removed", removed)
  end
  rawset(t, key, value)
  return value
end

-- Loader ---------------------------------------------------------------------

local function exists(path)
  local f = io.open(ROOT .. path, "r")
  if f then f:close() end
  return f ~= nil
end

function wow.tocFiles()
  local files = {}
  for line in io.lines(ROOT .. TOC) do
    line = line:gsub("\r", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  return files
end

local function selected(file, paths)
  if file:match("^Core/") or file:match("^Locales/") then return true end
  for _, p in ipairs(paths or {}) do
    p = p:gsub("\\", "/"):gsub("/$", "")
    if file == p or file:sub(1, #p + 1) == p .. "/" then return true end
  end
  return false
end

-- Executes Core and Locale files, then the named files or folders, in TOC order into wow.ns.
-- Skips files that do not exist yet and XML. opts.loadAll keeps every locale table.
function wow.load(paths, opts)
  opts = opts or {}
  local ns = wow.ns
  for _, file in ipairs(wow.tocFiles()) do
    if selected(file, paths) and not file:match("%.xml$") and exists(file) then
      local chunk = assert(loadfile(ROOT .. file))
      chunk(ADDON, ns)
      if file == "Locales/Locale.lua" and opts.loadAll then ns.Locale.loadAll = true end
    end
  end
  wow.loaded = { paths = paths, opts = opts }
  return ns
end

-- ADDON_LOADED, PLAYER_LOGIN and the first PLAYER_ENTERING_WORLD; opts.reload marks a /reload.
function wow.login(opts)
  opts = opts or {}
  wow.fire("ADDON_LOADED", ADDON)
  wow.state.loggedIn = true
  wow.fire("PLAYER_LOGIN")
  wow.fire("PLAYER_ENTERING_WORLD", not opts.reload, opts.reload == true)
  return wow.ns
end

function wow.logout()
  wow.fire("PLAYER_LOGOUT")
end

-- A /reload: logout, SavedVariables written and read back, the same files, login as a reload.
-- World fixtures (units, map, data, clock) stay; frames, timers and addon state do not.
function wow.reload()
  wow.logout()
  local saved = deepcopy(_G.AshmarkDB)
  local loaded = wow.loaded or {}
  local world = wow.state
  resetClient()
  wow.state = world
  _G.AshmarkDB = saved
  wow.load(loaded.paths, loaded.opts)
  return wow.login({ reload = true })
end

wow.reset()
package.loaded["tests.helpers.wow"] = wow
return wow

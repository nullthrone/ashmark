local ADDON, ns = ...

-- The packager writes the release tag into ## Version; a copy run from the source still holds the
-- unreplaced @project-version@ token, which reads as "dev".
local tocVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.version = type(tocVersion) == "string" and tocVersion ~= "" and not tocVersion:find("@", 1, true)
  and tocVersion or "dev"
ns.debug = false
ns.ready = false

local MAX_ERRORS = 10

local modules, byName = {}, {}
local live, failed = {}, {}
local errorCount, reported, hooked = {}, {}, {}

-- Errors ------------------------------------------------------------------

local function trace(err)
  if debugstack then
    return tostring(err) .. "\n" .. debugstack(2)
  end
  return tostring(err)
end

local function moduleLabel(M)
  return ns.L[(M.opts.locale or M.name:upper()) .. "_MODULE_NAME"]
end

local function fail(M)
  failed[M] = true
  M.enabled = false
  ns.Print(ns.Format(ns.L.CORE_MODULE_FAILED, { module = moduleLabel(M) }))
  ns.Combat.Run("module:" .. M.name, function() ns:SyncModules() end)
end

-- Reports once per (owner, source) per session; a module is disabled after MAX_ERRORS.
function ns:Report(owner, source, err)
  local count = (errorCount[owner] or 0) + 1
  errorCount[owner] = count
  local seen = reported[owner]
  if not seen then
    seen = {}
    reported[owner] = seen
  end
  if not seen[source] then
    seen[source] = true
    local handler = geterrorhandler and geterrorhandler()
    if handler then
      pcall(handler, string.format("%s %s (%s): %s", ADDON, owner.name, tostring(source), tostring(err)))
    end
  end
  if count >= MAX_ERRORS and not owner.core and not failed[owner] then
    fail(owner)
  end
end

local function finish(owner, source, ok, ...)
  if not ok then
    ns:Report(owner, source, (...))
    return false
  end
  return true, ...
end

-- Stock Lua 5.1 xpcall forwards no arguments, so the call closes over them (3.6). The client's
-- xpcall may forward them; checked once at load, the call then allocates nothing.
local forwards = select(2, xpcall(function(v) return v end, trace, true)) == true

function ns:Call(owner, source, fn, ...)
  local n = select("#", ...)
  if n == 0 then
    return finish(owner, source, xpcall(fn, trace))
  end
  if forwards then
    return finish(owner, source, xpcall(fn, trace, ...))
  end
  local args = { ... }
  return finish(owner, source, xpcall(function() return fn(unpack(args, 1, n)) end, trace))
end

function ns.Print(text)
  local frame = DEFAULT_CHAT_FRAME
  if not frame then return end
  local title = ns.L.CORE_TITLE
  if NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.WrapTextInColorCode then
    title = NORMAL_FONT_COLOR:WrapTextInColorCode(title)
  end
  local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
  if info then
    frame:AddMessage(title .. ": " .. tostring(text), info.r, info.g, info.b)
  else
    frame:AddMessage(title .. ": " .. tostring(text))
  end
end

-- Module contract ---------------------------------------------------------

local Module = {}
Module.__index = Module

function Module:RegisterEvent(event, handler)
  return ns.Events:Register(self, event, handler)
end

function Module:RegisterUnitEvent(event, unit, handler)
  return ns.Events:RegisterUnit(self, event, unit, handler)
end

function Module:UnregisterEvent(event, unit)
  ns.Events:Unregister(self, event, unit)
end

function Module:Subscribe(topic, handler)
  ns.Bus:Subscribe(self, topic, handler)
end

function Module:Fire(topic, ...)
  ns.Bus:Fire(topic, ...)
end

-- A function that returns at once while the module is off and runs fn through the error wrapper.
function Module:Wrap(source, fn)
  return function(...)
    if not self.enabled then return end
    return select(2, ns:Call(self, source, fn, ...))
  end
end

function Module:Hook(key, install)
  local keys = hooked[self]
  if not keys then
    keys = {}
    hooked[self] = keys
  end
  if keys[key] then return end
  keys[key] = true
  ns:Call(self, key, install)
end

function Module:Char()
  return ns.DB:Char()
end

function Module:Setting(name)
  return ns.Settings:Get(self.name .. "." .. name)
end

function Module:Stat(name, delta)
  local char = ns.DB:Char()
  local stats = char and char.stats
  if type(stats) ~= "table" then return 0 end
  local key = self.name .. "." .. name
  local value = stats[key] or 0
  if ns.DB.readOnly or not delta or delta == 0 then return value end
  value = value + delta
  stats[key] = value
  return value
end

function ns:NewModule(name, opts)
  assert(not byName[name], "module registered twice: " .. tostring(name))
  opts = opts or {}
  local M = setmetatable({ name = name, opts = opts, enabled = false }, Module)
  modules[#modules + 1] = M
  byName[name] = M
  ns[name] = M
  local prefix = opts.locale or name:upper()
  ns.Settings:Register(name .. ".enabled", opts.default ~= false, prefix .. "_MODULE_NAME", prefix .. "_MODULE_DESC")
  return M
end

-- Core's own handlers: owners with the module helpers that are always on and never disabled.
function ns:NewService(name)
  local S = setmetatable({ name = name, enabled = true, core = true, opts = {} }, Module)
  ns[name] = S
  return S
end

function ns:GetModule(name)
  return byName[name]
end

function ns:Modules()
  local i = 0
  return function()
    i = i + 1
    return modules[i]
  end
end

-- Enabling and disabling -------------------------------------------------

local function unavailable(M)
  if ns.DB.readOnly then return { ns.DB.readOnlyReason or "schema" } end
  if failed[M] then return { "error" } end
  local reasons = {}
  for _, cap in ipairs(M.opts.requires or {}) do
    if not ns.Compat.Has[cap] then reasons[#reasons + 1] = cap end
  end
  for _, dep in ipairs(M.opts.modules or {}) do
    local D = byName[dep]
    if not (D and D.enabled) then reasons[#reasons + 1] = dep end
  end
  if #reasons > 0 then return reasons end
end

local function enable(M)
  live[M] = true
  M.enabled = true
  if M.OnEnable then ns:Call(M, "OnEnable", M.OnEnable, M) end
  if ns.ready and M.enabled and M.OnWorldReady then
    ns:Call(M, "OnWorldReady", M.OnWorldReady, M, false, false)
  end
end

local function disable(M)
  live[M] = nil
  M.enabled = false
  ns.Events:UnregisterAll(M)
  ns.Bus:UnsubscribeAll(M)
  if M.OnDisable then ns:Call(M, "OnDisable", M.OnDisable, M) end
end

-- Brings every module, in TOC order, to the state its setting and requirements ask for.
function ns:SyncModules()
  for _, M in ipairs(modules) do
    M.unavailable = unavailable(M)
    local want = not M.unavailable and ns.Settings:Get(M.name .. ".enabled") == true
    if want and not live[M] then
      enable(M)
    elseif not want and live[M] then
      disable(M)
    elseif not want then
      M.enabled = false
    end
  end
end

-- Test checks -------------------------------------------------------------

ns.Test = { checks = {} }

function ns.Test:Register(id, fn)
  for _, check in ipairs(self.checks) do
    if check.id == id then
      check.fn = fn
      return
    end
  end
  self.checks[#self.checks + 1] = { id = id, fn = fn }
end

function ns.Test:Tooltip()
  local tip = AshmarkTestTooltip or CreateFrame("GameTooltip", "AshmarkTestTooltip", UIParent, "GameTooltipTemplate")
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  return tip
end

-- Lifecycle (3.3) ---------------------------------------------------------

local Core = ns:NewService("Core")

local function onLogout()
  ns.Watch:Logout()
end

local function onWorld(self, _, isInitialLogin, isReloadingUi)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  ns.ready = true
  ns.Watch:Baseline()
  for _, M in ipairs(modules) do
    if M.enabled and M.OnWorldReady then
      ns:Call(M, "OnWorldReady", M.OnWorldReady, M, isInitialLogin, isReloadingUi)
    end
  end
  ns.Watch:WorldReady()
  ns.Log:WorldReady()
end

local function onLogin(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  ns.Identity:Refresh()
  ns.Compat.Refresh(true)
  ns.Comm:Start()
  ns.Names:Start()
  ns.Watch:Start()
  ns:SyncModules()
  -- Built after OnEnable so module tooltips can name missing events (3.5).
  ns.Settings:Build()
end

local function onAddonLoaded(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  if not ns.Compat.IsForever() then
    ns.stopped = true
    ns.Print(ns.L.CORE_NOT_FOREVER)
    return
  end
  ns.Compat.Refresh(false)
  ns.DB:Load()
  if math.randomseed then
    math.randomseed(time() + math.floor((GetTime() % 1) * 1000000))
  end
  for _, M in ipairs(modules) do
    if M.OnInitialize then ns:Call(M, "OnInitialize", M.OnInitialize, M) end
  end
  self:RegisterEvent("PLAYER_LOGIN", onLogin)
  self:RegisterEvent("PLAYER_ENTERING_WORLD", onWorld)
  self:RegisterEvent("PLAYER_LOGOUT", onLogout)
end

-- Called by Core/Events.lua once the dispatcher exists.
function Core:Boot()
  self:RegisterEvent("ADDON_LOADED", onAddonLoaded)
end

local ADDON, ns = ...

-- ns.Settings; the Blizzard Settings API is the global Settings.
local Options = { defs = {}, order = {}, bound = {} }
ns.Settings = Options

local L = ns.L
local muted

function Options:Register(key, default, labelKey, tooltipKey)
  if not self.defs[key] then self.order[#self.order + 1] = key end
  self.defs[key] = { default = default, label = labelKey, tooltip = tooltipKey }
end

local function store()
  local db = AshmarkDB
  if type(db) == "table" and type(db.settings) == "table" then return db.settings end
end

function Options:Get(key)
  local def = self.defs[key]
  local t = store()
  local value = t and t[key]
  if not def then return value end
  if value == nil or type(value) ~= type(def.default) then return def.default end
  return value
end

local function changed(key)
  local value = Options:Get(key)
  ns.Bus:Fire("SETTINGS_CHANGED", key, value)
  local name = key:match("^(%w+)%.enabled$")
  if name and ns:GetModule(name) then
    ns.Combat.Run("module:" .. name, function() ns:SyncModules() end)
  end
end

function Options:Set(key, value)
  local def = self.defs[key]
  local t = store()
  if ns.DB.readOnly or not t or not def or type(value) ~= type(def.default) then return false end
  t[key] = value
  local setting = self.bound[key]
  if setting then
    -- Keeps the panel in step; its own change callback is muted so the change is announced once.
    muted = key
    pcall(setting.SetValue, setting, value)
    muted = nil
  end
  changed(key)
  return true
end

local function moduleName(M)
  return L[(M.opts.locale or M.name:upper()) .. "_MODULE_NAME"]
end

-- M.unavailable holds internal ids (3.2); the player reads a needed module by its name and one
-- line for any missing client feature (the test report names the capabilities).
local function reasons(M)
  local lines, client = {}, false
  for _, reason in ipairs(M.unavailable) do
    local D = ns:GetModule(reason)
    if D then
      lines[#lines + 1] = ns.Format(L.CORE_UNAVAILABLE, { capability = moduleName(D) })
    elseif reason == "error" then
      lines[#lines + 1] = ns.Format(L.CORE_MODULE_FAILED, { module = moduleName(M) })
    elseif reason == "schema" then
      lines[#lines + 1] = L.CORE_SV_NEWER
    elseif not client then
      client = true
      lines[#lines + 1] = L.CORE_UNAVAILABLE_CLIENT
    end
  end
  return table.concat(lines, "\n")
end

local function tooltip(key, def)
  local text = L[def.tooltip or key]
  local M = ns:GetModule(key:match("^(%w+)%.enabled$") or "")
  if M and M.unavailable and #M.unavailable > 0 then
    text = text .. "\n" .. reasons(M)
  end
  if M and M.missingEvents and #M.missingEvents > 0 then
    text = text .. "\n" .. ns.Format(L.CORE_MISSING_EVENTS, { events = table.concat(M.missingEvents, ", ") })
  end
  return text
end

local function bind(api, category, key, def)
  local variable = "Ashmark_" .. key
  local setting = api.RegisterAddOnSetting(category, variable, key, AshmarkDB.settings, type(def.default),
    L[def.label or key], def.default)
  local function callback()
    if muted ~= key then changed(key) end
  end
  if type(api.SetOnValueChangedCallback) == "function" then
    api.SetOnValueChangedCallback(variable, callback)
  elseif setting and setting.SetValueChangedCallback then
    setting:SetValueChangedCallback(callback)
  end
  api.CreateCheckbox(category, setting, tooltip(key, def))
  Options.bound[key] = setting
end

local function build()
  local api = Settings
  local category, layout = api.RegisterVerticalLayoutCategory("Ashmark")
  if ns.DB.readOnly then
    if layout and CreateSettingsListSectionHeaderInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.CORE_SV_NEWER))
    end
  else
    for _, key in ipairs(Options.order) do
      bind(api, category, key, Options.defs[key])
    end
  end
  api.RegisterAddOnCategory(category)
  Options.category = category
end

-- PLAYER_LOGIN, after the modules' OnEnable.
function Options:Build()
  if self.category or not ns.Compat.Has.settingsApi then return end
  ns:Call(ns.Core, "settings", build)
end

function Options:Open()
  local category = self.category
  if not category then return end
  ns.Combat.Run("settings:open", function() Settings.OpenToCategory(category:GetID()) end)
end

Options:Register("Core.chatLines", true, "CORE_SETTING_CHAT_LINES", "CORE_SETTING_CHAT_LINES_DESC")
Options:Register("Core.sounds", true, "CORE_SETTING_SOUNDS", "CORE_SETTING_SOUNDS_DESC")
Options:Register("Comm.share", true, "CORE_SETTING_SHARE", "CORE_SETTING_SHARE_DESC")

local ADDON, ns = ...
-- luacheck: read globals ButtonFrameTemplate_HideButtonBar

local UI = ns.UI or {}
ns.UI = UI

-- A Core service, so the window's events and topics have an owner that is never disabled.
local MainFrame = ns:NewService("MainFrame")
UI.MainFrame = MainFrame

local L = ns.L

local WIDTH, HEIGHT = 640, 500
local PAGE_INSET = 3             -- keeps tab pages inside the Inset's border
local REFRESH_DELAY = 0.5
local TOPICS = { "LOG_ADDED", "LOG_COMPACTED", "NAMES_UPDATED", "CONTACT_UPDATED", "HOUSE_CHANGED", "PROFILE_CHANGED" }

local frame
local tabs, sorted = {}, {}      -- [id] = tab; the same tabs in `order`
local current                    -- id of the selected tab

-- Plays a SOUNDKIT entry by name if the constant exists and Core.sounds is on.
function UI:Sound(kit)
  local id = SOUNDKIT and SOUNDKIT[kit]
  if id and ns.Settings:Get("Core.sounds") then PlaySound(id) end
end

-- Tabs ---------------------------------------------------------------------

-- Errors in a module's tab count against that module (3.6).
local function call(tab, what, fn, ...)
  local owner = tab.module and ns:GetModule(tab.module) or MainFrame
  return ns:Call(owner, "tab:" .. tab.id .. ":" .. what, fn, ...)
end

local function available(tab)
  if not tab.module then return true end
  local M = ns:GetModule(tab.module)
  return M ~= nil and M.enabled == true
end

local function pick(id)
  local tab = id and tabs[id]
  if tab and available(tab) then return tab end
  tab = current and tabs[current]
  if tab and available(tab) then return tab end
  for _, candidate in ipairs(sorted) do
    if available(candidate) then return candidate end
  end
end

local function onTabClick(button)
  local tab = sorted[button:GetID()]
  if tab then MainFrame:Show(tab.id) end
end

local function tabButton(i)
  local button = frame.Tabs[i]
  if not button then
    button = CreateFrame("Button", nil, frame, "PanelTabButtonTemplate")
    button:SetID(i)
    button:SetScript("OnClick", onTabClick)
    frame.Tabs[i] = button
  end
  return button
end

-- Buttons in `order`; the visible ones are anchored in a row, tabs of disabled modules are hidden.
local function layout()
  local previous
  for i, tab in ipairs(sorted) do
    tab.index = i
    local button = tabButton(i)
    button:SetText(L[tab.label])
    PanelTemplates_TabResize(button, 0)
    button:ClearAllPoints()
    if available(tab) then
      if previous then
        button:SetPoint("TOPLEFT", previous, "TOPRIGHT", 3, 0)
      else
        button:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
      end
      button:Show()
      previous = button
    else
      button:Hide()
    end
  end
  PanelTemplates_SetNumTabs(frame, #sorted)
  local tab = current and tabs[current]
  if tab then PanelTemplates_SetTab(frame, tab.index) end
end

-- A tab is built once, the first time it is shown, into a page that fills the Inset.
local function build(tab)
  if tab.page then return end
  local inset = frame.Inset
  local page = CreateFrame("Frame", nil, inset)
  page:SetPoint("TOPLEFT", inset, "TOPLEFT", PAGE_INSET, -PAGE_INSET)
  page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -PAGE_INSET, PAGE_INSET)
  tab.page = page
  local ok, object = call(tab, "build", tab.build, page)
  if ok then tab.object = object end
end

local function refresh(tab)
  local object = tab.object
  if object and object.Refresh then call(tab, "refresh", object.Refresh, object) end
end

-- Window -------------------------------------------------------------------

local function portrait()
  frame:SetPortraitToUnit("player")
end

-- Dragging never starts in combat (ground rule 5); stopping always works.
local function startMoving()
  if not InCombatLockdown() then frame:StartMoving() end
end

local function stopMoving()
  frame:StopMovingOrSizing()
end

local function create()
  frame = CreateFrame("Frame", "AshmarkFrame", UIParent, "ButtonFrameTemplate")
  frame:Hide()
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetTitle(L.CORE_TITLE)
  -- No buttons along the bottom: the Inset reaches down to the border.
  if type(ButtonFrameTemplate_HideButtonBar) == "function" then
    pcall(ButtonFrameTemplate_HideButtonBar, frame)
  end
  local title = frame.TitleContainer
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", startMoving)
  title:SetScript("OnDragStop", stopMoving)
  frame.Tabs = {}
  frame:SetScript("OnShow", function()
    portrait()
    UI:Sound("IG_QUEST_LOG_OPEN")
  end)
  frame:SetScript("OnHide", function()
    UI:Sound("IG_QUEST_LOG_CLOSE")
  end)
  tinsert(UISpecialFrames, "AshmarkFrame")
  MainFrame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player", function()
    if frame:IsShown() then portrait() end
  end)
end

local function open(id)
  if not frame then create() end
  local tab = pick(id)
  if tab then current = tab.id end
  layout()
  if tab then
    build(tab)
    for _, other in ipairs(sorted) do
      if other.page then other.page:SetShown(other == tab) end
    end
  end
  frame:Show()
  if tab then refresh(tab) end
end

local function shownTab()
  if not (frame and frame:IsShown()) then return nil end
  local tab = current and tabs[current]
  if tab and tab.page then return tab end
end

-- Refreshes the visible tab only; if its module went away, the first available tab takes its place.
local function refreshShown()
  local tab = shownTab()
  if not tab then return end
  layout()
  if available(tab) then refresh(tab) else open() end
end

local function queueRefresh()
  ns.Combat.Run("ui:refresh", refreshShown)
end

-- At most one refresh per REFRESH_DELAY, and none while the window is closed (3.9).
local function onChange()
  if shownTab() then ns.Util.Debounce("ui:refresh", REFRESH_DELAY, queueRefresh) end
end

for _, topic in ipairs(TOPICS) do
  MainFrame:Subscribe(topic, onChange)
end

-- A module toggle: Settings syncs the modules before the debounced refresh runs, so the tab
-- row then shows the module's new state.
MainFrame:Subscribe("SETTINGS_CHANGED", function(_, _, key)
  if type(key) == "string" and key:match("%.enabled$") then onChange() end
end)

-- API (6.1) ----------------------------------------------------------------

-- def = { label = localeKey, order = n, module = name|nil, build = function(parent) return tab end }
function MainFrame:AddTab(id, def)
  assert(not tabs[id], "tab added twice: " .. tostring(id))
  local tab = { id = id, label = def.label, order = def.order or 0, module = def.module, build = def.build }
  tabs[id] = tab
  sorted[#sorted + 1] = tab
  table.sort(sorted, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.id < b.id
  end)
  if frame then ns.Combat.Run("frame:tabs", layout) end
end

function MainFrame:Show(id)
  ns.Combat.Run("frame:show", function() open(id) end)
end

-- The slash command's toggle uses the same key, so toggles queued in combat collapse into one.
function MainFrame:Toggle()
  ns.Combat.Run("frame:toggle", function()
    if frame and frame:IsShown() then
      frame:Hide()
    else
      open()
    end
  end)
end

-- Refreshes tab id now if it is the visible one (nil: whichever is visible).
function MainFrame:Refresh(id)
  ns.Combat.Run("ui:refresh:" .. tostring(id), function()
    local tab = shownTab()
    if tab and (id == nil or tab.id == id) then refresh(tab) end
  end)
end

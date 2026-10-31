local ADDON, ns = ...

-- AshmarkDialog (6.2): Ashmark's own confirmation and single-line editor. It replaces StaticPopup,
-- whose shared slots would taint Blizzard's dialogs.

local UI = ns.UI or {}
ns.UI = UI

-- A Core service, so an error in an onAccept callback is reported under the dialog's name.
local Dialog = ns:NewService("Dialog")
UI.Dialog = Dialog

local L = ns.L
local Safe = ns.Safe

local WIDTH = 320
local PAD = 16                   -- clears the dialog border
local GAP = 8
local TOP_OFFSET = -135          -- where StaticPopup1 sits
local EDIT_WIDTH, EDIT_HEIGHT = 240, 32
local BUTTON_WIDTH, BUTTON_HEIGHT = 128, 21

local frame
local current                    -- options of the dialog on screen until it is answered

local function hide()
  frame:Hide()
end

-- Answers once: in combat the dialog stays on screen until PLAYER_REGEN_ENABLED, and further
-- clicks on it do nothing.
local function answer(accepted)
  local opts = current
  if not opts then return end
  current = nil
  local text = opts.edit and frame.EditBox:GetText() or nil
  ns.Combat.Run("dialog", hide)
  if accepted and type(opts.onAccept) == "function" then
    ns:Call(Dialog, "dialog:accept", opts.onAccept, text)
  end
end

local function accept()
  answer(true)
end

local function cancel()
  answer(false)
end

local function newButton(point, x, onClick)
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  button:SetPoint(point, frame, "BOTTOM", x, PAD)
  button:SetScript("OnClick", onClick)
  return button
end

local function create()
  frame = CreateFrame("Frame", "AshmarkDialog", UIParent, "DialogBorderTemplate")
  frame:Hide()
  frame:ClearAllPoints()           -- the template fills its parent
  frame:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
  frame:SetWidth(WIDTH)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)

  local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOP", 0, -PAD)
  text:SetWidth(WIDTH - 2 * PAD)

  local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  edit:SetSize(EDIT_WIDTH, EDIT_HEIGHT)
  edit:SetPoint("TOP", text, "BOTTOM", 0, -GAP)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEnterPressed", accept)
  edit:SetScript("OnEscapePressed", cancel)

  frame.Text, frame.EditBox = text, edit
  frame.Accept = newButton("BOTTOMRIGHT", -GAP / 2, accept)
  frame.Cancel = newButton("BOTTOMLEFT", GAP / 2, cancel)
  -- Escape (UISpecialFrames) hides the dialog at any time: that is a cancel.
  frame:SetScript("OnHide", function()
    current = nil
    edit:ClearFocus()
  end)
  tinsert(UISpecialFrames, "AshmarkDialog")
end

local function label(key, fallback)
  if key then return L[key] end
  return fallback
end

-- A dialog asked for in combat appears when combat ends, while the player is moving and casting: its
-- editor then takes no keyboard focus, or the next keys would overwrite the text and Enter would accept.
local function show(opts, deferred)
  if not frame then create() end
  current = opts
  local edit, box = opts.edit, frame.EditBox
  frame.Text:SetText(opts.text)
  frame.Accept:SetText(label(opts.accept, ACCEPT))
  frame.Cancel:SetText(label(opts.cancel, CANCEL))
  local height = PAD + frame.Text:GetStringHeight() + GAP + BUTTON_HEIGHT + PAD
  if edit then
    local value = Safe.Value(edit.text)
    box:SetMaxLetters(tonumber(edit.max) or 0)
    box:SetText(type(value) == "string" and value or "")
    height = height + EDIT_HEIGHT + GAP
  end
  box:SetShown(edit ~= nil)
  frame:SetHeight(height)
  frame:Show()
  if edit and not deferred then
    box:SetFocus()
    box:HighlightText()
  end
end

-- opts = { text, edit = { text, max } or nil, accept = key, cancel = key, onAccept = fn(text) }.
-- onAccept gets the edit box's text, or nil without one. A new Show replaces a dialog on screen.
function Dialog:Show(opts)
  if type(opts) ~= "table" or Safe.IsSecret(opts.text) or type(opts.text) ~= "string" then return end
  local deferred = (InCombatLockdown and InCombatLockdown()) and true or false
  ns.Combat.Run("dialog", function() show(opts, deferred) end)
end

local _, ns = ...

-- The quest-dialog line (7.1): a strip under the quest dialog that marks a quest contradicting the
-- character's alliance (rule 3) or one the character's house stands against (rule 6). It shows at
-- once, also in combat: it is Ashmark's own unprotected frame (ground rule 5).
local M = ns.Conflicts
local Dialog = {}
M.QuestDialog = Dialog

local Safe = ns.Safe
local L = ns.L

local PAD = 8
local HIDE_ON = { "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE" }

local strip

-- A child of QuestFrameDetailPanel, so it is visible only with the quest details. Its two top corners
-- sit on QuestFrame's bottom edge: under the dialog, as wide as it, outside QuestInfo's layout chain.
local function create()
  strip = CreateFrame("Frame", nil, QuestFrameDetailPanel, "TooltipBackdropTemplate")
  strip:Hide()
  strip:SetPoint("TOPLEFT", QuestFrame, "BOTTOMLEFT")
  strip:SetPoint("TOPRIGHT", QuestFrame, "BOTTOMRIGHT")
  local text = strip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("TOPLEFT", PAD, -PAD)
  text:SetPoint("TOPRIGHT", -PAD, -PAD)
  strip.Text = text
end

local function show(text, kind)
  if not strip then create() end
  local color = kind == "house" and NORMAL_FONT_COLOR or RED_FONT_COLOR
  strip.Text:SetText(text)
  strip.Text:SetTextColor(color:GetRGB())
  strip:SetHeight(strip.Text:GetStringHeight() + 2 * PAD)
  strip:Show()
end

function Dialog:Hide()
  if strip then strip:Hide() end
end

local function hide()
  Dialog:Hide()
end

-- QUEST_DETAIL carries no quest ID; GetQuestID() names the quest on the page.
local function onDetail()
  local ok, questId = Safe.Call(GetQuestID)
  local text, kind
  if ok and type(questId) == "number" then text, kind = M:DialogLine(questId, M:Char()) end
  if text then show(text, kind) else hide() end
end

-- For the test screenshot (7.10): with the dialog open, the strip shows a sample line unless a real
-- one is showing, so the picture confirms the placement.
local function checkDialog()
  if not ns.Compat.Has.questFrame then return false, "QuestFrame or QuestFrameDetailPanel is missing" end
  if not M.enabled then return nil, "Conflicts is off" end
  if Safe.Bool(QuestFrame:IsShown()) ~= true then return nil, "talk to a quest giver first" end
  if not (strip and strip:IsShown()) then show(L.CONFLICT_TEST_DIALOG, "house") end
  if Safe.Bool(QuestFrameDetailPanel:IsVisible()) == true then return true, "shown under the quest details" end
  return true, "shown; it is visible on a quest's details page"
end

-- OnInitialize
function Dialog:Initialize()
  ns.Test:Register("Conflicts.questDialog", checkDialog)
end

-- OnEnable; without QuestFrame the rules still run and only the line is missing.
function Dialog:Enable()
  if not ns.Compat.Has.questFrame then return end
  M:RegisterEvent("QUEST_DETAIL", onDetail)
  for _, event in ipairs(HIDE_ON) do M:RegisterEvent(event, hide) end
  M:Hook("QuestFrame:OnHide", function()
    QuestFrame:HookScript("OnHide", M:Wrap("QuestFrame:OnHide", hide))
  end)
end

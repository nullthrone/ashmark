local ADDON, ns = ...

local UI = ns.UI or {}
ns.UI = UI

local Notice = {}
UI.Notice = Notice

local HOLD, FADE = 3, 1          -- seconds at full alpha, then seconds fading out

local frame

local function hide()
  -- A notice shown since the fade ended keeps the frame.
  if not frame.Fade:IsPlaying() then frame:Hide() end
end

local function create()
  frame = CreateFrame("Frame", "AshmarkNoticeFrame", UIParent)
  frame:Hide()
  frame:SetFrameStrata("HIGH")
  frame:SetSize(1, 1)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  text:SetPoint("TOP")
  frame.Text = text
  local fade = frame:CreateAnimationGroup()
  fade:SetToFinalAlpha(true)
  local alpha = fade:CreateAnimation("Alpha")
  alpha:SetFromAlpha(1)
  alpha:SetToAlpha(0)
  alpha:SetStartDelay(HOLD)
  alpha:SetDuration(FADE)
  fade:SetScript("OnFinished", function() ns.Combat.Run("notice:hide", hide) end)
  frame.Fade = fade
end

local function show(text)
  if not frame then create() end
  local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
  if info then frame.Text:SetTextColor(info.r, info.g, info.b) end
  frame.Text:SetText(text)
  frame.Fade:Stop()
  frame:SetAlpha(1)
  frame:Show()
  frame.Fade:Play()
end

-- Centre-screen line (6.2). In combat only the latest notice waits for PLAYER_REGEN_ENABLED.
function Notice:Show(text)
  if ns.Safe.IsSecret(text) or type(text) ~= "string" or text == "" then return end
  ns.Combat.Run("notice", function() show(text) end)
end

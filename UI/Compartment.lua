local ADDON, ns = ...

local L = ns.L

-- Before 11.0 the click passes the mouse button's name; since then, a table with buttonName.
local function mouseButton(input)
  if type(input) == "table" then return input.buttonName end
  return input
end

-- The TOC names these three globals (## AddonCompartmentFunc*), so they cannot be locals.
function Ashmark_OnAddonCompartmentClick(_, input)
  if ns.stopped then
    ns.Print(L.CORE_NOT_FOREVER)
  elseif mouseButton(input) == "RightButton" then
    ns.Settings:Open()
  else
    ns.UI.MainFrame:Toggle()
  end
end

function Ashmark_OnAddonCompartmentEnter(_, button)
  if type(button) ~= "table" then return end
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText(L.CORE_TITLE, HIGHLIGHT_FONT_COLOR:GetRGB())
  GameTooltip:AddLine(L.CORE_COMPARTMENT_CLICK, NORMAL_FONT_COLOR:GetRGB())
  GameTooltip:AddLine(L.CORE_COMPARTMENT_RIGHT_CLICK, NORMAL_FONT_COLOR:GetRGB())
  GameTooltip:Show()
end

function Ashmark_OnAddonCompartmentLeave(_, button)
  if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
end

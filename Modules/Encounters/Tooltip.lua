local _, ns = ...

-- The unit tooltip line (7.4): how often this character met the player under the mouse and where, and
-- the archetype Fiction knows for them. Added inside the tooltip post-call, also in combat; the post-call
-- reads stored data and cached names only, and writes nothing.
local M = ns.Encounters
local Tooltip = {}
M.Tooltip = Tooltip

local Safe = ns.Safe
local L = ns.L

local function displayedGuid(tooltip)
  local ok, _, _, guid = Safe.Call(TooltipUtil and TooltipUtil.GetDisplayedUnit, tooltip)
  if ok then return guid end
end

-- Everything after the tooltip gate, as one function of (tooltip, data); the test check runs it on its own
-- tooltip. Returns true when it added the line.
function Tooltip.Fill(tooltip, data)
  local guid, ok = Safe.Field(data, "guid")
  if not ok then return false end
  if guid == nil then guid = displayedGuid(tooltip) end
  local rec = type(guid) == "string" and M:Met(guid, M:Char())
  if not (rec and type(rec.count) == "number") then return false end
  local text = rec.lastPlace and ns.Format(L.ENC_TOOLTIP, { count = rec.count, place = ns.Names.Map(rec.lastPlace) })
    or ns.Format(L.ENC_TOOLTIP_NOPLACE, { count = rec.count })
  tooltip:AddLine(text, NORMAL_FONT_COLOR:GetRGB())
  local archetype = M:PeerLabel(guid)
  if archetype then
    tooltip:AddLine(ns.Format(L.ENC_TOOLTIP_PEER, { archetype = archetype }), HIGHLIGHT_FONT_COLOR:GetRGB())
  end
  -- Ground rule 11: Encounters may resize the tooltip after its own lines.
  tooltip:Show()
  return true
end

local function onUnit(tooltip, data)
  if tooltip ~= GameTooltip or tooltip:IsForbidden() then return end
  Tooltip.Fill(tooltip, data)
end

-- Test check (7.10) --------------------------------------------------------------------------

local hooked = false

-- A contact this character has met, so a bail-out shows the secret was refused, not an unknown GUID.
local function sampleGuid()
  local guid = next(M:Known(M:Char()))
  return guid, guid ~= nil
end

local function run(data)
  local tip = ns.Test:Tooltip()
  local before = tip:NumLines()
  local done, added = pcall(Tooltip.Fill, tip, data)
  local lines = tip:NumLines() - before
  tip:Hide()
  return done, added == true, lines
end

-- Secret input changes nothing and raises nothing; a known contact, if there is one, gets its line.
local function checkSecret()
  if type(secretwrap) ~= "function" then return nil, "no secretwrap" end
  local guid, known = sampleGuid()
  guid = guid or ns.playerGUID or "Player-0-00000000"
  local made, inputs = pcall(function()
    return { table = secretwrap({ guid = guid }), guid = { guid = secretwrap(guid) } }
  end)
  if not made then return false, "secretwrap: " .. tostring(inputs) end
  local failed = {}
  for _, name in ipairs({ "table", "guid" }) do
    local done, added, lines = run(inputs[name])
    if not done or added or lines ~= 0 then failed[#failed + 1] = name end
  end
  local detail = #failed == 0 and "secret table and secret guid change nothing"
    or ("changed or raised on secret " .. table.concat(failed, ", "))
  local plain = true
  if known then
    local done, added = run({ guid = guid })
    plain = done and added
    detail = detail .. (plain and "; a known contact gets the line" or "; a known contact got no line")
  end
  detail = detail .. "; post-call " .. (hooked and "installed" or "not installed")
  return #failed == 0 and plain, detail
end

-- Lifecycle (called by Encounters.lua) ------------------------------------------------------------

function Tooltip:Initialize()
  ns.Test:Register("Encounters.tooltip", checkSecret)
end

-- Without the tooltip processor the module still records contacts; only the line is missing.
function Tooltip:Enable()
  local types = ns.Compat.Has.tooltipProcessor and Enum.TooltipDataType
  if not (types and types.Unit ~= nil) then return end
  M:Hook("tooltip:unit", function()
    TooltipDataProcessor.AddTooltipPostCall(types.Unit, M:Wrap("tooltip:unit", onUnit))
    hooked = true
  end)
end

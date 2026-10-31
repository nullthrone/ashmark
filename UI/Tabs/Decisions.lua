local _, ns = ...

-- The Decisions tab (6.1, 7.1), in the reputation frame's pattern: collapsible zone headers and under
-- each one row per conflict with its title and both sides, the side taken and since when (or open) and
-- how often the word was broken there. The total of broken words sits above the list.

local UI = ns.UI
local Conflicts = ns.Conflicts
local L = ns.L

local EXTENT = 34                -- two lines per conflict
local TOP = 30                   -- room for the total above the list
local INDENT = 22                -- rows start where their header's text starts
local PAD = 8

local function day(t)
  local d = date("*t", t)
  if type(FormatShortDate) == "function" then return FormatShortDate(d.day, d.month, d.year % 100) end
  return date("%Y-%m-%d", t)
end

-- Rows ---------------------------------------------------------------------

local function newText(button, font)
  local text = button:CreateFontString(nil, "OVERLAY", font)
  text:SetJustifyH("LEFT")
  return text
end

-- Header rows are drawn by the list itself (6.1); this sets up a conflict row once per pooled button.
local function initRow(button, data)
  if not button.sides then
    local sides = newText(button, "GameFontHighlight")
    sides:SetPoint("TOPLEFT", INDENT, -4)
    sides:SetPoint("RIGHT", -PAD, 0)
    local broken = newText(button, "GameFontHighlightSmall")
    broken:SetPoint("BOTTOMRIGHT", -PAD, 5)
    broken:SetJustifyH("RIGHT")
    broken:SetTextColor(RED_FONT_COLOR:GetRGB())
    local status = newText(button, "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", INDENT, 5)
    status:SetPoint("RIGHT", broken, "LEFT", -PAD, 0)
    button.sides, button.status, button.broken = sides, status, broken
  end
  button.sides:SetText(data.sides)
  button.status:SetText(data.status)
  button.status:SetTextColor((data.open and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
  button.broken:SetText(data.broken)
end

local function conflictRow(char, conflict)
  local side, since, broken = Conflicts:Decision(char, conflict.id)
  local status = L.CONFLICT_TAB_OPEN
  if side then
    status = ns.Format(L.CONFLICT_TAB_ALLIED, { faction = Conflicts:SideName(conflict, side), date = day(since) })
  end
  local a, b = Conflicts:SideName(conflict, "A"), Conflicts:SideName(conflict, "B")
  return {
    id = conflict.id,
    sides = ns.Format(ns.Util.StartsWithSound(b, "o") and L.CONFLICT_TAB_SIDES_VOWEL or L.CONFLICT_TAB_SIDES,
      { title = Conflicts:Title(conflict), a = a, b = b }),
    status = status,
    open = side == nil,
    broken = broken > 0 and ns.Format(L.CONFLICT_TAB_BROKEN, { count = broken }) or "",
  }
end

-- Conflicts grouped by zone, the zones by name.
local function zones()
  local byZone, order = {}, {}
  for _, conflict in ipairs(Conflicts:All()) do
    local group = byZone[conflict.zone]
    if not group then
      group = { zone = conflict.zone, name = ns.Names.Map(conflict.zone), conflicts = {} }
      byZone[conflict.zone] = group
      order[#order + 1] = group
    end
    group.conflicts[#group.conflicts + 1] = conflict
  end
  table.sort(order, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.zone < b.zone
  end)
  return order
end

-- Every header with all its rows: the list keeps collapsed headers collapsed (6.1).
local function rows(char)
  local out = {}
  for _, group in ipairs(zones()) do
    out[#out + 1] = { header = true, key = group.zone, text = group.name }
    for _, conflict in ipairs(group.conflicts) do out[#out + 1] = conflictRow(char, conflict) end
  end
  return out
end

-- Tab ----------------------------------------------------------------------

local function refresh(tab)
  local char = ns.DB:Char()
  local list = rows(char)
  tab.List:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
  local broken = Conflicts:Violations(char)
  tab.Total:SetText(broken > 0 and ns.Format(L.CONFLICT_TAB_VIOLATIONS, { count = broken })
    or L.CONFLICT_TAB_NO_VIOLATIONS)
  tab.Empty:SetShown(#list == 0)
end

local function build(parent)
  local total = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  total:SetPoint("TOPLEFT", PAD, -PAD)
  total:SetPoint("RIGHT", -PAD, 0)
  total:SetJustifyH("LEFT")
  local body = CreateFrame("Frame", nil, parent)
  body:SetPoint("TOPLEFT", 0, -TOP)
  body:SetPoint("BOTTOMRIGHT")
  local empty = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -PAD)
  empty:SetText(L.CONFLICT_TAB_EMPTY)
  parent.List = UI:List(body, { extent = EXTENT, init = initRow, owner = Conflicts })
  parent.Total, parent.Empty = total, empty
  parent.Refresh = refresh
  return parent
end

UI.MainFrame:AddTab("decisions", { label = "CONFLICT_TAB", order = 20, module = "Conflicts", build = build })

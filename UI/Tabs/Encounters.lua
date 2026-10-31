local _, ns = ...

-- The Encounters tab (6.1, 7.4), in the friends list's pattern: one row per person this character has met,
-- the most recent meeting first. A row shows the class icon, the name in class colour with the marker for a
-- recurring contact, the note, and below them how often and where they last met; the row's button opens the
-- note editor, its tooltip shows the rest.

local UI = ns.UI
local Encounters = ns.Encounters
local L = ns.L

local EXTENT = 34                -- two lines, as in the friends list
local TOP = 30                   -- room for the total above the list
local PAD = 8
local GAP = 6
local ICON = 24
local BUTTON_WIDTH, BUTTON_HEIGHT = 64, 22
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function day(t)
  local d = date("*t", t)
  if type(FormatShortDate) == "function" then return FormatShortDate(d.day, d.month, d.year % 100) end
  return date("%Y-%m-%d", t)
end

-- Rows ---------------------------------------------------------------------------------

local function newText(button, font)
  local text = button:CreateFontString(nil, "OVERLAY", font)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  return text
end

local function onNoteClick(button)
  local row = button:GetParent()
  if row.guid then Encounters:EditNote(row.guid) end
end

local function onEnter(row)
  local data = row.data
  if not data then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(data.name)
  GameTooltip:AddLine(data.who, HIGHLIGHT_FONT_COLOR:GetRGB())
  GameTooltip:AddLine(data.info, GRAY_FONT_COLOR:GetRGB())
  if data.first then GameTooltip:AddLine(data.first, GRAY_FONT_COLOR:GetRGB()) end
  if data.note ~= "" then
    local r, g, b = NORMAL_FONT_COLOR:GetRGB()
    GameTooltip:AddLine(data.note, r, g, b, true)
  end
  GameTooltip:Show()
end

local function onLeave(row)
  if GameTooltip:GetOwner() == row then GameTooltip:Hide() end
end

-- Builds the row's regions once per pooled button.
local function setup(row)
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON, ICON)
  icon:SetPoint("LEFT", PAD, 0)
  local note = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  note:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  note:SetPoint("RIGHT", -PAD, 0)
  note:SetText(L.ENC_TAB_NOTE)
  note:SetScript("OnClick", onNoteClick)
  local name = newText(row, "GameFontNormal")
  name:SetPoint("TOPLEFT", icon, "TOPRIGHT", GAP, 1)
  local marker = newText(row, "GameFontHighlightSmall")
  marker:SetPoint("LEFT", name, "RIGHT", GAP, 0)
  marker:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
  local text = newText(row, "GameFontHighlightSmall")
  text:SetPoint("LEFT", marker, "RIGHT", GAP, 0)
  text:SetPoint("RIGHT", note, "LEFT", -GAP, 0)
  text:SetJustifyH("RIGHT")
  local info = newText(row, "GameFontHighlightSmall")
  info:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", GAP, -1)
  info:SetPoint("RIGHT", note, "LEFT", -GAP, 0)
  info:SetTextColor(GRAY_FONT_COLOR:GetRGB())
  row:SetHighlightTexture(HIGHLIGHT, "ADD")
  row:SetScript("OnEnter", onEnter)
  row:SetScript("OnLeave", onLeave)
  row.icon, row.name, row.marker, row.note, row.info, row.noteButton = icon, name, marker, text, info, note
end

local function initRow(row, data)
  if not row.name then setup(row) end
  row.guid, row.data = data.guid, data
  local atlas = type(GetClassAtlas) == "function" and data.class and GetClassAtlas(data.class)
  if atlas then row.icon:SetAtlas(atlas) end
  row.icon:SetShown(atlas and true or false)
  row.name:SetText(data.name)
  row.marker:SetText(data.recurring and L.ENC_RECURRING or "")
  row.note:SetText(data.note)
  row.info:SetText(data.info)
end

local function met(rec, last)
  if rec.lastPlace then
    return ns.Format(L.ENC_TAB_MET, { count = rec.count, place = ns.Names.Map(rec.lastPlace), date = day(last) })
  end
  return ns.Format(L.ENC_TAB_MET_NOPLACE, { count = rec.count, date = day(last) })
end

local function contactRow(guid, rec)
  local contact = Encounters:Contact(guid) or {}
  local note = type(contact.note) == "string" and contact.note or ""
  local last = tonumber(rec.last) or 0
  return {
    guid = guid,
    last = last,
    sortName = Encounters:DisplayName(contact),
    name = UI:ClassColored(Encounters:DisplayName(contact), contact.class),
    class = type(contact.class) == "string" and contact.class or nil,
    recurring = Encounters:IsRecurring(rec),
    note = note,
    info = met(rec, last),
    who = ns.Format(L.ENC_TAB_WHO, { race = ns.Names.Race(contact.race), class = ns.Names.Class(contact.class,
      contact.sex) }),
    first = type(rec.first) == "number" and ns.Format(L.ENC_TAB_FIRST, { date = day(rec.first) }) or nil,
  }
end

-- Contacts with a record for this character, the most recent meeting first.
local function rows(char)
  local out = {}
  for guid, rec in pairs(Encounters:Known(char)) do out[#out + 1] = contactRow(guid, rec) end
  table.sort(out, function(a, b)
    if a.last ~= b.last then return a.last > b.last end
    if a.sortName ~= b.sortName then return a.sortName < b.sortName end
    return a.guid < b.guid
  end)
  return out
end

-- Tab -------------------------------------------------------------------------------------

local function refresh(tab)
  local list = rows(ns.DB:Char())
  local recurring = 0
  for _, row in ipairs(list) do
    if row.recurring then recurring = recurring + 1 end
  end
  tab.List:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
  tab.Total:SetText(ns.Format(L.ENC_TAB_TOTAL, { count = #list, recurring = recurring }))
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
  empty:SetPoint("RIGHT", -PAD, 0)
  empty:SetJustifyH("LEFT")
  empty:SetText(L.ENC_TAB_EMPTY)
  parent.List = UI:List(body, { extent = EXTENT, init = initRow })
  parent.Total, parent.Empty = total, empty
  parent.Refresh = refresh
  return parent
end

UI.MainFrame:AddTab("encounters", { label = "ENC_TAB", order = 30, module = "Encounters", build = build })

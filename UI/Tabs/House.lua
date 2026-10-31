local _, ns = ...

-- The House tab (6.1, 7.5): the house's name and the account's Legacy, this character's three axes
-- with the archetypes at their ends, then one list with collapsible sections: the members by level,
-- the feuds siblings took up that this character does not share, the family chronicle and the
-- people the siblings keep meeting.

local UI = ns.UI
local House = ns.House
local L = ns.L

local PAD = 8
local INDENT = 22                -- rows start where their header's text starts
local ICON = 16
local EXTENT = 20
local BARS_TOP = 58
local BAR_WIDTH = 240
local BAR_STEP = 20              -- bar height and the gap below it
local POLE_GAP = 6
local LIST_TOP = 124
local FAMILY_LIMIT = 60
local RECURRING = 3              -- times met before a contact is family memory (7.4)
local SIDES = { "A", "B" }

-- Each axis with the archetype at its negative and at its positive end (7.2).
local AXES = {
  { key = "fidelity", low = "OPPORTUNIST", high = "OATHKEEPER" },
  { key = "habitat", low = "TOWNSFOLK", high = "WANDERER" },
  { key = "mercy", low = "RUTHLESS", high = "GENTLE" },
}

local RULESETS = {
  Normal = "CORE_RULESET_NORMAL", PvP = "CORE_RULESET_PVP", RP = "CORE_RULESET_RP",
  RPPvP = "CORE_RULESET_RPPVP", Hardcore = "CORE_RULESET_HARDCORE",
}

-- Rows -----------------------------------------------------------------------------

-- A sentence too long for its row shows in full in the tooltip.
local function onRowEnter(button)
  local label = button.label
  if not label:IsTruncated() then return end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText(label:GetText(), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1, true)
  GameTooltip:Show()
end

local function onRowLeave(button)
  if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
end

-- A family-memory row holds its sibling and contact; the sentence is made only when it is drawn.
local function rowText(data)
  if not data.knows then return nil end
  return ns.Format(L.HOUSE_TAB_KNOWS, { sibling = data.sibling, name = UI:ClassColored(data.name, data.class) })
end

-- Header rows are drawn by the list (6.1); members carry a class icon, other rows a sentence.
local function initRow(button, data)
  if not button.label then
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", INDENT, 0)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    button:SetScript("OnEnter", onRowEnter)
    button:SetScript("OnLeave", onRowLeave)
    button.icon, button.label = icon, label
  end
  local icon, label = button.icon, button.label
  label:SetFontObject(data.member and GameFontHighlight or GameFontHighlightSmall)
  label:ClearAllPoints()
  if data.atlas then
    icon:SetAtlas(data.atlas)
    icon:Show()
    label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
  else
    icon:Hide()
    label:SetPoint("LEFT", INDENT, 0)
  end
  label:SetPoint("RIGHT", -PAD, 0)
  label:SetText(data.text or rowText(data))
end

-- A character record's first name; "someone" for a record whose name the client never gave (Identity).
local function firstName(char)
  local name = char.name
  if type(name) == "string" and name ~= "" then return name end
  return L.CORE_UNKNOWN_PLAYER
end

local function fullName(char)
  local name = firstName(char)
  if type(char.surname) == "string" and char.surname ~= "" then return name .. " " .. char.surname end
  return name
end

local function classAtlas(class)
  if type(class) == "string" and type(GetClassAtlas) == "function" then return GetClassAtlas(class) end
end

-- By level, highest first (House:Members); the ruleset only when the members' rulesets differ.
local function memberRows(members)
  local differ = false
  for _, member in ipairs(members) do
    if member.ruleset ~= members[1].ruleset then differ = true end
  end
  local rows = {}
  for _, member in ipairs(members) do
    local text = ns.Format(L.HOUSE_TAB_MEMBER, {
      name = UI:ClassColored(fullName(member), member.class), level = tonumber(member.level) or 0,
    })
    local ruleset = differ and RULESETS[member.ruleset]
    if ruleset then text = ns.Format(L.HOUSE_TAB_MEMBER_RULESET, { member = text, ruleset = L[ruleset] }) end
    rows[#rows + 1] = { member = true, atlas = classAtlas(member.class), text = text }
  end
  return rows
end

local function sideName(conflict, side)
  local f = type(conflict[side]) == "table" and conflict[side].faction
  if f == 0 then return L.CONFLICT_UNNAMED end
  return ns.Names.Faction(f)
end

local function byFeud(a, b)
  if a.zone ~= b.zone then return a.zone < b.zone end
  if a.title ~= b.title then return a.title < b.title end
  if a.faction ~= b.faction then return a.faction < b.faction end
  return a.name < b.name
end

-- Sides siblings took in conflicts where this character stands elsewhere or nowhere yet. One row per
-- conflict, side and sibling; the conflict's title tells apart conflicts of one faction pair in one zone.
local function feudRows(char, members)
  local conflicts = ns.Conflicts
  if not conflicts then return {} end
  local byGuid = {}
  for _, member in ipairs(members) do byGuid[member.guid] = member end
  local rows = {}
  local function add(conflict, side, sibling)
    local row = { zone = ns.Names.Map(conflict.zone), title = conflicts:Title(conflict) or L.CORE_UNKNOWN_QUEST,
                  faction = sideName(conflict, side), name = firstName(sibling) }
    row.text = ns.Format(L.HOUSE_TAB_FEUD, {
      title = row.title, name = UI:ClassColored(row.name, sibling.class), faction = row.faction, zone = row.zone,
    })
    rows[#rows + 1] = row
  end
  for id, split in pairs(House:SiblingAlliances(char, members)) do
    local conflict = conflicts:Get(id)
    local own = conflicts:Alliance(char, id)
    for _, side in ipairs(SIDES) do
      if conflict and own ~= side then
        for _, guid in ipairs(split[side]) do add(conflict, side, byGuid[guid]) end
      end
    end
  end
  table.sort(rows, byFeud)
  return rows
end

local function chronicleRows(char, members)
  local rows = {}
  for _, item in ipairs(House:FamilyChronicle(char, FAMILY_LIMIT, members)) do
    rows[#rows + 1] = { text = item.text }
  end
  return rows
end

local function byName(a, b)
  if a.name ~= b.name then return a.name < b.name end
  return a.guid < b.guid
end

-- Each sibling's recurring contacts (7.4), by name; rowText words them once they are drawn.
local function memoryRows(char, members)
  local encounters = ns.Encounters
  if not encounters then return {} end
  local rows = {}
  for _, sibling in ipairs(members) do
    if sibling ~= char then
      local known = {}
      for guid in pairs(encounters:Known(sibling, RECURRING) or {}) do
        local contact = encounters:Contact(guid)
        known[#known + 1] = { knows = true, guid = guid, name = ns.Names.Player(guid),
                              class = contact and contact.class }
      end
      table.sort(known, byName)
      local name = #known > 0 and UI:ClassColored(firstName(sibling), sibling.class)
      for _, row in ipairs(known) do
        row.sibling = name
        rows[#rows + 1] = row
      end
    end
  end
  return rows
end

-- Every section with rows, under its header; the list keeps collapsed headers collapsed (6.1).
local function sections(char)
  local members = House:Members(char)
  local rows = {}
  local function section(key, label, items)
    if #items == 0 then return end
    rows[#rows + 1] = { header = true, key = key, text = L[label] }
    for _, item in ipairs(items) do rows[#rows + 1] = item end
  end
  section("members", "HOUSE_TAB_MEMBERS", memberRows(members))
  section("feuds", "HOUSE_TAB_FEUDS", feudRows(char, members))
  section("chronicle", "HOUSE_TAB_CHRONICLE", chronicleRows(char, members))
  section("memory", "HOUSE_TAB_MEMORY", memoryRows(char, members))
  return rows
end

-- Tab ----------------------------------------------------------------------------------

-- An archetype label in the form for the character's sex (5.8).
local function label(archetype, char)
  return ns.Gender("PROFILE_" .. archetype, char.sex)
end

local function showAxes(tab, char)
  local profile = ns.Profile
  local shown = profile ~= nil and char ~= nil
  tab.Archetype:SetShown(shown)
  for _, bar in ipairs(tab.Bars) do bar:SetShown(shown) end
  if not shown then return end
  local axes = profile:Axes(char)
  tab.Archetype:SetText(ns.Format(L.HOUSE_TAB_ARCHETYPE, { archetype = label(profile:Archetype(char), char) }))
  for i, axis in ipairs(AXES) do
    local value, bar = tonumber(axes[axis.key]) or 0, tab.Bars[i]
    bar:SetValue(value)
    bar.Text:SetText(tostring(value))
    bar.Low:SetText(label(axis.low, char))
    bar.High:SetText(label(axis.high, char))
  end
end

local function refresh(tab)
  local char = ns.DB:Char()
  local key = House:Key(char)
  tab.Heading:SetText(key and ns.Format(L.HOUSE_TAB_HEADING, { house = key }) or L.HOUSE_TAB_NO_HOUSE)
  tab.Legacy:SetText(House:Legacy(char) or "")
  showAxes(tab, char)
  local rows = key and sections(char) or {}
  tab.List:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
  tab.Empty:SetShown(key == nil)
end

-- The archetype at one end of a bar; its text follows the shown character (showAxes).
local function pole(bar, point, relative, x)
  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint(point, bar, relative, x, 0)
  return text
end

local function newBar(parent, i)
  local bar = UI:StatusBar(parent)
  bar:SetWidth(BAR_WIDTH)
  bar:SetPoint("TOP", parent, "TOP", 0, -(BARS_TOP + (i - 1) * BAR_STEP))
  bar:SetMinMaxValues(-100, 100)
  bar.Low = pole(bar, "RIGHT", "LEFT", -POLE_GAP)
  bar.High = pole(bar, "LEFT", "RIGHT", POLE_GAP)
  return bar
end

-- The parts hang off the tab page under parent keys, as in Blizzard's templates.
local function build(parent)
  local legacy = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  legacy:SetPoint("TOPRIGHT", -PAD, -PAD - 4)
  legacy:SetJustifyH("RIGHT")
  local heading = parent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
  heading:SetPoint("TOPLEFT", PAD, -PAD)
  heading:SetPoint("RIGHT", legacy, "LEFT", -PAD, 0)
  heading:SetJustifyH("LEFT")
  heading:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
  local archetype = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  archetype:SetPoint("TOP", parent, "TOP", 0, -(BARS_TOP - BAR_STEP - 2))
  local bars = {}
  for i = 1, #AXES do bars[i] = newBar(parent, i) end

  local body = CreateFrame("Frame", nil, parent)
  body:SetPoint("TOPLEFT", 0, -LIST_TOP)
  body:SetPoint("BOTTOMRIGHT")
  local empty = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -PAD)
  empty:SetPoint("RIGHT", -PAD, 0)
  empty:SetJustifyH("LEFT")
  empty:SetText(L.HOUSE_TAB_NONE)

  parent.List = UI:List(body, { extent = EXTENT, init = initRow, owner = House })
  parent.Heading, parent.Legacy, parent.Archetype, parent.Bars, parent.Empty = heading, legacy, archetype, bars, empty
  parent.Refresh = refresh
  return parent
end

-- Entries the tab never shows (gold, quest.turnin, item.held, ...) and item names redraw nothing.
local function ignore(topic, payload)
  if topic == "NAMES_UPDATED" then return payload == "item" end
  return topic == "LOG_ADDED" and type(payload) == "table" and not House:Concerns(payload)
end

UI.MainFrame:AddTab("house", { label = "HOUSE_TAB", order = 40, module = "House", build = build, ignore = ignore })

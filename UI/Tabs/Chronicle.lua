local ADDON, ns = ...
-- luacheck: read globals FormatShortDate ScrollBoxConstants

-- The Chronicle tab (6.1): the quest log's layout, chapters on the left and the selected
-- chapter's sentences on a parchment page on the right.

local UI = ns.UI
local Chronicle = ns.Chronicle
local L = ns.L

local LIST_WIDTH = 180           -- chapter column, scroll bar included
local GAP = 6
local PAD = 18                   -- margin of the text on the page
local CHAPTER_EXTENT = 20
local LINE_EXTENT = 34           -- two lines of QuestFont
local TITLE_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local selected                   -- chapter number the reader picked; nil follows the open chapter
local shown                      -- chapter number on the page
local parchment                  -- the page has the client's parchment; otherwise light text on the Inset

local function day(t)
  local d = date("*t", t)
  if type(FormatShortDate) == "function" then return FormatShortDate(d.day, d.month, d.year % 100) end
  return date("%Y-%m-%d", t)
end

local function place(m)
  return ns.Names.Map(m and (ns.Where.Zone(m) or m))
end

local function title(chapter, inList)
  local key = (inList and chapter.open) and "CORE_CHRONICLE_CHAPTER_OPEN" or "CORE_CHRONICLE_CHAPTER"
  return ns.Format(L[key], { roman = ns.Util.Roman(chapter.no) })
end

local function subtitle(char, chapter)
  if not chapter.open then
    return ns.Format(L.CORE_CHRONICLE_CLOSED, { date = day(chapter.closed), place = place(chapter.m) })
  end
  local first = ns.Log:Iter(char, chapter.from)()
  if first then return ns.Format(L.CORE_CHRONICLE_BEGUN, { date = day(first.t) }) end
  return L.CORE_CHRONICLE_OPEN
end

local function tint(fontString, color)
  if not parchment then fontString:SetTextColor(color:GetRGB()) end
end

-- Rows ---------------------------------------------------------------------

local function onChapterClick(button)
  if button.no == shown then return end
  selected = button.no
  UI:Sound("IG_ABILITY_PAGE_TURN")
  UI.MainFrame:Refresh("chronicle")
end

-- Quest log titles: gold, white under the mouse, the selected one locked in its highlight.
local function initChapter(button, data)
  if not button.label then
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    button:SetFontString(label)
    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetHighlightTexture(TITLE_HIGHLIGHT, "ADD")
    button:SetScript("OnClick", onChapterClick)
    button.label = label
  end
  button.no = data.no
  button:SetText(data.text)
  if data.current then button:LockHighlight() else button:UnlockHighlight() end
end

-- A sentence too long for its row shows in full in the tooltip.
local function onLineEnter(button)
  local text = button.text
  if not text:IsTruncated() then return end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText(text:GetText(), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1, true)
  GameTooltip:Show()
end

local function onLineLeave(button)
  if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
end

local function initLine(button, data)
  if not button.text then
    local text = button:CreateFontString(nil, "OVERLAY", "QuestFont")
    text:SetPoint("TOPLEFT", 0, -2)
    text:SetPoint("BOTTOMRIGHT", 0, 2)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    tint(text, HIGHLIGHT_FONT_COLOR)
    button:SetScript("OnEnter", onLineEnter)
    button:SetScript("OnLeave", onLineLeave)
    button.text = text
  end
  button.text:SetText(data.text)
end

-- Tab ----------------------------------------------------------------------

local function find(chapters, no)
  for _, chapter in ipairs(chapters) do
    if chapter.no == no then return chapter end
  end
end

-- A new data provider per refresh; the page keeps its scroll position while it shows the same chapter.
local function fill(box, rows, keepScroll)
  local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
  local discard = ScrollBoxConstants and ScrollBoxConstants.DiscardScrollPosition
  box:SetDataProvider(CreateDataProvider(rows), keepScroll and retain or discard)
end

local function refresh(tab)
  local char = ns.DB:Char()
  local chapters = char and Chronicle:Chapters(char) or {}
  local chapter = selected and find(chapters, selected)
  if not chapter then
    selected, chapter = nil, chapters[#chapters]
  end
  local rows = {}
  for i = #chapters, 1, -1 do
    local c = chapters[i]
    rows[#rows + 1] = { no = c.no, text = title(c, true), current = c == chapter }
  end
  fill(tab.Chapters, rows, true)
  local no = chapter and chapter.no
  local lines = chapter and Chronicle:Lines(char, chapter, { char = char, own = true }) or {}
  fill(tab.Lines, lines, no == shown)
  shown = no
  tab.Heading:SetText(chapter and title(chapter) or "")
  tab.Subtitle:SetText(chapter and subtitle(char, chapter) or "")
  tab.Empty:SetText(char and L.CORE_CHRONICLE_EMPTY or L.CORE_CHRONICLE_NO_RECORD)
  tab.Empty:SetShown(#lines == 0)
end

local function newText(parent, font, color)
  local fontString = parent:CreateFontString(nil, "OVERLAY", font)
  fontString:SetPoint("RIGHT", -PAD, 0)
  fontString:SetJustifyH("LEFT")
  tint(fontString, color)
  return fontString
end

-- The parts hang off the tab page under parent keys, as in Blizzard's templates.
local function build(parent)
  local column = CreateFrame("Frame", nil, parent)
  column:SetPoint("TOPLEFT")
  column:SetPoint("BOTTOMLEFT")
  column:SetWidth(LIST_WIDTH)

  local page = CreateFrame("Frame", nil, parent)
  page:SetPoint("TOPLEFT", column, "TOPRIGHT", GAP, 0)
  page:SetPoint("BOTTOMRIGHT")
  local background = page:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  parchment = UI:Parchment(background)
  if not parchment then background:Hide() end

  local heading = newText(page, "QuestTitleFont", NORMAL_FONT_COLOR)
  heading:SetPoint("TOPLEFT", PAD, -PAD)
  local sub = newText(page, "QuestFont", HIGHLIGHT_FONT_COLOR)
  sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
  local body = CreateFrame("Frame", nil, page)
  body:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
  body:SetPoint("BOTTOMRIGHT", -GAP, PAD)
  local empty = newText(page, "QuestFont", HIGHLIGHT_FONT_COLOR)
  empty:SetPoint("TOPLEFT", body, "TOPLEFT")

  parent.Chapters = UI:List(column, { extent = CHAPTER_EXTENT, init = initChapter })
  parent.Lines = UI:List(body, { extent = LINE_EXTENT, init = initLine })
  parent.Parchment, parent.Heading, parent.Subtitle, parent.Empty = background, heading, sub, empty
  parent.Refresh = refresh
  return parent
end

UI.MainFrame:AddTab("chronicle", { label = "CORE_TAB_CHRONICLE", order = 10, build = build })

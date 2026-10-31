local ADDON, ns = ...

-- Shared widgets (6.1): the scrolling list with collapsible headers, the parchment, class colours
-- and the status bar. Every piece is a Blizzard template or client texture.

local UI = ns.UI or {}
ns.UI = UI

-- Client parchment atlases, in order of preference; the test mode reports each one (7.10).
UI.PARCHMENT_ATLASES = { "QuestBG-Parchment" }

local DEFAULT_EXTENT = 20
local BAR_SPACE = 14             -- MinimalScrollBar and the gap before it, inside the parent
local BAR_GAP = 6
local TOGGLE_SIZE = 16
local BAR_HEIGHT = 14
local TRACK_ALPHA = 0.5

-- The quest log's header toggles, present in every client.
local EXPAND = "Interface\\Buttons\\UI-PlusButton-Up"
local COLLAPSE = "Interface\\Buttons\\UI-MinusButton-Up"
local TOGGLE_GLOW = "Interface\\Buttons\\UI-PlusButton-Hilight"
local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"

-- List ---------------------------------------------------------------------
--
-- Header rows (data.header = true) are drawn by the list: the quest log's +/- toggle and
-- data.text. A header's children are the rows after it up to the next header. Collapsing one
-- rebuilds the data provider without them; the state is kept per header (data.key, else
-- data.text), so every later SetDataProvider with the full rows leaves the header collapsed.
--
-- The scroll box recycles one pool of frames for both kinds of row, so each pooled frame carries
-- two children: the list's header and the row handed to opts.init. Only one of them is shown,
-- and neither ever sees the other's regions.

local function headerKey(data)
  return data.key or data.text
end

local function retainScroll()
  return ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
end

-- The caller's provider unchanged while nothing is collapsed, otherwise a filtered copy.
local function visible(list, provider)
  if not provider or next(list.collapsed) == nil then return provider end
  local rows, hiding = {}, false
  for _, data in provider:Enumerate() do
    if data.header then hiding = list.collapsed[headerKey(data)] == true end
    if data.header or not hiding then rows[#rows + 1] = data end
  end
  return CreateDataProvider(rows)
end

local function onHeaderClick(header)
  local list, key = header.list, headerKey(header.data)
  if key == nil then return end
  list.collapsed[key] = not list.collapsed[key] or nil
  list.setDataProvider(list.box, visible(list, list.full), retainScroll())
end

local function newHeader(frame, list)
  local header = CreateFrame("Button", nil, frame)
  header:SetAllPoints()
  local icon = header:CreateTexture(nil, "ARTWORK")
  icon:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
  icon:SetPoint("LEFT", 2, 0)
  local glow = header:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture(TOGGLE_GLOW)
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(icon)
  local label = header:CreateFontString(nil, "OVERLAY")
  label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
  label:SetPoint("RIGHT", -4, 0)
  label:SetJustifyH("LEFT")
  header:SetFontString(label)
  header:SetNormalFontObject(GameFontNormal)
  header:SetHighlightFontObject(GameFontHighlight)
  header:SetScript("OnClick", onHeaderClick)
  header.icon, header.list = icon, list
  frame.header = header
  return header
end

local function newRow(frame)
  local row = CreateFrame("Button", nil, frame)
  row:SetAllPoints()
  frame.row = row
  return row
end

local function initElement(list, frame, data)
  if data.header then
    local header = frame.header or newHeader(frame, list)
    if frame.row then frame.row:Hide() end
    header.data = data
    header:SetText(data.text)
    header.icon:SetTexture(list.collapsed[headerKey(data)] and EXPAND or COLLAPSE)
    header:Show()
  else
    local row = frame.row or newRow(frame)
    if frame.header then frame.header:Hide() end
    row:Show()
    list.init(row, data)
  end
end

-- opts = { extent = n, init = function(button, data) end } -> scrollBox, dataProvider
function UI:List(parent, opts)
  local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
  box:SetPoint("TOPLEFT")
  box:SetPoint("BOTTOMRIGHT", -BAR_SPACE, 0)
  local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", BAR_GAP, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", BAR_GAP, 0)

  local list = { box = box, init = opts.init, collapsed = {}, setDataProvider = box.SetDataProvider }
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(opts.extent or DEFAULT_EXTENT)
  view:SetElementInitializer("Button", function(frame, data) initElement(list, frame, data) end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

  -- Callers keep passing their full rows (6.1); the list applies its collapsed headers to them.
  function box.SetDataProvider(scrollBox, provider, retain)
    list.full = provider
    return list.setDataProvider(scrollBox, visible(list, provider), retain)
  end

  local provider = CreateDataProvider()
  box:SetDataProvider(provider)
  return box, provider
end

-- Parchment ----------------------------------------------------------------

-- Puts the first parchment atlas the client has on texture; false if it has none (6).
function UI:Parchment(texture)
  local info = C_Texture and C_Texture.GetAtlasInfo
  if type(info) ~= "function" then return false end
  for _, atlas in ipairs(UI.PARCHMENT_ATLASES) do
    if info(atlas) then
      texture:SetAtlas(atlas)
      return true
    end
  end
  return false
end

-- Text ---------------------------------------------------------------------

-- text in the class colour of classFile ("WARRIOR"); plain text for an unknown class.
function UI:ClassColored(text, classFile)
  if ns.Safe.IsSecret(text) then return "" end
  text = tostring(text or "")
  local class = ns.Safe.Value(classFile)
  local get = C_ClassColor and C_ClassColor.GetClassColor
  local color = type(class) == "string" and type(get) == "function" and get(class)
  if color then return color:WrapTextInColorCode(text) end
  return text
end

-- Status bar ---------------------------------------------------------------

-- A StatusBar with the standard texture over a dimmed track, and a centred label in bar.Text.
-- The caller sets its size, range, value and, if it likes, a colour from a Blizzard colour object.
function UI:StatusBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(BAR_HEIGHT)
  bar:SetStatusBarTexture(STATUSBAR)
  bar:SetStatusBarColor(NORMAL_FONT_COLOR:GetRGB())
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetTexture(STATUSBAR)
  local r, g, b = GRAY_FONT_COLOR:GetRGB()
  track:SetVertexColor(r, g, b, TRACK_ALPHA)
  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  bar.Track, bar.Text = track, text
  return bar
end

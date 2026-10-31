local wow = require("tests.helpers.wow")

-- A scroll box that behaves like the client's for what the list relies on: one pool of element
-- frames, released and reacquired (first released, first reused) on every SetDataProvider, each
-- acquired frame run through the view's initializer. Status bars record their texture and colour.
local function fakeClient()
  wow.stub("ScrollBoxConstants", { RetainScrollPosition = true, DiscardScrollPosition = false })
  wow.stub("CreateScrollBoxListLinearView", function()
    local view = {}
    function view:SetElementExtent(extent) self.extent = extent end
    function view:SetElementInitializer(kind, fn) self.kind, self.initializer = kind, fn end
    return view
  end)
  local create = CreateFrame
  wow.stub("CreateFrame", function(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    if template == "WowScrollBoxList" then
      frame.pool, frame.elements, frame.calls = {}, {}, 0
      function frame:SetDataProvider(provider, retain)
        self.calls = self.calls + 1
        for _, element in ipairs(self.elements) do
          element:Hide()
          self.pool[#self.pool + 1] = element
        end
        self.elements, self.provider, self.retain = {}, provider, retain
        for _, data in provider:Enumerate() do
          local element = table.remove(self.pool, 1) or create(self.view.kind, nil, self.ScrollTarget)
          element:Show()
          self.view.initializer(element, data)
          self.elements[#self.elements + 1] = element
        end
      end
    elseif kind == "StatusBar" then
      function frame:SetStatusBarTexture(texture) self.texture = texture end
      function frame:SetStatusBarColor(r, g, b) self.color = { r, g, b } end
    end
    return frame
  end)
end

local function rows(...)
  local out = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    out[i] = type(v) == "table" and v or { text = v }
  end
  return out
end

describe("UI Widgets", function()
  local ns, UI

  before_each(function()
    wow.reset()
    fakeClient()
    ns = wow.load({ "UI/Widgets.lua" })
    UI = ns.UI
    wow.login()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("List", function()
    local parent, seen

    -- The text of each element on screen: a header's label, or what init wrote on a row.
    local function screen(box)
      local out = {}
      for _, element in ipairs(box.elements) do
        if element.header and element.header:IsShown() then
          out[#out + 1] = "+" .. element.header:GetText()
        else
          out[#out + 1] = element.row.text
        end
      end
      return out
    end

    local function list(extent)
      seen = {}
      return UI:List(parent, {
        extent = extent,
        init = function(button, data)
          seen[#seen + 1] = data
          button.text = data.text
        end,
      })
    end

    before_each(function()
      parent = CreateFrame("Frame", nil, UIParent)
    end)

    it("builds a WowScrollBoxList with a MinimalScrollBar that fill the parent", function()
      local box, provider = list(34)
      local bar = box.bar
      assert.equal("WowScrollBoxList", box.__template)
      assert.equal("MinimalScrollBar", bar.__template)
      assert.equal("EventFrame", bar:GetObjectType())
      assert.same({ parent, parent }, { box:GetParent(), bar:GetParent() })
      assert.equal("TOPLEFT", (box:GetPoint(1)))
      local point, x = box:GetPoint(2)
      assert.equal("BOTTOMRIGHT", point)
      assert.is_true(x < 0)
      assert.equal(box, select(2, bar:GetPoint(1)))
      assert.equal(box, select(2, bar:GetPoint(2)))
      assert.same({ 34, "Button" }, { box.view.extent, box.view.kind })
      assert.equal(provider, box.provider)
      assert.equal(0, provider:GetSize())
    end)

    it("uses an extent of 20 when none is given", function()
      local box = list()
      assert.equal(20, box.view.extent)
    end)

    it("hands each row to init on a button of its own that the recycled frame keeps", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows("a", "b")))
      local first = box.elements[1].row
      assert.equal("Button", first:GetObjectType())
      assert.equal(box.elements[1], first:GetParent())
      assert.same({ "a", "b" }, screen(box))
      box:SetDataProvider(CreateDataProvider(rows("c")))
      assert.equal(first, box.elements[1].row)
      assert.same({ "c" }, screen(box))
    end)

    it("passes the caller's provider and scroll flag through while nothing is collapsed", function()
      local box = list()
      local provider = CreateDataProvider(rows({ header = true, text = "Desolace" }, "a"))
      box:SetDataProvider(provider, true)
      assert.equal(provider, box.provider)
      assert.is_true(box.retain)
    end)

    it("draws header rows itself, in the quest log's colours, and never hands them to init", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows({ header = true, text = "Desolace" }, "a", "b")))
      assert.same({ "+Desolace", "a", "b" }, screen(box))
      assert.same({ "a", "b" }, { seen[1].text, seen[2].text })
      local header = box.elements[1].header
      assert.is_nil(box.elements[1].row)
      assert.equal("Interface\\Buttons\\UI-MinusButton-Up", header.icon:GetTexture())
    end)

    it("collapses a header on click and expands it again, keeping the scroll position", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows({ header = true, text = "Desolace" }, "a", "b",
                                                  { header = true, text = "Durotar" }, "c")))
      wow.script(box.elements[1].header, "OnClick")
      assert.same({ "+Desolace", "+Durotar", "c" }, screen(box))
      assert.is_true(box.retain)
      assert.equal("Interface\\Buttons\\UI-PlusButton-Up", box.elements[1].header.icon:GetTexture())
      assert.equal("Interface\\Buttons\\UI-MinusButton-Up", box.elements[2].header.icon:GetTexture())

      wow.script(box.elements[1].header, "OnClick")
      assert.same({ "+Desolace", "a", "b", "+Durotar", "c" }, screen(box))
      assert.equal("Interface\\Buttons\\UI-MinusButton-Up", box.elements[1].header.icon:GetTexture())
    end)

    it("keeps a header collapsed when the caller sets new rows, by key or else by text", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows({ header = true, key = 1443, text = "Desolace" }, "a",
                                                  { header = true, text = "Durotar" }, "b")))
      wow.script(box.elements[1].header, "OnClick")
      wow.script(box.elements[2].header, "OnClick")
      assert.same({ "+Desolace", "+Durotar" }, screen(box))

      -- A refresh with the full rows; the first header's name has changed, its key has not.
      box:SetDataProvider(CreateDataProvider(rows({ header = true, key = 1443, text = "Désolace" }, "a", "x",
                                                  { header = true, text = "Durotar" }, "b",
                                                  { header = true, text = "Elwynn Forest" }, "c")), true)
      assert.same({ "+Désolace", "+Durotar", "+Elwynn Forest", "c" }, screen(box))
      assert.is_true(box.retain)
    end)

    it("never hides the rows before the first header", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows("top", { header = true, text = "Desolace" }, "a")))
      wow.script(box.elements[2].header, "OnClick")
      assert.same({ "top", "+Desolace" }, screen(box))
    end)

    it("leaves a header without key and text expanded", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows({ header = true }, "a")))
      local calls = box.calls
      wow.script(box.elements[1].header, "OnClick")
      assert.equal(calls, box.calls)
      assert.same({ "a" }, { seen[#seen].text })
    end)

    it("shows only the part of a recycled frame that its new row needs", function()
      local box = list()
      box:SetDataProvider(CreateDataProvider(rows({ header = true, text = "Desolace" }, "a")))
      local element = box.elements[1]
      box:SetDataProvider(CreateDataProvider(rows("b", { header = true, text = "Durotar" })))
      assert.equal(element, box.elements[1])
      assert.is_true(element.row:IsShown())
      assert.is_false(element.header:IsShown())
      assert.same({ "b", "+Durotar" }, screen(box))

      box:SetDataProvider(CreateDataProvider(rows({ header = true, text = "Elwynn Forest" })))
      assert.equal(element, box.elements[1])
      assert.is_true(element.header:IsShown())
      assert.is_false(element.row:IsShown())
      assert.equal("Elwynn Forest", element.header:GetText())
    end)

    it("keeps the collapsed state of each list apart", function()
      local one, two = list(), list()
      local data = rows({ header = true, text = "Desolace" }, "a")
      one:SetDataProvider(CreateDataProvider(data))
      two:SetDataProvider(CreateDataProvider(data))
      wow.script(one.elements[1].header, "OnClick")
      two:SetDataProvider(CreateDataProvider(data))
      assert.same({ "+Desolace" }, screen(one))
      assert.same({ "+Desolace", "a" }, screen(two))
    end)
  end)

  describe("Parchment", function()
    it("puts the first parchment atlas the client has on the texture", function()
      local texture = UIParent:CreateTexture()
      assert.same({ "QuestBG-Parchment" }, UI.PARCHMENT_ATLASES)
      assert.is_true(UI:Parchment(texture))
      assert.equal("QuestBG-Parchment", texture:GetAtlas())
    end)

    it("tries the candidates in order", function()
      UI.PARCHMENT_ATLASES[2] = "Other-Parchment"
      wow.data.missingAtlases["QuestBG-Parchment"] = true
      local texture = UIParent:CreateTexture()
      assert.is_true(UI:Parchment(texture))
      assert.equal("Other-Parchment", texture:GetAtlas())
    end)

    it("returns false and leaves the texture alone when the client has none", function()
      wow.data.missingAtlases["QuestBG-Parchment"] = true
      local texture = UIParent:CreateTexture()
      assert.is_false(UI:Parchment(texture))
      assert.is_nil(texture:GetAtlas())
      wow.stub("C_Texture", nil)
      assert.is_false(UI:Parchment(texture))
    end)
  end)

  describe("ClassColored", function()
    it("wraps the text in the class colour", function()
      local asked
      wow.stub("C_ClassColor.GetClassColor", function(class)
        asked = class
        return NORMAL_FONT_COLOR
      end)
      assert.equal(NORMAL_FONT_COLOR:WrapTextInColorCode("Mira"), UI:ClassColored("Mira", "MAGE"))
      assert.equal("MAGE", asked)
    end)

    it("returns the plain text for an unknown, missing or secret class", function()
      wow.stub("C_ClassColor.GetClassColor", function() end)
      assert.equal("Mira", UI:ClassColored("Mira", "NOBODY"))
      assert.equal("Mira", UI:ClassColored("Mira", nil))
      assert.equal("Mira", UI:ClassColored("Mira", wow.secret("MAGE")))
      wow.stub("C_ClassColor", nil)
      assert.equal("Mira", UI:ClassColored("Mira", "MAGE"))
    end)

    it("never concatenates a secret text", function()
      assert.equal("", UI:ClassColored(wow.secret("Mira"), "MAGE"))
    end)
  end)

  describe("StatusBar", function()
    it("is a StatusBar with the standard texture over a track, and a label", function()
      local parent = CreateFrame("Frame", nil, UIParent)
      local bar = UI:StatusBar(parent)
      assert.equal("StatusBar", bar:GetObjectType())
      assert.equal(parent, bar:GetParent())
      assert.equal("Interface\\TargetingFrame\\UI-StatusBar", bar.texture)
      assert.same({ NORMAL_FONT_COLOR:GetRGB() }, bar.color)
      assert.is_true(bar:GetHeight() > 0)
      assert.equal("Interface\\TargetingFrame\\UI-StatusBar", bar.Track:GetTexture())
      assert.equal("GameFontHighlightSmall", bar.Text.__template)
    end)
  end)

  -- The Chronicle tab against the real List and Parchment instead of the fakes of its own spec.
  describe("with the Chronicle tab", function()
    before_each(function()
      wow.reset()
      fakeClient()
      ns = wow.load({ "UI/Widgets.lua", "UI/MainFrame.lua", "UI/Tabs/Chronicle.lua" })
      wow.login()
    end)

    it("shows its chapters and sentences on the parchment", function()
      ns.Log:Add("level", { l = 2 })
      ns.Log:CloseChapter({})
      ns.Log:Add("level", { l = 3 })
      ns.UI.MainFrame:Show("chronicle")
      local page
      for _, child in ipairs(_G.AshmarkFrame.Inset.__children) do
        if rawget(child, "Chapters") then page = child end
      end
      local chapters, lines = page.Chapters, page.Lines
      assert.same({ "Chapter II (current)", "Chapter I" },
                  { chapters.elements[1].row:GetText(), chapters.elements[2].row:GetText() })
      assert.equal("You reached level 3.", lines.elements[1].row.text:GetText())
      assert.equal("QuestBG-Parchment", page.Parchment:GetAtlas())

      wow.script(chapters.elements[2].row, "OnClick")
      assert.equal("You reached level 2.", lines.elements[1].row.text:GetText())
      assert.equal("Chapter I", page.Heading:GetText())
    end)
  end)
end)

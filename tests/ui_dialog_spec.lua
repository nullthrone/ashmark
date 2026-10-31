local wow = require("tests.helpers.wow")

describe("UI Dialog", function()
  local ns, Dialog, accepted, popups

  -- Records what the mock frames would swallow: the dialog's strata and the edit box's focus.
  local function recordFrames()
    local create = CreateFrame
    wow.stub("CreateFrame", function(kind, name, parent, template)
      local frame = create(kind, name, parent, template)
      if name == "AshmarkDialog" then
        function frame:SetFrameStrata(strata) self.strata = strata end
      elseif kind == "EditBox" then
        function frame:SetFocus() self.focused = true end
        function frame:ClearFocus() self.focused = false end
      end
      return frame
    end)
  end

  local function dialog()
    return _G.AshmarkDialog
  end

  local function show(opts)
    opts = opts or {}
    opts.text = opts.text or "Wipe it all?"
    opts.accept = opts.accept or "CORE_RESET_ACCEPT"
    opts.cancel = opts.cancel or "CORE_CANCEL"
    if opts.onAccept == nil then
      opts.onAccept = function(...) accepted[#accepted + 1] = { n = select("#", ...), ... } end
    end
    Dialog:Show(opts)
    return dialog()
  end

  local function printed(text)
    for _, line in ipairs(wow.chat) do
      if line:find(text, 1, true) then return true end
    end
    return false
  end

  before_each(function()
    wow.reset()
    recordFrames()
    popups = {}
    wow.stub("StaticPopup_Show", function(...) popups[#popups + 1] = { ... } end)
    wow.stub("StaticPopupDialogs", {})
    ns = wow.load({ "UI/Dialog.lua" })
    Dialog = ns.UI.Dialog
    accepted = {}
    wow.login()
  end)

  after_each(function()
    assert.same({}, wow.errors)
    assert.same({}, popups)
    assert.same({}, _G.StaticPopupDialogs)
  end)

  it("creates AshmarkDialog on the first Show from the Blizzard templates", function()
    assert.is_nil(dialog())
    local d = show()
    assert.equal("DialogBorderTemplate", d.__template)
    assert.equal("DIALOG", d.strata)
    assert.is_true(d:IsShown())
    assert.is_true(tContains(UISpecialFrames, "AshmarkDialog"))
    assert.equal("GameFontHighlight", d.Text.__template)
    assert.equal("Wipe it all?", d.Text:GetText())
    assert.equal("UIPanelButtonTemplate", d.Accept.__template)
    assert.equal("UIPanelButtonTemplate", d.Cancel.__template)
    assert.same({ ns.L.CORE_RESET_ACCEPT, ns.L.CORE_CANCEL }, { d.Accept:GetText(), d.Cancel:GetText() })
    assert.equal("InputBoxTemplate", d.EditBox.__template)
    assert.is_false(d.EditBox:IsShown())
  end)

  it("labels the buttons with the client's Accept and Cancel when no keys are given", function()
    Dialog:Show({ text = "Sure?" })
    assert.same({ ACCEPT, CANCEL }, { dialog().Accept:GetText(), dialog().Cancel:GetText() })
  end)

  it("hands nil to onAccept and hides on Accept", function()
    local d = show()
    wow.script(d.Accept, "OnClick")
    assert.is_false(d:IsShown())
    assert.same({ { n = 1 } }, accepted)
  end)

  it("hides without calling onAccept on Cancel", function()
    local d = show()
    wow.script(d.Cancel, "OnClick")
    assert.is_false(d:IsShown())
    assert.same({}, accepted)
  end)

  it("treats Escape as a cancel: a later click does nothing", function()
    local d = show()
    d:Hide()
    wow.script(d.Accept, "OnClick")
    assert.same({}, accepted)
  end)

  it("edits one line of at most max letters and hands its text to onAccept", function()
    local plain = show():GetHeight()
    local d = show({ text = "Note for Mira", edit = { text = "Met in Desolace", max = 120 } })
    local box = d.EditBox
    assert.is_true(box:IsShown())
    assert.equal(120, box:GetMaxLetters())
    assert.equal("Met in Desolace", box:GetText())
    assert.is_true(box.focused)
    assert.is_true(d:GetHeight() > plain)
    box:SetText("Healer, kind")
    wow.script(d.Accept, "OnClick")
    assert.same({ { n = 1, "Healer, kind" } }, accepted)
    assert.is_false(box.focused)
  end)

  it("accepts on Enter and cancels on Escape in the edit box", function()
    local d = show({ edit = { text = "", max = 120 } })
    d.EditBox:SetText("x")
    wow.script(d.EditBox, "OnEnterPressed")
    assert.same({ { n = 1, "x" } }, accepted)
    d = show({ edit = { text = "", max = 120 } })
    wow.script(d.EditBox, "OnEscapePressed")
    assert.is_false(d:IsShown())
    assert.equal(1, #accepted)
  end)

  it("starts an edit empty when its text is missing or secret, without a letter limit when max is", function()
    local d = show({ edit = { text = wow.secret("x") } })
    assert.equal("", d.EditBox:GetText())
    assert.equal(0, d.EditBox:GetMaxLetters())
    d = show({ edit = {} })
    assert.equal("", d.EditBox:GetText())
  end)

  it("replaces a dialog on screen, whose onAccept then never runs", function()
    local first
    show({ edit = { text = "old", max = 10 }, onAccept = function() first = true end })
    local d = show({ text = "Second" })
    assert.equal("Second", d.Text:GetText())
    assert.is_false(d.EditBox:IsShown())
    wow.script(d.Accept, "OnClick")
    assert.is_nil(first)
    assert.equal(1, #accepted)
  end)

  it("shows only out of combat", function()
    wow.combat(true)
    show()
    assert.is_nil(dialog())
    wow.combat(false)
    assert.is_true(dialog():IsShown())
  end)

  it("takes no keyboard focus for an editor asked for in combat when it appears after combat", function()
    local highlighted = 0
    wow.combat(true)
    show({ text = "Note for Mira", edit = { text = "Great healer", max = 120 } })
    assert.is_nil(dialog())
    wow.combat(false)
    local d = dialog()
    d.EditBox.HighlightText = function() highlighted = highlighted + 1 end
    assert.is_true(d:IsShown())
    assert.is_true(d.EditBox:IsShown())
    assert.equal("Great healer", d.EditBox:GetText())
    assert.is_falsy(d.EditBox.focused)
    show({ text = "Note for Mira", edit = { text = "Great healer", max = 120 } })
    assert.is_true(d.EditBox.focused)
    assert.equal(1, highlighted)
  end)

  it("answers once in combat and hides when combat ends", function()
    local d = show()
    wow.combat(true)
    wow.script(d.Accept, "OnClick")
    wow.script(d.Accept, "OnClick")
    assert.equal(1, #accepted)
    assert.is_true(d:IsShown())
    wow.combat(false)
    assert.is_false(d:IsShown())
  end)

  it("lets go of the keyboard at once when its editor is answered in combat", function()
    for _, key in ipairs({ "OnEnterPressed", "OnEscapePressed" }) do
      local d = show({ text = "Note for Mira", edit = { text = "Great healer", max = 120 } })
      assert.is_true(d.EditBox.focused)
      wow.combat(true)
      wow.script(d.EditBox, key)
      assert.is_true(d:IsShown())
      assert.is_false(d.EditBox.focused, key)
      wow.combat(false)
      assert.is_false(d:IsShown())
    end
    assert.same({ { n = 1, "Great healer" } }, accepted)
  end)

  it("reports an error in onAccept under the dialog and still hides", function()
    local d = show({ onAccept = function() error("boom") end })
    wow.script(d.Accept, "OnClick")
    assert.is_false(d:IsShown())
    assert.equal(1, #wow.errors)
    assert.truthy(wow.errors[1]:find("Dialog (dialog:accept)", 1, true))
    wow.errors = {}
  end)

  it("refuses options without a plain text", function()
    Dialog:Show()
    Dialog:Show({ text = wow.secret("x") })
    Dialog:Show({ text = 42 })
    assert.is_nil(dialog())
  end)

  describe("for /ashmark reset", function()
    it("confirms before wiping this character's record", function()
      ns.Log:Add("level", { l = 2 })
      SlashCmdList.ASHMARK("reset")
      local d = dialog()
      assert.equal(ns.L.CORE_RESET_CONFIRM, d.Text:GetText())
      assert.same({ ns.L.CORE_RESET_ACCEPT, ns.L.CORE_CANCEL }, { d.Accept:GetText(), d.Cancel:GetText() })
      assert.equal(1, ns.Log:Seq(ns.DB:Char()))
      wow.script(d.Accept, "OnClick")
      assert.equal(0, ns.Log:Seq(ns.DB:Char()))
      assert.is_true(printed(ns.L.CORE_RESET_DONE))
    end)

    it("wipes nothing on Cancel", function()
      ns.Log:Add("level", { l = 2 })
      SlashCmdList.ASHMARK("reset")
      wow.script(dialog().Cancel, "OnClick")
      assert.equal(1, ns.Log:Seq(ns.DB:Char()))
    end)

    it("confirms before wiping others' contacts", function()
      _G.AshmarkDB.contacts["Player-1-00000002"] = { guid = "Player-1-00000002" }
      SlashCmdList.ASHMARK("reset others")
      assert.equal(ns.L.CORE_RESET_OTHERS_CONFIRM, dialog().Text:GetText())
      wow.script(dialog().Accept, "OnClick")
      assert.same({}, _G.AshmarkDB.contacts)
      assert.is_true(printed(ns.L.CORE_RESET_OTHERS_DONE))
    end)
  end)
end)

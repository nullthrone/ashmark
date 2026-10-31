local wow = require("tests.helpers.wow")

describe("Core Chronicle", function()
  local ns, char
  before_each(function()
    wow.reset()
    ns = wow.load()
    ns.Log:RegisterKind("test.said", {
      render = function(entry, ctx) return ns.Chronicle:Text("TEST_SAID", ctx, { what = entry.w }) end,
    })
    ns.Log:RegisterKind("test.silent", {})
    ns.Log:RegisterKind("test.broken", { render = function() error("boom") end })
    local L = ns.Locale:Base()
    L.TEST_SAID = "You said {what}."
    L.TEST_SAID_THEY = "{name} said {what}."
    wow.login()
    char = ns.DB:Char()
  end)

  it("lists the chapters and the open one", function()
    ns.Log:Add("test.said", { w = "a" })
    local first = ns.Log:CloseChapter({})
    ns.Log:Add("test.said", { w = "b" })
    local chapters = ns.Chronicle:Chapters(char)
    assert.equal(first, chapters[1])
    assert.same({ no = 2, from = 3, open = true }, chapters[2])
    assert.same({ { no = 1, from = 1, open = true } }, ns.Chronicle:Chapters({ chapters = {} }))
  end)

  it("renders the lines of a chapter in order, skipping silent and failing entries", function()
    ns.Log:Add("test.said", { w = "a" })
    ns.Log:Add("test.silent", {})
    ns.Log:Add("test.broken", {})
    ns.Log:Add("test.said", { w = "b" })
    local lines = ns.Chronicle:Lines(char, ns.Chronicle:Chapters(char)[1])
    assert.same({ "You said a.", "You said b." }, { lines[1].text, lines[2].text })
    assert.equal(2, #lines)
    assert.equal(4, lines[2].entry.n)
    assert.equal(1, #wow.errors)
  end)

  it("uses the third person with the member's name when ctx.own is false", function()
    local e = ns.Log:Add("test.said", { w = "a" })
    assert.equal("Aren said a.", ns.Chronicle:Render(e, { char = char, own = false }))
    assert.equal("You said a.", ns.Chronicle:Render(e, { char = char, own = true }))
  end)

  it("uses the feminine form for the character's sex", function()
    local L = ns.Locale:Base()
    L.TEST_SAID_F = "She-you said {what}."
    local e = ns.Log:Add("test.said", { w = "a" })
    assert.equal("She-you said a.", ns.Chronicle:Render(e, { char = { sex = 3 }, own = true }))
  end)

  it("renders the chapter entry with its numeral and place", function()
    wow.state.map = 9002
    ns.Log:Add("test.said", { w = "a" })
    ns.Log:CloseChapter({})
    assert.equal("Chapter I closes in Desolace.", ns.Chronicle:Render(ns.Log:Last(char, "chapter"), { char = char }))
  end)
end)

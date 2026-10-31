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

  it("never sets a place outside every zone into a sentence that may call it a zone", function()
    -- As deDE and ruRU write them: the plain keys put {place} after a word for zone.
    local L = ns.Locale:Base()
    L.CORE_LOG_DEATH, L.CORE_LOG_DEATH_THEY = "You died in the zone {place}.", "{name} died in the zone {place}."
    L.CORE_LOG_CHAPTER = "Chapter {roman} closes in the zone {place}."
    local own, family = { char = char }, { char = char, own = false }
    local function render(entry, ctx) return ns.Chronicle:Render(entry, ctx or own) end
    assert.equal("You died in the zone Desolace.", render({ k = "death", m = 9002 }))
    assert.equal("You died in Kalimdor.", render({ k = "death", m = 1414 }))
    assert.equal("Aren died in Kalimdor.", render({ k = "death", m = 1414 }, family))
    assert.equal("You died in the zone an unknown place.", render({ k = "death" }))
    assert.equal("You died in the zone an unknown place.", render({ k = "death", m = 4242 }))
    assert.equal("Chapter III closes in the zone Desolace.", render({ k = "chapter", no = 3, m = 1443 }))
    assert.equal("Chapter III closes in Test Orphan.", render({ k = "chapter", no = 3, m = 9003 }))
    assert.equal("Aren's chapter III closes in Kalimdor.", render({ k = "chapter", no = 3, m = 1414 }, family))
  end)
end)

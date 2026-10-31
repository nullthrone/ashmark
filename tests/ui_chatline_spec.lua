local wow = require("tests.helpers.wow")

describe("UI ChatLine", function()
  local ns, prefix

  before_each(function()
    wow.reset()
    ns = wow.load({ "UI/ChatLine.lua" })
    wow.login()
    wow.chat, wow.chatColors = {}, {}
    prefix = NORMAL_FONT_COLOR:WrapTextInColorCode("Ashmark") .. ": "
  end)

  it("prints with Ashmark's prefix in the system colour", function()
    assert.is_true(ns.UI.ChatLine:Print("You know Mira: met 3×, last in Desolace."))
    assert.is_true(ns.UI.ChatLine:Print("Again.", "system"))
    assert.same({ prefix .. "You know Mira: met 3×, last in Desolace.", prefix .. "Again." }, wow.chat)
    local info = ChatTypeInfo.SYSTEM
    assert.same({ info.r, info.g, info.b }, wow.chatColors[1])
    assert.same({ info.r, info.g, info.b }, wow.chatColors[2])
  end)

  it("prints rumours in the monster say colour", function()
    assert.is_true(ns.UI.ChatLine:Print("People say an oathkeeper sided with the Gelkis.", "rumour"))
    local info = ChatTypeInfo.MONSTER_SAY
    assert.same({ info.r, info.g, info.b }, wow.chatColors[1])
  end)

  it("prints nothing with Core.chatLines off", function()
    ns.Settings:Set("Core.chatLines", false)
    assert.is_false(ns.UI.ChatLine:Print("Hidden."))
    assert.same({}, wow.chat)
  end)

  it("refuses secret and non-string text", function()
    assert.is_false(ns.UI.ChatLine:Print(wow.secret("x")))
    assert.is_false(ns.UI.ChatLine:Print(nil))
    assert.is_false(ns.UI.ChatLine:Print(42))
    assert.same({}, wow.chat)
    assert.same({}, wow.errors)
  end)
end)

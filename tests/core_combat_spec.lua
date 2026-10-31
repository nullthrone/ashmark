local wow = require("tests.helpers.wow")

describe("Core Combat", function()
  local ns
  before_each(function()
    wow.reset()
    ns = wow.load()
    wow.login()
  end)

  it("runs at once out of combat", function()
    local ran = false
    ns.Combat.Run("k", function() ran = true end)
    assert.is_true(ran)
  end)

  it("queues in combat, keeps the latest per key and runs in insertion order", function()
    local ran = {}
    wow.combat(true)
    ns.Combat.Run("a", function() ran[#ran + 1] = "a1" end)
    ns.Combat.Run("b", function() ran[#ran + 1] = "b" end)
    ns.Combat.Run("a", function() ran[#ran + 1] = "a2" end)
    assert.same({}, ran)
    wow.combat(false)
    assert.same({ "a2", "b" }, ran)
    wow.combat(true)
    wow.combat(false)
    assert.same({ "a2", "b" }, ran)
  end)

  it("reports a failing function and runs the rest", function()
    local ran = false
    wow.combat(true)
    ns.Combat.Run("bad", function() error("boom") end)
    ns.Combat.Run("good", function() ran = true end)
    wow.combat(false)
    assert.is_true(ran)
    assert.equal(1, #wow.errors)
  end)
end)

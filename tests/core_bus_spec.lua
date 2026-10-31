local wow = require("tests.helpers.wow")

describe("Core Bus", function()
  local ns, A, B
  before_each(function()
    wow.reset()
    ns = wow.load()
    A = ns:NewModule("Alpha", { locale = "ALPHA" })
    B = ns:NewModule("Beta", { locale = "BETA" })
    wow.login()
  end)

  it("delivers in subscription order with the payload", function()
    local seen = {}
    B:Subscribe("T", function(self, topic, x, y) seen[#seen + 1] = { self.name, topic, x, y } end)
    A:Subscribe("T", function(self, topic, x, y) seen[#seen + 1] = { self.name, topic, x, y } end)
    ns.Bus:Fire("T", 1, nil)
    assert.same({ { "Beta", "T", 1, nil }, { "Alpha", "T", 1, nil } }, seen)
  end)

  it("queues a Fire inside a handler until the current topic reached every subscriber (FIFO)", function()
    local seen = {}
    A:Subscribe("first", function()
      seen[#seen + 1] = "A:first"
      ns.Bus:Fire("second", "x")
      ns.Bus:Fire("third")
      seen[#seen + 1] = "A:first:end"
    end)
    B:Subscribe("first", function() seen[#seen + 1] = "B:first" end)
    A:Subscribe("second", function(_, _, v)
      seen[#seen + 1] = "A:second:" .. v
      ns.Bus:Fire("fourth")
    end)
    B:Subscribe("second", function() seen[#seen + 1] = "B:second" end)
    B:Subscribe("third", function() seen[#seen + 1] = "B:third" end)
    A:Subscribe("fourth", function() seen[#seen + 1] = "A:fourth" end)
    ns.Bus:Fire("first")
    seen[#seen + 1] = "returned"
    assert.same({ "A:first", "A:first:end", "B:first", "A:second:x", "B:second", "B:third", "A:fourth",
                  "returned" }, seen)
  end)

  it("skips disabled modules and stops after Unsubscribe", function()
    local calls = 0
    A:Subscribe("T", function() calls = calls + 1 end)
    A.enabled = false
    ns.Bus:Fire("T")
    A.enabled = true
    ns.Bus:Fire("T")
    ns.Bus:Unsubscribe(A, "T")
    ns.Bus:Fire("T")
    assert.equal(1, calls)
  end)

  it("keeps dispatching after a handler error", function()
    local calls = 0
    A:Subscribe("T", function() error("boom") end)
    B:Subscribe("T", function() calls = calls + 1 end)
    ns.Bus:Fire("T")
    ns.Bus:Fire("T")
    assert.equal(2, calls)
    assert.equal(1, #wow.errors)
  end)

  it("fires nothing before the ready flag", function()
    ns.ready = false
    local calls = 0
    A:Subscribe("T", function() calls = calls + 1 end)
    ns.Bus:Fire("T")
    assert.equal(0, calls)
  end)
end)

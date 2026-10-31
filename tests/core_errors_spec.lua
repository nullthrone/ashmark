local wow = require("tests.helpers.wow")

describe("Core error wrapper", function()
  local ns, M
  before_each(function()
    wow.reset()
    ns = wow.load()
    M = ns:NewModule("Alpha", { locale = "ALPHA" })
    wow.login()
  end)

  it("forwards every argument, nils included", function()
    local got
    local function probe(...)
      got = { n = select("#", ...), ... }
      return "x", nil
    end
    local ok, a, b = ns:Call(M, "src", probe, 1, nil, 3, nil)
    assert.is_true(ok)
    assert.equal("x", a)
    assert.is_nil(b)
    assert.equal(4, got.n)
    assert.same({ 1, nil, 3 }, { got[1], got[2], got[3] })
  end)

  it("hands the arguments to xpcall itself on a client whose xpcall forwards them", function()
    local stock = _G.xpcall
    local forwarded = 0
    _G.xpcall = function(f, handler, ...)
      local n = select("#", ...)
      if n > 0 then forwarded = forwarded + 1 end
      local args = { ... }
      return stock(function() return f(unpack(args, 1, n)) end, handler)
    end
    local ok, err = pcall(function()
      wow.reset()
      ns = wow.load()
      M = ns:NewModule("Alpha", { locale = "ALPHA" })
      wow.login()
      forwarded = 0
      local got
      local called, a = ns:Call(M, "src", function(...)
        got = { n = select("#", ...), ... }
        return "x"
      end, 1, nil, 3, nil)
      assert.is_true(called)
      assert.equal("x", a)
      assert.equal(4, got.n)
      assert.same({ 1, nil, 3 }, { got[1], got[2], got[3] })
      assert.equal(1, forwarded)
      assert.is_false(ns:Call(M, "boom", function(v) error("boom " .. v) end, "now"))
      assert.truthy(wow.errors[1]:find("boom now", 1, true))
    end)
    _G.xpcall = stock
    assert(ok, err)
  end)

  it("reports once per (module, source) and keeps other handlers running", function()
    local other = 0
    M:RegisterEvent("BAG_UPDATE", function() error("boom") end)
    ns.Core:RegisterEvent("BAG_UPDATE", function() other = other + 1 end)
    for _ = 1, 3 do wow.fire("BAG_UPDATE") end
    assert.equal(3, other)
    assert.equal(1, #wow.errors)
    assert.truthy(wow.errors[1]:find("Alpha", 1, true))
    assert.truthy(wow.errors[1]:find("BAG_UPDATE", 1, true))
    M:RegisterEvent("BAG_UPDATE_DELAYED", function() error("boom") end)
    wow.fire("BAG_UPDATE_DELAYED")
    assert.equal(2, #wow.errors)
  end)

  it("disables a module for the session after 10 caught errors", function()
    local disabled = 0
    function M:OnDisable() disabled = disabled + 1 end
    M:RegisterEvent("BAG_UPDATE", function() error("boom") end)
    M:Subscribe("LOG_ADDED", function() end)
    for _ = 1, 9 do wow.fire("BAG_UPDATE") end
    assert.is_true(M.enabled)
    wow.fire("BAG_UPDATE")
    assert.is_false(M.enabled)
    assert.same({ "error" }, M.unavailable)
    assert.equal(1, disabled)
    assert.equal(0, ns.Events:Count("BAG_UPDATE"))
    local failures = 0
    for _, line in ipairs(wow.chat) do
      if line:find("stopped after repeated errors", 1, true) then failures = failures + 1 end
    end
    assert.equal(1, failures)
    ns.Settings:Set("Alpha.enabled", false)
    ns.Settings:Set("Alpha.enabled", true)
    assert.is_false(M.enabled)
  end)

  it("never disables Core services", function()
    ns.Core:RegisterEvent("BAG_UPDATE", function() error("boom") end)
    for _ = 1, 20 do wow.fire("BAG_UPDATE") end
    assert.is_true(ns.Core.enabled)
    assert.equal(1, #wow.errors)
  end)

  it("installs a hook once per key and wraps hook bodies", function()
    local installs, calls = 0, 0
    local target = { Fn = function() return "orig" end }
    for _ = 1, 3 do
      M:Hook("fn", function()
        installs = installs + 1
        hooksecurefunc(target, "Fn", M:Wrap("fn", function() calls = calls + 1 error("inside") end))
      end)
    end
    assert.equal(1, installs)
    assert.equal("orig", target.Fn())
    assert.equal(1, calls)
    assert.equal(1, #wow.errors)
    M.enabled = false
    target.Fn()
    assert.equal(1, calls)
  end)
end)

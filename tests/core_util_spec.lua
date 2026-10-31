local wow = require("tests.helpers.wow")

describe("Core Util", function()
  local ns
  before_each(function()
    wow.reset()
    ns = wow.load()
  end)

  it("makes 8 lowercase hex tokens", function()
    for _ = 1, 50 do
      assert.truthy(ns.Util.Token():match("^[0-9a-f]+$"))
      assert.equal(8, #ns.Util.Token())
    end
  end)

  it("writes roman numerals and falls back to digits outside 1..3999", function()
    assert.equal("I", ns.Util.Roman(1))
    assert.equal("IV", ns.Util.Roman(4))
    assert.equal("XIV", ns.Util.Roman(14))
    assert.equal("MCMXCIX", ns.Util.Roman(1999))
    assert.equal("0", ns.Util.Roman(0))
    assert.equal("4000", ns.Util.Roman(4000))
  end)

  it("clamps, rounds and trims", function()
    assert.equal(5, ns.Util.Clamp(9, 0, 5))
    assert.equal(0, ns.Util.Clamp(-1, 0, 5))
    assert.equal(3, ns.Util.Round(2.5))
    assert.equal(-2, ns.Util.Round(-2.5))
    assert.equal("a b", ns.Util.Trim("  a b \t"))
    assert.equal("", ns.Util.Trim(nil))
  end)

  it("debounces per key and absorbs later calls", function()
    local calls = 0
    ns.Util.Debounce("k", 1, function() calls = calls + 1 end)
    ns.Util.Debounce("k", 1, function() calls = calls + 10 end)
    wow.advance(0.5)
    assert.equal(0, calls)
    wow.advance(0.5)
    assert.equal(1, calls)
    ns.Util.Debounce("k", 1, function() calls = calls + 1 end)
    wow.advance(1)
    assert.equal(2, calls)
  end)

  it("keeps one ticker per key until it is stopped", function()
    local calls = 0
    local first = ns.Util.Ticker("t", 2, function() calls = calls + 1 end)
    assert.equal(first, ns.Util.Ticker("t", 2, function() calls = calls + 100 end))
    wow.advance(5)
    assert.equal(2, calls)
    ns.Util.StopTicker("t")
    wow.advance(10)
    assert.equal(2, calls)
  end)

  it("reports an error in a timer callback instead of raising it", function()
    ns.Util.Debounce("boom", 0, function() error("boom") end)
    assert.has_no.errors(function() wow.advance(0) end)
    assert.equal(1, #wow.errors)
  end)
end)

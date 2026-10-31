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

  it("reads the realm's clock, and the system clock only without it", function()
    wow.stub("GetServerTime", function() return 1234 end)
    assert.equal(1234, ns.Util.Now())
    wow.stub("GetServerTime", function() return wow.secret(5) end)
    assert.equal(time(), ns.Util.Now())
    wow.stub("GetServerTime", function() error("no clock") end)
    assert.equal(time(), ns.Util.Now())
    wow.stub("GetServerTime", nil)
    assert.equal(time(), ns.Util.Now())
  end)

  it("folds A to Z and the capitals of Latin-1, Latin Extended-A and Cyrillic, and nothing else", function()
    local Fold = ns.Util.Fold
    assert.equal("élodie ashvale", Fold("ÉLODIE Ashvale"))
    assert.equal("øðþàö", Fold("ØÐÞÀÖ"))
    assert.equal("żółty-ÿĳ", Fold("ŻÓŁTY-ŸĲ"))
    assert.equal("брайтвейл ёжов ђ", Fold("БРАЙТВЕЙЛ Ёжов Ђ"))
    assert.equal("×İı", Fold("×İı"))
    assert.equal("", Fold(nil))
    assert.equal("", Fold(7))
  end)

  it("tells names that begin with the sounds /i/ and /o/, for Spanish e and u", function()
    local S = ns.Util.StartsWithSound
    for _, name in ipairs({ "Ira", "isla", "\195\141caro", "Hilda", "h\195\173gado", "|cffff0000Ines|r" }) do
      assert.is_true(S(name, "i"), name)
    end
    for _, name in ipairs({ "Hierro", "hielo", "Hiato", "Mira", "", "Yara" }) do
      assert.is_false(S(name, "i"), name)
    end
    for _, name in ipairs({ "Orgrimmar", "ojo", "\195\147rdenes", "Hojas", "Hombres", "|cff00ff00Olga|r" }) do
      assert.is_true(S(name, "o"), name)
    end
    for _, name in ipairs({ "Gelkis", "Uldum", "Huevo", "Ira" }) do
      assert.is_false(S(name, "o"), name)
    end
    assert.is_false(S(nil, "i"))
    assert.is_false(S("Ira", "a"))
    assert.is_false(S(wow.secret("Ira"), "i"))
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

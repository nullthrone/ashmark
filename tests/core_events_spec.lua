local wow = require("tests.helpers.wow")

describe("Core Events", function()
  local ns, A, B
  before_each(function()
    wow.reset()
    ns = wow.load()
    A = ns:NewModule("Alpha", { locale = "ALPHA" })
    B = ns:NewModule("Beta", { locale = "BETA" })
    A.enabled, B.enabled = true, true
  end)

  it("shares one frame per plain event and unregisters it when the count reaches 0", function()
    local seen = {}
    assert.is_true(A:RegisterEvent("BAG_UPDATE", function(self, event, bag)
      seen[#seen + 1] = { self.name, event, bag }
    end))
    assert.is_true(B:RegisterEvent("BAG_UPDATE", function(self, _, bag) seen[#seen + 1] = { self.name, bag } end))
    assert.equal(2, ns.Events:Count("BAG_UPDATE"))
    assert.equal(1, wow.registered("BAG_UPDATE"))
    wow.fire("BAG_UPDATE", 3)
    assert.same({ { "Alpha", "BAG_UPDATE", 3 }, { "Beta", 3 } }, seen)
    A:UnregisterEvent("BAG_UPDATE")
    assert.equal(1, wow.registered("BAG_UPDATE"))
    B:UnregisterEvent("BAG_UPDATE")
    assert.equal(0, wow.registered("BAG_UPDATE"))
    assert.equal(0, ns.Events:Count("BAG_UPDATE"))
  end)

  it("replaces a module's handler when it registers the same event again", function()
    local calls = {}
    A:RegisterEvent("BAG_UPDATE", function() calls[#calls + 1] = 1 end)
    A:RegisterEvent("BAG_UPDATE", function() calls[#calls + 1] = 2 end)
    wow.fire("BAG_UPDATE")
    assert.same({ 2 }, calls)
  end)

  it("gives each (event, unit) pair one shared frame and filters by unit", function()
    local seen = {}
    A:RegisterUnitEvent("UNIT_AURA", "player", function(_, _, unit) seen[#seen + 1] = "A:" .. unit end)
    B:RegisterUnitEvent("UNIT_AURA", "player", function(_, _, unit) seen[#seen + 1] = "B:" .. unit end)
    B:RegisterUnitEvent("UNIT_AURA", "target", function(_, _, unit) seen[#seen + 1] = "B:" .. unit end)
    assert.equal(2, wow.registered("UNIT_AURA"))
    assert.equal(2, ns.Events:Count("UNIT_AURA", "player"))
    wow.fire("UNIT_AURA", "player")
    wow.fire("UNIT_AURA", "target")
    wow.fire("UNIT_AURA", "party1")
    assert.same({ "A:player", "B:player", "B:target" }, seen)
  end)

  it("reuses the pair's frame when a unit event is registered again", function()
    local frames = #wow.frames
    for _ = 1, 5 do
      A:RegisterUnitEvent("UNIT_HEALTH", "target", function() end)
      A:UnregisterEvent("UNIT_HEALTH", "target")
    end
    assert.equal(frames + 1, #wow.frames)
    assert.equal(0, wow.registered("UNIT_HEALTH"))
  end)

  it("skips invalid events, records them and never throws", function()
    wow.invalidEvents.COMBAT_LOG_EVENT_UNFILTERED = true
    local ok
    assert.has_no.errors(function() ok = A:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function() end) end)
    assert.is_false(ok)
    assert.is_false(A:RegisterUnitEvent("COMBAT_LOG_EVENT_UNFILTERED", "player", function() end))
    assert.same({ "COMBAT_LOG_EVENT_UNFILTERED" }, A.missingEvents)
    assert.equal(0, wow.registered("COMBAT_LOG_EVENT_UNFILTERED"))
  end)

  it("falls back to a pcall around the frame call without C_EventUtils", function()
    wow.stub("C_EventUtils", nil)
    wow.invalidEvents.NOT_AN_EVENT = true
    assert.is_false(A:RegisterEvent("NOT_AN_EVENT", function() end))
    assert.same({ "NOT_AN_EVENT" }, A.missingEvents)
    assert.is_true(A:RegisterEvent("BAG_UPDATE", function() end))
  end)

  it("does not deliver to disabled modules", function()
    local calls = 0
    A:RegisterEvent("BAG_UPDATE", function() calls = calls + 1 end)
    A.enabled = false
    wow.fire("BAG_UPDATE")
    assert.equal(0, calls)
  end)

  it("keeps dispatching when a handler unregisters another one", function()
    local seen = {}
    A:RegisterEvent("BAG_UPDATE", function()
      seen[#seen + 1] = "A"
      B:UnregisterEvent("BAG_UPDATE")
    end)
    B:RegisterEvent("BAG_UPDATE", function() seen[#seen + 1] = "B" end)
    wow.fire("BAG_UPDATE")
    wow.fire("BAG_UPDATE")
    assert.same({ "A", "A" }, seen)
  end)

  it("removes every event and unit event of a module at once", function()
    A:RegisterEvent("BAG_UPDATE", function() end)
    A:RegisterUnitEvent("UNIT_AURA", "player", function() end)
    B:RegisterEvent("BAG_UPDATE", function() end)
    ns.Events:UnregisterAll(A)
    assert.equal(1, ns.Events:Count("BAG_UPDATE"))
    assert.equal(0, ns.Events:Count("UNIT_AURA", "player"))
    assert.equal(0, wow.registered("UNIT_AURA"))
  end)
end)

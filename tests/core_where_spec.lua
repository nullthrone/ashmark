local wow = require("tests.helpers.wow")

describe("Core Where", function()
  local ns
  before_each(function()
    wow.reset()
    ns = wow.load()
  end)

  it("is empty without a map", function()
    assert.same({}, ns.Where())
  end)

  it("rounds plain positions to integer percent", function()
    wow.state.map = 1443
    wow.state.pos = { x = 0.1249, y = 0.995 }
    assert.same({ m = 1443, x = 12, y = 100 }, ns.Where())
  end)

  it("keeps the map without a position", function()
    wow.state.map = 1443
    assert.same({ m = 1443 }, ns.Where())
    wow.state.pos = { x = 0.5 }
    assert.same({ m = 1443 }, ns.Where())
  end)

  it("drops a secret map or a secret position", function()
    wow.state.map = wow.secret(1443)
    wow.state.pos = { x = 0.5, y = 0.5 }
    assert.same({}, ns.Where())
    wow.state.map = 1443
    wow.state.pos = wow.secret({ x = 0.5, y = 0.5 })
    assert.same({ m = 1443 }, ns.Where())
    wow.stub("C_Map.GetPlayerMapPosition", function() return { x = wow.secret(0.5), y = 0.5 } end)
    assert.same({ m = 1443 }, ns.Where())
  end)

  it("never throws when the map API fails", function()
    wow.stub("C_Map.GetBestMapForUnit", function() error("restricted") end)
    assert.same({}, ns.Where())
    wow.stub("C_Map", nil)
    assert.same({}, ns.Where())
  end)

  it("records the instance and no position inside instances", function()
    local asked = false
    wow.state.map = 9001
    wow.state.pos = { x = 0.5, y = 0.5 }
    wow.state.instance = { name = "Maraudon", type = "party", instanceID = 349 }
    local original = C_Map.GetPlayerMapPosition
    wow.stub("C_Map.GetPlayerMapPosition", function(...) asked = true return original(...) end)
    assert.same({ m = 9001, i = 349 }, ns.Where())
    assert.is_false(asked)
    wow.state.instance.name = wow.secret("Maraudon")
    assert.same({ m = 9001, i = 349 }, ns.Where())
  end)

  it("walks up to the zone and the continent and caches per map", function()
    assert.equal(1443, ns.Where.Zone(1443))
    assert.equal(1443, ns.Where.Zone(9002))
    assert.equal(1414, ns.Where.Continent(9002))
    assert.is_nil(ns.Where.Zone(1414))
    assert.is_nil(ns.Where.Zone(947))
    assert.is_nil(ns.Where.Zone(9003))
    assert.is_nil(ns.Where.Zone(nil))
    assert.is_nil(ns.Where.Zone(123456))
    wow.data.maps[9002].parentMapID = 1411
    assert.equal(1443, ns.Where.Zone(9002))
  end)
end)

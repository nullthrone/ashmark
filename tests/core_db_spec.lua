local wow = require("tests.helpers.wow")

local function printed(text)
  for _, line in ipairs(wow.chat) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

local TOP = { "settings", "chars", "contacts", "peers", "rumours", "traces", "dev" }

describe("Core DB load safety", function()
  local ns
  before_each(function()
    wow.reset()
  end)

  it("starts a fresh record when AshmarkDB is nil", function()
    ns = wow.load()
    wow.fire("ADDON_LOADED", "Ashmark")
    assert.is_true(ns.DB.fresh)
    assert.equal(1, _G.AshmarkDB.schema)
    assert.equal(time(), _G.AshmarkDB.created)
    for _, key in ipairs(TOP) do assert.is_table(_G.AshmarkDB[key]) end
    assert.same({ schema = 0, outbox = {}, inbox = {} }, _G.AshmarkDB.traces)
    assert.same({ heard = {}, told = {} }, _G.AshmarkDB.rumours)
    assert.same({ tests = {}, probes = {}, blocked = {} }, _G.AshmarkDB.dev)
    assert.is_true(printed("A new record has started"))
  end)

  it("keeps a value that is not a table in recovered", function()
    wow.saved("garbage")
    ns = wow.load()
    wow.fire("ADDON_LOADED", "Ashmark")
    assert.equal("garbage", _G.AshmarkDB.recovered)
    assert.equal(1, _G.AshmarkDB.schema)
    assert.is_false(ns.DB.fresh)
    assert.is_true(printed("AshmarkDB.recovered"))
  end)

  it("keeps a table without schema in recovered", function()
    local old = { chars = { x = 1 } }
    wow.saved(old)
    ns = wow.load()
    wow.fire("ADDON_LOADED", "Ashmark")
    assert.equal(old, _G.AshmarkDB.recovered)
    assert.same({}, _G.AshmarkDB.chars)
  end)

  it("keeps an existing record", function()
    wow.saved({ schema = 1, created = 5, chars = { g = { name = "x" } } })
    ns = wow.load()
    wow.fire("ADDON_LOADED", "Ashmark")
    assert.equal(5, _G.AshmarkDB.created)
    assert.same({ name = "x" }, _G.AshmarkDB.chars.g)
    assert.is_table(_G.AshmarkDB.dev.blocked)
  end)

  describe("with a newer schema", function()
    local before, groupChanged
    before_each(function()
      wow.saved({
        schema = 2, created = 1, settings = { ["Alpha.enabled"] = true }, future = { keep = true },
        chars = { ["Player-1-00000001"] = { guid = "Player-1-00000001", name = "Old", seq = 0, log = {},
                                             chapters = {}, zones = {}, stats = {}, state = { inGroup = true } } },
        dev = { tests = {}, probes = {}, blocked = {} },
      })
      before = wow.deepcopy(_G.AshmarkDB)
      ns = wow.load()
      local M = ns:NewModule("Alpha", { locale = "ALPHA" })
      M.OnEnable = function() error("must not run") end
      ns.Core:Subscribe("GROUP_CHANGED", function(_, _, inGroup) groupChanged = inGroup end)
      wow.state.map = 1443
      wow.login()
    end)

    it("is read-only and makes every module unavailable", function()
      assert.is_true(ns.DB.readOnly)
      assert.is_true(printed("newer version of Ashmark"))
      assert.same({ "schema" }, ns.Alpha.unavailable)
      assert.is_false(ns.Alpha.enabled)
      assert.same({}, wow.errors)
    end)

    it("writes nothing: identity, zones, stats, state, settings binding, dev, log", function()
      assert.is_nil(ns.Log:Add("death", {}))
      assert.is_nil(ns.Log:CloseChapter({}))
      assert.is_false(ns.Settings:Set("Core.sounds", false))
      assert.equal(0, ns.Core:Stat("playedSec", 10))
      wow.fire("ZONE_CHANGED_NEW_AREA")
      wow.fire("ADDON_ACTION_BLOCKED", "Ashmark", "Fn")
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(600)
      wow.logout()
      assert.same(before, _G.AshmarkDB)
      assert.same({}, wow.panel.settings)
      assert.equal("Old", ns.DB:Char().name)
    end)

    it("keeps the group flag in memory", function()
      assert.is_false(groupChanged)
      assert.is_false(ns.DB:State().inGroup)
      assert.is_true(_G.AshmarkDB.chars["Player-1-00000001"].state.inGroup)
    end)

    it("shows only the read-only notice in the settings panel", function()
      local category = wow.panel.categories[1]
      assert.equal("Ashmark", category.name)
      assert.same({ { header = ns.L.CORE_SV_NEWER } }, category.layout.initializers)
      assert.same({}, wow.panel.checkboxes)
    end)
  end)

  describe("migrations", function()
    local function boot(db, migrations, schema)
      wow.saved(db)
      ns = wow.load()
      ns.DB.SCHEMA = schema
      for v, fn in pairs(migrations) do ns.DB.migrations[v] = fn end
      wow.fire("ADDON_LOADED", "Ashmark")
    end

    it("run in order from the stored schema and are idempotent", function()
      local order = {}
      local migrations = {
        [2] = function(db) order[#order + 1] = 2 db.two = 1 end,
        [3] = function(db) order[#order + 1] = 3 db.three = db.two and "after two" end,
      }
      boot({ schema = 1, created = 7 }, migrations, 3)
      assert.same({ 2, 3 }, order)
      assert.equal(3, _G.AshmarkDB.schema)
      assert.equal(1, _G.AshmarkDB.two)
      assert.equal("after two", _G.AshmarkDB.three)
      local once = wow.deepcopy(_G.AshmarkDB)
      migrations[2](_G.AshmarkDB)
      migrations[3](_G.AshmarkDB)
      assert.same(once, _G.AshmarkDB)
    end)

    it("start at the stored schema", function()
      local order = {}
      boot({ schema = 2, created = 7 }, {
        [2] = function() order[#order + 1] = 2 end,
        [3] = function() order[#order + 1] = 3 end,
      }, 3)
      assert.same({ 3 }, order)
    end)

    it("leave the record read-only when one fails", function()
      boot({ schema = 1, created = 7 }, { [2] = function() error("broken") end }, 2)
      assert.is_true(ns.DB.readOnly)
      assert.equal(1, _G.AshmarkDB.schema)
      assert.equal(1, #wow.errors)
    end)

    it("leave the stored record untouched by the steps before and the part of the step that failed", function()
      local log = { { n = 1, old = "x" }, { n = 2, old = "y" } }
      local stored = { schema = 1, created = 7, chars = { a = { log = log } } }
      local before = wow.deepcopy(stored)
      boot(stored, {
        [2] = function(db) db.two = true end,
        [3] = function(db)
          for _, entry in ipairs(db.chars.a.log) do
            entry.new, entry.old = entry.old, nil
            if entry.n == 2 then error("corrupt entry") end
          end
        end,
      }, 3)
      assert.is_true(ns.DB.readOnly)
      assert.equal(stored, _G.AshmarkDB)
      assert.same(before, _G.AshmarkDB)
    end)
  end)

  it("appends to array stores and drops the oldest beyond the cap", function()
    ns = wow.load()
    wow.fire("ADDON_LOADED", "Ashmark")
    local list = {}
    for i = 1, 25 do ns.DB:Append(list, i, 20) end
    assert.equal(20, #list)
    assert.equal(6, list[1])
  end)
end)

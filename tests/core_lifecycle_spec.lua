local wow = require("tests.helpers.wow")

describe("Core lifecycle", function()
  local ns, trace

  local function module(name, opts)
    local M = ns:NewModule(name, opts or { locale = name:upper() })
    function M:OnInitialize() trace[#trace + 1] = name .. ":init:" .. tostring(self:Char() ~= nil) end
    function M:OnEnable()
      trace[#trace + 1] = name .. ":enable:" .. tostring(ns.ready) .. ":" .. tostring(ns.Log:Add("death", {}) ~= nil)
      self:Subscribe("LOG_ADDED", function(_, _, entry) trace[#trace + 1] = name .. ":added:" .. entry.k end)
      self:RegisterEvent("BAG_UPDATE", function() trace[#trace + 1] = name .. ":bag" end)
    end
    function M:OnWorldReady(initial, reloading)
      trace[#trace + 1] = table.concat({ name, "world", tostring(initial), tostring(reloading), tostring(ns.ready) }, ":")
    end
    function M:OnDisable() trace[#trace + 1] = name .. ":disable" end
    return M
  end

  before_each(function()
    wow.reset()
    trace = {}
    ns = wow.load()
  end)

  it("runs the steps in order and sets the ready flag at the start of step 3", function()
    module("Alpha")
    module("Beta")
    wow.login()
    assert.same({
      "Alpha:init:false", "Beta:init:false",
      "Alpha:enable:false:false", "Beta:enable:false:false",
      "Alpha:world:true:false:true", "Beta:world:true:false:true",
    }, trace)
    assert.same({}, wow.errors)
  end)

  it("passes the reload flags to OnWorldReady", function()
    module("Alpha")
    wow.fire("ADDON_LOADED", "Ashmark")
    wow.fire("PLAYER_LOGIN")
    wow.fire("PLAYER_ENTERING_WORLD", false, true)
    wow.fire("PLAYER_ENTERING_WORLD", false, false)
    assert.equal("Alpha:world:false:true:true", trace[#trace])
  end)

  it("makes Core's zone, group, chapter and compaction writes after every OnWorldReady", function()
    local A = module("Alpha")
    local B = module("Beta")
    wow.saved({ schema = 1, created = 1, chars = { ["Player-1-00000001"] = {
      guid = "Player-1-00000001", seq = 1200, chapters = {}, zones = {}, stats = {},
      state = { inGroup = true, senders = {} }, log = {},
    } } })
    for n = 1, 1200 do
      table.insert(_G.AshmarkDB.chars["Player-1-00000001"].log, { n = n, t = time() - 1000, k = "death" })
    end
    wow.state.map = 1443
    local order = {}
    A.OnWorldReady = function() order[#order + 1] = "A:world" end
    B.OnWorldReady = function() order[#order + 1] = "B:world" end
    B.OnEnable = function(self)
      self:Subscribe("LOG_ADDED", function(_, _, entry) order[#order + 1] = "B:" .. entry.k end)
      self:Subscribe("GROUP_CHANGED", function(_, _, inGroup) order[#order + 1] = "B:group:" .. tostring(inGroup) end)
      self:Subscribe("CHAPTER_CLOSED", function(_, _, chapter) order[#order + 1] = "B:closed:" .. chapter.no end)
      self:Subscribe("LOG_COMPACTED", function() order[#order + 1] = "B:compacted" end)
    end
    wow.login()
    assert.same({ "A:world", "B:world", "B:zone", "B:group:false", "B:chapter", "B:closed:1" }, order)
    local char = ns.DB:Char()
    assert.equal(1202, char.seq)
    assert.equal(true, char.chapters[1].auto)
    assert.equal(1202, char.chapters[1].to)
  end)

  it("gives OnInitialize no character and OnEnable no log writes", function()
    module("Alpha")
    wow.login()
    assert.equal("Alpha:init:false", trace[1])
    assert.equal("Alpha:enable:false:false", trace[2])
    assert.is_table(ns.Alpha:Char())
  end)

  it("stops on other clients and runs no module", function()
    wow.stub("WOW_PROJECT_ID", 1)
    wow.data.build = { "12.0.1", "1", "x", 120001 }
    module("Alpha")
    wow.login()
    assert.same({}, trace)
    assert.is_true(ns.stopped)
    assert.is_nil(_G.AshmarkDB)
    assert.truthy(wow.chat[1]:find("only on World of Warcraft Forever", 1, true))
  end)

  it("detects Forever by the interface range when the project constant is missing", function()
    wow.stub("WOW_PROJECT_CAMELOT", nil)
    wow.stub("WOW_PROJECT_ID", 1)
    assert.is_true(ns.Compat.IsForever())
  end)

  it("leaves a module off when a required capability or module is missing", function()
    wow.stub("C_UnitAuras", nil)
    module("Alpha", { requires = { "auras" }, locale = "ALPHA" })
    module("Beta", { modules = { "Alpha" }, locale = "BETA" })
    module("Gamma", { requires = { "auras", "map" }, modules = { "Beta" }, locale = "GAMMA" })
    wow.login()
    assert.same({ "auras" }, ns.Alpha.unavailable)
    assert.same({ "Alpha" }, ns.Beta.unavailable)
    assert.same({ "auras", "Beta" }, ns.Gamma.unavailable)
    assert.is_false(ns.Alpha.enabled)
    assert.same({ "Alpha:init:false", "Beta:init:false", "Gamma:init:false" }, trace)
  end)

  it("honours a module's enabled setting and toggles it later", function()
    wow.saved({ schema = 1, created = 1, settings = { ["Alpha.enabled"] = false } })
    module("Alpha")
    module("Beta", { modules = { "Alpha" }, locale = "BETA" })
    wow.login()
    assert.is_false(ns.Alpha.enabled)
    assert.is_nil(ns.Alpha.unavailable)
    assert.same({ "Alpha" }, ns.Beta.unavailable)
    trace = {}
    ns.Settings:Set("Alpha.enabled", true)
    assert.same({ "Alpha:enable:true:true", "Alpha:world:false:false:true",
                  "Beta:enable:true:true", "Beta:world:false:false:true" }, trace)
    wow.fire("BAG_UPDATE")
    trace = {}
    ns.Settings:Set("Alpha.enabled", false)
    assert.same({ "Alpha:disable", "Beta:disable" }, trace)
    trace = {}
    wow.fire("BAG_UPDATE")
    ns.Log:Add("death", {})
    assert.same({}, trace)
  end)

  it("defers a toggle made in combat until combat ends", function()
    module("Alpha")
    wow.login()
    wow.combat(true)
    trace = {}
    ns.Settings:Set("Alpha.enabled", false)
    ns.Settings:Set("Alpha.enabled", true)
    ns.Settings:Set("Alpha.enabled", false)
    assert.same({}, trace)
    wow.combat(false)
    assert.same({ "Alpha:disable" }, trace)
  end)

  it("registers the module setting with its locale keys", function()
    module("Alpha", { locale = "ALPHA", default = true })
    local def = ns.Settings.defs["Alpha.enabled"]
    assert.same({ default = true, label = "ALPHA_MODULE_NAME", tooltip = "ALPHA_MODULE_DESC" }, def)
    assert.equal(ns.Alpha, ns:GetModule("Alpha"))
    assert.is_nil(ns:GetModule("Nope"))
    local names = {}
    for M in ns:Modules() do names[#names + 1] = M.name end
    assert.same({ "Alpha" }, names)
  end)

  it("keeps test checks by id and hands out a cleared test tooltip", function()
    local fn = function() return true end
    ns.Test:Register("a", function() end)
    ns.Test:Register("b", fn)
    ns.Test:Register("a", fn)
    assert.equal(2, #ns.Test.checks)
    assert.equal(fn, ns.Test.checks[1].fn)
    local tip = ns.Test:Tooltip()
    tip:AddLine("x")
    assert.equal(tip, ns.Test:Tooltip())
    assert.equal(0, tip:NumLines())
    assert.equal(UIParent, tip:GetOwner())
  end)

  it("counts played time and writes lastSeen on the ticker and at logout, never at login", function()
    wow.saved({ schema = 1, created = 1, chars = { ["Player-1-00000001"] = {
      guid = "Player-1-00000001", lastSeen = 42, seq = 0, log = {}, chapters = {}, zones = {}, stats = {},
      state = { inGroup = false, senders = {} },
    } } })
    local seenAtWorld
    local M = module("Alpha")
    M.OnWorldReady = function(self) seenAtWorld = self:Char().lastSeen end
    wow.login()
    assert.equal(42, seenAtWorld)
    assert.equal(42, ns.DB:Char().lastSeen)
    wow.advance(300)
    assert.equal(time(), ns.DB:Char().lastSeen)
    assert.equal(300, ns.DB:Char().stats["Core.playedSec"])
    wow.advance(100.5)
    wow.logout()
    assert.equal(400, ns.DB:Char().stats["Core.playedSec"])
    assert.equal(time(), ns.DB:Char().lastSeen)
  end)

  it("survives a /reload with the record intact", function()
    module("Alpha")
    wow.state.map = 1443
    wow.login()
    local seq = ns.DB:Char().seq
    ns = wow.reload()
    assert.equal(seq, ns.DB:Char().seq)
    assert.is_false(ns.DB.fresh)
    assert.same({}, wow.errors)
  end)
end)

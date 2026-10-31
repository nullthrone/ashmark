local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.profile_mock")

local DAY = mock.DAY

describe("Profile", function()
  local ns, P, changes

  local function boot(setup)
    ns = mock.boot(wow, { setup = function(n)
      changes = {}
      n.Core:Subscribe("PROFILE_CHANGED", function(_, _, axes) changes[#changes + 1] = axes end)
      if setup then setup(n) end
    end })
    P = ns.Profile
    return ns.DB:Char()
  end

  local function axes()
    return P:Axes(ns.DB:Char())
  end

  local function raw()
    return ns.DB:Char().profile.raw
  end

  -- Raw values as of now; axes not named keep theirs.
  local function set(values)
    local p = ns.DB:Char().profile
    for axis, v in pairs(values) do p.raw[axis] = v end
    p.asOf = time()
  end

  local function stat(name)
    return ns.DB:Char().stats["Profile." .. name] or 0
  end

  local function abandon(q)
    wow.data.quests[q] = { inLog = true }
    C_QuestLog.SetSelectedQuest(q)
    C_QuestLog.SetAbandonQuest()
    C_QuestLog.AbandonQuest()
  end

  local function healthWatch()
    return ns.Events:Count("UNIT_HEALTH", "target")
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("record", function()
    it("is created in the shape of 4.1 at the first world entry", function()
      local p = boot().profile
      assert.same({ fidelity = 0, habitat = 0, mercy = 0 }, p.raw)
      assert.same({ 0, 0, 0 }, { p.fidelity, p.habitat, p.mercy })
      assert.equal(time(), p.asOf)
      assert.same({ key = date("%Y-%m-%d"), kills = 0, loot = 0, quest = 0 }, p.day)
      assert.same({}, p.kept)
      assert.same({ 0, 0 }, { p.wild, p.civil })
      assert.is_nil(p.origin)
    end)

    it("registers the kill kinds, quiet in the chronicle, and its options", function()
      boot()
      for _, kind in ipairs({ "kill.neutral", "kill.critter" }) do
        local spec = ns.Log:Kind(kind)
        assert.is_table(spec, kind)
        assert.is_falsy(spec.keep)
        assert.is_nil(spec.render)
      end
      assert.is_nil(P.opts.requires)
      assert.same({ "map", "critterType" }, P.opts.optional)
      assert.is_true(P.enabled)
    end)

    it("names every archetype and itself in the enUS locale", function()
      boot()
      local L = ns.Locale:Base()
      for _, key in ipairs({ "OATHKEEPER", "OPPORTUNIST", "WANDERER", "TOWNSFOLK", "GENTLE", "RUTHLESS",
                             "PRAGMATIST", "MODULE_NAME", "MODULE_DESC", "TEST_MERCY_HOWTO" }) do
        assert.is_string(L["PROFILE_" .. key], key)
      end
    end)

    it("keeps its accumulators through a /reload", function()
      boot()
      ns.Log:Add("rest.camp", {})
      ns = wow.reload()
      local char = ns.DB:Char()
      assert.equal(6, char.profile.habitat)
      assert.equal(6, ns.Profile:Axes(char).habitat)
      assert.same({}, wow.errors)
    end)
  end)

  describe("fidelity", function()
    it("earns 2 for a turn-in on the side allied before it", function()
      boot()
      mock.accept(wow, 1001)
      assert.equal(0, axes().fidelity)
      mock.turnIn(wow, 1001)
      assert.equal(2, axes().fidelity)
      mock.turnIn(wow, 1002)
      assert.equal(4, axes().fidelity)
      mock.turnIn(wow, 9999)
      assert.equal(4, axes().fidelity)
    end)

    it("earns no 2 for the turn-in that forms the alliance", function()
      local char = boot()
      mock.turnIn(wow, 1001)
      assert.equal("A", ns.Conflicts:Alliance(char, "clan_choice"))
      assert.equal(0, raw().fidelity)
      mock.turnIn(wow, 1002)
      assert.equal(2, raw().fidelity)
    end)

    it("changes by exactly the violation weight on a violating turn-in", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 1001)
      local before = raw().fidelity
      mock.turnIn(wow, 2001)
      assert.equal(1, mock.count(char, "violation"))
      assert.equal(-25, raw().fidelity - before)
      assert.equal(-23, axes().fidelity)
      -- The word is now given to B: its turn-ins earn again.
      mock.turnIn(wow, 2002)
      assert.equal(-21, axes().fidelity)
    end)

    it("costs 15 for a violation in the opportunist wording", function()
      local char = boot()
      mock.accept(wow, 1001)
      set({ fidelity = -40 })
      assert.is_true(P:IsOpportunist(char))
      mock.turnIn(wow, 2001)
      assert.equal(1, ns.Log:Last(char, "violation").o)
      assert.equal(-55, raw().fidelity)
    end)

    it("costs 2 for an abandoned quest", function()
      boot()
      abandon(1382)
      assert.equal(-2, axes().fidelity)
    end)

    it("earns 5 for an alliance held 7 days, then 7 days after each award", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.days(wow, 6)
      assert.equal(0, axes().fidelity)
      mock.days(wow, 1)
      local since = char.conflicts.since.clan_choice
      assert.equal(since + 7 * DAY, char.profile.kept.clan_choice)
      assert.equal(5, raw().fidelity)
      mock.days(wow, 6)
      assert.equal(since + 7 * DAY, char.profile.kept.clan_choice)
      assert.equal(4, axes().fidelity)
      mock.days(wow, 1)
      assert.equal(since + 14 * DAY, char.profile.kept.clan_choice)
      assert.near(5 * 0.5 ^ ((7 * DAY + 120) / (30 * DAY)) + 5, raw().fidelity, 1e-9)
      assert.equal(9, axes().fidelity)
    end)

    it("awards a week held offline once, at the next day roll, on the alliance's own cadence", function()
      local char = boot()
      mock.accept(wow, 1001)
      local since = char.conflicts.since.clan_choice
      wow.state.epoch = wow.state.epoch + 23 * DAY
      ns = wow.reload()
      char = ns.DB:Char()
      assert.equal(since + 21 * DAY, char.profile.kept.clan_choice)
      assert.equal(5, char.profile.raw.fidelity)
    end)

    it("counts the 7 days again from a violation", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.days(wow, 5)
      mock.turnIn(wow, 2001)
      mock.days(wow, 6)
      assert.is_nil(char.profile.kept.clan_choice)
      mock.days(wow, 1)
      assert.equal(char.conflicts.since.clan_choice + 7 * DAY, char.profile.kept.clan_choice)
    end)

    it("costs 1 per 10 gold of loot beyond quest gold in a day", function()
      boot()
      wow.fire("LOOT_OPENED")
      wow.state.money = wow.state.money + 250000
      wow.fire("PLAYER_MONEY")
      wow.fire("LOOT_CLOSED")
      ns.Log:Add("gold", { src = "loot", c = 100000 })
      ns.Log:Add("gold", { src = "quest", c = 100000 })
      ns.Log:Add("gold", { src = "vendor", c = 900000 })
      assert.same({ 350000, 100000 }, { ns.DB:Char().profile.day.loot, ns.DB:Char().profile.day.quest })
      assert.equal(0, raw().fidelity)
      mock.days(wow, 1)
      assert.equal(-2, raw().fidelity)
      assert.same({ 0, 0 }, { ns.DB:Char().profile.day.loot, ns.DB:Char().profile.day.quest })
    end)

    it("costs at most 5 for one day's loot, and nothing below 10 gold beyond quest gold", function()
      boot()
      ns.Log:Add("gold", { src = "loot", c = 10000000 })
      mock.days(wow, 1)
      assert.equal(-5, raw().fidelity)
      set({ fidelity = 0 })
      ns.Log:Add("gold", { src = "loot", c = 190000 })
      ns.Log:Add("gold", { src = "quest", c = 100000 })
      mock.days(wow, 1)
      assert.equal(0, raw().fidelity)
    end)
  end)

  describe("habitat", function()
    it("earns 6 for every camp and bedroll rest", function()
      boot()
      ns.Log:Add("rest.camp", {})
      ns.Log:Add("rest.bedroll", {})
      assert.equal(12, axes().habitat)
    end)

    it("earns 1 per 600 s outdoors and not resting, and loses 1 per 600 s resting", function()
      local char = boot()
      wow.state.outdoors = true
      wow.advance(540)
      assert.same({ 540, 0 }, { char.profile.wild, axes().habitat })
      wow.advance(60)
      assert.same({ 0, 1 }, { char.profile.wild, axes().habitat })
      wow.state.resting = true
      wow.advance(1200)
      assert.same({ 0, 0, -1 }, { char.profile.wild, char.profile.civil, axes().habitat })
    end)

    it("samples nothing indoors outside a rest area or while away", function()
      local char = boot()
      wow.advance(1200)
      wow.state.outdoors = true
      wow.state.units.player.afk = true
      wow.advance(1200)
      assert.same({ 0, 0, 0 }, { char.profile.wild, char.profile.civil, axes().habitat })
    end)

    it("loses 1 for a turn-in in a capital", function()
      boot()
      wow.state.map = 1453
      mock.turnIn(wow, 5555)
      assert.equal(-1, axes().habitat)
      wow.state.map = 1429
      mock.turnIn(wow, 5556)
      assert.equal(-1, axes().habitat)
    end)

    it("samples no time and no origin without the map API, and still counts rests", function()
      local char = boot(function() wow.stub("C_Map.GetBestMapForUnit", nil) end)
      assert.is_false(ns.Compat.Has.map)
      assert.is_true(P.enabled)
      wow.state.outdoors = true
      wow.advance(1200)
      assert.same({ 0, 0 }, { char.profile.wild, axes().habitat })
      assert.is_nil(char.profile.originSec)
      ns.Log:Add("rest.camp", {})
      assert.equal(6, axes().habitat)
    end)
  end)

  describe("mercy", function()
    it("earns 1 for a played day without a kill and nothing for a day with one", function()
      boot()
      mock.days(wow, 1)
      assert.equal(1, axes().mercy)
      mock.fight(wow, mock.critter(wow))
      assert.equal(-1, axes().mercy)
      mock.days(wow, 1)
      assert.equal(-1, axes().mercy)
    end)

    it("rolls the finished day once in OnWorldReady after days offline", function()
      boot()
      wow.state.epoch = wow.state.epoch + 3 * DAY
      ns = wow.reload()
      assert.equal(1, ns.Profile:Axes(ns.DB:Char()).mercy)
      assert.equal(date("%Y-%m-%d"), ns.DB:Char().profile.day.key)
    end)

    it("costs 3 for a neutral kill and 2 for a critter", function()
      local char = boot()
      mock.fight(wow, mock.target(wow))
      assert.equal(-3, axes().mercy)
      mock.fight(wow, mock.critter(wow))
      assert.equal(-5, axes().mercy)
      assert.equal(2, char.profile.day.kills)
    end)
  end)

  describe("decay", function()
    it("halves every 30 days, and Axes decays a copy without writing", function()
      local char = boot()
      set({ fidelity = -25, habitat = 50, mercy = 10 })
      local asOf = char.profile.asOf
      wow.state.epoch = wow.state.epoch + 30 * DAY
      assert.same({ fidelity = -12, habitat = 25, mercy = 5 }, axes())
      wow.state.epoch = wow.state.epoch + 30 * DAY
      assert.same({ fidelity = -6, habitat = 13, mercy = 3 }, axes())
      assert.same({ fidelity = -25, habitat = 50, mercy = 10 }, raw())
      assert.equal(asOf, char.profile.asOf)
    end)

    it("decays the accumulators before every change", function()
      local char = boot()
      set({ fidelity = -25, mercy = 8 })
      wow.state.epoch = wow.state.epoch + 30 * DAY
      abandon(1382)
      assert.same({ fidelity = -14.5, habitat = 0, mercy = 4 }, raw())
      assert.equal(time(), char.profile.asOf)
      assert.same({ -14, 4 }, { char.profile.fidelity, char.profile.mercy })
    end)

    it("decays by the realm's clock, so a system date set a year ahead and back keeps the axes", function()
      local char = boot()
      set({ fidelity = 40, habitat = -40 })
      local real = time
      _G.time = function(t) if t then return real(t) end return real() + 365 * DAY end
      abandon(1382)
      assert.same({ fidelity = 38, habitat = -40, mercy = 0 }, axes())
      _G.time = real
      ns.Log:Add("rest.camp", {})
      assert.same({ fidelity = 38, habitat = -34, mercy = 0 }, axes())
      assert.equal(GetServerTime(), char.profile.asOf)
    end)

    it("clamps the displayed axes to -100 and 100", function()
      boot()
      set({ fidelity = 0, habitat = 180, mercy = -250 })
      assert.same({ fidelity = 0, habitat = 100, mercy = -100 }, axes())
      for _ = 1, 5 do ns.Log:Add("violation", { c = "clan_choice", side = "B", q = 2001 }) end
      assert.equal(-125, raw().fidelity)
      assert.equal(-100, axes().fidelity)
    end)

    it("fires PROFILE_CHANGED only when a displayed integer changes", function()
      local char = boot()
      local n = #changes
      ns.Log:Add("gold", { src = "loot", c = 100 })
      assert.equal(n, #changes)
      ns.Log:Add("rest.camp", {})
      assert.equal(n + 1, #changes)
      assert.same({ fidelity = 0, habitat = 6, mercy = 0 }, changes[#changes])
      set({ habitat = 6.4 })
      ns.Log:Add("gold", { src = "loot", c = 100 })
      assert.equal(n + 1, #changes)
      set({ habitat = 6.5 })
      ns.Log:Add("gold", { src = "loot", c = 100 })
      assert.equal(n + 2, #changes)
      assert.equal(7, changes[#changes].habitat)
      -- Decay alone moves it back at the next tick.
      mock.days(wow, 1)
      assert.equal(6, changes[#changes].habitat)
      assert.equal(6, char.profile.habitat)
    end)
  end)

  describe("archetype", function()
    local function archetype(f, h, m)
      set({ fidelity = f, habitat = h, mercy = m })
      return P:Archetype(ns.DB:Char())
    end

    it("follows the axis with the largest absolute value of at least 34", function()
      boot()
      assert.equal("PRAGMATIST", archetype(33, -33, 33))
      assert.equal("OATHKEEPER", archetype(34, 0, 0))
      assert.equal("OPPORTUNIST", archetype(-34, 0, 0))
      assert.equal("TOWNSFOLK", archetype(34, -40, 0))
      assert.equal("WANDERER", archetype(0, 50, -49))
      assert.equal("RUTHLESS", archetype(0, 0, -60))
      assert.equal("GENTLE", archetype(-35, 0, 60))
      assert.equal("GENTLE", archetype(0, 0, 33.6))
      assert.equal("PRAGMATIST", archetype(0, 0, 33.4))
    end)

    it("breaks ties by fidelity, then habitat, then mercy", function()
      boot()
      assert.equal("OATHKEEPER", archetype(40, -40, 40))
      assert.equal("OPPORTUNIST", archetype(-40, 40, 0))
      assert.equal("TOWNSFOLK", archetype(0, -40, 40))
      assert.equal("WANDERER", archetype(0, 40, -40))
    end)

    it("calls a character an opportunist from fidelity -34", function()
      local char = boot()
      set({ fidelity = -33 })
      assert.is_false(P:IsOpportunist(char))
      set({ fidelity = -34 })
      assert.is_true(P:IsOpportunist(char))
      wow.state.epoch = wow.state.epoch + 30 * DAY
      assert.is_false(P:IsOpportunist(char))
    end)
  end)

  describe("origin", function()
    it("counts zone time over the first 20 played hours, then keeps the leader for good", function()
      local char = boot()
      char.stats["Core.playedSec"] = 0
      wow.state.map = 1443
      wow.advance(120)
      assert.same({ [1443] = 120 }, char.profile.originSec)
      assert.equal(1443, P:Origin(char))
      wow.state.map = 9001                       -- a dungeon map counts for its zone
      wow.advance(60)
      wow.state.map = 1429
      wow.advance(180)
      assert.same({ [1443] = 180, [1429] = 180 }, char.profile.originSec)
      assert.equal(1429, P:Origin(char))         -- a tie goes to the lower map ID
      wow.advance(60)
      assert.is_nil(char.profile.origin)
      char.stats["Core.playedSec"] = 72000
      wow.advance(60)
      assert.equal(1429, char.profile.origin)
      assert.is_nil(char.profile.originSec)
      char.stats["Core.playedSec"] = 0
      wow.state.map = 1443
      wow.advance(600)
      assert.equal(1429, P:Origin(char))
      assert.is_nil(char.profile.originSec)
    end)

    it("knows no origin before any zone time", function()
      local char = boot()
      assert.is_nil(P:Origin(char))
      wow.advance(120)
      assert.is_nil(P:Origin(char))
    end)
  end)

  describe("kill approximation", function()
    local char

    before_each(function()
      char = boot()
    end)

    it("writes kill.neutral when a calm neutral target attacked by the player dies", function()
      mock.fight(wow, mock.target(wow))
      assert.equal(1, mock.count(char, "kill.neutral"))
      assert.equal(0, mock.count(char, "kill.critter"))
      assert.same({ 1, 1, 0, 0 }, { stat("killCand"), stat("killNeutral"), stat("killCritter"), stat("killSecret") })
      assert.equal(0, healthWatch())
    end)

    it("tells critters by creature type ID, else by the client's name for type 8", function()
      mock.fight(wow, mock.critter(wow))
      mock.fight(wow, mock.critter(wow, { creatureTypeID = mock.NONE }))
      mock.fight(wow, mock.target(wow, { creatureType = "Critter", creatureTypeID = 1 }))
      assert.equal(2, mock.count(char, "kill.critter"))
      assert.equal(1, mock.count(char, "kill.neutral"))
      assert.same({ 3, 1, 2 }, { stat("killCand"), stat("killNeutral"), stat("killCritter") })
    end)

    it("takes no hostile, friendly, fighting, player-controlled, dead or missing target", function()
      for _, fields in ipairs({ { reaction = 2 }, { reaction = 5 }, { combat = true }, { playerControlled = true },
                                { dead = true }, { reaction = mock.NONE } }) do
        mock.fight(wow, mock.target(wow, fields))
      end
      wow.unit("target", nil)
      wow.fire("PLAYER_TARGET_CHANGED")
      wow.combat(true)
      wow.combat(false)
      assert.equal(0, stat("killCand"))
      assert.same({ 0, 0 }, { mock.count(char, "kill.neutral"), mock.count(char, "kill.critter") })
    end)

    it("samples only while the player is out of combat by UnitAffectingCombat, never by lockdown", function()
      wow.state.inCombat = true
      local target = mock.target(wow)
      wow.combat(true)
      mock.die(wow, target)
      wow.combat(false)
      assert.equal(0, stat("killCand"))
      wow.state.combatLockdown = true
      target = mock.target(wow)
      wow.state.combatLockdown = false
      mock.fight(wow, target)
      assert.same({ 1, 1 }, { stat("killCand"), mock.count(char, "kill.neutral") })
    end)

    it("keeps the candidate on UNIT_FLAGS(target) in combat before PLAYER_REGEN_DISABLED", function()
      local target = mock.target(wow)
      target.combat = true
      wow.fire("UNIT_FLAGS", "target")           -- the target first, the player still out of combat
      wow.state.inCombat = true
      wow.fire("UNIT_FLAGS", "target")           -- both in combat, no REGEN event yet
      wow.combat(true)
      assert.equal(1, stat("killCand"))
      assert.equal(1, healthWatch())
      mock.die(wow, target)
      wow.combat(false)
      assert.equal(1, mock.count(char, "kill.neutral"))
    end)

    it("samples on UNIT_FLAGS without a candidate and drops one whose reaction changed", function()
      local target = mock.target(wow, { reaction = 2 })
      target.reaction = 4
      wow.fire("UNIT_FLAGS", "target")
      target.reaction = 2
      wow.fire("UNIT_FLAGS", "target")
      mock.fight(wow, target)
      assert.equal(0, stat("killCand"))
      target.reaction, target.combat, target.dead = 4, false, false
      wow.fire("UNIT_FLAGS", "target")
      mock.fight(wow, target)
      assert.same({ 1, 1 }, { stat("killCand"), mock.count(char, "kill.neutral") })
    end)

    it("sees a death that shows up in UNIT_FLAGS after the last health update", function()
      local target = mock.target(wow)
      mock.engage(wow, target)
      mock.die(wow, target, "UNIT_FLAGS")
      assert.equal(1, mock.count(char, "kill.neutral"))
      assert.equal(0, healthWatch())
      wow.combat(false)
    end)

    it("writes nothing for a death tapped by someone else", function()
      local target = mock.target(wow)
      mock.engage(wow, target)
      target.tapDenied = true
      mock.die(wow, target)
      assert.equal(0, healthWatch())
      wow.combat(false)
      assert.equal(0, mock.count(char, "kill.neutral"))
      assert.equal(0, axes().mercy)
    end)

    it("drops the candidate on a target change in combat and at the end of combat", function()
      local target = mock.target(wow)
      mock.engage(wow, target)
      local other = mock.target(wow, { name = "Kodo" })
      assert.equal(0, healthWatch())
      mock.die(wow, other)
      wow.fire("UNIT_FLAGS", "target")
      wow.combat(false)
      target = mock.target(wow)
      mock.engage(wow, target)
      wow.combat(false)
      assert.equal(0, healthWatch())
      target.combat = true
      wow.combat(true)
      mock.die(wow, target)
      wow.combat(false)
      assert.equal(2, stat("killCand"))
      assert.equal(0, mock.count(char, "kill.neutral"))
    end)

    it("registers UNIT_HEALTH for the target only while a frozen candidate exists", function()
      assert.equal(0, healthWatch())
      mock.target(wow)
      assert.equal(0, healthWatch())
      wow.combat(true)
      assert.equal(1, healthWatch())
      assert.equal(1, wow.registered("UNIT_HEALTH"))
      wow.combat(false)
      assert.equal(0, healthWatch())
      assert.equal(0, wow.registered("UNIT_HEALTH"))
      mock.target(wow, { reaction = 2 })
      wow.combat(true)
      assert.equal(0, healthWatch())
      wow.combat(false)
    end)

    it("drops the candidate and counts every secret read", function()
      mock.target(wow, { reaction = wow.secret(4) })
      assert.equal(1, stat("killSecret"))
      local target = mock.target(wow)
      target.reaction = wow.secret(4)
      wow.fire("UNIT_FLAGS", "target")
      assert.equal(2, stat("killSecret"))
      wow.combat(true)
      wow.combat(false)
      assert.equal(0, stat("killCand"))
      target = mock.target(wow)
      mock.engage(wow, target)
      target.dead = wow.secret(true)
      wow.fire("UNIT_HEALTH", "target")
      assert.equal(3, stat("killSecret"))
      assert.equal(0, healthWatch())
      wow.combat(false)
      target = mock.target(wow)
      mock.engage(wow, target)
      target.dead, target.tapDenied = true, wow.secret(false)
      wow.fire("UNIT_HEALTH", "target")
      assert.equal(4, stat("killSecret"))
      wow.combat(false)
      wow.state.units.player.combat = wow.secret(false)
      mock.target(wow)
      assert.equal(5, stat("killSecret"))
      wow.state.units.player.combat = nil
      mock.target(wow, { creatureType = wow.secret("Beast"), creatureTypeID = wow.secret(1) })
      assert.equal(6, stat("killSecret"))
      wow.combat(true)
      wow.combat(false)
      assert.equal(2, stat("killCand"))
      assert.equal(0, mock.count(char, "kill.neutral"))
    end)
  end)

  describe("services", function()
    it("answer for any record, also while the module is off", function()
      local char = boot()
      local zero = { fidelity = 0, habitat = 0, mercy = 0 }
      local records = { {}, { profile = 5 }, { profile = { raw = "x" } },
                        { profile = { raw = { fidelity = "a", mercy = 0 / 0 }, asOf = "b", origin = "c" } } }
      for _, rec in ipairs(records) do
        assert.same(zero, P:Axes(rec))
        assert.equal("PRAGMATIST", P:Archetype(rec))
        assert.is_nil(P:Origin(rec))
        assert.is_false(P:IsOpportunist(rec))
      end
      assert.same(zero, P:Axes(nil))
      assert.is_nil(P:Origin(nil))
      local sibling = { profile = { raw = { fidelity = 0, habitat = -50, mercy = 0 }, asOf = time(),
                                    originSec = { [1429] = 60, [1453] = 600 } } }
      assert.equal("TOWNSFOLK", P:Archetype(sibling))
      assert.equal(1453, P:Origin(sibling))
      ns.Settings:Set("Profile.enabled", false)
      assert.is_false(P.enabled)
      set({ fidelity = -50 })
      assert.is_true(P:IsOpportunist(char))
      assert.equal("OPPORTUNIST", P:Archetype(char))
    end)

    it("stop the ticker and the kill watch while the module is off", function()
      local char = boot()
      wow.state.outdoors = true
      ns.Settings:Set("Profile.enabled", false)
      wow.advance(1200)
      mock.fight(wow, mock.target(wow))
      assert.same({ 0, 0, 0 }, { char.profile.wild, mock.count(char, "kill.neutral"), stat("killCand") })
      ns.Settings:Set("Profile.enabled", true)
      wow.advance(600)
      assert.equal(1, axes().habitat)
      mock.fight(wow, mock.target(wow))
      assert.equal(1, mock.count(char, "kill.neutral"))
    end)

    it("add up to a replay of the log", function()
      local char = boot()
      mock.accept(wow, 1001)
      mock.turnIn(wow, 1001)
      mock.turnIn(wow, 1002)
      wow.state.map = 1453
      mock.turnIn(wow, 2001)
      mock.turnIn(wow, 2002)
      wow.state.map = 1443
      mock.turnIn(wow, 1003)
      abandon(1382)
      ns.Log:Add("rest.camp", {})
      ns.Log:Add("rest.bedroll", {})
      mock.fight(wow, mock.target(wow))
      mock.fight(wow, mock.critter(wow))
      assert.equal(2, mock.count(char, "violation"))
      local replay = mock.replay(ns, char, mock.data())
      assert.same({ fidelity = -46, habitat = 10, mercy = -5 }, replay)
      assert.same(replay, axes())
    end)
  end)

  describe("test checks", function()
    it("report the kill counters with the how-to", function()
      boot()
      local ok, detail = mock.check(ns, "Profile.mercy")
      assert.is_nil(ok)
      assert.truthy(detail:find("candidates 0, secret reads 0, neutral kills 0, critter kills 0", 1, true))
      assert.truthy(detail:find(ns.L.PROFILE_TEST_MERCY_HOWTO, 1, true))
      mock.fight(wow, mock.critter(wow))
      ok, detail = mock.check(ns, "Profile.mercy")
      assert.is_true(ok)
      assert.truthy(detail:find("candidates 1, secret reads 0, neutral kills 0, critter kills 1", 1, true))
    end)

    it("report how critters are told apart", function()
      boot()
      assert.same({ true, "critterType: Critter" }, { mock.check(ns, "Profile.critter") })
      mock.target(wow)
      assert.same({ true, "creature type ID" }, { mock.check(ns, "Profile.critter") })
    end)

    it("say when critters cannot be told apart, and then a critter kill counts as neutral", function()
      local char = boot(function() wow.stub("C_CreatureInfo.GetCreatureTypeInfo", function() end) end)
      assert.is_false(ns.Compat.Has.critterType)
      assert.same({ nil, ns.L.PROFILE_TEST_CRITTER_TARGET }, { mock.check(ns, "Profile.critter") })
      mock.fight(wow, mock.critter(wow, { creatureTypeID = mock.NONE }))
      assert.same({ false, ns.L.PROFILE_TEST_CRITTER_OFF }, { mock.check(ns, "Profile.critter") })
      assert.same({ 0, 1 }, { mock.count(char, "kill.critter"), mock.count(char, "kill.neutral") })
    end)

    it("show the axes, the archetype and the origin", function()
      boot()
      set({ fidelity = 40 })
      wow.state.map = 1443
      wow.advance(60)
      assert.same({ true, "fidelity 40, habitat 0, mercy 0, OATHKEEPER, origin 1443" },
        { mock.check(ns, "Profile.axes") })
    end)

    it("run in the test mode without an error", function()
      ns = mock.boot(wow, { files = { "Dev" } })
      SlashCmdList.ASHMARK("test")
      local tests = _G.AshmarkDB.dev.tests
      local ids = {}
      for _, r in ipairs(tests[#tests].results) do ids[r.id] = r end
      assert.is_true(ids["Profile.axes"].ok)
      assert.is_true(ids["Profile.critter"].ok)
      assert.is_nil(ids["Profile.mercy"].ok)
      assert.is_true(ids["Module.Profile"].ok)
      wow.advance(11)
    end)
  end)
end)

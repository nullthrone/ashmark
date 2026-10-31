local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.rumours_mock")

local MIRA, THALEN = mock.MIRA, mock.THALEN
local DAY, HOUR = 86400, 3600

describe("Rumours", function()
  local ns

  local function boot(opts)
    ns = mock.boot(wow, opts)
    return ns.DB:Char()
  end

  local function heard()
    return _G.AshmarkDB.rumours.heard
  end

  local function told()
    return _G.AshmarkDB.rumours.told
  end

  local function only()
    local id = next(heard())
    return heard()[id]
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("needs addon messages and the Fiction module", function()
    boot()
    local M = ns.Rumours
    assert.same({ "addonMessages" }, M.opts.requires)
    assert.same({ "canSend" }, M.opts.optional)
    assert.same({ "Fiction" }, M.opts.modules)
    assert.is_true(M.enabled)
    ns.Settings:Set("Fiction.enabled", false)
    assert.same({ "Fiction" }, M.unavailable)
    assert.is_false(M.enabled)
  end)

  describe("seeds", function()
    it("turn an own alliance into a rumour with a random 8-hex id", function()
      boot()
      local now = wow.state.epoch
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      local r = only()
      assert.matches("^[0-9a-f]+$", r.id)
      assert.equal(8, #r.id)
      assert.same({ id = r.id, tpl = "ALLIANCE", a = "OATHKEEPER", f = 92, m = 1443, hops = 0, strength = 100,
                    t = now, heard = now, own = true }, r)
      assert.equal(r, ns.Rumours:Get(r.id))
    end)

    it("name the faction broken with for a violation and the faction taken for a house turn", function()
      boot()
      mock.archetype = "OPPORTUNIST"
      ns.Log:Add("violation", { c = "gelkis", side = "B", q = 1385 })
      local broke = only()
      assert.same({ "BROKE", 92, "OPPORTUNIST" }, { broke.tpl, broke.f, broke.a })
      heard()[broke.id] = nil
      ns.Log:Add("houseturn", { c = "gelkis", side = "B", q = 1385, h = "Ashvale" })
      local turned = only()
      assert.same({ "TURNED", 93, 1443 }, { turned.tpl, turned.f, turned.m })
    end)

    it("keep faction 0 for a side without one", function()
      boot()
      ns.Log:Add("alliance", { c = "bloodsail", side = "B" })
      assert.same({ 0, 1434 }, { only().f, only().m })
    end)

    it("ignore other kinds and unknown conflicts", function()
      boot()
      ns.Log:Add("alliance", { c = "nowhere", side = "A" })
      ns.Log:Add("level", { l = 21 })
      assert.same({}, heard())
    end)

    it("draw the id again on a collision", function()
      mock.saved(wow, { deadbeef = mock.rumour("deadbeef", wow.state.epoch) })
      local tokens = { "deadbeef", "cafef00d" }
      boot({ setup = function(n)
        n.Util.Token = function() return table.remove(tokens, 1) end
      end })
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      assert.same({ "cafef00d", "deadbeef" }, mock.heardIds())
      assert.is_true(heard().cafef00d.own)
      assert.is_nil(heard().deadbeef.own)
    end)
  end)

  describe("strength", function()
    it("halves every 3 days from the moment the copy got its strength", function()
      boot()
      local now = wow.state.epoch
      assert.equal(100, ns.Rumours:Strength(mock.rumour("a", now, { strength = 100 })))
      assert.equal(50, ns.Rumours:Strength(mock.rumour("a", now - 3 * DAY, { strength = 100 })))
      assert.equal(25, ns.Rumours:Strength(mock.rumour("a", now - 6 * DAY, { strength = 100 })))
      assert.equal(35, ns.Rumours:Strength(mock.rumour("a", now - 3 * DAY, { t = now - 30 * DAY })))
      assert.equal(0, ns.Rumours:Strength(nil))
      assert.equal(0, ns.Rumours:Strength({ id = "a" }))
    end)

    it("drops rumours below 20 at the next prune, with their told lists", function()
      local now = wow.state.epoch
      mock.saved(wow, {
        weak = mock.rumour("weak", now - 7 * DAY, { strength = 100, own = true }),
        kept = mock.rumour("kept", now - 6 * DAY, { strength = 100, own = true }),
        broken = { id = "broken" },
      }, { weak = { [MIRA] = now }, kept = { [MIRA] = now }, gone = { [MIRA] = now } })
      boot()
      assert.same({ "kept" }, mock.heardIds())
      assert.same({ kept = { [MIRA] = now } }, told())
    end)
  end)

  describe("receiving", function()
    local seen

    local function start(opts)
      local char = boot(opts)
      seen = mock.listen(ns, { "RUMOUR_HEARD" }, {})
      mock.peers(wow, "mira")
      wow.chat = {}
      return char
    end

    it("stores the copy one hop on, writes the rumour entry, fires RUMOUR_HEARD and prints one line", function()
      start()
      local now = wow.state.epoch
      mock.ru(wow, "mira", { id = "deadbeef", hops = 0, strength = 100, age = 5 })
      local r = heard().deadbeef
      assert.same({ id = "deadbeef", tpl = "ALLIANCE", a = "OATHKEEPER", f = 92, m = 1443, hops = 1, strength = 70,
                    t = now - 5 * HOUR, heard = now }, r)
      local entries = mock.entries(ns, "rumour")
      assert.equal(1, #entries)
      assert.equal("deadbeef", entries[1].r)
      assert.same({ { "RUMOUR_HEARD", r } }, seen)
      assert.same({ "People say the Oathkeeper from Desolace has sided with Gelkis Clan Centaur." }, mock.lines(wow))
      local info = ChatTypeInfo.MONSTER_SAY
      assert.same({ info.r, info.g, info.b }, wow.chatColors[1])
      assert.same({ [MIRA] = now }, told().deadbeef)
    end)

    it("widens the place to the continent from the second hop and drops the faction from the third", function()
      start()
      mock.ru(wow, "mira", { id = "00000002", hops = 1, tpl = "BROKE" })
      mock.ru(wow, "mira", { id = "00000003", hops = 2, tpl = "TURNED", a = "TOWNSFOLK" })
      assert.same({ 2, 1414, 92 }, { heard()["00000002"].hops, heard()["00000002"].m, heard()["00000002"].f })
      assert.same({ 3, 1414, 0 }, { heard()["00000003"].hops, heard()["00000003"].m, heard()["00000003"].f })
      assert.same({
        "People say the Oathkeeper from Kalimdor broke faith with Gelkis Clan Centaur.",
        "People say the Town-dweller from Kalimdor turned from their own house.",
      }, mock.lines(wow))
    end)

    it("uses the vague line for a rumour without a faction", function()
      start()
      mock.ru(wow, "mira", { f = 0, m = 1434, a = "GENTLE" })
      assert.same({ "People say the Gentle soul from Stranglethorn Vale has chosen a side." }, mock.lines(wow))
    end)

    it("names the archetype without a sex: a feminine form is never picked", function()
      wow.state.units.player.sex = 3
      start()
      ns.Locale:Base().PROFILE_OATHKEEPER_F = "Oathkeeper (f)"
      mock.ru(wow, "mira", {})
      assert.same({ "People say the Oathkeeper from Desolace has sided with Gelkis Clan Centaur." }, mock.lines(wow))
    end)

    it("drops a rumour whose place is unknown or that falls below 20", function()
      start()
      mock.ru(wow, "mira", { id = "00000001", m = 777777 })
      mock.ru(wow, "mira", { id = "00000002", m = 0 })
      mock.ru(wow, "mira", { id = "00000003", hops = 1, m = 9003 })
      mock.ru(wow, "mira", { id = "00000004", strength = 28 })
      mock.ru(wow, "mira", { id = "00000005", strength = 29 })
      assert.same({ "00000005" }, mock.heardIds())
      assert.equal(20, heard()["00000005"].strength)
      assert.equal(1, #seen)
    end)

    it("takes 30 % off the strength per hop, rounded down", function()
      start()
      mock.ru(wow, "mira", { id = "00000001", strength = 90 })
      mock.ru(wow, "mira", { id = "00000002", strength = 99 })
      assert.same({ 63, 69 }, { heard()["00000001"].strength, heard()["00000002"].strength })
    end)

    it("keeps the stronger copy of a known rumour and prints nothing for it", function()
      start()
      mock.ru(wow, "mira", { strength = 50 })
      assert.equal(35, heard().deadbeef.strength)
      mock.ru(wow, "mira", { strength = 100, age = 2 })
      assert.equal(70, heard().deadbeef.strength)
      mock.ru(wow, "mira", { strength = 60 })
      assert.equal(70, heard().deadbeef.strength)
      assert.equal(1, #mock.lines(wow))
      assert.equal(1, #mock.entries(ns, "rumour"))
      assert.equal(1, #seen)
    end)

    it("never replaces an own rumour", function()
      start({ setup = function(n) n.Util.Token = function() return "deadbeef" end end })
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      mock.ru(wow, "mira", { strength = 100 })
      local r = heard().deadbeef
      assert.same({ true, 0, 100 }, { r.own, r.hops, r.strength })
      assert.same({}, mock.lines(wow))
      assert.is_number(told().deadbeef[MIRA])
    end)

    it("decays a received copy from the moment it was heard", function()
      start()
      mock.ru(wow, "mira", { strength = 100, age = 72 })
      assert.equal(70, ns.Rumours:Strength(heard().deadbeef))
      wow.advance(3 * DAY)
      assert.equal(35, ns.Rumours:Strength(heard().deadbeef))
    end)

    it("drops a rumour from a party member who has not said HI", function()
      boot()
      mock.join(wow, "mira")
      mock.ru(wow, "mira")
      assert.same({}, heard())
    end)

    it("keeps listening on an account that cannot send", function()
      wow.state.trial = true
      start()
      mock.ru(wow, "mira")
      assert.is_table(heard().deadbeef)
    end)

    it("takes at most 6 new rumours per sender in 2 minutes and drops the rest unstored", function()
      start()
      mock.peers(wow, "mira", "thalen")
      wow.advance(5)
      seen = mock.listen(ns, { "RUMOUR_HEARD" }, {})
      local t0 = wow.state.epoch
      for i = 1, 8 do mock.ru(wow, "mira", { id = string.format("%08x", i) }) end
      mock.ru(wow, "mira", { id = "00000001", strength = 100 })
      for i = 9, 14 do mock.ru(wow, "thalen", { id = string.format("%08x", i) }) end
      assert.same({ "00000001", "00000002", "00000003", "00000004", "00000005", "00000006", "00000009", "0000000a",
                    "0000000b", "0000000c", "0000000d", "0000000e" }, mock.heardIds())
      assert.is_nil(told()["00000007"])
      assert.equal(12, #seen)
      wow.advance(t0 + 119 - wow.state.epoch)
      mock.ru(wow, "mira", { id = "00000007" })
      assert.is_nil(heard()["00000007"])
      wow.advance(1)
      mock.ru(wow, "mira", { id = "00000007" })
      assert.is_table(heard()["00000007"])
    end)

    it("writes the rumour entry only with a printed line, so a flood adds at most 5 entries an hour", function()
      start()
      for minute = 1, 120 do
        for i = 1, 20 do mock.ru(wow, "mira", { id = string.format("%04x%04x", minute, i) }) end
        wow.advance(60)
      end
      assert.equal(10, #mock.entries(ns, "rumour"))
      assert.equal(10, #mock.lines(wow))
      assert.equal(200, #mock.heardIds())
    end)

    it("never lets received copies push an own rumour out of the store", function()
      local now = wow.state.epoch
      local list = { mine = mock.rumour("mine", now - 2 * DAY, { strength = 100, hops = 0, own = true }) }
      for i = 1, 199 do
        local id = string.format("%08x", i)
        list[id] = mock.rumour(id, now)
      end
      mock.saved(wow, list)
      start()
      assert.equal(62, ns.Rumours:Strength(heard().mine))
      mock.ru(wow, "mira", { id = "ffffffff", strength = 100 })
      assert.is_table(heard().mine)
      assert.is_table(heard().ffffffff)
      assert.is_nil(heard()["00000001"])
      assert.equal(200, #mock.heardIds())
    end)
  end)

  describe("caps", function()
    it("keep 200 rumours: the weakest go, with their told lists", function()
      local now = wow.state.epoch
      local list = {}
      for i = 1, 201 do
        local id = string.format("%08x", i)
        list[id] = mock.rumour(id, now, { strength = i == 1 and 21 or 60 })
      end
      mock.saved(wow, list, { ["00000001"] = { [MIRA] = now } })
      boot()
      assert.is_nil(heard()["00000001"])
      assert.same({}, told())
      local n = 0
      for _ in pairs(heard()) do n = n + 1 end
      assert.equal(200, n)
      mock.peers(wow, "mira")
      mock.ru(wow, "mira", { id = "ffffffff" })
      assert.is_table(heard().ffffffff)
      assert.is_nil(heard()["00000002"])
      assert.is_table(heard()["00000003"])
    end)

    it("keep 50 peers per told list, the newest, none older than 30 days", function()
      local now = wow.state.epoch
      local peers = { ["Player-1-0000ffff"] = now - 31 * DAY }
      for i = 1, 51 do peers[string.format("Player-1-%08x", i)] = now - 1000 + i end
      mock.saved(wow, { deadbeef = mock.rumour("deadbeef", now) }, { deadbeef = peers })
      boot()
      local kept = told().deadbeef
      local n = 0
      for _ in pairs(kept) do n = n + 1 end
      assert.equal(50, n)
      assert.is_nil(kept["Player-1-0000ffff"])
      assert.is_nil(kept["Player-1-00000001"])
      assert.is_number(kept["Player-1-00000002"])
    end)

    it("leave the player's own log alone through four hours of RU floods and archetype flips", function()
      boot()
      for i = 1, 1500 do ns.Log:Add("quest.turnin", { q = i }) end
      mock.peers(wow, "mira", "thalen")
      for minute = 1, 240 do
        for i = 1, 20 do
          mock.ru(wow, "mira", { id = string.format("%04x%04x", minute, i) })
          mock.hi(wow, "thalen", i % 2 == 0 and "RUTHLESS" or "GENTLE")
        end
        wow.advance(60)
      end
      local char = ns.DB:Char()
      assert.is_true(ns.Log:Count(char) < 1600)
      ns.Log:Compact(char)
      assert.equal(1500, #mock.entries(ns, "quest.turnin"))
      assert.equal(20, #mock.entries(ns, "rumour"))
      assert.equal(2, #mock.entries(ns, "peer"))
    end)
  end)

  describe("exchange", function()
    it("tells a new peer the rumour 5 s after it was seen, with the decayed strength and the age", function()
      boot()
      local t = wow.state.epoch
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      local id = only().id
      mock.peers(wow, "mira")
      wow.advance(4)
      assert.same({}, mock.sentRU(wow))
      wow.advance(1)
      local now = wow.state.epoch
      local sent = mock.sentRU(wow)
      assert.equal(1, #sent)
      assert.equal(string.format("1|RU|%s|ALLIANCE|0|%d|0|OATHKEEPER|92|1443", id,
        math.floor(100 * 0.5 ^ ((now - t) / (3 * DAY)))), sent[1].text)
      assert.is_nil(sent[1].text:find("Player-", 1, true))
      assert.is_nil(sent[1].text:find("Aren", 1, true))
      assert.same({ [MIRA] = now }, told()[id])
    end)

    it("sends at most 3 rumours, newest first, then strongest", function()
      local now = wow.state.epoch
      local function own(id, age, s)
        return mock.rumour(id, now - age * HOUR, { strength = s, hops = 0, own = true })
      end
      mock.saved(wow, {
        ["00000001"] = own("00000001", 5, 100), ["00000002"] = own("00000002", 1, 100),
        ["00000003"] = own("00000003", 2, 100), ["00000004"] = own("00000004", 1, 80),
        ["00000005"] = own("00000005", 3, 100),
      })
      boot()
      mock.peers(wow, "mira")
      wow.advance(5)
      local sent = mock.sentRU(wow)
      assert.same({ "00000002", "00000004", "00000003" }, mock.ids(sent))
      assert.same({ 1, 1, 2 }, { sent[1].age, sent[2].age, sent[3].age })
    end)

    it("tells nobody twice, never tells back the peer it heard from, and keeps one round per 2 minutes", function()
      boot()
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      local id = only().id
      mock.peers(wow, "mira")
      mock.ru(wow, "mira", { id = "deadbeef" })
      wow.advance(5)
      assert.same({ id }, mock.ids(mock.sentRU(wow)))
      local first = wow.state.epoch
      wow.advance(30)
      mock.peers(wow, "mira", "thalen")
      wow.advance(5)
      assert.equal(1, #mock.sentRU(wow))
      wow.advance(first + 119 - wow.state.epoch)
      assert.equal(1, #mock.sentRU(wow))
      wow.advance(1)
      local sent = mock.sentRU(wow)
      assert.same({ "deadbeef", id }, { sent[2].id, sent[3].id })
      assert.same({ 1, 0 }, { sent[2].hops, sent[3].hops })
      assert.same({ [MIRA] = first + 120, [THALEN] = first + 120 }, told().deadbeef)
    end)

    it("runs a round when a chapter closes with members", function()
      wow.saved({ schema = 1, peers = { [MIRA] = { guid = MIRA, archetype = "WANDERER", seenBy = {} } } })
      boot({ party = { "mira" } })
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      ns.Log:CloseChapter({})
      assert.same({}, mock.sentRU(wow))
      ns.Log:Add("level", { l = 21 })
      ns.Log:CloseChapter({ MIRA })
      assert.equal(1, #mock.sentRU(wow))
    end)

    it("sends nothing on an account that cannot send, or with sharing off", function()
      wow.state.trial = true
      boot()
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      mock.peers(wow, "mira")
      wow.advance(10)
      assert.same({}, wow.sent)
      wow.reset()
      boot()
      ns.Settings:Set("Comm.share", false)
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      mock.peers(wow, "mira")
      wow.advance(10)
      assert.same({}, wow.sent)
      assert.same({}, told())
    end)

    it("passes on no copy past the wire's hop limit", function()
      boot()
      mock.peers(wow, "mira", "thalen")
      mock.ru(wow, "mira", { id = "00000009", hops = 8, strength = 100, f = 0, m = 1414 })
      mock.ru(wow, "mira", { id = "0000000a", hops = 9, strength = 100, f = 0, m = 1414 })
      assert.same({ 9, 10 }, { heard()["00000009"].hops, heard()["0000000a"].hops })
      wow.advance(5)
      assert.same({ "00000009" }, mock.ids(mock.sentRU(wow)))
    end)
  end)

  describe("lines", function()
    local function enter(map)
      wow.state.map = map
      wow.fire("ZONE_CHANGED_NEW_AREA")
    end

    it("print a heard rumour again in its zone after 24 hours, not before", function()
      boot()
      mock.peers(wow, "mira")
      mock.ru(wow, "mira")
      enter(1443)
      assert.equal(1, #mock.lines(wow))
      wow.advance(DAY - 1)
      enter(1411)
      enter(1443)
      assert.equal(1, #mock.lines(wow))
      wow.advance(1)
      enter(1411)
      enter(1443)
      assert.equal(2, #mock.lines(wow))
    end)

    it("pick the strongest heard rumour of the zone or its continent, never an own one", function()
      local now = wow.state.epoch
      mock.saved(wow, {
        zone = mock.rumour("zone", now, { strength = 40 }),
        land = mock.rumour("land", now, { strength = 60, m = 1414, hops = 2, a = "RUTHLESS" }),
        away = mock.rumour("away", now, { strength = 90, m = 1434 }),
        mine = mock.rumour("mine", now, { strength = 100, own = true, hops = 0 }),
      })
      boot()
      enter(1443)
      enter(1443)
      enter(1443)
      assert.same({
        "People say the Ruthless soul from Kalimdor has sided with Gelkis Clan Centaur.",
        "People say the Wanderer from Desolace has sided with Gelkis Clan Centaur.",
      }, mock.lines(wow))
      local shown = ns.DB:Char().state.shown
      assert.same({ land = now, zone = now }, shown)
    end)

    it("print at most 5 rumour lines an hour in total", function()
      boot()
      mock.peers(wow, "mira")
      for i = 1, 7 do
        mock.ru(wow, "mira", { id = string.format("%08x", i), strength = 30 + 10 * i })
        wow.advance(20)
      end
      assert.equal(7, #mock.heardIds())
      assert.equal(5, #mock.lines(wow))
      assert.equal(5, #mock.entries(ns, "rumour"))
      enter(1443)
      assert.equal(5, #mock.lines(wow))
      wow.advance(HOUR)
      enter(1443)
      local lines = mock.lines(wow)
      assert.equal(6, #lines)
      assert.is_number(ns.DB:Char().state.shown["00000007"])
      assert.is_nil(ns.DB:Char().state.shown["00000006"])
    end)

    it("count no line while chat lines are off", function()
      boot()
      mock.peers(wow, "mira")
      ns.Settings:Set("Core.chatLines", false)
      mock.ru(wow, "mira")
      assert.same({}, mock.lines(wow))
      assert.same({}, ns.DB:Char().state.lines)
      assert.same({}, mock.entries(ns, "rumour"))
      ns.Settings:Set("Core.chatLines", true)
      enter(1443)
      assert.equal(1, #mock.lines(wow))
    end)
  end)

  describe("public services", function()
    it("answer while the module is off", function()
      local now = wow.state.epoch
      mock.saved(wow, { deadbeef = mock.rumour("deadbeef", now - 3 * DAY, { strength = 60 }) })
      boot()
      ns.Settings:Set("Rumours.enabled", false)
      assert.equal("deadbeef", ns.Rumours:Get("deadbeef").id)
      assert.equal(30, ns.Rumours:Strength(ns.Rumours:Get("deadbeef")))
      assert.is_nil(ns.Rumours:Get("cafef00d"))
      assert.is_nil(ns.Rumours:Get(nil))
    end)
  end)

  describe("test check", function()
    it("is skipped with a hint until a rumour exists, then counts rumours and told peers", function()
      boot()
      local ok, detail = mock.check(ns, "Rumours.counts")
      assert.is_nil(ok)
      assert.matches("Side with a faction in a conflict", detail, 1, true)
      ns.Log:Add("alliance", { c = "gelkis", side = "A" })
      mock.peers(wow, "mira")
      mock.ru(wow, "mira")
      wow.advance(5)
      ok, detail = mock.check(ns, "Rumours.counts")
      assert.is_true(ok)
      assert.matches("rumours 2 (own 1, heard 1, strong enough to pass on 2), told 2 times, send and receive",
        detail, 1, true)
    end)
  end)
end)

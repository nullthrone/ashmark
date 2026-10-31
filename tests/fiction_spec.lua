local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.fiction_mock")

local ME = mock.ME
local MIRA, THALEN = mock.guid("mira"), mock.guid("thalen")
local ALT = "Player-1-0000000b"
local DAY = 86400
local HI = "1|HI|" .. ME .. "|OATHKEEPER|1443|Normal|1.0.0-test"
local PR = "1|PR|" .. ME .. "|41|-7|12"

describe("Fiction", function()
  local ns

  local function boot(opts)
    ns = mock.boot(wow, opts)
    return ns.DB:Char()
  end

  local function greeted()
    return ns.DB:Char().state.greeted
  end

  local function texts()
    local out = {}
    for _, m in ipairs(wow.sent) do out[#out + 1] = m.text end
    return out
  end

  before_each(function()
    wow.reset()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("needs addon messages, sends only with canSend and registers the keep kind peer", function()
    boot()
    assert.same({ "addonMessages" }, ns.Fiction.opts.requires)
    assert.same({ "canSend" }, ns.Fiction.opts.optional)
    assert.is_true(ns.Fiction.enabled)
    assert.same({ fields = { "p", "a" }, keep = true }, ns.Log:Kind("peer"))
  end)

  it("is unavailable without addon messages", function()
    wow.stub("C_ChatInfo.SendAddonMessage", nil)
    boot()
    assert.same({ "addonMessages" }, ns.Fiction.unavailable)
    assert.is_false(ns.Fiction.enabled)
  end)

  describe("greeting", function()
    it("sends HI and then PR once when someone joins, and marks every member greeted", function()
      boot()
      local t = wow.state.epoch
      mock.join(wow, "mira")
      assert.same({ HI, PR }, texts())
      assert.same({ "PARTY", "PARTY" }, { wow.sent[1].channel, wow.sent[2].channel })
      assert.same({ [MIRA] = t + 2 }, greeted())
      mock.roster(wow)
      wow.advance(60)
      mock.roster(wow)
      assert.equal(2, #wow.sent)
    end)

    it("greets several members who join together with one HI and one PR", function()
      boot()
      mock.join(wow, "mira", "thalen")
      assert.same({ "HI", "PR" }, mock.sent(wow))
      local list = greeted()
      assert.is_number(list[MIRA])
      assert.is_number(list[THALEN])
    end)

    it("coalesces roster updates for 2 s", function()
      boot()
      mock.party(wow, "mira")
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(1)
      wow.fire("GROUP_ROSTER_UPDATE")
      assert.same({}, wow.sent)
      wow.advance(1)
      assert.same({ "HI", "PR" }, mock.sent(wow))
    end)

    it("greets the party it finds at login", function()
      mock.party(wow, "mira")
      boot()
      assert.same({ "HI", "PR" }, mock.sent(wow))
    end)

    it("never answers a greeting, so nothing loops", function()
      boot()
      mock.join(wow, "mira")
      wow.sent = {}
      mock.hi(wow, "mira")
      mock.pr(wow, "mira", 5, 5, 5)
      wow.advance(60)
      mock.hi(wow, "mira")
      wow.advance(60)
      assert.same({}, wow.sent)
    end)

    it("waits out the 30 s window for a member who joins inside it, then greets", function()
      boot()
      mock.join(wow, "mira")
      local first = wow.state.epoch
      wow.advance(10)
      mock.join(wow, "mira", "thalen")
      assert.equal(2, #wow.sent)
      assert.is_nil(greeted()[THALEN])
      wow.advance(first + 29 - wow.state.epoch)
      assert.equal(2, #wow.sent)
      wow.advance(1)
      assert.same({ "HI", "PR", "HI", "PR" }, mock.sent(wow))
      assert.same({ [MIRA] = first + 30, [THALEN] = first + 30 }, greeted())
    end)

    it("greets a member again who left and rejoined", function()
      boot()
      mock.join(wow, "mira", "thalen")
      wow.advance(30)
      mock.join(wow, "thalen")
      assert.is_nil(greeted()[MIRA])
      assert.equal(2, #wow.sent)
      wow.advance(30)
      mock.join(wow, "thalen", "mira")
      assert.same({ "HI", "PR", "HI", "PR" }, mock.sent(wow))
      assert.is_number(greeted()[MIRA])
    end)

    it("clears greeted when the group ends", function()
      boot()
      mock.join(wow, "mira")
      assert.is_number(greeted()[MIRA])
      mock.leave(wow)
      assert.same({}, greeted())
      wow.advance(30)
      mock.join(wow, "mira")
      assert.same({ "HI", "PR", "HI", "PR" }, mock.sent(wow))
    end)

    it("does not greet again after a /reload, and keeps the window across it", function()
      boot()
      mock.join(wow, "mira")
      local first = wow.state.epoch
      wow.advance(5)
      ns = wow.reload()
      assert.same({}, wow.sent)
      mock.roster(wow)
      assert.same({}, wow.sent)
      assert.is_number(greeted()[MIRA])
      mock.join(wow, "mira", "thalen")
      assert.same({}, wow.sent)
      wow.advance(first + 30 - wow.state.epoch)
      assert.same({ "HI", "PR" }, mock.sent(wow))
    end)

    it("only listens on an account that cannot send", function()
      wow.state.trial = true
      boot()
      mock.join(wow, "mira")
      assert.same({}, wow.sent)
      assert.same({}, greeted())
      mock.hi(wow, "mira")
      assert.is_table(ns.Fiction:Peer(MIRA))
    end)

    it("sends nothing with sharing off and greets once it is back on", function()
      boot()
      ns.Settings:Set("Comm.share", false)
      mock.join(wow, "mira")
      assert.same({}, wow.sent)
      assert.same({}, greeted())
      ns.Settings:Set("Comm.share", true)
      mock.roster(wow)
      assert.same({ "HI", "PR" }, mock.sent(wow))
    end)

    it("sends Profile's numbers and falls back to a pragmatist from nowhere without Profile", function()
      boot({ setup = function(n) n.Profile = nil end })
      mock.join(wow, "mira")
      assert.same({ "1|HI|" .. ME .. "|PRAGMATIST|0|Normal|1.0.0-test", "1|PR|" .. ME .. "|0|0|0" }, texts())
    end)

    it("carries the ruleset and a version stripped to the wire's characters", function()
      wow.state.rules[Enum.GameRule.RPRuleset] = true
      wow.data.metadata.Version = "v1.2.0 (build 12345678901234)"
      boot()
      mock.join(wow, "mira")
      assert.equal("1|HI|" .. ME .. "|OATHKEEPER|1443|RP|v1.2.0build123456789", wow.sent[1].text)
    end)

    it("names an unset version dev", function()
      wow.data.metadata.Version = nil
      boot()
      mock.join(wow, "mira")
      assert.equal("1|HI|" .. ME .. "|OATHKEEPER|1443|Normal|dev", wow.sent[1].text)
    end)

    it("skips members whose identity is secret", function()
      boot()
      mock.party(wow, "mira")
      wow.state.units.party1.guid = wow.secret(MIRA)
      mock.roster(wow)
      assert.same({}, wow.sent)
    end)
  end)

  describe("receiving", function()
    local seen

    local function start(opts)
      local char = boot(opts)
      seen = mock.listen(ns, { "PEER_SEEN" }, {})
      mock.join(wow, "mira")
      return char
    end

    it("stores a peer from HI with this character in seenBy, writes the peer entry and fires PEER_SEEN", function()
      local char = start()
      local t = wow.state.epoch
      mock.hi(wow, "mira", "WANDERER", 1429, "RP", "1.2.0")
      local peer = ns.Fiction:Peer(MIRA)
      assert.same({ guid = MIRA, archetype = "WANDERER", origin = 1429, ruleset = "RP", version = "1.2.0",
                    first = t, last = t, seenBy = { [char.guid] = "WANDERER" }, logged = { [char.guid] = t } }, peer)
      assert.equal(peer, _G.AshmarkDB.peers[MIRA])
      local entries = mock.entries(ns, "peer")
      assert.equal(1, #entries)
      assert.same({ MIRA, "WANDERER" }, { entries[1].p, entries[1].a })
      assert.same({ { "PEER_SEEN", MIRA, peer, true } }, seen)
    end)

    it("updates a known peer without a new entry while the archetype stays", function()
      start()
      local t = wow.state.epoch
      mock.hi(wow, "mira", "WANDERER", 1429)
      wow.advance(600)
      mock.hi(wow, "mira", "WANDERER", 1411, "RP", "1.3.0")
      local peer = ns.Fiction:Peer(MIRA)
      assert.same({ t, t + 600, 1411, "1.3.0" }, { peer.first, peer.last, peer.origin, peer.version })
      assert.equal(1, #mock.entries(ns, "peer"))
      assert.same({ "PEER_SEEN", MIRA, peer, false }, seen[2])
    end)

    it("writes another entry when the archetype changes a day after the last one", function()
      local char = start()
      mock.hi(wow, "mira", "WANDERER")
      wow.advance(DAY)
      mock.hi(wow, "mira", "RUTHLESS")
      local entries = mock.entries(ns, "peer")
      assert.same({ "WANDERER", "RUTHLESS" }, { entries[1].a, entries[2].a })
      assert.same({ [char.guid] = "RUTHLESS" }, ns.Fiction:Peer(MIRA).seenBy)
      assert.same({ [char.guid] = wow.state.epoch }, ns.Fiction:Peer(MIRA).logged)
    end)

    it("writes at most one archetype change a day, so a peer flipping archetypes cannot flood the log", function()
      local char = start()
      -- Comm's receive budget (5.6) would stop this flood first; widen it to test Fiction's own limit.
      for _, budget in pairs(ns.Comm.RECEIVE) do budget.burst, budget.every = 1000, 0.001 end
      local t = wow.state.epoch
      mock.hi(wow, "mira", "WANDERER")
      for i = 1, 200 do
        mock.hi(wow, "mira", i % 2 == 1 and "RUTHLESS" or "GENTLE")
        wow.advance(5)
      end
      local peer = ns.Fiction:Peer(MIRA)
      assert.equal(1, #mock.entries(ns, "peer"))
      assert.equal("GENTLE", peer.archetype)
      assert.same({ [char.guid] = "WANDERER" }, peer.seenBy)
      assert.equal(201, #seen)
      -- The change held back is written by the first HI after the day that still carries one.
      wow.advance(t + DAY - 1 - wow.state.epoch)
      mock.hi(wow, "mira", "RUTHLESS")
      assert.equal(1, #mock.entries(ns, "peer"))
      wow.advance(1)
      mock.hi(wow, "mira", "WANDERER")
      assert.equal(1, #mock.entries(ns, "peer"))
      mock.hi(wow, "mira", "RUTHLESS")
      mock.hi(wow, "mira", "GENTLE")
      local entries = mock.entries(ns, "peer")
      assert.same({ "WANDERER", "RUTHLESS" }, { entries[1].a, entries[2].a })
      assert.same({ [char.guid] = "RUTHLESS" }, ns.Fiction:Peer(MIRA).seenBy)
    end)

    it("writes the first change of a peer stored before changes were limited", function()
      wow.saved({ schema = 1, peers = {
        [MIRA] = { guid = MIRA, archetype = "WANDERER", origin = 1429, ruleset = "RP", version = "1.0.0",
                   first = 100, last = 200, seenBy = { [mock.ME] = "WANDERER" } },
      } })
      start()
      mock.hi(wow, "mira", "RUTHLESS")
      assert.same({ "RUTHLESS" }, { mock.entries(ns, "peer")[1].a })
    end)

    it("writes the first sight of every character on the account and keeps the others in seenBy", function()
      wow.saved({ schema = 1, peers = {
        [MIRA] = { guid = MIRA, archetype = "WANDERER", origin = 1429, ruleset = "RP", version = "1.0.0",
                   first = 100, last = 200, seenBy = { [ALT] = "WANDERER" } },
      } })
      local char = start()
      mock.hi(wow, "mira", "WANDERER")
      local peer = ns.Fiction:Peer(MIRA)
      assert.same({ [ALT] = "WANDERER", [char.guid] = "WANDERER" }, peer.seenBy)
      assert.equal(100, peer.first)
      assert.equal(1, #mock.entries(ns, "peer"))
      assert.is_false(seen[1][4])
    end)

    it("takes the profile from PR after HI and drops a PR that comes first", function()
      start()
      mock.pr(wow, "mira", 50, -20, 10)
      assert.is_nil(ns.Fiction:Peer(MIRA))
      assert.same({}, seen)
      mock.hi(wow, "mira")
      mock.pr(wow, "mira", 50, -20, 10)
      assert.same({ fidelity = 50, habitat = -20, mercy = 10 }, ns.Fiction:Peer(MIRA).profile)
      mock.hi(wow, "mira")
      assert.same({ fidelity = 50, habitat = -20, mercy = 10 }, ns.Fiction:Peer(MIRA).profile)
    end)

    it("ignores a GUID that belongs to no party member and the player's own echo", function()
      start()
      mock.receive(wow, "mira", "1|HI|" .. THALEN .. "|WANDERER|1429|RP|1.0.0")
      mock.receive(wow, "mira", HI)
      assert.same({}, _G.AshmarkDB.peers)
      assert.same({}, seen)
    end)

    it("keeps at most 500 peers and drops the oldest", function()
      local peers = {}
      for i = 1, 500 do
        local guid = string.format("Player-1-%08x", 0x1000 + i)
        peers[guid] = { guid = guid, archetype = "PRAGMATIST", origin = 0, ruleset = "Normal", version = "1",
                        first = i, last = 1000 + i, seenBy = {} }
      end
      wow.saved({ schema = 1, peers = peers })
      start()
      mock.hi(wow, "mira")
      local n = 0
      for _ in pairs(_G.AshmarkDB.peers) do n = n + 1 end
      assert.equal(500, n)
      assert.is_nil(_G.AshmarkDB.peers[string.format("Player-1-%08x", 0x1001)])
      assert.is_table(_G.AshmarkDB.peers[string.format("Player-1-%08x", 0x1002)])
      assert.is_table(ns.Fiction:Peer(MIRA))
    end)

    it("stops listening while the module is off", function()
      start()
      ns.Settings:Set("Fiction.enabled", false)
      mock.hi(wow, "mira")
      assert.is_nil(ns.Fiction:Peer(MIRA))
    end)
  end)

  describe("public services", function()
    it("return the stored peer, and only the peers in the party as present", function()
      wow.saved({ schema = 1, peers = { [THALEN] = { guid = THALEN, archetype = "GENTLE", seenBy = {} } } })
      boot()
      mock.join(wow, "mira")
      mock.hi(wow, "mira")
      local present = ns.Fiction:PresentPeers()
      assert.same({ [MIRA] = ns.Fiction:Peer(MIRA) }, present)
      assert.equal("GENTLE", ns.Fiction:Peer(THALEN).archetype)
      assert.is_nil(ns.Fiction:Peer("Player-1-000000ff"))
      assert.is_nil(ns.Fiction:Peer(nil))
    end)

    it("answer while the module is unavailable", function()
      wow.stub("C_ChatInfo.SendAddonMessage", nil)
      wow.saved({ schema = 1, peers = { [MIRA] = { guid = MIRA, archetype = "GENTLE", seenBy = {} } } })
      boot()
      mock.party(wow, "mira")
      assert.equal("GENTLE", ns.Fiction:Peer(MIRA).archetype)
      assert.equal("GENTLE", ns.Fiction:PresentPeers()[MIRA].archetype)
    end)
  end)

  describe("test check", function()
    it("is skipped with a hint until a peer is known, then counts peers", function()
      boot()
      local ok, detail = mock.check(ns, "Fiction.peers")
      assert.is_nil(ok)
      assert.matches("Group with another Ashmark user", detail, 1, true)
      mock.join(wow, "mira")
      mock.hi(wow, "mira")
      ok, detail = mock.check(ns, "Fiction.peers")
      assert.is_true(ok)
      assert.matches("peers 1 (met by this character 1), present 1, greeted 1, send and receive", detail, 1, true)
    end)

    it("reports a receive-only client", function()
      wow.state.trial = true
      boot()
      local _, detail = mock.check(ns, "Fiction.peers")
      assert.matches("receive only", detail, 1, true)
    end)
  end)
end)

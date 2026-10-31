local wow = require("tests.helpers.wow")

local ME = "Player-1-00000001"
local MIRA = "Player-1-00000002"
local THALEN = "Player-1-00000003"
local KEL = "Player-1-00000004"
local HI = { MIRA, "OATHKEEPER", 1443, "RP", "1.0.0" }
local RU = { "deadbeef", "ALLIANCE", 0, 100, 0, "OATHKEEPER", 92, 1443 }

describe("Core Comm", function()
  local ns, Comm, got

  local function boot()
    ns = wow.load()
    Comm = ns.Comm
    wow.login()
    got = {}
    for _, kind in ipairs({ "HI", "PR", "RU" }) do
      Comm:Register(kind, function(from, fields, channel) got[#got + 1] = { kind, from, fields, channel } end)
    end
    return ns
  end

  local function group()
    wow.unit("party1", { guid = MIRA, name = "Mira" })
  end

  local function receive(text, sender, channel, prefix)
    wow.fire("CHAT_MSG_ADDON", prefix or "Ashmark", text, channel or "PARTY", sender or "Mira-Forever")
  end

  local function hi(guid, sender)
    receive("1|HI|" .. guid .. "|OATHKEEPER|1443|RP|1.0.0", sender)
  end

  local function ru(sender)
    receive("1|RU|deadbeef|ALLIANCE|0|100|0|OATHKEEPER|92|1443", sender)
  end

  before_each(function()
    wow.reset()
  end)

  describe("encoding", function()
    before_each(function()
      group()
      boot()
    end)

    it("registers the prefix and writes the wire format", function()
      assert.is_true(wow.prefixes.Ashmark)
      assert.equal("1|HI|Player-1-00000002|OATHKEEPER|1443|RP|1.0.0", Comm:Encode("HI", HI))
      assert.equal("1|PR|Player-1-00000002|-100|0|100", Comm:Encode("PR", { MIRA, -100, 0, 100 }))
    end)

    it("refuses characters outside the field whitelist and values outside the rules", function()
      local bad = {
        { "HI", { MIRA, "OATHKEEPER", 1443, "RP", "1.0|x" } },
        { "HI", { MIRA, "OATHKEEPER", 1443, "RP", "1.0 x" } },
        { "HI", { MIRA, "Oathkeeper", 1443, "RP", "1.0" } },
        { "HI", { "Thalen", "OATHKEEPER", 1443, "RP", "1.0" } },
        { "HI", { MIRA, "OATHKEEPER", 1443, "Roleplay", "1.0" } },
        { "HI", { MIRA, "OATHKEEPER", 1000000, "RP", "1.0" } },
        { "HI", { MIRA, "OATHKEEPER", 1443, "RP", string.rep("1", 21) } },
        { "HI", { MIRA, "OATHKEEPER", 1443, "RP" } },
        { "PR", { MIRA, 101, 0, 0 } },
        { "PR", { MIRA, 1.5, 0, 0 } },
        { "RU", { "DEADBEEF", "ALLIANCE", 0, 100, 0, "OATHKEEPER", 92, 1443 } },
        { "RU", { "deadbeef", "FEUD", 0, 100, 0, "OATHKEEPER", 92, 1443 } },
        { "RU", { "deadbeef", "ALLIANCE", 10, 100, 0, "OATHKEEPER", 92, 1443 } },
        { "RU", { "deadbeef", "ALLIANCE", 0, 100, 2161, "OATHKEEPER", 92, 1443 } },
        { "XX", { "a" } },
      }
      for _, case in ipairs(bad) do
        assert.same({ false, "invalid" }, { Comm:Send(case[1], case[2], "PARTY") })
      end
      assert.same({ false, "invalid" }, { Comm:Send("HI", { wow.secret(MIRA), "OATHKEEPER", 1, "RP", "1" }, "PARTY") })
      assert.same({}, wow.sent)
    end)

    it("refuses messages over 255 bytes and never chunks", function()
      local guid = "Player-1-" .. string.rep("a", 240)
      assert.same({ false, "tooLong" }, { Comm:Send("HI", { guid, "OATHKEEPER", 1, "RP", "1" }, "PARTY") })
      assert.same({}, wow.sent)
    end)

    it("sends only on PARTY", function()
      for _, channel in ipairs({ "RAID", "GUILD", "WHISPER", "CHANNEL" }) do
        assert.same({ false, "invalid" }, { Comm:Send("HI", HI, channel) })
      end
    end)
  end)

  describe("sending", function()
    it("refuses when sharing is off, the account cannot send, or nobody is grouped", function()
      boot()
      assert.same({ false, "notGrouped" }, { Comm:Send("HI", HI, "PARTY") })
      group()
      ns.Settings:Set("Comm.share", false)
      assert.same({ false, "share" }, { Comm:Send("HI", HI, "PARTY") })
      wow.reset()
      wow.state.trial = true
      group()
      boot()
      assert.same({ false, "cannotSend" }, { Comm:Send("HI", HI, "PARTY") })
    end)

    it("throttles with a bucket of 6 refilled one per 1.5 s", function()
      group()
      boot()
      for _ = 1, 10 do assert.is_true(Comm:Send("RU", RU, "PARTY")) end
      assert.equal(6, #wow.sent)
      assert.equal(4, Comm:Queued())
      wow.advance(1.5)
      assert.equal(7, #wow.sent)
      wow.advance(1.5)
      assert.equal(8, #wow.sent)
      wow.advance(10)
      assert.equal(10, #wow.sent)
      assert.equal(10, Comm.stats.sent)
      assert.same({ prefix = "Ashmark", channel = "PARTY", text = Comm:Encode("RU", RU), result = 0 }, wow.sent[1])
    end)

    it("sends by priority, then age", function()
      group()
      boot()
      for _ = 1, 6 do Comm:Send("RU", RU, "PARTY") end
      Comm:Send("RU", { "00000001", "BROKE", 0, 100, 0, "OATHKEEPER", 92, 1443 }, "PARTY")
      Comm:Send("PR", { MIRA, 1, 2, 3 }, "PARTY")
      Comm:Send("HI", HI, "PARTY")
      Comm:Send("RU", { "00000002", "BROKE", 0, 100, 0, "OATHKEEPER", 92, 1443 }, "PARTY", nil, 1)
      wow.advance(6)
      local kinds = {}
      for i = 7, #wow.sent do kinds[#kinds + 1] = wow.sent[i].text:match("^1|(%u+)|([^|]+)") end
      assert.same({ "PR", "HI", "RU", "RU" }, kinds)
      assert.truthy(wow.sent[9].text:find("00000002", 1, true))
      assert.truthy(wow.sent[10].text:find("00000001", 1, true))
    end)

    it("holds at most 30 and drops the oldest of the lowest priority", function()
      group()
      boot()
      wow.state.chatLockdown = true
      Comm:Send("HI", HI, "PARTY")
      for i = 1, 30 do
        Comm:Send("RU", { string.format("%08x", i), "BROKE", 0, 100, 0, "OATHKEEPER", 92, 1443 }, "PARTY")
      end
      assert.equal(30, Comm:Queued())
      assert.equal(1, Comm.stats.dropped)
      wow.state.chatLockdown = false
      wow.advance(60)
      assert.truthy(wow.sent[1].text:find("^1|HI|"))
      assert.truthy(wow.sent[2].text:find("00000002", 1, true))
    end)

    it("pauses during a chat lockdown and while not grouped", function()
      group()
      boot()
      wow.state.chatLockdown = true
      Comm:Send("HI", HI, "PARTY")
      wow.advance(5)
      assert.same({}, wow.sent)
      wow.state.chatLockdown = false
      wow.unit("party1", nil)
      wow.advance(5)
      assert.same({}, wow.sent)
      group()
      wow.advance(0.5)
      assert.equal(1, #wow.sent)
    end)

    it("requeues a throttled message at the front and pauses 5 s", function()
      group()
      boot()
      wow.state.sendResult = 3
      Comm:Send("HI", HI, "PARTY")
      assert.equal(1, Comm:Queued())
      wow.state.sendResult = 0
      wow.advance(4.5)
      assert.equal(1, #wow.sent)
      wow.advance(1)
      assert.equal(2, #wow.sent)
      assert.equal(0, Comm:Queued())
      assert.same({ [3] = 1, [0] = 1 }, Comm.stats.results)
    end)

    it("pauses after a lockdown result until the next zone change or loading screen", function()
      group()
      boot()
      wow.state.sendResult = 11
      Comm:Send("HI", HI, "PARTY")
      wow.state.sendResult = true
      wow.advance(60)
      assert.equal(1, #wow.sent)
      wow.fire("ZONE_CHANGED_NEW_AREA")
      assert.equal(2, #wow.sent)
      assert.equal(1, Comm.stats.results[0])
    end)

    it("drops the queue when the client says the player is not in a group", function()
      group()
      boot()
      wow.state.chatLockdown = true
      for _ = 1, 3 do Comm:Send("RU", RU, "PARTY") end
      wow.state.chatLockdown = false
      wow.state.sendResult = 5
      wow.advance(1)
      assert.equal(1, #wow.sent)
      assert.equal(0, Comm:Queued())
      assert.equal(3, Comm.stats.dropped)
    end)

    it("disables sending for the session after three consecutive unknown results", function()
      group()
      boot()
      wow.state.sendResult = 9
      Comm:Send("HI", HI, "PARTY")
      Comm:Send("HI", HI, "PARTY")
      wow.state.sendResult = 0
      Comm:Send("HI", HI, "PARTY")
      wow.state.sendResult = 2
      for _ = 1, 3 do Comm:Send("HI", HI, "PARTY") end
      assert.is_false(ns.Compat.Has.canSend)
      assert.equal("SendAddonMessage result 2", ns.Compat.disabled.canSend)
      assert.same({ false, "cannotSend" }, { Comm:Send("HI", HI, "PARTY") })
      ns.Compat.Refresh(true)
      assert.is_false(ns.Compat.Has.canSend)
    end)
  end)

  describe("receiving", function()
    before_each(function()
      group()
      boot()
    end)

    it("accepts HI from a party member with that GUID and decodes integers", function()
      hi(MIRA)
      assert.equal(1, #got)
      local kind, from, fields, channel = unpack(got[1])
      assert.equal("HI", kind)
      assert.same({ sender = "Mira-Forever", guid = MIRA, unit = "party1" }, from)
      assert.same({ MIRA, "OATHKEEPER", 1443, "RP", "1.0.0" }, fields)
      assert.equal("PARTY", channel)
      assert.equal(MIRA, ns.DB:Char().state.senders["Mira-Forever"])
    end)

    it("drops HI and PR whose GUID is not in party1..4", function()
      hi("Player-1-00000099")
      receive("1|PR|Player-1-00000099|1|2|3")
      assert.same({}, got)
    end)

    it("drops other prefixes, channels, secrets, long texts and bad schemas", function()
      receive("1|HI|" .. MIRA .. "|OATHKEEPER|1443|RP|1.0.0", nil, nil, "Other")
      receive("1|HI|" .. MIRA .. "|OATHKEEPER|1443|RP|1.0.0", nil, "RAID")
      receive(wow.secret("1|HI|x"))
      receive("1|HI|" .. MIRA .. "|OATHKEEPER|1443|RP|1.0.0", wow.secret("Mira"))
      wow.fire("CHAT_MSG_ADDON", wow.secret("Ashmark"), "x", "PARTY", "Mira")
      receive("1|HI|" .. MIRA .. "|OATHKEEPER|1443|RP|" .. string.rep("1", 250))
      assert.equal(0, Comm.stats.rejected)
      receive("2|HI|" .. MIRA .. "|OATHKEEPER|1443|RP|1.0.0")
      receive("1|HI|" .. MIRA .. "|OATHKEEPER|1443|RP")
      receive("1|HI|" .. MIRA .. "|OATHKEEPER|1443|RP|1.0.0|extra")
      receive("1|PR|" .. MIRA .. "|1|2|101")
      receive("1|ZZ|a")
      assert.same({}, got)
      assert.equal(5, Comm.stats.rejected)
    end)

    it("accepts RU only from a sender validated by HI", function()
      ru()
      assert.same({}, got)
      hi(MIRA)
      ru()
      assert.equal("RU", got[2][1])
      assert.same({ sender = "Mira-Forever", guid = MIRA, unit = "party1" }, got[2][2])
      assert.same({ "deadbeef", "ALLIANCE", 0, 100, 0, "OATHKEEPER", 92, 1443 }, got[2][3])
    end)

    it("learns its own sender name from its own HI and drops its echoes", function()
      hi(ME, "Aren-Forever")
      assert.equal("Aren-Forever", ns.DB:Char().state.selfSender)
      receive("1|PR|" .. ME .. "|1|2|3", "Aren-Forever")
      ru("Aren-Forever")
      assert.same({}, got)
    end)

    it("drops beyond 20 messages per sender per minute", function()
      for _, budget in pairs(Comm.RECEIVE) do budget.burst, budget.every = 100, 0.01 end
      for _ = 1, 25 do hi(MIRA) end
      assert.equal(20, #got)
      wow.advance(60)
      hi(MIRA)
      assert.equal(21, #got)
    end)

    it("takes HI and PR at the greeting's pace: 3 at once, then 1 per 30 s, per sender and type", function()
      for _ = 1, 5 do hi(MIRA) end
      for _ = 1, 5 do receive("1|PR|" .. MIRA .. "|1|2|3") end
      assert.equal(6, #got)
      assert.equal(4, Comm.stats.limited)
      wow.advance(29)
      hi(MIRA)
      assert.equal(6, #got)
      wow.advance(2)
      hi(MIRA)
      hi(MIRA)
      assert.equal(7, #got)
      assert.equal("HI", got[7][1])
      hi(THALEN, "Thalen-Forever")
      assert.is_nil(got[8])
      wow.unit("party2", { guid = THALEN, name = "Thalen" })
      hi(THALEN, "Thalen-Forever")
      assert.equal(THALEN, got[8][2].guid)
      wow.advance(3600)
      for _ = 1, 5 do hi(MIRA) end
      assert.equal(11, #got)
    end)

    it("takes RU at the rumour rounds' pace: 10 at once, then 1 per 40 s", function()
      hi(MIRA)
      for _ = 1, 12 do ru() end
      assert.equal(11, #got)
      wow.advance(29)
      ru()
      assert.equal(11, #got)
      wow.advance(12)
      ru()
      assert.equal(12, #got)
      assert.equal("RU", got[12][1])
      assert.equal(3, Comm.stats.limited)
    end)

    it("delivers to a handler's owner only while it is enabled", function()
      local M = ns:NewModule("Alpha", { locale = "ALPHA" })
      local calls = 0
      Comm:Register("HI", function() calls = calls + 1 end, M)
      hi(MIRA)
      M.enabled = true
      hi(MIRA)
      assert.equal(1, calls)
    end)

    it("reports a failing handler and keeps receiving", function()
      Comm:Register("HI", function() error("boom") end)
      assert.has_no.errors(function() hi(MIRA) end)
      assert.equal(1, #wow.errors)
    end)
  end)

  describe("binding a GUID to its sender", function()
    local function party(units)
      for i, u in ipairs(units) do wow.unit("party" .. i, u) end
    end

    it("drops HI and PR whose sender's name belongs to another party member", function()
      party({ { guid = MIRA, name = "Mira" }, { guid = THALEN, name = "Thalen" } })
      boot()
      hi(THALEN, "Mira-Forever")
      receive("1|PR|" .. THALEN .. "|-100|0|0", "Mira-Forever")
      assert.same({}, got)
      assert.same({}, ns.DB:Char().state.senders)
      hi(THALEN, "Thalen-Forever")
      hi(MIRA, "Mira-Forever")
      assert.equal(2, #got)
      assert.same({ ["Thalen-Forever"] = THALEN, ["Mira-Forever"] = MIRA }, ns.DB:Char().state.senders)
    end)

    it("keeps the first sender of a GUID when names do not resolve, and one GUID per sender", function()
      party({ { guid = MIRA, name = "Mira" }, { guid = THALEN, name = "Thalen" }, { guid = KEL, name = "Kel" } })
      boot()
      hi(THALEN, "Thalen-Vell")
      hi(THALEN, "Mira-Vell")
      hi(MIRA, "Mira-Vell")
      hi(KEL, "Mira-Vell")
      receive("1|PR|" .. THALEN .. "|-100|0|0", "Mira-Vell")
      assert.same({ "HI", "HI" }, { got[1][1], got[2][1] })
      assert.equal(2, #got)
      assert.equal(THALEN, got[1][2].guid)
      assert.same({ sender = "Mira-Vell", guid = MIRA, unit = "party1" }, got[2][2])
      assert.same({ ["Thalen-Vell"] = THALEN, ["Mira-Vell"] = MIRA }, ns.DB:Char().state.senders)
    end)

    it("hands a GUID to the sender whose name resolves to it", function()
      party({ { guid = MIRA, name = "Mira" }, { guid = THALEN, name = "Thalen" } })
      boot()
      hi(THALEN, "Someone-Vell")
      ru("Someone-Vell")
      assert.equal(2, #got)
      hi(THALEN, "Thalen-Forever")
      assert.equal(3, #got)
      assert.same({ ["Thalen-Forever"] = THALEN }, ns.DB:Char().state.senders)
      ru("Someone-Vell")
      hi(THALEN, "Someone-Vell")
      assert.equal(3, #got)
    end)
  end)

  describe("the queue after the moment it was meant for", function()
    local checks

    local function count()
      checks = 0
      wow.stub("C_ChatInfo.InChatMessagingLockdown", function()
        checks = checks + 1
        return wow.state.chatLockdown
      end)
    end

    it("is dropped once sharing is switched off", function()
      group()
      boot()
      wow.state.chatLockdown = true
      Comm:Send("HI", HI, "PARTY")
      Comm:Send("RU", RU, "PARTY")
      ns.Settings:Set("Comm.share", false)
      wow.state.chatLockdown = false
      wow.advance(5)
      assert.same({}, wow.sent)
      assert.equal(0, Comm:Queued())
      assert.equal(2, Comm.stats.dropped)
    end)

    it("is dropped once the client cannot send", function()
      group()
      boot()
      wow.state.chatLockdown = true
      Comm:Send("HI", HI, "PARTY")
      ns.Compat.Disable("canSend", "test")
      wow.state.chatLockdown = false
      wow.advance(5)
      assert.same({}, wow.sent)
      assert.equal(0, Comm:Queued())
    end)

    it("drops a type's messages once the module that registered it is off, and keeps the others", function()
      group()
      boot()
      local rumours = { enabled = true }
      Comm:Register("RU", function() end, rumours)
      wow.state.chatLockdown = true
      Comm:Send("HI", HI, "PARTY")
      Comm:Send("RU", RU, "PARTY")
      rumours.enabled = false
      wow.state.chatLockdown = false
      wow.advance(5)
      assert.equal(1, #wow.sent)
      assert.matches("^1|HI|", wow.sent[1].text)
      assert.equal(0, Comm:Queued())
      assert.equal(1, Comm.stats.dropped)
    end)

    it("is dropped when the group ends, and its ticker stops", function()
      group()
      boot()
      count()
      wow.state.chatLockdown = true
      Comm:Send("HI", HI, "PARTY")
      Comm:Send("RU", RU, "PARTY")
      wow.unit("party1", nil)
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(2)
      assert.equal(0, Comm:Queued())
      assert.equal(2, Comm.stats.dropped)
      checks = 0
      wow.advance(600)
      assert.equal(0, checks)
      wow.state.chatLockdown = false
      wow.unit("party1", { guid = THALEN, name = "Thalen" })
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(2)
      assert.same({}, wow.sent)
    end)
  end)

  describe("the sender map", function()
    it("keeps accepting RU after a /reload from a sender learned before it", function()
      group()
      boot()
      hi(MIRA)
      ns = wow.reload()
      Comm = ns.Comm
      got = {}
      Comm:Register("RU", function(from) got[#got + 1] = from end)
      ru()
      assert.same({ { sender = "Mira-Forever", guid = MIRA, unit = "party1" } }, got)
    end)

    it("is cleared on GROUP_CHANGED(false) and relearned from the HI of a member who rejoins", function()
      group()
      boot()
      hi(MIRA, "Mira-Forever")
      hi(ME, "Aren-Forever")
      wow.unit("party1", nil)
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(1)
      assert.same({}, ns.DB:Char().state.senders)
      assert.equal("Aren-Forever", ns.DB:Char().state.selfSender)
      group()
      wow.fire("GROUP_ROSTER_UPDATE")
      wow.advance(1)
      got = {}
      ru()
      assert.same({}, got)
      hi(MIRA)
      ru()
      assert.equal(2, #got)
    end)

    it("holds at most 40 senders, dropping those no longer grouped first", function()
      group()
      boot()
      local senders = ns.DB:Char().state.senders
      for i = 1, 40 do senders["Old" .. i] = string.format("Player-1-%08X", 100 + i) end
      hi(MIRA, "Mira-Forever")
      local n = 0
      for _ in pairs(senders) do n = n + 1 end
      assert.equal(1, n)
      assert.equal(MIRA, senders["Mira-Forever"])
    end)
  end)
end)

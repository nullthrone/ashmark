local wow = require("tests.helpers.wow")

local function printed(text)
  for _, line in ipairs(wow.chat) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

local function probes()
  return _G.AshmarkDB.dev.probes
end

local function fact(record, call)
  for _, f in ipairs(record.facts) do
    if f.call == call then return f end
  end
end

local function calls(record, prefix)
  local out = {}
  for _, f in ipairs(record.facts) do
    if f.call:sub(1, #prefix) == prefix then out[#out + 1] = f.call end
  end
  return out
end

local function probe()
  SlashCmdList.ASHMARK("probe")
  return probes()[#probes()]
end

local SAVED = { schema = 1, created = 7 }

describe("Dev probe", function()
  local ns
  before_each(function()
    wow.reset()
  end)

  local function start(db, setup)
    wow.saved(wow.deepcopy(db or SAVED))
    ns = wow.load({ "Dev" })
    if setup then setup() end
    wow.login()
  end

  it("appends a record with the context", function()
    start(SAVED, function() wow.state.map = 1443 end)
    local record = probe()
    assert.equal(1, #probes())
    assert.equal(time(), record.t)
    assert.same({ map = 1443, zone = 1443, party = false, raid = false, combat = false }, record.context)
    assert.is_true(printed(ns.Format(ns.L.TEST_PROBE_DONE, { count = #record.facts })))
    assert.is_true(printed(ns.L.TEST_PROBE_NEXT))
    assert.is_true(printed(ns.L.TEST_RELOAD))
  end)

  it("records the context inside an instance and in combat", function()
    start(SAVED, function()
      wow.state.instance = { instanceID = 389 }
      wow.unit("party1", { guid = "Player-1-00000002", name = "Mira" })
    end)
    wow.combat(true)
    local record = probe()
    assert.same({ instance = 389, party = true, raid = false, combat = true }, record.context)
  end)

  it("captures every return as a string", function()
    start()
    local record = probe()
    assert.same({ call = "GetBuildInfo()", ok = true, r = { "1.60.1", "70532", "Oct 20 2026", "16001" } },
      fact(record, "GetBuildInfo()"))
    assert.same({ call = "WOW_PROJECT_ID", ok = true, r = { "18" } }, fact(record, "WOW_PROJECT_ID"))
    assert.same({ "Forever" }, fact(record, 'C_AddOns.GetAddOnMetadata("Ashmark", "X-TocVariant")').r)
    assert.same({ "Aren", "Ashvale" }, fact(record, 'UnitName("player")').r)
    assert.same({ "Player-1-00000001" }, fact(record, 'UnitGUID("player")').r)
    assert.same({ "false" }, fact(record, 'C_Secrets.ShouldUnitIdentityBeSecret("party1")').r)
    assert.same({ "<nil>" }, fact(record, 'C_Map.GetBestMapForUnit("player")').r)
    assert.same({}, fact(record, 'UnitCreatureType("target")').r)
    assert.same({ "<nil>" }, fact(record, "C_CreatureInfo.GetRaceInfo(<target race>)").r)
    wow.unit("target", { guid = "Creature-0-1", name = "Boar", creatureType = "Beast", creatureTypeID = 1 })
    assert.same({ "Beast", "1" }, fact(probe(), 'UnitCreatureType("target")').r)
    wow.unit("target", { guid = "Player-1-9", name = "Bryn", raceID = 3, raceFile = "Dwarf", raceName = "Zwergin",
                         sex = 3, isPlayer = true })
    local race = probe()
    assert.same({ "Zwergin", "Dwarf", "3" }, fact(race, 'UnitRace("target")').r)
    assert.same({ "3" }, fact(race, 'UnitSex("target")').r)
    assert.truthy(fact(race, "C_CreatureInfo.GetRaceInfo(<target race>)").r[1]:find("raceName=Dwarf", 1, true))
    record = probes()[1]
    assert.same({ "{name=Critter}" }, fact(record, "C_CreatureInfo.GetCreatureTypeInfo(8)").r)
    local faction = fact(record, "C_Reputation.GetFactionDataByID(92)").r[1]
    assert.truthy(faction:find("name=Gelkis Clan Centaur", 1, true))
    assert.truthy(faction:find("reaction=4", 1, true))
    assert.same({ "<nil>" }, fact(record, "C_Reputation.GetFactionDataByID(2802)").r)
    assert.same({ "{factionID=2802, name=Legacy, renownLevel=1}" },
      fact(record, "C_MajorFactions.GetMajorFactionData(2802)").r)
    assert.same({ "1" }, fact(record, "C_GameRules.GetForeverExperiencePreset()").r)
  end)

  it("marks secrets, missing functions and errors", function()
    start(SAVED, function()
      wow.stub("C_PlayerInfo.ShouldDisplaySurname", function() return nil, wow.secret(true) end)
      wow.stub("C_Secrets.ShouldAurasBeSecret", function() error("not allowed here") end)
      wow.unit("party1", { guid = "Player-1-00000002", name = wow.secret("Mira") })
      wow.state.map = wow.secret(1443)
      wow.stub("C_CombatLog", { IsCombatLogRestricted = function() return true end })
    end)
    local record = probe()
    assert.same({ call = "C_PlayerInfo.ShouldDisplaySurname()", ok = true, r = { "<nil>", "<secret>" } },
      fact(record, "C_PlayerInfo.ShouldDisplaySurname()"))
    local aurasSecret = fact(record, 'C_Secrets.ShouldAurasBeSecret("player")')
    assert.is_false(aurasSecret.ok)
    assert.truthy(aurasSecret.r[1]:find("not allowed here", 1, true))
    assert.same({ "true" }, fact(record, 'issecretvalue(UnitName("party1"))').r)
    assert.same({ "<secret>" }, fact(record, 'C_Map.GetBestMapForUnit("player")').r)
    assert.same({ "true" }, fact(record, 'issecretvalue(C_Map.GetBestMapForUnit("player"))').r)
    assert.same({ "true" }, fact(record, "C_CombatLog.IsCombatLogRestricted()").r)
    wow.stub("C_CombatLog", nil)
    wow.stub("issecretvalue", nil)
    record = probe()
    assert.same({ call = "C_CombatLog.IsCombatLogRestricted()", ok = false, r = { "<missing>" } },
      fact(record, "C_CombatLog.IsCombatLogRestricted()"))
    assert.same({ call = 'issecretvalue(UnitName("party1"))', ok = false, r = { "<missing>" } },
      fact(record, 'issecretvalue(UnitName("party1"))'))
  end)

  it("records the game rules", function()
    start(SAVED, function() wow.state.rules[102] = true end)
    local record = probe()
    assert.same({ "102" }, fact(record, "Enum.GameRule.RPRuleset").r)
    assert.same({ "true" }, fact(record, "C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset)").r)
    assert.same({ "false" }, fact(record, "C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset)").r)
  end)

  it("lists C_RestrictedActions and its state per restriction type", function()
    start(SAVED, function()
      wow.stub("Enum.AddOnRestrictionType", { Combat = 0, Map = 4 })
      wow.stub("C_RestrictedActions.GetAddOnRestrictionState", function(kind) return kind == 4 and 2 or 0 end)
    end)
    local record = probe()
    assert.same({ "GetAddOnRestrictionState", "IsAddOnRestrictionActive" }, fact(record, "C_RestrictedActions").r)
    assert.same({ "Combat=0", "Map=4" }, fact(record, "Enum.AddOnRestrictionType").r)
    assert.same({ "2" }, fact(record, "C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Map)").r)
    assert.same({ "false" },
      fact(record, "C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)").r)
  end)

  it("reads the camp auras Campfire tracks", function()
    start()
    assert.same({ "<missing>" }, fact(probe(), "ns.Campfire.AURAS").r)
    ns.Campfire = { AURAS = { WELCOME = 1289723, BENEFITS = 1229741, BEDROLL = { 555 } } }
    wow.state.auras[1289723] = { spellId = 1289723, name = "Welcome" }
    local record = probe()
    local auraCalls = {}
    for _, f in ipairs(record.facts) do
      if f.call:find("GetPlayerAuraBySpellID", 1, true) then auraCalls[#auraCalls + 1] = f.call end
    end
    assert.same({ "BEDROLL C_UnitAuras.GetPlayerAuraBySpellID(555)",
                  "BENEFITS C_UnitAuras.GetPlayerAuraBySpellID(1229741)",
                  "WELCOME C_UnitAuras.GetPlayerAuraBySpellID(1289723)" }, auraCalls)
    assert.same({ "<nil>" }, fact(record, "BENEFITS C_UnitAuras.GetPlayerAuraBySpellID(1229741)").r)
    assert.same({ "{name=Welcome, spellId=1289723}" },
      fact(record, "WELCOME C_UnitAuras.GetPlayerAuraBySpellID(1289723)").r)
  end)

  it("records the bag indices and the Hearthstone tooltip line types", function()
    start(SAVED, function()
      wow.data.tooltips[6948] = { id = 6948, lines = {
        { type = 29, leftText = "Hearthstone" }, { type = 20, leftText = wow.secret("Soulbound") },
      } }
    end)
    local record = probe()
    local bags = fact(record, "Enum.BagIndex").r
    assert.truthy(tContains(bags, "Backpack=0"))
    assert.truthy(tContains(bags, "Bank=-1"))
    assert.same({ "29 Hearthstone", "20 <secret>" }, fact(record, 'line types of C_TooltipInfo.GetItemByID(6948)').r)
  end)

  it("checks every event of the spec and never the combat log", function()
    start(SAVED, function() wow.invalidEvents.ENCOUNTER_END = true end)
    local valid = fact(probe(), "C_EventUtils.IsEventValid").r
    assert.truthy(tContains(valid, "QUEST_ACCEPTED=true"))
    assert.truthy(tContains(valid, "ENCOUNTER_END=false"))
    assert.equal(48, #valid)
    for _, v in ipairs(valid) do assert.is_nil(v:find("COMBAT_LOG", 1, true)) end
    assert.equal(0, wow.registered("COMBAT_LOG_EVENT"))
    assert.equal(0, wow.registered("COMBAT_LOG_EVENT_UNFILTERED"))
    for _, file in ipairs({ "Dev/Probe.lua", "Dev/TestMode.lua" }) do
      local f = assert(io.open(wow.ROOT .. file, "r"))
      local source = f:read("*a")
      f:close()
      assert.is_nil(source:find("COMBAT_LOG_EVENT", 1, true))
      assert.is_nil(source:find("CombatLogGetCurrentEventInfo", 1, true))
    end
  end)

  it("records the arguments of the next QUEST_ACCEPTED only", function()
    start()
    local record = probe()
    local before = #record.facts
    wow.fire("QUEST_ACCEPTED", 5, 1382)
    wow.fire("QUEST_ACCEPTED", 6, 1383)
    assert.equal(before + 1, #record.facts)
    assert.same({ call = "QUEST_ACCEPTED", ok = true, r = { "5", "1382" } }, record.facts[#record.facts])
  end)

  it("records the dispatch order around the next pull", function()
    start()
    wow.unit("target", { guid = "Creature-0-1", name = "Boar", combat = false })
    local record = probe()
    wow.fire("UNIT_FLAGS", "target")         -- too long before the pull
    wow.advance(5)
    wow.state.units.target.combat = true
    wow.fire("UNIT_FLAGS", "target")
    wow.fire("UNIT_FLAGS", "player")
    wow.fire("UNIT_FLAGS", "focus")
    wow.combat(true)
    wow.advance(1)
    wow.fire("UNIT_FLAGS", "target")
    wow.advance(2)
    wow.fire("UNIT_FLAGS", "target")         -- after the window
    local now = wow.state.uptime
    assert.same({ "pull UNIT_FLAGS target", "pull UNIT_FLAGS player", "pull PLAYER_REGEN_DISABLED",
                  "pull UNIT_FLAGS target" }, calls(record, "pull "))
    local pull = {}
    for _, f in ipairs(record.facts) do
      if f.call:sub(1, 5) == "pull " then pull[#pull + 1] = f.r end
    end
    assert.same({ tostring(now - 3), "false", "true" }, pull[1])
    assert.same({ tostring(now - 3), "true", "true" }, pull[3])
    assert.same({ tostring(now - 2), "true", "true" }, pull[4])
    assert.equal(0, ns.Events:Count("UNIT_FLAGS", "target"))
    assert.equal(0, ns.Events:Count("UNIT_FLAGS", "player"))
    assert.equal(0, ns.Events:Count("PLAYER_REGEN_DISABLED"))
    wow.combat(false)
    wow.combat(true)
    assert.equal(4, #calls(record, "pull "))
  end)

  describe("in a group", function()
    before_each(function()
      start(SAVED, function()
        wow.unit("party1", { guid = "Player-1-00000002", name = "Mira", surname = "Vell" })
      end)
    end)

    it("sends one HI through Comm and records the result", function()
      local record = probe()
      assert.equal(1, #wow.sent)
      assert.same({ prefix = "Ashmark", text = "1|HI|Player-1-00000001|PRAGMATIST|0|Normal|1.0.0-test",
                    channel = "PARTY", result = 0 }, wow.sent[1])
      assert.same({ call = 'ns.Comm:Send("HI")', ok = true, r = { "true", "<nil>", "result 0=1" } },
        fact(record, 'ns.Comm:Send("HI")'))
    end)

    it("uses the archetype and origin from Profile when it is loaded", function()
      ns.Profile = {
        Archetype = function() return "WANDERER" end,
        Origin = function() error("broken") end,
      }
      probe()
      assert.equal("1|HI|Player-1-00000001|WANDERER|0|Normal|1.0.0-test", wow.sent[1].text)
    end)

    it("adds the raw sender of its own echo when it arrives", function()
      local record = probe()
      wow.fire("CHAT_MSG_ADDON", "Ashmark", "1|HI|Player-1-00000002|GENTLE|0|Normal|1", "PARTY", "Mira-Vell")
      wow.fire("CHAT_MSG_ADDON", "Ashmark", wow.sent[1].text, "PARTY", "Aren-Ashvale")
      assert.same({ call = "CHAT_MSG_ADDON own HI", ok = true, r = { "Aren-Ashvale", "PARTY" } },
        record.facts[#record.facts])
      assert.equal(1, ns.Events:Count("CHAT_MSG_ADDON"))
      wow.advance(30)
      assert.equal("CHAT_MSG_ADDON own HI", record.facts[#record.facts].call)
      assert.is_true(record.facts[#record.facts].ok)
    end)

    it("notes a missing echo after 30 s", function()
      local record = probe()
      wow.advance(30)
      assert.same({ call = "CHAT_MSG_ADDON own HI", ok = false, r = { "<none>" } }, record.facts[#record.facts])
      assert.equal(1, ns.Events:Count("CHAT_MSG_ADDON"))
    end)

    it("records why Comm refused", function()
      ns.Settings:Set("Comm.share", false)
      local record = probe()
      assert.same({}, wow.sent)
      assert.same({ "false", "share" }, fact(record, 'ns.Comm:Send("HI")').r)
    end)
  end)

  it("sends nothing outside a group", function()
    start()
    local record = probe()
    assert.same({}, wow.sent)
    assert.same({ call = 'ns.Comm:Send("HI")', ok = false, r = { "<not grouped>" } },
      fact(record, 'ns.Comm:Send("HI")'))
  end)

  it("keeps the newest 20 records", function()
    start()
    for i = 1, 22 do probe().i = i end
    assert.equal(20, #probes())
    assert.equal(3, probes()[1].i)
  end)

  it("warns with CORE_SV_NEW on a fresh record", function()
    wow.saved(nil)
    ns = wow.load({ "Dev" })
    wow.login()
    wow.chat = {}
    SlashCmdList.ASHMARK("probe")
    assert.is_true(printed("A new record has started"))
    assert.is_false(printed(ns.L.TEST_RELOAD))
  end)

  it("prints every fact and stores nothing in read-only mode", function()
    start({ schema = 2, created = 1, dev = { tests = {}, probes = {}, blocked = {} } })
    local before = wow.deepcopy(_G.AshmarkDB)
    wow.chat = {}
    SlashCmdList.ASHMARK("probe")
    assert.same(before, _G.AshmarkDB)
    assert.is_true(printed(ns.L.TEST_NOT_STORED))
    assert.is_true(printed("GetBuildInfo(): 1.60.1, 70532, Oct 20 2026, 16001"))
    assert.is_false(printed(ns.L.TEST_RELOAD))
    wow.fire("QUEST_ACCEPTED", 5, 1382)
    assert.is_true(printed("QUEST_ACCEPTED: 5, 1382"))
    assert.same(before, _G.AshmarkDB)
  end)
end)

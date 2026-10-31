local wow = require("tests.helpers.wow")

local function printed(text)
  for _, line in ipairs(wow.chat) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

local function result(record, id)
  for _, r in ipairs(record.results) do
    if r.id == id then return r end
  end
end

local function tests()
  return _G.AshmarkDB.dev.tests
end

local function stored()
  return _G.AshmarkDB.dev.tests[#_G.AshmarkDB.dev.tests]
end

local function run()
  SlashCmdList.ASHMARK("test")
  return stored()
end

local SAVED = { schema = 1, created = 7 }

describe("Dev test mode", function()
  local ns
  before_each(function()
    wow.reset()
  end)

  local function start(db, setup)
    if db then wow.saved(wow.deepcopy(db)) end
    ns = wow.load({ "Dev" })
    if setup then setup(ns) end
    wow.login()
    return ns
  end

  it("refuses to run in combat", function()
    start(SAVED)
    wow.combat(true)
    SlashCmdList.ASHMARK("test")
    assert.is_true(printed(ns.L.TEST_NOT_IN_COMBAT))
    assert.same({}, tests())
    assert.same({}, wow.screenshots)
  end)

  it("runs every registered check through the error wrapper", function()
    start(SAVED, function()
      local M = ns:NewModule("Alpha", { locale = "ALPHA" })
      function M:OnInitialize()
        ns.Test:Register("Alpha.pass", function() return true, "fine" end)
        ns.Test:Register("Alpha.fail", function() return false, "bad" end)
        ns.Test:Register("Alpha.skip", function() return nil end)
        ns.Test:Register("Alpha.boom", function() error("kaboom") end)
        ns.Test:Register("Alpha.secret", function() return wow.secret(true), wow.secret("x") end)
      end
    end)
    local record = run()
    assert.same({ id = "Alpha.pass", ok = true, detail = "fine" }, result(record, "Alpha.pass"))
    assert.same({ id = "Alpha.fail", ok = false, detail = "bad" }, result(record, "Alpha.fail"))
    assert.same({ id = "Alpha.skip" }, result(record, "Alpha.skip"))
    local boom = result(record, "Alpha.boom")
    assert.is_false(boom.ok)
    assert.truthy(boom.detail:find("kaboom", 1, true))
    assert.is_nil(boom.detail:find("\n", 1, true))
    assert.same({ id = "Alpha.secret", ok = false, detail = "<secret>" }, result(record, "Alpha.secret"))
    local reports = 0
    for _, e in ipairs(wow.errors) do
      if e:find("test:Alpha.boom", 1, true) then reports = reports + 1 end
    end
    assert.equal(1, reports)
    assert.is_true(ns.Alpha.enabled)
    assert.equal("Core.forever", record.results[1].id)
  end)

  it("stores the record in the specified shape", function()
    start(SAVED)
    local record = run()
    assert.equal(time(), record.t)
    assert.same({ version = "1.60.1", build = "70532", date = "Oct 20 2026", interface = 16001 }, record.build)
    assert.equal("enUS", record.locale)
    assert.equal(18, record.project)
    assert.equal("Forever", record.tocVariant)
    assert.same({ created = 7, fresh = false, readOnly = false, entries = 0, seq = 0 }, record.db)
    assert.same({ sent = 0, rejected = 0, dropped = 0, results = {} }, record.comm)
    assert.are_not.equal(ns.Comm.stats, record.comm)
    for _, r in ipairs(record.results) do
      assert.is_string(r.id)
      assert.is_true(r.ok == nil or type(r.ok) == "boolean")
      assert.is_true(r.detail == nil or type(r.detail) == "string")
    end
  end)

  it("records only the type of a recovered value", function()
    start("garbage")
    local record = run()
    assert.equal("string", record.db.recovered)
    start({ chars = { big = { 1, 2, 3 } } })
    assert.equal("table", run().db.recovered)
  end)

  it("keeps the newest 10 records", function()
    start(SAVED)
    for i = 1, 12 do
      wow.advance(1)
      run().n = i
    end
    assert.equal(10, #tests())
    assert.equal(3, tests()[1].n)
    assert.equal(12, tests()[10].n)
  end)

  it("prints the summary and the failed checks, then asks for a reload", function()
    start(SAVED, function()
      local M = ns:NewModule("Alpha", { locale = "ALPHA" })
      function M:OnInitialize()
        ns.Test:Register("Alpha.pass", function() return true, "fine" end)
        ns.Test:Register("Alpha.fail", function() return false, "bad" end)
      end
    end)
    local record = run()
    local passed, failed, skipped = 0, 0, 0
    for _, r in ipairs(record.results) do
      if r.ok == true then
        passed = passed + 1
      elseif r.ok == false then
        failed = failed + 1
      else
        skipped = skipped + 1
      end
    end
    assert.is_true(printed(ns.Format(ns.L.TEST_SUMMARY, { passed = passed, failed = failed, skipped = skipped })))
    assert.is_true(printed("FAIL Alpha.fail: bad"))
    assert.is_false(printed("Alpha.pass"))
    assert.is_true(printed(ns.L.TEST_RELOAD))
    assert.equal(ns.L.TEST_RELOAD, wow.chat[#wow.chat]:match(": (.*)$"))
  end)

  it("warns with CORE_SV_NEW instead of asking for a reload on a fresh record", function()
    start()
    wow.chat = {}
    run()
    assert.is_false(printed(ns.L.TEST_RELOAD))
    assert.is_true(printed("A new record has started"))
    assert.equal(1, #tests())
  end)

  it("prints the full report and stores nothing in read-only mode", function()
    local db = { schema = 2, created = 1, dev = { tests = { { t = 1 } }, probes = {}, blocked = {} } }
    start(db)
    local before = wow.deepcopy(_G.AshmarkDB)
    wow.chat = {}
    SlashCmdList.ASHMARK("test")
    assert.same(before, _G.AshmarkDB)
    assert.is_true(printed(ns.L.TEST_NOT_STORED))
    assert.is_true(printed("pass Core.forever: "))
    assert.is_true(printed("Test finished: "))
    assert.is_false(printed(ns.L.TEST_RELOAD))
    wow.fire("SCREENSHOT_SUCCEEDED")
    assert.is_true(printed("Later result: screenshot succeeded"))
    assert.same(before, _G.AshmarkDB)
  end)

  describe("screenshot", function()
    local shown
    local function withMainFrame()
      shown = nil
      ns.UI = { MainFrame = { Show = function(_, id) shown = id end } }
      CreateFrame("Frame", "AshmarkFrame", UIParent)
    end

    it("shows the chronicle anchored to the right of the quest dialog", function()
      start(SAVED, withMainFrame)
      QuestFrame:Show()
      local record = run()
      assert.equal("chronicle", shown)
      local point, relative, relativePoint = AshmarkFrame:GetPoint(1)
      assert.equal("TOPLEFT", point)
      assert.equal(QuestFrame, relative)
      assert.equal("TOPRIGHT", relativePoint)
      assert.is_true(record.questDialog)
      assert.is_false(printed(ns.L.TEST_OPEN_QUEST_DIALOG))
    end)

    it("asks for a quest dialog when none is open", function()
      start(SAVED, withMainFrame)
      local record = run()
      assert.equal("chronicle", shown)
      assert.equal(0, AshmarkFrame:GetNumPoints())
      assert.is_false(record.questDialog)
      assert.is_true(printed(ns.L.TEST_OPEN_QUEST_DIALOG))
    end)

    it("still takes the screenshot without the main window", function()
      start(SAVED)
      run()
      assert.equal(1, #wow.screenshots)
    end)

    it("adds screenshot and blocked-action events of the next 10 s to the record", function()
      start(SAVED)
      local record = run()
      assert.equal(1, #wow.screenshots)
      assert.equal("called", record.screenshot)
      wow.advance(3)
      wow.fire("SCREENSHOT_SUCCEEDED")
      wow.fire("ADDON_ACTION_BLOCKED", "Ashmark", "Foo()")
      wow.fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "Bar()")
      wow.fire("ADDON_ACTION_FORBIDDEN", "Ashmark", wow.secret("Baz()"))
      assert.equal("succeeded", record.screenshot)
      assert.same({ { event = "ADDON_ACTION_BLOCKED", fn = "Foo()", after = 3 },
                    { event = "ADDON_ACTION_FORBIDDEN", after = 3 } }, record.blocked)
      wow.advance(8)
      wow.fire("SCREENSHOT_FAILED")
      wow.fire("ADDON_ACTION_BLOCKED", "Ashmark", "Late()")
      assert.equal("succeeded", record.screenshot)
      assert.equal(2, #record.blocked)
      assert.equal(0, ns.Events:Count("SCREENSHOT_SUCCEEDED"))
      assert.equal(0, ns.Events:Count("SCREENSHOT_FAILED"))
    end)

    it("moves the window to a newer run", function()
      start(SAVED)
      local first = run()
      wow.advance(5)
      local second = run()
      wow.advance(6)
      wow.fire("SCREENSHOT_FAILED")
      assert.equal("called", first.screenshot)
      assert.equal("failed", second.screenshot)
    end)

    it("notes a client without Screenshot", function()
      start(SAVED, function() wow.stub("Screenshot", nil) end)
      assert.equal("missing", run().screenshot)
      assert.same({}, wow.screenshots)
    end)
  end)

  describe("Core checks", function()
    it("proves the SavedVariables round trip only with a record from an earlier session", function()
      start(SAVED)
      local first = run()
      assert.is_nil(result(first, "Core.savedVariables").ok)
      wow.advance(60)
      local second = run()
      assert.is_nil(result(second, "Core.savedVariables").ok)
      ns = wow.reload()
      wow.advance(60)
      local third = run()
      local check = result(third, "Core.savedVariables")
      assert.is_true(check.ok)
      assert.truthy(check.detail:find("previous=" .. second.t, 1, true))
      assert.truthy(check.detail:find("created=7 fresh=false readOnly=false recovered=nil entries=0 seq=0", 1, true))
      assert.equal(3, #tests())
    end)

    it("reports detection, TOC variant and build", function()
      start(SAVED)
      local record = run()
      assert.same({ id = "Core.forever", ok = true, detail = "project=18 camelot=18 interface=16001" },
        result(record, "Core.forever"))
      assert.same({ id = "Core.toc", ok = true, detail = "Forever" }, result(record, "Core.toc"))
      assert.same({ id = "Core.build", ok = true, detail = "1.60.1.70532 Oct 20 2026 interface 16001" },
        result(record, "Core.build"))
    end)

    it("reports every capability, with the reason for a demotion", function()
      start(SAVED, function() wow.stub("C_QuestLog.RequestLoadQuestByID", nil) end)
      ns.Compat.Disable("canSend", "SendAddonMessage result 9")
      local record = run()
      for _, cap in ipairs(ns.Compat.KEYS) do assert.is_table(result(record, "Compat." .. cap)) end
      assert.same({ id = "Compat.questLog", ok = false, detail = "false" }, result(record, "Compat.questLog"))
      assert.same({ id = "Compat.reputation", ok = true, detail = "true" }, result(record, "Compat.reputation"))
      assert.same({ id = "Compat.canSend", ok = false, detail = "disabled: SendAddonMessage result 9" },
        result(record, "Compat.canSend"))
      local comm = result(record, "Core.comm")
      assert.is_false(comm.ok)
      assert.truthy(comm.detail:find("canSend=false (SendAddonMessage result 9)", 1, true))
    end)

    it("reports each module's state, reasons and missing events", function()
      start(SAVED, function()
        wow.invalidEvents.NO_SUCH_EVENT = true
        ns:NewModule("Alpha", { locale = "ALPHA" })
        ns:NewModule("Beta", { locale = "BETA", requires = { "nothing" } })
        local G = ns:NewModule("Gamma", { locale = "GAMMA" })
        function G:OnEnable() self:RegisterEvent("NO_SUCH_EVENT", function() end) end
        ns:NewModule("Delta", { locale = "DELTA" })
        _G.AshmarkDB.settings = { ["Delta.enabled"] = false }
      end)
      local record = run()
      assert.same({ id = "Module.Alpha", ok = true, detail = "enabled" }, result(record, "Module.Alpha"))
      assert.same({ id = "Module.Beta", ok = false, detail = "unavailable: nothing" }, result(record, "Module.Beta"))
      assert.same({ id = "Module.Gamma", ok = false, detail = "enabled; missing events: NO_SUCH_EVENT" },
        result(record, "Module.Gamma"))
      assert.same({ id = "Module.Delta", detail = "off" }, result(record, "Module.Delta"))
    end)

    it("builds each template once and hides it", function()
      start(SAVED, function()
        wow.data.templates.InputBoxTemplate = { type = "EditBox" }
        wow.data.missingTemplates.DialogBorderTemplate = true
      end)
      local record = run()
      assert.same({ id = "Template.InputBoxTemplate", ok = true, detail = "EditBox" },
        result(record, "Template.InputBoxTemplate"))
      assert.same({ id = "Template.DialogBorderTemplate", ok = false, detail = "missing" },
        result(record, "Template.DialogBorderTemplate"))
      assert.is_true(result(record, "Template.ButtonFrameTemplate").ok)
      local function built()
        local frames = {}
        for _, f in ipairs(wow.frames) do
          if f.__template == "InputBoxTemplate" then frames[#frames + 1] = f end
        end
        return frames
      end
      assert.equal(1, #built())
      assert.equal("EditBox", built()[1].__kind)
      assert.is_false(built()[1]:IsShown())
      run()
      assert.equal(1, #built())
    end)

    it("skips templates without C_XMLUtil", function()
      start(SAVED, function() wow.stub("C_XMLUtil.GetTemplateInfo", nil) end)
      assert.same({ id = "Template.ButtonFrameTemplate", detail = "no C_XMLUtil.GetTemplateInfo" },
        result(run(), "Template.ButtonFrameTemplate"))
    end)

    it("checks the parchment atlases, fonts and sounds", function()
      start(SAVED)
      local record = run()
      assert.same({ id = "Core.parchment", ok = true, detail = "QuestBG-Parchment=true" },
        result(record, "Core.parchment"))
      assert.same({ id = "Core.fonts", ok = true, detail = "all 7" }, result(record, "Core.fonts"))
      assert.same({ id = "Core.sounds", ok = true, detail = "all 3" }, result(record, "Core.sounds"))
      wow.data.missingAtlases["QuestBG-Parchment"] = true
      ns.UI = { PARCHMENT_ATLASES = { "QuestBG-Parchment", "Other-Parchment" } }
      wow.stub("GameFontDisable", nil)
      wow.stub("SOUNDKIT.IG_ABILITY_PAGE_TURN", nil)
      record = run()
      assert.same({ id = "Core.parchment", ok = true, detail = "QuestBG-Parchment=false, Other-Parchment=true" },
        result(record, "Core.parchment"))
      assert.same({ id = "Core.fonts", ok = false, detail = "missing: GameFontDisable" }, result(record, "Core.fonts"))
      assert.same({ id = "Core.sounds", ok = false, detail = "missing: IG_ABILITY_PAGE_TURN" },
        result(record, "Core.sounds"))
    end)

    it("lists missing keys of the active locale", function()
      start(SAVED)
      assert.same({ id = "Core.locale", ok = true, detail = "enUS: complete" }, result(run(), "Core.locale"))
      wow.reset()
      wow.state.locale = "deDE"
      start(SAVED)
      local check = result(run(), "Core.locale")
      assert.is_false(check.ok)
      assert.truthy(check.detail:match("^deDE: %d+ missing: %u+_"))
    end)

    it("reports the player's identity and the surname source", function()
      start(SAVED)
      local check = result(run(), "Core.identity")
      assert.is_true(check.ok)
      assert.truthy(check.detail:find("guid=Player-1-00000001 name=Aren surname=Ashvale source=UnitNameUnmodified", 1,
        true))
      wow.state.units.player.surname = nil
      check = result(run(), "Core.identity")
      assert.is_false(check.ok)
      assert.truthy(check.detail:find("surname=nil source=nil", 1, true))
    end)

    it("proves that Safe, Log:Add and the Comm decoder refuse secrets, without leaving a trace", function()
      start(SAVED)
      local char = ns.DB:Char()
      local check = result(run(), "Core.secrets")
      assert.same({ id = "Core.secrets", ok = true,
                    detail = "every Safe function, Log:Add and Comm:Decode refuse secrets" }, check)
      assert.equal(0, char.seq)
      assert.equal(0, char.stats["Core.secretDropped"] or 0)
      assert.same({}, wow.errors)
    end)

    it("names the Safe function that lets a secret through", function()
      start(SAVED)
      ns.Safe.Bool = function(v) return v end
      local check = result(run(), "Core.secrets")
      assert.same({ id = "Core.secrets", ok = false, detail = "not refused: Bool" }, check)
    end)

    it("skips the secret check without secretwrap", function()
      start(SAVED, function() wow.stub("secretwrap", nil) end)
      assert.same({ id = "Core.secrets", detail = "no secretwrap" }, result(run(), "Core.secrets"))
    end)

    it("records the restriction CVars, including ones only C_Console lists", function()
      start(SAVED)
      assert.same({ id = "Core.restrictionCVars", detail = "none of these CVars exist" },
        result(run(), "Core.restrictionCVars"))
      wow.data.cvars.addonChatRestrictionsForced = "0"
      wow.data.cvars.addonNewRestrictionsForced = "1"
      wow.stub("C_Console", { GetAllCommands = function()
        return { { command = "addonNewRestrictionsForced" }, { command = "cameraYawSpeed" } }
      end })
      assert.same({ id = "Core.restrictionCVars", ok = true,
                    detail = "addonChatRestrictionsForced=0, addonNewRestrictionsForced=1" },
        result(run(), "Core.restrictionCVars"))
    end)

    it("reports the Comm state", function()
      start(SAVED)
      local check = result(run(), "Core.comm")
      assert.is_true(check.ok)
      assert.equal("canSend=true addonMessages=true share=true sent=0 rejected=0 dropped=0 queued=0 results=none",
        check.detail)
    end)

    it("lists blocked actions since the last run", function()
      start(SAVED)
      assert.same({ id = "Core.blocked", ok = true, detail = "none" }, result(run(), "Core.blocked"))
      wow.advance(30)
      wow.fire("ADDON_ACTION_BLOCKED", "Ashmark", "Bar()")
      wow.advance(30)
      assert.same({ id = "Core.blocked", ok = false, detail = "ADDON_ACTION_BLOCKED Bar()" },
        result(run(), "Core.blocked"))
      wow.advance(30)
      assert.same({ id = "Core.blocked", ok = true, detail = "none since the last run" },
        result(run(), "Core.blocked"))
    end)

    it("reports events missing for Core's own services", function()
      start(SAVED, function() wow.invalidEvents.QUEST_DATA_LOAD_RESULT = true end)
      assert.same({ id = "Core.events", ok = false, detail = "missing: Names:QUEST_DATA_LOAD_RESULT" },
        result(run(), "Core.events"))
    end)
  end)

  it("is listed in the slash help", function()
    start(SAVED)
    SlashCmdList.ASHMARK("help")
    assert.is_true(printed("/ashmark test - " .. ns.L.TEST_HELP))
    assert.is_true(printed("/ashmark probe - " .. ns.L.TEST_HELP_PROBE))
  end)
end)

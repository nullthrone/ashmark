local wow = require("tests.helpers.wow")

local function printed(text)
  for _, line in ipairs(wow.chat) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

describe("Core Slash", function()
  local ns, dialog
  before_each(function()
    wow.reset()
    ns = wow.load()
    wow.login()
    dialog = nil
    ns.UI = ns.UI or {}
    ns.UI.Dialog = { Show = function(_, opts) dialog = opts end }
  end)

  it("registers /ashmark and /amk", function()
    assert.equal("/ashmark", _G.SLASH_ASHMARK1)
    assert.equal("/amk", _G.SLASH_ASHMARK2)
    assert.is_function(SlashCmdList.ASHMARK)
  end)

  it("dispatches subcommands with their arguments, case-insensitive", function()
    local got
    ns.Slash:Register("fixture", function(args) got = args end, "FIXTURE_HELP")
    SlashCmdList.ASHMARK("  FIXTURE  Ashvale of Lordaeron ")
    assert.equal("Ashvale of Lordaeron", got)
    SlashCmdList.ASHMARK("fixture")
    assert.equal("", got)
  end)

  it("lists subcommands on help and on an unknown command", function()
    ns.Slash:Register("fixture", function() end, "FIXTURE_HELP")
    SlashCmdList.ASHMARK("help")
    assert.is_true(printed("/ashmark fixture - FIXTURE_HELP"))
    assert.is_true(printed("/ashmark debug - "))
    wow.chat = {}
    SlashCmdList.ASHMARK("nope")
    assert.is_true(printed("Unknown command: nope"))
    assert.is_true(printed("/ashmark help - "))
  end)

  it("toggles debug output", function()
    SlashCmdList.ASHMARK("debug")
    assert.is_true(ns.debug)
    SlashCmdList.ASHMARK("debug")
    assert.is_false(ns.debug)
  end)

  it("toggles the main window without arguments", function()
    local toggled = 0
    ns.UI.MainFrame = { Toggle = function() toggled = toggled + 1 end }
    SlashCmdList.ASHMARK("")
    SlashCmdList.ASHMARK()
    assert.equal(2, toggled)
  end)

  it("wipes this character's record after confirmation", function()
    wow.state.map = 1443
    wow.fire("ZONE_CHANGED_NEW_AREA")
    assert.equal(1, ns.DB:Char().seq)
    SlashCmdList.ASHMARK("reset")
    assert.equal(ns.L.CORE_RESET_CONFIRM, dialog.text)
    assert.equal(1, ns.DB:Char().seq)
    dialog.onAccept()
    local char = ns.DB:Char()
    assert.equal(0, char.seq)
    assert.same({}, char.log)
    assert.equal("Aren", char.name)
  end)

  it("wipes this character's meetings and peer sightings with its record", function()
    local me, alt = ns.playerGUID, "Player-1-0000000b"
    local db = _G.AshmarkDB
    db.contacts = {
      once = { guid = "once", note = "", byChar = { [me] = { count = 2 } } },
      noted = { guid = "noted", note = "owes me", byChar = { [me] = { count = 1 } } },
      shared = { guid = "shared", byChar = { [me] = { count = 1 }, [alt] = { count = 4 } } },
      other = { guid = "other", byChar = { [alt] = { count = 1 } } },
    }
    db.peers = {
      p = { guid = "p", seenBy = { [me] = "GENTLE", [alt] = "RUTHLESS" }, logged = { [me] = 5, [alt] = 6 } },
    }
    SlashCmdList.ASHMARK("reset")
    dialog.onAccept()
    assert.same({
      noted = { guid = "noted", note = "owes me", byChar = {} },
      shared = { guid = "shared", byChar = { [alt] = { count = 4 } } },
      other = { guid = "other", byChar = { [alt] = { count = 1 } } },
    }, db.contacts)
    assert.same({ [alt] = "RUTHLESS" }, db.peers.p.seenBy)
    assert.same({ [alt] = 6 }, db.peers.p.logged)
  end)

  it("wipes contacts, peers and rumours that are not own", function()
    local db = _G.AshmarkDB
    db.contacts.x, db.peers.y = {}, {}
    db.rumours.heard = { mine = { id = "mine", own = true }, theirs = { id = "theirs" } }
    db.rumours.told = { mine = { p = 1 }, theirs = { p = 2 } }
    SlashCmdList.ASHMARK("reset others")
    dialog.onAccept()
    db = _G.AshmarkDB
    assert.same({}, db.contacts)
    assert.same({}, db.peers)
    assert.same({ mine = { id = "mine", own = true } }, db.rumours.heard)
    assert.same({ mine = { p = 1 } }, db.rumours.told)
  end)

  it("redraws the visible tab after a wipe of others", function()
    local refreshed = 0
    ns.UI.MainFrame = { Refresh = function(_, id) refreshed = refreshed + 1 assert.is_nil(id) end }
    SlashCmdList.ASHMARK("reset OTHERS")
    dialog.onAccept()
    assert.equal(1, refreshed)
  end)

  describe("another character", function()
    local MIRA, THALEN1, THALEN2 = "Player-1-0000000c", "Player-1-0000000d", "Player-1-0000000e"
    local refreshed

    before_each(function()
      local db = _G.AshmarkDB
      db.chars[MIRA] = { guid = MIRA, name = "Mira", surname = "Ashvale", level = 20, log = {} }
      db.chars[THALEN1] = { guid = THALEN1, name = "Thalen", surname = "Ashvale", level = 12, log = {} }
      db.chars[THALEN2] = { guid = THALEN2, name = "Thalen", level = 31, log = {} }
      db.contacts = {
        mine = { guid = "mine", note = "", byChar = { [MIRA] = { count = 1 }, [ns.playerGUID] = { count = 1 } } },
        hers = { guid = "hers", note = "", byChar = { [MIRA] = { count = 5 } } },
      }
      db.peers = { p = { guid = "p", seenBy = { [MIRA] = "GENTLE" }, logged = { [MIRA] = 5 } } }
      refreshed = 0
      ns.UI.MainFrame = { Refresh = function() refreshed = refreshed + 1 end }
    end)

    it("is forgotten by first or full name after confirmation, with its meetings and sightings", function()
      SlashCmdList.ASHMARK("reset mira ashvale")
      assert.equal(ns.Format(ns.L.CORE_RESET_CHAR_CONFIRM, { name = "Mira Ashvale" }), dialog.text)
      assert.is_table(_G.AshmarkDB.chars[MIRA])
      dialog.onAccept()
      local db = _G.AshmarkDB
      assert.is_nil(db.chars[MIRA])
      assert.is_table(db.chars[ns.playerGUID])
      assert.same({ mine = { guid = "mine", note = "", byChar = { [ns.playerGUID] = { count = 1 } } } }, db.contacts)
      assert.same({}, db.peers.p.seenBy)
      assert.equal(1, refreshed)
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_DONE, { name = "Mira Ashvale" })))
      dialog = nil
      SlashCmdList.ASHMARK("reset Mira")
      assert.is_nil(dialog)
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_UNKNOWN, { name = "Mira" })))
    end)

    it("lists characters that share a name with their GUIDs, and takes one by GUID", function()
      SlashCmdList.ASHMARK("reset thalen")
      assert.is_nil(dialog)
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_AMBIGUOUS, { name = "thalen" })))
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_LINE, { name = "Thalen", level = 31, guid = THALEN2 })))
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_LINE,
        { name = "Thalen Ashvale", level = 12, guid = THALEN1 })))
      SlashCmdList.ASHMARK("reset " .. THALEN2)
      dialog.onAccept()
      assert.is_nil(_G.AshmarkDB.chars[THALEN2])
      assert.is_table(_G.AshmarkDB.chars[THALEN1])
    end)

    it("never names the current character", function()
      local me = _G.AshmarkDB.chars[ns.playerGUID]
      SlashCmdList.ASHMARK("reset " .. me.name)
      SlashCmdList.ASHMARK("reset " .. ns.playerGUID)
      assert.is_nil(dialog)
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_UNKNOWN, { name = me.name })))
      assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_UNKNOWN, { name = ns.playerGUID })))
    end)

    it("never wipes the current character for an argument that names nobody", function()
      local db = _G.AshmarkDB
      local me, contacts = db.chars[ns.playerGUID], db.contacts
      for _, arg in ipairs({ "nobody", "othres", "me", "all", "Player-1-ffffffff" }) do
        SlashCmdList.ASHMARK("reset " .. arg)
        assert.is_nil(dialog)
        assert.is_true(printed(ns.Format(ns.L.CORE_RESET_CHAR_UNKNOWN, { name = arg })))
      end
      assert.equal(me, db.chars[ns.playerGUID])
      assert.equal(contacts, db.contacts)
      assert.is_table(db.chars[MIRA])
      assert.is_table(db.contacts.mine.byChar[ns.playerGUID])
      assert.equal(0, refreshed)
    end)
  end)

  it("refuses to reset in read-only mode", function()
    ns.DB.readOnly = true
    SlashCmdList.ASHMARK("reset")
    SlashCmdList.ASHMARK("reset Mira")
    assert.is_nil(dialog)
    assert.is_true(printed(ns.L.CORE_RESET_READONLY))
  end)

  it("reports a failing subcommand", function()
    ns.Slash:Register("boom", function() error("boom") end)
    assert.has_no.errors(function() SlashCmdList.ASHMARK("boom") end)
    assert.equal(1, #wow.errors)
  end)
end)

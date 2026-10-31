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

  it("refuses to reset in read-only mode", function()
    ns.DB.readOnly = true
    SlashCmdList.ASHMARK("reset")
    assert.is_nil(dialog)
    assert.is_true(printed(ns.L.CORE_RESET_READONLY))
  end)

  it("reports a failing subcommand", function()
    ns.Slash:Register("boom", function() error("boom") end)
    assert.has_no.errors(function() SlashCmdList.ASHMARK("boom") end)
    assert.equal(1, #wow.errors)
  end)
end)

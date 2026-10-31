-- Fixtures for the Campfire specs (not shipped): the camp auras on the player, the notice and the
-- CHAPTER_CLOSED topic recorded, and the test checks run by id.
local mock = {}

mock.FILES = { "UI/MainFrame.lua", "UI/Notice.lua", "Modules/Campfire" }
mock.NEARBY, mock.WELCOME, mock.BENEFITS, mock.BOOSTED = 1283391, 1289723, 1229741, 1229451

-- Core, Locales, the notice, the main window (for ns.UI:Sound) and Campfire; opts.setup(ns) runs before
-- login. Returns ns and a record of { notices = { text, ... }, chapters = { { chapter, members }, ... } }.
function mock.boot(wow, opts)
  opts = opts or {}
  local ns = wow.load(mock.FILES)
  local seen = { notices = {}, chapters = {} }
  local show = ns.UI.Notice.Show
  ns.UI.Notice.Show = function(self, text)
    seen.notices[#seen.notices + 1] = text
    return show(self, text)
  end
  local spy = ns:NewService("CampfireSpec")
  spy:Subscribe("CHAPTER_CLOSED", function(_, _, chapter, members)
    seen.chapters[#seen.chapters + 1] = { chapter = chapter, members = members }
  end)
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns, seen
end

-- Puts an aura on the player (data = true for a plain table, or any value such as a secret) or takes it
-- off (nil), then fires UNIT_AURA for the player unless opts.silent.
function mock.aura(wow, id, data, silent)
  if data == true then data = { spellId = id, name = "aura " .. id } end
  wow.state.auras[id] = data
  if not silent then wow.fire("UNIT_AURA", "player", { isFullUpdate = true }) end
end

function mock.sit(wow)
  mock.aura(wow, mock.WELCOME, true)
end

function mock.stand(wow)
  mock.aura(wow, mock.WELCOME, nil)
end

function mock.benefit(wow)
  mock.aura(wow, mock.BENEFITS, true)
end

-- Entries of a kind in the current character's log.
function mock.count(ns, kind)
  local n = 0
  for entry in ns.Log:Iter(ns.DB:Char(), 1) do
    if entry.k == kind then n = n + 1 end
  end
  return n
end

-- Entries of a kind with no meaning for Campfire, to fill the open chapter: n of them, or as many as
-- take the log to sequence number n.
function mock.fill(ns, n)
  for i = 1, n do ns.Log:Add("level", { l = i }) end
end

function mock.fillTo(ns, n)
  mock.fill(ns, n - ns.Log:Seq(ns.DB:Char()))
end

function mock.check(ns, id)
  for _, c in ipairs(ns.Test.checks) do
    if c.id == id then return c.fn() end
  end
  error("no test check " .. id)
end

return mock

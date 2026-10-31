-- Fixtures for the House specs (not shipped): an account with siblings of House Ashvale, a character of
-- another house and one without a surname, log entries written straight into their records, and the
-- Conflicts kinds with plain sentences (Conflicts is not loaded).
local mock = {}

mock.FILES = { "Modules/House" }

mock.AREN = "Player-1-00000001"  -- the player of tests/helpers/wow.lua: Aren Ashvale, level 20, warrior
mock.MIRA = "Player-1-00000002"
mock.TOBIN = "Player-1-00000003"
mock.KEL = "Player-1-00000004"
mock.NYM = "Player-1-00000005"

local function record(guid, name, surname, level, class, extra)
  local char = { guid = guid, name = name, surname = surname, level = level, class = class, sex = 3,
                 ruleset = "Normal", seq = 0, log = {}, chapters = {}, stats = {}, state = {} }
  for k, v in pairs(extra or {}) do char[k] = v end
  return char
end

-- The other characters on the account; fields in extra[guid] are merged into their records.
function mock.siblings(extra)
  extra = extra or {}
  return {
    [mock.MIRA] = record(mock.MIRA, "Mira", "Ashvale", 35, "MAGE", extra[mock.MIRA]),
    [mock.TOBIN] = record(mock.TOBIN, "Tobin", "Ashvale", 12, "ROGUE", extra[mock.TOBIN]),
    [mock.KEL] = record(mock.KEL, "Kel", "Ironhold", 50, "PALADIN", extra[mock.KEL]),
    [mock.NYM] = record(mock.NYM, "Nym", nil, 8, "PRIEST", extra[mock.NYM]),
  }
end

-- Appends an entry to a stored record as Log:Add would have written it (4.2).
function mock.entry(char, kind, t, fields)
  local entry = { k = kind, t = t }
  for k, v in pairs(fields or {}) do entry[k] = v end
  char.seq = char.seq + 1
  entry.n = char.seq
  char.log[#char.log + 1] = entry
  return entry
end

-- The kinds Conflicts registers (7.1), with sentences that show who acted.
function mock.kinds(ns)
  local function say(verb)
    return function(entry, ctx)
      return (ctx.own and "You" or ctx.char.name) .. " " .. verb .. " " .. tostring(entry.c) .. "."
    end
  end
  ns.Log:RegisterKind("alliance", { fields = { "c", "side", "rep" }, keep = true, render = say("sided in") })
  ns.Log:RegisterKind("violation", { fields = { "c", "side", "q", "o" }, keep = true, render = say("broke faith in") })
  ns.Log:RegisterKind("houseturn", { fields = { "c", "side", "q", "h" }, keep = true, render = say("turned in") })
end

-- AshmarkDB with the siblings (opts.extra merged into them), the files (opts.files after the House module),
-- the Conflicts kinds, opts.setup(ns), then login. Returns ns and the player's record.
function mock.boot(wow, opts)
  opts = opts or {}
  wow.saved({ schema = opts.schema or 1, chars = mock.siblings(opts.extra) })
  local files = {}
  for _, f in ipairs(mock.FILES) do files[#files + 1] = f end
  for _, f in ipairs(opts.files or {}) do files[#files + 1] = f end
  local ns = wow.load(files)
  if opts.kinds ~= false then mock.kinds(ns) end
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns, ns.DB:Char()
end

function mock.char(guid)
  return _G.AshmarkDB.chars[guid]
end

function mock.names(list)
  local out = {}
  for i, char in ipairs(list) do out[i] = char.name end
  return out
end

-- Runs the registered test check id.
function mock.check(ns, id)
  for _, c in ipairs(ns.Test.checks) do
    if c.id == id then return c.fn() end
  end
  error("no test check " .. id)
end

-- Records every HOUSE_CHANGED payload through a bus subscriber of its own.
function mock.changes(ns)
  local seen = {}
  local owner = ns:NewService("HouseSpec")
  owner:Subscribe("HOUSE_CHANGED", function(_, _, key) seen[#seen + 1] = key == nil and "<nil>" or key end)
  return seen
end

return mock

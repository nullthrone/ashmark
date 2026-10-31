-- Fixtures for the Profile specs (not shipped): a small conflict dataset for the fidelity rules, targets
-- for the kill approximation, and the replay of the event weights from the log that 7.2 keeps out of the
-- addon: the incremental accumulators must add up to it.
local mock = {}

mock.FILES = { "Modules/Conflicts", "Modules/Profile" }
mock.DAY = 86400
mock.NONE = {}                   -- a target field given as mock.NONE is removed from the fixture

-- One conflict without a reputation trigger, so only quests decide alliances.
function mock.data()
  return {
    count = 1,
    list = {
      { id = "clan_choice", zone = 1443, theme = "feud",
        A = { faction = 92, quests = { 1001, 1002, 1003 } },
        B = { faction = 93, quests = { 2001, 2002 } },
        verified = false },
    },
  }
end

-- Core, Locales, Conflicts and Profile (plus opts.files) with the fixture data, opts.setup(ns), then login.
-- The player stays indoors and out of rest unless a spec says otherwise, so the ticker adds no habitat time.
function mock.boot(wow, opts)
  opts = opts or {}
  wow.state.outdoors = false
  local files = {}
  for _, f in ipairs(mock.FILES) do files[#files + 1] = f end
  for _, f in ipairs(opts.files or {}) do files[#files + 1] = f end
  local ns = wow.load(files)
  ns.Data = { Conflicts = opts.data or mock.data() }
  -- Campfire writes these; registered here so the specs can write them without it.
  ns.Log:RegisterKind("rest.camp", {})
  ns.Log:RegisterKind("rest.bedroll", {})
  if opts.setup then opts.setup(ns) end
  wow.login()
  return ns
end

function mock.accept(wow, q)
  local quest = wow.data.quests[q] or {}
  quest.inLog = true
  wow.data.quests[q] = quest
  wow.fire("QUEST_ACCEPTED", q)
end

function mock.turnIn(wow, q)
  wow.fire("QUEST_TURNED_IN", q, 0, 0)
end

-- Moves the clock by whole days without running the timers in between, then lets the ticker run once.
function mock.days(wow, n)
  wow.state.epoch = wow.state.epoch + n * mock.DAY
  wow.advance(60)
end

-- A calm neutral beast as the new target; fields override the fixture (reaction, combat, dead, ...).
function mock.target(wow, fields)
  local target = { guid = "Creature-0-1-1-1-3233-000000001", name = "Plainstrider", reaction = 4, combat = false,
                   creatureType = "Beast", creatureTypeID = 1, health = 100, healthMax = 100 }
  for k, v in pairs(fields or {}) do
    if v == mock.NONE then target[k] = nil else target[k] = v end
  end
  wow.unit("target", target)
  wow.fire("PLAYER_TARGET_CHANGED")
  return target
end

function mock.critter(wow, fields)
  local target = { name = "Hare", creatureType = "Critter", creatureTypeID = 8 }
  for k, v in pairs(fields or {}) do target[k] = v end
  return mock.target(wow, target)
end

-- Both enter combat in one server update: UNIT_FLAGS for the target comes before PLAYER_REGEN_DISABLED.
function mock.engage(wow, target)
  target.combat = true
  wow.state.inCombat = true
  wow.fire("UNIT_FLAGS", "target")
  wow.combat(true)
end

function mock.die(wow, target, event)
  target.dead, target.health = true, 0
  wow.fire(event or "UNIT_HEALTH", "target")
end

-- Engage, the target dies, combat ends.
function mock.fight(wow, target)
  mock.engage(wow, target)
  mock.die(wow, target)
  wow.combat(false)
end

function mock.count(char, kind)
  local n = 0
  for _, entry in ipairs(char.log) do
    if entry.k == kind then n = n + 1 end
  end
  return n
end

local CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }

-- The event weights of 7.2 summed from the log alone, without decay or time-based inputs. The side held
-- per conflict follows the alliance and violation entries; a turn-in sees the side held before it,
-- because the entries it causes come after it in the log.
function mock.replay(ns, char, data)
  local sideOf = {}
  for _, conflict in ipairs(data.list) do
    for _, side in ipairs({ "A", "B" }) do
      for _, q in ipairs(conflict[side].quests) do sideOf[q] = { id = conflict.id, side = side } end
    end
  end
  local held = {}
  local axes = { fidelity = 0, habitat = 0, mercy = 0 }
  for _, e in ipairs(char.log) do
    if e.k == "alliance" or e.k == "violation" then
      held[e.c] = e.side
    end
    if e.k == "quest.turnin" then
      local hit = sideOf[e.q]
      if hit and held[hit.id] == hit.side then axes.fidelity = axes.fidelity + 2 end
      if CAPITALS[ns.Where.Zone(e.m) or 0] then axes.habitat = axes.habitat - 1 end
    elseif e.k == "quest.abandon" then
      axes.fidelity = axes.fidelity - 2
    elseif e.k == "violation" then
      axes.fidelity = axes.fidelity + (e.o == 1 and -15 or -25)
    elseif e.k == "rest.camp" or e.k == "rest.bedroll" then
      axes.habitat = axes.habitat + 6
    elseif e.k == "kill.neutral" then
      axes.mercy = axes.mercy - 3
    elseif e.k == "kill.critter" then
      axes.mercy = axes.mercy - 2
    end
  end
  for axis, v in pairs(axes) do axes[axis] = math.max(-100, math.min(100, v)) end
  return axes
end

-- A registered test check by id: ok, detail.
function mock.check(ns, id)
  for _, c in ipairs(ns.Test.checks) do
    if c.id == id then return c.fn() end
  end
  error("no test check " .. id)
end

return mock

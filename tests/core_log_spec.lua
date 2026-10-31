local wow = require("tests.helpers.wow")

local GUID = "Player-1-00000001"
local DAY = 86400

describe("Core Log", function()
  local ns, Log, M, added

  before_each(function()
    wow.reset()
  end)

  local function boot(log, seq, chapters)
    if log then
      wow.saved({ schema = 1, created = 1, chars = { [GUID] = {
        guid = GUID, seq = seq or #log, log = log, chapters = chapters or {}, zones = {}, stats = {},
        state = { inGroup = false, senders = {} },
      } } })
    end
    ns = wow.load()
    Log = ns.Log
    M = ns:NewModule("Alpha", { locale = "ALPHA" })
    function M:OnInitialize()
      Log:RegisterKind("test.keep", { fields = { "v" }, keep = true })
      Log:RegisterKind("test.plain", { fields = { "v" } })
      Log:RegisterKind("contact", { fields = { "p" }, keep = true })
      Log:RegisterKind("peer", { fields = { "p", "a" }, keep = true })
      Log:RegisterKind("test.shown", { fields = { "v" }, render = function() return "shown" end })
      Log:RegisterKind("test.some", { fields = { "v" }, shown = function(e) return e.v == 1 end,
                                      render = function(e) if e.v == 1 then return "some" end end })
    end
    function M:OnEnable()
      self:Subscribe("LOG_ADDED", function(_, _, entry, char) added[#added + 1] = { entry = entry, char = char } end)
    end
    added = {}
    wow.login()
  end

  local function entries(count, kind, age, from)
    local list = {}
    for i = 1, count do
      list[i] = { n = (from or 0) + i, t = time() - (age or 0), k = kind }
    end
    return list
  end

  local function kinds(char)
    local c = {}
    for _, e in ipairs(char.log) do c[e.k] = (c[e.k] or 0) + 1 end
    return c
  end

  it("numbers entries per character and stamps time, kind and location", function()
    boot()
    wow.state.map = 1443
    wow.state.pos = { x = 0.123, y = 0.456 }
    local a = Log:Add("test.plain", { v = 1 })
    local b = Log:Add("test.plain", { v = "x" }, { noWhere = true })
    assert.same({ n = 1, t = time(), k = "test.plain", v = 1, m = 1443, x = 12, y = 46 }, a)
    assert.same({ n = 2, t = time(), k = "test.plain", v = "x" }, b)
    assert.equal(2, Log:Seq(ns.DB:Char()))
    assert.equal(2, Log:Count(ns.DB:Char()))
    assert.equal(b, added[2].entry)
    assert.equal(ns.DB:Char(), added[2].char)
  end)

  it("writes nothing before the ready flag", function()
    boot()
    ns.ready = false
    assert.is_nil(Log:Add("test.plain", {}))
    assert.equal(0, ns.DB:Char().seq)
  end)

  it("drops unknown kinds, and raises in debug mode", function()
    boot()
    assert.is_nil(Log:Add("nope", {}))
    ns.debug = true
    assert.has_error(function() Log:Add("nope", {}) end)
  end)

  it("strips reserved keys, and raises in debug mode", function()
    boot()
    local e = Log:Add("test.plain", { n = 99, t = 1, k = "x", m = 5, x = 1, y = 1, i = 3, v = 2 }, { noWhere = true })
    assert.same({ n = 1, t = time(), k = "test.plain", v = 2 }, e)
    ns.debug = true
    assert.has_error(function() Log:Add("test.plain", { n = 5 }) end)
    assert.equal(1, ns.DB:Char().seq)
  end)

  it("drops entries with a secret or non-plain field, counts and reports once per kind", function()
    boot()
    assert.is_nil(Log:Add("test.plain", { v = wow.secret(1) }))
    assert.is_nil(Log:Add("test.plain", { v = {} }))
    assert.is_nil(Log:Add("test.plain", wow.secret({})))
    assert.is_nil(Log:Add("test.keep", { v = wow.secret("x") }))
    local char = ns.DB:Char()
    assert.equal(0, char.seq)
    assert.equal(4, char.stats["Core.secretDropped"])
    assert.equal(2, #wow.errors)
    assert.same({}, added)
  end)

  it("counts but never reports drops of a quiet kind", function()
    boot()
    Log:RegisterKind("test.quiet", { fields = { "v" }, quiet = true })
    assert.is_nil(Log:Add("test.quiet", { v = wow.secret(1) }))
    assert.equal(1, ns.DB:Char().stats["Core.secretDropped"])
    assert.same({}, wow.errors)
  end)

  it("iterates ascending ranges by sequence number; compacted entries are absent", function()
    local log = {}
    for _, n in ipairs({ 1, 2, 5, 6, 9 }) do log[#log + 1] = { n = n, t = time(), k = "test.plain" } end
    boot(log, 9)
    local char = ns.DB:Char()
    local function ns_of(from, to)
      local out = {}
      for e in Log:Iter(char, from, to) do out[#out + 1] = e.n end
      return out
    end
    assert.same({ 1, 2, 5, 6, 9 }, ns_of())
    assert.same({ 2, 5, 6 }, ns_of(2, 6))
    assert.same({ 5, 6, 9 }, ns_of(3))
    assert.same({}, ns_of(10))
    assert.same({}, ns_of(3, 4))
    assert.same({}, ns_of(1, 0))
  end)

  it("finds the last entry of a kind", function()
    boot()
    Log:Add("test.plain", { v = 1 })
    Log:Add("test.keep", { v = 2 })
    Log:Add("test.plain", { v = 3 })
    assert.equal(3, Log:Last(ns.DB:Char(), "test.plain").v)
    assert.equal(2, Log:Last(ns.DB:Char(), "test.keep").v)
    assert.is_nil(Log:Last(ns.DB:Char(), "contact"))
  end)

  describe("compaction", function()
    it("runs after an Add takes the log above 4,000 and keeps keep kinds", function()
      boot()
      local char = ns.DB:Char()
      char.log = entries(3000, "test.plain")
      for i, e in ipairs(entries(1000, "test.keep", 0, 3000)) do char.log[3000 + i] = e end
      char.seq = 4000
      local compacted = 0
      M:Subscribe("LOG_COMPACTED", function() compacted = compacted + 1 end)
      Log:Add("test.plain", { v = 1 })
      assert.equal(4001, #ns.DB:Char().log)
      Log:Add("test.plain", { v = 2 })
      wow.advance(0)
      char = ns.DB:Char()
      assert.equal(1, compacted)
      assert.equal(3000, #char.log)
      assert.same({ ["test.keep"] = 1000, ["test.plain"] = 2000 }, kinds(char))
      assert.equal(1003, char.log[1].n)
      assert.equal(4002, char.seq)
      assert.equal(4003, Log:Add("test.plain", {}).n)
    end)

    it("waits for combat to end", function()
      boot()
      ns.DB:Char().log = entries(4000, "test.plain")
      ns.DB:Char().seq = 4000
      wow.combat(true)
      Log:Add("test.plain", {})
      wow.advance(0)
      assert.equal(4001, #ns.DB:Char().log)
      wow.combat(false)
      assert.equal(3000, #ns.DB:Char().log)
    end)

    it("removes non-keep entries older than 180 days at login", function()
      local log = entries(10, "test.plain", 181 * DAY)
      for i, e in ipairs(entries(5, "test.keep", 400 * DAY, 10)) do log[10 + i] = e end
      for i, e in ipairs(entries(5, "test.plain", 179 * DAY, 15)) do log[15 + i] = e end
      boot(log, 20, { { no = 1, from = 1, to = 20, closed = time() } })
      local char = ns.DB:Char()
      assert.same({ ["test.keep"] = 5, ["test.plain"] = 5 }, kinds(char))
      assert.equal(11, char.log[1].n)
      assert.same({ no = 1, from = 1, to = 20, closed = time() }, char.chapters[1])
    end)

    local function pusher(log)
      local n = 0
      return function(count, kind, fields)
        for _ = 1, count do
          n = n + 1
          log[n] = { n = n, t = time(), k = kind }
          for key, v in pairs(fields or {}) do log[n][key] = v end
        end
        return n
      end
    end

    it("drops the oldest peer and then contact entries first when keep kinds exceed 2,000", function()
      local log = {}
      local push = pusher(log)
      push(1500, "contact")
      push(400, "test.keep")
      push(300, "peer")
      local n = push(100, "test.plain")
      boot(log, n, { { no = 1, from = 1, to = n, closed = time() } })
      local char = ns.DB:Char()
      assert.same({ contact = 1500, ["test.keep"] = 400, peer = 100, ["test.plain"] = 100 }, kinds(char))
      assert.equal(1, char.log[1].n)
      assert.equal(2101, char.log[1901].n)

      wow.reset()
      log = {}
      push = pusher(log)
      push(1800, "contact")
      push(100, "peer")
      push(300, "test.keep")
      n = push(10, "test.plain")
      boot(log, n, { { no = 1, from = 1, to = n, closed = time() } })
      assert.same({ contact = 1700, ["test.keep"] = 300, ["test.plain"] = 10 }, kinds(ns.DB:Char()))
      assert.equal(101, ns.DB:Char().log[1].n)
    end)

    it("drops entries the chronicle never shows before older ones it shows", function()
      local log = {}
      local push = pusher(log)
      push(1000, "test.shown")
      push(500, "test.some", { v = 1 })
      push(1000, "test.some", { v = 2 })
      push(500, "test.keep")
      local n = push(1500, "test.plain")
      boot(log, n, { { no = 1, from = 1, to = n, closed = time() } })
      local char = ns.DB:Char()
      assert.equal(3000, #char.log)
      assert.same({ ["test.shown"] = 1000, ["test.some"] = 500, ["test.keep"] = 500, ["test.plain"] = 1000 },
        kinds(char))
      assert.equal(1, char.log[1].n)
      assert.equal(3501, char.log[2001].n)
      assert.is_true(Log:Shown({ k = "test.shown" }))
      assert.is_true(Log:Shown({ k = "test.some", v = 1 }))
      assert.is_false(Log:Shown({ k = "test.some", v = 2 }))
      assert.is_false(Log:Shown({ k = "test.plain" }))
      assert.is_false(Log:Shown({ k = "nope" }))
      assert.is_true(Log:Shown({ k = "zone", z = 1443, first = true }))
      assert.is_false(Log:Shown({ k = "zone", z = 1443 }))
      assert.is_false(Log:Shown({ k = "gold", src = "loot", c = 5 }))
    end)

    it("then drops the oldest shown entries", function()
      local log = {}
      local push = pusher(log)
      push(500, "test.plain")
      push(3000, "test.shown")
      local n = push(600, "test.keep")
      boot(log, n, { { no = 1, from = 1, to = n, closed = time() } })
      local char = ns.DB:Char()
      assert.same({ ["test.shown"] = 2400, ["test.keep"] = 600 }, kinds(char))
      assert.equal(1101, char.log[1].n)
    end)

    it("ages entries by the server clock, so a system date set ahead deletes nothing", function()
      local log = entries(10, "test.plain", 10 * DAY)
      wow.stub("time", function() return math.floor(wow.state.epoch) + 365 * DAY end)
      boot(log, 10, { { no = 1, from = 1, to = 10, closed = 1 } })
      assert.equal(10, #ns.DB:Char().log)
    end)

    it("never ages an entry beyond one written before it, so a clock set back deletes nothing", function()
      -- n 1..5 are 10 days old and n 6..10 a session stamped 400 days back by a wrong clock: all stay. Entries
      -- 200 days old by their own date and by every entry before them still go.
      local log = entries(5, "test.plain", 10 * DAY)
      for i, e in ipairs(entries(5, "test.plain", 400 * DAY, 5)) do log[5 + i] = e end
      boot(log, 10, { { no = 1, from = 1, to = 10, closed = time() } })
      assert.equal(10, #ns.DB:Char().log)

      wow.reset()
      log = entries(5, "test.plain", 200 * DAY)
      for i, e in ipairs(entries(5, "test.plain", 0, 5)) do log[5 + i] = e end
      boot(log, 10, { { no = 1, from = 1, to = 10, closed = time() } })
      assert.equal(5, #ns.DB:Char().log)
      assert.equal(6, ns.DB:Char().log[1].n)
    end)

    it("does not disturb an Iter in progress", function()
      boot(entries(2900, "test.plain"), 2900, { { no = 1, from = 1, to = 2900, closed = time() } })
      local char = ns.DB:Char()
      local seen = 0
      for _ in Log:Iter(char) do
        seen = seen + 1
        if seen == 10 then
          for i = 1, 600 do char.log[#char.log + 1] = { n = 2900 + i, t = time(), k = "test.plain" } end
          char.seq = 3500
          Log:Compact(char)
        end
      end
      assert.equal(3500, seen)
      assert.equal(3000, #char.log)
      assert.equal(501, char.log[1].n)
    end)
  end)

  -- The mock's skew moves the system clock (time(), date()) away from the realm's (GetServerTime).
  describe("clocks", function()
    local function play(sessions, kind)
      for _ = 1, sessions do
        ns.Log:Add(kind, {})
        ns.Log:Add(kind, {})
        ns = wow.reload()
      end
      return ns.DB:Char()
    end

    it("stamps entries and chapters by the realm's clock, the one that ages them", function()
      wow.state.skew = -200 * DAY
      boot()
      local entry = Log:Add("test.plain", {})
      assert.equal(GetServerTime(), entry.t)
      assert.equal(GetServerTime(), Log:CloseChapter().closed)
    end)

    it("closes no chapter at every login while the system clock runs 8 days behind the realm", function()
      wow.state.skew = -8 * DAY
      boot()
      local char = play(4, "death")
      assert.same({}, char.chapters)
      assert.equal(8, #char.log)
    end)

    it("deletes nothing a session wrote while the system clock runs 181 days behind or ahead", function()
      for _, skew in ipairs({ -181 * DAY, 400 * DAY }) do
        wow.reset()
        wow.state.skew = skew
        boot()
        local char = play(3, "death")
        assert.equal(6, #char.log)
        assert.same({}, char.chapters)
      end
    end)
  end)

  describe("chapters", function()
    it("returns nil for an empty open chapter", function()
      boot()
      assert.is_nil(Log:CloseChapter({}))
    end)

    it("closes the open chapter with its record and members", function()
      boot()
      wow.state.map = 1443
      wow.state.pos = { x = 0.5, y = 0.5 }
      local closed, recordAtAdd
      M:Subscribe("CHAPTER_CLOSED", function(_, _, chapter, members) closed = { chapter, members } end)
      M:Subscribe("LOG_ADDED", function(_, _, entry, char)
        if entry.k == "chapter" then recordAtAdd = char.chapters[entry.no] end
      end)
      Log:Add("test.plain", {})
      Log:Add("test.plain", {})
      local chapter = Log:CloseChapter({ "Player-1-00000002" })
      assert.same({ no = 1, from = 1, to = 3, closed = time(), m = 1443, x = 50, y = 50 }, chapter)
      assert.equal(chapter, recordAtAdd)
      assert.same({ chapter, { "Player-1-00000002" } }, closed)
      assert.same({ n = 3, t = time(), k = "chapter", no = 1, m = 1443, x = 50, y = 50 }, ns.DB:Char().log[3])
      assert.is_nil(Log:CloseChapter())
      Log:Add("test.plain", {})
      local second = Log:CloseChapter(nil, { auto = true })
      assert.same({ no = 2, from = 4, to = 5, closed = time(), m = 1443, x = 50, y = 50, auto = true }, second)
      assert.same({}, closed[2])
    end)

    it("closes automatically at login after more than 1,000 entries", function()
      boot(entries(1001, "test.plain"))
      local char = ns.DB:Char()
      assert.same({ no = 1, from = 1, to = 1002, closed = time(), auto = true }, char.chapters[1])
      assert.is_true(char.log[#char.log].auto)
    end)

    it("does not close at login with 1,000 recent entries", function()
      boot(entries(1000, "test.plain"))
      assert.same({}, ns.DB:Char().chapters)
    end)

    it("closes automatically at login when the open chapter began more than 7 days ago", function()
      local log = entries(3, "test.plain", 8 * DAY)
      boot(log)
      assert.equal(4, ns.DB:Char().chapters[1].to)
    end)

    it("counts only the open chapter for the automatic close", function()
      local log = entries(5, "test.plain", 8 * DAY)
      for i, e in ipairs(entries(3, "test.plain", 0, 5)) do log[5 + i] = e end
      boot(log, 8, { { no = 1, from = 1, to = 5, closed = time() - 8 * DAY } })
      assert.equal(1, #ns.DB:Char().chapters)
    end)
  end)
end)

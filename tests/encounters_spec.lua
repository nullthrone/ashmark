local wow = require("tests.helpers.wow")
local mock = require("tests.helpers.encounters_mock")

local ME, ALT = mock.ME, mock.ALT
local THALEN, MIRA, KEL, ORLA = mock.guid("thalen"), mock.guid("mira"), mock.guid("kel"), mock.guid("orla")
local ELWYNN, DESOLACE = 1429, 1443

describe("Encounters", function()
  local ns, M, topics

  local function boot(opts)
    opts = opts or {}
    local setup = opts.setup
    opts.setup = function(n)
      ns, M = n, n.Encounters
      topics = mock.listen(n, { "CONTACT_UPDATED", "GROUP_SESSION_ENDED" }, {})
      if setup then setup(n) end
    end
    mock.boot(wow, opts)
    return ns.DB:Char()
  end

  local function relog(gap, opts)
    opts = opts or {}
    local setup = opts.setup
    opts.setup = function(n)
      ns, M = n, n.Encounters
      topics = mock.listen(n, { "CONTACT_UPDATED", "GROUP_SESSION_ENDED" }, {})
      if setup then setup(n) end
    end
    mock.relog(wow, gap, opts)
    return ns.DB:Char()
  end

  local function last(kind)
    return ns.Log:Last(ns.DB:Char(), kind)
  end

  local function render(entry, ctx)
    return ns.Chronicle:Render(entry, ctx or { char = ns.DB:Char(), own = true })
  end

  local function named(kind)
    local out = {}
    for _, t in ipairs(topics) do
      if t[1] == kind then out[#out + 1] = t[2] end
    end
    return out
  end

  local function lines()
    local out = {}
    for _, line in ipairs(wow.chat) do
      local text = line:match("^|c%x+Ashmark|r: (.*)$")
      if text and not text:find("A new record", 1, true) then out[#out + 1] = text end
    end
    return out
  end

  before_each(function()
    wow.reset()
    wow.state.map = ELWYNN
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  describe("sessions", function()
    it("open on GROUP_CHANGED(true) and end on GROUP_CHANGED(false)", function()
      local char = boot()
      local t0 = time()
      mock.join(wow, "thalen", "mira")
      local session = M:OpenSession()
      assert.equal(char.state.group, session)
      assert.same({ THALEN, MIRA }, session.members)
      assert.same({ ELWYNN }, session.maps)
      assert.equal(t0 + 1, session.start)
      assert.equal("Thalen", session.people[THALEN].name)
      assert.is_nil(session.people[THALEN].unit)
      wow.advance(60)
      mock.leave(wow)
      assert.is_nil(char.state.group)
      assert.is_nil(M:OpenSession())
      local stored = char.sessions[session.id]
      assert.equal(session, stored)
      assert.is_nil(stored.people)
      assert.equal(time(), stored.stop)
      assert.equal("travel", stored.e)
      assert.same({ "contact", "contact", "group.end" }, mock.kinds(char))
      local entry = last("group.end")
      assert.same({ session.id, 2, "travel" }, { entry.g, entry.size, entry.e })
      assert.is_nil(entry.inst)
      assert.same({ THALEN, MIRA }, named("CONTACT_UPDATED"))
      assert.same({ stored }, named("GROUP_SESSION_ENDED"))
    end)

    it("take members from every roster update while open", function()
      boot()
      mock.join(wow, "thalen")
      mock.join(wow, "thalen", "mira")
      mock.join(wow, "mira")
      local session = M:OpenSession()
      assert.same({ THALEN, MIRA }, session.members)
      assert.is_table(session.people[MIRA])
      mock.leave(wow)
      assert.equal(2, last("group.end").size)
    end)

    it("open only once and end only an open session", function()
      boot()
      mock.join(wow, "thalen")
      local id = M:OpenSession().id
      ns.Bus:Fire("GROUP_CHANGED", true)
      assert.equal(id, M:OpenSession().id)
      mock.leave(wow)
      ns.Bus:Fire("GROUP_CHANGED", false)
      assert.same({ "contact", "group.end" }, mock.kinds(ns.DB:Char()))
    end)

    it("add zones and instances as context", function()
      boot()
      mock.join(wow, "thalen")
      wow.state.map = DESOLACE
      wow.fire("ZONE_CHANGED_NEW_AREA")
      wow.state.map = 9001
      wow.state.instance = { name = "Test Dungeon", instanceID = 389 }
      wow.fire("PLAYER_ENTERING_WORLD", false, false)
      wow.fire("PLAYER_ENTERING_WORLD", false, false)
      local session = M:OpenSession()
      assert.same({ ELWYNN, DESOLACE }, session.maps)
      assert.same({ 389 }, session.inst)
      wow.state.instance = nil
      wow.state.map = ELWYNN
      wow.fire("PLAYER_ENTERING_WORLD", false, false)
      wow.fire("ZONE_CHANGED_NEW_AREA")
      mock.leave(wow)
      assert.equal(389, last("group.end").inst)
      local rec = M:Met(THALEN, ns.DB:Char())
      assert.same({ ELWYNN, 389 }, { rec.lastPlace, rec.lastInstance })
    end)

    it("snapshot no one inside an instance and catch up at the first roster update outside", function()
      wow.state.instance = { name = "Test Dungeon", instanceID = 389 }
      wow.state.map = 9001
      local char = boot()
      mock.join(wow, "thalen")
      local session = M:OpenSession()
      assert.same({ THALEN }, session.members)
      assert.same({}, session.people)
      assert.same({ 389 }, session.inst)
      mock.join(wow, "thalen", "kel")
      mock.join(wow, "thalen")
      assert.same({ THALEN, KEL }, session.members)
      wow.state.instance = nil
      wow.state.map = ELWYNN
      mock.join(wow, "thalen", "mira")
      assert.same({ THALEN, KEL, MIRA }, session.members)
      assert.is_table(session.people[THALEN])
      assert.is_table(session.people[MIRA])
      assert.is_nil(session.people[KEL])
      mock.leave(wow)
      assert.equal(3, last("group.end").size)
      assert.is_table(M:Contact(THALEN))
      assert.is_nil(M:Contact(KEL))
      assert.same({ "contact", "contact", "group.end" }, mock.kinds(char))
    end)

    it("take no snapshot during chat lockdown", function()
      boot()
      wow.state.chatLockdown = true
      mock.join(wow, "thalen")
      assert.same({}, M:OpenSession().people)
      wow.state.chatLockdown = false
      mock.roster(wow)
      assert.is_table(M:OpenSession().people[THALEN])
    end)

    it("keep at most 40 people", function()
      boot()
      for i = 1, 40 do
        wow.unit("raid" .. i, { guid = string.format("Player-1-1%07x", i), name = "Raider" .. i, classFile = "MAGE",
                                raceID = 1, sex = 2, faction = "Alliance", level = 20, isPlayer = true })
      end
      wow.unit("raid40", { guid = ME, name = "Aren", isPlayer = true })
      mock.roster(wow)
      local session = M:OpenSession()
      local function people()
        local n = 0
        for _ in pairs(session.people) do n = n + 1 end
        return n
      end
      assert.equal(39, #session.members)
      assert.equal(39, people())
      wow.unit("raid40", { guid = "Player-1-1fffffff", name = "Late", isPlayer = true })
      wow.unit("raid41", nil)
      mock.roster(wow)
      assert.equal(40, people())
      wow.unit("raid39", { guid = "Player-1-1ffffffe", name = "Later", isPlayer = true })
      mock.roster(wow)
      assert.equal(41, #session.members)
      assert.equal(40, people())
      assert.is_nil(session.people["Player-1-1ffffffe"])
    end)

    it("skip members whose GUID or name is secret", function()
      local char = boot()
      mock.join(wow, "thalen", { guid = wow.secret("Player-1-0000000e"), name = "Hidden", isPlayer = true },
        { guid = "Player-1-0000000f", name = wow.secret("Masked"), isPlayer = true })
      local session = M:OpenSession()
      assert.same({ THALEN, "Player-1-0000000f" }, session.members)
      assert.is_nil(session.people["Player-1-0000000f"])
      mock.leave(wow)
      assert.is_nil(M:Contact("Player-1-0000000f"))
      assert.equal(0, char.stats["Core.secretDropped"] or 0)
    end)

    it("record nothing while the module is off", function()
      local char = boot()
      ns.Settings:Set("Encounters.enabled", false)
      mock.join(wow, "thalen")
      assert.is_nil(M:OpenSession())
      mock.leave(wow)
      assert.same({}, mock.kinds(char))
    end)
  end)

  describe("outcome", function()
    local function outcome(during)
      boot()
      mock.session(wow, ns, { "thalen" }, during)
      return last("group.end").e
    end

    local function encounter(success)
      wow.fire("ENCOUNTER_END", 1084, "Onyxia", 1, 5, success)
    end

    it("is travel when nothing else happened", function()
      assert.equal("travel", outcome())
    end)

    it("is a wipe after ENCOUNTER_END with success 0", function()
      assert.equal("wipe", outcome(function() encounter(0) end))
    end)

    it("counts bosses and wipes and puts a boss before a wipe", function()
      local session
      assert.equal("boss", outcome(function(s)
        session = s
        encounter(0)
        encounter(1)
        encounter(0)
      end))
      assert.same({ 1, 2 }, { session.boss, session.wipe })
    end)

    it("ignores a secret success", function()
      assert.equal("travel", outcome(function() encounter(wow.secret(1)) end))
    end)

    it("is camp after a chapter closed with members, not without", function()
      assert.equal("travel", outcome(function() ns.Bus:Fire("CHAPTER_CLOSED", { no = 1 }, {}) end))
      assert.equal("camp", outcome(function() ns.Bus:Fire("CHAPTER_CLOSED", { no = 1 }, { THALEN }) end))
    end)

    it("puts camp after a wipe", function()
      assert.equal("wipe", outcome(function()
        ns.Bus:Fire("CHAPTER_CLOSED", { no = 1 }, { THALEN })
        encounter(0)
      end))
    end)

    it("is kick when the system says so, before everything else", function()
      assert.equal("kick", outcome(function()
        encounter(1)
        ns.Bus:Fire("CHAPTER_CLOSED", { no = 1 }, { THALEN })
        wow.fire("CHAT_MSG_SYSTEM", "Thalen has joined the group.")
        wow.fire("CHAT_MSG_SYSTEM", ERR_UNINVITE_YOU)
      end))
    end)

    it("misses a kick whose text is secret", function()
      assert.equal("travel", outcome(function() wow.fire("CHAT_MSG_SYSTEM", wow.secret(ERR_UNINVITE_YOU)) end))
    end)

    it("counts per contact and character", function()
      boot()
      mock.session(wow, ns, { "thalen" }, function() encounter(1) end)
      mock.session(wow, ns, { "thalen" }, function() encounter(0) end)
      mock.session(wow, ns, { "thalen" })
      mock.session(wow, ns, { "thalen" }, function() encounter(1) end)
      assert.same({ boss = 2, wipe = 1, travel = 1 }, M:Met(THALEN, ns.DB:Char()).outcomes)
    end)

    it("leaves ENCOUNTER_END unregistered without the encounters capability", function()
      wow.invalidEvents.ENCOUNTER_END = true
      boot()
      assert.is_true(M.enabled)
      assert.is_false(ns.Compat.Has.encounters)
      assert.same({}, M.missingEvents or {})
      assert.equal(0, ns.Events:Count("ENCOUNTER_END"))
    end)
  end)

  describe("contacts", function()
    it("keep the latest snapshot and this character's meetings", function()
      local char = boot()
      local first = mock.session(wow, ns, { "thalen" })
      wow.advance(3600)
      local person = mock.PEOPLE.thalen
      local renamed = { guid = THALEN, name = "Thalen", surname = "Dawnward", classFile = "PALADIN", raceID = 1,
                        sex = 2, faction = "Alliance", level = 30, isPlayer = true }
      mock.join(wow, renamed)
      wow.state.map = DESOLACE
      wow.fire("ZONE_CHANGED_NEW_AREA")
      mock.leave(wow)
      local contact = M:Contact(THALEN)
      assert.same({ THALEN, "Thalen", "Dawnward", "PALADIN", person.raceID, 2, "Alliance", "Normal" },
        { contact.guid, contact.name, contact.surname, contact.class, contact.race, contact.sex, contact.faction,
          contact.ruleset })
      assert.equal("", contact.note)
      local rec = contact.byChar[ME]
      assert.same({ 2, first.start, time(), DESOLACE }, { rec.count, rec.first, rec.last, rec.lastPlace })
      assert.equal(2, #rec.sessions)
      assert.same({ "contact", "group.end", "group.end" }, mock.kinds(char))
      assert.equal(THALEN, last("contact").p)
    end)

    it("overwrite a snapshot field the newest snapshot lacks", function()
      boot()
      mock.session(wow, ns, { "thalen" })
      local plain = { guid = THALEN, name = "Thalen", classFile = "PALADIN", raceID = 1, sex = 2,
                      faction = "Alliance", level = 20, isPlayer = true }
      mock.session(wow, ns, { plain })
      assert.is_nil(M:Contact(THALEN).surname)
    end)

    it("keep the last 10 session ids", function()
      local char = boot()
      local ids = {}
      for i = 1, 11 do ids[i] = mock.session(wow, ns, { "thalen" }).id end
      local rec = M:Met(THALEN, char)
      assert.equal(11, rec.count)
      assert.same({ unpack(ids, 2, 11) }, rec.sessions)
    end)

    it("are shared by the account, with counts per character", function()
      boot()
      mock.session(wow, ns, { "thalen", "mira" })
      M:SetNote(THALEN, "Knows the Deadmines")
      local char = relog(600, { player = mock.BRYN })
      assert.equal(ALT, char.guid)
      assert.is_nil(M:Met(THALEN, char))
      mock.session(wow, ns, { "thalen" })
      mock.session(wow, ns, { "thalen" })
      local contact = M:Contact(THALEN)
      assert.same({ 1, 2 }, { contact.byChar[ME].count, contact.byChar[ALT].count })
      assert.equal("Knows the Deadmines", contact.note)
      assert.same({ "contact", "group.end", "group.end" }, mock.kinds(char))
      assert.is_nil(M:Met(MIRA, char))
      assert.is_table(M:Known(_G.AshmarkDB.chars[ME])[MIRA])
    end)

    it("answer Known, Met, Contact, Session and OpenSession", function()
      local char = boot()
      for _ = 1, 3 do mock.session(wow, ns, { "thalen", "mira" }) end
      mock.session(wow, ns, { "thalen", "kel" })
      local s = mock.session(wow, ns, { "thalen" })
      local known = M:Known(char)
      assert.same({ 5, 3, 1 }, { known[THALEN].count, known[MIRA].count, known[KEL].count })
      local recurring = M:Known(char, 3)
      assert.is_not_nil(recurring[THALEN])
      assert.is_not_nil(recurring[MIRA])
      assert.is_nil(recurring[KEL])
      assert.same({}, M:Known(char, 6))
      assert.same({}, M:Known(nil))
      assert.equal(known[KEL], M:Met(KEL, char))
      assert.is_nil(M:Met(ORLA, char))
      assert.is_nil(M:Met(KEL, nil))
      assert.is_nil(M:Contact(ORLA))
      assert.is_nil(M:Contact(nil))
      assert.equal(s, M:Session(char, s.id))
      assert.is_nil(M:Session(char, "nope"))
      assert.is_nil(M:Session(nil, s.id))
      mock.join(wow, "orla")
      local open = M:OpenSession()
      assert.equal(open, M:Session(char, open.id))
      assert.is_true(M:IsRecurring(known[MIRA]))
      assert.is_false(M:IsRecurring(known[KEL]))
    end)

    it("keep their services while the module is off and after a wipe of the others", function()
      local char = boot()
      mock.session(wow, ns, { "thalen" })
      ns.Settings:Set("Encounters.enabled", false)
      assert.is_table(M:Contact(THALEN))
      assert.equal(1, M:Known(char)[THALEN].count)
      _G.AshmarkDB.contacts = {}
      assert.is_nil(M:Contact(THALEN))
      assert.same({}, M:Known(char))
      _G.AshmarkDB.contacts = nil
      assert.same({}, M:Known(char))
      ns.Settings:Set("Encounters.enabled", true)
      mock.session(wow, ns, { "thalen" })
      assert.equal(1, M:Known(char)[THALEN].count)
    end)

    it("are capped at 2,000: never-recurring contacts without a note go, oldest last first", function()
      local now = wow.state.epoch
      local contacts = {}
      for i = 1, 2000 do
        local guid = string.format("Player-1-2%07x", i)
        contacts[guid] = mock.contact(guid, { name = "Old" .. i, byChar = { [ME] = mock.met(1, now - 10000 + i) } })
      end
      local noted, recurring = "Player-1-20000001", "Player-1-20000002"
      contacts[noted].note = "keep me"
      contacts[recurring].byChar = { [ALT] = mock.met(3, now - 20000) }
      wow.saved({ schema = 1, contacts = contacts })
      boot()
      mock.session(wow, ns, { "thalen", "mira" })
      local n = 0
      for _ in pairs(_G.AshmarkDB.contacts) do n = n + 1 end
      assert.equal(2000, n)
      assert.is_table(M:Contact(noted))
      assert.is_table(M:Contact(recurring))
      assert.is_nil(M:Contact("Player-1-20000003"))
      assert.is_nil(M:Contact("Player-1-20000004"))
      assert.is_table(M:Contact("Player-1-20000005"))
      assert.is_table(M:Contact(THALEN))
      assert.is_table(M:Contact(MIRA))
    end)

    it("leave sessions at 200, the oldest stop first", function()
      local now = wow.state.epoch
      local sessions = {}
      for i = 1, 200 do
        local id = string.format("%08x", i)
        sessions[id] = { id = id, start = now - 5000 + i, stop = now - 4000 + i, members = {}, maps = {}, inst = {},
                         boss = 0, wipe = 0, camp = false, kick = false, e = "travel" }
      end
      wow.saved({ schema = 1, chars = { [ME] = { sessions = sessions } } })
      local char = boot()
      local s = mock.session(wow, ns, { "thalen" })
      local n = 0
      for _ in pairs(char.sessions) do n = n + 1 end
      assert.equal(200, n)
      assert.is_nil(char.sessions["00000001"])
      assert.is_table(char.sessions["00000002"])
      assert.equal(s, char.sessions[s.id])
    end)
  end)

  describe("reload and login", function()
    it("resume a session after a /reload while the group stays", function()
      boot()
      mock.join(wow, "thalen", "mira")
      local id = M:OpenSession().id
      wow.reload()
      ns, M = wow.ns, wow.ns.Encounters
      local char = ns.DB:Char()
      local session = M:OpenSession()
      assert.equal(id, session.id)
      assert.same({ THALEN, MIRA }, session.members)
      assert.is_table(session.people[THALEN])
      assert.same({}, mock.kinds(char))
      assert.same({}, lines())
      mock.leave(wow)
      assert.same({ "contact", "contact", "group.end" }, mock.kinds(char))
      assert.equal(id, last("group.end").g)
    end)

    it("end a stale session after a long offline gap at the previous lastSeen", function()
      boot()
      mock.join(wow, "thalen")
      local start = M:OpenSession().start
      wow.advance(1200)
      local char = relog(3 * 86400, { party = {} })
      local stop = _G.AshmarkDB.chars[ME].lastSeen
      assert.is_true(stop >= start + 1200)
      assert.is_true(stop < time() - 86400)
      assert.is_nil(M:OpenSession())
      local entry = last("group.end")
      local stored = char.sessions[entry.g]
      assert.equal(stop, stored.stop)
      assert.equal(stop, M:Met(THALEN, char).last)
      assert.is_nil(entry.m)
      assert.same({ "contact", "group.end" }, mock.kinds(char))
      assert.equal(1, #named("GROUP_SESSION_ENDED"))
    end)

    it("stop a crashed session no earlier than it started", function()
      boot()
      mock.join(wow, "thalen")
      local start = M:OpenSession().start
      local char = relog(7200, { crash = true, party = {} })
      assert.equal(start, char.sessions[last("group.end").g].stop)
    end)

    it("end a stale session and open a new one for a different group", function()
      boot()
      mock.join(wow, "thalen")
      local old = M:OpenSession().id
      local char = relog(3600, { party = { "kel" } })
      assert.equal(old, last("group.end").g)
      local session = M:OpenSession()
      assert.is_not_nil(session)
      assert.is_not.equal(old, session.id)
      assert.same({ KEL }, session.members)
      assert.equal(time(), session.start)
      assert.same({ "contact", "group.end" }, mock.kinds(char))
    end)

    it("resume after a log-out in the same group and add who joined meanwhile", function()
      boot()
      mock.join(wow, "thalen")
      local id = M:OpenSession().id
      relog(60, { party = { "thalen", "mira" } })
      local session = M:OpenSession()
      assert.equal(id, session.id)
      assert.same({ THALEN, MIRA }, session.members)
    end)

    it("open a session at login inside a group", function()
      mock.party(wow, "thalen")
      local char = boot()
      local session = M:OpenSession()
      assert.same({ THALEN }, session.members)
      assert.is_true(char.state.inGroup)
    end)

    it("repair a stored session with missing fields", function()
      local group = { id = "0000beef", members = { THALEN }, boss = "x" }
      wow.saved({ schema = 1, chars = { [ME] = { state = { inGroup = true, group = group } } } })
      mock.party(wow, "thalen")
      boot()
      local session = M:OpenSession()
      assert.equal("0000beef", session.id)
      assert.same({ 0, 0, false }, { session.boss, session.wipe, session.kick })
      wow.fire("ENCOUNTER_END", 1, "x", 1, 5, 1)
      mock.leave(wow)
      assert.equal("boss", last("group.end").e)
    end)

    it("drop a stored session without an id", function()
      wow.saved({ schema = 1, chars = { [ME] = { state = { inGroup = false, group = { members = {} } } } } })
      local char = boot()
      assert.is_nil(char.state.group)
      assert.same({}, mock.kinds(char))
    end)
  end)

  describe("recognition", function()
    it("prints one line for each of three known members, then one for the rest", function()
      boot()
      mock.session(wow, ns, { "thalen", "mira", "kel", "orla" })
      wow.state.map = DESOLACE
      wow.fire("ZONE_CHANGED_NEW_AREA")
      mock.join(wow, "thalen", "mira", "kel", "orla")
      assert.same({
        "You know Thalen Brightwood: met 1×, last in Elwynn Forest.",
        "You know Mira: met 1×, last in Elwynn Forest.",
        "You know Kel: met 1×, last in Elwynn Forest.",
        "…and 1 more you know.",
      }, lines())
    end)

    it("names only known members who just joined", function()
      boot()
      mock.session(wow, ns, { "thalen" })
      mock.join(wow, "mira")
      assert.same({}, lines())
      mock.join(wow, "mira", "thalen")
      mock.join(wow, "mira", "thalen", "kel")
      assert.same({ "You know Thalen Brightwood: met 1×, last in Elwynn Forest." }, lines())
    end)

    it("stays quiet inside instances and for members met only by another character", function()
      boot()
      mock.session(wow, ns, { "thalen" })
      wow.state.instance = { instanceID = 389 }
      mock.join(wow, "thalen")
      mock.leave(wow)
      wow.state.instance = nil
      relog(60, { player = mock.BRYN })
      mock.join(wow, "thalen")
      assert.same({}, lines())
    end)

    it("leaves out the place when none is known", function()
      wow.state.map = nil
      boot()
      mock.session(wow, ns, { "thalen" })
      mock.join(wow, "thalen")
      assert.same({ "You know Thalen Brightwood: met 1×." }, lines())
    end)

    it("respects the chat-lines setting", function()
      boot()
      mock.session(wow, ns, { "thalen" })
      ns.Settings:Set("Core.chatLines", false)
      mock.join(wow, "thalen")
      assert.same({}, lines())
    end)
  end)

  describe("chronicle", function()
    it("names up to three members from contacts and counts the rest", function()
      boot()
      mock.session(wow, ns, { "thalen", "mira" })
      assert.equal("You met Mira for the first time.", render(last("contact")))
      assert.equal("You travelled with Thalen and Mira.", render(last("group.end")))
      mock.session(wow, ns, { "thalen" })
      assert.equal("You travelled with Thalen.", render(last("group.end")))
      mock.session(wow, ns, { "thalen", "mira", "kel", "orla" })
      assert.equal("You travelled with Thalen, Mira, Kel and one other.", render(last("group.end")))
    end)

    it("counts members without a contact as others or strangers", function()
      boot()
      wow.state.instance = { instanceID = 389 }
      mock.join(wow, "kel", "orla")
      mock.leave(wow)
      assert.equal("You travelled with 2 strangers.", render(last("group.end")))
      mock.session(wow, ns, { "mira" })
      assert.equal("You travelled with a stranger.", render(last("group.end")))
      wow.state.instance = nil
      mock.session(wow, ns, { "thalen" })
      wow.state.instance = { instanceID = 389 }
      mock.session(wow, ns, { "thalen", "kel", "orla" })
      assert.equal("You travelled with Thalen and 2 others.", render(last("group.end")))
    end)

    it("words the sentence by outcome", function()
      boot()
      local cases = {
        { function() wow.fire("ENCOUNTER_END", 1, "x", 1, 5, 1) end, "You fought beside Thalen and won." },
        { function() wow.fire("ENCOUNTER_END", 1, "x", 1, 5, 0) end, "You fought beside Thalen and fell." },
        { function() ns.Bus:Fire("CHAPTER_CLOSED", { no = 1 }, { THALEN }) end,
          "You shared a campfire with Thalen." },
        { function() wow.fire("CHAT_MSG_SYSTEM", ERR_UNINVITE_YOU) end,
          "You were sent away from the group of Thalen." },
      }
      for _, case in ipairs(cases) do
        mock.session(wow, ns, { "thalen" }, case[1])
        assert.equal(case[2], render(last("group.end")))
      end
    end)

    it("adds a peer's archetype and origin", function()
      boot({ setup = function(n)
        mock.fiction(n, { [THALEN] = { guid = THALEN, archetype = "OATHKEEPER", origin = DESOLACE },
                          [MIRA] = { guid = MIRA, archetype = "WANDERER", origin = 0 },
                          [KEL] = { guid = KEL, archetype = "NOPE", origin = DESOLACE } })
      end })
      mock.session(wow, ns, { "thalen", "mira", "kel" })
      assert.equal("You travelled with Thalen (Oathkeeper from Desolace), Mira (Wanderer) and Kel.",
        render(last("group.end")))
    end)

    it("labels a peer's archetype in the form for the contact's sex", function()
      boot({ setup = function(n)
        local base = n.Locale:Base()
        base.PROFILE_OATHKEEPER_F, base.PROFILE_WANDERER_F = "Oathkeeper (f)", "Wanderer (f)"
        mock.fiction(n, { [THALEN] = { guid = THALEN, archetype = "OATHKEEPER", origin = DESOLACE },
                          [MIRA] = { guid = MIRA, archetype = "WANDERER", origin = 0 } })
      end })
      mock.session(wow, ns, { "thalen", "mira" })
      assert.equal("You travelled with Thalen (Oathkeeper from Desolace) and Mira (Wanderer (f)).",
        render(last("group.end")))
    end)

    it("uses the third person in the family chronicle", function()
      local char = boot()
      mock.session(wow, ns, { "thalen", "mira" })
      local ctx = { char = char, own = false }
      assert.equal("Aren travelled with Thalen and Mira.", render(last("group.end"), ctx))
      assert.equal("Aren met Mira for the first time.", render(last("contact"), ctx))
    end)

    it("falls back to the group's size when its session is gone, without calling known people strangers", function()
      local char = boot()
      local s = mock.session(wow, ns, { "thalen", "mira" })
      char.sessions[s.id] = nil
      assert.equal("You travelled with 2 companions.", render(last("group.end")))
      assert.equal("You travelled with a companion.", render({ k = "group.end", g = "gone", size = 1, e = "travel" }))
      assert.equal("You travelled with strangers.", render({ k = "group.end", g = "gone", size = 0, e = "odd" }))
      assert.equal("You met someone for the first time.", render({ k = "contact", p = "Player-1-0" }))
    end)

    it("writes no second first meeting for a contact the store forgot", function()
      local char = boot()
      mock.session(wow, ns, { "thalen" })
      local entry = last("contact")
      _G.AshmarkDB.contacts[THALEN] = nil
      assert.equal("You met someone for the first time.", render(entry))
      mock.session(wow, ns, { "thalen", "mira" })
      assert.same({ "contact", "group.end", "contact", "group.end" }, mock.kinds(char))
      assert.equal(MIRA, last("contact").p)
      assert.equal("You met Thalen for the first time.", render(entry))
      assert.equal(1, M:Met(THALEN, char).count)
      relog(60, { player = mock.BRYN })
      mock.session(wow, ns, { "thalen" })
      assert.equal(THALEN, last("contact").p)
    end)

    it("joins the last name with ENC_LIST_AND_VOWEL when it begins with the sound /i/", function()
      boot({ setup = function(n) n.Locale:Base().ENC_LIST_AND_VOWEL = "{list} e {last}" end })
      local function member(i, name)
        return { guid = string.format("Player-1-3%07x", i), name = name, classFile = "MAGE", raceID = 1, sex = 3,
                 faction = "Alliance", level = 20, isPlayer = true }
      end
      local cases = {
        { "Iris", "Thalen e Iris" }, { "isolde", "Thalen e isolde" }, { "\195\141\195\177igo", "Thalen e Íñigo" },
        { "Hilda", "Thalen e Hilda" }, { "H\195\173a", "Thalen e Hía" }, { "Hierro", "Thalen and Hierro" },
        { "Hialmar", "Thalen and Hialmar" }, { "Mira", "Thalen and Mira" }, { "Helga", "Thalen and Helga" },
      }
      for i, case in ipairs(cases) do
        mock.session(wow, ns, { "thalen", member(i, case[1]) })
        assert.equal("You travelled with " .. case[2] .. ".", render(last("group.end")))
      end
      mock.session(wow, ns, { member(1, "Iris"), "thalen" })
      assert.equal("You travelled with Iris and Thalen.", render(last("group.end")))
    end)

    it("keeps one word for 'and' in English", function()
      boot()
      mock.session(wow, ns, { "thalen", { guid = "Player-1-30000001", name = "Iris", isPlayer = true } })
      assert.equal("You travelled with Thalen and Iris.", render(last("group.end")))
    end)

    it("keeps contact entries through compaction, not group.end entries", function()
      boot()
      assert.is_true(ns.Log:Kind("contact").keep)
      assert.is_falsy(ns.Log:Kind("group.end").keep)
    end)
  end)

  describe("notes", function()
    it("are trimmed, cut to 120 characters, stored and announced", function()
      local char = boot()
      mock.session(wow, ns, { "thalen" })
      topics = mock.listen(ns, { "CONTACT_UPDATED" }, {})
      assert.is_true(M:SetNote(THALEN, "  Tanked\nthe Deadmines  "))
      assert.equal("Tanked the Deadmines", M:Contact(THALEN).note)
      assert.same({ THALEN }, named("CONTACT_UPDATED"))
      M:SetNote(THALEN, string.rep("é", 130))
      assert.equal(string.rep("é", 120), M:Contact(THALEN).note)
      M:SetNote(THALEN, string.rep("a", 119) .. " b")
      assert.equal(string.rep("a", 119), M:Contact(THALEN).note)
      assert.is_false(M:SetNote(THALEN, wow.secret("x")))
      assert.is_false(M:SetNote(ORLA, "who?"))
      assert.equal(string.rep("a", 119), M:Contact(THALEN).note)
      assert.is_nil(char.log[#char.log].note)
    end)

    it("are edited in AshmarkDialog", function()
      local shown
      boot({ setup = function(n)
        n.UI.Dialog = { Show = function(_, opts) shown = opts end }
      end })
      mock.session(wow, ns, { "thalen" })
      M:SetNote(THALEN, "Old note")
      M:EditNote(THALEN)
      assert.equal("Your note on Thalen Brightwood:", shown.text)
      assert.same({ text = "Old note", max = 120 }, shown.edit)
      assert.equal("ENC_NOTE_SAVE", shown.accept)
      shown.onAccept("New note")
      assert.equal("New note", M:Contact(THALEN).note)
      shown = nil
      M:EditNote(ORLA)
      assert.is_nil(shown)
    end)
  end)

  describe("test check", function()
    it("reports the stores", function()
      boot()
      mock.session(wow, ns, { "thalen", "mira" })
      mock.join(wow, "kel")
      local check
      for _, c in ipairs(ns.Test.checks) do
        if c.id == "Encounters.records" then check = c.fn end
      end
      local ok, detail = check()
      assert.is_true(ok)
      assert.equal("contacts=2 known=2 recurring=0 sessions=1 open=1 members, 1 people kickText=true", detail)
    end)
  end)
end)

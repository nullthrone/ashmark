local _, ns = ...

-- Module 4 (7.4): the people this character groups with. A session runs from GROUP_CHANGED(true) to
-- GROUP_CHANGED(false); at its end every member snapshotted outside an instance becomes or updates a
-- contact. Contacts are keyed by GUID account-wide, with counts, dates and outcomes per character, and
-- never leave the client. The unit tooltip line lives in Tooltip.lua, the tab in UI/Tabs/Encounters.lua.
local M = ns:NewModule("Encounters", {
  optional = { "tooltipProcessor", "encounters" },
  locale = "ENC",
  default = true,
})

local Safe = ns.Safe
local L = ns.L

local MAX_CONTACTS = 2000
local MAX_SESSIONS = 200
local MAX_PEOPLE = 40
local SESSION_IDS = 10           -- session ids kept per contact and character
local NOTE_MAX = 120
local RECOGNISED = 3             -- chat lines before ENC_RECOGNISE_MORE
local NAMED = 3                  -- members named in the group.end sentence
local ROSTER_DELAY = 1

M.RECURRING = 3                  -- byChar.count of a recurring contact (ENC_RECURRING)

-- Fields of a contact's snapshot, and of a Person kept in session.people (5.3, without the unit token).
-- raceName is read in the client's locale, so both keep that locale with it (Names.Race, 5.7).
local SNAPSHOT = { "guid", "name", "surname", "class", "race", "raceName", "locale", "sex", "faction", "ruleset" }
local PERSON = { "guid", "name", "surname", "full", "class", "race", "raceName", "sex", "faction", "level",
                 "ruleset" }

local SENTENCES = {
  kick = "ENC_LOG_KICK", boss = "ENC_LOG_BOSS", wipe = "ENC_LOG_WIPE", camp = "ENC_LOG_CAMP",
  travel = "ENC_LOG_TRAVEL",
}

-- Stores ----------------------------------------------------------------------------

local function contacts()
  local db = AshmarkDB
  local all = type(db) == "table" and db.contacts
  if type(all) == "table" then return all end
end

local function contactStore()
  local all = contacts()
  if not all then
    all = {}
    AshmarkDB.contacts = all
  end
  return all
end

local function byChar(contact, charGuid)
  local list = type(contact) == "table" and contact.byChar
  local rec = type(list) == "table" and type(charGuid) == "string" and list[charGuid]
  if type(rec) == "table" then return rec end
end

local function openOf(char)
  local state = type(char) == "table" and char.state
  local session = type(state) == "table" and state.group
  if type(session) == "table" and type(session.id) == "string" and type(session.members) == "table" then
    return session
  end
end

-- Another unit's public service (3.8), looked up at call time; nil if the unit or the call is missing.
local function ask(unit, method, ...)
  local service = ns[unit]
  local ok, result = Safe.Call(service and service[method], service, ...)
  if ok then return result end
end

-- Public services (3.8) --------------------------------------------------------------

function M:Contact(guid)
  local all = contacts()
  local contact = all and type(guid) == "string" and all[guid]
  if type(contact) == "table" then return contact end
end

function M:Met(guid, char)
  return byChar(self:Contact(guid), type(char) == "table" and char.guid)
end

function M:Known(char, minCount)
  local out = {}
  local all, own = contacts(), type(char) == "table" and char.guid
  if not (all and type(own) == "string") then return out end
  local min = tonumber(minCount) or 1
  for guid, contact in pairs(all) do
    local rec = byChar(contact, own)
    if rec and type(rec.count) == "number" and rec.count >= min then out[guid] = rec end
  end
  return out
end

-- A stored session, or the open one when id names it.
function M:Session(char, id)
  if type(char) ~= "table" or id == nil then return nil end
  local stored = type(char.sessions) == "table" and char.sessions[id]
  if type(stored) == "table" then return stored end
  local open = openOf(char)
  if open and open.id == id then return open end
end

function M:OpenSession()
  return openOf(self:Char())
end

-- For this unit's tooltip, tab and renderers ----------------------------------------

function M:DisplayName(contact)
  local name = type(contact) == "table" and contact.name
  if type(name) ~= "string" or name == "" then return L.CORE_UNKNOWN_PLAYER end
  local surname = contact.surname
  if type(surname) == "string" and surname ~= "" then return name .. " " .. surname end
  return name
end

function M:IsRecurring(rec)
  return type(rec) == "table" and type(rec.count) == "number" and rec.count >= M.RECURRING
end

-- The archetype label Fiction holds for guid, in the form for the contact's sex (5.8), and the peer's origin
-- zone (or nil). A key without a label gives nothing.
function M:PeerLabel(guid)
  local peer = ask("Fiction", "Peer", guid)
  local key = type(peer) == "table" and type(peer.archetype) == "string" and "PROFILE_" .. peer.archetype
  if not (key and ns.Locale:Get(key)) then return nil end
  local contact = self:Contact(guid)
  local label = ns.Gender(key, contact and contact.sex)
  local origin = peer.origin
  return label, type(origin) == "number" and origin > 0 and origin or nil
end

local function colored(contact)
  local name = M:DisplayName(contact)
  local UI = ns.UI
  if UI and UI.ClassColored then return UI:ClassColored(name, contact.class) end
  return name
end

-- Place and group ---------------------------------------------------------------------

local function inInstance()
  local ok, inside = Safe.Call(IsInInstance)
  return ok and inside == true
end

local function instanceID()
  local ok, id = Safe.Call(function() return (select(8, GetInstanceInfo())) end)
  if ok and type(id) == "number" and id ~= 0 then return id end
end

-- Appends v unless it repeats the last value.
local function push(list, v)
  if v ~= nil and list[#list] ~= v then list[#list + 1] = v end
end

-- GUIDs of the other group members right now, in unit order, and the same as a set; secret ones are skipped.
-- The unit tokens come from Identity:Tokens, so a battleground's instance group yields no member (5.3).
local function groupGuids()
  local prefix, size = ns.Identity:Tokens("all")
  if not prefix then return {}, {} end
  local me = ns.playerGUID
  local list, set = {}, {}
  for i = 1, size do
    local guid = Safe.UnitGUID(prefix .. i)
    if guid and guid ~= me and not set[guid] then
      set[guid] = true
      list[#list + 1] = guid
    end
  end
  return list, set
end

-- Sessions -------------------------------------------------------------------------------

local function copyFields(source, keys)
  local fields = {}
  for _, key in ipairs(keys) do fields[key] = source[key] end
  return Safe.Clean(fields)
end

-- Up to MAX_PEOPLE Persons, refreshed on every snapshot; only outside instances and chat lockdown.
local function snapshot(session, index)
  local people, n = session.people, 0
  for _ in pairs(people) do n = n + 1 end
  for guid, person in pairs(ns.Identity:Group("all")) do
    local rec = (people[guid] or n < MAX_PEOPLE) and copyFields(person, PERSON)
    if rec then
      rec.locale = ns.Locale.active
      if not people[guid] then n = n + 1 end
      people[guid] = rec
      if not index[guid] then
        index[guid] = true
        session.members[#session.members + 1] = guid
      end
    end
  end
end

local function recogniseLine(contact, rec)
  local name = colored(contact)
  local place = rec.lastPlace and ns.Names.Map(rec.lastPlace)
  if place then return ns.Format(L.ENC_RECOGNISE, { name = name, count = rec.count, place = place }) end
  return ns.Format(L.ENC_RECOGNISE_NOPLACE, { name = name, count = rec.count })
end

-- One chat line for each of the first RECOGNISED known members among those just added, then one for the rest.
local function recognise(char, added)
  local chat = ns.UI and ns.UI.ChatLine
  if not chat then return end
  local shown, more = 0, 0
  for _, guid in ipairs(added) do
    local contact = M:Contact(guid)
    local rec = byChar(contact, char.guid)
    if rec and type(rec.count) == "number" and rec.count >= 1 then
      if shown < RECOGNISED then
        shown = shown + 1
        chat:Print(recogniseLine(contact, rec), "system")
      else
        more = more + 1
      end
    end
  end
  if more > 0 then chat:Print(ns.Format(L.ENC_RECOGNISE_MORE, { count = more }), "system") end
end

-- When the session opens and on every roster update: new members, the snapshot and the recognition line.
local function addMembers(session, char)
  local index = {}
  for _, guid in ipairs(session.members) do index[guid] = true end
  local added = {}
  for _, guid in ipairs((groupGuids())) do
    if not index[guid] then
      index[guid] = true
      session.members[#session.members + 1] = guid
      added[#added + 1] = guid
    end
  end
  if inInstance() then return end
  if not Safe.InLockdown() then snapshot(session, index) end
  if #added > 0 then recognise(char, added) end
end

local function newId(char)
  local stored = type(char.sessions) == "table" and char.sessions or {}
  local id = ns.Util.Token()
  for _ = 1, 10 do
    if stored[id] == nil then break end
    id = ns.Util.Token()
  end
  return id
end

-- The zone and instance the group forms in count as its first context.
local function open(char)
  local session = {
    id = newId(char), start = time(), members = {}, people = {}, maps = {}, inst = {},
    boss = 0, wipe = 0, camp = false, kick = false,
  }
  push(session.maps, ns.Where.Zone(ns.Where().m))
  if inInstance() then push(session.inst, instanceID()) end
  char.state.group = session
  addMembers(session, char)
  return session
end

-- A session from SavedVariables with every field in its type; nil if it cannot be one.
local function repair(session)
  if type(session) ~= "table" or type(session.id) ~= "string" then return nil end
  for _, key in ipairs({ "members", "people", "maps", "inst" }) do
    if type(session[key]) ~= "table" then session[key] = {} end
  end
  for _, key in ipairs({ "boss", "wipe" }) do
    if type(session[key]) ~= "number" then session[key] = 0 end
  end
  session.camp, session.kick = session.camp == true, session.kick == true
  if type(session.start) ~= "number" then session.start = time() end
  return session
end

local function outcome(session)
  if session.kick then return "kick" end
  if session.boss > 0 then return "boss" end
  if session.wipe > 0 then return "wipe" end
  if session.camp then return "camp" end
  return "travel"
end

local function contactOf(all, guid)
  local contact = all[guid]
  if type(contact) ~= "table" then
    contact = {}
    all[guid] = contact
  end
  if type(contact.note) ~= "string" then contact.note = "" end
  if type(contact.byChar) ~= "table" then contact.byChar = {} end
  return contact
end

local function sub(rec, key)
  if type(rec[key]) ~= "table" then rec[key] = {} end
  return rec[key]
end

-- GUIDs that this character's log already names in a `contact` entry (a keep kind).
local function loggedContacts(char)
  local set = {}
  for entry in ns.Log:Iter(char, 1) do
    if entry.k == "contact" and type(entry.p) == "string" then set[entry.p] = true end
  end
  return set
end

-- One member of an ending session: the snapshot, this character's record, the first-meeting entry.
-- logged() gives loggedContacts: a contact pruned from the store (4) and met again keeps its first
-- meeting in the log and gets no second one.
local function meet(char, session, guid, person, opts, logged)
  local snap = copyFields(person, SNAPSHOT)
  if not snap then return end
  local contact = contactOf(contactStore(), guid)
  for _, key in ipairs(SNAPSHOT) do contact[key] = snap[key] end
  local rec = contact.byChar[char.guid]
  local first = type(rec) ~= "table" and not logged()[guid]
  if type(rec) ~= "table" then
    rec = {}
    contact.byChar[char.guid] = rec
  end
  rec.count = (tonumber(rec.count) or 0) + 1
  rec.first = tonumber(rec.first) or session.start
  rec.last = session.stop
  rec.lastPlace, rec.lastInstance = session.maps[#session.maps], session.inst[#session.inst]
  local outcomes = sub(rec, "outcomes")
  outcomes[session.e] = (tonumber(outcomes[session.e]) or 0) + 1
  local ids = sub(rec, "sessions")
  ids[#ids + 1] = session.id
  while #ids > SESSION_IDS do table.remove(ids, 1) end
  if first then ns.Log:Add("contact", { p = guid }, opts) end
  M:Fire("CONTACT_UPDATED", guid)
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function stopOf(session)
  return type(session) == "table" and tonumber(session.stop) or -math.huge
end

-- At most MAX_SESSIONS per character; the oldest stop goes first (4).
local function pruneSessions(stored)
  local excess = count(stored) - MAX_SESSIONS
  if excess <= 0 then return end
  local ids = {}
  for id in pairs(stored) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b)
    local sa, sb = stopOf(stored[a]), stopOf(stored[b])
    if sa ~= sb then return sa < sb end
    return tostring(a) < tostring(b)
  end)
  for i = 1, excess do stored[ids[i]] = nil end
end

local function newest(contact)
  local latest = -math.huge
  for _, rec in pairs(type(contact) == "table" and type(contact.byChar) == "table" and contact.byChar or {}) do
    local last = type(rec) == "table" and tonumber(rec.last)
    if last and last > latest then latest = last end
  end
  return latest
end

-- A note or a recurring meeting for any character keeps a contact through pruning.
local function kept(contact)
  if type(contact) ~= "table" then return false end
  if type(contact.note) == "string" and contact.note ~= "" then return true end
  for _, rec in pairs(type(contact.byChar) == "table" and contact.byChar or {}) do
    if M:IsRecurring(rec) then return true end
  end
  return false
end

-- At most MAX_CONTACTS; contacts without note and never recurring go, oldest last first (4).
local function pruneContacts()
  local all = contacts()
  if not all then return end
  local excess = count(all) - MAX_CONTACTS
  if excess <= 0 then return end
  local candidates = {}
  for guid, contact in pairs(all) do
    if not kept(contact) then candidates[#candidates + 1] = { guid = guid, last = newest(contact) } end
  end
  table.sort(candidates, function(a, b)
    if a.last ~= b.last then return a.last < b.last end
    return tostring(a.guid) < tostring(b.guid)
  end)
  for i = 1, math.min(excess, #candidates) do all[candidates[i].guid] = nil end
end

-- Session end (7.4). A stale session, ended at login, writes its entries without the current location.
local function finish(char, session, stop, stale)
  session.stop = stop
  session.e = outcome(session)
  local opts = stale and { noWhere = true } or nil
  local set
  local function logged()
    set = set or loggedContacts(char)
    return set
  end
  for _, guid in ipairs(session.members) do
    local person = session.people[guid]
    if type(person) == "table" then meet(char, session, guid, person, opts, logged) end
  end
  ns.Log:Add("group.end", {
    g = session.id, size = #session.members, inst = session.inst[#session.inst], e = session.e,
  }, opts)
  session.people = nil
  if type(char.sessions) ~= "table" then char.sessions = {} end
  char.sessions[session.id] = session
  pruneSessions(char.sessions)
  char.state.group = nil
  pruneContacts()
  M:Fire("GROUP_SESSION_ENDED", session)
end

-- While the unit tokens name an instance group (a battleground), no member of the home group can be seen,
-- so the session stands until the home group itself ends.
local function stillThere(session)
  if not ns.Identity:Tokens("all") then return true end
  local _, present = groupGuids()
  for _, guid in ipairs(session.members) do
    if present[guid] then return true end
  end
  return false
end

-- Handlers -------------------------------------------------------------------------------

local function onGroupChanged(_, _, inGroup)
  local char = M:Char()
  if not (char and type(char.state) == "table") then return end
  local session = openOf(char)
  if inGroup then
    if not session then open(char) end
  elseif session then
    finish(char, session, time())
  end
end

local roster = M:Wrap("GROUP_ROSTER_UPDATE", function()
  local char = M:Char()
  local session = openOf(char)
  if session then addMembers(session, char) end
end)

local function onRoster()
  ns.Util.Debounce("Encounters.roster", ROSTER_DELAY, roster)
end

local function onLogAdded(_, _, entry, char)
  if entry.k ~= "zone" then return end
  local session = openOf(char)
  if session then push(session.maps, entry.z) end
end

local function onEnteringWorld()
  local session = openOf(M:Char())
  if session and inInstance() then push(session.inst, instanceID()) end
end

-- success is the fifth argument; a secret one counts neither way, and encounterName is never read.
local function onEncounterEnd(_, _, ...)
  local session = openOf(M:Char())
  if not session then return end
  local success = Safe.Value((select(5, ...)))
  if success == 1 then
    session.boss = session.boss + 1
  elseif success == 0 then
    session.wipe = session.wipe + 1
  end
end

local function onChapterClosed(_, _, _, members)
  local session = openOf(M:Char())
  if session and type(members) == "table" and #members > 0 then session.camp = true end
end

-- Where the text is secret (inside instances), kicks go unnoticed.
local function onSystemMessage(_, _, ...)
  local session = openOf(M:Char())
  if not session or session.kick then return end
  local msg = Safe.Value((...))
  if msg and type(ERR_UNINVITE_YOU) == "string" and msg == ERR_UNINVITE_YOU then session.kick = true end
end

-- Notes ------------------------------------------------------------------------------------

-- The first max UTF-8 characters of text, as SetMaxLetters counts them.
local function clip(text, max)
  local out = {}
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if #out >= max then break end
    out[#out + 1] = char
  end
  return table.concat(out)
end

function M:SetNote(guid, text)
  local contact = self:Contact(guid)
  text = Safe.Value(text)
  if not contact or ns.DB.readOnly or type(text) ~= "string" then return false end
  contact.note = ns.Util.Trim(clip(ns.Util.Trim((text:gsub("%c", " "))), NOTE_MAX))
  self:Fire("CONTACT_UPDATED", guid)
  return true
end

-- The note editor (7.4): AshmarkDialog with a single-line edit box.
function M:EditNote(guid)
  local contact = self:Contact(guid)
  local dialog = ns.UI and ns.UI.Dialog
  if not (contact and dialog) then return end
  dialog:Show({
    text = ns.Format(L.ENC_NOTE_PROMPT, { name = self:DisplayName(contact) }),
    edit = { text = contact.note, max = NOTE_MAX },
    accept = "ENC_NOTE_SAVE",
    onAccept = function(note) M:SetNote(guid, note) end,
  })
end

-- Chronicle ----------------------------------------------------------------------------------

local function memberText(guid)
  local contact = M:Contact(guid)
  local name = contact and contact.name
  if type(name) ~= "string" or name == "" then return nil end
  local archetype, origin = M:PeerLabel(guid)
  if not archetype then return name end
  if origin then
    return ns.Format(L.ENC_LOG_PEER, { who = name, archetype = archetype, place = ns.Names.Map(origin) })
  end
  return ns.Format(L.ENC_LOG_PEER_NOPLACE, { who = name, archetype = archetype })
end

local function joined(items)
  if #items == 1 then return items[1] end
  local last = items[#items]
  -- Spanish writes "e" for "y" before the sound /i/; every other ENC_LIST_AND_VOWEL repeats ENC_LIST_AND.
  return ns.Format(ns.Util.StartsWithSound(last, "i") and L.ENC_LIST_AND_VOWEL or L.ENC_LIST_AND, {
    list = table.concat(items, L.ENC_LIST_SEP, 1, #items - 1), last = last,
  })
end

local function strangers(n)
  if n == 1 then return L.ENC_LOG_STRANGER end
  if n > 1 then return ns.Format(L.ENC_LOG_STRANGERS, { count = n }) end
  return L.ENC_LOG_STRANGERS_ANY
end

-- Without the session (pruned, 4) the members are only a number, and some may have been contacts.
local function companions(n)
  if n == 1 then return L.ENC_LOG_COMPANION end
  if n > 1 then return ns.Format(L.ENC_LOG_COMPANIONS, { count = n }) end
  return strangers(n)
end

-- Up to NAMED members with a contact, then the rest as a number; without the session, only the size.
local function people(session, size)
  if not session then return companions(tonumber(size) or 0) end
  local members = session.members
  local named, rest = {}, 0
  for _, guid in ipairs(members) do
    local text = #named < NAMED and memberText(guid)
    if text then named[#named + 1] = text else rest = rest + 1 end
  end
  if #named == 0 then return strangers(#members) end
  if rest == 1 then
    named[#named + 1] = L.ENC_LOG_OTHER
  elseif rest > 1 then
    named[#named + 1] = ns.Format(L.ENC_LOG_OTHERS, { count = rest })
  end
  return joined(named)
end

local function renderGroupEnd(entry, ctx)
  local session = M:Session(ctx and ctx.char, entry.g)
  return ns.Chronicle:Text(SENTENCES[entry.e] or SENTENCES.travel, ctx, { people = people(session, entry.size) })
end

-- A first meeting is told while the contact is stored. Once the store forgets it (pruned, 4) the entry
-- stays, but says nothing rather than "You met someone"; /ashmark reset others removes the entry itself.
local function renderContact(entry, ctx)
  if not M:Contact(entry.p) then return nil end
  return ns.Chronicle:Text("ENC_LOG_CONTACT", ctx, { contact = ns.Names.Player(entry.p) })
end

-- Test check (7.10) ---------------------------------------------------------------------------

local function checkRecords()
  local char = M:Char()
  local known, recurring = 0, 0
  for _, rec in pairs(M:Known(char)) do
    known = known + 1
    if M:IsRecurring(rec) then recurring = recurring + 1 end
  end
  local session = openOf(char)
  local stored = char and type(char.sessions) == "table" and count(char.sessions) or 0
  return true, string.format("contacts=%d known=%d recurring=%d sessions=%d open=%s kickText=%s",
    count(contacts() or {}), known, recurring, stored,
    session and string.format("%d members, %d people", #session.members, count(session.people or {})) or "none",
    tostring(type(ERR_UNINVITE_YOU) == "string"))
end

-- Lifecycle -------------------------------------------------------------------------------------

function M:OnInitialize()
  ns.Log:RegisterKind("group.end", { fields = { "g", "size", "inst", "e" }, render = renderGroupEnd })
  ns.Log:RegisterKind("contact", { fields = { "p" }, keep = true, render = renderContact })
  ns.Test:Register("Encounters.records", checkRecords)
  self.Tooltip:Initialize()
end

function M:OnEnable()
  -- Handlers trust the open session's fields; one read back from SavedVariables is repaired first.
  local char = self:Char()
  if char and type(char.state) == "table" then char.state.group = repair(char.state.group) end
  self:Subscribe("GROUP_CHANGED", onGroupChanged)
  self:Subscribe("LOG_ADDED", onLogAdded)
  self:Subscribe("CHAPTER_CLOSED", onChapterClosed)
  self:RegisterEvent("GROUP_ROSTER_UPDATE", onRoster)
  self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
  self:RegisterEvent("CHAT_MSG_SYSTEM", onSystemMessage)
  if ns.Compat.Has.encounters then self:RegisterEvent("ENCOUNTER_END", onEncounterEnd) end
  self.Tooltip:Enable()
end

-- A stored session resumes if the group still holds one of its members; otherwise it ends when the last
-- session ended (lastSeen, 5.10), and a group the player is in now opens a new one.
function M:OnWorldReady()
  local char = self:Char()
  if not (char and type(char.state) == "table") then return end
  local session = openOf(char)
  local grouped = ns.Identity:InGroup()
  if session then
    if grouped and stillThere(session) then
      addMembers(session, char)
      return
    end
    finish(char, session, math.max(tonumber(char.lastSeen) or session.start, session.start), true)
  end
  if grouped then open(char) end
end

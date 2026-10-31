local ADDON, ns = ...

local Slash = { commands = {}, order = {} }
ns.Slash = Slash

local L = ns.L

function Slash:Register(sub, fn, helpKey)
  sub = sub:lower()
  if not self.commands[sub] then self.order[#self.order + 1] = sub end
  self.commands[sub] = { fn = fn, help = helpKey }
end

local function help()
  ns.Print(L.CORE_HELP_HEADER)
  ns.Print("/ashmark - " .. L.CORE_HELP_TOGGLE)
  for _, sub in ipairs(Slash.order) do
    local command = Slash.commands[sub]
    if command.help then ns.Print("/ashmark " .. sub .. " - " .. L[command.help]) end
  end
end

-- The main window belongs to UI/MainFrame.lua, which shows and hides it through Combat.Run.
local function toggle()
  local main = ns.UI and ns.UI.MainFrame
  if main then main:Toggle() end
end

local function confirm(textKey, onAccept, values)
  local dialog = ns.UI and ns.UI.Dialog
  if not dialog then return end
  dialog:Show({ text = ns.Format(L[textKey], values or {}), accept = "CORE_RESET_ACCEPT", cancel = "CORE_CANCEL",
                onAccept = onAccept })
end

-- The visible tab redraws: a wipe changes what every tab shows, and no topic tells of it.
local function redraw()
  local main = ns.UI and ns.UI.MainFrame
  if main and main.Refresh then main:Refresh() end
end

-- This character's part of the account stores: its meetings in contacts (a contact no other
-- character met and without a note goes with them) and its sightings of peers (seenBy, logged).
local function forgetCharacter(db, guid)
  for id, contact in pairs(type(db.contacts) == "table" and db.contacts or {}) do
    local byChar = type(contact) == "table" and contact.byChar
    if type(byChar) == "table" then
      byChar[guid] = nil
      local note = contact.note
      if next(byChar) == nil and (type(note) ~= "string" or note == "") then db.contacts[id] = nil end
    end
  end
  for _, peer in pairs(type(db.peers) == "table" and db.peers or {}) do
    for _, key in ipairs({ "seenBy", "logged" }) do
      if type(peer) == "table" and type(peer[key]) == "table" then peer[key][guid] = nil end
    end
  end
end

-- The new record keeps Comm's sender map of the party the player is in (5.6): nobody re-sends HI, so
-- without it every RU from that party would be dropped. Its group flag starts false, so CheckGroup
-- fires GROUP_CHANGED(true) while grouped and Encounters opens a session for the group.
local function wipeCharacter()
  local guid = ns.playerGUID
  if ns.DB.readOnly or not guid then return end
  local old = type(AshmarkDB.chars[guid]) == "table" and AshmarkDB.chars[guid].state
  AshmarkDB.chars[guid] = nil
  forgetCharacter(AshmarkDB, guid)
  ns.Identity:Refresh()
  local char = ns.DB:Char()
  if char then
    if type(old) == "table" then
      if type(old.senders) == "table" then char.state.senders = old.senders end
      char.state.selfSender = old.selfSender
    end
    ns.Bus:Fire("LOG_COMPACTED", char)
    ns.Watch:CheckGroup()
  end
  ns.Print(L.CORE_RESET_DONE)
end

-- Log kinds that name another player (Encounters' first meetings, Fiction's peer sightings).
local OTHERS_KINDS = { contact = true, peer = true }

-- What a character's record keeps of other players: its log's contact and peer entries, its stored group
-- sessions (their member GUIDs; a group.end line then counts its companions), and the open session's
-- members and snapshots, which would make contacts again when it ends. Another character's sender map
-- and greetings go too; the current character keeps those of the party it is in. True if the log changed.
local function forgetOthers(char, current)
  if type(char) ~= "table" then return false end
  char.sessions = nil
  local state = type(char.state) == "table" and char.state or nil
  local open = state and state.group
  if type(open) == "table" then open.members, open.people = {}, {} end
  if state and not current then state.senders, state.greeted = {}, nil end
  if type(char.log) ~= "table" then return false end
  local kept = {}
  for _, entry in ipairs(char.log) do
    if not (type(entry) == "table" and OTHERS_KINDS[entry.k]) then kept[#kept + 1] = entry end
  end
  if #kept == #char.log then return false end
  char.log = kept                -- a new array, as a compaction leaves it, so an Iter in progress is safe
  return true
end

-- Contacts, peers, every rumour this account did not start, whom its own were told to, and what each
-- character's record keeps of other players.
local function wipeOthers()
  if ns.DB.readOnly then return end
  local db = AshmarkDB
  db.contacts, db.peers = {}, {}
  local heard, told = {}, {}
  for id, rumour in pairs(db.rumours.heard) do
    if type(rumour) == "table" and rumour.own then
      heard[id] = rumour
      told[id] = {}
    end
  end
  db.rumours.heard, db.rumours.told = heard, told
  for guid, char in pairs(type(db.chars) == "table" and db.chars or {}) do
    if forgetOthers(char, guid == ns.playerGUID) and guid == ns.playerGUID then
      ns.Bus:Fire("LOG_COMPACTED", char)
    end
  end
  redraw()
  ns.Print(L.CORE_RESET_OTHERS_DONE)
end

local function named(char)
  return type(char.name) == "string" and char.name ~= ""
end

-- A record without a name (written while the client still called the player Unknown) reads as someone.
local function fullName(char)
  local name = named(char) and char.name or L.CORE_UNKNOWN_PLAYER
  if type(char.surname) == "string" and char.surname ~= "" then return name .. " " .. char.surname end
  return name
end

-- Other stored characters that `query` names: the GUID exactly, else the full name or the first name,
-- ignoring case (Util.Fold: A-Z and the capitals of Latin-1, Latin Extended-A and Cyrillic). Never the
-- current character; a record without a name only by its GUID. Sorted by name, then GUID.
local function others(query)
  local chars, me, Fold = type(AshmarkDB.chars) == "table" and AshmarkDB.chars or {}, ns.playerGUID, ns.Util.Fold
  local own = chars[query]
  if query ~= me and type(own) == "table" then return { { guid = query, char = own } } end
  local wanted, out = Fold(query), {}
  for guid, char in pairs(chars) do
    if guid ~= me and type(char) == "table" and named(char)
      and (Fold(char.name) == wanted or Fold(fullName(char)) == wanted) then
      out[#out + 1] = { guid = guid, char = char }
    end
  end
  table.sort(out, function(a, b)
    local na, nb = fullName(a.char), fullName(b.char)
    if na ~= nb then return na < nb end
    return tostring(a.guid) < tostring(b.guid)
  end)
  return out
end

-- Another character of this account, deleted or moved in the game: its record and its share of the
-- account stores go (5.9). The House, the quest-dialog hint and houseturn read AshmarkDB.chars live.
local function forgetOther(guid, name)
  return function()
    if ns.DB.readOnly or guid == ns.playerGUID or type(AshmarkDB.chars[guid]) ~= "table" then return end
    AshmarkDB.chars[guid] = nil
    forgetCharacter(AshmarkDB, guid)
    redraw()
    ns.Print(ns.Format(L.CORE_RESET_CHAR_DONE, { name = name }))
  end
end

local function resetOther(query)
  local found = others(query)
  if #found == 0 then
    ns.Print(ns.Format(L.CORE_RESET_CHAR_UNKNOWN, { name = query }))
  elseif #found > 1 then
    ns.Print(ns.Format(L.CORE_RESET_CHAR_AMBIGUOUS, { name = query }))
    for _, hit in ipairs(found) do
      ns.Print(ns.Format(L.CORE_RESET_CHAR_LINE, {
        name = fullName(hit.char), level = tonumber(hit.char.level) or "?", guid = hit.guid,
      }))
    end
  else
    local hit = found[1]
    local name = named(hit.char) and fullName(hit.char) or hit.guid
    confirm("CORE_RESET_CHAR_CONFIRM", forgetOther(hit.guid, name), { name = name })
  end
end

local function reset(args)
  if ns.DB.readOnly then
    -- After a failed update the data is only read for this session; it is not from a newer Ashmark.
    ns.Print(ns.DB.readOnlyReason == "migration" and L.CORE_SV_MIGRATE_FAILED or L.CORE_RESET_READONLY)
  elseif args == "" or args == nil then
    confirm("CORE_RESET_CONFIRM", wipeCharacter)
  elseif args:lower() == "others" then
    confirm("CORE_RESET_OTHERS_CONFIRM", wipeOthers)
  else
    resetOther(args)
  end
end

local function debug()
  ns.debug = not ns.debug
  ns.Print(ns.debug and L.CORE_DEBUG_ON or L.CORE_DEBUG_OFF)
end

local function run(msg)
  if ns.stopped then
    ns.Print(L.CORE_NOT_FOREVER)
    return
  end
  msg = ns.Util.Trim(msg)
  local sub, args = msg:match("^(%S+)%s*(.-)$")
  if not sub then return toggle() end
  local command = Slash.commands[sub:lower()]
  if not command then
    ns.Print(ns.Format(L.CORE_UNKNOWN_COMMAND, { command = sub }))
    return help()
  end
  ns:Call(ns.Core, "slash:" .. sub:lower(), command.fn, args)
end

Slash:Register("help", help, "CORE_HELP_HELP")
Slash:Register("debug", debug, "CORE_HELP_DEBUG")
Slash:Register("reset", reset, "CORE_HELP_RESET")

SLASH_ASHMARK1 = "/ashmark"
SLASH_ASHMARK2 = "/amk"
SlashCmdList.ASHMARK = run

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

local function wipeCharacter()
  local guid = ns.playerGUID
  if ns.DB.readOnly or not guid then return end
  AshmarkDB.chars[guid] = nil
  forgetCharacter(AshmarkDB, guid)
  ns.Identity:Refresh()
  local char = ns.DB:Char()
  if char then ns.Bus:Fire("LOG_COMPACTED", char) end
  ns.Print(L.CORE_RESET_DONE)
end

-- Contacts, peers and every rumour this account did not start (and their told lists).
local function wipeOthers()
  if ns.DB.readOnly then return end
  local db = AshmarkDB
  db.contacts, db.peers = {}, {}
  local heard, told = {}, {}
  for id, rumour in pairs(db.rumours.heard) do
    if type(rumour) == "table" and rumour.own then
      heard[id] = rumour
      told[id] = db.rumours.told[id]
    end
  end
  db.rumours.heard, db.rumours.told = heard, told
  redraw()
  ns.Print(L.CORE_RESET_OTHERS_DONE)
end

local function fullName(char)
  local name = type(char.name) == "string" and char.name or ""
  if type(char.surname) == "string" and char.surname ~= "" then return name .. " " .. char.surname end
  return name
end

-- Other stored characters that `query` names: the GUID exactly, else the full name or the first name,
-- ignoring ASCII case. Never the current character. Sorted by name, then GUID.
local function others(query)
  local chars, me = type(AshmarkDB.chars) == "table" and AshmarkDB.chars or {}, ns.playerGUID
  local own = chars[query]
  if query ~= me and type(own) == "table" then return { { guid = query, char = own } } end
  local wanted, out = query:lower(), {}
  for guid, char in pairs(chars) do
    if guid ~= me and type(char) == "table" and type(char.name) == "string"
      and (char.name:lower() == wanted or fullName(char):lower() == wanted) then
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
    local name = fullName(found[1].char)
    confirm("CORE_RESET_CHAR_CONFIRM", forgetOther(found[1].guid, name), { name = name })
  end
end

local function reset(args)
  if ns.DB.readOnly then
    ns.Print(L.CORE_RESET_READONLY)
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

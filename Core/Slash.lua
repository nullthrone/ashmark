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

local function confirm(textKey, onAccept)
  local dialog = ns.UI and ns.UI.Dialog
  if not dialog then return end
  dialog:Show({ text = L[textKey], accept = "CORE_RESET_ACCEPT", cancel = "CORE_CANCEL", onAccept = onAccept })
end

local function wipeCharacter()
  local guid = ns.playerGUID
  if ns.DB.readOnly or not guid then return end
  AshmarkDB.chars[guid] = nil
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
  ns.Print(L.CORE_RESET_OTHERS_DONE)
end

local function reset(args)
  if ns.DB.readOnly then
    ns.Print(L.CORE_RESET_READONLY)
  elseif args == "others" then
    confirm("CORE_RESET_OTHERS_CONFIRM", wipeOthers)
  else
    confirm("CORE_RESET_CONFIRM", wipeCharacter)
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

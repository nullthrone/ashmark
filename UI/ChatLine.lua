local ADDON, ns = ...

local UI = ns.UI or {}
ns.UI = UI

local ChatLine = {}
UI.ChatLine = ChatLine

local L = ns.L

local CHAT_TYPES = { system = "SYSTEM", rumour = "MONSTER_SAY" }

-- One line in the default chat window with Ashmark's prefix (6.2); kind "system" (default) or
-- "rumour". Returns true if the line was printed, so callers count only lines that were shown.
function ChatLine:Print(text, kind)
  local chat = DEFAULT_CHAT_FRAME
  if not chat or ns.Safe.IsSecret(text) or type(text) ~= "string" then return false end
  if not ns.Settings:Get("Core.chatLines") then return false end
  local line = NORMAL_FONT_COLOR:WrapTextInColorCode(L.CORE_TITLE) .. ": " .. text
  local info = ChatTypeInfo and ChatTypeInfo[CHAT_TYPES[kind] or "SYSTEM"]
  if info then
    -- The chat type id lets the line follow later changes of that chat colour.
    chat:AddMessage(line, info.r, info.g, info.b, info.id)
  else
    chat:AddMessage(line)
  end
  return true
end

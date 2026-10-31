local ADDON, ns = ...

local Combat = ns:NewService("Combat")

local order, queued = {}, {}
local listening = false

local function flush()
  local keys, fns = order, queued
  order, queued = {}, {}
  for _, key in ipairs(keys) do
    ns:Call(Combat, key, fns[key])
  end
end

-- Runs fn now out of combat; otherwise keeps the latest fn per key until PLAYER_REGEN_ENABLED.
function Combat.Run(key, fn)
  if not (InCombatLockdown and InCombatLockdown()) then
    ns:Call(Combat, key, fn)
    return
  end
  if not queued[key] then order[#order + 1] = key end
  queued[key] = fn
  if not listening then
    listening = true
    Combat:RegisterEvent("PLAYER_REGEN_ENABLED", flush)
  end
end

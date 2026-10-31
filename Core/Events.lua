local ADDON, ns = ...

local Events = {}
ns.Events = Events

-- Lists are replaced, never edited, so a dispatch in progress walks a stable array.
local plain = {}        -- [event] = { entry, ... }
local units = {}        -- [event .. "\0" .. unit] = { frame = f, list = { entry, ... } }
local EMPTY = {}

local function dispatch(list, event, ...)
  for i = 1, #list do
    local entry = list[i]
    local owner = entry.owner
    if not entry.removed and owner.enabled then
      ns:Call(owner, event, entry.handler, owner, event, ...)
    end
  end
end

local shared = CreateFrame("Frame")
shared:SetScript("OnEvent", function(_, event, ...)
  dispatch(plain[event] or EMPTY, event, ...)
end)

local function without(list, owner)
  local out = {}
  for _, entry in ipairs(list) do
    if entry.owner == owner then
      entry.removed = true
    else
      out[#out + 1] = entry
    end
  end
  return out
end

local function with(list, owner, handler)
  local out = without(list, owner)
  out[#out + 1] = { owner = owner, handler = handler }
  return out
end

local function missing(owner, event)
  local list = owner.missingEvents or {}
  owner.missingEvents = list
  for _, known in ipairs(list) do
    if known == event then return end
  end
  list[#list + 1] = event
end

local function valid(event, register)
  if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
    local ok, isValid = pcall(C_EventUtils.IsEventValid, event)
    if ok and not isValid then return false end
  end
  return (pcall(register))
end

function Events:Register(owner, event, handler)
  local list = plain[event]
  if not list then
    if not valid(event, function() shared:RegisterEvent(event) end) then
      missing(owner, event)
      return false
    end
    list = {}
  end
  plain[event] = with(list, owner, handler)
  return true
end

function Events:RegisterUnit(owner, event, unit, handler)
  local key = event .. "\0" .. unit
  local slot = units[key]
  if not slot then
    slot = { frame = CreateFrame("Frame"), event = event, unit = unit, list = {} }
    slot.frame:SetScript("OnEvent", function(_, e, ...) dispatch(slot.list, e, ...) end)
    units[key] = slot
  end
  -- The frame stays with its pair, so registering again (UNIT_HEALTH per kill candidate) creates no frame.
  if #slot.list == 0 and not valid(event, function() slot.frame:RegisterUnitEvent(event, unit) end) then
    missing(owner, event)
    return false
  end
  slot.list = with(slot.list, owner, handler)
  return true
end

function Events:Unregister(owner, event, unit)
  if unit then
    local key = event .. "\0" .. unit
    local slot = units[key]
    if not slot or #slot.list == 0 then return end
    slot.list = without(slot.list, owner)
    if #slot.list == 0 then
      slot.frame:UnregisterEvent(event)
    end
    return
  end
  local list = plain[event]
  if not list then return end
  list = without(list, owner)
  if #list == 0 then
    shared:UnregisterEvent(event)
    plain[event] = nil
  else
    plain[event] = list
  end
end

function Events:UnregisterAll(owner)
  local events = {}
  for event, list in pairs(plain) do
    for _, entry in ipairs(list) do
      if entry.owner == owner then events[#events + 1] = event end
    end
  end
  for _, event in ipairs(events) do
    self:Unregister(owner, event)
  end
  for _, slot in pairs(units) do
    for _, entry in ipairs(slot.list) do
      if entry.owner == owner then
        self:Unregister(owner, slot.event, slot.unit)
        break
      end
    end
  end
end

-- Number of handlers for an event (for unit events, of one unit); used by tests and the test report.
function Events:Count(event, unit)
  if unit then
    local slot = units[event .. "\0" .. unit]
    return slot and #slot.list or 0
  end
  return #(plain[event] or EMPTY)
end

-- The dispatcher exists now: the lifecycle (Core/Init.lua) can register ADDON_LOADED.
ns.Core:Boot()

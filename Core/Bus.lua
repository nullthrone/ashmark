local ADDON, ns = ...

local Bus = {}
ns.Bus = Bus

local subs = {}          -- [topic] = { entry, ... }; replaced, never edited
local queue = {}
local dispatching = false

local function deliver(topic, ...)
  local list = subs[topic]
  if not list then return end
  for i = 1, #list do
    local entry = list[i]
    local owner = entry.owner
    if not entry.removed and owner.enabled then
      ns:Call(owner, topic, entry.handler, owner, topic, ...)
    end
  end
end

local function without(list, owner)
  local out = {}
  for _, entry in ipairs(list or {}) do
    if entry.owner == owner then
      entry.removed = true
    else
      out[#out + 1] = entry
    end
  end
  return out
end

function Bus:Subscribe(owner, topic, handler)
  local list = without(subs[topic], owner)
  list[#list + 1] = { owner = owner, handler = handler }
  subs[topic] = list
end

function Bus:Unsubscribe(owner, topic)
  local list = without(subs[topic], owner)
  subs[topic] = #list > 0 and list or nil
end

function Bus:UnsubscribeAll(owner)
  local topics = {}
  for topic in pairs(subs) do topics[#topics + 1] = topic end
  for _, topic in ipairs(topics) do self:Unsubscribe(owner, topic) end
end

-- Synchronous. A Fire issued during a dispatch is queued and delivered FIFO once the current
-- topic has reached every subscriber; the outermost Fire returns when the queue is empty.
function Bus:Fire(topic, ...)
  if not ns.ready then return end
  if dispatching then
    queue[#queue + 1] = { n = select("#", ...) + 1, topic, ... }
    return
  end
  dispatching = true
  deliver(topic, ...)
  local i = 1
  while queue[i] do
    local item = queue[i]
    deliver(unpack(item, 1, item.n))
    i = i + 1
  end
  queue = {}
  dispatching = false
end

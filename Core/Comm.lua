local ADDON, ns = ...

local Comm = ns:NewService("Comm")

local Safe = ns.Safe

local PREFIX = "Ashmark"
local VERSION = "1"
local CHANNEL = "PARTY"
local MAX_LEN = 255
local CAPACITY, REFILL = 6, 1.5        -- token bucket, under Blizzard's 10 per prefix and 1/s
local MAX_QUEUE = 30
local TICK = 0.5
local THROTTLE_PAUSE = 5
local RATE_LIMIT, RATE_WINDOW = 20, 60
local MAX_SENDERS = 40
local MAX_BAD_RESULTS = 3

Comm.PREFIX = PREFIX
Comm.stats = { sent = 0, rejected = 0, dropped = 0, results = {} }
local stats = Comm.stats

-- Field rules (5.6): the same table validates sending and receiving. Each takes the wire
-- string and returns the decoded value, or nil.

local function set(...)
  local t = {}
  for i = 1, select("#", ...) do t[select(i, ...)] = true end
  return function(s) if t[s] then return s end end
end

local function integer(lo, hi)
  return function(s)
    if not s:match("^%-?%d+$") then return nil end
    local v = tonumber(s)
    if v and v >= lo and v <= hi then return v end
  end
end

local RULES = {
  guid = function(s) if s:match("^Player%-%d+%-%x+$") then return s end end,
  archetype = set("OATHKEEPER", "OPPORTUNIST", "WANDERER", "TOWNSFOLK", "GENTLE", "RUTHLESS", "PRAGMATIST"),
  origin = integer(0, 999999),
  faction = integer(0, 999999),
  map = integer(0, 999999),
  ruleset = set("Normal", "PvP", "RP", "RPPvP", "Hardcore"),
  version = function(s) if #s <= 20 and s:match("^[%w.%-]+$") then return s end end,
  fidelity = integer(-100, 100),
  habitat = integer(-100, 100),
  mercy = integer(-100, 100),
  id = function(s) if #s == 8 and s:match("^[0-9a-f]+$") then return s end end,
  tpl = set("ALLIANCE", "BROKE", "TURNED"),
  hops = integer(0, 9),
  strength = integer(0, 100),
  age = integer(0, 2160),
}

local TYPES = {
  HI = { "guid", "archetype", "origin", "ruleset", "version" },
  PR = { "guid", "fidelity", "habitat", "mercy" },
  RU = { "id", "tpl", "hops", "strength", "age", "archetype", "faction", "map" },
}

local DEFAULT_PRIORITY = { HI = 1, PR = 1, RU = 3 }

local function wire(v)
  if type(v) == "number" then
    if v % 1 ~= 0 then return nil end
    return string.format("%d", v)
  end
  if type(v) == "string" and not Safe.IsSecret(v) then return v end
end

local function check(name, s)
  if not s:match("^[%w_.:%-]*$") then return nil end
  return RULES[name](s)
end

-- text, or nil and "invalid" / "tooLong". No escaping: other characters are refused.
function Comm:Encode(kind, fields)
  local names = TYPES[kind]
  if not names or type(fields) ~= "table" or Safe.IsSecret(fields) or #fields ~= #names then
    return nil, "invalid"
  end
  local parts = { VERSION, kind }
  for i, name in ipairs(names) do
    local s = wire(fields[i])
    if not s or check(name, s) == nil then return nil, "invalid" end
    parts[#parts + 1] = s
  end
  local text = table.concat(parts, "|")
  if #text > MAX_LEN then return nil, "tooLong" end
  return text
end

-- kind, values (integers decoded), or nil.
function Comm:Decode(text)
  if Safe.IsSecret(text) or type(text) ~= "string" or #text > MAX_LEN then return nil end
  local parts = {}
  for part in (text .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = part end
  local names = parts[1] == VERSION and TYPES[parts[2]]
  if not names or #parts - 2 ~= #names then return nil end
  local values = {}
  for i, name in ipairs(names) do
    local v = check(name, parts[i + 2])
    if v == nil then return nil end
    values[i] = v
  end
  return parts[2], values
end

-- Queue ---------------------------------------------------------------------

local queue = {}                 -- priority ascending, then age
local seq = 0
local tokens, refilledAt = CAPACITY, nil
local pausedUntil, lockedOut = 0, false
local badResults = 0

local function refill(now)
  tokens = math.min(CAPACITY, tokens + (now - (refilledAt or now)) / REFILL)
  refilledAt = now
end

local function paused(now)
  return lockedOut or now < pausedUntil or Safe.InLockdown() or not ns.Identity:InGroup()
end

local function dropLowest()
  local worst
  for i, item in ipairs(queue) do
    if not worst or item.priority > queue[worst].priority then worst = i end
  end
  table.remove(queue, worst)
  stats.dropped = stats.dropped + 1
end

local function enqueue(item)
  local i = #queue
  while i >= 1 and queue[i].priority > item.priority do i = i - 1 end
  table.insert(queue, i + 1, item)
  if #queue > MAX_QUEUE then dropLowest() end
end

local function dropAll()
  stats.dropped = stats.dropped + #queue
  queue = {}
end

local function transmit(item)
  local api = C_ChatInfo and C_ChatInfo.SendAddonMessage
  local ok, result = Safe.Call(api, PREFIX, item.text, item.channel)
  if not ok or result == false then return -1 end
  if result == true or result == nil then return 0 end
  return type(result) == "number" and result or -1
end

local pump

local function settle(item, code, now)
  stats.results[code] = (stats.results[code] or 0) + 1
  if code == 0 or code == 3 or code == 5 or code == 8 or code == 11 then
    badResults = 0
  else
    badResults = badResults + 1
  end
  if code == 0 then
    stats.sent = stats.sent + 1
  elseif code == 3 or code == 8 then
    table.insert(queue, 1, item)
    pausedUntil = now + THROTTLE_PAUSE
  elseif code == 11 then
    table.insert(queue, 1, item)
    lockedOut = true
  elseif code == 5 then
    stats.dropped = stats.dropped + 1
    dropAll()
  else
    stats.dropped = stats.dropped + 1
    if badResults >= MAX_BAD_RESULTS then
      ns.Compat.Disable("canSend", "SendAddonMessage result " .. tostring(code))
      dropAll()
    end
  end
end

pump = function()
  local now = GetTime()
  refill(now)
  while queue[1] and tokens >= 1 and not paused(now) do
    local item = table.remove(queue, 1)
    tokens = tokens - 1
    settle(item, transmit(item), now)
  end
  if queue[1] then
    ns.Util.Ticker("Comm", TICK, pump)
  else
    ns.Util.StopTicker("Comm")
  end
end

-- ok, or false and "share", "cannotSend", "invalid", "tooLong", "notGrouped".
function Comm:Send(kind, fields, channel, target, priority)
  if ns.Settings:Get("Comm.share") ~= true then return false, "share" end
  if not ns.Compat.Has.canSend then return false, "cannotSend" end
  if channel ~= CHANNEL or target ~= nil then return false, "invalid" end
  local text, reason = self:Encode(kind, fields)
  if not text then return false, reason end
  if not ns.Identity:InGroup() then return false, "notGrouped" end
  seq = seq + 1
  enqueue({ text = text, channel = channel, priority = priority or DEFAULT_PRIORITY[kind], seq = seq })
  pump()
  return true
end

-- Receive -------------------------------------------------------------------

local handlers = {}
local rates = {}                 -- [sender] = { start, count }

-- fn(from, fields, channel); with an owner, delivered only while it is enabled and errors count to it.
function Comm:Register(kind, fn, owner)
  handlers[kind] = { fn = fn, owner = owner }
end

local function state()
  local s = ns.DB:State()
  if s and type(s.senders) ~= "table" then s.senders = {} end
  return s
end

local function partyUnit(guid)
  for i = 1, 4 do
    local unit = "party" .. i
    if Safe.UnitGUID(unit) == guid then return unit end
  end
end

local function limited(sender, now)
  local rate = rates[sender]
  if not rate or now - rate.start >= RATE_WINDOW then
    rate = { start = now, count = 0 }
    rates[sender] = rate
  end
  rate.count = rate.count + 1
  return rate.count > RATE_LIMIT
end

local function remember(s, sender, guid)
  local senders = s.senders
  if senders[sender] == nil then
    local count = 0
    for _ in pairs(senders) do count = count + 1 end
    if count >= MAX_SENDERS then
      for known, g in pairs(senders) do
        if not partyUnit(g) then
          senders[known] = nil
          count = count - 1
        end
      end
      if count >= MAX_SENDERS then senders[next(senders)] = nil end
    end
  end
  senders[sender] = guid
end

local function onMessage(_, _, prefix, text, channel, sender)
  if Safe.IsSecret(prefix) or prefix ~= PREFIX then return end
  if Safe.IsSecret(text) or Safe.IsSecret(channel) or Safe.IsSecret(sender) then return end
  if channel ~= CHANNEL or type(text) ~= "string" or #text > MAX_LEN or type(sender) ~= "string" then return end
  local kind, values = Comm:Decode(text)
  if not kind then
    stats.rejected = stats.rejected + 1
    return
  end
  if limited(sender, GetTime()) then return end
  local s = state()
  if not s or sender == s.selfSender then return end
  local from = { sender = sender }
  if kind == "HI" or kind == "PR" then
    local guid = values[1]
    if guid == Safe.UnitGUID("player") then
      s.selfSender = sender
      return
    end
    from.unit = partyUnit(guid)
    if not from.unit then return end
    remember(s, sender, guid)
    from.guid = guid
  else
    from.guid = s.senders[sender]
    if not from.guid then return end
    from.unit = partyUnit(from.guid)
  end
  local handler = handlers[kind]
  if not handler then return end
  local owner = handler.owner or Comm
  if owner.enabled then
    ns:Call(owner, "comm:" .. kind, handler.fn, from, values, channel)
  end
end

local function unlock()
  lockedOut = false
  if queue[1] then pump() end
end

local function onGroupChanged(_, _, inGroup)
  if inGroup then return end
  local s = state()
  if s then s.senders = {} end
  rates = {}
end

-- PLAYER_LOGIN
function Comm:Start()
  if not ns.Compat.Has.addonMessages then return end
  Safe.Call(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  self:RegisterEvent("CHAT_MSG_ADDON", onMessage)
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", unlock)
  self:RegisterEvent("PLAYER_ENTERING_WORLD", unlock)
  self:Subscribe("GROUP_CHANGED", onGroupChanged)
end

-- Number of queued messages (tests and the test report).
function Comm:Queued()
  return #queue
end

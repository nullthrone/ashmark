local ADDON, ns = ...

local Log = {}
ns.Log = Log

local RESERVED = { n = true, t = true, k = true, m = true, x = true, y = true, i = true }
local COMPACT_AT = 4000          -- an Add above this schedules a compaction
local KEEP_TOTAL = 3000          -- entries left after a compaction
local KEEP_KINDS_MAX = 2000      -- beyond this, the oldest chapter, then peer, then contact entries go
local MAX_AGE = 180 * 86400      -- non-keep entries older than this go
local AUTO_CHAPTER_SIZE = 1000
local AUTO_CHAPTER_AGE = 7 * 86400
local EMPTY = {}

local kinds = {}
local compactPending = false

function Log:RegisterKind(kind, spec)
  kinds[kind] = spec or {}
end

function Log:Kind(kind)
  return kinds[kind]
end

-- True when the chronicle can show the entry: its kind has a renderer and, if the kind has a
-- shown(entry) test (zone shows only first visits), the entry passes it.
function Log:Shown(entry)
  local spec = type(entry) == "table" and kinds[entry.k]
  if not (spec and spec.render) then return false end
  if spec.shown then return spec.shown(entry) and true or false end
  return true
end

-- Debug mode raises; otherwise the caller drops or strips.
local function fault(message)
  if ns.debug then error("Ashmark log: " .. message, 3) end
end

local function scheduleCompact()
  if compactPending then return end
  compactPending = true
  C_Timer.After(0, function()
    ns.Combat.Run("log:compact", function()
      compactPending = false
      Log:Compact(ns.DB:Char())
    end)
  end)
end

-- Entries are stamped and aged by one clock, the realm's where the client offers it (ns.Util.Now), so a
-- wrong system date neither deletes history nor closes a chapter at every login (4.2).
local function clock()
  return ns.Util.Now()
end

-- before(entry) runs after the append and before LOG_ADDED (CloseChapter stores its record there).
local function write(kind, fields, opts, before)
  if not ns.ready or ns.DB.readOnly then return nil end
  local char = ns.DB:Char()
  if not char then return nil end
  if not kinds[kind] then
    fault("unknown kind " .. tostring(kind))
    return nil
  end
  local entry = ns.Safe.Clean(fields or EMPTY)
  if not entry then
    ns.Core:Stat("secretDropped", 1)
    -- A quiet kind (the test mode's secret check) drops on purpose: counted, not reported.
    if not kinds[kind].quiet then
      ns:Report(ns.Core, "drop:" .. kind, "entry dropped: a field is secret or not a number, string or boolean")
    end
    return nil
  end
  for key in pairs(RESERVED) do
    if entry[key] ~= nil then
      fault("reserved key " .. key .. " in " .. kind)
      entry[key] = nil
    end
  end
  local n = char.seq + 1
  entry.n, entry.t, entry.k = n, clock(), kind
  if not (opts and opts.noWhere) then
    local w = ns.Where()
    entry.m, entry.x, entry.y, entry.i = w.m, w.x, w.y, w.i
  end
  char.seq = n
  char.log[#char.log + 1] = entry
  if before then before(entry) end
  ns.Bus:Fire("LOG_ADDED", entry, char)
  if #char.log > COMPACT_AT then scheduleCompact() end
  return entry
end

function Log:Add(kind, fields, opts)
  return write(kind, fields, opts)
end

-- First index whose entry has n >= seq (the log is ascending by n).
local function firstIndex(log, seq)
  local lo, hi = 1, #log + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if log[mid].n < seq then lo = mid + 1 else hi = mid end
  end
  return lo
end

-- Walks the array it started with: a compaction replaces the array, so it cannot disturb an Iter.
function Log:Iter(char, fromSeq, toSeq)
  local log = char and char.log or EMPTY
  local i = firstIndex(log, fromSeq or 1) - 1
  local last = toSeq or math.huge
  return function()
    i = i + 1
    local entry = log[i]
    if entry and entry.n <= last then return entry end
  end
end

function Log:Last(char, kind)
  local log = char and char.log or EMPTY
  for i = #log, 1, -1 do
    if log[i].k == kind then return log[i] end
  end
end

function Log:Count(char)
  return char and char.log and #char.log or 0
end

function Log:Seq(char)
  return char and char.seq or 0
end

local function lastTo(char)
  local last = char.chapters[#char.chapters]
  return last and last.to or 0
end

function Log:CloseChapter(members, opts)
  local char = ns.DB:Char()
  if not char or ns.DB.readOnly then return nil end
  local chapters = char.chapters
  local from = lastTo(char) + 1
  if char.seq < from then return nil end
  local no = #chapters + 1
  local auto = opts and opts.auto and true or nil
  local chapter
  local entry = write("chapter", { no = no, auto = auto }, opts, function(e)
    chapter = { no = no, from = from, to = e.n, closed = e.t, m = e.m, x = e.x, y = e.y, auto = auto }
    chapters[no] = chapter
  end)
  if not entry then return nil end
  ns.Bus:Fire("CHAPTER_CLOSED", chapter, members or {})
  return chapter
end

local function isKeep(entry)
  local spec = kinds[entry.k]
  return spec and spec.keep and true or false
end

-- Drops stay[i] for the oldest entries that pass test(i), until count(dropped) reaches excess.
local function dropOldest(log, stay, excess, test)
  local dropped = 0
  for i = 1, #log do
    if dropped >= excess then break end
    if stay[i] and test(i, log[i]) then
      stay[i] = nil
      dropped = dropped + 1
    end
  end
  return dropped
end

function Log:Compact(char)
  if ns.DB.readOnly or type(char) ~= "table" or type(char.log) ~= "table" then return end
  local log, now = char.log, clock()
  local stay, keepKind = {}, {}
  local nKeep, nOther = 0, 0
  -- An entry never counts as older than one written before it, so a session stamped by a system clock set
  -- back (where the realm's clock is missing, or in a log from before stamps used it) ages from the entries
  -- before it, not from its own date.
  local newest = 0
  for i, entry in ipairs(log) do
    local t = tonumber(entry.t) or 0
    if t > newest then newest = t end
    if isKeep(entry) then
      stay[i], keepKind[i] = true, true
      nKeep = nKeep + 1
    elseif now - newest <= MAX_AGE then
      stay[i] = true
      nOther = nOther + 1
    end
  end
  -- Keep kinds beyond 2,000: chapter entries first, whose record (char.chapters) keeps all they say, so
  -- a character who rests at camp for years never crowds out its meetings or this session's entries;
  -- then peer entries (written on other clients' word) before the player's own first meetings.
  for _, kind in ipairs({ "chapter", "peer", "contact" }) do
    if nKeep > KEEP_KINDS_MAX then
      nKeep = nKeep - dropOldest(log, stay, nKeep - KEEP_KINDS_MAX, function(_, entry) return entry.k == kind end)
    end
  end
  -- Then non-keep entries down to 3,000 in all: first those the chronicle never shows (gold,
  -- quest.accept, kills, rests, rumours, item.held, revisited zones), then the shown ones.
  for _, shown in ipairs({ false, true }) do
    if nKeep + nOther > KEEP_TOTAL then
      nOther = nOther - dropOldest(log, stay, nKeep + nOther - KEEP_TOTAL, function(i, entry)
        return not keepKind[i] and self:Shown(entry) == shown
      end)
    end
  end
  if nKeep + nOther == #log then return end
  local kept = {}
  for i, entry in ipairs(log) do
    if stay[i] then kept[#kept + 1] = entry end
  end
  char.log = kept
  ns.Bus:Fire("LOG_COMPACTED", char)
end

-- Lifecycle step 3, after every OnWorldReady: the automatic chapter close, then compaction (4.2).
function Log:WorldReady()
  local char = ns.DB:Char()
  if not char or ns.DB.readOnly then return end
  local log = char.log
  local first = firstIndex(log, lastTo(char) + 1)
  local held = #log - first + 1
  local began = log[first] and log[first].t
  if held > AUTO_CHAPTER_SIZE or (began and clock() - began > AUTO_CHAPTER_AGE) then
    self:CloseChapter(nil, { auto = true })
  end
  self:Compact(char)
end

Log:RegisterKind("chapter", {
  fields = { "no", "auto" },
  keep = true,
  render = function(entry, ctx)
    return ns.Chronicle:PlaceText("CORE_LOG_CHAPTER", ctx, entry.m, { roman = ns.Util.Roman(entry.no) })
  end,
})

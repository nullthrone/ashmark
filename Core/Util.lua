local ADDON, ns = ...

local Util = {}
ns.Util = Util

local pending, tickers = {}, {}

function Util.Token()
  return string.format("%04x%04x", math.random(0, 0xffff), math.random(0, 0xffff))
end

local ROMAN = {
  { 1000, "M" }, { 900, "CM" }, { 500, "D" }, { 400, "CD" }, { 100, "C" }, { 90, "XC" },
  { 50, "L" }, { 40, "XL" }, { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" },
}

function Util.Roman(n)
  if type(n) ~= "number" or n < 1 or n > 3999 or n % 1 ~= 0 then
    return tostring(n)
  end
  local out = {}
  for _, pair in ipairs(ROMAN) do
    while n >= pair[1] do
      out[#out + 1] = pair[2]
      n = n - pair[1]
    end
  end
  return table.concat(out)
end

function Util.Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Util.Round(v)
  return math.floor(v + 0.5)
end

function Util.Trim(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Seconds since the epoch by the realm's clock where the client offers it, else the system clock. Ageing
-- and decay (log compaction, profile axes, rumour strength) read this, so a system date set ahead or back
-- neither wipes history nor freezes it.
function Util.Now()
  if type(GetServerTime) == "function" then
    local ok, now = pcall(GetServerTime)
    if ok and type(now) == "number" and now > 0 and not (ns.Safe and ns.Safe.IsSecret(now)) then return now end
  end
  return time()
end

-- The first letters, in UTF-8, of each sound a conjunction changes before (Spanish "y" -> "e" before /i/,
-- "o" -> "u" before /o/). A leading "h" is silent; a plain "hi" before another vowel ("hie-", "hia-") is /j/.
local SOUND_LETTERS = {
  i = { "I", "i", "\195\141", "\195\173" },           -- I i Í í
  o = { "O", "o", "\195\147", "\195\179" },           -- O o Ó ó
}

local function glide(after)
  return after:find("^[AaEeOoUu]") ~= nil or after:find("^\195[\129\137\147\154\161\169\179\186]") ~= nil
end

-- True when text (a name, possibly in a colour code) begins with the sound "i" or "o" (see SOUND_LETTERS).
-- Only code sees the names, so locales pick a _VOWEL key by it (ENC_LIST_AND_VOWEL, CONFLICT_TAB_SIDES_VOWEL,
-- MAP_PIN_SIDES_VOWEL); every language but Spanish repeats its plain key there.
function Util.StartsWithSound(text, sound)
  local letters = SOUND_LETTERS[sound]
  if not letters or type(text) ~= "string" or (ns.Safe and ns.Safe.IsSecret(text)) then return false end
  local s = text:gsub("^|c%x%x%x%x%x%x%x%x", "")
  local rest = s:match("^[Hh](.*)$")
  local word = rest or s
  for _, letter in ipairs(letters) do
    if word:sub(1, #letter) == letter then
      if sound == "i" and rest and #letter == 1 then return not glide(word:sub(2)) end
      return true
    end
  end
  return false
end

-- One pending timer per key; calls while it is pending are absorbed.
function Util.Debounce(key, seconds, fn)
  if pending[key] then return end
  pending[key] = true
  C_Timer.After(seconds, function()
    pending[key] = nil
    ns:Call(ns.Core, key, fn)
  end)
end

function Util.Ticker(key, seconds, fn)
  if tickers[key] then return tickers[key] end
  local ticker = C_Timer.NewTicker(seconds, function() ns:Call(ns.Core, key, fn) end)
  tickers[key] = ticker
  return ticker
end

function Util.StopTicker(key)
  local ticker = tickers[key]
  if ticker then
    ticker:Cancel()
    tickers[key] = nil
  end
end

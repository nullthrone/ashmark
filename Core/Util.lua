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

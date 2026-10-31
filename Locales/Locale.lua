local ADDON, ns = ...

local Locale = {
  active = GetLocale and GetLocale() or "enUS",
  loadAll = false,                 -- tests: keep every locale table
  tables = { enUS = {} },
}
ns.Locale = Locale

function Locale:Base()
  return self.tables.enUS
end

-- Locale files have no early return: an inactive locale writes into a throwaway table.
function Locale:For(code)
  if code == self.active or self.loadAll then
    local t = self.tables[code] or {}
    self.tables[code] = t
    return t
  end
  return {}
end

function Locale:Get(key)
  local t = self.tables[self.active]
  local v = t and t[key]
  if v == nil then
    v = self.tables.enUS[key]
  end
  return v
end

function Locale:Missing(code)
  local t, missing = self.tables[code] or {}, {}
  for key in pairs(self.tables.enUS) do
    if t[key] == nil then missing[#missing + 1] = key end
  end
  table.sort(missing)
  return missing
end

ns.L = setmetatable({}, {
  __index = function(_, key) return Locale:Get(key) or key end,
  __newindex = function() error("ns.L is read-only; write through ns.Locale:Base() or :For(code)", 2) end,
})

function ns.Format(text, values)
  return (tostring(text):gsub("{(%w+)}", function(name)
    local v = values and values[name]
    if v ~= nil then return tostring(v) end
  end))
end

function ns.Gender(key, sex)
  if sex == 3 then
    local feminine = Locale:Get(key .. "_F")
    if feminine then return feminine end
  end
  return ns.L[key]
end

local ADDON, ns = ...

local Safe = ns.Safe
local MAP_TYPE = Enum and Enum.UIMapType or {}
local ZONE = MAP_TYPE.Zone or 3
local CONTINENT = MAP_TYPE.Continent or 2
local MAX_DEPTH = 32

local zoneCache, continentCache = {}, {}

local function instanceID()
  return (select(8, GetInstanceInfo()))
end

local function percent(v)
  if type(v) ~= "number" then return nil end
  return ns.Util.Clamp(math.floor(v * 100 + 0.5), 0, 100)
end

-- { m, x, y, i } for the player; never throws, unknown or secret fields are nil.
local function where()
  local w = {}
  local ok, m = Safe.Call(C_Map and C_Map.GetBestMapForUnit, "player")
  if ok and type(m) == "number" then w.m = m end
  local okInstance, inInstance = Safe.Call(IsInInstance)
  if okInstance and inInstance then
    local okId, id = Safe.Call(instanceID)
    if okId and type(id) == "number" then w.i = id end
    return w
  end
  if w.m then
    local okPos, pos = Safe.Call(C_Map.GetPlayerMapPosition, w.m, "player")
    if okPos and pos then
      local px, okX = Safe.Field(pos, "x")
      local py, okY = Safe.Field(pos, "y")
      if okX and okY then
        w.x, w.y = percent(px), percent(py)
        if not (w.x and w.y) then w.x, w.y = nil, nil end
      end
    end
  end
  return w
end

local function climb(cache, mapType, m)
  if type(m) ~= "number" then return nil end
  local hit = cache[m]
  if hit ~= nil then return hit or nil end
  local id, found = m, false
  for _ = 1, MAX_DEPTH do
    local ok, info = Safe.Call(C_Map and C_Map.GetMapInfo, id)
    if not ok or type(info) ~= "table" then break end
    if Safe.Field(info, "mapType") == mapType then
      found = id
      break
    end
    local parent = Safe.Field(info, "parentMapID")
    if type(parent) ~= "number" or parent == 0 or parent == id then break end
    id = parent
  end
  cache[m] = found
  return found or nil
end

ns.Where = setmetatable({
  Zone = function(m) return climb(zoneCache, ZONE, m) end,
  Continent = function(m) return climb(continentCache, CONTINENT, m) end,
}, { __call = function() return where() end })

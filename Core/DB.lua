local ADDON, ns = ...

local DB = {
  SCHEMA = 1,
  migrations = {},     -- [v] = function(db) upgrading schema v - 1 to v; idempotent
  readOnly = false,
  fresh = false,
}
ns.DB = DB

local L = ns.L
local memoryState      -- read-only mode: Core's volatile state lives here, never in AshmarkDB

local function sub(t, key)
  if type(t[key]) ~= "table" then t[key] = {} end
  return t[key]
end

-- Creates every top-level table of the schema (4); safe on an existing table.
local function ensure(db)
  if type(db.created) ~= "number" then db.created = time() end
  sub(db, "settings")
  sub(db, "chars")
  sub(db, "contacts")
  sub(db, "peers")
  local rumours = sub(db, "rumours")
  sub(rumours, "heard")
  sub(rumours, "told")
  local traces = sub(db, "traces")
  if traces.schema == nil then traces.schema = 0 end
  sub(traces, "outbox")
  sub(traces, "inbox")
  local dev = sub(db, "dev")
  sub(dev, "tests")
  sub(dev, "probes")
  sub(dev, "blocked")
end

local function migrate(db)
  for v = db.schema + 1, DB.SCHEMA do
    local step = DB.migrations[v]
    if step then step(db) end
    db.schema = v
  end
end

-- Load safety (4.4), at ADDON_LOADED for this addon.
function DB:Load()
  local db = AshmarkDB
  if db == nil then
    db = { schema = self.SCHEMA, created = time() }
    self.fresh = true
    ns.Print(L.CORE_SV_NEW)
  elseif type(db) ~= "table" or type(db.schema) ~= "number" then
    db = { schema = self.SCHEMA, created = time(), recovered = db }
    ns.Print(L.CORE_SV_RECOVERED)
  elseif db.schema > self.SCHEMA then
    self.readOnly = true
    ns.Print(L.CORE_SV_NEWER)
    return
  elseif db.schema < self.SCHEMA and not ns:Call(ns.Core, "migration", migrate, db) then
    self.readOnly = true
    ns.Print(L.CORE_SV_MIGRATE_FAILED)
    return
  end
  ensure(db)
  AshmarkDB = db
end

function DB:Char()
  local db = AshmarkDB
  local guid = ns.playerGUID
  if not guid or type(db) ~= "table" or type(db.chars) ~= "table" then return nil end
  local char = db.chars[guid]
  if type(char) == "table" then return char end
end

-- Core's volatile state (4.1 state.inGroup, state.senders, state.selfSender). In read-only
-- mode a copy in memory, seeded from the stored record, so nothing is written.
function DB:State()
  local char = self:Char()
  if not self.readOnly then
    return char and char.state
  end
  if not memoryState then
    local stored = char and type(char.state) == "table" and char.state or {}
    local senders = {}
    if type(stored.senders) == "table" then
      for sender, guid in pairs(stored.senders) do senders[sender] = guid end
    end
    memoryState = { inGroup = stored.inGroup == true, senders = senders, selfSender = stored.selfSender }
  end
  return memoryState
end

-- Appends to an array store and drops the oldest entries beyond cap.
function DB:Append(list, item, cap)
  if self.readOnly or type(list) ~= "table" then return end
  list[#list + 1] = item
  while #list > cap do
    table.remove(list, 1)
  end
end

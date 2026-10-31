local ADDON, ns = ...

local Chronicle = {}
ns.Chronicle = Chronicle

-- Chapters plus the open one: { no, from, open = true }.
function Chronicle:Chapters(char)
  local list = {}
  local chapters = char and char.chapters or {}
  for i, chapter in ipairs(chapters) do list[i] = chapter end
  local last = chapters[#chapters]
  list[#list + 1] = { no = #chapters + 1, from = (last and last.to or 0) + 1, open = true }
  return list
end

function Chronicle:Render(entry, ctx)
  local spec = type(entry) == "table" and ns.Log:Kind(entry.k)
  if not (spec and spec.render) then return nil end
  local ok, text = ns:Call(ns.Core, "render:" .. tostring(entry.k), spec.render, entry, ctx)
  if ok and type(text) == "string" and text ~= "" then return text end
end

function Chronicle:Lines(char, chapter, ctx)
  ctx = ctx or { char = char, own = true }
  local lines = {}
  if not (char and chapter) then return lines end
  for entry in ns.Log:Iter(char, chapter.from, chapter.to) do
    local text = self:Render(entry, ctx)
    if text then lines[#lines + 1] = { entry = entry, text = text } end
  end
  return lines
end

-- Renderer helper: key in the first person, or key .. "_THEY" with {name} when ctx.own is false;
-- the feminine form follows the character's sex (5.8).
function Chronicle:Text(key, ctx, values)
  local char = ctx and ctx.char
  values = values or {}
  if ctx and ctx.own == false then
    key = key .. "_THEY"
    values.name = values.name or (char and char.name) or ns.L.CORE_UNKNOWN_PLAYER
  end
  return ns.Format(ns.Gender(key, char and char.sex), values)
end

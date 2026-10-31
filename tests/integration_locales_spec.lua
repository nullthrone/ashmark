local wow = require("tests.helpers.wow")
local flow = require("tests.helpers.integration_flow")

-- Every client locale (docs/DECISIONS.md) active in turn: its file loads with the whole addon in TOC order, the
-- integration flow runs once without a reported error, the test mode finds the locale complete, and every
-- chronicle line of the flow renders in both persons and for both sexes. The player is a woman, so the
-- surfaces that pick _F forms (5.8) show them.

local LOCALES = { "enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhTW", "zhCN" }
local TOCS = { "Ashmark_Forever.toc", "Ashmark_Camelot.toc" }

-- Taken before any test of this file loads the addon: wow.reset only clears globals named Ashmark*.
local BASELINE = flow.baseline()

local function headers(toc)
  local out = {}
  for line in io.lines(wow.ROOT .. toc) do
    line = line:gsub("\r", ""):gsub("%s+$", "")
    if line:match("^##") then out[#out + 1] = line end
  end
  return out
end

-- The result of the last /ashmark test run with this id.
local function lastResult(id)
  local tests = _G.AshmarkDB.dev.tests
  for _, r in ipairs(tests[#tests].results) do
    if r.id == id then return r end
  end
end

-- Every logged entry rendered as own and as a sibling's, for a man and for a woman; texts that still hold a
-- placeholder or a key name.
local function badLines(ns, char)
  local bad, rendered = {}, 0
  for _, sex in ipairs({ 2, 3 }) do
    local who = {}
    for k, v in pairs(char) do who[k] = v end
    who.sex = sex
    for _, own in ipairs({ true, false }) do
      for entry in ns.Log:Iter(char, 1) do
        local text = ns.Chronicle:Render(entry, { char = who, own = own })
        if text then
          rendered = rendered + 1
          if text:find("{%w+}") or text:find("%u%u+_%u[%u_]*") then
            bad[#bad + 1] = string.format("%s (sex %d, own %s): %s", entry.k, sex, tostring(own), text)
          end
        end
      end
    end
  end
  return bad, rendered
end

describe("Integration in every locale", function()
  before_each(function()
    wow.reset()
  end)

  -- The addon list shows Notes and groups by Category as the client's locale names them.
  for _, field in ipairs({ "Notes", "Category" }) do
    it("names a " .. field .. " line for every translated locale in both TOCs, in order, after ## " .. field,
      function()
        local expected = {}
        for _, code in ipairs(LOCALES) do
          if code ~= "enUS" then expected[#expected + 1] = "## " .. field .. "-" .. code end
        end
        for _, toc in ipairs(TOCS) do
          local lines, found, at = headers(toc), {}, nil
          for i, line in ipairs(lines) do
            if line:match("^## " .. field .. ":") then at = i end
            local tag, text = line:match("^(## " .. field .. "%-%a+):%s*(.*)$")
            if tag then
              assert.is_true(text ~= "", tag)
              assert.equal(at + #found + 1, i, tag .. " in " .. toc)
              found[#found + 1] = tag
            end
          end
          assert.same(expected, found, toc)
        end
      end)
  end

  for _, code in ipairs(LOCALES) do
    it(code .. " loads as the active locale and plays the integration flow without an error", function()
      wow.state.locale = code
      wow.state.units.player.sex = 3
      local ns = flow.play(wow)

      assert.equal(code, ns.Locale.active)
      for other in pairs(ns.Locale.tables) do
        assert.is_true(other == "enUS" or other == code, other)
      end
      local own = ns.Locale.tables[code]
      assert.is_table(own)
      for key, text in pairs(own) do assert.equal(text, ns.L[key], key) end

      local locale = lastResult("Core.locale")
      assert.is_true(locale.ok, locale.detail)
      assert.equal(code .. ": complete", locale.detail)

      local bad, rendered = badLines(ns, ns.DB:Char())
      assert.is_true(rendered > 0)
      assert.same({}, bad)

      assert.same({}, wow.errors)
      assert.same({}, flow.newGlobals(BASELINE))
    end)
  end
end)

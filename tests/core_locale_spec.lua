local wow = require("tests.helpers.wow")

local LOCALES = { "enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhTW", "zhCN" }

-- The keys shown with a sex (5.8): Chronicle:Text keys and their _THEY forms, the map pins and the archetypes.
local GENDERED = {}
for _, key in ipairs({ "CORE_LOG_TURNIN", "CORE_LOG_ABANDON", "CORE_LOG_ZONE_FIRST", "CORE_LOG_LEVEL",
                       "CORE_LOG_DEATH", "CORE_LOG_REP", "CORE_LOG_CHAPTER", "CONFLICT_ALLIED", "CONFLICT_ALLIED_REP",
                       "CONFLICT_BROKE_WORD", "CONFLICT_SWITCHED", "CONFLICT_HOUSETURN", "ENC_LOG_TRAVEL",
                       "ENC_LOG_BOSS", "ENC_LOG_WIPE", "ENC_LOG_CAMP", "ENC_LOG_KICK", "ENC_LOG_CONTACT" }) do
  GENDERED[key], GENDERED[key .. "_THEY"] = true, true
end
for _, key in ipairs({ "MAP_PIN_OPEN", "MAP_PIN_ALLIED", "MAP_PIN_BROKEN" }) do GENDERED[key] = true end
for _, key in ipairs({ "OATHKEEPER", "OPPORTUNIST", "WANDERER", "TOWNSFOLK", "GENTLE", "RUTHLESS", "PRAGMATIST" }) do
  GENDERED["PROFILE_" .. key] = true
end

local function exists(path)
  local f = io.open(wow.ROOT .. path, "r")
  if f then f:close() end
  return f ~= nil
end

describe("Core Locale", function()
  local ns
  before_each(function()
    wow.reset()
  end)

  it("falls back from the active locale to enUS to the key itself", function()
    wow.state.locale = "deDE"
    ns = wow.load()
    local de = ns.Locale:For("deDE")
    de.CORE_TITLE = "Aschmal"
    de.CORE_UNKNOWN_QUEST = nil
    assert.equal("Aschmal", ns.L.CORE_TITLE)
    assert.equal("a quest", ns.L.CORE_UNKNOWN_QUEST)
    assert.equal("NO_SUCH_KEY", ns.L.NO_SUCH_KEY)
    assert.has_error(function() ns.L.X = 1 end)
  end)

  it("hands inactive locales a throwaway table unless loadAll is set", function()
    ns = wow.load()
    local fr = ns.Locale:For("frFR")
    fr.CORE_TITLE = "x"
    assert.is_nil(ns.Locale.tables.frFR)
    assert.equal(ns.Locale:Base(), ns.Locale:For("enUS"))
    ns.Locale.loadAll = true
    assert.equal(ns.Locale:For("frFR"), ns.Locale.tables.frFR)
  end)

  it("formats named placeholders and leaves unknown ones", function()
    ns = wow.load()
    assert.equal("Hi Mira, 3 times.", ns.Format("Hi {name}, {count} times.", { name = "Mira", count = 3 }))
    assert.equal("Hi {name}.", ns.Format("Hi {name}."))
    assert.equal("50% of {x}", ns.Format("50% of {x}", { y = 1 }))
    assert.equal("a%b", ns.Format("{v}", { v = "a%b" }))
  end)

  it("picks the feminine form for sex 3 when one exists", function()
    wow.state.locale = "deDE"
    ns = wow.load()
    local de = ns.Locale:For("deDE")
    de.TEST_WORD = "Kämpfer"
    de.TEST_WORD_F = "Kämpferin"
    assert.equal("Kämpferin", ns.Gender("TEST_WORD", 3))
    assert.equal("Kämpfer", ns.Gender("TEST_WORD", 2))
    assert.equal("Kämpfer", ns.Gender("TEST_WORD", 1))
    de.CORE_UNKNOWN_QUEST_F = nil
    assert.equal(ns.L.CORE_UNKNOWN_QUEST, ns.Gender("CORE_UNKNOWN_QUEST", 3))
  end)

  it("lists the enUS keys a locale lacks", function()
    ns = wow.load()
    local base = ns.Locale:Base()
    ns.Locale.loadAll = true
    local de = ns.Locale:For("deDE")
    for key, text in pairs(base) do de[key] = text end
    de.CORE_TITLE = nil
    assert.same({ "CORE_TITLE" }, ns.Locale:Missing("deDE"))
    assert.same({}, ns.Locale:Missing("enUS"))
  end)

  describe("every client locale (loadAll)", function()
    local loaded
    setup(function()
      wow.reset()
      loaded = wow.load(nil, { loadAll = true })
    end)

    it("names only enUS keys as shown with a sex, and none of the rumour lines", function()
      local base, unknown = loaded.Locale:Base(), {}
      for key in pairs(GENDERED) do
        if base[key] == nil or key:match("^RUMOUR_") then unknown[#unknown + 1] = key end
      end
      table.sort(unknown)
      assert.same({}, unknown)
    end)

    for _, code in ipairs(LOCALES) do
      local file = code == "enUS" and "Locales/enUS/Core.lua" or ("Locales/" .. code .. ".lua")
      if exists(file) then
        it(code .. " has every enUS key", function()
          assert.same({}, loaded.Locale:Missing(code))
        end)
        if code ~= "enUS" then
          it(code .. " has only enUS keys and their _F forms, as non-empty strings", function()
            local base, unknown = loaded.Locale:Base(), {}
            for key, text in pairs(loaded.Locale.tables[code]) do
              local stem = key:match("^(.+)_F$")
              if base[key] == nil and not (stem and base[stem] ~= nil) then unknown[#unknown + 1] = key end
              if type(text) ~= "string" or text == "" then unknown[#unknown + 1] = key .. " (empty)" end
            end
            table.sort(unknown)
            assert.same({}, unknown)
          end)
          it(code .. " has _F forms only for the keys shown with a sex", function()
            local dead = {}
            for key in pairs(loaded.Locale.tables[code]) do
              local stem = key:match("^(.+)_F$")
              if stem and not GENDERED[stem] then dead[#dead + 1] = key end
            end
            table.sort(dead)
            assert.same({}, dead)
          end)
          it(code .. " keeps every placeholder of the enUS text", function()
            local base, wrong = loaded.Locale:Base(), {}
            local function holders(text)
              local set = {}
              for name in tostring(text):gmatch("{(%w+)}") do set[#set + 1] = name end
              table.sort(set)
              return table.concat(set, ",")
            end
            for key, text in pairs(loaded.Locale.tables[code]) do
              local source = base[key] or base[key:match("^(.+)_F$") or ""]
              if source ~= nil and holders(text) ~= holders(source) then wrong[#wrong + 1] = key end
            end
            table.sort(wrong)
            assert.same({}, wrong)
          end)
        end
      else
        pending(code .. ": " .. file .. " is not delivered yet")
      end
    end
  end)
end)

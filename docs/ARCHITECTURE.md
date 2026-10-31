# Architecture

Ashmark is one addon for World of Warcraft Forever with a small core and eleven feature units. The core keeps one event log per character in account-wide SavedVariables; modules write facts into the log and derive everything else from it. This document is the contract every unit is built against. Decisions behind it: `docs/DECISIONS.md`. Platform facts: `docs/research/forever-platform.md`.

## 1. Ground rules

1. **Forever only.** The addon loads through `Ashmark_Forever.toc`. At `ADDON_LOADED` the core checks `ns.Compat.IsForever()`; on any other client it prints one localized line and stops. No module runs.
2. **Mainline API.** Use `C_*` namespaces (`C_QuestLog`, `C_Reputation`, `C_Map`, `C_Item`, `C_Container`, `C_UnitAuras`, `C_ChatInfo`, `C_Timer`). Never Classic Era globals (`GetFactionInfo`, `GetQuestLogTitle`, global `GetSpellInfo`, `GetItemInfo`).
3. **Feature-detect everything uncertain.** Every API listed in section 6 is read through `ns.Compat.Has`. A module whose required capability is missing disables itself and says so in the settings panel and in the test mode report. It never throws.
4. **Secret values are opaque.** Any value that can be secret (unit names, GUIDs, tooltip data, chat payloads, aura data) is read through `ns.Safe`. Code never compares, concatenates, indexes with, or stores a secret value.
5. **Out of combat.** Ashmark never changes UI while `InCombatLockdown()`; it queues through `ns.Combat.Run`. Ashmark creates no secure or protected frames and calls no protected functions.
6. **No combat log.** Never register `COMBAT_LOG_EVENT` or `COMBAT_LOG_EVENT_UNFILTERED`.
7. **No libraries.** No LibStub, Ace3, HereBeDragons, ChatThrottleLib. Everything is Blizzard API plus the core in this repo.
8. **Locale-proof logic.** Logic never matches localized text. Where text matching is unavoidable, it matches Blizzard's own global strings (`ERR_*`, `ITEM_*`), which the client localizes.
9. **Game terms come from the client.** Faction, zone, quest, item, class and race names are read at runtime (`C_Reputation.GetFactionDataByID(id).name`, `C_Map.GetMapInfo(id).name`, `C_QuestLog.GetTitleForQuestID(id)`, `C_Item.GetItemNameByID(id)`, `LOCALIZED_CLASS_NAMES_MALE`). Ashmark's own strings are the only translated text.
10. **Only own data leaves the client.** Addon messages carry the sender's own profile and decisions. Encounters with other players stay local. No free text is ever sent.

## 2. Files

```
Ashmark_Forever.toc
Core/       Init.lua Util.lua Compat.lua Safe.lua Combat.lua Events.lua Bus.lua
            DB.lua Identity.lua Where.lua Log.lua Chronicle.lua Comm.lua Settings.lua Slash.lua
Locales/    Locale.lua                         -- L table, Format(), fallback
            enUS/Core.lua enUS/<Module>.lua    -- base strings, one file per unit
            deDE.lua frFR.lua esES.lua esMX.lua ptBR.lua ruRU.lua koKR.lua zhTW.lua zhCN.lua
UI/         Templates.xml MainFrame.lua Notice.lua ChatLine.lua Compartment.lua
            Tabs/Chronicle.lua Tabs/Decisions.lua Tabs/Encounters.lua Tabs/House.lua
Modules/    Conflicts/Conflicts.lua Conflicts/QuestDialog.lua
            Profile/Profile.lua
            Map/Map.lua
            Encounters/Encounters.lua Encounters/Tooltip.lua
            House/House.lua
            Campfire/Campfire.lua
            Knowledge/Knowledge.lua
            Rumours/Rumours.lua
            Fiction/Fiction.lua
            Traces/Traces.lua                  -- v2 schema only, no behaviour
Data/       Conflicts.lua                      -- GENERATED from data/conflicts/*.csv
Dev/        TestMode.lua Probe.lua
data/conflicts/   *.csv                        -- contribution source, not shipped
tools/      conflicts.py                       -- generate + validate, not shipped
tests/      helpers/wow.lua (API mock)  *_spec.lua (busted)
.luacheckrc .busted .pkgmeta .github/workflows/
```

TOC load order: `Core/Init.lua`, `Core/Util.lua`, `Locales/Locale.lua`, all `Locales/enUS/*.lua`, the nine locale files, remaining `Core/*` in the order listed above, `UI/Templates.xml`, `UI/*.lua`, `UI/Tabs/*.lua`, `Data/Conflicts.lua`, `Modules/**`, `Dev/*`. The TOC lists every file of every unit from the start, so units never edit it.

TOC header:

```
## Interface: 16001
## Title: Ashmark
## Notes: Decisions leave a mark. Solo role-play for World of Warcraft Forever.
## Author: Nullthrone
## Version: @project-version@
## SavedVariables: AshmarkDB
## IconTexture: Interface\Icons\INV_Misc_Book_09
## Category: Roleplay
## AddonCompartmentFunc: Ashmark_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: Ashmark_OnAddonCompartmentEnter
## AddonCompartmentFuncOnLeave: Ashmark_OnAddonCompartmentLeave
## X-License: MIT
```

`Interface: 16001` is the beta and test value; the live value is confirmed at launch.

## 3. Namespace and module contract

Every file starts with `local ADDON, ns = ...`. `ns` is private. The only globals are `AshmarkDB`, the three compartment functions, `SLASH_ASHMARK1/2` and `SlashCmdList.ASHMARK`, and frame names prefixed `Ashmark`.

```lua
-- Core/Init.lua
ns.version          -- from C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.modules          -- name -> module, in registration order

local M = ns:NewModule("Conflicts", {
  requires = { "questLog", "reputation" },   -- ns.Compat.Has keys; all must be true
  optional = { "tooltipProcessor" },         -- read by the module, never blocking
  default  = true,                           -- enabled unless the user turns it off
})
function M:OnInitialize() end   -- ADDON_LOADED, after DB is ready; no game queries yet
function M:OnEnable() end       -- PLAYER_LOGIN (and later when re-enabled in settings)
function M:OnDisable() end      -- optional: settings toggle off; unregister everything
```

The core calls `OnInitialize` for every module, then `OnEnable` for every module whose `requires` are met and whose setting is on. Errors inside these calls are caught with `xpcall` and reported through `geterrorhandler()`; one failing module never stops another. `M.enabled` and `M.unavailable` (list of missing capabilities) are set by the core.

Helpers available on every module:

```lua
M:RegisterEvent(event, handler)          -- handler(self, event, ...)
M:RegisterUnitEvent(event, unit, handler)
M:UnregisterEvent(event)
M:Subscribe(topic, handler)              -- internal bus, handler(self, topic, ...)
M:Fire(topic, ...)                       -- = ns.Bus:Fire
M:Char()                                 -- current character record (DB)
M:Setting(key)                           -- ns.Settings:Get("<Module>.<key>")
```

Events are dispatched by one hidden frame in `Core/Events.lua`. Each handler call is wrapped in `xpcall`.

### Internal bus topics

| Topic | Payload | Fired by |
| --- | --- | --- |
| `LOG_ADDED` | entry | Log |
| `CHAPTER_CLOSED` | chapter record | Campfire |
| `ALLIANCE_FORMED` | conflictId, side | Conflicts |
| `ALLIANCE_BROKEN` | conflictId, side, questId | Conflicts |
| `PROFILE_CHANGED` | axes table | Profile |
| `GROUP_SESSION_ENDED` | session record | Encounters |
| `PEER_SEEN` | peer record | Fiction |
| `RUMOUR_HEARD` | rumour record | Rumours |
| `SETTINGS_CHANGED` | key, value | Settings |

## 4. SavedVariables

One account-wide variable, `AshmarkDB`. No `SavedVariablesPerCharacter`: the per-character folder layout on Forever is unverified and first names are not unique.

```lua
AshmarkDB = {
  schema   = 1,
  created  = <epoch>,
  settings = { ["Conflicts.enabled"] = true, ... },           -- flat keys, see 4.3
  chars    = { [guid] = CharRecord },
  houses   = { [houseKey] = HouseRecord },
  contacts = { [guid] = Contact },                            -- Module 4, local only
  peers    = { [guid] = Peer },                               -- Fiction, other Ashmark users
  rumours  = { heard = { [id] = Rumour }, told = { [id] = true } },
  traces   = { schema = 0, outbox = {}, inbox = {} },         -- v2, see 4.5
  dev      = { tests = {}, probes = {} },                     -- test mode output
}
```

### 4.1 CharRecord

```lua
{
  guid, name, surname, ruleset, faction, race, class, sex, level,  -- refreshed at login
  houseOverride = nil,       -- surname key set by /ashmark house <name>
  firstSeen, lastSeen,       -- epoch
  log      = { Entry, ... }, -- append-only, see 4.2
  logBase  = 0,              -- index offset after compaction
  chapters = { { from = i, to = j, closed = epoch, m = mapId, n = number }, ... },
  conflicts = { allied = { [conflictId] = "A"|"B" }, broken = { [conflictId] = n }, violations = n },
  profile   = { fidelity = 0, habitat = 0, mercy = 0, updated = epoch },
  knowledge = { held = { [itemId] = epoch } },
  stats     = { [key] = number },   -- counters modules keep for themselves
}
```

`houseKey` = `string.lower(surname)` with spaces trimmed, or `houseOverride`.

### 4.2 Log entries

An entry is a flat table with short keys. Every entry has `t` (epoch, `time()`) and `k` (kind). Location fields, where known: `m` (uiMapID), `x`, `y` (0–1, two decimals), `i` (instanceID when inside an instance).

| Kind | Fields | Writer |
| --- | --- | --- |
| `quest.accept` | q | Core (Log) |
| `quest.turnin` | q | Core |
| `quest.abandon` | q | Core |
| `zone` | m | Core |
| `level` | l | Core |
| `death` | | Core |
| `rep` | f, s (standing id), d (delta) | Core |
| `gold` | src (`quest`, `loot`, `vendor`, `trade`, `mail`, `other`), c (copper) | Core |
| `rest.camp` | | Campfire |
| `rest.bedroll` | | Campfire |
| `chapter` | n (chapter number) | Campfire |
| `alliance` | c (conflictId), side | Conflicts |
| `violation` | c, side, q | Conflicts |
| `houseturn` | c, side, q, h (houseKey) | Conflicts |
| `kill.neutral` | | Profile |
| `kill.critter` | | Profile |
| `group.end` | g (session id), n (members), i, e (outcome) | Encounters |
| `contact` | p (guid) | Encounters |
| `rumour` | r (rumour id) | Rumours |
| `peer` | p (guid), a (archetype) | Fiction |
| `item.held` | it | Knowledge, first time only |

The core writes the `quest.*`, `zone`, `level`, `death`, `rep` and `gold` kinds itself, so every module reads one consistent stream. Modules register their kinds with `ns.Log:RegisterKind(kind, { fields = {...}, render = fn })`.

API:

```lua
ns.Log:Add(kind, fields) -> entry       -- adds t, location (unless fields.noWhere), fires LOG_ADDED
ns.Log:Iter(char, fromIndex)            -- iterator over (index, entry)
ns.Log:Count(char)
ns.Log:Last(char, kind)
```

**Cap.** At 4,000 entries, the oldest closed chapters are compacted: their entries are dropped except kinds marked `keep = true` at registration (`alliance`, `violation`, `houseturn`, `chapter`, `level`, `contact`, `peer`), and `logBase` advances. Chapter ranges are rewritten to the compacted indices.

### 4.3 Settings

Flat keys `"<Unit>.<name>"`. Defaults registered by each unit with `ns.Settings:Register(key, default, labelKey, tooltipKey)`. The settings panel lists every registered key. Units read with `M:Setting(name)`.

Core keys: `<Module>.enabled` for every module, `Core.chatLines` (show Ashmark lines in chat, default true), `Core.sounds` (default true), `Comm.share` (send own profile and rumours to other Ashmark users, default true), `Comm.guild` (also use the guild channel, default false).

### 4.4 Load safety

`ADDON_LOADED`: if `AshmarkDB` is nil, create it with `created = time()`. If it exists, run migrations from `schema` to the current number. A table without `schema` is renamed into `AshmarkDB.recovered` and a fresh table is built around it, so nothing is overwritten silently. The test mode reports `created` and the entry count, which makes a lost SavedVariables round trip visible.

### 4.5 Traces (v2)

v1 reserves `AshmarkDB.traces` with `schema = 0`. v2 fills `outbox` with own traces (grave, extinguished camp, note from templates) and a companion app writes `inbox` between sessions. Format, documented now so v2 can build on it:

```lua
{ id = "<guid>-<t>", k = "grave"|"camp"|"note", m, x, y, t, tpl = templateId, args = { ... }, a = archetype }
```

v1 contains no code that reads or writes traces.

## 5. Core services

### 5.1 Compat

```lua
ns.Compat.IsForever()   -- WOW_PROJECT_ID == WOW_PROJECT_CAMELOT, or interface 16000..16999
ns.Compat.build         -- { version, build, date, interface } from GetBuildInfo()
ns.Compat.Has.<cap>     -- booleans, computed once at ADDON_LOADED, recomputed at PLAYER_LOGIN
ns.Compat.Check(cap)    -- recompute one capability
```

Capabilities and their detection:

| Key | True when |
| --- | --- |
| `questLog` | `C_QuestLog.GetTitleForQuestID` and `C_QuestLog.GetLogIndexForQuestID` exist |
| `questFrame` | `QuestFrameDetailPanel` (or `QuestFrame`) exists |
| `reputation` | `C_Reputation.GetFactionDataByID` exists |
| `map` | `C_Map.GetBestMapForUnit` and `C_Map.GetPlayerMapPosition` exist |
| `mapPins` | `WorldMapFrame.AddDataProvider`, `MapCanvasDataProviderMixin` and `MapCanvasPinMixin` exist |
| `tooltipProcessor` | `TooltipDataProcessor.AddTooltipPostCall` and `Enum.TooltipDataType` exist |
| `auras` | `C_UnitAuras.GetPlayerAuraBySpellID` exists |
| `addonMessages` | `C_ChatInfo.SendAddonMessage` and `C_ChatInfo.RegisterAddonMessagePrefix` exist |
| `canSend` | `addonMessages`, and not `IsTrialAccount()` and not `IsVeteranTrialAccount()` |
| `secrets` | `issecretvalue` or `canaccessvalue` exists |
| `settingsApi` | `Settings.RegisterVerticalLayoutCategory` and `Settings.RegisterAddOnCategory` exist |
| `scrollBox` | `CreateScrollBoxListLinearView` and `CreateDataProvider` exist |
| `container` | `C_Container.GetContainerItemID` exists |
| `itemInfo` | `C_Item.GetItemInfo` exists |
| `encounters` | the `ENCOUNTER_END` event can be registered |
| `legacy` | `C_Reputation.GetFactionDataByID(2802)` returns data, or `C_MajorFactions.GetMajorFactionData(2802)` does |
| `screenshot` | `Screenshot` exists |
| `rulesets` | `C_GameRules.IsGameRuleActive` and `Enum.GameRule` exist |

### 5.2 Safe

```lua
ns.Safe.IsSecret(v)                -- issecretvalue(v) if available, else false
ns.Safe.Value(v)                   -- nil if secret, else v
ns.Safe.Call(fn, ...)              -- pcall; returns nil if it failed or any result is secret
ns.Safe.UnitName(unit)             -- name, surname or nil
ns.Safe.UnitGUID(unit)             -- guid or nil
ns.Safe.UnitIdentityRestricted(unit) -- C_Secrets.ShouldUnitIdentityBeSecret(unit) if present
ns.Safe.InLockdown()               -- C_ChatInfo.InChatMessagingLockdown() if present, else false
```

`canaccessvalue` is preferred over `issecretvalue` when both exist. All Safe functions return plain Lua values or nil.

### 5.3 Identity

```lua
ns.Identity:Player() -> { guid, name, surname, full, ruleset, faction, race, class, sex, level }
ns.Identity:Unit(unit) -> same shape or nil       -- via Safe; nil if anything is secret
ns.Identity:HouseKey(char) -> string or nil
```

Surname: second return of `UnitName("player")` on Forever (shipped Forever addons read it so; unverified). If it is nil or empty, `UnitFullName("player")` is tried; if still nil, the character has no house until `/ashmark house <surname>` sets `houseOverride`. Ruleset: `C_GameRules.IsGameRuleActive(Enum.GameRule.<X>)` for `HardcoreRuleset`, `RPPvPRuleset`, `RPRuleset`, `PvPRuleset`, in that order, else `Normal`. Each probe is guarded: an unknown enum key means not active.

### 5.4 Where

`ns.Where()` returns `{ m, x, y, i }`: `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(m, "player"):GetXY()` rounded to two decimals, and `select(8, GetInstanceInfo())` when `IsInInstance()`. Positions inside instances are usually nil; that is expected.

### 5.5 Combat

`ns.Combat.Run(fn, ...)` runs `fn` now if not in combat lockdown, otherwise queues it until `PLAYER_REGEN_ENABLED`. Used for every show, hide, resize and notice.

### 5.6 Comm

Prefix `Ashmark` (registered at login). Wire format, all ASCII:

```
<version>|<type>|<field1>|<field2>|...
```

`version` = `1`. Fields are escaped: `|` → `\p`, `\` → `\\`. Each message must fit 255 bytes; the encoder refuses longer messages (it never chunks).

| Type | Fields | Meaning |
| --- | --- | --- |
| `HI` | archetypeKey, originMapId, rulesetKey, ashmarkVersion | Hello; sent when grouped with someone new, at most once per 10 minutes per channel |
| `PR` | fidelity, habitat, mercy (integers -100..100) | Own profile; reply to `HI` |
| `RU` | rumourId, templateKey, hops, strength (0–100), arg1, arg2, arg3 | One rumour |

Channels: `PARTY` and `RAID` when grouped and not in chat lockdown; `GUILD` if `Comm.guild`; `WHISPER` only as a reply to a peer's `HI`. `CHANNEL` is not used in v1.

Throttle: token bucket per prefix, capacity 6, refill 1 per 1.5 s, which stays under Blizzard's 10 per prefix with 1 per second regeneration. Queue priorities: `HI` > `PR` > `RU`; the queue holds at most 30 messages and drops the oldest `RU` first. Send results other than success (`Enum.SendAddonMessageResult`) are counted per code in `ns.Comm.stats` and shown in the test mode.

Receive: `CHAT_MSG_ADDON` with our prefix. Sender name may be secret: run it through `ns.Safe.Value`; drop the message if nil. Messages from self are ignored. Unknown versions are ignored. Handlers: `ns.Comm:Register(type, fn(sender, fields, channel))`.

If `Compat.Has.canSend` is false or `Comm.share` is off, Ashmark only receives.

### 5.7 Chronicle

`ns.Chronicle:Chapters(char)` returns chapters with entries; the open chapter is the range after the last closed one. `ns.Chronicle:Render(entry, char)` returns one localized sentence or nil, through the renderer each kind registered. Chronicle text is generated at display time, so it follows the client locale and never stores prose.

### 5.8 Localization

```lua
local L = ns.L                       -- table of key -> string
L.CONFLICT_CONTRADICTS = "Contradicts your alliance with {faction}."
ns.Format(L.CONFLICT_CONTRADICTS, { faction = name })
ns.Gender(key, sex)                  -- returns L[key .. "_F"] for sex 3 if present, else L[key]
```

Keys are upper snake case with a unit prefix (`CORE_`, `CONFLICT_`, `PROFILE_`, `MAP_`, `ENC_`, `HOUSE_`, `CAMP_`, `KNOW_`, `RUMOUR_`, `FICTION_`, `TEST_`). Placeholders are named, `{name}`, so translators can reorder them. `enUS/*.lua` define every key. A locale file starts with `if GetLocale() ~= "deDE" then return end` and overrides keys; missing keys fall back to enUS through a metatable. `esMX` and `esES` are separate files. A key ending in `_F` is the feminine form, used for languages that inflect (de, fr, es, pt, ru). The test mode lists missing keys for the active locale.

### 5.9 Slash commands

`/ashmark` and `/amk`. Subcommands: none (toggle window), `test`, `probe`, `house <surname>`, `house reset`, `debug` (toggle debug output), `reset confirm` (wipe this character's record, asks via StaticPopup).

## 6. UI

Rules from the concept, binding for every unit:

- **Inherit, never rebuild.** Frames come from Blizzard templates: `PortraitFrameTemplate` for the window, `PanelTabButtonTemplate` for tabs with `PanelTemplates_SetNumTabs/SetTab/TabResize`, `WowScrollBoxList` with `MinimalScrollBar`, `CreateScrollBoxListLinearView` and `CreateDataProvider` for lists, `UIPanelButtonTemplate` for buttons, `InputBoxTemplate` for single-line input, `StaticPopupDialogs` for confirmations and the note editor.
- **Fonts:** `QuestTitleFont` for headings, `QuestFont` for text on parchment, `GameFontNormal`, `GameFontHighlight`, `GameFontHighlightSmall`, `GameFontDisable` for lists. No custom sizes, no custom colors except class colors (`C_ClassColor.GetClassColor`) and the standard faction-standing colors (`FACTION_BAR_COLORS`).
- **Parchment** only as a client texture: try the atlases in `ns.UI.PARCHMENT_ATLASES` with `C_Texture.GetAtlasInfo`; if none exists, use the window's default inset background. Never `SetColorTexture` for surfaces.
- **Icons** from the client: class atlases via `GetClassAtlas` when present, quest and item icons via their APIs, map icons from Blizzard's atlas. No emoji, no custom vector art.
- **Sounds** with `PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)` / `IG_QUEST_LOG_CLOSE` on open and close, `SOUNDKIT.IG_ABILITY_PAGE_TURN` on chapter change; every constant guarded, `Core.sounds` respected.
- **Known game patterns, not tables.** No grid lines, sortable column headers, toggle switches or data tables.
- **Information where it happens:** quest dialog line (Conflicts), unit tooltip line (Encounters), world-map pins (Map), centre-screen notice (Campfire), chat line (Rumours, Encounters recognition).

### 6.1 Main window

`AshmarkFrame` (`PortraitFrameTemplate`, 640 × 500, movable, `UISpecialFrames` so Escape closes it). Portrait: the player portrait via `SetPortraitTexture`. Tabs register through:

```lua
ns.UI.MainFrame:AddTab(id, labelKey, order, builder)  -- builder(parentFrame) called once, lazily
ns.UI.MainFrame:Refresh(id)                           -- rebuild the tab's data provider
ns.UI.MainFrame:Show(id)
```

| Tab | Unit | Content |
| --- | --- | --- |
| Chronicle | Core (`UI/Tabs/Chronicle.lua`) | Questlog layout: chapter list on the left, parchment page on the right with the rendered sentences of the selected chapter |
| Decisions | Conflicts | Alliances with their faction names and dates, open conflicts in the current zone, broken alliances and the violation count |
| Encounters | Encounters | Friends-list pattern: name in class color, times met, last place, note; contact marker for recurring players |
| House | House | Family members (class icon, level, name), profile axes as status bars, inherited feuds, family chronicle, Legacy if readable |

Each tab file under `UI/Tabs/` belongs to its unit (Chronicle to the core).

### 6.2 Other surfaces

- `ns.UI.Notice:Show(text)` — centre-screen message using `RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.SYSTEM)`; queued out of combat.
- `ns.UI.ChatLine:Print(text, kind)` — `DEFAULT_CHAT_FRAME:AddMessage` with Ashmark's prefix, color from `ChatTypeInfo` (`SYSTEM` for core, `MONSTER_SAY` for rumours); respects `Core.chatLines`.
- Addon Compartment and the settings category `Ashmark` (Settings API), `UI/Compartment.lua` and `Core/Settings.lua`.

## 7. Units

Each unit owns its files and its `Locales/enUS/<Unit>.lua` and `tests/<unit>_spec.lua`. A unit needing a core change does not make it; it lists the change in its report.

### 7.1 Conflicts (Module 1)

Data, generated into `Data/Conflicts.lua`:

```lua
ns.Data.Conflicts = {
  version = "2026-10-31",
  list = {
    { id = "desolace_centaurs", zone = 1443, theme = "feud",
      sides = { A = { faction = 92, quests = { 1367, 1368 } },
                B = { faction = 93, quests = { 1365, 1366 } } },
      anchor = { m = 1443, x = 0.55, y = 0.45 },
      honored = 9,                 -- standing id that forms the alliance by reputation alone
      verified = false, source = "https://..." },
  },
}
```

`ns.Data.ConflictIndex` (built at load): `byQuest[q] = { conflictId, side }`.

Rules:
- `QUEST_ACCEPTED` or `QUEST_TURNED_IN` of a quest on side S of conflict C with no alliance in C → alliance S (`alliance` entry, `ALLIANCE_FORMED`).
- Standing with side S's faction ≥ `honored` → alliance S, if none yet. Checked at login and on `UPDATE_FACTION`.
- `QUEST_DETAIL` for a quest on the other side of an existing alliance → line in the quest dialog: `CONFLICT_CONTRADICTS` with the allied faction's name. Quest acceptance is never blocked; addons cannot block it.
- `QUEST_TURNED_IN` of such a quest → `violation` entry, `conflicts.violations + 1`, alliance in C moves to the other side, `broken[C] + 1`, `ALLIANCE_BROKEN`. Chronicle wording depends on the profile: opportunistic (fidelity ≤ -34) → `CONFLICT_SWITCHED`; otherwise `CONFLICT_BROKE_WORD`.
- House hint: if this character has no alliance in C and a sibling (same house key) does, the quest dialog shows `HOUSE_STANDS_AGAINST` for quests on the sibling's opposite side. Turning one in writes `houseturn` (not a violation).
- Quest dialog line: one `FontString` (`GameFontNormal`, red-tinted via `RED_FONT_COLOR` for contradictions, `NORMAL_FONT_COLOR` for house hints) anchored below the quest title in `QuestFrameDetailPanel`/`QuestInfoTitleHeader`; hidden on `QUEST_FINISHED`.

### 7.2 Profile (Module 2)

Three axes in [-100, 100], each the clamped sum of weighted events with a 30-day half-life, recomputed from the log on login and incrementally on `LOG_ADDED`.

| Axis | + | − |
| --- | --- | --- |
| Fidelity | quest turned in on an allied side (+2), alliance kept for 7 days (+5, once per alliance per week) | violation (−25, −15 if already opportunistic), abandoned quest (−2), gold from looting corpses vs quest rewards (−1 per 10 gold of loot beyond quest gold, per day) |
| Habitat | resting at a camp or bedroll (+6 wild), 10 minutes outdoors outside cities (+1 wild) | 10 minutes resting in a city or inn (−1 civil), turning in quests in capitals (−1 civil) |
| Mercy | a day without needless kills (+1, max 30 per month) | `kill.neutral` (−3), `kill.critter` (−2) |

Positive Habitat = wild, negative = civil; positive Mercy = merciful. The weights live in one table at the top of `Profile.lua` and are covered by tests.

Kill approximation, no combat log: track the current target on `PLAYER_TARGET_CHANGED` and `UNIT_HEALTH` for `target`. A target that is not player-controlled, had `UnitReaction(target, "player") == 4` (neutral), was not in combat (`not UnitAffectingCombat(target)`) when the player entered combat (`PLAYER_REGEN_DISABLED`) and is then dead (`UnitIsDead`) is a `kill.neutral`. A dead target whose `UnitCreatureType` equals the client's localized critter type name and which the player attacked counts as `kill.critter`. Every read goes through `ns.Safe`; a secret value means the event is not counted.

Archetype, used by Fiction and the House tab: the axis with the largest absolute value ≥ 34 decides — fidelity + `PROFILE_OATHKEEPER`, − `PROFILE_OPPORTUNIST`; habitat + `PROFILE_WANDERER`, − `PROFILE_TOWNSFOLK`; mercy + `PROFILE_GENTLE`, − `PROFILE_RUTHLESS`; none → `PROFILE_PRAGMATIST`. Archetype keys go over the wire, never text. Origin: the zone with the most `zone` entries in the first 20 hours played (map id).

### 7.3 Map (Module 3)

`WorldMapFrame:AddDataProvider(provider)` with a provider built from `MapCanvasDataProviderMixin` and pins from `MapCanvasPinMixin` (template `AshmarkMapPinTemplate` in `UI/Templates.xml`). On `RefreshAllData` for the shown map it places:

- conflict anchors of the map's conflicts: allied, hostile (other side of an alliance) or open, using Blizzard atlases (`ns.Map.ATLAS`), tooltip with faction names and state;
- places where this character broke an alliance (`violation` entries with position);
- chapter closes (`chapter` entries with position): the camps where chapters ended.

A child map shows its own pins; a continent map shows conflict anchors only. Pins are hidden when the module is off. If `mapPins` is false, the module is unavailable. Known risk: map-replacement addons (OpenMap, Leatrix Maps) may not call data providers.

### 7.4 Encounters (Module 4)

- On `GROUP_ROSTER_UPDATE` outside instances and outside chat lockdown, snapshot members via `ns.Identity:Unit`. A group session starts with the first other member and ends when the player leaves the group or the group dissolves.
- Context per session: zones and instances entered (`PLAYER_ENTERING_WORLD` + `GetInstanceInfo`), `ENCOUNTER_END` successes and failures inside it (if `encounters`), whether a chapter closed during it (campfire together), whether the player was removed (`CHAT_MSG_SYSTEM` equal to `ERR_UNINVITE_YOU`).
- Outcome `e`: `boss` (any successful encounter), `wipe` (failed encounters and no success), `kick`, `camp`, `travel`.
- At session end every member becomes or updates a `Contact`: `{ guid, name, surname, class, race, faction, ruleset, first, last, count, lastPlace = mapId, lastInstance, outcomes = { [e] = n }, note = "", sessions = { last 10 } }`, and a `group.end` entry is logged.
- A contact met 3 or more times is a recurring contact (`ENC_RECURRING`).
- Recognition: when a known contact joins the group, one chat line `ENC_RECOGNISE` ("You know {name}: met {count}×, last in {place}.").
- Unit tooltip: `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)`; resolve the unit with `tooltip:GetUnit()`; skip if the GUID is secret or unknown; add `ENC_TOOLTIP` ("Met: {count}× · last {place}").
- Note editor: `StaticPopupDialogs.ASHMARK_NOTE` with `hasEditBox`, max 120 characters, stored locally only.
- Contacts are never sent anywhere.

### 7.5 House (Module 5)

- House members: all `AshmarkDB.chars` with the same house key. A character without surname and without override has no house.
- House tab: members sorted by level, class icon, level, full name, ruleset tag when rulesets differ; the three axes as `StatusBar`s using the standard status bar texture, labeled with the archetype; inherited feuds = alliances of siblings that this character does not share; family chronicle = all members' `alliance`, `violation`, `houseturn`, `chapter`, `level` (every 10 levels) entries, newest first; Legacy level if `legacy`.
- Feud hint data for Conflicts: `ns.House:SiblingAlliances(char)` → `{ [conflictId] = { side, siblingGuid } }`.
- `/ashmark house <surname>` sets `houseOverride` for the current character; `house reset` clears it.

### 7.6 Campfire (Module 6)

Aura spell IDs (Wowhead Forever, unverified until the probe confirms them):

```lua
CAMP_NEARBY = 1283391     -- passive, 100 yd
CAMP_WELCOME = 1289723    -- while sitting at a camp
CAMP_BENEFITS = 1229741   -- after one minute at a camp
CAMP_BOOSTED = 1229451    -- Camp Tent debuff
BEDROLL_AURAS = { }       -- Cozy Sleeping Bag "Well-Rested"; filled by the probe, empty until verified
```

- On `UNIT_AURA` for `player` (out of combat; ignore if aura data is secret): `CAMP_WELCOME` appearing starts a rest; `CAMP_BENEFITS` appearing while resting completes it → `rest.camp`. A bedroll aura appearing → `rest.bedroll`.
- A completed rest closes the open chapter if it holds at least 20 entries or spans at least 30 minutes: `chapter` entry, `chapters` record, `CHAPTER_CLOSED`, centre notice `CAMP_CHAPTER_CLOSED` ("Chapter {roman} closes · {place}"), page-turn sound.
- Party members present when the chapter closes are passed to Encounters through the event (outcome `camp`) and to Fiction/Rumours (exchange trigger).

### 7.7 Knowledge (Module 7)

- Held items: scan bags (`C_Container`, including the reagent bag), equipment (`GetInventoryItemID` for slots 1–19) on `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED` and `BANKFRAME_OPENED`; first sighting writes `knowledge.held[itemId]` and an `item.held` entry.
- Tooltip: `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`. If the item is not held by this character, not a quest reward currently shown in the quest frame (setting `Knowledge.questRewards`, default true), not secret, and the server has revealed it (`C_Item.GetItemInfo` returns data): hide every line after the first whose text is not in the keep set (item level, binding, slot and type lines, identified by comparing with `ITEM_LEVEL`, `ITEM_BIND_*`, `ITEM_SOULBOUND`, `INVTYPE_*` and the item's own type and subtype from `C_Item.GetItemInfoInstant`), then add `KNOW_UNKNOWN` ("Your character has never held this."). Hiding means `SetText("")` on the line's font strings followed by `tooltip:Show()` to resize.
- Applies to `GameTooltip`, `ItemRefTooltip` and the shopping tooltips. If any line text is secret, the module leaves the tooltip untouched.
- Default on. The test mode reports whether hiding took effect on a sample item.

### 7.8 Rumours

- Seeds: own `alliance`, `violation` and `houseturn` entries create a rumour `{ id = "<guid>:<t>", tpl = "ALLIANCE"|"BROKE"|"TURNED", args = { archetypeKey, factionId, mapId }, hops = 0, strength = 100, t }` in `rumours.heard` (own rumours are marked `own = true`).
- Exchange: when Fiction sees a peer (after `HI`), send up to 3 rumours the peer has not been sent (newest, strongest first), and mark them in `told`.
- Received rumour: `hops + 1`, strength × 0.7; at `hops ≥ 2` the map id is replaced by its continent (`C_Map.GetMapInfo(m).parentMapID` chain to `Enum.UIMapType.Continent`); at `hops ≥ 3` the faction is dropped (template variant `_VAGUE`). Strength < 20 → discarded. Age decay: strength halves every 3 days (applied on read).
- Hearing a new rumour prints `RUMOUR_HEARD_<TPL>` as a chat line ("People say {archetype} from {place} sided with {faction}."). Entering a zone a stored rumour refers to prints it again at most once per day.
- At most 200 stored rumours; weakest dropped first.
- No names: rumours describe an archetype and an origin, never a character.

### 7.9 Fiction (silent shared fiction)

- On joining a group, and when a chapter closes with party members present, send `HI` (and `PR` on request) if `Comm.share`.
- On `HI`/`PR` from a party member: store `peers[guid] = { archetype, origin, ruleset, version, profile, lastSeen }`, write a `peer` entry, fire `PEER_SEEN`.
- Chronicle: `group.end` entries render the peers in the group with their archetype ("You travelled with Thalen, an oathkeeper from Westfall."); Encounters' tooltip line adds the archetype for peers.
- Nothing is displayed to the other player; the dungeon stays pure MMO.

### 7.10 Test mode and probe (Dev)

`/ashmark test`: runs every check synchronously, stores `AshmarkDB.dev.tests[#+1] = { t, build, locale, project, results = { { id, ok, detail }, ... } }`, prints a summary, opens the main window on the Chronicle tab and the quest log, takes a `Screenshot()` after one second, then calls `C_UI.Reload()` (fallback `ReloadUI()`) after `SCREENSHOT_SUCCEEDED`/`SCREENSHOT_FAILED` or three seconds. If the reload is blocked, it prints `TEST_RELOAD_MANUALLY`.

Checks: Forever detection; every `Compat.Has` capability; each template used by the UI can be created (`pcall(CreateFrame, "Frame", nil, nil, template)`); each atlas in `PARCHMENT_ATLASES` and `ns.Map.ATLAS` (`C_Texture.GetAtlasInfo`); font objects exist; every SOUNDKIT constant used; locale completeness for the active locale; `Identity:Player()` fields; SavedVariables age and entry count; Comm send result codes (self-whisper); camp aura IDs resolve to spell names (`C_Spell.GetSpellName`); a sample tooltip hide on a known revealed item (Knowledge).

`/ashmark probe`: records raw facts for the open platform questions into `AshmarkDB.dev.probes[#+1]` with the context (zone, instance, in party, in combat): `GetBuildInfo()`, `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT`, `UnitName("player")`, `UnitFullName("player")`, `GetRealmName()`, `UnitGUID("player")`, `C_Secrets.ShouldUnitIdentityBeSecret("party1")`, `issecretvalue(UnitName("party1"))`, `C_ChatInfo.InChatMessagingLockdown()`, `C_RestrictedActions` state if present, `IsTrialAccount()`, `C_CombatLog.IsCombatLogRestricted()` if present, camp auras present, faction data for 92, 93, 2802, `C_GameRules.GetForeverExperiencePreset()`, `GetLocale()`. Never registers the combat log. Each value is stored through `tostring` after a secret check (secret → the string `"<secret>"`).

## 8. Tests

- `busted` from the repo root; `.busted` points at `tests/`. `tests/helpers/wow.lua` provides a mock WoW environment: `CreateFrame` returning stub frames that accept any method call, the `C_*` functions used, `GetLocale`, `time`, `GetTime`, `C_Timer.After` (immediate), `issecretvalue`, and a loader that runs the TOC file list into one `ns`.
- Every unit has `tests/<unit>_spec.lua` covering its rules: Conflicts (alliance, violation, house hint, reputation trigger), Profile (weights, decay, archetype, kill approximation), Rumours (decay, precision loss, caps), Comm (escape, size limit, throttle, priorities), Log (cap and compaction), DB (migrations, recovery), Locale (fallback, Format, gender, completeness of every locale against enUS), Identity (surname parsing, house key), Knowledge (held state, keep set), Campfire (aura transitions, chapter thresholds), Encounters (session lifecycle, outcomes, contact merge).
- `luacheck .` must pass with `.luacheckrc` (std `lua51`, WoW globals as `read_globals`, Ashmark globals as `globals`).
- CI runs both on every push and pull request.

## 9. Ownership for parallel work

| Unit | Owns |
| --- | --- |
| Core | `Ashmark_Forever.toc`, `Core/*`, `Locales/Locale.lua`, `Locales/enUS/Core.lua`, `UI/*` except other units' tabs, `UI/Tabs/Chronicle.lua`, `Dev/*`, `Locales/enUS/Test.lua`, `tests/helpers/*`, `tests/core_*_spec.lua`, `.luacheckrc`, `.busted` |
| Conflicts | `Modules/Conflicts/*`, `UI/Tabs/Decisions.lua`, `Locales/enUS/Conflicts.lua`, `tests/conflicts_spec.lua` |
| Profile | `Modules/Profile/*`, `Locales/enUS/Profile.lua`, `tests/profile_spec.lua` |
| Map | `Modules/Map/*`, `Locales/enUS/Map.lua`, `tests/map_spec.lua` |
| Encounters | `Modules/Encounters/*`, `UI/Tabs/Encounters.lua`, `Locales/enUS/Encounters.lua`, `tests/encounters_spec.lua` |
| House | `Modules/House/*`, `UI/Tabs/House.lua`, `Locales/enUS/House.lua`, `tests/house_spec.lua` |
| Campfire | `Modules/Campfire/*`, `Locales/enUS/Campfire.lua`, `tests/campfire_spec.lua` |
| Knowledge | `Modules/Knowledge/*`, `Locales/enUS/Knowledge.lua`, `tests/knowledge_spec.lua` |
| Rumours | `Modules/Rumours/*`, `Locales/enUS/Rumours.lua`, `tests/rumours_spec.lua` |
| Fiction | `Modules/Fiction/*`, `Modules/Traces/*`, `Locales/enUS/Fiction.lua`, `tests/fiction_spec.lua` |
| Dataset | `data/conflicts/*`, `tools/conflicts.py`, `Data/Conflicts.lua` |
| Localization | `Locales/<locale>.lua` for the nine non-English locales |

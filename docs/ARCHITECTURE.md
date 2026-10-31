# Architecture

Ashmark is one addon for World of Warcraft Forever: a core and nine feature modules. The core keeps one event log per character in account-wide SavedVariables; modules write facts into the log and derive everything else from it. This document is the contract every unit builds against; section 9 lists the units and the files each one owns. Decisions behind it: `docs/DECISIONS.md`. Platform facts: `docs/research/forever-platform.md`. Values marked unverified are checked by the test mode and the probe (7.10) at launch.

## 1. Ground rules

1. **Forever only.** The addon loads through `Ashmark_Forever.toc` or `Ashmark_Camelot.toc` (same file list). At `ADDON_LOADED` for this addon the core checks `ns.Compat.IsForever()`; on any other client it prints one localized line and stops. No module runs.
2. **Mainline API.** Use `C_*` namespaces (`C_QuestLog`, `C_Reputation`, `C_Map`, `C_Item`, `C_Container`, `C_UnitAuras`, `C_ChatInfo`, `C_Timer`). Never Classic Era globals (`GetFactionInfo`, `GetQuestLogTitle`, global `GetSpellInfo`, `GetItemInfo`).
3. **Feature-detect everything uncertain.** Every API in the table in 5.1 is read through `ns.Compat.Has`, and every event through the validity check in 3.5. A module whose required capability is missing disables itself and says so in the settings panel and in the test report. Nothing throws.
4. **Secret values are opaque.** Any value that can be secret is read through `ns.Safe` (5.2). Code never compares, concatenates, negates, indexes with, uses as a table key or stores a secret value. A handler that meets a secret returns without side effects. `ns.Log:Add` and `ns.Safe.Clean` refuse secrets at write time.
5. **Combat.** Ashmark's own windows (`AshmarkFrame`, `AshmarkDialog`, `AshmarkNoticeFrame`) are shown, hidden, moved and resized only out of combat, through `ns.Combat.Run` (Escape still closes the two in `UISpecialFrames` at any time; they are not protected, so this is harmless). Tooltip post-calls and the quest-dialog line (7.1) apply at once; chat lines print at any time; map pins are never acquired in combat (7.3). Ashmark creates no secure frames and calls no protected function. The only hardware-event call is `Screenshot()` inside the `/ashmark test` handler.
6. **No combat log.** Never register `COMBAT_LOG_EVENT` or `COMBAT_LOG_EVENT_UNFILTERED`; never call `CombatLogGetCurrentEventInfo`.
7. **No libraries.** No LibStub, Ace3, HereBeDragons, ChatThrottleLib, LibDialog. Everything is Blizzard API plus the core in this repo.
8. **Locale-proof logic.** Logic prefers typed data (IDs, enums, `Enum.TooltipDataLineType`). Where text matching is unavoidable, it matches only strings the client localizes itself: global strings (`ERR_*`, `ITEM_*`) and names returned by client APIs (`C_CreatureInfo`, `C_Item.GetItemInfoInstant`).
9. **Game terms come from the client** through `ns.Names` (5.7), which copes with uncached data. Ashmark's own strings are the only translated text.
10. **What leaves the client.** Addon messages carry the sender's own GUID, archetype, origin, ruleset, version and profile (`HI`, `PR`), and rumours. A rumour carries only a random id, a template key, an archetype key, a faction id, a map id, hops, strength and age: never a GUID, a name or free text; the id and the content stay the same on every hop (7.8). Contacts, notes and peers stay local.
11. **Blizzard frames are read-only.** Never `SetPoint`, `SetText`, `SetHeight`, `Show`, `Hide` or `SetScript` on a Blizzard frame or region. Use `HookScript`, `hooksecurefunc`, `TooltipDataProcessor` and map data providers. The one exception: inside tooltip post-calls, Encounters and Knowledge add lines, Knowledge blanks lines (7.7), and either may call `tooltip:Show()` after its edits to resize the tooltip. `GameTooltip` after Ashmark's own `SetOwner` call (map pins, the compartment entry, list rows) is filled, shown and hidden as usual.
12. **Lua 5.1.** No `goto`, `//`, bit operators or `table.unpack`; use `unpack` and `select("#", ...)`. Numbers on the wire go through `string.format("%d", n)`.
13. **No stored array positions.** Modules reference log entries by sequence number (4.2), never by index into `char.log`.

## 2. Files

The tree is in TOC load order. Both TOCs list every file of every unit from the start, so units never edit them.

```
Core/       Init.lua Util.lua
Locales/    Locale.lua
            enUS/Core.lua enUS/Test.lua enUS/Conflicts.lua enUS/Profile.lua enUS/Map.lua
            enUS/Encounters.lua enUS/House.lua enUS/Campfire.lua enUS/Knowledge.lua
            enUS/Fiction.lua enUS/Rumours.lua
            deDE.lua frFR.lua esES.lua esMX.lua ptBR.lua ruRU.lua koKR.lua zhTW.lua zhCN.lua
Core/       Compat.lua Safe.lua Combat.lua Events.lua Bus.lua DB.lua Identity.lua Where.lua
            Names.lua Log.lua Watch.lua Chronicle.lua Comm.lua Settings.lua Slash.lua
UI/         Widgets.lua MainFrame.lua Dialog.lua Notice.lua ChatLine.lua Compartment.lua
Data/       Conflicts.lua                      -- GENERATED by tools/conflicts.py
Modules/    Conflicts/Conflicts.lua Conflicts/QuestDialog.lua
            Profile/Profile.lua
            Map/Map.lua Map/MapPins.xml        -- Map.lua first: the XML names its mixin
            Encounters/Encounters.lua Encounters/Tooltip.lua
            House/House.lua
            Campfire/Campfire.lua
            Knowledge/Knowledge.lua
            Fiction/Fiction.lua
            Rumours/Rumours.lua
            Traces/Traces.lua                  -- v2 schema comment only, no code
UI/Tabs/    Chronicle.lua Decisions.lua Encounters.lua House.lua
Dev/        TestMode.lua Probe.lua
```

Not loaded by the client:

```
Ashmark_Forever.toc Ashmark_Camelot.toc        -- identical except ## X-TocVariant
data/conflicts/*.csv data/conflicts/README.md  -- dataset source and its format, not shipped; registry.csv and
                                               -- renamed.csv keep released ids and sides permanent (7.1)
tools/conflicts.py tools/test_conflicts.py     -- generator + validator and its unittest specs, not shipped
tools/toc_check.py                             -- CI: the two TOCs agree and list only existing files
tests/helpers/wow.lua tests/helpers/<unit>_mock.lua tests/core_<service>_spec.lua tests/<unit>_spec.lua
tests/ui_*_spec.lua tests/dev_*_spec.lua       -- Core's UI shell and Dev
tests/helpers/integration_flow.lua tests/integration_*_spec.lua
.busted .luacheckrc .pkgmeta .github/workflows/*.yml
README.md LICENSE docs/ .claude/
```

There is no plain or `_Mainline` TOC. CI checks that the two TOC file lists are identical. Ashmark ships no XML templates of its own except Map's pin template.

TOC header:

```
## Interface: 16001
## Title: Ashmark
## Notes: Decisions leave a mark. Solo role-play for World of Warcraft Forever.
## Notes-deDE: ...                      -- one line per locale; text from the Localization unit
## Author: Nullthrone
## Version: @project-version@
## AllowLoadGameType: forever, camelot
## ExcludeLoadGameType: standard, classic
## SavedVariables: AshmarkDB
## IconTexture: Interface\Icons\INV_Misc_Book_09
## Category: Roleplay
## Category-deDE: Rollenspiel             -- one line per locale, the community's name for the category
## AddonCompartmentFunc: Ashmark_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: Ashmark_OnAddonCompartmentEnter
## AddonCompartmentFuncOnLeave: Ashmark_OnAddonCompartmentLeave
## X-TocVariant: Forever                -- "Camelot" in Ashmark_Camelot.toc
## X-License: MIT
## X-Curse-Project-ID: 1777037   -- CurseForge project; the packager uploads there
```

`Interface: 16001` is the beta and test value; the live value is confirmed at launch.

## 3. Namespace and module contract

### 3.1 Globals

Every Lua file with code starts with `local ADDON, ns = ...` (`Traces.lua` is a comment only, 4.5). `ns` is private. The only globals are `AshmarkDB`; `Ashmark_OnAddonCompartmentClick`, `Ashmark_OnAddonCompartmentEnter`, `Ashmark_OnAddonCompartmentLeave`; `SLASH_ASHMARK1`, `SLASH_ASHMARK2` and `SlashCmdList.ASHMARK`; `AshmarkMapPinMixin` (XML can only name a global mixin); and frame names prefixed `Ashmark` (`AshmarkFrame`, `AshmarkDialog`, `AshmarkNoticeFrame`, `AshmarkTestTooltip`). `.luacheckrc` lists exactly these as writable globals.

### 3.2 Modules

```lua
-- Core/Init.lua
ns.version                       -- C_AddOns.GetAddOnMetadata(ADDON, "Version"): the release tag the packager wrote;
                                 -- "dev" when it is missing, empty or still the unreplaced @project-version@
local M = ns:NewModule("Conflicts", {
  requires = { "questLog", "reputation" },   -- ns.Compat.Has keys; all must be true
  optional = { "questFrame" },               -- read by the module, never blocking
  modules  = nil,                             -- other modules that must be enabled
  locale   = "CONFLICT",                      -- prefix of <PREFIX>_MODULE_NAME / _MODULE_DESC
  default  = true,                            -- default of the setting "Conflicts.enabled"
})
ns:GetModule("Conflicts")        -- the same table; nil for unknown names
ns.Conflicts                     -- NewModule also sets ns[name] = M: the unit's public service table
ns:Modules()                     -- iterator in registration (TOC) order
```

Core sets `M.enabled` (boolean), `M.unavailable` (nil, or a list of reasons: capability keys, module names, `"error"`, `"schema"`, `"migration"`) and `M.missingEvents` (3.5).

| Module | requires | optional | modules | locale |
| --- | --- | --- | --- | --- |
| Conflicts | questLog, reputation | questFrame | | CONFLICT |
| Profile | | map, critterType | | PROFILE |
| Map | map, mapPins | | | MAP |
| Encounters | | tooltipProcessor, encounters | | ENC |
| House | | legacy | | HOUSE |
| Campfire | auras | | | CAMP |
| Knowledge | tooltipProcessor, container, itemCache | | | KNOW |
| Fiction | addonMessages | canSend | | FICTION |
| Rumours | addonMessages | canSend | Fiction | RUMOUR |

Every module has `default = true`. Without `canSend`, Fiction and Rumours only receive. Profile without `map` skips habitat sampling and origin. `Traces.lua` registers no module.

### 3.3 Lifecycle

| Step | Event | Core does first | Then calls | Allowed in the callback |
| --- | --- | --- | --- | --- |
| 1 | `ADDON_LOADED` with arg1 == `ADDON` (then unregistered) | Forever check, DB load and migrations (4.4), `math.randomseed` once if it exists | `M:OnInitialize()` on every module | register settings, kinds, slash subcommands, test checks. `M:Char()` is nil |
| 2 | `PLAYER_LOGIN` | Identity refresh creates or updates `chars[guid]`, Compat recompute, Comm prefix | `M:OnEnable()` on every module whose `requires` and `modules` are met and whose setting is on; then Core builds the settings category, so module tooltips can name missing events (3.5) | events, bus subscriptions, hooks (`M:Hook`), data providers. No log writes, no topic fires |
| 3 | first `PLAYER_ENTERING_WORLD` after login or reload | sets the ready flag (from here on `Log:Add` writes and topics fire), silent watcher baselines (5.10) | `M:OnWorldReady(isInitialLogin, isReloadingUi)` on enabled modules, in TOC order; afterwards Core's own first writes: zone check and group state (5.10), auto chapter and compaction (4.2) | first game-state reads; log writes and topic fires |
| 4 | `PLAYER_LOGOUT` | played time and `lastSeen` (5.10), pending `other` gold | nothing | |

- Every `OnEnable` runs before any `OnWorldReady`, so every subscriber is in place before the first write.
- Core's own step-3 writes run after every `OnWorldReady` has returned, so each module has seeded its state (Encounters' resumed session, Map's cache, Campfire's `present`) before those entries and topics reach it.
- Entries and topics written inside one module's `OnWorldReady` (Conflicts' reputation alliance, Encounters ending a stale session) can reach a module whose `OnWorldReady` has not run yet. Subscribers accept them: the state their handlers need is created in `OnInitialize` or on first use.
- Reads that return nil at `OnWorldReady` retry on the next `UPDATE_FACTION` (reputation) or `QUEST_LOG_UPDATE` (quest log).
- Enabling later (settings): `OnEnable`, then `OnWorldReady(false, false)`, through `ns.Combat.Run("module:" .. name, fn)`.
- Disabling (settings or errors): Core removes every event, unit event and bus subscription made through the helpers, then calls the optional `M:OnDisable()` (remove data providers, hide own frames). Hooks stay installed and return early.

### 3.4 Helpers

```lua
M:RegisterEvent(event, handler)            -- handler(self, event, ...); false if the event is invalid
M:RegisterUnitEvent(event, unit, handler)  -- one unit per call
M:UnregisterEvent(event[, unit])
M:Subscribe(topic, handler)                -- handler(self, topic, ...); delivered only while M.enabled
M:Fire(topic, ...)                         -- ns.Bus:Fire
M:Hook(key, install)                       -- runs install() at most once per session
M:Wrap(source, fn) -> function             -- returns at once while M is off; runs fn(...) through 3.6 under source
M:Char()                                   -- current CharRecord; nil before PLAYER_LOGIN
M:Setting(name)                            -- ns.Settings:Get("<Name>." .. name)
M:Stat(name, delta)                        -- char.stats["<Name>." .. name] += delta; returns the new value
```

Hooks (`hooksecurefunc`, `HookScript`, `TooltipDataProcessor.AddTooltipPostCall`) are installed only through `M:Hook` in `OnEnable`. Every hook body is wrapped with `M:Wrap(key, body)`, so it returns early while the module is off and runs through the error wrapper (3.6). Callbacks a module hands to `ns.Util.Debounce`, `ns.Util.Ticker` or `C_Timer` are wrapped the same way; unwrapped, their errors never count against the module and they keep running after it is disabled.

```lua
ns.Util.Token() -> string                  -- 8 lowercase hex chars: two math.random(0, 0xffff)
ns.Util.Roman(n), ns.Util.Clamp(v, lo, hi), ns.Util.Round(v), ns.Util.Trim(s)
ns.Util.Debounce(key, seconds, fn)         -- one pending C_Timer.After per key; later calls are absorbed
ns.Util.Ticker(key, seconds, fn)           -- one C_Timer.NewTicker per key; ns.Util.StopTicker(key)
ns.Util.Now() -> epoch                     -- GetServerTime() where the client has it, else time(); every
                                           -- ageing and decay reads it (4.2, 7.2, 7.8), so a system clock set
                                           -- ahead or back neither wipes history nor freezes it
ns.Util.StartsWithSound(text, "i"|"o")     -- text (colour code stripped) begins with that sound: I-, Í-, Hi-
                                           -- (not Hia-, Hie-) or O-, Ó-, Ho-; picks the _VOWEL keys (5.8)
ns.Util.Fold(s) -> string                  -- s with A-Z and the UTF-8 capitals of Latin-1, Latin Extended-A
                                           -- (not İ) and Cyrillic made small; "" for a non-string or secret.
                                           -- Names compare through it ignoring case (5.9, 7.5)
```

Two clocks. Every stamp that something is later aged against comes from `ns.Util.Now()`: a log entry's `t` and a chapter's `closed` (4.2), and through them Conflicts' `since` and House's family chronicle; the open chapter's age (7.6); the profile's `asOf` and kept alliances (7.2); every Rumours stamp (7.8). Stamps that are only shown or compared with one another use `time()`: `firstSeen`, `lastSeen` and `created`, Encounters' session `start` and `stop` and a contact's dates (7.4), Campfire's `rest.started`, Knowledge's held stamps, Fiction's `greeted`, and the test and probe records.

### 3.5 Events

`Core/Events.lua` dispatches every event.

- Plain events share one frame. Each event has an ordered list of (module, handler) and a count; the frame unregisters the event when the count reaches 0.
- Unit events get one frame per (event, unit) pair, created lazily and shared by every module asking for that pair. A module never uses `RegisterEvent` and `RegisterUnitEvent` for the same event.
- Validity: before registering, `C_EventUtils.IsEventValid(event)` when it exists, otherwise a `pcall` around the frame call. An invalid event is skipped and added to `M.missingEvents`, which the settings panel and the test report show. Registration never throws.
- Core's own handlers use the same API under always-enabled Core services (`ns:NewService(name)`, one per service, because an owner holds one handler per event). Their errors are reported but never disable anything.

### 3.6 Errors

Stock Lua 5.1 `xpcall` forwards no arguments. `Core/Init.lua` checks once at load whether the client's `xpcall` does (`xpcall(function(v) return v end, report, true)` returns `true, true`); then `ns:Call` hands the arguments to `xpcall` itself and allocates nothing. Otherwise every wrapper closes over them:

```lua
local args, n = { ... }, select("#", ...)
xpcall(function() return handler(self, unpack(args, 1, n)) end, report)
```

- Wrapped: lifecycle callbacks, event and bus handlers, hook bodies, Comm handlers, renderers, test checks, tab builders and list row initializers (6.1).
- `report` calls `geterrorhandler()` at most once per (module, source) per session; source is the event, topic, hook key or message type.
- After 10 caught errors in one module in a session, Core disables it for the session (`M.unavailable = { "error" }`), prints `CORE_MODULE_FAILED` once, and the test report lists it.

### 3.7 Bus topics

`ns.Bus:Fire(topic, ...)` is synchronous; handlers run in subscription order. Before the ready flag (3.3, step 3) it does nothing. A `Fire` issued while another `Fire` is dispatching is queued and delivered only after the current topic has reached every subscriber (FIFO); the outermost `Fire` returns once the queue is empty. Every subscriber therefore sees topics in the order they were fired: `LOG_ADDED` for a `quest.accept` before `LOG_ADDED` for the `alliance` it caused. State is not queued: a handler can see changes that an earlier subscriber made while handling the same topic (Conflicts handles `LOG_ADDED` before Profile), so rules that depend on the state before an entry compare sequence numbers (7.2).

| Topic | Payload | Fired by |
| --- | --- | --- |
| `LOG_ADDED` | entry, char | Log |
| `LOG_COMPACTED` | char | Log |
| `CHAPTER_CLOSED` | chapter, members (list of GUIDs present, may be empty) | Log (`CloseChapter`) |
| `REP_CHANGED` | factionId, reaction, delta | Core (5.10) |
| `GROUP_CHANGED` | inGroup | Core (5.10) |
| `NAMES_UPDATED` | kind (`"quest"`, `"item"`), id | Names |
| `SETTINGS_CHANGED` | key, value | Settings |
| `ALLIANCE_FORMED` | conflictId, side, viaRep | Conflicts |
| `ALLIANCE_BROKEN` | conflictId, newSide, questId | Conflicts |
| `PROFILE_CHANGED` | axes | Profile |
| `GROUP_SESSION_ENDED` | session | Encounters |
| `CONTACT_UPDATED` | guid | Encounters |
| `HOUSE_CHANGED` | houseKey or nil | House |
| `PEER_SEEN` | guid, peer, isNew | Fiction |
| `RUMOUR_HEARD` | rumour | Rumours |

### 3.8 Public services

Cross-unit calls use only the functions below and the core services in section 5. They read AshmarkDB and static data, work whether the owning module is enabled, unavailable or failed, never error, and return nil or an empty table when data is missing. No unit reads another unit's locals or file-scope tables, and CharRecord fields are written only by the unit listed in 4.1.

- Units may read, but never write, other units' `AshmarkDB` stores and CharRecord fields in the shapes this spec defines (4, 4.1, 7). Where a service below exists, use it.
- Modules reference other units as `ns.<Unit>` at call time (`OnInitialize` or later), never captured at file scope. `NewModule` sets `ns[name]` when the module file loads, in TOC order (Conflicts, Profile, Map, Encounters, House, Campfire, Knowledge, Fiction, Rumours), so `local House = ns.House` at the top of `Conflicts.lua` is nil. Only tab files (6.1) may capture units at load.

```lua
ns.Conflicts:All() -> { conflict, ... }
ns.Conflicts:Get(id) -> conflict|nil                      -- also for an old id the dataset renamed (7.1)
ns.Conflicts:Title(conflict) -> string                    -- ns.Names.Quest of the first side-A quest
ns.Conflicts:SideOf(questId) -> conflictId, side | nil
ns.Conflicts:InZone(mapId) -> { conflict, ... }          -- zone == mapId or anchor.m == mapId
ns.Conflicts:Alliance(char, id) -> "A"|"B"|nil, began     -- began: n of the entry that began it (7.1)
ns.Profile:Axes(char) -> { fidelity, habitat, mercy }      -- integers -100..100, decayed to now
ns.Profile:Archetype(char) -> key                          -- "OATHKEEPER" .. "PRAGMATIST" (7.2)
ns.Profile:Origin(char) -> zoneMapId|nil
ns.Profile:IsOpportunist(char) -> bool                     -- fidelity <= -34
ns.Encounters:Contact(guid) -> Contact|nil
ns.Encounters:Met(guid, char) -> ContactChar|nil           -- char's sub-record
ns.Encounters:Known(char[, minCount]) -> { [guid] = ContactChar }   -- byChar[char.guid].count >= minCount (default 1)
ns.Encounters:Session(char, id) -> Session|nil
ns.Encounters:OpenSession() -> Session|nil
ns.House:Key(char) -> houseKey|nil
ns.House:Members(char) -> { CharRecord, ... }              -- including char, by level, highest first
ns.House:SiblingAlliances(char[, members]) -> { [conflictId] = { A = { guid, ... }, B = { guid, ... } } }
ns.House:FamilyChronicle(char, limit[, members]) -> { { entry = e, char = member }, ... }   -- newest first
    -- members: the list Members(char) returned, when the caller holds it already
ns.Campfire.AURAS                                          -- 7.6
ns.Campfire:IsResting() -> bool
ns.Knowledge:Held(char, itemId) -> epoch|nil
ns.Fiction:Peer(guid) -> Peer|nil
ns.Fiction:PresentPeers() -> { [guid] = Peer }             -- peers among party1..4 right now
ns.Rumours:Get(id) -> Rumour|nil
ns.Rumours:Strength(rumour) -> 0..100                      -- after age decay
```

### 3.9 Hot paths

- `UNIT_AURA` only as `RegisterUnitEvent("UNIT_AURA", "player")`. The payload is ignored; the handler returns at once in combat and checks only the tracked spell IDs, without allocating.
- `UNIT_HEALTH` for `target` is registered only while a kill candidate exists (7.2).
- `GROUP_ROSTER_UPDATE`, `UPDATE_FACTION`, `BAG_UPDATE_DELAYED` and `QUEST_LOG_UPDATE` are coalesced with `ns.Util.Debounce` (0.5 to 2 s).
- Tooltip post-calls do O(1) lookups with cached names. They never write the log or SavedVariables and never request data.
- `LOG_ADDED` subscribers do O(1) work (index lookups, counters).
- UI refreshes run only for a visible tab or a shown map, at most every 0.5 s, through `ns.Combat.Run` with a key.
- `CHAT_MSG_ADDON` checks the prefix first and rate-limits each sender (5.6).

## 4. SavedVariables

One account-wide variable, `AshmarkDB`. No `SavedVariablesPerCharacter` (DECISIONS: account-wide only; the per-character folder layout on Forever is unverified and first names are not unique).

```lua
AshmarkDB = {
  schema   = 1,
  created  = <epoch>,
  settings = { ["Conflicts.enabled"] = true, ... },              -- 4.3
  chars    = { [guid] = CharRecord },                            -- 4.1
  contacts = { [guid] = Contact },                               -- Encounters, 7.4; local only
  peers    = { [guid] = Peer },                                  -- Fiction, 7.9
  rumours  = { heard = { [id] = Rumour },                        -- Rumours, 7.8
               told  = { [id] = { [peerGuid] = epoch } } },
  traces   = { schema = 0, outbox = {}, inbox = {} },            -- v2, 4.5
  dev      = { tests = {}, probes = {}, blocked = {} },          -- 7.10
  recovered = nil,                                               -- 4.4
}
```

| Store | Cap | Pruned by | Order |
| --- | --- | --- | --- |
| `chars[guid].log` | 4.2 | Log | 4.2 |
| `chars[guid].sessions` | 200 | Encounters | oldest `stop` |
| `contacts` | 2,000 | Encounters | contacts without note and never recurring for any character, oldest `last` |
| `peers` | 500 | Fiction | oldest `last` |
| `rumours.heard` | 200 | Rumours | below strength 20 first; then received copies before own rumours, each weakest after decay; `told[id]` goes with it |
| `rumours.told[id]` | 50 peers | Rumours | oldest; entries older than 30 days |
| `chars[guid].state.greeted` | 4 (the party) | Fiction | GUIDs that left the party; all on `GROUP_CHANGED(false)` |
| `chars[guid].state.senders` | 40 | Core (Comm) | senders whose GUID is no longer in the group first; all on `GROUP_CHANGED(false)` |
| `dev.tests`, `dev.probes`, `dev.blocked` | 10, 20, 20 | Dev, Dev, Core | oldest |

### 4.1 CharRecord

```lua
{
  guid, name, surname, surnameSource, ruleset, faction, race, class, sex, level,  -- Core, at PLAYER_LOGIN
  firstSeen, lastSeen,                                   -- Core, epoch; lastSeen is written on the 5-minute
                                                         -- played-time ticker and at PLAYER_LOGOUT, never at
                                                         -- login, so OnWorldReady sees when the last session ended
  houseOverride = nil,                                   -- House
  seq = 0, log = { Entry, ... },                         -- Log, 4.2
  chapters = { { no, from, to, closed, m, x, y, auto }, ... },   -- Log; from/to are sequence numbers
  zones = { [zoneMapId] = epoch },                       -- Core: first visit
  conflicts = { allied = { [conflictId] = "A"|"B" }, since = { [conflictId] = epoch },
                began = { [conflictId] = n },            -- n of the alliance or violation entry that began it
                broken = { [conflictId] = n }, violations = 0, turned = { [conflictId] = true } },  -- Conflicts
  profile = { fidelity = 0, habitat = 0, mercy = 0, raw = { fidelity = 0, habitat = 0, mercy = 0 },
              asOf, origin, originSec = { [zoneMapId] = s }, kept = { [conflictId] = epoch },
              day = { key, kills, loot, quest }, wild = 0, civil = 0 },   -- Profile, 7.2
  knowledge = { held = { [itemId] = epoch }, scanned = { bags = false, bank = false } },   -- Knowledge
  sessions = { [sessionId] = Session },                  -- Encounters, 7.4
  state = {                                              -- volatile state that survives /reload
    inGroup = false,                                     -- Core: the group boundary (5.10)
    senders = { [sender] = guid }, selfSender = nil,     -- Core (Comm): sender map (5.6)
    group   = Session|nil,                               -- Encounters: the open group session
    greeted = { [guid] = epoch },                        -- Fiction
    rest    = { started = epoch }|nil,                   -- Campfire
    shown   = { [rumourId] = epoch }, lines = { epoch, ... },   -- Rumours: re-print limits
  },
  stats = { ["<Unit>.<name>"] = number },                -- each unit writes only its own prefix
}
```

Encodings, identical in CharRecord, Person (5.3) and Contact (7.4):

| Field | Value | Display |
| --- | --- | --- |
| `class` | classFilename, `select(2, UnitClass(u))`, e.g. `"WARRIOR"` | `ns.Names.Class(class, sex)`, `C_ClassColor.GetClassColor(class)` |
| `race` | raceID, `select(3, UnitRace(u))`; Person and Contact also keep `raceName`, the first return of `UnitRace(u)` (the client's form for the unit's sex), and Contact the `locale` it was read in | `ns.Names.Race(race, raceName, locale)` (5.7) |
| `sex` | `UnitSex(u)`: 2 male, 3 female, 1 unknown | selects `_F` keys (5.8) |
| `faction` | first return of `UnitFactionGroup(u)`: `"Alliance"`, `"Horde"`, `"Neutral"` | `FACTION_ALLIANCE`, `FACTION_HORDE` |
| `ruleset` | `"Normal"`, `"PvP"`, `"RP"`, `"RPPvP"`, `"Hardcore"` | `CORE_RULESET_<KEY>` |

Names are display only; every key is a GUID.

### 4.2 Log entries

An entry is a flat table with short keys. Reserved keys, set only by `Log:Add`: `n` (sequence number per character, never reused), `t` (epoch, `ns.Util.Now()`, the clock that ages it), `k` (kind), and the location `m` (uiMapID), `x`, `y` (integers 0 to 100, percent of the map) and `i` (instanceID inside instances). Every value is a number, a string or a boolean.

| Kind | Fields | Writer | keep | Chronicle shows |
| --- | --- | --- | --- | --- |
| `quest.accept` | q | Core | | nothing |
| `quest.turnin` | q | Core | | yes |
| `quest.abandon` | q | Core | | yes |
| `zone` | z (zone-level map), first (true on the first visit) | Core | | only with `first` |
| `level` | l | Core | yes | yes |
| `death` | | Core | | yes |
| `rep` | f, s (reaction 1 to 8), d (points since the last `rep` entry for f) | Core, on a standing change only | | yes |
| `gold` | src (`quest`, `loot`, `vendor`, `trade`, `mail`, `other`), c (signed copper) | Core | | nothing |
| `chapter` | no, auto | Core (`Log:CloseChapter`) | yes | yes |
| `rest.camp`, `rest.bedroll` | | Campfire | | nothing |
| `alliance` | c (conflictId), side, rep (true when formed by reputation) | Conflicts; one for every zone and faction a reputation pass decides (7.1) | yes | yes |
| `violation` | c, side (the side now allied), q, o (1 = opportunist wording) | Conflicts | yes | yes |
| `houseturn` | c, side, q (nil when by reputation), h (houseKey) | Conflicts | yes | yes |
| `kill.neutral`, `kill.critter` | | Profile | | nothing |
| `group.end` | g (session id), size, inst (instanceID), e (outcome) | Encounters | | yes, with peers' archetypes |
| `contact` | p (guid) | Encounters, first meeting per character | yes | yes, while the contact is stored |
| `peer` | p (guid), a (archetype) | Fiction, first sight per character; an archetype change at most once per 24 h per peer per character (7.9) | yes | nothing |
| `rumour` | r (rumour id) | Rumours, first hearing with a printed line, so at most 5 an hour (7.8) | | nothing |
| `item.held` | it (itemId) | Knowledge, after the first scan | | nothing |

```lua
ns.Log:RegisterKind(kind, { fields = { "q" }, keep = false, render = function(entry, ctx) end,   -- 5.7
                            shown = function(entry) end })   -- optional: false for entries render skips
ns.Log:Shown(entry) -> bool                      -- the kind has a renderer and the entry passes its shown()
ns.Log:Add(kind, fields [, opts]) -> entry|nil   -- current character; opts.noWhere skips the location
ns.Log:Iter(char, fromSeq[, toSeq])              -- for entry in ...: ascending; compacted entries are absent
ns.Log:Last(char, kind) -> entry|nil
ns.Log:Count(char) -> number of stored entries
ns.Log:Seq(char) -> last sequence number
ns.Log:CloseChapter(members[, opts]) -> chapter|nil
ns.Log:Compact(char)                             -- Log only
```

`Add` rules:
- Before Core sets the ready flag at the start of lifecycle step 3 (3.3), or when the DB is read-only (4.4), `Add` returns nil.
- An unknown kind, or a reserved key in `fields`, raises an error in debug mode and is otherwise dropped or stripped.
- Every field value must be a number, a string or a boolean and not secret. Otherwise the entry is dropped, `stats["Core.secretDropped"]` grows, and the drop is reported once per kind.
- `n = char.seq + 1`; `t = ns.Util.Now()`; location from `ns.Where()` unless `opts.noWhere`; the entry is appended; `LOG_ADDED(entry, char)` fires.

Core registers the `quest.*`, `zone`, `level`, `death`, `rep` and `gold` kinds in `Core/Watch.lua` and `chapter` in `Core/Log.lua`. Modules register their kinds in `OnInitialize`.

**Chapters.** The open chapter is every entry with `n` greater than the last chapter's `to`. `CloseChapter(members, opts)` returns nil if the open chapter is empty; otherwise it writes a `chapter { no, auto }` entry, appends `{ no = #chapters + 1, from = previous.to + 1 (or 1), to = entry.n, closed = entry.t, m, x, y, auto }` to `chapters`, and fires `CHAPTER_CLOSED(chapter, members or {})`. Campfire decides when a rest closes a chapter (7.6). In lifecycle step 3, after every module's `OnWorldReady`, Core closes the open chapter itself (`auto = true`, no notice) when it holds more than 1,000 entries or began more than 7 days ago by `ns.Util.Now()`, so the chronicle never becomes one endless chapter.

**Compaction.** Only `Log:Compact` removes entries, and it does not depend on chapters.
- It runs in lifecycle step 3, after every module's `OnWorldReady` and the automatic chapter close, for the current character, and after an `Add` that takes the log above 4,000 entries (scheduled with `C_Timer.After(0)` through `ns.Combat.Run("log:compact")`). An `Iter` in progress keeps walking the array it started with.
- One pass builds a new array. Ages are measured against `ns.Util.Now()` (the realm's clock), and an entry never counts as older than one written before it, so a session stamped by a clock set ahead or back (where the realm's clock is missing, or in a log from before stamps used it) deletes nothing.
  1. Keep-kind entries stay; non-keep entries older than 180 days go.
  2. If keep-kind entries exceed 2,000, the oldest `chapter` entries go first (`chapters` and the map pins keep everything they say, so years of camp rests never crowd out meetings or this session's entries), then the oldest `peer` entries (written on other clients' word; the chronicle shows none), then the oldest `contact` entries.
  3. Non-keep entries go, oldest first, until at most 3,000 entries remain: first those the chronicle never shows (`Log:Shown(entry)` is false: `gold`, `quest.accept`, `kill.*`, `rest.*`, `rumour`, `item.held`, zone revisits), then shown ones.
- The new array replaces the old one and `LOG_COMPACTED(char)` fires. Sequence numbers and chapter ranges never change; an old chapter simply contains fewer entries.

### 4.3 Settings

Flat keys `"<Unit>.<name>"`, stored in `AshmarkDB.settings`. Units register at file load or in `OnInitialize` with `ns.Settings:Register(key, default, labelKey, tooltipKey)`; Core registers `"<Module>.enabled"` for every module (label `<PREFIX>_MODULE_NAME`, tooltip `<PREFIX>_MODULE_DESC`). `ns.Settings:Get(key)`; `ns.Settings:Set(key, value)` fires `SETTINGS_CHANGED`. All v1 settings are booleans.

| Key | Default | Meaning |
| --- | --- | --- |
| `<Module>.enabled` | true | module on |
| `Core.chatLines` | true | Ashmark lines in chat |
| `Core.sounds` | true | Ashmark sounds |
| `Comm.share` | true | send own `HI`, `PR` and rumours to other Ashmark users |
| `Knowledge.questRewards` | true | never hide tooltips of quest rewards shown in the quest frame |

The panel is built at `PLAYER_LOGIN`:

```lua
local cat = Settings.RegisterVerticalLayoutCategory("Ashmark")
local s = Settings.RegisterAddOnSetting(cat, "Ashmark_" .. key, key, AshmarkDB.settings,
                                        type(default), L[labelKey], default)
Settings.CreateCheckbox(cat, s, L[tooltipKey])
Settings.RegisterAddOnCategory(cat)
Settings.OpenToCategory(cat:GetID())     -- through ns.Combat.Run
```

An unavailable module's tooltip names each reason in the player's words: `CORE_UNAVAILABLE` ("Needs {capability}") with the localized `<PREFIX>_MODULE_NAME` of a needed module, one `CORE_UNAVAILABLE_CLIENT` line for any missing client capabilities, `CORE_MODULE_FAILED` for `"error"`, `CORE_SV_NEWER` for `"schema"` and `CORE_SV_MIGRATE_FAILED` for `"migration"`. The text is built when the panel is built at `PLAYER_LOGIN` (a function tooltip depends on the unverified Settings API), so `CORE_MODULE_FAILED` appears there only for a module that failed before it. A module that fails later in the session (3.6) is named in chat (`CORE_MODULE_FAILED`, once) and in the test report, not in its tooltip, and its checkbox keeps the player's setting; the failure lasts only for the session, so after the next reload the module runs again. Module toggles run enable and disable through `ns.Combat.Run`.

A module that needs other modules (`opts.modules`, 3.2) is nested under the first of them with the checkbox initializer's `SetParentInitializer(parent, modifiable)`, and is greyed out while any module it needs is off: unticking Shared fiction shows that Rumours stops with it. `SetParentInitializer` is Mainline Settings API, unverified on Forever; without it the checkboxes stay flat.

### 4.4 Load safety

At `ADDON_LOADED` for this addon:

1. `AshmarkDB` is set but not a table: a fresh table is built with `recovered = <old value>`.
2. A table without `schema`: a fresh table is built with `recovered = <old table>`. Nothing is overwritten silently.
3. `schema` newer than the code: read-only mode. `ns.DB.readOnly = true`, `ns.DB.readOnlyReason = "schema"`, every module is unavailable (`"schema"`), `Log:Add` returns nil, `CORE_SV_NEWER` is printed, and nothing is written. Core's own writers are gated: it skips the Identity refresh (no `chars[guid]` is created or updated; `M:Char()` returns the existing record or nil), `zones`, `lastSeen`, `stats` (including the played-time ticker), `state` (group flag, sender map; Comm keeps them in memory), pending `other` gold, `dev.blocked`, `dev.tests`, `dev.probes` and the settings binding (no `RegisterAddOnSetting` on `AshmarkDB.settings`; the panel shows only `CORE_SV_NEWER`). `/ashmark test` and `probe` print their report without storing it (`TEST_NOT_STORED`), and `/ashmark reset` refuses. The table stays untouched, so logout writes it back unchanged.
4. `schema` older: migrations run in order on a deep copy, which replaces `AshmarkDB` only when every step succeeded; each is idempotent and tested. A migration that raises leaves the stored table exactly as loaded and the DB read-only for the session as in 3, but with `readOnlyReason = "migration"`: `CORE_SV_MIGRATE_FAILED` is printed, every module is unavailable (`"migration"`), and the panel header, the module tooltips and `/ashmark reset`'s refusal say `CORE_SV_MIGRATE_FAILED` instead of blaming a newer Ashmark (`CORE_SV_NEWER`), as `/ashmark test` and `probe` say `TEST_NOT_STORED_MIGRATION` instead of `TEST_NOT_STORED`.
5. `AshmarkDB` is nil: a fresh table with `created = time()`, `ns.DB.fresh = true`, and `CORE_SV_NEW` is printed once: "A new record has started. If Ashmark was used on this account before, the saved data did not load: do not /reload or log out again. Quit the game, then replace `Ashmark.lua` with `Ashmark.lua.bak` in `WTF\Account\<account>\SavedVariables\` before the next login." The client moves `Ashmark.lua` to `Ashmark.lua.bak` on every save (each /reload, logout or quit), so after a failed load the first save moves the good file to `.bak` and the second destroys it.

`Core/DB.lua` creates every top-level table of the schema, including `traces`. The test report shows `created`, `fresh`, `readOnly`, `recovered` and the entry count; a second test run must find the first run's record, which proves the SavedVariables round trip.

### 4.5 Traces (v2)

v1 reserves `AshmarkDB.traces` with `schema = 0`. v2 fills `outbox` with own traces (grave, extinguished camp, note from templates) and a companion app writes `inbox` between sessions. `Modules/Traces/Traces.lua` holds only this format as a comment; v1 has no code that reads or writes traces.

```lua
{ id = <ns.Util.Token()>, k = "grave"|"camp"|"note", m, x, y, t, tpl = templateId, args = { ... }, a = archetype }
```

## 5. Core services

### 5.1 Compat

```lua
ns.Compat.IsForever()     -- (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
                          --   or (iface >= 16000 and iface < 20000), iface = select(4, GetBuildInfo())
ns.Compat.build           -- { version, build, date, interface } from GetBuildInfo()
ns.Compat.tocVariant      -- C_AddOns.GetAddOnMetadata(ADDON, "X-TocVariant")
ns.Compat.Has.<cap>       -- booleans; computed at ADDON_LOADED, recomputed at PLAYER_LOGIN before any OnEnable
ns.Compat.Check(cap)      -- recompute one capability
ns.Compat.Disable(cap, reason)   -- runtime demotion for the session (canSend, 5.6)
```

Each detector runs in its own `pcall`, so a failure sets only that key to false. Functions are checked with `type(f) == "function"` and every namespace is guarded (`C_MajorFactions and C_MajorFactions.GetMajorFactionData`).

| Key | True when |
| --- | --- |
| `questLog` | `C_QuestLog.GetTitleForQuestID`, `GetLogIndexForQuestID` and `RequestLoadQuestByID` exist |
| `questFrame` | `QuestFrame` and `QuestFrameDetailPanel` both exist |
| `abandonHooks` | `C_QuestLog.SetAbandonQuest`, `GetAbandonQuest` and `AbandonQuest` exist |
| `reputation` | `C_Reputation.GetFactionDataByID` exists |
| `map` | `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition` and `GetMapInfo` exist |
| `mapPins` | `WorldMapFrame.AddDataProvider`, `MapCanvasDataProviderMixin`, `MapCanvasPinMixin` and `C_Map.GetMapRectOnMap` exist |
| `tooltipProcessor` | `TooltipDataProcessor.AddTooltipPostCall` and `Enum.TooltipDataType` exist |
| `auras` | `C_UnitAuras.GetPlayerAuraBySpellID` exists |
| `addonMessages` | `C_ChatInfo.SendAddonMessage` and `C_ChatInfo.RegisterAddonMessagePrefix` exist |
| `canSend` | `addonMessages`, and neither `IsTrialAccount()` nor `IsVeteranTrialAccount()` returns true; demoted by Comm (5.6) |
| `secrets` | `issecretvalue` or `canaccessvalue` exists |
| `eventCheck` | `C_EventUtils.IsEventValid` exists |
| `settingsApi` | `Settings.RegisterVerticalLayoutCategory`, `RegisterAddOnSetting`, `CreateCheckbox` and `RegisterAddOnCategory` exist |
| `scrollBox` | `CreateScrollBoxListLinearView`, `CreateDataProvider` and `ScrollUtil.InitScrollBoxListWithScrollBar` exist |
| `xmlInfo` | `C_XMLUtil.GetTemplateInfo` exists |
| `container` | `C_Container.GetContainerItemID` and `GetContainerNumSlots` exist |
| `itemCache` | `C_Item.IsItemDataCachedByID` and `C_Item.GetItemInfoInstant` exist |
| `encounters` | `C_EventUtils.IsEventValid("ENCOUNTER_END")`; without `eventCheck`, true (registration is pcall-guarded) |
| `critterType` | `C_CreatureInfo.GetCreatureTypeInfo(8)` returns a name |
| `legacy` | from `PLAYER_LOGIN`, rechecked on `UPDATE_FACTION`: `C_Reputation.GetFactionDataByID(2802)` or `C_MajorFactions.GetMajorFactionData(2802)` returns data |
| `screenshot` | `Screenshot` exists |
| `rulesets` | `C_GameRules.IsGameRuleActive` and `Enum.GameRule` exist |

### 5.2 Safe

```lua
ns.Safe.IsSecret(v) -> bool
ns.Safe.Value(v) -> v, true | nil, false
ns.Safe.Bool(v) -> true | false | nil            -- nil only when v is secret
ns.Safe.Call(fn, ...) -> ok, ...                 -- ok = false if fn is missing or errors, or a top-level
                                                 -- result is secret or an inaccessible table
ns.Safe.Field(t, k) -> v, ok                     -- ok = false if t is nil or inaccessible, or t[k] is secret
ns.Safe.Fields(t, k1, k2, ...) -> { [k] = v } | nil   -- nil if t is inaccessible or any listed field is secret
ns.Safe.Clean(t) -> shallow copy | nil           -- nil if any value is secret or not a number/string/boolean
ns.Safe.UnitName(unit) -> name, surname | nil   -- nil also for the client's placeholders UNKNOWNOBJECT and
                                                 -- UKNOWNBEING (read at call time): a unit not loaded yet
ns.Safe.UnitGUID(unit) -> guid | nil
ns.Safe.UnitIdentityRestricted(unit) -> true | false | nil   -- C_Secrets.ShouldUnitIdentityBeSecret; nil = unknown
ns.Safe.AurasRestricted(unit) -> true | false | nil          -- C_Secrets.ShouldAurasBeSecret; nil = unknown
ns.Safe.InLockdown() -> bool                     -- C_ChatInfo.InChatMessagingLockdown(); false if missing
```

One predicate, used by every Safe function:

```lua
IsSecret(v) = (canaccessvalue and not canaccessvalue(v))
           or (issecretvalue and issecretvalue(v))
           or (type(v) == "table" and ((canaccesstable and not canaccesstable(v))
                                       or (issecrettable and issecrettable(v))))
           or false
```

Rules:
- Read through Safe every value that can be secret: unit names and GUIDs, unit state of non-group units, aura data, tooltip data, chat and addon-message payloads, map IDs and positions on restricted maps, encounter payloads.
- A handler that gets `ok == false`, or nil from `Safe.Bool`, returns without side effects. Never negate a Safe result: `not Safe.Value(x)` is true for a secret.
- Table fields are read only through `Safe.Field` or `Safe.Fields`.
- `C_Secrets` and `C_RestrictedActions` functions are called only through `Safe.Call` (they may be AllowedWhenUntainted). Callers decide by the values they actually read; the restriction predicates are hints.
- Encounters, Fiction and Rumours copy data through `Safe.Clean` before writing contacts, peers and rumours.

### 5.3 Identity

```lua
ns.Identity:Player() -> Person                     -- plus surnameSource
ns.Identity:Unit(unit) -> Person|nil               -- nil if the GUID or name is missing or secret, or the name
                                                   -- is still the client's placeholder (Safe.UnitName)
ns.Identity:Group(scope) -> { [guid] = Person }    -- excludes the player, skips secret members
    -- scope "party": party1..4 (in a raid, the player's subgroup); "all": raid1..40 or party1..4;
    -- the tokens come from Tokens(scope), so the result is empty while they name an instance group
ns.Identity:Tokens(scope) -> prefix, count | nil   -- "party", 4 or ("all" in a home raid) "raid", 40; nil
                                                   -- while IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
ns.Identity:Ruleset() -> key
ns.Identity:InGroup() -> bool                      -- IsInGroup(home) and GetNumGroupMembers(home) > 1; the only
                                                   -- group predicate
-- Person = { guid, name, surname, full, class, race, raceName, sex, faction, level, ruleset, unit }
-- raceName: first return of UnitRace(unit), the client's name in the form for the unit's sex (4.1)
```

Ashmark's group is the home group, the party or raid the player formed (`LE_PARTY_CATEGORY_HOME`, read only where the constant exists). A battleground puts every player into an instance group, and without a category `IsInGroup`, `IsInRaid` and `GetNumGroupMembers` answer for it while it lasts, so `InGroup` and `IsInRaid` always pass the home category. While an instance group is active the unit tokens name its members and the home group has none of its own: `Tokens` returns nil, `Group` returns no members, and every unit that walks the roster (Fiction, Campfire, Encounters' `groupGuids`) takes no stranger from the battleground for a companion. A player who queued alone is in no group there. The probe records both categories (7.10).

Surname of the player: the first candidate that is non-empty, not secret, contains no `-`, and equals neither `GetRealmName()` nor `GetNormalizedRealmName()`:

1. `select(2, UnitNameUnmodified("player"))`, source `"UnitNameUnmodified"`
2. `select(2, UnitName("player"))`, source `"UnitName"`
3. `select(2, UnitFullName("player"))`, source `"UnitFullName"`

None: `surname = nil`, and the character has a house only through `/ashmark house` (7.5). While the player's own name still reads as the placeholder, `Refresh` keeps the stored `name`, `surname` and `surnameSource`. Other units use steps 1 and 2 with their unit token. `full` = name and surname joined by a space, or the name alone. An other unit's `ruleset` is the player's own: cross-ruleset grouping is not supported.

Ruleset: a rule is active if `Enum.GameRule[key] ~= nil` and `Safe.Call(C_GameRules.IsGameRuleActive, Enum.GameRule[key])` returns true. `Hardcore` if `HardcoreRuleset`; else `RPPvP` if `RPPvPRuleset`, or both `RPRuleset` and `PvPRuleset`; else `RP` if `RPRuleset`; else `PvP` if `PvPRuleset`; else `Normal`. Recomputed on `GAME_RULES_CHANGED`. Without `rulesets`: `Normal`.

### 5.4 Where

```lua
ns.Where() -> { m, x, y, i }        -- never throws, always a table; unknown or secret fields are nil
ns.Where.Zone(m) -> mapId|nil       -- m or the first map up its parent chain with mapType Enum.UIMapType.Zone
ns.Where.Continent(m) -> mapId|nil  -- same for Enum.UIMapType.Continent
```

`m = Safe.Value(C_Map.GetBestMapForUnit("player"))`, inside instances as well. Inside an instance (`IsInInstance()`), `m` is kept when `Safe.Value` returns it, `x` and `y` are nil, `i = select(8, GetInstanceInfo())` (through Safe) is set, and `GetPlayerMapPosition` is not called. Otherwise, if `m` is set: `ok, pos = Safe.Call(C_Map.GetPlayerMapPosition, m, "player")`, and `pos.x`, `pos.y` are read through `Safe.Field`. Only plain numbers are rounded: `x = math.floor(px * 100 + 0.5)`. `Zone` and `Continent` walk `C_Map.GetMapInfo(id).parentMapID` with nil checks and cache per map per session.

### 5.5 Combat

`ns.Combat.Run(key, fn)` runs `fn` now if not `InCombatLockdown()`. Otherwise it stores `fn` under `key` (a later call with the same key replaces it) and runs the queue in insertion order at `PLAYER_REGEN_ENABLED`. Used for every show, hide, move and resize of Ashmark's windows, the notice, opening the settings panel, module enable and disable, adding and removing the map provider, map refreshes and log compaction.

### 5.6 Comm

Prefix `Ashmark`, registered at `PLAYER_LOGIN`. Wire format, ASCII:

```
1|<type>|<field1>|<field2>|...
```

Every field matches `^[%w_.:%-]*$`, so there is no escaping: the encoder refuses other characters and the decoder drops the message. A message is at most 255 bytes; the encoder refuses longer ones and never chunks.

| Type | Fields | Sent by |
| --- | --- | --- |
| `HI` | guid, archetype, origin, ruleset, version | Fiction, 7.9 |
| `PR` | guid, fidelity, habitat, mercy | Fiction, right after every `HI` |
| `RU` | id, tpl, hops, strength, age, archetype, faction, map | Rumours, 7.8 |

Field rules (the same table validates sending and receiving):

| Field | Rule |
| --- | --- |
| guid | `^Player%-%d+%-%x+$` |
| archetype | `OATHKEEPER`, `OPPORTUNIST`, `WANDERER`, `TOWNSFOLK`, `GENTLE`, `RUTHLESS` or `PRAGMATIST` |
| origin, faction, map | integer 0 to 999999; 0 = none |
| ruleset | `Normal`, `PvP`, `RP`, `RPPvP`, `Hardcore` |
| version | `^[%w.%-]+$`, at most 20 characters |
| fidelity, habitat, mercy | integer -100 to 100 |
| id | 8 lowercase hex characters |
| tpl | `ALLIANCE`, `BROKE`, `TURNED` |
| hops | integer 0 to 9 |
| strength | integer 0 to 100 |
| age | integer 0 to 2160 (hours since the rumour began) |

**Channel.** v1 sends only on `PARTY`. In a raid, `PARTY` reaches only the player's subgroup (`party1..4`), so no message ever has more than four recipients; the probe confirms this, and if `PARTY` fails in raids, Ashmark is silent there. `RAID`, `GUILD`, `WHISPER` and `CHANNEL` are not used in v1, and messages on other channels are dropped.

```lua
ns.Comm:Send(type, fields, channel, target, priority) -> ok, reason
  -- fields: array of strings and integers; channel "PARTY"; target nil (reserved for WHISPER, unused)
  -- priority 1 (handshake) to 3 (bulk); default 1 for HI and PR, 3 for RU
  -- reason: "share" (Comm.share off), "cannotSend", "invalid", "tooLong", "notGrouped"
ns.Comm:Register(type, fn, owner)   -- fn(from, fields, channel); from = { sender = raw string, guid, unit }
                                    -- owner: the module; fn runs only while owner.enabled, errors count to it
ns.Comm.stats                 -- { sent, rejected, dropped, limited, results = { [code] = n } }
ns.Comm.RECEIVE               -- per-type receive budgets (step 4); read at receive time, specs may widen them
```

**Queue.** Token bucket with capacity 6 and a refill of 1 per 1.5 s, under Blizzard's 10 per prefix with 1 per second regeneration. The queue holds at most 30 messages, ordered by priority then age; when full it drops the oldest message of the lowest priority. A ticker runs only while the queue is not empty. The queue pauses while `ns.Safe.InLockdown()` or `not ns.Identity:InGroup()`. Results (`Enum.SendAddonMessageResult`; `true` counts as 0): 0 sent; 3 or 8 (throttle) requeue at the front and pause 5 s; 11 (lockdown) requeues and pauses until `ZONE_CHANGED_NEW_AREA` or `PLAYER_ENTERING_WORLD`; 5 (not in group) drops the queue; anything else drops the message. Three consecutive results outside 0, 3, 5, 8 and 11 call `Compat.Disable("canSend")` for the session, and the test report shows why. A queued message never goes out after the moment it was meant for: the queue is dropped when the ticker finds `Comm.share` off or `canSend` lost, and on `GROUP_CHANGED(false)`, which also stops the ticker. A queued message whose type's module (the owner given to `Comm:Register`: Fiction for `HI` and `PR`, Rumours for `RU`) is off by the time it would go out is dropped too.

**Receive** (`CHAT_MSG_ADDON`), in this order:
1. Return if `Safe.IsSecret(prefix)` or `prefix ~= "Ashmark"`.
2. Drop if text, channel or sender is secret, if channel is not `PARTY`, or if `#text > 255`.
3. Split on `|`; drop unless the version is `1` and every field passes its rule; count failures in `stats.rejected`.
4. Drop beyond 20 messages per sender per minute, and beyond the sender's budget for the type (`Comm.RECEIVE`, about the protocol's own rates): `HI` and `PR` 3 at once, then 1 per 30 s each; `RU` 10 at once, then 1 per 40 s. Every drop here counts in `stats.limited`.
5. Drop messages whose sender equals `selfSender`.
6. `HI`, `PR`: if the GUID equals `Safe.UnitGUID("player")`, set `selfSender` to this sender and drop. Otherwise accept only if some `party1..4` has `Safe.UnitGUID(unit) == guid`, and the claim binds the GUID to this sender:
   - refused if the sender's name (through `Ambiguate(sender, "none")` and `UnitGUID`) belongs to another party member. The client reads a unit token first and ignores its case, so a sender named Target or Focus would name whoever the player targets: the name resolves to a GUID only if `Safe.UnitName` of the same string equals the sender's name before the `-`;
   - a sender whose name resolves to the claimed GUID takes it over from any other sender;
   - otherwise refused if this sender is bound to another GUID still in the party, or the GUID is bound to another sender. While the Forever sender format is unverified and names do not resolve, the first sender to claim a GUID keeps it, so an impostor who first claims a member without Ashmark keeps that GUID until the group ends.

   Then `senders[sender] = guid`. `RU`: accept only if `senders[sender]` is set.
7. Call the handler (wrapped, 3.6). Handlers build a complete record before writing anything.

**Sender map.** `senders` and `selfSender` are `state.senders` and `state.selfSender` of the current CharRecord (4.1), so a /reload while grouped keeps them; nobody re-sends `HI` after a reload, and an in-memory map would drop every `RU` from the party until someone new joined. On `GROUP_CHANGED(false)` (5.10) Comm clears `state.senders`; `selfSender` is kept. At most 40 senders (4).

If `Compat.Has.canSend` is false or `Comm.share` is off, Ashmark only receives.

### 5.7 Names and Chronicle

```lua
ns.Names.Quest(id)              -- C_QuestLog.GetTitleForQuestID, else L.CORE_UNKNOWN_QUEST ("a quest")
ns.Names.Item(id)               -- C_Item.GetItemNameByID, else L.CORE_UNKNOWN_ITEM ("an item")
ns.Names.Faction(id)            -- C_Reputation.GetFactionDataByID(id).name, else L.CORE_UNKNOWN_FACTION ("a faction")
ns.Names.Map(id)                -- C_Map.GetMapInfo(id).name, else L.CORE_UNKNOWN_PLACE ("an unknown place")
ns.Names.Class(classFile, sex) -> name, known   -- LOCALIZED_CLASS_NAMES_FEMALE for sex 3, else _MALE;
                                                -- else L.CORE_UNKNOWN_CLASS, false
ns.Names.Race(raceID[, storedName, storedLocale]) -> name, known
    -- storedName (UnitRace's form for the unit's sex) while the client runs storedLocale, else
    -- C_CreatureInfo.GetRaceInfo(raceID).raceName (the male form), else L.CORE_UNKNOWN_RACE, false
ns.Names.Player(guid)           -- contact or character record name, else L.CORE_UNKNOWN_PLAYER ("someone")
```

Every result is checked for nil before it is indexed, table fields go through Safe, and names are cached per session. A placeholder for a quest or item also requests the data (`C_QuestLog.RequestLoadQuestByID`, `C_Item.RequestLoadItemDataByID`), at most once per id per session. On `QUEST_DATA_LOAD_RESULT` or `ITEM_DATA_LOAD_RESULT` with success, Names fires `NAMES_UPDATED(kind, id)`, and visible tabs refresh. These functions never return nil.

```lua
ns.Chronicle:Chapters(char) -> { chapter, ..., open }   -- open = { no, from, open = true }
ns.Chronicle:Lines(char, chapter, ctx) -> { { entry = e, text = s }, ... }   -- ascending
ns.Chronicle:Render(entry, ctx) -> string|nil
ns.Chronicle:Text(key, ctx, values) -> string             -- renderer helper: key, or key .. "_THEY" with
                                                          -- {name} when ctx.own == false; _F by ctx.char.sex
ns.Chronicle:PlaceText(key, ctx, m, values) -> string     -- Text with {place} for a stored map m: m's zone
    -- with key; a known map outside every zone (a continent, the open sea) with key .. "_NOZONE", whose text
    -- calls it no zone; no map or an unknown one with key and CORE_UNKNOWN_PLACE (death and chapter lines)
-- ctx = { char = CharRecord, own = true|false }   -- own = false in the House's family chronicle
```

Renderers:
- `render(entry, ctx) -> string|nil`, registered with the kind; nil means the entry is not shown.
- They use only the entry, `ctx`, `ns.Names` and public services, never the current profile or other mutable state. Wording that depends on state is decided and stored at write time (`violation.o`). Records looked up by key through a service (contacts, sessions, peers, conflicts) are the exception: the `group.end` sentence names members from contacts and shows a peer's current archetype, a `contact` entry whose contact the store forgot renders nothing (7.4), and so do the `alliance`, `violation` and `houseturn` entries of a retired conflict id (7.1).
- With `ctx.own == false` they use the third-person key `<KEY>_THEY` with `{name}` (the member's name).
- They run through the error wrapper under Core (a kind has no owner); an error renders nothing.

Chronicle text is generated at display time, so it follows the client locale and never stores prose.

### 5.8 Localization

```lua
-- Locales/enUS/Conflicts.lua
local _, ns = ...
local L = ns.Locale:Base()
L.CONFLICT_CONTRADICTS = "Contradicts your alliance with {faction}."

-- Locales/deDE.lua
local _, ns = ...
local L = ns.Locale:For("deDE")   -- a throwaway table unless deDE is active or ns.Locale.loadAll is set (tests)
L.CONFLICT_CONTRADICTS = "..."

-- anywhere
local L = ns.L                     -- proxy: active locale, then enUS, then the key itself
ns.Format(L.CONFLICT_CONTRADICTS, { faction = name })
ns.Gender(key, sex)                -- L[key .. "_F"] for sex 3 if present, else L[key]
ns.Locale:Missing(code) -> { key, ... }   -- enUS keys the locale lacks
```

- Locale files have no early return; `ns.Locale.tables[code]` keeps only the active locale (all locales when `loadAll` is set).
- Keys are upper snake case. A key lives with the unit that owns the concept: in that unit's enUS file, with that unit's prefix (`CORE_`, `TEST_`, `CONFLICT_`, `PROFILE_`, `MAP_`, `ENC_`, `HOUSE_`, `CAMP_`, `KNOW_`, `RUMOUR_`, `FICTION_`). `TEST_` keys belong to Core's test mode (`enUS/Test.lua`).
- Shared vocabularies that any unit may read: `PROFILE_<ARCHETYPE>` (Profile; shown by House, Encounters' tooltip, the `group.end` renderer and Rumours), `CONFLICT_UNNAMED` (Conflicts; a side without a faction, also on Map's pins and the House tab), `CORE_RULESET_<KEY>` and `CORE_UNKNOWN_*` (Core).
- `PROFILE_<ARCHETYPE>` is a label: capitalised, without an article ("Oathkeeper"). Sentences that embed it are written around a label ("Thalen (Oathkeeper from Westfall)", "People say the {archetype} from {place} …").
- `PROFILE_<ARCHETYPE>_F` is the label for a female character, in locales whose label inflects. Wherever the character's sex is known, the label goes through `ns.Gender("PROFILE_" .. key, sex)`: the House tab's archetype line and axis poles (the shown character's `sex`), and Encounters' tooltip line and the `group.end` renderer (the contact's `sex`; `PeerLabel` first checks `ns.Locale:Get("PROFILE_" .. key)`, so a key without a label still shows nothing). Rumours carry no sex and always use `PROFILE_<ARCHETYPE>`, so that form must read for anyone in the rumour lines.
- A unit's own test-check strings use its own prefix, e.g. `PROFILE_TEST_MERCY_HOWTO` in `enUS/Profile.lua`.
- Rumours carry no sex, so `RUMOUR_HEARD_*` must phrase `{archetype}` in a gender-neutral way and have no `_F` forms; `enUS/Rumours.lua` says so to translators in a comment above these keys.
- Placeholders are named, `{name}`, so translators can reorder them.
- A conjunction that changes before a sound has a `_VOWEL` key, picked by code through `ns.Util.StartsWithSound` (3.4): `ENC_LIST_AND_VOWEL` when `{last}` begins with /i/, `CONFLICT_TAB_SIDES_VOWEL` and `MAP_PIN_SIDES_VOWEL` when `{b}` begins with /o/. Spanish writes "e" and "u" there; every other locale repeats its plain key.
- Every unit defines `<PREFIX>_MODULE_NAME` and `<PREFIX>_MODULE_DESC`.
- A key ending in `_F` is the feminine form, used for languages that inflect (de, fr, es, pt, ru). `esMX` and `esES` are separate files.
- `_F` forms exist only for the keys shown with a sex: the `Chronicle:Text` keys (`CORE_LOG_TURNIN`, `CORE_LOG_ABANDON`, `CORE_LOG_ZONE_FIRST`, `CORE_LOG_LEVEL`, `CORE_LOG_DEATH`, `CORE_LOG_REP`, `CORE_LOG_CHAPTER`, `CORE_LOG_DEATH_NOZONE`, `CORE_LOG_CHAPTER_NOZONE`, `CONFLICT_ALLIED`, `CONFLICT_ALLIED_REP`, `CONFLICT_BROKE_WORD`, `CONFLICT_SWITCHED`, `CONFLICT_HOUSETURN`, `ENC_LOG_TRAVEL`, `ENC_LOG_BOSS`, `ENC_LOG_WIPE`, `ENC_LOG_CAMP`, `ENC_LOG_KICK`, `ENC_LOG_CONTACT`) and their `_THEY` forms (`_THEY_F`), `MAP_PIN_OPEN`, `MAP_PIN_ALLIED`, `MAP_PIN_BROKEN`, and `PROFILE_<ARCHETYPE>`. A locale adds one only where its text inflects; `core_locale` fails on any other `_F` key.
- The test mode lists missing keys for the active locale; the specs check every locale.

### 5.9 Slash commands

`/ashmark` and `/amk`. `ns.Slash:Register(sub, fn(args), helpKey)` adds a subcommand.

| Subcommand | Owner | Effect |
| --- | --- | --- |
| (none) | Core | toggle the main window |
| `help` | Core | list subcommands |
| `version` | Core | print `ns.version`; the main window's title and the Addon Compartment tooltip show it too |
| `test`, `probe` | Core (Dev) | 7.10 |
| `debug` | Core | toggle debug output for the session |
| `reset` | Core | `AshmarkDialog` confirmation, then wipe this character's record and its share of the account stores: its `byChar` entries in contacts (a contact left with nobody and no note goes), and its `seenBy` and `logged` entries in peers. The new record keeps `state.senders` and `selfSender` of the party the player is in (nobody re-sends `HI`, 5.6); then Core runs the group check (5.10), so while grouped `GROUP_CHANGED(true)` opens a session and Fiction greets the party again. Conflicts forms its reputation alliances again on the `LOG_COMPACTED` of the new record (7.1) |
| `reset others` | Core | `AshmarkDialog` confirmation, then wipe contacts, peers and rumours that are not own, and empty the `told` lists of own rumours. In every character's record it also removes the log's `contact` and `peer` entries (a new array, as compaction leaves it), drops the stored group `sessions` (a `group.end` line then says "N companions"), empties the open session's `members` and `people`, and clears another character's `state.senders` and `state.greeted`; the current character keeps those of the party it is in |
| `reset <name>` | Core | another character of this account, deleted or moved in the game: the argument matches a stored GUID exactly, else a full or first name ignoring case (`ns.Util.Fold`: A-Z and the capitals of Latin-1, Latin Extended-A and Cyrillic), never the current character; a record without a name only by its GUID, which then names it in the dialog and the done line. No match prints `CORE_RESET_CHAR_UNKNOWN` and wipes nothing; several print `CORE_RESET_CHAR_AMBIGUOUS` and one `CORE_RESET_CHAR_LINE` (name, level, GUID) each; one match asks in `AshmarkDialog` (`CORE_RESET_CHAR_CONFIRM`), then deletes `chars[guid]` and its share of contacts and peers as for `reset` |
| `house <name>`, `house reset` | House | 7.5 |

Every wipe redraws the visible tab: `reset` fires `LOG_COMPACTED` for the new record, `reset others` fires it for the current record when its log changed, and both `others` and `<name>` call `MainFrame:Refresh()`. `others` is a keyword, so a character named Others is reset by its GUID. In read-only mode every reset refuses, with `CORE_SV_MIGRATE_FAILED` after a failed migration and `CORE_RESET_READONLY` otherwise (4.4).

### 5.10 Core watchers

`Core/Watch.lua` writes the core kinds, so every module reads one consistent stream.

- **Quests.** `QUEST_ACCEPTED`: `questID = select(select("#", ...), ...)` (the last argument), valid only if `C_QuestLog.GetLogIndexForQuestID(questID)` returns non-nil → `quest.accept`. `QUEST_TURNED_IN(questID, xpReward, moneyReward)` → `quest.turnin`, and if `moneyReward > 0` also `gold { src = "quest", c = moneyReward }`. `QUEST_DETAIL` carries no quest ID; readers use `GetQuestID()`.
- **Abandon.** With `abandonHooks`: `hooksecurefunc(C_QuestLog, "SetAbandonQuest")` remembers `C_QuestLog.GetAbandonQuest()`, and `hooksecurefunc(C_QuestLog, "AbandonQuest")` writes `quest.abandon` for it; `QUEST_REMOVED` is ignored. Without them: on `QUEST_REMOVED(questID)`, after `C_Timer.After(2)`, write `quest.abandon` only if no `QUEST_TURNED_IN` for that quest arrived within 2 s in either order, `not C_QuestLog.IsQuestFlaggedCompleted(questID)`, and the quest is not a task quest (`C_QuestLog.IsQuestTask`, if present).
- **Zone.** On `ZONE_CHANGED_NEW_AREA` and in lifecycle step 3 after the modules' `OnWorldReady`: `z = Where.Zone(m)`; no entry when `z` is nil; write `zone` only when `z` differs from the last `zone` entry; `first = true` and `zones[z] = t` on the first visit.
- **Group.** The group boundary is defined once, here. On `GROUP_ROSTER_UPDATE` and `GROUP_LEFT` (coalesced 1 s), and in lifecycle step 3 after the modules' `OnWorldReady`, Core compares `ns.Identity:InGroup()` with `state.inGroup`. When they differ, Core stores the new value and fires `GROUP_CHANGED(inGroup)`. Comm, Fiction and Encounters take the group boundary only from this topic: Comm clears `state.senders`, Fiction clears `state.greeted`, Encounters opens or ends its session. Because `state.inGroup` survives /reload and logout, a character that logs back in outside the group still gets `GROUP_CHANGED(false)`.
- **Level and death.** `PLAYER_LEVEL_UP(level)` → `level { l }`; `PLAYER_DEAD` → `death`.
- **Reputation.** Tracked factions: every non-zero faction in `ns.Data.Conflicts` plus 2802. The baseline (`reaction`, `currentStanding` via `Safe.Fields`) is taken silently at the start of lifecycle step 3, or at a faction's first non-nil read. `UPDATE_FACTION` is coalesced to 1 s; for each tracked faction whose values changed, Core writes `rep { f, s = reaction, d }` if `reaction` changed, then fires `REP_CHANGED(f, reaction, delta)`.
- **Gold.** On `PLAYER_MONEY`, `delta = GetMoney() - last`. Quest money is counted once, in either event order: money logged from `QUEST_TURNED_IN` consumes the `PLAYER_MONEY` gains of the next 2 s, and a gain up to 2 s before the `QUEST_TURNED_IN` is taken back out of the context it went into. The rest accumulates in the open context: `loot` (`LOOT_OPENED` to `LOOT_CLOSED`), `vendor` (`MERCHANT_SHOW` to `MERCHANT_CLOSED`), `trade` (`TRADE_SHOW` to `TRADE_CLOSED`), `mail` (`MAIL_SHOW` to `MAIL_CLOSED`). One `gold` entry with signed `c` is written when the context closes, if `c ~= 0`. Changes outside any context collect as `other`, written at most every 10 minutes and at logout.
- **Played time.** `stats["Core.playedSec"]` grows by session time on a 5-minute ticker and at `PLAYER_LOGOUT`, and `lastSeen = time()` is written at the same moments. Core never writes `lastSeen` at login, so readers in `OnWorldReady` see when the previous session ended (to within 5 minutes after a crash). Ashmark never calls `RequestTimePlayed()`.
- **Blocked actions.** `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` with arg1 == `ADDON` append `{ t, event, fn }` to `dev.blocked`.

## 6. UI

Rules from the concept, binding for every unit:

- **Inherit, never rebuild.** Frames come from Blizzard templates: `ButtonFrameTemplate` for the window (it has an `Inset`), `PanelTabButtonTemplate` for tabs, `WowScrollBoxList` with `MinimalScrollBar` through `ns.UI:List`, `UIPanelButtonTemplate` for buttons, `InputBoxTemplate` for single-line input, `DialogBorderTemplate` for the dialog, `TooltipBackdropTemplate` for the quest-dialog strip, `StatusBar` with the standard status bar texture.
- **No StaticPopup.** Ashmark never calls `StaticPopup_Show` and never adds entries to `StaticPopupDialogs`; the shared popup slots would taint Blizzard's own dialogs. Confirmations and the note editor use `AshmarkDialog` (6.2).
- **Fonts:** `QuestTitleFont` for headings, `QuestFont` for text on parchment, `GameFontNormal`, `GameFontHighlight`, `GameFontHighlightSmall`, `GameFontDisable` for lists, `GameFontNormalHuge` for the notice. No custom sizes.
- **Colours** come only from Blizzard colour objects: `NORMAL_FONT_COLOR`, `HIGHLIGHT_FONT_COLOR`, `RED_FONT_COLOR`, `GRAY_FONT_COLOR`, `ChatTypeInfo`, `C_ClassColor.GetClassColor`, `FACTION_BAR_COLORS`. Never literal RGB.
- **Parchment** only as a client texture: `ns.UI:Parchment(texture)` tries `ns.UI.PARCHMENT_ATLASES = { "QuestBG-Parchment" }` (Core may add candidates from the exported Blizzard art) with `C_Texture.GetAtlasInfo` and returns false if none exists; the caller then leaves `AshmarkFrame.Inset.Bg` visible. Never `SetColorTexture` for surfaces.
- **Icons** from the client: class atlases via `GetClassAtlas` when present, quest and item icons via their APIs, map icons from Blizzard's atlases. No emoji, no custom vector art.
- **Sounds:** `SOUNDKIT.IG_QUEST_LOG_OPEN` / `IG_QUEST_LOG_CLOSE` on open and close, `SOUNDKIT.IG_ABILITY_PAGE_TURN` on chapter change; played through `ns.UI:Sound(kit)` (`UI/MainFrame.lua`), which guards the constant and respects `Core.sounds`.
- **Known game patterns, not tables.** No grid lines, sortable column headers, toggle switches or data tables.
- **Information where it happens:** quest-dialog line (Conflicts), unit tooltip line (Encounters), world-map pins (Map), centre-screen notice (Campfire), chat line (Rumours, Encounters recognition).

### 6.1 Main window

`AshmarkFrame` = `CreateFrame("Frame", "AshmarkFrame", UIParent, "ButtonFrameTemplate")`, 640 × 500. `SetTitle(L.CORE_TITLE)`; `SetPortraitToUnit("player")` on show and on `UNIT_PORTRAIT_UPDATE` for `player`. Movable: `SetMovable(true)`, `SetClampedToScreen(true)`, and `TitleContainer` gets `RegisterForDrag("LeftButton")` with `StartMoving` / `StopMovingOrSizing`. `tinsert(UISpecialFrames, "AshmarkFrame")` so Escape closes it.

```lua
ns.UI.MainFrame:AddTab(id, { label = key, order = n, module = name|nil, build = function(parent) return tab end,
                              ignore = function(topic, ...) return true end|nil })   -- skip that refresh
-- tab must have tab:Refresh()
ns.UI.MainFrame:Refresh(id)
ns.UI.MainFrame:Show(id)
ns.UI.MainFrame:Toggle()         -- /ashmark and the compartment
```

MainFrame creates `AshmarkFrame.Tabs[i]` from `PanelTabButtonTemplate` in `order`, calls `SetID(i)`, maps string ids to indices, and uses `PanelTemplates_SetNumTabs`, `PanelTemplates_SetTab` and `PanelTemplates_TabResize`. `build` runs once, when the tab is first shown. Tabs whose module is disabled or unavailable are hidden. MainFrame calls `tab:Refresh()` on show and on `Refresh(id)`, and refreshes the visible tab (only that one) at most every 0.5 s on `LOG_ADDED`, `LOG_COMPACTED`, `NAMES_UPDATED`, `CONTACT_UPDATED`, `HOUSE_CHANGED` and `PROFILE_CHANGED`, unless the tab's `ignore(topic, ...)` returns true: the Chronicle tab skips `PROFILE_CHANGED`, `HOUSE_CHANGED` and entries it never shows (except the one that begins the open chapter, whose date heads the page), the Encounters tab redraws only for contacts, a reset, names and module toggles, and the House tab skips log entries other than family entries and Legacy reputation entries (`House:Concerns`) and item names, so it redraws for those entries, `PROFILE_CHANGED` (the axes), `HOUSE_CHANGED`, `CONTACT_UPDATED` (family memory), `LOG_COMPACTED` and quest names (feud titles). The Chronicle tab keeps its chapter rows (`no`, `open`, `current`) and their data provider until a chapter closes or the record is replaced; a row's title is formatted when the list draws it, and a selection change only moves `current`, so a new entry re-formats no closed chapter. Tab files load after `Modules/` and may capture `ns.<Unit>` at load.

| Tab | id, order | Unit | Content |
| --- | --- | --- | --- |
| Chronicle | `chronicle`, 10 | Core (`UI/Tabs/Chronicle.lua`) | Questlog layout: chapter list on the left, parchment page on the right with the rendered sentences of the selected chapter |
| Decisions | `decisions`, 20 | Conflicts | ReputationFrame pattern (7.1) |
| Encounters | `encounters`, 30 | Encounters | Friends-list pattern (7.4) |
| House | `house`, 40 | House | 7.5 |

Shared widgets in `UI/Widgets.lua`:

```lua
ns.UI:List(parent, { extent = 20, init = function(button, data) end, owner = M }) -> scrollBox, dataProvider
  -- WowScrollBoxList + MinimalScrollBar, CreateScrollBoxListLinearView,
  -- view:SetElementInitializer("Button", init), view:SetElementExtent(extent),
  -- ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view); no XML needed
  -- the box and its bar fill parent; new rows: scrollBox:SetDataProvider(CreateDataProvider(rows),
  -- ScrollBoxConstants.RetainScrollPosition); each row's init runs through the error wrapper (3.6)
  -- under owner, the tab's module (MainFrame when nil)
ns.UI:Parchment(texture) -> bool
ns.UI:ClassColored(text, classFile) -> string
ns.UI:StatusBar(parent) -> StatusBar
```

Every `UI/` file extends `ns.UI` (`local UI = ns.UI or {}; ns.UI = UI`) and never replaces it. Header rows are list rows with `data.header = true`; the list draws them itself (the quest log's +/- toggle and `data.text`) and never hands them to `init`. A header's children are the rows after it up to the next header; collapsing a header rebuilds the data provider without them. The collapsed state is kept per list by `data.key`, else `data.text`, so callers always pass their full rows.

### 6.2 Other surfaces

- `ns.UI.Dialog:Show({ text, edit = { text, max } or nil, accept = key, cancel = key, onAccept = fn(text) })` shows `AshmarkDialog`: DIALOG strata, a `DialogBorderTemplate` border, `GameFontHighlight` text, an `InputBoxTemplate` edit box with `SetMaxLetters(max)` when `edit` is set, two `UIPanelButtonTemplate` buttons. It is in `UISpecialFrames` and is shown and hidden through `ns.Combat.Run`. Shown at once, the edit box takes the keyboard focus with its text highlighted; a dialog asked for in combat appears after it without focus or highlight, so the keys pressed meanwhile overwrite nothing and Enter does not accept it. Answering (a button, Enter or Escape) releases the keyboard focus at once, also in combat, where the hide waits for the fight's end.
- `ns.UI.Notice:Show(text)` shows `AshmarkNoticeFrame`: HIGH strata, centred at the top of the screen (`TOP` of `UIParent`, y = -200), one `GameFontNormalHuge` FontString coloured from `ChatTypeInfo.SYSTEM`, an AnimationGroup that holds 3 s and fades 1 s. Queued through `ns.Combat.Run("notice")`. Ashmark does not use `RaidNotice_AddMessage`.
- `ns.UI.ChatLine:Print(text, kind) -> printed`: `DEFAULT_CHAT_FRAME:AddMessage` with Ashmark's prefix; colour from `ChatTypeInfo.SYSTEM` (`kind = "system"`) or `ChatTypeInfo.MONSTER_SAY` (`"rumour"`); respects `Core.chatLines`.
- Addon Compartment (`UI/Compartment.lua`) and the settings category `Ashmark` (`Core/Settings.lua`).

## 7. Units

Each unit owns the files listed in section 9. A unit needing a change in a file it does not own does not make it; it lists the change in its report. A unit adds files only as `tests/<unit>*_spec.lua` and `tests/helpers/<unit>_mock.lua`.

### 7.1 Conflicts (Module 1)

Data, generated into `Data/Conflicts.lua` by `tools/conflicts.py`, exactly in this shape:

```lua
ns.Data.Conflicts = {
  count = 6,
  list = {
    { id = "gelkis_magram_clan_choice", zone = 1443, theme = "feud",
      A = { faction = 92, quests = { 1382, 1368, 1384 } },
      B = { faction = 93, quests = { 1385, 1367, 1386 } },
      honored = 6,                                -- optional: reaction 5..8 (6 = Honored)
      anchor = { m = 1443, x = 0.55, y = 0.45 },  -- optional: position 0..1 on map m
      verified = false },
  },
  renamed = { ["old_id"] = "new_id" },            -- optional: written only when data/conflicts/renamed.csv
}                                                 -- renames an id
```

- `theme` is one of `feud`, `law`, `trade`, `nature`, `faith`, `other`. `faction = 0` means the side has no faction: no reputation trigger, and the dialog line uses `CONFLICT_CONTRADICTS_NOFACTION`. A quest belongs to at most one conflict (the validator enforces it). `source` and `quest_name` stay in the CSV and are not shipped.
- CSV header (Dataset unit): `conflict_id,zone,theme,honored,anchor_m,anchor_x,anchor_y,side,faction,quest,quest_name,verified,source`.
- Ids and sides are permanent once generated, because stored alliances name them. `data/conflicts/registry.csv` lists every id the generator ever wrote with each side's faction and quests; `--check` fails on a missing registry, a dropped id, a side with another faction or a quest moved to the other side. `data/conflicts/renamed.csv` (`old_id,new_id,reason`) is the only way to rename or retire an id: the target keeps the old id's sides, two ids never become one (two old ids renamed to one, or an old id renamed onto an id generated under its own name: a new target enters the registry with every quest of the old id, so one registered without them was released on its own), and a renamed or retired id is never reused. Renames ship as `renamed`; retired ids do not ship.
- Conflicts builds its indices in `OnInitialize` (`byQuest[q] = { id, side }`, `byId`, `byZone`) and never edits the data. `tests/conflicts_spec.lua` uses its own fixture, not `Data/Conflicts.lua`.
- Also in `OnInitialize`, every `AshmarkDB.chars` record follows the renames: the keys of `allied`, `since`, `began`, `broken` and `turned` move from an old id to its `renamed` target (a value already stored under the target wins; read-only mode moves nothing), so House reads siblings by the current id. `Get` resolves an old id, so `alliance`, `violation` and `houseturn` entries written before a rename still render. A retired id stays in stored state and resolves to nothing. Its `alliance`, `violation` and `houseturn` entries render nothing, as a forgotten contact does (7.4), and Map pins none of its violations (7.3); the entries stay in the log with `c` and `side`, so a later release that ships the id again tells them again. The Decisions header still counts its violations: `violations` is the character's lifetime record.

Rules, active from `OnWorldReady`:
1. **Alliance by quest.** A `quest.accept` or `quest.turnin` entry (via `LOG_ADDED`) for a quest on side S of conflict C, with no alliance in C: `allied[C] = S`, `since[C] = t`, `alliance { c, side = S }`, `began[C]` = that entry's `n`, `ALLIANCE_FORMED(C, S, false)`. Each such alliance keeps its own entry. Its line (`CONFLICT_ALLIED`, `_THEY`: "You sided with {faction} in {zone} ({title}).") names the conflict's `Title`, so alliances in conflicts of one faction pair in one zone read apart; the `_REP` lines of rule 2 stand for every conflict a pass decides in the zone and name none.
2. **Alliance by reputation.** In `OnWorldReady`, on `REP_CHANGED` and on `LOG_COMPACTED` (the new record after `/ashmark reset`, 5.9; after a compaction every alliance already stands), for each conflict with `honored` and no alliance: read `reaction` with `Safe.Fields(C_Reputation.GetFactionDataByID(f), "reaction")` for both sides' factions. Compare `reaction` (standing ID 1 to 8; 6 = Honored) with `honored`; never compare `currentStanding`, which holds raw points. If exactly one side S is at or above `honored`: `allied[C] = S`, `since[C] = t`, `alliance { c, side = S, rep = true }`, `began[C]` = that entry's `n`, `ALLIANCE_FORMED(C, S, true)`. If both are, no alliance forms. The conflicts one pass decides for the same faction in the same zone form together: one `alliance` entry with `c` = the first of them in data order, and for each conflict its own `allied`, `since`, `began` (that entry's `n` and `t`) and `ALLIANCE_FORMED`. A character Honored with a faction gets one chronicle line and one rumour per zone, not one per conflict.
3. **Contradiction line.** On `QUEST_DETAIL`, `questID = GetQuestID()`. A quest on side S' of C while `allied[C]` is the other side shows `CONFLICT_CONTRADICTS` with `{faction}` = `ns.Names.Faction` of the allied side (or `CONFLICT_CONTRADICTS_NOFACTION`). Quest acceptance is never blocked; addons cannot block it.
4. **Violation.** A `quest.turnin` of such a quest: `o = ns.Profile:IsOpportunist(char) and 1 or nil`, read before the write; `violation { c, side = S', q, o }`; `violations + 1`; `broken[C] + 1`; `allied[C] = S'`; `since[C] = t`; `began[C]` = the violation's `n`; `ALLIANCE_BROKEN(C, S', q)`. No `alliance` entry and no `ALLIANCE_FORMED` follow; the violation is the record. The renderer uses `CONFLICT_SWITCHED` when `o == 1`, otherwise `CONFLICT_BROKE_WORD`.
5. **Turning from the house.** When rule 1 or 2 forms this character's first alliance in C on side S and `ns.House:SiblingAlliances(char)[C]` holds GUIDs only on the other side, Conflicts writes `houseturn { c, side = S, q, h = ns.House:Key(char) }` right after the `alliance` entry and sets `turned[C] = true`. At most once per conflict per character; never a violation. A group formed together (rule 2) writes at most one `houseturn`, for the first conflict whose siblings stand against the side taken, and sets `turned[C]` for every conflict of the group they stand against.
6. **House hint.** On `QUEST_DETAIL` for a quest on side S of C, with no alliance in C and siblings holding only the other side: `CONFLICT_HOUSE_STANDS_AGAINST` with `{house}`. Siblings on both sides: no hint.

Quest-dialog line (`QuestDialog.lua`): one Ashmark frame, a child of `QuestFrameDetailPanel` inheriting `TooltipBackdropTemplate`, its top corners anchored to `QuestFrame`'s bottom corners so it keeps the dialog's width: a strip under the dialog, outside QuestInfo's layout chain. One `GameFontNormal` FontString, tinted `RED_FONT_COLOR` for contradictions and `NORMAL_FONT_COLOR` for house hints. Shown on `QUEST_DETAIL` when a line applies; hidden on `QUEST_FINISHED`, `QUEST_PROGRESS`, `QUEST_COMPLETE` and on `QuestFrame`'s `OnHide` (`HookScript` through `M:Hook`). It never touches a Blizzard region. The test screenshot confirms the placement.

Decisions tab: the ReputationFrame pattern. Collapsible zone headers (`ns.Names.Map(zone)`), one row per conflict with its title and both sides' faction names (`CONFLICT_TAB_SIDES`, "{title}: {a} or {b}"; `Title` is the first side-A quest's title, so conflicts of one faction pair in one zone are told apart), the allied side and its date or "open", and the broken count; the violation total sits in the tab header.

### 7.2 Profile (Module 2)

Three axes in [-100, 100]. Positive Habitat = wild, negative = civil; positive Mercy = merciful. Profile keeps incremental accumulators in `char.profile` and never rebuilds from the log (time-based inputs are not in the log; a replay exists only as a test helper).

- **Decay.** Before every change and on every ticker run: `raw[a] = raw[a] * 0.5 ^ ((now - asOf) / (30 * 86400))` with `now = ns.Util.Now()`, then `asOf = now`. `Axes()` computes the same decayed values without storing them, so it works for any character and in read-only mode. The displayed axis is `Clamp(Round(raw[a]), -100, 100)`. `PROFILE_CHANGED(axes)` fires when a displayed integer changes.
- **Ticker.** `ns.Util.Ticker("Profile", 60)`, skipped while `UnitIsAFK("player")`. It adds 60 s to `wild` when `IsOutdoors() and not IsResting()`, or to `civil` when `IsResting()`; every full 600 s applies the weight. It also rolls the day.
- **Day.** `day.key = date("%Y-%m-%d")`. When the ticker or `OnWorldReady` sees a new key, the finished day applies the gold rule, the calm-day rule and the 7-day alliance check, then `day` resets.

The weights live in one `WEIGHTS` table at the top of `Profile.lua` and are covered by tests.

| Axis | Input | Weight |
| --- | --- | --- |
| Fidelity | `quest.turnin` of a quest on the side this character was allied with before the turn-in: `C, S = ns.Conflicts:SideOf(q)`, `side, began = ns.Conflicts:Alliance(char, C)`, `side == S` and `began < entry.n`. A violation or an alliance formed by this turn-in begins at a later `n` and earns nothing | +2 |
| | an alliance held 7 days since `since[C]` or the last award (`kept[C]`). Alliances that share `began[C]` (formed together by one standing, 7.1) earn one award between them; a conflict the shipped dataset no longer lists earns nothing | +5 |
| | `violation` | -25, or -15 when `o == 1` |
| | `quest.abandon` | -2 |
| | per day, `loot` gold beyond `quest` gold | -1 per 10 gold, at most -5 |
| Habitat | `rest.camp`, `rest.bedroll` | +6 |
| | 600 s wild | +1 |
| | 600 s civil | -1 |
| | `quest.turnin` with `Where.Zone(m)` in `CAPITAL_MAPS` | -1 |
| Mercy | a played day without `kill.*` | +1 |
| | `kill.neutral` | -3 |
| | `kill.critter` | -2 |

`CAPITAL_MAPS = { 1453, 1454, 1455, 1456, 1457, 1458 }` (Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity), at the top of `Profile.lua`. In `OnInitialize` every character's `profile.kept` keys follow `ns.Data.Conflicts.renamed` as Conflicts' stores do (7.1), so a renamed conflict keeps its award cadence.

**Kill approximation** (no combat log):
- "Out of combat" means live `Safe.Bool(UnitAffectingCombat("player")) == false`, read at each sample; never `InCombatLockdown()` and never a flag set by the REGEN events. A secret read counts as in combat: no sample.
- Out of combat, `PLAYER_TARGET_CHANGED` samples from scratch: `cand` is set only if a target exists, `Safe.Bool(UnitIsDead("target")) == false`, `Safe.Value(UnitReaction("target", "player")) == 4`, `Safe.Bool(UnitAffectingCombat("target")) == false` and `Safe.Bool(UnitPlayerControlled("target")) == false`; `cand.critter = isCritter("target")`. Otherwise `cand = nil`.
- Out of combat, `UNIT_FLAGS` for `target` samples the same way while there is no `cand`. With a `cand` it only refreshes the reaction and the secret checks: it clears `cand` when the reaction is no longer 4 or a read is secret, never because the target is now in combat. The target and the player usually enter combat in the same server update, and `UNIT_FLAGS(target)` can be dispatched before `PLAYER_REGEN_DISABLED`. The target itself changes only through `PLAYER_TARGET_CHANGED`, which samples again.
- Any secret read clears `cand` and adds to `Profile.killSecret`.
- `PLAYER_REGEN_DISABLED` freezes `cand` (no new samples). If `cand` is set, Profile adds to `Profile.killCand` and registers `UNIT_HEALTH` for `target`. "Attacked" means: the target when combat began.
- In combat, `PLAYER_TARGET_CHANGED` clears `cand`, so no GUID comparison is needed.
- On `UNIT_HEALTH` and on `UNIT_FLAGS` for `target` while a frozen `cand` is set: if `Safe.Bool(UnitIsDead("target")) == true` and `Safe.Bool(UnitIsTapDenied("target")) == false`, write `kill.critter` (when `cand.critter`) or `kill.neutral`, count it, clear `cand` and unregister `UNIT_HEALTH`. Checking both events catches a death that shows up in a flags update after the last health update. `PLAYER_REGEN_ENABLED` clears and unregisters as well.
- `isCritter(unit)`: creature type 8. The second return of `UnitCreatureType(unit)` if it is a number; otherwise the first return equals `C_CreatureInfo.GetCreatureTypeInfo(8).name` (`critterType`). Neither available: false, so `kill.critter` is off and the test report says so.
- Counters `Profile.killCand`, `killSecret`, `killNeutral`, `killCritter` feed the Mercy accuracy check (7.10).

**Archetype**, used by Fiction, Rumours and the House tab: the axis with the largest absolute value at least 34 decides (ties: fidelity, then habitat, then mercy). Fidelity + `OATHKEEPER`, − `OPPORTUNIST`; habitat + `WANDERER`, − `TOWNSFOLK`; mercy + `GENTLE`, − `RUTHLESS`; none `PRAGMATIST`. The wire carries the key, the UI shows `L["PROFILE_" .. key]`.

**Origin**: while `stats["Core.playedSec"] < 72000` (20 hours), the ticker adds 60 s to `originSec[Where.Zone(m)]`. Once the threshold is passed, `origin` = the zone with the most seconds, `originSec = nil`, and it is never recomputed. `Origin(char)` returns `origin`, else the current leader, else nil.

### 7.3 Map (Module 3)

`Modules/Map/MapPins.xml`:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
  <Frame name="AshmarkMapPinTemplate" mixin="AshmarkMapPinMixin" virtual="true" enableMouse="true">
    <Size x="20" y="20"/>
    <Layers><Layer level="ARTWORK"><Texture parentKey="Icon" setAllPoints="true"/></Layer></Layers>
    <Scripts>
      <OnLoad method="OnLoad"/>
      <OnEnter method="OnMouseEnter"/>
      <OnLeave method="OnMouseLeave"/>
    </Scripts>
  </Frame>
</Ui>
```

`Modules/Map/Map.lua`:

```lua
AshmarkMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
function AshmarkMapPinMixin:OnLoad() self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") end
function AshmarkMapPinMixin:OnAcquired(info) self.info = info; self.Icon:SetAtlas(info.atlas); self:SetPosition(info.x, info.y) end
function AshmarkMapPinMixin:OnMouseEnter() end   -- GameTooltip from self.info: stored data and ns.Names only
function AshmarkMapPinMixin:OnMouseLeave() GameTooltip:Hide() end
function AshmarkMapPinMixin:DisableInheritedMotionScriptsWarning() return true end   -- the XML sets OnEnter/OnLeave;
                                                         -- without this, AcquirePin asserts on a new pin

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
function provider:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate("AshmarkMapPinTemplate") end
function provider:RefreshAllData(fromOnShow)
  self:RemoveAllData()
  if not M.enabled then return end
  if InCombatLockdown() then self.dirty = true return end
  -- for each pin below: self:GetMap():AcquirePin("AshmarkMapPinTemplate", info)
  -- with info = { x, y, atlas, ... } for self:GetMap():GetMapID()
end
```

- No `SetPassThroughButtons` override: pins are acquired only out of combat, so the canvas's `CheckMouseButtonPassthrough("RightButton")` on `AcquirePin` always runs out of combat, and a right click on a pin zooms the map out. No test can click, so it is checked by hand at launch: a right click on a pin in Desolace zooms out to Kalimdor.
- `OnEnable` adds the provider with `WorldMapFrame:AddDataProvider(provider)`, and `OnDisable` removes it with `RemoveDataProvider`, both through `ns.Combat.Run`. On `PLAYER_REGEN_ENABLED`, if `provider.dirty` and `WorldMapFrame:IsShown()`, Map calls `RefreshAllData()`. New `violation` and `chapter` entries and `ALLIANCE_*` topics refresh a shown map through `ns.Combat.Run("map:refresh")`.
- **Zone and smaller maps** (`C_Map.GetMapInfo(shown).mapType` greater than `Enum.UIMapType.Continent`: Zone, Dungeon, Micro, Orphan): conflict anchors with `anchor.m == shown`; `violation` entries and chapter records whose `m` or `Where.Zone(m)` equals `shown` and that have `x` and `y` (divide by 100). A position recorded on a map `m ~= shown` is relative to `m` and is converted through `C_Map.GetMapRectOnMap(m, shown)` as on continent maps.
- **Continent maps** (`Enum.UIMapType.Continent`): conflict anchors only. `minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(a.m, shown)`; skip if nil or empty (zero width or height); `x = minX + a.x * (maxX - minX)`, `y = minY + a.y * (maxY - minY)`.
- World and cosmic maps: no pins.
- Anchor states: `open` (no alliance in C), `allied` (an alliance, never broken), `broken` (`broken[C] > 0`). Tooltip: the conflict's title and both factions' names (`MAP_PIN_SIDES`, "{title}: {a} or {b}", title from `ns.Conflicts:Title`), then the state. Atlases in `ns.Map.ATLAS = { open, allied, broken, violation, chapter }` are Blizzard atlas names chosen by Map; Map registers a test check for them and the template.
- Map keeps a per-map cache of violation and chapter positions, appended on `LOG_ADDED` and rebuilt after `LOG_COMPACTED`. Chapter records on the same `m`, `x`, `y` share one pin: the newest record's tooltip, then `MAP_PIN_CHAPTER_COUNT` ("Chapters closed here: {count}") with how many closed there; every violation keeps its own pin. A `violation` whose `c` `ns.Conflicts:Get` no longer resolves (a retired id, 7.1) gets no pin, since its chronicle sentence tells nothing.
- Ashmark never calls `WorldMapFrame:SetMapID`, `NavigateToMap`, `Show` or `Hide`, and never adds frame-level types. Known risk: map-replacement addons (OpenMap, Leatrix Maps) may not call data providers.

### 7.4 Encounters (Module 4)

```lua
Contact = {
  guid, name, surname, class, race, raceName, sex, faction, ruleset,   -- latest snapshot (Safe.Clean)
  locale,                                                    -- ns.Locale.active when raceName was read
  note = "",                                                 -- shared by the account, at most 120 characters
  byChar = { [charGuid] = { first, last, count, lastPlace, lastInstance,
                            outcomes = { [e] = n }, sessions = { id, ... } } },   -- last 10 session ids
}
Session = { id = <ns.Util.Token()>, start, stop, members = { guid, ... }, people = { [guid] = Person },
            maps = { zoneMapId, ... }, inst = { instanceID, ... }, boss = 0, wipe = 0,
            camp = false, kick = false, e }
```

Contacts are keyed by the contact's GUID account-wide; counts, dates and outcomes live per character, so an alt does not remember what a sibling met. The House tab shows sibling meetings as family memory.

- **Membership**, everywhere including instances: `GROUP_CHANGED(true)` (5.10) opens a session in `state.group` if none is open; `GROUP_CHANGED(false)` ends the open session. Encounters never decides the group boundary itself. While a session is open, it adds members when it opens and on every `GROUP_ROSTER_UPDATE` (coalesced 1 s), reading the unit tokens `ns.Identity:Tokens("all")` names (5.3): while they name a battleground's instance group it adds nobody, so strangers from a battleground never become companions.
- **Snapshots** via `ns.Identity:Group("all")` only when `not IsInInstance()` and `not ns.Safe.InLockdown()`; `people` holds up to 40 Persons. A member who joins inside an instance is snapshotted at the first roster update outside it, or never; such members appear in `members` only. A member whose name still reads as the client's placeholder (`UNKNOWNOBJECT`, `UKNOWNBEING`; `Identity:Unit` returns nil, 5.3) is not snapshotted and keeps the Person of an earlier snapshot, so a contact never takes "Unknown" with its class and race missing.
- **Context:** a new session starts with the current zone in `maps` (and the instance in `inst` when it opens inside one); `zone` entries during the session add to `maps`; `PLAYER_ENTERING_WORLD` inside an instance adds `select(8, GetInstanceInfo())` (through Safe) to `inst`. `ENCOUNTER_END`: `success = Safe.Value(select(5, ...))`; `== 1` adds a boss, `== 0` a wipe, secret counts neither; `encounterName` is never read. `CHAPTER_CLOSED` with members sets `camp`. `CHAT_MSG_SYSTEM`: `msg = Safe.Value(...)`; `if msg and msg == ERR_UNINVITE_YOU` sets `kick` (kick detection is unavailable where the text is secret, e.g. inside instances).
- **Outcome** `e` at session end, first that applies: `kick`, `boss`, `wipe`, `camp`, `travel`.
- **Session end:** `stop = now`. For each member in `people`: the contact's snapshot fields are overwritten; `byChar[current]` gets `count + 1`, `first` if unset, `last`, `lastPlace` (last of `maps`), `lastInstance`, `outcomes[e] + 1` and the session id (keep 10); a `contact { p }` entry on this character's first meeting (a contact the store pruned and met again gets none while this character's log still holds its `contact` entry, which then names it again); `CONTACT_UPDATED(guid)`. Then `group.end { g = id, size = #members, inst = last of inst, e }`, `sessions[id] = session` (without `people`), `state.group = nil`, `GROUP_SESSION_ENDED(session)`.
- **Reload and login:** in `OnWorldReady`, an open `state.group` resumes if `ns.Identity:InGroup()` and at least one stored member is still in the group, or the unit tokens name an instance group, where no member of the home group can be seen. Otherwise it ends with `stop = char.lastSeen`, the end of the previous session (5.10), not the login time; if the player is in a group, a new session then opens.
- **Recognition:** when a roster update adds members this character has met, one chat line `ENC_RECOGNISE` ("You know {name}: met {count}×, last in {place}.") for at most 3 of them, then `ENC_RECOGNISE_MORE` ("…and {count} more you know."). Not inside instances.
- **Recurring contact:** `byChar[current].count >= 3` (`ENC_RECURRING`).
- **Unit tooltip** (`Tooltip.lua`, through `M:Hook`): `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data) ... end)`. Return unless `tooltip == GameTooltip` and not `tooltip:IsForbidden()`; `guid, ok = Safe.Field(data, "guid")` (`TooltipUtil.GetDisplayedUnit` only as a fallback); return unless ok and `byChar[current]` exists; add `ENC_TOOLTIP` ("Met: {count}× · last {place}"), plus `ENC_TOOLTIP_PEER` ("{archetype}", for the contact's sex, 5.8) when `ns.Fiction:Peer(guid)` exists.
- **Note editor:** `ns.UI.Dialog` with an edit box, `max = 120`; stored in `contact.note`, local only; fires `CONTACT_UPDATED`.
- **Encounters tab:** friends-list pattern: contacts with a `byChar` entry for the current character, newest `last` first; name in class colour, race and class (`ENC_TAB_WHO`; a race or class the client does not know is left out, so a row may show one of them or neither), times met, last place, note; a marker for recurring contacts; a note button. A refresh builds and sorts small row records only; a row's texts are built when the list draws it.
- **Chronicle:** the `group.end` renderer (Encounters) names up to 3 members from contacts ("You travelled with Thalen and Mira."), and appends a peer's archetype (for the contact's sex, 5.8) and origin through `ns.Fiction:Peer(guid)` and `ns.Names.Map` ("Thalen (Oathkeeper from Westfall)"). When the session is gone (pruned, 4, or dropped by `/ashmark reset others`, 5.9), only `size` is known: `ENC_LOG_COMPANION` / `ENC_LOG_COMPANIONS` ("{count} companions"), since some may have been contacts; size 0 says `ENC_LOG_STRANGERS_ANY`. Names are lost once sessions or contacts are pruned. The `contact` renderer returns nil when the contact is gone; `/ashmark reset others` removes the `contact` entries themselves.
- Contacts are never sent anywhere.

### 7.5 House (Module 5)

- **House key** (`ns.House:Key(char)`): `char.houseOverride`, else `char.surname` exactly as stored (trimmed), else nil. A character without either has no house.
- **Members:** every `AshmarkDB.chars` record with the same key. A character deleted or moved in the game stays a member until `/ashmark reset <name>` (5.9) forgets it.
- `/ashmark house <name>`: if `<name>` equals, ignoring case (`ns.Util.Fold`, 3.4), the stored surname of an account character or the `houseOverride` of another one, that stored name becomes `houseOverride` (an exact match wins); otherwise `<name>` as typed (trimmed). `house reset` clears it. Both fire `HOUSE_CHANGED`.
- `SiblingAlliances(char[, members])`: the siblings' `conflicts.allied`, grouped per conflict into `A` and `B` GUID lists.
- `FamilyChronicle(char, limit[, members])`: all members' `alliance`, `violation`, `houseturn`, `chapter` and `level` (multiples of 10 only) entries, newest first, rendered with `ctx.own = (member == char)`. It remembers each log's family entries and the newest `n` it read, so later calls read only newer entries; a log replaced by a new table (compaction, reset) is read afresh.
- **House tab:** members sorted by level (class icon, level, full name, ruleset tag when rulesets differ); the three axes as `ns.UI:StatusBar`s labelled with the archetype (for the character's sex, 5.8); inherited feuds = sibling alliances this character does not share, one row per conflict, side and sibling (`HOUSE_TAB_FEUD`, "{title}: {name} sided with {faction} in {zone}.", `{title}` = `ns.Conflicts:Title`, so conflicts of one faction pair in one zone are told apart), sorted by zone, title, faction and name; the family chronicle; family memory = siblings' recurring contacts from `ns.Encounters:Known(sibling, 3)` ("{sibling} knows {name}", worded when its row is drawn); the Legacy level if `legacy` (`C_MajorFactions.GetMajorFactionData(2802).renownLevel`, else the standing label `GetText("FACTION_STANDING_LABEL" .. reaction, sex)`).

### 7.6 Campfire (Module 6)

Aura spell IDs (Wowhead Forever, unverified until the probe confirms them):

```lua
ns.Campfire.AURAS = {
  NEARBY   = 1283391,   -- passive, 100 yd
  WELCOME  = 1289723,   -- while sitting at a camp
  BENEFITS = 1229741,   -- after one minute at a camp
  BOOSTED  = 1229451,   -- Camp Tent debuff
  BEDROLL  = { },       -- Cozy Sleeping Bag "Well-Rested"; filled from the probe, empty until verified
}
```

- **Check()**: return if `InCombatLockdown()` or `Safe.AurasRestricted("player") == true`. For each tracked ID: `ok, aura = Safe.Call(C_UnitAuras.GetPlayerAuraBySpellID, id)`; if any call is not ok, return and keep the old state. `now[id] = aura ~= nil`; diff with `present`. The `UNIT_AURA` payload is ignored.
- Called on `UNIT_AURA` (unit event, `player`) and `PLAYER_REGEN_ENABLED`. In `OnWorldReady` it only seeds `present` and fires no transitions, so a reload at a camp writes nothing; then `state.rest` is cleared unless `WELCOME` is present.
- **Transitions**, in this order within one Check: `BENEFITS` appears while `state.rest` is set → `rest.camp`, `state.rest = nil`, chapter check. `WELCOME` disappears while `state.rest` is still set (the player stood up before the benefit) → `state.rest = nil`. `WELCOME` appears → `state.rest = { started = t }`. Any `BEDROLL` ID appears → `rest.bedroll`, chapter check.
- A `state.rest` older than 10 minutes is stale: Check clears it before the transitions, and `IsResting()` ignores it, so a later `BENEFITS` never writes `rest.camp` against an old start.
- **Chapter check:** the open chapter holds at least 20 entries (`Log:Seq(char)` minus the last chapter's `to`) or its first entry is at least 30 minutes old by `ns.Util.Now()`, the clock that stamped it → `ns.Log:CloseChapter(members)` with the GUIDs of `ns.Identity:Group("party")`; notice `CAMP_CHAPTER_CLOSED` ("Chapter {roman} closes · {place}") with `ns.Util.Roman` and `ns.Names.Map`; the page-turn sound.
- `IsResting()`: a `state.rest` at most 10 minutes old, or `present[WELCOME]`.

### 7.7 Knowledge (Module 7)

Held items:
- Bags: `Enum.BagIndex.Backpack` to `Enum.BagIndex.ReagentBag` (0 to `NUM_TOTAL_EQUIPPED_BAG_SLOTS`). Bank, on `BANKFRAME_OPENED`: every `Enum.BagIndex` value whose key contains `Bank` and not `Account`, plus `Enum.BagIndex.Bank` if present, keeping those with `C_Container.GetContainerNumSlots(i) > 0`. Equipment: `GetInventoryItemID("player", slot)` for `INVSLOT_FIRST_EQUIPPED` to `INVSLOT_LAST_EQUIPPED`; the bag forming each scanned container above 0 counts too, `GetInventoryItemID("player", C_Container.ContainerIDToInventoryID(bag))` where the client has it.
- Events: `BAG_UPDATE_DELAYED` (coalesced 1 s), `PLAYER_EQUIPMENT_CHANGED`, `BANKFRAME_OPENED`.
- A new item ID writes `knowledge.held[id] = t` and an `item.held { it }` entry. Silence is tracked per area: the first full scan of bags and equipment (`scanned.bags == false`) and the first bank scan (`scanned.bank == false`) fill `held` silently and set their flag, so the first bank visit after install writes no burst of entries.

Item tooltip (`TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)` through `M:Hook`), in this order. Steps 2 to 8 are one function of `(tooltip, data)`; the post-call runs step 1 and then calls it, and the test check calls it directly (7.10).
1. Return unless the tooltip is `GameTooltip`, `ItemRefTooltip`, `ShoppingTooltip1` or `ShoppingTooltip2`, is not `IsForbidden()`, and `GetName()` is not nil.
2. `id, ok = Safe.Field(data, "id")`; return unless ok and id.
3. Return if this character holds the item: `knowledge.held[id]` is set, or `C_Item.GetItemCount(id)` (bags, not the bank; through Safe, feature-detected) is above 0, so an item put into the bags before the 1 s scan has noted it counts as held. Step 3 writes nothing; the scan does the noting.
4. Return if `Knowledge.questRewards` is on and `tooltip:GetOwner()` is inside `QuestFrame`: quest rewards are never hidden.
5. Revealed = `C_Item.IsItemDataCachedByID(id)`, cached per item per session and updated on `ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED`. Not revealed: return (the server still hides it). The post-call never calls `C_Item.GetItemInfo` and never requests item data.
6. For `i = 2, tooltip:NumLines()`: read `_G[name .. "TextLeft" .. i]:GetText()` and `TextRight` through Safe; if any text is secret, or a data line's `leftText` or `type` is, return without changes.
7. Keep line 1 and every line that is: of type `ItemName`, `ItemBinding`, `EquipSlot`, `SellPrice` or `Restricted*` (`data.lines[i].type`, used only when `data.lines[i].leftText` equals the tooltip's line i, so lines other addons added or moved match no data line and only those lose their type); matching `ITEM_LEVEL` or one of the binding and requirement strings (`ITEM_BIND_ON_EQUIP`, `ITEM_BIND_ON_PICKUP`, `ITEM_BIND_ON_USE`, `ITEM_BIND_QUEST`, `ITEM_SOULBOUND`, `ITEM_BIND_TO_ACCOUNT`, `ITEM_BIND_TO_BNETACCOUNT`, `ITEM_ACCOUNTBOUND`, `ITEM_BNETACCOUNTBOUND`, `ITEM_MIN_LEVEL`, `ITEM_CLASSES_ALLOWED`, `ITEM_RACES_ALLOWED`, `ITEM_MIN_SKILL`, `ITEM_REQ_SKILL`, `ITEM_REQ_REPUTATION`, `ITEM_REQ_ALLIANCE`, `ITEM_REQ_HORDE`; read through `_G[key]`, a string the client lacks is skipped) turned into a pattern once at load (magic characters and `%` escaped, `%d`/`%1$d` → `%d+`, `%s`/`%1$s` → `.+`, `%%` → a literal %); equal to the item's type, subtype or slot (`_G[equipLoc]`, e.g. "Two-Hand") from `C_Item.GetItemInfoInstant`; or without visible text on either side (a spacer, or the line a money frame sits on). Every other line gets `SetText("")` on its left and right font strings. A line another addon inserts in the middle sends every later line to these fallbacks; whether Blizzard's own code adds item lines in a post-call, and what text the sell-price line carries, is checked in the client.
8. Add `KNOW_UNKNOWN` ("Your character has never held this."), then `tooltip:Show()` to resize (rule 11).

Three states result: hidden by the server (untouched), revealed but never held by this character (lines hidden), held (untouched).

### 7.8 Rumours

```lua
Rumour = { id, tpl, a = archetype, f = factionId (0 = none), m = mapId, hops, strength, t = origin epoch,
           heard = epoch, own = true|nil }
```

- **Ids:** `ns.Util.Token()`, 8 random hex characters (`math.random` seeded once in `Core/Init.lua`), regenerated on collision. A rumour id never contains or derives from a GUID.
- **Seeds**, from own entries via `LOG_ADDED`: `alliance` → `ALLIANCE` (f = the allied faction); `violation` → `BROKE` (f = the faction of the side broken with); `houseturn` → `TURNED` (f = the faction of the side taken). `a = ns.Profile:Archetype(char)`, `m` = the conflict's `zone`, `hops = 0`, `strength = 100`, `own = true`. An own rumour with the same `tpl`, `a`, `f` and `m` still at strength 20 or more stands in for a new seed: nothing is written, so the account keeps one rumour per template, archetype, faction and zone while it lasts (one `ALLIANCE` rumour for all four Gelkis quests of Desolace, and none repeating a rule-2 rumour for the same zone). A received copy never stands in.
- **Strength** on read: `strength * 0.5 ^ ((now - heard) / (3 * 86400))`, with `now = ns.Util.Now()` here and for every stamp Rumours writes. A received copy's `strength` is already decayed by its sender, so it decays from `heard`, not from `t` (for own rumours `heard == t`); `t` only drives the age on the wire. Below 20 the rumour is dropped at the next prune.
- **Exchange round:** on `PEER_SEEN` (coalesced 5 s) and on `CHAPTER_CLOSED` with members; at most one round per 2 minutes. Candidates are rumours with strength at least 20 that some peer in `ns.Fiction:PresentPeers()` has not been told; newest, then strongest, at most 3. Each goes out as `ns.Comm:Send("RU", { id, tpl, hops, strength, age, a, f, m }, "PARTY")` with the decayed strength and `age = floor((now - t) / 3600)`, and `told[id][peerGuid] = now` is set for every present peer.
- **Receiving** (Comm accepts `RU` only from senders validated by `HI`): an id already in `heard` keeps the stronger copy and prints nothing. A new id beyond 6 per sender per 2 minutes (twice an honest client's 3 per round) is dropped: not stored, not recorded in `told`, no topic. Otherwise `hops + 1`; `strength = floor(strength * 0.7)`; `t = now - age * 3600`; at `hops >= 2`, `m = ns.Where.Continent(m)`; at `hops >= 3`, `f = 0` (template variant `_VAGUE`). A map unknown to `C_Map.GetMapInfo`, or a strength below 20, drops the rumour. The complete record is built, then stored, then `RUMOUR_HEARD(rumour)` fires and one chat line `RUMOUR_HEARD_<TPL>` or `RUMOUR_HEARD_<TPL>_VAGUE` ("People say the {archetype} from {place} has sided with {faction}.") is printed within the re-print limits below. The `rumour { r }` entry is written only together with a printed line, so other players add at most 5 entries an hour. `f = 0` always uses the `_VAGUE` form.
- **Re-print:** on `ZONE_CHANGED_NEW_AREA`, at most one rumour line: the strongest rumour whose `m` is the current zone or its continent and that was not shown in the last 24 hours (`state.shown`); at most 5 rumour lines per hour in total (`state.lines`).
- At most 200 stored rumours (4); received copies go before own rumours, so what others send never pushes out this character's own.
- No names: rumours describe an archetype and an origin, never a character. The client names the sender of every addon message, though, so party members who hear an own rumour first (hops 0) know whose deed it is. A copy keeps its id, its content and its age from hop to hop, and its hops (and the zone, continent and faction steps) give its distance from the source. Whoever knows whose deed a rumour is can therefore tell from a later copy that its sender grouped with that character (hops 1), or how many groups lay between them, within the rumour's life of about a week. A fresh id per hop or a vaguer hop count would not hide this: the content (template, archetype, faction, place, age in hours) and those steps identify the rumour and its hop range anyway. `RUMOUR_MODULE_DESC` tells the player so.

### 7.9 Fiction (silent shared fiction)

```lua
Peer = { guid, archetype, origin, ruleset, version, profile = { fidelity, habitat, mercy } or nil,
         first, last, seenBy = { [charGuid] = archetype },      -- the archetype this character's log last recorded
         logged = { [charGuid] = epoch } }                       -- when this character last wrote a peer entry
```

- **Greeting:** the roster check runs on `GROUP_ROSTER_UPDATE` (coalesced 2 s) and once in `OnWorldReady`:
  1. Every GUID in `state.greeted` that is no longer in `ns.Identity:Group("party")` is removed, so a member who leaves and rejoins is greeted again.
  2. If the party holds a GUID not in `state.greeted`, send `HI { guid, archetype, origin, ruleset, version }` and then `PR { guid, fidelity, habitat, mercy }`, and set `greeted[guid] = now` for every current party member.
  3. At most one greeting per 30 s. A greeting due inside the window waits instead of being dropped: `ns.Util.Debounce("Fiction.greet", remaining, check)` runs the roster check again when the window ends, so a member who joins within 30 s of the last greeting is still greeted.

  `state.greeted` is cleared on `GROUP_CHANGED(false)` (5.10). Every client greets on its own roster change, so nobody replies and nothing loops: one join in a party of five costs at most 10 messages across all clients. A /reload loses nothing: `state.greeted` and Comm's sender map (5.6) both survive it.
- `version` = `ns.version` stripped to `[%w.%-]` and cut to 20 characters, or `dev`. `origin` = `ns.Profile:Origin(char)` or 0.
- **Receiving `HI`** (validated by Comm): `peers[guid]` is created or updated through `Safe.Clean`, then `PEER_SEEN(guid, peer, isNew)`. A `peer { p, a }` entry is written when `seenBy[current]` is unset, or differs from the archetype and this character's last `peer` entry for the peer (`logged[current]`) is at least 24 h old; then `seenBy[current]` and `logged[current]` are set. A change held back leaves `seenBy[current]` alone, so the first `HI` after the window that still carries another archetype writes the entry; `peer.archetype` is always the latest. A record from before `logged` existed logs its first change. **`PR`** updates the profile of an existing peer only.
- `PresentPeers()`: peers whose GUID is in `ns.Identity:Group("party")`.
- Nothing is displayed to the other player; the dungeon stays pure MMO. Archetypes appear in Encounters' tooltip line and in the `group.end` sentence.
- `Modules/Traces/Traces.lua` (Fiction) holds only the v2 format comment (4.5).

### 7.10 Test mode and probe (Dev)

```lua
ns.Test:Register(id, fn)   -- Core/Init.lua; fn() -> ok (true, false, or nil = skipped), detail (string)
ns.Test:Tooltip()          -- Core/Init.lua; AshmarkTestTooltip, created on first call with
                           -- CreateFrame("GameTooltip", "AshmarkTestTooltip", UIParent, "GameTooltipTemplate"),
                           -- returned cleared and owned (ClearLines, SetOwner(UIParent, "ANCHOR_NONE"))
```

Every unit registers its own checks in `OnInitialize`, in its own files; `Dev/TestMode.lua` runs them and holds Core's own checks. A check that raises or returns a secret is stored as a failure; the error counts against the test mode, never against a module.

`/ashmark test`:
1. In combat (`InCombatLockdown()`): print `TEST_NOT_IN_COMBAT` and stop.
2. Run every registered check synchronously, each through the error wrapper.
3. Store `AshmarkDB.dev.tests[#+1] = { t, version, build, locale, project, tocVariant, db = { created, fresh, readOnly, recovered, entries, seq }, comm = <copy of ns.Comm.stats>, results = { { id, ok, detail }, ... }, questDialog, screenshot, blocked }` (the last three from steps 5 and 6). `recovered` is only `type(AshmarkDB.recovered)` or nil, never the value, which can be a whole old DB. In read-only mode nothing is stored (4.4), and the test and the probe print `TestMode:NotStoredText()`: `TEST_NOT_STORED_MIGRATION` after a failed update, else `TEST_NOT_STORED`.
4. Print a summary (`TEST_SUMMARY`).
5. Show `AshmarkFrame` on the Chronicle tab. If `QuestFrame:IsShown()`, anchor `AshmarkFrame` to the right of it; otherwise print `TEST_OPEN_QUEST_DIALOG` ("Talk to a quest giver first for the screenshot."). Ashmark never opens the quest log or the world map.
6. Call `Screenshot()` directly in the slash handler (the key press is the hardware event). `SCREENSHOT_SUCCEEDED`, `SCREENSHOT_FAILED`, and `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` with arg1 == `ADDON` within the next 10 s are added to the same test record.
7. Print `TEST_RELOAD` ("Type /reload to save the results."). Addon code cannot reload the UI without a hardware event, so Ashmark never calls `C_UI.Reload` or `ReloadUI`. If `ns.DB.fresh` is set, the test mode prints `CORE_SV_NEW` (4.4) in place of `TEST_RELOAD`: a reload is a save that moves the files (4.4), and after it `fresh` is false, so no second warning would come.

Core checks:
- Forever detection, TOC variant, build; every `Compat.Has` value; each module's `enabled`, `unavailable` and `missingEvents`.
- Templates: `ButtonFrameTemplate`, `PanelTabButtonTemplate`, `WowScrollBoxList`, `MinimalScrollBar`, `UIPanelButtonTemplate`, `InputBoxTemplate`, `DialogBorderTemplate`, `TooltipBackdropTemplate` (Map checks `AshmarkMapPinTemplate` in its own `Map.template`). `info = C_XMLUtil.GetTemplateInfo(name)`: missing fails; otherwise `pcall(CreateFrame, info.type, nil, UIParent, name)`, then hide it; the detail reports the type.
- Parchment atlases (`C_Texture.GetAtlasInfo`), font objects, every `SOUNDKIT` constant used.
- Locale completeness: `ns.Locale:Missing(GetLocale())`.
- `Identity:Player()` fields and `surnameSource`.
- SavedVariables: `created`, `fresh`, `readOnly`, `recovered`, entry count, `seq`, and whether a test record from an earlier session exists (round trip; skipped until one does).
- Secret handling: if `secretwrap` exists, wrap a string and a table; every Safe function returns its not-ok form without error; `Log:Add` drops an entry with a wrapped field (of a kind registered with `quiet = true`, so the deliberate drop is counted, then undone, and not reported); the Comm decoder drops a wrapped text. Also record the `addon*RestrictionsForced` CVars.
- Comm (`Core.comm`): `canSend`, `addonMessages`, `Comm.share` and every `stats` counter (`sent`, `rejected`, `dropped`, `limited`), the queue length and the result codes; `dev.blocked` since the last run. The test record's `comm` copies every counter, `limited` included.

Unit checks:
- Conflicts: every quest ID yields a title, every faction ID a name, and every zone and `anchor.m` a `C_Map.GetMapInfo` name (uncached → "pending, run again"), so `verified = false` entries can be checked in the client. The detail reads `"<n> conflicts, <n> quests, <n> factions, <n> maps, verified <n>/<n>"`, then `; maps: <id> <client name>, ...` so the tester can compare the names, and `; no map info: <ids>` for any map the client does not know; a missing or secret map info fails the check.
- Profile: the kill counters, `critterType`, and `PROFILE_TEST_MERCY_HOWTO` ("Kill 3 critters and 3 calm neutral beasts, then run /ashmark test again.").
- Map: atlases, pin template, provider added, conflicts with an anchor (`Map.anchors`: a count; skipped while none has one, which is true of the shipped data).
- Encounters, Knowledge: the tooltip handler on secret input (with `secretwrap`) changes nothing and raises nothing.
- Knowledge: lines hidden on a sample tooltip for a revealed item the character has not held, by the test of 7.7 step 3, so a sample in the bags that the scan has not noted yet is passed over (first match from a short list in `Knowledge.lua`). The check never displays a Blizzard tooltip: `tip = ns.Test:Tooltip()`, `tip:SetItemByID(id)`, then the post-call body (7.7, steps 2 to 8) runs on `(tip, C_TooltipInfo.GetItemByID(id))`; the check reads the blanked lines and hides `tip`.
- Campfire: each aura ID resolves through `C_Spell.GetSpellName`; current `present` state.
- Fiction, Rumours: peer, rumour and told counts.

`/ashmark probe` appends raw facts for the open platform questions to `AshmarkDB.dev.probes` with the context (zone, instance, in party, in raid, in combat). Every call's returns are captured in full (`select("#", ...)`) as strings: `"<secret>"`, `"<nil>"` or `tostring(v)`. It never registers the combat log.
- `GetBuildInfo()`, `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT`, `X-TocVariant`, `GetLocale()`.
- `UnitName("player")`, `UnitNameUnmodified("player")`, `UnitFullName("player")`, `GetRealmName()`, `GetNormalizedRealmName()`, `C_PlayerInfo.ShouldDisplaySurname()`, `UnitGUID("player")`.
- `C_Secrets.ShouldUnitIdentityBeSecret("party1")`, `C_Secrets.ShouldAurasBeSecret("player")` (ok and error of each call), `issecretvalue(UnitName("party1"))`, `C_ChatInfo.InChatMessagingLockdown()`, `C_RestrictedActions` state if present, `C_CombatLog.IsCombatLogRestricted()` if present, the secrecy of `C_Map.GetBestMapForUnit("player")`.
- `IsTrialAccount()`, `IsVeteranTrialAccount()`; `IsInGroup` and `GetNumGroupMembers` for `LE_PARTY_CATEGORY_HOME` and `LE_PARTY_CATEGORY_INSTANCE`, so a run inside a battleground shows the group category Identity reads (5.3).
- `Enum.GameRule` keys `HardcoreRuleset`, `RPRuleset`, `PvPRuleset`, `RPPvPRuleset` and `IsGameRuleActive` for each; `C_GameRules.GetForeverExperiencePreset()`.
- Camp auras present; faction data for 92, 93 and 2802; `C_MajorFactions.GetMajorFactionData(2802)`; `C_Map.GetMapInfo` (all returns) for every zone and `anchor.m` of `ns.Data.Conflicts`, each map once in data order (Shen'dralas, 2652, among them).
- `UnitCreatureType("target")` (all returns), `C_CreatureInfo.GetCreatureTypeInfo(8)`.
- For the next pull (registered for the session): the dispatch order of `UNIT_FLAGS` for `target`, `UNIT_FLAGS` for `player` and `PLAYER_REGEN_DISABLED`, each with `GetTime()` and `UnitAffectingCombat` of `player` and `target` at that moment (7.2).
- `Enum.BagIndex` keys and values; line types of `C_TooltipInfo.GetItemByID(6948)`.
- `C_EventUtils.IsEventValid` for every event named in this spec (the list lives in `Probe.lua`).
- The argument count and values of the next `QUEST_ACCEPTED` (registered for the session).
- When grouped (`ns.Identity:InGroup()`, the home group): one `HI` through `ns.Comm:Send`, its send result, and the raw sender string of its own echo in `CHAT_MSG_ADDON` (added to the probe record when it arrives); in a raid this shows whether `PARTY` works. The `HI` is Fiction's: while Shared fiction is not enabled the probe sends nothing and records `<Shared fiction off>` or `<Shared fiction unavailable: <reasons>>`; outside a group it records `<not grouped>`.

## 8. Tests

- `busted` from the repo root under **Lua 5.1**. `.busted`: `return { default = { ROOT = { "tests" }, pattern = "_spec", lua = "lua5.1", helper = "tests/helpers/wow.lua" } }`. CI installs Lua 5.1 (e.g. `leafo/gh-actions-lua` with `luaVersion: "5.1"`) and runs busted with it.
- `tests/helpers/wow.lua` (Core) provides the mock WoW environment:

```lua
wow.reset()                        -- fresh global mock and empty ns
wow.load({ "Modules/Conflicts" })  -- Core and Locale files in TOC order, then the named files or folders;
                                   -- skips missing files and .xml; returns ns
wow.stub(path, value)              -- "UnitReaction" or "C_Map.GetMapInfo"
wow.secret(v)                      -- newproxy userdata whose __index, __lt, __le, __concat, __len, __call
                                   -- and arithmetic raise; the mocked issecretvalue, canaccessvalue,
                                   -- issecrettable and canaccesstable recognise it
wow.fire(event, ...)               -- dispatch to registered frames
wow.advance(seconds)               -- runs due C_Timer.After / NewTicker callbacks in time order
wow.combat(on)                     -- InCombatLockdown and the REGEN events
```

  `CreateFrame` returns stub frames that accept any method call. The mock client defines `UNKNOWNOBJECT` ("Unknown") and `UKNOWNBEING`; a unit fixture with `loading = true` returns `UNKNOWNOBJECT` from the name APIs, as the client does until a unit's name arrives; unit tokens are read ignoring case, as the client reads them; `C_Item.GetItemCount(id)` counts the bag fixtures 0 to 5. `C_Timer.After` queues and never runs immediately. Lua 5.1 calls `__eq` only between two userdata, so the proxy cannot catch `secret == "x"`; specs assert that handlers return before comparing.
- A unit adds its own mocks in `tests/helpers/<unit>_mock.lua` and requires them from its specs. Units never edit `wow.lua`.
- Specs: `tests/core_<service>_spec.lua`, `tests/ui_*_spec.lua` and `tests/dev_*_spec.lua` (Core) and `tests/<unit>_spec.lua` per unit. The Dataset unit's generator has Python unittest specs in `tools/test_conflicts.py` (`python3 -B -m unittest discover -s tools -p "test_*.py"`).

| Spec | Covers |
| --- | --- |
| `core_log` | sequence numbers, `Add` checks (reserved keys, secrets), `Iter` ranges, compaction by size and by age (unshown entries before shown ones, `chapter` before `peer` before `contact`, a clock set ahead or back deletes nothing), stamps by `ns.Util.Now()` (a system clock 8 days behind closes no chapter at each login), `CloseChapter`, auto chapter |
| `core_db` | fresh, recovered, newer schema read-only (Core writes nothing: Identity, settings binding, `stats`, `state`, `dev.*`), migrations, a failed migration leaves the stored table untouched and reads `"migration"`, not `"schema"` |
| `core_comm` | field whitelist, size limit, schema validation, throttle, priorities, lockdown pause, GUID check against party units, self drop, sender map: `RU` accepted after a /reload from a sender learned before it (`state.senders`), cleared on `GROUP_CHANGED(false)`, relearned from the `HI` of a member who left and rejoined, cap; GUID binding to the sender (a sender named like a unit token takes no member's GUID), per-type receive budgets, the queue dropped when sharing or sending is lost and on leaving the group |
| `core_safe`, `core_events`, `core_errors` | secret proxy; shared and unit frames with refcounts, invalid events; once per source, disable after 10 |
| `core_version` | `ns.version` from the release tag, `dev` for a missing, empty or unreplaced `## Version` |
| `core_bus` | subscription order; a `Fire` inside a handler is queued and delivered FIFO after the current topic reached every subscriber |
| `core_lifecycle` | ready flag at the start of step 3, Core's zone, group, chapter and compaction writes after every `OnWorldReady` |
| `core_locale` | fallback, `Format`, `Gender`, `Missing` for every locale (`loadAll`), `_F` only on keys shown with a sex |
| `core_identity`, `core_where`, `core_names` | surname order and rejection, ruleset, the home group only (a battleground's instance group is no group and names no member, `Tokens`); nil map, nil position, secret map; placeholders and requests |
| `core_watch` | `QUEST_ACCEPTED` argument, abandon in both event orders, gold contexts, rep baseline and standing change, first zone visit, no zone entry for a nil zone, `GROUP_CHANGED` only on change and after login outside the stored group, `lastSeen` never written at login |
| `conflicts` | alliance by accept and turn-in, reputation trigger (`reaction`, both sides), one entry per zone and faction for a reputation pass, contradiction line, violation with `o` read before the write, `began` set by alliance and violation, `houseturn` once per group, no hint when siblings are split, faction 0, alliances by standing formed again for the new record after `/ashmark reset`, renamed ids followed in every record and in `Get`, a retired id renders nothing, an alliance by quest names its conflict's title, zone and anchor maps in the data check |
| `profile` | weights, decay, day rollover, archetype, origin, kill approximation incl. secret and tap-denied, `UNIT_FLAGS(target)` in combat before `PLAYER_REGEN_DISABLED` keeps `cand`, death seen on `UNIT_FLAGS`; a violating turn-in changes fidelity by exactly the violation weight, an alliance formed by the turn-in earns no +2; one kept-alliance award per standing, none for a retired conflict, `kept` follows renames |
| `map` | placement on zone and continent maps, combat deferral, right clicks passed to the canvas out of combat, pin tooltips, one pin for the chapters closed on one spot, the anchor count, no pin for a retired conflict's violation |
| `encounters` | session lifecycle on `GROUP_CHANGED` in and out of instances, outcome priority, `ENCOUNTER_END` with success 0, per-character contact merge, resume after reload, a stale session ended after a long offline gap stops at the previous `lastSeen`, no member taken from a battleground's raid and the session kept across a /reload there, no snapshot of a member the client still calls Unknown, `Known` |
| `house`, `house_tab` | key, override matching ignoring case (accented and Cyrillic capitals too), sibling alliances with split sides, family chronicle filter; one titled feud row per conflict, side and sibling |
| `campfire` | aura transitions, seed after reload, chapter thresholds by the realm's clock, `state.rest` cleared when `WELCOME` goes without `BENEFITS` and after 10 minutes |
| `knowledge` | silent first scan of bags and of the bank, keep set by type (matched by text, so another addon's lines cost the item's lines nothing) and by the client's strings, slot and positional specifiers, lines without text kept, secret bail-out, an item in the bags before the scan noted it counts as held |
| `rumours` | ids, decay with age, precision loss, caps, re-print limits, the per-sender limit on new ids, rumour entries only with a printed line, own rumours never pruned for received ones, one own rumour per template, archetype, faction and zone while it lives |
| `fiction` | greeting once per member, no loop, peer storage, `PR` before `HI`, a join inside the 30 s window greeted when it ends, leave and rejoin greeted again, `greeted` cleared on `GROUP_CHANGED(false)`, no re-greeting after a /reload, at most one archetype-change entry a day per peer |
| `integration_load` | both TOCs against section 2, every file loaded into one ns, lifecycle and /reload, no new globals, the integration flow (`tests/helpers/integration_flow.lua`: every module's main events with every tab open, each module off and on, the test mode) |
| `integration_locales` | the integration flow once under each of the ten locales with a female player, the test mode's locale check complete, every chronicle line of the flow rendered in both persons and for both sexes without a placeholder or key name left, the TOC `## Notes-<locale>` and `## Category-<locale>` lines |

- `luacheck .` must pass with `.luacheckrc` (Core): std `lua51`, a broad WoW `read_globals` list, Ashmark's globals (3.1) as `globals`. A unit that reads a WoW global missing from the list declares it at the top of its own file with `-- luacheck: read globals X, Y`. Units never edit `.luacheckrc`.
- CI (Packaging) runs busted, luacheck, `python3 tools/conflicts.py --check`, the generator's unittest specs and the TOC file-list comparison (`tools/toc_check.py --strict`) on every push and pull request.

## 9. Ownership for parallel work

Every file in the repository belongs to exactly one unit.

| Unit | Owns |
| --- | --- |
| Core | `Ashmark_Forever.toc`, `Ashmark_Camelot.toc`, `Core/*.lua`, `Locales/Locale.lua`, `Locales/enUS/Core.lua`, `Locales/enUS/Test.lua`, `UI/*.lua` (Widgets, MainFrame, Dialog, Notice, ChatLine, Compartment), `UI/Tabs/Chronicle.lua`, `Dev/*.lua`, `tests/helpers/wow.lua`, `tests/helpers/integration_flow.lua`, `tests/core_*_spec.lua`, `tests/ui_*_spec.lua`, `tests/dev_*_spec.lua`, `tests/integration_*_spec.lua`, `.busted`, `.luacheckrc` |
| Conflicts | `Modules/Conflicts/*`, `UI/Tabs/Decisions.lua`, `Locales/enUS/Conflicts.lua`, `tests/conflicts*_spec.lua`, `tests/helpers/conflicts_mock.lua` |
| Profile | `Modules/Profile/*`, `Locales/enUS/Profile.lua`, `tests/profile*_spec.lua`, `tests/helpers/profile_mock.lua` |
| Map | `Modules/Map/Map.lua`, `Modules/Map/MapPins.xml`, `Locales/enUS/Map.lua`, `tests/map*_spec.lua`, `tests/helpers/map_mock.lua` |
| Encounters | `Modules/Encounters/*`, `UI/Tabs/Encounters.lua`, `Locales/enUS/Encounters.lua`, `tests/encounters*_spec.lua`, `tests/helpers/encounters_mock.lua` |
| House | `Modules/House/*`, `UI/Tabs/House.lua`, `Locales/enUS/House.lua`, `tests/house*_spec.lua`, `tests/helpers/house_mock.lua` |
| Campfire | `Modules/Campfire/*`, `Locales/enUS/Campfire.lua`, `tests/campfire*_spec.lua`, `tests/helpers/campfire_mock.lua` |
| Knowledge | `Modules/Knowledge/*`, `Locales/enUS/Knowledge.lua`, `tests/knowledge*_spec.lua`, `tests/helpers/knowledge_mock.lua` |
| Rumours | `Modules/Rumours/*`, `Locales/enUS/Rumours.lua`, `tests/rumours*_spec.lua`, `tests/helpers/rumours_mock.lua` |
| Fiction | `Modules/Fiction/*`, `Modules/Traces/Traces.lua`, `Locales/enUS/Fiction.lua`, `tests/fiction*_spec.lua`, `tests/helpers/fiction_mock.lua` |
| Dataset | `data/conflicts/*` (the CSV files, `registry.csv`, `renamed.csv` and `README.md`), `tools/conflicts.py`, `tools/test_conflicts.py`, `Data/Conflicts.lua` |
| Localization | `Locales/deDE.lua`, `frFR.lua`, `esES.lua`, `esMX.lua`, `ptBR.lua`, `ruRU.lua`, `koKR.lua`, `zhTW.lua`, `zhCN.lua`; delivers the TOC `## Notes-<locale>` texts in its report, Core inserts them |
| Packaging | `.pkgmeta`, `.github/workflows/*`, `tools/toc_check.py` |
| Docs | `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `docs/index.html`, `.github/ISSUE_TEMPLATE/*`, `.github/FUNDING.yml` |
| Lead | `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/research/*`, `LICENSE`, `.claude/*` |

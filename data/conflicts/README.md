# Conflict data

Source files for Module 1. `tools/conflicts.py` validates them and generates `Data/Conflicts.lua`, which ships with the addon. Never edit the generated file.

## Format

One CSV file per area, UTF-8, one row per quest. The conflict columns repeat on every row of a conflict and must agree. `registry.csv` and `renamed.csv` are not area files (see below).

| Column | Meaning |
| --- | --- |
| `conflict_id` | snake_case, unique across all files |
| `zone` | uiMapID of the zone the conflict belongs to |
| `theme` | `feud`, `law`, `trade`, `nature`, `faith` or `other` |
| `honored` | reputation reaction (5 Friendly, 6 Honored, 7 Revered, 8 Exalted) at which standing alone forms the alliance; empty when no side has a faction |
| `anchor_m`, `anchor_x`, `anchor_y` | optional map pin: uiMapID and coordinates 0–1; all three or none |
| `side` | `A` or `B` |
| `faction` | reputation faction ID of the side, empty for a side without one |
| `quest` | quest ID; a quest belongs to at most one conflict |
| `quest_name` | English name, for review only; the addon reads the localized name from the client |
| `verified` | `true` only after the quest was checked in the Forever client |
| `source` | the page the quest was taken from |

## Ids and sides are permanent

A character's alliances are stored under the `conflict_id`, as the letter `A` or `B` of the side. Once an id has been generated, renaming it, removing it or swapping its sides would silently change what players have already decided. So:

- `registry.csv` lists every id the generator has written, with the faction and the quests of each side. The generator adds new ids and new quests; it never changes a row. Edit it by hand only to record a deliberate change to a written side, and say why in the commit.
- The generator refuses data in which a registered id is missing, a registered side has another faction, or a registered quest has moved to the other side of its conflict.
- `renamed.csv` (`old_id,new_id,reason`) is the only way to rename or retire an id. With `new_id` set, the old id ships in `Data/Conflicts.lua` as `renamed = { ["old_id"] = "new_id" }` so stored alliances can follow it; the new id must keep the old id's sides, and two ids cannot become one: neither two old ids renamed to one new id, nor an old id renamed to an id already generated under its own name. A new id enters `registry.csv` with every quest the old id was generated with. With `new_id` empty the id is retired. A renamed or retired id can never be used again.

## Contributing

1. Add or change rows. A good conflict is one where the quest texts themselves set one side against the other.
2. Run `python3 tools/conflicts.py`. It refuses inconsistent rows, writes `Data/Conflicts.lua` and adds new ids and quests to `registry.csv`.
3. Commit the CSVs, `registry.csv` and `Data/Conflicts.lua` together. CI runs `python3 tools/conflicts.py --check` and fails if the generated file or the registry is stale.

The generator's own tests: `python3 -B -m unittest discover -s tools -p "test_*.py"`.

Most wanted: conflicts below level 30 outside Zephras Isle (see Coverage).

## Provenance

The pilot set was researched on 2026-10-30 and 2026-10-31 from Wowhead's Forever database and re-checked quest by quest by a second pass. Every row is `verified = false` until it is tested in the client. The pilot holds 10 conflicts: three Gelkis–Magram decision points in Desolace, three in Shen'dralas, two Booty Bay–Bloodsail conflicts in Stranglethorn Vale and two Windshapers–High Order conflicts on Zephras Isle. The classic starter zones yielded no quest pairs whose texts oppose each other, so none are included.

Coverage by level: Zephras Isle is the Skyborne starting zone (levels 1–12); its two conflicts reach only Skyborne characters, and perhaps only one player faction of them (open points). For every other character the first conflict quests are Desolace's centaur quests around level 30 (Gelkis Alliance, 1368, is level 33; the Valley of Bones quests need level 35); Shen'dralas follows the Valley of Bones, and Stranglethorn Vale is a mid-level zone. Before that, Module 1 and everything fed by it (fidelity from kept alliances, house feuds, rumours) have nothing to record. `docs/DECISIONS.md` still plans about 20 conflicts including a few starter zones; the pilot is this smaller set.

Open points, to settle in the client:

- Zone IDs for Stranglethorn Vale (1434) and Zephras Isle (2521) come from the Classic and Forever uiMap tables, not from quest pages.
- The Zephras Isle factions may each be tied to one player faction (Skyborne Horde shamans, Alliance mages); then no single character can reach both sides and the conflict never triggers.
- Quest-giver coordinates are missing (Wowhead's Forever pages did not show them), so no conflict has a map anchor yet.
- Whether each quest is open to both factions.

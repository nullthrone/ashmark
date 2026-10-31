# Conflict data

Source files for Module 1. `tools/conflicts.py` validates them and generates `Data/Conflicts.lua`, which ships with the addon. Never edit the generated file.

## Format

One CSV file per area, UTF-8, one row per quest. The conflict columns repeat on every row of a conflict and must agree.

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

## Contributing

1. Add or change rows. A good conflict is one where the quest texts themselves set one side against the other.
2. Run `python3 tools/conflicts.py`. It refuses inconsistent rows and writes `Data/Conflicts.lua`.
3. Commit both. CI runs `python3 tools/conflicts.py --check` and fails if the generated file is stale.

## Provenance

The pilot set was researched on 2026-10-30 and 2026-10-31 from Wowhead's Forever database and re-checked quest by quest by a second pass. Every row is `verified = false` until it is tested in the client. Not yet covered: quest-giver coordinates (Wowhead's Forever pages did not show them), and whether each quest is open to both factions.

# Ashmark

Decisions leave a mark. Solo role-play for World of Warcraft Forever.

Ashmark keeps a chronicle of one character's decisions and lets them have consequences. Some quests set one side against another: Ashmark remembers the side you take, marks quests that contradict it under the quest dialog and records it when you break your word. What you do shapes an archetype, alts on your account who share a surname form a house with one family history, and party members who also run Ashmark learn your archetype and origin through addon messages, with nothing shown in chat.

Ashmark runs on World of Warcraft Forever only. Retail and Classic Era are not supported. It never reads the combat log, automates nothing, never uses StaticPopup and ships no libraries.

The full guide is [docs/index.html](docs/index.html).

## Status

Pre-release. Ashmark has run only against the mock client of its test suite. Forever launches on 4 November 2026 at 23:00 UTC; until the test mode has run in the live client, the platform facts in [docs/research/forever-platform.md](docs/research/forever-platform.md) and every conflict in the dataset are unverified. `## Interface: 16001` is the beta and test value.

## Modules

| Module | Where you meet it |
| --- | --- |
| Chronicle (core) | Chronicle tab: chapters and the sentences of each |
| Conflicts | a line under the quest dialog; Decisions tab |
| Profile | House tab: three axes (fidelity, habitat, mercy) and the archetype |
| World map | world-map pins for broken words and closed chapters; conflict pins come once the conflict data has map positions |
| Encounters | a unit tooltip line, the Encounters tab, chat lines when people you know join your group |
| House | House tab; a hint under the quest dialog |
| Campfire | a centre-screen notice when a rest at a camp closes a chapter |
| Character knowledge | item tooltips hide what this character has never held |
| Rumours | chat lines about what other Ashmark users did in a conflict; needs Shared fiction |
| Shared fiction | no surface of its own; feeds the tooltip line and the chronicle with other Ashmark users' archetype and origin |

The pilot holds 10 conflicts. Outside Zephras Isle, the Skyborne starting zone, the first of them begin around level 30 in Desolace, so Conflicts and what it feeds (kept alliances, house feuds, rumours) have nothing to record before that.

Mercy is an approximation: without the combat log, a kill counts when you target a calm neutral creature out of combat, combat starts with it as your target, and it dies with no one else having tapped it. The test mode measures its accuracy at launch. Traces and a companion app are planned for v2; v1 only reserves their store.

## Install

- CurseForge: not published yet.
- From a release: extract the zip of a tagged [release](https://github.com/nullthrone/ashmark/releases) into `World of Warcraft\_forever_\Interface\AddOns\`, so that `Interface\AddOns\Ashmark\Ashmark_Forever.toc` exists, and restart the game. No release is tagged yet.
- From the source: until then, download the repository as a zip, extract it into the same `AddOns` folder and rename the extracted folder to `Ashmark`.

Open the window with `/ashmark`, `/amk` or the Addon Compartment (left click: window, right click: settings). The settings are under Options, AddOns, Ashmark: one switch per module, plus Lines in chat, Sounds, Share with other Ashmark users and Quest rewards in full. All start on.

## Commands

| Command | Effect |
| --- | --- |
| `/ashmark`, `/amk` | open or close the main window |
| `/ashmark help` | list the commands |
| `/ashmark house` | show the house this character belongs to |
| `/ashmark house <name>` | join the house of that name |
| `/ashmark house reset` | follow your surname again |
| `/ashmark test` | run the self-test, show the chronicle next to the quest dialog, take a screenshot |
| `/ashmark probe` | record raw client facts for the developers |
| `/ashmark debug` | turn debug mode on or off for the session; in it a malformed log entry raises a Lua error |
| `/ashmark reset` | after a confirmation, wipe this character's record, its meetings and its sightings of Ashmark users |
| `/ashmark reset <name>` | after a confirmation, forget another character of this account that you deleted or moved; several with that name are listed with their GUIDs, and `/ashmark reset <GUID>` picks one |
| `/ashmark reset others` | after a confirmation, wipe contacts, peers and heard rumours on the account |

## Languages

enUS (also enGB), deDE, frFR, esES, esMX, ptBR, ruRU, koKR, zhTW and zhCN: the ten locales the Forever client offers. Only Ashmark's own sentences are translated; faction, zone, quest, item, class and race names come from the client.

## Privacy

- Ashmark sends addon messages with the prefix `Ashmark` on the `PARTY` channel only (in a raid, `PARTY` should reach only your subgroup; the probe checks this at launch): `HI` (your GUID, archetype, origin zone ID, ruleset, addon version), `PR` (your GUID and three axis values) and `RU` (a rumour: random id, template, hops, strength, age, archetype, faction ID, map ID). Names, contacts, notes and free text are never sent.
- It only receives when "Share with other Ashmark users" is off, on Forever trial and veteran accounts, which cannot send addon messages, and for the rest of a session in which three sends in a row fail.
- Everything is stored in one account-wide SavedVariable, `AshmarkDB` (`_forever_\WTF\Account\<ACCOUNT>\SavedVariables\Ashmark.lua`), with characters keyed by GUID.
- `/ashmark reset` wipes this character's record and its share of contacts and peers (a contact no other character met and without a note goes); `/ashmark reset <name>` does the same for another character of the account. `/ashmark reset others` wipes contacts, peers and rumours this account did not start.
- A rumour carries no name, but the game names the sender of every addon message, so party members who hear your own rumour first know it is yours.

## Testing at launch

1. Talk to a quest giver, stay out of combat and type `/ashmark test`, then `/reload` to save the results. Run `/ashmark test` again after the reload to prove the SavedVariables round trip.
2. Type `/ashmark probe` in the open world, in a party, inside a dungeon, in a raid and at a camp, with a `/reload` after each; accept a quest and start a fight in the same session.
3. Open an issue with `Ashmark.lua` from the SavedVariables folder (results are in `AshmarkDB.dev`), the screenshots, the client language and any Lua error text. The file also holds your characters, contacts and notes; send only the `dev` table if you prefer.

The guide lists every fact only the live client can settle.

## Contributing conflict data

Conflicts live in `data/conflicts/*.csv`, one row per quest; the format is in [data/conflicts/README.md](data/conflicts/README.md). Every row carries `verified=false` until the quest was checked in the Forever client, and a `source` URL. Conflicts below level 30 outside Zephras Isle are the most wanted. After editing, run:

```
python3 tools/conflicts.py           # validate, write Data/Conflicts.lua, register new ids in registry.csv
python3 tools/conflicts.py --check   # validate; fail if Data/Conflicts.lua or registry.csv is stale
```

Commit the CSVs, `data/conflicts/registry.csv` and the generated `Data/Conflicts.lua` together. Conflict ids and sides are permanent once generated, because players' alliances are stored under them: rename or retire an id only with a row in `data/conflicts/renamed.csv`.

## Development

Lua 5.1, no libraries. The contract every unit builds against is [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); the decisions behind it are in [docs/DECISIONS.md](docs/DECISIONS.md). Every file belongs to exactly one unit (section 9 of the architecture).

```
luacheck .
busted
python3 tools/conflicts.py --check
python3 -B -m unittest discover -s tools -p "test_*.py"
python3 tools/toc_check.py --strict
```

CI runs all five on every push and every pull request.

## Release

Push a tag that starts with `v`. The release workflow runs the BigWigs packager, which builds the zip from `.pkgmeta` and creates a GitHub release. Uploading to CurseForge needs the `CF_API_KEY` repository secret and a `## X-Curse-Project-ID` line in both TOCs; Wago is optional and uses `WAGO_API_TOKEN`.

## License

MIT, see [LICENSE](LICENSE). Ashmark started under the working name Embertale.

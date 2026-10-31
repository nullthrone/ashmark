<p align="center"><img src="docs/assets/ashmark-logo.png" width="160" alt="Ashmark logo: a burnt-out campfire seen from above, with one ember at its centre"></p>

# 🔥 Ashmark

**Decisions leave a mark.** Solo role-play for World of Warcraft Forever.

[![CI](https://github.com/nullthrone/ashmark/actions/workflows/ci.yml/badge.svg)](https://github.com/nullthrone/ashmark/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![WoW Forever](https://img.shields.io/badge/WoW-Forever-8f6b26)
![Languages](https://img.shields.io/badge/languages-10-2f6b4f)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support%20Ashmark-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/tsprock)

Your character remembers. Side with the Gelkis in Desolace, and the Magram quests of that conflict carry a warning under the quest dialog. Turn one in anyway and the chronicle records that you broke your word. Everything you do shapes an archetype, your alts form a house with one family history, and other Ashmark players in your party learn your archetype and origin without a single line in chat.

📖 The full guide is [docs/index.html](docs/index.html).

## 🚦 Status

**Pre-release.** Ashmark has run only against the mock client of its test suite. Forever launches on **4 November 2026 at 23:00 UTC**; until the test mode has run in the live client, the platform facts in [docs/research/forever-platform.md](docs/research/forever-platform.md) and every conflict in the dataset are unverified. `## Interface: 16001` is the beta and test value.

## ✨ Features

| | Module | Where you meet it |
| --- | --- | --- |
| 📜 | **Chronicle** | Chronicle tab: your story in chapters, told in sentences in your client's language |
| ⚔️ | **Conflicts** | a line under the quest dialog when a quest contradicts your side; the Decisions tab |
| 🎭 | **Profile** | House tab: three axes (fidelity, habitat, mercy) and the archetype they make you |
| 🗺️ | **World map** | pins where you broke your word and where your chapters closed; conflict pins come once the conflict data has map positions |
| 🤝 | **Encounters** | a tooltip line on people you have met, the Encounters tab, a chat line when someone you know joins your group |
| 🏰 | **House** | House tab for the alts who share your surname; a hint under the quest dialog when your house stands against a faction |
| 🏕️ | **Campfire** | a centre-screen notice when a rest at a camp closes a chapter |
| 🔍 | **Character knowledge** | item tooltips hide what this character has never held |
| 🗣️ | **Rumours** | chat lines about what other Ashmark players did in a conflict; needs Shared fiction |
| 👥 | **Shared fiction** | no surface of its own; feeds the tooltip line and the chronicle with other Ashmark players' archetype and origin |

The pilot holds **10 conflicts**. Outside Zephras Isle, the Skyborne starting zone, the first of them begin around level 30 in Desolace, so Conflicts and what it feeds (kept alliances, house feuds, rumours) have nothing to record before that.

Mercy is an approximation: without the combat log, a kill counts when you target a calm neutral creature out of combat, combat starts with it as your target, and it dies with no one else having tapped it. The test mode measures its accuracy at launch. Traces and a companion app are planned for v2; v1 only reserves their store.

### 🚫 What Ashmark never does

- 🛑 read the combat log: Forever closes it to addons
- 🤖 automate anything: it never accepts, blocks or abandons a quest
- 🧩 use StaticPopup or ship libraries: Blizzard APIs only
- 🌐 run outside WoW Forever: Retail and Classic Era are not supported

## 📦 Install

- **CurseForge**: the project exists (ID 1777037); the first release goes up at launch.
- **From a release**: extract the zip of a tagged [release](https://github.com/nullthrone/ashmark/releases) into `World of Warcraft\_forever_\Interface\AddOns\`, so that `Interface\AddOns\Ashmark\Ashmark_Forever.toc` exists, and restart the game. No release is tagged yet.
- **From the source**: until then, download the repository as a zip, extract it into the same `AddOns` folder and rename the extracted folder to `Ashmark`.

Open the window with `/ashmark`, `/amk` or the Addon Compartment at the minimap (left click: window, right click: settings). The settings are under Options, AddOns, Ashmark: one switch per module, plus Lines in chat, Sounds, Share with other Ashmark users and Quest rewards in full. All start on.

## ⌨️ Commands

| Command | Effect |
| --- | --- |
| `/ashmark`, `/amk` | open or close the main window |
| `/ashmark help` | list the commands |
| `/ashmark version` | show the installed version; the window title and the minimap menu tooltip show it too |
| `/ashmark house` | show the house this character belongs to |
| `/ashmark house <name>` | join the house of that name |
| `/ashmark house reset` | follow your surname again |
| `/ashmark test` | run the self-test, show the chronicle next to the quest dialog, take a screenshot |
| `/ashmark probe` | record raw client facts for the developers |
| `/ashmark debug` | turn debug mode on or off for the session; in it a malformed log entry raises a Lua error |
| `/ashmark reset` | after a confirmation, wipe this character's record, its meetings and its sightings of Ashmark players |
| `/ashmark reset <name>` | after a confirmation, forget another character of this account that you deleted or moved; several with that name are listed with their GUIDs, and `/ashmark reset <GUID>` picks one |
| `/ashmark reset others` | after a confirmation, wipe contacts, peers and heard rumours on the account, and what every character's record keeps of other players |

## 🌍 Languages

🇺🇸 enUS (also enGB) · 🇩🇪 deDE · 🇫🇷 frFR · 🇪🇸 esES · 🇲🇽 esMX · 🇧🇷 ptBR · 🇷🇺 ruRU · 🇰🇷 koKR · 🇹🇼 zhTW · 🇨🇳 zhCN

The ten locales the Forever client offers. Only Ashmark's own sentences are translated; faction, zone, quest, item, class and race names come from the client.

## 🔒 Privacy

- Ashmark sends addon messages with the prefix `Ashmark` on the `PARTY` channel only (in a raid, `PARTY` should reach only your subgroup; the probe checks this at launch): `HI` (your GUID, archetype, origin zone ID, ruleset, addon version), `PR` (your GUID and three axis values) and `RU` (a rumour: random id, template, hops, strength, age, archetype, faction ID, map ID). Names, contacts, notes and free text are never sent.
- It only receives when "Share with other Ashmark users" is off, on Forever trial and veteran accounts, which cannot send addon messages, and for the rest of a session in which three sends in a row fail.
- Everything is stored in one account-wide SavedVariable, `AshmarkDB` (`_forever_\WTF\Account\<ACCOUNT>\SavedVariables\Ashmark.lua`), with characters keyed by GUID.
- `/ashmark reset` wipes this character's record and its share of contacts and peers (a contact no other character met and without a note goes); `/ashmark reset <name>` does the same for another character of the account. `/ashmark reset others` wipes contacts, peers and rumours this account did not start, whom your own rumours were told to, and in every character's record the first meetings and sightings in the log, the stored group sessions with their members, and the party's Ashmark senders of other characters.
- A rumour carries no name, but the game names the sender of every addon message, so party members who hear your own rumour first know it is yours. A copy keeps its id, content and age from hop to hop, and its hop count and vagueness show how far it is from the deed: anyone who knows whose deed a rumour is can tell from your copy whether you grouped with that player in the past week, or how many groups lie between you.

## 🧪 Help us at launch

1. Talk to a quest giver, stay out of combat and type `/ashmark test`, then `/reload` to save the results. Run `/ashmark test` again after the reload to prove the SavedVariables round trip.
2. Type `/ashmark probe` in the open world, in a party, inside a dungeon, in a raid and at a camp, with a `/reload` after each; accept a quest and start a fight in the same session.
3. [Open an issue](https://github.com/nullthrone/ashmark/issues) with `Ashmark.lua` from the SavedVariables folder (results are in `AshmarkDB.dev`), the screenshots, the client language and any Lua error text. The file also holds your characters, contacts and notes; send only the `dev` table if you prefer.

The guide lists every fact only the live client can settle.

## 🛠️ Contributing

Bug reports, conflict data, translations and code are all welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md); everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

The most wanted contribution: ⚔️ **conflicts below level 30 outside Zephras Isle**. The format is in [data/conflicts/README.md](data/conflicts/README.md).

Lua 5.1, no libraries. The contract every unit builds against is [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); the decisions behind it are in [docs/DECISIONS.md](docs/DECISIONS.md). CI runs these on every push and every pull request:

```
luacheck .
busted
python3 tools/conflicts.py --check
python3 -B -m unittest discover -s tools -p "test_*.py"
python3 tools/toc_check.py --strict
```

## 🚀 Release

Add the release notes to the top of [CHANGELOG.md](CHANGELOG.md), then push a tag that starts with `v`. The release workflow runs the BigWigs packager, which builds the zip from `.pkgmeta` and creates a GitHub release with those notes. Uploading to CurseForge needs the `CF_API_KEY` repository secret; both TOCs carry the project ID (`## X-Curse-Project-ID: 1777037`); Wago is optional and uses `WAGO_API_TOKEN`.

## ☕ Support

Ashmark is free and open source. If it gives your character a story worth keeping, you can buy the author a coffee on [Ko-fi](https://ko-fi.com/tsprock).

## 📄 License

MIT, see [LICENSE](LICENSE).

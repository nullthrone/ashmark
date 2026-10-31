# Changelog

## v0.1.0 · first pre-release

**Decisions leave a mark.** The first public build of Ashmark, a solo role-play addon for World of Warcraft Forever, ready for the Forever launch on 4 November 2026.

> ⚠️ **Pre-release.** Ashmark has run only against the mock client of its test suite. This is its first run in the live client, so expect rough edges. The test steps below help us fix them fast.

### ✨ What's in it

- 📜 **Chronicle**: your character's story in chapters, told in sentences in your client's language. A camp rest closes a chapter.
- ⚔️ **Conflicts**: quests that set two sides against each other. Ashmark remembers the side you take and warns under the quest dialog when a quest contradicts it. Turning one in anyway records a broken word. Includes the Decisions tab.
- 🎭 **Profile**: three axes (fidelity, habitat, mercy) read from what you do, and the archetype they make you.
- 🗺️ **World map**: pins where you broke your word and where your chapters closed.
- 🤝 **Encounters**: the people you grouped with, with times met, last place, how it went and your own notes. Includes a tooltip line and a chat line when people you know join your group.
- 🏰 **House**: alts who share a surname form a house with one family history, inherited feuds and family memory.
- 🏕️ **Campfire**: a rest at a camp, once Camp Benefits takes hold, closes the open chapter when it holds 20 entries or began 30 minutes ago.
- 🔍 **Character knowledge**: item tooltips hide what this character has never held.
- 🗣️ **Rumours** and 👥 **Shared fiction**: other Ashmark players in your party learn your archetype and origin. Rumours of your choices travel from party to party, with nothing shown in chat.
- 🌍 **Ten languages**: enUS/enGB, deDE, frFR, esES, esMX, ptBR, ruRU, koKR, zhTW, zhCN.

Open the window with `/ashmark`, `/amk` or the Addon Compartment at the minimap. `/ashmark help` lists every command, and `/ashmark version` shows the installed version.

### 🚧 Known limits

- **Conflicts**: the pilot holds 10 conflicts, all marked unverified until checked in the client. Outside Zephras Isle, the Skyborne starting zone, the first ones begin around level 30 in Desolace. They have no map pins yet, because the quest givers' coordinates are still missing.
- **Mercy** is an approximation, because Forever closes the combat log to addons. The test mode measures how well it works.
- **Bedroll rests** are not counted yet: the sleeping bag's aura ID is unknown.
- **Interface 16001** is the beta and test value. If the AddOns list marks Ashmark as out of date at launch, please tell us; the next release follows the live value.
- **Traces** in the world and a companion app are planned for v2.

### 🔒 Privacy

Ashmark talks only on the `PARTY` addon channel and never sends names, notes or chat text. Everything is stored in one account-wide SavedVariable. The README lists exactly what is sent and how to wipe it.

### 🧪 Help us at launch

1. Talk to a quest giver, stay out of combat and type `/ashmark test`, then `/reload`, then `/ashmark test` again.
2. Type `/ashmark probe` in the open world, in a party, inside a dungeon, in a raid and at a camp, with a `/reload` after each.
3. Send the results with the **Launch test results** issue form: <https://github.com/nullthrone/ashmark/issues/new/choose>

Bugs, conflict ideas and translation fixes have their own forms there too. Thank you for playing and testing! ☕ <https://ko-fi.com/tsprock>

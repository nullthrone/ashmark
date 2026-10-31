# WoW Forever: platform research

Research for Ashmark v1, run on 2026-10-30, five days before the Forever launch (2026-11-04, 23:00 UTC). Four researchers covered platform, addon API, game systems and ecosystem; an adversarial verifier re-checked contested and load-bearing claims; a completeness critic listed what is still unknown. Nothing here was tested in the client. Every value marked unverified must be checked with the in-game test mode at launch.

## What this means for Ashmark

| Topic | Finding | Consequence for the build |
| --- | --- | --- |
| Client | Forever is its own Battle.net product (`wowf`, version 1.60.1, install folder `_forever_`), built from the Retail/Mainline code branch. It is not the Midnight client, but it shares Midnight's UI code and almost all of its API. | Write against the Mainline `C_*` API. No Classic Era globals (`GetFactionInfo`, `GetQuestLogTitle`, global `GetSpellInfo`). |
| TOC | Game type `forever` (alias `camelot`), suffix `_Forever.toc` / `_Camelot.toc`, Interface `16001` on beta and test. The live interface number is unpublished. | Ship a Forever TOC with `16001`; confirm at launch with `/dump select(4, GetBuildInfo())`. |
| Runtime detection | `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18) per warcraft.wiki.gg; Questie instead checks an interface range 16000–16999. | Guard with both; refuse to run outside Forever. |
| Restrictions | Midnight's addon restrictions, including secret values, are active (developer Discord post via warcraft.wiki.gg). The combat log is closed to addons. Chat sender names and texts can be secret in dungeons and raids. | No combat-log input for the profile. Every unit-name read goes through `issecretvalue` / `canaccessvalue`. Snapshot party rosters in the open world. |
| Addon messages | `C_ChatInfo.SendAddonMessage`: prefix ≤ 16, message ≤ 255, 10 messages per prefix, regenerating 1 per second. Trial and veteran accounts cannot send. Whether `CHANNEL` works on Forever is unknown. | Own throttle under Blizzard's limit; receive-only mode for accounts that cannot send; v1 sends over PARTY only (ARCHITECTURE 5.6), so rumours travel from group to group. |
| Groups | No retail Dungeon Finder. Forever has a Classic-style Group Finder listing board; groups form by whisper and invite. | Module 4 records party and raid rosters from any source, not from a queue. |
| Names | Characters have a first name and a surname. Only the full name is unique per region; unrelated players can share a surname. Shipped Forever addons read the surname as the second return of `UnitName` (unverified). | House = alts of this account that share a surname, discovered from account-wide SavedVariables. Primary key is the player GUID; names are display only. |
| SavedVariables | Per-character folder layout under `WTF` is unknown (first names are not unique). A beta bug that dropped SavedVariables was fixed in build 70009. | Account-wide SavedVariables only, keyed by GUID. Never overwrite stored data with defaults when a load returns nil. |
| Camping | No camping event or API. Camps are detectable through player auras: Campfire Nearby `1283391`, Welcoming Campfire `1289723`, Camp Benefits `1229741`, Boosted Rest `1229451`. The Cozy Sleeping Bag grants Well-Rested. | Module 6 detects a rest by aura transition (Welcoming Campfire, then Camp Benefits) out of combat. |
| Reputation | `C_Reputation.GetFactionDataByID`. Gelkis `92`, Magram `93`. Forever continues their storyline (Valley of Bones, quest `93034`, min level 35). Wowhead Forever shows Gelkis Alliance (`1368`) without the Classic Magram penalty. | The pilot conflict makes the exclusivity Blizzard may have relaxed a matter of the character's word. Addons cannot block quest acceptance, so Module 1 marks and records. |
| Quests | Classic quest IDs carry over (content can differ), SoD quests are reused, 1,000+ new Forever quests use IDs around 92xxx–96xxx. Quest API is `C_QuestLog`; `QUEST_DETAIL`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_REMOVED` exist. | Dataset entries carry quest IDs plus `verified = false` until checked in the client. |
| Zones | Shen'dralas is a new zone (uiMap `2652`, parent Kalimdor `1414`), reached from Desolace (`1443`) through the Valley of Bones. Shen'dralar is a separate faction (Dire Maul elves). | Pilot area: Desolace and Shen'dralas. |
| Hidden items | All items are obfuscated until they drop for someone in the region; about 4,900 of 12,700 tracked hidden items were revealed by 2026-10-30. No discovery event exists. | Module 7 models three states: hidden by the server, revealed but never held by this character, held. Feature-detected; disabled where tooltip data is secret. |
| Account progress | Legacy is account-wide horizontal progression (65 challenges at launch). Faction `2802` "Legacy Track" exists in client data. | Module 5 can show Legacy as the house's shared heritage if the faction is readable. |
| Presets | First login chooses an Experience Preset, Classic or Enhanced. `C_GameRules.GetForeverExperiencePreset()` exists. | The main window inherits Blizzard templates so it follows the preset. |
| Locales | The `wowf` product config lists 10 locales: enUS, deDE, esES, esMX, frFR, ruRU, koKR, ptBR, zhTW, zhCN. The global shop sells 10 languages without Italian; zhCN serves the China/NetEase region (launch 2026-11-05). | v1 ships all ten client locales, zhCN included (decided after this research; see DECISIONS.md). No itIT. |
| Ecosystem | Overlapping Forever addons exist: Emberpath (campfire tales, map pins, addon-message sync), Ember: Camping Companion, I Remember You (384.7K downloads, remembered players), SocialForever, Forever Wayfinder (discovery journal). | The differentiator is the coupling: consequences, identity and house written into one character log, not any single module. |

## Settle at launch

The test mode answers these in one run. Commands are for the Forever client.

| Question | Check |
| --- | --- |
| Live interface number, project constant | `/dump select(4, GetBuildInfo()), WOW_PROJECT_ID, WOW_PROJECT_CAMELOT` |
| How surnames come back | `/dump UnitName("player"), UnitFullName("player"), GetRealmName()` |
| GUID stability | `/dump UnitGUID("player")` across sessions |
| Party names in dungeons | `/dump C_Secrets.ShouldUnitIdentityBeSecret("party1"), issecretvalue(UnitName("party1"))` inside an instance |
| Addon-message channels | `C_ChatInfo.SendAddonMessage` result codes for PARTY, GUILD, WHISPER, CHANNEL; `IsTrialAccount()` |
| Camp auras readable | `/dump C_UnitAuras.GetPlayerAuraBySpellID(1229741)` at a camp |
| Tooltip hiding | Whether `TooltipDataProcessor` exists and whether item tooltip lines are secret, open world and instance |
| Hidden item state | `C_Item.GetItemInfo`, `GET_ITEM_INFO_RECEIVED` success flag for an unrevealed item ID |
| Gelkis / Magram exclusivity | `C_Reputation.GetFactionDataByID(92)` and `(93)` before and after quest `1368` |
| Legacy | `C_MajorFactions.GetMajorFactionData(2802)`, `C_Reputation.GetFactionDataByID(2802)` |
| Map pins | `WorldMapFrame.AddDataProvider`, `C_Map.GetMapInfo(2652)`. The test mode's `Conflicts.data` check and `/ashmark probe` record `C_Map.GetMapInfo` for every conflict zone and anchor map. |
| Bag item count | `/dump C_Item.GetItemCount(<itemID>)` for an item in the bags returns a number. Knowledge counts a bag item as held through it before the bag scan has run; without it that fix does nothing. |
| Screenshot from addon code | `Screenshot()` with `SCREENSHOT_SUCCEEDED` / `SCREENSHOT_FAILED` |
| Blizzard UI source | Launch with `-console`, then `exportInterfaceFiles code` and `exportInterfaceFiles art` at the login screen |


## Verifier verdicts

### Refuted: Concept doc (citing kami-labs.fr): 'Forever runs on the Midnight retail client'.

Forever is not the Midnight client. It is its own client, built from the same Retail/Mainline code branch. Evidence: (1) It is a separate NGDP product 'wowf' under title_id 'wow', with its own install subfolder (shared_container_default_subfolder '_forever_'). (2) It has its own version line. On 2026-10-30, Blizzard's version server shows 1.60.1.70707 in us/eu/cn/kr/tw, while retail 'wow' is 12.1.5.70575. (3) The Forever build config reads 'build-name = WOW-70707patch1.60.1_Retail', 'build-uid = wowf'. Retail reads 'WOW-70575patch12.1.5_Retail'; Classic Era reads 'WOW-70576patch1.15.9_ClassicRetail'. So Forever comes from the Retail branch, not the Classic one. (4) Dev statement 'An Update On Secrets In WoW: Forever' (a Discord post dated 2026-09-15, known only from the warcraft.wiki.gg transcription, not news.blizzard.com): 'WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5', with Forever and Midnight as game types 'Camelot (to be renamed before launch) and Standard'. WHAT THIS IMPLIES: write against the Mainline C_* API and Mainline FrameXML. WHAT IT DOES NOT IMPLY: (a) the same interface number (16001, not 120105); (b) the same AddOns folder; (c) retail content or IDs, since content is Classic plus Forever; (d) every retail system. The 12.1.5(69952) to 1.60.1(70205) diff removes 1041 FrameXML functions, and Blizzard_GroupFinder is excluded on camelot. kami-labs itself does not say 'runs on the retail client'. It says the API is 'identical to retail's' / 'one-for-one' and cites a Warcraft Tavern interview, not a blue post.

Sources: <https://us.version.battle.net/v2/products/wowf/versions>, <https://us.version.battle.net/v2/products/wow/versions>, <https://level3.ssl.blizzard.com/tpr/configs/data/2c/ed/2ced73c17301c297ca062bc7c3583420>, <http://level3.blizzard.com/tpr/wow/config/7f/eb/7feb61f3c994bcb168526b8db521514a>, <http://level3.blizzard.com/tpr/wow/config/d7/18/d718abcc42604d8efbd35aecfa5bb75b>, <http://level3.blizzard.com/tpr/wow/config/56/04/5604ce35a8644bdcf0e26c1daf979c15>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>

### Confirmed: Concept doc: 'Blizzard aligned addon restrictions with Midnight' (secret values active in Forever).

Confirmed, but the source is weaker than the doc implies. The only developer wording is the 2026-09-15 Discord post as transcribed on warcraft.wiki.gg: 'The addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever.' I found no news.blizzard.com article or forum blue post saying this. kami-labs bases its claim on a Warcraft Tavern interview. Forever also adds restrictions of its own, per the wiki's Discord-sourced beta notes: Beta 4, build 70291 (2026-10-08): 'Trial accounts can no longer send addon messages'; SendChatMessage 'EMOTE' 'now requires a hardware event when called from addon code outside of instances'; a new 'FrameStrata' secret aspect. Beta 5, build 70425 (2026-10-16): the server-ID and spawn-ID parts of creature, vehicle, pet and gameobject GUIDs are obfuscated. The wiki's SendAddonMessage page states: 'Forever and modern clients starting in patch 12.1.7 prohibit trial and veteran accounts from sending addon messages.'

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage>, <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>

### Confirmed: Concept doc: the combat log is locked for addons on Forever (COMBAT_LOG_EVENT_UNFILTERED unavailable).

Confirmed in practice, although no Blizzard text names the combat log for Forever. The chain of evidence: (1) the wiki CLEU page says 'This event is no longer accessible to addons in Midnight since Patch 12.0.0' and 'Fires ADDON_ACTION_FORBIDDEN when attempting to register this event'; (2) the TOC page says Forever 1.60.1 'Includes all Modern changes up to 12.1.5'; (3) the dev statement says Midnight disarmament is active. In shipped code, BigWigs v427.8 sets isModern = isRetail or isForever (Loader.lua) and returns before RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED') when isModern (BossPrototype.lua). The ForeverUI CurseForge page says 'Skada and Recount can't read the combat log on Forever.' kami-labs never mentions the combat log, so the concept doc's attribution is wrong. Ashmark must never register CLEU. C_CombatLog.IsCombatLogRestricted() is listed for forever 1.60.1 (69913) and can be used as a runtime check.

Sources: <https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT_UNFILTERED>, <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/API_C_CombatLog.IsCombatLogRestricted>, <https://mediafilez.forgecdn.net/files/9299/959/BigWigs-v427.8.zip>, <https://www.curseforge.com/wow/addons/foreverui>, <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>

### Confirmed: TOC suffixes: _Forever.toc and _Camelot.toc (game type), _Mainline.toc (family); game-specific beats family; use AllowLoadGameType forever + ExcludeLoadGameType standard, classic.

Confirmed on warcraft.wiki.gg: game types 'forever' and 'camelot' with suffixes AddOnName_Forever.toc and AddOnName_Camelot.toc; the mainline family (standard, forever, camelot, plunderstorm, wowhack) uses AddOnName_Mainline.toc; footnote 'The Camelot value may be changed to Forever in the future.' Build 70291 (Oct 7, 2026) 'Added the "forever" TOC game type which is equivalent to "camelot"'. The two wiki pages use different example names: TOC_format uses 'ForeverOnly.lua [AllowLoadGameType camelot][ExcludeLoadGameType standard, classic]', while Patch_1.60.1/API_changes uses '## AllowLoadGameType: forever' plus '## ExcludeLoadGameType: standard, classic'. Warning from the TOC page: if none of the listed game types is recognized, the condition is still satisfied, so always add the Exclude. Shipped Forever addons do it differently: Questie ships only Questie_Camelot.toc (Interface 16001) plus a fallback Questie.toc with Interface 00000. QuestieDB ships identical _Camelot and _Forever TOCs. LFG Forever ships a plain LFGForever.toc with 16001. BigWigs uses one multi-interface TOC plus 'Init_[Game].lua', which resolves to Init_Camelot.lua, so [Game] still expands to 'Camelot'. Recommendation: ship Ashmark_Camelot.toc and Ashmark_Forever.toc (both '## Interface: 16001'), with no plain or _Mainline TOC. Midnight 12.1.7 'TOC directives no longer expand variables such as [Game] or [Family]', so do not rely on '## X-Game: [Game]'. Not verified: which file the client picks when both _Camelot and _Forever exist.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/Patch_12.1.7/API_changes>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>, <https://mediafilez.forgecdn.net/files/9263/876/LFGForever.zip>, <https://mediafilez.forgecdn.net/files/9299/959/BigWigs-v427.8.zip>

### Confirmed: Interface number is 16001 (Forever Beta/Test, build 70532, 2026-10-20); no live value published.

Confirmed as worded. TOC_format lists Forever Beta 16001 and Forever Test 16001, and the 'Forever' (live) row is empty. API_GetBuildInfo lists 1.60.1 / 70532 / 2026-10-20 / 16001 for Beta and Test and has no live data. The live product is already newer: 1.60.1.70707 in all five regions. I found no primary source giving 70707's interface number, so the live value is unresolved. Every Forever addon I opened declares 16001: Questie_Camelot.toc (Oct 26), LFGForever.toc (Oct 20), the BigWigs.toc list, and the IRememberYou.toc list. Check on 2026-11-04 with /dump select(4, GetBuildInfo()). For comparison: Midnight Standard 120105, Vanilla 11509.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/API_GetBuildInfo>, <https://us.version.battle.net/v2/products/wowf/versions>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>, <https://mediafilez.forgecdn.net/files/9263/876/LFGForever.zip>

### Confirmed: Runtime detection: WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18); there is no WOW_PROJECT_FOREVER.

The constant is confirmed, but sources disagree on whether WOW_PROJECT_ID can be trusted. The wiki WOW_PROJECT_ID table has '18 WOW_PROJECT_CAMELOT World of Warcraft: Forever' and no FOREVER constant. The build notes say '70170 (Oct 1 2026): Added WOW_PROJECT_CAMELOT (18) constant'. BigWigs' bundled LibSpecialization uses 'isForever = wowID == 18'. However, Questie v12.3.1 (Oct 26, 2026), VersionCheck.lua, comments: 'Forever shares Retail's project ID, but uses Classic content. Detect it by interface version instead.' It uses 'interfaceVersion >= 16000 and interfaceVersion < 17000'. This is probably stale from builds before 70170, but it is unverified. The wiki suggests the range 'version > 16000 and version < 20000'. Use a guard that does not depend on WOW_PROJECT_ID alone: (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) or (iface >= 16000 and iface < 20000), with iface = select(4, GetBuildInfo()). Re-check after the announced 'Camelot' rename.

Sources: <https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://mediafilez.forgecdn.net/files/9299/959/BigWigs-v427.8.zip>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>

### Confirmed: Secret values: party/raid members' names stay readable (also in instances); non-player, non-group units' identity is secret when restricted.

Confirmed at the documentation level only; there is no in-game test. UnitName, UnitFullName and UnitNameUnmodified carry the predicates AllowedWhenTainted and SecretWhenUnitNameIdentityRestricted. The Secret values page says that predicate follows 'regular unit identity secrecy rules', with an exception in PvP for player units. SecretWhenUnitIdentityRestricted produces secrets 'when the unit isn't player-controlled or in the party/raid', and compound tokens such as 'boss1target' are secret if any link fails. C_Secrets.ShouldUnitIdentityBeSecret(unit) 'Returns true if queries for unit identity (such as name or GUID) will produce secret values' and is listed for forever 1.60.1 (69913). Test helpers: issecretvalue, canaccessvalue, issecrettable, canaccesstable. Tainted code may not do arithmetic, comparisons, '#', indexing or calls on secrets, or use them as table keys. Storing and passing secrets is allowed. Debug CVars: addonMapRestrictionsForced, addonChatRestrictionsForced, addonCombatRestrictionsForced, addonPvPMatchRestrictionsForced, addonEncounterRestrictionsForced, addonChallengeModeRestrictionsForced. IRememberYou 1.75 guards UnitName results with issecretvalue on Forever.

Sources: <https://warcraft.wiki.gg/wiki/API_UnitName>, <https://warcraft.wiki.gg/wiki/Secret_values>, <https://warcraft.wiki.gg/wiki/API_C_Secrets.ShouldUnitIdentityBeSecret>, <https://mediafilez.forgecdn.net/files/9175/624/IRememberYou%201.75.zip>

### Confirmed: Inside dungeons/raids, chat sender names/text, LFG listing data and tooltip data become secret (SecretInChatMessagingLockdown / restricted maps).

Confirmed for Forever by the documentation and by two Forever addons, against an older Blizzard statement about Midnight. The wiki defines SecretInChatMessagingLockdown as applying during encounter, challenge-mode or PvP-match restrictions 'and while the player is on a chat-limited map like a dungeon or raid'. SecretOnRestrictedMaps (12.0.5) applies on 'an addon-restricted map such as a dungeon or raid'. C_ChatInfo.InChatMessagingLockdown() returns one boolean (the lockdownReason return was removed in 12.0.5) and is listed for forever 1.60.1. The contradiction: in October 2025 Kaivax narrowed the Midnight alpha lockdown to 'only ... while there is an active raid encounter or M+ run underway' (Warcraft Tavern, 2025-10-03). Forever code reads the stricter rule. LFG Forever: C_LFGList getters 'are all SecretInChatMessagingLockdown', and CHAT_MSG_WHISPER text and playerName are not NeverSecret, so the data is 'unreadable in a dungeon or raid'. Questie: 'Inside Forever instances tooltip data is restricted, effectively all secret'. For module 4: snapshot group names from UnitName on party/raid tokens, ideally outside instances, and never from chat payloads inside instances.

Sources: <https://warcraft.wiki.gg/wiki/Secret_values>, <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.InChatMessagingLockdown>, <https://www.warcrafttavern.com/wow/news/blizzard-walks-back-some-api-changes-for-addons-in-midnight/>, <https://mediafilez.forgecdn.net/files/9263/876/LFGForever.zip>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>

### Confirmed: Client locales: exactly 10 (enUS, deDE, esES, esMX, frFR, ruRU, koKR, ptBR, zhTW, zhCN); no itIT; zhCN only for the China/NetEase region.

The list is confirmed; the China-only point is an inference. The wowf product config lists supported_locales and display_locales as enUS, deDE, esES, esMX, frFR, ruRU, koKR, ptBR, zhTW, zhCN, and the 'cn' region's display_locales as [zhCN]. The Battle.net shop page lists Forever (product 5730135|19) as: English (US), Español (AL), Português (BR), English (EU), Deutsch, Español (EU), Français, Русский, 한국어, 繁體中文 (no Italiano). Midnight (5730135|18) lists the same plus Italiano. Regions: Americas & Oceania, Europe, Korea, Taiwan. Retail's product config includes itIT; Classic Era's has the same 10 as Forever. CORRECTION: zhCN appears in the global ('all') locale lists for Forever, retail and Classic Era alike. The shop's not listing Simplified Chinese does not prove global clients cannot select zhCN. GetLocale codes: enUS, koKR, frFR, deDE, zhCN, esES, zhTW, esMX, ruRU, ptBR, itIT, and 'enGB clients return enUS'. Ashmark should ship enUS, deDE, esES, esMX, frFR, ruRU, koKR, ptBR, zhTW, plus zhCN at low cost, and drop itIT.

Sources: <https://level3.ssl.blizzard.com/tpr/configs/data/2c/ed/2ced73c17301c297ca062bc7c3583420>, <https://level3.ssl.blizzard.com/tpr/configs/data/53/02/53020d32e1a25648c8e1eafd5771935f>, <https://level3.ssl.blizzard.com/tpr/configs/data/c9/93/c9934edfc8f217a2e01c47e4deae8454>, <https://us.shop.battle.net/en-us/product/world-of-warcraft-forever>, <https://warcraft.wiki.gg/wiki/API_GetLocale>

### Confirmed: Characters have a main name and a secondary name (surname); only the full combination must be unique within the region, so unrelated players can share a surname.

Confirmed by Blizzard: 'each character will have two names'; 'Your full character name needs to be distinct within your region, rather than only within a single realm'; example 'Asha Brightvale, Thalen Brightvale, and Mira Brightvale could share the same family-style second name'. The starter guide says 'a main name and a secondary name. The complete combination must be unique within your region.' The secondary name can be hidden in the world under Options > Nameplates ('My Secondary Name') 'but it will still appear in chat'. CVar UnitSurnameOwn: default '1', scope Account, 'show player surname over head'. APIs added in 1.60.1: C_PlayerInfo.ShouldDisplaySurname, C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator, RegionalUniqueNamesEnabled, and FrameXML NameUtil.SplitPlayerNameIntoParts / GetUnitFirstName / GetFullNameWithoutRealm / FormatUnitNameForDisplay / GetUnmodifiedUnitFullName / IsPlayerMe. The wiki does not mark these as added or removed; I read them as added. Blizzard's article does not cover length rules, renames or surname changes. Module 5 consequence: a surname does not prove a family. A House must be built from the account's own characters registered in SavedVariables.

Sources: <https://news.blizzard.com/en-us/article/24304161/create-a-name-of-your-own-in-wow-forever>, <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

### Unresolved: How surnames are exposed to addons: UnitName/UnitFullName return the surname as the second value where retail returns the realm.

No primary source settles this, but the evidence points to yes. warcraft.wiki.gg API_UnitName still documents 'name, realm = UnitName(unit)', with realm being the normalized realm or nil, and has no Forever note. Two independent pieces of shipped Forever code treat the second return as the surname. (1) IRememberYou 1.75 main.lua: 'if forever then local firstName, lastName = UnitName(id) ... return firstName.." "..lastName'. (2) The AceDB-3.0 bundled in Questie v12.3.1: 'if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then' realmKey is set from C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset / RPRuleset / PvPRuleset) to 'Hardcore'/'RP'/'PvP'/'PvE', and 'local name, surname = UnitNameUnmodified("player")', charKey = name .. " " .. surname. On Forever, the ruleset therefore takes the role of the realm in SavedVariables keys. Still unverified: the surname separator character used by C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator, the exact string format in chat, whisper and addon-message senders, and what GetRealmName() returns. Test in game on 2026-11-04, and read NameUtil in Ketho/wow-ui-source-forever (not opened).

Sources: <https://warcraft.wiki.gg/wiki/API_UnitName>, <https://mediafilez.forgecdn.net/files/9175/624/IRememberYou%201.75.zip>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

### Confirmed: Quest IDs match Classic (original quests keep Classic IDs; new Forever quests use 9xxxx IDs).

IDs carry over, but the content behind them can differ. Quest 1368 'Gelkis Alliance' exists on both Wowhead Classic and Wowhead Forever. In Classic it rewards Gelkis +100 and Magram -500, in a 6-part series ending with Khan Jehn / Khan Hratha. On Wowhead Forever the same ID shows Gelkis +250 and no Magram penalty, and the series continues into Forever-only quests, e.g. 93034 'Valley of Bones' (Honored Gelkis, +125). Blizzard dev notes (Kaivax, Oct 8, 2026): 'The new quests for the Gelkis and the Magram beginning with "Valley of Bones" now require a minimum level of 35 (was 30).' Questie's Forever database is built from the Era database plus Forever corrections. foreverQuestFixes.lua has 88 entries with IDs from 78124 to 97286, so Season of Discovery IDs (78xxx/79xxx/81xxx) are reused. eraToForever.lua re-projects coordinates for Mulgore (uiMapID 1412), Eastern Plaguelands (1423), Redridge (1433) and Stormwind City (1453) from DBC 1.15.9.69722 to 1.60.1.69893, which also shows Classic-era uiMapIDs are kept. Unresolved: whether Forever keeps the Gelkis/Magram reputation penalty (Wowhead may simply not show it), so Ashmark must read standings at runtime and not hard-code Classic reputation values.

Sources: <https://www.wowhead.com/forever/quest=1368/gelkis-alliance>, <https://www.wowhead.com/classic/quest=1368/gelkis-alliance>, <https://www.wowhead.com/forever/quest=93034/valley-of-bones>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>

### Confirmed: There is no dedicated addon event/API for camping; campfires must be detected through player auras.

Confirmed. The 1.60.1 event list (header: Added 24, Removed 2) contains no CAMP/CAMPFIRE/CAMPSITE events. The Forever-specific events are DIEL_CYCLE_CHANGED, GAME_RULES_CHANGED, SHARD_TRANSFER, SHARD_TRANSFER_IMMINENT, LFG_LIST_ROLE_UPDATE, LFG_LIST_SHOW_SEARCH, PLAYER_SWING, PLAYER_SWING_RANGE_UPDATE, UNIT_HAPPINESS, GUILD_PREFERRED_PLAY_SETTINGS_UPDATED, CHAT_MSG_COLLECTED_APPEARANCE and others. Aura IDs on Wowhead Forever: 'Camp Benefits' spell 1229741 (1 hour, 'Aura cannot be cancelled', Apply Aura: Dummy); 'Welcoming Campfire' 1289723 (1 minute, Periodic Dummy every minute, 20 yd); 'Campfire Nearby' 1283391 (passive, no duration, 100 yd radius). Blizzard: sitting or crafting at a campsite 'for at least one minute' grants the benefits; nearby players can add up to three Camp Features, one each. C_UnitAuras.GetPlayerAuraBySpellID(spellID) is listed for forever 1.60.1, with the return marked SecretWhenUnitAuraRestricted, so read it out of combat or guard it with issecretvalue. Not verified by me: Enum.GameRule.DisableCampsites (114) and the 'Boosted Rest' spell ID.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://www.wowhead.com/forever/spell=1229741>, <https://www.wowhead.com/forever/spell=1289723>, <https://www.wowhead.com/forever/spell=1283391>, <https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID>, <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>

### Unresolved: Item-stat discovery (~40% of items hidden) has addon-visible events / a discovery API.

No dedicated event or API exists in the 1.60.1 additions: no event names contain REVEAL, DISCOVER or ITEM. What is confirmed (Josh Greenfield, via Warcraft Tavern citing MMORPG.com, Sep 16, 2026): 'we're actually obfuscating all items in the game', and stats appear once an item drops 'for you, until it drops for someone on your server'. The article does not say whether discovery is per character or server-wide. The '~40%' figure (12,594 of about 31,800) comes from Icy Veins and MassivelyOP, both of which returned HTTP 403, so it is supported only by search snippets. foreverchanges.pro, an aggregator updated 2026-10-30 at build 70707, says 4,928 of 12,715 tracked hidden items are revealed. It also says the client asks the server when you loot, view at a vendor, click a link or an addon requests the item; the tooltip shows 'Retrieving item information' until the reply; and the reply is cached in the WoW folder. Whether GET_ITEM_INFO_RECEIVED / ITEM_DATA_LOAD_RESULT fire on a reveal is unverified. For module 7: the client cache is per installation, not per character, so 'never held by this character' has to be Ashmark's own record, keyed on item IDs and filled from loot, bag and bank scans.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://www.warcrafttavern.com/forever/news/item-stats-will-not-be-known-in-advance-for-wow-forever/>, <https://foreverchanges.pro/hidden-items>, <https://www.icy-veins.com/wow-forever/news/wow-forever-hid-over-12500-items-from-dataminers-heres-whats-still-secret/>

### Confirmed: There is no retail-style Dungeon Finder in Forever; only a Classic-style Looking For Group / Group Finder listing tool.

Confirmed. Warcraft Tavern (Sep 14, 2026, BlizzCon demo): the LFG UI 'does not form them automatically or teleport everyone to the dungeon'; Meeting Stones are not present. Blizzard dev notes (Kaivax) mention 'Group Finder postings' (Oct 8) and the 'Looking For Group UI' / 'Show All Level Ranges' (Oct 16). LFG Forever v0.29.0, which reads Blizzard's source, comments that 'Blizzard_GroupFinder is gated off camelot entirely (Blizzard_GroupFinder.toc:10, ## ExcludeLoadGameType: camelot)'. Forever instead loads Blizzard_LFGVanilla_* (Listing / Browse / Who List tabs, LFGVanilla_ToggleFrame) inside the LoadOnDemand Blizzard_GroupFinder_VanillaStyle. Module 4 must drop the 'Dungeon Finder' idea and remember companions from GROUP_ROSTER_UPDATE rosters, LFG listings (secret inside instances), campsites and guilds. Blizzard: grouping only within the same ruleset and faction; 'Cross-ruleset grouping is not supported'.

Sources: <https://www.warcrafttavern.com/forever/news/no-group-finder-or-summoning-stones-in-wow-forever/>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>, <https://mediafilez.forgecdn.net/files/9263/876/LFGForever.zip>, <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>, <https://worldofwarcraft.blizzard.com/en-us/news/24302070/>

### Refuted: Concept doc: 'Classic addons do not load' on Forever.

kami-labs does not say this. It says Classic Era, Classic and TBC Anniversary 'stay on the old, unrestricted API, unchanged'. What is true: Classic-family TOC suffixes (_Classic, _Vanilla, _TBC, etc.) are never selected on Forever. However, any addon whose TOC includes 16001 loads, for example BigWigs.toc ('11508, 11509, 16001, ... 120107') and IRememberYou.toc ('11509, 16001, 20506, 38002, 50504, 120105'). Classic Era code fails at runtime when it uses removed globals. API_GetSpellInfo lists no Forever availability ('Removed, replaced by C_Spell.GetSpellInfo'), and API_GetFactionInfo lists no Forever availability (its header points to C_Reputation.GetFactionDataByIndex/ByID). So Ashmark must use the Mainline C_* API.

Sources: <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>, <https://warcraft.wiki.gg/wiki/TOC_format>, <https://mediafilez.forgecdn.net/files/9299/959/BigWigs-v427.8.zip>, <https://mediafilez.forgecdn.net/files/9175/624/IRememberYou%201.75.zip>, <https://warcraft.wiki.gg/wiki/API_GetSpellInfo>, <https://warcraft.wiki.gg/wiki/API_GetFactionInfo>

### Confirmed: Mainline UI building blocks (PortraitFrameTemplate family, ScrollBox, Settings API, Addon Compartment, TooltipDataProcessor) are available on Forever.

Confirmed through shipped Forever-only code (an inference from addons, not Blizzard documentation). LFG Forever (Interface 16001) says each template it uses was 'confirmed to load on camelot': PortraitFrameTemplateNoCloseButton (SharedUIPanelTemplates.xml:656), UIPanelCloseButtonNoScripts, PanelDragBarTemplate. It also uses WowScrollBoxList, MinimalScrollBar, ScrollUtil, CreateDataProvider and Settings.Register*, and has an AddonCompartment entry in its TOC. BigWigs uses PortraitFrameTexturedBaseTemplate and SharedButtonTemplate when isModern (retail or Forever). Questie calls TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item/Spell/Unit/Object) and AddLinePreCall on Forever, behind type checks. The wiki says the Addon compartment section 'concerns content related to Midnight and Forever'. Caveat from LFG Forever: LFG* templates live in the LoadOnDemand Blizzard_GroupFinder_VanillaStyle and fail in CreateFrame until that addon is loaded.

Sources: <https://mediafilez.forgecdn.net/files/9263/876/LFGForever.zip>, <https://mediafilez.forgecdn.net/files/9299/959/BigWigs-v427.8.zip>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>, <https://warcraft.wiki.gg/wiki/TOC_format>

### Confirmed: Windows install: addons go in <WoW root>\_forever_\Interface\AddOns and settings in _forever_\WTF; beta used _classic_beta_.

Confirmed. The wowf product config has shared_container_default_subfolder '_forever_' and a shared_container_move_list of Cache, Interface, Screenshots, WTF. On Windows the binaries are Wow.exe and Wow-arm64.exe; minimum OS 10.0.0.18362; 4 CPU cores, 8192 MB RAM, 128,000,000,000 bytes required space; supports_multibox true. The CurseForge blog (Niv Hajaj, Oct 25, 2026) says the beta was 'World of Warcraft\_classic_beta_' and live is 'World of Warcraft\_forever_\Interface\AddOns'; when migrating, rename the beta account folder under WTF\Account to the live account name. SavedVariables go in WTF\[account]\SavedVariables\Ashmark.lua. Unresolved: the exact default root. The config only says form.game_dir default 'Program Files' with dirname 'World of Warcraft', which does not settle whether it is 'Program Files' or 'Program Files (x86)'. Check the Battle.net app on the owner's PC.

Sources: <https://level3.ssl.blizzard.com/tpr/configs/data/2c/ed/2ced73c17301c297ca062bc7c3583420>, <https://blog.curseforge.com/wow-forever-migrate-addons-beta-to-live/>, <https://warcraft.wiki.gg/wiki/TOC_format>

### Refuted: Forever client does not read SavedVariables back after reload/restart (ForeverUI page, updated Oct 20 2026).

This was a beta bug that appears to be fixed. The wiki's 1.60.1 notes say '70009 (Sep 23 2026): Fixed SavedVariables not loading.' In the EU forum thread (bug reported on 1.60.1.69913 on Sep 19), players reported on Sep 24-25 that 'the issue has finally been resolved with version 1.60.1.70009'. There was no blue post. One remaining report concerns built-in chat customizations, not addon SavedVariables. The ForeverUI page text is probably stale. Ashmark still needs a SavedVariables round-trip test on live build 70707 or later. ADDON_LOADED should treat nil SavedVariables carefully, so that a load failure cannot overwrite good data with defaults.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://eu.forums.blizzard.com/en/wow/t/solvedforever-beta-160169913-savedvariables-fail-to-load-on-client-startupreload-%E2%80%94-all-addon-settings-reset-on-restart/629888>, <https://www.curseforge.com/wow/addons/foreverui>

### Confirmed: Addon messaging: C_ChatInfo.SendAddonMessage exists on Forever (prefix ≤16, message ≤255, 10-message allowance regaining 1/s); trial/veteran accounts cannot send; CHANNEL chat type availability on Forever unknown.

Confirmed: signature result = C_ChatInfo.SendAddonMessage(prefix, message [, chatType [, target]]), listed for forever. PARTY, RAID, INSTANCE_CHAT, GUILD, OFFICER and WHISPER work on both retail and Classic. 'CHANNEL' is retail-only and 'Disabled on Classic to prevent players communicating over custom chat channels'; the wiki does not say how Forever behaves, so this stays unresolved and decides whether rumours can travel over a hidden channel. Enum.SendAddonMessageResult: 0 Success through 12 TargetOffline, with 11 AddOnMessageLockdown. 'Forever and modern clients starting in patch 12.1.7 prohibit trial and veteran accounts from sending addon messages.' The rumours module must work in receive-only mode for those accounts.

Sources: <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>

### Refuted: Module 1 pilot naming: 'Shen'dralas' is the faction.

The faction is Shen'dralar ('A remnant of the once powerful elves living in Dire Maul', Wowhead Forever faction page; standard thresholds Neutral 42,000 / Friendly 45,000 / Honored 51,000 / Revered 63,000 / Exalted 84,000; no related quests listed). Shen'dralas is a new contested zone 'exclusive to World of Warcraft: Forever' (added in 1.60.1), 'southeast of Desolace and between Feralas and Mulgore'. Its level range is unknown. Affiliated groups: Shen'dralar, Magram clan, Bristleback tribe. Subzones: Bristleback Retreat, Evenshade Overlook, Magram Front, Outcast Hideaway, Shen'dralas, Valley of Bones. The zone's uiMapID is unknown.

Sources: <https://www.wowhead.com/forever/faction=809/shendralar>, <https://warcraft.wiki.gg/wiki/Shen'dralas>

### Confirmed: Rulesets replace realms (Normal, PvP, Roleplay, Roleplay PvP; Hardcore later); no cross-ruleset grouping; PvP ruleset is single-faction per account; Collections/Legacy account-wide.

Confirmed in Blizzard's 'Choose Your Ruleset in World of Warcraft: Forever' (October 22): 'Hardcore will be available sometime after launch'; 'Cross-ruleset grouping is not supported'; 'Battlegrounds may include players from other rulesets, with the exception of Hardcore'; 'On the PvP ruleset, players can only create characters for one faction'; Preferred Online Language 'applies to all characters and has a 24-hour cooldown'; 'Collections and Legacy Points are account-wide across rulesets, with Hardcore handled differently'. Launch is Nov 4, 2026, 3:00 p.m. PST (23:00 UTC; 12:00 a.m. CET Nov 5). Raids open Dec 9. For Ashmark: store the ruleset (C_GameRules.IsGameRuleActive with Enum.GameRule.HardcoreRuleset/RPRuleset/PvPRuleset, as Questie's AceDB does) and the faction with every House, companion and rumour record.

Sources: <https://worldofwarcraft.blizzard.com/en-us/news/24302070/>, <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <https://mediafilez.forgecdn.net/files/9334/933/Questie-v12.3.1%2Bv1.0.9.zip>

## Open questions (completeness critic)

- **Can any in-client test run before launch (2026-11-04 23:00 UTC, which is 00:00 CET on Nov 5)? Name reservation allows 'Create up to 3 characters', but Blizzard's reservation article never says you can enter the world, and addons only load in the world.**
  - Impact: If no one can enter the world before launch, every /dump check below waits until launch night. v0.1 then has to be built on assumptions plus a throwaway probe addon that records all checks at once into SavedVariables.
  - How to settle: Try 'Enter World' on a reserved character now. If it fails, prepare an 'AshmarkProbe' addon that runs the checks below on PLAYER_LOGIN and writes the results to its SavedVariables. Source checked: https://news.blizzard.com/en-gb/article/24303866/world-of-warcraft-forever-early-name-reservations-are-now-live (silent on world login).
- **Can the Forever FrameXML be read before launch? Does ExportInterfaceFiles work in the Forever client, and which repository holds a Forever dump?**
  - Impact: This one step would settle, before launch, whether these exist and are unchanged: PortraitFrameTemplate/ButtonFrameTemplate, ScrollBox/ScrollUtil, Settings, TooltipDataProcessor, MapCanvasDataProviderMixin/WorldMapFrame:AddDataProvider, NameUtil (surname separator), Blizzard_LegacySystem, Blizzard_LFGVanilla, and any Camelot-specific skins or atlases. Today these are known only by inference from other addons' code.
  - How to settle: Windows: Battle.net app > WoW Forever > Game Settings > Additional command line arguments '-console'. At the login screen press ` and run 'exportInterfaceFiles code' and 'exportInterfaceFiles art', then check <WoW root>\_forever_\BlizzardInterfaceCode. The command runs at the login screen, so it may work before launch. Fallback: read Ketho/wow-ui-source-forever (its existence is unverified) or a Forever branch of Gethe/wow-ui-source.
- **What interface number and game-type names will the live client use at launch: 16001? A 'Camelot' to 'Forever' rename? A WOW_PROJECT_FOREVER constant? And which TOC wins when both _Forever.toc and _Camelot.toc are shipped?**
  - Impact: Decides the TOC files to ship and the runtime guard. If a rename lands at launch, a TOC set up only for _Camelot or only for 'forever' could silently fail to load.
  - How to settle: /dump select(4, GetBuildInfo()); /dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, WOW_PROJECT_FOREVER. Ship the probe as Probe_Forever.toc and Probe_Camelot.toc with different '## Title' values, then /dump C_AddOns.GetAddOnMetadata('Probe','Title'). Watch https://wago.tools/api/builds key 'wowf' (1.60.1.70707 as of today) and the live row on https://warcraft.wiki.gg/wiki/TOC_format.
- **How does Forever handle out-of-date addons? Is there a 'Load out of date AddOns' option, and does a TOC with Interface 120105 (as Emberpath ships) or without 16001 (HandyNotes core) load?**
  - Impact: Decides whether Ashmark must bump its Interface line on every Forever patch. It also explains why Emberpath and HandyNotes-based plugins are reported as working on Forever.
  - How to settle: Check the AddOns list in game. Install a probe copy with '## Interface: 120105' and see whether it loads.
- **How are two-part names exposed? Does UnitName/UnitFullName/UnitNameUnmodified return (first, surname) or (name, realm)? What do GetRealmName()/GetNormalizedRealmName() return? What sender string do CHAT_MSG_* and CHAT_MSG_ADDON carry? What target string does SendAddonMessage 'WHISPER' expect? Which character is the surname separator?**
  - Impact: Sets the identity key format for modules 4 and 5 and how WHISPER addon messages are addressed. Shipped code (IRememberYou, Questie's AceDB) assumes (first, surname); the wiki still documents realm.
  - How to settle: /dump UnitName('player'), UnitFullName('player'), UnitNameUnmodified('player'), GetRealmName(), GetNormalizedRealmName(), UnitGUID('player'), GetPlayerInfoByGUID(UnitGUID('player')), C_PlayerInfo.ShouldDisplaySurname(). Whisper your own alt and log the CHAT_MSG_WHISPER and CHAT_MSG_ADDON sender args. Read NameUtil.SplitPlayerNameIntoParts in the exported FrameXML.
- **Which identifier stays stable for a character? Is the player GUID stable across logins, renames, surname changes (is there a paid name service?), paid ruleset transfers (C_CharacterServices.GetPaidCharacterTransferSuperDistrictDestinations exists) and Hardcore death transfers?**
  - Impact: If the GUID is stable, it should be the primary key for House members, companions and rumours, with names as display only. Name-based keys break when a character is renamed or moved to another ruleset.
  - How to settle: /dump UnitGUID('player') across sessions; compare before and after a rename or transfer once services exist. Check the Battle.net shop for Forever character services. Read Blizzard's Hardcore rules article when it is published.
- **How are per-character folders laid out under WTF? Is the 'realm' folder the ruleset? Is the character folder named by first name only or by full name? Do two alts with the same first name on the same ruleset collide?**
  - Impact: If the folder uses only the first name, SavedVariablesPerCharacter would mix data between 'Asha Brightvale' and 'Asha Stone'. Ashmark would then need account-wide SavedVariables keyed by ruleset + GUID or full name, as Questie's AceDB does.
  - How to settle: After first login on Windows, look at <WoW root>\_forever_\WTF\Account\<ACCOUNT>\ and create two alts that share a first name on one ruleset. Also do a SavedVariables round trip (/reload and a full client restart), because the beta SavedVariables bug was reported fixed in 70009 but ForeverUI still claims otherwise.
- **Is there any API that lists the account's characters across rulesets and factions, for the House roster?**
  - Impact: If none exists, a House can only contain alts that have logged in with Ashmark enabled. On the PvP ruleset a House is single-faction. Hardcore members stay separate.
  - How to settle: Search the exported FrameXML or Ketho/BlizzardInterfaceResources (Forever lists) for character-list or warband-style APIs. Assume none until found.
- **Can addons read Legacy points? Quick check: the Forever Faction table on wago.tools (build 1.60.1.70707) has faction 2802 'Legacy Track', which fits the community claim that Legacy is a renown-style faction.**
  - Impact: Module 5 (shared family 'heritage' from the account-wide Legacy pool) and module 2 (identity signals).
  - How to settle: /dump C_MajorFactions.GetCurrentRenownLevel(2802); /dump C_MajorFactions.GetMajorFactionData(2802); /dump C_Reputation.GetFactionDataByID(2802). Read Blizzard_LegacySystem (LegacySystemFrame_LoadUI) in the exported FrameXML. Data source checked: https://wago.tools/db2/Faction/csv?build=1.60.1.70707
- **Do the achievement and statistics APIs exist on Forever (GetStatistic, GetCategoryList, GetAchievementInfo), given that Legacy 'replaces achievements'?**
  - Impact: If statistics exist (deaths, quests completed, kills, falls and similar), they are the richest behaviour source for module 2 that needs no combat log. If not, module 2 relies only on live events and its own counters.
  - How to settle: /dump GetStatistic ~= nil, GetCategoryList and GetStatistic(60), C_AchievementInfo ~= nil.
- **Is the combat-log lock absolute or conditional on Forever? C_CombatLog.IsCombatLogRestricted() exists, which implies a restriction state that can change.**
  - Impact: Module 2. If the open-world combat log is readable, behaviour profiling becomes much richer. If it is locked everywhere, Ashmark must never register CLEU.
  - How to settle: /dump C_CombatLog.IsCombatLogRestricted() in the open world, out of combat and in combat. In the probe addon only, never in Ashmark, try RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED') and watch for ADDON_ACTION_FORBIDDEN.
- **Which events that do not depend on the combat log exist on Forever, and are their payloads secret? Candidates: PARTY_KILL, PLAYER_DEAD, PLAYER_XP_UPDATE, CHAT_MSG_COMBAT_XP_GAIN, CHAT_MSG_LOOT, CHAT_MSG_SKILL, CHAT_MSG_COMBAT_FACTION_CHANGE, UPDATE_FACTION, BAG_UPDATE_DELAYED. Questie says CHAT_MSG_SYSTEM and CHAT_MSG_SKILL text 'can be secret'.**
  - Impact: Module 2 inputs. Module 7 'held' detection: if loot chat text is secret in instances, use bag, bank and equipment scans (C_Container, Enum.BagIndex incl. the reagent bag) instead of parsing CHAT_MSG_LOOT.
  - How to settle: /etrace in the open world and in a dungeon; in the probe, print issecretvalue(arg1) for each event; /dump Enum.BagIndex.
- **In Forever 5-player dungeons, do the addon restrictions last for the whole instance or only during boss encounters? The wiki says chat-limited maps such as dungeons; Kaivax narrowed the Midnight alpha rule to active raid encounters and M+ runs.**
  - Impact: Module 4 (when to snapshot party names), rumours (whether SendAddonMessage returns 11 AddOnMessageLockdown inside dungeons), and module 7 (whether item tooltips are secret where most loot drops).
  - How to settle: Inside a dungeon, out of combat: /dump C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Map), C_ChatInfo.InChatMessagingLockdown(), C_Secrets.ShouldUnitIdentityBeSecret('party1'), issecretvalue(UnitName('party1')), C_ChatInfo.SendAddonMessage('ETPROBE','x','PARTY'). Before launch, emulate with /console addonMapRestrictionsForced 1 (not saved).
- **Can addon code hide or replace item tooltip stat lines on Forever? Specifically: does TooltipDataProcessor exist (Questie guards it with type checks), does AddLinePreCall returning true suppress a line, and are line texts (TooltipDataLine.leftText) secret in the world, in combat or in instances?**
  - Impact: This is the core feasibility question for module 7. If lines are secret or cannot be hidden in instances, module 7 needs a fallback, such as a cover drawn over the tooltip or out-of-instance only.
  - How to settle: /dump TooltipDataProcessor ~= nil. In the probe: TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, d) print(issecretvalue(d.lines[2].leftText)) end), tested in the open world and in a dungeon, on GameTooltip, ItemRefTooltip, the shopping tooltips, loot-roll and AH tooltips. Test line suppression with AddLinePreCall.
- **How does Forever represent an item that the server has not revealed yet? What do C_Item.GetItemInfo and C_TooltipInfo.GetItemByID return? Does GET_ITEM_INFO_RECEIVED fire with success=false? Is the reveal scoped to the region, the ruleset or the whole game ('your server' in a realmless game)?**
  - Impact: Module 7 must model three states: hidden by the server, revealed but never held by this character, and held. It also has to avoid request loops for items the server refuses.
  - How to settle: Take an unrevealed ID from https://foreverchanges.pro/hidden-items. /run C_Item.RequestLoadItemDataByID(id) with /etrace running; /dump C_Item.GetItemInfo(id), C_Item.IsItemDataCachedByID(id), C_TooltipInfo.GetItemByID(id).
- **Can stat lines be found without matching localized text? Is there an Enum.TooltipDataLineType or a stats field for stat lines, and what keys does C_Item.GetItemStats return for Forever's merged hit/crit and new stats?**
  - Impact: Module 7 has to mask stats in 10 locales. Text patterns copied from Classic Era would miss Forever's stat names.
  - How to settle: /dump C_TooltipInfo.GetItemByID(id).lines (check line.type) and /dump C_Item.GetItemStats(link) on a few revealed items. Compare with ForeverGear's '/fg stats' output.
- **Are Gelkis and Magram still mutually exclusive in Forever? Is there still a penalty to the rival clan, and is there requiredMaxRep gating? Wowhead Forever shows Gelkis Alliance (1368) as +250 Gelkis with no Magram loss, where Classic had -500. Quick check: the Forever Faction table also has a hidden faction 2769 'Gelkis Outcasts' whose role is unknown.**
  - Impact: Module 1 pilot. If Blizzard removed the exclusivity, Ashmark cannot enforce it, because addons cannot block quest acceptance. It would have to be narrative only, or a different rival pair would be needed.
  - How to settle: Questie Forever DB (Questie/Questie: the Forever corrections and the requiredMinRep, requiredMaxRep and reputationReward fields for 1367, 1368, 93034, 92873, 92893). In game: record C_Reputation.GetFactionDataByID(92) and (93).currentStanding before and after a turn-in, watching UPDATE_FACTION. /dump C_Reputation.GetFactionDataByID(2769).
- **What do the quest events carry on Forever (mainline code running Classic-style content)? Is the QUEST_ACCEPTED payload (questID) or (questLogIndex, questID)? Which quest frames exist for annotation (QuestFrame, QuestMapFrame, Classic quest log)? QuestLogPopupDetailFrame_* was removed.**
  - Impact: Module 1 hooks for marking an exclusive choice at QUEST_DETAIL time.
  - How to settle: /etrace QUEST_DETAIL QUEST_ACCEPTED QUEST_TURNED_IN QUEST_REMOVED; /dump GetQuestID() on QUEST_DETAIL; /dump QuestFrame, QuestMapFrame, QuestLogFrame.
- **Do the map IDs and pin hooks work in the client? Quick check: the wago.tools Forever UiMap table (build 1.60.1.70707) lists Desolace 1443, Shen'dralas 2652 (parent Kalimdor 1414), Riverglades 2548, Mount Hyjal 2482, Darkspear Islands 2524, and Zephras Isle 2521 and 2665. It has only 60 rows, with no dungeon or Dalaran maps (possibly encrypted). Still open: are Desolace coordinates re-projected, does WorldMapFrame:AddDataProvider exist, and is the player's position readable in the open world?**
  - Impact: Module 3 pins and the Desolace/Shen'dralas pilot. It also determines compatibility with OpenMap and Leatrix Maps, which replace the map.
  - How to settle: /dump C_Map.GetBestMapForUnit('player') in each zone; /dump C_Map.GetMapInfo(2652); /dump WorldMapFrame.AddDataProvider; /dump C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit('player'),'player'). Read MadsFrost/Emberpath (data-provider pins) and OpenMap's Compat.lua. Source checked: https://wago.tools/db2/UiMap/csv?build=1.60.1.70707
- **Who is at my campfire? Can an addon list nearby players who are not grouped (friendly nameplates nameplateN, mouseover, target) without getting secret values in the open world? Does adding a Camp Feature produce any event or system message?**
  - Impact: Modules 6 and 4. Without this, a chapter's participants are limited to party members plus other Ashmark users found through addon messages.
  - How to settle: At a campfire with friendly nameplates on: /dump C_NamePlate.GetNamePlates(), UnitName('nameplate1'), issecretvalue(UnitName('nameplate1')). Run /etrace while another player places a feature.
- **Can addons read the campfire auras? Quick check: the wago.tools Forever SpellName table has 1229741 'Camp Benefits', 1289723 'Welcoming Campfire', 1283391 'Campfire Nearby', 1229451 'Boosted Rest', 818 'Basic Campfire' (the cast) and 7359 'Bright Campfire'. Still open: are these auras readable out of combat, and are the per-effect tooltip lines of Camp Benefits readable?**
  - Impact: Module 6 chapter trigger (Welcoming Campfire turning into Camp Benefits). The camp's 'size' would come from the effect lines.
  - How to settle: At a camp: /dump C_UnitAuras.GetPlayerAuraBySpellID(1289723) and C_UnitAuras.GetPlayerAuraBySpellID(1229741), then /dump C_TooltipInfo.GetUnitBuffByAuraInstanceID('player', <auraInstanceID>). Also check the bedroll: /dump C_Spell.GetSpellInfo(429959). Source checked: https://wago.tools/db2/SpellName/csv?build=1.60.1.70707
- **Which channels can carry rumours? Does SendAddonMessage accept 'CHANNEL' (retail yes, Classic no) or 'SAY'/'YELL' (Classic only) on Forever? Can custom channels be joined, and what member limits apply on region-wide rulesets? How does SocialForever exchange data with 'nearby players'? Do trial accounts exist on Forever, and how are they detected?**
  - Impact: Decides whether shared fiction can spread through nearby players or a zone, or only through GUILD, PARTY, RAID and WHISPER. Accounts that cannot send need a receive-only mode.
  - How to settle: In the probe: print(C_ChatInfo.SendAddonMessage('ETPROBE','x','SAY')), then 'YELL', then 'CHANNEL' after JoinTemporaryChannel('etprobe'); read the Enum.SendAddonMessageResult codes. /dump IsTrialAccount(), IsVeteranTrialAccount(). Read babunidev/SocialForever and MadsFrost/Emberpath.
- **Is there any layer (world instance) identity for addons? What payload do SHARD_TRANSFER and SHARD_TRANSFER_IMMINENT carry?**
  - Impact: Module 3 world state and rumours. Creature and object GUIDs are obfuscated per session, so pins and shared state must not depend on the layer, and remembered players may be in another layer.
  - How to settle: /etrace SHARD_TRANSFER SHARD_TRANSFER_IMMINENT during a layer change (group invite, capital city).
- **Can the main window match the version's look? Does Blizzard ship Classic-preset (Camelot) panel skins or atlases that addons can use? What does C_GameRules.GetForeverExperiencePreset() return?**
  - Impact: Main window style and the owner's goal of embracing this version's character, under both the Classic and the Enhanced preset.
  - How to settle: Search the exported art and code for 'Camelot' and 'Forever' atlases and templates; /dump C_GameRules.GetForeverExperiencePreset().
- **Do Screenshot(), ToggleSit() and DoEmote('SIT') work from addon code without a hardware event on Forever?**
  - Impact: Module 6: a chapter image at the campfire and a 'sit by the fire' button. EMOTE chat already needs a hardware event outside instances.
  - How to settle: In the probe: C_Timer.After(1, Screenshot), C_Timer.After(1, ToggleSit); watch SCREENSHOT_SUCCEEDED, SCREENSHOT_FAILED and ADDON_ACTION_BLOCKED.
- **How does a Forever release get published? Does the BigWigs packager map 16001 and _Forever/_Camelot to the Forever flavor? What is the CurseForge upload game-version ID for '1.60.1'?**
  - Impact: CI and release automation. The final name drives the folder, SavedVariables, addon-message prefix and slash-command names, and these are costly to change after release.
  - How to settle: Read release.sh in BigWigsMods/packager; query the CurseForge API /api/game/versions with a token; contact Bollinea or CurseForge support. Use a working codename until this is settled.

### Claims the critic flagged as overstated

- Several verdicts check kami-labs against only one of its two pages. They say kami-labs 'does not say runs on the retail client', 'never mentions the combat log' and 'does not say [Classic addons don't load]'. This applies to verdict 1, verdict 3, the 'Classic addons do not load' verdict and the addon-api finding 'Correction to the concept doc' (rated high). All of them used only https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/. A quick check of https://kami-labs.fr/en/addons-wow-forever/ (by Kami, 'Checked on Oct 20, 2026', beta 1.60.1) shows it literally says 'Forever runs on the Midnight Retail client', 'It runs on the Midnight Retail client ... with its own interface number: 16001', 'An addon written for Classic ... simply won't load', and 'The combat log ... is closed to addons'. So the concept doc quoted kami-labs correctly. What is wrong is the substance: Forever is a separate client 'wowf' from the Mainline code family.
- The verdict 'Classic addons do not load: refuted' is too strong. For Classic-only addons (only _Classic, _Vanilla or 11509 TOCs) the statement is true in practice. It is false only for multi-interface TOCs that include 16001. The verdict should be 'partly true'.
- Platform finding (high): 'Midnight's addon restrictions ... are officially active in Forever.' The only source is warcraft.wiki.gg's transcription of a Discord post. No news.blizzard.com article or blue post was found, and the verdict itself says so. 'Officially' overstates the source.
- Platform finding (high): 'own version line (1.60.x, TOC 16001)'. The wiki documents 16001 only for Forever Beta and Test (build 70532). The live product 1.60.1.70707 has no published interface number.
- Platform finding (high): zhCN exists only for China. The wowf product config includes zhCN in the global locale list, as retail and Classic Era also do. China-only is an inference from the shop page, as the verdict notes.
- Addon-api findings (high): 'Forever's project constant is WOW_PROJECT_CAMELOT = 18' and 'Blizzard-documented ways to detect Forever'. These methods come from warcraft.wiki.gg, not from Blizzard documentation. Questie v12.3.1 (Oct 26) says in code that Forever shares Retail's project ID and detects it by interface range instead. The X-Game/[Game] method may break with 12.1.7's change to variable expansion. 'GetActiveGameMode has no Forever value' is read from the generic Enum.GameMode page, not from a Forever dump.
- Addon-api finding (high): the full secret-values API list is 'present in Forever 1.60.1'. That covers secretwrap, scrubsecretvalues, dropsecretaccess, mapvalues, the Enum.AddOnRestrictionType values and the six *RestrictionsForced CVars. Most of these come from the Midnight 12.0.0 and 12.0.5 pages. Only some functions were shown with Forever availability, so presence is inferred from inheritance.
- Verdict 'Inside dungeons/raids, chat sender names/text, LFG listing data and tooltip data become secret: confirmed'. The evidence is wiki predicate definitions plus code comments in two third-party addons. That stands against a Blizzard statement (Kaivax, Oct 2025) narrowing lockdown to active raid encounters and M+ runs, and no one has tested a Forever dungeon. It should be 'likely' or 'unresolved'.
- Verdict 'party/raid names stay readable, also in instances: confirmed'. This is confirmed only by documentation, with no in-game test. Questie's Forever comments ('UnitGUID can be secret', instance tooltip data 'effectively all secret') point the other way. The label 'confirmed' is too strong.
- Verdict 'combat log locked: confirmed in practice' and the ecosystem finding (high) 'combat log not available on Forever'. No source tested this on Forever. BigWigs skipping CLEU registration is its authors' design choice, the ForeverUI and kami-labs text are secondary claims, and the existence of C_CombatLog.IsCombatLogRestricted() suggests a conditional state, not a permanent block.
- Verdict 'Mainline UI building blocks (incl. TooltipDataProcessor) available: confirmed'. Questie calls TooltipDataProcessor behind type checks, which means it is written to survive the function being absent; that is not proof it exists. Evidence for the templates is a third-party author's comments ('confirmed to load on camelot'). Medium at most.
- Ecosystem finding (high): 'WhyHidden ... C_Secrets predicate API that is shared by Forever and Midnight'. It rests on one third-party README claiming it was 'verified identical on both live clients' on Oct 7, 2026. Forever was still in beta then, so the claim cannot be correct as written.
- Systems finding (high): SocialForever 'proves addon messaging works in the beta'. The evidence is a CurseForge feature description; the source code was not opened and the channel it uses is unknown. A feature description does not prove the feature works.
- Systems finding (high): 'Official camping rules'. It mixes in non-Blizzard details: the 5- and 10-feature capacities of upgraded fires come from Warcraft Tavern, Blizzard's table omits the Mining Lodestone, and the skill thresholds conflict between sources.
- Addon-api finding: Classic globals 'GetSpellInfo, GetItemInfo, UnitMaxHealth ... reported missing'. UnitMaxHealth has never been a WoW API name (the real function is UnitHealthMax). A player reporting that it returns nil proves nothing, which weakens the forum thread as evidence for the other names.
- Addon-api surname finding: 'Blizzard Watch (Sep 13, 2026, reporting Blizzard's Sep 17 Q&A update)'. An article dated Sep 13 cannot report a Sep 17 update, so one of the dates is wrong.
- Ecosystem and addon-api findings present Emberpath and HandyNotes Forever Instances as working Forever addons. Emberpath's TOC declares Interface 120105, and HandyNotes core has no 16001 build (the ecosystem finding rates 'no Forever-ready release' high). Whether either loads at all depends on how Forever handles out-of-date addons, which is unknown.
- Systems finding: 'Barkskin Burrow ... unverified' understates the evidence. A quick check shows faction 2747 'Barkskin Burrow' in the Forever Faction table (wago.tools, build 1.60.1.70707).

## Findings by domain

### Platform

#### World of Warcraft: Forever is a third, permanent version of WoW that sits alongside modern WoW (Midnight) and Classic. It was announced at BlizzCon 2026 on 2026-09-12. Its internal codename is 'Camelot', and the community calls it 'Classic+'.

Confidence: high. Relevance: Overall framing. Ashmark targets only this game type, not Midnight or Classic Era.

Blizzard's wording: 'a new permanent home alongside modern and Classic WoW'. The wiki says it was 'developed by a portion of Team 2' and 'operates as a standalone branch of the MMO, running concurrently with both retail and Classic'. The Battle.net shop's internal SKU names use the codename, for example 'WoW Camelot 1.60.0 Skyborne Heroic Edition (US/EU/KR/TW)'.

Sources: <https://news.blizzard.com/en-us/article/24302093/carve-a-new-path-with-world-of-warcraft-forever>, <https://warcraft.wiki.gg/wiki/Patch_1.60>, <https://www.warcrafttavern.com/forever/news/warcraft-forever-classic-announced-at-blizzcon-2026/>, <https://us.shop.battle.net/en-us/product/world-of-warcraft-forever>

#### The setting is the first year of original WoW (25 ADP): after Warcraft III Reforged: Forsaken Kingdom, before Molten Core and The Burning Crusade. It is its own continuity, separate from retail. The original continents are expanded with new and reimagined zones and over 1,000 new quests.

Confidence: high. Relevance: Module 1 (Shen'dralas is a real new Forever zone), map layer (module 3), and lore tone for the identity and rumours modules.

New zones and regions: Mount Hyjal, Riverglades, Shen'dralas, Zephras Isle (the Skyborne starting zone), Darkwhisper Gorge, Darkspear Islands, and Dalaran in Alterac. Nine new 5-player dungeons cover levels 13-60. Raids unlock Dec 9 for level 60: Barrow Deeps (10-player), Hyjal Summit (20) and Onyxia's Lair (40). New 15v15 battleground: Battle for the Darkspear Islands. New race: Skyborne (Horde Skyborne can be Shaman, Alliance Skyborne can be Mage). Races from TBC onward are not playable. Blizzard calls the continuity a 'time bubble'; that quote comes from a Twitch clip cited by the wiki.

Sources: <https://news.blizzard.com/en-us/article/24302093/carve-a-new-path-with-world-of-warcraft-forever>, <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <https://news.blizzard.com/en-us/article/24303862/world-of-warcraft-forever-whats-next-panel-recap>, <https://warcraft.wiki.gg/wiki/Patch_1.60>

#### Progression is permanently capped at level 60 and grows horizontally. There is no level scaling and no flying. Progress across the account comes from the Legacy System.

Confidence: high. Relevance: Module 2 (identity profile), Module 5 (House / account-wide Legacy), and level gating for module 1 quests.

Blizzard describes 'the level 1-60 journey' with 'no level scaling' and 'no flying mounts'. The wiki's development pillar says 'No level cap increases'. The beta cap was 20, later raised to 30 (dev notes Oct 1: 'Players can now level up to a maximum of level 30'). Legacy is 'an account-wide horizontal progression system' made of Legacy Challenges, Perks and Rewards, and 'All character advantages can be unlocked on a single character'. According to the wiki, Legacy replaces achievements, there are 65 points at launch, and rewards unlock at 15/25/40/55 points. Collections and Legacy Points are account-wide across rulesets; Hardcore progress flows out to other rulesets but not back in.

Sources: <https://news.blizzard.com/en-us/article/24303862/world-of-warcraft-forever-whats-next-panel-recap>, <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <https://worldofwarcraft.blizzard.com/en-us/news/24302070/>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>, <https://warcraft.wiki.gg/wiki/Patch_1.60>

#### No separate purchase is needed: Forever is included with any WoW Subscription or Game Time. Optional paid upgrades unlock the Skyborne race.

Confidence: high. Relevance: Audience assumptions. Trial accounts cannot send addon messages (see the addon-security finding), which affects the rumours feature.

Blizzard footnote: 'Requires World of Warcraft Subscription or Game Time.' US shop prices: Skyborne Heroic Pack $29.99, Skyborne Epic Pack $59.99 (adds beta access and 30 days of Game Time from Nov 4), Warcraft Forever Collection $79.99 (adds Warcraft III: Reforged and the Forsaken Kingdom campaign; on sale through Jan 11, 2027). There is also a physical Collector's Edition. Invite-A-Friend launch codes work Nov 4-11, 2026.

Sources: <https://news.blizzard.com/en-us/article/24301508/pre-purchase-world-of-warcraft-forever-upgrades-and-begin-your-next-journey-in-azeroth>, <https://us.shop.battle.net/en-us/product/world-of-warcraft-forever>, <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>

#### Launch is a single global moment: 2026-11-04 at 3:00 p.m. PST (23:00 UTC). The beta has ended. Early Name Reservation is running now (Oct 27 - Nov 3).

Confidence: high. Relevance: Release planning and testing. As of 2026-10-30 there is no beta to test in; the live client is downloadable now (see the client finding).

Local launch times: Americas 3:00 p.m. PST Nov 4; Brazil 8:00 p.m. BRT Nov 4; UK 11:00 p.m. GMT Nov 4; Europe 12:00 a.m. CET Nov 5; Taiwan 7:00 a.m. CST Nov 5; Korea 8:00 a.m. KST Nov 5; ANZ 10:00 a.m. AEDT Nov 5. Beta: Sep 17 - Oct 21, 2026 PST. Stress test: Oct 21. Name reservation opened at EU 27 Oct 18:00 CET, NA 27 Oct 1:00 p.m. PDT, and KR/TW 28 Oct 07:00, for up to three characters total across all rulesets, first-come first-served. Raids open Dec 9. Hardcore comes 'sometime after launch'.

Sources: <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <https://news.blizzard.com/en-us/article/24301508/pre-purchase-world-of-warcraft-forever-upgrades-and-begin-your-next-journey-in-azeroth>, <https://news.blizzard.com/en-gb/article/24303866/world-of-warcraft-forever-early-name-reservations-are-now-live>, <https://news.blizzard.com/en-us/article/24304160/the-world-of-warcraft-forever-beta-now-live>

#### Global regions are Americas & Oceania, Europe, Korea and Taiwan. China runs separately under NetEase as 《魔兽世界：无限》 and launches 2026-11-05, Beijing time.

Confidence: high. Relevance: Locale planning (CN is the only zhCN market) and the scope of shared-fiction communication (region-wide names).

Shop 'Available Regions': 'Americas & Oceania', 'Europe', 'Korea', 'Taiwan'. Internal SKUs are tagged '(US/EU/KR/TW)'. The China page wow.blizzard.cn says '11月5日全球同步上线' (simultaneous worldwide launch Nov 5) and lists a CN beta from 2026-10-06. Tencent News reports the CN beta ran to about Oct 27, CN pre-order packs at 388 / 218 RMB, and that 'retail-framework addon restrictions are expected to apply'. The CN CDN host for the 'wowf' product is blzdist-wow.necdn.leihuo.netease.com. Localized registry names in the product config: KR '월드 오브 워크래프트: 포에버', TW '魔獸世界：永恆', CN '魔兽世界:"无限"'.

Sources: <https://us.shop.battle.net/en-us/product/world-of-warcraft-forever>, <https://wow.blizzard.cn/h5/20260913/friend/>, <https://news.qq.com/rain/a/20260913A03KMM00>, <https://us.version.battle.net/v2/products/wowf/versions>, <https://level3.ssl.blizzard.com/tpr/configs/data/2c/ed/2ced73c17301c297ca062bc7c3583420>

#### In the Battle.net app, Forever is not a separate game tile. It is a 'Game Version' under World of Warcraft, with its own NGDP/TACT product code 'wowf' and its own install subfolder '_forever_'.

Confidence: high. Relevance: Windows dev setup (owner chose Windows): install path, folder for symlinking the addon, ARM64 build.

Blizzard: 'In the Game Version menu above the Play button, select World of Warcraft: Forever, then select Install.' (The beta was listed as 'World of Warcraft: Forever Beta' under 'In Development'.) The product config for wowf says: "product":"wowf", title_id "wow" (wowf appears in products_in_title next to wow, wowt, wow_classic and others), "shared_container_default_subfolder":"_forever_". Binaries are Wow.exe and Wow-arm64.exe on Windows and 'World of Warcraft.app' on Mac. Minimum OS is Windows 10.0.0.18362 or macOS 12.0, with 128 GB required space and supports_multibox true. Live versions on 2026-10-30: us/kr/tw/cn 1.60.1.70707, eu 1.60.1.70685; retail 'wow' is 12.1.5.70575. On Windows, addons should therefore go in <WoW install>\_forever_\Interface\AddOns and SavedVariables in _forever_\WTF; this follows from the standard shared-container layout (Interface and WTF are in the move list).

Sources: <https://news.blizzard.com/en-us/article/24303866/claim-your-world-of-warcraft-forever-character-names>, <https://news.blizzard.com/en-us/article/24304160/the-world-of-warcraft-forever-beta-now-live>, <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>, <https://us.version.battle.net/v2/products/wowf/versions>, <https://level3.ssl.blizzard.com/tpr/configs/data/2c/ed/2ced73c17301c297ca062bc7c3583420>

#### Forever has its own version line (1.60.x, TOC 16001) but is built from the same Mainline codebase as Midnight. The concept doc's claim that it 'runs on the Midnight retail client' is therefore partly true: it is a separate client and install that shares Midnight's UI architecture and almost all of its API.

Confidence: high. Relevance: Core architecture. Ashmark uses modern Mainline APIs and templates (PortraitFrameTemplate, ScrollBox, Settings API), not Classic Era APIs. Future Midnight API changes will likely also land in Forever.

Blizzard, quoted on the wiki from WoWUIDev on 2026-09-15: 'WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5 ... Forever and modern WoW (Midnight) are two game types within the Mainline code family: Camelot (to be renamed before launch) and Standard, respectively.' The TOC page adds that 1.60.1 'Includes all Modern changes up to 12.1.5'. Diff from 12.1.5 (69952) to 1.60.1 (70205): 176 global APIs added and 10 removed; 471 FrameXML functions added and 1041 removed; 24 events added and 2 removed. Midnight 12.1.7 'Includes API changes from Patch 1.60.1'. Blizzard also says: 'you can expect similar UI changes in the future to be introduced to both Standard and Forever.'

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Patch_12.1.7/API_changes>, <https://warcraft.wiki.gg/wiki/Public_client_builds>

#### Midnight's addon restrictions, including secret values, are officially active in Forever, and Forever adds restrictions of its own. The concept doc's claim that Blizzard 'aligned addon restrictions with Midnight' is confirmed. The combat log being locked is very likely by inheritance, but no source states it for Forever.

Confidence: high. Relevance: Module 4 (unit names may be secret values in instances or combat), module 2 (behaviour must come from events other than CLEU), and the rumours module (no addon messages from trial accounts; chat hardware-event rules).

Blizzard: 'The addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever.' Forever 1.60.1 additions: a new FrameStrata secret aspect (GetFrameStrata returns a secret value); 'Trial accounts can no longer send addon messages'; SendChatMessage with 'EMOTE' needs a hardware event outside instances (as SAY/YELL already do); minimap rotation is blocked during encounters. Build 70425 replaced the server-ID and spawn-ID parts of creature, vehicle, pet and game-object GUIDs with obfuscated values 'to prevent comparison to determine layer'; player GUIDs are not in that list. COMBAT_LOG_EVENT_UNFILTERED 'is no longer accessible to addons in Midnight since Patch 12.0.0'; the wiki lists the event for forever 1.60.1 with no Forever-specific note.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT_UNFILTERED>

#### TOC and game-type facts: Interface 16001, game type 'camelot' with alias 'forever', file suffixes _Forever.toc and _Camelot.toc, Mainline family, WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18). Classic-family TOCs are not used on Forever.

Confidence: high. Relevance: Ashmark's TOC setup and enforcing Forever-only loading. Addon Compartment is available.

The Forever Beta and Forever Test rows on the TOC page both show 16001 (the live 'Forever' row is blank). The 'forever' alias was added in 1.60.1 build 70291 (2026-10-07). Families: Mainline = standard, forever, camelot, plunderstorm, wowhack (suffix _Mainline.toc); Classic = vanilla, tbc, wrath, cata, mists (_Classic.toc). The wiki's example for loading only on Forever is '## AllowLoadGameType: forever' plus '## ExcludeLoadGameType: standard, classic'; the exclude line is needed because unrecognized game types load anyway on 12.1.5 and classic clients. Interface-range check: 'version > 16000 and version < 20000'. The '[Game]' variable expands to 'Camelot'; 12.1.7 stops expanding [Game] and [Family] in TOC directives. Addon Compartment directives (AddonCompartmentFunc etc.) are documented as working on Midnight and Forever. CurseForge has a 'Forever' flavor with game version '1.60.1'. Interface numbers for comparison: Midnight 120105, Classic Era 11509.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/Patch_12.1.7/API_changes>, <https://www.curseforge.com/wow/addons/foreverlfg>

#### The 'Classic look vs modern look' is a first-login Experience Preset (Classic or Enhanced), plus a per-character choice of SD or HD models.

Confidence: high. Relevance: Main window styling. Ashmark should look right under both presets and could read the preset to match Classic vs Enhanced styling. Anchoring to the reskinned unit frames is fragile.

Classic preset: Standard Definition models, quest points of interest and objective blobs off, one-bag off, transmog off, camera-turning keybinds, 'Classic screen UI layout'. Enhanced preset: HD models, POI on, one-bag on, transmog on, strafe keybinds, 'Centralized screen UI layout'. The preset is chosen before the ruleset and can be changed under Game Menu > Options; the SD/HD choice can be changed in Options or at a Barbershop. Related API: C_GameRules.GetForeverExperiencePreset/SetForeverExperiencePreset, C_GameRules.IsSDHDToggleEnabled/SetSDHDToggleValue/AccountHasSDEnabled. CVars: hasSelectedExperiencePreset ('Classic or Modern'), classicStyleWorldText. Build 70425 reskinned the Forever player, target, pet, target-of-target, totem and focus frames and the minimap header. Edit Mode exists, with layouts saved per UI type.

Sources: <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>

#### Rulesets replace realms: Normal, PvP, Roleplay and Roleplay-PvP at launch, Hardcore later. Each ruleset is a region-wide 'ecosystem' with no realm selection. Layering ('world instances') exists.

Confidence: high. Relevance: Module 3 (world state is shared across layers within a ruleset), the rumours module (addon-message audience is ruleset- and faction-scoped), and RP-ruleset flavour for the identity module.

Blizzard: 'Each ruleset functions more like a broad player ecosystem than a single traditional realm'; 'Cross-ruleset grouping is not supported'; 'Battlegrounds may include players from other rulesets, with the exception of Hardcore'; 'Players cannot freely hop between rulesets'; a dead Hardcore character 'can transfer to another ruleset'. The phrase 'one mega-realm per ruleset per region' appears only on warcraft.wiki.gg, without a citation; Blizzard says 'realmless Azeroth'. Ruleset check: C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset / RPRuleset / PvPRuleset). Other new APIs: C_GameRules.IsHardcoreActive, IsSelfFoundAllowed, C_CharacterServices.IsRealmlessRealmSelectionEnabled, Get(Hardcore|PaidCharacter)TransferSuperDistrictDestinations. Layer evidence: SHARD_TRANSFER and SHARD_TRANSFER_IMMINENT events; dev note 'changing party composition may transfer players to a different world instance'.

Sources: <https://worldofwarcraft.blizzard.com/en-us/news/24302070/>, <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <https://warcraft.wiki.gg/wiki/Patch_1.60>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>

#### Each character has two names: a main (first) name and a secondary name (surname). Only the full combination must be unique within a region, so any number of characters, including other players' characters, can share a surname.

Confidence: high. Relevance: Module 5 (House): a shared surname is NOT proof of a family. Strangers can use the same surname, so a House must be built from the account's own characters, not by surname matching alone. Module 4: player keys should use the full two-part name, parsed with NameUtil helpers.

Starter guide: 'WoW: Forever uses a two-name system: a main name and a secondary name.' 'The complete combination must be unique within your region.' Naming article: 'Asha Brightvale, Thalen Brightvale, and Mira Brightvale could share the same family-style second name'; first names can be reused. Hiding it: Options > Nameplates > 'My Secondary Name' (CVar UnitSurnameOwn, default 1, Account scope, 'show player surname over head'); 'it will still appear in chat'. New APIs: C_PlayerInfo.ShouldDisplaySurname() returns a boolean, C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator, RegionalUniqueNamesEnabled, and FrameXML NameUtil.SplitPlayerNameIntoParts / GetUnitFirstName / GetFullNameWithoutRealm / FormatUnitNameForDisplay / GetUnmodifiedUnitFullName. My inference: the surname seems to live inside one name string with a 'surname separator', not as a separate field. Dev notes: fixed mail ignoring surnames (Sep 24) and loot rolls not showing the full name (Oct 1).

Sources: <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>, <https://news.blizzard.com/en-us/article/24304161/create-a-name-of-your-own-in-wow-forever>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>

#### Supported client languages: exactly the 10 languages listed on the Battle.net shop. There is no Italian. Simplified Chinese (zhCN) exists only as a client locale for the China/NetEase region and is not sold on the global shop.

Confidence: high. Relevance: Localization scope for all modules. Drop itIT; zhCN is optional (CN market only).

Shop 'Available Languages' for title 5730135|19 'World of Warcraft: Forever' (same on the us en-us, eu en-gb and eu de-de pages): English (US), Español (AL), Português (BR), English (EU), Deutsch, Español (EU), Français, Русский, 한국어, 繁體中文. The same page lists Midnight (5730135|18) with those plus Italiano (11 languages). wowf product config supported_locales: enUS, deDE, esES, esMX, frFR, ruRU, koKR, ptBR, zhTW, zhCN; the cn region display_locales is [zhCN]. Retail 'wow' includes itIT; Classic Era, like Forever, does not. GetLocale codes: enUS, koKR, frFR, deDE, zhCN, esES, zhTW, esMX, ruRU, ptBR, itIT. 'enGB clients return enUS', so English (EU) has no locale code of its own. Locales Ashmark should cover: enUS, deDE, esES, esMX, frFR, ruRU, koKR, ptBR, zhTW, plus zhCN if China matters.

Sources: <https://us.shop.battle.net/en-us/product/world-of-warcraft-forever>, <https://eu.shop.battle.net/de-de/product/world-of-warcraft-forever>, <https://level3.ssl.blizzard.com/tpr/configs/data/2c/ed/2ced73c17301c297ca062bc7c3583420>, <https://level3.ssl.blizzard.com/tpr/configs/data/53/02/53020d32e1a25648c8e1eafd5771935f>, <https://warcraft.wiki.gg/wiki/API_GetLocale>

#### 'Preferred Online Language' is an account-wide setting with a 24-hour cooldown that lets players 'encounter others who share that preference'.

Confidence: medium. Relevance: Module 4 and rumours: groups and campfire partners may cluster by language. Shared fiction could be tagged with locale. Exact semantics still need in-game testing.

Path: Game Menu (Esc) > Options > Languages and Social (under System) > 'Preferred Online Language'. 'This account-wide setting applies to all characters and has a 24-hour cooldown before it can be changed again.' Blizzard does not list the selectable languages. APIs added in 1.60.1: C_AccountServices.GetPreferredLocales, GetPreferredDatacenterLocalities, GetPreferredPlaySettings, SetPreferredPlaySettings, RequestPreferredPlaySettings, GetPreferredPlaySettingsFeatures; guild versions C_GuildInfo.Get/Set/RequestPreferredPlaySettings with the event GUILD_PREFERRED_PLAY_SETTINGS_UPDATED.

Sources: <https://worldofwarcraft.blizzard.com/en-us/news/24302070/>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

#### There is no retail-style automated Dungeon Finder. Forever uses a Classic-style 'Group Finder' / 'Looking For Group' listing tool.

Confidence: high. Relevance: Module 4 needs redesign: there are no Dungeon Finder groups. Remembered companions should come from group rosters (GROUP_ROSTER_UPDATE), LFG listings, campfires and guilds.

Compared with 12.1.5, the 1.60.1 FrameXML removes LFDFrame_*, LFDQueueFrame_* (including LFDQueueFrame_SetTypeRandomDungeon), GroupFinderFrame_* and about 185 retail LFGList* functions. It adds LFGBrowse_*, LFGListing*, LFGParentFrameTab1-3_OnClick, LFGVanilla_ShowFrame/ToggleFrame, GroupFinderVanillaStyle_LoadUI, C_LFGListRoles.GetRoles/GetSavedRoles/SetRoles, and the events LFG_LIST_ROLE_UPDATE and LFG_LIST_SHOW_SEARCH. Blizzard dev notes mention 'Group Finder postings' (with In-Game Voice Mode), the 'Looking For Group UI', and a 'Show All Level Ranges' checkbox. Design pillar: 'community building over auto-matchmaking'. Players on the forums describe it as 'a listing system' with whisper and invite and no queue or teleport. I found no single Blizzard sentence saying 'no dungeon finder'.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>, <https://us.forums.blizzard.com/en/wow/t/the-group-finder-in-forever-is-just-worse-than-the-modern-one/2362755>, <https://warcraft.wiki.gg/wiki/Patch_1.60>

#### No cross-faction play: grouping, guilds, dungeons and raids require the same ruleset AND the same faction. On the PvP ruleset an account can only have characters of one faction.

Confidence: high. Relevance: Module 5: a House on the PvP ruleset is single-faction. Rumours: addon-message reach is limited to same-faction players. Module 4: companions are always the same faction.

Starter guide: 'Characters can group, join guilds, run dungeons, and raid only with players on the same Ruleset and faction.' Ruleset article: 'Horde and Alliance players still cannot group together'; 'On the PvP ruleset, players can only create characters for one faction.' Normal, RP and Hardcore allow both factions on one account. C_PvP.IsWarModeFeatureEnabled returns false in Forever. Skyborne choose a faction at character creation. Dev note Oct 16: Horde are attacked on sight in Dalaran and can no longer gain Kirin Tor reputation.

Sources: <http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever>, <https://worldofwarcraft.blizzard.com/en-us/news/24302070/>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>

#### Forever adds new Gelkis and Magram quests in Desolace, starting with 'Valley of Bones', with a minimum level of 35.

Confidence: high. Relevance: Module 1 pilot: Blizzard itself expanded the Gelkis/Magram content. Ashmark must find out which quests are Blizzard's mutually exclusive ones before layering its own.

Dev notes, Oct 8, 2026: 'The new quests for the Gelkis and the Magram beginning with "Valley of Bones" now require a minimum level of 35 (was 30).' Rewards that were tuned: Blade of the Magram Clan, Centaur Spear, Ceremonial Centaur Blanket, Scavenged Magram Armament (equip requirement hotfixed to level 35).

Sources: <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>

#### Camping is an official Forever system: Cooking's Basic Campfire becomes a shared campsite that others can join.

Confidence: high. Relevance: Module 6 (campfire as chapter boundary) can hook into the official campsite system and its buff auras. Module 4: campsite companions are natural 'remembered' people.

'The Camping system in World of Warcraft: Forever turns the Cooking profession's Basic Campfire into a shared campsite.' 'Nearby players can contribute up to three profession-crafted Camp Features, with each player adding one.' Sitting or crafting at the campsite for at least one minute grants benefits, 'including buffs that are mutually exclusive with their corresponding class buffs'. Dev notes: the campfire buff also works while sitting in a chair, sleeping, lying down or kneeling; campfires no longer damage players below level 5; there is a 'Boosted Rest' debuff. The wiki says camping unlocks around level 5 and tradeskill camp buffs start at skill 20.

Sources: <https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>, <https://warcraft.wiki.gg/wiki/Patch_1.60>

Contradictions:

- Beta end date: Blizzard says the beta ran 'through October 21, the last full day of testing' (https://news.blizzard.com/en-us/article/24304160/the-world-of-warcraft-forever-beta-now-live) and 'September 17 to October 21, 2026, PST' (https://news.blizzard.com/en-us/article/24301508/pre-purchase-world-of-warcraft-forever-upgrades-and-begin-your-next-journey-in-azeroth). warcraft.wiki.gg lists an end-of-beta event on Oct 22 and 'Beta, until 2026-10-23 17:00' (https://warcraft.wiki.gg/wiki/Patch_1.60).
- Hardcore timing: Blizzard says only 'sometime after launch' (https://worldofwarcraft.blizzard.com/en-us/news/24302070/). warcraft.wiki.gg says 'Winter 2026/27' (https://warcraft.wiki.gg/wiki/Patch_1.60). Tencent News says Q4 (https://news.qq.com/rain/a/20260913A03KMM00).
- Realm terminology: warcraft.wiki.gg says players are split 'on one mega-realm per ruleset per region', with no citation (https://warcraft.wiki.gg/wiki/Patch_1.60). Blizzard never says 'mega-realm'; it says 'realmless Azeroth' and that each ruleset is 'a broad player ecosystem rather than a single traditional realm' (https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4, https://worldofwarcraft.blizzard.com/en-us/news/24302070/).
- Preset naming: Blizzard calls the two presets 'Classic' and 'Enhanced' (http://worldofwarcraft.blizzard.com/en-us/news/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever). The client CVar hasSelectedExperiencePreset is described as 'Classic or Modern' (https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes).
- Beta access: Warcraft Tavern says beta access was 'included with an active WoW subscription or game time' (https://www.warcrafttavern.com/forever/news/warcraft-forever-classic-announced-at-blizzcon-2026/). Blizzard says access came through opt-in selection or the Epic Pack / Warcraft Forever Collection (https://news.blizzard.com/en-us/article/24304160/the-world-of-warcraft-forever-beta-now-live).
- China launch date: wow.blizzard.cn says '11月5日全球同步上线' (simultaneous worldwide launch Nov 5) (https://wow.blizzard.cn/h5/20260913/friend/). Gamersky's article body says 11月4日 (Nov 4) while its metadata says 2026-11-05 (https://www.gamersky.com/news/202609/2208538.shtml). Both describe the same moment, Nov 4 23:00 UTC.

### Addon API

#### Forever has its own TOC suffixes: _Forever.toc and _Camelot.toc. It is also in the 'mainline' family, so _Mainline.toc applies to it. A game-specific suffix takes priority over a family suffix, which takes priority over a bare AddOnName.toc.

Confidence: high. Relevance: TOC/packaging for all modules; guarantees Ashmark loads only on Forever

Game suffixes: _Standard (Midnight), _Forever and _Camelot (Forever), _Mists, _Cata, _Wrath, _TBC, _Vanilla, _Plunderstorm/_WoWLabs, _WoWHack. Family suffixes: _Mainline (standard, forever, camelot, plunderstorm, wowhack) and _Classic (vanilla, tbc, wrath, cata, mists). The wiki says 'Family suffixes have a lower priority'. Footnote: 'The Camelot value may be changed to Forever in the future.' The 'forever' alias for TOC suffixes, the [Game] variable and game-type folder lookup was added in Forever beta build 70291 (Oct 7/8, 2026). A shipped Forever addon (HandyNotes Forever Instances) uses only HandyNotes_ForeverInstances_Camelot.toc. Recommendation: ship Ashmark_Forever.toc. Also ship _Camelot.toc as a fallback in case a client lacks the alias. Do not ship _Mainline.toc, because it would also load on Midnight.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://www.curseforge.com/wow/addons/forever-instances-dungeons-raids>

#### The interface number is 16001 for Forever Beta and Forever Test (patch 1.60.1, latest build 70532, dated 2026-10-20). No value is published for the live release client yet.

Confidence: high. Relevance: TOC ## Interface line; release checklist

TOC_format table: Forever Beta 16001, Forever Test 16001, Forever (release) left blank. The GetBuildInfo Latest Builds table and Public client builds both list 1.60.1 / 70532 / 2026-10-20 / 16001 for Beta and Test, with nothing marked live. For comparison: Midnight Standard 120105, Standard Test 120107, Vanilla 11509. The wiki notes the values are 'maintained by contributors'. Build 70630 (Oct 26/27) is mentioned only by third parties. Use '## Interface: 16001' and check in-game with /dump select(4, GetBuildInfo()) after launch on Nov 4, 2026.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/API_GetBuildInfo>, <https://warcraft.wiki.gg/wiki/Public_client_builds>

#### AllowLoadGameType and ExcludeLoadGameType take the game types standard, forever, camelot, mists, cata, wrath, tbc, vanilla, plunderstorm and wowhack, plus the families mainline and classic. Both work as file-level directives and as inline [..] conditions.

Confidence: high. Relevance: TOC; preventing Ashmark from loading on Midnight or Classic

Example from the wiki 1.60.1 page: '## AllowLoadGameType: forever' plus '## ExcludeLoadGameType: standard, classic'. Inline form: 'MyFile.lua [AllowLoadGameType forever][ExcludeLoadGameType standard, classic]'. Per-flavor metadata: '## Title: My title for Forever [AllowLoadGameType forever]'. Warning from the TOC page: if at least one game type is given and the client recognizes none of them, the condition is still satisfied, so always pair the directive with ExcludeLoadGameType. Other TOC facts on that page: the Bootstrap inline directive and the RegionalTextLocale variable are supported in Forever. Midnight 12.1.7 'Prevented use of variables in addon directives', so a '## X-Game: [Game]' style variable may stop working once Forever takes changes past 12.1.5. AddonCompartmentFunc, Category, Group, IconTexture/IconAtlas and LoadSavedVariablesFirst are documented for mainline and not marked as excluded from Forever.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

#### Forever's project constant is WOW_PROJECT_CAMELOT = 18. There is no WOW_PROJECT_FOREVER constant. Builds before 70170 (Oct 1, 2026) wrongly returned WOW_PROJECT_ID = 1, the Mainline value.

Confidence: high. Relevance: Runtime flavor guard in the Ashmark core

WOW_PROJECT_ID table: 1 MAINLINE, 2 CLASSIC, 3 WOWLABS, 5 BURNING_CRUSADE_CLASSIC, 11 WRATH_CLASSIC, 14 CATACLYSM_CLASSIC, 18 CAMELOT ('World of Warcraft: Forever'), 19 MISTS_CLASSIC. Added in Patch 1.60.1 and defined in Camelot ProjectConstants.lua. 1.60.1 notable changes: '70170 (Oct 1): Added WOW_PROJECT_CAMELOT (18)'. wowforeverguides (an SEO site) reports build 69913 returning 1 and build 70338 returning 18.

Sources: <https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://wowforeverguides.com/addons/api-cheatsheet>

#### Blizzard-documented ways to detect Forever at runtime: WOW_PROJECT_ID == WOW_PROJECT_CAMELOT; an interface range check on GetBuildInfo(); or the X-Game metadata value 'Camelot'. C_GameRules.GetActiveGameMode() cannot be used, because it has no Forever value.

Confidence: high. Relevance: Core bootstrap guard; RP-ruleset awareness for the identity, rumour and silent-shared-fiction modules

Code from the wiki: 'if WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then -- forever end'; 'local version = select(4, GetBuildInfo()); if version > 16000 and version < 20000 then -- forever end'; '## X-Game: [Game]' plus 'C_AddOns.GetAddOnMetadata("MyAddOn", "X-Game") == "Camelot"'. GetBuildInfo returns buildVersion, buildNumber, buildDate, interfaceVersion, localizedVersion, buildInfo, e.g. '1.60.1', '70532', ..., 16001. Enum.GameMode for C_GameRules.GetActiveGameMode has only 1 Standard, 2 Plunderstorm, 3 WoWHack. Ruleset detection: C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset = 10, RPRuleset = 214, PvPRuleset = 213), otherwise PvE.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/API_GetBuildInfo>, <https://warcraft.wiki.gg/wiki/API_C_GameRules.GetActiveGameMode>, <https://warcraft.wiki.gg/wiki/API_C_GameRules.IsGameRuleActive>, <https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnMetadata>

#### Correction to the concept doc: Forever is not 'the Midnight retail client'. It is a separate client and game type (Camelot/Forever, version 1.60.1, interface 16001, project ID 18, own _forever_ folder) built from the same Mainline UI code, and Midnight's addon restrictions, including secrets, are active in it.

Confidence: high. Relevance: Concept doc correction; overall platform assumptions

Developer statement dated 2026-09-15, 'An Update On Secrets In WoW: Forever' (a WoWUIDev Discord post, recorded on the wiki): 'WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5.' Forever (Camelot, to be renamed) and Midnight (Standard) are 'two game types in the same code family.' 'The addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever.' The 12.1.0 AuraContainer/AuraButton changes also apply. The 1.60.1 patch is labelled 'Includes all Modern changes up to 12.1.5'. The kami-labs.fr article (Kami, 16 Sep 2026) only says restrictions match retail and the API is 'one-for-one'. It does NOT say Forever runs on the retail client, and it never mentions the combat log. It attributes the alignment to a Warcraft Tavern interview, not a blue post. Blizzard's Midnight article says Blizzard tried 'to avoid interfering with access to non-combat information'.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/TOC_format>, <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>, <https://news.blizzard.com/en-us/article/24244638/how-midnights-upcoming-game-changes-will-impact-combat-addons>

#### On Windows the live Forever client installs into 'World of Warcraft\_forever_\', with addons in Interface\AddOns and settings in WTF. The beta used '_classic_beta_'.

Confidence: high. Relevance: Dev setup on Windows (user confirmed Windows); distribution via CurseForge

CurseForge blog (Oct 25, 2026, Niv Hajaj): copy Interface and WTF from 'World of Warcraft\_classic_beta_' to 'World of Warcraft\_forever_'. Under WTF\Account, rename the beta account folder to the live account name. A nested Interface\Interface folder hides addons. SavedVariables path per the TOC page: WTF\[account]\SavedVariables\MyAddOn.lua. CurseForge has a separate 'Forever' flavor with game version 1.60.1 (seen on UpQuest Forever, Forever Visuals and LFG Forever).

Sources: <https://blog.curseforge.com/wow-forever-migrate-addons-beta-to-live/>, <https://warcraft.wiki.gg/wiki/TOC_format>, <https://www.curseforge.com/wow/addons/upquest-forever>, <https://www.curseforge.com/wow/addons/forevervisuals>

#### Classic Era addons and Classic-style global APIs do not carry over. Forever uses the Mainline (C_*) API surface: global GetSpellInfo, GetItemInfo, UnitMaxHealth and GetItemStats are reported missing, and GetFactionInfo and GetQuestLogTitle are not listed for Forever.

Confidence: medium. Relevance: All modules: write against the C_* Mainline API, not Classic Era globals

Forever is a mainline-family game type, so _Vanilla/_Classic/_TBC TOC files are never chosen. Per the TOC page, an addon whose Interface does not match the client is 'out-of-date'. Beta testers report nil for GetSpellInfo, GetItemInfo and UnitMaxHealth (Blizzard forum, Oct 18, 2026, player posts) and for GetItemStats (same thread). SEO guides list replacements: C_Spell.GetSpellInfo, C_Item.GetItemInfo, C_Spell.RequestLoadSpellData, C_Item.RequestLoadItemDataByID. The wiki's GetFactionInfo page lists retail only up to 11.0.0 plus the Classic flavors, not Forever. C_Item.GetItemStats is listed for Forever 1.60.1. The 1.60.1 Global API diff shows 176 added and 10 removed, including AbandonSkill, BNSetBlocked, GetPetFoodTypes and SetBarSlotFromIntro.

Sources: <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-addon-feedback/2385926>, <https://wowforeverguides.com/addons/api-cheatsheet>, <https://warcraft.wiki.gg/wiki/API_GetFactionInfo>, <https://warcraft.wiki.gg/wiki/API_C_Item.GetItemStats>, <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

#### The combat log is effectively closed to addons on Forever. Mainline since 12.0.0 refuses COMBAT_LOG_EVENT / COMBAT_LOG_EVENT_UNFILTERED registration with ADDON_ACTION_FORBIDDEN, and the wiki does not list CombatLogGetCurrentEventInfo for Forever.

Confidence: medium. Relevance: Module 2 (behaviour-derived identity) must not rely on the combat log; module 6 (camping chapters)

CLEU page: 'This event is no longer accessible to addons in Midnight since Patch 12.0.0' and 'Fires ADDON_ACTION_FORBIDDEN when attempting to register this event.' 12.0.0 summary: 'COMBAT_LOG_EVENT and COMBAT_LOG_EVENT_UNFILTERED will error when trying to register them.' CombatLogGetCurrentEventInfo is 'deprecated in patch 12.0.0' and its availability data lists Standard 8.0.1-12.0.0, Mists, TBC and Vanilla, but not Forever. C_CombatLog.IsCombatLogRestricted() exists in Forever 1.60.1. Because Forever includes all Modern changes up to 12.1.5, the 12.0.0 lock applies. wowforeverguides reports the reader is unavailable on Forever and marks this unverified. Community GitHub reports (not opened) say registering also taints the addon for the rest of the session. Ashmark must never register CLEU. Use PARTY_KILL, PLAYER_DEAD, UNIT_* and quest/loot events instead.

Sources: <https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT_UNFILTERED>, <https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes>, <https://warcraft.wiki.gg/wiki/API_CombatLogGetCurrentEventInfo>, <https://warcraft.wiki.gg/wiki/API_C_CombatLog.IsCombatLogRestricted>, <https://wowforeverguides.com/addons/patterns>

#### The secret-values API is present in Forever 1.60.1: issecretvalue, issecrettable, canaccessvalue, canaccesstable, the C_Secrets predicate functions, and the C_RestrictedActions state API with Enum.AddOnRestrictionType.

Confidence: high. Relevance: Core safety layer; modules 2, 4 and 6 must guard every unit, aura and chat value

Global tests: issecretvalue(value), issecrettable(t), canaccessvalue(v), canaccesstable(t). The 12.0.0 list also has secretwrap, scrubsecretvalues, canaccesssecrets, canaccessallvalues, dropsecretaccess, hasanysecretvalues, mapvalues, securecallmethod, FrameScriptObject:HasSecretValues/HasSecretAspect/SetPreventSecretValues. C_Secrets includes ShouldUnitIdentityBeSecret(unit), ShouldAurasBeSecret(), ShouldCooldownsBeSecret, ShouldUnitHealthMaxBeSecret, ShouldUnitSpellCastBeSecret, ShouldUnitComparisonBeSecret, HasSecretRestrictions and GetSpellAuraSecrecy. Restriction state: C_RestrictedActions.IsAddOnRestrictionActive(type), C_RestrictedActions.GetAddOnRestrictionState and C_RestrictedActions.CheckAllowProtectedFunctions, plus event ADDON_RESTRICTION_STATE_CHANGED. Enum.AddOnRestrictionType: 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat (12.0.5). Rules for tainted code: no arithmetic, comparisons, boolean tests on boolean secrets, '#', indexing, calling, or use as table keys. Storing, passing, concatenating and string.format are allowed; type() returns the real type. Test CVars (not saved): addonCombatRestrictionsForced, addonEncounterRestrictionsForced, addonMapRestrictionsForced, addonChatRestrictionsForced, addonPvPMatchRestrictionsForced, addonChallengeModeRestrictionsForced. Forever beta 4 added a 'FrameStrata' secret aspect, so GetFrameStrata can return a secret.

Sources: <https://warcraft.wiki.gg/wiki/Secret_values>, <https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes>, <https://warcraft.wiki.gg/wiki/API_issecretvalue>, <https://warcraft.wiki.gg/wiki/API_C_Secrets.ShouldAurasBeSecret>, <https://warcraft.wiki.gg/wiki/API_C_Secrets.ShouldUnitIdentityBeSecret>, <https://warcraft.wiki.gg/wiki/API_C_RestrictedActions.IsAddOnRestrictionActive>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>

#### Unit names are secret only when unit identity is restricted. That happens when the unit is neither player-controlled nor in your party/raid (with a PvP exception), so party and raid members' names should stay readable, including inside instances.

Confidence: medium. Relevance: Module 4 (remembered group members): snapshot names on GROUP_ROSTER_UPDATE outside combat and guard with issecretvalue

UnitName / UnitFullName / UnitNameUnmodified predicates: AllowedWhenTainted, SecretWhenUnitNameIdentityRestricted (12.1.0, 'Regular unit identity rules, except in PvP when the queried unit is a player'). SecretWhenUnitIdentityRestricted (12.0.0): secret 'when the unit isn't player-controlled or in your party/raid'. Compound tokens are secret if any link fails. The Secret Values page says UnitName returns secrets 'for non-player or pet units in combat'. SecretWhenUnitComparisonRestricted makes unit-token comparisons secret on addon-restricted maps, and compound tokens such as 'boss1target' are always secret. Check with C_Secrets.ShouldUnitIdentityBeSecret(unit) before storing a name. UnitName('player') returning 'Unknown' before PLAYER_LOGIN was fixed in build 70170. Beta testers report that the UNIT_SPELLCAST_SENT target is secret, and that UnitGUID/UnitIsUnit return nil for it.

Sources: <https://warcraft.wiki.gg/wiki/API_UnitName>, <https://warcraft.wiki.gg/wiki/Secret_values>, <https://warcraft.wiki.gg/wiki/API_C_Secrets.ShouldUnitIdentityBeSecret>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-addon-feedback/2385926>

#### Chat events carry the SecretInChatMessagingLockdown predicate. During a chat lockdown the sender name, text and GUID of CHAT_MSG_* events become secret, and C_ChatInfo.InChatMessagingLockdown() reports the lockdown. Both exist in Forever 1.60.1.

Confidence: high. Relevance: Module 4 (familiar faces from instance chat); rumours module

CHAT_MSG_PARTY: predicates SecretInChatMessagingLockdown and SynchronousEvent. NeverSecret fields are languageName, channelName, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, isMobile, isSubtitle, hideSenderInLetterbox and suppressRaidIcons. text, playerName, playerName2, guid and bnSenderID are NOT marked NeverSecret. SecretInChatMessagingLockdown (12.0.0) applies 'during encounter, challenge mode, or PvP restrictions, and on communication-restricted maps' (example given: a dungeon or raid). isRestricted = C_ChatInfo.InChatMessagingLockdown() returns a boolean; the lockdownReason return was removed in 12.0.5. 12.0.5 also removed C_ChatInfo.AreOutgoingAddonChatMessagesRestricted. Players report that some system notices print without firing any CHAT_MSG_* event, and that CHAT_MSG_TEXT_EMOTE has an empty author field for built-in emotes.

Sources: <https://warcraft.wiki.gg/wiki/CHAT_MSG_PARTY>, <https://warcraft.wiki.gg/wiki/Secret_values>, <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.InChatMessagingLockdown>, <https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-addon-feedback/2385926>

#### C_ChatInfo.SendAddonMessage exists in Forever. Limits: prefix up to 16 characters, message up to 255 characters, a per-prefix throttle of 10 messages regenerating at 1 per second, and result codes including AddOnMessageLockdown. Forever trial and veteran accounts cannot send addon messages at all.

Confidence: high. Relevance: Rumours / silent shared fiction; module 4 handshake between Ashmark users

Signature: result = C_ChatInfo.SendAddonMessage(prefix, message [, chatType [, target]]); chatType defaults to 'PARTY'. chatTypes on both retail and Classic: PARTY, RAID, INSTANCE_CHAT, GUILD, OFFICER, WHISPER. 'CHANNEL' is retail-only ('Disabled on Classic'); Forever is not stated. SAY and YELL are Classic-only. Enum.SendAddonMessageResult: 0 Success, 1 InvalidPrefix, 2 InvalidMessage, 3 AddonMessageThrottle, 4 InvalidChatType, 5 NotInGroup, 6 TargetRequired, 7 InvalidChannel, 8 ChannelThrottle, 9 GeneralError, 10 NotInGuild, 11 AddOnMessageLockdown (11.1.0), 12 TargetOffline (12.0.0). A success result only means 'enqueued'. Whispers outside instanced content are exempt from the per-prefix limit. Use SendAddonMessageLogged for user-generated content; it fires CHAT_MSG_ADDON_LOGGED. Wiki: 'Forever and modern clients starting in patch 12.1.7 prohibit trial and veteran accounts from sending addon messages' (Forever beta 4, build 70291). Receiving requires C_ChatInfo.RegisterAddonMessagePrefix(prefix), which returns Enum.RegisterAddonMessagePrefixResult (0 Success, 1 DuplicatePrefix, 2 InvalidPrefix, 3 MaxPrefixes). Registrations do not persist across /reload. CHAT_MSG_ADDON payload: prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID.

Sources: <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage>, <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.RegisterAddonMessagePrefix>, <https://warcraft.wiki.gg/wiki/CHAT_MSG_ADDON>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>

#### Outgoing chat on Forever: since beta 4, SendChatMessage with 'EMOTE' outside instances needs a hardware event, the same as SAY and YELL. JoinChannelByName (custom channels) is listed for Forever.

Confidence: medium. Relevance: Rumours via a hidden custom channel; any emote automation in the camping module must be user-initiated

Beta 4 (build 70291): 'SendChatMessage with "EMOTE" outside instances now requires a hardware event, matching "SAY" and "YELL"'. JoinChannelByName(channelName [, password, frameID, hasVoice]) returns type, name. The '-' character is not allowed in channelName. It is listed for standard 12.1.5, forever 1.60.1, mists, tbc and vanilla. A player asked on the forum why addons cannot say, yell or emote in instances, with no Blizzard answer.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://warcraft.wiki.gg/wiki/API_JoinChannelByName>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-addon-feedback/2385926>

#### Item tooltip data APIs exist in Forever (C_TooltipInfo.GetItemByID). TooltipDataProcessor.AddTooltipPostCall comes from Mainline FrameXML and is very likely present, but no Forever-specific confirmation was found.

Confidence: medium. Relevance: Module 7 (character knowledge: hiding stat lines)

C_TooltipInfo.GetItemByID(itemID [, quality [, itemContext [, treasureContextLevel]]]) returns TooltipData and is listed for Standard 12.1.5 and Forever 1.60.1. TooltipDataProcessor offers AddTooltipPreCall/AddTooltipPostCall(tooltipType, func) and AddLinePreCall/AddLinePostCall(lineType, func) (wiki stub). Enum.TooltipDataType: 0 Item, 1 Spell, 2 Unit, ... 23 Quest, 27 Outfit. TooltipDataLine fields: leftText, rightText, leftColor, rightColor, type, wrapText, price, bonding, etc. No wiki statement on whether tooltip lines are secret. No TooltipDataProcessor or TooltipUtil names appear in the visible parts of the 1.60.1 FrameXML removed list (an inference, not a confirmation).

Sources: <https://warcraft.wiki.gg/wiki/API_C_TooltipInfo.GetItemByID>, <https://warcraft.wiki.gg/wiki/Tooltip_API>, <https://warcraft.wiki.gg/wiki/Enum.TooltipDataType>, <https://warcraft.wiki.gg/wiki/Structure_TooltipData>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

#### Forever itself hides stats for many items until the server reveals them. Discovery appears to be server-wide, not per character. The client shows 'Retrieving item information' until data arrives through the normal item-cache path (C_Item.GetItemInfo nil, then GET_ITEM_INFO_RECEIVED / ITEM_DATA_LOAD_RESULT).

Confidence: medium. Relevance: Module 7: Ashmark's per-character layer sits on top of Forever's server-wide reveal and must handle nil/unrevealed items

Josh Greenfield (MMORPG.com interview, reported Sep 16, 2026): 'You will not see an item's stats until it drops for you, until it drops for someone on your server.' foreverchanges.pro (aggregator, updated Oct 30, 2026): client files hold only item ID, icon, slot/type and set name. Name, quality, item level, required level, stats and effects come from the server and are cached in the WoW folder. On Sep 25 an addon requested all ~12,600 hidden items and the server answered about one third. Count: 4,928 of 12,715 revealed. API: C_Item.GetItemInfo 'returns nil if the item is not cached yet or does not exist'. GET_ITEM_INFO_RECEIVED(itemID, success): success true = queried OK, false = 'can't be queried from the server', nil = item doesn't exist. C_Item.RequestLoadItemDataByID fires ITEM_DATA_LOAD_RESULT. No Forever-specific 'discovery' API or event was found. Only aggregator and fan sites describe the mechanism; no Blizzard addon documentation.

Sources: <https://www.classicquester.com/news/item-stats-hidden-until-drop>, <https://foreverchanges.pro/hidden-items>, <https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo>, <https://warcraft.wiki.gg/wiki/GET_ITEM_INFO_RECEIVED>, <https://warcraft.wiki.gg/wiki/API_C_Item.RequestLoadItemDataByID>

#### C_Map APIs exist in Forever, and Blizzard's MapCanvas-based world map is present (Forever addons hook it and HandyNotes plugins draw pins). WorldMapFrame:AddDataProvider and MapCanvasPinMixin are not explicitly documented for Forever.

Confidence: medium. Relevance: Module 3 (world-state map layer and pins); do not key persistent pins on NPC spawn IDs

C_Map.GetBestMapForUnit(unitToken) and C_Map.GetPlayerMapPosition(uiMapID, unitToken) are listed for Forever 1.60.1. GetPlayerMapPosition is restricted and returns nil in instances ('only works outdoors'). The ForeverBeta Map Fix addon supports 'the main World Map and several Blizzard MapCanvas-based interfaces'. HandyNotes Forever Instances draws world map and minimap markers on Forever. An SEO guide claims C_Map.SetUserWaypoint works while C_SuperTrack.SetSuperTrackedUserWaypoint fails silently (unverified). No WorldMap or MapCanvas names appear in the visible 1.60.1 FrameXML removed list. Beta 5 (build 70425) obfuscates the server and spawn ID parts of creature, vehicle, pet and game-object GUIDs ('stable and unique within your own session').

Sources: <https://warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit>, <https://warcraft.wiki.gg/wiki/API_C_Map.GetPlayerMapPosition>, <https://www.curseforge.com/wow/addons/foreverbeta-map-fix>, <https://www.curseforge.com/wow/addons/forever-instances-dungeons-raids>, <https://wowforeverguides.com/addons/api-cheatsheet>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>

#### Reputation in Forever uses C_Reputation (GetFactionDataByID, GetFactionDataByIndex), not the old GetFactionInfo. Wowhead's Forever database has the pilot factions.

Confidence: medium. Relevance: Module 1 (Gelkis vs Magram, Shen'dralar)

factionData = C_Reputation.GetFactionDataByID(factionID) is listed for Standard 12.1.5 and Forever 1.60.1. FactionData fields: factionID, name, description, reaction, currentReactionThreshold, nextReactionThreshold, currentStanding, atWarWith, canToggleAtWar, isChild, isHeader, isHeaderWithRep, isCollapsed, isWatched, hasBonusRepGain, canSetInactive, isAccountWide. GetFactionInfo is not listed for Forever. 1.60.1 added C_MajorFactions.GetMajorFactionProgressionInfo and GetTotalReputationForRenownLevel and the CVar defaultReputationSortType. Wowhead Forever pages exist for faction=92 (Gelkis Clan Centaur, 'Mortal enemies of the Magram Centaur') and faction=809 (Shen'dralar), each Hated 0-36,000 through Exalted 84,000+.

Sources: <https://warcraft.wiki.gg/wiki/API_C_Reputation.GetFactionDataByID>, <https://warcraft.wiki.gg/wiki/API_GetFactionInfo>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://www.wowhead.com/forever/faction=92/gelkis-clan-centaur>, <https://www.wowhead.com/forever/faction=809/shendralar>

#### The quest API in Forever is C_QuestLog (Mainline style), and the events QUEST_DETAIL, QUEST_ACCEPTED, QUEST_TURNED_IN and QUEST_REMOVED are all listed for Forever 1.60.1.

Confidence: high. Relevance: Module 1 (mutually exclusive quests)

info = C_QuestLog.GetInfo(questLogIndex) returns QuestInfo (title, questLogIndex, questID, level, difficultyLevel, suggestedGroup, frequency, isHeader, isHidden, questClassification ...) for Forever 1.60.1. GetQuestLogTitle is not listed for Forever. 1.60.1 added C_QuestLog.GetQuestTimers, GetTrivialRange and IsEliteQuest, and the CVars showQuestLevel, showQuestDifficultyColor and instantQuestText. Event payloads: QUEST_DETAIL(questStartItemID?), with GetQuestID() for the shown quest; QUEST_ACCEPTED(questId) on Mainline (the questLogIndex first argument is 'Classic only'); QUEST_TURNED_IN(questID, xpReward, moneyReward); QUEST_REMOVED(questID, wasReplayQuest).

Sources: <https://warcraft.wiki.gg/wiki/API_C_QuestLog.GetInfo>, <https://warcraft.wiki.gg/wiki/QUEST_DETAIL>, <https://warcraft.wiki.gg/wiki/QUEST_ACCEPTED>, <https://warcraft.wiki.gg/wiki/QUEST_TURNED_IN>, <https://warcraft.wiki.gg/wiki/QUEST_REMOVED>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

#### The Addon Compartment and the Mainline Options > AddOns settings panel exist in Forever. The wiki scopes the compartment TOC directives to 'Midnight and Forever', and Forever addons register into both. The Settings.* signatures are documented for Mainline only.

Confidence: medium. Relevance: Main window entry point (Addon Compartment) and options (Settings API)

TOC page: the AddonCompartmentFunc / AddonCompartmentFuncOnEnter / AddonCompartmentFuncOnLeave section 'concerns content related to Midnight and Forever'. Click handler args are (addonName, buttonName); since 11.0.0 there is no third menuButtonFrame argument. OnEnter/OnLeave args are (addonName, menuButtonFrame). Manual registration: AddonCompartmentFrame:RegisterAddon({text, icon, notCheckable, func, funcOnEnter, funcOnLeave}), where func receives (button, menuInputData, menu). IconTexture outranks IconAtlas. Forever Visuals opens 'with /fv, the minimap icon or the AddOn compartment' on 1.60.1, and Forever square-minimap addons relocate the compartment button. Forever Simple Settings (warperia, an aggregator) shows the in-game 'Options → AddOns' window with each addon's Options page. Settings API signatures: Settings.RegisterVerticalLayoutCategory(name), Settings.RegisterCanvasLayoutCategory(frame, name), Settings.RegisterAddOnCategory(category), Settings.RegisterAddOnSetting(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue), Settings.OpenToCategory(category [, scrollToElementName]).

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>, <https://warcraft.wiki.gg/wiki/Addon_compartment>, <https://warcraft.wiki.gg/wiki/Settings_API>, <https://www.curseforge.com/wow/addons/forevervisuals>, <https://www.curseforge.com/wow/addons/forever-simple-square-minimap>, <https://warperia.com/addon-forever/forever-simple-settings/>

#### Forever's FrameXML removes retail-only systems. The removed list includes the retail Dungeon Finder queue (LFDQueueFrame_*), the premade LFGList UI, PVEFrame, Encounter Journal, Garrison and Housing. Forever adds a Classic-style Group Finder (LFGBrowse*/LFGListing*, ToggleGroupFinderFrame) and a Legacy UI (LegacySystemFrame_LoadUI, ToggleLegacySystemUI, LegacyChallengeViewedUtil).

Confidence: medium. Relevance: Module 4 assumes a 'Dungeon Finder' that may not exist as retail-style queue matchmaking; UI templates for the main window (inferred present)

1.60.1 vs 12.1.5 FrameXML: 'Added (471)', 'Removed (1041)'. Removed names seen include LFDQueueFrame_Join, LFDQueueFrame_SetTypeRandomDungeon, LFGListApplicationDialog_*, PVEFrame_ToggleFrame, PVPUIFrame_*, EncounterJournal_*, Garrison*, HousingFramesUtil.*, ProfessionsBookFrame_* and QuestLogPopupDetailFrame_*. No Settings, ScrollBox, ScrollUtil, Portrait/ButtonFrame templates, WorldMap, MapCanvas, Tooltip core, Reputation or Minimap names were found in the visible removed parts. This is my reading of a scraped list and the page does not mark removals clearly, so check it in Ketho/wow-ui-source-forever. C_LFGList.GetSearchResultInfo exists in Forever (leaderName, numMembers, ...; predicate SecretInChatMessagingLockdown). Dev notes mention 'Group Finder postings' and a 'Looking For Group UI'. The LFG Forever addon extends 'Blizzard's Group Finder'. New events: LFG_LIST_ROLE_UPDATE and LFG_LIST_SHOW_SEARCH.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-26/2360696>, <https://www.curseforge.com/projects/1707849>

#### No dedicated addon API was found for campfires/camping, Legacy points or 'familiar faces'. Forever does add surname, day/night, shard-transfer and ruleset APIs that Ashmark can use.

Confidence: medium. Relevance: Module 6 (campfire as chapter boundary), module 5 (surnames), module 3 (day/night world state)

New in 1.60.1: C_PlayerInfo.ShouldDisplaySurname, C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator, CVar UnitSurnameOwn ('show player surname over head'), C_DateAndTime.IsDayTime plus event DIEL_CYCLE_CHANGED, GAME_RULES_CHANGED, SHARD_TRANSFER / SHARD_TRANSFER_IMMINENT, CHAT_MSG_COLLECTED_APPEARANCE, PLAYER_SWING / PLAYER_SWING_RANGE_UPDATE / C_SwingTimer, C_SkillInfo.*, C_PetInfo.GetPetHappiness / UNIT_HAPPINESS, ToggleSit, and C_GameRules.GetForeverExperiencePreset / SetForeverExperiencePreset / IsHardcoreActive / IsSelfFoundAllowed / IsSDHDToggleEnabled. Enum.GameRule has 114 DisableCampsites (its meaning for Forever is unconfirmed; it may be the retail warband campsite). Dev notes describe Campfire buffs ('mutually exclusive' wording, Oct 1), a 'Boosted Rest' debuff with a new icon, campfire buffs obtainable while sitting, sleeping or kneeling, and campfires dealing no damage below level 5. Camping would therefore have to be detected through player auras (UNIT_AURA), which are readable out of combat but secret under SecretWhenAurasRestricted.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/Enum.GameRule>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-26/2360696>, <https://warcraft.wiki.gg/wiki/Secret_values>

#### Forever surnames: full names are unique, first names are not, and several alts can share a surname. Since unrelated players can also share a surname, a surname alone cannot identify an Ashmark 'House'.

Confidence: medium. Relevance: Module 5 (House): key the house on account-wide SavedVariables plus surname, not surname alone; module 4 name storage

Blizzard Watch (Sep 13, 2026, reporting Blizzard's Sep 17 Q&A update): only one character may use a given full name, and the name is 'taken everywhere'. The surname system lets 'characters share a first name while remaining identifiable by their unique full name'. Last names are mandatory. Shared surnames across alts are allowed. Blizzard forum (Sep 16, player posts only, no blue): the surname can be hidden from display, and there are 'no servers/realms', just a mega-server with layers. Community GitHub reports (not opened, so unverified) say UnitName/UnitFullName return the surname as the SECOND value where retail returns the realm.

Sources: <https://blizzardwatch.com/2026/09/13/surnames-wow-forever/>, <https://us.forums.blizzard.com/en/wow/t/forever-naming-system/2351318>, <https://warcraft.wiki.gg/wiki/API_UnitName>

#### Utility APIs: Screenshot(), C_UI.Reload / ReloadUI and GetLocale are listed for Forever 1.60.1. ExportInterfaceFiles is documented only generically, with no Forever mention.

Confidence: medium. Relevance: Module 6 (campfire screenshot as chapter image), dev workflow, localization

Screenshot() 'Takes a screenshot'. The CVar screenshotFormat (jpeg/png/tga) controls the format. The wiki gives no protection note for Screenshot. C_UI.Reload() is 'restricted' and tagged #hwevent, so calling it from a slash-command handler (which runs on a key press) is the intended path. A global UIReload was added in 1.60.1. ExportInterfaceFiles code / ExportInterfaceFiles art 'only works from the actual console on the login and character selection screens' and writes the BlizzardInterfaceCode / BlizzardInterfaceArt folders. GetLocale codes: enUS (enGB returns enUS), koKR, frFR, deDE, zhCN, esES, zhTW, esMX, ruRU, ptBR, itIT. Other 1.60.1 Lua changes: 'require' renamed to 'import' (build 70291). SavedVariables and RestrictedEnvironment not loading was fixed in build 70009. Beta testers still disputed SavedVariables persistence on Oct 18.

Sources: <https://warcraft.wiki.gg/wiki/API_Screenshot>, <https://warcraft.wiki.gg/wiki/API_ReloadUI>, <https://warcraft.wiki.gg/wiki/Viewing_Blizzard%27s_interface_code>, <https://warcraft.wiki.gg/wiki/API_GetLocale>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>, <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-addon-feedback/2385926>

#### WhyHidden on CurseForge is a working Forever addon that reads C_Secrets predicates. It reports that the C_Secrets surface is identical on Forever 1.60.1 and Midnight 12.1.0/12.1.5, with values hidden during 'arenas, battlegrounds, enclosed encounters'.

Confidence: medium. Relevance: Reference implementation for Ashmark's secret-guard helper; debugging tool during development

WhyHidden 0.3.0 (Oct 7, 2026): lists health, names, casting, auras, cooldowns and threat as values that can be secret. Slash commands are /whh and /whh mouse. It says it is 'inert on clients without secret values'. The page names no specific C_Secrets function.

Sources: <https://www.curseforge.com/wow/addons/whyhidden>

Contradictions:

- Chat lockdown scope: the warcraft.wiki.gg Secret values page says SecretInChatMessagingLockdown also applies 'on communication-restricted maps' such as dungeons and raids (https://warcraft.wiki.gg/wiki/Secret_values). Warcraft Tavern (Oct 3, 2025, quoting Kaivax) says Blizzard narrowed it to 'only ... while there is an active raid encounter or M+ run underway' (https://www.warcrafttavern.com/wow/news/blizzard-walks-back-some-api-changes-for-addons-in-midnight/). Which rule Forever dungeons follow is unclear.
- WOW_PROJECT_ID: wowforeverguides reports 1 (= WOW_PROJECT_MAINLINE) on build 69913 (https://wowforeverguides.com/addons/api-cheatsheet). The wiki says WOW_PROJECT_CAMELOT = 18 was added in build 70170 (https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes). This is a change between builds, but addons written against early builds misdetect Forever.
- SavedVariables: the wiki says SavedVariables not loading was fixed in build 70009 on Sep 23 (https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes). A beta tester said on Oct 18 that SavedVariables still don't persist, and another player replied that they do (https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-addon-feedback/2385926).
- Concept doc vs kami-labs: the concept doc attributes 'Forever runs on the Midnight retail client ... combat log is locked' to kami-labs.fr. The kami-labs article itself only claims retail-identical restrictions and a 'one-for-one' API, and does not mention the combat log (https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/). The wiki shows Forever is a separate game type and client (1.60.1 / 16001 / project 18) in the same Mainline code family (https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes).
- Midnight interface number: wowforeverguides gives Midnight as 120100 (https://wowforeverguides.com/addons/developers), while warcraft.wiki.gg lists Midnight Standard as 120105 (https://warcraft.wiki.gg/wiki/TOC_format). The SEO site is stale. Separately, that wowforeverguides page contained embedded instruction-like text aimed at AI summarizers, so treat it as low-reliability.
- Hidden item counts on foreverchanges.pro differ between a search snippet (4,795 of 12,619) and the fetched page (4,928 of 12,715, updated Oct 30, 2026) (https://foreverchanges.pro/hidden-items). This is a moving target, not a true conflict.

### Game systems

#### Timeline as of 2026-10-30: the beta ran 17 Sep to 22 Oct 2026 and is over. Name reservation and character creation opened 27 Oct, launch is 4 Nov 2026 at 23:00 UTC, raids unlock 9 Dec, and Hardcore comes later.

Confidence: high. Relevance: All modules: re-check everything on the live build after 4 Nov.

Insider Gaming roadmap (images credited to Blizzard): Beta 17 Sep - 22 Oct; 'Early Name Reservation & Character Creation' 27 Oct; launch 4 Nov; raids 9 Dec (Barrow Deeps 10p, Hyjal Summit 20p, Onyxia's Lair 40p). Spring 2027: 2 raids, 2 dungeons, new quests, new playable area, legendary questline. Summer 2027 includes 'Professions & Legacy Updates'. warcraft.wiki.gg: stress test 21 Oct; end-of-beta event 22 Oct; 'Hardcore mode launches' Winter 2026/2027. Blizzard: 3:00 p.m. PST 4 Nov = 23:00 UTC = 00:00 CET 5 Nov. Name reservation 27 Oct - 3 Nov, up to 3 characters across rulesets. All mechanics below come from the beta and may change.

Sources: <https://insider-gaming.com/world-of-warcraft-forever-roadmap/>, <https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever>, <https://news.blizzard.com/en-us/article/24315820>, <https://news.blizzard.com/en-us/article/24303866>

#### Forever is a separate client branch, version 1.60.1, internal codename 'Camelot', listed on CurseForge as its own 'Forever' flavor. No source gave the TOC Interface number.

Confidence: medium. Relevance: TOC and packaging: a _Camelot TOC suffix and game version 1.60.1. This disproves 'Forever runs on the Midnight retail client' in the literal sense: it is its own branch.

warcraft.wiki.gg: 'standalone branch running alongside retail and Classic', internal name 'Camelot', platforms Windows and macOS, features added in 'Patch 1.60.1 (Beta)'. CurseForge ForeverGear: game version 1.60.1, flavor Forever, ships ForeverGear.toc and ForeverGear_Camelot.toc. Beta build numbers seen: 1.60.1.69893 (product 'wow_classic_beta', per classicwowforever.com, an aggregator), 1.60.1.70532 (wowforeverbuilds.com), 1.60.1.70707 (foreverchanges.pro, 30 Oct). Spell, item and faction IDs are in modern ranges (spells 1229432-1291341, items 273085-279978, factions 2765/2778). That points to a shared modern ID space, which is my inference, not stated by any source.

Sources: <https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever>, <https://www.curseforge.com/wow/addons/forevergear>, <https://classicwowforever.com/guides/forever-beta-datamine-hidden-loot/>, <https://foreverchanges.pro/hidden-items>

#### The concept doc's kami-labs claim that Forever addon restrictions exactly match Midnight is not supported by the source it cites. Warcraft Tavern's own Dev Q&A does say Forever uses a 'modern addon API that blocks certain types of addons'.

Confidence: medium. Relevance: Concept doc correction: say 'modern (retail-style) restricted addon API, per a Warcraft Tavern paraphrase', not 'exactly Midnight per Blizzard'. Combat-log and secret-value details need API-level checks.

kami-labs.fr (16 Sep 2026) says 'WoW Forever addons will face exactly the same restrictions as... Midnight' and cites the Warcraft Tavern Ion/Holly interview (14 Sep). That interview has no Forever-specific addon question or answer; Ion's addon remarks are about Midnight. Warcraft Tavern Dev Q&A (17 Sep; Randy Jordan, Josh Greenfield, Nora Mills, Tim Jones) paraphrases: 'modern addon API that blocks certain types of addons' and players 'shouldn't have to have addons to be able to play the game'. Player-only forum reports (Oct 2026): combat-log data hidden, a cooldown manager exists, most addons 'come from Retail'. No blue post confirms these.

Sources: <https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/>, <https://www.warcrafttavern.com/forever/news/ion-holly-interview-blizzcon-2026/>, <https://www.warcrafttavern.com/forever/news/wow-forever-developer-qa-elf-races-character-models-gdkp/>, <https://us.forums.blizzard.com/en/wow/t/forever-addons/2374159>

#### Official camping rules: a Cooking Basic Campfire creates a shared campsite. Nearby players add profession-crafted Camp Features, one per player, up to 3 on a Basic Campfire (5 or 10 on upgraded fires). Players must sit or craft there for at least 1 minute to get the benefits.

Confidence: high. Relevance: Module 6 (campfire as chapter boundary): a camp is a shared, timed, multi-player event with a 1-minute sit gate.

Blizzard: Basic Campfire learned at Cooking 1; 'creates a shared campsite where nearby players can rest'. All features need a campfire nearby and share a 1-hour cooldown. Camp buffs are mutually exclusive with the matching class buffs. Feature table (profession skill 20): First Aid Kit 3-56 Stamina (vs Power Word: Fortitude); Fishing Bowl 8% stats (vs Blessing of Kings); Mana Well 10-29 mp5 (vs Blessing of Wisdom); Sharpening Wheel 6-34 Str (vs Strength of Earth Totem); Enchanted Lute armor/stats/resists (vs Mark of the Wild); Reagent Bot sells reagents; Incense Candle 2-25 Int (vs Arcane Intellect); Camp Tent +5% of a level Rested XP; Camp Chair +2% crit (vs Moonkin Aura); Faction Banner 14-32 Spirit, faction members only (vs Divine Spirit). Items needing skill 140+ drop in dungeons and raids. On PvP rulesets enemies can find your camp. Camping can repair gear.

Sources: <https://news.blizzard.com/en-us/article/24301516>, <https://news.blizzard.com/en-us/article/24315820>, <https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap>

#### Campfire tiers and feature spell IDs (beta data): Basic, Journeyman and Expert campfires allow 3, 5 and 10 features. Each profession has tier 1, 2 and 3 objects. Mining's tier 1 object is the Lodestone (Attack Power).

Confidence: medium. Relevance: Module 6: IDs to recognise camp objects and their crafting. A camp's object count is a natural measure of how 'big' a chapter was.

Warcraft Tavern objects page: Basic Campfire spell 818 (Simple Wood, tool Flint and Tinder); Journeyman Campfire 1283400 (Star Wood, Cooking 90, Blueprint item 273087 from Deadmines/Wailing Caverns); Expert Campfire 1291341 (Thick Logs, Cooking 220, item 273101). Tier 1 spells: Mana Well 1230564, Sharpening Wheel 1230171, Enchanted Lute 1230643, Reagent Bot 1230656, First Aid Kit 1230117, Fish Bowl 1229745, Incense Candle 1229705, Camp Tent 1229432, Lodestone 1230161, Camp Chair 1229517 (you can sit on it), Faction Banner 1263425. Tier 2 needs skill 140, tier 3 needs 300 (e.g. Repair Bot 1263034 repairs gear; Greenhouse grows herbs; Rock Garden spawns a mining node; Field Guide tracks beasts). Cosmetic Scarlet Banner item 278030. Campfire lasts about 10 min, is single-use, 5 min cooldown; object cooldown 1 h per character (WT camping guide, wowforever.be). The 'Camping 101: <Profession>' quests teach the tier 1 items.

Sources: <https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/>, <https://www.warcrafttavern.com/forever/guides/camping/>, <https://wowforever.be/guides/camping/>, <https://www.method.gg/wow-forever/camping-in-wow-forever-how-it-all-works-all-profession-buffs>

#### Camp auras an addon can watch: 'Campfire Nearby' (passive, 100 yd), 'Welcoming Campfire' (1 min, while sitting), 'Camp Benefits' (1 h, one aura holding every camp effect, cannot be cancelled) and the 'Boosted Rest' debuff (1 h, from Camp Tent).

Confidence: medium. Relevance: Module 6: start a chapter when Welcoming Campfire turns into Camp Benefits. Module 2: camp frequency and contributions feed the identity profile. Aura readability under the restricted API needs a test.

Wowhead Forever spell pages: Camp Benefits spell=1229741, duration 1 hour, Apply Aura Dummy (value 33) plus two 20 yd dummy effects, 'Aura cannot be cancelled'. Welcoming Campfire spell=1289723, 1 minute, Periodic Dummy every 1 min, 20 yd radius. Campfire Nearby spell=1283391, passive, Aura Unique, radius 100 yd, no duration. Boosted Rest spell=1229451, 1 hour, flagged 'Aura is Debuff', persists through death. Name-to-ID mapping comes from wowforever.be: '/sit, and after a minute' Welcoming Campfire becomes Camp Benefits, and hovering it shows which effects you have; sitting again adds effects from objects placed later. Camp Tent spell 1229432 creates item 279978. The Tent tops Rested XP up to 5% of a level, with no effect if already above that.

Sources: <https://www.wowhead.com/forever/spell=1229741>, <https://www.wowhead.com/forever/spell=1289723>, <https://www.wowhead.com/forever/spell=1283391>, <https://www.wowhead.com/forever/spell=1229451>, <https://www.wowhead.com/forever/spell=1229432>, <https://wowforever.be/guides/camping/>

#### The camping unlock quest 'The Great Outdoors' (about level 5-6) is followed by 'Camping 101: <Profession>' quests. Their IDs are new, Forever-only quest IDs in the 9xxxx range.

Confidence: high. Relevance: Module 6: the first camp chapter can hook the camping tutorial quest IDs.

Wowhead quest=96046 'Camping 101: Mining': giver Yarr Hammerstone, Kharanos; raise Mining to 20; reward: learn the Lodestone. warcraft.wiki.gg: Eleanor Shackleton (Forever-only, SW of Brill, 57.3, 55.5) gives the Camping 101 series and 'The Great Outdoors (Forever)' (neutral, level 6); added in 1.60.1. Method: 'The Great Outdoors' is around level 5 from NPCs in each starting zone (Alliance: Dun Morogh, Elwynn, Teldrassil, Zephras Isle; Horde: Tirisfal, Durotar, Mulgore).

Sources: <https://www.wowhead.com/forever/quest=96046>, <https://warcraft.wiki.gg/wiki/Eleanor_Shackleton>, <https://www.method.gg/wow-forever/camping-in-wow-forever-how-it-all-works-all-profession-buffs>

#### The Cozy Sleeping Bag (bedroll) is a reused Season of Discovery item and quest chain (level 14+). It gives 'Well-Rested' (+1% XP per minute rested, up to 3 stacks), works as a rested zone, and stacks with camp buffs and food.

Confidence: medium. Relevance: Module 6: the bedroll is a second, solo 'rest' signal for chapter boundaries. It also shows Forever's data includes SoD content.

Warcraft Tavern: item 211527; chain starts with '...and that note you found' (Alliance 79008, Horde 79007) and ends with 'This Must Be the Place'. Buff Well-Rested spell 429959: one stack per minute of sleeping, max 3, +1% XP each; 1-hour cooldown; party members can use your bag. It cannot be used in cities or inns, disappears if you move about 100 yd away, and does not work across PvP-flag states. Staying in the bag earns Rested XP like an inn. Wowhead Forever item page marks it 'Unconfirmed... may not be in WoW: Forever'.

Sources: <https://www.warcrafttavern.com/forever/guides/cozy-sleeping-bag/>, <https://www.wowhead.com/forever/item=211527/cozy-sleeping-bag>, <https://wow-anniversary.fi/en/news/blueposts/wow-forever-camping-guide-cozy-sleeping-bag/>

#### Legacy (official): points are Battle.net account-wide for all non-Hardcore characters, and each character spends them separately in three trees. There are 65 challenges at launch (1 point each), with a 16-point spending cap per character.

Confidence: high. Relevance: Module 5 (House): the only account-wide link between alts is the Legacy point pool. No official alt roster or family feature was found, so a House needs its own roster in SavedVariables. Modules 1/2: Diplomat and Permanence change reputation and camp pacing.

Blizzard: unlocked by your first Legacy Point (usually level 25, or 150 in a non-gathering primary tradeskill, or exploring the full world map). Open with hotkey Y or the shield icon. Categories: Classes 27 (levels 25/45/60 on each class), Tradeskills 18, PvP 12, Adventure 2, Dungeons 3, Raids 3. A single character can reach 29 points without alts; 'leveling alternate (alts) characters is not required'. Trees: Professions (Working Overtime, Bountiful Harvest, Bartering, Performance, Master Chef, Luremaster, Dedicated Study); Adventure (Well Rested, Thrill of Adventure, High Alert, Field Guide = shorter 1-h camp cooldown (8% per Method), Field Medicine, Talented, Frequent Flier); Resourcefulness (Gourmand, The Quick and the Dead, Reinforce, For Great Honor, Permanence = longer party/raid/camp buffs (50% per Method), Diplomat = more reputation (2%/rank, 5 ranks per BoostRoom data), Reagent Economy = no purchasable reagents and free tier 1 camp features). Rewards at 15/25/40/55 points: Replica Ironforge Air Rifle, Spectral Bear Cub, Spectral Bear Tabard, Reins of the Spectral Bear (wiki). Trees are respecced at class trainers (wiki).

Sources: <https://news.blizzard.com/en-us/article/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system>, <https://warcraft.wiki.gg/wiki/Legacy_System>, <https://guildorder.com/games/wow_forever/wiki/legacy-points-and-the-alt-roster>, <https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap>

#### Characters have two-part names whose full combination is unique per region across all rulesets. Characters, including other players' characters, may share a second name. There is no official family or account-linked surname feature.

Confidence: high. Relevance: Module 5: a shared surname is a player convention, not proof of the same account (strangers can share it). House membership must be opt-in and per account. Module 4: store full 'First Last' as the key; sender name format is still to be verified.

Blizzard 'Create a Name of Your Own': 'each character will have two names'; full name 'distinct within your region'. The example shows several characters sharing the surname 'Brightvale'. A second name can suggest a family, but no mechanism links them. The nameplate option 'My Secondary Name' (Options > Nameplates) hides it in the world, 'but it will still appear in chat'. Warcraft Tavern: each part 2-12 characters; no spaces, hyphens, numbers, symbols, punctuation or apostrophes; accented letters allowed; no letter more than twice in a row; first letter uppercase. RP ruleset flags multi-word and non-fantasy names. Dev Q&A: a last name is mandatory.

Sources: <https://news.blizzard.com/en-us/article/24304161>, <https://www.warcrafttavern.com/forever/guides/names/>, <https://www.warcrafttavern.com/forever/news/wow-forever-developer-qa-elf-races-character-models-gdkp/>, <https://news.blizzard.com/en-us/article/24315820>

#### Rulesets replace realms: Normal, PvP, Roleplay and Roleplay PvP at launch, Hardcore later. Cross-ruleset grouping is not supported (battlegrounds excepted, Hardcore excluded), and factions cannot group.

Confidence: high. Relevance: Modules 4 and rumours: addon-message reach and remembered players are limited to one ruleset and faction. Store the ruleset with every record.

Blizzard (posted 22 Oct): 'Cross-ruleset grouping is not supported.' 'Battlegrounds may include players from other rulesets, with the exception of Hardcore'. On PvP, characters for one faction only. Preferred language is account-wide and 'has a 24-hour cooldown'. Players 'cannot freely hop between rulesets'. Collections and Legacy are account-wide except Hardcore. Deep Dive recap: 'This is not one giant realm for everyone'. Wiki: one 'mega-realm' per ruleset per region.

Sources: <https://worldofwarcraft.blizzard.com/en-us/news/24302070>, <https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap>, <https://eu.forums.blizzard.com/en/wow/t/630507>

#### Familiar Faces (BlizzCon Deep Dive, 13 Sep 2026, Lead Software Engineer Ana Resendez) biases which players share your world copy: people you met before, guildmates, your preferred language and, on PvP, faction balance. Blizzard has published no mechanism details, and layering ('world refresh') stays.

Confidence: medium. Relevance: Module 4: fits Ashmark's theme, but there is no public API. The addon must log encounters itself, and remembered players may sit in another layer. The community addon SocialForever already does this.

Warcraft Tavern: 'Familiar Faces aims to combine the benefits of a large, populated realm with a sense of persistent community'; guildmates 'should always be able to see each other'. It is unclear how it interacts with layer hopping, and 'encounter' is not defined. MMO-Champion recap: 'The goal is for strangers to become familiar faces'; PvP faction balance 'similar to the approach introduced in Season of Discovery'. Layering: a 5-minute warning with a 'Refresh Now' button (masterofwarcraft; Icy Veins reportedly says 3 min, not opened). Clay Stone statement (23 Oct, via Outputlag): fixes keep transport groups together and stop large groups splitting at capital cities; some layering 'will always' remain; zone-border swaps not addressed. Wowhead headline: 'Forced World Refreshes Will Be Significantly Reduced' (body not readable).

Sources: <https://www.warcrafttavern.com/forever/news/familiar-faces-to-simulate-realms-in-wow-forever/>, <https://www.mmo-champion.com/content/14512-BlizzCon-2026-World-of-Warcraft-Forever-Deep-Dive-Panel>, <https://www.masterofwarcraft.net/2026/09/wow-forever-five-minute-layer-change-warning.html>, <https://outputlag.com/news/wow-forevers-most-divisive-beta-feature-is-getting-fixes-but-blizzard-says-it-isnt-going-away/>, <https://seramate.com/news/forever/2026/10/17/forever-layering-group-and-zone-issues-587e51dc>, <https://www.wowhead.com/forever/news/forced-world-refreshes-will-be-significantly-reduced-for-wow-forever-383649>

#### There is no automated Dungeon Finder and no meeting-stone summoning. Forever has the Classic-style Looking For Group listing board, with a required Playstyle choice (Learning, Relaxed, Competitive, Carry Offered) added in the beta. Groups form by manual whispers and invites.

Confidence: high. Relevance: Module 4: drop 'Dungeon Finder' from the concept. Remembered group members come from LFG listings, manual groups, camps and the open world, and every group is formed by hand.

Warcraft Tavern (14 Sep, BlizzCon demo): the LFG UI is the WoW Classic version, which 'does not form them automatically or teleport everyone to the dungeon'; Meeting Stones 'doesn't work'; 'players must physically travel to the entrances'. Warcraft Tavern (2 Oct): the beta build added Playstyle with the four options, without official descriptions. Forum (26 Sep, players): listing produces floods of whispers and no role or class is shown.

Sources: <https://www.warcrafttavern.com/forever/news/no-group-finder-or-summoning-stones-in-wow-forever/>, <https://www.warcrafttavern.com/forever/news/playstyle-selection-now-required-for-lfg-in-wow-forever/>, <https://us.forums.blizzard.com/en/wow/t/2363328>, <https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever>

#### Hidden item stats: Blizzard obfuscates 'all items in the game', and stats appear only once an item has dropped 'for someone on your server'. About 12.7k items are tracked as hidden, covering new Forever, Classic and SoD items, and roughly 39% were revealed by 30 Oct.

Confidence: medium. Relevance: Module 7: the game already hides undiscovered items at server level. Ashmark's per-character 'never held' layer sits on top and must handle items whose data the server has not sent. Discovery counts come from aggregators.

Josh Greenfield (MMORPG.com, via Warcraft Tavern 16 Sep): 'we're actually obfuscating all items in the game'; 'you will not see an item's stats until it drops for you, until it drops for someone on your server'; no dungeon journal at first. foreverchanges.pro (aggregator, updated 30 Oct, build 1.60.1.70707): '4,928 of 12,715 revealed' = new Forever 814/2,530, Classic 3,189/5,006, SoD leftovers 925/5,179. The client asks the server for item data on loot, vendor view, chat-link click or addon request. The tooltip shows 'Retrieving item information' until the reply, which is cached in the WoW folder. In a 25 Sep test, about 1/3 of ~12,600 requests got answers. classicwowforever.com: records encrypted twice and 'the keys are not in the client'. Forum (22 Sep): AH list tooltips show only name and item level. Icy Veins' '12,594 (40%) of 31,800' could not be opened (HTTP 403).

Sources: <https://www.warcrafttavern.com/forever/news/item-stats-will-not-be-known-in-advance-for-wow-forever/>, <https://foreverchanges.pro/hidden-items>, <https://classicwowforever.com/guides/forever-beta-datamine-hidden-loot/>, <https://us.forums.blizzard.com/en/wow/t/items-in-auction-hall-do-not-show-stats-in-tool-tip-when-you-go-into-item-list/2358108>

#### Forever changes the stat system: spell, melee and ranged hit are merged, as are their crits, and there are new stats that did not exist in Classic. Tooltips also show which specs an item is for.

Confidence: medium. Relevance: Module 7: line-masking must use Forever's stat names, not Classic Era text patterns.

MMO-Champion Deep Dive (Blizzard recap): 'Spell, melee, and ranged hit chance are combined, as are spell, melee, and ranged critical chance'; panel notes: 'New stats added that did not exist in WoW Classic'. ForeverGear has '/fg stats' to collect unknown Forever stat keys. Forum player: AH tooltips lack 'the specs an item is for'.

Sources: <https://www.mmo-champion.com/content/14512-BlizzCon-2026-World-of-Warcraft-Forever-Deep-Dive-Panel>, <https://www.curseforge.com/wow/addons/forevergear>, <https://us.forums.blizzard.com/en/wow/t/items-in-auction-hall-do-not-show-stats-in-tool-tip-when-you-go-into-item-list/2358108>

#### Forever already continues the Gelkis and Magram storyline into the Valley of Bones and Shen'dralas. Both factions keep their Classic IDs (92, 93), and long new chains require Honored standing.

Confidence: high. Relevance: Module 1 pilot: Blizzard's own content already covers this storyline. Ashmark should build on these quest IDs and standings (e.g. a 'sworn clan' state at Honored) rather than duplicate them.

Wowhead Forever: Gelkis faction=92 (southern Desolace), Magram faction=93 (eastern Desolace), 'Mortal enemies'; standard thresholds (Neutral 42000, Friendly 45000, Honored 51000, Revered 63000, Exalted 84000). Gelkis Alliance quest=1368 (Classic ID, level 33, requires Friendly, +250 Gelkis). Gelkis series: Strange Alliance > Gelkis Alliance / Raid on the Kolkar > Stealing Supplies > Ongeku > Valley of Bones (93034, lvl 38, needs Honored, +125) > Ravaging Ravagers / Outing Outcasts > Facing the Truth > A Cleansing Cry > Test Your Theory. Magram series of 13: Brutal Politics > Magram Alliance / Assault on the Kolkar > Broken Tears > A Conqueror's Crown > Valley of Bones > Mountain of Bones / Outcast Necromancers > Corrupting Tears > Proof of Concept (92873, lvl 41, Honored, +500, reward choice Blade of the Magram Clan / Staff of Revelations / Desperate Barrier) > No Mercy for the Weak (92893, slay 5 Gelkis Captives) / Bone Raising > Bristleback Retreat > Long-Term Solutions / Threat of Starvation > Return to Orgrul (93188, lvl 43) > Khan Jehn. Quest giver Orgrul; objectives say 'Maintain your Magram reputation'. Wowhead lists no negative opposite-clan reputation on these quests.

Sources: <https://www.wowhead.com/forever/faction=92/gelkis-clan-centaur>, <https://www.wowhead.com/forever/faction=93/magram-clan-centaur>, <https://www.wowhead.com/forever/quest=1368/gelkis-alliance>, <https://www.wowhead.com/forever/quest=93034/valley-of-bones>, <https://www.wowhead.com/forever/quest=92873/proof-of-concept>, <https://www.wowhead.com/forever/quest=92893/no-mercy-for-the-weak>, <https://www.wowhead.com/forever/quest=93188/return-to-orgrul>

#### Shen'dralas is a new contested zone reached on foot from Desolace through the Valley of Bones. It holds Shen'dralar, Magram and Bristleback content; no official level range is published.

Confidence: medium. Relevance: Modules 1 and 3: the centaur pilot spans Desolace and Shen'dralas, so map pins need the new zone's uiMapID (unknown).

warcraft.wiki.gg: 'south-east of Desolace and between Feralas and Mulgore'; 'Unknown level range'; contested; affiliations Shen'dralar, Magram clan, Bristleback tribe; subzones Bristleback Retreat, Evenshade Overlook, Magram Front, Outcast Hideaway, Shen'dralas, Valley of Bones; added 1.60.1. Shen'dralar wiki: 'friendly Shen'dralar spirits inhabit Shen'dralas north of Dire Maul'; Mordent Evenshade; the Shal'nan rebels 'would eventually become the Skyborne'. Warcraft Tavern (13 Sep): 'between Desolace and Mulgore', continues the Kolkar, Gelkis and Magram stories, ties to Dire Maul, Prince Tortheldrin, Razorfen Downs and Maraudon; level estimate 30-50 is the author's guess.

Sources: <https://warcraft.wiki.gg/wiki/Shen'dralas>, <https://warcraft.wiki.gg/wiki/Shen'dralar>, <https://www.warcrafttavern.com/forever/news/all-new-zones-areas-in-wow-forever-revealed-at-blizzcon/>

#### The four new zones are Mount Hyjal (endgame), Riverglades (contested, 35-45), Shen'dralas and Zephras Isle (1-12, Skyborne start). Dalaran returns in Alterac Mountains, and there are nine new 5-player dungeons.

Confidence: high. Relevance: Module 3 (map layer) and Module 2: new zones and dungeons for exploration and identity data.

Blizzard: 'Mount Hyjal, Shen'dralas, the Riverglades, and Zephras Isle'; more than 1,000 new quests; nine new dungeons for levels 13-60: Hall of Thanes, Ruins of Lordaeron, Excavation Site, City of Dalaran, The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace. warcraft.wiki.gg Riverglades: SE Khaz Modan, east of Badlands and Burning Steppes, 35-45, settlements Farholde Keep (Alliance), Rog'mar and Bolder'ok (Horde), Powderfuse Port (neutral, boat to Tanaris), Krol'dok Stronghold 40-45. Warcraft Tavern: Riverglades has 150+ quests; Hyjal has 'a few reputations to grind' and the raids Hyjal Summit and Barrow Deeps. Method spells the Skyborne zone 'Zephyr's Isle'; Blizzard spells it 'Zephras Isle'.

Sources: <https://news.blizzard.com/en-gb/article/24315643/return-to-azeroth-in-world-of-warcraft-forever>, <https://news.blizzard.com/en-us/article/24315820>, <https://warcraft.wiki.gg/wiki/Riverglades>, <https://www.warcrafttavern.com/forever/news/all-new-zones-areas-in-wow-forever-revealed-at-blizzcon/>, <https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever>

#### New reputation factions exist: Guardians of Hyjal (ID 2765), Windshapers (2778) and High Order (the two Skyborne factions), Brotherhood of the Horse (Riverglades), and the battleground factions Darkspear Raiders and Theramore Expeditionary Force. Quartermasters and rewards are undocumented.

Confidence: medium. Relevance: Module 1: candidate factions beyond the centaur pilot. Windshapers vs High Order is a natural rival pair, but the game does not make it exclusive.

Wowhead faction=2765 Guardians of Hyjal: 'splinter faction of the Cenarion Circle'. faction=2778 Windshapers: 'shamanistic spiritual leaders of the Skyborne'. Quest 93797 'Boughs in the Wind' gives +50 Windshapers and +50 High Order (not exclusive at that stage). warcraft.wiki.gg: Brotherhood of the Horse added as a reputation in 1.60.1. Blizzard: the Battle for the Darkspear Islands BG (15v15) uses the two BG factions. BoostRoom (16 Sep, third party): returning factions include Timbermaw, Argent Dawn, Thorium Brotherhood, Cenarion Circle, Zandalar, Shen'dralar and the capital factions; none newly mutually exclusive besides Gelkis/Magram. Other names seen only in search snippets (Barkskin Burrow, Cenarion Scouts, Kirin Tor, Earthen Ring, The Watchers) are unverified.

Sources: <https://www.wowhead.com/forever/faction=2765/guardians-of-hyjal>, <https://www.wowhead.com/forever/faction=2778/windshapers>, <https://www.wowhead.com/forever/quest=93797/boughs-in-the-wind>, <https://warcraft.wiki.gg/wiki/Brotherhood_of_the_Horse>, <https://boostroom.com/blog/wow-forever-reputation-guide-factions-rewards-and-reputation-farming>, <https://news.blizzard.com/en-us/article/24315820>

#### Quest data lineage: Classic quest IDs are kept (e.g. Mor'Ladim 228, Gelkis Alliance 1368), SoD quests are reused (79007/79008), and 1,000+ new quests use IDs around 92xxx-96xxx. Some original quests have changed rewards. Questie now ships a Forever build.

Confidence: high. Relevance: Module 1: Classic quest data applies only partly. Use Forever-specific IDs and treat Questie's Forever DB as the reference.

Wowhead Forever quest=228 'Mor'Ladim' (Duskwood). Deep Dive recap: 'Quest rewards have also been updated or expanded'; the Mor'ladim quest now also grants the 'Ladimore Heirloom Ring'. New IDs seen: 92699, 92844, 92873, 92893, 93034, 93188, 93791, 93797, 96046. CurseForge Questie lists a 'Forever' flavor, game version 1.60.1, file v12.3.1+v1.0.9 dated 26 Oct 2026. wowforeverbuilds.com (last verified 16 Sep) still said 'Forever support not confirmed' (outdated). Forum player (8 Oct): a beta Questie lacked the new quests.

Sources: <https://www.wowhead.com/forever/quest=228>, <https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap>, <https://www.curseforge.com/wow/addons/questie>, <https://wowforeverbuilds.com/addons/questie>, <https://us.forums.blizzard.com/en/wow/t/forever-addons/2374159>

#### Hardcore is not available at launch ('sometime after launch'; roadmap Winter 2026/2027). It will be a fully enclosed ecosystem, dead characters can transfer out, and Legacy progress flows only out of Hardcore.

Confidence: high. Relevance: Modules 2 and 5: plan a death and epitaph state for Hardcore characters, and keep a House's Hardcore members separate.

Blizzard: 'Hardcore characters will remain in a fully enclosed ecosystem'; a dead Hardcore character can 'transfer to another ruleset - including PvP'. Legacy: challenges from other rulesets 'will not show up in Hardcore'; one earned in Hardcore 'will grant that challenge in all other rulesets'; Hardcore has 12 Hardcore-specific challenges because PvP ones can't be done there. Collections and Legacy are not shared into Hardcore. Full rules and an exact date are unpublished.

Sources: <https://worldofwarcraft.blizzard.com/en-us/news/24302070>, <https://news.blizzard.com/en-us/article/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system>, <https://news.blizzard.com/en-gb/article/24315643/return-to-azeroth-in-world-of-warcraft-forever>, <https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever>

#### On first login players choose an 'Experience Preset', Classic or Enhanced. It sets the UI layout and other defaults, all changeable later under Game Menu > Options.

Confidence: high. Relevance: Main window: test under both layouts. The Classic preset fits Ashmark's character; module 3 pins must coexist with quest POI on or off.

Blizzard: Classic = SD models, quest POI and objective blobs off, one-bag off, transmog off, camera-turn keybinds, 'Classic screen UI layout'. Enhanced = HD models, POI and blobs on, one-bag on, transmog on, strafe keybinds, 'Centralized screen UI layout'. The SD/HD model choice is per character and 'affects only appearance'.

Sources: <https://news.blizzard.com/en-us/article/24315820>, <https://news.blizzard.com/en-gb/article/24315643/return-to-azeroth-in-world-of-warcraft-forever>

#### Bags and bank: there is a fifth bag slot for a reagent bag, a mounts window, transmog collection and a larger default bank. No account-wide bank was confirmed at the time of the sources read.

Confidence: medium. Relevance: Module 5: no shared-family storage to hook into. Module 7: the item-held history must cover bags, bank and the reagent bag.

Warcraft Tavern (16 Sep): reagent bag slot; mounts no longer in bags; Greenfield: default bank 'either twice or four times as large' (~96 slots, unsure). An account-wide bank is reportedly only 'considered' (Ion quotes seen only in search snippets of Icy Veins and MassivelyOP, both unreadable: 403).

Sources: <https://www.warcrafttavern.com/forever/news/changes-to-bags-banks-in-world-of-warcraft-forever/>

#### A community addon, SocialForever, already does 'remembered players' on Forever. It records encounters and shares marks and flags with nearby addon users, which proves addon messaging works in the beta.

Confidence: high. Relevance: Module 4 and rumours: a direct precedent and possible competitor. Its source shows which encounter APIs and addon-message channels work on Forever.

CurseForge: by BabuniGaming; lists recently encountered nearby players with encounter counts and locations; marks Green/Yellow/Red; 'Exchanges marks and flags with nearby players who also use the addon'; memory saved account-wide; game version 1.60.1; v0.4.6-beta (22 Oct 2026); MIT license; source github.com/babunidev/SocialForever.

Sources: <https://www.curseforge.com/wow/addons/socialforever>

Contradictions:

- Campfire skill requirements: the Warcraft Tavern objects page says Journeyman 90 / Expert 220 (https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/). The Warcraft Tavern camping guide says 140 / 220 (https://www.warcrafttavern.com/forever/guides/camping/). Method says 90 / 200 (https://www.method.gg/wow-forever/camping-in-wow-forever-how-it-all-works-all-profession-buffs).
- Engineering tier 1 camp item: Blizzard's table and Warcraft Tavern say Reagent Bot, with Repair Bot as tier 2 (https://news.blizzard.com/en-us/article/24301516, https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/). Method lists Repair Bot as tier 1 (https://www.method.gg/wow-forever/camping-in-wow-forever-how-it-all-works-all-profession-buffs).
- Mining camp feature: Blizzard's feature table omits Mining (https://news.blizzard.com/en-us/article/24301516). Wowhead quest 96046 and Warcraft Tavern show a Lodestone, Attack Power like Blessing of Might (https://www.wowhead.com/forever/quest=96046, https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/).
- Addon restrictions: kami-labs says Forever addons get 'exactly the same restrictions' as Midnight, citing the Ion/Holly interview (https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/). That interview contains no Forever-specific addon statement (https://www.warcrafttavern.com/forever/news/ion-holly-interview-blizzcon-2026/). Warcraft Tavern's Dev Q&A only paraphrases a 'modern addon API that blocks certain types of addons' (https://www.warcrafttavern.com/forever/news/wow-forever-developer-qa-elf-races-character-models-gdkp/).
- Shen'dralas location: Warcraft Tavern says 'between Desolace and Mulgore' (https://www.warcrafttavern.com/forever/news/all-new-zones-areas-in-wow-forever-revealed-at-blizzcon/). warcraft.wiki.gg says 'south-east of Desolace and between Feralas and Mulgore' (https://warcraft.wiki.gg/wiki/Shen'dralas).
- Krol'dok Stronghold level: Warcraft Tavern says 40-55 (https://www.warcrafttavern.com/forever/news/all-new-zones-areas-in-wow-forever-revealed-at-blizzcon/). warcraft.wiki.gg says 40-45 (https://warcraft.wiki.gg/wiki/Riverglades).
- Item discovery propagation: Greenfield says stats appear once an item 'drops for someone on your server' (https://www.warcrafttavern.com/forever/news/item-stats-will-not-be-known-in-advance-for-wow-forever/). foreverchanges says the server answered only about 1/3 of requests for hidden items, and community cache collection (Raidbots) drives reveals (https://foreverchanges.pro/hidden-items).
- Skyborne zone name: Method writes 'Zephyr's Isle' (https://www.method.gg/wow-forever/camping-in-wow-forever-how-it-all-works-all-profession-buffs). Blizzard writes 'Zephras Isle' (https://news.blizzard.com/en-us/article/24315820).
- Beta dates: a fetch of warcraft.wiki.gg summarized the roadmap as 'Sept 17: Beta ends at 17:00 UTC' (https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever). The Insider Gaming table says Beta 17 Sep - 22 Oct, consistent with the wiki's own '22 Oct end of beta event' (https://insider-gaming.com/world-of-warcraft-forever-roadmap/).
- Questie Forever support: wowforeverbuilds (last verified 16 Sep) says 'Forever support not confirmed' (https://wowforeverbuilds.com/addons/questie). The Questie CurseForge page lists a Forever flavor file v12.3.1+v1.0.9 dated 26 Oct 2026 (https://www.curseforge.com/wow/addons/questie).
- Cozy Sleeping Bag: Warcraft Tavern documents it as obtainable in Forever (https://www.warcrafttavern.com/forever/guides/cozy-sleeping-bag/). Wowhead's Forever item page marks it 'Unconfirmed... may not be in WoW: Forever' (https://www.wowhead.com/forever/item=211527/cozy-sleeping-bag).

### Ecosystem and release

#### Several Forever addons already cover Ashmark's campfire, shared-fiction and map-pin ideas. Emberpath is the closest conceptual competitor.

Confidence: high. Relevance: Module 6 (campfire as chapter boundary), module 3 (private map layer with pins), and the later rumours / silent shared fiction. Ashmark needs to differentiate from them.

Emberpath (DronningMargrethe / 'Mads', project 1744439, MIT, source github.com/MadsFrost/Emberpath, v0.1.0, Oct 14 2026, flavor Forever 1.60.1). It offers secret daily omens drawn when you pitch camp, campfire 'tales' left on friends' world maps, ghost trails between campfires, 'The Gathering' and an 'Ember Ledger', and it syncs over addon messages in GUILD plus PARTY or RAID with WHISPER catch-up (prefix 'Emberpath'). The page says 'Trial accounts cannot send addon messages'. The map layer uses a MapCanvasDataProviderMixin added through WorldMapFrame:AddDataProvider, plus C_Map.GetMapPosFromWorldPos. Its TOC declares '## Interface: 120105' and 'AddonCompartmentFunc'. 'Ember: Camping Companion' (Jibbs, project 1756292): camp benefits, shares fires to the zone General channel as clickable map pins, Nearby Fires tab, icebreakers; tested on 1.60.1.70450. Also 'Embers - Campfire Addon' (dr4mx): a cinematic campfire pause. ForeverArtisan covers 'all 12 professions and Camping'. CurseForge has a 'Camping' category.

Sources: <https://www.curseforge.com/wow/addons/emberpath>, <https://www.curseforge.com/wow/addons/emberpath/files/all>, <https://www.curseforge.com/api/v1/mods/1744439/files/9171255/download>, <https://www.curseforge.com/wow/addons/ember-camping-companion>, <https://www.curseforge.com/wow/search?search=ember&gameVersionTypeId=88568>, <https://www.curseforge.com/wow/search?search=forever>

#### 'Forever Wayfinder' is a standalone quest companion with an illustrated atlas and a personal Discovery Journal. Two other, unrelated addons are also called Wayfinder.

Confidence: high. Relevance: Module 2 (behaviour-derived identity and journal) and module 3 (map layer) partly overlap with Forever Wayfinder's journal and atlas. It does not cover reputation-exclusive quests, House, or knowledge-gated tooltips.

Forever Wayfinder (Donald_Stone, project 1717217, ForeverWayfinder-0.7.1-alpha.zip, Oct 8 2026, Forever 1.60.1, All Rights Reserved, 201 downloads). Features: an Atlas with painted zone overviews and quest completion per zone; 'Where next?' tabs (All / Class / Special / Zones); a Discovery Journal that records quests, explored zones, dungeon visits and milestones, with personal notes, saved locally account-wide; Classic quest chains; one waypoint marker. '∞' marks a possible Forever quest. Commands are /fw, /fw atlas, /fw journal, /fw chain, /fw text. Separately, 'Wayfinder' (Wyomarus, project 1110568, MIT) is a compass banner that shows super-tracked targets with distance and ETA, tagged Forever 1.60.1, Retail 12.1.0 and Classic 1.15.9. A third, GitHub-only 'Wayfinder' (saad780) is a fog-of-war map that records service NPCs; it appeared only in search results and was not opened.

Sources: <https://www.curseforge.com/wow/addons/forever-wayfinder>, <https://www.curseforge.com/wow/addons/wayfinder>, <https://www.curseforge.com/wow/search?search=wayfinder&gameVersionTypeId=88568>, <https://addons.wago.io/addons/wayfinder/versions?stability=stable>

#### Remembering past group members is already done on Forever by 'I remember you' (384.7K downloads) and several note addons, and they guard UnitName against secret values.

Confidence: medium. Relevance: Module 4 (remembered group members) has strong incumbents. Module 5 (House / surnames): this addon assumes UnitName returns a surname in Forever, but warcraft.wiki.gg still documents the second return as realm. Needs in-game verification.

IRememberYou 1.75 (Bettiold, project 958586, Oct 14 2026). File tags: 12.1.5, 5.5.4, 3.80.2, 2.5.6, 1.60.1, 1.15.9. Single TOC '## Interface: 11509, 16001, 20506, 38002, 50504, 120105'. Its code checks issecretvalue() on tooltip GUID, on unit and on UnitName results. In Forever it treats UnitName's second return as a last name ('local firstName, lastName = UnitName(id)') and drops realm suffixes. Other Forever addons: 'i Will Remember' (Crasling, 17.8K), 'Worth Remembering' (maliceftw), 'RepKeeper' (Frostaphim), 'Name Drop' (first names with a short surname tag), 'CleanPlayerNames'.

Sources: <https://www.curseforge.com/wow/addons/i-remember-you>, <https://www.curseforge.com/wow/addons/i-remember-you/files/9175624>, <https://mediafilez.forgecdn.net/files/9175/624/IRememberYou%201.75.zip>, <https://www.curseforge.com/wow/search?search=ember&gameVersionTypeId=88568>, <https://www.curseforge.com/wow/search?search=surname&gameVersionTypeId=88568>

#### LFG Forever (not 'ForeverLFG') extends Blizzard's Forever Group Finder. Its code says C_LFGList search-result functions return fully secret values during chat-messaging lockdown.

Confidence: medium. Relevance: Module 4: names from Group Finder listings may be secret in dungeons, encounters or PvP. Forever's group finder appears to be the Classic-style 'LFGVanilla' browse list.

LFG Forever (Artefius, project 1707849, Wago ID n6VYgWNd, GPLv3 per TOC, about 30.8K downloads, latest LFGForever.zip file 9263876 Oct 20 2026, Forever-only 1.60.1). TOC: '## Interface: 16001', '## Category: Group Finder', 'AddonCompartmentFunc/OnEnter/OnLeave'. Code comment: GetSearchResultInfo, GetSearchResultLeaderInfo and GetSearchResultPlayerInfo 'are all SecretInChatMessagingLockdown = true'; LfgSearchResultData has one NeverSecret field (partyGUID); the panel is 'copied from Blizzard's camelot Browse panel (Blizzard_LFGVanilla_Browse.lua)'. It guards reads with canaccessvalue(). APIs used: C_LFGList.* and C_LFGListRoles.GetRoles.

Sources: <https://www.curseforge.com/projects/1707849>, <https://www.curseforge.com/wow/addons/lfg-forever/files/all>, <https://www.curseforge.com/api/v1/mods/1707849/files/9263876/download>

#### WhyHidden exists on CurseForge and lists the C_Secrets predicate API that is shared by Forever and Midnight.

Confidence: high. Relevance: Modules 4 and 7: call C_Secrets.ShouldUnitIdentityBeSecret before storing names, and wrap the calls in pcall.

WhyHidden (Booyaka101, project 1731223, WhyHidden-0.3.0.zip file 9085852, Oct 7 2026, tagged Forever 1.60.1 and Retail 12.1.0 / 12.1.5). TOC '## Interface: 16001, 120100, 120105'. README: 'the C_Secrets surface has been verified identical on both live clients'. Functions used: C_Secrets.HasSecretRestrictions, ShouldUnitIdentityBeSecret(unit), ShouldUnitHealthMaxBeSecret, ShouldUnitPowerBeSecret(unit, powerType), ShouldUnitPowerMaxBeSecret, ShouldUnitStatsBeSecret, ShouldUnitSpellCastingBeSecret, ShouldUnitSpellCastBeSecret(unit, spellID), ShouldUnitThreatValuesBeSecret('player', mob), ShouldAurasBeSecret(), ShouldCooldownsBeSecret(). Code comment: C_Secrets 'is tagged AllowedWhenUntainted and the Forever beta moves week to week'. Same author: ClearCombatText and wow-secret-lint.

Sources: <https://www.curseforge.com/wow/search?search=whyhidden>, <https://www.curseforge.com/wow/addons/whyhidden>, <https://mediafilez.forgecdn.net/files/9085/852/WhyHidden-0.3.0.zip>

#### Questie supports Forever with a Forever-specific database and a dedicated TOC suffix. Its code says tooltip data inside Forever instances is effectively all secret.

Confidence: high. Relevance: Module 1: detect reputation through faction state, not by parsing CHAT_MSG_SYSTEM. Module 3: don't reuse Era coordinates for those re-projected zones. Module 7: item and unit tooltip hooks must handle secret tooltip data and must not inspect it in instances. Questie also gives a quest-database baseline.

Questie v12.3.1+v1.0.9 (CurseForge project 334372, Wago qv634BKb, Oct 26 2026). Tags on Wago: supported_forever_patches ['1.60.1'] and classic ['1.15.9']. The zip ships Questie/Questie_Camelot.toc ('## Interface: 16001', LoadSavedVariablesFirst: 1, IconTexture, Category) and a fallback Questie.toc with '## Interface: 00000'. It also ships QuestieDB/QuestieDB_Camelot.toc and QuestieDB_Forever.toc (identical, 'X-Flavor: Forever'). Forever corrections live in QuestieDB/src/corrections/Forever/ and include new quest IDs such as 91317, 92682, 94489, 97277. eraToForever.lua says map coordinates were re-projected for Mulgore, Eastern Plaguelands, Redridge and Stormwind (DBC 1.15.9.69722 -> 1.60.1.69893). Detection: 'Questie.IsForever = interfaceVersion >= 16000 and interfaceVersion < 17000'. Code comments: 'Inside Forever instances tooltip data is restricted, effectively all secret'; 'Forever can hide unit and tooltip values, inside instances and for some tooltips in combat'; CHAT_MSG_SYSTEM and CHAT_MSG_SKILL text 'can be secret'; UnitGUID can be secret; WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition() can return secrets. Rendering uses C_StringUtil.TruncateWhenZero/WrapString, C_Intl.CompareStrings and C_CurveUtil.EvaluateColorValueFromBoolean so secrets are never branched on.

Sources: <https://www.curseforge.com/wow/addons/questie>, <https://www.curseforge.com/wow/addons/questie/files/9334933>, <https://addons.wago.io/addons/questie/versions?stability=stable>

#### warcraft.wiki.gg lists dedicated Forever game types, TOC suffixes and interface number 16001.

Confidence: high. Relevance: TOC layout. Ship Ashmark_Forever.toc (optionally also _Camelot.toc, as QuestieDB does) with '## Interface: 16001' and no plain or _Mainline TOC, so Retail does not load it.

Game types: 'forever' and 'camelot'. TOC suffixes: AddOnName_Forever.toc and AddOnName_Camelot.toc. The 'mainline' family (suffix _Mainline.toc) covers standard, forever, camelot, plunderstorm and wowhack, and game-type-specific suffixes take priority over family ones. Interface: Forever Beta 16001, Forever Test 16001; no value is listed for the 'Forever' live channel. Example: 'ForeverOnly.lua [AllowLoadGameType camelot][ExcludeLoadGameType standard, classic]'. Warning: if no listed game type is recognized the condition is still satisfied, so pair it with ExcludeLoadGameType. Footnote: 'The Camelot value may be changed to Forever in the future.' Patch 1.60.1 (Beta) 'Includes all Modern changes up to 12.1.5' and 'Added Camelot game type, Game variable value and TOC suffix, with Forever game type and TOC suffix alias.' The Bootstrap inline directive, RegionalTextLocale and the Addon compartment are marked as applying to Midnight and Forever.

Sources: <https://warcraft.wiki.gg/wiki/TOC_format>

#### According to the warcraft.wiki.gg transcription of the 2026-09-15 dev post, Forever shares Mainline's UI and API, and Midnight's addon 'disarmament' (secrets) is active in Forever.

Confidence: medium. Relevance: Confirms the concept doc's 'restrictions aligned with Midnight' claim, using a reputable secondary transcription. EMOTE needs a hardware event, so automated emotes for rumours or camp roleplay are out. Trial accounts can't use addon comms. GUIDs can't be used to fingerprint layers or spawns for the world-state layer. Surname APIs exist for module 5.

Quotes from 'An Update On Secrets In WoW: Forever' (originally posted on Discord): 'WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5.' Forever and Midnight are 'two game types within the Mainline code family', and Camelot is 'to be renamed before launch'. 'The addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever.' Build notes: 70009 (Sep 23) 'Fixed SavedVariables not loading'; 70170 (Oct 1) 'Added WOW_PROJECT_CAMELOT (18) constant'; 70291 (Oct 7-8, Beta 4) 'Added the "forever" TOC game type which is equivalent to "camelot"', 'Trial accounts can no longer send addon messages', and 'SendChatMessage with the "EMOTE" chat type now requires a hardware event when called from addon code outside of instances'. Beta 4 also added a FrameStrata secret aspect. 70425 (Oct 16, Beta 5): creature, vehicle, pet and gameobject GUIDs have obfuscated server and spawn IDs 'to prevent comparison to determine layer'. New API includes C_PlayerInfo.ShouldDisplaySurname, C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator, C_GameRules.IsHardcoreActive / IsSelfFoundAllowed / GetForeverExperiencePreset, and C_LFGListRoles.GetRoles/SetRoles/GetSavedRoles.

Sources: <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>

#### The combat log is not available to addons on Forever, which matches Midnight.

Confidence: high. Relevance: Module 2 (behaviour-derived identity) can't use combat-log statistics. Use events, quest, reputation and other non-combat data instead.

warcraft.wiki.gg COMBAT_LOG_EVENT: 'This event is no longer accessible to addons in Midnight since Patch 12.0.0'. Registering it fires ADDON_ACTION_FORBIDDEN; the page has no Forever-specific note. BigWigs v427.8 code sets 'public.isModern = tbl.isRetail or tbl.isForever' and registers COMBAT_LOG_EVENT_UNFILTERED only 'if not BigWigsLoader.isModern'. The ForeverUI page says Skada and Recount 'can't read the combat log on Forever'.

Sources: <https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT>, <https://addons.wago.io/addons/bigwigs/versions?stability=stable>, <https://www.curseforge.com/wow/addons/foreverui>

#### Secret-value predicates relevant to Ashmark and when they apply (warcraft.wiki.gg, Midnight-based; Forever inherits them according to the dev post).

Confidence: medium. Relevance: Module 4 (names inside dungeons may be secret; capture them before entering or after leaving), module 7 (tooltips in instances), and rumours (addon messages blocked during lockdown; trial accounts can't send at all).

Test functions: issecretvalue, canaccessvalue, issecrettable, canaccesstable. Predicates: SecretOnRestrictedMaps (12.0.5; on 'an addon-restricted map such as a dungeon or raid'); SecretInChatMessagingLockdown (encounter, challenge mode, PvP match, or a communication-restricted map such as a dungeon or raid); SecretWhenUnitNameIdentityRestricted (12.1.0; UnitName carries it); SecretWhenAurasRestricted (12.1.0); SecretWhenInCombat. Debug CVars: addonMapRestrictionsForced, addonCombatRestrictionsForced, addonEncounterRestrictionsForced. Namespace: C_RestrictedActions. SendAddonMessage result 11 = AddOnMessageLockdown; limits are a 16-character prefix, 255-character message, and 10 messages per prefix regained at 1 per second; 'Forever and modern clients starting in patch 12.1.7 prohibit trial and veteran accounts from sending addon messages.'

Sources: <https://warcraft.wiki.gg/wiki/Secret_Values>, <https://warcraft.wiki.gg/wiki/API_UnitName>, <https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage>

#### CurseForge has a dedicated 'Forever' flavor for WoW (gameVersionTypeId 88568), and Forever uploads are tagged with game version '1.60.1'.

Confidence: high. Relevance: Release path: upload with flavor Forever and game version 1.60.1 only.

Flavor filter link for Forever: /wow/search?...&gameVersionTypeId=88568. The other flavors are Retail 517, Classic 67408, Classic TBC 73246, WotLK 73713, Cataclysm 77522, Titan Reforged 81212 and MoP 79434. The game-version list includes '1.60.1', the only Forever version. Authors tag uploads in two ways: (a) one multi-flavor file tagged with several versions (Questie file 9334933: 5.5.4, 3.80.2, 2.5.6, 1.60.1, 1.15.9; BigWigs v427.8 and IRememberYou 1.75 likewise), or (b) separate per-flavor files labelled '-forever' (OpenMap 'v0.7.5-beta-forever', file 9299630; Leatrix Maps '1.60.25-forever', file 9275553). Tags are author-declared and not checked against the TOC: Emberpath is tagged Forever 1.60.1 while its TOC says Interface 120105.

Sources: <https://www.curseforge.com/wow/search?search=forever>, <https://www.curseforge.com/wow/search?class=addons&page=1&pageSize=50&sortBy=total+downloads&gameVersionTypeId=88568>, <https://www.curseforge.com/wow/addons/questie/files/9334933>, <https://www.curseforge.com/wow/addons/openmap/files/all>, <https://www.curseforge.com/wow/addons/leatrix-maps>, <https://www.curseforge.com/api/v1/mods/1744439/files/9171255/download>

#### Wago Addons supports Forever as its own game version ('forever'). Each release carries a 'supported_forever_patches' field, and wago.tools tracks Forever builds under the product key 'wowf'.

Confidence: high. Relevance: Release path: Wago is a working second channel. Use wago.tools 'wowf' to track the current client build for datamined data such as quest and faction IDs.

Wago page JSON fields: supported_retail_patches, supported_classic_patches, supported_bc_patches, supported_wotlk_patches, supported_cata_patches, supported_mop_patches, supported_forever_patches. Examples: Questie v12.3.1+v1.0.9 has forever ['1.60.1']; BigWigs v427.8 has forever ['1.60.1'], retail ['12.1.0','12.1.5','12.1.7'], classic ['1.15.8','1.15.9'], mop ['5.5.3','5.5.4']; DBM 12.1.18 has forever ['1.60.1']. The filter addons.wago.io/?game_version=forever showed 982 addons. Wago UI Packs FAQ: 'UI Packs support Retail, Forever, Mists Classic, Burning Crusade Classic, and Classic Era.' wago.tools/api/builds key 'wowf': latest 1.60.1.70707 (2026-10-30 03:20), then 70685 and 70658. The 'Tweaks Forever' changelog says Forever builds are listed under wowf, newer than wow_classic_beta.

Sources: <https://addons.wago.io/addons/tweaks-forever/versions?stability=stable>, <https://addons.wago.io/addons/questie/versions?stability=stable>, <https://addons.wago.io/addons/bigwigs/versions?stability=stable>, <https://addons.wago.io/addons/deadly-boss-mods-dbm/versions?stability=stable>, <https://addons.wago.io/?game_version=forever>, <https://uipacks.wago.io/>, <https://wago.tools/api/builds>

#### The BigWigs packager almost certainly maps Interface 16001 to the Forever game version on CurseForge and Wago, but this was inferred from a release because the packager docs on GitHub were off-limits.

Confidence: medium. Relevance: CI and release automation. Verify release.sh before relying on '-g forever' or on automatic _Forever.toc and _Camelot.toc recognition.

BigWigs (BigWigsMods, the packager's own authors) ships one BigWigs.toc with '## Interface: 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107' and per-game files via 'Init_[Game].lua' (the zip contains Init_Camelot.lua, so [Game] expands to 'Camelot' on Forever). Its Wago release carries supported_forever_patches ['1.60.1'] and its CurseForge files include the Forever flavor. LibSpecialization in the zip uses 'isForever = wowID == 18'. warcraft.wiki.gg's packager page (edited 4 Oct 2026) documents comma-separated Interface values, '## Interface-[Type]:' lines with -S TOC generation, CF_API_KEY / WAGO_API_TOKEN / WOWI_API_TOKEN, and X-Curse-Project-ID / X-Wago-ID, but says nothing about Forever.

Sources: <https://addons.wago.io/addons/bigwigs/versions?stability=stable>, <https://www.curseforge.com/wow/addons/big-wigs>, <https://www.curseforge.com/wow/addons/big-wigs/files/9299959>, <https://warcraft.wiki.gg/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions>

#### WoWInterface has no Forever category or compatibility label.

Confidence: high. Relevance: Release path: WoWInterface is low priority for a Forever-exclusive addon because its labelling is misleading.

Top-level categories: Addons for WoW Classic (Cataclysm Classic, TBC Classic, Classic - General, WOTLK Classic), Stand-Alone Addons, Compilations, Utilities, Optional. Example: 'FallenBag - WoWForever' (info27264) shows Compatibility 'Classic (1.15.2)', version 1.60.1, and a download tooltip saying 'WoW Retail'.

Sources: <https://www.wowinterface.com/addons.php>, <https://www.wowinterface.com/downloads/info27264-FallenBag-WoWForever.html>

#### OpenMap is a Forever world-map replacement that tells users to turn off Leatrix Maps and Mapster, and its code notes that map frame-level changes are restricted in combat.

Confidence: high. Relevance: Module 3: use a standard MapCanvasDataProvider and pins so they work under OpenMap and Leatrix; avoid changing frame levels in combat; test alongside OpenMap, Leatrix Maps and Questie.

OpenMap (jigrobbulus / 'OpenMap contributors', project 1735937, MIT, 162.3K downloads, v0.7.5-beta-forever Oct 23 2026, Forever 1.60.1; a separate Retail build v0.7.1-beta-retail is tagged 12.1.5). TOC: '## Interface: 16001', AddonCompartmentFunc. Page: 'If you use another world map addon (Leatrix Maps, Mapster, Magnify …), turn it off to avoid conflicts'; it warns at login. Compat.lua lifts Leatrix Maps, RareScanner and 'Books on Map Forever' icons above its stitched art, and says 'in combat they wait (a frame level change on the map is restricted then)'. Both it and Leatrix replace the zone label script at login. NPC icons need Questie. Uses C_Map.SetUserWaypoint, GetPlayerMapPosition and GetBestMapForUnit. Leatrix Maps (project 298842) ships a separate Forever file '1.60.25-forever' (Oct 21 2026).

Sources: <https://www.curseforge.com/wow/addons/openmap>, <https://www.curseforge.com/wow/addons/openmap/files/all>, <https://mediafilez.forgecdn.net/files/9299/630/OpenMap-v0.7.5-beta.zip>, <https://www.curseforge.com/wow/addons/leatrix-maps>

#### HandyNotes has no Forever-ready release yet.

Confidence: high. Relevance: Module 3: don't depend on HandyNotes as a plugin host for the Forever pin layer; build Ashmark's own map data provider.

Latest HandyNotes v1.6.31 (Aug 12 2026; CurseForge project 14154). TOC '## Interface: 120100,120007,11509,20506,50504' with no 16001. The Wago release has supported_forever_patches null (retail ['12.1.0','12.0.7'], classic ['1.15.9']). The CurseForge file list shows no Forever file, although the project sidebar lists Forever as a flavor.

Sources: <https://www.curseforge.com/wow/addons/handynotes>, <https://www.curseforge.com/wow/addons/handynotes/files/all>, <https://addons.wago.io/addons/handynotes/versions?stability=stable>

#### No Forever-specific Blizzard addon policy or whitelist was found. The general UI Add-On Development Policy still applies.

Confidence: medium. Relevance: Monetization (no paid features or in-game donation asks) and comms volume (rumour sync must stay light).

Blizzard forum thread 'UI Add-On Development Policy' (policy dated March 20, 2009; top post by Kaivax). Rules: distributed free of charge, with no premium versions or paywalls; code not hidden or obfuscated; no harm to realms or players (e.g., excessive chat); no advertising; no donation requests in game; content fits the 'T' rating; follow the ToU and EULA; Blizzard can disable add-on functionality at its discretion. The policy text names no game versions. A Forever 'recommended addons' forum thread (Jettao, Oct 27 2026) is a community post with no staff badge.

Sources: <https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534>, <https://eu.forums.blizzard.com/en/wow/t/wow-forever-%E2%80%93-recommended-addons/638001>

#### Community reports about Forever restrictions show threat values are secret and that auras are blocked for tainted code in combat.

Confidence: medium. Relevance: Module 6: detect the campfire by spell ID (GetPlayerAuraBySpellID), not by scanning auras by index. Module 2: no threat or combat metrics.

EU forum thread 'Threat is a secret/hidden value in addon API. Why?' (Oct 6-20 2026, no blue posts): UnitDetailedThreatSituation and UnitThreatPercentageOfLead('player','nameplate1') return secrets for party, raid and nameplate units; secrets can be displayed but not compared or used in arithmetic. Questie checks C_Secrets.ShouldAurasBeSecret() before reading auras.

Sources: <https://eu.forums.blizzard.com/en/wow/t/threat-is-a-secrethidden-value-in-addon-api-why/633885>, <https://addons.wago.io/addons/questie/versions?stability=stable>

#### Many existing Forever addons ship Addon Compartment entries and Blizzard-style settings. Forever's Blizzard Group Finder is extended by addons, and dev notes mention Group Finder and dungeon-list changes.

Confidence: medium. Relevance: Main window, Addon Compartment and Settings API: these are proven to work on Forever. Module 6: campfire and rest mechanics exist and change between builds.

AddonCompartmentFunc / OnEnter / OnLeave appear in the LFGForever.toc, OpenMap.toc and Emberpath.toc files. Wayfinder's settings page is 'styled like Blizzard's options' under Esc > Options > AddOns. Blizzard dev notes (Kaivax, 'WoW Forever Beta Development Notes – Updated September 24'): Oct 8 Group Finder postings can choose a voice mode; Oct 16 the dungeon list updates eligibility across party levels; Sept 24 Campfire buff fixes (obtainable while sitting, lying or kneeling); Oct 1 a 'Boosted Rest' debuff icon and tooltip; Oct 16 Horde/Kirin Tor reputation fixes.

Sources: <https://www.curseforge.com/api/v1/mods/1707849/files/9263876/download>, <https://mediafilez.forgecdn.net/files/9299/630/OpenMap-v0.7.5-beta.zip>, <https://www.curseforge.com/wow/addons/wayfinder>, <https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696>

Contradictions:

- kami-labs.fr says 'Forever runs on the Midnight Retail client'. The warcraft.wiki.gg transcription of the 2026-09-15 dev post instead describes 'two game types within the Mainline code family': a separate game type (camelot/forever), interface 16001, and its own wago.tools product 'wowf'. So it shares the Mainline UI and API but is not the Midnight client. Sources: https://kami-labs.fr/en/addons-wow-forever/ vs https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes and https://wago.tools/api/builds
- kami-labs.fr says 'Classic addons won't load'. Loading actually depends on the TOC: the _Classic and _Vanilla suffixes are not used on Forever, but any addon whose TOC includes 16001 (or ships _Forever, _Camelot or _Mainline) loads, as BigWigs, IRememberYou and WhyHidden do with single multi-interface TOCs. Sources: https://kami-labs.fr/en/addons-wow-forever/ vs https://warcraft.wiki.gg/wiki/TOC_format and https://addons.wago.io/addons/bigwigs/versions?stability=stable
- The ForeverUI CurseForge page (updated Oct 20 2026) says the Forever client 'doesn't read [settings] back after a reload or restart'. The warcraft.wiki.gg build 70009 note (Sep 23 2026) says 'Fixed SavedVariables not loading.' The ForeverUI text may be stale. Sources: https://www.curseforge.com/wow/addons/foreverui vs https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes
- The TOC suffix is reported variously as _Camelot, _Mainline or _Forever. Per warcraft.wiki.gg all three can work: _Forever and _Camelot are game-type suffixes (Forever an alias since build 70291) and _Mainline is the family suffix. Questie ships Questie_Camelot.toc only, while QuestieDB ships both _Camelot and _Forever. Sources: https://warcraft.wiki.gg/wiki/TOC_format vs https://addons.wago.io/addons/questie/versions?stability=stable
- I Remember You treats UnitName()'s second return as a last name on Forever. warcraft.wiki.gg API_UnitName still documents it as realm, with no Forever note. Sources: https://mediafilez.forgecdn.net/files/9175/624/IRememberYou%201.75.zip vs https://warcraft.wiki.gg/wiki/API_UnitName
- Emberpath is tagged on CurseForge as Forever 1.60.1, but its TOC declares '## Interface: 120105', showing CurseForge flavor tags are not validated against the TOC. Sources: https://www.curseforge.com/wow/addons/emberpath vs https://www.curseforge.com/api/v1/mods/1744439/files/9171255/download
- HandyNotes lists Forever as a flavor in the CurseForge sidebar and appears in Wago's game_version=forever filter, but none of its files or releases carry a Forever tag or 16001. Sources: https://www.curseforge.com/wow/addons/handynotes vs https://www.curseforge.com/wow/addons/handynotes/files/all and https://addons.wago.io/addons/handynotes/versions?stability=stable
- FallenBag on WoWInterface shows Compatibility 'Classic (1.15.2)', its description says it is for WoW Forever, and its download tooltip says 'WoW Retail'. Source: https://www.wowinterface.com/downloads/info27264-FallenBag-WoWForever.html

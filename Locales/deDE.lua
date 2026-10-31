local _, ns = ...
local L = ns.Locale:For("deDE")

-- Address form: "Ihr" (Ihr/Euch/Euer/Eure, always capitalised), as in Blizzard's deDE client.
-- Names from the client stay uninflected: "die Fraktion {faction}", "im Gebiet {zone}", "aus dem Gebiet {place}".
-- The fallbacks CORE_UNKNOWN_FACTION, CORE_UNKNOWN_PLACE and CORE_UNKNOWN_PLAYER read as names ("Unbekannt", as
-- the client shows unknown names), so they fit those frames; {people} always stands in the dative.

-- Core -----------------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark läuft nur unter World of Warcraft Forever und bleibt in diesem Client deaktiviert."
L.CORE_SV_NEW = "Eine neue Aufzeichnung hat begonnen. Falls Ashmark auf diesem Account schon verwendet wurde, "
  .. "wurden die gespeicherten Daten nicht geladen: Gebt nicht /reload ein und loggt Euch nicht erneut aus. "
  .. "Beendet das Spiel und ersetzt vor dem nächsten Login Ashmark.lua durch Ashmark.lua.bak in "
  .. "WTF\\Account\\<Account>\\SavedVariables\\."
L.CORE_SV_NEWER = "Diese gespeicherten Daten stammen aus einer neueren Version von Ashmark. Bis Ihr Ashmark "
  .. "aktualisiert, werden sie nur gelesen."
L.CORE_SV_RECOVERED = "Die gespeicherten Daten lagen in einer Form vor, die Ashmark nicht kennt. Eine neue "
  .. "Aufzeichnung hat begonnen; die alten Daten bleiben unverändert in AshmarkDB.recovered erhalten."
L.CORE_SV_MIGRATE_FAILED = "Ashmark konnte seine gespeicherten Daten nicht aktualisieren und kann sie in "
  .. "dieser Sitzung nur lesen."

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "Das Modul {module} wurde nach wiederholten Fehlern angehalten und bleibt bis zum nächsten "
  .. "Neuladen deaktiviert."
L.CORE_UNAVAILABLE = "Benötigt {capability}"
L.CORE_MISSING_EVENTS = "Ereignisse, die diesem Client fehlen: {events}"
L.CORE_SETTING_CHAT_LINES = "Zeilen im Chat"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark darf kurze Zeilen ins Chatfenster schreiben."
L.CORE_SETTING_SOUNDS = "Klänge"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark spielt die Seiten- und Buchklänge des Spiels ab."
L.CORE_SETTING_SHARE = "Mit anderen Ashmark-Nutzern teilen"
L.CORE_SETTING_SHARE_DESC = "Sendet Euren Archetyp, Eure Herkunft und Eure Gerüchte an Gruppenmitglieder, die "
  .. "ebenfalls Ashmark nutzen. Kontakte und Notizen verlassen Euren Client nie."

-- Shared vocabulary (5.8)
L.CORE_UNKNOWN_QUEST = "eine Quest"
L.CORE_UNKNOWN_ITEM = "ein Gegenstand"
L.CORE_UNKNOWN_FACTION = "Unbekannt"
L.CORE_UNKNOWN_PLACE = "Unbekannt"
L.CORE_UNKNOWN_PLAYER = "Unbekannt"
L.CORE_UNKNOWN_CLASS = "Abenteurer"
L.CORE_UNKNOWN_RACE = "Unbekanntes Volk"
L.CORE_RULESET_NORMAL = "Normal"
L.CORE_RULESET_PVP = "PvP"
L.CORE_RULESET_RP = "Rollenspiel"
L.CORE_RULESET_RPPVP = "Rollenspiel-PvP"
L.CORE_RULESET_HARDCORE = "Hardcore"

-- Chronicle sentences
L.CORE_LOG_TURNIN = "Ihr habt {quest} abgeschlossen."
L.CORE_LOG_TURNIN_THEY = "{name} hat {quest} abgeschlossen."
L.CORE_LOG_ABANDON = "Ihr habt {quest} abgebrochen."
L.CORE_LOG_ABANDON_THEY = "{name} hat {quest} abgebrochen."
L.CORE_LOG_ZONE_FIRST = "Ihr habt das Gebiet {zone} zum ersten Mal betreten."
L.CORE_LOG_ZONE_FIRST_THEY = "{name} hat das Gebiet {zone} zum ersten Mal betreten."
L.CORE_LOG_LEVEL = "Ihr habt Stufe {level} erreicht."
L.CORE_LOG_LEVEL_THEY = "{name} hat Stufe {level} erreicht."
L.CORE_LOG_DEATH = "Ihr seid im Gebiet {place} gestorben."
L.CORE_LOG_DEATH_THEY = "{name} ist im Gebiet {place} gestorben."
L.CORE_LOG_REP = "Ihr seid bei der Fraktion {faction} nun {standing}."
L.CORE_LOG_REP_THEY = "{name} ist bei der Fraktion {faction} nun {standing}."
L.CORE_LOG_CHAPTER = "Kapitel {roman} endet im Gebiet {place}."
L.CORE_LOG_CHAPTER_THEY = "Für {name} endet Kapitel {roman} im Gebiet {place}."

-- Slash commands (5.9)
L.CORE_HELP_HEADER = "Befehle:"
L.CORE_HELP_TOGGLE = "die Chronik öffnen oder schließen"
L.CORE_HELP_HELP = "diese Befehle auflisten"
L.CORE_HELP_DEBUG = "Debug-Ausgabe für diese Sitzung ein- oder ausschalten"
L.CORE_HELP_RESET = "die Aufzeichnungen dieses Charakters löschen; „reset others“ löscht Kontakte, Mitspieler "
  .. "und gehörte Gerüchte"
L.CORE_UNKNOWN_COMMAND = "Unbekannter Befehl: {command}"
L.CORE_DEBUG_ON = "Die Debug-Ausgabe ist für diese Sitzung eingeschaltet."
L.CORE_DEBUG_OFF = "Die Debug-Ausgabe ist ausgeschaltet."
L.CORE_RESET_CONFIRM = "Alles löschen, was Ashmark für diesen Charakter aufgezeichnet hat? Dies kann nicht "
  .. "rückgängig gemacht werden."
L.CORE_RESET_OTHERS_CONFIRM = "Alle Kontakte, Mitspieler und gehörten Gerüchte auf diesem Account löschen? Eure "
  .. "eigenen Gerüchte bleiben erhalten. Dies kann nicht rückgängig gemacht werden."
L.CORE_RESET_ACCEPT = "Löschen"
L.CORE_CANCEL = "Abbrechen"
L.CORE_RESET_DONE = "Die Aufzeichnungen dieses Charakters wurden gelöscht."
L.CORE_RESET_OTHERS_DONE = "Kontakte, Mitspieler und gehörte Gerüchte wurden gelöscht."
L.CORE_RESET_READONLY = "Die gespeicherten Daten stammen aus einer neueren Version von Ashmark, daher kann nichts "
  .. "gelöscht werden."

-- UI shell (6.1, 6.2)
L.CORE_TAB_CHRONICLE = "Chronik"
L.CORE_CHRONICLE_CHAPTER = "Kapitel {roman}"
L.CORE_CHRONICLE_CHAPTER_OPEN = "Kapitel {roman} (aktuell)"
L.CORE_CHRONICLE_CLOSED = "Abgeschlossen am {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "Begonnen am {date} · wird noch geschrieben"
L.CORE_CHRONICLE_OPEN = "Wird noch geschrieben"
L.CORE_CHRONICLE_EMPTY = "In diesem Kapitel ist noch nichts Erzählenswertes geschehen."
L.CORE_CHRONICLE_NO_RECORD = "Ashmark führt für diesen Charakter noch keine Aufzeichnungen."
L.CORE_COMPARTMENT_CLICK = "Klickt, um die Chronik zu öffnen oder zu schließen."
L.CORE_COMPARTMENT_RIGHT_CLICK = "Rechtsklickt, um die Einstellungen zu öffnen."

-- Test -----------------------------------------------------------------------------------------------------------

L.TEST_HELP = "den Selbsttest in diesem Client ausführen und einen Screenshot aufnehmen"
L.TEST_HELP_PROBE = "Rohdaten über diesen Client für die Entwickler aufzeichnen"
L.TEST_NOT_IN_COMBAT = "Der Test läuft nicht im Kampf. Versucht es erneut, sobald der Kampf vorüber ist."
L.TEST_SUMMARY = "Test beendet: {passed} bestanden, {failed} fehlgeschlagen, {skipped} übersprungen."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "bestanden"
L.TEST_FAIL = "FEHLER"
L.TEST_SKIP = "übersprungen"
L.TEST_OPEN_QUEST_DIALOG = "Sprecht für den Screenshot zuerst mit einem Questgeber."
L.TEST_RELOAD = "Gebt /reload ein, um die Ergebnisse zu speichern."
L.TEST_NOT_STORED = "Die gespeicherten Daten stammen aus einer neueren Version von Ashmark, daher wird nichts "
  .. "gespeichert. Der vollständige Bericht folgt."
L.TEST_LATE = "Späteres Ergebnis: {what}"
L.TEST_PROBE_DONE = "Die Sonde hat {count} Fakten aufgezeichnet."
L.TEST_PROBE_NEXT = "Nehmt in dieser Sitzung eine Quest an und beginnt einen Kampf: Die Sonde zeichnet beides auf."

-- Conflicts ------------------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "Konflikte"
L.CONFLICT_MODULE_DESC = "Manche Quests stellen eine Seite gegen eine andere. Ashmark merkt sich, welche Seite Ihr "
  .. "wählt, markiert unter dem Questfenster Quests, die dieser Wahl widersprechen, und hält fest, wenn Ihr Euer "
  .. "Wort brecht."

-- A side without a reputation faction; stands where a faction name would, also after "die Fraktion".
L.CONFLICT_UNNAMED = "Die Bannerlosen"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "Widerspricht Eurem Bündnis mit der Fraktion {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Widerspricht der Seite, die Ihr gewählt habt."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Euer Haus {house} steht gegen die Fraktion {faction}."
L.CONFLICT_TEST_DIALOG = "Hier erscheint Ashmarks Zeile unter dem Questfenster."

-- Chronicle sentences
L.CONFLICT_ALLIED = "Ihr habt Euch im Gebiet {zone} auf die Seite der Fraktion {faction} gestellt."
L.CONFLICT_ALLIED_THEY = "{name} hat sich im Gebiet {zone} auf die Seite der Fraktion {faction} gestellt."
L.CONFLICT_ALLIED_REP = "Euer Ruf bei der Fraktion {faction} hat im Gebiet {zone} über Eure Seite entschieden."
L.CONFLICT_ALLIED_REP_THEY = "Der Ruf bei der Fraktion {faction} hat im Gebiet {zone} über die Seite von {name} "
  .. "entschieden."
L.CONFLICT_BROKE_WORD = "Ihr habt der Fraktion {broken} die Treue gebrochen und {quest} für die Fraktion {faction} "
  .. "abgeschlossen."
L.CONFLICT_BROKE_WORD_THEY = "{name} hat der Fraktion {broken} die Treue gebrochen und {quest} für die Fraktion "
  .. "{faction} abgeschlossen."
L.CONFLICT_SWITCHED = "Ihr habt erneut die Seite gewechselt: {quest} für die Fraktion {faction}, die Fraktion "
  .. "{broken} zurückgelassen."
L.CONFLICT_SWITCHED_THEY = "{name} hat erneut die Seite gewechselt: {quest} für die Fraktion {faction}, die "
  .. "Fraktion {broken} zurückgelassen."
L.CONFLICT_HOUSETURN = "Ihr habt Euch von Haus {house} abgewandt und im Gebiet {zone} auf die Seite der Fraktion "
  .. "{faction} gestellt."
L.CONFLICT_HOUSETURN_THEY = "{name} hat sich von Haus {house} abgewandt und im Gebiet {zone} auf die Seite der "
  .. "Fraktion {faction} gestellt."

-- Decisions tab (6.1)
L.CONFLICT_TAB = "Entscheidungen"
L.CONFLICT_TAB_SIDES = "{a} oder {b}"
L.CONFLICT_TAB_ALLIED = "Seit {date} auf der Seite der Fraktion {faction}"
L.CONFLICT_TAB_OPEN = "Offen"
L.CONFLICT_TAB_BROKEN = "{count}× gebrochen"
L.CONFLICT_TAB_VIOLATIONS = "Wortbrüche: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "Ihr habt Euer Wort nicht gebrochen."
L.CONFLICT_TAB_EMPTY = "Ashmark kennt in dieser Welt noch keine Konflikte."

-- Profile --------------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "Profil"
L.PROFILE_MODULE_DESC = "Ashmark liest Euren Charakter an dem ab, was Ihr tut: ob Ihr Euer Wort haltet, ob Ihr in "
  .. "der Wildnis oder in Städten lebt und wie Ihr mit Kreaturen umgeht, die nichts Böses wollen."

-- Archetypes (7.2): labels without an article. "Seele" is feminine whatever the sex, so those two have no _F.
L.PROFILE_OATHKEEPER = "Eidhüter"
L.PROFILE_OATHKEEPER_F = "Eidhüterin"
L.PROFILE_OPPORTUNIST = "Opportunist"
L.PROFILE_OPPORTUNIST_F = "Opportunistin"
L.PROFILE_WANDERER = "Wanderer"
L.PROFILE_WANDERER_F = "Wanderin"
L.PROFILE_TOWNSFOLK = "Städter"
L.PROFILE_TOWNSFOLK_F = "Städterin"
L.PROFILE_GENTLE = "Sanfte Seele"
L.PROFILE_RUTHLESS = "Gnadenlose Seele"
L.PROFILE_PRAGMATIST = "Pragmatiker"
L.PROFILE_PRAGMATIST_F = "Pragmatikerin"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "Tötet 3 Kleintiere und 3 friedliche neutrale Wildtiere und führt dann erneut "
  .. "/ashmark test aus."
L.PROFILE_TEST_CRITTER_TARGET = "Visiert eine beliebige Kreatur an und führt dann erneut /ashmark test aus."
L.PROFILE_TEST_CRITTER_OFF = "Dieser Client kann Kleintiere nicht erkennen, daher werden getötete Kleintiere nicht "
  .. "gezählt."

-- Map ------------------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "Weltkarte"
L.MAP_MODULE_DESC = "Zeichnet Eure eigene Geschichte auf der Weltkarte ein: die Konflikte, die Ihr kennt, und die "
  .. "Seite, die Ihr gewählt habt, die Orte, an denen Ihr Euer Wort gebrochen habt, und die, an denen Eure Kapitel "
  .. "endeten. Nur Ihr seht diese Markierungen."

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{a} oder {b}"
L.MAP_PIN_OPEN = "Hier habt Ihr keine Seite gewählt."
L.MAP_PIN_ALLIED = "Ihr steht auf der Seite der Fraktion {faction}."
L.MAP_PIN_BROKEN = "Ihr steht auf der Seite der Fraktion {faction} und habt hier {count}× Euer Wort gebrochen."
L.MAP_PIN_VIOLATION = "Hier habt Ihr Euer Wort gebrochen"
L.MAP_PIN_CHAPTER = "Kapitel {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Hier abgeschlossen am {date}"

-- Encounters -----------------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "Begegnungen"
L.ENC_MODULE_DESC = "Ashmark merkt sich die Leute, mit denen Ihr in einer Gruppe spielt: wie oft Ihr Euch begegnet "
  .. "seid, wo und wie es lief. Es fügt ihrem Tooltip eine Zeile hinzu, listet sie im Reiter „Begegnungen“ auf und "
  .. "bewahrt Eure Notizen über sie. Kontakte und Notizen verlassen Euren Client nie."

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "Getroffen: {count}× · zuletzt: {place}"
L.ENC_TOOLTIP_NOPLACE = "Getroffen: {count}×"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "Ihr kennt {name}: {count}× getroffen, zuletzt im Gebiet {place}."
L.ENC_RECOGNISE_NOPLACE = "Ihr kennt {name}: {count}× getroffen."
L.ENC_RECOGNISE_MORE = "…und {count} weitere, die Ihr kennt."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "Bekanntes Gesicht"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "Eure Notiz zu {name}:"
L.ENC_NOTE_SAVE = "Speichern"

-- Encounters tab (6.1)
L.ENC_TAB = "Begegnungen"
L.ENC_TAB_TOTAL = "Leute, die Ihr getroffen habt: {count} · bekannte Gesichter: {recurring}"
L.ENC_TAB_EMPTY = "Noch hat niemand Euren Weg gekreuzt. Spielt mit jemandem in einer Gruppe, und Ashmark merkt "
  .. "sich die Begegnung."
L.ENC_TAB_MET = "{count}× getroffen · zuletzt: {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "{count}× getroffen · {date}"
L.ENC_TAB_NOTE = "Notiz"
L.ENC_TAB_WHO = "{race} {class}"
L.ENC_TAB_FIRST = "Erste Begegnung am {date}"

-- Chronicle sentences. {people} always follows "mit" or "von", so its parts below are dative.
L.ENC_LOG_CONTACT = "Ihr seid {contact} zum ersten Mal begegnet."
L.ENC_LOG_CONTACT_THEY = "{name} ist {contact} zum ersten Mal begegnet."
L.ENC_LOG_TRAVEL = "Ihr seid mit {people} gereist."
L.ENC_LOG_TRAVEL_THEY = "{name} ist mit {people} gereist."
L.ENC_LOG_BOSS = "Ihr habt an der Seite von {people} gekämpft und gesiegt."
L.ENC_LOG_BOSS_THEY = "{name} hat an der Seite von {people} gekämpft und gesiegt."
L.ENC_LOG_WIPE = "Ihr habt an der Seite von {people} gekämpft und seid gefallen."
L.ENC_LOG_WIPE_THEY = "{name} hat an der Seite von {people} gekämpft und ist gefallen."
L.ENC_LOG_CAMP = "Ihr habt mit {people} ein Lagerfeuer geteilt."
L.ENC_LOG_CAMP_THEY = "{name} hat mit {people} ein Lagerfeuer geteilt."
L.ENC_LOG_KICK = "Ihr wurdet aus der Gruppe von {people} fortgeschickt."
L.ENC_LOG_KICK_THEY = "{name} wurde aus der Gruppe von {people} fortgeschickt."

-- Parts of {people}
L.ENC_LOG_PEER = "{who} ({archetype} aus dem Gebiet {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "einer weiteren Person"
L.ENC_LOG_OTHERS = "{count} weiteren"
L.ENC_LOG_STRANGER = "einem Fremden"
L.ENC_LOG_STRANGERS = "{count} Fremden"
L.ENC_LOG_STRANGERS_ANY = "Fremden"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} und {last}"

-- House ----------------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "Haus"
L.HOUSE_MODULE_DESC = "Charaktere auf diesem Account mit demselben Nachnamen bilden ein Haus. Der Reiter „Haus“ "
  .. "zeigt seine Mitglieder, die Fehden, die Eure Verwandten aufgenommen haben, die Familienchronik und die Leute, "
  .. "die sie kennen."

-- /ashmark house (5.9)
L.HOUSE_HELP = "Euer Haus anzeigen; „house <Name>“ tritt dem Haus dieses Namens bei, „house reset“ kehrt zu "
  .. "Eurem Nachnamen zurück"
L.HOUSE_SLASH_CURRENT = "Ihr gehört zum Haus {house}."
L.HOUSE_SLASH_NONE = "Ihr gehört keinem Haus an. Gebt /ashmark house <Name> ein, um einem beizutreten."
L.HOUSE_SLASH_SET = "Ihr gehört nun zum Haus {house}."
L.HOUSE_SLASH_RESET = "Euer Haus richtet sich wieder nach Eurem Nachnamen: Haus {house}."
L.HOUSE_SLASH_RESET_NONE = "Euer Haus richtet sich wieder nach Eurem Nachnamen. Ohne Nachnamen gehört Ihr keinem "
  .. "Haus an."
L.HOUSE_SLASH_OFF = "Das Modul „Haus“ ist ausgeschaltet oder nicht verfügbar, daher kann sich Euer Haus jetzt "
  .. "nicht ändern."

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "Haus"
L.HOUSE_TAB_HEADING = "Haus {house}"
L.HOUSE_TAB_NO_HOUSE = "Ohne Haus"
L.HOUSE_TAB_NONE = "Charaktere auf diesem Account mit demselben Nachnamen bilden ein Haus. Ashmark kennt für "
  .. "diesen Charakter keinen Nachnamen: Gebt /ashmark house <Name> ein, um ein Haus zu wählen."
L.HOUSE_TAB_ARCHETYPE = "Archetyp: {archetype}"
L.HOUSE_TAB_MEMBERS = "Mitglieder"
L.HOUSE_TAB_MEMBER = "{name}, Stufe {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "Geerbte Fehden"
L.HOUSE_TAB_FEUD = "{name} hat sich im Gebiet {zone} auf die Seite der Fraktion {faction} gestellt."
L.HOUSE_TAB_CHRONICLE = "Familienchronik"
L.HOUSE_TAB_MEMORY = "Familiengedächtnis"
L.HOUSE_TAB_KNOWS = "{sibling} kennt {name}."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}: Stufe {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

-- Campfire -------------------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "Lagerfeuer"
L.CAMP_MODULE_DESC = "Rastet an einem Lager, bis seine Wirkung einsetzt, und Ashmark kann dort ein Kapitel Eurer "
  .. "Chronik abschließen, sofern seit dem letzten genug geschehen ist."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "Kapitel {roman} endet · {place}"

-- Knowledge ------------------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "Charakterwissen"
L.KNOW_MODULE_DESC = "Gegenstandstooltips zeigen nur, was Euer Charakter wissen kann. Ein Gegenstand, der nie in "
  .. "den Taschen, in der Bank oder in der Ausrüstung dieses Charakters war, zeigt Namen, Bindung, Ausrüstungsplatz, "
  .. "Gegenstandsstufe, Typ und Anforderungen; der Rest bleibt verborgen. Gegenstände, die das Spiel selbst noch "
  .. "verbirgt, bleiben so, wie das Spiel sie zeigt."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "Euer Charakter hat dies noch nie besessen."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "Vollständige Questbelohnungen"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "Die Tooltips der Belohnungen im Questfenster nie verbergen, damit Ihr eine "
  .. "Belohnung in Kenntnis ihrer Wirkung wählen könnt."

-- Fiction --------------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "Gemeinsame Fiktion"
L.FICTION_MODULE_DESC = "Gruppenmitglieder, die ebenfalls Ashmark nutzen, erfahren Euren Archetyp und Eure "
  .. "Herkunft, ohne dass ein Wort im Chat fällt, und Ihr erfahrt die ihren, sodass Eure Chronik und Eure Tooltips "
  .. "wissen, mit wem Ihr unterwegs wart. Anderen Spielern wird nichts angezeigt."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "Bildet mit einem anderen Ashmark-Nutzer eine Gruppe und führt dann erneut /ashmark test aus."

-- Rumours --------------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "Gerüchte"
L.RUMOUR_MODULE_DESC = "Was Ihr in einem Konflikt tut, wandert als Gerücht von Gruppe zu Gruppe weiter, und Ihr "
  .. "hört, was andere getan haben. Ein Gerücht nennt eine Art von Person, einen Ort und eine Fraktion, nie einen "
  .. "Charakter."

-- Chat lines for a rumour heard (7.8). No sex is known: {archetype} stands as a name after "den man … nennt",
-- where it needs no article, and "jemand" carries the grammar (no _F forms).
L.RUMOUR_HEARD_ALLIANCE = "Es heißt, jemand aus dem Gebiet {place}, den man {archetype} nennt, habe sich auf die "
  .. "Seite der Fraktion {faction} gestellt."
L.RUMOUR_HEARD_BROKE = "Es heißt, jemand aus dem Gebiet {place}, den man {archetype} nennt, habe der Fraktion "
  .. "{faction} die Treue gebrochen."
L.RUMOUR_HEARD_TURNED = "Es heißt, jemand aus dem Gebiet {place}, den man {archetype} nennt, habe dem eigenen Haus "
  .. "den Rücken gekehrt, um an der Seite der Fraktion {faction} zu stehen."
-- Without a faction
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "Es heißt, jemand aus dem Gebiet {place}, den man {archetype} nennt, habe sich für "
  .. "eine Seite entschieden."
L.RUMOUR_HEARD_BROKE_VAGUE = "Es heißt, jemand aus dem Gebiet {place}, den man {archetype} nennt, sei wortbrüchig "
  .. "geworden."
L.RUMOUR_HEARD_TURNED_VAGUE = "Es heißt, jemand aus dem Gebiet {place}, den man {archetype} nennt, habe dem eigenen "
  .. "Haus den Rücken gekehrt."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Stellt Euch in einem Konflikt auf die Seite einer Fraktion oder bildet mit einem anderen "
  .. "Ashmark-Nutzer eine Gruppe und führt dann erneut /ashmark test aus."

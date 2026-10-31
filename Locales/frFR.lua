local _, ns = ...
local L = ns.Locale:For("frFR")

-- Address form: "vous" (vouvoiement), as in Blizzard's frFR client.
-- Names from the client keep their own article, so they never follow "de" or "à", which would need an
-- elision or a contraction ("d'Orgrimmar", "aux Tarides"): zones stand after "dans" or as a direct object,
-- factions after "pour", "avec", "contre" or as a direct object, character names never after "de".
-- CORE_UNKNOWN_FACTION and CORE_UNKNOWN_PLACE carry their own article ("une faction", "un lieu inconnu").

-- Core ---------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark ne fonctionne que sur World of Warcraft Forever et reste inactif sur ce client."
L.CORE_SV_NEW = "Un nouveau registre a été ouvert. Si Ashmark a déjà servi sur ce compte, les données "
  .. "sauvegardées n'ont pas été chargées : n'utilisez plus /reload et ne vous déconnectez plus. Quittez le jeu, "
  .. "puis remplacez Ashmark.lua par Ashmark.lua.bak dans WTF\\Account\\<compte>\\SavedVariables\\ avant la "
  .. "prochaine connexion."
L.CORE_SV_NEWER = "Ces données sauvegardées proviennent d'une version plus récente d'Ashmark. Ashmark se contente "
  .. "de les lire tant que vous ne l'avez pas mis à jour."
L.CORE_SV_RECOVERED = "Les données sauvegardées avaient une forme qu'Ashmark ne connaît pas. Un nouveau registre a "
  .. "été ouvert ; les anciennes données sont conservées intactes dans AshmarkDB.recovered."
L.CORE_SV_MIGRATE_FAILED = "Ashmark n'a pas pu mettre à jour ses données sauvegardées et se contente de les lire "
  .. "pendant cette session."

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "Le module {module} s'est arrêté après des erreurs répétées et reste désactivé jusqu'au "
  .. "prochain rechargement de l'interface."
L.CORE_UNAVAILABLE = "Nécessite : {capability}"
L.CORE_UNAVAILABLE_CLIENT = "Il manque à ce client une fonction dont ce module a besoin."
L.CORE_MISSING_EVENTS = "Événements absents de ce client : {events}"
L.CORE_SETTING_CHAT_LINES = "Lignes dans la discussion"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark peut écrire de courtes lignes dans la fenêtre de discussion."
L.CORE_SETTING_SOUNDS = "Sons"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark joue les sons de page et de livre du jeu."
L.CORE_SETTING_SHARE = "Partager avec les autres utilisateurs d'Ashmark"
L.CORE_SETTING_SHARE_DESC = "Envoie votre archétype, votre origine, vos scores de profil (fidélité, habitat, "
  .. "clémence), votre type de royaume, votre version d'Ashmark et vos rumeurs aux membres du groupe qui utilisent "
  .. "aussi Ashmark. Les contacts et les notes ne quittent jamais votre client."

-- Shared vocabulary (5.8)
L.CORE_UNKNOWN_QUEST = "une quête"
L.CORE_UNKNOWN_ITEM = "un objet"
L.CORE_UNKNOWN_FACTION = "une faction"
L.CORE_UNKNOWN_PLACE = "un lieu inconnu"
L.CORE_UNKNOWN_PLAYER = "quelqu'un"
L.CORE_UNKNOWN_CLASS = "Aventurier"   -- opens ENC_TAB_WHO, like the client's class names
L.CORE_UNKNOWN_RACE = "d'un peuple inconnu"   -- follows the class in ENC_TAB_WHO
L.CORE_RULESET_NORMAL = "Normal"
L.CORE_RULESET_PVP = "JcJ"
L.CORE_RULESET_RP = "JdR"
L.CORE_RULESET_RPPVP = "JdR JcJ"
L.CORE_RULESET_HARDCORE = "Hardcore"

-- Chronicle sentences for Core's kinds; _THEY forms are used in the family chronicle with {name}.
L.CORE_LOG_TURNIN = "Vous avez accompli {quest}."
L.CORE_LOG_TURNIN_THEY = "{name} a accompli {quest}."
L.CORE_LOG_ABANDON = "Vous avez abandonné {quest}."
L.CORE_LOG_ABANDON_THEY = "{name} a abandonné {quest}."
L.CORE_LOG_ZONE_FIRST = "Vous avez foulé {zone} pour la première fois."
L.CORE_LOG_ZONE_FIRST_THEY = "{name} a foulé {zone} pour la première fois."
L.CORE_LOG_LEVEL = "Vous avez atteint le niveau {level}."
L.CORE_LOG_LEVEL_THEY = "{name} a atteint le niveau {level}."
L.CORE_LOG_DEATH = "Vous avez trouvé la mort dans {place}."
L.CORE_LOG_DEATH_THEY = "{name} a trouvé la mort dans {place}."
-- {standing} is the client's label, already in the character's gender ("Honoré", "Honorée").
L.CORE_LOG_REP = "Pour {faction}, vous êtes désormais {standing}."
L.CORE_LOG_REP_THEY = "Pour {faction}, {name} est désormais {standing}."
L.CORE_LOG_CHAPTER = "Le chapitre {roman} se clôt dans {place}."
L.CORE_LOG_CHAPTER_THEY = "{name} clôt son chapitre {roman} dans {place}."

-- Slash commands (5.9)
L.CORE_HELP_HEADER = "Commandes :"
L.CORE_HELP_TOGGLE = "ouvre ou ferme la chronique"
L.CORE_HELP_HELP = "affiche ces commandes"
L.CORE_HELP_DEBUG = "active ou désactive les messages de débogage pour cette session"
L.CORE_HELP_RESET = "efface le registre de ce personnage ; « reset others » efface les contacts, les pairs et les "
  .. "rumeurs entendues ; « reset <nom> » oublie un autre personnage de ce compte"
L.CORE_UNKNOWN_COMMAND = "Commande inconnue : {command}"
L.CORE_DEBUG_ON = "Les messages de débogage sont activés pour cette session."
L.CORE_DEBUG_OFF = "Les messages de débogage sont désactivés."
L.CORE_RESET_CONFIRM = "Effacer tout ce qu'Ashmark a consigné pour ce personnage ? Cette action est irréversible."
L.CORE_RESET_OTHERS_CONFIRM = "Effacer tous les contacts, pairs et rumeurs entendues sur ce compte ? Vos propres "
  .. "rumeurs sont conservées. Cette action est irréversible."
L.CORE_RESET_ACCEPT = "Effacer"
L.CORE_CANCEL = "Annuler"
L.CORE_RESET_DONE = "Le registre de ce personnage a été effacé."
L.CORE_RESET_OTHERS_DONE = "Les contacts, les pairs et les rumeurs entendues ont été effacés."
L.CORE_RESET_READONLY = "Les données sauvegardées proviennent d'une version plus récente d'Ashmark : rien ne peut "
  .. "être effacé."
L.CORE_RESET_CHAR_UNKNOWN = "Aucun autre personnage nommé {name} n'est enregistré sur ce compte."
L.CORE_RESET_CHAR_AMBIGUOUS = "Plusieurs personnages s'appellent {name}. Tapez /ashmark reset <GUID> avec le GUID "
  .. "de l'un d'eux :"
L.CORE_RESET_CHAR_LINE = "{name}, niveau {level} : {guid}"
L.CORE_RESET_CHAR_CONFIRM = "Oublier {name} ? Ashmark efface la chronique, les décisions, le profil et les "
  .. "rencontres de ce personnage. Ne le faites que pour un personnage que vous avez supprimé ou transféré."
L.CORE_RESET_CHAR_DONE = "Ashmark a oublié {name}."

-- UI shell (6.1, 6.2): main window tabs, the Chronicle tab and the Addon Compartment
L.CORE_TAB_CHRONICLE = "Chronique"
L.CORE_CHRONICLE_CHAPTER = "Chapitre {roman}"
L.CORE_CHRONICLE_CHAPTER_OPEN = "Chapitre {roman} (en cours)"
L.CORE_CHRONICLE_CLOSED = "Clos le {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "Ouvert le {date} · toujours en cours d'écriture"
L.CORE_CHRONICLE_OPEN = "Toujours en cours d'écriture"
L.CORE_CHRONICLE_EMPTY = "Rien dans ce chapitre ne mérite encore d'être conté."
L.CORE_CHRONICLE_NO_RECORD = "Ashmark ne tient encore aucun registre pour ce personnage."
L.CORE_COMPARTMENT_CLICK = "Clic gauche pour ouvrir ou fermer la chronique."
L.CORE_COMPARTMENT_RIGHT_CLICK = "Clic droit pour ouvrir les options."

-- Test ---------------------------------------------------------------------------------------------------

L.TEST_HELP = "lance l'autotest sur ce client et prend une capture d'écran"
L.TEST_HELP_PROBE = "consigne des données brutes sur ce client pour les développeurs"
L.TEST_NOT_IN_COMBAT = "Le test ne se lance pas en combat. Réessayez une fois le combat terminé."
L.TEST_SUMMARY = "Test terminé. Réussis : {passed}, échoués : {failed}, ignorés : {skipped}."
L.TEST_LINE = "{state} {id} : {detail}"
L.TEST_PASS = "réussi"
L.TEST_FAIL = "ÉCHEC"
L.TEST_SKIP = "ignoré"
L.TEST_OPEN_QUEST_DIALOG = "Parlez d'abord à un donneur de quête pour la capture d'écran."
L.TEST_RELOAD = "Tapez /reload pour enregistrer les résultats."
L.TEST_NOT_STORED = "Les données sauvegardées proviennent d'une version plus récente d'Ashmark : rien n'est "
  .. "enregistré. Le rapport complet suit."
L.TEST_LATE = "Résultat tardif : {what}"
L.TEST_PROBE_DONE = "Faits consignés par la sonde : {count}."
L.TEST_PROBE_NEXT = "Acceptez une quête et engagez un combat pendant cette session : la sonde consigne les deux."

-- Conflicts ----------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "Conflits"
L.CONFLICT_MODULE_DESC = "Certaines quêtes dressent un camp contre un autre. Ashmark retient le camp que vous "
  .. "choisissez, signale sous la fenêtre de quête celles qui le contredisent et consigne chaque manquement à "
  .. "votre parole."

-- Stands where a faction name would: after "pour", "avec", "contre" and as a direct object.
L.CONFLICT_UNNAMED = "ceux qui vont sans bannière"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "Contredit votre alliance avec {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Contredit le camp que vous avez choisi."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Votre maison, {house}, se dresse contre {faction}."
L.CONFLICT_TEST_DIALOG = "La ligne d'Ashmark sous la fenêtre de quête apparaît ici."

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}.
L.CONFLICT_ALLIED = "Vous avez pris parti pour {faction} dans {zone} ({title})."
L.CONFLICT_ALLIED_THEY = "{name} a pris parti pour {faction} dans {zone} ({title})."
L.CONFLICT_ALLIED_REP = "Vous avez pris parti pour {faction} dans {zone}, comme le dictait votre réputation."
L.CONFLICT_ALLIED_REP_THEY = "{name} a pris parti pour {faction} dans {zone}, comme le dictait sa réputation."
L.CONFLICT_BROKE_WORD = "Vous avez trahi {broken} en achevant {quest} pour {faction}."
L.CONFLICT_BROKE_WORD_THEY = "{name} a trahi {broken} en achevant {quest} pour {faction}."
L.CONFLICT_SWITCHED = "Vous avez changé de camp une fois de plus : {quest} pour {faction}, {broken} derrière vous."
L.CONFLICT_SWITCHED_THEY = "{name} a changé de camp une fois de plus : {quest} pour {faction}, {broken} derrière lui."
L.CONFLICT_SWITCHED_THEY_F = "{name} a changé de camp une fois de plus : {quest} pour {faction}, {broken} derrière "
  .. "elle."
L.CONFLICT_HOUSETURN = "Vous avez tourné le dos à la maison {house} et pris parti pour {faction} dans {zone}."
L.CONFLICT_HOUSETURN_THEY = "{name} a tourné le dos à la maison {house} et pris parti pour {faction} dans {zone}."

-- Decisions tab (6.1)
L.CONFLICT_TAB = "Décisions"
L.CONFLICT_TAB_SIDES = "{title} : {a} ou {b}"
L.CONFLICT_TAB_SIDES_VOWEL = "{title} : {a} ou {b}"
L.CONFLICT_TAB_ALLIED = "Vous soutenez {faction} depuis le {date}"
L.CONFLICT_TAB_OPEN = "Aucun camp choisi"
L.CONFLICT_TAB_BROKEN = "Parole rompue {count} fois"
L.CONFLICT_TAB_VIOLATIONS = "Paroles rompues : {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "Vous n'avez jamais manqué à votre parole."
L.CONFLICT_TAB_EMPTY = "Ashmark ne connaît encore aucun conflit dans ce monde."

-- Profile ------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "Profil"
L.PROFILE_MODULE_DESC = "Ashmark dresse le portrait de votre personnage d'après vos actes : si vous tenez parole, "
  .. "si vous vivez dans la nature ou en ville, et comment vous traitez les créatures qui ne veulent de mal à "
  .. "personne."

-- Archetypes (7.2): labels without an article. _F forms where the character's sex is known.
L.PROFILE_OATHKEEPER = "Gardien de serment"
L.PROFILE_OATHKEEPER_F = "Gardienne de serment"
L.PROFILE_OPPORTUNIST = "Opportuniste"
L.PROFILE_WANDERER = "Vagabond"
L.PROFILE_WANDERER_F = "Vagabonde"
L.PROFILE_TOWNSFOLK = "Citadin"
L.PROFILE_TOWNSFOLK_F = "Citadine"
L.PROFILE_GENTLE = "Âme douce"
L.PROFILE_RUTHLESS = "Âme impitoyable"
L.PROFILE_PRAGMATIST = "Pragmatique"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "Tuez 3 bestioles et 3 bêtes neutres et paisibles, puis tapez de nouveau "
  .. "/ashmark test."
L.PROFILE_TEST_CRITTER_TARGET = "Ciblez n'importe quelle créature, puis tapez de nouveau /ashmark test."
L.PROFILE_TEST_CRITTER_OFF = "Ce client ne sait pas reconnaître les bestioles : celles que vous tuez ne sont pas "
  .. "comptées."

-- Map ----------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "Carte du monde"
L.MAP_MODULE_DESC = "Inscrit votre propre histoire sur la carte du monde : les lieux où vous avez manqué à votre "
  .. "parole et ceux où vos chapitres se sont clos. Personne d'autre que vous ne voit ces marques. Les marques des "
  .. "conflits que vous connaissez, et du camp que vous avez choisi, viendront dans une version ultérieure."

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{title} : {a} ou {b}"
L.MAP_PIN_SIDES_VOWEL = "{title} : {a} ou {b}"
L.MAP_PIN_OPEN = "Vous n'avez choisi aucun camp ici."
L.MAP_PIN_ALLIED = "Vous soutenez {faction}."
L.MAP_PIN_BROKEN = "Vous soutenez {faction} ; ici, vous avez manqué {count} fois à votre parole."
L.MAP_PIN_VIOLATION = "Ici, vous avez manqué à votre parole"
L.MAP_PIN_CHAPTER = "Chapitre {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Clos ici le {date}"

-- Encounters ---------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "Rencontres"
L.ENC_MODULE_DESC = "Ashmark se souvient des personnes avec qui vous formez un groupe : combien de fois vous les "
  .. "avez rencontrées, où, et comment cela s'est passé. Il ajoute une ligne à leur infobulle, les répertorie "
  .. "dans l'onglet Rencontres et conserve vos notes à leur sujet. Les contacts et les notes ne quittent jamais "
  .. "votre client."

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "Rencontres : {count} · dernière dans {place}"
L.ENC_TOOLTIP_NOPLACE = "Rencontres : {count}"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "Vous connaissez {name} : vos chemins se sont croisés {count} fois, la dernière dans {place}."
L.ENC_RECOGNISE_NOPLACE = "Vous connaissez {name} : vos chemins se sont croisés {count} fois."
L.ENC_RECOGNISE_MORE = "… et encore {count} de vos connaissances."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "Visage familier"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "Votre note sur {name} :"
L.ENC_NOTE_SAVE = "Enregistrer"

-- Encounters tab (6.1)
L.ENC_TAB = "Rencontres"
L.ENC_TAB_TOTAL = "Personnes rencontrées : {count} · visages familiers : {recurring}"
L.ENC_TAB_EMPTY = "Personne n'a encore croisé votre route. Formez un groupe avec quelqu'un et Ashmark s'en "
  .. "souviendra."
L.ENC_TAB_MET = "Rencontres : {count} · dernière dans {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "Rencontres : {count} · {date}"
L.ENC_TAB_NOTE = "Note"
L.ENC_TAB_WHO = "{class} {race}"
L.ENC_TAB_FIRST = "Première rencontre : {date}"

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}, the family member.
-- {people} follows "avec", never "de".
L.ENC_LOG_CONTACT = "Vous avez rencontré {contact} pour la première fois."
L.ENC_LOG_CONTACT_THEY = "{name} a rencontré {contact} pour la première fois."
L.ENC_LOG_TRAVEL = "Vous avez fait route avec {people}."
L.ENC_LOG_TRAVEL_THEY = "{name} a fait route avec {people}."
L.ENC_LOG_BOSS = "Avec {people}, vous avez combattu et vaincu."
L.ENC_LOG_BOSS_THEY = "Avec {people}, {name} a combattu et vaincu."
L.ENC_LOG_WIPE = "Avec {people}, vous avez combattu et vous êtes tombé."
L.ENC_LOG_WIPE_F = "Avec {people}, vous avez combattu et vous êtes tombée."
L.ENC_LOG_WIPE_THEY = "Avec {people}, {name} a combattu et est tombé."
L.ENC_LOG_WIPE_THEY_F = "Avec {people}, {name} a combattu et est tombée."
L.ENC_LOG_CAMP = "Vous avez partagé un feu de camp avec {people}."
L.ENC_LOG_CAMP_THEY = "{name} a partagé un feu de camp avec {people}."
L.ENC_LOG_KICK = "Vous avez été écarté du groupe que vous formiez avec {people}."
L.ENC_LOG_KICK_F = "Vous avez été écartée du groupe que vous formiez avec {people}."
L.ENC_LOG_KICK_THEY = "{name} a été écarté du groupe qu'il formait avec {people}."
L.ENC_LOG_KICK_THEY_F = "{name} a été écartée du groupe qu'elle formait avec {people}."

-- Parts of {people}
L.ENC_LOG_PEER = "{who} ({archetype}, {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "quelqu'un d'autre"
L.ENC_LOG_OTHERS = "{count} autres"
L.ENC_LOG_STRANGER = "un inconnu"
L.ENC_LOG_STRANGERS = "{count} inconnus"
L.ENC_LOG_STRANGERS_ANY = "des inconnus"
L.ENC_LOG_COMPANION = "un compagnon"
L.ENC_LOG_COMPANIONS = "{count} compagnons"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} et {last}"
L.ENC_LIST_AND_VOWEL = "{list} et {last}"

-- House --------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "Maison"
L.HOUSE_MODULE_DESC = "Les personnages de ce compte qui partagent un nom de famille forment une maison. L'onglet "
  .. "Maison en montre les membres, les querelles que vos proches ont épousées, la chronique familiale et les "
  .. "personnes qu'ils connaissent."

-- /ashmark house (5.9)
L.HOUSE_HELP = "affiche votre maison ; « house <nom> » rejoint la maison de ce nom, « house reset » revient à "
  .. "votre nom de famille"
L.HOUSE_SLASH_CURRENT = "Vous appartenez à la maison {house}."
L.HOUSE_SLASH_NONE = "Vous n'appartenez à aucune maison. Tapez /ashmark house <nom> pour en rejoindre une."
L.HOUSE_SLASH_SET = "Vous appartenez désormais à la maison {house}."
L.HOUSE_SLASH_RESET = "Votre maison redevient celle de votre nom de famille : la maison {house}."
L.HOUSE_SLASH_RESET_NONE = "Votre maison redevient celle de votre nom de famille. Sans nom de famille, vous "
  .. "n'appartenez à aucune maison."
L.HOUSE_SLASH_OFF = "Le module Maison est désactivé ou indisponible : votre maison ne peut pas changer pour le "
  .. "moment."

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "Maison"
L.HOUSE_TAB_HEADING = "Maison {house}"
L.HOUSE_TAB_NO_HOUSE = "Sans maison"
L.HOUSE_TAB_NONE = "Les personnages de ce compte qui partagent un nom de famille forment une maison. Ashmark ne "
  .. "connaît aucun nom de famille pour ce personnage : tapez /ashmark house <nom> pour choisir une maison."
L.HOUSE_TAB_ARCHETYPE = "Archétype : {archetype}"
L.HOUSE_TAB_MEMBERS = "Membres"
L.HOUSE_TAB_MEMBER = "{name}, niveau {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "Querelles héritées"
L.HOUSE_TAB_FEUD = "{title} : {name} a pris parti pour {faction} dans {zone}."
L.HOUSE_TAB_CHRONICLE = "Chronique familiale"
L.HOUSE_TAB_MEMORY = "Mémoire familiale"
L.HOUSE_TAB_KNOWS = "{sibling} connaît {name}."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction} : niveau {level}"
L.HOUSE_LEGACY_STANDING = "{faction} : {standing}"

-- Campfire -----------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "Feu de camp"
L.CAMP_MODULE_DESC = "Reposez-vous près d'un feu de camp jusqu'à ce que ses bienfaits agissent, et Ashmark "
  .. "pourra y clore un chapitre de votre chronique, s'il s'est passé assez de choses depuis le précédent."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "Le chapitre {roman} se clôt · {place}"

-- Knowledge ----------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "Connaissances du personnage"
L.KNOW_MODULE_DESC = "Les infobulles des objets ne montrent que ce que votre personnage peut savoir. Un objet qui "
  .. "n'a jamais été dans les sacs, la banque ou l'équipement de ce personnage affiche son nom, sa liaison, son "
  .. "emplacement, son niveau d'objet, son type et ses conditions requises ; le reste demeure caché. Les objets "
  .. "que le jeu lui-même masque encore restent tels que le jeu les montre."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "Votre personnage n'a jamais possédé cet objet."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "Récompenses de quête détaillées"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "Ne masque jamais les infobulles des récompenses affichées dans la fenêtre de "
  .. "quête, pour que vous puissiez choisir une récompense en sachant ce qu'elle fait."

-- Fiction ------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "Fiction partagée"
L.FICTION_MODULE_DESC = "Les membres du groupe qui utilisent aussi Ashmark apprennent votre archétype, votre "
  .. "origine, vos scores de profil, votre type de royaume et votre version d'Ashmark sans un mot dans la "
  .. "discussion, et vous apprenez les leurs : votre chronique et vos infobulles savent ainsi avec qui vous avez "
  .. "voyagé. Rien n'est montré aux autres joueurs."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "Formez un groupe avec un autre utilisateur d'Ashmark, puis tapez de nouveau /ashmark test."

-- Rumours ------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "Rumeurs"
L.RUMOUR_MODULE_DESC = "Ce que vous faites dans un conflit circule de groupe en groupe sous forme de rumeur, et "
  .. "vous entendez ce que d'autres ont fait. Une rumeur nomme un type de personne, un lieu et une faction, jamais "
  .. "un personnage."

-- Chat lines for a rumour heard (7.8). Rumours carry no sex: {archetype} stands as a quoted nickname after
-- "quelqu'un que l'on surnomme", so the masculine label needs no agreement. No _F forms.
L.RUMOUR_HEARD_ALLIANCE = "On raconte que dans {place}, quelqu'un que l'on surnomme « {archetype} » a pris parti "
  .. "pour {faction}."
L.RUMOUR_HEARD_BROKE = "On raconte que dans {place}, quelqu'un que l'on surnomme « {archetype} » a trahi "
  .. "{faction}."
L.RUMOUR_HEARD_TURNED = "On raconte que dans {place}, quelqu'un que l'on surnomme « {archetype} » a tourné le dos "
  .. "à sa maison pour soutenir {faction}."
-- Without a faction: after three hops, or when the side has none.
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "On raconte que dans {place}, quelqu'un que l'on surnomme « {archetype} » a choisi "
  .. "son camp."
L.RUMOUR_HEARD_BROKE_VAGUE = "On raconte que dans {place}, quelqu'un que l'on surnomme « {archetype} » a manqué "
  .. "à sa parole."
L.RUMOUR_HEARD_TURNED_VAGUE = "On raconte que dans {place}, quelqu'un que l'on surnomme « {archetype} » a tourné "
  .. "le dos à sa propre maison."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Prenez parti pour une faction dans un conflit, ou formez un groupe avec un autre "
  .. "utilisateur d'Ashmark, puis tapez de nouveau /ashmark test."

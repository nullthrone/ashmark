local _, ns = ...
local L = ns.Locale:Base()

L.ENC_MODULE_NAME = "Encounters"
L.ENC_MODULE_DESC = "Ashmark remembers the people you group with: how often you met, where and how it went. "
  .. "It adds a line to their tooltip, lists them in the Encounters tab and keeps your notes on them. "
  .. "Contacts and notes never leave your client."

-- Unit tooltip (7.4). {count} is a number, {place} a zone name from the client, {archetype} one of the
-- PROFILE_<ARCHETYPE> labels.
L.ENC_TOOLTIP = "Met: {count}× · last {place}"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group. {name} is a character name.
L.ENC_RECOGNISE = "You know {name}: met {count}×, last in {place}."
L.ENC_RECOGNISE_NOPLACE = "You know {name}: met {count}×."
L.ENC_RECOGNISE_MORE = "…and {count} more you know."

-- Marker for someone this character has met at least three times.
L.ENC_RECURRING = "Familiar face"

-- Note editor (6.2). {name} is a character name.
L.ENC_NOTE_PROMPT = "Your note on {name}:"
L.ENC_NOTE_SAVE = "Save"

-- Encounters tab (6.1). {date} is a short date from the client, {race} and {class} come from the client.
L.ENC_TAB = "Encounters"
L.ENC_TAB_TOTAL = "People you have met: {count} · familiar faces: {recurring}"
L.ENC_TAB_EMPTY = "Nobody has crossed your path yet. Group with someone and Ashmark will remember them."
L.ENC_TAB_MET = "Met {count}× · last in {place} · {date}"
L.ENC_TAB_NOTE = "Note"
L.ENC_TAB_WHO = "{race} {class}"
L.ENC_TAB_FIRST = "First met {date}"

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}, the family member.
-- {contact} is a character name. {people} is a list built from the ENC_LIST_* and ENC_LOG_* parts below,
-- such as "Thalen (Oathkeeper from Westfall), Mira and 2 others".
L.ENC_LOG_CONTACT = "You met {contact} for the first time."
L.ENC_LOG_CONTACT_THEY = "{name} met {contact} for the first time."
L.ENC_LOG_TRAVEL = "You travelled with {people}."
L.ENC_LOG_TRAVEL_THEY = "{name} travelled with {people}."
L.ENC_LOG_BOSS = "You fought beside {people} and won."
L.ENC_LOG_BOSS_THEY = "{name} fought beside {people} and won."
L.ENC_LOG_WIPE = "You fought beside {people} and fell."
L.ENC_LOG_WIPE_THEY = "{name} fought beside {people} and fell."
L.ENC_LOG_CAMP = "You shared a campfire with {people}."
L.ENC_LOG_CAMP_THEY = "{name} shared a campfire with {people}."
L.ENC_LOG_KICK = "You were sent away from the group of {people}."
L.ENC_LOG_KICK_THEY = "{name} was sent away from the group of {people}."

-- Parts of {people}. {who} is a character name, {place} the zone they come from.
L.ENC_LOG_PEER = "{who} ({archetype} from {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "one other"
L.ENC_LOG_OTHERS = "{count} others"
L.ENC_LOG_STRANGER = "a stranger"
L.ENC_LOG_STRANGERS = "{count} strangers"
L.ENC_LOG_STRANGERS_ANY = "strangers"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} and {last}"

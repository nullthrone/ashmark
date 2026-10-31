local _, ns = ...
local L = ns.Locale:Base()

L.HOUSE_MODULE_NAME = "House"
L.HOUSE_MODULE_DESC = "Characters on this account who share a surname form a house. The House tab shows its "
  .. "members, the feuds your relatives took up, the family chronicle and the people they know."

-- /ashmark house (5.9). {house} is a family name: a surname, or one the player typed.
L.HOUSE_HELP = "show your house; \"house <name>\" joins the house of that name, \"house reset\" follows your "
  .. "surname again"
L.HOUSE_SLASH_CURRENT = "You belong to House {house}."
L.HOUSE_SLASH_NONE = "You belong to no house. Type /ashmark house <name> to join one."
L.HOUSE_SLASH_SET = "You now belong to House {house}."
L.HOUSE_SLASH_RESET = "Your house follows your surname again: House {house}."
L.HOUSE_SLASH_RESET_NONE = "Your house follows your surname again. Without one, you belong to no house."
L.HOUSE_SLASH_OFF = "House is turned off or unavailable, so your house cannot change now."

-- House tab (6.1, 7.5). {name} and {sibling} are character names, {faction} a faction name and {zone} a
-- zone name from the client, {level} and {count} numbers, {ruleset} a ruleset name.
L.HOUSE_TAB = "House"
L.HOUSE_TAB_HEADING = "House {house}"
L.HOUSE_TAB_NO_HOUSE = "Without a house"
L.HOUSE_TAB_NONE = "Characters on this account who share a surname form a house. Ashmark knows no surname for "
  .. "this character: type /ashmark house <name> to choose a house."
L.HOUSE_TAB_ARCHETYPE = "Archetype: {archetype}"
L.HOUSE_TAB_MEMBERS = "Members"
L.HOUSE_TAB_MEMBER = "{name}, level {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "Inherited feuds"
L.HOUSE_TAB_FEUD = "{name} sided with {faction} in {zone}."
L.HOUSE_TAB_CHRONICLE = "Family chronicle"
L.HOUSE_TAB_MEMORY = "Family memory"
L.HOUSE_TAB_KNOWS = "{sibling} knows {name}."

-- A side without a reputation faction, where a faction name would stand.
L.HOUSE_UNNAMED = "those without a banner"

-- The account's Legacy (7.5). {faction} is the faction's name from the client, {standing} a standing
-- label from the client ("Friendly").
L.HOUSE_LEGACY_LEVEL = "{faction}: level {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

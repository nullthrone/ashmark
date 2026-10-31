local _, ns = ...
local L = ns.Locale:Base()

L.RUMOUR_MODULE_NAME = "Rumours"
L.RUMOUR_MODULE_DESC = "What you do in a conflict travels on as a rumour from party to party, and you hear what "
  .. "others did. A rumour names a kind of person, a place and a faction, never a character."

-- Chat lines for a rumour heard (7.8). {archetype} is an archetype label (PROFILE_*), {place} a zone or, after
-- two hops, a continent, {faction} a faction name; the last two come from the client.
-- Translators: rumours carry no sex. Phrase {archetype} so it needs no gender agreement (as a title or epithet,
-- not after an inflected article or adjective). These keys have no _F forms.
L.RUMOUR_HEARD_ALLIANCE = "People say the {archetype} from {place} has sided with {faction}."
L.RUMOUR_HEARD_BROKE = "People say the {archetype} from {place} broke faith with {faction}."
L.RUMOUR_HEARD_TURNED = "People say the {archetype} from {place} turned from their house to stand with {faction}."
-- Without a faction: after three hops, or when the side has none.
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "People say the {archetype} from {place} has chosen a side."
L.RUMOUR_HEARD_BROKE_VAGUE = "People say the {archetype} from {place} broke their word."
L.RUMOUR_HEARD_TURNED_VAGUE = "People say the {archetype} from {place} turned from their own house."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Side with a faction in a conflict, or group with another Ashmark user, then run "
  .. "/ashmark test again."

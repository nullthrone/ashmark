local _, ns = ...
local L = ns.Locale:Base()

L.PROFILE_MODULE_NAME = "Profile"
L.PROFILE_MODULE_DESC = "Ashmark reads your character from what you do: whether you keep your word, whether you "
  .. "live in the wild or in towns, and how you treat creatures that mean no harm."

-- Archetypes (7.2), a shared vocabulary: shown by the House tab, the Encounters tooltip, the group sentence in
-- the chronicle and in rumours. They name a kind of person and are used as labels, without an article.
-- Translators: where a label inflects for a woman, add PROFILE_<ARCHETYPE>_F; the House tab, the tooltip and the
-- group sentence pick it by the character's sex. Rumours carry no sex and always use the form without _F.
L.PROFILE_OATHKEEPER = "Oathkeeper"
L.PROFILE_OPPORTUNIST = "Opportunist"
L.PROFILE_WANDERER = "Wanderer"
L.PROFILE_TOWNSFOLK = "Town-dweller"
L.PROFILE_GENTLE = "Gentle soul"
L.PROFILE_RUTHLESS = "Ruthless soul"
L.PROFILE_PRAGMATIST = "Pragmatist"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "Kill 3 critters and 3 calm neutral beasts, then run /ashmark test again."
L.PROFILE_TEST_CRITTER_TARGET = "Target any creature, then run /ashmark test again."
L.PROFILE_TEST_CRITTER_OFF = "This client cannot tell critters apart, so critter kills are not counted."

local _, ns = ...
local L = ns.Locale:Base()

L.KNOW_MODULE_NAME = "Character knowledge"
L.KNOW_MODULE_DESC = "Item tooltips show only what your character can know. An item that has never been in "
  .. "this character's bags, bank or equipment shows its name, binding, slot, item level, type and "
  .. "requirements; the rest stays hidden. Items the game itself still hides are left as the game shows them."

-- Last line of such a tooltip (7.7).
L.KNOW_UNKNOWN = "Your character has never held this."

-- Setting (4.3).
L.KNOW_SETTING_QUEST_REWARDS = "Quest rewards in full"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "Never hide the tooltips of rewards shown in the quest dialog, so you can "
  .. "choose a reward knowing what it does."

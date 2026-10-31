local _, ns = ...
local L = ns.Locale:Base()

L.CONFLICT_MODULE_NAME = "Conflicts"
L.CONFLICT_MODULE_DESC = "Some quests set one side against another. Ashmark remembers the side you take, marks quests "
  .. "that contradict it under the quest dialog and records it when you break your word."

-- A side without a reputation faction, used where a faction name would stand. Shared vocabulary:
-- Map and House show it too (ARCHITECTURE 5.8).
L.CONFLICT_UNNAMED = "those without a banner"

-- Quest-dialog line (7.1). {faction} is a faction name from the client, {house} a family name.
L.CONFLICT_CONTRADICTS = "Contradicts your alliance with {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Contradicts the side you have taken."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Your house, {house}, stands against {faction}."
L.CONFLICT_TEST_DIALOG = "Ashmark's line under the quest dialog appears here."

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}. {zone} is a zone name,
-- {quest} a quest title, {faction} the side taken, {broken} the side left.
L.CONFLICT_ALLIED = "You sided with {faction} in {zone}."
L.CONFLICT_ALLIED_THEY = "{name} sided with {faction} in {zone}."
L.CONFLICT_ALLIED_REP = "Your standing with {faction} decided your side in {zone}."
L.CONFLICT_ALLIED_REP_THEY = "Standing with {faction} decided {name}'s side in {zone}."
L.CONFLICT_BROKE_WORD = "You broke faith with {broken} and finished {quest} for {faction}."
L.CONFLICT_BROKE_WORD_THEY = "{name} broke faith with {broken} and finished {quest} for {faction}."
L.CONFLICT_SWITCHED = "You changed sides once more: {quest} for {faction}, and {broken} left behind."
L.CONFLICT_SWITCHED_THEY = "{name} changed sides once more: {quest} for {faction}, and {broken} left behind."
L.CONFLICT_HOUSETURN = "You turned from House {house} and sided with {faction} in {zone}."
L.CONFLICT_HOUSETURN_THEY = "{name} turned from House {house} and sided with {faction} in {zone}."

-- Decisions tab (6.1). {title} is the conflict's title (a quest title from the client), {a} and {b} are
-- the two sides, {date} a short date from the client.
L.CONFLICT_TAB = "Decisions"
L.CONFLICT_TAB_SIDES = "{title}: {a} or {b}"
L.CONFLICT_TAB_ALLIED = "Sided with {faction} since {date}"
L.CONFLICT_TAB_OPEN = "Open"
L.CONFLICT_TAB_BROKEN = "Broken {count}×"
L.CONFLICT_TAB_VIOLATIONS = "Words broken: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "You have not broken your word."
L.CONFLICT_TAB_EMPTY = "Ashmark knows no conflicts in this world yet."

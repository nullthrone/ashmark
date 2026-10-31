local _, ns = ...
local L = ns.Locale:Base()

L.MAP_MODULE_NAME = "World map"
-- No conflict in the shipped data has an anchor yet (Map.anchors counts them); once some do, the
-- description promises conflict marks again.
L.MAP_MODULE_DESC = "Marks your own story on the world map: the places where you broke your word and where your "
  .. "chapters closed. Only you see these marks. Marks for the conflicts you know, and the side you took, come "
  .. "in a later version."

-- Pin tooltips (7.3). {title} is the conflict's title (a quest title from the client), {a} and {b} are the
-- two sides of a conflict and {faction} the side taken, faction names from the client; {count} is a number,
-- {roman} a Roman numeral, {date} a short date from the client.
L.MAP_PIN_SIDES = "{title}: {a} or {b}"
-- Used instead of MAP_PIN_SIDES when {b} begins with the sound /o/ (O-, Ó-, Ho-). Spanish writes
-- "{a} u {b}" here; every other language repeats its MAP_PIN_SIDES.
L.MAP_PIN_SIDES_VOWEL = "{title}: {a} or {b}"
L.MAP_PIN_OPEN = "You have taken no side here."
L.MAP_PIN_ALLIED = "You stand with {faction}."
L.MAP_PIN_BROKEN = "You stand with {faction}, and broke your word here {count}×."
L.MAP_PIN_VIOLATION = "Here you broke your word"
L.MAP_PIN_CHAPTER = "Chapter {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Closed here on {date}"
-- Below the newest of several chapters closed on the same spot; {count} is how many closed there (2 or more).
L.MAP_PIN_CHAPTER_COUNT = "Chapters closed here: {count}"


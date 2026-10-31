local _, ns = ...
local L = ns.Locale:Base()

L.MAP_MODULE_NAME = "World map"
L.MAP_MODULE_DESC = "Marks your own story on the world map: the conflicts you know and the side you took, the "
  .. "places where you broke your word and where your chapters closed. Only you see these marks."

-- Pin tooltips (7.3). {a} and {b} are the two sides of a conflict and {faction} the side taken, faction
-- names from the client; {count} is a number, {roman} a Roman numeral, {date} a short date from the client.
L.MAP_PIN_SIDES = "{a} or {b}"
L.MAP_PIN_OPEN = "You have taken no side here."
L.MAP_PIN_ALLIED = "You stand with {faction}."
L.MAP_PIN_BROKEN = "You stand with {faction}, and broke your word here {count}×."
L.MAP_PIN_VIOLATION = "Here you broke your word"
L.MAP_PIN_CHAPTER = "Chapter {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Closed here on {date}"

-- A side without a reputation faction, where a faction name would stand.
L.MAP_UNNAMED = "those without a banner"

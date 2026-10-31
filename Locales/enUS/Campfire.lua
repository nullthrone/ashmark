local _, ns = ...
local L = ns.Locale:Base()

L.CAMP_MODULE_NAME = "Campfire"
L.CAMP_MODULE_DESC = "Rest at a camp until its benefits take hold, and Ashmark may close a chapter of your "
  .. "chronicle there, when enough has happened since the last one."

-- Centre-screen notice (7.6). {roman} is a Roman numeral, {place} a zone name from the client.
L.CAMP_CHAPTER_CLOSED = "Chapter {roman} closes · {place}"

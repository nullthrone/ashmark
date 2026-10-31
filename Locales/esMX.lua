local _, ns = ...
local L = ns.Locale:For("esMX")

-- Address form: "tú" (tuteo), as in Blizzard's esMX client; plural "ustedes" where the player and others meet.
-- Names from the client carry no article ("Desolace", "Clan Gelkis"), so they stand after "en", "con", "por",
-- "para", "de" or as a direct object, as in the client's own reputation lines ("con %s").
-- CORE_UNKNOWN_FACTION and CORE_UNKNOWN_PLACE carry their own article or determiner ("una facción",
-- "algún lugar"). "o" and "y" before {b} and {last} stay as written; a name that begins with an "o" or "i"
-- sound would call for "u" or "e".

-- Core ---------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark solo funciona en World of Warcraft Forever y permanece desactivado en este cliente."
L.CORE_SV_NEW = "Se inició un nuevo registro. Si ya usaste Ashmark en esta cuenta, los datos guardados no se "
  .. "cargaron: no vuelvas a usar /reload ni a cerrar sesión. Sal del juego y reemplaza Ashmark.lua por "
  .. "Ashmark.lua.bak en WTF\\Account\\<cuenta>\\SavedVariables\\ antes de volver a iniciar sesión."
L.CORE_SV_NEWER = "Estos datos guardados provienen de una versión más reciente de Ashmark. Ashmark solo los "
  .. "leerá hasta que lo actualices."
L.CORE_SV_RECOVERED = "Los datos guardados no tenían un formato que Ashmark reconozca. Se inició un nuevo registro; "
  .. "los datos anteriores se conservan intactos en AshmarkDB.recovered."
L.CORE_SV_MIGRATE_FAILED = "Ashmark no pudo actualizar sus datos guardados y durante esta sesión solo los leerá."

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "El módulo {module} se detuvo tras errores repetidos y permanecerá desactivado hasta la "
  .. "próxima recarga."
L.CORE_UNAVAILABLE = "Requiere: {capability}"
L.CORE_MISSING_EVENTS = "Eventos que faltan en este cliente: {events}"
L.CORE_SETTING_CHAT_LINES = "Líneas en el chat"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark puede escribir líneas breves en la ventana de chat."
L.CORE_SETTING_SOUNDS = "Sonidos"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark reproduce los sonidos de páginas y libros del juego."
L.CORE_SETTING_SHARE = "Compartir con usuarios de Ashmark"
L.CORE_SETTING_SHARE_DESC = "Envía tu arquetipo, tu origen y tus rumores a los miembros del grupo que también "
  .. "usan Ashmark. Los contactos y las notas nunca salen de tu cliente."

-- Shared vocabulary (5.8)
L.CORE_UNKNOWN_QUEST = "una misión"
L.CORE_UNKNOWN_ITEM = "un objeto"
L.CORE_UNKNOWN_FACTION = "una facción"
L.CORE_UNKNOWN_PLACE = "algún lugar"
L.CORE_UNKNOWN_PLAYER = "alguien"
L.CORE_UNKNOWN_CLASS = "Aventurero"           -- a label in ENC_TAB_WHO, like the client's class names
L.CORE_UNKNOWN_RACE = "Pueblo desconocido"    -- a label in ENC_TAB_WHO, like the client's race names
L.CORE_RULESET_NORMAL = "Normal"
L.CORE_RULESET_PVP = "JcJ"
L.CORE_RULESET_RP = "Rol"
L.CORE_RULESET_RPPVP = "Rol JcJ"
L.CORE_RULESET_HARDCORE = "Hardcore"

-- Chronicle sentences for Core's kinds; _THEY forms are used in the family chronicle with {name}.
L.CORE_LOG_TURNIN = "Completaste {quest}."
L.CORE_LOG_TURNIN_THEY = "{name} completó {quest}."
L.CORE_LOG_ABANDON = "Abandonaste {quest}."
L.CORE_LOG_ABANDON_THEY = "{name} abandonó {quest}."
L.CORE_LOG_ZONE_FIRST = "Pusiste un pie en {zone} por primera vez."
L.CORE_LOG_ZONE_FIRST_THEY = "{name} puso un pie en {zone} por primera vez."
L.CORE_LOG_LEVEL = "Alcanzaste el nivel {level}."
L.CORE_LOG_LEVEL_THEY = "{name} alcanzó el nivel {level}."
L.CORE_LOG_DEATH = "Moriste en {place}."
L.CORE_LOG_DEATH_THEY = "{name} murió en {place}."
-- {standing} is the client's label, already in the character's gender ("Amistoso", "Amistosa").
L.CORE_LOG_REP = "Ahora eres {standing} con {faction}."
L.CORE_LOG_REP_THEY = "{name} ahora es {standing} con {faction}."
L.CORE_LOG_CHAPTER = "El capítulo {roman} se cierra en {place}."
L.CORE_LOG_CHAPTER_THEY = "El capítulo {roman} de {name} se cierra en {place}."

-- Slash commands (5.9)
L.CORE_HELP_HEADER = "Comandos:"
L.CORE_HELP_TOGGLE = "abre o cierra la crónica"
L.CORE_HELP_HELP = "muestra estos comandos"
L.CORE_HELP_DEBUG = "activa o desactiva los mensajes de depuración durante esta sesión"
L.CORE_HELP_RESET = "borra el registro de este personaje; \"reset others\" borra los contactos, los datos de "
  .. "otros usuarios de Ashmark y los rumores escuchados"
L.CORE_UNKNOWN_COMMAND = "Comando desconocido: {command}"
L.CORE_DEBUG_ON = "Los mensajes de depuración están activados durante esta sesión."
L.CORE_DEBUG_OFF = "Los mensajes de depuración están desactivados."
L.CORE_RESET_CONFIRM = "¿Borrar todo lo que Ashmark registró de este personaje? Esto no se puede deshacer."
L.CORE_RESET_OTHERS_CONFIRM = "¿Borrar todos los contactos, los datos de otros usuarios de Ashmark y los rumores "
  .. "escuchados en esta cuenta? Tus propios rumores se conservan. Esto no se puede deshacer."
L.CORE_RESET_ACCEPT = "Borrar"
L.CORE_CANCEL = "Cancelar"
L.CORE_RESET_DONE = "Se borró el registro de este personaje."
L.CORE_RESET_OTHERS_DONE = "Se borraron los contactos, los datos de otros usuarios de Ashmark y los rumores "
  .. "escuchados."
L.CORE_RESET_READONLY = "Los datos guardados provienen de una versión más reciente de Ashmark, así que no se puede "
  .. "borrar nada."

-- UI shell (6.1, 6.2): main window tabs, the Chronicle tab and the Addon Compartment
L.CORE_TAB_CHRONICLE = "Crónica"
L.CORE_CHRONICLE_CHAPTER = "Capítulo {roman}"
L.CORE_CHRONICLE_CHAPTER_OPEN = "Capítulo {roman} (actual)"
L.CORE_CHRONICLE_CLOSED = "Cerrado el {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "Iniciado el {date} · aún se está escribiendo"
L.CORE_CHRONICLE_OPEN = "Aún se está escribiendo"
L.CORE_CHRONICLE_EMPTY = "Nada en este capítulo merece contarse todavía."
L.CORE_CHRONICLE_NO_RECORD = "Ashmark aún no lleva ningún registro de este personaje."
L.CORE_COMPARTMENT_CLICK = "Haz clic para abrir o cerrar la crónica."
L.CORE_COMPARTMENT_RIGHT_CLICK = "Haz clic derecho para abrir las opciones."

-- Test ---------------------------------------------------------------------------------------------------

L.TEST_HELP = "ejecuta la autoprueba en este cliente y toma una captura de pantalla"
L.TEST_HELP_PROBE = "registra datos sin procesar sobre este cliente para los desarrolladores"
L.TEST_NOT_IN_COMBAT = "La prueba no se ejecuta en combate. Vuelve a intentarlo cuando termine la pelea."
L.TEST_SUMMARY = "Prueba terminada. Superadas: {passed}, fallidas: {failed}, omitidas: {skipped}."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "superada"
L.TEST_FAIL = "FALLIDA"
L.TEST_SKIP = "omitida"
L.TEST_OPEN_QUEST_DIALOG = "Para la captura de pantalla, primero habla con un PNJ que ofrezca misiones."
L.TEST_RELOAD = "Escribe /reload para guardar los resultados."
L.TEST_NOT_STORED = "Los datos guardados provienen de una versión más reciente de Ashmark, así que no se guarda "
  .. "nada. A continuación, el informe completo."
L.TEST_LATE = "Resultado tardío: {what}"
L.TEST_PROBE_DONE = "Datos registrados por la sonda: {count}."
L.TEST_PROBE_NEXT = "Acepta una misión e inicia un combate durante esta sesión: la sonda registra ambas cosas."

-- Conflicts ----------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "Conflictos"
L.CONFLICT_MODULE_DESC = "Algunas misiones enfrentan a un bando con otro. Ashmark recuerda el bando que eliges, "
  .. "marca bajo la ventana de misión las misiones que lo contradicen y registra las veces que faltas a tu palabra."

-- Stands where a faction name would: after "con", "por", "para", "a", "de", "dejando atrás a" and in "{a} o {b}".
L.CONFLICT_UNNAMED = "quienes van sin estandarte"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "Contradice tu compromiso con {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Contradice el bando que elegiste."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Tu casa, {house}, se opone a {faction}."
L.CONFLICT_TEST_DIALOG = "Aquí aparece la línea de Ashmark bajo la ventana de misión."

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}.
L.CONFLICT_ALLIED = "Tomaste partido por {faction} en {zone}."
L.CONFLICT_ALLIED_THEY = "{name} tomó partido por {faction} en {zone}."
L.CONFLICT_ALLIED_REP = "Tu reputación con {faction} decidió tu bando en {zone}."
L.CONFLICT_ALLIED_REP_THEY = "La reputación de {name} con {faction} decidió su bando en {zone}."
L.CONFLICT_BROKE_WORD = "Faltaste a tu palabra con {broken} y completaste {quest} para {faction}."
L.CONFLICT_BROKE_WORD_THEY = "{name} faltó a su palabra con {broken} y completó {quest} para {faction}."
L.CONFLICT_SWITCHED = "Cambiaste de bando una vez más: {quest} para {faction}, dejando atrás a {broken}."
L.CONFLICT_SWITCHED_THEY = "{name} cambió de bando una vez más: {quest} para {faction}, dejando atrás a {broken}."
L.CONFLICT_HOUSETURN = "Le diste la espalda a la Casa {house} y tomaste partido por {faction} en {zone}."
L.CONFLICT_HOUSETURN_THEY = "{name} le dio la espalda a la Casa {house} y tomó partido por {faction} en {zone}."

-- Decisions tab (6.1)
L.CONFLICT_TAB = "Decisiones"
L.CONFLICT_TAB_SIDES = "{a} o {b}"
L.CONFLICT_TAB_ALLIED = "Del lado de {faction} desde el {date}"
L.CONFLICT_TAB_OPEN = "Sin decidir"
L.CONFLICT_TAB_BROKEN = "Palabra rota {count}×"
L.CONFLICT_TAB_VIOLATIONS = "Veces que faltaste a tu palabra: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "No has faltado a tu palabra."
L.CONFLICT_TAB_EMPTY = "Ashmark aún no conoce ningún conflicto en este mundo."

-- Profile ------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "Perfil"
L.PROFILE_MODULE_DESC = "Ashmark deduce cómo es tu personaje a partir de lo que haces: si cumples tu palabra, si "
  .. "vives en tierras salvajes o en ciudades, y cómo tratas a las criaturas que no buscan hacer daño."

-- Archetypes (7.2): labels without an article. _F forms where the character's sex is known; "Oportunista",
-- "Errante" and the two "Alma" labels are the same for both.
L.PROFILE_OATHKEEPER = "Guardián de juramentos"
L.PROFILE_OATHKEEPER_F = "Guardiana de juramentos"
L.PROFILE_OPPORTUNIST = "Oportunista"
L.PROFILE_WANDERER = "Errante"
L.PROFILE_TOWNSFOLK = "Citadino"
L.PROFILE_TOWNSFOLK_F = "Citadina"
L.PROFILE_GENTLE = "Alma compasiva"
L.PROFILE_RUTHLESS = "Alma despiadada"
L.PROFILE_PRAGMATIST = "Pragmático"
L.PROFILE_PRAGMATIST_F = "Pragmática"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "Mata 3 alimañas y 3 bestias neutrales y tranquilas, y luego vuelve a escribir "
  .. "/ashmark test."
L.PROFILE_TEST_CRITTER_TARGET = "Selecciona cualquier criatura como objetivo y luego vuelve a escribir /ashmark test."
L.PROFILE_TEST_CRITTER_OFF = "Este cliente no distingue a las alimañas, así que no se cuentan las que mates."

-- Map ----------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "Mapa del mundo"
L.MAP_MODULE_DESC = "Marca tu propia historia en el mapa del mundo: los conflictos que conoces y el bando que "
  .. "elegiste, los lugares donde faltaste a tu palabra y donde se cerraron tus capítulos. Solo tú ves estas "
  .. "marcas."

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{a} o {b}"
L.MAP_PIN_OPEN = "Aquí no has tomado partido."
L.MAP_PIN_ALLIED = "Estás del lado de {faction}."
L.MAP_PIN_BROKEN = "Estás del lado de {faction} y aquí faltaste a tu palabra {count}×."
L.MAP_PIN_VIOLATION = "Aquí faltaste a tu palabra"
L.MAP_PIN_CHAPTER = "Capítulo {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Cerrado aquí el {date}"

-- Encounters ---------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "Encuentros"
L.ENC_MODULE_DESC = "Ashmark recuerda a las personas con las que formas grupo: cuántas veces te encontraste "
  .. "con ellas, dónde y cómo te fue. Agrega una línea a su descripción emergente, las muestra en la pestaña "
  .. "Encuentros y guarda tus notas sobre ellas. Los contactos y las notas nunca salen de tu cliente."

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "Encuentros: {count} · el último en {place}"
L.ENC_TOOLTIP_NOPLACE = "Encuentros: {count}"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "Conoces a {name}: se encontraron {count}×, la última vez en {place}."
L.ENC_RECOGNISE_NOPLACE = "Conoces a {name}: se encontraron {count}×."
L.ENC_RECOGNISE_MORE = "…y {count} más que conoces."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "Rostro conocido"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "Tu nota sobre {name}:"
L.ENC_NOTE_SAVE = "Guardar"

-- Encounters tab (6.1). The client's race name does not follow the character's sex, so race and class stand
-- as two labels.
L.ENC_TAB = "Encuentros"
L.ENC_TAB_TOTAL = "Personas que conociste: {count} · rostros conocidos: {recurring}"
L.ENC_TAB_EMPTY = "Nadie se ha cruzado en tu camino todavía. Forma grupo con alguien y Ashmark lo recordará."
L.ENC_TAB_MET = "Encuentros: {count} · el último en {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "Encuentros: {count} · {date}"
L.ENC_TAB_NOTE = "Nota"
L.ENC_TAB_WHO = "{race} · {class}"
L.ENC_TAB_FIRST = "Primer encuentro: {date}"

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}, the family member.
-- {people} follows "con", "junto a" and "del grupo de".
L.ENC_LOG_CONTACT = "Te cruzaste con {contact} por primera vez."
L.ENC_LOG_CONTACT_THEY = "{name} se cruzó con {contact} por primera vez."
L.ENC_LOG_TRAVEL = "Viajaste con {people}."
L.ENC_LOG_TRAVEL_THEY = "{name} viajó con {people}."
L.ENC_LOG_BOSS = "Luchaste junto a {people} y venciste."
L.ENC_LOG_BOSS_THEY = "{name} luchó junto a {people} y venció."
L.ENC_LOG_WIPE = "Luchaste junto a {people} y caíste."
L.ENC_LOG_WIPE_THEY = "{name} luchó junto a {people} y cayó."
L.ENC_LOG_CAMP = "Compartiste una fogata con {people}."
L.ENC_LOG_CAMP_THEY = "{name} compartió una fogata con {people}."
L.ENC_LOG_KICK = "Fuiste expulsado del grupo de {people}."
L.ENC_LOG_KICK_F = "Fuiste expulsada del grupo de {people}."
L.ENC_LOG_KICK_THEY = "{name} fue expulsado del grupo de {people}."
L.ENC_LOG_KICK_THEY_F = "{name} fue expulsada del grupo de {people}."

-- Parts of {people}
L.ENC_LOG_PEER = "{who} ({archetype}, de {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "otra persona"
L.ENC_LOG_OTHERS = "otras {count} personas"
L.ENC_LOG_STRANGER = "un desconocido"
L.ENC_LOG_STRANGERS = "{count} desconocidos"
L.ENC_LOG_STRANGERS_ANY = "desconocidos"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} y {last}"

-- House --------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "Casa"
L.HOUSE_MODULE_DESC = "Los personajes de esta cuenta que comparten apellido forman una casa. La pestaña Casa "
  .. "muestra a sus miembros, las enemistades que hicieron suyas tus parientes, la crónica familiar y las "
  .. "personas que conocen."

-- /ashmark house (5.9)
L.HOUSE_HELP = "muestra tu casa; \"house <nombre>\" te une a la casa de ese nombre, \"house reset\" te devuelve "
  .. "a la casa de tu apellido"
L.HOUSE_SLASH_CURRENT = "Perteneces a la Casa {house}."
L.HOUSE_SLASH_NONE = "No perteneces a ninguna casa. Escribe /ashmark house <nombre> para unirte a una."
L.HOUSE_SLASH_SET = "Ahora perteneces a la Casa {house}."
L.HOUSE_SLASH_RESET = "Tu casa vuelve a ser la de tu apellido: Casa {house}."
L.HOUSE_SLASH_RESET_NONE = "Tu casa vuelve a ser la de tu apellido. Sin apellido, no perteneces a ninguna casa."
L.HOUSE_SLASH_OFF = "El módulo Casa está desactivado o no está disponible, así que por ahora no puedes cambiar "
  .. "de casa."

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "Casa"
L.HOUSE_TAB_HEADING = "Casa {house}"
L.HOUSE_TAB_NO_HOUSE = "Sin casa"
L.HOUSE_TAB_NONE = "Los personajes de esta cuenta que comparten apellido forman una casa. Ashmark no conoce "
  .. "ningún apellido de este personaje: escribe /ashmark house <nombre> para elegir una casa."
L.HOUSE_TAB_ARCHETYPE = "Arquetipo: {archetype}"
L.HOUSE_TAB_MEMBERS = "Miembros"
L.HOUSE_TAB_MEMBER = "{name}, nivel {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "Enemistades heredadas"
L.HOUSE_TAB_FEUD = "{name} tomó partido por {faction} en {zone}."
L.HOUSE_TAB_CHRONICLE = "Crónica familiar"
L.HOUSE_TAB_MEMORY = "Memoria familiar"
L.HOUSE_TAB_KNOWS = "{sibling} conoce a {name}."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}: nivel {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

-- Campfire -----------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "Fogata"
L.CAMP_MODULE_DESC = "Descansa en un campamento hasta que sus beneficios surtan efecto, y Ashmark podrá cerrar "
  .. "allí un capítulo de tu crónica, si ha ocurrido lo suficiente desde el anterior."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "Se cierra el capítulo {roman} · {place}"

-- Knowledge ----------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "Conocimiento del personaje"
L.KNOW_MODULE_DESC = "Las descripciones emergentes de los objetos muestran solo lo que tu personaje puede saber. "
  .. "Un objeto que nunca estuvo en las bolsas, el banco o el equipo de este personaje muestra su nombre, cómo "
  .. "se liga, su ranura, su nivel de objeto, su tipo y sus requisitos; el resto permanece oculto. Los objetos "
  .. "que el propio juego todavía oculta se quedan tal como los muestra el juego."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "Tu personaje nunca ha tenido este objeto."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "Recompensas de misión completas"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "Nunca oculta las descripciones emergentes de las recompensas que aparecen en "
  .. "la ventana de misión, para que puedas elegir una recompensa sabiendo lo que hace."

-- Fiction ------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "Ficción compartida"
L.FICTION_MODULE_DESC = "Los miembros del grupo que también usan Ashmark se enteran de tu arquetipo y tu origen "
  .. "sin una sola palabra en el chat, y tú de los suyos, para que tu crónica y tus descripciones emergentes "
  .. "sepan con quién viajaste. No se muestra nada a otros jugadores."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "Forma grupo con otro usuario de Ashmark y luego vuelve a escribir /ashmark test."

-- Rumours ------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "Rumores"
L.RUMOUR_MODULE_DESC = "Lo que haces en un conflicto viaja como rumor de grupo en grupo, y tú escuchas lo que "
  .. "hicieron otros. Un rumor menciona un tipo de persona, un lugar y una facción, nunca a un personaje."

-- Chat lines for a rumour heard (7.8). Rumours carry no sex: {archetype} stands as a quoted nickname after
-- "alguien a quien llaman", so the masculine label needs no agreement. {place} is a zone or a continent.
-- No _F forms.
L.RUMOUR_HEARD_ALLIANCE = "Cuentan que en {place} alguien a quien llaman \"{archetype}\" tomó partido por "
  .. "{faction}."
L.RUMOUR_HEARD_BROKE = "Cuentan que en {place} alguien a quien llaman \"{archetype}\" faltó a su palabra con "
  .. "{faction}."
L.RUMOUR_HEARD_TURNED = "Cuentan que en {place} alguien a quien llaman \"{archetype}\" le dio la espalda a su "
  .. "casa para ponerse del lado de {faction}."
-- Without a faction: after three hops, or when the side has none.
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "Cuentan que en {place} alguien a quien llaman \"{archetype}\" eligió un bando."
L.RUMOUR_HEARD_BROKE_VAGUE = "Cuentan que en {place} alguien a quien llaman \"{archetype}\" faltó a su palabra."
L.RUMOUR_HEARD_TURNED_VAGUE = "Cuentan que en {place} alguien a quien llaman \"{archetype}\" le dio la espalda a "
  .. "su propia casa."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Toma partido por una facción en un conflicto o forma grupo con otro usuario de Ashmark, "
  .. "y luego vuelve a escribir /ashmark test."

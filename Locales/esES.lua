local _, ns = ...
local L = ns.Locale:For("esES")

-- Address form: "tú" (tú/te/ti/tu), as in Blizzard's esES client ("Has alcanzado el nivel…", "Ahora eres %s con
-- %s.", "Tu reputación con %s…").
-- Names from the client stand bare, as the client itself writes them: "con {faction}", "en {zone}", "a {broken}".
-- Chronicle sentences are told in the pretérito indefinido ("Completaste", "{name} murió").
-- CORE_UNKNOWN_* carry their own article or need none ("una misión", "algún lugar", "alguien"), so they fit the
-- same frames as the client names they replace. CONFLICT_UNNAMED reads as a name ("Los Sin Estandarte").

-- Core -----------------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark solo funciona en World of Warcraft Forever y permanece desactivado en este cliente."
L.CORE_SV_NEW = "Ha comenzado un registro nuevo. Si ya usabas Ashmark en esta cuenta, los datos guardados no se "
  .. "han cargado: no uses /reload ni vuelvas a desconectarte. Sal del juego y, antes de volver a conectarte, "
  .. "sustituye Ashmark.lua por Ashmark.lua.bak en WTF\\Account\\<cuenta>\\SavedVariables\\."
L.CORE_SV_NEWER = "Estos datos guardados proceden de una versión más reciente de Ashmark. Ashmark solo los leerá "
  .. "hasta que lo actualices."
L.CORE_SV_RECOVERED = "Los datos guardados no tenían un formato que Ashmark conozca. Ha comenzado un registro "
  .. "nuevo; los datos antiguos se conservan intactos en AshmarkDB.recovered."
L.CORE_SV_MIGRATE_FAILED = "Ashmark no ha podido actualizar sus datos guardados y en esta sesión solo los leerá."

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "El módulo {module} se ha detenido tras repetidos errores y seguirá desactivado hasta la "
  .. "próxima recarga."
L.CORE_UNAVAILABLE = "Requiere {capability}"
L.CORE_UNAVAILABLE_CLIENT = "A este cliente le falta una función que este módulo necesita."
L.CORE_MISSING_EVENTS = "Eventos que le faltan a este cliente: {events}"
L.CORE_SETTING_CHAT_LINES = "Líneas en el chat"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark puede escribir líneas breves en la ventana de chat."
L.CORE_SETTING_SOUNDS = "Sonidos"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark reproduce los sonidos de páginas y libros del juego."
L.CORE_SETTING_SHARE = "Compartir con otros usuarios de Ashmark"
L.CORE_SETTING_SHARE_DESC = "Envía tu arquetipo, tu origen, tus valores de perfil (fidelidad, hábitat, "
  .. "clemencia), tu tipo de reino, tu versión de Ashmark y tus rumores a los miembros del grupo que también usen "
  .. "Ashmark. Los contactos y las notas nunca salen de tu cliente."

-- Shared vocabulary (5.8)
L.CORE_UNKNOWN_QUEST = "una misión"
L.CORE_UNKNOWN_ITEM = "un objeto"
L.CORE_UNKNOWN_FACTION = "una facción"
L.CORE_UNKNOWN_PLACE = "algún lugar"
L.CORE_UNKNOWN_PLAYER = "alguien"
L.CORE_UNKNOWN_CLASS = "Aventurero"
L.CORE_UNKNOWN_RACE = "Pueblo desconocido"
L.CORE_RULESET_NORMAL = "Normal"
L.CORE_RULESET_PVP = "JcJ"
L.CORE_RULESET_RP = "Rol"
L.CORE_RULESET_RPPVP = "Rol JcJ"
L.CORE_RULESET_HARDCORE = "Hardcore"

-- Chronicle sentences. {standing} comes from the client already in the character's gender ("Amistosa").
L.CORE_LOG_TURNIN = "Completaste {quest}."
L.CORE_LOG_TURNIN_THEY = "{name} completó {quest}."
L.CORE_LOG_ABANDON = "Abandonaste {quest}."
L.CORE_LOG_ABANDON_THEY = "{name} abandonó {quest}."
L.CORE_LOG_ZONE_FIRST = "Pisaste {zone} por primera vez."
L.CORE_LOG_ZONE_FIRST_THEY = "{name} pisó {zone} por primera vez."
L.CORE_LOG_LEVEL = "Alcanzaste el nivel {level}."
L.CORE_LOG_LEVEL_THEY = "{name} alcanzó el nivel {level}."
L.CORE_LOG_DEATH = "Moriste en {place}."
L.CORE_LOG_DEATH_THEY = "{name} murió en {place}."
L.CORE_LOG_REP = "Ahora eres {standing} con {faction}."
L.CORE_LOG_REP_THEY = "{name} es ahora {standing} con {faction}."
L.CORE_LOG_CHAPTER = "El capítulo {roman} se cierra en {place}."
L.CORE_LOG_CHAPTER_THEY = "El capítulo {roman} de {name} se cierra en {place}."
L.CORE_LOG_DEATH_NOZONE = "Moriste en {place}."
L.CORE_LOG_DEATH_NOZONE_THEY = "{name} murió en {place}."
L.CORE_LOG_CHAPTER_NOZONE = "El capítulo {roman} se cierra en {place}."
L.CORE_LOG_CHAPTER_NOZONE_THEY = "El capítulo {roman} de {name} se cierra en {place}."

-- Slash commands (5.9)
L.CORE_HELP_HEADER = "Comandos:"
L.CORE_HELP_TOGGLE = "abrir o cerrar la crónica"
L.CORE_HELP_HELP = "mostrar estos comandos"
L.CORE_HELP_DEBUG = "activar o desactivar los mensajes de depuración durante esta sesión"
L.CORE_HELP_RESET = "borrar el registro de este personaje; «reset others» borra los contactos, los datos de otros "
  .. "usuarios de Ashmark y los rumores oídos; «reset <nombre>» olvida a otro personaje de esta cuenta"
L.CORE_UNKNOWN_COMMAND = "Comando desconocido: {command}"
L.CORE_DEBUG_ON = "Los mensajes de depuración están activados durante esta sesión."
L.CORE_DEBUG_OFF = "Los mensajes de depuración están desactivados."
L.CORE_RESET_CONFIRM = "¿Borrar todo lo que Ashmark ha registrado de este personaje? Esta acción no se puede "
  .. "deshacer."
L.CORE_RESET_OTHERS_CONFIRM = "¿Borrar todos los contactos, los datos de otros usuarios de Ashmark y los rumores "
  .. "oídos en esta cuenta? Tus propios rumores se conservan. Esta acción no se puede deshacer."
L.CORE_RESET_ACCEPT = "Borrar"
L.CORE_CANCEL = "Cancelar"
L.CORE_RESET_DONE = "Se ha borrado el registro de este personaje."
L.CORE_RESET_OTHERS_DONE = "Se han borrado los contactos, los datos de otros usuarios de Ashmark y los rumores "
  .. "oídos."
L.CORE_RESET_READONLY = "Los datos guardados proceden de una versión más reciente de Ashmark, así que no se puede "
  .. "borrar nada."
L.CORE_RESET_CHAR_UNKNOWN = "No hay ningún otro personaje llamado {name} guardado en esta cuenta."
L.CORE_RESET_CHAR_AMBIGUOUS = "Hay varios personajes llamados {name}. Escribe /ashmark reset <GUID> con el GUID de "
  .. "uno de ellos:"
L.CORE_RESET_CHAR_LINE = "{name}, nivel {level}: {guid}"
L.CORE_RESET_CHAR_CONFIRM = "¿Olvidar a {name}? Ashmark borra la crónica, las decisiones, el perfil y los "
  .. "encuentros de este personaje. Hazlo solo con un personaje que hayas borrado o transferido."
L.CORE_RESET_CHAR_DONE = "Ashmark ha olvidado a {name}."

-- UI shell (6.1, 6.2). "Cerrado" and "Iniciado" agree with "capítulo".
L.CORE_TAB_CHRONICLE = "Crónica"
L.CORE_CHRONICLE_CHAPTER = "Capítulo {roman}"
L.CORE_CHRONICLE_CHAPTER_OPEN = "Capítulo {roman} (actual)"
L.CORE_CHRONICLE_CLOSED = "Cerrado el {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "Iniciado el {date} · aún se está escribiendo"
L.CORE_CHRONICLE_OPEN = "Aún se está escribiendo"
L.CORE_CHRONICLE_EMPTY = "Aún no ha ocurrido nada en este capítulo que merezca contarse."
L.CORE_CHRONICLE_NO_RECORD = "Ashmark aún no lleva ningún registro de este personaje."
L.CORE_COMPARTMENT_CLICK = "Haz clic para abrir o cerrar la crónica."
L.CORE_COMPARTMENT_RIGHT_CLICK = "Haz clic derecho para abrir las opciones."

-- Test -----------------------------------------------------------------------------------------------------------

L.TEST_HELP = "ejecutar la autoprueba en este cliente y hacer una captura de pantalla"
L.TEST_HELP_PROBE = "registrar datos en bruto de este cliente para los desarrolladores"
L.TEST_NOT_IN_COMBAT = "La prueba no se ejecuta en combate. Vuelve a intentarlo cuando termine el combate."
L.TEST_SUMMARY = "Prueba terminada. Superadas: {passed}; fallidas: {failed}; omitidas: {skipped}."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "superada"
L.TEST_FAIL = "FALLIDA"
L.TEST_SKIP = "omitida"
L.TEST_OPEN_QUEST_DIALOG = "Para la captura de pantalla, habla primero con un PNJ que ofrezca misiones."
L.TEST_RELOAD = "Escribe /reload para guardar los resultados."
L.TEST_NOT_STORED = "Los datos guardados proceden de una versión más reciente de Ashmark, así que no se guarda "
  .. "nada. A continuación figura el informe completo."
L.TEST_NOT_STORED_MIGRATION = "Ashmark no ha podido actualizar sus datos guardados, así que no se guarda nada. A "
  .. "continuación figura el informe completo."
L.TEST_LATE = "Resultado posterior: {what}"
L.TEST_PROBE_DONE = "La sonda ha registrado {count} datos."
L.TEST_PROBE_NEXT = "Acepta una misión y empieza un combate en esta sesión: la sonda registra ambas cosas."

-- Conflicts ------------------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "Conflictos"
L.CONFLICT_MODULE_DESC = "Algunas misiones enfrentan a un bando con otro. Ashmark recuerda el bando que eliges, "
  .. "marca bajo la ventana de misión las misiones que lo contradicen y deja constancia cuando faltas a tu palabra."

-- A side without a reputation faction, standing where a faction name would: a name, so it also opens "{a} o {b}".
L.CONFLICT_UNNAMED = "Los Sin Estandarte"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "Contradice tu alianza con {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Contradice el bando que has elegido."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Tu casa, {house}, se opone a {faction}."
L.CONFLICT_TEST_DIALOG = "Aquí aparece la línea de Ashmark bajo la ventana de misión."

-- Chronicle sentences. {broken} never needs to agree: it stands after "a".
L.CONFLICT_ALLIED = "Te pusiste del lado de {faction} en {zone} ({title})."
L.CONFLICT_ALLIED_THEY = "{name} se puso del lado de {faction} en {zone} ({title})."
L.CONFLICT_ALLIED_REP = "Tu reputación con {faction} decidió tu bando en {zone}."
L.CONFLICT_ALLIED_REP_THEY = "La reputación de {name} con {faction} decidió su bando en {zone}."
L.CONFLICT_BROKE_WORD = "Faltaste a la palabra dada a {broken} y completaste {quest} para {faction}."
L.CONFLICT_BROKE_WORD_THEY = "{name} faltó a la palabra dada a {broken} y completó {quest} para {faction}."
L.CONFLICT_SWITCHED = "Cambiaste de bando una vez más: completaste {quest} para {faction} y dejaste atrás a "
  .. "{broken}."
L.CONFLICT_SWITCHED_THEY = "{name} cambió de bando una vez más: completó {quest} para {faction} y dejó atrás a "
  .. "{broken}."
L.CONFLICT_HOUSETURN = "Le diste la espalda a la Casa {house} y te pusiste del lado de {faction} en {zone}."
L.CONFLICT_HOUSETURN_THEY = "{name} le dio la espalda a la Casa {house} y se puso del lado de {faction} en {zone}."

-- Decisions tab (6.1). "×" keeps the counts free of singular and plural.
L.CONFLICT_TAB = "Decisiones"
L.CONFLICT_TAB_SIDES = "{title}: {a} o {b}"
L.CONFLICT_TAB_SIDES_VOWEL = "{title}: {a} u {b}"
L.CONFLICT_TAB_ALLIED = "Del lado de {faction} desde el {date}"
L.CONFLICT_TAB_OPEN = "Sin decidir"
L.CONFLICT_TAB_BROKEN = "Palabra rota {count}×"
L.CONFLICT_TAB_VIOLATIONS = "Veces que has faltado a tu palabra: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "No has faltado a tu palabra."
L.CONFLICT_TAB_EMPTY = "Ashmark aún no conoce ningún conflicto en este mundo."

-- Profile --------------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "Perfil"
L.PROFILE_MODULE_DESC = "Ashmark deduce cómo es tu personaje a partir de lo que haces: si cumples tu palabra, si "
  .. "vives en tierras salvajes o en ciudades, y cómo tratas a las criaturas que no pretenden hacer daño."

-- Archetypes (7.2): labels without an article. "Guardajuramentos", "Oportunista" and "Errante" serve both sexes,
-- and "Alma" is feminine whatever the sex, so only "Ciudadano" and "Pragmático" have _F forms.
L.PROFILE_OATHKEEPER = "Guardajuramentos"
L.PROFILE_OPPORTUNIST = "Oportunista"
L.PROFILE_WANDERER = "Errante"
L.PROFILE_TOWNSFOLK = "Ciudadano"
L.PROFILE_TOWNSFOLK_F = "Ciudadana"
L.PROFILE_GENTLE = "Alma compasiva"
L.PROFILE_RUTHLESS = "Alma despiadada"
L.PROFILE_PRAGMATIST = "Pragmático"
L.PROFILE_PRAGMATIST_F = "Pragmática"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "Mata 3 alimañas y 3 bestias neutrales tranquilas; después, vuelve a ejecutar "
  .. "/ashmark test."
L.PROFILE_TEST_CRITTER_TARGET = "Selecciona como objetivo cualquier criatura y vuelve a ejecutar /ashmark test."
L.PROFILE_TEST_CRITTER_OFF = "Este cliente no distingue las alimañas, así que no se cuentan las que matas."

-- Map ------------------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "Mapa del mundo"
L.MAP_MODULE_DESC = "Marca tu propia historia en el mapa del mundo: los lugares donde faltaste a tu palabra y "
  .. "donde se cerraron tus capítulos. Solo tú ves estas marcas. Las marcas de los conflictos que conoces, y del "
  .. "bando que tomaste, llegarán en una versión posterior."

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{title}: {a} o {b}"
L.MAP_PIN_SIDES_VOWEL = "{title}: {a} u {b}"
L.MAP_PIN_OPEN = "Aquí no has tomado partido."
L.MAP_PIN_ALLIED = "Estás del lado de {faction}."
L.MAP_PIN_BROKEN = "Estás del lado de {faction} y aquí has faltado a tu palabra {count}×."
L.MAP_PIN_VIOLATION = "Aquí faltaste a tu palabra"
L.MAP_PIN_CHAPTER = "Capítulo {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Cerrado aquí el {date}"
L.MAP_PIN_CHAPTER_COUNT = "Capítulos cerrados aquí: {count}"

-- Encounters -----------------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "Encuentros"
L.ENC_MODULE_DESC = "Ashmark recuerda a las personas con las que formas grupo: cuántas veces habéis coincidido, "
  .. "dónde y cómo fue. Añade una línea a su descripción emergente, las muestra en la pestaña Encuentros y guarda "
  .. "tus notas sobre ellas. Los contactos y las notas nunca salen de tu cliente."

-- Unit tooltip (7.4). "Encuentros:" and "×" keep the counts free of singular and plural.
L.ENC_TOOLTIP = "Encuentros: {count} · el último en {place}"
L.ENC_TOOLTIP_NOPLACE = "Encuentros: {count}"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "Conoces a {name}: habéis coincidido {count}×, la última vez en {place}."
L.ENC_RECOGNISE_NOPLACE = "Conoces a {name}: habéis coincidido {count}×."
L.ENC_RECOGNISE_MORE = "…y {count} más que conoces."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "Cara conocida"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "Tu nota sobre {name}:"
L.ENC_NOTE_SAVE = "Guardar"

-- Encounters tab (6.1). "·" between race and class, so neither has to read as the other's adjective and the
-- fallbacks ("Pueblo desconocido", "Aventurero") fit as labels too.
L.ENC_TAB = "Encuentros"
L.ENC_TAB_TOTAL = "Personas que conoces: {count} · caras conocidas: {recurring}"
L.ENC_TAB_EMPTY = "Aún no se ha cruzado nadie en tu camino. Forma grupo con alguien y Ashmark lo recordará."
L.ENC_TAB_MET = "Encuentros: {count} · el último en {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "Encuentros: {count} · {date}"
L.ENC_TAB_NOTE = "Nota"
L.ENC_TAB_WHO = "{race} · {class}"
L.ENC_TAB_FIRST = "Primer encuentro: {date}"

-- Chronicle sentences. Only "expulsado" agrees with the subject, so ENC_LOG_KICK alone has _F forms.
L.ENC_LOG_CONTACT = "Conociste a {contact}."
L.ENC_LOG_CONTACT_THEY = "{name} conoció a {contact}."
L.ENC_LOG_TRAVEL = "Viajaste con {people}."
L.ENC_LOG_TRAVEL_THEY = "{name} viajó con {people}."
L.ENC_LOG_BOSS = "Luchaste junto a {people} y venciste."
L.ENC_LOG_BOSS_THEY = "{name} luchó junto a {people} y venció."
L.ENC_LOG_WIPE = "Luchaste junto a {people} y caíste."
L.ENC_LOG_WIPE_THEY = "{name} luchó junto a {people} y cayó."
L.ENC_LOG_CAMP = "Compartiste una hoguera con {people}."
L.ENC_LOG_CAMP_THEY = "{name} compartió una hoguera con {people}."
L.ENC_LOG_KICK = "Fuiste expulsado del grupo de {people}."
L.ENC_LOG_KICK_F = "Fuiste expulsada del grupo de {people}."
L.ENC_LOG_KICK_THEY = "{name} fue expulsado del grupo de {people}."
L.ENC_LOG_KICK_THEY_F = "{name} fue expulsada del grupo de {people}."

-- Parts of {people}, which always follows "con", "junto a" or "de"
L.ENC_LOG_PEER = "{who} ({archetype} de {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "otra persona"
L.ENC_LOG_OTHERS = "otras {count} personas"
L.ENC_LOG_STRANGER = "un desconocido"
L.ENC_LOG_STRANGERS = "{count} desconocidos"
L.ENC_LOG_STRANGERS_ANY = "desconocidos"
L.ENC_LOG_COMPANION = "un compañero"
L.ENC_LOG_COMPANIONS = "{count} compañeros"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} y {last}"
L.ENC_LIST_AND_VOWEL = "{list} e {last}"

-- House ----------------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "Casa"
L.HOUSE_MODULE_DESC = "Los personajes de esta cuenta que comparten apellido forman una casa. La pestaña Casa "
  .. "muestra sus miembros, las enemistades que tus parientes hicieron suyas, la crónica familiar y las personas a "
  .. "las que conocen."

-- /ashmark house (5.9). A family is "la Casa {house}", as noble houses are in the client.
L.HOUSE_HELP = "mostrar tu casa; «house <nombre>» te une a la casa de ese nombre, «house reset» vuelve a la casa "
  .. "de tu apellido"
L.HOUSE_SLASH_CURRENT = "Perteneces a la Casa {house}."
L.HOUSE_SLASH_NONE = "No perteneces a ninguna casa. Escribe /ashmark house <nombre> para unirte a una."
L.HOUSE_SLASH_SET = "Ahora perteneces a la Casa {house}."
L.HOUSE_SLASH_RESET = "Tu casa vuelve a ser la de tu apellido: Casa {house}."
L.HOUSE_SLASH_RESET_NONE = "Tu casa vuelve a ser la de tu apellido. Como no tienes apellido, no perteneces a "
  .. "ninguna casa."
L.HOUSE_SLASH_OFF = "El módulo Casa está desactivado o no está disponible, así que ahora no puedes cambiar de casa."

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
L.HOUSE_TAB_FEUD = "{title}: {name} se puso del lado de {faction} en {zone}."
L.HOUSE_TAB_CHRONICLE = "Crónica familiar"
L.HOUSE_TAB_MEMORY = "Memoria familiar"
L.HOUSE_TAB_KNOWS = "{sibling} conoce a {name}."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}: nivel {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

-- Campfire -------------------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "Hoguera"
L.CAMP_MODULE_DESC = "Descansa en un campamento hasta que sus beneficios surtan efecto y Ashmark podrá cerrar allí "
  .. "un capítulo de tu crónica, si ha ocurrido lo suficiente desde el anterior."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "Se cierra el capítulo {roman} · {place}"

-- Knowledge ------------------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "Conocimiento del personaje"
L.KNOW_MODULE_DESC = "Las descripciones emergentes de los objetos solo muestran lo que tu personaje puede saber. "
  .. "Un objeto que nunca ha estado en las bolsas, el banco o el equipo de este personaje muestra su nombre, cómo "
  .. "se liga, su ranura, su nivel de objeto, su tipo y sus requisitos; el resto permanece oculto. Los objetos que "
  .. "el propio juego aún oculta se dejan tal como los muestra el juego."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "Tu personaje nunca ha tenido esto en sus manos."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "Recompensas de misión al completo"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "No ocultar nunca las descripciones emergentes de las recompensas que aparecen "
  .. "en la ventana de misión, para que puedas elegir una recompensa sabiendo lo que hace."

-- Fiction --------------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "Ficción compartida"
L.FICTION_MODULE_DESC = "Los miembros del grupo que también usan Ashmark conocen tu arquetipo, tu origen, tus "
  .. "valores de perfil, tu tipo de reino y tu versión de Ashmark sin que aparezca una sola palabra en el chat, y tú "
  .. "conoces los suyos, de modo que tu crónica y tus descripciones emergentes pueden decir con quién viajaste. A "
  .. "los demás jugadores no se les muestra nada."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "Forma grupo con otro usuario de Ashmark y vuelve a ejecutar /ashmark test."

-- Rumours --------------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "Rumores"
L.RUMOUR_MODULE_DESC = "Lo que haces en un conflicto viaja como rumor de grupo en grupo, y tú oyes lo que hicieron "
  .. "otros. Un rumor habla de un tipo de persona, un lugar y una facción, nunca de un personaje, pero el juego "
  .. "muestra quién lo transmite: tu grupo puede saber qué rumores cuentan tus propios actos, y quien sepa de quién "
  .. "es el acto que cuenta un rumor puede deducir de tu versión si has estado en grupo con ese jugador durante la "
  .. "última semana, o cuántos grupos os separan."

-- Chat lines for a rumour heard (7.8). No sex is known: "alguien" carries the grammar and {archetype} stands as a
-- name after "a quien llaman", with no article or adjective to agree with (no _F forms).
L.RUMOUR_HEARD_ALLIANCE = "Cuentan que alguien de {place} a quien llaman {archetype} se ha puesto del lado de "
  .. "{faction}."
L.RUMOUR_HEARD_BROKE = "Cuentan que alguien de {place} a quien llaman {archetype} ha faltado a la palabra dada "
  .. "a {faction}."
L.RUMOUR_HEARD_TURNED = "Cuentan que alguien de {place} a quien llaman {archetype} le ha dado la espalda a su casa "
  .. "para ponerse del lado de {faction}."
-- Without a faction
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "Cuentan que alguien de {place} a quien llaman {archetype} ha elegido un bando."
L.RUMOUR_HEARD_BROKE_VAGUE = "Cuentan que alguien de {place} a quien llaman {archetype} ha faltado a su palabra."
L.RUMOUR_HEARD_TURNED_VAGUE = "Cuentan que alguien de {place} a quien llaman {archetype} le ha dado la espalda a "
  .. "su propia casa."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Ponte del lado de una facción en un conflicto o forma grupo con otro usuario de Ashmark, y "
  .. "vuelve a ejecutar /ashmark test."

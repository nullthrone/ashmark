local _, ns = ...
local L = ns.Locale:For("ruRU")

-- Address form: "вы" (formal), as in Blizzard's ruRU client, lowercase inside a sentence. Verbs and short
-- participles with "вы" are plural and carry no gender, so the first-person keys need no _F forms; the _THEY
-- forms with a past-tense verb about {name} do.
-- Names from the client stay in the nominative, so no placeholder follows a preposition or a verb that would
-- need another case: zones follow "в зоне", quests stand in quotes after "задание", factions and sides stand
-- after a colon, a dash or in parentheses, character names are subjects. CORE_UNKNOWN_* and CONFLICT_UNNAMED
-- fill the same slots and are written for them. Blizzard's ruRU style: no "ё".

-- Core ---------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark работает только в World of Warcraft Forever и в этом клиенте остается отключенным."
L.CORE_SV_NEW = "Ashmark начал вести записи с чистого листа. Если на этой учетной записи Ashmark уже использовался, "
  .. "сохраненные данные не загрузились: больше не выполняйте /reload и не выходите из игрового мира. "
  .. "Закройте игру, затем замените Ashmark.lua на Ashmark.lua.bak в папке "
  .. "WTF\\Account\\<учетная запись>\\SavedVariables\\ до следующего входа в игру."
L.CORE_SV_NEWER = "Эти сохраненные данные созданы более новой версией Ashmark. Пока вы не обновите аддон, "
  .. "Ashmark будет их только читать."
L.CORE_SV_RECOVERED = "Сохраненные данные имели формат, незнакомый Ashmark. Ashmark начал вести "
  .. "записи с чистого листа, а старые данные сохранены нетронутыми в AshmarkDB.recovered."
L.CORE_SV_MIGRATE_FAILED = "Ashmark не удалось обновить сохраненные данные, поэтому в этом сеансе он их только "
  .. "читает."

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "Модуль «{module}» остановлен после повторяющихся ошибок и останется отключенным до "
  .. "следующей перезагрузки интерфейса."
L.CORE_UNAVAILABLE = "Требуется: {capability}"
L.CORE_MISSING_EVENTS = "События, которых нет в этом клиенте: {events}"
L.CORE_SETTING_CHAT_LINES = "Строки в чате"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark может выводить короткие строки в окно чата."
L.CORE_SETTING_SOUNDS = "Звуки"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark воспроизводит игровые звуки страниц и книг."
L.CORE_SETTING_SHARE = "Делиться с пользователями Ashmark"
L.CORE_SETTING_SHARE_DESC = "Передавать ваш архетип, происхождение и слухи участникам группы, которые тоже "
  .. "пользуются Ashmark. Контакты и заметки никогда не покидают ваш клиент."

-- Shared vocabulary (5.8). Each fills a placeholder slot in the nominative: CORE_UNKNOWN_QUEST stands in
-- quotes after "задание", CORE_UNKNOWN_PLACE after "в зоне" or alone, CORE_UNKNOWN_FACTION after a colon or
-- a dash, CORE_UNKNOWN_RACE before the class in ENC_TAB_WHO.
L.CORE_UNKNOWN_QUEST = "без названия"
L.CORE_UNKNOWN_ITEM = "предмет"
L.CORE_UNKNOWN_FACTION = "неизвестная фракция"
L.CORE_UNKNOWN_PLACE = "без названия"
L.CORE_UNKNOWN_PLAYER = "кто-то"
L.CORE_UNKNOWN_CLASS = "искатель приключений"
L.CORE_UNKNOWN_RACE = "неизвестный народ"
L.CORE_RULESET_NORMAL = "Обычный"
L.CORE_RULESET_PVP = "PvP"
L.CORE_RULESET_RP = "Ролевой"
L.CORE_RULESET_RPPVP = "Ролевой PvP"
L.CORE_RULESET_HARDCORE = "Хардкор"

-- Chronicle sentences for Core's kinds; _THEY forms are used in the family chronicle with {name}.
-- {standing} is the client's standing label, a noun ("Дружелюбие").
L.CORE_LOG_TURNIN = "Вы выполнили задание «{quest}»."
L.CORE_LOG_TURNIN_THEY = "{name} выполнил задание «{quest}»."
L.CORE_LOG_TURNIN_THEY_F = "{name} выполнила задание «{quest}»."
L.CORE_LOG_ABANDON = "Вы отказались от задания «{quest}»."
L.CORE_LOG_ABANDON_THEY = "{name} отказался от задания «{quest}»."
L.CORE_LOG_ABANDON_THEY_F = "{name} отказалась от задания «{quest}»."
L.CORE_LOG_ZONE_FIRST = "Вы впервые оказались в зоне {zone}."
L.CORE_LOG_ZONE_FIRST_THEY = "{name} впервые оказался в зоне {zone}."
L.CORE_LOG_ZONE_FIRST_THEY_F = "{name} впервые оказалась в зоне {zone}."
L.CORE_LOG_LEVEL = "Вы достигли {level}-го уровня."
L.CORE_LOG_LEVEL_THEY = "{name} достиг {level}-го уровня."
L.CORE_LOG_LEVEL_THEY_F = "{name} достигла {level}-го уровня."
L.CORE_LOG_DEATH = "Вы погибли в зоне {place}."
L.CORE_LOG_DEATH_THEY = "{name} погиб в зоне {place}."
L.CORE_LOG_DEATH_THEY_F = "{name} погибла в зоне {place}."
L.CORE_LOG_REP = "Ваша репутация теперь: {faction} — {standing}."
L.CORE_LOG_REP_THEY = "Репутация персонажа {name} теперь: {faction} — {standing}."
L.CORE_LOG_CHAPTER = "Глава {roman} завершается в зоне {place}."
L.CORE_LOG_CHAPTER_THEY = "{name} завершает главу {roman} в зоне {place}."

-- Slash commands (5.9)
L.CORE_HELP_HEADER = "Команды:"
L.CORE_HELP_TOGGLE = "открыть или закрыть летопись"
L.CORE_HELP_HELP = "вывести список этих команд"
L.CORE_HELP_DEBUG = "включить или выключить отладочный вывод на этот сеанс"
L.CORE_HELP_RESET = "стереть записи этого персонажа; «reset others» — стереть контакты, сведения о других "
  .. "пользователях Ashmark и услышанные слухи"
L.CORE_UNKNOWN_COMMAND = "Неизвестная команда: {command}"
L.CORE_DEBUG_ON = "Отладочный вывод включен на этот сеанс."
L.CORE_DEBUG_OFF = "Отладочный вывод выключен."
L.CORE_RESET_CONFIRM = "Стереть все, что Ashmark записал об этом персонаже? Это действие нельзя отменить."
L.CORE_RESET_OTHERS_CONFIRM = "Стереть все контакты, сведения о других пользователях Ashmark и услышанные слухи "
  .. "на этой учетной записи? Ваши собственные слухи сохранятся. Это действие нельзя отменить."
L.CORE_RESET_ACCEPT = "Стереть"
L.CORE_CANCEL = "Отмена"
L.CORE_RESET_DONE = "Записи этого персонажа стерты."
L.CORE_RESET_OTHERS_DONE = "Контакты, сведения о других пользователях Ashmark и услышанные слухи стерты."
L.CORE_RESET_READONLY = "Сохраненные данные созданы более новой версией Ashmark, поэтому стереть ничего нельзя."

-- UI shell (6.1, 6.2): main window tabs, the Chronicle tab and the Addon Compartment
L.CORE_TAB_CHRONICLE = "Летопись"
L.CORE_CHRONICLE_CHAPTER = "Глава {roman}"
L.CORE_CHRONICLE_CHAPTER_OPEN = "Глава {roman} (текущая)"
L.CORE_CHRONICLE_CLOSED = "Завершена {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "Начата {date} · еще пишется"
L.CORE_CHRONICLE_OPEN = "Еще пишется"
L.CORE_CHRONICLE_EMPTY = "В этой главе пока нет ничего, о чем стоило бы рассказать."
L.CORE_CHRONICLE_NO_RECORD = "Ashmark пока не ведет записей об этом персонаже."
L.CORE_COMPARTMENT_CLICK = "Щелкните, чтобы открыть или закрыть летопись."
L.CORE_COMPARTMENT_RIGHT_CLICK = "Щелкните правой кнопкой мыши, чтобы открыть настройки."

-- Test ---------------------------------------------------------------------------------------------------

L.TEST_HELP = "запустить самопроверку в этом клиенте и сделать снимок экрана"
L.TEST_HELP_PROBE = "записать необработанные сведения об этом клиенте для разработчиков"
L.TEST_NOT_IN_COMBAT = "Проверка не запускается в бою. Повторите попытку, когда бой закончится."
L.TEST_SUMMARY = "Проверка завершена. Пройдено: {passed}, провалено: {failed}, пропущено: {skipped}."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "успех"
L.TEST_FAIL = "ПРОВАЛ"
L.TEST_SKIP = "пропуск"
L.TEST_OPEN_QUEST_DIALOG = "Для снимка экрана сначала поговорите с персонажем, который выдает задания."
L.TEST_RELOAD = "Введите /reload, чтобы сохранить результаты."
L.TEST_NOT_STORED = "Сохраненные данные созданы более новой версией Ashmark, поэтому ничего не сохраняется. "
  .. "Далее следует полный отчет."
L.TEST_LATE = "Поздний результат: {what}"
L.TEST_PROBE_DONE = "Записано фактов о клиенте: {count}."
L.TEST_PROBE_NEXT = "Примите задание и вступите в бой в этом сеансе: будет записано и то, и другое."

-- Conflicts ----------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "Конфликты"
L.CONFLICT_MODULE_DESC = "Некоторые задания сталкивают одну сторону с другой. Ashmark запоминает, какую сторону "
  .. "вы выбрали, отмечает строкой под окном задания те задания, что противоречат этому выбору, и записывает, "
  .. "когда вы нарушаете слово."

-- A side without a reputation faction. It stands where a faction name would: alone, after a colon or a dash,
-- in parentheses and in "{a} или {b}", never after "фракция".
L.CONFLICT_UNNAMED = "люди без знамени"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "Противоречит вашему союзу: {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Противоречит выбранной вами стороне."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Ваш дом, {house}, выступает против этой стороны: {faction}."
L.CONFLICT_TEST_DIALOG = "Здесь появляется строка Ashmark под окном задания."

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}.
L.CONFLICT_ALLIED = "В зоне {zone} вы выбрали сторону: {faction}."
L.CONFLICT_ALLIED_THEY = "В зоне {zone} {name} выбрал сторону: {faction}."
L.CONFLICT_ALLIED_THEY_F = "В зоне {zone} {name} выбрала сторону: {faction}."
L.CONFLICT_ALLIED_REP = "В зоне {zone} вашу сторону определила репутация: {faction}."
L.CONFLICT_ALLIED_REP_THEY = "В зоне {zone} сторону персонажа {name} определила репутация: {faction}."
L.CONFLICT_BROKE_WORD = "Вы нарушили слово, данное одной стороне ({broken}), и выполнили задание «{quest}» "
  .. "для другой ({faction})."
L.CONFLICT_BROKE_WORD_THEY = "{name} нарушил слово, данное одной стороне ({broken}), и выполнил задание "
  .. "«{quest}» для другой ({faction})."
L.CONFLICT_BROKE_WORD_THEY_F = "{name} нарушила слово, данное одной стороне ({broken}), и выполнила задание "
  .. "«{quest}» для другой ({faction})."
L.CONFLICT_SWITCHED = "Вы снова сменили сторону: задание «{quest}» выполнено для новой ({faction}), а прежняя "
  .. "({broken}) осталась позади."
L.CONFLICT_SWITCHED_THEY = "{name} снова сменил сторону: задание «{quest}» выполнено для новой ({faction}), "
  .. "а прежняя ({broken}) осталась позади."
L.CONFLICT_SWITCHED_THEY_F = "{name} снова сменила сторону: задание «{quest}» выполнено для новой ({faction}), "
  .. "а прежняя ({broken}) осталась позади."
L.CONFLICT_HOUSETURN = "Вы отвернулись от дома {house} и в зоне {zone} выбрали сторону: {faction}."
L.CONFLICT_HOUSETURN_THEY = "{name} отвернулся от дома {house} и в зоне {zone} выбрал сторону: {faction}."
L.CONFLICT_HOUSETURN_THEY_F = "{name} отвернулась от дома {house} и в зоне {zone} выбрала сторону: {faction}."

-- Decisions tab (6.1)
L.CONFLICT_TAB = "Решения"
L.CONFLICT_TAB_SIDES = "{a} или {b}"
L.CONFLICT_TAB_ALLIED = "Ваша сторона: {faction}, с {date}"
L.CONFLICT_TAB_OPEN = "Сторона не выбрана"
L.CONFLICT_TAB_BROKEN = "Нарушений: {count}"
L.CONFLICT_TAB_VIOLATIONS = "Всего нарушений слова: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "Вы ни разу не нарушили слово."
L.CONFLICT_TAB_EMPTY = "Ashmark пока не знает ни одного конфликта в этом мире."

-- Profile ------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "Профиль"
L.PROFILE_MODULE_DESC = "Ashmark судит о характере вашего персонажа по вашим делам: держите ли вы слово, живете "
  .. "ли в глуши или в городах и как обращаетесь с существами, которые никому не желают зла."

-- Archetypes (7.2): capitalised labels without an article, used as epithets ("Тален (Хранитель клятв,
-- Западный Край)"). _F forms where the character's sex is known; "Добрая душа", "Безжалостная душа" and
-- "Прагматик" serve both sexes.
L.PROFILE_OATHKEEPER = "Хранитель клятв"
L.PROFILE_OATHKEEPER_F = "Хранительница клятв"
L.PROFILE_OPPORTUNIST = "Искатель выгоды"
L.PROFILE_OPPORTUNIST_F = "Искательница выгоды"
L.PROFILE_WANDERER = "Странник"
L.PROFILE_WANDERER_F = "Странница"
L.PROFILE_TOWNSFOLK = "Горожанин"
L.PROFILE_TOWNSFOLK_F = "Горожанка"
L.PROFILE_GENTLE = "Добрая душа"
L.PROFILE_RUTHLESS = "Безжалостная душа"
L.PROFILE_PRAGMATIST = "Прагматик"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "Убейте 3 зверька и 3 спокойных нейтральных животных, затем снова введите "
  .. "/ashmark test."
L.PROFILE_TEST_CRITTER_TARGET = "Выберите целью любое существо, затем снова введите /ashmark test."
L.PROFILE_TEST_CRITTER_OFF = "Этот клиент не различает зверьков, поэтому убитые зверьки не учитываются."

-- Map ----------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "Карта мира"
L.MAP_MODULE_DESC = "Отмечает на карте мира вашу собственную историю: известные вам конфликты и выбранную "
  .. "сторону, места, где вы нарушили слово, и места, где завершились ваши главы. Эти отметки видите только вы."

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{a} или {b}"
L.MAP_PIN_OPEN = "Здесь вы не встали ни на чью сторону."
L.MAP_PIN_ALLIED = "Ваша сторона: {faction}."
L.MAP_PIN_BROKEN = "Ваша сторона: {faction}. Нарушений слова здесь: {count}."
L.MAP_PIN_VIOLATION = "Здесь вы нарушили слово"
L.MAP_PIN_CHAPTER = "Глава {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Завершена здесь {date}"

-- Encounters ---------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "Встречи"
L.ENC_MODULE_DESC = "Ashmark запоминает тех, с кем вы бываете в группе: как часто вы встречались, где и как все "
  .. "прошло. Он добавляет строку в их подсказку, показывает их во вкладке «Встречи» и хранит ваши заметки о "
  .. "них. Контакты и заметки никогда не покидают ваш клиент."

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "Встреч: {count} · последняя — {place}"
L.ENC_TOOLTIP_NOPLACE = "Встреч: {count}"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "{name}: вы знакомы. Встреч: {count}, последняя — в зоне {place}."
L.ENC_RECOGNISE_NOPLACE = "{name}: вы знакомы. Встреч: {count}."
L.ENC_RECOGNISE_MORE = "…и еще знакомых: {count}."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "Знакомое лицо"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "Ваша заметка о персонаже {name}:"
L.ENC_NOTE_SAVE = "Сохранить"

-- Encounters tab (6.1)
L.ENC_TAB = "Встречи"
L.ENC_TAB_TOTAL = "Встречено персонажей: {count} · знакомых лиц: {recurring}"
L.ENC_TAB_EMPTY = "Ваш путь еще ни с кем не пересекался. Вступите с кем-нибудь в группу, и Ashmark запомнит "
  .. "ваших спутников."
L.ENC_TAB_MET = "Встреч: {count} · последняя — {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "Встреч: {count} · {date}"
L.ENC_TAB_NOTE = "Заметка"
L.ENC_TAB_WHO = "{race}, {class}"
L.ENC_TAB_FIRST = "Первая встреча: {date}"

-- Chronicle sentences; _THEY forms are used in the family chronicle with {name}, the family member.
-- {people} is a list in the nominative, so it follows a colon ("со спутниками: …").
L.ENC_LOG_CONTACT = "Вы и {contact} встретились впервые."
L.ENC_LOG_CONTACT_THEY = "{name} и {contact} встретились впервые."
L.ENC_LOG_TRAVEL = "Вы странствовали со спутниками: {people}."
L.ENC_LOG_TRAVEL_THEY = "{name} странствовал со спутниками: {people}."
L.ENC_LOG_TRAVEL_THEY_F = "{name} странствовала со спутниками: {people}."
L.ENC_LOG_BOSS = "Вы сражались бок о бок со спутниками: {people} — и победили."
L.ENC_LOG_BOSS_THEY = "{name} сражался бок о бок со спутниками: {people} — и победил."
L.ENC_LOG_BOSS_THEY_F = "{name} сражалась бок о бок со спутниками: {people} — и победила."
L.ENC_LOG_WIPE = "Вы сражались бок о бок со спутниками: {people} — и пали."
L.ENC_LOG_WIPE_THEY = "{name} сражался бок о бок со спутниками: {people} — и пал."
L.ENC_LOG_WIPE_THEY_F = "{name} сражалась бок о бок со спутниками: {people} — и пала."
L.ENC_LOG_CAMP = "Вы сидели у костра со спутниками: {people}."
L.ENC_LOG_CAMP_THEY = "{name} сидел у костра со спутниками: {people}."
L.ENC_LOG_CAMP_THEY_F = "{name} сидела у костра со спутниками: {people}."
L.ENC_LOG_KICK = "Вас исключили из группы, в которую входили ваши спутники: {people}."
L.ENC_LOG_KICK_THEY = "{name} был исключен из группы, в которую входили его спутники: {people}."
L.ENC_LOG_KICK_THEY_F = "{name} была исключена из группы, в которую входили ее спутники: {people}."

-- Parts of {people}, all in the nominative
L.ENC_LOG_PEER = "{who} ({archetype}, {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "еще один"
L.ENC_LOG_OTHERS = "еще {count}"
L.ENC_LOG_STRANGER = "незнакомец"
L.ENC_LOG_STRANGERS = "незнакомцы ({count})"
L.ENC_LOG_STRANGERS_ANY = "незнакомцы"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} и {last}"

-- House --------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "Дом"
L.HOUSE_MODULE_DESC = "Персонажи этой учетной записи с общей фамилией образуют дом. Во вкладке «Дом» показаны "
  .. "его члены, распри, в которые вступили ваши родичи, семейная летопись и те, кого они знают."

-- /ashmark house (5.9)
L.HOUSE_HELP = "показать ваш дом; «house <название>» — вступить в дом с этим названием, «house reset» — "
  .. "снова определять дом по фамилии"
L.HOUSE_SLASH_CURRENT = "Вы принадлежите к дому {house}."
L.HOUSE_SLASH_NONE = "Вы не принадлежите ни к одному дому. Введите /ashmark house <название>, чтобы вступить в дом."
L.HOUSE_SLASH_SET = "Теперь вы принадлежите к дому {house}."
L.HOUSE_SLASH_RESET = "Ваш дом снова определяется по фамилии: дом {house}."
L.HOUSE_SLASH_RESET_NONE = "Ваш дом снова определяется по фамилии. Без фамилии вы не принадлежите ни к одному "
  .. "дому."
L.HOUSE_SLASH_OFF = "Модуль «Дом» отключен или недоступен, поэтому сейчас сменить дом нельзя."

-- House tab (6.1, 7.5). HOUSE_TAB_FEUD and HOUSE_TAB_KNOWS have no _F forms, so they carry no gender.
L.HOUSE_TAB = "Дом"
L.HOUSE_TAB_HEADING = "Дом {house}"
L.HOUSE_TAB_NO_HOUSE = "Без дома"
L.HOUSE_TAB_NONE = "Персонажи этой учетной записи с общей фамилией образуют дом. Ashmark не знает фамилии этого "
  .. "персонажа: введите /ashmark house <название>, чтобы выбрать дом."
L.HOUSE_TAB_ARCHETYPE = "Архетип: {archetype}"
L.HOUSE_TAB_MEMBERS = "Члены дома"
L.HOUSE_TAB_MEMBER = "{name}, уровень {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "Унаследованные распри"
L.HOUSE_TAB_FEUD = "{name}: выбор в зоне {zone} — {faction}."
L.HOUSE_TAB_CHRONICLE = "Семейная летопись"
L.HOUSE_TAB_MEMORY = "Семейная память"
L.HOUSE_TAB_KNOWS = "{sibling} и {name} знакомы."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}: уровень {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

-- Campfire -----------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "Костер"
L.CAMP_MODULE_DESC = "Отдохните в лагере, пока не проявится его благотворное действие, и Ashmark сможет "
  .. "завершить там главу вашей летописи, если с прошлой главы произошло достаточно событий."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "Глава {roman} завершается · {place}"

-- Knowledge ----------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "Знания персонажа"
L.KNOW_MODULE_DESC = "Подсказки предметов показывают только то, что может знать ваш персонаж. У предмета, который "
  .. "ни разу не побывал в сумках, банке или экипировке этого персонажа, видны название, привязка, ячейка, "
  .. "уровень предмета, тип и требования; остальное скрыто. Предметы, которые игра сама по-прежнему скрывает, "
  .. "остаются в том виде, в каком их показывает игра."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "Ваш персонаж никогда не владел этим предметом."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "Полные подсказки наград"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "Никогда не скрывать подсказки наград в окне задания, чтобы вы могли выбрать "
  .. "награду, зная, что она дает."

-- Fiction ------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "Общая история"
L.FICTION_MODULE_DESC = "Участники группы, которые тоже пользуются Ashmark, без единого слова в чате узнают ваш "
  .. "архетип и происхождение, а вы — их. Благодаря этому летопись и подсказки могут рассказать, с кем вы "
  .. "странствовали. Другим игрокам ничего не показывается."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "Вступите в группу с другим пользователем Ashmark, затем снова введите /ashmark test."

-- Rumours ------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "Слухи"
L.RUMOUR_MODULE_DESC = "Ваши поступки в конфликте расходятся слухами от группы к группе, а вы слышите о том, что "
  .. "сделали другие. Слух называет архетип, место и фракцию, но никогда — самого персонажа."

-- Chat lines for a rumour heard (7.8). Rumours carry no sex: {archetype} is a quoted nickname after
-- "некто по прозвищу", so the verb agrees with "некто" and the masculine label needs no agreement. {place}
-- follows "в краях под названием", which suits a zone and a continent alike. No _F forms.
L.RUMOUR_HEARD_ALLIANCE = "Говорят, в краях под названием {place} некто по прозвищу «{archetype}» выбрал "
  .. "сторону: {faction}."
L.RUMOUR_HEARD_BROKE = "Говорят, в краях под названием {place} некто по прозвищу «{archetype}» предал "
  .. "союзников: {faction}."
L.RUMOUR_HEARD_TURNED = "Говорят, в краях под названием {place} некто по прозвищу «{archetype}» отвернулся "
  .. "от своего дома и выбрал сторону: {faction}."
-- Without a faction: after three hops, or when the side has none.
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "Говорят, в краях под названием {place} некто по прозвищу «{archetype}» "
  .. "выбрал сторону."
L.RUMOUR_HEARD_BROKE_VAGUE = "Говорят, в краях под названием {place} некто по прозвищу «{archetype}» нарушил "
  .. "слово."
L.RUMOUR_HEARD_TURNED_VAGUE = "Говорят, в краях под названием {place} некто по прозвищу «{archetype}» "
  .. "отвернулся от собственного дома."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Встаньте на сторону одной из фракций в конфликте или вступите в группу с другим "
  .. "пользователем Ashmark, затем снова введите /ashmark test."

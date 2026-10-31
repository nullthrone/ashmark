local _, ns = ...
local L = ns.Locale:For("ptBR")

-- Address form: "você" with third-person verbs and "seu/sua", as in Blizzard's ptBR client ("Você alcançou o
-- nível…", "Sua reputação com…"); instructions in the imperative of "você" ("Clique", "Digite").
-- Names from the client stand bare, as the client itself writes them: "com {faction}", "em {zone}", "de {place}".
-- Faction names follow "com", "para", "contra" or stand as a direct object wherever the sentence allows it.
-- Chronicle sentences are told in the pretérito perfeito ("Você concluiu", "{name} morreu"), whose verbs do not
-- change with the subject's sex; only a participle does ("expulso/expulsa"), so ENC_LOG_KICK alone has _F forms.
-- The addon is "o Ashmark" (masculine, like "o addon"), so "do Ashmark", "usuários do Ashmark".
-- CORE_UNKNOWN_* carry their own article or need none ("uma missão", "algum lugar", "alguém"), so they fit the
-- same frames as the client names they replace. CONFLICT_UNNAMED ("quem não tem estandarte") takes no article,
-- so it also stands after "de", "com" and "para" without a contraction.

-- Core -----------------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "O Ashmark funciona apenas no World of Warcraft Forever e permanece desativado neste cliente."
L.CORE_SV_NEW = "Um novo registro foi iniciado. Se o Ashmark já foi usado nesta conta, os dados salvos não foram "
  .. "carregados: não use /reload nem se desconecte novamente. Saia do jogo e, antes de se conectar outra vez, "
  .. "substitua Ashmark.lua por Ashmark.lua.bak em WTF\\Account\\<conta>\\SavedVariables\\."
L.CORE_SV_NEWER = "Estes dados salvos vêm de uma versão mais recente do Ashmark. O Ashmark apenas os lê até que "
  .. "você o atualize."
L.CORE_SV_RECOVERED = "Os dados salvos não estavam em um formato que o Ashmark reconheça. Um novo registro foi "
  .. "iniciado; os dados antigos foram mantidos intactos em AshmarkDB.recovered."
L.CORE_SV_MIGRATE_FAILED = "O Ashmark não conseguiu atualizar os dados salvos e, nesta sessão, apenas os lê."

-- Modules and settings (3.2, 4.3). {module} is a module name; "O módulo" carries the agreement.
L.CORE_MODULE_FAILED = "O módulo {module} parou após erros repetidos e fica desativado até a próxima recarga da "
  .. "interface."
L.CORE_UNAVAILABLE = "Requer {capability}"
L.CORE_MISSING_EVENTS = "Eventos que faltam neste cliente: {events}"
L.CORE_SETTING_CHAT_LINES = "Linhas no bate-papo"
L.CORE_SETTING_CHAT_LINES_DESC = "O Ashmark pode escrever linhas curtas na janela de bate-papo."
L.CORE_SETTING_SOUNDS = "Sons"
L.CORE_SETTING_SOUNDS_DESC = "O Ashmark reproduz os sons de página e de livro do jogo."
L.CORE_SETTING_SHARE = "Compartilhar com outros usuários do Ashmark"
L.CORE_SETTING_SHARE_DESC = "Envia seu arquétipo, sua origem e seus rumores aos membros do grupo que também usam "
  .. "o Ashmark. Contatos e notas nunca saem do seu cliente."

-- Shared vocabulary (5.8)
L.CORE_UNKNOWN_QUEST = "uma missão"
L.CORE_UNKNOWN_ITEM = "um item"
L.CORE_UNKNOWN_FACTION = "uma facção"
L.CORE_UNKNOWN_PLACE = "algum lugar"
L.CORE_UNKNOWN_PLAYER = "alguém"
L.CORE_UNKNOWN_CLASS = "aventureiro"
L.CORE_UNKNOWN_RACE = "Povo desconhecido"
L.CORE_RULESET_NORMAL = "Normal"
L.CORE_RULESET_PVP = "JxJ"
L.CORE_RULESET_RP = "Interpretação"
L.CORE_RULESET_RPPVP = "Interpretação JxJ"
L.CORE_RULESET_HARDCORE = "Hardcore"

-- Chronicle sentences. {standing} comes from the client already in the character's gender ("Amistosa").
L.CORE_LOG_TURNIN = "Você concluiu {quest}."
L.CORE_LOG_TURNIN_THEY = "{name} concluiu {quest}."
L.CORE_LOG_ABANDON = "Você abandonou {quest}."
L.CORE_LOG_ABANDON_THEY = "{name} abandonou {quest}."
L.CORE_LOG_ZONE_FIRST = "Você pisou em {zone} pela primeira vez."
L.CORE_LOG_ZONE_FIRST_THEY = "{name} pisou em {zone} pela primeira vez."
L.CORE_LOG_LEVEL = "Você alcançou o nível {level}."
L.CORE_LOG_LEVEL_THEY = "{name} alcançou o nível {level}."
L.CORE_LOG_DEATH = "Você morreu em {place}."
L.CORE_LOG_DEATH_THEY = "{name} morreu em {place}."
L.CORE_LOG_REP = "Agora você é {standing} com {faction}."
L.CORE_LOG_REP_THEY = "{name} agora é {standing} com {faction}."
L.CORE_LOG_CHAPTER = "O capítulo {roman} se encerra em {place}."
L.CORE_LOG_CHAPTER_THEY = "O capítulo {roman} de {name} se encerra em {place}."

-- Slash commands (5.9). Subcommand words stay in English: they are what the player types.
L.CORE_HELP_HEADER = "Comandos:"
L.CORE_HELP_TOGGLE = "abrir ou fechar a crônica"
L.CORE_HELP_HELP = "listar estes comandos"
L.CORE_HELP_DEBUG = "ativar ou desativar as mensagens de depuração nesta sessão"
L.CORE_HELP_RESET = "apagar o registro deste personagem; \"reset others\" apaga contatos, dados de outros usuários "
  .. "do Ashmark e rumores ouvidos"
L.CORE_UNKNOWN_COMMAND = "Comando desconhecido: {command}"
L.CORE_DEBUG_ON = "As mensagens de depuração estão ativadas nesta sessão."
L.CORE_DEBUG_OFF = "As mensagens de depuração estão desativadas."
L.CORE_RESET_CONFIRM = "Apagar tudo o que o Ashmark registrou deste personagem? Esta ação não pode ser desfeita."
L.CORE_RESET_OTHERS_CONFIRM = "Apagar todos os contatos, dados de outros usuários do Ashmark e rumores ouvidos "
  .. "nesta conta? Seus próprios rumores são mantidos. Esta ação não pode ser desfeita."
L.CORE_RESET_ACCEPT = "Apagar"
L.CORE_CANCEL = "Cancelar"
L.CORE_RESET_DONE = "O registro deste personagem foi apagado."
L.CORE_RESET_OTHERS_DONE = "Contatos, dados de outros usuários do Ashmark e rumores ouvidos foram apagados."
L.CORE_RESET_READONLY = "Os dados salvos vêm de uma versão mais recente do Ashmark, então nada pode ser apagado."

-- UI shell (6.1, 6.2). "Encerrado", "Iniciado" and "escrito" agree with "capítulo".
L.CORE_TAB_CHRONICLE = "Crônica"
L.CORE_CHRONICLE_CHAPTER = "Capítulo {roman}"
L.CORE_CHRONICLE_CHAPTER_OPEN = "Capítulo {roman} (atual)"
L.CORE_CHRONICLE_CLOSED = "Encerrado em {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "Iniciado em {date} · ainda sendo escrito"
L.CORE_CHRONICLE_OPEN = "Ainda sendo escrito"
L.CORE_CHRONICLE_EMPTY = "Ainda não há nada neste capítulo que valha a pena contar."
L.CORE_CHRONICLE_NO_RECORD = "O Ashmark ainda não mantém nenhum registro deste personagem."
L.CORE_COMPARTMENT_CLICK = "Clique para abrir ou fechar a crônica."
L.CORE_COMPARTMENT_RIGHT_CLICK = "Clique com o botão direito para abrir as configurações."

-- Test -----------------------------------------------------------------------------------------------------------

L.TEST_HELP = "executar o autoteste neste cliente e fazer uma captura de tela"
L.TEST_HELP_PROBE = "registrar dados brutos deste cliente para os desenvolvedores"
L.TEST_NOT_IN_COMBAT = "O teste não é executado em combate. Tente novamente quando a luta terminar."
L.TEST_SUMMARY = "Teste concluído. Aprovados: {passed}; com falha: {failed}; ignorados: {skipped}."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "aprovado"
L.TEST_FAIL = "FALHA"
L.TEST_SKIP = "ignorado"
L.TEST_OPEN_QUEST_DIALOG = "Para a captura de tela, fale primeiro com um personagem que ofereça missões."
L.TEST_RELOAD = "Digite /reload para salvar os resultados."
L.TEST_NOT_STORED = "Os dados salvos vêm de uma versão mais recente do Ashmark, então nada é armazenado. O "
  .. "relatório completo vem a seguir."
L.TEST_LATE = "Resultado posterior: {what}"
L.TEST_PROBE_DONE = "A sonda registrou {count} dados."
L.TEST_PROBE_NEXT = "Aceite uma missão e comece uma luta nesta sessão: a sonda registra as duas coisas."

-- Conflicts ------------------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "Conflitos"
L.CONFLICT_MODULE_DESC = "Algumas missões colocam um lado contra o outro. O Ashmark se lembra do lado que você "
  .. "escolhe, marca abaixo da janela de missão as missões que o contradizem e registra quando você quebra sua "
  .. "palavra."

-- A side without a reputation faction, standing where a faction name would. No article, so it also fits after
-- "de" ("do lado de quem não tem estandarte") and opens "{a} ou {b}" the way enUS does.
L.CONFLICT_UNNAMED = "quem não tem estandarte"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "Contradiz sua aliança com {faction}."
L.CONFLICT_CONTRADICTS_NOFACTION = "Contradiz o lado que você escolheu."
L.CONFLICT_HOUSE_STANDS_AGAINST = "Sua casa, {house}, está contra {faction}."
L.CONFLICT_TEST_DIALOG = "A linha do Ashmark abaixo da janela de missão aparece aqui."

-- Chronicle sentences. A family is "a Casa {house}", as noble houses are named in Portuguese.
L.CONFLICT_ALLIED = "Você se aliou com {faction} em {zone}."
L.CONFLICT_ALLIED_THEY = "{name} se aliou com {faction} em {zone}."
L.CONFLICT_ALLIED_REP = "Sua reputação com {faction} decidiu seu lado em {zone}."
L.CONFLICT_ALLIED_REP_THEY = "A reputação com {faction} decidiu o lado de {name} em {zone}."
L.CONFLICT_BROKE_WORD = "Você traiu {broken} e concluiu {quest} para {faction}."
L.CONFLICT_BROKE_WORD_THEY = "{name} traiu {broken} e concluiu {quest} para {faction}."
L.CONFLICT_SWITCHED = "Você mudou de lado mais uma vez: concluiu {quest} para {faction} e deixou {broken} para "
  .. "trás."
L.CONFLICT_SWITCHED_THEY = "{name} mudou de lado mais uma vez: concluiu {quest} para {faction} e deixou {broken} "
  .. "para trás."
L.CONFLICT_HOUSETURN = "Você deu as costas à Casa {house} e se aliou com {faction} em {zone}."
L.CONFLICT_HOUSETURN_THEY = "{name} deu as costas à Casa {house} e se aliou com {faction} em {zone}."

-- Decisions tab (6.1). "×" keeps the counts free of singular and plural.
L.CONFLICT_TAB = "Decisões"
L.CONFLICT_TAB_SIDES = "{a} ou {b}"
L.CONFLICT_TAB_ALLIED = "Do lado de {faction} desde {date}"
L.CONFLICT_TAB_OPEN = "Em aberto"
L.CONFLICT_TAB_BROKEN = "Palavra quebrada {count}×"
L.CONFLICT_TAB_VIOLATIONS = "Palavras quebradas: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "Você não quebrou sua palavra."
L.CONFLICT_TAB_EMPTY = "O Ashmark ainda não conhece nenhum conflito neste mundo."

-- Profile --------------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "Perfil"
L.PROFILE_MODULE_DESC = "O Ashmark lê seu personagem pelo que você faz: se você cumpre sua palavra, se vive em "
  .. "terras selvagens ou em cidades e como trata as criaturas inofensivas."

-- Archetypes (7.2): labels without an article, in title case like epithets ("Thalen (Andarilho de Cerro Oeste)").
-- "Oportunista" serves both sexes and "Alma" is feminine whatever the sex, so those have no _F forms.
L.PROFILE_OATHKEEPER = "Guardião da Palavra"
L.PROFILE_OATHKEEPER_F = "Guardiã da Palavra"
L.PROFILE_OPPORTUNIST = "Oportunista"
L.PROFILE_WANDERER = "Andarilho"
L.PROFILE_WANDERER_F = "Andarilha"
L.PROFILE_TOWNSFOLK = "Citadino"
L.PROFILE_TOWNSFOLK_F = "Citadina"
L.PROFILE_GENTLE = "Alma Gentil"
L.PROFILE_RUTHLESS = "Alma Implacável"
L.PROFILE_PRAGMATIST = "Pragmático"
L.PROFILE_PRAGMATIST_F = "Pragmática"

-- Test mode (7.10). "Bicho" is the client's creature type for critters.
L.PROFILE_TEST_MERCY_HOWTO = "Mate 3 bichos e 3 feras neutras e calmas, depois execute /ashmark test novamente."
L.PROFILE_TEST_CRITTER_TARGET = "Selecione qualquer criatura como alvo, depois execute /ashmark test novamente."
L.PROFILE_TEST_CRITTER_OFF = "Este cliente não consegue identificar bichos, então os bichos abatidos não são "
  .. "contados."

-- Map ------------------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "Mapa-múndi"
L.MAP_MODULE_DESC = "Marca sua própria história no mapa-múndi: os conflitos que você conhece e o lado que tomou, "
  .. "os lugares onde quebrou sua palavra e onde seus capítulos se encerraram. Só você vê essas marcas."

-- Pin tooltips (7.3). No word here agrees with the character's sex, so there are no _F forms.
L.MAP_PIN_SIDES = "{a} ou {b}"
L.MAP_PIN_OPEN = "Aqui você não tomou partido."
L.MAP_PIN_ALLIED = "Você está do lado de {faction}."
L.MAP_PIN_BROKEN = "Você está do lado de {faction} e aqui quebrou sua palavra {count}×."
L.MAP_PIN_VIOLATION = "Aqui você quebrou sua palavra"
L.MAP_PIN_CHAPTER = "Capítulo {roman}"
L.MAP_PIN_CHAPTER_CLOSED = "Encerrado aqui em {date}"

-- Encounters -----------------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "Encontros"
L.ENC_MODULE_DESC = "O Ashmark se lembra das pessoas com quem você forma grupo: quantas vezes vocês se "
  .. "encontraram, onde e como foi. Ele acrescenta uma linha à dica dessas pessoas, mostra-as na aba Encontros e "
  .. "guarda suas notas sobre elas. Contatos e notas nunca saem do seu cliente."

-- Unit tooltip (7.4). "Encontros:" keeps the count free of singular and plural.
L.ENC_TOOLTIP = "Encontros: {count} · último em {place}"
L.ENC_TOOLTIP_NOPLACE = "Encontros: {count}"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "Você conhece {name}: vocês se encontraram {count}×, a última vez em {place}."
L.ENC_RECOGNISE_NOPLACE = "Você conhece {name}: vocês se encontraram {count}×."
L.ENC_RECOGNISE_MORE = "…e mais {count} que você conhece."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "Rosto familiar"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "Sua nota sobre {name}:"
L.ENC_NOTE_SAVE = "Salvar"

-- Encounters tab (6.1). {race} {class} in the order of the client's own unit tooltip.
L.ENC_TAB = "Encontros"
L.ENC_TAB_TOTAL = "Pessoas que você conheceu: {count} · rostos familiares: {recurring}"
L.ENC_TAB_EMPTY = "Ninguém cruzou seu caminho ainda. Forme um grupo com alguém e o Ashmark se lembrará dessa "
  .. "pessoa."
L.ENC_TAB_MET = "Encontros: {count} · último em {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "Encontros: {count} · {date}"
L.ENC_TAB_NOTE = "Nota"
L.ENC_TAB_WHO = "{race} {class}"
L.ENC_TAB_FIRST = "Primeiro encontro: {date}"

-- Chronicle sentences. Only "expulso" agrees with the subject, so ENC_LOG_KICK alone has _F forms.
L.ENC_LOG_CONTACT = "Você conheceu {contact}."
L.ENC_LOG_CONTACT_THEY = "{name} conheceu {contact}."
L.ENC_LOG_TRAVEL = "Você viajou com {people}."
L.ENC_LOG_TRAVEL_THEY = "{name} viajou com {people}."
L.ENC_LOG_BOSS = "Você lutou ao lado de {people} e venceu."
L.ENC_LOG_BOSS_THEY = "{name} lutou ao lado de {people} e venceu."
L.ENC_LOG_WIPE = "Você lutou ao lado de {people} e tombou."
L.ENC_LOG_WIPE_THEY = "{name} lutou ao lado de {people} e tombou."
L.ENC_LOG_CAMP = "Você compartilhou uma fogueira com {people}."
L.ENC_LOG_CAMP_THEY = "{name} compartilhou uma fogueira com {people}."
L.ENC_LOG_KICK = "Você foi expulso do grupo de {people}."
L.ENC_LOG_KICK_F = "Você foi expulsa do grupo de {people}."
L.ENC_LOG_KICK_THEY = "{name} foi expulso do grupo de {people}."
L.ENC_LOG_KICK_THEY_F = "{name} foi expulsa do grupo de {people}."

-- Parts of {people}, which always follows "com" or "de", so none of them carries an article that would contract.
L.ENC_LOG_PEER = "{who} ({archetype} de {place})"
L.ENC_LOG_PEER_NOPLACE = "{who} ({archetype})"
L.ENC_LOG_OTHER = "outra pessoa"
L.ENC_LOG_OTHERS = "outras {count} pessoas"
L.ENC_LOG_STRANGER = "um desconhecido"
L.ENC_LOG_STRANGERS = "{count} desconhecidos"
L.ENC_LOG_STRANGERS_ANY = "desconhecidos"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list} e {last}"

-- House ----------------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "Casa"
L.HOUSE_MODULE_DESC = "Personagens desta conta que compartilham um sobrenome formam uma casa. A aba Casa mostra "
  .. "os membros, as rixas que seus parentes assumiram, a crônica familiar e as pessoas que eles conhecem."

-- /ashmark house (5.9). "house", "reset" and "<nome>" as typed after /ashmark.
L.HOUSE_HELP = "mostrar sua casa; \"house <nome>\" entra na casa com esse nome, \"house reset\" volta a seguir seu "
  .. "sobrenome"
L.HOUSE_SLASH_CURRENT = "Você pertence à Casa {house}."
L.HOUSE_SLASH_NONE = "Você não pertence a nenhuma casa. Digite /ashmark house <nome> para entrar em uma."
L.HOUSE_SLASH_SET = "Agora você pertence à Casa {house}."
L.HOUSE_SLASH_RESET = "Sua casa volta a seguir seu sobrenome: Casa {house}."
L.HOUSE_SLASH_RESET_NONE = "Sua casa volta a seguir seu sobrenome. Sem sobrenome, você não pertence a nenhuma "
  .. "casa."
L.HOUSE_SLASH_OFF = "O módulo Casa está desativado ou indisponível, então sua casa não pode mudar agora."

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "Casa"
L.HOUSE_TAB_HEADING = "Casa {house}"
L.HOUSE_TAB_NO_HOUSE = "Sem casa"
L.HOUSE_TAB_NONE = "Personagens desta conta que compartilham um sobrenome formam uma casa. O Ashmark não conhece "
  .. "nenhum sobrenome deste personagem: digite /ashmark house <nome> para escolher uma casa."
L.HOUSE_TAB_ARCHETYPE = "Arquétipo: {archetype}"
L.HOUSE_TAB_MEMBERS = "Membros"
L.HOUSE_TAB_MEMBER = "{name}, nível {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "Rixas herdadas"
L.HOUSE_TAB_FEUD = "{name} se aliou com {faction} em {zone}."
L.HOUSE_TAB_CHRONICLE = "Crônica familiar"
L.HOUSE_TAB_MEMORY = "Memória familiar"
L.HOUSE_TAB_KNOWS = "{sibling} conhece {name}."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}: nível {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

-- Campfire -------------------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "Fogueira"
L.CAMP_MODULE_DESC = "Descanse em um acampamento até que seus benefícios façam efeito, e o Ashmark poderá encerrar "
  .. "ali um capítulo da sua crônica, se tiver acontecido o bastante desde o anterior."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "O capítulo {roman} se encerra · {place}"

-- Knowledge ------------------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "Conhecimento do personagem"
L.KNOW_MODULE_DESC = "As dicas de itens mostram apenas o que seu personagem pode saber. Um item que nunca esteve "
  .. "nas bolsas, no banco ou no equipamento deste personagem mostra o nome, o vínculo, onde é equipado, o nível "
  .. "do item, o tipo e os requisitos; o resto fica oculto. Itens que o próprio jogo ainda oculta ficam como o jogo "
  .. "os mostra."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "Seu personagem nunca teve isto em mãos."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "Recompensas de missão completas"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "Nunca ocultar as dicas das recompensas mostradas na janela de missão, para "
  .. "que você possa escolher uma recompensa sabendo o que ela faz."

-- Fiction --------------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "Ficção compartilhada"
L.FICTION_MODULE_DESC = "Membros do grupo que também usam o Ashmark descobrem seu arquétipo e sua origem sem que "
  .. "uma só palavra seja dita no bate-papo, e você descobre os deles, para que sua crônica e suas dicas possam "
  .. "dizer com quem você viajou. Nada é mostrado a outros jogadores."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "Forme um grupo com outro usuário do Ashmark, depois execute /ashmark test novamente."

-- Rumours --------------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "Rumores"
L.RUMOUR_MODULE_DESC = "O que você faz em um conflito corre como rumor de grupo em grupo, e você ouve o que os "
  .. "outros fizeram. Um rumor fala de um tipo de pessoa, um lugar e uma facção, nunca de um personagem."

-- Chat lines for a rumour heard (7.8). No sex is known: "alguém" carries the grammar and {archetype} stands as a
-- name after "a quem chamam de", with no article or adjective to agree with (no _F forms).
L.RUMOUR_HEARD_ALLIANCE = "Dizem que alguém de {place}, a quem chamam de {archetype}, se aliou com {faction}."
L.RUMOUR_HEARD_BROKE = "Dizem que alguém de {place}, a quem chamam de {archetype}, traiu {faction}."
L.RUMOUR_HEARD_TURNED = "Dizem que alguém de {place}, a quem chamam de {archetype}, deu as costas à própria casa "
  .. "para se aliar com {faction}."
-- Without a faction
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "Dizem que alguém de {place}, a quem chamam de {archetype}, escolheu um lado."
L.RUMOUR_HEARD_BROKE_VAGUE = "Dizem que alguém de {place}, a quem chamam de {archetype}, quebrou a palavra dada."
L.RUMOUR_HEARD_TURNED_VAGUE = "Dizem que alguém de {place}, a quem chamam de {archetype}, deu as costas à própria "
  .. "casa."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "Alie-se a uma facção em um conflito ou forme um grupo com outro usuário do Ashmark, depois "
  .. "execute /ashmark test novamente."

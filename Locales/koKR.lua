local _, ns = ...
local L = ns.Locale:For("koKR")

-- Address form: 당신, as Blizzard's koKR client addresses the player, in the formal polite style (하십시오체:
-- -습니다, -십시오). The subject 당신 is left out where Korean leaves it implicit, as the client does.
-- Names from the client stay uninflected: they stand before an invariant particle (에, 에서, 의) or a noun
-- ("{quest} 퀘스트", "{faction} 편", "{faction} 측", "{house} 가문"). Only the character names {name} and {sibling}
-- take a paired particle, 은(는). The fallbacks fit those frames: CORE_UNKNOWN_QUEST is the determiner "어떤"
-- ("어떤 퀘스트"), CORE_UNKNOWN_PLACE is "어딘가", CORE_UNKNOWN_PLAYER "누군가". {people} always stands before "의".
-- Korean has no grammatical gender, so this file has no _F forms.

-- Core -----------------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark는 World of Warcraft Forever 전용이므로 이 클라이언트에서는 꺼져 있습니다."
L.CORE_SV_NEW = "새 기록을 시작했습니다. 이 계정에서 전에 Ashmark를 사용했다면 저장된 데이터를 "
  .. "불러오지 못한 것입니다. /reload를 입력하거나 다시 로그아웃하지 마십시오. 게임을 종료한 다음, "
  .. "다음에 접속하기 전에 WTF\\Account\\<계정명>\\SavedVariables\\ 폴더에서 Ashmark.lua 파일을 "
  .. "Ashmark.lua.bak 파일로 교체하십시오."
L.CORE_SV_NEWER = "이 저장 데이터는 더 새로운 버전의 Ashmark에서 만들어졌습니다. 업데이트할 때까지 "
  .. "Ashmark는 이 데이터를 읽기만 합니다."
L.CORE_SV_RECOVERED = "저장된 데이터는 Ashmark가 알지 못하는 형식이었습니다. 새 기록을 시작했으며, "
  .. "이전 데이터는 손대지 않은 채 AshmarkDB.recovered에 보관됩니다."
L.CORE_SV_MIGRATE_FAILED = "Ashmark가 저장된 데이터를 업데이트하지 못했습니다. 이번 접속 동안에는 "
  .. "데이터를 읽기만 합니다."

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "반복된 오류로 {module} 모듈이 중지되었으며, 다음에 UI를 재시작할 때까지 "
  .. "꺼져 있습니다."
L.CORE_UNAVAILABLE = "필요한 기능: {capability}"
L.CORE_UNAVAILABLE_CLIENT = "이 클라이언트에는 이 모듈에 필요한 기능이 없습니다."
L.CORE_MISSING_EVENTS = "이 클라이언트에 없는 이벤트: {events}"
L.CORE_SETTING_CHAT_LINES = "대화창 메시지"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark가 대화창에 짧은 글을 남기도록 허용합니다."
L.CORE_SETTING_SOUNDS = "효과음"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark가 게임의 책장 넘기는 소리와 책 여닫는 소리를 재생합니다."
L.CORE_SETTING_SHARE = "다른 Ashmark 사용자와 공유"
L.CORE_SETTING_SHARE_DESC = "당신의 유형과 출신, 프로필 점수(신의, 생활권, 자비), 서버 종류, "
  .. "Ashmark 버전, 소문을 Ashmark를 사용하는 다른 파티원에게 보냅니다. "
  .. "만남 기록과 메모는 결코 당신의 클라이언트 밖으로 나가지 않습니다."

-- Shared vocabulary (5.8). Every frame writes "{quest} 퀘스트", so the quest fallback is a determiner.
L.CORE_UNKNOWN_QUEST = "어떤"
L.CORE_UNKNOWN_ITEM = "어떤 아이템"
L.CORE_UNKNOWN_FACTION = "알 수 없는 세력"
L.CORE_UNKNOWN_PLACE = "어딘가"
L.CORE_UNKNOWN_PLAYER = "누군가"
L.CORE_UNKNOWN_CLASS = "모험가"
L.CORE_UNKNOWN_RACE = "알 수 없는 종족"
L.CORE_RULESET_NORMAL = "일반"
L.CORE_RULESET_PVP = "PvP"
L.CORE_RULESET_RP = "역할극"
L.CORE_RULESET_RPPVP = "역할극 PvP"
L.CORE_RULESET_HARDCORE = "하드코어"

-- Chronicle sentences
L.CORE_LOG_TURNIN = "{quest} 퀘스트를 완료했습니다."
L.CORE_LOG_TURNIN_THEY = "{name}은(는) {quest} 퀘스트를 완료했습니다."
L.CORE_LOG_ABANDON = "{quest} 퀘스트를 포기했습니다."
L.CORE_LOG_ABANDON_THEY = "{name}은(는) {quest} 퀘스트를 포기했습니다."
L.CORE_LOG_ZONE_FIRST = "처음으로 {zone}에 발을 디뎠습니다."
L.CORE_LOG_ZONE_FIRST_THEY = "{name}은(는) 처음으로 {zone}에 발을 디뎠습니다."
L.CORE_LOG_LEVEL = "레벨 {level}에 도달했습니다."
L.CORE_LOG_LEVEL_THEY = "{name}은(는) 레벨 {level}에 도달했습니다."
L.CORE_LOG_DEATH = "{place}에서 죽음을 맞았습니다."
L.CORE_LOG_DEATH_THEY = "{name}은(는) {place}에서 죽음을 맞았습니다."
L.CORE_LOG_REP = "{faction}에 대한 평판이 이제 {standing}입니다."
L.CORE_LOG_REP_THEY = "{faction}에 대한 {name}의 평판이 이제 {standing}입니다."
L.CORE_LOG_CHAPTER = "{place}에서 제{roman}장이 막을 내립니다."
L.CORE_LOG_CHAPTER_THEY = "{place}에서 {name}의 제{roman}장이 막을 내립니다."

-- Slash commands (5.9). Help texts are short noun phrases, as in a command list.
L.CORE_HELP_HEADER = "명령어:"
L.CORE_HELP_TOGGLE = "연대기 열기 또는 닫기"
L.CORE_HELP_HELP = "이 명령어 목록 보기"
L.CORE_HELP_DEBUG = "이번 접속 동안 디버그 출력 켜기 또는 끄기"
L.CORE_HELP_RESET = "이 캐릭터의 기록 지우기 (\"reset others\": 만남 기록, 다른 사용자 정보, 들은 소문 지우기, "
  .. "\"reset <이름>\": 이 계정의 다른 캐릭터 잊기)"
L.CORE_UNKNOWN_COMMAND = "알 수 없는 명령어: {command}"
L.CORE_DEBUG_ON = "이번 접속 동안 디버그 출력이 켜졌습니다."
L.CORE_DEBUG_OFF = "디버그 출력이 꺼졌습니다."
L.CORE_RESET_CONFIRM = "Ashmark가 이 캐릭터에 대해 기록한 모든 내용을 지우시겠습니까? 되돌릴 수 "
  .. "없습니다."
L.CORE_RESET_OTHERS_CONFIRM = "이 계정의 모든 만남 기록, 다른 사용자 정보, 들은 소문을 지우시겠습니까? "
  .. "당신에게서 비롯된 소문은 남습니다. 되돌릴 수 없습니다."
L.CORE_RESET_ACCEPT = "지우기"
L.CORE_CANCEL = "취소"
L.CORE_RESET_DONE = "이 캐릭터의 기록을 지웠습니다."
L.CORE_RESET_OTHERS_DONE = "만남 기록, 다른 사용자 정보, 들은 소문을 지웠습니다."
L.CORE_RESET_READONLY = "저장된 데이터가 더 새로운 버전의 Ashmark에서 만들어졌으므로 아무것도 지울 "
  .. "수 없습니다."
L.CORE_RESET_CHAR_UNKNOWN = "이 계정에 저장된 다른 캐릭터 중 이름이 {name}인 캐릭터는 없습니다."
L.CORE_RESET_CHAR_AMBIGUOUS = "이름이 {name}인 캐릭터가 여럿입니다. 그중 하나의 GUID로 /ashmark reset <GUID>를 "
  .. "입력하십시오:"
L.CORE_RESET_CHAR_LINE = "{name}, 레벨 {level}: {guid}"
L.CORE_RESET_CHAR_CONFIRM = "{name}을(를) 잊으시겠습니까? Ashmark가 이 캐릭터의 연대기, 결정, 프로필, 만남 기록을 "
  .. "지웁니다. 삭제했거나 다른 곳으로 이전한 캐릭터에만 사용하십시오."
L.CORE_RESET_CHAR_DONE = "{name}을(를) 잊었습니다."

-- UI shell (6.1, 6.2)
L.CORE_TAB_CHRONICLE = "연대기"
L.CORE_CHRONICLE_CHAPTER = "제{roman}장"
L.CORE_CHRONICLE_CHAPTER_OPEN = "제{roman}장 (현재)"
L.CORE_CHRONICLE_CLOSED = "{date}에 끝맺음 · {place}"
L.CORE_CHRONICLE_BEGUN = "{date}에 시작 · 아직 쓰이는 중"
L.CORE_CHRONICLE_OPEN = "아직 쓰이는 중"
L.CORE_CHRONICLE_EMPTY = "이 장에는 아직 이야기할 만한 일이 없습니다."
L.CORE_CHRONICLE_NO_RECORD = "Ashmark에는 아직 이 캐릭터의 기록이 없습니다."
L.CORE_COMPARTMENT_CLICK = "클릭하여 연대기를 열거나 닫습니다."
L.CORE_COMPARTMENT_RIGHT_CLICK = "오른쪽 클릭하여 설정을 엽니다."

-- Test -----------------------------------------------------------------------------------------------------------

L.TEST_HELP = "이 클라이언트에서 자체 테스트를 실행하고 스크린샷 찍기"
L.TEST_HELP_PROBE = "개발자를 위해 이 클라이언트의 원시 정보 기록하기"
L.TEST_NOT_IN_COMBAT = "전투 중에는 테스트를 실행할 수 없습니다. 전투가 끝난 뒤 다시 시도하십시오."
L.TEST_SUMMARY = "테스트 완료: 통과 {passed}개, 실패 {failed}개, 건너뜀 {skipped}개."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "통과"
L.TEST_FAIL = "실패"
L.TEST_SKIP = "건너뜀"
L.TEST_OPEN_QUEST_DIALOG = "스크린샷을 위해 먼저 퀘스트 제공자에게 말을 거십시오."
L.TEST_RELOAD = "결과를 저장하려면 /reload를 입력하십시오."
L.TEST_NOT_STORED = "저장된 데이터가 더 새로운 버전의 Ashmark에서 만들어졌으므로 아무것도 저장하지 "
  .. "않습니다. 전체 보고서가 이어집니다."
L.TEST_LATE = "뒤늦은 결과: {what}"
L.TEST_PROBE_DONE = "조사 결과 정보 {count}개를 기록했습니다."
L.TEST_PROBE_NEXT = "이번 접속 중에 퀘스트를 하나 수락하고 전투를 한 번 시작하십시오. 조사가 두 "
  .. "가지를 모두 기록합니다."

-- Conflicts ------------------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "분쟁"
L.CONFLICT_MODULE_DESC = "어떤 퀘스트는 한쪽 편을 다른 편과 맞서게 합니다. Ashmark는 당신이 택한 "
  .. "편을 기억하고, 그 편에 어긋나는 퀘스트에는 퀘스트 창 아래에 표시를 남기며, 당신이 맹세를 "
  .. "어기면 이를 기록합니다."

-- A side without a reputation faction; stands where a faction name would, before "편", "측" or "또는".
L.CONFLICT_UNNAMED = "깃발 없는 이들"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "{faction} 측과 맺은 동맹에 어긋납니다."
L.CONFLICT_CONTRADICTS_NOFACTION = "당신이 택한 편에 어긋납니다."
L.CONFLICT_HOUSE_STANDS_AGAINST = "당신이 속한 {house} 가문은 {faction} 측과 대립하고 있습니다."
L.CONFLICT_TEST_DIALOG = "퀘스트 창 아래에 나타나는 Ashmark의 문구가 여기에 표시됩니다."

-- Chronicle sentences
L.CONFLICT_ALLIED = "{zone}에서 {faction} 편에 섰습니다({title} 퀘스트)."
L.CONFLICT_ALLIED_THEY = "{name}은(는) {zone}에서 {faction} 편에 섰습니다({title} 퀘스트)."
L.CONFLICT_ALLIED_REP = "{zone}에서는 {faction}에 대한 평판이 당신의 편을 정했습니다."
L.CONFLICT_ALLIED_REP_THEY = "{zone}에서는 {faction}에 대한 평판이 {name}의 편을 정했습니다."
L.CONFLICT_BROKE_WORD = "{broken} 측과의 신의를 저버리고 {faction} 측을 위해 {quest} 퀘스트를 "
  .. "완수했습니다."
L.CONFLICT_BROKE_WORD_THEY = "{name}은(는) {broken} 측과의 신의를 저버리고 {faction} 측을 위해 "
  .. "{quest} 퀘스트를 완수했습니다."
L.CONFLICT_SWITCHED = "또다시 편을 바꾸었습니다. {faction} 측을 위해 {quest} 퀘스트를 완수하고 "
  .. "{broken} 측을 뒤로했습니다."
L.CONFLICT_SWITCHED_THEY = "{name}은(는) 또다시 편을 바꾸었습니다. {faction} 측을 위해 {quest} "
  .. "퀘스트를 완수하고 {broken} 측을 뒤로했습니다."
L.CONFLICT_HOUSETURN = "{house} 가문을 등지고 {zone}에서 {faction} 편에 섰습니다."
L.CONFLICT_HOUSETURN_THEY = "{name}은(는) {house} 가문을 등지고 {zone}에서 {faction} 편에 섰습니다."

-- Decisions tab (6.1)
L.CONFLICT_TAB = "결정"
L.CONFLICT_TAB_SIDES = "{title} 퀘스트: {a} 또는 {b}"
L.CONFLICT_TAB_SIDES_VOWEL = "{title} 퀘스트: {a} 또는 {b}"
L.CONFLICT_TAB_ALLIED = "{date}부터 {faction} 편에 서 있음"
L.CONFLICT_TAB_OPEN = "미정"
L.CONFLICT_TAB_BROKEN = "{count}회 어김"
L.CONFLICT_TAB_VIOLATIONS = "맹세를 어긴 횟수: {count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "맹세를 어긴 적이 없습니다."
L.CONFLICT_TAB_EMPTY = "Ashmark는 아직 이 세계의 분쟁을 하나도 알지 못합니다."

-- Profile --------------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "프로필"
L.PROFILE_MODULE_DESC = "Ashmark는 당신의 행동에서 캐릭터의 됨됨이를 읽어 냅니다. 맹세를 지키는지, "
  .. "야생에서 지내는지 도시에서 지내는지, 해를 끼치지 않는 생물을 어떻게 대하는지를 살핍니다."

-- Archetypes (7.2): nouns used as labels and epithets ("{place}의 {archetype}"). Korean has no gender, so no _F.
L.PROFILE_OATHKEEPER = "맹세지기"
L.PROFILE_OPPORTUNIST = "기회주의자"
L.PROFILE_WANDERER = "방랑자"
L.PROFILE_TOWNSFOLK = "도시인"
L.PROFILE_GENTLE = "자비로운 자"
L.PROFILE_RUTHLESS = "무자비한 자"
L.PROFILE_PRAGMATIST = "실용주의자"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "동물 3마리와 온순한 중립 야수 3마리를 처치한 다음 /ashmark test를 다시 "
  .. "실행하십시오."
L.PROFILE_TEST_CRITTER_TARGET = "아무 생물이나 대상으로 지정한 다음 /ashmark test를 다시 실행하십시오."
L.PROFILE_TEST_CRITTER_OFF = "이 클라이언트는 동물을 식별할 수 없으므로 동물 처치는 집계하지 않습니다."

-- Map ------------------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "세계 지도"
L.MAP_MODULE_DESC = "세계 지도에 당신만의 이야기를 표시합니다. 맹세를 어긴 곳, 연대기의 장이 막을 내린 곳을 보여 "
  .. "줍니다. 이 표시는 당신에게만 보입니다. 당신이 아는 분쟁과 당신이 택한 편은 이후 버전에서 표시됩니다."

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{title} 퀘스트: {a} 또는 {b}"
L.MAP_PIN_SIDES_VOWEL = "{title} 퀘스트: {a} 또는 {b}"
L.MAP_PIN_OPEN = "이곳에서는 아직 어느 편에도 서지 않았습니다."
L.MAP_PIN_ALLIED = "{faction} 편에 서 있습니다."
L.MAP_PIN_BROKEN = "{faction} 편에 서 있으며, 이곳에서 맹세를 {count}번 어겼습니다."
L.MAP_PIN_VIOLATION = "맹세를 어긴 곳"
L.MAP_PIN_CHAPTER = "제{roman}장"
L.MAP_PIN_CHAPTER_CLOSED = "{date}에 이곳에서 끝맺음"

-- Encounters -----------------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "만남"
L.ENC_MODULE_DESC = "Ashmark는 당신과 파티를 맺은 사람들에 대해 얼마나 자주, 어디서 만났는지와 그 "
  .. "만남이 어떻게 흘러갔는지를 기억합니다. 그들의 툴팁에 한 줄을 덧붙이고, 만남 탭에 목록으로 보여 "
  .. "주며, 그들에 대한 당신의 메모를 보관합니다. 만남 기록과 메모는 결코 당신의 클라이언트 밖으로 "
  .. "나가지 않습니다."

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "만남: {count}회 · 최근 {place}"
L.ENC_TOOLTIP_NOPLACE = "만남: {count}회"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "{name}의 얼굴을 압니다. {count}번 만났고, 마지막으로 만난 곳은 {place}입니다."
L.ENC_RECOGNISE_NOPLACE = "{name}의 얼굴을 압니다. {count}번 만났습니다."
L.ENC_RECOGNISE_MORE = "…그 밖에도 아는 사람이 {count}명 더 있습니다."

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "낯익은 얼굴"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "{name}에 대한 메모:"
L.ENC_NOTE_SAVE = "저장"

-- Encounters tab (6.1)
L.ENC_TAB = "만남"
L.ENC_TAB_TOTAL = "만난 사람: {count}명 · 낯익은 얼굴: {recurring}명"
L.ENC_TAB_EMPTY = "아직 길에서 마주친 사람이 없습니다. 누군가와 파티를 맺으면 Ashmark가 그 사람을 "
  .. "기억합니다."
L.ENC_TAB_MET = "{count}회 만남 · 최근 {place} · {date}"
L.ENC_TAB_MET_NOPLACE = "{count}회 만남 · {date}"
L.ENC_TAB_NOTE = "메모"
L.ENC_TAB_WHO = "{race} {class}"
L.ENC_TAB_FIRST = "첫 만남: {date}"

-- Chronicle sentences. {people} always stands before "의", so its parts below need no particle of their own.
L.ENC_LOG_CONTACT = "{contact}의 얼굴을 처음 마주했습니다."
L.ENC_LOG_CONTACT_THEY = "{name}은(는) {contact}의 얼굴을 처음 마주했습니다."
L.ENC_LOG_TRAVEL = "{people}의 길동무가 되었습니다."
L.ENC_LOG_TRAVEL_THEY = "{name}은(는) {people}의 길동무가 되었습니다."
L.ENC_LOG_BOSS = "{people}의 곁에서 싸워 승리했습니다."
L.ENC_LOG_BOSS_THEY = "{name}은(는) {people}의 곁에서 싸워 승리했습니다."
L.ENC_LOG_WIPE = "{people}의 곁에서 싸우다 쓰러졌습니다."
L.ENC_LOG_WIPE_THEY = "{name}은(는) {people}의 곁에서 싸우다 쓰러졌습니다."
L.ENC_LOG_CAMP = "{people}의 곁에 앉아 함께 모닥불을 쬐었습니다."
L.ENC_LOG_CAMP_THEY = "{name}은(는) {people}의 곁에 앉아 함께 모닥불을 쬐었습니다."
L.ENC_LOG_KICK = "{people}의 파티에서 쫓겨났습니다."
L.ENC_LOG_KICK_THEY = "{name}은(는) {people}의 파티에서 쫓겨났습니다."

-- Parts of {people}: a plain comma list, as Korean writes "탈렌, 미라, 다른 2명".
L.ENC_LOG_PEER = "{who}({place}의 {archetype})"
L.ENC_LOG_PEER_NOPLACE = "{who}({archetype})"
L.ENC_LOG_OTHER = "다른 한 명"
L.ENC_LOG_OTHERS = "다른 {count}명"
L.ENC_LOG_STRANGER = "낯선 이"
L.ENC_LOG_STRANGERS = "낯선 이 {count}명"
L.ENC_LOG_STRANGERS_ANY = "낯선 이들"
L.ENC_LOG_COMPANION = "동료"
L.ENC_LOG_COMPANIONS = "동료 {count}명"
L.ENC_LIST_SEP = ", "
L.ENC_LIST_AND = "{list}, {last}"
L.ENC_LIST_AND_VOWEL = "{list}, {last}"

-- House ----------------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "가문"
L.HOUSE_MODULE_DESC = "이 계정에서 성이 같은 캐릭터들은 하나의 가문을 이룹니다. 가문 탭에는 구성원, "
  .. "친족이 가담한 반목, 가문 연대기, 친족이 아는 사람들이 표시됩니다."

-- /ashmark house (5.9)
L.HOUSE_HELP = "당신의 가문 보기 (\"house <이름>\": 그 이름의 가문에 들어가기, \"house reset\": "
  .. "다시 성을 따르기)"
L.HOUSE_SLASH_CURRENT = "당신은 {house} 가문에 속해 있습니다."
L.HOUSE_SLASH_NONE = "당신은 어느 가문에도 속해 있지 않습니다. 가문에 들어가려면 /ashmark house "
  .. "<이름>을 입력하십시오."
L.HOUSE_SLASH_SET = "이제 당신은 {house} 가문의 일원입니다."
L.HOUSE_SLASH_RESET = "당신의 가문이 다시 성을 따릅니다. {house} 가문입니다."
L.HOUSE_SLASH_RESET_NONE = "당신의 가문이 다시 성을 따릅니다. 성이 없으므로 어느 가문에도 속하지 "
  .. "않습니다."
L.HOUSE_SLASH_OFF = "가문 모듈이 꺼져 있거나 사용할 수 없어 지금은 가문을 바꿀 수 없습니다."

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "가문"
L.HOUSE_TAB_HEADING = "{house} 가문"
L.HOUSE_TAB_NO_HOUSE = "가문 없음"
L.HOUSE_TAB_NONE = "이 계정에서 성이 같은 캐릭터들은 하나의 가문을 이룹니다. Ashmark는 이 캐릭터의 "
  .. "성을 알지 못합니다. 가문을 정하려면 /ashmark house <이름>을 입력하십시오."
L.HOUSE_TAB_ARCHETYPE = "유형: {archetype}"
L.HOUSE_TAB_MEMBERS = "구성원"
L.HOUSE_TAB_MEMBER = "{name}, 레벨 {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "물려받은 반목"
L.HOUSE_TAB_FEUD = "{title} 퀘스트: {name}은(는) {zone}에서 {faction} 편에 섰습니다."
L.HOUSE_TAB_CHRONICLE = "가문 연대기"
L.HOUSE_TAB_MEMORY = "가문의 기억"
L.HOUSE_TAB_KNOWS = "{sibling}은(는) {name}의 얼굴을 압니다."

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}: 레벨 {level}"
L.HOUSE_LEGACY_STANDING = "{faction}: {standing}"

-- Campfire -------------------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "모닥불"
L.CAMP_MODULE_DESC = "야영지에서 효과가 나타날 때까지 쉬면, 지난 장 이후로 일이 충분히 쌓였을 경우 "
  .. "Ashmark가 그곳에서 연대기의 한 장을 마무리할 수 있습니다."

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "제{roman}장이 막을 내립니다 · {place}"

-- Knowledge ------------------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "캐릭터 지식"
L.KNOW_MODULE_DESC = "아이템 툴팁에는 당신의 캐릭터가 알 수 있는 정보만 표시됩니다. 이 캐릭터의 "
  .. "가방이나 은행에 들어온 적도, 장착된 적도 없는 아이템은 이름, 귀속, 착용 부위, 아이템 레벨, "
  .. "종류, 요구 조건만 보이고 나머지는 숨겨집니다. 게임 자체가 아직 숨기고 있는 아이템은 게임이 보여 주는 "
  .. "그대로 둡니다."

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "당신의 캐릭터는 이 아이템을 지녀 본 적이 없습니다."

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "퀘스트 보상 전체 표시"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "퀘스트 창에 표시되는 보상의 툴팁은 숨기지 않습니다. 보상이 "
  .. "어떤 효과를 지니는지 알고 고를 수 있습니다."

-- Fiction --------------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "공유된 이야기"
L.FICTION_MODULE_DESC = "Ashmark를 사용하는 다른 파티원은 대화창에 한마디 없이도 당신의 유형과 "
  .. "출신, 프로필 점수, 서버 종류, Ashmark 버전을 알게 되고, 당신도 그들의 것을 알게 됩니다. "
  .. "그래서 연대기와 툴팁이 당신이 누구와 함께 여행했는지 알려 줄 수 있습니다. "
  .. "다른 플레이어에게는 아무것도 표시되지 않습니다."

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "다른 Ashmark 사용자와 파티를 맺은 다음 /ashmark test를 다시 실행하십시오."

-- Rumours --------------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "소문"
L.RUMOUR_MODULE_DESC = "분쟁에서 당신이 한 일은 소문이 되어 파티에서 파티로 퍼져 나가고, 당신 또한 "
  .. "다른 이들이 한 일을 듣게 됩니다. 소문은 어떤 유형의 사람과 장소, 세력을 말할 뿐 캐릭터를 "
  .. "지목하지 않습니다."

-- Chat lines for a rumour heard (7.8). No sex is known and Korean needs none: {archetype} stands as an epithet in
-- "{place}의 {archetype}에 관한 소문", before an invariant particle, and the second sentence leaves the subject
-- implicit (no _F forms).
L.RUMOUR_HEARD_ALLIANCE = "{place}의 {archetype}에 관한 소문이 들려옵니다. {faction} 편에 섰다고 "
  .. "합니다."
L.RUMOUR_HEARD_BROKE = "{place}의 {archetype}에 관한 소문이 들려옵니다. {faction} 측과의 신의를 "
  .. "저버렸다고 합니다."
L.RUMOUR_HEARD_TURNED = "{place}의 {archetype}에 관한 소문이 들려옵니다. 가문을 등지고 {faction} 편에 "
  .. "섰다고 합니다."

-- Without a faction
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "{place}의 {archetype}에 관한 소문이 들려옵니다. 어느 한쪽 편을 "
  .. "택했다고 합니다."
L.RUMOUR_HEARD_BROKE_VAGUE = "{place}의 {archetype}에 관한 소문이 들려옵니다. 맹세를 어겼다고 "
  .. "합니다."
L.RUMOUR_HEARD_TURNED_VAGUE = "{place}의 {archetype}에 관한 소문이 들려옵니다. 자신의 가문을 "
  .. "등졌다고 합니다."

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "분쟁에서 한 세력의 편에 서거나 다른 Ashmark 사용자와 파티를 맺은 다음 "
  .. "/ashmark test를 다시 실행하십시오."

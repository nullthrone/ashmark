local _, ns = ...
local L = ns.Locale:For("zhTW")

-- Address form: "你", as in Blizzard's zhTW client. Blizzard's zhTW terms: 任務, 聲望, 陣營, 隊伍, 組隊, 等級,
-- 背包, 銀行, 裝備, 物品等級, 滑鼠提示, 任務視窗, 用戶端, 帳號, 設定, 小動物.
-- Chinese has no grammatical gender and the _THEY forms avoid 他/她, so there are no _F keys.
-- Names from the client stand without particles of their own: quest titles in 「」, house names before 家族.
-- CORE_UNKNOWN_* fill the same slots ("未知任務" inside 「」, "某處" after 在 or 來自).
-- A half-width space separates Chinese text from Latin words, slash commands and numbers ({count}, {level},
-- {roman}, {date}); placeholders for names from the client take no space.

-- Core -----------------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark 只能在 World of Warcraft Forever 上運作，在此用戶端中不會啟用。"
L.CORE_SV_NEW = "已開始新的紀錄。如果此帳號曾使用過 Ashmark，表示已儲存的資料未能載入："
  .. "請勿再次 /reload 或登出。請離開遊戲，並在下次登入前，於 "
  .. "WTF\\Account\\<帳號名稱>\\SavedVariables\\ 中以 Ashmark.lua.bak 取代 Ashmark.lua。"
L.CORE_SV_NEWER = "這些已儲存的資料來自較新版本的 Ashmark。在你更新之前，Ashmark 只會讀取這些資料。"
L.CORE_SV_RECOVERED = "已儲存的資料不是 Ashmark 認得的格式。已開始新的紀錄；舊資料原封不動地保留在 "
  .. "AshmarkDB.recovered 中。"
L.CORE_SV_MIGRATE_FAILED = "Ashmark 無法更新其已儲存的資料，本次登入期間只會讀取這些資料。"

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "模組「{module}」因多次出錯而停止運作，在下次重新載入介面前都會保持關閉。"
L.CORE_UNAVAILABLE = "需要 {capability}"
L.CORE_UNAVAILABLE_CLIENT = "此用戶端缺少此模組所需的功能。"
L.CORE_MISSING_EVENTS = "此用戶端缺少的事件：{events}"
L.CORE_SETTING_CHAT_LINES = "聊天視窗訊息"
L.CORE_SETTING_CHAT_LINES_DESC = "Ashmark 可以在聊天視窗中寫下簡短的訊息。"
L.CORE_SETTING_SOUNDS = "音效"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark 會播放遊戲本身的翻頁與書本音效。"
L.CORE_SETTING_SHARE = "與其他 Ashmark 使用者分享"
L.CORE_SETTING_SHARE_DESC = "將你的人物類型、出身、側寫分數（守信、棲所、仁慈）、伺服器類型、"
  .. "Ashmark 版本與傳聞傳送給同樣使用 Ashmark 的隊伍成員。"
  .. "相識者紀錄與筆記絕不會離開你的用戶端。"

-- Shared vocabulary (5.8)
L.CORE_UNKNOWN_QUEST = "未知任務"
L.CORE_UNKNOWN_ITEM = "未知物品"
L.CORE_UNKNOWN_FACTION = "未知陣營"
L.CORE_UNKNOWN_PLACE = "某處"
L.CORE_UNKNOWN_PLAYER = "某人"
L.CORE_UNKNOWN_CLASS = "冒險者"
L.CORE_UNKNOWN_RACE = "未知種族"
L.CORE_RULESET_NORMAL = "一般"
L.CORE_RULESET_PVP = "PvP"
L.CORE_RULESET_RP = "角色扮演"
L.CORE_RULESET_RPPVP = "角色扮演 PvP"
L.CORE_RULESET_HARDCORE = "專家模式"

-- Chronicle sentences
L.CORE_LOG_TURNIN = "你完成了「{quest}」。"
L.CORE_LOG_TURNIN_THEY = "{name}完成了「{quest}」。"
L.CORE_LOG_ABANDON = "你放棄了「{quest}」。"
L.CORE_LOG_ABANDON_THEY = "{name}放棄了「{quest}」。"
L.CORE_LOG_ZONE_FIRST = "你初次踏足{zone}。"
L.CORE_LOG_ZONE_FIRST_THEY = "{name}初次踏足{zone}。"
L.CORE_LOG_LEVEL = "你達到了 {level} 級。"
L.CORE_LOG_LEVEL_THEY = "{name}達到了 {level} 級。"
L.CORE_LOG_DEATH = "你死於{place}。"
L.CORE_LOG_DEATH_THEY = "{name}死於{place}。"
L.CORE_LOG_REP = "你在{faction}的聲望現在是{standing}。"
L.CORE_LOG_REP_THEY = "{name}在{faction}的聲望現在是{standing}。"
L.CORE_LOG_CHAPTER = "第 {roman} 章在{place}落幕。"
L.CORE_LOG_CHAPTER_THEY = "{name}的第 {roman} 章在{place}落幕。"
L.CORE_LOG_DEATH_NOZONE = "你死於{place}。"
L.CORE_LOG_DEATH_NOZONE_THEY = "{name}死於{place}。"
L.CORE_LOG_CHAPTER_NOZONE = "第 {roman} 章在{place}落幕。"
L.CORE_LOG_CHAPTER_NOZONE_THEY = "{name}的第 {roman} 章在{place}落幕。"

-- Slash commands (5.9)
L.CORE_HELP_HEADER = "指令："
L.CORE_HELP_TOGGLE = "開啟或關閉編年史"
L.CORE_HELP_HELP = "列出這些指令"
L.CORE_HELP_DEBUG = "在本次登入期間開啟或關閉偵錯訊息"
L.CORE_HELP_RESET = "清除此角色的紀錄；「reset others」會清除相識者、同行者與聽來的傳聞；「reset <名稱>」"
  .. "會忘記此帳號的另一個角色"
L.CORE_UNKNOWN_COMMAND = "未知的指令：{command}"
L.CORE_DEBUG_ON = "本次登入期間已開啟偵錯訊息。"
L.CORE_DEBUG_OFF = "偵錯訊息已關閉。"
L.CORE_RESET_CONFIRM = "要清除 Ashmark 為此角色記錄的一切嗎？此動作無法復原。"
L.CORE_RESET_OTHERS_CONFIRM = "要清除此帳號上所有的相識者、同行者與聽來的傳聞嗎？你自己的傳聞會保留。"
  .. "此動作無法復原。"
L.CORE_RESET_ACCEPT = "清除"
L.CORE_CANCEL = "取消"
L.CORE_RESET_DONE = "此角色的紀錄已清除。"
L.CORE_RESET_OTHERS_DONE = "相識者、同行者與聽來的傳聞已清除。"
L.CORE_RESET_READONLY = "已儲存的資料來自較新版本的 Ashmark，因此無法清除任何內容。"
L.CORE_RESET_CHAR_UNKNOWN = "此帳號沒有儲存其他名為{name}的角色。"
L.CORE_RESET_CHAR_AMBIGUOUS = "有數個角色都名為{name}。請以其中一個角色的 GUID 輸入 /ashmark reset <GUID>："
L.CORE_RESET_CHAR_LINE = "{name}，等級 {level}：{guid}"
L.CORE_RESET_CHAR_CONFIRM = "要忘記{name}嗎？Ashmark 會刪除此角色的編年史、抉擇、人物側寫與相遇紀錄。"
  .. "請只對你已刪除或已轉移的角色這麼做。"
L.CORE_RESET_CHAR_DONE = "已忘記{name}。"

-- UI shell (6.1, 6.2)
L.CORE_TAB_CHRONICLE = "編年史"
L.CORE_CHRONICLE_CHAPTER = "第 {roman} 章"
L.CORE_CHRONICLE_CHAPTER_OPEN = "第 {roman} 章（進行中）"
L.CORE_CHRONICLE_CLOSED = "結束於 {date} · {place}"
L.CORE_CHRONICLE_BEGUN = "始於 {date} · 仍在書寫中"
L.CORE_CHRONICLE_OPEN = "仍在書寫中"
L.CORE_CHRONICLE_EMPTY = "這一章裡還沒有值得一提的事。"
L.CORE_CHRONICLE_NO_RECORD = "Ashmark 尚未為此角色保存任何紀錄。"
L.CORE_COMPARTMENT_CLICK = "點擊以開啟或關閉編年史。"
L.CORE_COMPARTMENT_RIGHT_CLICK = "右鍵點擊以開啟設定。"

-- Test -----------------------------------------------------------------------------------------------------------

L.TEST_HELP = "對此用戶端執行自我測試並截圖"
L.TEST_HELP_PROBE = "為開發者記錄此用戶端的原始資料"
L.TEST_NOT_IN_COMBAT = "戰鬥中無法執行測試。請在戰鬥結束後再試一次。"
L.TEST_SUMMARY = "測試完成：{passed} 項通過，{failed} 項失敗，{skipped} 項略過。"
L.TEST_LINE = "{state} {id}：{detail}"
L.TEST_PASS = "通過"
L.TEST_FAIL = "失敗"
L.TEST_SKIP = "略過"
L.TEST_OPEN_QUEST_DIALOG = "請先與任務 NPC 交談，以便截圖。"
L.TEST_RELOAD = "輸入 /reload 以儲存結果。"
L.TEST_NOT_STORED = "已儲存的資料來自較新版本的 Ashmark，因此不會儲存任何內容。以下是完整報告。"
L.TEST_NOT_STORED_MIGRATION = "Ashmark 無法更新其已儲存的資料，因此不會儲存任何內容。以下是完整報告。"
L.TEST_LATE = "後續結果：{what}"
L.TEST_PROBE_DONE = "探測記錄了 {count} 項資訊。"
L.TEST_PROBE_NEXT = "請在本次登入期間接受一個任務並開始一場戰鬥：探測會將兩者都記錄下來。"

-- Conflicts ------------------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "衝突"
L.CONFLICT_MODULE_DESC = "有些任務會讓一方與另一方對立。Ashmark 會記住你選擇的立場，在任務視窗下方標示與之"
  .. "相悖的任務，並在你違背諾言時記下這件事。"

-- A side without a reputation faction; stands where a faction name would.
L.CONFLICT_UNNAMED = "無旗之眾"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "此任務違背你與{faction}的盟約。"
L.CONFLICT_CONTRADICTS_NOFACTION = "此任務違背你所選擇的立場。"
L.CONFLICT_HOUSE_STANDS_AGAINST = "你所屬的{house}家族與{faction}為敵。"
L.CONFLICT_TEST_DIALOG = "Ashmark 在任務視窗下方的提示會顯示在這裡。"

-- Chronicle sentences
L.CONFLICT_ALLIED = "你在{zone}站到了{faction}一邊（「{title}」）。"
L.CONFLICT_ALLIED_THEY = "{name}在{zone}站到了{faction}一邊（「{title}」）。"
L.CONFLICT_ALLIED_REP = "你在{faction}的聲望決定了你在{zone}的立場。"
L.CONFLICT_ALLIED_REP_THEY = "{name}在{faction}的聲望決定了自己在{zone}的立場。"
L.CONFLICT_BROKE_WORD = "你背棄了{broken}，為{faction}完成了「{quest}」。"
L.CONFLICT_BROKE_WORD_THEY = "{name}背棄了{broken}，為{faction}完成了「{quest}」。"
L.CONFLICT_SWITCHED = "你再度改換立場：為{faction}完成了「{quest}」，將{broken}拋在身後。"
L.CONFLICT_SWITCHED_THEY = "{name}再度改換立場：為{faction}完成了「{quest}」，將{broken}拋在身後。"
L.CONFLICT_HOUSETURN = "你背離了{house}家族，在{zone}站到了{faction}一邊。"
L.CONFLICT_HOUSETURN_THEY = "{name}背離了{house}家族，在{zone}站到了{faction}一邊。"

-- Decisions tab (6.1)
L.CONFLICT_TAB = "抉擇"
L.CONFLICT_TAB_SIDES = "「{title}」：{a}或{b}"
L.CONFLICT_TAB_SIDES_VOWEL = "「{title}」：{a}或{b}"
L.CONFLICT_TAB_ALLIED = "自 {date} 起站在{faction}一邊"
L.CONFLICT_TAB_OPEN = "尚未選擇"
L.CONFLICT_TAB_BROKEN = "違諾 {count} 次"
L.CONFLICT_TAB_VIOLATIONS = "違背諾言：{count} 次"
L.CONFLICT_TAB_NO_VIOLATIONS = "你從未違背諾言。"
L.CONFLICT_TAB_EMPTY = "Ashmark 尚未得知這個世界中的任何衝突。"

-- Profile --------------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "人物側寫"
L.PROFILE_MODULE_DESC = "Ashmark 從你的所作所為解讀你的角色：你是否信守諾言，你棲身荒野還是城鎮，"
  .. "以及你如何對待無害的生物。"

-- Archetypes (7.2): labels, used as epithets ("來自西部荒野的守誓者"); no feminine forms.
L.PROFILE_OATHKEEPER = "守誓者"
L.PROFILE_OPPORTUNIST = "投機者"
L.PROFILE_WANDERER = "漂泊者"
L.PROFILE_TOWNSFOLK = "城鎮居民"
L.PROFILE_GENTLE = "仁慈之人"
L.PROFILE_RUTHLESS = "冷酷之人"
L.PROFILE_PRAGMATIST = "務實者"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "擊殺 3 隻小動物和 3 隻尚未進入戰鬥的中立野獸，然後再次執行 /ashmark test。"
L.PROFILE_TEST_CRITTER_TARGET = "以任一生物為目標，然後再次執行 /ashmark test。"
L.PROFILE_TEST_CRITTER_OFF = "此用戶端無法辨識小動物，因此不會計入擊殺小動物的次數。"

-- Map ------------------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "世界地圖"
L.MAP_MODULE_DESC = "在世界地圖上標出你自己的故事：你違背諾言的地點，以及你各章落幕之處。只有你能看見這些標記。"
  .. "你所知的衝突與你選擇的立場，將在日後的版本中標出。"

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "「{title}」：{a}或{b}"
L.MAP_PIN_SIDES_VOWEL = "「{title}」：{a}或{b}"
L.MAP_PIN_OPEN = "你在此尚未選擇立場。"
L.MAP_PIN_ALLIED = "你站在{faction}這一邊。"
L.MAP_PIN_BROKEN = "你站在{faction}這一邊，並曾在此違背諾言 {count} 次。"
L.MAP_PIN_VIOLATION = "你在此違背了諾言"
L.MAP_PIN_CHAPTER = "第 {roman} 章"
L.MAP_PIN_CHAPTER_CLOSED = "於 {date} 在此落幕"
L.MAP_PIN_CHAPTER_COUNT = "在此落幕的章節：{count} 章"

-- Encounters -----------------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "相遇"
L.ENC_MODULE_DESC = "Ashmark 會記住與你組隊的人：你們相遇過幾次、在何處相遇、結果如何。它會在對方的"
  .. "滑鼠提示中加上一行，在「相遇」分頁中列出他們，並保存你對他們的筆記。"
  .. "相識者紀錄與筆記絕不會離開你的用戶端。"

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "相遇：{count} 次 · 上次：{place}"
L.ENC_TOOLTIP_NOPLACE = "相遇：{count} 次"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "你認識{name}：相遇過 {count} 次，上次在{place}。"
L.ENC_RECOGNISE_NOPLACE = "你認識{name}：相遇過 {count} 次。"
L.ENC_RECOGNISE_MORE = "……另外還有 {count} 位你認識的人。"

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "熟面孔"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "你對{name}的筆記："
L.ENC_NOTE_SAVE = "儲存"

-- Encounters tab (6.1)
L.ENC_TAB = "相遇"
L.ENC_TAB_TOTAL = "你遇見過的人：{count} · 熟面孔：{recurring}"
L.ENC_TAB_EMPTY = "你的旅途中還沒有遇見任何人。與他人組隊，Ashmark 便會記住他們。"
L.ENC_TAB_MET = "相遇 {count} 次 · 上次在{place} · {date}"
L.ENC_TAB_MET_NOPLACE = "相遇 {count} 次 · {date}"
L.ENC_TAB_NOTE = "筆記"
L.ENC_TAB_WHO = "{race} {class}"
L.ENC_TAB_FIRST = "初次相遇於 {date}"

-- Chronicle sentences. {people} follows 與 (or precedes 所在的隊伍); its parts are joined with 、 and 和.
L.ENC_LOG_CONTACT = "你初次遇見了{contact}。"
L.ENC_LOG_CONTACT_THEY = "{name}初次遇見了{contact}。"
L.ENC_LOG_TRAVEL = "你與{people}同行。"
L.ENC_LOG_TRAVEL_THEY = "{name}與{people}同行。"
L.ENC_LOG_BOSS = "你與{people}並肩作戰，贏得了勝利。"
L.ENC_LOG_BOSS_THEY = "{name}與{people}並肩作戰，贏得了勝利。"
L.ENC_LOG_WIPE = "你與{people}並肩作戰，卻倒下了。"
L.ENC_LOG_WIPE_THEY = "{name}與{people}並肩作戰，卻倒下了。"
L.ENC_LOG_CAMP = "你與{people}圍坐在同一堆營火旁。"
L.ENC_LOG_CAMP_THEY = "{name}與{people}圍坐在同一堆營火旁。"
L.ENC_LOG_KICK = "你被請出了{people}所在的隊伍。"
L.ENC_LOG_KICK_THEY = "{name}被請出了{people}所在的隊伍。"

-- Parts of {people}
L.ENC_LOG_PEER = "{who}（來自{place}的{archetype}）"
L.ENC_LOG_PEER_NOPLACE = "{who}（{archetype}）"
L.ENC_LOG_OTHER = "另外一人"
L.ENC_LOG_OTHERS = "另外 {count} 人"
L.ENC_LOG_STRANGER = "一位陌生人"
L.ENC_LOG_STRANGERS = "{count} 位陌生人"
L.ENC_LOG_STRANGERS_ANY = "一些陌生人"
L.ENC_LOG_COMPANION = "一位同伴"
L.ENC_LOG_COMPANIONS = "{count} 位同伴"
L.ENC_LIST_SEP = "、"
L.ENC_LIST_AND = "{list}和{last}"
L.ENC_LIST_AND_VOWEL = "{list}和{last}"

-- House ----------------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "家族"
L.HOUSE_MODULE_DESC = "此帳號上姓氏相同的角色組成一個家族。「家族」分頁會顯示家族成員、你的親族所結下的"
  .. "世仇、家族編年史，以及他們認識的人。"

-- /ashmark house (5.9)
L.HOUSE_HELP = "顯示你的家族；「house <名稱>」會加入該名稱的家族，「house reset」會讓家族重新以你的姓氏為準"
L.HOUSE_SLASH_CURRENT = "你屬於{house}家族。"
L.HOUSE_SLASH_NONE = "你不屬於任何家族。輸入 /ashmark house <名稱> 即可加入一個家族。"
L.HOUSE_SLASH_SET = "你現在屬於{house}家族。"
L.HOUSE_SLASH_RESET = "你的家族再次以你的姓氏為準：{house}家族。"
L.HOUSE_SLASH_RESET_NONE = "你的家族再次以你的姓氏為準。沒有姓氏，你便不屬於任何家族。"
L.HOUSE_SLASH_OFF = "「家族」模組已關閉或無法使用，因此現在無法變更你的家族。"

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "家族"
L.HOUSE_TAB_HEADING = "{house}家族"
L.HOUSE_TAB_NO_HOUSE = "無所屬家族"
L.HOUSE_TAB_NONE = "此帳號上姓氏相同的角色組成一個家族。Ashmark 不知道此角色的姓氏："
  .. "輸入 /ashmark house <名稱> 即可選擇一個家族。"
L.HOUSE_TAB_ARCHETYPE = "人物類型：{archetype}"
L.HOUSE_TAB_MEMBERS = "成員"
L.HOUSE_TAB_MEMBER = "{name}，等級 {level}"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "承襲的世仇"
L.HOUSE_TAB_FEUD = "「{title}」：{name}在{zone}站到了{faction}一邊。"
L.HOUSE_TAB_CHRONICLE = "家族編年史"
L.HOUSE_TAB_MEMORY = "家族記憶"
L.HOUSE_TAB_KNOWS = "{sibling}認識{name}。"

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}：等級 {level}"
L.HOUSE_LEGACY_STANDING = "{faction}：{standing}"

-- Campfire -------------------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "營火"
L.CAMP_MODULE_DESC = "在營地休息到增益效果生效，若自上一章以來已發生足夠多的事，Ashmark 便可能在那裡"
  .. "為你的編年史結束一章。"

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "第 {roman} 章落幕 · {place}"

-- Knowledge ------------------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "角色見聞"
L.KNOW_MODULE_DESC = "物品的滑鼠提示只會顯示你的角色所能知道的資訊。從未出現在此角色的背包、銀行或裝備中"
  .. "的物品，只會顯示名稱、綁定方式、裝備欄位、物品等級、類型與需求，其餘內容則保持隱藏。"
  .. "遊戲本身仍會隱藏的物品，則依遊戲原本的方式顯示。"

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "你的角色從未持有過這件物品。"

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "完整顯示任務獎勵"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "永不隱藏任務視窗中獎勵的滑鼠提示，讓你在選擇獎勵時知道它的作用。"

-- Fiction --------------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "共同敘事"
L.FICTION_MODULE_DESC = "同樣使用 Ashmark 的隊伍成員無需在聊天中多說一句，就能得知你的人物類型、出身、"
  .. "側寫分數、伺服器類型與 Ashmark 版本，你也能得知他們的，"
  .. "讓你的編年史與滑鼠提示能說出你曾與誰同行。其他玩家看不到任何內容。"

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "與另一位 Ashmark 使用者組隊，然後再次執行 /ashmark test。"

-- Rumours --------------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "傳聞"
L.RUMOUR_MODULE_DESC = "你在衝突中的作為會化為傳聞，在隊伍之間流傳，你也會聽到他人的所作所為。傳聞只會提及某類人物、"
  .. "一個地點與一個陣營，從不指名道姓；但遊戲會顯示是誰傳出傳聞：你的隊伍能看出哪些傳聞說的是你自己的事蹟，"
  .. "而知道某則傳聞是誰所為的人，也能從你傳出的版本看出你在過去一週內是否曾與那名玩家組隊，或你們之間隔著幾支隊伍。"

-- Chat lines for a rumour heard (7.8). No sex is known: {archetype} follows the neutral 那位 (no _F forms).
L.RUMOUR_HEARD_ALLIANCE = "據說，來自{place}的那位{archetype}已站到了{faction}一邊。"
L.RUMOUR_HEARD_BROKE = "據說，來自{place}的那位{archetype}背棄了{faction}。"
L.RUMOUR_HEARD_TURNED = "據說，來自{place}的那位{archetype}背離了自己的家族，轉而與{faction}站在一起。"
-- Without a faction
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "據說，來自{place}的那位{archetype}已選定了立場。"
L.RUMOUR_HEARD_BROKE_VAGUE = "據說，來自{place}的那位{archetype}違背了諾言。"
L.RUMOUR_HEARD_TURNED_VAGUE = "據說，來自{place}的那位{archetype}背離了自己的家族。"

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "在某場衝突中站到某個陣營一邊，或與另一位 Ashmark 使用者組隊，"
  .. "然後再次執行 /ashmark test。"

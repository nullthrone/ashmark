local _, ns = ...
local L = ns.Locale:For("zhCN")

-- Address form: 你, as Blizzard's zhCN client addresses the player in UI and system text ("你完成了……",
-- "你确定要……吗？"). Game terms follow the zhCN client: 任务, 声望, 阵营, 小队, 队伍, 组队, 等级, 背包, 银行,
-- 鼠标提示, 小动物, 野兽, 中立. Names from the client stand unmarked; quest names always stand before 任务
-- ("{quest}任务"), so CORE_UNKNOWN_QUEST is the determiner 某项 ("某项任务"). Faction names stand in
-- "站到{faction}一边", "在{faction}中的声望" or "{a}或{b}"; CONFLICT_UNNAMED and CORE_UNKNOWN_FACTION fit those
-- frames. {people} is a list joined with 、 and 和. Chinese has no grammatical gender and these strings use no
-- third-person pronoun (其, 自己 instead of 他/她), so this file has no _F forms.

-- Core -----------------------------------------------------------------------------------------------------------

L.CORE_TITLE = "Ashmark"

-- Load safety (4.4)
L.CORE_NOT_FOREVER = "Ashmark仅能在World of Warcraft Forever上运行，在此客户端中将保持关闭。"
L.CORE_SV_NEW = "已开始一份新记录。如果此账号以前使用过Ashmark，说明已保存的数据未能载入："
  .. "请勿再次/reload或登出。请退出游戏，并在下次登录前，于WTF\\Account\\<账号名>\\SavedVariables\\中"
  .. "用Ashmark.lua.bak替换Ashmark.lua。"
L.CORE_SV_NEWER = "这些已保存的数据来自较新版本的Ashmark。在你更新Ashmark之前，它只会读取这些数据。"
L.CORE_SV_RECOVERED = "Ashmark无法识别已保存数据的格式。已开始一份新记录；旧数据原封不动地保存在"
  .. "AshmarkDB.recovered中。"
L.CORE_SV_MIGRATE_FAILED = "Ashmark无法更新其已保存的数据，本次登录期间只会读取这些数据。"

-- Modules and settings (3.2, 4.3)
L.CORE_MODULE_FAILED = "“{module}”模块因反复出错而停止运行，在下次重载界面之前将保持关闭。"
L.CORE_UNAVAILABLE = "需要：{capability}"
L.CORE_UNAVAILABLE_CLIENT = "此客户端缺少该模块所需的功能。"
L.CORE_MISSING_EVENTS = "此客户端缺少的事件：{events}"
L.CORE_SETTING_CHAT_LINES = "聊天消息"
L.CORE_SETTING_CHAT_LINES_DESC = "允许Ashmark在聊天窗口中写下简短的文字。"
L.CORE_SETTING_SOUNDS = "音效"
L.CORE_SETTING_SOUNDS_DESC = "Ashmark会播放游戏自带的翻页声和书本音效。"
L.CORE_SETTING_SHARE = "与其他Ashmark用户共享"
L.CORE_SETTING_SHARE_DESC = "将你的人物类型、出身、侧写分数（守信、栖所、仁慈）、服务器类型、"
  .. "Ashmark版本和传闻发送给同样使用Ashmark的队友。"
  .. "相识记录和备注绝不会离开你的客户端。"

-- Shared vocabulary (5.8). Every frame writes "{quest}任务", so the quest fallback is a determiner.
L.CORE_UNKNOWN_QUEST = "某项"
L.CORE_UNKNOWN_ITEM = "某件物品"
L.CORE_UNKNOWN_FACTION = "某个阵营"
L.CORE_UNKNOWN_PLACE = "某地"
L.CORE_UNKNOWN_PLAYER = "某人"
L.CORE_UNKNOWN_CLASS = "冒险者"
L.CORE_UNKNOWN_RACE = "未知种族"
L.CORE_RULESET_NORMAL = "普通"
L.CORE_RULESET_PVP = "PvP"
L.CORE_RULESET_RP = "角色扮演"
L.CORE_RULESET_RPPVP = "角色扮演PvP"
L.CORE_RULESET_HARDCORE = "专家模式"

-- Chronicle sentences
L.CORE_LOG_TURNIN = "你完成了{quest}任务。"
L.CORE_LOG_TURNIN_THEY = "{name}完成了{quest}任务。"
L.CORE_LOG_ABANDON = "你放弃了{quest}任务。"
L.CORE_LOG_ABANDON_THEY = "{name}放弃了{quest}任务。"
L.CORE_LOG_ZONE_FIRST = "你首次踏足{zone}。"
L.CORE_LOG_ZONE_FIRST_THEY = "{name}首次踏足{zone}。"
L.CORE_LOG_LEVEL = "你达到了{level}级。"
L.CORE_LOG_LEVEL_THEY = "{name}达到了{level}级。"
L.CORE_LOG_DEATH = "你在{place}死去。"
L.CORE_LOG_DEATH_THEY = "{name}在{place}死去。"
L.CORE_LOG_REP = "你在{faction}中的声望现为{standing}。"
L.CORE_LOG_REP_THEY = "{name}在{faction}中的声望现为{standing}。"
L.CORE_LOG_CHAPTER = "第{roman}章在{place}落幕。"
L.CORE_LOG_CHAPTER_THEY = "{name}的第{roman}章在{place}落幕。"
L.CORE_LOG_DEATH_NOZONE = "你在{place}死去。"
L.CORE_LOG_DEATH_NOZONE_THEY = "{name}在{place}死去。"
L.CORE_LOG_CHAPTER_NOZONE = "第{roman}章在{place}落幕。"
L.CORE_LOG_CHAPTER_NOZONE_THEY = "{name}的第{roman}章在{place}落幕。"

-- Slash commands (5.9). Help texts are short verb phrases, as in a command list.
L.CORE_HELP_HEADER = "命令："
L.CORE_HELP_TOGGLE = "打开或关闭编年史"
L.CORE_HELP_HELP = "列出这些命令"
L.CORE_HELP_DEBUG = "在本次登录期间开启或关闭调试输出"
L.CORE_HELP_RESET = "清除此角色的记录；“reset others”清除相识记录、其他用户资料和听到的传闻；“reset <名称>”"
  .. "忘记此账号的另一个角色"
L.CORE_UNKNOWN_COMMAND = "未知命令：{command}"
L.CORE_DEBUG_ON = "本次登录期间已开启调试输出。"
L.CORE_DEBUG_OFF = "调试输出已关闭。"
L.CORE_RESET_CONFIRM = "要清除Ashmark为此角色记录的所有内容吗？此操作无法撤销。"
L.CORE_RESET_OTHERS_CONFIRM = "要清除此账号上的所有相识记录、其他用户资料和听到的传闻吗？你自己的传闻"
  .. "将会保留。此操作无法撤销。"
L.CORE_RESET_ACCEPT = "清除"
L.CORE_CANCEL = "取消"
L.CORE_RESET_DONE = "此角色的记录已清除。"
L.CORE_RESET_OTHERS_DONE = "相识记录、其他用户资料和听到的传闻已清除。"
L.CORE_RESET_READONLY = "已保存的数据来自较新版本的Ashmark，因此无法清除任何内容。"
L.CORE_RESET_CHAR_UNKNOWN = "此账号没有保存其他名为{name}的角色。"
L.CORE_RESET_CHAR_AMBIGUOUS = "有多个角色名为{name}。请用其中一个角色的GUID输入/ashmark reset <GUID>："
L.CORE_RESET_CHAR_LINE = "{name}，{level}级：{guid}"
L.CORE_RESET_CHAR_CONFIRM = "要忘记{name}吗？Ashmark将删除此角色的编年史、抉择、人物侧写和相遇记录。"
  .. "请仅对你已删除或已转移的角色执行此操作。"
L.CORE_RESET_CHAR_DONE = "已忘记{name}。"

-- UI shell (6.1, 6.2)
L.CORE_TAB_CHRONICLE = "编年史"
L.CORE_CHRONICLE_CHAPTER = "第{roman}章"
L.CORE_CHRONICLE_CHAPTER_OPEN = "第{roman}章（当前）"
L.CORE_CHRONICLE_CLOSED = "落幕于{date} · {place}"
L.CORE_CHRONICLE_BEGUN = "始于{date} · 尚在书写"
L.CORE_CHRONICLE_OPEN = "尚在书写"
L.CORE_CHRONICLE_EMPTY = "本章尚无值得讲述之事。"
L.CORE_CHRONICLE_NO_RECORD = "Ashmark尚未为此角色留下任何记录。"
L.CORE_COMPARTMENT_CLICK = "点击以打开或关闭编年史。"
L.CORE_COMPARTMENT_RIGHT_CLICK = "右键点击以打开设置。"

-- Test -----------------------------------------------------------------------------------------------------------

L.TEST_HELP = "在此客户端上运行自检并截图"
L.TEST_HELP_PROBE = "为开发者记录此客户端的原始信息"
L.TEST_NOT_IN_COMBAT = "战斗中无法运行测试。请在战斗结束后重试。"
L.TEST_SUMMARY = "测试完成：{passed}项通过，{failed}项失败，{skipped}项跳过。"
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "通过"
L.TEST_FAIL = "失败"
L.TEST_SKIP = "跳过"
L.TEST_OPEN_QUEST_DIALOG = "截图前请先与一位任务发布者对话。"
L.TEST_RELOAD = "输入/reload以保存结果。"
L.TEST_NOT_STORED = "已保存的数据来自较新版本的Ashmark，因此不会保存任何内容。完整报告如下。"
L.TEST_NOT_STORED_MIGRATION = "Ashmark无法更新其已保存的数据，因此不会保存任何内容。完整报告如下。"
L.TEST_LATE = "后续结果：{what}"
L.TEST_PROBE_DONE = "探测共记录了{count}条信息。"
L.TEST_PROBE_NEXT = "请在本次登录期间接受一个任务并发起一场战斗：探测会将两者都记录下来。"

-- Conflicts ------------------------------------------------------------------------------------------------------

L.CONFLICT_MODULE_NAME = "纷争"
L.CONFLICT_MODULE_DESC = "有些任务会让两方势力彼此对立。Ashmark会记住你所选择的一方，在任务窗口下方"
  .. "标出与之相悖的任务，并在你食言时记录下来。"

-- A side without a reputation faction; stands where a faction name would ("站到{faction}一边", "{a}或{b}").
L.CONFLICT_UNNAMED = "无旗之众"

-- Quest-dialog line (7.1)
L.CONFLICT_CONTRADICTS = "违背你与{faction}的盟约。"
L.CONFLICT_CONTRADICTS_NOFACTION = "违背你所选择的立场。"
L.CONFLICT_HOUSE_STANDS_AGAINST = "你所属的{house}家族与{faction}对立。"
L.CONFLICT_TEST_DIALOG = "Ashmark在任务窗口下方的提示文字会显示在这里。"

-- Chronicle sentences
L.CONFLICT_ALLIED = "你在{zone}站到了{faction}一边（{title}任务）。"
L.CONFLICT_ALLIED_THEY = "{name}在{zone}站到了{faction}一边（{title}任务）。"
L.CONFLICT_ALLIED_REP = "你在{faction}中的声望决定了你在{zone}的立场。"
L.CONFLICT_ALLIED_REP_THEY = "{name}在{faction}中的声望决定了其在{zone}的立场。"
L.CONFLICT_BROKE_WORD = "你背弃了{broken}，为{faction}完成了{quest}任务。"
L.CONFLICT_BROKE_WORD_THEY = "{name}背弃了{broken}，为{faction}完成了{quest}任务。"
L.CONFLICT_SWITCHED = "你再次改换了立场：为{faction}完成{quest}任务，将{broken}抛在身后。"
L.CONFLICT_SWITCHED_THEY = "{name}再次改换了立场：为{faction}完成{quest}任务，将{broken}抛在身后。"
L.CONFLICT_HOUSETURN = "你背离了{house}家族，在{zone}站到了{faction}一边。"
L.CONFLICT_HOUSETURN_THEY = "{name}背离了{house}家族，在{zone}站到了{faction}一边。"

-- Decisions tab (6.1)
L.CONFLICT_TAB = "抉择"
L.CONFLICT_TAB_SIDES = "{title}任务：{a}或{b}"
L.CONFLICT_TAB_SIDES_VOWEL = "{title}任务：{a}或{b}"
L.CONFLICT_TAB_ALLIED = "自{date}起站在{faction}一边"
L.CONFLICT_TAB_OPEN = "未定"
L.CONFLICT_TAB_BROKEN = "食言{count}次"
L.CONFLICT_TAB_VIOLATIONS = "食言次数：{count}"
L.CONFLICT_TAB_NO_VIOLATIONS = "你从未食言。"
L.CONFLICT_TAB_EMPTY = "Ashmark尚不知晓这个世界中的任何纷争。"

-- Profile --------------------------------------------------------------------------------------------------------

L.PROFILE_MODULE_NAME = "人物侧写"
L.PROFILE_MODULE_DESC = "Ashmark会从你的所作所为中解读你的角色：你是否信守诺言，是栖身荒野还是城镇，"
  .. "以及你如何对待无害的生物。"

-- Archetypes (7.2): nouns used as labels and epithets ("{who}（来自{place}的{archetype}）"). Chinese has no
-- gender, so no _F.
L.PROFILE_OATHKEEPER = "守誓者"
L.PROFILE_OPPORTUNIST = "投机者"
L.PROFILE_WANDERER = "流浪者"
L.PROFILE_TOWNSFOLK = "城镇居民"
L.PROFILE_GENTLE = "仁慈之人"
L.PROFILE_RUTHLESS = "冷酷之人"
L.PROFILE_PRAGMATIST = "务实者"

-- Test mode (7.10)
L.PROFILE_TEST_MERCY_HOWTO = "击杀3只小动物和3只未处于战斗状态的中立野兽，然后再次输入/ashmark test。"
L.PROFILE_TEST_CRITTER_TARGET = "将任意生物选为目标，然后再次输入/ashmark test。"
L.PROFILE_TEST_CRITTER_OFF = "此客户端无法识别小动物，因此不会统计击杀小动物的次数。"

-- Map ------------------------------------------------------------------------------------------------------------

L.MAP_MODULE_NAME = "世界地图"
L.MAP_MODULE_DESC = "在世界地图上标出你自己的故事：你食言之处，以及你的各个章节落幕之地。这些标记只有你能看到。"
  .. "你所知的纷争与你选择的立场将在以后的版本中标出。"

-- Pin tooltips (7.3)
L.MAP_PIN_SIDES = "{title}任务：{a}或{b}"
L.MAP_PIN_SIDES_VOWEL = "{title}任务：{a}或{b}"
L.MAP_PIN_OPEN = "你在此地尚未选择立场。"
L.MAP_PIN_ALLIED = "你站在{faction}一边。"
L.MAP_PIN_BROKEN = "你站在{faction}一边，并曾在此食言{count}次。"
L.MAP_PIN_VIOLATION = "你在此食言"
L.MAP_PIN_CHAPTER = "第{roman}章"
L.MAP_PIN_CHAPTER_CLOSED = "于{date}在此落幕"
L.MAP_PIN_CHAPTER_COUNT = "在此落幕的章节：{count}章"

-- Encounters -----------------------------------------------------------------------------------------------------

L.ENC_MODULE_NAME = "相遇"
L.ENC_MODULE_DESC = "Ashmark会记住与你组队的人：你们相遇的次数、地点以及经过。它会在对方的鼠标提示中"
  .. "添加一行，在“相遇”标签页中列出他们，并保存你对他们的备注。相识记录和备注绝不会离开你的客户端。"

-- Unit tooltip (7.4)
L.ENC_TOOLTIP = "相遇：{count}次 · 上次在{place}"
L.ENC_TOOLTIP_NOPLACE = "相遇：{count}次"
L.ENC_TOOLTIP_PEER = "{archetype}"

-- Chat line when people you know join your group
L.ENC_RECOGNISE = "你认识{name}：已相遇{count}次，上次在{place}。"
L.ENC_RECOGNISE_NOPLACE = "你认识{name}：已相遇{count}次。"
L.ENC_RECOGNISE_MORE = "……另有{count}位你认识的人。"

-- Marker for someone this character has met at least three times
L.ENC_RECURRING = "熟面孔"

-- Note editor (6.2)
L.ENC_NOTE_PROMPT = "你对{name}的备注："
L.ENC_NOTE_SAVE = "保存"

-- Encounters tab (6.1)
L.ENC_TAB = "相遇"
L.ENC_TAB_TOTAL = "你遇见过的人：{count} · 熟面孔：{recurring}"
L.ENC_TAB_EMPTY = "还没有人与你相逢。与他人组队，Ashmark便会记住对方。"
L.ENC_TAB_MET = "相遇{count}次 · 上次在{place} · {date}"
L.ENC_TAB_MET_NOPLACE = "相遇{count}次 · {date}"
L.ENC_TAB_NOTE = "备注"
L.ENC_TAB_WHO = "{race} {class}"
L.ENC_TAB_FIRST = "初次相遇：{date}"

-- Chronicle sentences. {people} stands after 与 or before 的队伍.
L.ENC_LOG_CONTACT = "你初次遇见了{contact}。"
L.ENC_LOG_CONTACT_THEY = "{name}初次遇见了{contact}。"
L.ENC_LOG_TRAVEL = "你与{people}结伴同行。"
L.ENC_LOG_TRAVEL_THEY = "{name}与{people}结伴同行。"
L.ENC_LOG_BOSS = "你与{people}并肩作战，赢得了胜利。"
L.ENC_LOG_BOSS_THEY = "{name}与{people}并肩作战，赢得了胜利。"
L.ENC_LOG_WIPE = "你与{people}并肩作战，最终倒下。"
L.ENC_LOG_WIPE_THEY = "{name}与{people}并肩作战，最终倒下。"
L.ENC_LOG_CAMP = "你与{people}围坐在同一堆篝火旁。"
L.ENC_LOG_CAMP_THEY = "{name}与{people}围坐在同一堆篝火旁。"
L.ENC_LOG_KICK = "你被请出了{people}的队伍。"
L.ENC_LOG_KICK_THEY = "{name}被请出了{people}的队伍。"

-- Parts of {people}, as Chinese writes "塔伦（来自西部荒野的守誓者）、米拉和另外2人".
L.ENC_LOG_PEER = "{who}（来自{place}的{archetype}）"
L.ENC_LOG_PEER_NOPLACE = "{who}（{archetype}）"
L.ENC_LOG_OTHER = "另外一人"
L.ENC_LOG_OTHERS = "另外{count}人"
L.ENC_LOG_STRANGER = "一位陌生人"
L.ENC_LOG_STRANGERS = "{count}位陌生人"
L.ENC_LOG_STRANGERS_ANY = "一些陌生人"
L.ENC_LOG_COMPANION = "一位同伴"
L.ENC_LOG_COMPANIONS = "{count}位同伴"
L.ENC_LIST_SEP = "、"
L.ENC_LIST_AND = "{list}和{last}"
L.ENC_LIST_AND_VOWEL = "{list}和{last}"

-- House ----------------------------------------------------------------------------------------------------------

L.HOUSE_MODULE_NAME = "家族"
L.HOUSE_MODULE_DESC = "此账号上姓氏相同的角色组成一个家族。“家族”标签页会显示家族成员、亲族结下的世仇、"
  .. "家族编年史，以及他们认识的人。"

-- /ashmark house (5.9)
L.HOUSE_HELP = "显示你的家族；“house <名称>”加入该名称的家族，“house reset”重新以你的姓氏为准"
L.HOUSE_SLASH_CURRENT = "你属于{house}家族。"
L.HOUSE_SLASH_NONE = "你不属于任何家族。输入/ashmark house <名称>以加入一个家族。"
L.HOUSE_SLASH_SET = "你现在属于{house}家族。"
L.HOUSE_SLASH_RESET = "你的家族重新以你的姓氏为准：{house}家族。"
L.HOUSE_SLASH_RESET_NONE = "你的家族重新以你的姓氏为准。由于你没有姓氏，你不属于任何家族。"
L.HOUSE_SLASH_OFF = "“家族”模块已关闭或不可用，因此现在无法更改你的家族。"

-- House tab (6.1, 7.5)
L.HOUSE_TAB = "家族"
L.HOUSE_TAB_HEADING = "{house}家族"
L.HOUSE_TAB_NO_HOUSE = "无家族"
L.HOUSE_TAB_NONE = "此账号上姓氏相同的角色组成一个家族。Ashmark不知道此角色的姓氏：输入/ashmark house "
  .. "<名称>以选择一个家族。"
L.HOUSE_TAB_ARCHETYPE = "人物类型：{archetype}"
L.HOUSE_TAB_MEMBERS = "成员"
L.HOUSE_TAB_MEMBER = "{name}，{level}级"
L.HOUSE_TAB_MEMBER_RULESET = "{member} · {ruleset}"
L.HOUSE_TAB_FEUDS = "世仇"
L.HOUSE_TAB_FEUD = "{title}任务：{name}在{zone}站到了{faction}一边。"
L.HOUSE_TAB_CHRONICLE = "家族编年史"
L.HOUSE_TAB_MEMORY = "家族记忆"
L.HOUSE_TAB_KNOWS = "{sibling}认识{name}。"

-- The account's Legacy (7.5)
L.HOUSE_LEGACY_LEVEL = "{faction}：{level}级"
L.HOUSE_LEGACY_STANDING = "{faction}：{standing}"

-- Campfire -------------------------------------------------------------------------------------------------------

L.CAMP_MODULE_NAME = "篝火"
L.CAMP_MODULE_DESC = "在营地休息，直到营地的增益效果生效；若自上一章以来已发生了足够多的事，Ashmark"
  .. "可能会让你编年史中的一章在那里落幕。"

-- Centre-screen notice (7.6)
L.CAMP_CHAPTER_CLOSED = "第{roman}章落幕 · {place}"

-- Knowledge ------------------------------------------------------------------------------------------------------

L.KNOW_MODULE_NAME = "角色认知"
L.KNOW_MODULE_DESC = "物品的鼠标提示只显示你的角色能够知道的信息。从未进入过此角色背包、银行或装备栏的物品，"
  .. "只显示其名称、绑定类型、装备部位、物品等级、类型和需求，其余信息均会隐藏。游戏本身仍会隐藏信息的物品，"
  .. "则保持游戏原本的显示方式。"

-- Last line of such a tooltip (7.7)
L.KNOW_UNKNOWN = "你的角色从未持有过此物。"

-- Setting (4.3)
L.KNOW_SETTING_QUEST_REWARDS = "完整显示任务奖励"
L.KNOW_SETTING_QUEST_REWARDS_DESC = "从不隐藏任务窗口中所列奖励的鼠标提示，以便你了解其效果后再选择奖励。"

-- Fiction --------------------------------------------------------------------------------------------------------

L.FICTION_MODULE_NAME = "共享叙事"
L.FICTION_MODULE_DESC = "同样使用Ashmark的小队成员无需在聊天中多说一句，就能得知你的人物类型、出身、"
  .. "侧写分数、服务器类型和Ashmark版本，你也能得知他们的，"
  .. "因此你的编年史和鼠标提示能讲述你曾与谁同行。其他玩家不会看到任何内容。"

-- Test mode (7.10)
L.FICTION_TEST_HOWTO = "与另一位Ashmark用户组队，然后再次输入/ashmark test。"

-- Rumours --------------------------------------------------------------------------------------------------------

L.RUMOUR_MODULE_NAME = "传闻"
L.RUMOUR_MODULE_DESC = "你在纷争中的所作所为会化作传闻，在一支支队伍间流传，你也会听闻他人的作为。"
  .. "传闻只提及某类人物、某个地点和某个阵营，从不指名道姓；但游戏会显示是谁传出了传闻："
  .. "你的小队能看出哪些传闻讲的是你自己的事迹，而知道某则传闻是谁所为的人，"
  .. "也能从你传出的版本看出你在过去一周内是否与那名玩家组过队，或者你们之间隔着几支队伍。"

-- Chat lines for a rumour heard (7.8). No sex is known and Chinese needs none: {archetype} stands as a bare
-- epithet in "来自{place}的{archetype}", and the sentences use 自己, never 他/她 (no _F forms).
L.RUMOUR_HEARD_ALLIANCE = "有传言说，来自{place}的{archetype}已站到{faction}一边。"
L.RUMOUR_HEARD_BROKE = "有传言说，来自{place}的{archetype}背弃了{faction}。"
L.RUMOUR_HEARD_TURNED = "有传言说，来自{place}的{archetype}背离了自己的家族，转而站到{faction}一边。"

-- Without a faction
L.RUMOUR_HEARD_ALLIANCE_VAGUE = "有传言说，来自{place}的{archetype}已选定立场。"
L.RUMOUR_HEARD_BROKE_VAGUE = "有传言说，来自{place}的{archetype}食言了。"
L.RUMOUR_HEARD_TURNED_VAGUE = "有传言说，来自{place}的{archetype}背离了自己的家族。"

-- Test mode (7.10)
L.RUMOUR_TEST_HOWTO = "在一场纷争中站到某个阵营一边，或与另一位Ashmark用户组队，然后再次输入/ashmark test。"

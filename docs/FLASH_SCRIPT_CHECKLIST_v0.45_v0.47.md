# 闪翼 0.45—0.47 原 RM 脚本迁移清单

2026-10-12，按用户要求，仅匹配黎之闪翼（开发中）。本文件是下一阶段的任务和验收清单，未勾选项目不表示已经实现。

0.43—0.44实际已生成单元、已接通事件和局部服务适配见[既有实现清单](FLASH_SCRIPT_CHECKLIST_v0.43_v0.44.md)。该清单同时记录0.44尚未恢复的Global血瓶/宝石ID表逐项赋值，后续纳入45-01补迁。

2026-10-12最新执行范围：**特殊BOSS战不迁移**；普通地图战斗仍迁移。**半成品地图系统迁移已有实现**，包括发现/区域/连接/布局/预览/换图记录及其保存，不补写尚未设计的玩法。用户已授权按0.45→0.46→0.47顺序实施。

0.45的阶段方法已实现，源码对应、原事件证据及跨版本边界见[0.45说明](SCRIPT_MIGRATION_v0.45.md)。下方勾选仅表示0.45表内的方法职责，不能视为同名原脚本全部完成；正式输出检查见[验证记录](../tests/VERIFICATION_v0.45.md)。0.46/0.47继续原顺序。源码错误按用户选择“修正明显错误，保留原公式”处理并登记来源。

## 核对依据与完成标准

- 原工程：`D:/Dev/Godot_Trans/rm_template/魔塔样板7630·改`；标题为“黎之闪翼（开发中）”。实际输入为 `Data/Scripts.rxdata`，编号是该文件中的 **1 起始加载序号**，不是内部 script_id。
- 已直接只读解包当前原 `Scripts.rxdata`，339 个脚本槽位的名称、顺序和源码均与 0.44 正式输出中的 `legacy/ordered_scripts` 一致；原 Ruby 未执行。源文件 SHA256：`22763e029aa1b52a96ac24355909e3daf4a5c9c23940ae1c36cfbff2fe6233cf`。
- 339 个槽位中，0.44 盘点识别 241 个含执行内容的脚本，98 个空项、分组项或整段注释项。241 是源码盘点数量，不能当作已迁移数量，也不代表每项都已证明在游戏中可达。
- 展开的 `Scripts/*.rb` 是镜像。0150、0152、0153、0154、0155、0191 六项与实际加载源码不同；迁移和验收以 rxdata 版本为准。
- 全部槽位、原名、内部 ID、来源 SHA256、版本任务和 0.44 生成状态见同目录 `FLASH_SCRIPT_CHECKLIST_v0.45_v0.47.json`。本文附录提供 241 项逐脚本定位；主表按功能拆分同一脚本，避免用“整个文件已迁移”掩盖尚未完成的方法。
- 现有通用事件、菜单、数据和存档能力可以复用；仍需核对闪翼对同名类的重开、覆盖和 alias。原生能力存在不等于闪翼定制行为已迁移。
- 每项完成必须登记实际 GDScript 路径、对应类/方法、调用入口和行为验证；数据初始化可对应 JSON，需说明后续编辑入口。尚未接通的运行逻辑不能只用注释、空函数或保留 Ruby 代替。
- 0.45/0.46 所需的语法、动态分派、键盘、绘图等依赖，必须在使用它的版本接通；0.47 收尾剩余能力和持久化，不应成为前两版无法运行的理由。

## 0.45：玩法计算、效果和结算

此版负责可执行的玩法逻辑。图形表现由 0.46 接入，完整对象关系持久化由 0.47 接入；同一运行状态在三版持续扩展。

| 任务 | 原 RM 脚本（加载序号） | 需要迁移/核对的内容与验收结果 |
| --- | --- | --- |
| [x] 45-01 基础语义与绑定 | 0003 `Global`、0005 `Universal_Bind`、0006 `全局定义`、0018 `Object`、0019 `Array`、0021 `Numeric`、0024 `Hash`、0034 `RPG追加`、0037 `DataBase`、0040 `->Sotrage`、0315 `Utils` | 玩法实际调用的集合/数值扩展、常量、`_main_actor/_support_actors/_this` 等绑定，数据库运行时同步及几何/查事件工具。保持加载顺序；数值、类型和 Ruby 真值正确。系统 API、绘图和持久化部分另见后续版本。 |
| [x] 45-02 物品与装备对象 | 0053 `Game_Object`、0054 `Game_Item`、0055 `Game_Weapon`、0056 `Game_Armor`、0057 `Game_Ornament`、0086 `Game_Equipment` | 在 0.44 数据导入基础上接通实际对象访问、默认值、物品使用限制、饰品、装备增幅与抗性；动态对象类型选择形成显式分派。 |
| [x] 45-03 角色/怪物属性与状态 | 0065—0067 `Game_Battler 1—3`、0068—0069 `Game_Actor 1—2`、0070—0071 `Game_Enemy 1—2`、0085 `Game_Actors` | `maxhp/maxsp/patk/pdef/matk/mdef/agi/int/resist` 及写入规则、派生参数、状态增删、周期伤害、角色装备/技能槽、敌人技能和掉落字段；原始扩展字段不再仅供展示。 |
| [x] 45-04 技能预设与旧接口核对 | 0060 `->Sotrage`、0061 `->Storage(技能文本)`、0062 `Skill 1`、0064 `Skill 3` | 经验表、技能参数、文本描述与仍被调用的 `Skill` 接口。新普通战斗以 0072/0073 的实际覆盖为准；旧接口若被事件调用必须有实现，若无调用需登记依据。 |
| [x] 45-05 当前普通战斗 | 0072 `BattleSystem`、0073 `SkillRegistry` | 技能注册 DSL、`AttributeCalculator`、`StateContainer`、`Timeline`、`TargetResolver`、`FollowUpResolver`、`Simulator`；主战/援护、连击/反击/追击、被动、狂暴、敌人耐心、退出结果、预估伤害和缓存失效。按照当前源码的运算与阶段顺序验证，不依据注释自行新增效果。 |
| [x] 45-06 普通战斗结算与队伍 | 0072 `BattleSystem` 的 `PartyRoles/EventSettlement`、0078 `▲Game_Party`、0096 `Game_Event` 的 `dead?/die/refresh_damage` | `begin_battle!/pending_battle_result/finish_battle!` 与公共事件衔接；扣血、战斗不能、角色接替、休息恢复、经验/金币奖励和事件死亡标记。成功结算一次，失败不产生部分奖励。0.44 货币接口复用并检查一致性。 |
| [x] 45-07 地图怪物效果 | 0079 `Game_Troop`、0087 `Game_Troops`、0098 `Game_Player 2`、0104 `Game_Map 2`，配合 0096 `Game_Event` | 楼层怪物实例接上完整 `Game_Enemy`；潜伏、领域、夹击、退敌、中毒等效果与 `refresh_damage`。0.44 查询/覆盖记录复用；这些类按闪翼地图用途迁移。 |
| [x] 45-08 地图物品效果 | 0052 `->Sotrage`、0193 `药品库`、0263 `★Item caculator`，配合 0041 `Game_Temp`、0043 `Game_System 2` | `Storage.use_item`、破墙/破冰/冰冻/地震/对称飞行/大黄门钥匙/炸弹/圣锤/药水/宝石/解状态/上下楼/随意门等原有分派；`Item.Recover`、`Item_calc.cal_item`、事件页修改及扣物品。源代码的未设计分支单列，不虚构效果。 |
| [x] 45-09 角色初始化与成长 | 0317 `Actor_Init`、0318 `Level_Up`、0060 `->Sotrage`，配合 0068 `Game_Actor 1`、0078 `▲Game_Party` | 接通 `Actor_Init.load` 的真实状态写入、`Level_Up.level_up`、经验和升级判定；以公共事件实际调用校验等级/属性变化及消息请求。 |
| [x] 45-10 结晶回路 | 0088 `Game_Blastics`、0212 `->Storage(结晶回路追加定义)`、0213 `->Storage`、0214 `Game_Blastic`，配合 0068 `Game_Actor 1` | 结晶预设、孔位/限制/锁、`unlock/equip_crystal/cancel_crystal`、元素累计、回响及角色属性关联。0215—0221 的显示归 0.46；背包交换与装备操作必须同步。 |
| 用户排除：45-11 自定义 BOSS 战逻辑 | 0275 `■Skill追加`、0277 `ObservableBattler`（含 `DataBus`）、0282 `Game_BossBattle_Data`、0283 `■■Temp_Battler`、0284 `Game_Boss_Battler`、0285 `Game_Boss_Actor`、0286 `Game_Boss_Enemy`、0287 `Game_Boss_Tactical`、0288 `Battle_Calculator`、0306 `Battle_Manager` | BOSS 属性/BUFF、BP/Boost、行动延迟、阵型、技能段数/次数、伤害与目标预处理、管理器状态机及事件通知。计算和命令逻辑从精灵/窗口操作中分出；这是特殊BOSS战，已按最新用户要求排除；此行保留原匹配记录。源实现中的参数和未完成方法疑点先记录，不能生成假成功。 |
| [x] 45-12 场景中的业务操作 | 0200 `▲Scene_Map 1`、0202 `▲Scene_Map 3`、0254 `★Scene_Flytofloor`、0255 `★Scene_CP`、0256 `▲Scene_Item`、0257 `Scene_Skill`、0258 `▲Scene_Equip`、0259 `Scene_Shop_new` | 将切换主战/援护、使用物品、技能配置、回路背包交换、装备/商店交易接到同一服务。0.45 验证事务和结果；窗口、输入和场景生命周期归 0.46。闪翼属性商店若通过事件脚本实现，按原事件逐项接入，不假定存在某个商店脚本。 |
| [x] 45-13 公共事件与地图脚本闭环 | 公共事件 1 `战斗`、2 `加减血`、3 `加减攻防`、4 `开门`、6 `路障处理`、7 `箱子处理`、9 `使用物品处理`、11 `获得物品`、12 `结局判定`、13 `事件结束的处理`、14 `升级判定`、17 `每层的并行处理内容`、21 `★初始化★`、23 `事件名驱动`，以及调用这些功能的地图脚本 | 从原事件恢复 355/655、111 和路线45的真实源码与上下文；正则捕获和可分析的事件名表达式需在本版接通。核对公共事件1扣血/奖励、14升级、23怪物/宝石等分派；普通原生事件仍复用现有执行器。 |
| [x] 45-14 历史战斗代码审计 | 0075 `Battle_Data`、0076 `Delay_Ctrl`、公共事件36 `战斗(以前的版本)`，配合 0062/0064 | 0075/0076 源注释明确为旧数据/调度器留档；公共事件36仍保留旧 `battle_data` 访问。分别核对静态调用、动态入口和编辑器可调用性，登记“仍需兼容”或“历史留档”的证据；不能按文件名直接删除，也不能把旧类当作新普通战斗核心。 |

0.45 验收重点：在相同输入状态下，属性、伤害预估、结算、奖励、物品效果、成长和回路操作符合原实现；业务操作使用生成工程的实际状态与事件入口。特殊BOSS战按最新用户指示排除。

## 0.46：自定义页面、绘图与地图表现

此版把 0.45 的业务功能接到闪翼实际界面，并迁移窗口、输入、表现和更新机制。表中基础类已有 Godot 对应实现的部分仍需检查闪翼覆盖。

| 任务 | 原 RM 脚本（加载序号） | 需要迁移/核对的内容与验收结果 |
| --- | --- | --- |
| [x] 46-01 绘图与资源基础 | 0009 `Sotrage`、0022 `Color`、0023 `Bitmap`、0025 `RPG::Cache`、0026 `Tilemap`、0027 `Bitmap绘图追加`、0030 `Shape`、0031 `Hexagon`、0032 `Graphics`、0034 `RPG追加`；配合 0012 `[]TKTK_Bitmap` | 颜色/图形、文字、边框/渐变/H8面板、技能卡框、图标/头像缓存、地图遮罩、截图和过渡。实际页面依赖的插件效果需在本版实现；其余原生内存调用收尾归 0.47。 |
| [x] 46-02 系统与地图对象覆盖 | 0041 `Game_Temp`、0042 `Game_System 1`、0043 `Game_System 2`、0044 `Game_Screen`、0045 `Game_Picture`、0048 `Sprite_Picture`、0049 `Sprite_Timer`、0091 `->Sotrage`、0092 `Game_CommonEvent`、0093—0095 `Game_Character 1—3`、0096 `Game_Event`、0097—0098 `Game_Player 1—2`、0099 `▲Sprite_Character`、0102 `->Sotrage`、0103—0104 `Game_Map 1—2`、0105 `Spriteset_Map`、0108 `Game_Floor`、0109 `Game_Region` | 闪翼扩展的图块/事件修改、地图遮罩、人物显示、移动/奔跑/碰撞、楼层链接/区域切换、屏幕和音频调用。已有原生能力复用；地图伤害归 0.45，运行修改的保存归 0.47。 |
| [x] 46-03 基础窗口和旧入口 | 0111 `▲Window_Base`、0112 `Window_Selectable`、0113 `Window_Command`、0114 `Window_Help`；0116—0136 中实际有内容的物品/飞行器/CP/技能/目标/装备/状态/存档/商店/姓名/数字/消息/调试窗口 | 具名窗口、选中/滚动/帮助、HUD、布局、颜色、显示/隐藏和输入。相同类在后续脚本被重开时按最终加载关系处理；旧存档窗口仅迁移新工程需要的展示职责，不读取 RM 旧存档。 |
| [x] 46-04 标题、设置、音乐和成就 | 0139 `▲Scene_Title`、0140 `Window_BackGround`、0141 `Window_Mode`、0142 `Window_Title`、0143 `Window_Config`、0144 `Window_Music`、0145 `Window_Merit`、0046 `Game_Config`、0047 `Game_Music`、0265 `■Window_Version` | 标题子页面、模式/继续游戏、设置、音量、显示模式、音乐室、成就；输入、返回和动效正确。设置与解锁数据的跨启动持久化归 0.47；本版所需窗口缩放必须已能在 Godot 使用。 |
| [x] 46-05 自定义消息系统 | 0148 `->Storage`、0149—0150 `Message 1—2`、0151 `Message::TextRow`、0152—0153 `Message::TextBox 1—2`、0154—0155 `Message::HintBox 1—2`、0156 `Message::Words`、0157 `Message_Memory`、0191 `Message_Controller`、0270 `■GPRA_TextStream` | 文本码、字体/宽度与分页、名字/头像、阻塞对话与非阻塞提示、选择/数字输入联动、历史文本、文件文本读取和事件等待。使用已核对的 rxdata 版本，不套用六项不同镜像中的时钟机制。 |
| [x] 46-06 解释器定制与等待 | 0005 `Universal_Bind`、0159—0165 `Interpreter 1—7`，配合 0191 `Message_Controller` | 保留已接入的原生指令和 0.43 脚本入口；补齐闪翼调用绑定、返回值/等待、消息、场景和自定义 API。原生回合制战斗指令与原生战斗事件按既定范围排除；解释器中的其他方法逐项核对。 |
| [x] 46-07 地图菜单、HUD与物品栏 | 0166 `▲Scene_Menu`、0177 `Window_ItemCategory`、0178 `Window_ItemHelp`、0179 `Window_ItemDesc`、0180 `Window_Item`、0181 `Window_Gold`、0182 `Window_ItemConfig`、0183 `※Window_ItemBar`、0186 `Window_State`、0187 `Window_Topic`、0188 `Window_MapName`、0197 `■●Window_PlayerData`、0198 `△Window_MenuCommand`、0200—0203 `▲Scene_Map 1—4` | 地图内菜单、角色状态/HUD、快捷物品栏及预设、货币、章节/地图名、历史文本、各子页面切换、淡入淡出/截图。显示实际 0.45 角色/战斗/回路状态；快捷键和暂停/恢复不重复推进事件。 |
| [x] 46-08 技能配置页面 | 0207 `Window_Skill`、0208 `Window_SkillHelp`、0209 `Window_SkillCategory`，配合 0257 `Scene_Skill` | 技能分类、槽位/回合配置、帮助与描述、原卡框显示、确认/取消；实际修改 0.45 角色技能状态。 |
| [x] 46-09 结晶回路页面 | 0215 `Window_Blastic`、0216 `Window_BlasticAtrri`、0217 `Window_BlasticEquip`、0218 `Window_BlasticEquipDesc`、0219 `Window_BlasticGroup`、0220 `Window_BlasticTitle`、0221 `Window_BlasticCrystal` | 魔盘、孔位、结晶选择、属性预览与回响页面；名称为原脚本名，0219 实际定义 `Window_BlasticEcho`。选择/装备/卸下调用 0.45 服务，预览和背包数量一致。 |
| [x] 46-10 笔记页面 | 0224 `->Storage`、0225 `Window_NoteCommand`、0226 `Window_NoteSelect`、0227 `Window_NoteDesc` | 笔记类别/条目解锁、说明、滚动和返回；源预设与运行解锁状态分别管理，完整保存归 0.47。 |
| [x] 46-11 灵视与敌人信息 | 0231 `Window_SightMap`、0232 `Window_SightDesc`、0233 `Window_Enemy`、0235 `Window_EnemySkill`、0236 `Window_EnemyAction`、0237 `Window_EnmeyAction2`、0238 `Window_SightHelp`、0239 `Window_EnemyList`、0240 `Window_ItemList`、0262 `■●Window_EnemyDate` | 地图游标、敌人/物品列表、行动/技能说明、血量/战后伤害和焦点切换；采用 0.45 的同一预估结果，状态变化后刷新，不另算一套公式。 |
| [x] 46-12 地图系统 | 0244 `Window_RD_Map`、0245 `  —>相关定义`、0246 `Game_MapSystem`、0247 `Game_MapBlock`、0248 `Window_Map`、0249 `Window_Map_Selct`、0250 `Sprite_MapBlock`、0251 `Spriteset_MapSystem`，配合 0108/0109 | 已发现地图、区域/连接、图块布局、地图游标、地图预览、换图记录；布局/发现状态由 0.47 完整保存。0251 还重开 `Scene_Map.transfer_player`，需核对实际覆盖。 |
| [x] 46-13 独立功能页面与存档展示 | 0254 `★Scene_Flytofloor`、0255 `★Scene_CP`、0256 `▲Scene_Item`、0257 `Scene_Skill`、0258 `▲Scene_Equip`、0259 `Scene_Shop_new`、0260 `Scene_Debug`、0170 `Window_FileChapter`、0171 `Window_FileKind`、0172 `Window_MapSnap`、0173 `Window_File`、0174 `Window_FileTips` | 飞行器/CP/物品/技能/装备/商店/调试页面，存档分类、章节、缩略图和说明；存档展示接现有 Godot 存档接口，闪翼完整保存/撤回在 0.47 收尾。 |
| 用户排除：46-14 自定义 BOSS 战显示与输入 | 0276 `■RPG相关追加`、0278—0281 `Scene_BossBattle 1—4`、0289 `Window_Boss_Command`、0290 `Window_BCDesc`、0291 `Window_BCHelp`、0292 `Window_BDetail`、0293 `Arrow_Base`、0294 `Arrow_Enemy`、0295 `Arrow_Actor`、0296 `Animation_Damage`、0298 无名脚本（实际定义 `Sprite_Damage`）、0299 `Sprite_BossStatus`、0300 `Screen_BossBattle`、0301 `●Sprite_AT_List`、0302 `->Sprite_AT_Block`、0304 `Sprite_Boss_Character`、0305 `Spriteset_BossBattle`、0306 `Battle_Manager` 的显示协调 | 命令/目标选择、血量/BP/BUFF/AT条、行动预览、动画帧触发伤害、飘字、战斗场景与地图返回。业务结算和动画触发只消费/提交一次，同一时钟按 Godot 生命周期推进。 |
| [x] 46-15 剧情演出与跟随 | 0310 `Game_Engine`、0311 `碎屏`、0312 `游戏帮助`、0315 `Utils` 的文字/图形工具、0330 `行走图`、0331 `位图消逝`、0332 `跟随` | 冻结/解冻、模糊/滤镜/扫描线/旁白/碎屏、行走图和图片消逝、队伍跟随与移动队列。实际依赖的块/动态表达式本版处理，不能保留阻塞式 `Graphics.update` 循环。 |
| [x] 46-16 启动与显示模式 | 0337 `Main`、0032 `Graphics`、0033 `WindowScaler`、0046 `Game_Config`，配合 0266 `■full kboard` | 将原 60 FPS 设定、640×640 内部画布、字体、标题/场景循环接到 Godot 设置与生命周期；页面所需按键和显示模式本版可用，平台辅助程序/剩余 API 在 0.47 审计替换。 |

0.46 验收重点：范围内的闪翼各页面可见、可操作、可正确关闭/返回；显示同一份业务状态。地图移动、战斗动画、对话等待和剧情演出不阻塞引擎，也不重复推进或结算。

2026-10-13：0.46表内阶段职责已实现。勾选表示该版本的页面/运行方法，不表示同名原Ruby整库、0.47持久化或源空实现已补全。具体源码、覆盖关系、缺失源依赖和开发入口见[0.46源码说明](FLASH_UI_GDSCRIPT_v0.46.md)，完整检查见[验证记录](../tests/VERIFICATION_v0.46.md)。后续仅进行闪翼回归，二律历史证据保留。

## 0.47：剩余动态能力、原生插件与完整持久化

2026-10-14：下表阶段方法已接入，实际入口和源边界见[0.47说明](SCRIPT_MIGRATION_v0.47.md)及[生命周期审计](FLASH_LIFECYCLE_AUDIT_v0.47.md)。勾选不表示原空功能或未提供媒体已补造；正式导出与核验状态以[验证记录](../tests/VERIFICATION_v0.47.md)为准。

| 任务 | 原 RM 脚本（加载序号） | 需要迁移/核对的内容与验收结果 |
| --- | --- | --- |
| [x] 47-01 跨存档配置与解锁 | 0004 `Global_Variables`、0046 `Game_Config`、0047 `Game_Music`，配合 0139、0143—0145 | 全局变量、音量/按键/显示配置、音乐与成就解锁的新 Godot 持久化；区分跨启动数据和单存档数据，校验后整体恢复。核对原调用中缺失的方法，不自动伪造实现。 |
| [x] 47-02 完整存档与摘要 | 0169 `Game_FileData`、0173 `Window_File` 的 `save/load`、0315 `Utils.DeepClone`，配合 0041—0045、0065—0072、0078—0079、0082—0088、0093—0098、0103—0109、0157、0214、0246—0247、0332 等持有状态的脚本 | 按原保存清单覆盖 system、变量/开关、地图/人物/屏幕、角色/队伍/楼层怪物/装备、`$movedevents`、地图系统与结晶回路；检查自定义对象、共享/循环引用、身份、重置和缓存重建。窗口/精灵监听重新绑定，运行资源不直接写入存档；不读取 RM 旧存档。 |
| [x] 47-03 自动记录与撤回 | 0320 `BackSpace(撤回)`、0043 `Game_System 2`、0097 `Game_Player 1`、0096 `Game_Event`，配合 0169/0173 | `Game_System.record`、`BackSpace.UndoSave`、事件前快照、进度编号/历史容量、自动记录条件；撤回恢复地图、角色、货币、事件修改、回路和地图发现状态，消息/音频/跟随重新接通。 |
| [x] 47-04 系统 API与键盘 | 0003 `Global` 的 `__API/__TITLE/__HWND`、0020 `String` 的 API参数工具、0025 `RPG::Cache.api`、0033 `WindowScaler`、0266 `■full kboard`、0333 `临时debug` | 按具体用途替换 Windows 句柄/键盘/窗口缩放/控制台调用；目标保持标准版 Godot、纯 GDScript。页面已需要的功能前置到 0.46，开发调试工具单独登记。 |
| [x] 47-05 位图插件与航拍 | 0012 `[]TKTK_Bitmap`、0023 `Bitmap` 中的原生地址/像素/PNG接口、0329 `航拍`，配合 0310、0311、0331 的调用 | 图像效果、混合、像素访问、截图/地图航拍和 PNG 输出按用途提供 Godot 实现；原 DLL/内存地址接口不直接照搬。0.46 界面需要的效果已提前接入，本版验证剩余插件功能与导出。 |
| [x] 47-06 视频工具 | 0323 `Movie_Player` | 替换 MCI 播放链，处理路径、区域、等待/跳过、停止/暂停/继续和异常；先核对实际素材与调用。不能将系统解码器依赖或没有素材的分支宣称已验证。 |
| [x] 47-07 剩余 eval、反射与文件访问 | 0019 `Array.bwise`、0053/0070 自定义数据表达式、0078 货币分派、0086 对象选择、0094 路线脚本、0096 事件页字段、0098 动态移动、0108 楼层链接、0161/0165 脚本入口、0169 摘要字段、0306 阵营分派、0331 `instance_eval`，以及公共事件23等动态片段 | 可确定表达式和有限分派转为生成代码/明确接口；前两版需要的分支已在对应版本实现，本版审核剩余输入与诊断。文件读取定位目标工程资源，不依赖原 RM 运行目录。无法确定的剩余项逐项写明影响，保留缺口状态。 |
| [x] 47-08 全脚本依赖与生命周期审计 | 241 个含执行内容的脚本及全部地图/公共事件脚本入口 | 检查加载顺序、类重开/alias、最后实际方法、注册时机、跨图对象、存读档/新游戏/回标题、跟随与监听恢复；逐项登记自动转译、适配、数据化、历史留档或未完成。仍有约定范围内运行缺口时，不标“全部自定义脚本迁移完成”。 |

0.47 验收重点：新游戏、换图、保存/读取、重启和撤回后的玩法状态与界面一致；核心调用链不再依赖 Ruby、RM 原运行目录或旧存档格式。0.48 的工作区仍需展示这些源码对应关系，0.49 再做完整流程整合。

## 需要保留的边界和源工程疑点

1. **特殊BOSS战按最新用户指示排除；普通地图战斗仍纳入。RM原生回合制战斗仍按既定约定排除。**不能仅按 `Battler/Troop/Scene_Battle` 名称判断。0338 `战斗圆盘` 当前整段位于 `=begin/=end` 注释中，不作为启用的 BOSS 战入口。
2. **旧代码与未调用代码单独登记。**0075/0076 明确旧留档，公共事件36仍保留旧接口；0063、0074、0234、0253、0297、0303 等当前无执行内容。不能把“有 .rb 文件”当作“实际加载有代码”，也不能在未完成调用审计时把非空脚本认定为未使用。
3. **外部数据缺失**：Global 配置 `Enemy.exdata`、`Deputy.exdata`，目录实际只有 `Enemies.txt`、`Deputies.txt` 示例。0.44 已报告；后续需要区分原有默认/数据库回退与缺失的自定义输入，不能擅自用示例补出怪物规则。
   **既有迁移缺口**：0.44仅提取`POTION_ITEM_ID/GEM_ITEM_ID`的初始空Hash，原Global中后续逐项赋值未恢复，需在45-01补齐；这不是原数据文件缺失，也不能计为映射表已完整迁移。
4. **源实现本身的空方法/不一致**需要独立登记。例如 0288 `Battle_Calculator.element_formula` 为空，0306 对 `Game_BossBattle_Data` 的部分调用参数与 0282 构造器定义不一致。这些分支要核对可达性与原意，不能仅通过编译便宣称原功能正常，也不能在迁移中自行设计新机制。
5. **按方法验收**：同一源文件可能同时包含计算、UI、保存和历史代码。至少分别登记来源方法/行、目标 GDScript 方法或数据项、调用上下文、当前完成状态与验证证据。表中“配合”表示依赖/部分方法，不表示整文件属于单一版本。

## 逐脚本定位附录

下表按原加载顺序列出含执行内容的脚本。任务栏是后续需要核对/补齐的版本归属，全部处于计划状态；已实现的 0.44 局部服务仍需按上表复用、核对。源码链接指向已经与当前原 rxdata 逐项比较通过的只读保留副本。

<!-- FLASH_SCRIPT_APPENDIX -->

| 序号 | 原脚本名与源码 | 主核对版本 | 具体任务（47-08 全库审计适用于全部非空项） |
| --- | --- | --- | --- |
| 0003 | [Global](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0003_Global.rb>) | 0.45 | 45-01、47-04 |
| 0004 | [Global_Variables](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0004_Global_Variables.rb>) | 0.47 | 47-01 |
| 0005 | [Universal_Bind](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0005_Universal_Bind.rb>) | 0.45 | 45-01、46-06 |
| 0006 | [全局定义](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0006_全局定义.rb>) | 0.45 | 45-01 |
| 0009 | [Sotrage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0009_Sotrage.rb>) | 0.46 | 46-01 |
| 0012 | [\[\]TKTK_Bitmap](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0012_[]TKTK_Bitmap.rb>) | 0.46 | 46-01、47-05 |
| 0018 | [Object](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0018_Object.rb>) | 0.45 | 45-01 |
| 0019 | [Array](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0019_Array.rb>) | 0.45 | 45-01、47-07 |
| 0020 | [String](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0020_String.rb>) | 0.47 | 47-04 |
| 0021 | [Numeric](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0021_Numeric.rb>) | 0.45 | 45-01 |
| 0022 | [Color](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0022_Color.rb>) | 0.46 | 46-01 |
| 0023 | [Bitmap](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0023_Bitmap.rb>) | 0.46 | 46-01、47-05 |
| 0024 | [Hash](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0024_Hash.rb>) | 0.45 | 45-01 |
| 0025 | [RPG::Cache](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0025_RPG__Cache.rb>) | 0.46 | 46-01、47-04 |
| 0026 | [Tilemap](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0026_Tilemap.rb>) | 0.46 | 46-01 |
| 0027 | [Bitmap绘图追加](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0027_Bitmap绘图追加.rb>) | 0.46 | 46-01 |
| 0030 | [Shape](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0030_Shape.rb>) | 0.46 | 46-01 |
| 0031 | [Hexagon](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0031_Hexagon.rb>) | 0.46 | 46-01 |
| 0032 | [Graphics](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0032_Graphics.rb>) | 0.46 | 46-01、46-16 |
| 0033 | [WindowScaler](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0033_WindowScaler.rb>) | 0.47 | 46-16、47-04 |
| 0034 | [RPG追加](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0034_RPG追加.rb>) | 0.45 | 45-01、46-01 |
| 0037 | [DataBase](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0037_DataBase.rb>) | 0.45 | 45-01 |
| 0040 | [->Sotrage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0040_-_Sotrage.rb>) | 0.45 | 45-01、46-04 |
| 0041 | [Game_Temp](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0041_Game_Temp.rb>) | 0.46 | 45-08、46-02、47-02 |
| 0042 | [Game_System 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0042_Game_System 1.rb>) | 0.46 | 46-02、47-02 |
| 0043 | [Game_System 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0043_Game_System 2.rb>) | 0.46 | 45-08、46-02、47-02、47-03 |
| 0044 | [Game_Screen](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0044_Game_Screen.rb>) | 0.46 | 46-02、47-02 |
| 0045 | [Game_Picture](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0045_Game_Picture.rb>) | 0.46 | 46-02、47-02 |
| 0046 | [Game_Config](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0046_Game_Config.rb>) | 0.46 | 46-04、46-16、47-01 |
| 0047 | [Game_Music](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0047_Game_Music.rb>) | 0.46 | 46-04、47-01 |
| 0048 | [Sprite_Picture](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0048_Sprite_Picture.rb>) | 0.46 | 46-02 |
| 0049 | [Sprite_Timer](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0049_Sprite_Timer.rb>) | 0.46 | 46-02 |
| 0052 | [->Sotrage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0052_-_Sotrage.rb>) | 0.45 | 45-08 |
| 0053 | [Game_Object](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0053_Game_Object.rb>) | 0.45 | 45-02、47-07 |
| 0054 | [Game_Item](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0054_Game_Item.rb>) | 0.45 | 45-02 |
| 0055 | [Game_Weapon](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0055_Game_Weapon.rb>) | 0.45 | 45-02 |
| 0056 | [Game_Armor](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0056_Game_Armor.rb>) | 0.45 | 45-02 |
| 0057 | [Game_Ornament](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0057_Game_Ornament.rb>) | 0.45 | 45-02 |
| 0060 | [->Sotrage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb>) | 0.45 | 45-04、45-09 |
| 0061 | [->Storage(技能文本)](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0061_-_Storage(技能文本).rb>) | 0.45 | 45-04 |
| 0062 | [Skill 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb>) | 0.45 | 45-04、45-14 |
| 0064 | [Skill 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0064_Skill 3.rb>) | 0.45 | 45-04、45-14 |
| 0065 | [Game_Battler 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0065_Game_Battler 1.rb>) | 0.45 | 45-03、47-02 |
| 0066 | [Game_Battler 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0066_Game_Battler 2.rb>) | 0.45 | 45-03、47-02 |
| 0067 | [Game_Battler 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0067_Game_Battler 3.rb>) | 0.45 | 45-03、47-02 |
| 0068 | [Game_Actor 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0068_Game_Actor 1.rb>) | 0.45 | 45-03、45-09、45-10、47-02 |
| 0069 | [Game_Actor 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0069_Game_Actor 2.rb>) | 0.45 | 45-03、47-02 |
| 0070 | [Game_Enemy 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0070_Game_Enemy 1.rb>) | 0.45 | 45-03、47-02、47-07 |
| 0071 | [Game_Enemy 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0071_Game_Enemy 2.rb>) | 0.45 | 45-03、47-02 |
| 0072 | [BattleSystem](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0072_BattleSystem.rb>) | 0.45 | 45-05、45-06、47-02 |
| 0073 | [SkillRegistry](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0073_SkillRegistry.rb>) | 0.45 | 45-05 |
| 0075 | [Battle_Data](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb>) | 0.45 | 45-14 |
| 0076 | [Delay_Ctrl](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb>) | 0.45 | 45-14 |
| 0078 | [▲Game_Party](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0078_▲Game_Party.rb>) | 0.45 | 45-06、45-09、47-02、47-07 |
| 0079 | [Game_Troop](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0079_Game_Troop.rb>) | 0.45 | 45-07、47-02 |
| 0082 | [Game_Switches](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0082_Game_Switches.rb>) | 0.47 | 47-02 |
| 0083 | [Game_Variables](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0083_Game_Variables.rb>) | 0.47 | 47-02 |
| 0084 | [Game_SelfSwitches](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0084_Game_SelfSwitches.rb>) | 0.47 | 47-02 |
| 0085 | [Game_Actors](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0085_Game_Actors.rb>) | 0.45 | 45-03、47-02 |
| 0086 | [Game_Equipment](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0086_Game_Equipment.rb>) | 0.45 | 45-02、47-02、47-07 |
| 0087 | [Game_Troops](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0087_Game_Troops.rb>) | 0.45 | 45-07、47-02 |
| 0088 | [Game_Blastics](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0088_Game_Blastics.rb>) | 0.45 | 45-10、47-02 |
| 0091 | [->Sotrage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0091_-_Sotrage.rb>) | 0.46 | 46-02 |
| 0092 | [Game_CommonEvent](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0092_Game_CommonEvent.rb>) | 0.46 | 46-02 |
| 0093 | [Game_Character 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0093_Game_Character 1.rb>) | 0.46 | 46-02、47-02 |
| 0094 | [Game_Character 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0094_Game_Character 2.rb>) | 0.46 | 46-02、47-02、47-07 |
| 0095 | [Game_Character 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0095_Game_Character 3.rb>) | 0.46 | 46-02、47-02 |
| 0096 | [Game_Event](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0096_Game_Event.rb>) | 0.45 | 45-06、45-07、46-02、47-02、47-03、47-07 |
| 0097 | [Game_Player 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0097_Game_Player 1.rb>) | 0.46 | 46-02、47-02、47-03 |
| 0098 | [Game_Player 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0098_Game_Player 2.rb>) | 0.45 | 45-07、46-02、47-02、47-07 |
| 0099 | [▲Sprite_Character](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0099_▲Sprite_Character.rb>) | 0.46 | 46-02 |
| 0102 | [->Sotrage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0102_-_Sotrage.rb>) | 0.46 | 46-02 |
| 0103 | [▲●Game_Map 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0103_▲●Game_Map 1.rb>) | 0.46 | 46-02、47-02 |
| 0104 | [Game_Map 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0104_Game_Map 2.rb>) | 0.45 | 45-07、46-02、47-02 |
| 0105 | [Spriteset_Map](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0105_Spriteset_Map.rb>) | 0.46 | 46-02、47-02 |
| 0108 | [Game_Floor](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0108_Game_Floor.rb>) | 0.46 | 46-02、46-12、47-02、47-07 |
| 0109 | [Game_Region](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0109_Game_Region.rb>) | 0.46 | 46-02、46-12、47-02 |
| 0111 | [▲Window_Base](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0111_▲Window_Base.rb>) | 0.46 | 46-03 |
| 0112 | [Window_Selectable](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0112_Window_Selectable.rb>) | 0.46 | 46-03 |
| 0113 | [Window_Command](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0113_Window_Command.rb>) | 0.46 | 46-03 |
| 0114 | [Window_Help](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0114_Window_Help.rb>) | 0.46 | 46-03 |
| 0116 | [▲Window_Item](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0116_▲Window_Item.rb>) | 0.46 | 46-03 |
| 0117 | [★Window_Flytofloor](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0117_★Window_Flytofloor.rb>) | 0.46 | 46-03 |
| 0118 | [★Window_CP](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0118_★Window_CP.rb>) | 0.46 | 46-03 |
| 0119 | [Window_Skill](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0119_Window_Skill.rb>) | 0.46 | 46-03 |
| 0120 | [Window_SkillStatus](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0120_Window_SkillStatus.rb>) | 0.46 | 46-03 |
| 0121 | [Window_Target](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0121_Window_Target.rb>) | 0.46 | 46-03 |
| 0122 | [▲Window_EquipLeft](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0122_▲Window_EquipLeft.rb>) | 0.46 | 46-03 |
| 0123 | [Window_EquipRight](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0123_Window_EquipRight.rb>) | 0.46 | 46-03 |
| 0124 | [▲Window_EquipItem](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0124_▲Window_EquipItem.rb>) | 0.46 | 46-03 |
| 0125 | [Window_Status](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0125_Window_Status.rb>) | 0.46 | 46-03 |
| 0126 | [▲Window_SaveFile](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0126_▲Window_SaveFile.rb>) | 0.46 | 46-03、47-02 |
| 0127 | [Window_ShopCommand_New](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0127_Window_ShopCommand_New.rb>) | 0.46 | 46-03 |
| 0128 | [Window_ShopBuy](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0128_Window_ShopBuy.rb>) | 0.46 | 46-03 |
| 0129 | [Window_ShopSell](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0129_Window_ShopSell.rb>) | 0.46 | 46-03 |
| 0130 | [Window_ShopNumber](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0130_Window_ShopNumber.rb>) | 0.46 | 46-03 |
| 0131 | [Window_ShopStatus](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0131_Window_ShopStatus.rb>) | 0.46 | 46-03 |
| 0132 | [Window_NameEdit](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0132_Window_NameEdit.rb>) | 0.46 | 46-03 |
| 0133 | [▲Window_InputNumber](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0133_▲Window_InputNumber.rb>) | 0.46 | 46-03 |
| 0134 | [▲Window_Message](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0134_▲Window_Message.rb>) | 0.46 | 46-03 |
| 0135 | [Window_DebugLeft](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0135_Window_DebugLeft.rb>) | 0.46 | 46-03 |
| 0136 | [Window_DebugRight](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0136_Window_DebugRight.rb>) | 0.46 | 46-03 |
| 0139 | [▲Scene_Title](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0139_▲Scene_Title.rb>) | 0.46 | 46-04、47-01 |
| 0140 | [Window_BackGround](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0140_Window_BackGround.rb>) | 0.46 | 46-04 |
| 0141 | [Window_Mode](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0141_Window_Mode.rb>) | 0.46 | 46-04 |
| 0142 | [Window_Title](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0142_Window_Title.rb>) | 0.46 | 46-04 |
| 0143 | [Window_Config](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0143_Window_Config.rb>) | 0.46 | 46-04、47-01 |
| 0144 | [Window_Music](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0144_Window_Music.rb>) | 0.46 | 46-04、47-01 |
| 0145 | [Window_Merit](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0145_Window_Merit.rb>) | 0.46 | 46-04、47-01 |
| 0148 | [->Storage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0148_-_Storage.rb>) | 0.46 | 46-05 |
| 0149 | [Message 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0149_Message 1.rb>) | 0.46 | 46-05 |
| 0150 | [Message 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0150_Message 2.rb>) | 0.46 | 46-05 |
| 0151 | [Message::TextRow](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0151_Message__TextRow.rb>) | 0.46 | 46-05 |
| 0152 | [Message::TextBox 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0152_Message__TextBox 1.rb>) | 0.46 | 46-05 |
| 0153 | [Message::TextBox 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0153_Message__TextBox 2.rb>) | 0.46 | 46-05 |
| 0154 | [Message::HintBox 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0154_Message__HintBox 1.rb>) | 0.46 | 46-05 |
| 0155 | [Message::HintBox 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0155_Message__HintBox 2.rb>) | 0.46 | 46-05 |
| 0156 | [Message::Words](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0156_Message__Words.rb>) | 0.46 | 46-05 |
| 0157 | [Message_Memory](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0157_Message_Memory.rb>) | 0.46 | 46-05、47-02 |
| 0159 | [Interpreter 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0159_Interpreter 1.rb>) | 0.46 | 46-06 |
| 0160 | [Interpreter 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0160_Interpreter 2.rb>) | 0.46 | 46-06 |
| 0161 | [Interpreter 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0161_Interpreter 3.rb>) | 0.46 | 46-06、47-07 |
| 0162 | [Interpreter 4](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0162_Interpreter 4.rb>) | 0.46 | 46-06 |
| 0163 | [▲Interpreter 5](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0163_▲Interpreter 5.rb>) | 0.46 | 46-06 |
| 0164 | [Interpreter 6](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0164_Interpreter 6.rb>) | 0.46 | 46-06 |
| 0165 | [Interpreter 7](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0165_Interpreter 7.rb>) | 0.46 | 46-06、47-07 |
| 0166 | [▲Scene_Menu](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0166_▲Scene_Menu.rb>) | 0.46 | 46-07 |
| 0169 | [Game_FileData](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0169_Game_FileData.rb>) | 0.47 | 47-02、47-03、47-07 |
| 0170 | [Window_FileChapter](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0170_Window_FileChapter.rb>) | 0.46 | 46-13 |
| 0171 | [Window_FileKind](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0171_Window_FileKind.rb>) | 0.46 | 46-13 |
| 0172 | [Window_MapSnap](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0172_Window_MapSnap.rb>) | 0.46 | 46-13 |
| 0173 | [Window_File](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0173_Window_File.rb>) | 0.46 | 46-13、47-02、47-03 |
| 0174 | [Window_FileTips](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0174_Window_FileTips.rb>) | 0.46 | 46-13 |
| 0177 | [Window_ItemCategory](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0177_Window_ItemCategory.rb>) | 0.46 | 46-07 |
| 0178 | [Window_ItemHelp](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0178_Window_ItemHelp.rb>) | 0.46 | 46-07 |
| 0179 | [Window_ItemDesc](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0179_Window_ItemDesc.rb>) | 0.46 | 46-07 |
| 0180 | [Window_Item](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0180_Window_Item.rb>) | 0.46 | 46-07 |
| 0181 | [Window_Gold](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0181_Window_Gold.rb>) | 0.46 | 46-07 |
| 0182 | [Window_ItemConfig](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0182_Window_ItemConfig.rb>) | 0.46 | 46-07 |
| 0183 | [※Window_ItemBar](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0183_※Window_ItemBar.rb>) | 0.46 | 46-07 |
| 0186 | [Window_State](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0186_Window_State.rb>) | 0.46 | 46-07 |
| 0187 | [Window_Topic](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0187_Window_Topic.rb>) | 0.46 | 46-07 |
| 0188 | [Window_MapName](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0188_Window_MapName.rb>) | 0.46 | 46-07 |
| 0191 | [Message_Controller](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0191_Message_Controller.rb>) | 0.46 | 46-05、46-06 |
| 0193 | [药品库](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0193_药品库.rb>) | 0.45 | 45-08 |
| 0197 | [■●Window_PlayerData](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0197_■●Window_PlayerData.rb>) | 0.46 | 46-07 |
| 0198 | [△Window_MenuCommand](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0198_△Window_MenuCommand.rb>) | 0.46 | 46-07 |
| 0200 | [▲Scene_Map 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0200_▲Scene_Map 1.rb>) | 0.46 | 45-12、46-07 |
| 0201 | [▲Scene_Map 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0201_▲Scene_Map 2.rb>) | 0.46 | 46-07 |
| 0202 | [▲Scene_Map 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0202_▲Scene_Map 3.rb>) | 0.46 | 45-12、46-07 |
| 0203 | [▲Scene_Map 4](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0203_▲Scene_Map 4.rb>) | 0.46 | 46-07 |
| 0207 | [Window_Skill](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0207_Window_Skill.rb>) | 0.46 | 46-08 |
| 0208 | [Window_SkillHelp](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0208_Window_SkillHelp.rb>) | 0.46 | 46-08 |
| 0209 | [Window_SkillCategory](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0209_Window_SkillCategory.rb>) | 0.46 | 46-08 |
| 0212 | [->Storage(结晶回路追加定义)](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0212_-_Storage(结晶回路追加定义).rb>) | 0.45 | 45-10 |
| 0213 | [->Storage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0213_-_Storage.rb>) | 0.45 | 45-10 |
| 0214 | [Game_Blastic](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0214_Game_Blastic.rb>) | 0.45 | 45-10、47-02 |
| 0215 | [Window_Blastic](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0215_Window_Blastic.rb>) | 0.46 | 46-09 |
| 0216 | [Window_BlasticAtrri](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0216_Window_BlasticAtrri.rb>) | 0.46 | 46-09 |
| 0217 | [Window_BlasticEquip](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0217_Window_BlasticEquip.rb>) | 0.46 | 46-09 |
| 0218 | [Window_BlasticEquipDesc](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0218_Window_BlasticEquipDesc.rb>) | 0.46 | 46-09 |
| 0219 | [Window_BlasticGroup](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0219_Window_BlasticGroup.rb>) | 0.46 | 46-09 |
| 0220 | [Window_BlasticTitle](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0220_Window_BlasticTitle.rb>) | 0.46 | 46-09 |
| 0221 | [Window_BlasticCrystal](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0221_Window_BlasticCrystal.rb>) | 0.46 | 46-09 |
| 0224 | [->Storage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0224_-_Storage.rb>) | 0.46 | 46-10 |
| 0225 | [Window_NoteCommand](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0225_Window_NoteCommand.rb>) | 0.46 | 46-10 |
| 0226 | [Window_NoteSelect](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0226_Window_NoteSelect.rb>) | 0.46 | 46-10 |
| 0227 | [Window_NoteDesc](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0227_Window_NoteDesc.rb>) | 0.46 | 46-10 |
| 0231 | [Window_SightMap](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0231_Window_SightMap.rb>) | 0.46 | 46-11 |
| 0232 | [Window_SightDesc](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0232_Window_SightDesc.rb>) | 0.46 | 46-11 |
| 0233 | [Window_Enemy](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0233_Window_Enemy.rb>) | 0.46 | 46-11 |
| 0235 | [Window_EnemySkill](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0235_Window_EnemySkill.rb>) | 0.46 | 46-11 |
| 0236 | [Window_EnemyAction](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0236_Window_EnemyAction.rb>) | 0.46 | 46-11 |
| 0237 | [Window_EnmeyAction2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0237_Window_EnmeyAction2.rb>) | 0.46 | 46-11 |
| 0238 | [Window_SightHelp](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0238_Window_SightHelp.rb>) | 0.46 | 46-11 |
| 0239 | [Window_EnemyList](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0239_Window_EnemyList.rb>) | 0.46 | 46-11 |
| 0240 | [Window_ItemList](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0240_Window_ItemList.rb>) | 0.46 | 46-11 |
| 0244 | [Window_RD_Map](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0244_Window_RD_Map.rb>) | 0.46 | 46-12 |
| 0245 | [  —>相关定义](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0245_—_相关定义.rb>) | 0.46 | 46-12 |
| 0246 | [Game_MapSystem](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0246_Game_MapSystem.rb>) | 0.46 | 46-12、47-02 |
| 0247 | [Game_MapBlock](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0247_Game_MapBlock.rb>) | 0.46 | 46-12、47-02 |
| 0248 | [Window_Map](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0248_Window_Map.rb>) | 0.46 | 46-12 |
| 0249 | [Window_Map_Selct](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0249_Window_Map_Selct.rb>) | 0.46 | 46-12 |
| 0250 | [Sprite_MapBlock](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0250_Sprite_MapBlock.rb>) | 0.46 | 46-12 |
| 0251 | [Spriteset_MapSystem](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0251_Spriteset_MapSystem.rb>) | 0.46 | 46-12 |
| 0254 | [★Scene_Flytofloor](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0254_★Scene_Flytofloor.rb>) | 0.46 | 45-12、46-13 |
| 0255 | [★Scene_CP](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0255_★Scene_CP.rb>) | 0.46 | 45-12、46-13 |
| 0256 | [▲Scene_Item](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0256_▲Scene_Item.rb>) | 0.46 | 45-12、46-13 |
| 0257 | [Scene_Skill](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0257_Scene_Skill.rb>) | 0.46 | 45-12、46-08、46-13 |
| 0258 | [▲Scene_Equip](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0258_▲Scene_Equip.rb>) | 0.46 | 45-12、46-13 |
| 0259 | [Scene_Shop_new](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0259_Scene_Shop_new.rb>) | 0.46 | 45-12、46-13 |
| 0260 | [Scene_Debug](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0260_Scene_Debug.rb>) | 0.46 | 46-13 |
| 0262 | [■●Window_EnemyDate](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0262_■●Window_EnemyDate.rb>) | 0.46 | 46-11 |
| 0263 | [★Item caculator](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0263_★Item caculator.rb>) | 0.45 | 45-08 |
| 0265 | [■Window_Version](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0265_■Window_Version.rb>) | 0.46 | 46-04 |
| 0266 | [■full kboard](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0266_■full kboard.rb>) | 0.47 | 46-16、47-04 |
| 0270 | [■GPRA_TextStream](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0270_■GPRA_TextStream.rb>) | 0.46 | 46-05 |
| 0275 | [■Skill追加](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0275_■Skill追加.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0276 | [■RPG相关追加](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0276_■RPG相关追加.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0277 | [ObservableBattler](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0277_ObservableBattler.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0278 | [Scene_BossBattle 1](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0278_Scene_BossBattle 1.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0279 | [Scene_BossBattle 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0279_Scene_BossBattle 2.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0280 | [Scene_BossBattle 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0280_Scene_BossBattle 3.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0281 | [Scene_BossBattle 4](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0281_Scene_BossBattle 4.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0282 | [Game_BossBattle_Data](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0282_Game_BossBattle_Data.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0283 | [■■Temp_Battler](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0283_■■Temp_Battler.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0284 | [Game_Boss_Battler](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0284_Game_Boss_Battler.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0285 | [Game_Boss_Actor](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0285_Game_Boss_Actor.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0286 | [Game_Boss_Enemy](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0286_Game_Boss_Enemy.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0287 | [Game_Boss_Tactical](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0287_Game_Boss_Tactical.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0288 | [Battle_Calculator](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0288_Battle_Calculator.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0289 | [Window_Boss_Command](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0289_Window_Boss_Command.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0290 | [Window_BCDesc](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0290_Window_BCDesc.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0291 | [Window_BCHelp](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0291_Window_BCHelp.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0292 | [Window_BDetail](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0292_Window_BDetail.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0293 | [Arrow_Base](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0293_Arrow_Base.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0294 | [Arrow_Enemy](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0294_Arrow_Enemy.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0295 | [Arrow_Actor](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0295_Arrow_Actor.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0296 | [Animation_Damage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0296_Animation_Damage.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0298 | [无名：实际定义 Sprite_Damage](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0298_unnamed.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0299 | [Sprite_BossStatus](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0299_Sprite_BossStatus.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0300 | [Screen_BossBattle](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0300_Screen_BossBattle.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0301 | [●Sprite_AT_List](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0301_●Sprite_AT_List.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0302 | [->Sprite_AT_Block](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0302_-_Sprite_AT_Block.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0304 | [Sprite_Boss_Character](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0304_Sprite_Boss_Character.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0305 | [Spriteset_BossBattle](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0305_Spriteset_BossBattle.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0306 | [Battle_Manager](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0306_Battle_Manager.rb>) | 用户排除特殊BOSS战 | 保留原文 |
| 0310 | [Game_Engine](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0310_Game_Engine.rb>) | 0.46 | 46-15、47-05 |
| 0311 | [碎屏](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0311_碎屏.rb>) | 0.46 | 46-15、47-05 |
| 0312 | [游戏帮助](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0312_游戏帮助.rb>) | 0.46 | 46-15 |
| 0315 | [Utils](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0315_Utils.rb>) | 0.47 | 45-01、46-15、47-02 |
| 0317 | [Actor_Init](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0317_Actor_Init.rb>) | 0.45 | 45-09 |
| 0318 | [Level_Up](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0318_Level_Up.rb>) | 0.45 | 45-09 |
| 0320 | [BackSpace(撤回)](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0320_BackSpace(撤回).rb>) | 0.47 | 47-03 |
| 0323 | [Movie_Player](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0323_Movie_Player.rb>) | 0.47 | 47-06 |
| 0329 | [航拍](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0329_航拍.rb>) | 0.47 | 47-05 |
| 0330 | [行走图](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0330_行走图.rb>) | 0.46 | 46-15 |
| 0331 | [位图消逝](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0331_位图消逝.rb>) | 0.46 | 46-15、47-05、47-07 |
| 0332 | [跟随](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0332_跟随.rb>) | 0.46 | 46-15、47-02 |
| 0333 | [临时debug](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0333_临时debug.rb>) | 0.47 | 47-04 |
| 0337 | [Main](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0337_Main.rb>) | 0.46 | 46-16 |

98 个无执行内容的槽位（保留原名/源码，详细见 JSON）：

- 0001 `Test`
- 0002 `▼ 全局设定`
- 0007 `————————————`
- 0008 `▼ 系统预设`
- 0010 `————————————`
- 0011 `▼ 插件`
- 0013 `————————————`
- 0014 `▼ 测试集`
- 0015 `Test`
- 0016 `————————————`
- 0017 `▼ RGSS 追加`
- 0028 `————————————`
- 0029 `▼ GDI追加`
- 0035 `————————————`
- 0036 `▼ 数据`
- 0038 `————————————`
- 0039 `▼ 系统`
- 0050 `————————————`
- 0051 `▼ 游戏对象`
- 0058 `————————————`
- 0059 `▼ 战斗相关`
- 0063 `Skill 2`
- 0074 `●█Game_Enemy 3`
- 0077 `▼ 队列`
- 0080 `————————————`
- 0081 `▼ 系统排列`
- 0089 `————————————`
- 0090 `▼ 事件相关`
- 0100 `————————————`
- 0101 `▼ 地图相关`
- 0106 `————————————`
- 0107 `▼ 楼层相关`
- 0110 `————————————`
- 0115 `Window_Gold`
- 0137 `————————————`
- 0138 `▼ 标题相关`
- 0146 `————————————`
- 0147 `▼ 信息相关`
- 0158 `————————————`
- 0167 `——————————`
- 0168 `▼ 档案相关`
- 0175 `——————————`
- 0176 `▼ 道具相关`
- 0184 `——————————`
- 0185 `▼ 通用窗口`
- 0189 `——————————`
- 0190 `▼ 控制信息`
- 0192 `——————————`
- 0194 `——————————`
- 0195 `▼ 状态、菜单`
- 0196 `■●Window_PlayerData(废弃)`
- 0199 `▲Scene_Map`
- 0204 `——————————`
- 0205 `▼ 技能相关`
- 0206 `Window_SkillConfig`
- 0210 `——————————`
- 0211 `▼ Orbment相关`
- 0222 `——————————`
- 0223 `▼ 笔记相关`
- 0228 `无名`
- 0229 `——————————`
- 0230 `▼ 灵视系统`
- 0234 `Window_Enemy（废弃）`
- 0241 `——————————`
- 0242 `▼ 地图系统`
- 0243 `  —>地图右下显示`
- 0252 `——————————`
- 0253 `★Scene_EnemyView`
- 0261 `■Enemy_Ready`
- 0264 `■enemy property`
- 0267 `■●Window_PlayerData`
- 0268 `第一版UI`
- 0269 `■sort item`
- 0271 `■GPRA_Window_Message`
- 0272 `伤害显示`
- 0273 `————————————`
- 0274 `▼ 特殊BOSS战`
- 0297 `Sprite_Damage`
- 0303 `Sprite_Sp_Character(弃)`
- 0307 `备忘录`
- 0308 `————————————`
- 0309 `▼ 剧情相关`
- 0313 `————————————`
- 0314 `▼ 工具类`
- 0316 `BackSpace`
- 0319 `New_Audio`
- 0321 `玄鸟专用调试用功能`
- 0322 `玄鸟的突发奇想`
- 0324 `————————————`
- 0325 `▼ 剧情相关`
- 0326 `开关变量注释`
- 0327 `————————————`
- 0328 `▼ Vendor `
- 0334 `————————————`
- 0335 `▼ Main`
- 0336 `BATTLE_TEST`
- 0338 `战斗圆盘`
- 0339 `●RGSSruby`

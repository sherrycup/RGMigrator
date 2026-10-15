# 闪翼 0.43—0.44 已实现脚本迁移清单

2026-10-12，沿用用户要求，仅匹配“黎之闪翼（开发中）”。本文件是既有实现及正式产物的回溯清单；后续任务见[0.45—0.47清单](FLASH_SCRIPT_CHECKLIST_v0.45_v0.47.md)。

最新范围备注：用户随后明确特殊BOSS战不迁移；本文仍保留0.43—0.44历史生成记录，后续不将其列为必须完成的运行功能。

## 核对口径

- 0.43 来源为 `D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot`；0.44 来源为 `D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot`。本次只读核对产物和源码，不重新迁移、不覆盖历史工程。
- 原库共339个加载槽位、事件脚本144个片段。原脚本编号按 `Data/Scripts.rxdata` 的1起始加载顺序；两版保留源码与当前原文件一致，读取时未执行 Ruby。
- **已生成代码**：确有 `.gd` 文件，表示当前编译器能生成该单元，不保证依赖、初始化或原游戏完整调用链已接通。
- **已接通入口**：生成片段被绑定到原事件/条件/路线中；仍需检查所调用的游戏对象和方法。
- **已实现服务适配**：用共享 GDScript 服务承接原脚本的指定字段或方法。只覆盖下表列明部分，不能据此把整份源脚本标为已迁移。
- **已提取数据**：确定的初始化/配置转为目标数据；不意味着原初始化方法或加载器已经完整转译。
- `runtime_verified` 不因编译或绑定自动变为true；本次保留原注册表值。已有专项验证单独说明，不把私有夹具证明扩大为所有原工程玩法已验证。

## 两版正式产物的数量

| 闪翼产物 | 截至0.43 | 截至0.44 | 0.44相对0.43变化 |
| --- | --- | --- | --- |
| 生成库脚本单元 | 8 | 9 | 新增0085 `Game_Actors` 的生成结果 |
| 生成事件片段 | 33 | 46 | 新增13个，其中11个实际绑定 |
| 实际事件绑定 | 27：24个355、3个111 | 38：34个355、4个111 | 新增10个355、1个111 |
| 原工程路线45绑定 | 0 | 0 | 入口已实现并通过人物上下文夹具；闪翼原路线脚本尚未形成可用绑定 |
| 数据表达式生成单元 | 0 | 8 | 外部数据中的字面量/数组表达式，详见附录 |

0.43的8个库单元是截至该版已有的生成结果，语法/语义生成基础来自0.42；不能把这8项都描述为0.43新完成的整份脚本迁移。0.44共63个生成文件为9库＋46事件＋8数据表达式。

## 0.43：已实现的入口与运行支持

| 原 RM 来源 | 已实现的部分 | 目标GDScript入口 | 完成边界 |
| --- | --- | --- | --- |
| 0165 `Interpreter 7.command_355`（355/655） | 按闪翼Interpreter合并原脚本及续行；核对原文哈希，执行生成程序，忽略false返回并消费整组指令 | `EventInterpreter.gd`、`ScriptRuntime.execute_bound`、`runtime/generated/event_*.gd` | 已接通可生成片段；未转换脚本执行时明确失败，完整Interpreter类未自动迁移 |
| 0161 `Interpreter 3.command_111` 的脚本条件 | 按Ruby真值选择分支；false/nil为假，0/空字符串/空数组为真；执行错误不选择任何分支 | `EventValueResolver.gd`、`ScriptRuntime.gd`、`ScriptSemantics.gd` | 截至0.43闪翼有3条真实绑定，依赖未接通的条件仍不能运行 |
| 0094 `Game_Character 2.move_type_custom` 中路线45 | 使用实际人物上下文；false不阻止路线前进；等待后从下一动作恢复；整条路线预检 | `CharacterRoute.gd`、`ScriptRuntime.gd` | 入口和夹具已验证，原闪翼路线45实际绑定为0，不标为原路线迁移完成 |
| 0159 `Interpreter 1` 的运行上下文与等待机制 | 地图/事件/原记录位置、公共调用实例隔离、调用链、`@wait_count`换算、等待/取消/恢复 | `EventExecutionContext.gd`、`EventInterpreter.gd`、`EventWait.gd`、`ScriptRuntime.gd` | 支持的现场字段有明确映射；其他Interpreter实例字段读写仍可能失败，默认脚本帧率采用闪翼60 |
| 0082 `Game_Switches`、0083 `Game_Variables`、0078 `▲Game_Party` 中的基本状态访问 | 生成脚本和原生事件共享开关、整数变量和金币；出错回滚本次写入，事件报错并解除锁 | `ScriptStateBridge.gd`、`ScriptSemantics.gd`、`RuntimeState.gd` | 状态桥接沿用0.42；不等于原类全部方法已迁移；0.43变量仍为整数范围 |
| 库加载顺序、类重开/alias以及事件现场恢复 | 按需加载已转换的声明单元；保留定义版本；原事件等待/消费位置/实例字段可恢复 | `ScriptRuntime.gd`、`ScriptSemantics.gd`、`SaveCodec.gd`、事件持久化组件 | 不接管完整Main/启动链；后续未迁移覆盖或有副作用的库初始化不能跳过；自定义对象存档尚未完成 |
| 原地图和公共事件编辑入口 | 已绑定355/655整体选择/复制/移动/删除；条件分支和完整路线保留，原文变更使旧绑定失效 | 编辑器 `EditorScriptAdapter.gd`、`EditorCommandList.gd` 等 | 这是脚本入口编辑支持；源代码修改和重新编译工作区仍在0.48 |

实际来源验证例：地图003、事件26、第1页、第1条脚本 `event_000106` 中的 `$game_variables[2]=0`，已通过实际地图事件355入口改变同一运行状态。`Skill 3.real_time_readdition(61/62)` 的独立调用也已验证；这只证明该方法的61返回true、62返回false及按需重载，不证明完整技能系统已迁移。

## 0.44：已实现的数据提取与指定服务适配

| 原 RM 来源 | 实际完成内容 | 目标源码/数据 | 尚未完成的部分 |
| --- | --- | --- | --- |
| 0003 `Global` / `Kernel` | 提取61个常量条目，包括物品/状态编号、已确定效果参数、外部文件名；识别闪翼数据配置 | `data/custom_data.json.constants`、`CustomDataImporter.gd`、`ScriptRuntime.gd` | `__API/__TITLE/__HWND`未完整迁移；逐项构造的 `POTION_ITEM_ID/GEM_ITEM_ID` 在本版产物中仍为空Hash，只完成初始空值提取 |
| 0043 `Game_System 2.initialize` | 提取22个可确定的扩展默认字段；支持这些字段的脚本数据读写，例如 `interpretering/shotcut_enabled/show_playerdata/show_mapname/mdef_available/speed_available/show_greenkeys` | `data/custom_data.json.system_defaults`、`CustomDataState.gd` | 字段存在/可读写不表示对应HUD、消息、快捷键或地图业务已经实现；其他事件页修改方法仍待迁移 |
| 0053 `Game_Object.load_data`；0054—0057 `Game_Item/Weapon/Armor/Ornament` 的数据读取职责 | 迁移时按真实配置读取Items/Weapons/Armors/Ornaments.exdata；保留来源、原值、标签和已确定字段，生成8个纯表达式；已分析的 `setting || base` 按false/nil回退 | `CustomDataImporter.gd`、`data/database/*.json`、`data/custom_units.json`、`runtime/generated/data_*.gd` | 是数据加载职责的适配，不是这些类完整转译；对象行为、完整装备/抗性公式及物品效果待0.45；Enemy/Deputy配置文件缺失仍报告 |
| 0078 `▲Game_Party` 的货币与仇恨字段 | `gold/kin/spar`查询，`gain_gold/lose_gold/gain_currency/gain_kin/lose_kin/gain_spar/lose_spar`；`hatred`读写。KIN和五类耀晶石与原生金币共用余额/上限/事务 | `CustomDataState.party_call/gain_currency`、`DecimalInteger.gd`、`RuntimeState.gd` | 队伍、背包、主战/援护、经验和物品使用等其他方法未因此完成；仇恨的战斗用途待0.45 |
| 0065 `Game_Battler 1.initialize`、0068 `Game_Actor 1.setup` 的原始扩展属性 | 闪翼正式输出实际暴露4类字段：`tp_plus`、`resist_plus`、`skill_parameters`、`delay_const`。脚本、菜单快照、数据库草稿和存档使用同一组原始值 | `Actors.json._custom_data.attributes`、`CustomDataState.actor_attributes`、`RuntimeState.custom_actor_attributes` | `patk/maxhp`等最终派生值、装备/状态倍率和完整Game_Actor对象方法未迁移；不把其他初始化字段都计为已暴露属性 |
| 0317 `Actor_Init.load` | 提取角色2/3/4/5的0号预设值，保留原ID与字段 | `data/custom_data.json.actor_presets` | 只是预设提取；`Actor_Init.load`的运行写入和成长仍待0.45 |
| 0037 `DataBase.cre_maptree/get_floor_type` | 提取1条楼层关系：地区1/楼层1→地图4，P模板为地图5；提供`get_floor_type`查询和归一化楼层数据读取 | `custom_data.json.floors`、`CustomDataState.gd` | 完整DataBase初始化/战斗注册、`Game_Floor/Game_Region`业务未完成；`maptree`返回目标归一化结构，不能视为原混合Hash所有下标访问方式都已兼容 |
| 0079 `Game_Troop`、0087 `Game_Troops` 的楼层排列职责 | `$game_troops[map_id]`/当前楼层引用、`enemies/variety`、`enemy_check/ enemy_event`、`clear_enemies/load_enemies/update`；事件ID/坐标双索引、数据实例覆盖、随现场事件移动/移除更新 | `CustomDataState.gd` | 缓存中的数据引用不是完整Game_Enemy；构造/技能/伤害、潜伏/领域/夹击/退敌等玩法待0.45。原enemy_event按事件ID查坐标的缺陷已由适配查询修正 |
| 0083 `Game_Variables`、原`$data_*`和普通自定义数据 | 变量扩展为可保存标量/Array/类型化Hash；数据库只读原始定义与运行覆盖分开；嵌套修改和货币等统一事务提交/失败回滚；普通全局/常量树形数据可保存 | `ScriptStateBridge.gd`、`ScriptSemantics.gd`、`RuntimeData.gd`、`CustomDataState.gd`、`ScriptRuntime.gd`、`SaveCodec.gd` | 普通数据能力已扩展；循环/共享引用和自定义类对象仍拒绝保存，完整对象关系待0.47 |
| 原地图/公共事件注释及外部文件 | 保留200条原注释分组及位置/哈希、42份自定义文件原字节；提供项目数据、角色扩展属性草稿编辑和显式保存 | `CustomDataTags.gd`、`data/custom_data.json`、`legacy/custom_data`、编辑器相关数据页 | 保留原文/标签不表示标签玩法或显示效果已迁移；原Ruby编辑后重新转换仍待0.48 |

以上“服务已实现”有相关数据运行、事务、菜单/编辑器、存读档专项证据；未对每个原方法逐一证明完整游戏流程。正式适配登记有11条带原方法位置的记录，列于附录；属性声明生成的访问器等支持另按实际字段列出，不能由11条记录推算整库覆盖率。

## 0.44新增的事件接入

相对0.43新增的11个实际绑定均在公共事件中，原地图绑定保持21个。

| 公共事件 | 新绑定片段 | 新接入的脚本内容 | 功能边界 |
| --- | --- | --- | --- |
| 9 `使用物品处理` | `event_000058`、`event_000063` | 开始/结束时写入`interpretering`，恢复`shotcut_enabled` | 其他物品处理和`$mapdamage_obj.refresh`依赖未完成，不能标整个公共事件9可用 |
| 17 `每层的并行处理内容` | `event_000074` | 修改敌人33/34名称、26/27攻击/防御的数据库运行覆盖 | 已生成并绑定；完整怪物/战斗行为仍待0.45，不将数据库写入当作战斗迁移 |
| 21 `★初始化★` | `event_000075/000076/000078/000079/000080/000081` | 六个系统字段写入 | 数据字段接通；可见HUD/快捷键等仍待后续表现层 |
| 23 `事件名驱动` | `event_000082`、`event_000083` | 读取`interpretering`的111条件、关闭`shotcut_enabled`的355脚本 | 后续正则捕获、事件名分派、物品/战斗调用尚未完成 |

另新增 `event_000007`、`event_000020` 两个条件的生成结果，但未形成实际绑定；新增库单元0085 `Game_Actors`也只有生成状态，不能标为完整角色注册表迁移。

## 已确认的未完成项

1. 完整`BattleSystem/SkillRegistry`、角色/怪物派生属性、结算、物品效果、成长、回路、BOSS战、窗口和剧情演出仍在0.45—0.47清单中。
2. 已绑定的 `GameEngine::Screen.Voiceover` 调用仍可能因GameEngine未迁移失败；生成/绑定不证明目标接口可用。仅生成但未绑定的片段见下表，不能作为原事件已接通的证据。
3. `POTION_ITEM_ID/GEM_ITEM_ID`后续逐项赋值尚未导入，是0.44迁移缺口，纳入0.45基础预设补迁。源配置的Enemy/Deputy文件缺失则是另一类来源缺口，不能混淆。
4. 闪翼原路线45在两版都为0个可用绑定；运行接口存在，原路线内容仍待转换。
5. 原注册表的`runtime_verified`保留false；单独验证过的方法/能力以测试证据说明。不因这些数字提前宣布脚本库功能完成。

## 验证依据与定位方式

- [0.43验证记录](../tests/VERIFICATION_v0.43.md)：事件入口/上下文/失败/恢复，原始地图`event_000106`，真实`Skill 3`方法，最终事件绑定与源码审计。
- [0.44验证记录](../tests/VERIFICATION_v0.44.md)：最终数据运行33项、数据编辑13项以及原事件回归；覆盖KIN/耀晶石、`tp_plus`、数据库覆盖、集合事务、楼层索引/移动/移除、菜单和存读档等。
- 可读取的逐项快照为同目录 `FLASH_SCRIPT_CHECKLIST_v0.43_v0.44.json`：包含339个库脚本、144个事件片段的两版状态，8个数据表达式、11条服务适配登记及实际目标路径。
- 生成代码来源仍查各导出工程的 `data/script_source_map.json`；服务适配查 `data/custom_data.json.adapters`。生成文件中的`env.define_method`记录原方法及实际GDScript函数名。

## 生成库单元逐项清单

以下只列确实存在的生成文件；“仅生成”不表示完整可运行。这一层与上面的数据/服务适配分别统计。

<!-- FLASH_IMPLEMENTED_APPENDIX -->

| 原库编号/名称 | 0.43 | 0.44 | 实际方法/生成内容 | 状态说明 |
| --- | --- | --- | --- | --- |
| 0006 [全局定义](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0006_全局定义.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0006.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0006.gd>) | 赋值/类声明，无显式方法 | 常量/全局赋值的生成结果；全局启动链未接管。 |
| 0041 [Game_Temp](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0041_Game_Temp.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0041.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0041.gd>) | initialize；attr_addition_clear | 类方法生成；原$game_temp与原生事件现场的完整字段绑定尚未接通。 |
| 0064 [Skill 3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0064_Skill 3.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0064.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0064.gd>) | real_time_readdition | real_time_readdition独立真实调用已验证；完整Skill系统未完成。 |
| 0082 [Game_Switches](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0082_Game_Switches.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0082.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0082.gd>) | initialize；[]；[]= | 原类代码生成；全局开关实际运行通过已有状态桥接。 |
| 0083 [Game_Variables](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0083_Game_Variables.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0083.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0083.gd>) | initialize；[]；[]= | 原类代码生成；变量桥接另在0.44扩展为集合。 |
| 0085 [Game_Actors](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0085_Game_Actors.rb>) | 未生成 | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0085.gd>) | initialize；[] | 0.44新增生成；Game_Actor依赖未完整迁移，不能据此标完整注册表可用。 |
| 0088 [Game_Blastics](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0088_Game_Blastics.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0088.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0088.gd>) | initialize；[] | Game_Blastic依赖未完成，不能据此标结晶回路可用。 |
| 0279 [Scene_BossBattle 2](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0279_Scene_BossBattle 2.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0279.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0279.gd>) | set_windows；update_windows；dispose | 其他Scene_BossBattle定义和窗口/管理器未完成，不能据此标BOSS场景可用。 |
| 0292 [Window_BDetail](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0292_Window_BDetail.rb>) | [生成GD](<D:/Dev/Godot_Trans/output/0.43/delivery/黎之闪翼（开发中）_Godot/runtime/generated/script_0292.gd>) | [生成GD](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/script_0292.gd>) | 赋值/类声明，无显式方法 | 只有类声明；Window_Base依赖未完成，不能据此标窗口可用。 |

## 事件片段逐项清单

以下列出两版至少一版已生成的46个片段，包含仅生成未绑定项；全部144个片段的状态与原文在JSON中。所有原注册表的runtime_verified仍为false。

| 单元与0.44生成源码 | 原事件位置 | 原文摘要 | 0.43 | 0.44 |
| --- | --- | --- | --- | --- |
| [event_000007](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000007.gd>) | 公共事件2 加减血，指令3 | `$game_system.potion_itemization` | 未生成 | 仅生成 |
| [event_000016](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000016.gd>) | 公共事件2 加减血，指令40 | `_main_actor.dead?` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000020](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000020.gd>) | 公共事件3 加减攻防，指令3 | `$game_system.gem_itemization` | 未生成 | 仅生成 |
| [event_000027](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000027.gd>) | 公共事件3 加减攻防，指令34 | `_main_actor.dead?` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000043](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000043.gd>) | 公共事件6 路障处理，指令8 | `_main_actor.add_state(POISON_STATE_ID)` | 仅生成 | 仅生成 |
| [event_000045](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000045.gd>) | 公共事件6 路障处理，指令13 | `_main_actor.add_state(WEAK_STATE_ID)` | 仅生成 | 仅生成 |
| [event_000047](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000047.gd>) | 公共事件6 路障处理，指令18 | `_main_actor.add_state(SLOW_STATE_ID)` | 仅生成 | 仅生成 |
| [event_000051](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000051.gd>) | 公共事件6 路障处理，指令29 | `_main_actor.add_state(POISON_STATE_ID) / _main_actor.add_state(WEAK_STATE_ID) / _main_…` | 仅生成 | 仅生成 |
| [event_000053](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000053.gd>) | 公共事件6 路障处理，指令37 | `_main_actor.maxhp = 1` | 仅生成 | 仅生成 |
| [event_000058](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000058.gd>) | 公共事件9 使用物品处理，指令1 | `$game_system.interpretering = true` | 未生成 | 已生成、已绑定 |
| [event_000062](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000062.gd>) | 公共事件9 使用物品处理，指令13 | `$mapdamage_obj.refresh` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000063](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000063.gd>) | 公共事件9 使用物品处理，指令15 | `$game_system.shotcut_enabled = true / $game_system.interpretering = false` | 未生成 | 已生成、已绑定 |
| [event_000074](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000074.gd>) | 公共事件17 每层的并行处理内容，指令1 | `$data_enemies[33].name=\ / "小巫师:!怪物034!035-Monster05!8!0!" / $data_enemies[34].name=\ …` | 未生成 | 已生成、已绑定 |
| [event_000075](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000075.gd>) | 公共事件21 ★初始化★，指令20 | `$game_system.show_playerdata = true` | 未生成 | 已生成、已绑定 |
| [event_000076](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000076.gd>) | 公共事件21 ★初始化★，指令22 | `$game_system.show_mapname = false` | 未生成 | 已生成、已绑定 |
| [event_000077](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000077.gd>) | 公共事件21 ★初始化★，指令33 | `$floorenemies=[] / $fledam=[] / #上面这两个用来记录每层的怪物` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000078](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000078.gd>) | 公共事件21 ★初始化★，指令37 | `$game_system.shotcut_enabled = true` | 未生成 | 已生成、已绑定 |
| [event_000079](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000079.gd>) | 公共事件21 ★初始化★，指令39 | `$game_system.mdef_available = true` | 未生成 | 已生成、已绑定 |
| [event_000080](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000080.gd>) | 公共事件21 ★初始化★，指令41 | `$game_system.speed_available = true` | 未生成 | 已生成、已绑定 |
| [event_000081](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000081.gd>) | 公共事件21 ★初始化★，指令43 | `$game_system.show_greenkeys = true` | 未生成 | 已生成、已绑定 |
| [event_000082](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000082.gd>) | 公共事件23 事件名驱动，指令1 | `$game_system.interpretering` | 未生成 | 已生成、已绑定 |
| [event_000083](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000083.gd>) | 公共事件23 事件名驱动，指令7 | `$game_system.shotcut_enabled = false` | 未生成 | 已生成、已绑定 |
| [event_000097](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000097.gd>) | 公共事件31 介绍物品一，指令1 | `GameEngine::Screen.Voiceover` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000098](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000098.gd>) | 公共事件31 介绍物品一，指令3 | `GameEngine::Screen.Voiceover(false)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000103](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000103.gd>) | Map001 / 事件12 / 页1 / 指令1 | `Storage::box_in_place?` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000104](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000104.gd>) | Map002 / 事件1 / 页2 / 指令6 | `$game_variables[124]={}#记录再生怪物 / $game_variables[125]={}#记录再生怪物 / $game_variables[133]…` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000105](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000105.gd>) | Map002 / 事件1 / 页2 / 指令12 | `_main_actor.maxhp = 300 # 生命 / _main_actor.maxsp = 0  # 精力 / _main_actor.hp = 150 / _m…` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000106](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000106.gd>) | Map003 / 事件26 / 页1 / 指令1 | `$game_variables[2]=0 / #上一句是把楼层名改成0层 /  / #或者像pk魔塔那样，把隐藏层设成固定楼层， / #比如81层、82层等，这样的好处是可…` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000110](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000110.gd>) | Map022 / 事件3 / 页1 / 指令2 | `GameEngine::Screen.wake / true` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000111](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000111.gd>) | Map022 / 事件3 / 页1 / 指令5 | `GameEngine::Screen.set_rect(1)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000112](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000112.gd>) | Map024 / 事件27 / 页1 / 指令1 | `GameEngine::Screen.wake` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000114](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000114.gd>) | Map024 / 事件28 / 页1 / 指令1 | `Actor_Init.load(2)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000116](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000116.gd>) | Map024 / 事件1 / 页1 / 指令1 | `GameEngine::Screen.set_rect(0)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000119](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000119.gd>) | Map024 / 事件2 / 页1 / 指令1 | `GameEngine::Screen.set_rect(1)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000124](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000124.gd>) | Map024 / 事件31 / 页1 / 指令1 | `GameEngine::Screen.freeze` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000128](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000128.gd>) | Map025 / 事件8 / 页1 / 指令1 | `GameEngine::Screen.set_rect(0)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000130](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000130.gd>) | Map025 / 事件8 / 页1 / 指令50 | `GameEngine::Screen.Voiceover` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000131](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000131.gd>) | Map025 / 事件8 / 页1 / 指令56 | `GameEngine::Screen.Voiceover(false)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000133](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000133.gd>) | Map025 / 事件8 / 页1 / 指令88 | `GameEngine::Screen.freeze` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000134](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000134.gd>) | Map025 / 事件8 / 页1 / 指令90 | `GameEngine::Screen.Unravel` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000136](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000136.gd>) | Map027 / 事件7 / 页1 / 指令7 | `$game_variables[5][8] = 1 / true` | 仅生成 | 仅生成 |
| [event_000137](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000137.gd>) | Map027 / 事件24 / 页1 / 指令1 | `Actor_Init.load(3)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000139](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000139.gd>) | Map027 / 事件9 / 页1 / 指令1 | `Actor_Init.load(2)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000141](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000141.gd>) | Map038 / 事件6 / 页1 / 指令1 | `Actor_Init.load(2) / Actor_Init.load(3) / Actor_Init.load(4) / Actor_Init.load(5)` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000142](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000142.gd>) | Map038 / 事件6 / 页1 / 指令6 | `$scene = Scene_BossBattle.new` | 已生成、已绑定 | 已生成、已绑定 |
| [event_000143](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/event_000143.gd>) | Map038 / 事件8 / 页1 / 指令1 | `Actor_Init.load(2)` | 已生成、已绑定 | 已生成、已绑定 |

## 0.44带原方法位置的服务适配登记

getter/属性声明和运行字段另见前面的能力表，此表只列正式manifest中的11条方法记录。

| 原脚本/方法 | 原行 | 目标服务源码 |
| --- | --- | --- |
| [0078 Game_Party.gain_currency](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0078_▲Game_Party.rb:151>) | 151 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0078 Game_Party.gain_kin](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0078_▲Game_Party.rb:174>) | 174 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0078 Game_Party.lose_kin](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0078_▲Game_Party.rb:181>) | 181 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0078 Game_Party.gain_spar](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0078_▲Game_Party.rb:190>) | 190 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0078 Game_Party.lose_spar](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0078_▲Game_Party.rb:198>) | 198 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0079 Game_Troop.enemy_check](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0079_Game_Troop.rb:138>) | 138 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0079 Game_Troop.enemy_event](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0079_Game_Troop.rb:147>) | 147 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0079 Game_Troop.clear_enemies](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0079_Game_Troop.rb:43>) | 43 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0079 Game_Troop.load_enemies](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0079_Game_Troop.rb:66>) | 66 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0079 Game_Troop.update](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0079_Game_Troop.rb:156>) | 156 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |
| [0037 DataBase.get_floor_type](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0037_DataBase.rb:71>) | 71 | [CustomDataState.gd](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/scripts/CustomDataState.gd>) |

## 0.44实际生成的数据表达式

这8项的实际输入是字面量或数组，不能按8个文件计算为8条复杂玩法公式已移植。

| 单元 | 原文件/行 | 记录字段 | 表达式 |
| --- | --- | --- | --- |
| [data_00001](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00001.gd>) | Data/Items.exdata:9 | Items[1].animation1_id | `0` |
| [data_00002](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00002.gd>) | Data/Items.exdata:10 | Items[1].animation2_id | `0` |
| [data_00003](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00003.gd>) | Data/Items.exdata:11 | Items[1].scope | `0` |
| [data_00004](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00004.gd>) | Data/Items.exdata:12 | Items[1].occasion | `3` |
| [data_00005](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00005.gd>) | Data/Items.exdata:13 | Items[1].common_event_id | `0` |
| [data_00006](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00006.gd>) | Data/Items.exdata:14 | Items[1].consumable | `false` |
| [data_00007](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00007.gd>) | Data/Weapons.exdata:13 | Weapons[1].resist_table | `[0,0,0 ]` |
| [data_00008](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/runtime/generated/data_00008.gd>) | Data/Armors.exdata:13 | Armors[1].resist_table | `[0,0,0]` |

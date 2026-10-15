# 0.45 闪翼玩法迁移与 GDScript 源码结构

2026-10-13。按原清单迁移玩法计算、普通战斗、结算、地图物品/伤害、成长与场景业务。正式原RM输出与检查记录见[验证记录](../tests/VERIFICATION_v0.45.md)。0.46接入自定义页面、文本、地图表现与半成品地图，0.47接入完整对象关系及持久化。用户决定脚本功能完成后整体验收；本阶段不等同全部自定义Ruby已经迁移。

仅匹配闪翼实际加载的Data/Scripts.rxdata，339个槽位、144个原事件片段；SHA256为22763e029aa1b52a96ac24355909e3daf4a5c9c23940ae1c36cfbff2fe6233cf。原工程及历史输出只读，源Ruby未执行。0274—0308特殊BOSS战按用户要求排除。镜像六处差异保留，以rxdata为准。

## 后续开发入口

迁移器的`templates/runtime/scripts/`成为生成工程的`runtime/scripts/`。这些GDScript是实际运行实现，可直接继续开发。预设数据在`data/flash_gameplay.json`，原具体技能已生成`runtime/generated/flash_skill_catalog.gd`；新增、修改普通技能从`source_skills()`或注册表DSL开始。[战斗结构与扩展示例](FLASH_BATTLE_GDSCRIPT_v0.45.md)说明两种入口和原公式。

`RuntimeState`是唯一游戏状态入口。`FlashActorState`继承`ActorState`，持有角色身份、HP/SP、状态和六类装备；`project_fields`与`CustomDataState.values.actors`共享同一份扩展字段。`FlashEnemyState`绑定楼层既有entry，不另建怪物注册表。0072最终覆盖后的战斗HP与继承方法使用的旧HP是原代码的两个不同字段，按原职责保留。

`FlashGameplay`组合模拟器、职位、缓存及开战/结算；模拟器只做脱离现场的预测。`FlashActions`提供GDScript业务入口，使用`ScriptRuntime`的同一事务。所有校验通过后统一安装角色、变量、背包、数据库覆盖和人物变更，再通知；失败回滚。首次创建角色和读档后的查询引用指向正式状态。

原事件生成源码在`runtime/generated/event_*.gd`，原库生成方法在`script_*.gd`。`data/script_source_map.json`定位这些生成方法，`data/script_units.json`保留诊断与状态。人工适配对应下表；生成数量或`method_sources`的解析位置不是行为完成证明。

## 原 RM 到 GDScript 的对应

每行只列本阶段方法职责。同一文件里的窗口、绘图、通用文件执行或对象身份仍按后续任务处理。

| 任务与原加载序号 | 实际源码入口 / 主要方法 | 行为与阶段边界 |
| --- | --- | --- |
| 45-01：0003/0005/0006；0018/0019/0021/0024；0034/0037；0040/0315 | `ScriptSemantics.read_name/invoke/index_get/index_set`、`CustomDataState.named/record/floor_tree_map`、`FlashUtils.invoke/integer_text`、`FlashValueExtensions` | ID逐项赋值、Ruby真值/类型/集合/数值、正则捕获、各角色/事件绑定、数据库覆盖、混合键maptree、距离/区域/查事件。绘图、地图树重建、DeepClone及对象图归0.46/0.47。 |
| 45-02：0053—0057、0086 | `FlashObjectCatalog.construct/value/equipment_ref/class_name_for/is_a`；外部设置提取 | 四类构造、getter、alias、职业集、nil/false回退和ID0默认。[逐方法表](FLASH_OBJECTS_AUDIT_v0.45.md)。缺少Game_Deputy/Deputy.exdata明确诊断；通用文件构造和对象身份归0.47。 |
| 45-03：0065—0071、0085 | `FlashBattlerRules.parameter/resist/change/query`；`FlashActorState.set_project_parameter/add_project_state/reset_project_all/periodic_damage/equip_project/trans_project_skill/swap_project_skills`；`FlashEnemyState.input/invoke` | 八项派生属性、五分量抗性、状态顺序/关联/强制/HP副作用、小数backing值、六槽装备、技能配置组、怪物技能/元素/掉落及参数表。角色/怪物共享正式状态，非法操作整体拒绝。 |
| 45-04：0060/0061、0062/0064 | `FlashGameplayImporter`→storage；`FlashGameplay.invoke(Storage)`；`FlashBattleCatalog` | 经验/技能参数、7条描述和1条简述保持原文。旧Skill无有效include/extend入口，保留定义/诊断，不声称旧算法全改写。[调用及方法审计](FLASH_LEGACY_AUDIT_v0.45.md)。 |
| 45-05：0072/0073 | `FlashBattleSkillDefinition/Registry/Catalog/StateContainer/Simulator/Cache` | 13个真实预设、注册/替换、被动、主战/援护、连击/追击/反击/计数、狂暴、DOT/叠层/窗口、时间线/耐心/80次上限、缓存扩展和失效。[完整源码结构](FLASH_BATTLE_GDSCRIPT_v0.45.md)。 |
| 45-06：0072、0078、0096 | `FlashGameplay.role_ids/party_snapshot/predict/begin_battle/finish_battle`；`CustomDataState.party_call`；`FlashMapBridge` | 固定一次开战结果，敌人先扣HP，原CE2扣角色HP后结算；战斗不能/接替/休息、队伍/货币/经验/永久死亡。状态身份加入缓存tag；开始/结束不重复奖励。 |
| 45-07：0079/0087、0098、0104 | `CustomDataState._floor/rebuild_floor_indices`；`FlashEnemyAbilities/FlashMapDamage`；`FlashMapBridge.refresh_damage`；`PlayerController` | 潜伏/领域/夹击/退敌/中毒按原顺序与MAXHP公式；真实普通走格只结算一次，强制路线不计步行伤害；怪物读当前数据库。伤害绘制/奔跑/遮罩归0.46。 |
| 45-08：0052、0091、0193、0263 | `FlashItemEffects.invoke/_map_effect`、`FlashMapBridge.read_tile/write_tile`、`FlashCharacterBridge.invoke/commit`；生成0193/0263/门宏 | 药水/宝石/解状态、墙/冰/冰冻/地震/对称飞行/炸弹/圣锤/巨钥匙；巨钥匙执行原公共事件和原生路线。五个源空工具保持nil/不消费。[方法表及缺口](FLASH_OBJECTS_AUDIT_v0.45.md)。 |
| 45-09：0317/0318、0060/0068/0078 | 生成`script_0317.gd/script_0318.gd`；`FlashActorState.next_level_experience/set_experience/set_level` | 初始化写同一角色；经验与自动升级分开，原CE14判定/增量/消息请求。经验末表nil错误加守卫，阈值和公式保持。消息绘制归0.46。 |
| 45-10：0088、0212—0214、0068 | `FlashBlastic.record/invoke/exchange/validate`；`FlashActions.exchange_crystal` | ID0原力器、两条链、孔位/锁/限制、装卸替换、背包交换、元素合计和回响阈值，操作一次提交。源plus_element为空/minus转调空方法照实保留。显示归0.46。 |
| 45-12：0200/0202、0254—0259 | `FlashActions`的职位/物品/装备/技能/配置/选择入口；`InventoryService/ShopService` | 公开RuntimeState.use_item使用原0193公式与扣减；工具预约CE9不提前消费。楼层/角色选择仅写原变量，不擅自传送/换角；商店共享状态/原子提交。窗口/输入/生命周期归0.46。 |
| 45-13：原CE1/2/3/4/6/7/9/11/12/13/14/17/21/23及调用地图 | `ScriptEventIntegrator/ScriptSemantics/EventInterpreter/FlashSourceCorrections`；原绑定`event_*.gd` | 完整原链的战斗/奖励/成长、血瓶/宝石、开门/路障/推箱、初始化、并行数据库更新、CE9消耗、结局请求/结束复位。CE11只有注释，保持该行为；Party.gain_item提示的绘制归0.46。 |
| 45-14：0075/0076、CE36 | 原历史定义；CE36迁移副本修正和原执行器 | 完整CE36→5/2/14存活/击败两支，双方HP各扣一次，旧耐心/奖励/升级保持；不另建旧战斗真值。[审计与33项证据](FLASH_LEGACY_AUDIT_v0.45.md)。旧RM Marshal档不在范围内。 |

45-11特殊BOSS战排除。清单JSON状态与本文同步；任务完成只表示表内阶段范围，不能推成同名原文件的所有方法完成。

## 原公式与确认修正

`data/source_corrections.json`登记迁移副本的原加载序号/公共事件/命令、行、原内容及目标方法。包括POITON/宝石/临时物品/门字段、无事件或非怪物的nil解引用、CE9标签、经验末表、CE36旧结果/角色、装备拼写/队伍接收者/武器动画、领域/退敌/元素拼写、门宏/圣锤/对称中心/数组抗性、回路孔锁/旧元素/返还溢出、对象缺块默认初始化及商店缺失装备背包接口。

保留影响数值的原实现：pdef取patk点数、mdef取matk点数、base_resist未累计装备抗性、Storage.potion修改MAXHP、Item.Recover恢复率不加/100、追击固定10%、命中小数先累计再截整，以及原药水/宝石ID冲突顺序。原未施加的回响战斗增幅不补写。

## 验证与后续验收

独立检查分别覆盖真实原数据、完整原事件执行器和刻意区分公式的合成输入。CommonFlow/LegacyFlow/GiantKeyFlow执行原命令链及原生地图、人物、等待服务，没有另写效果作为证据。对象、战斗核心、属性、地图效果、公开业务及回路另有专项；数量和正式输出见[验证记录](../tests/VERIFICATION_v0.45.md)。

本阶段检查不等同完整原剧情、所有页面及全部对象存档。下一阶段继续原0.46清单；半成品地图按已有发现/区域/连接/布局/预览/换图记录迁移，未设计内容单列。0.47完成共享/循环对象、现场引用和存档后，按用户决定再进行整体脚本验收。

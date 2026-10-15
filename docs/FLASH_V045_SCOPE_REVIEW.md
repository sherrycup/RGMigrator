# 闪翼0.45发布前范围复核

2026-10-13。独立只读复核339个原加载槽、144个原事件片段及当前模板中的玩法服务。匹配原`Scripts.rxdata`的0.44只读展开副本；原Ruby未执行。这里只判断0.45的13个非BOSS任务，不把0.46页面/半成品地图、0.47对象图/平台插件或已排除的RM旧存档列为本版缺口。

本轮发现的实际公共物品入口问题已经修复：`RuntimeState.use_item`经`InventoryService.use_item`进入Flash分派，恢复物品调用原生成0193 `Item.Recover`，工具进入原CE9预约。之前该公共入口仍使用原生恢复率除以100并截断HP，与源公式不同。根代理报告新增公开入口检查通过（FlashBusiness 25项）；当前源码已核对其分派。此前直接测试`FlashActions`不能证明公开入口正确，这次补齐了该接线。

当前检查没有发现另一项已确认会阻断原0.45玩法/事件/数据/业务的缺口。正式发布仍应以根代理最终模板、当前绑定/数据、必要回归及全新原RM迁移报告为准，不能用本表代替发布检查，也不能将各来源整文件计为已迁移。

## 13项的原方法与当前接线

| 任务 | 原方法/数据及调用依据 | 当前结构和复核结论 |
| --- | --- | --- |
| 45-01 基础语义与绑定 | 0005 `_s/_ss/_v/_actors/_main_actor/_attack_actor/_support_actors/_enemies/_map/_events/_this`；0018 `in?/to_param`；0019数组选择/向量运算；0021 `plus/minus/prod/===/to_opc`；0024多键Hash读取；0037 `maptree/get_floor_type`；0040初始化；0315几何/事件工具。实际事件主要调用CE3、CE7、CE23及地图属性服务。 | `ScriptSemantics`、`FlashValueExtensions`、`FlashUtils`、`CustomDataState`与迁移数据共同接入。`_main_actor`按操作角色索引，战斗主战/援护按变量14，不能混为同一个别名。`DataBase.maptree`已恢复混合[region,floor]/map_id键及原平铺I/P字段。`bwise/eval`仅原有限模式，未知表达式明确失败。`initialize/cre_maptree`运行时重新初始化和绘图/文件方法仍按46/47，不代表0037或0315整文件完成。 |
| 45-02 物品与装备对象 | 0053对象初始化/默认设置/外部文本；0054全部物品getter；0055—0057数值/抗性/分类/描述getter；0086二索引有限类型分派。 | `FlashObjectCatalog.construct/object_ref/equipment_ref/value`、`CustomDataImporter`以及`CustomDataState` typed ref。已检查Ruby的0真值、false回退、ID0默认对象、999装备缓存上限、分类和饰品默认值。源`Game_Deputy`和`Deputy.exdata`确实缺失，给来源诊断；不能用示例`Deputies.txt`补造实现。 |
| 45-03 角色/怪物属性与状态 | 0065八项getter/setter、五分量抗性、HP/SP；0066状态排斥/force/关联/排序/清除/查询；0067 `periodic_damage`；0068技能槽/配置/转移交换/原力器引用；0069原派生公式；0070—0071怪物配置/技能/元素/掉落/奖励。 | `FlashActorState`、`FlashActorFields`、`FlashBattlerRules`、`FlashEnemyState`及`CustomDataState`入口。当前实现保留浮点角色HP/SP，0072最终怪物HP/耐心覆盖取整数，独立旧backing HP与当前战斗HP；增量setter、强制状态、关联/查询、周期伤害及技能交换均有对应实现和针对性检查。原pdef/patk、mdef/matk和未累计装备抗性公式保留。怪物`drop_table`未配置时仍返回nil，不虚构掉落。 |
| 45-04 技能预设与旧接口 | 0060 `actor_exp_next/actor_init_exp/actor_init_animation/install_skill_parameters`；0061 `skill_description/skill_easy_description`；0062/0064旧Skill闭包。 | 原表与参数提取，全部7+1文本逐条检查；13个现行技能由0072/0073迁移。旧Skill有效调用/反射及历史入口已独立审计；没有有效include/extend旧Skill的普通循环，原定义仍保留，不能称所有旧闭包已经改写。详见历史审计。 |
| 45-05 当前普通战斗 | 0072 `SkillDefinition/SkillRegistry/AttributeCalculator/StateContainer/Timeline/TargetResolver/FollowUpResolver/Simulator/Cache`，0073实际注册。 | `FlashBattleSimulator`、`FlashBattleSkillDefinition`、`FlashBattleRegistry`、`FlashBattleStateContainer`、`FlashBattleCache`及生成`flash_skill_catalog.gd`。读取同一注册字典；GDScript修改原13定义可生效；注册修订、额外条件、不可用援护的原缓存输入、行动循环/追击/目标/狂暴均有明确实现。不能把源码提取的`method_sources`当运行验证。 |
| 45-06 普通战斗结算与队伍 | 0072 `begin_battle!/pending_battle_result/finish_battle!`、`PartyRoles/EventSettlement`；0078队伍、货币、经验；0096永久死亡。原CE1先开战、动画等待，再扣角色HP/finish，死亡分支给予奖励。 | `FlashGameplay`、`CustomDataState`、`ScriptRuntime`事务和原生成CE1。敌人HP开战时扣一次，原脚本角色扣血后提交结算；支持战斗不能、角色接替、休息恢复及缓存清除；EXP/金币在同一原奖励片段事务内提交。并非用旧Battle_Data计算。 |
| 45-07 地图怪物效果 | 0070 `load_skills`地图参数；0079双向怪物位置/事件索引和`update`；0098 `poison/hide/manor/cotack/hook_deal`；0104 `refresh_damage`。 | `FlashEnemyAbilities`、`CustomDataState._floor/_update_floor/rebuild_floor_indices`、`FlashMapDamage`和`FlashMapBridge`。普通原生玩家到达接`FlashActions.after_step`；强制路线排除。原MAXHP伤害及先X/Y比例再固定伤害保留；原拼写/nil阻击护栏已修。旧`hide_enemies`等返回方法合并为原生indices服务；这里应登记该结构变化，不能因为没有同名函数就认定计算未迁移，也不能称整0079已移植。 |
| 45-08 地图物品效果 | 0052 `Storage.use_item`及13个特殊物品/药水/宝石/解状态分派；0193 `Item.Recover`；0263 `Item_calc`；0091开门宏及0043事件页修改。 | `FlashItemEffects`、`FlashMapBridge`、`FlashCharacterBridge`、原生成0193/0263及`derived_0091_door_die`。拆开Storage药水MAXHP效果和Item.Recover当前HP/SP恢复。源上/下楼、随意门等5个空分支保持nil且不扣物品。大黄门钥匙完整安装/原强制路线/子事件/尾部死亡有独立链路检查；不直接修改原地图/公共事件定义。 |
| 45-09 初始化与成长 | 0317 `Actor_Init.load`、0318 `Level_Up.level_up`，0060经验/动画表；公共事件14原判定。 | 原生成0317/0318与同一actor draft；普通经验累加不自动升级。CE14阈值用尽时停止，已记录来源修复。原Actor1等级2增量保留，原其他空等级分支只执行原level增加。原始消息字段写入保留，文本显示按0.46。 |
| 45-10 结晶回路 | 0088 ID索引、0212/0213预设、0214孔锁/装备/卸下/元素，0202背包交换；0217/0219/0221限制/回响计算。 | `FlashBlastic`与`FlashActions.exchange_crystal`：两链、孔锁、功能重复限制、替换旧元素与背包回收原子提交；原力器0完整，缺孔位的其他原预设给来源诊断。角色引用保留同一ID。原`plus_element`为空，不补战斗增强；回响表/预览计算不代表原代码存在额外数值施加。 |
| 45-12 场景业务 | 0200 `switch_battle_roles/item_use`；0202恢复/工具/回路交换；0254/0255选择及取消；0258 `equip`；0259价格/半价/数量交易；0257技能配置相关的0068方法。 | `FlashActions`、`InventoryService`、`RuntimeState.use_item`、`ShopService`的Flash事务分派。公开物品入口已修；选择写原变量13/12并保持源取消值；装备调用六槽源setter而非原生五槽规则；Shop在ScriptRuntime事务内重新报价/暂存付款/物品增减及源提示/手册刷新。原0258没有额外背包交换，不能擅自补成原生equip交换。窗口/按键/场景返回仍归0.46，选择和交易服务须纳入根代理最终测试。 |
| 45-13 原事件闭环 | 公共事件1/2/3/4/6/7/9/11/12/13/14/17/21/23及其地图调用；正则捕获、typed宝石表达式、command_117父子调用、box移动后读取坐标。 | 当前私有源数据中的这些目标共有106个脚本片段，均已生成；Common11只有原注释无脚本，不能发明物品奖励。`FlashCommonFlowTests`以真实Game/Map/Player/Interpreter验证完整原命令链，其他专项检查地图效果/大黄门钥匙。144个原事件中143个生成；唯一未生成event_000127是Map024 EV032的Message::TextRow自定义文本测试，属于0.46消息页面且诊断保留，不是玩法计算已完成的证据，也不是本版普通事件闭环的阻断。 |
| 45-14 历史审计 | 0075/0076、0074注释旧循环、0234注释窗口、原公共事件36。 | 已核实静态调用、有限反射和编辑器117入口。CE36遗留battle_data/旧角色变量修复为同一当前预测和主战，完整原36→5/2/14两支33项检查通过，双方HP各扣一次。历史定义/方法源码继续保留；不迁移RM旧Marshal档，不把旧类当新核心。 |

## 本次实际发现与发布边界

- **已修复的本版接线缺口**：公开`RuntimeState.use_item → InventoryService.use_item`之前没有Flash分派，导致恢复率/100和浮点截断；当前先路由源`Item.Recover`或CE9工具预约，公开接口与独立Flash业务使用同一状态和公式。
- **源缺失与未设计行为**：副手类/数据、其他原力器不完整预设、5个Storage空分支、未配置怪物掉落应继续带来源状态；这些不能被补值后标为成功，也不能把源空分支列为迁移漏实现。
- **后续范围**：页面、消息码、绘图/演出、半成品地图整体发现/布局/区域/换图、数据库树运行时重新初始化属于0.46；共享/循环对象、全部持续执行状态、撤回、平台/视频等属于0.47。不是0.45普通计算闭环的缺口。
- **源码结构边界**：许多原getter、队列和小工具合并到native typed ref服务；应列方法/数据对应而非整脚本打勾。后续新增GDScript沿`FlashActions`、`FlashBattleRegistry/SkillDefinition`、`FlashGameplay`及共享RuntimeState开发，不新增第二份角色/背包/战斗真值。
- **运行证据边界**：本次主要是代码与调用审查，沿用明确的已有专项测试记录；本人独立执行的历史链检查是33项。根代理正在实施的最新选择/商店改动仍须完成其专项检查和最终正式迁移。本文件不冒充额外全剧情、页面或正式发布验证。

历史接口的精确方法/属性、文件哈希和调用来源见[FLASH_LEGACY_AUDIT_v0.45.md](D:/Dev/Godot_Trans/RGMigrator/docs/FLASH_LEGACY_AUDIT_v0.45.md)及同名JSON。当前源码仍在开发，最终0.45状态以实施记录/发布清单为准。

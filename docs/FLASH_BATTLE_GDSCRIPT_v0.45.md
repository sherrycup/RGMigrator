# 闪翼普通战斗的 GDScript 对应

本表仅说明 0.45 普通战斗核心的实际实现和针对性检查，不表示 0.45 整版交付。源文件按 `Scripts.rxdata` 加载序号 0072 `BattleSystem`、0073 `SkillRegistry` 对照；0274—0308 特殊 BOSS 战按用户要求排除。

| 原 Ruby 职责 | GDScript 源码 | 当前对应行为 |
| --- | --- | --- |
| SkillDefinition、RageDefinition、RageRule | `templates/runtime/scripts/FlashBattleSkillDefinition.gd` | display/action/追击/反击/被动/额外段、狂暴门槛及 Grant/Override 构建 |
| SkillRegistry | `templates/runtime/scripts/FlashBattleRegistry.gd` | 同 ID 整份替换、revision、查询/分类、运行时数据库同步字段；模块注册跨脚本事务复用 |
| 0073 真实 13 项预设 | `FlashGameplayImporter.gd` → `runtime/generated/flash_skill_catalog.gd` → `FlashBattleCatalog.gd` → Registry.configure | 实际生成可编辑 GDScript；原 ID 0、40—46、61、62、81、101、121 的名称、参数、标签和目标，原文中的注释示例不当作真实注册 |
| BattleStatus、StateContainer | `templates/runtime/scripts/FlashBattleStateContainer.gd` | 临时状态倍率乘算/加值相加、DOT、叠层、持续窗口；与角色持久数据库状态分开 |
| AttributeCalculator、BattlerRuntime、Timeline、TargetResolver、FollowUpResolver、Simulator | `templates/runtime/scripts/FlashBattleSimulator.gd` | 主战/敌人时间轴；援护只反应；主动→反应→DOT→状态计时→重新排程→行动上限；预估脱离现场 |
| EnemySkillEntry、EnemySkillSet、EnemySkills | `FlashBattleSimulator.resolve_enemy_skills` | 原身份/来源、条件/优先度、严格耐心门槛、高门槛先应用、已持有不重复 Grant、原 ID 连续 Override、visible_entries、attack_rate |
| Cache.register_condition、tag_for、with_party_snapshot | `templates/runtime/scripts/FlashBattleCache.gd` | GDScript Callable 扩展、输入值快照、仅限只读批次的短期缓存、禁止把游戏对象作为条件返回 |
| PartyRoles、EnemyState、EventSettlement、begin/finish | `FlashGameplay.gd`、`FlashEnemyState.gd`、`FlashActorState.gd` | 属于同一共享事务的角色职位、敌人真实 HP/耐心及公共事件结算；本表不替代完整事件闭环验收 |

普通战斗的公式继续遵循原源码：每段 `max(物攻 × 倍率 − 防御, 0)` 以 Float 累加后取整数；额外段按 100% 物攻另算。追击执行器固定读取本窗口伤害的 10%，不自行把注册里的 rate 改成其他比例。攻击计数追击始终观察主战；援护反击观察主战受击段数，零伤害段也计数。固定 ENEMY 目标的技能给敌人使用时打敌人自身。主动行动上限仍为 80；同延时时间轴保持此前排序结果。

生成工程的 `runtime/generated/flash_skill_catalog.gd` 是原 13 项技能的具体 GDScript 源码入口，`static source_skills()` 返回各 ID 的定义 Dictionary，每项保留原来源注释。可以在该文件修改现有定义、加入技能，再重新启动游戏。`INPUT_SHA` 标识迁移前的提取值，修改技能时保留它；仅原输入匹配时启用该目录，其他独立规则不会被它覆盖。目录返回类型错误会明确拒绝运行。

后续 GDScript 开发也可以通过同一个注册表创建、替换普通技能：

```gdscript
var result = gameplay.simulator.define_skill(201, func(skill):
	skill.display("蛮力", "自身物攻提高20%。")
	skill.passive_attack_rate(1.2)
)
if not result.ok:
	push_error(result.message)

gameplay.simulator.define_skill(300, func(skill):
	skill.display("狂暴：示例")
	skill.rage(func(rules):
		rules.when_patience_below(3, "获得蛮力。", func(effect):
			effect.add_skill(201)
		)
	)
)
```

注册不等于给角色或敌人装备；角色技能配置、敌人 action 数据仍走对应业务入口。狂暴引用可以稍后注册，但模拟/数据库同步前必须整体校验。原没有治疗、通用 buff 或通用 effect 注册接口，本次没有创造这些新技能效果。

`simulator.build_context` 对应原 Simulator.build_context；扩展 GDScript 可以覆写它，并用 `context.main.state_container.add(FlashBattleStateContainer.create_status(...))` 添加原容器能表达的临时状态。DOT 在行动使用者自己的第三结算阶段执行，首次计时不减窗口，nil 持续窗口永久保留。伤害先乘叠层再由 receive_damage 取整数，日志保留原 DOT 数值。

Cache 与 Registry 的注册项是模块进程状态，Callable 不进 JSON 存档。普通事务 fork 重建 Gameplay 后仍共享原注册；更换提取的 catalog 时 Registry 重装。缓存 tag 要使用原职位输入（包括暂时战斗不能的援护），计算时再用 PartyRoles.snapshot 剔除无法参战者。RuntimeState 退出时释放 Cache providers，避免 GDScript lambda 保留退出中的脚本上下文；新游戏和普通事务不清注册。

`tests/runtime/FlashBattleCoreTests.gd` 检查全部 13 真实技能的公式/目标/硬直或反应、GDScript 注册、狂暴和来源、状态容器真实第三阶段、缓存扩展及批次失效。`FlashBattleCatalogTests.gd` 在私有夹具临时修改并原样恢复生成目录，检查 GDScript 修改启用、原输入不匹配回退、非法返回拒绝和缓存跨真实事务复用。上述输入刻意用小数、零伤害、缺援护、相同延时和低耐心区分顺序及公式，不能替代完整普通战斗公共事件和页面验收；最终通过数量和日志以本轮运行结果为准。

本轮最终检查为 Core 64 项、Catalog 18 项通过；已有 FlashGameplayRuntime 47 项与完整运行时加载检查回归通过，均退出码 0 且无 SCRIPT ERROR。目录测试还覆盖“首次在脚本事务创建角色，提交后下一事务再次预估”的实际路径，发现并修复了首次注册角色保留已释放草稿数据库 Callable 的问题。

仍需由版本总体验证确认公共事件完整调度、扣血/动画/奖励/升级/恢复组合、原 SkillPresentation 的页面接入和正式重新迁移输出。状态容器没有自行注入源工程未注册的状态技能；13 个真实预设里没有狂暴/额外段技能，相关接口以原机制的针对性合成输入验证。新增或替换的GDScript技能通过RuntimeData.record/database共享内存视图同步显示字段及兼容字段，source_record/原缓存数组不变；CustomDataState/角色事务可读取并学习新ID。冷启动首次读取Skills也加载实际GDScript目录，避免依赖已经创建过Gameplay。内存数据库31项、冷启动目录7项检查通过；注册表不写编辑器数据库文件。

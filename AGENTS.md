# RGMigrator ver0.5 — 开发代理与运行时接口契约

2026-10-16 用户授权：本轮版本更名为0.5，修复战斗/开门等待与击杀显伤顺序，显伤改为线程处理，完成后提交并推送GitHub；此授权覆盖下文旧的禁止提交约束。原图形UI和GDScript事件直接编辑尚未完成，不因版本号变更标为完成。最新实现见docs/PERFORMANCE_v0.5.md，验收见tests/VERIFICATION_v0.5.md；正式原RM输出另建../output/0.5/final/，不得覆盖历史。

0.5线程边界更新：FlashDamageWorker使用单个Semaphore/Mutex邮箱，仅接收复制的角色/敌人/技能/常量，无节点/共享注册表访问；输入相同的通知不废弃正在运行的请求。主线程按请求版本、地图代次核验并绘制，死亡HP/标志和已删除事件立即排除。refresh_damage只请求显示刷新，脚本getter与真实战斗仍同步按原公式求值。FlashHistory仅将已脱离现场快照的SaveGraph.reason及类链接检查放入工作线程，Schema/资源/恢复实例校验仍在主线程；完整验证后才执行事件，不得省略快照或验证。SavePreparation继续由SaveCodec生成且支持同一图检查回调，检查结果复用不表示取消校验。捕获的Graph.clone_checked合并脱离和有界资源检查，独立prepare及Custom.restore仍完整拒绝非法数据。

2026-10-15用户授权的0.49内部整合验收已完成：仅闪翼，48组运行时1222项、8组编辑器2786项、跨进程9项、26个独立错误进程、实际EditorPlugin无界面/图形9/10项、五分钟GPU28轮134项及正式来源11349项通过。事件菜单/对话框/路线统一“脚本”，绑定脚本条件保留“如果”的流程含义。正式原RM交付为../output/0.49/release/黎之闪翼（开发中）_Godot，首份final因漏带验收探针未作为最终交付，历史工程保留。直接GDScript事件编辑和原图形UI还原仍为0.5；本版仍为Ruby源码重新转换。完整剧情人工通关未完成，不能将本轮结果当作全部剧情或全地图稳定60帧；原公式、首错退出及既有排除保持。精确范围、帧峰值、受限编辑器缓存与旧测试更新见docs/SCRIPT_MIGRATION_v0.49.md和tests/VERIFICATION_v0.49.md/JSON。下文0.48中“0.49未完成”为历史阶段记录，以本段为准。

2026-10-15事件列表续行：509显示实际中文路线动作/参数，355/655显示脚本原文；绑定组内相邻355按续行对齐，保留缩进和空行。209主行可预览“前进2步”等动作，显示归纳不合并原记录。地图/公共事件共用；整段选择、编辑及绑定元数据不变。见docs/EVENT_CONTINUATIONS_FIX_v0.48.md，正式输出另建../output/0.48/fix-event-continuations/。

2026-10-15用户确认：原工程图形UI、Sprite/Bitmap布局、光标/轮播/过渡与输入节奏还原列入0.5优化目标，目前简化选择页不能称为原图形UI已完整迁移；见docs/UI_OPTIMIZATION_v0.5.md。当前先修复菜单卡顿，版本仍0.48：标题/常用页移动复用控件，存档展示摘要按主/备份实际字节SHA缓存，实际读取仍完整验证；存档八帧渐变用纹理合成，背景线程资源请求有界。新正式输出另建../output/0.48/fix-menu-latency/，不覆盖历史。见docs/MENU_PERFORMANCE_FIX_v0.48.md。

2026-10-15战斗/开门延迟追加：不得用仅含拾取的探针替代开门检查。FlashEncounterPerformanceProbe覆盖原Map010三种钥匙门、战斗和拾取，分别记录前置撤回准备时间、完整事件时间和最大帧间隔。保持直接脚本执行及报错退出、完整撤回验证；通过合并图/类检查、只读定义复用、避免默认值提前复制，以及降低逐节点场景检查和协程调度开销减小前置延迟。图预算检查批量32容器，自动准备软预算6ms含首帧捕获；实际让出/恢复和发布时检查完整请求归属，同步步间检查取消代次。源静态动画可在进入地图时准备，覆盖必须重新验证。公共事件5及门路线原等待保留，不把完整动画时间当卡帧。说明见docs/ENCOUNTER_DELAY_FIX_v0.48.md，正式输出另建../output/0.48/fix-encounter-delay/，历史目录不覆盖。

2026-10-15最新用户授权覆盖下文旧事务约束：闪翼脚本取消状态副本、全量结果校验、集中数据提交和失败回滚，直接读写正式变量/角色/背包/金币及自定义数据；中途错误保留已发生修改，首错立即停止游戏，显示来源弹窗，确认或关闭后退出1。原公式、等待与接口数值规则保留。语义错误、缺失绑定/程序以及引擎GDScript错误均须覆盖；不得只在日志打印后继续。ScriptErrorLogger使用Godot4.5+ Logger，非界面进程直接输出后退出。脚本执行的begin/finish只管理调用上下文/显示请求和通知，不得在闪翼路径恢复旧全图事务；ScriptQueryProof的只读事务优化不再参与该路径。显式存读档和事件前撤回记录的独立捕获/校验及后台线程边界仍保留。实际实现、测试变更及性能边界见docs/DIRECT_SCRIPT_EXECUTION_v0.48.md。正式输出另建../output/0.48/fix-direct-script/，不覆盖历史版本。0.49仍未完成。

2026-10-15追加确认：Map010 EV072/074的并行check_event及事件名/临时标量检查必须避免无写入时整图复制。ScriptQueryProof只证明效果，实际执行仍是生成GDScript；必须同时通过生成文件归属SHA校验，编辑后的代码回退普通完整事务。单一条件分支只在正文首条指令的tick前预检查，进入正文则恢复现场并完整重跑；所有真实修改保持完整验证/提交。不得把attr_addition_clear、puts_start/puts_end等变更或调试入口误当普通只读getter。共享/循环字段、正则捕获、对象比较和错误路径均须检查。最后测得仍有冷帧及单事务峰值，性能说明保留较慢的最终测量，不采用此前22–67ms候选数据宣称稳定60帧。

2026-10-14用户继续反馈战斗与拾取事件卡顿。本次须覆盖完整原Map010事件/公共事件链，不能用单条121代替。实现和显卡测量见docs/EVENT_PERFORMANCE_FIX_v0.48.md；新正式迁移目录为../output/0.48/fix-event-hotpath/。脚本强缓存仍核对源码SHA并读取修改后的文本，定义索引保留原加载顺序；角色副本不重跑初始化。主/并行解释器共享每帧时间预算，只在完整指令间让出；事件前快照主线程捕获并分帧完整验证，验证前不执行事件，取消/重置/换图不发布过期编号，工作线程仍只写脱离现场数据。SavePreparation.gd由SaveCodec.prepare生成，修改后须运行tools/sync_save_preparation.py及--check，禁止两套校验独立漂移。首次预编译增加进入游戏时间，不能将目标预算或七个样本冒充全地图稳定60帧。0.49仍未完成。

2026-10-14用户追加BGM无声反馈：音频子进程只按完整解码阶段及输入SHA/时长/退出码验收，启动证书错误不得误判素材。原7首地图MP3原样导入；MP2标题音乐可在迁移时配置FFmpeg转PCM WAV，原件和转换来源哈希保留，生成运行时无外部转码依赖。新安装音量默认10，已存0静音及解锁/成就不覆盖；UI菜单/动画时序SE与事件SE共享效果总线。最新正式输出另建../output/0.48/fix-audio-final/，边界和测试见docs/AUDIO_FIX_v0.48.md。此前性能与工作区修复包含在内，0.49仍未完成。

当前源码为ver0.49，0.49整合验收以新增记录为准；以下为0.48阶段说明。闪翼运行功能沿用0.45—0.47，新增脚本工作区、工作副本保存/重开、来源/诊断跳转、重新转换、覆盖与生成文件归属，以及项目数据专用页面。实际入口见docs/SCRIPT_MIGRATION_v0.48.md；正式导出及完整核验须以tests/VERIFICATION_v0.48.md记录为准，整体验收尚未进行。历史工程不覆盖。

2026-10-14用户反馈0.48/final脚本工作区点击无反应。EditorScriptDialog改为初始化隐藏、transient/exclusive附属窗口，并在打开时取得焦点。后续工作区检查必须包含实际EditorPlugin中的首次按钮点击、窗口归属、关闭重开与F8输入，不能只用SceneTree独立对话框可见性替代。原0.48/final保留，修复版从原RM重新导出至../output/0.48/fix-script-workspace/，以tests/VERIFICATION_v0.48.md的追加记录为准。

2026-10-14用户追加移动/事件/ESC菜单卡顿反馈。性能修复及实际GPU证据见docs/PERFORMANCE_FIX_v0.48.md；最新正式输出另建../output/0.48/fix-performance/。普通无效果步行跳过空事务，真实地图能力仍完整提交；只读规则复用而可变状态独立，图分桶仍用is_same判定身份，HUD/菜单复用未变化内容。FlashHistory.record_async主线程捕获/校验，后台仅写脱离现场的数据；RuntimeState每帧poll，显式存档、新游戏和退出flush，待写入撤回及失败反馈必须保留。不得从后台访问游戏节点或把事件前快照改成事件后快照。0.49仍未完成。

本文件是后续事件阶段的单一接入文档，按 ver0.49 实际源码整理。先读本文件即可定位现有类、调用入口、参数、等待条件、存档边界和测试；修改类内部实现时仍需阅读该类源码。不要凭 RGSS 同名类猜测已有方法。

ver0.21实现执行核心；ver0.22完成消息/输入、全部非战斗条件与变量操作数、计时器124；ver0.23完成自主/强制路线、位置/透明及201/207生命周期；ver0.24完成221–225、231–236及屏幕天气归属；ver0.25完成131、203–206非战斗子类型、241–251及系统/音频持久化；ver0.26完成129/135、311–322及303/351/353/354。ver0.27完成352、执行器/人物/路线现场存档及菜单物品/技能公共事件预约。ver0.28增加生成工程自带地图/事件编辑器和Ruby注释占位，并于2026-10-09经用户抽样验收通过。ver0.29增加数据库、原生表格/集合与公共事件编辑，地图和公共事件共用指令组件。“待接入”仍是后续开发约束。接口改变时必须同步本文件并运行文档一致性检查。

## 1. 工作范围和禁止事项

- 开发代码仅修改 RGMigrator 仓库；父目录 rm_template/ 是只读输入。允许按版本验收流程在父目录 output/ 新增导出工程，已有用户工程不得覆盖。
- 每个版本验收通过后，必须在工作区现有的 ../output/ 下新建以版本号命名的目录（如 ../output/0.28/、../output/0.29/），启动当前版本迁移器，将 ../rm_template/ 中的 RM 工程各重新迁移一份进去，供用户直接打开验收。必须从原 RM 工程运行正式迁移流程，不能用复制测试导出或只刷新运行时模板代替。完成后检查迁移报告、生成的 project.godot 和编辑器插件，并告知用户实际输出路径。同版本需要再次导出时使用新的子目录，保留已有非空工程；不要改写历史版本输出。
- 用户已提供并明确允许直接查看 ../rm_template/ 中的 RM 工程实现。事件接入时优先核对其中的 Interpreter、Game_Event、Game_CommonEvent、Game_Character、Game_Screen/Game_Picture 及实际事件数据；展开的 Scripts/*.rb 直接读取，Scripts.rxdata 可只读解包到仓库 .godot/，不执行 Ruby。按脚本加载顺序检查后续重写，区分 RMXP 原生与工程定制；样板 Main 设置60 FPS，小蛋挞配置默认50 FPS且可修改，不能将其实际时长误称为原生40 FPS基线。
- Godot 4.5+ 标准版、Windows、纯 GDScript、Compatibility。4.7.2 是当前测试引擎；版本号 ver0.29 不是 Godot 引擎版本。
- ver0.2/0.3阶段不执行/自动转换Ruby，自定义魔塔战斗/公式/窗口暂缓。2026-10-11用户明确0.4目标为脚本迁移并补齐由此暂缓的功能，现已授权实施第一个小版本0.40，见[0.4脚本迁移计划](docs/SCRIPT_MIGRATION_v0.4.md)与[0.40实现说明](docs/SCRIPT_MIGRATION_v0.40.md)；不得将旧阶段的“暂缓”当作0.4永久排除。源Ruby仍只读分析、不执行；迁移目标为纯GDScript。用户只排除RM原生回合制战斗、战斗事件及原生Troops功能；工程重载的$game_troop（如闪翼/样板楼层怪物排列）按实际用途分析，不能按类名排除或删除其数据。不迁移RTP或RM旧存档。当前已实现非战斗范围见docs/EVENT_SYSTEM_v0.2.md。
- 2026-10-11用户提供D:\Dev\CS\RM-sync\Rm-sync中的RGSS AST作为脚本迁移参考。已只读核对Editor/RubyAstService.cs、RubySemanticIndex.cs、DocumentAnalysis.cs和RgssApiCatalog.cs；参考其作用域、符号、类型推断、接口签名及缓存设计。转译仍需完整表达式/语句节点、严格诊断、大小写精确匹配、加载顺序与alias实现版本、IR及生成代码；评估与移植边界纳入0.40/0.41，详情见0.4计划。未授权修改该参考工程，不默认引入.NET依赖。
- Git提交/推送仅在用户明确授权时执行；本轮0.5已获授权。不得破坏已有修改，新增事件功能保持用户确认范围。
- 用户在0.21＋0.22验收后明确：后续版本着重事件功能实现与针对性检查，不再逐版新增演示场景；全部目标事件功能完成后，再搭组合验收场景。现有计数演示不足以直观说明并行内容与自动事件行为，不能把演示可运行当成完整验收。
- 文本增强暂不修改现有实现。后续完整文本功能需明确已知最大宽度，并据此自动换行；对话框显示位置、说话者表达、特殊文本标识一起考虑。RM编辑器四行容量不是新引擎排版规格；窗口适配和分页规则届时统一确定，不提前实施本轮撤回的窗口改动。
- 所有“字段 / 值”表均是专用UI尚未实现时的占位入口；实现具体UI后直接替换原位置，不保留重复编辑入口。角色、事件、图块及其它数据库均遵循此规则；0.37已替换可编辑数据库的常用字段，未支持战斗范围仍按原契约保留。
- 2026-10-11用户要求先记录事件列表竖线层级问题，下次版本更新再修改：条件分歧等结构的竖线在外层贯穿内部到对应结束，文章/注释等具体指令的竖线按层级向内缩进，多重嵌套逐层递进；保持正文对齐和整条指令选中。0.40已实现结构竖线贯穿至结束、具体指令竖线按indent内缩，待办状态见docs/UI_ROADMAP_v0.3.md。
- 0.28实现地图与地图事件编辑器，0.29实现数据库及公共事件编辑；事件原工程数据必须可打开。0.43按生成能力绑定并恢复355/655、111和路线45；未转换条件整段保留，未转换路线整条失败，不能删掉脚本后运行部分动作。未转换占位执行时必须失败，不能按注释跳过。编辑草稿显式保存才写data，编辑器不执行事件。
- 正式运行状态与独立预览分开；不得把预览按钮当成实际事件已接通的证据。
- 运行时数据库定义和共享纹理按只读使用；编辑器只操作脱离现场的数据草稿并显式保存；运行状态、色相/色调材料、动画进度归各实例。
- 命令失败须给出地图、事件、页、公共事件和命令位置；不能静默忽略不支持的参数、半执行交易或伪造缺失数值。

2026-10-11用户明确继续0.43，并决定脚本功能移植后整体验收。0.43阶段及持久化边界见[实现说明](docs/SCRIPT_MIGRATION_v0.43.md)；本轮不新增演示场景，仍需内部回归与全新正式输出。0.44—0.49顺序保持。

2026-10-12用户明确继续0.44。自定义数据由CustomDataImporter提取，CustomDataState持有可变记录覆盖、额外货币和楼层数据；RuntimeData.source_record保持只读，record提供现场覆盖后的只读视图。脚本变量扩展为可保存的标量/Array/Hash，数值事件遇集合明确失败。金币按源工程上限精确运算；脚本事务统一提交后再通知。已确认的普通树形数据纳入存档，循环/共享对象仍按0.47处理。阶段范围及源码映射见docs/SCRIPT_MIGRATION_v0.44.md。

2026-10-12用户要求0.45—0.47的原RM脚本匹配清单，仅匹配闪翼。任务、来源加载序号、跨版本方法边界及源工程疑点见docs/FLASH_SCRIPT_CHECKLIST_v0.45_v0.47.md，同名JSON覆盖339个脚本槽位和144个事件脚本片段。本清单是计划；后续实现按实际GDScript方法/数据项及行为证据更新完成状态，不能把解析/生成或版本号当作整库迁移完成。前两版需要的语言/API依赖在使用它的版本完成，0.47收尾剩余插件与持久化。特殊BOSS战是否迁移按下方最新用户授权执行。

2026-10-12用户追加要求0.43—0.44既有实现清单，仍匹配闪翼。见docs/FLASH_SCRIPT_CHECKLIST_v0.43_v0.44.md及同名JSON：逐项区分生成代码、原事件绑定、服务适配、数据提取与独立行为证据。0.43原路线45绑定为0，0.44仍为0；8/9库单元生成不代表完整类迁移。原Global中POTION_ITEM_ID/GEM_ITEM_ID后续逐项赋值在0.44产物中仍未恢复，归45-01补迁；不要把初始空Hash提取计为完整ID表迁移。闪翼已暴露的原始角色扩展属性为tp_plus/resist_plus/skill_parameters/delay_const，Actor_Init仅提取预设，运行应用和派生属性仍在0.45。

2026-10-12最新用户授权：顺序执行0.45—0.47，特殊BOSS战不迁移；保留闪翼半成品地图功能的迁移要求。原脚本列表“特殊BOSS战”分组（0274—0308）按用户排除登记、保留原文，普通地图战斗BattleSystem/SkillRegistry仍在范围内；共用方法若被其他已确认功能实际使用则按该用途保留。半成品地图的0244—0251、Game_Floor/Game_Region、发现/区域/连接/布局/预览/换图记录及存档按源已实现行为迁移，不自行发明尚未设计的地图功能。本授权覆盖三个版本及其验证/全新正式导出，整体验收仍待脚本功能完成后进行；阶段无法完成时须如实报告剩余工作，不提前宣布版本完成。

2026-10-12用户已明确选择“修正明显错误，保留原公式”：迁移副本中修正阻断普通玩法的拼写、字段引用和调用错误，并登记原位置及GDScript修正；原RM工程仍只读。影响数值平衡的原公式不自行修改，例如0069的pdef取patk点数、mdef取matk点数及未累加装备抗性的原计算保持，不能借迁移重新平衡。

0.45玩法阶段实现与方法对应关系见docs/SCRIPT_MIGRATION_v0.45.md；正式原RM导出检查见tests/VERIFICATION_v0.45.md。0.46/0.47继续原清单，不能将本阶段视为全部自定义脚本完成。FlashActorState持有原八项属性/六类槽位/技能配置，FlashBattleSimulator作脱离现场的普通战斗预估，FlashGameplay连接楼层怪物/队伍/结算，FlashActions提供共享脚本事务的GDScript业务入口，FlashBlastic管理两条回路链和背包交换。FlashObjectCatalog读取原外部设置/回退，不补造缺失的Game_Deputy。FlashMapBridge/FlashCharacterBridge连接当前地图人物，ScriptSemantics完成原事件捕获与command_117子调用。FlashSourceCorrections仅修改迁移副本并生成来源记录；原SHA256仍作绑定校验。0.45最终原RM输出为../output/0.45/delivery/，阶段方法与正式复核已完成；0.46页面和0.47关系持久化仍未完成。内部夹具不得替代正式输出。

2026-10-13最新用户要求：后续只执行闪翼回归，不再执行二律回归。此前已完成的二律检查保留为历史证据，不作为后续版本必须重跑的检查，也不再新增二律验证或导出工作。继续0.46→0.47的闪翼既定范围，特殊BOSS仍排除。

## 2. 路径、加载和实际结构

源模板为 templates/runtime/scripts/*.gd；生成工程内为 res://runtime/scripts/*.gd。模板中的 res://runtime 路径只在生成工程里成立，不能在迁移器主工程直接运行这些类。场景模板位于 templates/runtime/scenes/，生成到 res://scenes/。

多数文件是 Script 资源，不声明 class_name；通过 preload/load 实例化，不假设存在 Game_Actor 等全局类。唯一游戏运行状态入口是生成工程的 Autoload RuntimeState，继承 Node；其子节点 audio 独立于地图场景。迁移器自身不注册这个 Autoload。

```text
迁移器 Main -> Validator -> MigrationPipeline
                         -> AssetCopier / DataConverter / TestSetupGenerator
                         -> ProjectGenerator / MigrationReportWriter

生成工程
  RuntimeData（静态只读定义＋独立测试覆盖层）
  RuntimeState（Autoload，统一状态与服务入口）
    system_settings -> SystemSettings（窗口皮肤运行时覆盖）
    apply_actor_event -> ActorEventService（脱离现场事务）
    actors[id] -> ActorState -> ActorParameters
    party / inventory / gold / switches / variables / self_switches
    player_motion -> CharacterMotion
    screen -> ScreenState -> PictureState[] + WeatherState
    map_view -> MapViewState
    map_effects -> MapEffectsState（全景/雾）
    timer -> GameTimer
    audio -> AudioRuntime
  Title.tscn -> Title
  Gameover.tscn -> Gameover -> Title
  Game.tscn -> Game（组合协调，不继承 RGSS Scene_Map）
    MapRuntime -> MapTileRow[] / MapEvent[]
    PlayerController --继承--> MapCharacter <--继承-- MapEvent
                       motion -> CharacterMotion
    MapCamera -> MapViewState
    ScreenRenderer -> PictureSprite[]
    MapEffectsRenderer -> 全景 / 雾 / WeatherRenderer / 计时文字
    TransitionRenderer
    EventScheduler -> EventInterpreter -> EventExecutionContext / EventWait
    EventUIBroker <请求ID/token> DialogueOverlay / 商店 / NameInput / 事件菜单
    MenuCoordinator -> MenuScene -> InventoryScene / SkillScene / SaveSlots / ShopScene
                                  -> 测试工具
  WindowCommand --继承--> WindowSelectable --继承--> WindowBase
  CharacterSprite / UISpriteset / RmxpAnimationPlayer
  RmxpCache -> UIResources + RuntimeData.asset_index
  SaveService -> SaveCodec -> 脱离现场校验 -> RuntimeState.restore_prepared
```

这是组合关系与继承关系的区别：只有箭头明确写“继承”的人物链、窗口链属于脚本继承，其余主要为持有/调用关系。技能、职业、装备、State 定义目前是数据库 Dictionary，不是已经存在的 SkillState/StateState/游戏战斗类。

### 2.1 RGSS 职责对应与 Game_Screen 约束

- Game_Actors/Game_Actor：RuntimeState.actors + actor(id) / ActorState。
- Game_Party/Game_Switches/Game_Variables/Game_SelfSwitches：RuntimeState 的对应字段，目前未拆成独立同名类。
- Game_Character/Game_Player/Game_Event：MapCharacter / PlayerController / MapEvent，加独立 CharacterMotion。
- Game_Map/Spriteset_Map/Tilemap：MapRuntime 加 MapTileRow、MapCamera 和各显示组件；非一个 RGSS 式主循环。
- Scene_*：Title / Game / MenuScene / 各功能页面，MenuCoordinator 协调暂停与返回；状态页在 MenuScene 内，没有独立 StatusScene 类。
- Window_*：WindowBase / WindowSelectable / WindowCommand；Sprite/Spriteset 菜单角色显示由 CharacterSprite / UISpriteset 提供。
- Game_Screen：ScreenState管图片、色调、闪光、震动及天气。天气唯一状态由ScreenState持有（组合WeatherState），正式时钟只由ScreenRenderer推进；MapEffectsRenderer仅消费天气快照并显示粒子。
- 用户要求天气统一由Game_Screen对应层管理，ver0.24已完成。新游戏重置、换图保留、菜单/过渡暂停和存读档使用同一ScreenState天气；不能再把天气写回map_effects或建立渲染器天气真值。
- 全景/雾来自地图图块集；显示矩形/跟随中心属于地图视图；音频属于独立音频服务；不要仅因“看起来是画面效果”就把一切塞到 Game_Screen。
- 旧schema1的map_effects天气字段由SaveCodec校验后迁入ScreenState，归一化快照删除旧字段；两处都存在且冲突时拒绝读档，不部分恢复。

## 3. 所有调用共享的约定

- 数据库名称区分大小写：Actors、Classes、Items、Weapons、Armors、Skills、States、Animations、Tilesets、CommonEvents。源 ID 保留，正整数；0 在装备/动画等特定接口表示空，不是有效角色。
- JSON 数字可能是 float；ID 先验证为整数再 int()，不能依赖 Array.has 对 1 和 1.0 的相等判定。
- 方向数字 2/4/6/8 = 下/左/右/上；地图底层 can_move 用 Vector2i 单位方向，而人物 move_straight 用方向数字。
- 地图一格 32px，格坐标与平滑显示位置分开；real_x/real_y 是像素，不是旧 RGSS 的 128 单位。
- 底层时长一律秒，推进 delta 也是秒。用户已明确新引擎无需照搬RM旧实现的乘2；接入边界直接按各命令的原生单位换算成秒，不能统一把编辑器原参数 /40。例如等待106的旧实现先乘2再按标准40帧/秒推进，Godot直接用参数/20.0，参数20约1秒，不额外乘2。天气和音频按各自单位，接入前核对标准脚本和独立夹具，底层不能重复换算。动画数据帧按0.05秒一帧（20动画帧/秒）。
- 普通动作结果为 Dictionary，至少 ok；失败含 message。先检查 ok，再读其他字段。有的成功没有 message/changed，不要无条件取值。
- 查询可以返回 null、{}、[] 或 false，按各类契约判断；null 表示无法计算，不能擅自当作 0。
- decode() 不修改现场；ScreenState 返回 {ok,screen}，PictureState 返回 {ok,picture}，MapViewState/MapEffectsState/GameTimer 返回 {ok,value}，不要混用。
- 动画、音频、过渡开始成功不代表执行完成。等待用实际状态/完成信号，不用阻塞 sleep，不在每帧重复 start/play。
- 带前导下划线的方法/字段是内部实现；附录只列非下划线方法及带参数构造器。Godot 自带生命周期回调不作为事件接入 API。
- state_changed 用于刷新界面；角色 changed 已转发。事件开关/变量/独立开关通过set_event_switch/variable/self_switch写入并发event_state_changed；直接改字段者须显式refresh_events，背包仍按现有业务接口，不能在 UI 或解释器维护第二份状态。

## 4. RuntimeState：事件优先调用的入口

### 4.1 全局状态和初始化

字段：actors（整数ID→ActorState）、party（整数ID列表）、inventory（"item:ID"/"weapon:ID"/"armor:ID"→0..99）、gold、steps、play_seconds、save_count、message_position/message_frame、switches/variables（字符串ID键）、self_switches（"地图ID:事件ID:A..D"键）、save_disabled、menu_disabled、playing、testing_enabled、diagnostics。

player_x/player_y/player_direction 代理 player_motion 的逻辑坐标/方向。register_player/register_game 持弱引用，player()/game() 无有效地图节点时返回 null。不要缓存跨标题/新游戏的节点引用。

begin_new_game(system,testing_override={}) 重置所有运行状态、角色注册表、屏幕/镜头/表现/计时器，停止音频，读取起点并只发放一次测试物资。restore_prepared的preserve_audio=true仅用于事件验收地图返回，保留实时音频；普通读档使用默认false清理音频。重复看菜单用 actor(id)，不是 begin_new_game 或 actor(id,true)。change_party(id,true,initialize) 的 initialize=true 才重建该角色；移出队伍不抹去其注册状态。record_step() 只用于成功走完普通一格。

self_switch_key(map,event,letter) 生成上述键。report_diagnostic(message) 去重存储并发送 diagnostic_added，但不会自动弹出对话或停止事件，解释器需要负责这一层。

### 4.2 角色、背包、装备与商店

actor(id,reset=false) 返回同一个注册对象，缺记录返回 null 并诊断。party_snapshots() 返回脱离数据库的显示快照，跳过缺失成员。actor_parameter_sources(id,key) 返回来源字典或 {}。

change_actor_parameter 增加的是永久 plus，不是最终值增量；set_actor_parameter 设置精确最终值；set_actor_parameter_plus 设置永久 plus。set/change_actor_experience、set/change_actor_level、set/change_actor_vital 是设置/增量对，vital key 仅 hp/sp。recover_actor_vitals 只回满，不清状态。rename_actor、change_actor_class、set_actor_graphic 提供身份变更；不要直接写 class_id/equipment 绕过回收和校验。

change_skill(id,skill,learning)、has_skill、skill_ids；change_state(id,state,adding)、has_state、state_ids_for(include_equipment=true)、clear_states。角色不在队伍也可以通过注册表操作；无效引用返回失败。状态附加/解除执行zero_hp和plus/minus关联，保留来源与倍率；不执行中毒、概率/回合解除或战斗结算。原生角色事件优先使用apply_actor_event(code,parameters)，详见6.4。

inventory_entries() 返回 [{kind,id,count,name,description,icon_name,missing}]；inventory_count 查询。use_item(item,target_actor)支持确定性HP/SP恢复及原生公共事件预约；无目标/敌人目标的菜单公共事件直接返回地图，存活队友单体/全体支持原有恢复与公共事件组合；未支持效果整次拒绝。use_skill(actor,skill,target=0)接通公共事件使用入口，先验证已学/存活/菜单可用/状态限制/SP及目标，再预约和扣SP。common_event_reason/reserve_common_event检查有效地图与唯一预约，EventScheduler在前台空闲时优先接取并清除一次预约。

equip_preview(actor,slot,id) 返回 {ok,before,after,equipment}，不提交；equip 提交库存交换。slot=0武器、1盾、2头部防具、3身体防具、4饰品；id=0卸下，仍须满足固定槽位/回收库存要求。测试装备只豁免有效职业装备表，不豁免槽位固定。

shop_buy(goods,kind,id,quantity)/shop_sell(kind,id,quantity) 原子交易。goods 是 [[0物品/1武器/2防具,ID],...]，不包含自定义价格；kind 用 item/weapon/armor。购买数据库价格，出售半价取整；库存99、金币使用源工程上限（默认9999999），与事件和脚本共用精确余额；出售背包物品，不出售身上装备。

### 4.3 人物、屏幕、地图与音频

configure_player(value) 原子部分更新：move_speed=1..6（默认4）、walk_anime、step_anime、direction_fix、through、transparent（布尔）、opacity=0..255、blend_type=0..2、idle_pattern=0..3。默认像素/秒10×2^速度；方向固定不禁移动，穿透不越地图边界。

show_picture(number,name,pose)、move_picture、rotate_picture、tint_picture、erase_picture：编号1..50。优先通过 RuntimeState，以校验素材存在、测试素材权限并保持缺素材时原图；不要事件直接调用 screen.show_picture 绕过素材预检。
pose={origin:0左上/1中心,x,y,zoom_x,zoom_y,opacity,blend_type}，x/y 为窗口逻辑像素（-1000000..1000000），缩放0..10000百分比，透明度0..255，混合0正常/1加算/2减算；部分更新允许省略字段。色调=[R,G,B,gray]，RGB=-255..255，gray=0..255；闪光RGBA=0..255。旋转-36000..36000度/秒，正数逆时针；震动振幅0..100px、频率0..60Hz。屏幕方法见 ScreenState 附录。

configure_map_view({view_rect:[],follow_center:[],follow_enabled:true}) 原子部分更新。view_rect=[x,y,w,h] 是窗口里的地图区域，follow_center=[x,y] 是区域内跟随点；[] 表示全窗口/区域中心，不是0,0。屏幕尺寸改变时显示区域裁切至合法范围。新游戏读取 project.godot 的 rgmigrator/map_view_rect、map_follow_center。
scroll_map(direction,tiles,seconds) 手动滚动、停止跟随，重复滚动未结束则拒绝；resume_map_follow() 取消剩余滚动并恢复跟随。等待观察 map_view.scroll_remaining；显示原点在 map_view.display（地图像素）。

configure_map_effects(changes) 先检查非空素材再提交；MapEffectsState.configure 只检查格式，不加载素材。可修改：panorama_name/hue、fog_name/hue/opacity/blend_type/zoom/sx/sy。name=""关该层；色相0..360，fog_zoom=1..10000%、sx/sy=-10000..10000，自动偏移每秒-5×sx/sy px。全景在透明图层后半速视差；不透明地图覆盖全景是正常遮挡。
map_effects.tint_fog(tone,seconds)、fade_fog(opacity,seconds)控制雾；screen.weather(type,power,seconds)控制天气，weather_snapshot()取得脱离现场的六字段快照。天气0无/1雨/2暴风雨/3雪、强度0..9；强度0是最低天气，关闭必须type=0。天气换图保留，雾/全景换图按新图块集初始化；同地图 setup_map 不重置。

fade_screen(opacity,seconds) 的opacity0显示地图、255全黑；await freeze_screen() 获取实际截图；transition_screen(seconds,name="",vague=40) 揭示新画面，name来自 Transitions 分类，vague0..255。未完成 freeze、重复冻结、headless 截图均拒绝。缺蒙版保留冻结图并失败，可 cancel_screen_transition() 释放。221/222使用Game.begin_event_screen_transition、event_screen_transition_status的请求身份协议，等待实际截图/过渡结束，详见6.2；事件不能依赖私有_transition字段。cancel_screen_transition同时取消正式传送/过渡请求。

timer.start(seconds,show=true)、stop()；0..359999秒；remaining/running/visible 可查，text() 向上取整MM:SS；expired 只在运行倒计时归零时发一次，不触发战斗或事件。stop 不清剩余秒数但隐藏并停止。

audio.play(kind,{name,volume=100,pitch=100},position_seconds=0)：kind大写BGM/BGS/ME/SE，音量0..100、音调50..150；空name停止该类；缺失文件失败且不替换原频道。BGM/BGS循环，ME暂停/结束恢复BGM，SE独立并发上限32（释放最老）。fade_out仅BGM/BGS/ME；memorize返回BGM/BGS字典，不是ok结果；restore_memory返回ok。stop_all还清记忆。snapshot反映BGM/BGS定义/当前位置，persistent_snapshot保存playing/memory/fades；decode_persistent预加载并校验所有音频后，restore_prepared整体提交，不持久化ME/SE。247/248保留记忆位置，是相比RM原生重头播放的改进。空SE为空操作，251才停止并发SE。

## 5. 角色规则、查询快照和只读数据

ActorState 的九项：maxhp最大HP、maxsp最大SP、str力量、dex灵巧、agi速度、int魔力、atk攻击力、pdef物理防御、mdef魔法防御。

parameter_sources(key)={database,equipment,base,plus,state_rates,value,minimum,maximum,reason}；base 包含数据库+装备并先限幅，plus 只保存永久修正，不叠存装备。最终值按已有 State 倍率顺序取整再限幅。HP上限1..9999、SP上限0..9999；四项基础属性1..999，攻击/防御0..999；当前hp/sp可0。坏引用value/base可null且reason说明，不能伪造。

get_parameter/get_base_parameter/get_equipment_parameter/get_parameter_plus 对应上述层。动态属性 key、key_plus、base_key、equip_key、database_key 提供读取；key/key_plus、exp、name 可写，结果看 last_mutation_result。显式方法更适合事件，因为能返回失败；直接写 level/experience 不等于调用成长接口。

snapshot(equipment_override=[],level_override=-1,bonuses_override={}) 可用于纯预览，空覆盖参数表示当前值；返回 {id,name,class_name,level,hp,sp,parameters,parameter_sources,experience,next_experience,equipment,states,skill_ids,diagnostics,character_name,character_hue}。equipment条目为显示信息，不暴露数据库 definition；states 为名称列表，ID另用get_state_ids。最终等级next_experience=null；experience_for_level 返回升级到该级所需累计经验或null。set_parameter精确最终值若倍率/取整使目标不可达，整次拒绝。

set_experience/add_experience、set_level/add_level 按源 exp_basis/exp_inflation 曲线，累计经验0..9999999、等级1..final_level（至多99）；升级学习职业表，降级不遗忘，升级不治疗。persistent_data 保存角色运行字段/普通状态/特技/plus/图像；restore_persistent返回空字符串表示成功，非空为失败原因，不是ok字典。

add_state保留既有普通来源接口：显式附加可在装备来源之外单独保存，卸装后仍保留；add_state_native用于313，已存在装备自动来源时按RM不建立普通来源。State 的普通来源和防具auto_state来源分开：remove_state/clear_states只删除普通来源，自动状态仍有效。has_state/get_state_ids默认包含装备来源；include_equipment=false仅普通ID。执行zero_hp附加置HP0、解除最后一个普通死亡状态恢复HP1，plus_state_set/minus_state_set关联与互斥规则；先校验关联图，循环超过预算拒绝。保留倍率显示，不执行中毒/概率/回合解除/状态动画或战斗结算。Skills 定义保留标准字段（包括animation1_id、animation2_id可0）；无独立可变Skill对象，不执行效果/消耗。

RuntimeData.record 从测试覆盖层或源数据库取引用；source_record只取原定义；database返回原数组（下标就是ID，可能null/空洞）。这些结果不是深拷贝，调用方必须只读；需要改定义展示时duplicate(true)。configure_testing独立注册测试定义，不能覆盖源ID；install_testing仅存档整体校验后使用，不能再次发放物资。read_json有静态缓存，test_config有独立文件读取行为，不承诺修改磁盘后所有数据库热更新。

Table 数据：{_rmxp_type:"table",dimensions,x_size,y_size,z_size,values}，扁平下标x+y*x_size+z*x_size*y_size。角色参数表x为六项索引，y为等级（用level而不是level-1）；地图x/y/z为格/层。数据库值不直接塞进会改写的运动/画面对象。

## 6. 地图、人物与动画接入

MapRuntime.load_map(id) 从 RuntimeData读取，返回bool；load_definition(definition,tileset_definition) 为独立夹具入口，正式地图优先load_map。map_width/map_height为格，valid查询边界；tile_id层0..2，tile_priority依数据库；terrain_tag/is_bush/is_counter查询图层标志。tile IDs为0空、48..383自动图块、>=384图块集；绘制、通行和人物遮挡不可各维护不一致的规则。

can_move(from,unit_direction,through,ignore_event_id) 检查起点/终点双向通行及人物占位；can_stand检查跳跃落点；正在移动人物占据起点+终点。ignore_event_id=-1通常排除玩家；正ID排除自身事件。event_ids_at(x,y)返回当前占位事件ID。

MapCharacter.move_straight(direction) 为单格尝试，成功返回true；失败可能仍已转向，方向固定时不转。move_to(x,y) 是边界内立即重定位、不是寻路、不计步，不等同于经过通行检查的move_straight。jump(dx,dy) 相对格偏移，能跨障碍但落点须合法，不计步。turn/is_idle/moving/jumping/motion_snapshot，arrived("walk"/"jump") 表示已到终点。不要同时让节点_process和事件手动advance_motion推进两次。

PlayerController.configure(map) 绑定统一player_motion，队首Actor提供图像；input_enabled只禁玩家输入，运动组件仍可推进，菜单是真正pause。resume_after_menu避免确认键残留。MapEvent.configure(event_data,page,id,map_id)设置页图像、选项及自主路线；未变页保留实体/位置/路线，变页安装新路线并解除强制。front_interaction描述当前是否在前方交互，不是事件触发器总开关。

MapRuntime.request_action处理脚下/前方/柜台隔格确认；trigger_player_touch处理现有触碰；event_requested(commands,event_id)交给Game/EventScheduler的前台解释器。event_page返回1起页号；refresh_events重评页并保持同页人物；autorun_event保留兼容查询；正式启动由EventScheduler调度。event_contexts给出当前页，event_node查实体；erase_event在本图标记删除，flush_event_refresh按依赖重评页并发events_changed。主列表换页继续，并行失效立即取消。

transfer(map_id,x,y,direction=0)先查落点再加载，成功立即重定位，返回bool；201的完整淡化/完成等待由Game请求协议处理，详见6.1。显示节点随MapRuntime生命周期销毁；屏幕状态仍归RuntimeState，新游戏才重置。

MapRuntime.animation_target(character_id,current_event_id)的ID=-1玩家、0当前事件、正值指定事件；找不到null。play_animation(animation_id,character_id=-1,current_event_id=0,hit=true) 创建并追加独立播放器，返回{ok,empty,player}；0动画只返回ok+empty，无player。每次播放都是新实例，同一目标第二个动画不覆盖第一个，也不通过animation_id单值实现队列。

RmxpAnimationData.compile把原frames/cell_data转为至多16单元，每单元[pattern,x,y,zoom,angle,mirror,opacity,blend_type]，原sheet每格192px、每行5格；position=0头/1中/2脚/3画面。resolve校验ID/帧/素材边界，返回{ok,empty,id,position,hue,frames,timings,texture}或失败，0为空动画。
timings包含frame、se、flash_scope（0无/1目标/2画面/3隐藏）、flash_color（原数据的red/green/blue/alpha字典）、flash_duration（动画帧数，乘0.05秒）、condition（0总是/1命中/2未命中）；hit来自调用方，不计算战斗。finished/timing_reached可订阅，播放结束或目标失效会释放；等待动画时持有实例列表，不等待被覆盖的单一ID。不要再手动advance已在_process推进的播放器。

### 6.1 ver0.23 人物路线与地图命令

MapCharacter.routes为每个人物独立的CharacterRoute，弱引用持有人物；move_type=0固定/1随机/2接近/3自定义，move_frequency=1..6。route={repeat:bool,skippable:bool,list:[{code,parameters}]}，末尾必须是0；0..44全部接通，45脚本排除。Catalog校验完整格式，CharacterRoute.preflight先验证所有素材，再启动路线，失败不部分执行。定义只读，各人物仅持有独立游标；每次最多执行64条即时属性/开关指令，长链让出更新。

force_move_route(route,source,on_error)首次强制保留原自主路线/游标，再次强制只替换当前路线；非重复结束恢复原路线，repeat持续占用。阻挡时skippable=false重试原指令，true进入下一条。强制路线可移动正在对话锁定的事件，并清除锁定前朝向；自主路线在锁定期间停止。路线等待15参数/20秒；自主频度阈值(40-2*frequency)*(6-frequency)/40秒，频度6立即可动。随机/接近沿用参考原生规则，不迁移小蛋挞的Ruby寻路改写。

斜向移动允许水平→垂直或垂直→水平任一路径通行，每轴保持直走速度；阻挡仍按原生规则调整朝向，穿透不越地图边界。跳跃可偏移0,0原地起跳。39/40通过地图内z_index=1024置顶/恢复，不更改UI的CanvasLayer；置顶不显示草丛半透明。41更换图形清除图块图形，并按原生original_direction/original_pattern比较更新姿势；相同原图方向不强制覆盖运行时朝向。玩家强制路线不增加队伍步数，普通走格仍只计一次。

202参数[target,mode,x,y,direction]，target=-1玩家/0本事件/正数事件，mode=0直接/1变量/2与x指定人物交换（y=0）；方向0保持，2/4/6/8尊重方向固定。位置/交换先全部校验再执行，允许设置到有效地图格而不进行行走碰撞。208参数0隐藏/1显示玩家，只改透明显示，不删除碰撞人物。209接完整路线，紧随509仅为显示副本，须顺序匹配且不重放；孤立或不匹配509诊断。210查询当前地图全部人物的强制路线，不只最后一个；重复路线时仅提醒一次，保持持续等待。

201参数[mode,map,x,y,direction,fade]，mode=0直接/1变量，方向0保持、2/4/6/8尊重方向固定，fade=0淡化/1无淡化。正式Game.begin_event_transfer返回请求ID，event_transfer_status只查询对应请求；消息/其他传送/过渡占用时解释器重试等待。淡化抓取旧画面并用0.5秒揭示新图，需要真实渲染；headless明确拒绝截图且不换图。无淡化也等待实际延后执行完成，不在同一调用栈重复推进旧命令。相同地图不重载，不清删除/事件页/路线；跨图取消旧事件路线/动画/并行及玩家强制路线，前台列表保留源定位但本事件归0。新游戏/恢复/关闭场景取消未完成传送，旧协程不能修改新现场。

207参数[target,animation_id]；0动画为空操作，正数ID使用现有动画播放器且不阻塞事件。动画绑定原目标WeakRef，而不是每帧重新按事件ID找到另一实体；目标被删除/移除或换图即终止。页变化保留同一实体时仍跟随它。多个动画保持独立实例。

CharacterRoute.persistent_data/restore_persistent保存游标、原路线、等待、频度和故障；CharacterMotion保存平滑运动，MapCharacter保存所有显示/运动属性。EventPersistence统一保存当前地图全部事件，路线结束后的属性也保留；MapRuntime缓存隐藏页/删除人物的现场。普通换图重建，读档按记录恢复，背景路线可存档。现有验收地图保持，不新增演示地图。

### 6.2 ver0.24 图片、屏幕与天气事件

221无参数，222只有Transitions名称，空名称普通淡化0.5秒、有名称蒙版过渡1秒（原生Scene_Map的20/40帧按40fps换算）。准备时等待消息/商店/菜单/其他传送或过渡释放，再异步取得真实截图；已准备的截图可以复用。没有221时，222捕获当前画面再执行。缺蒙版先诊断并保持原截图；headless不能假装截图成功。

Game.begin_event_screen_transition(code,name="")返回{ok,id}或{ok:false,busy:true}；event_screen_transition_ready查询是否可启动，event_screen_transition_status(id)查询对应pending/ok/message结果，最多保留32个已完成请求。cancel_event_screen_transition(id=0)取消指定所有权或全部；旧请求不能取消新截图。解释器用screen_ready重试、screen_transition等待真实完成；取消所属解释器会释放其未完成请求/准备截图，新游戏、恢复及场景关闭统一取消。瞬时截图不写入schema1存档，Game和底层SaveService门禁保护。

RuntimeState.map_time_paused()包含普通菜单/商店/姓名输入暂停、终止场景切换和正式221截图准备/222揭示阶段；地图/人物路线/地图动画/自动图块/镜头滚动/雾/屏幕效果/天气/计时器/事件调度在222期间停止，过渡显示自身按delta推进。221完成后可以在冻结画面下继续事件和地图逻辑，直到222；223–225、231–236均不隐式等待，原工程用106另行等待。音频服务继续运行。

223/224接受原Tone/Color字典，Catalog.color_values转为四通道数组；223/224/225/232/234时长参数/20秒，236原脚本没有乘2，按参数/40秒。233旋转速度×20为度/秒，正数逆时针，0停止。225强度×2为px振幅、速度/2为Hz，保留底层平滑正弦和结束包络，优化旧逐帧折返的跳变并结束归零；峰值/周期对应原生规则，波形不声称逐像素复刻。

231参数[number,name,origin,mode,x,y,zoom_x,zoom_y,opacity,blend]，232把name位置换为duration；mode=0直接/1变量，原点0左上/1中心；变量坐标先校验，缺素材不替换原图。图片1..50独立，重新显示同编号重置其旋转/色调/移动；空名称擦除。232/233/234针对未显示图片按原生空效果成功，不建立假图片；235直接走RuntimeState。显示/变换/混合/色调/旋转采用现有正式PictureState/Sprite，无第二份真值。

ScreenState.weather_state独占WeatherState；正式ScreenRenderer推进screen.advance时一并推进天气，MapEffectsRenderer.screen_model只读快照并更新粒子。独立PresentationTools持自己的screen，preview=true时由其MapEffectsRenderer推进；预览不写真实天气。新快照在screen.weather保存六字段，map_effects不再存天气。旧map_effects字段完整校验、迁入screen并删除；双份相同可归一，冲突或缺字段拒绝。换图保留天气进度，新游戏归零，旧无天气字段存档默认中性。

### 6.3 ver0.25 地图表现、音频与系统设置

131[name]通过RuntimeState.set_windowskin设置SystemSettings.windowskin_override，null使用数据库默认，空名称为透明外观。非空素材预检192×128后提交；现有WindowBase及对话窗口刷新皮肤但保留内容、选择和文本排版。新游戏恢复默认。schema1新增可选system_settings；旧存档用null，非法/缺素材读档前拒绝。导入System始终只读。

203[direction,tiles,speed]使用原生1..6速度，像素/秒10×2^speed，时长tiles×32/速度。仅等待上一段滚动结束后启动本段，不等待本段完成；scroll_ready重试原命令而不重放其他效果。原生滚动目标保存未裁剪距离，保证接近边界时速度仍一致；结束后静止玩家不使镜头跳回，玩家越过中心时按移动方向跟随。MapViewState.native_follow/native_velocity与滚动进度保存，旧五字段地图视图默认false；新地图结束旧滚动并恢复跟随，菜单/过渡暂停地图时钟。普通自定义秒滚动接口保持可用。

204的0全景[name,hue]与1雾[name,hue,opacity,blend,zoom,sx,sy]接通；2战斗背景单独排除。原先将整条204排除有误，目标主命令数量修正为75（14回合制主命令与355排除）。缺素材先诊断不部分改变原表现。205[Tone,duration]、206[opacity,duration]按参数/20秒渐变，不额外乘2，不隐式等待；换图按原图块集重新设置全景/雾。

241/245/249/250完整AudioFile参数走正式AudioRuntime，失败回传源定位并停止后续命令；242/246淡出参数直接为秒，0立即停止。247记忆BGM/BGS及播放位置，248预检两个频道后整体恢复，记忆空频道恢复静音；251只停止SE。ME暂停BGM并在结束/停止后恢复，BGS独立，菜单/地图过渡不停止音频时钟。持久化BGM/BGS位置、音量/音调、音频记忆及剩余淡出，读取时全部解码成功后提交；地图载入不以自动播放覆盖已恢复音频，不序列化ME/SE。新游戏清空，新场景读档不重新发放物资。

### 6.4 ver0.26 角色与场景

RuntimeState.apply_actor_event(code,parameters)委托ActorEventService，完整校验原生参数和目标，脱离现场复制所有角色/背包/队伍后提交。失败不部分修改或注册新角色；成功保留已有注册对象身份。129原生四人上限，初始化先于加入检查，并安装初始防具自动状态/关联；移出队伍保留角色。135禁止玩家菜单，351显式事件菜单可越过该标志。

311/312/313/314/315/316允许角色ID=0代表当前队伍全体；其余角色命令指定角色，包括离队角色。增减按常量/变量及操作符解析，变量可为负数。311跳过已死角色，不允许死亡时活人最低HP1，允许死亡同步所有zero_hp状态；非空队伍全员HP0请求游戏结束。313只执行状态变化，无311的自动游戏结束标志。314按RM顺序先用当前上限回复HP/SP再删除普通状态，保留装备来源；不直接代用recover_actor_vitals（该接口仅回满且保留状态）。

315/316原生四参数，无其他RM版本的升级显示选项。317仅六索引maxhp/maxsp/str/dex/agi/int，增加永久plus并按原生范围饱和，倍率下不保证最终值恰好加操作数；九项精确赋值接口仍独立。318学习/遗忘。319要求新装备有库存，缺库存原生无操作；事件强制更换可越过固定槽位/职业/在队限制，菜单装备仍遵守限制。321保留等级/经验/特技并收回新职业不允许的装备。收回库存将超过99时整体拒绝，避免原生限幅丢装备。装备自动状态的新关联走ActorState.apply_equipment_states，该接口仅用于脱离现场的装备事务。

320姓名；322完整五参数[actor_id,character_name,character_hue,battler_name,battler_hue]。行走图预检四方向四帧，立即刷新队首/菜单；战斗图仅保存元数据，不渲染战斗。schema1保存两种图像覆盖，旧存档缺战斗图字段用数据库默认。

303姓名输入经EventUIBroker排队，专用NameInput页面复用WindowBase皮肤并支持系统输入法，按Unicode字符限制1..99；空确认恢复原名，Esc删除一个字符，X/Z/空格作为文本。351经同一队列调用MenuCoordinator.open_event_menu；302商店共用队列。消息可在人物移动中显示，姓名/菜单/商店页面等待本格走完再进入；EventUIBroker.next_kind供Game查询下一有效请求种类。界面持有请求ID/token，关闭只恢复原解释器一次；地图暂停，音频继续。取消/新游戏不接受旧回调。353/354以及311全员死亡经Game.request_event_scene先取消事件、并行、路线、传送和界面，停止游戏时钟，再带serial延后切换Gameover/Title；旧延后切换被重置作废。Gameover读取原背景/ME，素材缺失诊断并显示可返回标题的页面。

ver0.27已接通352，菜单存档和事件存档采用同一SaveService；已打开的menu/save界面等待在快照中归一为关闭后的指针，其他排队界面恢复身份和原等待。

### 6.5 ver0.27 事件现场和公共事件入口

SaveCodec新增可选event_state/common_event_reservation；旧schema1缺字段默认空。RuntimeState.restore_prepared只接收已验证记录，pending_event_state在Game载图后一次性消费。EventPersistence.capture先刷新页，记录全部事件、隐藏/删除缓存、玩家人物、前台/地图并行/公共并行、故障/调度游标和UI队列；decode完整脱离现场校验，restore重建人物、执行器及新wait token/请求ID。分支/循环键和指针在JSON浮点转换后归一为整数。运行列表作为已选页的快照保存，换图后的前台来源坐标也保留。

玩家半格仍拒绝SaveService；NPC中途可保存，保留cell/target/start/kind/duration/elapsed及动画计时。人物图形/色相、原方向/原图案、频度、置顶和全部motion.options随已结束路线继续保存。页未改变时刷新不覆盖属性，真正换页按原生新页属性重设。离开再进入地图按源定义重建，暂时删除只在当前地图实例有效。

352使用EventUIBroker的save请求和MenuCoordinator.open_event_save，成功保存/取消均只恢复原调用者。134只限制玩家普通存档，352显式调用越过该标志且保留标志；传送/瞬时截图/场景终止仍不可保存。待显示的message/choice/number/button/shop/name/menu/save携带原payload/owner保存；已打开的menu/save不再次打开。旧回调无法唤醒恢复后的执行。

物品/技能先通过common_event_reason验证引用和单一预约；扣物品/SP后发common_event_requested关闭整套菜单，EventScheduler在前台空闲时优先启动预约并清除。CommonEventUse只实现菜单公共事件入口；已有物品确定性恢复仍有效，队友范围的未知伤害/状态/属性/随机效果不部分执行。无目标/敌人范围在原生菜单只执行公共事件，不迁移回合制效果。新游戏清预约，存档保留尚未执行预约。

## 7. 场景、暂停、显示资源与存档

Game负责组装调度器、界面路由和节点。前台事件锁输入，并行时间等待不锁菜单；EventUIBroker串行界面请求，携带请求ID及等待token恢复正确实例。MenuCoordinator.can_open/open_menu是空闲地图入口；行走中按Esc等待本格完成。close_menu恢复同一地图，不重载、不重跑初始化。open_shop校验商品并暂停，close_shop通过请求ID恢复商店所属解释器；351使用open_event_menu，303使用open_name/close_name；通过同一协调器处理输入及暂停。

所有页面navigate(direction)一般用-1/+1，activate执行、back返回；各页面的action(index)、number_action等是内部UI按钮契约，不是事件业务API。WindowBase负责皮肤和内容，Selectable负责index/item_count/scroll_row/row_height/active，Command配置[{text,enabled},...]。向上先移光标，越过可见上缘才滚动；不逐帧重建窗口全文。

DialogueOverlay.show_message(lines,request_id=-1)、show_choices(choices,cancel_type,request_id=-1)、show_number(variable_id,digits,request_id=-1)、show_diagnostic(message,request_id=-1)显示并发出完成信号；closed用于恢复输入，不等于所有解释器等待都用resume_message。当前取消选项约定需与解释器分支相配，不能根据数组下标臆造RM取消参数语义。

显示层：全景-10、雾/天气0、地图色调1、显示区域遮罩2、图片5、屏幕闪光8、计时9、测试标记10、过渡15、对话20、菜单50（CanvasLayer）。图片屏幕空间且不跟地图色调/震动；闪光覆盖地图和图片，不盖对话/菜单。图块/人物脚点排序在地图层内部，不能拿CanvasLayer与z_index混算。

ScreenRenderer推进screen及其唯一天气；MapEffectsRenderer推进map_effects和timer，并消费screen天气快照；MapCamera推进map_view；AudioRuntime自推进。普通菜单暂停地图/运动/效果/倒计时，背景音乐和play_seconds继续；标题playing=false停止游戏时长，音频由标题逻辑切换。时间推进每帧仅一次；ScreenTools是推进真实屏幕效果的特殊测试页，PresentationTools则拥有独立预览对象，不能把两者混为一套逻辑。

RmxpCache分类严格映射Graphics/{Pictures,Icons,Titles,Windowskins,Characters,Animations,Tilesets,Autotiles,Panoramas,Fogs,Battlers,Gameovers,Transitions}，picture/icon/...只取本分类；缺失null、不补RTP，拒越界路径。categories返回13个预定义分类，list_names/list_assets从asset_index枚举分类素材，供编辑器预留：不加载图像、不列工具测试图，list_assets条目{category,name,source_key,path}。resolve返回生成工程资源路径，找不到""；exists同时检查索引解析和ResourceLoader.exists，不代表对应场景行为已实现。
UIResources内部缓存texture/AtlasTexture/SystemFont，RmxpCache调用它；不要改共享texture，也不要在新类另做相同路径缓存。clear仅放弃缓存引用，不销毁仍被节点持有的纹理、不触发磁盘重新导入。UIResources.word统一标准属性/槽名，其他读取System.words；play_sound是System键的UI音效路径，不是AudioRuntime的剧情播放入口。

SaveService四槽1..4，schema=1；版本字段标记来源，不因ver0.2而更改schema或无条件拒旧原生进度。工程ID、数据库/地图指纹、测试定义、格式与SHA256整体校验仍执行。正式目录user://rgmigrator_saves/<工程隔离目录>；directory_override仅供隔离测试。

capture(state)获取快照，prepare(snapshot)脱离现场整体校验，返回{ok,state,actors,test_records,screen,map_view,map_effects,timer}；prepare失败绝不调用restore_prepared。read_path/read_slot只校验不恢复；read_slot可返回recovered=true的备份候选，UI须确认；load_slot成功会提交，因此交互读档先检查备份确认，不能重复读取/提交导致测试物资发两次。
save_slot先写临时、校验、保存有效旧主件.bak再替换；坏主件保留.damaged副本；失败不删除原槽。Game.can_save要求玩家空闲、无当前对话/商店、菜单正在save页，普通存档遵守save_disabled，原生352通过event_save_override显式调用。SaveService也复核门禁；事件/并行/排队界面/删除/人物路线可保存，仍阻止传送、瞬时过渡、场景终止和脱离数据库/验收地图。

已保存：队伍/注册角色/背包/金币/开关变量独立开关/地图格坐标朝向/步数游戏时间/存档次数/消息位置与窗口/禁用标志/测试定义/图片与屏幕效果进度/玩家选项/镜头与滚动/地图表现与天气/计时器/系统皮肤覆盖/BGM与BGS位置及记忆/淡出进度。
不保存：半格行走跳跃、正在执行的事件栈/并行调度、动画实例、事件人物运行位移、瞬时截图/淡化、ME/SE瞬时播放。旧原生schema1缺可选扩展使用默认；不读取RM Marshal存档。天气归属迁移必须兼容旧map_effects字段，不能两份同时作为真值。

ver0.27新增EventSaveTests及Run-EventSaveRender：检查所有事件位置/已结束路线属性、半格运动/原路线、调用栈/循环/分支/等待、两类并行、352成功/取消/读档续行、原生134门禁、菜单物品/技能和选人流程、预约存档、坏记录及旧schema1兼容。Run-Headless增加各样例独立event-restart-write/read进程，实测启动后继续现场；实际三尺寸渲染比较保存前后人物画面并检查页面。验证记录见tests/VERIFICATION_v0.27.md。

## 8. 事件开发的现状与接入清单

用户确定 ver0.2 系列目标为除 Ruby 脚本和回合制战斗外的 RMXP 原生事件功能，魔塔结算暂缓。90主命令中排除14项回合制专用及355脚本，剩余75项为目标；详见[事件系统计划](docs/EVENT_SYSTEM_v0.2.md)。

ver0.21：EventExecutionContext拥有独立命令指针/栈/分支/循环和来源位置，EventWait拥有类型/剩余秒数/token。EventInterpreter.start兼容立即运行到等待；managed=true由EventScheduler.advance(delta)推进，单实例每次最多256条，共享每帧2048条预算，长循环让出执行；公共调用深度32。cancel使旧等待及回调无效。

EventScheduler拥有main和按事件页/公共ID区分的parallels。确认/触碰前台串行、锁朝向和玩家；自动按条件重复；并行独立结束后下帧重启。失败自动/并行仅诊断一次，条件/页失效再激活后允许重试。地图换代取消旧并行，前台列表继续且本事件ID归0。页刷新在命令边界执行，保留同页实体，失效并行取消。

RuntimeState.set_event_switch/variable/self_switch发依赖通知；EventUIBroker串行排队message/choice/number/button/shop/name/menu/diagnostic，WeakRef绑定所属实例，旧请求ID或旧token不能恢复新执行。菜单/商店沿用暂停整张地图策略；新游戏和restore_prepared先发execution_reset清理。schema1未保存事件现场，event_save_reason同时保护UI存档及直接SaveService。

F6测试工具的“正式事件验收地图”进入EventFixture，由同一Game和正式调度器执行原生事件。“联合流程”使用选择/数字输入、公共事件等待、循环、变量、条件与计时器；“文本与按键”演示控制字符、位置/透明、新按键与分页。原地图及调度器暂停保留，包括删除标记、人物位置与并行栈；退出恢复原进度，验收地图禁止存档。

ver0.22：EventCommandCatalog在导入和执行两侧校验101–106、111、121–128参数。EventValueResolver统一查询现有RuntimeState/Actor/地图人物；缺失引用或属性必须诊断，不用0伪装。ActorState.evasion()与get_parameter("eva")合计防具eva与有效状态eva，装备自动状态去重，不新增永久eva修正。

EventMessage.format只解析RMXP的V/N/C/G/双反斜杠，返回文本与着色片段，不启用BBCode。DialogueOverlay.show_event接受kind/lines及position/frame；选择附choices/cancel，数字附variable/digits。101紧跟的102在总计四原生行能容纳时合并；103在文本少于四行时合并。显示时冻结变量/名字；按实际文字宽度自动分页，只有最后一页完成事件。数字输入初始值来自变量，限制1..8位，支持直接键入；Esc不取消数字，选择cancel=0禁止取消、1..4选择对应项、5走取消分支。旧按钮以revision失效。EventInput提供2/4/6/8/11..18映射，111使用pressed，105经broker等待新trigger并写入原生编号；同一帧多键按原生规则取最大编号。

GameTimer.working表示124开启后到停止之间，倒数归零仍working=true，running=false；条件和操作数用剩余秒向下取整，现有可见倒计时仍向上取整。存档新增working，兼容旧三字段timer。save_count在成功原子替换后增加，失败不增加；message_position默认2、message_frame默认0，schema1可选扩展缺字段补默认。

已接通的match路径（部分命令只支持所列参数）：

- 0结束；106等待（参数/20秒）；116暂时删除（前台列表下一更新继续）；101+401文本、102+402/403/404选项、103数值；104消息位置/窗口、105新按键；108/408注释。
- 111+411/412条件：开关、变量六种比较、独立开关、计时器、角色队伍/名称/技能/武器/防具/状态、人物方向、金币、库存、按住按键；敌人和Ruby脚本排除。
- 112/113/413循环/跳出，115退出，117调用公共事件，118/119标签/跳转。
- 121开关、122变量（全部非敌人操作数；Ruby负数除法/余数、±99999999上限、除零不变；范围共用一次随机值）、123独立开关、124计时器开始/停止。
- 125金币、126/127/128背包数量、129队员、134禁止存档、135禁止菜单。
- 201传送，207显示动画（并发，不等待），235擦除图片。
- 131皮肤；203滚图；204全景/雾；205/206雾渐变；241/245/249/250音频、242/246淡出、247/248记忆恢复、251停止SE。
- 311–322全部角色指令（原生六项能力值、全体目标、状态/回复/装备/职业语义）；302+605商店、303姓名输入、351菜单、353游戏结束、354标题。

ver0.27已接入：352事件存档、执行现场持久化、物品/技能公共事件使用预约。Ruby和回合制战斗明确排除。导入和运行时共用EventCommandCatalog.reason/supported/route_reason，不能报告支持但运行时失败。

后续流程：解析并完整验证参数 -> 解析正确地图/事件/角色上下文 -> 调用正式RuntimeState/服务接口 -> 若等待则登记可取消的等待条件 -> 完成后继续解释器 -> 页条件/显示必要刷新 -> 精确诊断。
同一个事件命令涉及多个效果时先整体检查；等待不能阻塞主线程、不能误暂停需要完成的动画；退出地图/事件时清理等待引用，转场/读档不重复继续旧执行栈。

ver0.24已完成Game_Screen天气归属；禁止重新写入map_effects天气字段或在解释器/渲染器重复推进天气。


### 8.3 ver0.29数据库与公共事件编辑约定

EditorDatabaseDialog经EditorPanel的F9/按钮打开，共享EditorDocuments；修改字段是脱离数据的条目草稿，切换条目自动apply到文档草稿，显式Ctrl+S/save_changes才批量写文件。0.39起关闭也提交当前字段到共享草稿，只有显式保存才写文件；校验失败保持编辑窗口。Plugin退出/构建保存也须flush当前数据库条目，unsaved_status包括尚未apply的字段。RuntimeData静态缓存不热更新，运行游戏重新读取保存定义。

EditorCommandList统一地图页/公共事件的指令与块操作；common触发0无/1自动/2并行不能套用地图trigger0…4。公共事件209的本事件由实际调用者提供；编辑器不运行调度。EditorDatabaseSchema维护原生默认值/引用/表格结构校验，只校验改动定义，保留原未知字段与历史工程的未修改数据。

EditorTilesetEditor提供原图块点选及方向/草丛/柜台/优先级/地形标记，自动图块48种形状可统一修改，写回与地图共用的原生表。EditorTableDialog编辑x-fastest RM Table，成长表x=六项/y=等级；动画cell_data转置为单元行与八项参数列，写回仍x-fastest。动画frame_max/cell_max从帧列表/表格同步。EditorSetDialog提供编号集合与初始队伍顺序；开关/变量/属性名称表不可删除/重排，编号0保护。数据库清空保留槽位和ID，新增跳过独立测试定义ID；原生Troops只读，工程扩展数据库原样保留。

数据库保存与地图共用外部SHA256冲突检测、批量预检、备份与失败回滚。测试EditorDatabaseTests打开两原工程所有标准数据库记录/公共事件，操作实际控件与保存后运行时；EditorPluginProbe在真实Godot编辑器渲染数据库、成长表、多选、公共事件与系统，游戏不运行。操作见docs/EDITOR_v0.29.md。

### 8.4 ver0.30–0.31名称与事件可读性

EditorPresentation只负责文案、枚举和参数显示；EditorCommands.summary接受EditorDocuments与当前地图人物标签。EditorDocuments.reference_label从当前文档草稿返回名称＋ID，不深复制整库、不改ID，区分未命名/缺失引用；编号0含义由调用者传入，不能对所有角色或引用统一解释成全体/无。引用选择可按名称和编号搜索；未知枚举与历史异常编号不能在打开/确认时自动替换或截断。

EditorValueForm、EditorCommandList及EditorRouteForm订阅共享草稿changed，仅刷新显示；名称刷新不得发出编辑changed或写data。变量操作数、坐标变量、人物目标、角色条件和商店类型的提示按原指令参数上下文生成，地图触发与公共触发仍不同。摘要覆盖已支持命令、控制流标记、路线和单位；坏参数/未支持指令回退为保留提示，原参数放在悬停信息中。脚本占位不报告可执行，不新增运行时功能。

用户在0.31反馈后重排0.3目标：0.32先完成地图编辑基础与主工作区，0.33完善地图制作工具；不能以查看原地图或已有绘制代码代替实际地图制作验收，必须完成空地图选图块铺设、保存、重开和正式运行核对。RM按钮式事件菜单改为0.34，双击图片替换改为0.35，图块属性/地图管理0.36、数据库与复杂数据0.37、交互及完整流程0.38、完整事件指令分类配色与最终验收0.39。详见docs/UI_ROADMAP_v0.3.md；用户随后授权实现0.32–0.33，合并交付ver0.33；后续0.34–0.39仍按计划推进。

EditorReadabilityTests覆盖独立草稿、实际字段/搜索控件、改名/撤销刷新、特殊编号、未知枚举、原地图/公共事件全部指令摘要。Run-EditorRender的ReadabilityOnly检查真实插件中的事件摘要、名称选择与公共事件，游戏不运行；操作说明见docs/EDITOR_v0.31.md。

### 8.5 ver0.32–0.33地图制作

默认绘图下层，地图树/图块面板/画布同时可见。模式/层/工具按钮由EditorPanel统一收束当前笔画后切换，图块集选择保留原图块ID；新建地图更新地图文件、manifest和map_infos统一草稿，显式保存。地图标题/尺寸、图块集名称、当前工具/坐标、笔刷大小、缩放与未保存数可见。事件模式暴露事件工具和列表，事件指令选择菜单仍留在0.34翻新。

EditorMapCanvas地图制作palette支持矩形多图块选择，brush_selected传原ID矩阵；图块属性窗口configure_tileset保持单图块tile_selected。palette_region只读选区。update_map仅更新脱离现场地图引用/重画，不重新读取数据库/素材；完整refresh仍重取素材以支持冷导入，保留同图块集的选区。set_brush控制悬停笔刷图像/边框；缩放围绕中心或鼠标位置，hover/drag坐标均按origin与zoom还原。释放到画布外、失焦/切换工具收束单笔画；Esc恢复笔画前草稿，不产生历史项。

EditorMapOps.stamp批量铺笔刷矩阵，pattern按锚点循环填充选区/连通块，line_cells补快速拖动中间点。批量写完后统一重算触及格及八邻域的自动图块，保留未触及原图块，不重算整个原地图；边缘裁切不改变地图尺寸/其他层/事件/未知字段。一笔结束才apply一次，拖动期间不写磁盘、运行状态或共享定义。复制/粘贴采用当前层完整矩阵（含空格），一次历史项。矩形松开才应用，选区仅改选择反馈。

EditorMapEditingScenario在独立.godot草稿目录通过实际palette/canvas输入、工具按钮和地图表单新建/绘制/保存/重开。Run-Headless加入两个样本地图专项及MapRuntime原生读取；Run-EditorRender的MapEditingOnly在真实插件中执行相同制作操作并截图；Run-MapEditorRender用实际显卡检查保存结果在正式MapRuntime的图块像素。检查只使用隔离fixture，不改原输入或历史验收工程。操作说明docs/EDITOR_v0.33.md。

用户在ver0.33后的讨论确认将多素材图块集组合及可扩展图层安排在0.36，与RM式逐格属性界面一起修改。普通图块引用多个等宽素材，按顺序逻辑纵向拼接，共享原图片，不生成额外合成大图、不做缩放/补边/对齐；素材顺序或尺寸变化须保护已有图块编号，地图及图块事件图形使用同一映射。地图默认三层、按需追加，编辑器应按实际z_size处理绘制/预览/复制粘贴/保存/撤销/尺寸调整，事件模式脱离固定索引3；旧RM地图保持三层。运行时已有按z_size遍历的基础，但新增层的通行和遮挡仍须验收，独立装饰层规则不能自行推断。该计划在ver0.36由用户授权实施，具体契约见8.7；详见docs/UI_ROADMAP_v0.3.md。

### 8.6 ver0.34–0.35事件编辑与素材选择

EditorEventPageForm继承EditorValueForm，常用直接控件包含图形混合方式。工程扩展字段只显示页、条件、图形和路线中的非原生附加字段，不重复标准属性；没有扩展时隐藏入口。扩展确认仅合并原先存在的扩展路径，取消不修改草稿；下划线元数据继续保留。按事件页保留未知字段、原路线和历史枚举。EditorPanel页签切换先保存当前页表单，再显示选中页，事件应用与文档保存仍分开。EditorCommandDialog三页分类按钮覆盖Commands.available全部指令，各指令继续使用原语义提示和类型表单；原不支持指令只读保留，编辑器不运行事件。

EditorAssetPreview显示独立AtlasTexture和色相ShaderMaterial，不修改文档共享纹理；EditorAssetDialog分页加载缩略图，默认定位原素材（包括无扩展名/缺失的历史名称），取消不发出accepted。确认后EditorValueForm按原字段或显式参数路径一次更新图形草稿；行走图网格方向为2/4/6/8、帧为0–3，事件图块切换行走图时tile_id归0。普通字段仍可双击，图片字段统一进入图片选择窗，音频保留名称列表。数据库左侧预览使用当前表单草稿及当前图片字段对应的色相参数，同类图片字段共用组件。所有预览固定显示用途标题、简短说明及素材名称；空槽位也显示用途，自动图块槽位标为1–7。EditorTileGraphicDialog从当前地图绑定的数据库图块集按原图网格显示普通图块（384+），另有清空图形按钮，不提供RM人物精灵不支持的自动图块新选择。更换图块时确认设置tile_id、清除character_name和character_hue，原图块不变时确认保留全部原图形值，保留不透明度、混合方式与未知字段；空图形同时清除旧行走图，取消不修改。事件图块双击定位当前图块，行走图素材按钮可切换回字符素材；没有当前地图上下文时禁用图块入口。

EditorEventAuthoringScenario在.godot隔离目录通过事件页签、按钮、图片双击、搜索/取消/确认及4×4网格点击检查草稿与保存重开；Run-Headless和Run-EditorRender的EventAuthoringOnly共用此场景，真实编辑器验证1280×800和1600×1000。操作说明docs/EDITOR_v0.35.md。0.36图块组合/逐格属性/扩展图层现已获用户授权实施；事件图形双击与按钮入口按用户意见留待后续考虑，0.39完整指令配色不提前实施。

### 8.7 ver0.36图块组合、扩展图层与地图管理

TilesetLayout接受图块集与素材加载Callable，旧定义从tileset_name及纹理/表长度取得单素材；新tileset_sources按顺序保存{key,name,rows}，普通图块编号从384起、每行8格/32px，自动图块0–383独立。key是段身份，允许同PNG重复但key不能重复；rows是固定分配行数，避免外部图片高度改变后悄悄移动后续编号。宽256px/高rows×32，不缩放补边、不生成合成图片；配置异常报diagnostic，缺图不会静默挪动ID。正常定义与纹理仍只读，tile_texture新建32×32 AtlasTexture实例。MapRuntime、EditorMapCanvas、事件图形选择及预览共用同一映射。

EditorTilesetOps.prepare脱离现场准备数据库及全部引用地图的变更；尾部追加只扩展原生标记表，换序/移除/高度替换按key和局部格偏移重映射passages/priorities/terrain_tags、所有z层与所有事件页graphic.tile_id。已使用的删除/裁切、未知旧图块编号或缺地图阻止整个变更。新总ID不得超过RM有符号表的32767；未知字段及原生其它位保留，无需扩表时保留原表头。EditorTilesetSourcesDialog浏览/取消不写草稿，确认使用apply_batch同步当前条目及地图，一个undo/redo恢复整次变更；仍需显式保存。组合后tileset_name只镜像第一素材，图块首页“普通图块素材…”统一管理单张与多张普通素材，原始source列表不经通用表单改序；图块清空同样走引用保护。

EditorTilesetEditor为数据库图块首页常驻VBoxContainer，替换原字段表及二次弹窗；六种模式、素材/背景页签复用同一Canvas，模式切换保留滚动。名称直接编辑，自动图块/全景/雾/战斗背景有具名双击预览，背景参数有独立控件；未知字段及旧枚举保留，打开不自动扩表，修改属性时才补齐表。地形绘制通过EditorMapCanvas.terrain_text按整数显示JSON浮点数。逐格展示六类标记，连续拖动插值并把首次选择的属性值涂到经过格；方向模式使用右侧四方向笔刷，优先级0–5及地形0–7循环，自动图块可共用48形状。通行位修改保留其他位；定义由切换条目、关闭或保存时的内部校验合并进编辑草稿；0.39已去掉手动应用按钮。

EditorMapOps.layer_count/layer_names/set_layer_count处理实际z_size；默认3、范围1–32。追加空层，减少层数拒绝丢弃非零格。Panel事件模式独立boolean与按钮，不把索引3固定解释成事件；第四层是绘图。layer_names与_editor_hidden_layers为编辑元数据，隐藏层不能绘制，运行时不消费隐藏元数据。渲染、复制、resize及原生通行/地形按实际层数；新增层仍按优先级0短路通行和人物脚点前景排序，不根据层名推断装饰规则。

EditorDocuments.apply_batch对全部候选值临时预置后校验，任何失败恢复全部值且不添历史；成功作为单次历史，磁盘仅save_all写。read能返回撤销新文件后的null。地图新建/复制/属性更新走原子事务；resize保护事件及系统起点，父地图须存在且无环，未知地图/表/事件字段保留。数据库关闭后Panel重新读取地图，防止用旧草稿覆盖已同步图块编号。Panel按素材段key及编号范围比较布局，布局或图块集变化后重置笔刷与图块/事件剪贴板，避免粘贴旧编号；同一布局的普通刷新保留多格笔刷。

EditorTilesetLayersScenario在.godot隔离文件和显式纹理夹具检查组合、改序/删除/尺寸保护、逐格连续输入、五层绘制/复制/可见性/撤销/resize/父子关系、保存重开和图块事件预览。EditorTilesetLayersTests读取落盘定义经过实际MapRuntime/MapEvent，验证新增层原生通行及标记；Run-MapEditorRender的TilesetLayers用真实Compatibility核对两素材、第五层和前景人物像素。Run-EditorRender的TilesetLayersOnly检查真实插件与两种分辨率，游戏不运行。操作说明docs/EDITOR_v0.36.md。

### 8.8 ver0.37数据库与复杂数据

EditorDatabaseForm继承EditorValueForm的数据草稿/引用/素材/表格/集合机制，隐藏主界面的字段树和旧工具条，按用途页签生成直接控件；图片预览放在首个用途页签，数据库左侧旧预览隐藏。扩展入口只包含实际未识别字段，不能重复已实现属性。未知字段及旧异常数值/枚举浏览时保留，只有显式操作更新草稿。Troops原生战斗数据保持只读，Enemy.actions元数据保留，本版不实现战斗。

EditorNamesEditor以原数组索引维护开关/变量/属性名称，编号0保留，分页/搜索不能改编号，新增只追加末尾；清空名称不删除。EditorLearningsEditor操作独立learnings副本，同等级多项和原顺序合法，未知条目字段保留；特技使用共享具名引用选择；EditorValueForm.edit_path自动定位数组分页，专用列表第81条及之后的引用/素材不能因隐藏定位树分页而失效。EditorTableDialog成长列显示六项能力及整数，等级0保护；属性/状态有效度通过EditorDocuments解析名称，A–F映射原生1–6，范围外值额外标注原值，打开不截断。集合显示用途、选中数量及具名条目；初始队伍保留可排序语义。

EditorAnimationEditor编辑原生frames、cell_data及timings，原表按x快速变化保存，最多16个活动单元；增删/复制帧与单元显式同步计数，复制已分配但未使用列的帧须保持cell_max。Schema.normalize只为未显式修改计数的旧表格尺寸操作补计数。UI时序帧号从1开始、JSON从0开始；删除有时序的帧拒绝，删除早期帧同步后续时序。EditorAnimationCanvas单元为192px/5列图案，按原坐标、负旋转角、镜像、缩放、不透明度、混合和色相独立预览。纹理不修改，材料归各画布；播放默认20动画帧/秒，仅更新显示，不发编辑信号、不运行游戏/音效/目标闪光。保存结果通过实际RmxpAnimationData.compile/resolve读取。

EditorMapCanvas.set_palette_zoom控制属性调色板显示及点击坐标，EditorTilesetEditor默认1.5倍；实际图块和编号不变。EditorDatabaseAuthoringScenario通过专用可见控件检查编辑、草稿/取消、保存重开、名称稳定性、习得/集合/有效度和动画计数/时序；Tests调用正式动画编译与资源解析，Run-EditorRender -DatabaseAuthoringOnly检查真实插件布局和预览像素。完整事件指令配色仍属0.39。

### 8.9 ver0.37反馈修正

EditorAudioPreview归编辑器实例，通过EditorDocuments.asset_audio加载只读流后复制并关闭流循环；不更改共享资源或RuntimeState。EditorAudioBrowser复用在弹窗及数据库音频库；Audio为虚拟素材分类，不创建数据库JSON。EditorValueForm将AudioFile或无class的name/volume/pitch字典及子字段交给专用选择器，接受时保留未知字段。所有系统、地图、指令、路线、物品与动画音频都使用该入口。

EditorAnimationEditor从帧0开始逐帧播放SE及命中条件，默认单次，循环显式开启；尾音自然完成，关闭/停止清理声音。目标闪光仅正式RmxpAnimationPlayer处理。EditorMapLocationPicker通过EditorMapCanvas渲染草稿中的实际图块与各层，只列manifest实际地图，点格发chosen；System改当前条目草稿，201写直接坐标，变量模式不猜实际位置。系统页由左侧导航切换，常用字段无重复入口。

事件拖动仅事件模式捕获已有事件，过程中不写历史或文件，释放提交一次，Esc恢复；ID/页/未知字段保持。起点按钮删除，右键目标格指定并刷新标记。引用统一[xxxx] 名称，摘要按类型/名字/变化，数量允许省略名字；配色仍0.39。EditorFeedbackScenario/Tests与Run-EditorRender -FeedbackOnly检查两种尺寸及实际非零混音；测试总线低音量隔离，不将headless播放对象当作听音证据。

### 8.10 ver0.38–0.39交互、编号容量与配色

用户授权推进到0.39，合并实施0.38已记录的六项交互优化和0.39配色/最终验收。数据库按类别保持有效用途页签；动画切换、保存和类别往返保留动画编辑页并停止旧预览。公共事件设置区收紧，指令列表为主要空间。数据库手动应用按钮移除，切换/关闭/保存调用原校验提交草稿；显式Ctrl+S才写文件，关闭不是放弃修改，撤销可恢复。

EditorCapacityOps.resize为脱离现场容量计划，1–32767最大编号，不改ID或编号0；新增普通数据库槽位null、名称槽位空字符串。浏览空槽位只显示默认值，实际修改才建立定义。缩容拒绝有内容、测试保留ID、原生字段/集合/事件/路线的越界引用；未知指令可能引用越界数值时保守拒绝。独立测试定义编号在数据库中标为保留且不可编辑，扩容不会覆盖测试定义。条目列表每组100项并支持搜索/编号跳转，扩容一次历史项，不为每个空槽位生成复杂默认结构；RuntimeData仍只读缓存和直接按ID读取。

EditorCommandColors统一地图事件、公共事件和路线的类别色，浅色主题使用深色调；脚本占位及未支持状态保持文字/悬停提示，结束标记降强调，选中使用主题高对比文字。颜色不改原code、parameters、indent或脚本保留字段。图块标记在实际显示坐标绘制，O/X/箭头/星形使用几何图案、整数文字按实际字体尺寸居中；图块纹理继续最近邻缩放，点击按zoom还原。图块调色板仅绘制与祖先滚动视口相交的行列，滚动/视口变化触发重绘；类别色不逐行重复修改同一主题属性。顶部吸管按钮和I快捷键移除，右键拾取当前层后返回铅笔，事件右键仍为上下文菜单。

EditorFinalUiScenario/Tests以独立数据检查500/5000容量、空槽位创作、保存重开/运行时、撤销/缩容引用保护、动画页保持、公共事件布局、两套配色、放大标记与右键拾取。Run-Headless和Run-EditorRender -FinalUiOnly接入专项，真实界面通过两种窗口尺寸检查，正式交付从原RM运行新迁移且保留历史输出。

### 8.11 ver0.40脚本盘点与最小转换

ScriptMigrationInventory在EditorScriptAdapter之前提取355/655、111脚本条件、强制/自主路线45；每个片段保留地图/事件/页或公共事件、原指令编号及续行/路线编号，并建立源码行到原指令的映射。按源Interpreter的覆盖证据合并相邻355；闪翼使用__UBIND并继续，二律背反的false结果返回等待。脚本ID、加载顺序来自Scripts.rxdata，镜像另行比对并保留，差异不能静默当作已加载。词法声明/调用/功能词只提供追溯候选，不是完整AST或语义解析；中文变量、操作符方法、同名方法每次定义和alias保持加载顺序，不合并或宣称绑定完成。

RubySubsetCompiler仅编译$game_variables[正整数]的十进制常量赋值/增减与$game_switches[正整数]=true/false。支持换行、分号、普通行注释；整数绝对值不超过2147483647；拒绝前导零、动态下标、表达式、条件、方法及其余结构，整段不生成。AST保存语句/赋值目标/值及1起始Unicode字符行列，IR为state_write。生成工程data/script_units.json登记单元、AST/IR、来源、诊断和生成路径，data/script_inventory.json登记加载/依赖证据，script_inventory.md供阅读。

ScriptRuntime.execute_unit(unit_id,state)显式加载迁移时生成的runtime/generated/*.gd；ScriptStateBridge先整体检查操作和值，再用现有set_event_switch/variable写同一状态并发事件/界面通知。未知单元或越界结果返回失败，origin/span保留。当前只供明确调用及验证，不自动执行源脚本列表，不恢复355/111/45占位，也不改变Interpreter调度；完整入口按0.43实施。generated不是运行验证或玩法已迁移，验证结果见tests/VERIFICATION_v0.40.md。

EditorCommandList的_structures记录条件/选择/循环完整span，结构线贯穿内部至对应结束，指令条仅贯穿自己的续行并按indent内缩。空白缩进预留结构线位置；原正文对齐、整条选择、复制/删除/移动行为保持。EditorStructureGuideScenario用于真实插件两尺寸与滚动检查。

### 8.12 ver0.41/0.42脚本AST和语义转换

用户要求保留原计划顺序，0.41与0.42已实现并通过阶段验证，不前移0.43事件入口和0.48工作区。正式工程分别位于../output/0.41/final/和../output/0.42/verified/；验证见tests/VERIFICATION_v0.41_v0.42.md。实现说明见docs/SCRIPT_MIGRATION_v0.41_v0.42.md。RubyLexer/RubyParser补齐表达式和语句节点、块/异常及源位置；RubySemanticModel按AST记录作用域、各次定义和alias捕获版本，动态调用仍标明未绑定。0.41只保持原最小执行范围；0.42由RubyGDScriptCompiler生成直接GDScript函数/分支/循环。

ScriptSemantics提供旧Ruby真值/数值/集合/方法分派等已支持语义；方法表保存覆盖和旧别名，状态只桥接同一RuntimeState。execute_unit显式加载单元，call_method/new_object显式调用；session在新游戏/读档清空，自定义对象持久化留在0.47。变量、开关、金币先暂存后提交，失败回滚保留共享集合关系。未支持语义不生成空函数；字节字符串/异常路径/非局部返回等明确失败。data/script_ast、script_semantics.json、script_source_map.json分别提供AST、定义依赖与Ruby到GDScript源码映射。generated不代表依赖可用、事件接入或玩法已完成；原355/111/45占位保持。

## 9. 测试、版本和文档维护

版本唯一源scripts/Version.gd；模板RuntimeVersion.gd同步，ProjectGenerator生成时还会从唯一源覆盖。project.godot标题同步；新报告、生成配置注释/README/存档runtime_version应显示当前版本。历史CHANGELOG和tests/VERIFICATION_v0.xx、ACCEPTANCE_v0.xx保留历史版本，不批量改写验收证据。

本机引擎传入D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe（这是目录）；PowerShell测试脚本自动找其中*_console.exe。直接执行Godot时使用该目录里的Godot_v4.7.2-stable_win64_console.exe。

```powershell
& 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/DocumentationTests.gd
./tests/Run-Headless.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe' -SkipMigration -RefreshRuntime -SkipImport
```

默认不SkipMigration会迁移两个只读样例到新的.godot/test_exports_*；RefreshRuntime只更新.godot/test-results.json列出的隔离输出，不改已验收工程。EventTests覆盖执行等待帧率、调用栈/115、循环/标签、五种触发、自动/并行、页刷新/116、旧回调、菜单暂停、真实验收地图恢复及存档门禁。新增接口至少覆盖独立标准夹具、无效引用/原子失败、样例集成、菜单暂停和存档；render必须用真实Compatibility，不能headless代替画面。

EventActorSceneTests与Run-EventActorSceneRender覆盖0.26原生参数、全体角色事务、状态/装备关联、姓名键盘、串行界面与实际场景切换。测试定位：RuntimeTests/EventInterpreter基础；MenuTests互斥与返回；InventoryTests物品装备；SkillAnimationTests学习及独立并发动画；ShopStateTests商店状态；ActorMutationTests成长；ScreenTests图片屏幕；GraphicsCacheTests分类；MovementTests人物碰撞；PresentationTests镜头/天气/雾/计时/音频；SaveTests及SaveRestartTests保存/跨进程；RuntimeCompileTests类加载。EventScreenTests覆盖ver0.24命令/天气迁移，Run-EventScreenRender检查真实像素和过渡协议；EventPresentationTests及Run-EventPresentationRender覆盖0.25系统、地图、音频、失败原子性及实际皮肤/全景/雾/滚图。Run-Render、Run-MenuRender、Run-MovementRender、Run-PresentationRender为实际画面；后者-Benchmark为768×768/60秒负载，不把历史性能数值当本版重测。

DocumentationTests校验附录覆盖全部234个生产脚本、非下划线函数签名、带参数构造器、信号、继承声明、字段/常量清单与版本。附录包含内部UI辅助公共方法是为了完整索引，不意味着这些方法获准作为事件业务入口。公开字段清单也不表示可绕过业务方法任意赋值；初始化依赖字段和可写选项见各类说明。添加方法/类后先同步描述与附录，再测。

## 10. 按文件的全部接口索引

下列签名逐字对应源码；static func为脚本静态调用，其余为实例调用，_init参数作为.new(...)参数。继承类也拥有父类接口，附录只列当前文件自己声明的部分。Godot生命周期、前导下划线辅助实现以及继承自Godot的通用方法不重复罗列。每节说明调用者、作用和已知限制；详细业务参数遵守第3–8节。

### ActorParameters.gd

公开字段：无。

常量（不含依赖脚本引用）：`KEYS`、`TABLE_KEYS`、`MAX_EXPERIENCE`。

源文件：templates/runtime/scripts/ActorParameters.gd。纯计算服务；integer/minimum/maximum校验/上下限，calculate返回values/sources且不修改输入，apply_bonus按plus/倍率/限幅计算。不保存角色、不执行状态战斗效果。

```gdscript
extends RefCounted
static func integer(value: Variant, minimum: int = -9007199254740991, maximum: int = 9007199254740991) -> bool
static func maximum(key: String) -> int
static func minimum(key: String) -> int
static func calculate(database: Dictionary, equipment: Array[Dictionary], states: Array[Dictionary], bonuses: Dictionary, invalid_equipment: bool) -> Dictionary
static func apply_bonus(key: String, base: int, bonus: int, rates: Array) -> int
```

### ActorState.gd

公开字段：`id`、`actor_name`、`class_id`、`level`、`final_level`、`experience`、`character_name`、`character_hue`、`battler_name`、`battler_hue`、`last_mutation_result`、`equipment`、`state_ids`、`diagnostics`、`hp`、`sp`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/ActorState.gd。角色唯一运行对象由RuntimeState.actor获取；changed通知。configure仅初始化/重置，查询与修改、State来源、成长和persistent_data/restore_persistent契约见第5节；snapshot覆盖参数只预览，职业/库存交换必须通过RuntimeState/InventoryService。

```gdscript
extends RefCounted
signal changed
func configure(actor_id: int, definition: Dictionary, lookup: Callable) -> void
func learn_skill(skill_id: int) -> Dictionary
func forget_skill(skill_id: int) -> Dictionary
func has_skill(skill_id: int) -> bool
func get_skill_ids() -> Array[int]
func add_state(state_id: int) -> Dictionary
func add_state_native(state_id: int) -> Dictionary
func remove_state(state_id: int) -> Dictionary
func clear_states() -> Dictionary
func automatic_state_ids() -> Array
func change_hp_native(amount: int, allow_death: bool, zero_hp_ids: Array) -> Dictionary
func apply_equipment_states(previous_auto: Array) -> Dictionary
func recover_all() -> Dictionary
func detached_copy() -> Dictionary
func commit_event_state(prepared: RefCounted) -> void
func has_state(state_id: int) -> bool
func get_state_ids(include_equipment: bool = true) -> Array[int]
func persistent_data() -> Dictionary
func restore_persistent(saved: Dictionary) -> String
func slot_fixed(slot: int) -> bool
func snapshot(equipment_override: Array = [], level_override: int = -1, bonuses_override: Dictionary = {}) -> Dictionary
func parameter_sources(key: String) -> Dictionary
func get_parameter(key: String) -> Variant
func get_base_parameter(key: String) -> Variant
func get_equipment_parameter(key: String) -> Variant
func get_parameter_plus(key: String) -> Variant
func set_parameter_plus(key: String, value: Variant) -> Dictionary
func add_parameter_plus(key: String, amount: Variant) -> Dictionary
func set_parameter(key: String, value: Variant) -> Dictionary
func experience_for_level(value: int) -> Variant
func next_level_experience() -> Variant
func set_experience(value: Variant) -> Dictionary
func add_experience(amount: Variant) -> Dictionary
func set_level(value: Variant) -> Dictionary
func add_level(amount: Variant) -> Dictionary
func set_vital(key: String, value: Variant) -> Dictionary
func add_vital(key: String, amount: Variant) -> Dictionary
func recover_vitals() -> Dictionary
func rename(value: Variant) -> Dictionary
func set_graphic(value: Variant, hue: Variant = 0) -> Dictionary
func set_event_graphic(character: String, hue: int, battler: String, battler_color: int) -> Dictionary
func evasion() -> Variant
```

### ActorTools.gd

公开字段：`actor_id`、`parameter`、`selected`、`message`。

常量（不含依赖脚本引用）：`ACTIONS`。

源文件：templates/runtime/scripts/ActorTools.gd。F6角色成长测试UI，actor_id/parameter/selected选择当前对象/属性/按钮；refresh/paint_selection/update身份表单，action/identity_action执行已定义按钮，text_edit/parameter_name为UI辅助。navigate/activate/back/handle_key由菜单路由，has_text_focus防止编辑文本被快捷键截获，不是剧情事件入口。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func parameter_name(key: String) -> String
func paint_selection() -> void
func navigate(direction: int) -> void
func activate() -> void
func action(index: int) -> void
func open_identity() -> void
func text_edit(caption: String, value: String, y: float) -> LineEdit
func identity_action(index: int) -> void
func close_identity() -> void
func has_text_focus() -> bool
func back() -> void
func handle_key(key: int) -> void
```

### AnimationLab.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/AnimationLab.gd。原动画并发测试UI；play_at目标索引0/1，animation_id=0取当前选择而非正式播放的空动画语义。action/navigate/activate路由测试按钮，stop_all停止该页实例，back返回。独立目标，不代替当前地图的animation_target。

```gdscript
extends Control
signal back_requested
func play_at(target_index: int, animation_id: int = 0) -> Dictionary
func action(value: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func stop_all() -> void
func back() -> void
```

### AudioRuntime.gd

公开字段：`channels`、`definitions`、`fades`、`memory`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/AudioRuntime.gd。RuntimeState.audio持有的长寿命Node；播放参数、ME协调、SE上限、fade_out、memorize/restore_memory/snapshot返回差异见第4.3节。菜单不暂停音频，不把memory/播放进度存进现有存档。

```gdscript
extends Node
static func prepare_audio(kind: String, audio: Dictionary, position_seconds: Variant = 0.0) -> Dictionary
func play(kind: String, audio: Dictionary, position_seconds: Variant = 0.0) -> Dictionary
func stop(kind: String) -> void
func stop_all() -> void
func fade_out(kind: String, seconds: Variant) -> Dictionary
func memorize() -> Dictionary
func restore_memory() -> Dictionary
func persistent_snapshot() -> Dictionary
static func decode_persistent(value: Variant) -> Dictionary
func restore_prepared(prepared: Dictionary) -> void
func snapshot() -> Dictionary
```

### CharacterMotion.gd

公开字段：`cell`、`target`、`visual_cell`、`direction`、`pattern`、`options`、`jump_height`。

常量（不含依赖脚本引用）：`DIRECTIONS`、`DEFAULTS`。

源文件：templates/runtime/scripts/CharacterMotion.gd。纯运动状态；cell/target格，visual_cell浮点格，direction/pattern/options/jump_height。validate可partial或complete，configure原子更新；begin_move/begin_jump仅启动运动，不查地图碰撞（先由MapCharacter校验）。advance返回空字符串或完成类型walk/jump；relocate立即定位，reset默认重置，snapshot给像素real_x/y。

```gdscript
extends RefCounted
static func validate(value: Variant, complete: bool = false) -> bool
func configure(value: Dictionary) -> Dictionary
func reset() -> void
func relocate(destination: Vector2i) -> void
func is_idle() -> bool
func moving() -> bool
func jumping() -> bool
func turn(value: int, force: bool = false) -> bool
func pixels_per_second() -> float
func begin_move(value: int) -> bool
func begin_diagonal(offset: Vector2i) -> bool
func turn_diagonal(offset: Vector2i) -> bool
func begin_jump(offset: Vector2i) -> bool
func advance(delta: float) -> String
func snapshot() -> Dictionary
func persistent_data() -> Dictionary
static func decode(value: Variant, width: int, height: int) -> Dictionary
```

### CharacterSprite.gd

公开字段：无。

常量（不含依赖脚本引用）：`HUE_SHADER`。

源文件：templates/runtime/scripts/CharacterSprite.gd。菜单TextureRect角色图；configure使用Characters四方向四帧、独立色相，set_frame方向2/4/6/8和pattern0..3。没有地图碰撞/运行角色状态，纹理共享但实例材料独立。

```gdscript
extends TextureRect
func configure(character_name: String, hue: int = 0, direction: int = 2, pattern: int = 0) -> void
func set_frame(direction: int, pattern: int) -> void
```

### DialogueOverlay.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/DialogueOverlay.gd。CanvasLayer20，show_*与is_open及信号连接见第7节。数字输入完成返回数值，不负责直接修改变量。诊断显示不提供Ruby执行或完整RM文本控制码。

```gdscript
extends CanvasLayer
class_name DialogueOverlay
signal message_confirmed
signal choice_selected(index: int)
signal number_confirmed(value: int)
signal closed
signal event_response(request_id: int, kind: String, value: Variant)
signal event_failed(request_id: int,message: String)
func is_open() -> bool
func show_message(lines: Array, request_id: int = -1, options: Dictionary = {}) -> void
func show_choices(choices: Array, cancel_type: int, request_id: int = -1, options: Dictionary = {}) -> void
func show_number(variable_id: int, digits: int, request_id: int = -1, options: Dictionary = {}) -> void
func show_button(variable_id: int, request_id: int = -1, options: Dictionary = {}) -> void
func show_event(payload: Dictionary, request_id: int = -1) -> void
func show_diagnostic(message: String, request_id: int = -1) -> void
func dismiss() -> void
```

### EventInterpreter.gd

公开字段：`map_runtime`、`context`、`wait_state`、`managed`、`time_budget_usec`、`parallel`、`common_events`、`running`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventInterpreter.gd。RefCounted单个执行实例；context与wait_state独立，managed决定立即运行或预算推进。resume带可选token；cancel清理等待。reject_shop输出精确诊断并中断。信号与已接通指令见第8节；禁止额外创建天气/角色真值。

```gdscript
extends RefCounted
class_name EventInterpreter
signal message_requested(lines: Array)
signal unblocking_message_requested(lines: Array,event_id: int)
signal choices_requested(choices: Array, cancel_type: int)
signal number_requested(variable_id: int, digits: int)
signal dialogue_requested(payload: Dictionary)
signal button_requested(variable_id: int)
signal shop_requested(goods: Array)
signal name_requested(actor_id: int, maximum: int)
signal menu_requested
signal save_requested
signal scene_requested(kind: String)
signal diagnostic_requested(message: String)
signal completed
signal failed
func start(commands: Array, event_id: int, page: int = 1) -> void
func resume_message(token: int = -1) -> void
func reject_dialogue(message: String) -> void
func resume_choice(choice: int, token: int = -1) -> void
func resume_number(value: int, token: int = -1) -> void
func resume_button(code: int, token: int = -1) -> void
func resume_shop(token: int = -1) -> void
func advance(delta: float, budget: int = 256) -> int
func cancel() -> void
func wait_token() -> int
func wait_kind() -> String
func reject_shop(message: String) -> void
func resume_scene_ui(kind: String, value: Variant = null, token: int = -1) -> void
func reject_scene_ui(kind: String, message: String) -> void
```

### Game.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/Game.gd。Game.tscn组装者，自动创建地图、玩家、相机、显示层、解释器、对话和菜单；无通用Scene栈公共API。can_save为完整上下文门禁，save_slot成功委托SaveService。_map/_interpreter/_transition等属内部，未来事件统一入口不要绕过门禁。

```gdscript
extends Node2D
func can_save() -> bool
func play_flash_effect(name: String,args: Array=[]) -> Dictionary
func unravel_picture(number: int,args: Array=[]) -> Dictionary
func unravel_character(event_id: int=-1,args: Array=[]) -> Dictionary
func show_flash_scene(source_name: String,args: Array=[]) -> Dictionary
func event_save_override() -> bool
func capture_event_state(detached_nodes: Array=[]) -> Dictionary
func script_field_roots() -> Array
func restore_event_state() -> void
func event_save_reason(ignore_checkpoint: bool=false) -> String
func event_map() -> Node
func event_transfer_ready() -> bool
func event_ui_available() -> bool
func event_scene_transition_active() -> bool
func request_event_scene(kind: String) -> void
func scroll_event_map(direction: int, tiles: int, speed: int) -> Dictionary
func event_screen_transition_active() -> bool
func event_screen_transition_ready() -> bool
func begin_event_screen_transition(code: int, name_value: String = "") -> Dictionary
func event_screen_transition_status(id: int) -> Dictionary
func cancel_event_screen_transition(id: int = 0) -> void
func begin_event_transfer(map_id: int, x: int, y: int, direction: int, fade: bool) -> Dictionary
func event_transfer_status(id: int) -> Dictionary
func cancel_event_transfer() -> void
func reset_event_execution() -> void
func enter_event_test_map() -> Dictionary
func start_event_test_scenario(name: String) -> Dictionary
func exit_event_test_map() -> void
func save_slot(slot: int) -> Dictionary
```

### GameTimer.gd

公开字段：`remaining`、`running`、`working`、`visible`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/GameTimer.gd。RuntimeState.timer持有的纯计时状态；remaining/running/visible，expired信号、start/stop/text、decode见第4.3节。由MapEffectsRenderer推进，不能再在解释器每帧advance。

```gdscript
extends RefCounted
signal expired
func start(seconds: Variant, show: bool = true) -> Dictionary
func stop() -> void
func advance(delta: float) -> void
func text() -> String
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### InventoryScene.gd

公开字段：`mode`、`actor_id`、`page`、`list_index`、`target_index`、`slot_index`、`candidate_index`、`active_item_id`、`message`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/InventoryScene.gd。Control，mode为inventory/equipment、actor_id选角色；refresh按当前页面重建内容，navigate/activate/back按列表→角色→槽位→候选→确认层级路由。back_requested/sound_requested交MenuScene处理；业务修改仅通过InventoryService/RuntimeState。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
signal common_event_requested
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### InventoryService.gd

公开字段：无。

常量（不含依赖脚本引用）：`DATABASES`。

源文件：templates/runtime/scripts/InventoryService.gd。静态确定性物品/装备事务；entries/item_reason/equip_reason查询不提交，空reason表示可尝试。use_item成功含targets数量，equip_preview返回before/after/equipment，equip正式交换；failure为统一失败包装。限制和参数见第4.2节。

```gdscript
extends RefCounted
static func entries(state: Node) -> Array[Dictionary]
static func item_reason(item_id: int) -> String
static func use_item(state: Node, item_id: int, target_id: int) -> Dictionary
static func equip_reason(state: Node, actor_id: int, slot: int, equipment_id: int) -> String
static func equip_preview(state: Node, actor_id: int, slot: int, equipment_id: int) -> Dictionary
static func equip(state: Node, actor_id: int, slot: int, equipment_id: int) -> Dictionary
static func failure(message: String) -> Dictionary
```

### MapCamera.gd

公开字段：`model`、`map`、`player`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapCamera.gd。Camera2D，必须在add_child前设model(MapViewState)、map(MapRuntime)、player(MapCharacter)；sync计算当前尺寸/边界/跟随，snap仅强制定位；scroll委托model且提供地图尺寸。震动offset来自ScreenRenderer，不让第二套相机逻辑覆盖display。

```gdscript
extends Camera2D
func sync(delta: float = 0.0, snap: bool = false) -> void
func scroll(direction: int, tiles: Variant, seconds: Variant) -> Dictionary
```

### MapCharacter.gd

公开字段：`motion`、`routes`、`always_on_top`、`map_runtime`、`character_id`、`fallback_visible`、`tile_position`、`facing`、`move_speed`、`through`、`direction_fix`、`walk_anime`、`step_anime`、`transparent`、`opacity`、`blend_type`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapCharacter.gd。Node2D共用人物显示/运动父类；map_runtime、motion、character_id，派生PlayerController/MapEvent。set_graphic(name,hue,tile_id)可Characters或图块；tile_position/facing与选项属性代理motion。move_straight/move_to/jump、occupied_cells、arrived、advance_motion见第6节；animation_bounds给本人物局部图像范围。

```gdscript
extends Node2D
signal arrived(kind: String)
signal occupancy_changed
func set_graphic(name_value: String, hue: int = 0, tile_id: int = 0) -> void
func is_idle() -> bool
func moving() -> bool
func motion_snapshot() -> Dictionary
func persistent_data() -> Dictionary
func restore_persistent(value: Dictionary) -> void
func jumping() -> bool
func configure_motion(value: Dictionary) -> Dictionary
func turn(direction: int) -> bool
func move_straight(direction: int, turn_on_failure: bool = true) -> bool
func move_diagonal(offset: Vector2i) -> bool
func force_move_route(route: Dictionary, source: String = "", on_error: Callable = Callable()) -> Dictionary
func cancel_move_route(stop_autonomous: bool = false) -> void
func reset_route_state() -> void
func route_locked() -> bool
func clear_route_lock_direction() -> void
func set_always_on_top(value: bool) -> void
func set_route_graphic(name_value: String, hue: int, direction: int, pattern: int) -> void
func move_to(x: int, y: int) -> bool
func jump(x: int, y: int) -> bool
func occupied_cells() -> Array[Vector2i]
func advance_motion(delta: float) -> String
func animation_bounds() -> Rect2
```

### MapEffectsRenderer.gd

公开字段：`model`、`view_model`、`timer_model`、`screen_model`、`preview`、`map`、`camera`、`texture_overrides`、`panorama`、`fog`、`weather`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapEffectsRenderer.gd。Node持有全景/雾/天气/边界/计时显示组；add_child前设置model、view_model、screen_model，选填timer_model/map/camera。sync既推进模型又同步显示，不能重入重复计时；preview=true仅隔离预览，texture_overrides只用于工具对照图。不是天气状态拥有者。

```gdscript
extends Node
func sync(delta: float) -> void
```

### MapEffectsState.gd

公开字段：`data`、`revision`。

常量（不含依赖脚本引用）：`DEFAULTS`。

源文件：templates/runtime/scripts/MapEffectsState.gd。地图表现纯模型，data只含map_id和全景/雾/渐变；configure仅接受9个素材/静态参数，setup_map同图保留、换图重置雾。decode可校验并提取旧天气，返回legacy_weather供SaveCodec迁移，现场不再保存或推进天气。

```gdscript
extends RefCounted
static func validate(value: Variant) -> bool
func configure(changes: Dictionary) -> Dictionary
func setup_map(id: int, tileset: Dictionary) -> Dictionary
func tint_fog(tone: Array, seconds: Variant = 0.0) -> Dictionary
func fade_fog(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
func advance(delta: float) -> void
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### MapEvent.gd

公开字段：`event_id`、`map_id`、`trigger`、`commands`、`blocking`、`page_index`、`tile_id`、`locked`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapEvent.gd。继承MapCharacter，event_id/map_id/trigger/commands/blocking/page_index/tile_id；configure根据选定页设置图像和运动选项。front_interaction遵循RM原生over_trigger?：非穿透角色图或当前位置原生方向0通行检查失败时从正面触发，不以图块显示优先级判断。自主/强制路线由继承的MapCharacter.routes执行；本类不自行调度并行解释器。

```gdscript
extends "res://runtime/scripts/MapCharacter.gd"
class_name MapEvent
func configure(event_data: Dictionary, page: Dictionary, id: int, current_map_id: int) -> void
func front_interaction() -> bool
func lock() -> void
func unlock() -> void
func route_locked() -> bool
func clear_route_lock_direction() -> void
func set_route_graphic(name_value: String, hue: int, direction: int, pattern: int) -> void
func move_straight(direction: int, turn_on_failure: bool = true) -> bool
func move_diagonal(offset: Vector2i) -> bool
func jump(x: int, y: int) -> bool
```

### MapRuntime.gd

公开字段：`player_trigger_request`、`map_data`、`tileset`、`player_character`、`character_layer`、`background_visible`、`trigger_allowed`、`generation`。

常量（不含依赖脚本引用）：`TILE_SIZE`、`AUTOTILE_PARTS`。

源文件：templates/runtime/scripts/MapRuntime.gd。Node2D地图容器；map_data/tileset/通行与优先级表，player_character指向玩家。载入、查询、碰撞、触发、传送、动画接口见第6节。ensure_character_layer提供人物与前景同组排序；set_background_visible/draw_tile供显示组使用。show_picture/move_picture是遗留参数适配辅助且未接通231/232，未来接入需完整解析变量坐标/时间，不直接复用当已兼容；play_audio只接受现有241/245/249/250，stop_sound_effect只停SE。

```gdscript
extends Node2D
class_name MapRuntime
signal event_requested(commands: Array, event_id: int)
signal map_changed(map_id: int)
signal events_changed
func load_map(map_id: int) -> bool
func ensure_character_layer() -> Node2D
func load_definition(definition: Dictionary, tileset_definition: Dictionary) -> void
func apply_flash_tiles(changes: Dictionary,rebuild: bool=true) -> void
func map_width() -> int
func map_height() -> int
func valid(x: int, y: int) -> bool
func tile_id(x: int, y: int, layer: int) -> int
func tile_priority(id: int) -> int
func tile_texture(id: int) -> Texture2D
func can_overlap_trigger(cell: Vector2i) -> bool
func terrain_tag(x: int, y: int) -> int
func is_bush(x: int, y: int) -> bool
func is_counter(x: int, y: int) -> bool
func event_ids_at(x: int, y: int) -> Array[int]
func can_move(from: Vector2i, direction: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool
func can_stand(cell: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool
func can_move_diagonal(from: Vector2i, offset: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool
func request_action(position: Vector2i, facing: Vector2i) -> bool
func trigger_player_touch(position: Vector2i, blocked: bool = false) -> bool
func autorun_event() -> Dictionary
func event_page(event_id: int) -> int
func refresh_events() -> void
func event_contexts() -> Array[Dictionary]
func event_node(id: int) -> Node
func erase_event(id: int) -> Dictionary
func has_erased_events() -> bool
func flush_event_refresh() -> void
func request_event_touch(event: Node, target: Vector2i) -> bool
func animation_target(character_id: int, current_event_id: int = 0) -> CanvasItem
func set_character_position(target_id: int, mode: int, x: int, y: int, direction: int, current_event_id: int = 0) -> Dictionary
func has_forced_routes() -> bool
func repeating_forced_routes() -> Array[int]
func character_save_reason() -> String
func cancel_character_routes() -> void
func play_animation(animation_id: int, character_id: int = -1, current_event_id: int = 0, hit: bool = true) -> Dictionary
func transfer(map_id: int, x: int, y: int, direction: int = 0) -> bool
func show_picture(parameters: Array) -> void
func move_picture(parameters: Array) -> void
func erase_picture(number: int) -> void
func play_audio(code: int, audio: Variant) -> void
func stop_sound_effect() -> void
func set_background_visible(value: bool) -> void
func draw_tile(canvas: CanvasItem, id: int, destination: Vector2) -> void
```

### MapTileRow.gd

公开字段：`map_runtime`、`cells`、`animated`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapTileRow.gd。Node2D图块前景行，map_runtime/cells/animated在创建时设置，自动_draw调用map_runtime.draw_tile；cells的Vector3i分别为格x/y和tile_id。无自定义非下划线函数，生命周期由MapRuntime管理。不是Godot TileMap编辑器。

```gdscript
extends Node2D
# 本类未声明自定义公共方法。
```

### MapViewState.gd

公开字段：`options`、`display`、`scroll_target`、`scroll_remaining`、`initialized`、`revision`、`native_follow`、`native_velocity`。

常量（不含依赖脚本引用）：`DEFAULTS`。

源文件：templates/runtime/scripts/MapViewState.gd。地图区域/镜头純模型，options/display/scroll_target/scroll_remaining/initialized。valid_options完整校验，configure部分更新，view_rect/follow_center/bounded查询，advance推进跟随，scroll启动手动滚动，resume_follow取消并跟随。snapshot/decode详见第4.3节；extent/focus/window_size都是像素。

```gdscript
extends RefCounted
static func valid_options(value: Variant) -> bool
func configure(changes: Dictionary) -> Dictionary
func view_rect(window_size: Vector2) -> Rect2
func follow_center(window_size: Vector2) -> Vector2
func bounded(point: Vector2, extent: Vector2, window_size: Vector2) -> Vector2
func advance(delta: float, focus: Vector2, extent: Vector2, window_size: Vector2, snap: bool = false) -> void
func scroll(direction: int, tiles: Variant, seconds: Variant, extent: Vector2, window_size: Vector2) -> Dictionary
func scroll_native(direction: int, tiles: int, speed: int, extent: Vector2, window_size: Vector2) -> Dictionary
func resume_follow() -> void
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### MenuCoordinator.gd

公开字段：`game`、`menu`、`name_input`、`shop`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MenuCoordinator.gd。CanvasLayer50，game由Game绑定，menu/shop当前显示节点；can_open/open_menu/close_menu保持原地图，return_to_title停止playing并切Title，open_shop返回ok并暂停，close_shop续解释器。输入焦点与等待整格开菜单由该层统一负责。

```gdscript
extends CanvasLayer
func can_open() -> bool
func open_menu() -> bool
func open_flash_map() -> bool
func open_flash_history() -> bool
func open_flash_sight() -> bool
func open_event_menu(request_id: int) -> Dictionary
func open_event_save(request_id: int) -> Dictionary
func capture_flash_archive_snapshot() -> void
func begin_flash_backdrop() -> void
func load_flash_archive(slot: int) -> void
func open_flash_scene(source_name: String,args: Array=[],done: Callable=Callable()) -> Dictionary
func close_menu() -> void
func return_to_title() -> void
func open_name(actor_id: int, maximum: int, request_id: int) -> Dictionary
func close_name(request_id: int = -1, value: Variant = null) -> void
func open_shop(goods: Array, request_id: int = -1) -> Dictionary
func close_shop() -> void
```

### MenuScene.gd

公开字段：`save_callback`、`page`、`actor_index`、`command_index`、`scene_stack`、`content_rebuilds`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MenuScene.gd。Menu.tscn的Control脚本；page保存页名、save_callback来自Game.save_slot。navigate/activate/back/handle_back负责主菜单与子页；open_test_*及open_*_tools仅测试模式入口。状态页/结束页在本类实现；所有操作用统一RuntimeState，不重新初始化角色。

```gdscript
extends Control
signal close_requested
signal event_test_requested
signal title_requested
signal quit_requested
signal sound_requested(key: String)
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
func handle_back() -> void
func open_test_shop() -> void
func open_state_tools() -> void
func open_test_tools() -> void
func open_actor_tools() -> void
func open_screen_tools() -> void
func open_movement_tools() -> void
func show_currency_details() -> void
```

### MovementFixture.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MovementFixture.gd。纯测试夹具生成器：table生成x-fastest表，build生成原创地图/图块/检查点，event构造测试事件定义。只用独立验收区，不写源数据库、不把fixture触发当剧情执行。

```gdscript
extends RefCounted
static func table(values: Array, width: int, height: int = 1, depth: int = 1) -> Dictionary
static func build() -> Dictionary
static func event(x: int, y: int, name_value: String, trigger: int, text: String) -> Dictionary
```

### MovementTools.gd

公开字段：`map`、`avatar`、`selected`。

常量（不含依赖脚本引用）：`ACTIONS`。

源文件：templates/runtime/scripts/MovementTools.gd。F6独立移动UI；settings读取表单，apply_preview只改隔离人物，action按钮中显式“应用到玩家”才configure_player。update_labels显示结果；handle_key/navigate/activate/back/has_text_focus用于菜单路由，不替换真实地图或角色坐标。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func settings() -> Dictionary
func apply_preview() -> void
func has_text_focus() -> bool
func update_labels() -> void
func action(index: int) -> void
func handle_key(key: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### PictureSprite.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/PictureSprite.gd。Sprite2D显示PictureState快照，apply返回是否成功，按number设置z层、共享纹理、独立材料；shader_for按blend缓存Shader。该类不拥有/推进图片状态，不根据RM命令修改背包等数据。

```gdscript
extends Sprite2D
static func shader_for(blend: int) -> Shader
func apply(view: Dictionary) -> bool
```

### PictureState.gd

公开字段：无。

常量（不含依赖脚本引用）：`POSE`。

源文件：templates/runtime/scripts/PictureState.gd。一张图片的纯状态；create编号1..50失败null，decode失败字典/成功picture。pose_snapshot只当前姿态，snapshot加目标/剩余时长/旋转/色调进度；move/rotate/start_tone_change启动效果，advance每帧秒推进；numeric/vector_valid/valid_name/pose_valid/fail为校验工具。取值/单位见第4.3节。

```gdscript
extends RefCounted
static func numeric(value: Variant, minimum: float, maximum: float) -> bool
static func vector_valid(value: Variant, tone: bool = true) -> bool
static func valid_name(value: Variant) -> bool
static func pose_valid(value: Variant, partial: bool = false) -> bool
static func create(number: int, name_value: String, pose: Dictionary = {}) -> RefCounted
static func decode(value: Variant) -> Dictionary
func pose_snapshot() -> Dictionary
func snapshot() -> Dictionary
func move(pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
func rotate(degrees_per_second: Variant) -> Dictionary
func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary
func advance(delta: float) -> void
static func fail(message: String) -> Dictionary
```

### PlayerController.gd

公开字段：`input_enabled`、`stop_after_step`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/PlayerController.gd。继承MapCharacter，configure绑定RuntimeState.player_motion与地图，configure_motion转统一配置；input_enabled/stop_after_step供协调器门禁，resume_after_menu抑制残留按键。继承人物方法，成功普通行走才record_step；jump/撞墙/原地转向不计步。

```gdscript
extends "res://runtime/scripts/MapCharacter.gd"
class_name PlayerController
func configure(runtime: Node) -> void
func configure_motion(value: Dictionary) -> Dictionary
func move_straight(direction: int, turn_on_failure: bool = true) -> bool
func move_diagonal(offset: Vector2i) -> bool
func jump(x: int,y: int) -> bool
func move_to(x: int,y: int) -> bool
func reset_route_state() -> void
func resume_after_menu() -> void
```

### PresentationTools.gd

公开字段：`view`、`effects`、`screen`、`timer`、`map`、`avatar`、`camera`、`renderer`、`transition`、`audio`、`viewport`、`tabs`、`fields`、`choices`、`buttons`、`selected`、`status`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/PresentationTools.gd。F6独立48×36地图表现预览，持独立view/effects/screen/timer/transition/audio。navigate/activate/back/handle_key/has_text_focus仅UI入口；普通按钮不自动写回当前地图。只有显式真实地图应用/计时按钮连接RuntimeState；工具对照全景/雾禁止应用，当前会连天气一并拒绝。用户已接受保持此预览边界，事件后续走正式运行接口。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func has_text_focus() -> bool
func handle_key(key: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### RmxpAnimationData.gd

公开字段：无。

常量（不含依赖脚本引用）：`FRAME_SECONDS`。

源文件：templates/runtime/scripts/RmxpAnimationData.gd。静态原动画解码/校验服务；compile不加载纹理，resolve再查Animations和分类素材，返回数据契约见第6节；failure带动画ID定位。并非Godot Animation资源转换器。

```gdscript
extends RefCounted
static func prewarm() -> void
static func resolve(animation_id: int) -> Dictionary
static func compile(definition: Dictionary) -> Dictionary
static func failure(id: int, message: String) -> Dictionary
```

### RmxpAnimationPlayer.gd

公开字段：`frame_index`、`elapsed`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/RmxpAnimationPlayer.gd。每次play生成独立Node2D，parent控制生命周期，target_provider每次返回有效CanvasItem目标；0无动画无player，失败不创建实例。finished/timing_reached信号，advance由_process调用，stop释放并完成；同目标/不同位置皆可并发，不共享animation_id状态。

```gdscript
extends Node2D
signal finished
signal timing_reached(frame: int, timing: Dictionary)
static func play(parent: Node, animation_id: int, target_provider: Callable, hit: bool = true) -> Dictionary
func advance(delta: float) -> void
func stop() -> void
```

### RmxpCache.gd

公开字段：无。

常量（不含依赖脚本引用）：`CATEGORIES`、`IMAGE_EXTENSIONS`。

源文件：templates/runtime/scripts/RmxpCache.gd。静态分类素材Facade，所有方法和13分类见第7节；asset_key是合法Graphics分类键，resolve是索引资源路径，texture/region共享缓存，list_assets/list_names仅枚举。各shortcut接受原分类内文件名（可含子目录/扩展名），不接受任意外部路径。

```gdscript
extends RefCounted
static func categories() -> Array[String]
static func skills(name: String) -> Texture2D
static func face(name: String) -> Texture2D
static func asset_key(category: String, name: String) -> String
static func resolve(category: String, name: String) -> String
static func exists(category: String, name: String) -> bool
static func texture(category: String, name: String) -> Texture2D
static func region(category: String, name: String, rectangle: Rect2) -> Texture2D
static func list_assets(category: String) -> Array[Dictionary]
static func list_names(category: String) -> Array[String]
static func picture(name: String) -> Texture2D
static func icon(name: String) -> Texture2D
static func title(name: String) -> Texture2D
static func windowskin(name: String) -> Texture2D
static func character(name: String) -> Texture2D
static func animation(name: String) -> Texture2D
static func tileset(name: String) -> Texture2D
static func autotile(name: String) -> Texture2D
static func panorama(name: String) -> Texture2D
static func fog(name: String) -> Texture2D
static func battler(name: String) -> Texture2D
static func gameover(name: String) -> Texture2D
static func transition(name: String) -> Texture2D
static func clear() -> void
```

### RuntimeData.gd

公开字段：`testing_enabled`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/RuntimeData.gd。静态JSON缓存/数据库入口；返回定义引用必须只读，record含测试覆盖而source_record不含。manifest/system/map/database/read_json、测试覆盖操作、asset_index/asset_path、field安全取值契约见第5节。没有全局Actor实例或State效果逻辑。

```gdscript
extends RefCounted
class_name RuntimeData
static func bind_custom_data(value: RefCounted) -> void
static func read_json(path: String, fallback: Variant = {}) -> Variant
static func manifest() -> Dictionary
static func system() -> Dictionary
static func map(map_id: int) -> Dictionary
static func database(name: String) -> Variant
static func record(name: String, id: int) -> Dictionary
static func source_record(name: String, id: int) -> Dictionary
static func test_config() -> Dictionary
static func configure_testing(override: Dictionary = {}) -> Dictionary
static func is_test_record(database: String, id: int) -> bool
static func testing_snapshot() -> Dictionary
static func install_testing(enabled: bool, records: Dictionary) -> void
static func asset_index() -> Dictionary
static func asset_path(rmxp_path: String) -> String
static func field(value: Variant, key: String, fallback: Variant = null) -> Variant
```

### RuntimeState.gd

公开字段：`switches`、`variables`、`self_switches`、`inventory`、`gold`、`custom_data`、`save_count`、`message_position`、`message_frame`、`party`、`map_id`、`player_motion`、`player_x`、`player_y`、`player_direction`、`resume_from_save`、`pending_event_state`、`common_event_reservation`、`flash_temp_fields`、`save_disabled`、`menu_disabled`、`actors`、`diagnostics`、`script_session`、`steps`、`play_seconds`、`playing`、`testing_enabled`、`system_settings`、`screen`、`map_view`、`map_effects`、`timer`、`audio`、`flash_preferences`、`flash_messages`、`flash_followers`、`flash_effects`、`flash_keyboard`、`flash_archive_snapshot`、`pending_flash_presentation`、`flash_history`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/RuntimeState.gd。生成工程唯一Autoload，字段/方法的调用、空引用、诊断、事务、初始化和生命周期见第4节；restore_prepared仅接受SaveCodec.prepare已验证结果。register_*不拥有场景生命周期，request_quit先停止/释放音频后延迟退出。不能在解释器/UI重新建同一份游戏状态。

```gdscript
extends Node
signal system_settings_changed
signal state_changed
signal event_state_changed(kind: String, key: String)
signal execution_reset
signal diagnostic_added(message: String)
func event_frame_deadline(budget_usec: int) -> int
func request_quit() -> void
func set_event_switch(id: int, value: bool) -> bool
func set_event_variable(id: int, value: Variant) -> bool
func set_event_self_switch(map: int, event: int, letter: String, value: bool) -> bool
func begin_new_game(system: Dictionary, testing_override: Dictionary = {}) -> void
func inventory_entries() -> Array[Dictionary]
func common_event_reason(id: int) -> String
func reserve_common_event(id: int, source: String = "", actor_id: int = 0, target_id: int = 0) -> Dictionary
func use_skill(actor_id: int, skill_id: int, target_id: int = 0) -> Dictionary
func change_skill(actor_id: int, skill_id: int, learning: bool) -> Dictionary
func has_skill(actor_id: int, skill_id: int) -> bool
func skill_ids(actor_id: int) -> Array[int]
func use_item(item_id: int, target_id: int) -> Dictionary
func change_state(actor_id: int, state_id: int, adding: bool) -> Dictionary
func has_state(actor_id: int, state_id: int) -> bool
func state_ids_for(actor_id: int, include_equipment: bool = true) -> Array[int]
func clear_states(actor_id: int) -> Dictionary
func shop_buy(goods: Array, kind: String, id: int, quantity: int) -> Dictionary
func shop_sell(kind: String, id: int, quantity: int) -> Dictionary
func inventory_count(kind: String, id: int) -> int
func equip_preview(actor_id: int, slot: int, equipment_id: int) -> Dictionary
func equip(actor_id: int, slot: int, equipment_id: int) -> Dictionary
func actor_parameter_sources(actor_id: int, key: String) -> Dictionary
func apply_actor_event(code: int, parameters: Array) -> Dictionary
func change_actor_parameter(actor_id: int, key: String, amount: Variant) -> Dictionary
func set_actor_parameter(actor_id: int, key: String, value: Variant) -> Dictionary
func set_actor_parameter_plus(actor_id: int, key: String, value: Variant) -> Dictionary
func set_actor_experience(actor_id: int, value: Variant) -> Dictionary
func change_actor_experience(actor_id: int, amount: Variant) -> Dictionary
func set_actor_level(actor_id: int, value: Variant) -> Dictionary
func change_actor_level(actor_id: int, amount: Variant) -> Dictionary
func set_actor_vital(actor_id: int, key: String, value: Variant) -> Dictionary
func change_actor_vital(actor_id: int, key: String, amount: Variant) -> Dictionary
func recover_actor_vitals(actor_id: int) -> Dictionary
func rename_actor(actor_id: int, value: Variant) -> Dictionary
func set_actor_graphic(actor_id: int, value: Variant, hue: Variant = 0) -> Dictionary
func change_actor_class(actor_id: int, value: Variant) -> Dictionary
func create_actor(actor_id: int, definition: Dictionary, lookup: Callable) -> RefCounted
func actor(actor_id: int, reset: bool = false) -> RefCounted
func party_snapshots() -> Array[Dictionary]
func change_party(actor_id: int, adding: bool, initialize: bool = false) -> void
func record_step() -> void
func configure_player(value: Dictionary) -> Dictionary
func register_player(controller: Node) -> void
func player() -> Node
func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary
func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
func rotate_picture(number: int, degrees_per_second: Variant) -> Dictionary
func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary
func erase_picture(number: int) -> Dictionary
func report_diagnostic(message: String) -> void
func fatal_script_error(message: String) -> void
func register_game(instance: Node) -> void
func game() -> Node
func map_time_paused() -> bool
func windowskin_name() -> String
func set_windowskin(name_value: String) -> Dictionary
func configure_map_view(changes: Dictionary) -> Dictionary
func configure_map_effects(changes: Dictionary) -> Dictionary
func scroll_map(direction: int, tiles: Variant, seconds: Variant = 0.0) -> Dictionary
func scroll_map_native(direction: int, tiles: int, speed: int) -> Dictionary
func resume_map_follow() -> void
func fade_screen(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
func freeze_screen() -> Dictionary
func transition_screen(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary
func cancel_screen_transition() -> void
func self_switch_key(map_value: int, event_id: int, letter: String) -> String
func restore_prepared(prepared: Dictionary, preserve_audio: bool = false) -> void
func gain_currency(key: String,amount: Variant) -> Dictionary
func commit_script_data(writes: Dictionary,draft: RefCounted) -> void
func custom_record(database: String,id: int) -> Dictionary
func custom_actor_attributes(id: int) -> Dictionary
func evaluate_custom_expression(id: String) -> Dictionary
```

### RuntimeVersion.gd

公开字段：无。

常量（不含依赖脚本引用）：`VERSION`。

源文件：templates/runtime/scripts/RuntimeVersion.gd。运行时版本常量VERSION=ver0.27；无业务方法。ProjectGenerator由迁移器Version同步生成，不与存档SCHEMA混用。

```gdscript
extends RefCounted
# 本类未声明自定义公共方法。
```

### SaveCodec.gd

公开字段：无。

常量（不含依赖脚本引用）：`MAX_INTEGER`。

源文件：templates/runtime/scripts/SaveCodec.gd。静态快照校验器，capture/prepare/返回结构见第7节。integer/positive_key/id_list校验JSON整数和数据库ID，testing_records校验存档测试定义且不安装，fail包装错误。只构造脱离现场的角色、状态和预加载音频候选，不提交现场或恢复场景节点/事件。

```gdscript
extends RefCounted
static func integer(value: Variant, minimum: int = 0, maximum: int = MAX_INTEGER) -> bool
static func capture(state: Node) -> Dictionary
static func prepare(value: Variant,definitions: RefCounted=null,owned_snapshot: bool=false) -> Dictionary
static func testing_records(value: Variant) -> Dictionary
static func id_list(value: Variant, database: String, lookup: Callable) -> String
static func positive_key(key: String) -> bool
static func fail(message: String) -> Dictionary
```

### SaveService.gd

公开字段：`directory_override`。

常量（不含依赖脚本引用）：`SLOT_COUNT`、`FORMAT`、`SCHEMA`、`MAX_BYTES`、`INFO_CACHE_LIMIT`。

源文件：templates/runtime/scripts/SaveService.gd。静态四槽磁盘服务；project_id/directory/slot_path/fingerprint查询，save_slot提交磁盘，read_slot/read_path不恢复，load_slot会restore_prepared，slot_info/has_valid_save供标题/槽列表。write_text是内部文件辅助非事件API，fail包装错误；权限/备份确认/格式见第7节。

```gdscript
extends RefCounted
static func project_id() -> String
static func directory() -> String
static func slot_path(slot: int) -> String
static func maximum_slots() -> int
static func existing_slots() -> Array
static func fingerprint() -> String
static func save_slot(slot: int, state: Node) -> Dictionary
static func read_slot(slot: int) -> Dictionary
static func read_path(path: String) -> Dictionary
static func load_slot(slot: int, state: Node) -> Dictionary
static func slot_info(slot: int) -> Dictionary
static func has_valid_save() -> bool
static func write_text(path: String, content: String) -> Error
static func fail(message: String) -> Dictionary
```

### SaveSlots.gd

公开字段：`mode`、`save_callback`、`selected`、`message`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/SaveSlots.gd。Control，mode=save/load、save_callback是保存Callable；load_requested由标题处理实际读档，back_requested/sound_requested交父页面。refresh/window构建显示，navigate/activate/execute/back包含备份或覆盖确认流程，不能绕过确认直接调用load_slot。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
signal load_requested(slot: int)
func window(script: Script, rect: Rect2) -> Control
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func execute() -> void
func back() -> void
```

### ScreenRenderer.gd

公开字段：`camera`、`sprites`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/ScreenRenderer.gd。Node组装地图色调、图片与闪光显示，读取RuntimeState.screen，camera用于震动偏移。sync同步显示，full_rect创建ColorRect辅助；正常_process推进screen一次，普通菜单暂停，ScreenTools特例见第7节。它不是Game_Screen状态对象。

```gdscript
extends Node
func full_rect(parent: Node) -> ColorRect
func sync() -> void
```

### ScreenState.gd

公开字段：`weather_state`、`revision`。

常量（不含依赖脚本引用）：`DEFAULTS`。

源文件：templates/runtime/scripts/ScreenState.gd。当前Game_Screen对应的纯状态，拥有1..50图片和tone/flash/shake及weather_state。show/move/rotate/tint/erase操作图片，picture可null、picture_ids升序，effects_snapshot不含图片，snapshot含pictures和weather，decode返回screen并兼容旧缺weather字段；advance唯一推进正式屏幕/天气时长。正式显示图片优先RuntimeState校验素材。

```gdscript
extends RefCounted
func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary
func picture(number: int) -> RefCounted
func picture_ids() -> Array
func erase_picture(number: int) -> Dictionary
func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
func rotate_picture(number: int, speed: Variant) -> Dictionary
func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary
func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary
func start_flash(color: Array, seconds: Variant) -> Dictionary
func start_shake(power: Variant, speed: Variant, seconds: Variant) -> Dictionary
func advance(delta: float) -> void
func effects_snapshot() -> Dictionary
func snapshot() -> Dictionary
func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary
func weather_snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### ScreenTools.gd

公开字段：`selected`、`number`、`asset_name`、`assets`、`message`。

常量（不含依赖脚本引用）：`ACTIONS`。

源文件：templates/runtime/scripts/ScreenTools.gd。F6图片测试Control；number/asset_name/selected按钮状态，select_asset选原Pictures，display_at调用真实RuntimeState.show_picture，action测试变换/屏幕效果，neutral_tone作比较；refresh/update_labels/navigate/activate/back供UI。与PresentationTools不同，该页效果修改当前screen，工具图只在测试模式有效。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func select_asset(name_value: String) -> void
func update_labels() -> void
func display_at(id: int, x: float) -> Dictionary
func action(index: int) -> void
func navigate(direction: int) -> void
func neutral_tone(tone: Array) -> bool
func activate() -> void
func back() -> void
```

### ShopScene.gd

公开字段：`goods`、`mode`、`command_index`、`selected`、`actor_index`、`quantity`、`message`、`content_rebuilds`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/ShopScene.gd。Control，goods由MenuCoordinator设置，mode/command_index/selected/quantity/actor_index驱动列表/数量窗与装备比较。refresh/build_list/build_number/window辅助显示，number_action与navigate/activate/back/handle_key处理数量、确认和返回，change_actor切装备比较角色。业务通过ShopService，返回发back_requested而非直接恢复地图。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func window(script: Script, rect: Rect2) -> Control
func refresh() -> void
func build_list() -> void
func build_number() -> void
func number_action(value: int) -> void
func change_actor(direction: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
func handle_key(key: int) -> void
```

### ShopService.gd

公开字段：无。

常量（不含依赖脚本引用）：`KINDS`、`MAX_GOLD`。

源文件：templates/runtime/scripts/ShopService.gd。静态交易服务；catalog把RM goods解析为entries并去重，失败可含goods_index；item返回entry，counters返回owned或失败；quote_buy/sell返回maximum/unit_price/owned/message而不提交；buy/sell/transact原子提交，integer/fail辅助。金币库存/种类/价格见第4.2节。

```gdscript
extends RefCounted
static func integer(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool
static func catalog(goods: Array) -> Dictionary
static func item(kind: String, id: int) -> Dictionary
static func counters(state: Node, kind: String, id: int) -> Dictionary
static func quote_buy(state: Node, goods: Array, kind: String, id: int) -> Dictionary
static func quote_sell(state: Node, kind: String, id: int) -> Dictionary
static func buy(state: Node, goods: Array, kind: String, id: int, quantity: int) -> Dictionary
static func sell(state: Node, kind: String, id: int, quantity: int) -> Dictionary
static func transact(state: Node, goods: Array, kind: String, id: int, quantity: int, buying: bool) -> Dictionary
static func fail(message: String, goods_index: int = -1) -> Dictionary
```

### SkillScene.gd

公开字段：`actor_id`、`selected`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/SkillScene.gd。Control，actor_id对应列表；refresh/navigate/activate/back及信号交父菜单。普通列表接通原生公共事件入口及SP消耗，单体目标选择独立于动画预览；未支持的结算效果原子拒绝。测试模式可学习/遗忘/预览/进入原动画并发实验；不执行回合制战斗。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
signal common_event_requested
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### StateTools.gd

公开字段：`actor_id`、`selected_state`、`message`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/StateTools.gd。F6状态登记测试Control；refresh/selector显示角色与状态选择，action增删/查询/清空，navigate/activate/back路由。selector的actors布尔区分角色列表和状态列表；改变普通状态不清装备来源，不增加剧情事件指令。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func selector(position_value: Vector2, ids: Array[int], actors: bool) -> OptionButton
func action(value: int) -> void
func navigate(_direction: int) -> void
func activate() -> void
func back() -> void
```

### TestTools.gd

公开字段：`selected`。

常量（不含依赖脚本引用）：`PAGES`。

源文件：templates/runtime/scripts/TestTools.gd。F6工具目录Control；refresh刷新选择，navigate/activate/back通过tool_requested(page)让MenuScene开对应页。当前角色/商店/状态/图片/移动/表现/原动画入口只在测试模式可见，不是完整编辑器。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
signal tool_requested(page: String)
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### Title.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/Title.gd。Title.tscn脚本，仅Godot生命周期与内部回调，无自定义公共方法。使用System标题素材/音乐，提供新游戏、继续游戏、退出；新游戏begin_new_game后切Game，继续先SaveService验证/确认备份/restore_prepared，不读取Ruby Scene_Title。

```gdscript
extends Control
# 本类未声明自定义公共方法。
```

### TransitionRenderer.gd

公开字段：`preview`、`rect`、`remaining`、`duration`、`frozen`、`busy`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/TransitionRenderer.gd。CanvasLayer15瞬时画面服务，fade/freeze_screen/transition/cancel契约见第4.3节；必须add_child后使用，freeze需await真实post_draw。状态remaining/busy/frozen目前内部接入用，未来事件应建立正式等待协议；取消/退出释放截图，不序列化。

```gdscript
extends CanvasLayer
func fade(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
func freeze_screen() -> Dictionary
func transition(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary
func cancel() -> void
```

### UIResources.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/UIResources.gd。静态内部纹理/区域/字体共享缓存；texture接收Graphics全路径，业务首选RmxpCache分类接口。region创建AtlasTexture，font系统中文回退，word读取System并固定标准标签，play_sound播放System指定UI SE，clear释放缓存引用；不热导入文件。

```gdscript
extends RefCounted
static func texture(name: String) -> Texture2D
static func region(name: String, rectangle: Rect2) -> Texture2D
static func font() -> SystemFont
static func word(key: String, fallback: String) -> String
static func play_sound(parent: Node, key: String) -> void
static func clear() -> void
```

### UISpriteset.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/UISpriteset.gd。Control菜单成组生命周期；add_character(view,rectangle)用快照character_name/hue创建CharacterSprite并返回TextureRect，父节点释放时整组释放。不是地图Spriteset或角色状态拥有者。

```gdscript
extends Control
func add_character(view: Dictionary, rectangle: Rect2) -> TextureRect
```

### WeatherRenderer.gd

公开字段：`area`、`type`、`power`、`density`、`display`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WeatherRenderer.gd。Node2D批量显示，area逻辑像素、type/power/density/display由MapEffectsRenderer赋值。advance只移动/裁切粒子并queue_redraw，particle_count查询；至多256，不提供天气命令或保存，不能把粒子反向作为Game_Screen真值。

```gdscript
extends Node2D
func advance(delta: float) -> void
func particle_count() -> int
```

### WindowBase.gd

公开字段：`content`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WindowBase.gd。Control皮肤窗口；label创建Label返回实例，clear_content清掉内容，select_rect更新选择光标。192×128窗口皮肤背景/边框/光标，缺皮肤替代并诊断，content是窗口内容容器；无RGSS同名Ruby API运行能力。

```gdscript
extends Control
func label(text: String, rectangle: Rect2, color: Color = Color.WHITE, font_size: int = 20) -> Label
func clear_content() -> void
func select_rect(rectangle: Rect2, active: bool = true) -> void
```

### WindowCommand.gd

公开字段：`commands`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WindowCommand.gd。继承WindowSelectable，commands数组，configure(entries,selected) entries需text/enabled，current_enabled查当前项是否启用。父类select/move_selection负责滚动索引；disabled不表示业务已实现。

```gdscript
extends "res://runtime/scripts/WindowSelectable.gd"
func configure(entries: Array, selected: int = 0) -> void
func current_enabled() -> bool
```

### WindowSelectable.gd

公开字段：`index`、`item_count`、`row_height`、`active`、`scroll_row`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WindowSelectable.gd。继承WindowBase，index/item_count/row_height/active/scroll_row，select夹取索引并保持最小滚动，move_selection用方向增量并环绕，selection_changed发索引。父页面按选择/数据变化刷新，不逐帧重绘全部文字。

```gdscript
extends "res://runtime/scripts/WindowBase.gd"
signal selection_changed(index: int)
func select(value: int) -> void
func move_selection(direction: int) -> void
```

### AudioProbe.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/AudioProbe.gd。独立Godot SceneTree子进程入口，接收AssetCopier传入的命令行音频路径并隔离解码，成功标记/退出码由AssetCopier检查；没有可实例化的公共业务方法。不要在游戏事件中运行探针。

```gdscript
extends SceneTree
# 本类未声明自定义公共方法。
```

### MigrationPipeline.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/MigrationPipeline.gd。迁移流程run(preflight,progress)；preflight.ok且输出目录空才写，progress回调字符串。协调素材/脚本镜像/数据/模板/测试物资/报告，返回{ok,messages,output_path,report}；保留Ruby源码，不自动转GDScript。

```gdscript
extends RefCounted
class_name MigrationPipeline
func run(preflight: Dictionary, progress: Callable = Callable()) -> Dictionary
```

### MigrationReportWriter.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/MigrationReportWriter.gd。write(output_root,details)写JSON/中文Markdown报告，返回写入warnings数组；版本由Version引用，details来自Pipeline含统计/不支持命令/测试配置。调整事件支持后同步报告，不能只改文档宣称支持。

```gdscript
extends RefCounted
class_name MigrationReportWriter
func write(output_root: String, details: Dictionary) -> Array[String]
```

### ProjectGenerator.gd

公开字段：`warnings`。

常量（不含依赖脚本引用）：`EXTRA_README`。

源文件：scripts/importer/ProjectGenerator.gd。generate复制runtime/scripts/scenes/MAP_PRESENTATION文档并写project.godot、RuntimeVersion、输出README，返回warnings/width/height。窗口从INI取合法值，否则640×480；Compatibility/安全串行导入，RuntimeState Autoload，空地图区域/中心默认。生成器本身不保证外部调用的覆盖门禁，由Validator/Pipeline先检查。

```gdscript
extends RefCounted
class_name ProjectGenerator
func generate(output_root: String, project_title: String, ini: Dictionary, progress: Callable = Callable(), source_id: String = "") -> Dictionary
func write_flash_source_guide(output_root: String) -> void
```

### RmxpAssetCopier.gd

公开字段：`warnings`、`errors`、`copied_assets`、`copied_legacy_files`。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/RmxpAssetCopier.gd。copy将非RTP Graphics/Audio写到assets/rmxp并建立asset_index，错误扩展名修正副本，音频隔离probe失败保留legacy/unsupported_assets；其他文件保留legacy。copy_scripts_mirror优先保留源Scripts，返回copied/count；warnings/errors/counter为本次结果。绝不修改源素材。

```gdscript
extends RefCounted
class_name RmxpAssetCopier
func copy(source_root: String, output_root: String, progress: Callable = Callable()) -> Dictionary
func copy_scripts_mirror(source_root: String, output_root: String) -> Dictionary
```

### RmxpDataConverter.gd

公开字段：`warnings`、`errors`、`unsupported_commands`、`converted_files`、`converted_maps`、`exported_scripts`、`script_sources`、`script_inventory`。

常量（不含依赖脚本引用）：`RAW_STRING_KEY`。

源文件：scripts/importer/RmxpDataConverter.gd。new(codec)，set_asset_index映射素材，convert解析.rxdata/地图/系统/数据库/脚本并写JSON/legacy，export_scripts_from_data控制是否从Scripts.rxdata解压；返回统计/errors/warnings/unsupported_commands。原ID保留，未知Ruby类数据保留而非执行；新增事件支持同时修改这里的命令判定。

```gdscript
extends RefCounted
class_name RmxpDataConverter
func _init(text_codec: RmxpTextCodec) -> void
func set_asset_index(asset_index: Dictionary) -> void
func convert(source_root: String, output_root: String, progress: Callable = Callable(), export_scripts_from_data: bool = true) -> Dictionary
```

### RmxpIniReader.gd

公开字段：`codec`。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/RmxpIniReader.gd。new(codec)，read(path)按编码解析INI并返回章节Dictionary，供标题/分辨率/游戏设置读取；不执行INI指向的Ruby库。

```gdscript
extends RefCounted
class_name RmxpIniReader
func _init(text_codec: RmxpTextCodec) -> void
func read(path: String) -> Dictionary
```

### RmxpMarshalReader.gd

公开字段：`failed`、`error_message`。

常量（不含依赖脚本引用）：`RAW_STRING_KEY`。

源文件：scripts/importer/RmxpMarshalReader.gd。new(codec)，read_file/read_bytes返回Variant数据，failed/error_message标记解析失败，Ruby对象/用户自定义负载保留中间标识以供Converter处理。支持Marshal引用表，但不实例化执行Ruby。

```gdscript
extends RefCounted
class_name RmxpMarshalReader
func _init(text_codec: RmxpTextCodec) -> void
func read_file(path: String) -> Variant
func read_bytes(bytes: PackedByteArray) -> Variant
```

### RmxpTableDecoder.gd

公开字段：无。

常量（不含依赖脚本引用）：`RAW_STRING_KEY`。

源文件：scripts/importer/RmxpTableDecoder.gd。decode对用户自定义Table负载解析为dimensions/x_size/y_size/z_size/values（有符号16位）；非Table原样返回，坏Table返回_rmxp_table_error。下标规范见第5节，不把Ruby二进制留给地图渲染器。

```gdscript
extends RefCounted
class_name RmxpTableDecoder
static func decode(value: Variant) -> Variant
```

### RmxpTextCodec.gd

公开字段：`codepage`、`error_message`。

常量（不含依赖脚本引用）：`AUTO_CODEPAGE`、`GBK_CODEPAGE`、`SHIFT_JIS_CODEPAGE`。

源文件：scripts/importer/RmxpTextCodec.gd。new(requested_codepage=0)，0自动Windows ANSI、936GBK、932Shift-JIS；UTF-8有效输入优先。resolve_codepage取实际代码页，label给显示名，decode返回String并通过error_message报告失败，ensure_ready检查/生成解码表。Windows PowerShell仅用于编码表，不执行源工程脚本。

```gdscript
extends RefCounted
class_name RmxpTextCodec
func _init(requested_codepage: int = AUTO_CODEPAGE) -> void
static func resolve_codepage(requested_codepage: int) -> int
func label() -> String
func decode(bytes: PackedByteArray) -> String
func ensure_ready() -> bool
```

### RmxpValidator.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/RmxpValidator.gd。preflight(source_path,export_root,requested_encoding)返回ok/messages/errors及source_path/output_path/project_title/encoding/ini/map_files/database_files/graphics_count/audio_count；源含Game.rxproj/Game.ini/Data/System.rxdata，禁止导出到源内部或非空目标。调用方可加test_mode，传给Pipeline，预检不写源。

```gdscript
extends RefCounted
class_name RmxpValidator
func preflight(source_path: String, export_root: String, requested_encoding: int) -> Dictionary
```

### TestSetupGenerator.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/TestSetupGenerator.gd。generate(output_root,enabled)生成独立data/test_setup.json，避源ID冲突，包含测试物品装备/特技动画/状态/金币商品及初始比例；返回ok与配置摘要或message。默认准备不表示恢复样板Ruby自定义系统，不改原数据库。

```gdscript
extends RefCounted
func generate(output_root: String, enabled: bool) -> Dictionary
```

### Main.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/Main.gd。迁移器Control UI，用户选择源/导出/编码/测试准备、预检、迁移与报告；只有Godot生命周期/内部回调，无自定义公共方法。不可把它当生成游戏的运行状态入口。

```gdscript
extends Control
# 本类未声明自定义公共方法。
```

### Version.gd

公开字段：无。

常量（不含依赖脚本引用）：`NAME`、`VERSION`、`DISPLAY_NAME`。

源文件：scripts/Version.gd。class_name RGMigratorVersion，NAME、VERSION、DISPLAY_NAME是迁移器唯一版本常量；无自定义函数。当前VERSION=ver0.29，生成器和报告引用此处。

```gdscript
extends RefCounted
class_name RGMigratorVersion
# 本类未声明自定义公共方法。
```

### EventCommandCatalog.gd

公开字段：无。

常量（不含依赖脚本引用）：`SUPPORTED`、`BATTLE`。

源文件：templates/runtime/scripts/EventCommandCatalog.gd。导入器与生成运行时共享能力清单，reason返回空为支持，BATTLE回合制排除；部分111/122、106参数和路线45脚本有独立诊断。

```gdscript
extends RefCounted
static func reason(code: int, parameters: Array = []) -> String
static func supported(code: int, parameters: Array = []) -> bool
static func color_values(value: Variant, tone: bool = true) -> Array
static func route_reason(code: int, parameters: Array = []) -> String
static func route_validation(route: Variant) -> Dictionary
```

### EventExecutionContext.gd

公开字段：`commands`、`index`、`event_id`、`source_event_id`、`source_map_id`、`page`、`common_id`、`stack`、`branches`、`loops`、`waiting_indent`、`shop_command_index`、`script_fields`、`script_map_id`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventExecutionContext.gd。每个解释器独立拥有命令、指针、来源位置及公共栈/分支/循环；setup初始化，location提供原地图/事件/页与调用链，换图不改来源。

```gdscript
extends RefCounted
func setup(list: Array, id: int, map_id: int, page_number: int) -> void
func location() -> String
```

### EventFixture.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventFixture.gd。程序绘制素材的真实事件验收地图；build返回map/tileset/common_events；command/event构造独立夹具，原数据库只读。

```gdscript
extends RefCounted
static func command(code: int, parameters: Array = [], indent: int = 0) -> Dictionary
static func event(x: int, y: int, trigger: int, commands: Array, condition: Dictionary = {}, graphic: String = "@movement_character") -> Dictionary
static func build() -> Dictionary
static func scenario(name: String) -> Array
```

### EventScheduler.gd

公开字段：`map_runtime`、`main`、`parallels`、`common_events`、`frame_budget`、`frame_time_budget_usec`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventScheduler.gd。main串行前台与parallels独立并行；configure绑定地图，advance公平预算，start_main锁交互人物；cancel_all取消、dispose断开地图与主解释器信号。suppress_loaded_autoruns保留旧存档不重跑开局的兼容边界。

```gdscript
extends RefCounted
signal interpreter_created(interpreter: RefCounted)
signal main_completed
signal main_aborted
func configure(map: Node, common_override: Variant = null) -> void
func start_main(commands: Array, event_id: int, page: int = 1, key: String = "", defer_run: bool = false) -> bool
func advance(delta: float, allow_autorun: bool = true) -> void
func has_running_events() -> bool
func suppress_loaded_autoruns() -> void
func cancel_all() -> void
func dispose() -> void
```

### EventTestHUD.gd

公开字段：`game`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventTestHUD.gd。验收地图CanvasLayer10，仅观察实际变量并控制公共并行开关；F7或退出按钮发back_requested，由Game恢复原地图。

```gdscript
extends CanvasLayer
signal back_requested
# 本类未声明自定义公共方法。
```

### EventUIBroker.gd

公开字段：`active`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventUIBroker.gd。多解释器共用UI队列，弱引用及wait token识别所属执行，request_id区分显示请求。pump只展示有效等待，resolve正确恢复，cancel_all释放界面。

```gdscript
extends RefCounted
signal requested(kind: String, payload: Array, request_id: int)
signal dismissed(kind: String)
signal terminal_requested(kind: String)
func bind_interpreter(owner: RefCounted) -> void
func report(message: String) -> void
func busy() -> bool
func next_kind() -> String
func pump(available: bool = true) -> void
func resolve(request_id: int, value: Variant = null) -> void
func reject(request_id: int, message: String) -> void
func cancel_all() -> void
```

### EventWait.gd

公开字段：`kind`、`remaining`、`token`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventWait.gd。秒等待及界面等待协议；begin/clear提升token，advance只推进time；accepts校验类型与可选token，取消后旧回调失效。

```gdscript
extends RefCounted
func begin(value: String, seconds: float = 0.0) -> void
func clear() -> void
func advance(delta: float) -> void
func accepts(value: String, expected_token: int) -> bool
```

### EventInput.gd

源文件：templates/runtime/scripts/EventInput.gd。原生按键映射与trigger/pressed查询。

公开字段：无。
常量（不含依赖脚本引用）：`ACTIONS`、`KEYS`。

```gdscript
extends RefCounted
static func configure() -> void
static func pressed(code: int) -> bool
static func triggered() -> int
```

### EventMessage.gd

源文件：templates/runtime/scripts/EventMessage.gd。RM文本控制字符解析，返回颜色片段与金币窗口标志。

公开字段：无。
常量（不含依赖脚本引用）：`COLORS`。

```gdscript
extends RefCounted
static func format(text: String) -> Dictionary
```

### EventValueResolver.gd

源文件：templates/runtime/scripts/EventValueResolver.gd。非战斗条件和变量查询/算术，依赖正式状态，不复制状态。

公开字段：无。
常量（不含依赖脚本引用）：`PARAMETER_KEYS`。

```gdscript
extends RefCounted
static func character(map: Node, event_id: int, id: int) -> Node
static func condition(p: Array, map: Node, event_id: int) -> Dictionary
static func operand(p: Array, map: Node, event_id: int) -> Dictionary
static func numeric_variable(value: Variant) -> bool
static func calculate(current: int, operation: int, operand_value: int) -> int
```

### CharacterRoute.gd

源文件：templates/runtime/scripts/CharacterRoute.gd。每个人物的原生自主/强制路线执行器，参数与生命周期见6.1。

公开字段：`move_type`、`move_frequency`、`forcing`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(character: Node) -> void
static func preflight(route: Variant) -> Dictionary
func configure(type: Variant, frequency: Variant, route: Variant, source: String = "") -> Dictionary
func force(route: Dictionary, source: String = "", on_error: Callable = Callable()) -> Dictionary
func cancel() -> void
func repeat_forced() -> bool
func has_runtime_state() -> bool
func snapshot() -> Dictionary
func persistent_data() -> Dictionary
static func validate_persistent(value: Variant) -> bool
func restore_persistent(value: Dictionary) -> void
func advance(delta: float) -> void
```

### WeatherState.gd

源文件：templates/runtime/scripts/WeatherState.gd。由ScreenState持有的唯一天气模型，六字段及迁移/时钟契约见6.2。

公开字段：`data`。

常量（不含依赖脚本引用）：`DEFAULTS`。

```gdscript
extends RefCounted
static func validate(value: Variant) -> bool
func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary
func advance(delta: float) -> void
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### SystemSettings.gd

源文件：templates/runtime/scripts/SystemSettings.gd。运行时系统设置，窗口皮肤覆盖与兼容存档见6.3。

公开字段：`windowskin_override`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func windowskin_name() -> String
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### ActorEventService.gd

源文件：templates/runtime/scripts/ActorEventService.gd。原生角色事件事务：execute统一参数/目标，脱离现场复制与提交，fail返回错误；详见6.4。

公开字段：无。

常量（不含依赖脚本引用）：`PARAMETER_KEYS`。

```gdscript
extends RefCounted
static func execute(state: Node, code: int, p: Array) -> Dictionary
static func fail(message: String) -> Dictionary
```

### Gameover.gd

源文件：templates/runtime/scripts/Gameover.gd。实际游戏结束页面：源Gameovers背景和gameover_me，返回标题；清理执行由Game完成，详见6.4。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
func return_to_title() -> void
```

### NameInput.gd

源文件：templates/runtime/scripts/NameInput.gd。303专用姓名页面，actor_id/maximum/initial_name由协调器配置，confirmed仅返回文本，不直接改角色；submit/restore_name/back语义见6.4。

公开字段：`actor_id`、`maximum`、`initial_name`、`edit`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal confirmed(value: String)
func submit() -> void
func restore_name() -> void
func back() -> void
```

### CommonEventUse.gd

源文件：templates/runtime/scripts/CommonEventUse.gd。菜单特技的公共事件入口和SP原子消耗；契约见6.5。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func skill_reason(state: Node, actor_id: int, skill_id: int) -> String
static func use_skill(state: Node, actor_id: int, skill_id: int, target_id: int) -> Dictionary
```

### EventPersistence.gd

源文件：templates/runtime/scripts/EventPersistence.gd。脱离现场的事件/人物/路线/队列快照、完整校验与恢复；契约见6.5。

公开字段：无。

常量（不含依赖脚本引用）：`CONTEXT_FIELDS`、`LOCAL_FIELDS`、`WAITS`。

```gdscript
extends RefCounted
static func capture(game: Node,detached_nodes: Array=[]) -> Dictionary
static func decode(value: Variant, map: Dictionary, lookup: Callable = Callable()) -> Dictionary
static func restore(game: Node, value: Dictionary) -> void
```

### EditorCommandDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorCommandDialog.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：`GROUPS`。

```gdscript
extends ConfirmationDialog
signal accepted(code: int, parameters: Array)
func open(documents: RefCounted, code: int = 101, parameters: Array = [], adding: bool = true, characters: Dictionary = {}) -> void
```

### EditorCommands.gd

源文件：templates/editor/addons/rgm_editor/EditorCommands.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：`SCHEMA`、`ROUTE_NAMES`、`MARKERS`。

```gdscript
extends RefCounted
static func name_for(code: int) -> String
static func available() -> Array
static func command(code: int, indent: int = 0, parameters: Array = []) -> Dictionary
static func defaults(code: int) -> Array
static func route_command(code: int = 3) -> Dictionary
static func parameters_for(code: int, p: Array) -> Array
static func variant_parameters(code: int, p: Array, index: int, value: Variant) -> Array
static func expand(code: int, p: Array, indent: int) -> Array
static func span(list: Array, index: int) -> Vector2i
static func validate_structure(list: Array) -> String
static func summary(c: Dictionary, documents: RefCounted = null, characters: Dictionary = {}) -> String
```

### EditorDocuments.gd

源文件：templates/editor/addons/rgm_editor/EditorDocuments.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
signal changed
func _init(root_path: String = "res://") -> void
func read(path: String) -> Variant
func apply(path: String, value: Variant, label: String = "编辑") -> Dictionary
func apply_batch(changes: Dictionary, label: String = "批量编辑") -> Dictionary
func undo() -> bool
func redo() -> bool
func group_recent(count: int) -> void
func can_undo() -> bool
func can_redo() -> bool
func dirty_paths() -> Array
func error_message() -> String
func reload() -> void
func save_all() -> Dictionary
func records(name: String) -> Array
func reference_label(category: String, id: int, empty: String = "") -> String
func lookup(name: String) -> Array
func assets(category: String) -> Array
func asset_audio(category: String, name: String) -> AudioStream
func asset_texture(category: String, name: String) -> Texture2D
func new_page() -> Dictionary
func validate(path: String, value: Variant, before: Variant) -> String
```

### EditorMapCanvas.gd

源文件：templates/editor/addons/rgm_editor/EditorMapCanvas.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：`AUTOTILE_PARTS`。

```gdscript
extends Control
signal cell_pressed(cell: Vector2i, double_click: bool, button: int)
signal cell_dragged(cell: Vector2i)
signal stroke_finished
signal tile_selected(id: int)
signal brush_selected(tiles: Array)
signal cell_hovered(cell: Vector2i)
signal zoom_changed(value: float)
func configure(map: Dictionary, documents: RefCounted, palette: bool = false) -> void
func configure_tileset(tileset: Dictionary, documents: RefCounted) -> void
func set_palette_zoom(value: float) -> void
func set_layer(layer: int) -> void
func set_event_mode(enabled: bool) -> void
func set_property_mode(mode: String) -> void
func set_zoom(value: float) -> void
func reset_view() -> void
func update_map(map: Dictionary) -> void
func set_brush(tiles: Array, visible_brush: bool = true) -> void
func finish_input() -> void
func palette_region() -> Rect2i
func select_cell(cell: Vector2i) -> void
func select_tile(id: int) -> void
func focus_cell(cell: Vector2i) -> void
func set_region(region: Rect2i) -> void
func draw_tile(id: int,pos: Vector2,scale_value: float, opacity: float = 1.0) -> void
func terrain_text(id: int) -> String
```

### EditorMapOps.gd

源文件：templates/editor/addons/rgm_editor/EditorMapOps.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func tile(map: Dictionary, cell: Vector2i, layer: int) -> int
static func valid(map: Dictionary, cell: Vector2i) -> bool
static func paint(map: Dictionary, cells: Array, layer: int, id: int) -> void
static func stamp(map: Dictionary, origins: Array, layer: int, brush: Array) -> void
static func pattern(map: Dictionary, cells: Array, layer: int, brush: Array, anchor: Vector2i) -> void
static func line_cells(start: Vector2i, end: Vector2i) -> Array
static func flood_cells(map: Dictionary, start: Vector2i, layer: int) -> Array
static func resize_map(map: Dictionary, width: int, height: int) -> Dictionary
static func layer_count(map: Dictionary) -> int
static func layer_names(map: Dictionary) -> Array
static func set_layer_count(map: Dictionary, count: int) -> Dictionary
static func next_event_id(map: Dictionary) -> int
```

### EditorPanel.gd

源文件：templates/editor/addons/rgm_editor/EditorPanel.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
func setup(documents: RefCounted = null) -> void
func save_changes() -> bool
func unsaved_status() -> String
```

### EditorRouteDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorRouteDialog.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
signal accepted(route: Dictionary)
func open(route: Dictionary, documents: RefCounted = null) -> void
```

### EditorRouteForm.gd

源文件：templates/editor/addons/rgm_editor/EditorRouteForm.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
func configure(route: Dictionary, documents: RefCounted = null, read_only: bool = false) -> void
func draft() -> Dictionary
```

### EditorScriptAdapter.gd

源文件：templates/editor/addons/rgm_editor/EditorScriptAdapter.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func adapt_map(source: Dictionary) -> Dictionary
static func adapt_common(source: Array) -> Array
```

### EditorValueForm.gd

源文件：templates/editor/addons/rgm_editor/EditorValueForm.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：`IMAGE_ASSETS`、`LABELS`。

```gdscript
extends VBoxContainer
signal value_changed(value: Variant, path: Array, edited: Variant)
signal asset_edit_requested(path: Array)
func configure(value: Variant, labels: Variant = {}, documents: RefCounted = null, hints: Dictionary = {}, read_only: bool = false) -> void
func draft() -> Variant
func edit_path(path: Array) -> void
func edit_asset(path: Array) -> void
```

### Plugin.gd

源文件：templates/editor/addons/rgm_editor/Plugin.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends EditorPlugin
# 本类未声明自定义公共方法。
```

### EditorCommandList.gd

源文件：templates/editor/addons/rgm_editor/EditorCommandList.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。多行指令按原生续行编号及相同缩进组成视觉块；正文按字体宽度对齐，几何竖线贯通整块，空行也绘制。鼠标和键盘一次选中整块，复制/删除/粘贴/移动按整条处理；条件/循环的内部指令不属于续行。原文从draft/原参数读取；续行TreeItem文本仅保留分支标记，描述与提示保留正文。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
signal changed(list: Array)
func configure(list: Array, documents: RefCounted, characters: Dictionary = {}) -> void
func draft() -> Array
```


### EditorDatabaseDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorDatabaseDialog.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
func open(documents: RefCounted) -> void
func apply_current() -> bool
func open_tileset(documents: RefCounted, id: int) -> void
func pending_status() -> String
```


### EditorDatabaseSchema.gd

源文件：templates/editor/addons/rgm_editor/EditorDatabaseSchema.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：`CATEGORIES`、`LABELS`、`REFERENCES`、`SETS`。

```gdscript
extends RefCounted
static func audio(name: String = "") -> Dictionary
static func table(x: int, y: int = 1, z: int = 1, fill: int = 0) -> Dictionary
static func frame() -> Dictionary
static func timing() -> Dictionary
static func new_record(category: String, id: int, documents: RefCounted) -> Dictionary
static func hints(category: String, value: Dictionary) -> Dictionary
static func normalize(category: String, record: Dictionary, before: Dictionary = {}) -> Dictionary
static func reason(category: String, value: Dictionary, before: Dictionary, documents: RefCounted) -> String
```


### EditorSetDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorSetDialog.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
signal accepted(ids: Array)
func open(ids: Array, choices: Array, ordered: bool = false, caption: String = "集合") -> void
```


### EditorTableDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorTableDialog.gd。生成到res://addons/rgm_editor/，编辑器使用脱离运行现场的数据草稿；具体行为见第8.3节。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
signal accepted(table: Dictionary)
func open(value: Dictionary, kind: String, documents: RefCounted = null) -> void
```


### EditorTilesetEditor.gd

源文件：templates/editor/addons/rgm_editor/EditorTilesetEditor.gd。原图块图像点选后编辑共享passages/priorities/terrain_tags；自动图块可批量更新48个形状ID，草丛0x40/柜台0x80与原RM及MapRuntime一致，其他原位保留。仅编辑属性时按图像补齐新图块表，打开不改变原记录；背景参数与素材预览直接编辑脱离现场的值，不执行游戏。

公开字段：无。
常量（不含依赖脚本引用）：`BACKGROUND_FIELDS`。

```gdscript
extends VBoxContainer
signal sources_requested
func configure(value: Dictionary, documents: RefCounted) -> void
func draft() -> Dictionary
```

### EditorPresentation.gd

源文件：templates/editor/addons/rgm_editor/EditorPresentation.gd。编辑器文案、引用、参数含义与事件摘要；只读草稿，不操作运行时。101/108首行保留指令类型，401/408续行仅显示文本；EditorCommandList按主题字体测量首行前缀，将续行正文对齐至首行正文起点，分支标记保持原位。同段沿用文本/注释类别色，原始编号、参数和整段编辑规则保持。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func reference_text(documents: RefCounted, category: String, value: Variant, empty: String = "") -> String
static func character(value: Variant, characters: Dictionary = {}) -> String
static func field(value: Variant, hint: Dictionary, documents: RefCounted = null) -> String
static func summary(code: int, p: Array, name: String, documents: RefCounted = null, characters: Dictionary = {}) -> String
static func route_summary(code: int, p: Array, name: String, documents: RefCounted = null) -> String
static func parameter_hints(code: int, p: Array, characters: Dictionary = {}) -> Dictionary
```

### EditorAssetPreview.gd

源文件：templates/editor/addons/rgm_editor/EditorAssetPreview.gd。图片与行走图预览；实例私有材质/裁切，双击和网格选帧信号。

公开字段：`texture`。
常量（不含依赖脚本引用）：`HUE_SHADER`、`TITLES`、`PURPOSES`。

```gdscript
extends Control
signal activated
signal frame_selected(direction: int, pattern: int)
func configure(documents: RefCounted, category: String, asset_name: String, settings: Dictionary = {}, sheet: bool = false, editable: bool = true, caption: String = "") -> void
```

### EditorAssetDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorAssetDialog.gd。搜索、分页缩略图、大图、方向帧与颜色预览，确认返回独立选择。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
signal accepted(asset_name: String, settings: Dictionary)
func open(documents: RefCounted, category: String, current: String, settings: Dictionary = {}, caption: String = "") -> void
```

### EditorEventPageForm.gd

源文件：templates/editor/addons/rgm_editor/EditorEventPageForm.gd。事件页分组直接控件，共用原草稿、引用与路线对话框。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends "EditorValueForm.gd"
# 本类未声明自定义公共方法。
```

### EditorTileGraphicDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorTileGraphicDialog.gd。从当前地图绑定的图块集点选普通图块作为事件外观，取消不修改草稿。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
signal accepted(tile_id: int)
func open(documents: RefCounted, tileset: Dictionary, graphic: Dictionary) -> void
```

### TilesetLayout.gd

公开字段：`segments`、`errors`、`tile_count`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/TilesetLayout.gd。多素材普通图块虚拟布局，保留单纹理兼容；共享素材只读，定位与AtlasTexture不合成图片。

```gdscript
extends RefCounted
static func sources(definition: Dictionary, loader: Callable) -> Array
func configure(definition: Dictionary, loader: Callable) -> void
func locate(id: int) -> Dictionary
func tile_texture(id: int) -> Texture2D
```

### EditorTilesetOps.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/editor/addons/rgm_editor/EditorTilesetOps.gd。图块组合编号和原生标记的脱离现场同步计划；验证所有引用地图及事件，失败不修改编辑草稿。

```gdscript
extends RefCounted
static func prepare(documents: RefCounted, id: int, before: Dictionary, value: Dictionary) -> Dictionary
```

### EditorTilesetSourcesDialog.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/editor/addons/rgm_editor/EditorTilesetSourcesDialog.gd。普通图块素材顺序、替换和移除界面，确认以原子草稿事务同步数据库和地图，显式保存才写磁盘。

```gdscript
extends ConfirmationDialog
signal accepted(value: Dictionary)
func open(documents: RefCounted, value: Dictionary) -> void
```

### EditorDatabaseForm.gd

源文件：templates/editor/addons/rgm_editor/EditorDatabaseForm.gd。继承Typed ValueForm草稿和素材/表格/集合选择器，主界面用具名控件和用途页签替换字段树；隐藏树只供原有数据定位，不提供重复可见入口。未知扩展独立，原生Troops只读。

公开字段：无。

常量（不含依赖脚本引用）：`GROUPS`、`WORD_LABELS`、`CUSTOM_LABELS`。

```gdscript
extends "EditorValueForm.gd"
# 本类未声明自定义公共方法。
```

### EditorNamesEditor.gd

源文件：templates/editor/addons/rgm_editor/EditorNamesEditor.gd。开关/变量/属性稳定编号名称表；过滤与分页不改变ID，保护编号0，只允许末尾追加。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
signal changed(names: Array)
func configure(names: Array, kind: String, documents: RefCounted = null) -> void
func draft() -> Array
```

### EditorLearningsEditor.gd

源文件：templates/editor/addons/rgm_editor/EditorLearningsEditor.gd。职业习得等级和具名特技编辑，保留同级多条、原顺序及额外字段。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
signal changed(learnings: Array)
signal edit_requested(path: Array)
func configure(learnings: Array, documents: RefCounted) -> void
```

### EditorAnimationEditor.gd

源文件：templates/editor/addons/rgm_editor/EditorAnimationEditor.gd。动画帧、单元及音效/闪光时序专用编辑，预览只显示图像，不执行事件或音效；删除有时序的帧被拦截，后续时序随帧删除调整。

公开字段：无。

常量（不含依赖脚本引用）：`CELL_LABELS`。

```gdscript
extends VBoxContainer
signal changed(animation: Dictionary)
signal edit_requested(path: Array)
func configure(value: Dictionary, documents: RefCounted) -> void
func draft() -> Dictionary
```

### EditorAnimationCanvas.gd

源文件：templates/editor/addons/rgm_editor/EditorAnimationCanvas.gd。独立Sprite2D预览原生192px/5列动画图案、位置、缩放、逆向旋转、镜像、透明度和混合；纹理只读，每预览拥有色相材料。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
func configure(frame: Dictionary, texture: Texture2D, hue: int, selected: int = -1) -> void
```

### EditorAudioPreview.gd

源文件：templates/editor/addons/rgm_editor/EditorAudioPreview.gd。编辑器独立试听与动画音效。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends Node
func play(documents: RefCounted, category: String, audio: Dictionary, replace: bool = true) -> bool
func set_parameters(volume: float, pitch: float) -> void
func stop() -> void
```

### EditorAudioBrowser.gd

源文件：templates/editor/addons/rgm_editor/EditorAudioBrowser.gd。音频库及实时试听面板。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
func configure(documents: RefCounted, category: String, value: Dictionary = {}) -> void
func draft() -> Dictionary
func stop() -> void
```

### EditorAudioDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorAudioDialog.gd。音频引用和参数选择。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends ConfirmationDialog
signal accepted(audio: Dictionary)
func open(documents: RefCounted, category: String, audio: Dictionary) -> void
```

### EditorMapLocationPicker.gd

源文件：templates/editor/addons/rgm_editor/EditorMapLocationPicker.gd。实际地图点格位置选择。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends VBoxContainer
signal chosen(map_id: int, cell: Vector2i)
signal map_browsed(map_id: int)
func configure(documents: RefCounted, map_id: int, cell: Vector2i) -> void
```

### EditorCapacityOps.gd

源文件：templates/editor/addons/rgm_editor/EditorCapacityOps.gd。编号容量和引用保护的纯草稿计划。

公开字段：无。
常量（不含依赖脚本引用）：`MAXIMUM`。

```gdscript
extends RefCounted
static func resize(documents: RefCounted, category: String, values: Array, maximum: int) -> Dictionary
```

### EditorCommandColors.gd

源文件：templates/editor/addons/rgm_editor/EditorCommandColors.gd。事件与路线的类别色和主题对比。

公开字段：无。
常量（不含依赖脚本引用）：`DARK`、`LIGHT`。

```gdscript
extends RefCounted
static func group(code: int, route: bool = false) -> String
static func apply(tree: Tree, row: TreeItem, code: int, unsupported: bool = false, route: bool = false) -> void
```

### ScriptRuntime.gd

源文件：templates/runtime/scripts/ScriptRuntime.gd。显式或事件执行生成单元；绑定校验、按序惰性库加载和未迁移依赖诊断。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func execute_unit(unit_id: String, state: Object) -> Dictionary
static func prewarm() -> Dictionary
static func validate_binding(binding: Variant, source: String) -> Dictionary
static func execute_bound(binding: Variant, source: String, state: Object, context: Dictionary) -> Dictionary
static func error_text(result: Dictionary) -> String
static func save_reason(state: Object) -> String
static func call_method(receiver: Dictionary, method: String, arguments: Array, state: Object) -> Dictionary
static func call_transaction(state: Object,context: Dictionary,operation: Callable) -> Dictionary
static func dispatch_snapshot_exports(result: Dictionary) -> Dictionary
static func new_object(class_name_value: String, arguments: Array, state: Object) -> Dictionary
static func script_data(state: Object) -> Dictionary
static func validate_saved_data(value: Dictionary) -> String
static func validate_saved_objects(value: Variant,classes: Dictionary,seen: Array=[]) -> String
static func evaluate_data_expression(id: String,state: Object) -> Dictionary
```

### ScriptStateBridge.gd

源文件：templates/runtime/scripts/ScriptStateBridge.gd。生成单元的现有状态桥；整段验证后调用RuntimeState业务写入。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func apply(state: Object, operations: Array, origin: Dictionary = {}) -> Dictionary
```

### RubySubsetCompiler.gd

源文件：scripts/importer/RubySubsetCompiler.gd。迁移时严格子集编译器；返回AST、IR、生成文本或原位置诊断。

公开字段：无。
常量（不含依赖脚本引用）：`FORMAT`。

```gdscript
extends RefCounted
func compile(source: String, origin: Dictionary = {}) -> Dictionary
```

### ScriptMigrationInventory.gd

源文件：scripts/importer/ScriptMigrationInventory.gd。迁移前提取原脚本/事件片段并生成加载顺序和词法依赖证据；不执行Ruby。

公开字段：`raw_maps`、`raw_common`、`continuations`、`fragments`、`interpreter_policy`。
常量（不含依赖脚本引用）：`FORMAT`。

```gdscript
extends RefCounted
func configure_scripts(scripts: Array[Dictionary]) -> void
func collect_map(map: Dictionary, map_name: String) -> void
func collect_common(events: Array, database: String = "CommonEvents") -> void
func generate(output_root: String, scripts: Array[Dictionary]) -> Dictionary
```

### ScriptSemantics.gd

源文件：templates/runtime/scripts/ScriptSemantics.gd。

公开字段：`state`、`classes`、`methods`、`globals`、`constants`、`failure`、`origin`、`span`、`execution_context`、`definition_loader`、`loaded_units`、`loading_units`。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(runtime_state: Object) -> void
static func program(path: String) -> GDScript
static func truth(value: Variant) -> bool
static func text(value: Variant) -> String
static func words(value: String) -> Array
func stringify(value: Variant, depth: int = 0) -> Variant
func hash_pairs(pairs: Array) -> Dictionary
func begin(source_origin: Dictionary) -> bool
func begin_query(source_origin: Dictionary,plan: Dictionary) -> bool
func finish_query(value: Variant) -> Dictionary
func finish(value: Variant) -> Dictionary
func root_receiver() -> Variant
func ensure_definition(name: String, owner: String = "", singleton: bool = false) -> void
func tick(location: Dictionary) -> bool
func fail(message: String) -> Variant
func declare_type(name: String, parent: String, kind: String) -> void
func define_method(owner: String, name: String, singleton: bool, path: String, function: String, source: Dictionary) -> void
func alias_method(owner: String, name: String, target: String, singleton: bool = false) -> void
func copy_module_function(owner: String,name: String) -> void
func type_ref(name: String) -> Variant
func include_module(owner: String, module: Variant, singleton: bool = false) -> void
func object_ref(name: String) -> Variant
func read_name(name: String, locals: Dictionary, receiver: Variant, owner: String) -> Variant
func write_name(name: String, value: Variant, locals: Dictionary, receiver: Variant, owner: String) -> Variant
func index_get(receiver: Variant, index: Variant) -> Variant
func indexes_get(receiver: Variant,indexes: Array) -> Variant
func index_set(receiver: Variant, index: Variant, value: Variant) -> Variant
func unary(operator: String, value: Variant) -> Variant
func binary(operator: String, left: Variant, right: Variant) -> Variant
func sequence(first: Variant, last: Variant, exclusive: bool) -> Variant
func iterable(value: Variant) -> Array
func invoke(receiver: Variant, name: String, args: Array, owner: String = "Object") -> Variant
func regex_value(pattern: String,flags: String) -> Variant
func regex_match(descriptor: Dictionary,value: String) -> Variant
func enter_regex_scope() -> Variant
func leave_regex_scope(previous: Variant) -> void
func flash_attribute_read(name: Variant) -> Variant
func flash_attribute_write(name: Variant,value: Variant) -> Variant
func flash_name_value(source: Variant) -> Variant
func invoke_block(receiver: Variant, name: String, block: Callable) -> Variant
func copy_value(value: Variant, graph: Array = [], depth: int = 0) -> Variant
func big_integer(value: String) -> Variant
```

### RubyGDScriptCompiler.gd

源文件：scripts/importer/RubyGDScriptCompiler.gd。

公开字段：无。
常量（不含依赖脚本引用）：`FORMAT`、`BUILTINS`。

```gdscript
extends RefCounted
func compile(source: String, origin: Dictionary = {}, generated_path: String = "", known_methods: Array = []) -> Dictionary
func compile_ast(ast: Dictionary, generated_path: String, known_methods: Array = []) -> Dictionary
func method_names(ast: Dictionary) -> Array
```

### RubyLexer.gd

源文件：scripts/importer/RubyLexer.gd。

公开字段：无。
常量（不含依赖脚本引用）：`FORMAT`、`OPERATORS`。

```gdscript
extends RefCounted
func tokenize(source: String) -> Dictionary
```

### RubyParser.gd

源文件：scripts/importer/RubyParser.gd。

公开字段：无。
常量（不含依赖脚本引用）：`FORMAT`、`PRECEDENCE`。

```gdscript
extends RefCounted
func parse(source: String, origin: Dictionary = {}) -> Dictionary
```

### RubySemanticModel.gd

源文件：scripts/importer/RubySemanticModel.gd。

公开字段：无。
常量（不含依赖脚本引用）：`FORMAT`。

```gdscript
extends RefCounted
func build(entries: Array) -> Dictionary
```

### ScriptEventIntegrator.gd

源文件：scripts/importer/ScriptEventIntegrator.gd。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func key(origin: Dictionary) -> String
static func bind_list(commands: Array, origin: Dictionary, bindings: Dictionary) -> void
static func bind_route(route: Dictionary, origin: Dictionary, bindings: Dictionary) -> void
static func integrate(root: String, maps: Dictionary, common: Dictionary, units: Dictionary, errors: Array[String]) -> int
static func definitions(body: Array, owner: String = "Object",singleton_scope: bool=false) -> Dictionary
```

### CustomDataState.gd

源文件：templates/runtime/scripts/CustomDataState.gd。

公开字段：`manifest`、`values`、`failure`、`actor_edits`、`script_variables`、`execution_context`、`pending_effects`、`character_edits`、`screen_edits`、`last_screen_request`、`script_switches`、`keyboard_draft`、`scene_request`、`temp_fields`、`preference_data`、`history_request`、`movie_request`、`snapshot_requests`、`party_ids`、`inventory_items`、`live_execution`、`preference_changed`。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(owner: Object=null,initialize: bool=true) -> void
func reset() -> void
func currency_maximum(key: String="gold") -> Variant
func currency(key: String="gold") -> Variant
func valid_currency(value: Variant,key: String="gold") -> bool
func gain_currency(key: String,amount: Variant) -> Dictionary
func currency_rows() -> Array
func fork(copy_values: bool=true) -> RefCounted
func live_view() -> RefCounted
func install(draft: RefCounted) -> void
func snapshot() -> Dictionary
func restore(value: Variant) -> Dictionary
func record(database: String,id: int) -> Dictionary
func actor_attributes(id: int) -> Dictionary
func staged_actor(id: int) -> RefCounted
func gameplay() -> RefCounted
func map_system() -> RefCounted
func data_ref(kind: String,id: int=0,database: String="",event: int=0) -> Dictionary
func named(name: String) -> Variant
func index_get(ref: Dictionary,index: Variant) -> Variant
func invoke(ref: Dictionary,name: String,args: Array) -> Variant
func floor_tree_map(map_id: int) -> Variant
func party_call(name: String,args: Array) -> Variant
func monster_set(name: String,args: Array) -> Variant
func floor_entry(map_id: int,index: Variant) -> Variant
func rebuild_floor_indices(map_id: int) -> void
func reject(message: String) -> Variant
static func error(message: String) -> Dictionary
static func native_value(value: Variant) -> Variant
static func plain_reason(value: Variant,seen: Array=[],depth: int=0) -> String
static func same_value(a: Variant,b: Variant,seen: Array=[]) -> bool
```

### DecimalInteger.gd

源文件：templates/runtime/scripts/DecimalInteger.gd。

公开字段：无。
常量（不含依赖脚本引用）：`SAFE`。

```gdscript
extends RefCounted
static func normalize(value: Variant) -> String
static func compact(value: Variant) -> Variant
static func compare(a: Variant, b: Variant) -> int
static func add(a: Variant, b: Variant) -> Variant
static func negate(value: Variant) -> Variant
static func clamped_add(value: Variant, delta: Variant, maximum: Variant) -> Variant
```

### CustomDataImporter.gd

源文件：scripts/importer/CustomDataImporter.gd。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func generate(source_root: String, output_root: String, scripts: Array, maps: Dictionary, codec: RefCounted,common: Dictionary={}) -> Dictionary
```

### RubyDataValues.gd

源文件：scripts/importer/RubyDataValues.gd。

公开字段：`ruby_hash`、`constants`、`failure`。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func parse(source: String, origin: Dictionary={}) -> Dictionary
func expression(n: Dictionary, locals: Dictionary={}) -> Variant
```

### CustomDataTags.gd

源文件：templates/runtime/scripts/CustomDataTags.gd。

公开字段：无。
常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func parse(name: String) -> Array
```

### FlashGameplayImporter.gd

源文件：scripts/importer/FlashGameplayImporter.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func generate(output_root: String,scripts: Array) -> Dictionary
```

### FlashActorFields.gd

源文件：templates/runtime/scripts/FlashActorFields.gd。

公开字段：无。

常量（不含依赖脚本引用）：`KEYS`、`FIELDS`。

```gdscript
extends RefCounted
static func validate(value: Variant) -> String
static func integer(value: Variant) -> bool
static func number(value: Variant) -> bool
```

### FlashActorState.gd

源文件：templates/runtime/scripts/FlashActorState.gd。

公开字段：`project_fields`、`project_rules`。

常量（不含依赖脚本引用）：`PROJECT_KEYS`。

```gdscript
extends "ActorState.gd"
func configure(actor_id: int,definition: Dictionary,lookup: Callable) -> void
func attach_project_fields(fields: Dictionary) -> void
func get_parameter(key: String) -> Variant
func set_project_parameter(key: String,value: Variant) -> Dictionary
func get_resist() -> Array
func set_resist(values: Array) -> Dictionary
func equip_project(slot: int,record_id: int) -> Dictionary
func next_level_experience() -> Variant
func equip_project_skill(skill_id: int,turn: int) -> Dictionary
func cancel_project_skill(skill_id: int,turn: int) -> void
func project_skill_slot(skill_id: int) -> Array
func trans_project_skill(skill_id: int,turn: int) -> Dictionary
func swap_project_skills(first_id: int,second_id: int,first_turn: int,second_turn: int) -> Dictionary
func set_project_class(value: Variant) -> Dictionary
func clear_project_skills() -> void
func save_project_skill_set(index: int,side: String) -> Dictionary
func load_project_skill_set(index: int,side: String) -> Dictionary
func set_experience(value: Variant) -> Dictionary
func add_experience(amount: Variant) -> Dictionary
func add_level(amount: Variant) -> Dictionary
func get_parameter_plus(key: String) -> Variant
func set_parameter_plus(key: String,value: Variant) -> Dictionary
func set_level(value: Variant) -> Dictionary
func battle_down() -> bool
func inflict_battle_down(rest_count: int=-1) -> void
func recover_battle_down() -> void
func tick_battle_down_recovery() -> void
func snapshot(equipment_override: Array=[],level_override: int=-1,bonuses_override: Dictionary={}) -> Dictionary
func automatic_state_ids() -> Array
func add_project_state(state_id: int,force: bool=false) -> Dictionary
func clear_states() -> Dictionary
func reset_project_all() -> Dictionary
func recover_all() -> Dictionary
func set_vital(key: String,value: Variant) -> Dictionary
func add_vital(key: String,amount: Variant) -> Dictionary
func change_hp_native(amount: int,allow_death: bool,zero_hp_ids: Array) -> Dictionary
func project_state_query(name: String) -> Variant
func get_state_ids(include_equipment: bool=true) -> Array[int]
func periodic_damage(attacker: RefCounted) -> int
func persistent_data() -> Dictionary
func restore_persistent(saved: Dictionary) -> String
func detached_copy() -> Dictionary
func commit_event_state(prepared: RefCounted) -> void
```

### FlashBattleSimulator.gd

源文件：templates/runtime/scripts/FlashBattleSimulator.gd。

公开字段：`registry`、`skills`、`constants`、`failure`、`catalog_failure`。

常量（不含依赖脚本引用）：`REACTIONS`、`PASSIVES`。

```gdscript
extends RefCounted
func configure(rules: Dictionary) -> void
func validate() -> String
func define_skill(id: int,builder: Callable=Callable()) -> Dictionary
func resolve_enemy_skills(actions: Array,patience: int) -> Dictionary
func predict(main: Dictionary,support: Dictionary,enemy: Dictionary) -> Dictionary
func enemy_attributes(main: Dictionary,support: Dictionary,enemy: Dictionary) -> Dictionary
func skill_spec(id: int,side: String="actor") -> Dictionary
func legacy_log(result: Dictionary) -> Array
func build_context(main: Dictionary,support: Dictionary,enemy: Dictionary,result: Dictionary) -> Dictionary
```

### FlashCharacterBridge.gd

源文件：templates/runtime/scripts/FlashCharacterBridge.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func invoke(custom: RefCounted,ref: Dictionary,name: String,args: Array) -> Variant
static func validate(edits: Array) -> String
static func commit(edits: Array) -> void
```

### FlashGameplay.gd

源文件：templates/runtime/scripts/FlashGameplay.gd。

公开字段：`rules`、`simulator`、`simulation_count`、`cache_service`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(custom: RefCounted,definitions: RefCounted=null) -> void
func role_ids(initialize_main: bool=false,synchronize: bool=false) -> Array
func role_actor_ids() -> Array
func party_snapshot() -> Array
func party_cache_inputs() -> Array
func actor_input(actor: RefCounted) -> Dictionary
func enemy_input(map_id: int,event_id: int) -> Dictionary
func enemy_fields(map_id: int,event_id: int) -> Dictionary
func predict(map_id: int,event_id: int,force: bool=false) -> Variant
func begin_battle(map_id: int,event_id: int) -> Variant
func finish_battle(map_id: int,event_id: int) -> Variant
func load_skill_set(actor: RefCounted,index: int,side: String) -> Variant
func apply_actor_preset(actor_id: int,index: int=0) -> Variant
func enemy_call(ref: Dictionary,name: String,args: Array) -> Variant
func invoke(ref: Dictionary,name: String,args: Array) -> Variant
```

### RubyRegexValues.gd

源文件：templates/runtime/scripts/RubyRegexValues.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func compile(pattern: String,flags: String) -> Dictionary
static func match_value(descriptor: Dictionary,value: String) -> Dictionary
static func split(descriptor: Dictionary,value: String,limit: int=0) -> Dictionary
```

### FlashSourceCorrections.gd

源文件：scripts/importer/FlashSourceCorrections.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func adapt(source: String,origin: Dictionary) -> Dictionary
static func native_adaptations(source: String,origin: Dictionary) -> Array
static func adapt_commands(commands: Array,origin: Dictionary) -> Array
```

### FlashActions.gd

源文件：templates/runtime/scripts/FlashActions.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func exchange_crystal(state: Object,id: int,index: int,crystal_id: int) -> Dictionary
static func equip(state: Object,actor_id: int,slot: int,equipment_id: int) -> Dictionary
static func equip_skill(state: Object,actor_id: int,skill_id: int,turn: int) -> Dictionary
static func cancel_skill(state: Object,actor_id: int,skill_id: int,turn: int) -> Dictionary
static func set_roles(state: Object,main_id: int,support_id: int) -> Dictionary
static func use_item(state: Object,item_id: int) -> Dictionary
static func after_step(state: Object) -> Dictionary
static func recover_item(state: Object,item_id: int,actor_id: int) -> Dictionary
static func request_tool(state: Object,item_id: int) -> Dictionary
static func save_skill_set(state: Object,actor_id: int,index: int,side: String) -> Dictionary
static func load_skill_set(state: Object,actor_id: int,index: int,side: String) -> Dictionary
static func switch_roles(state: Object) -> Dictionary
static func choose_floor(state: Object,floor_number: Variant) -> Dictionary
static func cancel_floor(state: Object) -> Dictionary
static func choose_character(state: Object,actor_id: Variant) -> Dictionary
static func cancel_character(state: Object) -> Dictionary
```

### FlashBlastic.gd

源文件：templates/runtime/scripts/FlashBlastic.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func record(custom: RefCounted,id: int) -> Dictionary
static func invoke(custom: RefCounted,id: int,name: String,args: Array) -> Variant
static func exchange(custom: RefCounted,id: int,index: int,crystal_id: int) -> Dictionary
static func echoes(custom: RefCounted,elements: Array,preview: bool=false) -> Array
static func validate(custom: RefCounted,values: Dictionary) -> String
```

### FlashMapBridge.gd

源文件：templates/runtime/scripts/FlashMapBridge.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func invoke(custom: RefCounted,ref: Dictionary,name: String,args: Array) -> Variant
static func event_name(custom: RefCounted,map_id: int,event_id: int) -> String
static func is_dead(custom: RefCounted,map_id: int,event_id: int) -> bool
static func set_event_name(custom: RefCounted,map_id: int,event_id: int,value: String) -> void
static func current_map(custom: RefCounted) -> Node
static func read_tile(custom: RefCounted,map: Node,x: int,y: int,layer: int) -> Variant
static func write_tile(custom: RefCounted,map: Node,x: int,y: int,layer: int,value: int) -> void
static func check_event(custom: RefCounted,map: Node,x: int,y: int) -> int
static func passable_zero(custom: RefCounted,map: Node,x: int,y: int) -> bool
static func validate_saved_tiles(changes: Variant) -> String
```

### FlashObjectCatalog.gd

源文件：templates/runtime/scripts/FlashObjectCatalog.gd。

公开字段：无。

常量（不含依赖脚本引用）：`DATABASES`、`CLASSES`。

```gdscript
extends RefCounted
static func construct(custom: RefCounted,type_name: String,args: Array) -> Variant
static func object_ref(custom: RefCounted,database: String,id: int) -> Variant
static func class_name_for(database: String) -> String
static func is_a(database: String,type_name: String) -> bool
static func equipment_ref(custom: RefCounted,kind: Variant,id: Variant) -> Variant
static func value(custom: RefCounted,database: String,id: int,field: String,fields: Dictionary={}) -> Variant
static func validate_saved(value: Variant) -> String
```

### FlashValueExtensions.gd

源文件：templates/runtime/scripts/FlashValueExtensions.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func vector(left: Array,right: Variant,operation: String) -> Dictionary
static func bwise(values: Array,code: String) -> Dictionary
```

### FlashEnemyAbilities.gd

源文件：templates/runtime/scripts/FlashEnemyAbilities.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func map_parameters(actions: Array,constants: Dictionary) -> Dictionary
static func elements(definition: Dictionary) -> Array
```

### FlashItemEffects.gd

源文件：templates/runtime/scripts/FlashItemEffects.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func invoke(custom: RefCounted,name: String,args: Array) -> Variant
```

### FlashMapDamage.gd

源文件：templates/runtime/scripts/FlashMapDamage.gd。

公开字段：无。

常量（不含依赖脚本引用）：`OFFSETS`、`DIRECTIONS`。

```gdscript
extends RefCounted
static func invoke(custom: RefCounted,name: String) -> Variant
```

### FlashBattleCache.gd

源文件：templates/runtime/scripts/FlashBattleCache.gd。

公开字段：`conditions`、`revision`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func register_condition(name: String,provider: Callable) -> Dictionary
static func unregister_condition(name: String) -> void
static func clear_conditions() -> void
func tag_for(key: String,party: Array,enemy: Dictionary,skills: Dictionary,skill_revision: int) -> Dictionary
func with_party_snapshot(action: Callable) -> Variant
```

### FlashBattleCatalog.gd

源文件：templates/runtime/scripts/FlashBattleCatalog.gd。

公开字段：无。

常量（不含依赖脚本引用）：`SOURCE_PATH`。

```gdscript
extends RefCounted
static func install_catalog(registry: RefCounted,catalog: Dictionary) -> Dictionary
```

### FlashBattleRegistry.gd

源文件：templates/runtime/scripts/FlashBattleRegistry.gd。

公开字段：`definitions`、`revision`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func is_configured() -> bool
func configure(catalog: Dictionary) -> void
func define_skill(id: int,builder: Callable=Callable()) -> Dictionary
func fetch(id: int) -> Variant
func includes(id: int) -> bool
func action_skill(id: int) -> bool
func reaction_skill(id: int) -> bool
func passive_skill(id: int) -> bool
func rage_skill(id: int) -> bool
func database_fields(id: int) -> Dictionary
```

### FlashBattlerRules.gd

源文件：templates/runtime/scripts/FlashBattlerRules.gd。

公开字段：无。

常量（不含依赖脚本引用）：`KEYS`。

```gdscript
extends RefCounted
static func parameter(base: Variant,plus: Variant,key: String,states: Array,record: Callable) -> int
static func resist(base: Array,plus: Array,states: Array,record: Callable) -> Array
static func change(current: Dictionary,ids: Array,adding: bool,force: bool,parameter_getter: Callable,record: Callable) -> Dictionary
static func query(states: Array,name: String,record: Callable) -> Variant
```

### FlashBattleSkillDefinition.gd

源文件：templates/runtime/scripts/FlashBattleSkillDefinition.gd。

公开字段：`value`、`failure`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(id: int) -> void
func display(name: String,description: Variant=null) -> RefCounted
func action(target: String,atk_rate: float,hit_count: int=1,stiffness: int=20) -> RefCounted
func follow_up_damage(rate: float=0.0) -> RefCounted
func follow_up_counter(threshold: int,atk_rate: float) -> RefCounted
func follow_up_attack_count(threshold: int,atk_rate: float) -> RefCounted
func passive_enemy_defense_rate(rate: float) -> RefCounted
func passive_attack_rate(rate: float) -> RefCounted
func extra_attack(count: int) -> RefCounted
func rage(builder: Callable) -> RefCounted
func to_dictionary() -> Dictionary
```

### FlashBattleStateContainer.gd

源文件：templates/runtime/scripts/FlashBattleStateContainer.gd。

公开字段：`statuses`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func create_status(name: String,category: String,duration: Variant,effects: Dictionary={}) -> Dictionary
func add(status: Dictionary) -> void
func stat_rate(key: String) -> float
func stat_plus(key: String) -> float
func resolve_action_end(owner: Dictionary) -> Array
func tick_action_window() -> void
```

### FlashEnemyState.gd

源文件：templates/runtime/scripts/FlashEnemyState.gd。

公开字段：`custom`、`entry`、`definition`、`attributes`、`battle`、`map_id`、`event_id`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(owner: RefCounted,floor_entry: Dictionary,fields: Dictionary,map: int,event: int) -> void
static func handles(name: String) -> bool
func base_parameter(key: String) -> Variant
func get_parameter(key: String,states: Array=[]) -> int
func get_resist() -> Array
func clamp_battle() -> void
func input() -> Dictionary
func invoke(name: String,args: Array) -> Variant
static func validate(entry: Dictionary,lookup: Callable) -> String
```

### FlashUtils.gd

源文件：templates/runtime/scripts/FlashUtils.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func invoke(custom: RefCounted,name: String,args: Array) -> Variant
static func adapt_text(width: int,font_size: int,value: String,rich: bool=false) -> Array
static func get_pic(type: String,name: String,ext: String=".png") -> RefCounted
static func update_mask(mask_name: String,source: RefCounted,x: int,y: int) -> Dictionary
static func sprite_unravel(state: Object,sprite: Sprite2D,args: Array=[],initialize: Callable=Callable()) -> Dictionary
static func integer_text(value: String,base: int) -> Dictionary
```

2026-10-13：0.45普通战斗技能可编辑源码为生成工程runtime/generated/flash_skill_catalog.gd；Registry/Cache注册跨普通事务保留，RuntimeData提供脱离原数据的Skills内存视图。新注册角色与读档Flash角色的数据库lookup重绑RuntimeState.custom_record，不能保留临时草稿Callable。公开use_item、Flash装备、角色/楼层选择与商店业务接入原玩法事务；native工程行为保持。文档按161个生产脚本/1020个公开方法检查。

编码专项/正式迁移测试可用临时ProjectSettings设置rgmigrator/codec_temp_directory，将CP解码表留在工作区.godot/codec；普通迁移仍使用原用户数据目录。

### FlashFloor.gd

源文件：templates/runtime/scripts/FlashFloor.gd。

公开字段：`region`、`floor_number`、`map_id`、`links`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(custom: RefCounted,area: int,floor_id: int) -> void
func load_links() -> void
func signature() -> Array
func transloc() -> Variant
```

### FlashMapBlock.gd

源文件：templates/runtime/scripts/FlashMapBlock.gd。

公开字段：`id`、`x`、`y`、`width`、`height`、`tile_width`、`tile_height`、`area`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(map_id: int,tiles_x: int=20,tiles_y: int=15,region: int=0) -> void
func bind(system: RefCounted) -> void
func record() -> Dictionary
func position() -> Array
func set_position(pos: Array) -> void
func cell_at(px: int,py: int) -> Array
func center() -> Array
func distance_key(px: float,py: float) -> Array
```

### FlashMapConfig.gd

源文件：templates/runtime/scripts/FlashMapConfig.gd。

公开字段：`AREAS`、`MAPS`、`DIRECTIONS`。

常量（不含依赖脚本引用）：`CELL_WIDTH`、`CELL_HEIGHT`、`CELL_SIZE`、`CURSOR_SPEED`、`LOCK_FRAMES`、`PREVIEW_WIDTH`、`PREVIEW_HEIGHT`。

```gdscript
extends RefCounted
static func map_info(id: int) -> Dictionary
static func map_name(id: int) -> String
static func area_for(id: int) -> int
static func area_name(id: int) -> String
static func area_color(id: int) -> Color
static func cell_count(size: int,step: int) -> int
static func departure_override(a: int,b: int) -> Variant
```

### FlashMapCursor.gd

源文件：templates/runtime/scripts/FlashMapCursor.gd。

公开字段：`system`、`x`、`y`、`area`、`selected`、`locked`、`idle`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(owner: RefCounted,value: RefCounted) -> void
func select(value: RefCounted) -> void
func rect() -> Rect2
func update(dx: int,dy: int) -> String
func change_area(step: int) -> void
```

### FlashMapPreview.gd

源文件：templates/runtime/scripts/FlashMapPreview.gd。

公开字段：`images`、`order`、`id`、`frame`、`texture`、`error`、`source_kind`。

常量（不含依赖脚本引用）：`TILE_SIZE`、`HOLD_FRAMES`、`PIXELS_PER_FRAME`。

```gdscript
extends RefCounted
func show_map(map_id: int) -> void
func advance() -> Vector2
static func offset(tick: int,max_x: float,max_y: float) -> Vector2
static func ping_pong(tick: int,distance: float) -> float
static func render(map_id: int) -> Dictionary
static func table_value(table: Dictionary,x: int,y: int,z: int) -> int
static func tile_image(id: int,layout: RefCounted,tileset: Dictionary) -> Image
```

### FlashMapScreen.gd

源文件：templates/runtime/scripts/FlashMapScreen.gd。

公开字段：`page`、`world`、`cursor`、`preview`、`camera`、`preview_offset`、`ticks`、`canvas`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal close_requested
func center_camera() -> void
func follow_cursor() -> bool
func refresh() -> void
func handle_key(key: int) -> void
func point(x: float,y: float) -> Vector2
func draw_world(target: Control) -> void
```

### FlashMapSystem.gd

源文件：templates/runtime/scripts/FlashMapSystem.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(custom: RefCounted) -> void
func ensure_state() -> void
static func empty_state() -> Dictionary
func state() -> Dictionary
func block(id: int) -> RefCounted
func blocks() -> Dictionary
func connections() -> Array
func layout_notes() -> Array
func area_for(id: int) -> int
func areas() -> Dictionary
func area_unlock(id: int) -> bool
func maps_in_area(id: int) -> Array
func discover_current() -> RefCounted
func discover_map(id: int,tiles_x: int,tiles_y: int,pos: Variant=null) -> RefCounted
func free_position(area: int) -> Array
func occupied(value: RefCounted,pos: Array) -> bool
func capture_location() -> Dictionary
func departure_side(from: Dictionary,to: Dictionary) -> int
func adjacent_position(source: RefCounted,target: RefCounted,from: Dictionary,to: Dictionary,side: int) -> Variant
func record_transfer(from: Dictionary,to: Dictionary) -> RefCounted
func connected(a: int,b: int) -> bool
func nearest_map(area: int,px: float,py: float) -> RefCounted
func bridge(link: Dictionary) -> Variant
func links_for(id: int) -> Array
func invoke(ref: Dictionary,name: String,args: Array) -> Variant
static func validate(value: Variant) -> String
```

### FlashRegion.gd

源文件：templates/runtime/scripts/FlashRegion.gd。

公开字段：`region`、`floors`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(custom: RefCounted,area: Variant) -> void
func load_floors() -> void
func generate_structure() -> void
func set_region(area: Variant) -> void
```

### FlashTilemap.gd

源文件：templates/runtime/scripts/FlashTilemap.gd。

公开字段：无。

常量（不含依赖脚本引用）：`ANIMATION_SECONDS`、`AUTO_XY`。

```gdscript
extends RefCounted
static func parts(variant: int) -> Array
```

### FlashBlasticPage.gd

源文件：templates/runtime/scripts/FlashBlasticPage.gd。

公开字段：`page`、`blastic_id`、`slot`、`choosing`、`candidates`、`candidate_index`、`notice`、`value`、`preview_elements`、`preview_rows`、`crystal_description`、`echo_rows`。

常量（不含依赖脚本引用）：`CRYSTAL_NAME`。

```gdscript
extends Control
signal back_requested
func refresh() -> void
func commit_choice() -> Dictionary
func handle_key(key: int) -> void
func candidate_allowed(id: int) -> bool
```

### FlashConfigPage.gd

源文件：templates/runtime/scripts/FlashConfigPage.gd。

公开字段：`page`、`sheet`、`index`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal back_requested
func refresh() -> void
func adjust(direction: int) -> void
func handle_key(key: int) -> void
```

### FlashItemPage.gd

源文件：templates/runtime/scripts/FlashItemPage.gd。

公开字段：`page`、`stage`、`categories`、`category_index`、`item_ids`、`index`、`target_index`、`slot`、`active_item`、`notice`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal back_requested
signal common_event_requested
func selected_id() -> int
func refresh() -> void
func activate() -> void
func assign_preset() -> void
func handle_key(key: int) -> void
```

### FlashItemPresets.gd

源文件：templates/runtime/scripts/FlashItemPresets.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func variable_id(state: Object) -> int
static func slots(state: Object) -> Array
static func normalize(state: Object) -> Dictionary
static func set_slot(state: Object,slot: int,item_id: int) -> Dictionary
static func native_item(id: int,state: Object) -> Dictionary
static func category(item: Dictionary) -> String
```

### FlashMapHUD.gd

源文件：templates/runtime/scripts/FlashMapHUD.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends "res://runtime/scripts/FlashPlayerHUD.gd"
# 本类未声明自定义公共方法。
```

### FlashMapShortcuts.gd

源文件：templates/runtime/scripts/FlashMapShortcuts.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func use_slot(state: Object,slot: int) -> Dictionary
static func load_group(state: Object,slot: int,side: String) -> Dictionary
static func switch_roles(state: Object,key: int) -> Dictionary
```

### FlashMenuScreen.gd

源文件：templates/runtime/scripts/FlashMenuScreen.gd。

公开字段：`page`、`index`、`save_callback`、`child`、`active_command`。

常量（不含依赖脚本引用）：`COMMANDS`、`DEFAULT_LOCKS`。

```gdscript
extends Control
signal close_requested
signal title_requested
signal sound_requested(key: String)
signal load_requested(slot: int)
func enabled(command: int) -> bool
func refresh() -> void
func activate() -> void
func back() -> void
func handle_key(key: int) -> void
```

### FlashNotePage.gd

源文件：templates/runtime/scripts/FlashNotePage.gd。

公开字段：`page`、`category`、`index`、`selecting`、`entries`、`description`。

常量（不含依赖脚本引用）：`CATEGORIES`。

```gdscript
extends Control
signal back_requested
func enabled(id: int) -> bool
func refresh() -> void
func handle_key(key: int) -> void
```

### FlashPreferences.gd

源文件：templates/runtime/scripts/FlashPreferences.gd。

公开字段：`vars`、`music_lock`、`apply_display`、`directory_override`、`storage_error`、`bgm_volume`、`se_volume`、`run_mode`、`window_resize`。

常量（不含依赖脚本引用）：`MUSIC_BUS`、`EFFECT_BUS`。

```gdscript
extends RefCounted
signal changed
func _init(owner: Node) -> void
func set_volume(kind: String,value: int) -> bool
func next_run_mode() -> void
func change_window_size(direction: int) -> int
func apply_audio() -> void
func apply_window() -> void
func unlock_music(name: String) -> void
func storage_path() -> String
func save_preferences() -> Dictionary
func load_preferences() -> Dictionary
static func validate(value: Variant) -> String
```

### FlashSkillConfig.gd

源文件：templates/runtime/scripts/FlashSkillConfig.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func category(skill: Dictionary) -> int
static func available(custom: RefCounted,actor: RefCounted,skill_id: int) -> bool
static func set_skill(state: Object,actor_id: int,skill_id: int,input: int=0) -> Dictionary
static func switch_page_actor(state: Object) -> Dictionary
```

### FlashSkillPage.gd

源文件：templates/runtime/scripts/FlashSkillPage.gd。

公开字段：`page`、`skill_ids`、`index`、`easy`、`notice`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal back_requested
func actor() -> RefCounted
func refresh() -> void
func selected_id() -> int
func handle_key(key: int) -> void
```

### FlashTitleExtrasPage.gd

源文件：templates/runtime/scripts/FlashTitleExtrasPage.gd。

公开字段：`kind`、`index`、`book`、`progress`、`old_index`、`angle`、`playing`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal back_requested
func refresh() -> void
func handle_key(key: int) -> void
```

### FlashTitleScreen.gd

源文件：templates/runtime/scripts/FlashTitleScreen.gd。

公开字段：`index`、`difficulty`、`page`、`child`、`frame`、`logo_progress`。

常量（不含依赖脚本引用）：`COMMANDS`。

```gdscript
extends Control
signal new_game_requested(difficulty: int)
signal load_requested(slot: int)
func refresh() -> void
func activate() -> void
func back() -> void
func handle_key(key: int) -> void
```

### FlashMessageBoxState.gd

源文件：templates/runtime/scripts/FlashMessageBoxState.gd。

公开字段：`tokens`、`metadata`、`cursor`、`state`、`process`、`speed`、`waiting`、`auto_terminate`、`interpreter_waiting`、`move_time`、`movement`、`offset`、`back_opacity`、`style`、`painted`、`effects`、`pageon`、`page_scroll`、`page_targets`、`failure`、`hint`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(raw: String,owner: Object,is_hint: bool=false) -> void
func mode() -> int
func extend_enabled() -> bool
func finished() -> bool
func opacity() -> float
func zoom() -> float
func frame_opacity() -> float
func confirm() -> void
func tick() -> void
func plain_text() -> String
```

### FlashMessageText.gd

源文件：templates/runtime/scripts/FlashMessageText.gd。

公开字段：无。

常量（不含依赖脚本引用）：`CODES`、`ARGUMENTS`、`BOX_CODES`。

```gdscript
extends RefCounted
static func defaults() -> Dictionary
static func color(id: int) -> Color
static func frame_duration(value: int,frame_rate: int=60) -> int
static func parse(raw: String,state: Object,box_setup: bool=true) -> Dictionary
static func expand(raw: String,state: Object) -> Dictionary
static func font(style: Dictionary) -> SystemFont
static func apply_style(style: Dictionary,token: Array) -> void
```

### FlashTextRow.gd

源文件：templates/runtime/scripts/FlashTextRow.gd。

公开字段：`text`、`halign`、`valign`、`text_width`、`text_height`、`line_space`、`tokens`、`cursor`、`failure`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(raw: String,state: Object) -> void
func getchar() -> Variant
func peer() -> Variant
func shift(amount: int=1) -> int
func goto_head() -> void
func goto_tail() -> void
func eof() -> bool
func snapshot() -> Dictionary
static func invoke(custom: RefCounted,ref: Dictionary,name: String,args: Array) -> Variant
```

### FlashMessageController.gd

源文件：templates/runtime/scripts/FlashMessageController.gd。

公开字段：`boxes`、`viewport_size`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
signal responded(request_id: int,kind: String,value: Variant)
signal rejected(request_id: int,message: String)
signal changed
func _init(owner: Object) -> void
func present(payload: Dictionary,request_id: int=-1,event_id: int=0,hint: bool=false,consume_field: String="") -> Dictionary
func advance(delta: float) -> void
func tick() -> void
func confirm() -> bool
func handle_key(key: int) -> bool
func message_window_showing() -> bool
func interpreter_waiting(event_id: int,blocking: bool) -> bool
func cancel_request(request_id: int) -> void
func reset() -> void
func history(hint: bool=false) -> Array
```

### FlashMessageLayout.gd

源文件：templates/runtime/scripts/FlashMessageLayout.gd。

公开字段：`positions`、`rows`、`box_size`、`text_origin`、`text_size`、`name_text`、`face_name`、`face_index`、`anchor_event`、`fixed_anchor`、`failure`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(model: RefCounted,owner: Object,viewport_size: Vector2) -> void
func anchor(owner: Object) -> Vector2
func rectangle(owner: Object,viewport_size: Vector2,model: RefCounted) -> Rect2
```

### FlashMessageMemoryPage.gd

源文件：templates/runtime/scripts/FlashMessageMemoryPage.gd。

公开字段：`page`、`mode_index`、`index`、`records`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal close_requested
func check_text() -> void
func refresh() -> void
func plain_text(raw: String) -> String
func handle_key(key: int) -> void
```

### FlashMessageOverlay.gd

源文件：templates/runtime/scripts/FlashMessageOverlay.gd。

公开字段：`controller`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
# 本类未声明自定义公共方法。
```

### FlashMessageView.gd

源文件：templates/runtime/scripts/FlashMessageView.gd。

公开字段：`entry`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
func refresh(owner: Object,viewport_size: Vector2) -> void
```

### FlashTextStream.gd

源文件：templates/runtime/scripts/FlashTextStream.gd。

公开字段：`file_name`、`line_label`、`is_open`、`lines`、`cursor`、`failure`。

常量（不含依赖脚本引用）：`END_TEXT`。

```gdscript
extends RefCounted
func open(name: String,label: String="",reload: bool=false) -> bool
func close() -> void
func get_text(length: int=4) -> String
```

### FlashSightModel.gd

源文件：templates/runtime/scripts/FlashSightModel.gd。

公开字段：`cursor`、`focus`、`stage`、`list_index`、`skill_index`、`focused_ids`、`groups`、`description_visible`、`failure`。

常量（不含依赖脚本引用）：`FOCUS_NAMES`、`ITEM_NAMES`。

```gdscript
extends RefCounted
func _init(owner: Object,map: Node) -> void
func reset_free() -> void
func events() -> Array
func event_at_cursor() -> Dictionary
func enemy_groups() -> Array
func item_groups() -> Array
func set_focus(value: int) -> void
func update_group() -> void
func select_group() -> bool
func move_cursor(direction: Vector2i,viewport_size: Vector2) -> void
func view_bounds(viewport_size: Vector2) -> Rect2i
func enemy_snapshot() -> Dictionary
func skill_presentation(action: Dictionary,skill_set: Dictionary) -> Dictionary
func description() -> String
```

### FlashSightPage.gd

源文件：templates/runtime/scripts/FlashSightPage.gd。

公开字段：`page`、`game`、`model`、`snapshot`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal close_requested
func refresh() -> void
func handle_key(key: int) -> void
func draw_marks(target: Node2D) -> void
static func hp_opacities(frame: int) -> Array
```

### FlashActionOrder.gd

源文件：templates/runtime/scripts/FlashActionOrder.gd。

公开字段：`rows`、`sprites`。

常量（不含依赖脚本引用）：无。

```gdscript
extends ScrollContainer
# 本类未声明自定义公共方法。
```

### FlashMessageWords.gd

源文件：templates/runtime/scripts/FlashMessageWords.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func item_fails(item_id: int,parameter: int,custom: RefCounted) -> Variant
```

### FlashArchiveData.gd

源文件：templates/runtime/scripts/FlashArchiveData.gd。

公开字段：无。

常量（不含依赖脚本引用）：`CHAPTER_NAMES`、`MAX_PNG_BYTES`。

```gdscript
extends RefCounted
static func from_state(state: Node) -> Dictionary
static func actor_row(actor: RefCounted) -> Dictionary
static func validate(value: Variant) -> String
static func preview(value: Dictionary) -> Image
```

### FlashArchivePage.gd

源文件：templates/runtime/scripts/FlashArchivePage.gd。

公开字段：`page`、`allow_mode_switch`、`window_process`、`preview_process`、`preview_id`。

常量（不含依赖脚本引用）：无。

```gdscript
extends "SaveSlots.gd"
func refresh(reload_catalog: bool=true) -> void
func navigate(direction: int) -> void
func activate() -> void
func execute() -> void
func handle_key(key: int) -> void
```

### FlashBitmap.gd

源文件：templates/runtime/scripts/FlashBitmap.gd。

公开字段：`image`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(width: int=1,height: int=1) -> void
func clear() -> void
func fill_rect(rect: Rect2i,color: Color) -> void
func set_pixel(x: int,y: int,color: Color) -> void
func texture() -> ImageTexture
func clear_rect(rect: Rect2i) -> void
func get_pixel(x: int,y: int) -> Color
func copy() -> RefCounted
func invert() -> void
func hue_change(degrees: float) -> void
func change_tone(red: int,green: int,blue: int,_simplify: int=1) -> void
func clip_mask(mask: Image,x: int=0,y: int=0,outer: int=0) -> void
func mosaic(width: int=5,height: int=5) -> void
func mosaic_rect(rect: Rect2i,width: int=5,height: int=5) -> void
func blend_blt(x: int,y: int,source: Image,rect: Rect2i,blend_type: int=0,opacity: int=255) -> void
func blur2(radius: int=1) -> void
func get_pixel_data() -> PackedByteArray
func set_pixel_data(value: PackedByteArray) -> Dictionary
func png_save(path: String,_level: int=9,_filter: int=0) -> Dictionary
func draw_rhombus(points: Array,colors: Array) -> void
func fill_ellipse(center: Vector2i,width: int,height: int,color: Color) -> void
func draw_ellipse_border(center: Vector2i,radius: int,type: int,color: Color) -> void
func draw_rounded_border(center: Rect2i,radius: int,color: Color) -> void
func fill_rounded_rect(rect: Rect2i,radius: int,color: Color) -> void
func gradient(rect: Rect2i,first: Color,last: Color,vertical: bool=false) -> void
func gradation_rect(rect: Rect2i,first: Color,last: Color,align: int=0) -> void
func gradate_line(rect: Rect2i,colors: Array,indent: Vector2i=Vector2i.ZERO,vertical: bool=false) -> void
func gradate_rect(rect: Rect2i,colors: Array) -> void
func draw_line(first: int,second: int,third: int,fourth: int,coordinate: int,type: int=0,opacity: int=255) -> void
func draw_line2(first: Vector2i,last: Vector2i,width: int,colors: Array) -> void
func draw_h8_panel_fill(rect: Rect2i) -> void
func draw_h8_background(rect: Rect2i,opacity: int=160,margin: int=16) -> void
func draw_h8_outer_frame(rect: Rect2i,opacity: int=132) -> void
func draw_h8_corner_light(point: Vector2i,direction: Vector2i,opacity: int=132) -> void
func draw_h8_inner_line(first: Vector2i,last: Vector2i,type: int=0,opacity: int=132,width: int=1) -> void
func draw_h8_bulge(first: Vector2i,last: Vector2i,plus: bool,height: int,type: int) -> void
static func skill_frame_colors(type: int) -> Array
func draw_skill_frame(rect: Rect2i,type: int=1,show_turn_box: bool=false,corners: bool=true) -> void
func draw_turn_box(rect: Rect2i,colors: Array) -> void
func draw_item_frame(rect: Rect2i,corners: bool=true) -> void
func draw_hud_back(rect: Rect2i,type: int=0) -> void
func draw_hud_line(rect: Rect2i,value: int,maximum: int,first: Color,last: Color,type: int=0) -> void
func draw_trapezoid_meter(rect: Rect2i,value: int,maximum: int,first: Color,last: Color) -> void
static func panel_style(size: Vector2i,margin: int=16) -> StyleBoxTexture
static func skill_style(size: Vector2i,type: int=1,corners: bool=true) -> StyleBoxTexture
```

### FlashBrokenScreen.gd

源文件：templates/runtime/scripts/FlashBrokenScreen.gd。

公开字段：`shards`、`ticks`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func configure(source: Image,mask: Image,seed_value: int=-1) -> Dictionary
func advance_tick() -> void
func dispose() -> void
```

### FlashCastingPage.gd

源文件：templates/runtime/scripts/FlashCastingPage.gd。

公开字段：`page`。

常量（不含依赖脚本引用）：无。

```gdscript
extends "SkillScene.gd"
func handle_key(key: int) -> void
```

### FlashColor.gd

源文件：templates/runtime/scripts/FlashColor.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func rgba(color: Color) -> Array
static func rgb(color: Color) -> Array
static func add(first: Color,second: Variant) -> Color
static func subtract(first: Color,second: Variant) -> Color
static func multiply(color: Color,value: Variant) -> Color
static func divide(color: Color,value: Variant) -> Variant
```

### FlashDebugPage.gd

源文件：templates/runtime/scripts/FlashDebugPage.gd。

公开字段：`page`、`group`、`index`、`editing`、`groups`、`message`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func change(amount: int) -> Dictionary
func back() -> void
func handle_key(key: int) -> void
```

### FlashEffectView.gd

源文件：templates/runtime/scripts/FlashEffectView.gd。

公开字段：`model`、`game`。

常量（不含依赖脚本引用）：无。

```gdscript
extends CanvasLayer
func apply_map_visible(value: bool) -> void
func target_sprite(kind: String,id: int) -> Sprite2D
func sync() -> void
func draw_effects(canvas: Node2D,top: bool) -> void
func draw_particles(canvas: Node2D,blend: int=0) -> void
func draw_glitch(canvas: Node2D) -> void
```

### FlashEnemyMapLabels.gd

源文件：templates/runtime/scripts/FlashEnemyMapLabels.gd。

公开字段：`game`、`entries`、`rebuild_count`。

常量（不含依赖脚本引用）：`COLORS`。

```gdscript
extends CanvasLayer
func request_refresh() -> void
func rebuild() -> void
static func damage_grade(damage: int,hp: int) -> int
func draw_labels(target: Control) -> void
```

### FlashEquipmentPage.gd

源文件：templates/runtime/scripts/FlashEquipmentPage.gd。

公开字段：`page`、`actor_id`、`slot`、`index`、`choosing`、`candidates`、`preview`、`message`。

常量（不含依赖脚本引用）：`SLOT_NAMES`、`DATABASES`。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func candidate_rows() -> Array
func preview_equipment(id: int) -> Dictionary
func refresh() -> void
func activate() -> Dictionary
func back() -> void
func handle_key(key: int) -> void
```

### FlashFollowers.gd

源文件：templates/runtime/scripts/FlashFollowers.gd。

公开字段：`motions`、`graphics`、`move_list`、`transparent_actors`。

常量（不含依赖脚本引用）：`MAX_PARTY`、`CAT_GRAPHIC`、`DIAGONALS`。

```gdscript
extends RefCounted
func _init(owner: Node) -> void
func reset() -> void
func bind(player: Node,map: Node) -> void
func refresh() -> void
func advance(delta: float) -> void
func accept_action(type: int,args: Array=[]) -> void
func moveto_party_actors(x: int,y: int) -> void
func delete_move() -> void
func set_transparent_actors(value: bool) -> void
func get_characters_xy(index: int) -> Array
func set_characters(index: int,direction: int) -> void
func set_characters_xy(index: int,x: int,y: int) -> void
func snapshot() -> Dictionary
static func validate_snapshot(value: Variant) -> String
func restore_snapshot(value: Dictionary) -> void
```

### FlashHelpMessage.gd

源文件：templates/runtime/scripts/FlashHelpMessage.gd。

公开字段：`rect`、`shadows`、`text`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(x: int=0,y: int=0,width: int=0,height: int=0,canvas: Vector2i=Vector2i(640,640)) -> void
func make_shadow(canvas: Vector2i=Vector2i(640,640)) -> void
func set_text(_type: Variant) -> void
func update() -> void
func dispose() -> void
```

### FlashKeyboard.gd

源文件：templates/runtime/scripts/FlashKeyboard.gd。

公开字段：`held`、`repeats`、`key`、`input_provider`。

常量（不含依赖脚本引用）：`SOURCE_KEYS`。

```gdscript
extends RefCounted
func reset() -> void
static func godot_key(vk: int) -> int
func pressed(vk: int) -> bool
func snapshot() -> Dictionary
func install(value: Dictionary) -> void
static func invoke(custom: RefCounted,name: String,args: Array) -> Variant
```

### FlashPalette.gd

源文件：templates/runtime/scripts/FlashPalette.gd。

公开字段：无。

常量（不含依赖脚本引用）：`COLORS`、`GRADIENTS`。

```gdscript
extends RefCounted
static func color(index: int) -> Color
static func color_type(type: int,opacity: int=255) -> Array
```

### FlashPlayerHUD.gd

源文件：templates/runtime/scripts/FlashPlayerHUD.gd。

公开字段：`canvas`、`slots`、`rows`、`layout_flipped`、`window_process`、`itembar_process`、`mapname_frame`、`mapname`。

常量（不含依赖脚本引用）：无。

```gdscript
extends CanvasLayer
func reset() -> void
func map_changed(_id: int) -> void
func visible_target() -> bool
func refresh_rows() -> void
func draw_hud(target: Control) -> void
```

### FlashSceneBackdrop.gd

源文件：templates/runtime/scripts/FlashSceneBackdrop.gd。

公开字段：`entering`、`blur_process`。

常量（不含依赖脚本引用）：无。

```gdscript
extends TextureRect
# 本类未声明自定义公共方法。
```

### FlashSceneRegistry.gd

源文件：templates/runtime/scripts/FlashSceneRegistry.gd。

公开字段：无。

常量（不含依赖脚本引用）：`SCENES`。

```gdscript
extends RefCounted
static func validate(name: String,args: Array,state: Object) -> String
static func create(name: String,args: Array,state: Object) -> Control
static func construct(custom: RefCounted,name: String,args: Array) -> Variant
static func stage(custom: RefCounted,value: Dictionary) -> Variant
```

### FlashScreenEffects.gd

源文件：templates/runtime/scripts/FlashScreenEffects.gd。

公开字段：`active`、`results`、`test_capture`、`map_visible`、`rect_amount`、`filter_enabled`、`frozen`、`blurred`、`blur_radius`、`voice_visible`、`voice_process`、`voice_alpha`、`voice_zoom`、`voice`、`transient`、`particle_sets`、`broken`。

常量（不含依赖脚本引用）：`RECT_STEPS`。

```gdscript
extends RefCounted
func _init(owner: Object) -> void
func bind(view: Node) -> void
func reset() -> void
func reserve_id() -> int
func busy() -> bool
func transient_save_reason() -> String
func restore_sprite(target: Sprite2D) -> void
func status(id: int) -> Dictionary
func cancel(id: int) -> void
func appear(value: bool) -> void
static func stage(custom: RefCounted,name: String,args: Array) -> Variant
func validate(requests: Array) -> String
static func parameter_reason(name: String,args: Array) -> String
static func particle_reason(args: Array) -> String
func install(requests: Array) -> void
func advance(delta: float) -> void
func unravel_sprite(target: Sprite2D,args: Array=[],initialize: Callable=Callable()) -> Dictionary
```

### FlashSelectionPage.gd

源文件：templates/runtime/scripts/FlashSelectionPage.gd。

公开字段：`page`、`kind`、`index`、`entries`、`message`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func read_entries() -> void
func refresh() -> void
func activate() -> void
func back() -> void
func handle_key(key: int) -> void
```

### FlashShape.gd

源文件：templates/runtime/scripts/FlashShape.gd。

公开字段：`origin`、`rects`、`radius`、`phase`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func _init(x: int=0,y: int=0,rectangles: Array=[]) -> void
func set_origin(point: Vector2i) -> void
func includes(point: Vector2i) -> bool
func each_pixel(callback: Callable) -> void
func each_rect(callback: Callable) -> void
func fill(bitmap: RefCounted,color: Color) -> void
func set_hexagon(value: int,phase_value: float=0) -> void
func twist(angle: float) -> void
```

### FlashTextDrawing.gd

源文件：templates/runtime/scripts/FlashTextDrawing.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func draw_text(target: CanvasItem,rect: Rect2,value: String,style: Dictionary,align: int=0,shadow: bool=false) -> void
static func draw_text_border(target: CanvasItem,rect: Rect2,value: String,style: Dictionary,align: int=0) -> void
static func draw_delete_line_text(target: CanvasItem,rect: Rect2,value: String,style: Dictionary,align: int=0,shadow: bool=false) -> void
static func draw_rich_text(target: CanvasItem,rect: Rect2,raw: String,owner: Object,align: int=0,memory: bool=false) -> Dictionary
```

### FlashTopic.gd

源文件：templates/runtime/scripts/FlashTopic.gd。

公开字段：`title_id`、`text`、`fade`、`window_process`、`base_position`。

常量（不含依赖脚本引用）：无。

```gdscript
extends Panel
func set_title(id: int) -> void
func refresh() -> void
```

### FlashUnravel.gd

源文件：templates/runtime/scripts/FlashUnravel.gd。

公开字段：`speed`、`opaque_only`、`opaque_threshold`、`particles`、`image`、`moving`、`disposed`、`move_effect`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func make_speed(x: int=100,y: int=100,opacity: int=550) -> void
static func make_otake(value: bool=true) -> void
static func make_otake_value(value: int=1) -> void
func configure(source: Image,origin: Vector2,region: Rect2i,n: int=0,d: int=4,co: float=0.5,type: String="RU",shape: String="C",clear_source: bool=true,seed_value: int=-1,initialize: Callable=Callable()) -> Dictionary
func advance_ticks(count: int=1,area: Vector2=Vector2(640,640)) -> void
func all_move(x: float,y: float) -> void
func stop() -> void
func begin() -> void
func move_effe(callback: Callable) -> void
func move_type(type: String) -> Dictionary
func auto_dispose(part: Dictionary,_index: int=0,area: Vector2=Vector2(640,640)) -> void
func get_all_sprite() -> Array
func get_viewport() -> Variant
func dispose() -> void
```

## 0.46 闪翼接入约束（历史阶段）

RuntimeState持有flash_messages/flash_effects/flash_followers/flash_keyboard。页面、角色、敌人和预测使用同一份状态。FlashCharacterBridge的speed_change/人物参数、屏幕请求、场景请求与键盘重复计数须先草稿后提交。一个脚本片段同时申请场景与屏幕演出会明确拒绝，应拆成相邻指令。EventInterpreter/CharacterRoute按请求ID等待，退出/重开清除旧回调。屏幕演出、跟随、消息模型各只有一个60Hz时钟。

FlashScreenEffects.transient_save_reason拒绝尚无法复原的活动画面关系；完整活动消息/冻结/消散/跟随及设置跨启动持久化属于0.47。FlashArchiveData只读取正式状态，截图进入Godot校验存档且限制PNG尺寸/长度。SaveService闪翼最多4096位，其他工程原契约不变；本轮只做闪翼回归和导出。缺失原音效/碎屏蒙版明确拒绝，不把内存测试资源写入正式工程。源码文件映射见docs/FLASH_UI_GDSCRIPT_v0.46.md。

## 0.47 闪翼持久化与工具约束

SaveGraph将Array/Dictionary编码为带引用编号的JSON节点，保留循环、共享对象、精确整数与类型化键；不序列化Node、Callable或原生地址。普通数据和自定义类仍由SaveCodec整体校验，生成方法必须指向原有生成文件且SHA匹配。RuntimeState安装已验证的同一份图，装备包装对象的实例字段、缓存及变量别名保持身份；原数据库和纹理仍只读。

FlashPresentationState序列化拥有的PNG图像与消息/演出/粒子/跟随进度，人物和图片显示关系按地图事件ID或图片编号重绑。截图采集中的瞬时状态、尚未返回的独立页面、视频播放和传送仍有明确保存门禁；未登记的粒子动态回调会拒绝保存。恢复后的界面请求与wait token重新创建；旧回调无效，消息历史不得重新记录。预算为SaveGraph的MAX_NODES/MAX_EDGES/MAX_DEPTH、SaveService的MAX_BYTES和表现PNG的2048边长上限，不应静默裁切。

FlashPreferences在工程隔离的user://rgmigrator_preferences目录保存跨启动数据，不参与读档/撤回。FlashHistory保留原变量25和100条循环历史，事件前成功写入后再递增；只有原玩家触发的门/怪物条件自动记录，事件移动触发不额外记录。BackSpace恢复经过同一SaveCodec校验的进度；自动记录不读取RM AutoSave文件。

FlashMapSnapshot的M/U/T/A、缩放和PNG导出独立于活动地图；输出到user://MapSnapshots。FlashMoviePlayer使用Godot视频资源与非阻塞等待/跳过，原工程没有视频素材或事件调用，不能将缺失分支声称已实际播放验证。Win32/DLL地址由用途服务替代，原缺失音效/蒙版/副手和空方法保持明确边界。继续只做闪翼回归和全新正式原RM导出，不执行Ruby或二律回归，不修改原公式。

### FlashFileStore.gd

源文件：templates/runtime/scripts/FlashFileStore.gd。

公开字段：无。

常量（不含依赖脚本引用）：`MAX_BYTES`。

```gdscript
extends RefCounted
static func write(path: String,kind: String,value: Variant) -> Dictionary
static func read(path: String,kind: String,validator: Callable=Callable()) -> Dictionary
```

### FlashHistory.gd

源文件：templates/runtime/scripts/FlashHistory.gd。

公开字段：无。

常量（不含依赖脚本引用）：`CAPACITY`、`PREPARATION_BUDGET_USEC`。

```gdscript
extends RefCounted
signal checkpoint_prepared(request_id: int,result: Dictionary)
func _init(owner: Node) -> void
func eligible(name: String) -> bool
func path_for(serial: int) -> String
func record(force: bool=false) -> Dictionary
func record_async(force: bool=false) -> Dictionary
func prepare_record(request_id: int) -> void
func poll() -> void
func flush_pending() -> void
func reset() -> void
func cancel_preparation() -> void
func undo() -> Dictionary
```

### FlashMapSnapshot.gd

源文件：templates/runtime/scripts/FlashMapSnapshot.gd。

公开字段：`scale`、`mode`、`output_directory`。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func set_scale(value: int) -> bool
func set_mode(value: String) -> bool
func render(map_id: int) -> Dictionary
func snap(map_id: int) -> Dictionary
func snaps(ids: Array) -> Dictionary
func snap_all() -> Dictionary
```

### FlashMoviePlayer.gd

源文件：templates/runtime/scripts/FlashMoviePlayer.gd。

公开字段：`player`、`skippable`、`request_id`。

常量（不含依赖脚本引用）：无。

```gdscript
extends CanvasLayer
signal completed(request_id: int)
func resolve_path(filename: String) -> String
func play(filename: String,wait: bool=true,allow_skip: bool=true,x: int=0,y: int=0,width: int=640,height: int=640) -> Dictionary
func stop() -> void
func pause() -> bool
func resume() -> bool
func resize(x: int=0,y: int=0,width: int=640,height: int=640) -> bool
func playing() -> bool
func status(id: int) -> Dictionary
```

### FlashPresentationState.gd

源文件：templates/runtime/scripts/FlashPresentationState.gd。

公开字段：无。

常量（不含依赖脚本引用）：`EFFECT_FIELDS`、`BOX_FIELDS`、`LAYOUT_FIELDS`、`ENTRY_FIELDS`、`EFFECT_NAMES`。

```gdscript
extends RefCounted
static func capture(state: Node) -> Dictionary
static func prepare(value: Variant) -> Dictionary
static func restore(state: Node,row: Dictionary,game: Node,request_ids: Dictionary={}) -> void
```

### SaveGraph.gd

源文件：templates/runtime/scripts/SaveGraph.gd。

公开字段：无。

常量（不含依赖脚本引用）：`FORMAT`、`MAX_NODES`、`MAX_EDGES`、`MAX_DEPTH`。

```gdscript
extends RefCounted
static func encode(value: Variant) -> Dictionary
static func reason(value: Variant,classes: Variant=null) -> String
static func reason_cooperatively(value: Variant,pulse: Callable,classes: Variant=null) -> String
static func clone(value: Variant, graph: Array=[]) -> Variant
static func clone_checked(value: Variant,graph: Array=[]) -> Dictionary
static func rebind(value: Variant,pairs: Array,seen: Array=[]) -> Variant
static func decode(value: Variant) -> Dictionary
```

### ScriptWorkspaceExporter.gd

源文件：scripts/importer/ScriptWorkspaceExporter.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func generate(root: String) -> Dictionary
```

### EditorProjectTransaction.gd

源文件：templates/editor/addons/rgm_editor/EditorProjectTransaction.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func allowed(path: String) -> bool
static func stamp(root: String, path: String) -> Dictionary
static func publish(root: String, changes: Dictionary, expected: Dictionary) -> Dictionary
```

### EditorScriptCoverage.gd

源文件：templates/editor/addons/rgm_editor/EditorScriptCoverage.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func build(root: String, registry: Dictionary, inventory: Dictionary, workspace: Dictionary) -> Dictionary
static func markdown(report: Dictionary) -> String
```

### EditorScriptDialog.gd

源文件：templates/editor/addons/rgm_editor/EditorScriptDialog.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends Window
signal published
func open(documents: RefCounted) -> void
func apply_current() -> bool
func pending_status() -> String
func reload() -> void
```

### EditorScriptWorkspace.gd

源文件：templates/editor/addons/rgm_editor/EditorScriptWorkspace.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
signal changed
func _init(documents: RefCounted) -> void
func reload() -> void
static func initial(root: String, registry: Dictionary) -> Dictionary
func entries() -> Array
func source(id: String, original: bool=false) -> String
func generated(id: String) -> String
func set_source(id: String, text: String) -> Dictionary
func rename(id: String, name: String) -> Dictionary
func add_script(name: String="新脚本") -> Dictionary
func save() -> Dictionary
func diagnostics(id: String) -> Array
func coverage() -> Dictionary
func mappings(id: String) -> Array
func recompile() -> Dictionary
static func restore_map(source_map: Dictionary) -> Dictionary
static func restore_common(source_events: Array) -> Dictionary
```

### SavePreparation.gd

源文件：templates/runtime/scripts/SavePreparation.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends "SaveCodec.gd"
static func prepare_cooperatively(value: Variant,definitions: RefCounted,owned_snapshot: bool,pulse: Callable,graph_check: Callable=Callable()) -> Dictionary
```

### ScriptQueryProof.gd

源文件：templates/runtime/scripts/ScriptQueryProof.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
static func plan(unit: Dictionary) -> Dictionary
```

### ScriptErrorLogger.gd

源文件：templates/runtime/scripts/ScriptErrorLogger.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends Logger
func _init(owner: Node) -> void
```

### FlashDamageWorker.gd

源文件：templates/runtime/scripts/FlashDamageWorker.gd。

公开字段：无。

常量（不含依赖脚本引用）：无。

```gdscript
extends RefCounted
func request(job: Dictionary) -> Error
func take() -> Dictionary
func stop() -> void
```

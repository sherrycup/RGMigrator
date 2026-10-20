# GodotMotaTemplate 与当前 0.52 迁移工程对比

核对日期：2026-10-17。

对比对象：

- 开源样板：`D:/Dev/Godot_Trans/template/GodotMotaTemplate/`。
- 当前正式迁移工程：`D:/Dev/Godot_Trans/output/0.52/final/黎之闪翼（开发中）_Godot/`。
- 维护源码：`D:/Dev/Godot_Trans/RGMigrator/` 中的迁移器、运行模板及编辑器模板。

本次依据本地实际代码、配置、示例截图和已有验收记录进行比较；没有重新启动两套编辑器逐项操作，也没有进行同条件性能测量。涉及操作便利程度和后续成本的判断属于架构分析。0.52 验收数字引用已有记录，不表示本次重跑；完整剧情通关、全地图性能和跨平台发行均不据此作结论。

## 结论

**对方的主要优势是从零制作魔塔的工作流：用 Godot 场景画地图和拼 UI、用专用事件页配置门怪道具、用积木编排剧情、用 Excel 批量配表。我们的主要优势是继续开发现有 RM 作品：保留地图与事件数据、原战斗公式、自定义脚本行为及复杂运行现场，并提供来源定位和编辑校验。**

对于当前继续迁移闪翼的目标，保留现有底座更合适。全面切换到对方样板，需要重建数据、事件、战斗、存档和自定义系统之间的对应关系。对方适合用作制作工具和界面组织的参考；对于一款接受其规则和数据结构的新魔塔，它也有作为独立起点的价值。

## 一、整体定位与开发结构

| 方面 | GodotMotaTemplate | 当前 0.52 迁移工程 | 实际影响 |
| --- | --- | --- | --- |
| 核心目标 | Godot 魔塔游戏样板，附地图制作流程与事件插件 | RMXP 数据和脚本迁移后的可运行工程，附专用魔塔编辑器 | 新建作品时对方链路较短；延续现有作品时我们保留的内容更多 |
| 系统入口 | `MotaSystem` 静态入口，连接 GameManager、地图、事件、UI、资源等管理器 | `RuntimeState` Autoload 持有正式状态，Game 及服务组合协作 | 两边都有统一入口；对象与数据结构不能直接互换 |
| 地图 | Godot `.tscn` 场景、TileMap、TileSet；事件和事件页是场景节点 | JSON 地图与 RM Table 数据；运行时 MapRuntime/MapTileRow 消费，专用编辑器绘制 | 对方便于使用 Godot 场景工具；我们便于保留原地图编号、图块属性和事件关系 |
| 数据库 | Excel 原表，经导表工具生成 `.gd` 字典 | 迁移后的 JSON 定义及自定义数据，专用数据库表单编辑 | 对方适合批量数值配置；我们适合在一个工作区编辑并保护原编号引用 |
| 事件 | 专用 EventPage 子类，加 CombinedEvent 的 JSON 动作树 | RM 命令列表、解释器与调度器，加原生 GDScript 模块 | 对方适合按玩法摆放；我们适合保留并继续编辑复杂原事件 |
| 界面 | UI 场景、Control 节点、UIManager 分层管理 | 已有功能页和状态服务，原图形表现仍按后续规划恢复 | 对方的场景制作方式值得参考；当前原 UI 还原仍是我们的实际缺口 |
| 运行脚本 | 主要直接编写业务 GDScript | 业务 GDScript、生成 GDScript 与必要的 Ruby 语义适配并存 | 对方修改其自身规则较直接；我们维持旧行为的成本较高 |

对方并非只有事件编辑器：源码中包含战斗、装备、地图、存档、UI、寻路与特效等系统。其 `mota` 插件主要增强 Godot 检查器，并通过浏览器中的 Blockly 编辑复杂事件字段。

同时，“支持 RPG MAKER 素材”应按本地实现理解为素材使用流程。检查到的运行和插件代码没有与我们对应的 `.rxdata` 读取、Ruby 解析及完整 RM 工程迁移链路。

依据：[对方使用说明](../../template/GodotMotaTemplate/README.md)、[MotaSystem](../../template/GodotMotaTemplate/Script/MotaSystem.gd)、[当前结构说明](SCRIPT_STRUCTURE_v0.51.md)。

## 二、地图与日常制作

对方的地图就是 Godot 场景。空地图已有三层 TileMap，事件放在 Events 节点下；复制地图后，需要在 Map 表登记。绘图使用 Godot 的图块与地形工具，摆事件使用场景节点复制和栅格吸附。样板默认每格 64 像素。

其好处是场景、人物、动画和 UI 资源可以沿着 Godot 的常规工作流制作，熟悉 Godot 的作者能直接操作；新增资源和演出也较容易结合场景系统。制作步骤同时涉及场景、表格、节点和插件，作者需要掌握这些基础，并注意事件吸附与地图登记。

我们默认每格 32 像素，使用专门的地图树、图块面板和画布。当前支持绘制、填充、矩形、多格笔刷、复制粘贴、撤销、新建和复制地图、多素材图块集，以及按需扩展图层。数据库通行、四方向、优先级、草丛、柜台和地形标记继续对应 RM 规则。

这套方式对原 RM 作者和既有地图更友好，也能统一检查编号引用；代价是地图编辑、自动图块、遮挡和渲染的相关能力需要我们持续维护。它与对方的 TileMap 数据不直接兼容，直接替换需要重新核对通行、优先级和自动图块语义。

依据：[对方空地图](../../template/GodotMotaTemplate/Scene/Map/EmptyMap.tscn)、[对方图格配置](../../template/GodotMotaTemplate/Script/Defination/Defination.gd)、[我们的地图制作说明](EDITOR_v0.33.md)、[多素材与图层说明](EDITOR_v0.36.md)。

## 三、事件编辑与执行

### 对方的优势：常见内容配置直接，剧情结构直观

对方提供 MonsterEvent、BarrierEvent、ConsumableEvent、ItemEvent、TeleportEvent、RegionBarrierEvent 等专用事件页。常见门、怪物、道具和楼梯，可以选择类型并设置导出参数。复杂剧情使用 CombinedEvent，在 Blockly 中组织文本、选择、条件、变量、移动和演出。

事件页本身也是 GDScript 类，可以继承 EventPage 重写 `start()`。对熟悉代码的作者，接口调用直观；对不写代码的作者，积木能减少输入语法错误。其 EventAction.g4 把编辑块和动作结构集中定义，也适合作为扩展事件工具的参考。

编辑器实现通过本地 HTTP 服务与浏览器交换 JSON，再写回事件页的 `text` 字段。README 要求提交积木后继续保存 Godot 场景。这里有浏览器、插件和场景三者的协作成本。代码已包含对象及页索引的回传处理，因此不能仅凭 README 的旧提醒就断言当前版本必然保存到错误事件。

### 我们的优势：旧事件语义、执行管理和诊断较完整

我们使用原事件页条件和命令结构，地图事件、公共事件共用指令编辑组件。除简单文本和条件外，已经有循环、标签、公共调用、并行、移动路线及执行现场等对应机制。调度器管理前台与并行解释器、每帧预算、页变化、换图取消和等待身份。

0.52 已经能够直接编辑实际执行的 GDScript，覆盖地图脚本、公共事件、脚本条件、自主和强制路线。入口为 `static func run(ctx)`，通过上下文读写同一份角色、变量、开关、背包和地图状态。保存前编译和校验绑定；复制分配新身份，移动保留身份；保留原 Ruby 作为只读来源。

需要明确的边界有两项：

1. 自动迁移的事件仍可通过 `ctx.migrated(program)` 保留原有语义会话；历史业务也继续使用生成代码和 ScriptSemantics。原生事件编辑完成后，整个工程仍有兼容层需要维护。
2. 活动 `await` 协程及尚未接收的完成结果不能保存；需要可保存等待时，使用 `ctx.fields` 和 `ctx.retry`。现有执行现场保存能力有明确边界。

从本地 CombinedEvent 分派和语法定义看，对方现成积木包含条件与选择，没有看到与我们对应的循环、标签跳转和可恢复解释器栈；可通过自定义 GDScript 扩展。因此，它的可视化编辑体验值得借鉴，完整替换现有事件运行器需要补做行为映射。

依据：[CombinedEvent](../../template/GodotMotaTemplate/Script/Game/Event/CombinedEvent.gd)、[EventPage](../../template/GodotMotaTemplate/Script/Game/Event/EventPage.gd)、[积木语法](../../template/GodotMotaTemplate/addons/mota/webview/src/EventAction.g4)、[插件说明](../../template/GodotMotaTemplate/addons/mota/README.md)、[我们的原生事件说明](EVENT_GDSCRIPT_v0.52.md)。

## 四、战斗与魔塔功能

对方已有独立的 GameBattle、GameFighter、EnemyReady 和 AreaManager。代码可见伤害、回合、临界、先攻、吸血、破防比例、地图技能及光环等处理，也有装备组合预估、怪物资料界面、自动拾取和鼠标寻路。它适合围绕其现成规则设计新魔塔，能省去一批基础玩法和便捷功能的搭建工作。

我们的战斗系统围绕闪翼实际行为迁移，保留原属性、技能目录、普通地图战斗公式和结算链，并连接原事件、自定义数据、回路及相关页面。这对于继续开发现有作品很重要；原有数值和平衡的价值能够延续。

两边虽然都有攻击、防御、技能和伤害预估，但模型与公式不同。直接换用对方 GameBattle，需要同步重做敌人、角色、装备、技能、状态及事件结算的数据映射。对方有哪些现成功能，不等于这些功能可以直接用于当前闪翼。

现有迁移范围仍排除特殊 BOSS 战、RM 原生回合制战斗及战斗事件；这些排除不能作为遗漏计算。对方的现成玩法功能也不能由此推断为对闪翼特殊 BOSS 的支持。

依据：[对方战斗代码](../../template/GodotMotaTemplate/Script/Game/Battle/GameBattle.gd)、[装备与敌人预处理](../../template/GodotMotaTemplate/Script/Game/Battle/EnemyReady.gd)、[寻路](../../template/GodotMotaTemplate/Script/Game/FindMovePath.gd)、[闪翼玩法迁移](SCRIPT_MIGRATION_v0.45.md)。

## 五、存档、撤回与编辑保护

对方把角色数据、地图事件变化、临时事件、玩家数据和地图色彩等组织为 JSON，写入加密文件；有工程存档码、50 条自动存档和章节存档。读档通过重建 MainGame 流程恢复游戏。这种方案结构直接，适合在动作边界保存常规魔塔状态。

本次查看的 SaveManager 没有保存 CombinedEvent 当前动作索引、调用栈和活动协程，也没有看到与我们相同的复杂对象图恢复及完整存档预检链路。不能据此认为它能够在任意剧情等待点精确续跑。

我们已有带版本和数据指纹的存档、内容 SHA256、主备份与临时文件替换、恢复前校验，以及共享或循环对象、自定义对象、事件栈、路线和部分表现进度的保存恢复。闪翼的事件前撤回保留 100 条循环历史。更复杂的现场恢复是我们的优势，也会增加捕获、校验、兼容和性能维护成本。

编辑保护方面，我们的 Editor_Documents 管理独立草稿与撤销重做，显式保存才写 data；保存检查外部改动和引用，并有备份及失败恢复。对方的插件侧主要围绕场景属性和文本回写工作，没有看到同等的多文档草稿发布机制；Godot 本身的场景编辑能力仍应单独看待。

依据：[对方 SaveManager](../../template/GodotMotaTemplate/Script/Save/SaveManager.gd)、[我们的对象图持久化说明](SCRIPT_MIGRATION_v0.47.md)、[0.52 兼容与等待边界](EVENT_GDSCRIPT_v0.52.md)、[当前验收记录](../tests/VERIFICATION_v0.52.md)。

## 六、界面、语言与平台

对方把界面拆成独立场景和 UIForm，UIManager 使用多层 CanvasLayer；现有 TextForm、FukiTextForm、怪物资料、设置、存档和装备等页面。项目包含移动布局相关代码、语言选择及中英日翻译文件，还有翻译提取插件。对新作品，这些是可直接研究的制作起点。

我们现阶段的短板是原图形表现还原：已有功能和页面不代表原 Sprite/Bitmap 布局、光标、轮播、过渡、输入节奏和 Message 气泡全链路已经恢复。当前规划中，0.53—0.59 继续完成共用显示、Message、标题、菜单和整合检查。

因此，对方在“如何用 Godot 场景组织新界面”上更值得参考；我们在“接上闪翼既有业务状态与原规则”上更有积累。对方 UI 场景直接依赖 MotaSystem、GameData 和其配表结构，拷入我们工程仍需改接接口、布局和输入。

平台方面，本地对方源码有移动布局，但导出配置只看到 Windows Desktop；我们现有验收也主要针对 Windows Compatibility。两边的实际跨平台兼容和发布效果，本次没有验证。

本地版本信息还存在文档差异：对方 README 写 4.5.2，架构说明写 4.5.1，`project.godot` 的 features 写 4.7。应以实际打开和运行结果确定适用引擎版本，不能只依赖某一份说明。

依据：[对方 UIManager](../../template/GodotMotaTemplate/Script/UI/UIManager.gd)、[对方跟随文本](../../template/GodotMotaTemplate/Script/UI/UIForm/FukiTextForm.gd)、[对方项目配置](../../template/GodotMotaTemplate/project.godot)、[当前后续规划](ROADMAP_v0.5.md)。

## 七、性能与工程验证

对方使用 Godot TileMap 绘图；EnemyReady 的刷新路径会计算装备组合并遍历敌人，有缓存。我们使用自身地图渲染路径，显伤已有独立线程、复制输入、请求版本和地图代次检查；事件调度有共享预算，存档和撤回有相应分帧处理。

这些能说明两边处理问题的方式不同，无法直接换算成速度排名。对方采用 TileMap 不足以证明全部流程更快，我们使用线程也不足以证明所有地图更流畅。实际比较需要使用相同规模的地图和敌人数，测量冷启动、显伤刷新、战斗开门、存读档和最大帧间隔。

我们本地有针对迁移、事件、保存恢复、错误退出、编辑器实际渲染等的验收记录。0.52 记录了正式迁移 36 张地图、145 条原生绑定，以及实际插件保存重开等检查；同时明确完整剧情人工通关尚未进行。对方目录中本次未发现对应规模的自有自动验收记录，这仅表示当前可核对证据不同，不能推断作者从未测试或外部版本没有测试。

依据：[我们的性能边界](PERFORMANCE_v0.5.md)、[0.52 验收记录](../tests/VERIFICATION_v0.52.md)。

## 八、适合借鉴的部分与接入成本

| 借鉴方向 | 能解决的问题 | 接入成本与约束 |
| --- | --- | --- |
| 门、怪物、道具等常用事件模板 | 减少新建事件时重复配置 | 较低到中等；生成我们现有事件数据，沿用原公式和执行器 |
| 独立 UI 场景与可复用部件 | 提高界面定位、预览和修改效率 | 中等；结合 0.53—0.57 的原图形恢复，接入同一 RuntimeState 和现有输入、等待机制 |
| 示例地图和按用途组织的预制内容 | 降低作者理解制作流程的成本 | 较低到中等；可作为后续制作指南参考，当前既定工作不因此增加逐版演示任务 |
| Excel 批量编辑思路 | 方便成批调整数值 | 中等；若引入，明确 JSON 的权威关系、编号和引用校验，避免双份数据各自修改 |
| Blockly 可选视图 | 让长条件和分支更易观察 | 较高；需要原命令与积木双向映射、未知字段保留、稳定身份、撤销和诊断，适合作为后续独立方向 |
| 自动图块地形配置工具 | 减少 Godot TileSet 配置工作 | 当前直接收益有限；我们的图块仍使用 RM 属性模型，改用前需转换数据和规则 |
| 寻路、自动拾取、自动切装 | 增加新作品的便捷功能 | 中等到较高；与当前规则、怪物模型和结算链耦合，逐项评估，不直接替换 |

**当前建议：继续完成既定的 0.53—0.59，把对方作为 UI 场景组织、专用事件模板和制作体验的参考。** 如果以后希望把我们的工程扩展为通用的新魔塔制作工具，再分别评估积木视图、批量配表和更多原生 Godot 制作流程。

整体替换事件运行器、战斗公式、地图底层或存档系统，接入成本明显高于参考并改造单个工具；这些部分承载的原工程兼容价值应保留。未来若明确放弃原行为并重新设计玩法，再重新评估采用对方底座的收益。

## 九、阅读入口

- 对方上手流程：[README](../../template/GodotMotaTemplate/README.md)。
- 对方事件结构：[EventPage](../../template/GodotMotaTemplate/Script/Game/Event/EventPage.gd)、[CombinedEvent](../../template/GodotMotaTemplate/Script/Game/Event/CombinedEvent.gd)、[EventAction.g4](../../template/GodotMotaTemplate/addons/mota/webview/src/EventAction.g4)。
- 对方界面结构：[UIManager](../../template/GodotMotaTemplate/Script/UI/UIManager.gd)、[UIForm 目录](../../template/GodotMotaTemplate/Script/UI/UIForm/)。
- 我们的实际开发入口：[结构说明](SCRIPT_STRUCTURE_v0.51.md)、[原生事件接口](EVENT_GDSCRIPT_v0.52.md)。
- 我们的已验证范围与未完成项：[0.52 验收](../tests/VERIFICATION_v0.52.md)、[0.5 系列规划](ROADMAP_v0.5.md)。

本地对方目录附 MIT 代码许可证；README 另有 RPG MAKER 来源素材说明。这里仅记录文件内容，未对各个素材的授权来源逐项核验。

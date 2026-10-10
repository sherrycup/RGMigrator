# ver0.36 验证记录

日期：2026-10-10，Asia/Shanghai。Godot 4.7.2标准版，Windows，Compatibility/OpenGL。范围为多素材图块集、逐格属性、可扩展图层与地图管理；事件行走图入口沿用0.35，完整指令配色仍在0.39。操作见[0.36编辑器说明](../docs/EDITOR_v0.36.md)。

## 专项检查

`EditorTilesetLayersScenario`在每次新建的`.godot/tileset_layers_*`隔离目录使用独立JSON和显式纹理夹具，不修改原RM输入或工程原地图。通过真实按钮、属性控件与画布鼠标输入检查多素材尾部追加、同图片重复段、换序同步全部共享地图和事件图形、原生属性对应、单次撤销/重做、使用中素材和裁切行保护、尺寸替换、非法宽度/行数/重复标识、失败事务回滚及未知字段保留。

检查逐格通行、方向、优先级、草丛、柜台、地形与自动图块48形状，连续拖动覆盖中间格。地图检查第四/第五层绘制、多格笔刷、复制粘贴、事件模式独立、隐藏层禁止绘制、resize保留全部层、起点和事件边界、父地图不存在/循环拦截、复制完整撤销、显式保存/重开，以及事件选择器和预览读取第二张图片。

两份隔离工程最终专项各66项通过，记录`v036-final-sample1-EditorTilesetLayersTests.log`、`sample2-EditorTilesetLayersTests.log`。`EditorTilesetLayersTests`将落盘定义交给正式`MapRuntime`和`MapEvent`，验证多素材图形、新增层原生通行短路、方向限制、草丛/柜台/地形及编辑器显示元数据不影响游戏；并通过实际Title → Game检查系统起点、两段素材、第五层与第二素材事件图形。最后补充编号布局变化后重置笔刷和图块/事件剪贴板，防止随后粘贴旧编号。

真实Compatibility最终运行渲染通过74项，记录`.godot/test-logs/v036-final-runtime/`，逐像素对照第一/第二素材及第五层，验证第四层前景按人物脚点排序遮挡，并捕获正式Game。该渲染检查通过真实SubViewport和MapCharacter，headless不计入像素证据；此前68/73项记录保留在`v036-runtime-smallcake/`及`v036-runtime-final/`。

真实Godot编辑器1280×800最终69项通过，记录`.godot/test-logs/v036-final-editor-compact/`；最终正式二律背反工程1600×1000也通过69项，记录`v036-final-acceptance-editor/`。检查素材顺序窗口、逐格优先级标记、五层地图按钮、事件多素材图块选择器和弹窗尺寸，游戏不运行。此前两种分辨率各68项记录保留。

## 回归与正式输出

`Run-Headless.ps1 -SkipMigration -RefreshRuntime -SkipImport`完整70阶段均通过，汇总`.godot/test-logs/v036-regression-summary.json`；此阶段只刷新两份隔离测试工程，不等于正式迁移或冷导入。覆盖迁移器单元与启动、编辑器/数据库/可读性、地图/事件制作、所有已有事件阶段、推箱子、角色/物品/商店、地图移动、渲染服务、存档及事件现场跨进程恢复。

原工程全部地图/事件编辑2237 / 11866项、数据库2152 / 8997项、可读性1809 / 12325项均通过；地图制作各57项、事件制作各59项通过。最后笔刷/剪贴板修复后重跑9个相关阶段全部通过，两份素材/图层各66项、地图各57项、事件各59项及编译通过，记录`v036-final-checks.json`；运行时生产代码与70阶段回归保持一致。文档契约再次通过681项，111个生产脚本、717个公共方法。最终生产源码快照`.godot/v036-final-source-under-test.json`包含117个文件，初始快照保留。

从两份只读原RM工程运行`RmxpValidator.preflight`和`MigrationPipeline.run`全新导出，未复制隔离测试工程或覆盖历史输出。初始0.36导出与检查保留，最后修复后重新迁移到`../output/0.36/ui-final/`供用户验收，记录`v036-final-export.json`与`v036-final-export.log`。二律背反19地图/34数据文件/2530素材/254脚本，黎之闪翼36地图/50数据文件/4097素材/306脚本。

最终两份迁移报告均无错误，输出各102个模板/版本文件与最终117文件源码快照一致，记录`v036-final-audit.json`。生成配置启用`rgm_editor`和Compatibility，报告版本为`RGMigrator ver0.36`。两份最终工程冷导入与EditorCompileTests均退出0，没有SCRIPT ERROR / ERROR / FAIL，记录`v036-acceptance-final-sample1-checks.json`、`sample2-checks.json`。

最终黎之闪翼工程在真实编辑器1280×800使用原素材核对数据库、成长表、装备集合、公共事件、指令选择、逐格图块标记和系统窗口，33项通过，记录`v036-final-acceptance-database/`；原图像与○/×标记实际渲染，原数据保持干净。已实际查看图块、组合素材、优先级与五层地图、事件第二素材预览及正式Game的PNG。

用户验收入口：`D:/Dev/Godot_Trans/output/0.36/ui-final/二律背反_Godot/project.godot`与`D:/Dev/Godot_Trans/output/0.36/ui-final/黎之闪翼（开发中）_Godot/project.godot`。源码和历史输出保留，未进行Git提交。


## 图块首页反馈修订（2026-10-10）

“字段 / 值”统一视为未实现专用UI时的占位入口，专用UI完成后直接替换原位置；其它数据库专用界面继续按0.37推进。本轮用EditorTilesetEditor常驻画布和侧边属性替换图块字段树及二次标记弹窗，名称直接编辑；六类属性和素材/背景页签共用同一Canvas，切换模式保留滚动，应用后保留选择。自动图块、全景、雾及战斗背景均使用带名称的图片预览，背景参数使用独立控件。地形绘制把JSON浮点数按整数格式输出，0.0改为0。

属性控件只写对应标记，统一修改48种自动图块的通行不会覆盖它们各自的优先级或地形；无需扩表时不改原表头。打开不自动扩表，不改变原记录。保留未知字段、其它通行位与原工程超出标准范围的旧值；取消图片选择/当前条目不应用，显式保存才写文件。

最终15个相关阶段全部通过，记录`.godot/test-logs/v036-home-release-checks.json`，生产源码快照为`.godot/v036-home-source-under-test.json`（117文件）。文档契约681项通过：111个生产脚本、719个公共方法。两份素材/图层专项各85项、地图制作各57项、事件制作各59项；数据库2152 / 8997项、可读性1809 / 12325项、原地图事件编辑2237 / 11866项及编译均通过。此前完整70阶段记录仍是上一交付的历史证据，本次只重跑相关阶段。

真实Godot插件1280×800及1600×1000各92项通过，记录`v036-home-release-editor-1280x800/`与`v036-home-release-editor-1600x1000/`；小窗口中的优先级和地形控件直接可见，模式/素材页签均保留同一画布。实际查看地形整数、普通图块原像素与自动图块具名预览。正式运行Compatibility渲染93项通过，记录`v036-home-release-runtime/`，落盘后两段素材、第五层、图块事件、通行/地形与前景遮挡均一致。

从两份原RM工程正式运行preflight和MigrationPipeline.run，新导出到`../output/0.36/tileset-home/`，保留ui-final及其它历史工程；记录`v036-home-export.json/log`。二律背反19地图/34数据文件/2530素材/254脚本，黎之闪翼36地图/50数据文件/4097素材/306脚本。两份报告无错误，各102个模板/版本文件与117文件最终源码快照一致，记录`v036-home-audit.json`。两份冷导入与EditorCompileTests全部通过，记录`v036-acceptance-home-sample1-checks.json`和`sample2-checks.json`。

新正式二律背反工程真实编辑器1280×800数据库检查48项通过，记录`v036-home-acceptance-database/`，包括原素材像素、六种模式保留画布和滚动、素材页签保留画布、空间及互不重叠检查；浏览后原数据保持干净。原记录UI空间检查等待布局完成后读取，首次过早读取的失败日志保留；本轮初期旧测试窗口类型和场景副本问题日志同样保留，最终结果只使用上述完成的检查。

最新验收入口：`D:/Dev/Godot_Trans/output/0.36/tileset-home/二律背反_Godot/project.godot`与`D:/Dev/Godot_Trans/output/0.36/tileset-home/黎之闪翼（开发中）_Godot/project.godot`。操作见[0.36编辑器说明](../docs/EDITOR_v0.36.md)，未进行Git提交。

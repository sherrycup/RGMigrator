# ver0.37 验证记录

当前反馈修正见[0.37反馈验证](VERIFICATION_v0.37_feedback.md)；下文保留首次数据库UI的历史证据。

日期：2026-10-10，Asia/Shanghai。Godot 4.7.2标准版，Windows，Compatibility/OpenGL。范围为数据库专用界面、名称管理、成长/习得/集合/有效度与动画编辑；图块属性画布随本版放大到1.5倍。操作见[0.37编辑器说明](../docs/EDITOR_v0.37.md)。完整事件指令配色仍在0.39。

## 专项与回归

EditorDatabaseAuthoringScenario在每次新建的.godot/database_authoring_*隔离目录操作独立JSON与纹理，使用专用可见控件检查字段树替换、实际未知扩展、直接编辑/取消/应用、撤销重做、成长整数列和等级0、具名习得特技与额外字段、集合用途与数量、A–F具名有效度及历史特殊值、名称搜索/追加与稳定ID。

动画专项检查192px裁切、坐标/缩放/负角度/镜像/透明度、单元增删、复制帧保留活动数量、音效/闪光时序的1起始UI与0起始JSON、颜色转换、有时序帧删除保护、后续时序移位、预览不改数据、显式保存重开及实际RmxpAnimationData.compile/resolve。EditorDatabaseAuthoringTests还将落盘定义交给正式RmxpAnimationPlayer，检查图案变换、屏幕闪光与20fps推进；两份隔离工程最终各46项通过，记录v037-final-authoring-checks.json；补充第101条习得特技与动画时序的选择器定位，避免隐藏定位树分页限制专用界面。

最终相关回归19个阶段全部通过，汇总.godot/test-logs/v037-release-checks.json。覆盖文档契约与两份工程的动画运行时、编辑器编译、数据库制作专项、多素材/图层、地图制作、事件制作、数据库全记录、可读性及地图/事件全记录。专项各46项，动画运行时各62项，多素材/图层各85项，地图制作各57项，事件制作各59项。原数据库2152 / 8997项、地图/事件2237 / 11866项、可读性1809 / 12325项全部通过。没有把0.36的70阶段回归当作0.37重新测试。

文档契约通过711项：116个生产脚本、726个公共方法。生产源码快照.godot/v037-source-under-test.json包含122个文件。测试接口同步到AGENTS.md，新增专项已接入Run-Headless.ps1；本次执行的是19阶段相关回归。

## 实际界面

Run-EditorRender -DatabaseAuthoringOnly在真实Godot插件中检查角色分组、成长、习得、集合、有效度、名称、公共事件、动画帧/时序与放大图块画布，游戏不运行。1280×800与1600×1000各78项通过，截图目录.godot/test-logs/v037-final-editor-1280/与v037-final-editor-1600/。动画检查实际源图像素，headless不计为渲染证据。最终动画布局使预览与八项参数并排显示。

早期真实检查发现换行说明初始宽度不足撑大窗口，已给说明设置已知宽度并复查；原失败日志保留在v037-authoring-1280-early/、v037-authoring-1280-layout/和v037-layout-diagnostic/。

## 正式输出

从两份只读原RM工程运行RmxpValidator.preflight → MigrationPipeline.run，最终输出位于：

- D:/Dev/Godot_Trans/output/0.37/database-ui-final/二律背反_Godot/：19张地图、34个原数据文件、2530个素材、254段脚本归档。
- D:/Dev/Godot_Trans/output/0.37/database-ui-final/黎之闪翼（开发中）_Godot/：36张地图、50个原数据文件、4097个素材、306段脚本归档。

最终迁移记录v037-final-export.json与v037-final-export.log，两份迁移报告errors为空。v037-audit.json确认两个工程各107个模板文件与最终源码一致，插件启用、Compatibility配置及ver0.37正确。v037-original-data-audit.json将数据库/地图/系统等原定义与0.36正式输出逐份比较，原定义未改变；测试配置单独排除，因为它有版本元数据。

最终两份工程各执行首次--headless --import及EditorCompileTests，共4阶段通过，无SCRIPT ERROR/ERROR/FAIL；记录v037-acceptance-final-sample1-checks.json与sample2-checks.json。

在两个最终工程中运行真实插件：二律背反1280×800、黎之闪翼1600×1000各87项通过；记录v037-acceptance-final-editor-1280/与1600/，每份11张实际截图，游戏未运行。额外检查八项动画参数与预览同时可见、第101条习得和音效选择器可定位。倍率作为数据库流程内的画面检查，不设独立验收项。

交付汇总.godot/test-logs/v037-final-acceptance-summary.json包含19阶段相关回归、最终专项46项/工程、4个冷导入/编译阶段、实际插件87项/分辨率、正式迁移及模板/原定义一致性。先前database-ui/输出保留，最终链接指向database-ui-final/。



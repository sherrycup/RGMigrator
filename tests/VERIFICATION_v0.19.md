# RGMigrator ver0.19 验证记录

日期：2026-10-06。Godot 4.7.2 stable标准版Windows x64（ed1daf0bf），Compatibility/OpenGL3.3，GTX1660Ti，驱动596.21。没有实测Godot4.5或其他平台；真实渲染测试不使用headless，音频自动检查使用Dummy驱动，不能代替人工听感。人工步骤见[验收清单](ACCEPTANCE_v0.19.md)，接口见[地图表现说明](../templates/runtime/MAP_PRESENTATION.md)。

## 实现和依据

MapViewState负责独立显示矩形/跟随中心/地图像素原点/手动滚图；MapCamera单独拥有镜头位置，ScreenRenderer仅叠加震动偏移。边界根据地图显示区域而不是窗口尺寸计算，区域外遮住地图和天气；不是任意嵌套Viewport/Ruby兼容层，也不自动执行自定义UI代码。

已只读核对样板`0097_Game_Player 1.rb`的`center_x/center_y`及`center`，`0103_▲●Game_Map 1.rb`的display/scroll，`0104_Game_Map 2.rb`的fog参数/渐变，以及`0105_Spriteset_Map.rb`的半速panorama和fog/weather偏移。使用原生秒/像素而非128单位或40帧主循环；不自动转换这些脚本。图块集字段参考[RMXP随附帮助：RPG::Tileset](https://www.rpg-maker.fr/dl/monos/aide/xp/source/rgss/gc_rpg_tileset.html)，冻结/灰度过渡概念参考[Graphics](https://www.rpg-maker.fr/dl/monos/aide/xp/source/rgss/gm_graphics.html)。Camera2D接口核对[Godot4.5文档](https://docs.godotengine.org/en/4.5/classes/class_camera2d.html)，文档阅读不代表4.5实测。

MapEffectsState和GameTimer为纯数据；MapEffectsRenderer采用共享纹理、实例材料、批量WeatherRenderer，没有每粒子节点。天气0关闭，类型非0且强度0保留最低密度；天气/雾渐变按时间精确到端点。TransitionRenderer截图瞬时拥有，结束/取消/退场释放。AudioRuntime统一频道、ME/BGM互斥、淡出和记忆，测试音频实例独立。

## 新迁移与自动检查

仅生成在`.godot/test_exports_11275030/`，不覆盖用户已验收output，不修改rm_template，不提交Git。

- 魔塔样板7630·改 → 黎之闪翼（开发中）_Godot：36地图、50数据、4097素材、306Ruby脚本。
- 小蛋挞样例 → 二律背反_Godot：19地图、34数据、2530素材、254Ruby脚本，包含Map585。

首次全新迁移和两份冷导入成功；当时完整32阶段检查仍有存档归一化失败，不能称整轮通过。证据`.godot/test-logs/v019-cold-development-summary.json`。修复后在相同**新建可丢弃输出**刷新运行时、说明和报告，再跑整体回归。独立重启扩展第一轮也失败，证据`v019-restart-development-summary.json`；修复坐标数值类型后最终执行`Run-Headless.ps1 -SkipMigration -SkipImport`，34阶段、0失败。最终摘要`.godot/test-logs/v019-final-headless-summary.json`；最终脚本已复制到新输出，未以旧工程冒充新版本。

每份PresentationTests75项，包含三分辨率/大小地图边界、非窗口中心的跟随点、区域裁剪、无效参数原子拒绝、手动滚动/重叠拒绝/恢复、30/40/60/120FPS雾及天气端点、原图块集不变、最小天气强度、计时器只到零一次、菜单互斥/暂停/同地图实例、独立大地图/预览、存档缺字段默认/坏数据隔离、新游戏重置、音频音调/ME暂停恢复/SE上限/淡出/记忆/缺文件保护。

另外42类编译、库存82、技能动画62、商店State65、角色修改92、屏幕93、素材Cache63、人物97、存档75及独立进程write/read全部通过。重启读档检查独立跟随点/地图矩形、天气/雾剩余1.5秒、倒计时11.5秒，原角色、图片、人物选项检查保留。

## 真实画面和开发修复

640×480、800×480、768×768均使用实际OpenGL渲染并保存PNG：

- 样例1 `.godot/test-logs/v019-release-render1/`，74项。
- 样例2 `.godot/test-logs/v019-release-render2-perf/`，75项（含实际行走基准断言）。
- 覆盖原窗口皮肤/中文、三页滚动工具、独立大地图、左侧UI裁边像素、自定义中心人物实际像素、双轴随动、全景透过空地图像素、原工程平铺素材、暴风雨和计时、黑屏淡出、冻结/半程淡化、灰度图左右区域分别显示新/旧画面、截图材质释放。
- 两样例旧菜单三尺寸专项：`v019-menu-regression1/`、`v019-menu-regression2/`均通过；背包、装备、技能、动画并发、商店、State、存档/标题、图片屏幕及人物区没有退化。
- 人物像素专项`v019-movement-regression/`17项通过。`v019-map585.log`原图块像素0.2549一致、玩家(13,6)→(13,7)，既有不支持116诊断通过实际关闭按钮继续，不隐藏事件错误。
- 迁移器1000×720实际界面通过，版本标签ver0.19、测试准备开关和日志区域可用；截图`v019-migrator.png`，日志`v019-migrator-ui.log`。

开发修复包括：GDScript的Timer原生类命名冲突/Variant类型推断；全景被旧底色挡住（新增实际空图块像素断言，不以visible=true冒充通过）；JSON整数/浮点导致存档比较/跨进程坐标数组失败；640高度工具状态第二行被裁；长素材名称撑宽下拉框；天气强度0与关闭的区别；取消未完成截图的代次保护。修复后重新验证，未放宽像素或存档断言。

首轮样例2实际画面是在它的冷导入完成前启动，只能证明工具对照图，出现原素材缺失警告；不作为源素材加载通过依据。冷导入完成后的上述最终画面使用原素材、原皮肤。音频缺失或已隔离的源BGM仍会诊断，没有补取RTP或假称已能播放。

## 性能记录

实际Map585、768×768、预热120帧、Engine.max_fps=60、--disable-vsync，暴风雨9，原生人物在安全相邻格往返，through默认false；60秒间隔统计使用墙钟，实际278步，不用静止地图或headless代替。

最终证据`v019-release-render2-perf/performance.json`：60.008433秒、3601帧，平均**60.0082 FPS**，P95 **16.992ms**，达到平均≥59/P95≤20ms的本轮目标。之前一轮`v019-final-render2-perf/`为60.0054 FPS/P95 16.894ms，也通过。与ver0.18旧基准的菜单/运动负载和采样方式不同，不能据此直接归因于某个优化或宣称所有机器锁60。

20次普通菜单开关前后节点214→214、资源84→84；静态内存115258157→115668701（+410544字节，约401KiB），显存66330431→66898411（+567980字节，约555KiB）。没有观察到节点/资源数量累积，但存在小幅内存/显存增长，未通过长时测试证明绝无泄漏。基准脚本保留所有统计，不把启动成功当性能通过，也不把平均60等同每帧16.67ms。

## 边界

不接通新事件命令、强制/自主移动路线、并行/完整自动调度；不执行Ruby、默认战斗、旧RM存档或RTP。截图/淡入淡出/音频记忆与进度不序列化。用户需按清单确认实际手感和音频听感；开发自动检查不代表用户验收通过。

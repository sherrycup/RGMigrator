# ver0.2 验证记录

日期：2026-10-06。引擎：Godot 4.7.2 stable 标准版 Windows x64（ed1daf0bf）。

## 范围

用户已验收 ver0.19 的底层表现，本次仅将基础归档为 ver0.2，并建立后续事件开发契约；没有改动人物/渲染/菜单/事件逻辑，没有重构天气所有权，没有把独立预览操作改成真实地图操作。

修改仅位于 RGMigrator；rm_template 只读，用户已验收的导出工程未改写。现有 `.godot/test-results.json` 中的两个隔离工程通过 RefreshTestRuntime 更新版本、模板和生成说明/报告。本次没有重新迁移完整样例或进行冷素材导入。

## 文档与版本检查

执行 `tests/DocumentationTests.gd`，最终输出：

```text
DOCUMENTATION TESTS: PASSED / 423 checks / 68 scripts / 445 public methods
```

日志：`.godot/test-logs/v02-documentation.log`。

- AGENTS、README、迁移器配置、唯一版本源和运行时模板均为 ver0.2。
- 每个生产脚本有唯一源文件节，继承、class_name、信号、带参数构造器、非下划线方法签名、公开字段和非依赖常量与源码一致；缺失、过期接口或遗漏脚本会失败。
- 在新的 `.godot/version_contract_*` 夹具目录生成配置/运行时/README/中文及JSON报告，确认新产物显示 ver0.2，同时 Godot 4.5 最低配置和 Compatibility 渲染器保持不变。
- 文档明确当前不存在 ScreenState.weather()；天气仍归 MapEffectsState，统一 Game_Screen 管理是后续天气事件接入的前置任务，不是已完成功能。

检查先完成 287 项（仅签名/信号等），后补字段/常量清单，再执行最终 423 项；两次均通过。整体回归中的 documentation-contract 日志记录前一轮 287 项，最终独立日志记录完整 423 项，不能混淆。

## 两样例回归

命令：

```powershell
./tests/Run-Headless.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe' -SkipMigration -RefreshRuntime -SkipImport
```

汇总：`.godot/test-logs/summary.json`（2026-10-06T21:22:37+08:00），36 阶段、0 失败。

两个隔离输出均位于 `.godot/test_exports_11275030/`：黎之闪翼（开发中）_Godot、二律背反_Godot。每份完成标题、基础运行时、菜单、物品装备、技能动画、商店状态、角色成长、图片屏幕、分类缓存、人物地图、地图表现、类编译、存档、独立进程写入/读取和退出测试。

保留检查数量：物品装备 82、技能动画 62、商店状态 65、成长 92、屏幕 93、分类缓存 63、人物地图 97、表现 75、存档 75；其余阶段以退出码、无脚本错误和 PASSED 标记验证。另有迁移器单元测试、启动、隔离模板刷新及文档契约阶段。

## 未重新执行的验证

此次没有重测真实画面、音频听感或 60 秒 FPS；没有因为改了版本号就把历史性能数字算成本次测量。三尺寸/Map585/性能基线仍见 `VERIFICATION_v0.19.md`，用户已确认该版效果。没有进行 Git 提交或发布。

# kuro 迁移与交接资料

2026-10-21：游戏的日常说明已精简为 kuro 根目录的 README、DEVELOPMENT 和 AGENTS。
本目录汇总从游戏移回迁移器的历史资料；当前游戏位于 `D:\Dev\kuro`，运行不依赖此目录。

## 常用历史资料

- [0.59 整合及开发交接](../../INTEGRATION_v0.59.md)
- [0.59 迁移来源审计](../../MIGRATION_AUDIT_v0.59.md)
- [0.59 验证结论](../../../tests/VERIFICATION_v0.59.md)及[截图目录](../../../tests/verification/)
- [工程移动与独立 Git 验证](export_snapshot/tests/HANDOFF_2026-10-21.md)
- [本游戏完整迁移报告](export_snapshot/migration_report.md)及[机器报告](export_snapshot/migration_report.json)
- [本游戏自定义数据来源清单](export_snapshot/custom_data_inventory.md)
- [逐文件迁移索引](index.json)

迁移规划和分版本说明继续放在迁移器 `docs/`，历史验收记录和截图继续放在 `tests/`。
与现有文件逐字节一致的游戏副本直接复用现有文件；不同的导出快照保存在 `export_snapshot/`，不覆盖维护中的版本。
快照保留原字节和当时的说法，可能包含过时接口；游戏开发以 kuro 的 DEVELOPMENT 为准。
截图导入侧文件仅作为历史元数据保存，本目录通过 `.gdignore` 排除 Godot 资源扫描。

## 游戏侧保留的功能文件

- `migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.json`：脚本工作区和覆盖检查仍直接读取。
- `migration_docs/MIGRATION_AUDIT_v0.59.md`：简短的历史审计查询入口，兼容编辑器生成报告中的路径。
- `migration_report.md`：简短的诊断入口，兼容游戏错误提示。
- `script_inventory.md`、`script_coverage.md`：编辑器维护的当前报告。
- `data/`、`legacy/`、运行脚本、编辑器和可执行测试保持不变。

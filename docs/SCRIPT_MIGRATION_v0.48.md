# 0.48 脚本工作区与迁移报告

2026-10-14。本阶段仅推进闪翼。运行功能沿用0.45—0.47，0.48提供编辑、定位、重新转换和覆盖报告；完整游戏组合流程验收仍在0.49。特殊BOSS和此前确认的原生回合战/RTP/RM旧存档边界保留。

## 使用方式

打开生成工程的project.godot，在“魔塔编辑器”点击“脚本工作区 F8”。左侧按原加载顺序查看脚本库，也可筛选地图/公共事件、诊断或工作副本；名称、单元ID和地图位置支持搜索。

2026-10-14反馈修复：原0.48/final的工作区没有初始化为隐藏的附属弹窗，已修正首次弹出、窗口归属和打开时的焦点。请使用重新迁移的../output/0.48/fix-script-workspace/黎之闪翼（开发中）_Godot；原final工程保留。实际编辑器按钮及F8回归见验证记录。

同日追加移动、事件记录和ESC菜单性能反馈修复，工程为../output/0.48/fix-performance/黎之闪翼（开发中）_Godot，包含上述工作区修复。具体定位、行为边界和GPU测量见PERFORMANCE_FIX_v0.48.md。

随后追加BGM反馈修复，最新工程为../output/0.48/fix-audio-final/黎之闪翼（开发中）_Godot，包含工作区和性能修复；恢复MP3正常导入，MP2标题音乐转WAV，新安装默认音量10，已存静音设置保留。来源边界与混音检查见AUDIO_FIX_v0.48.md。

- “原 Ruby”只读，继续来自legacy/ordered_scripts及最初事件片段。
- “Ruby 工作副本”可编辑已生成的脚本库、空槽及原事件片段。修改只进入编辑草稿；Ctrl+S显式保存，重新打开仍保留。
- “生成 GDScript”只读，来源对应列表可跳到实际生成行。诊断可跳到Ruby行列，API候选可跳到来源脚本。
- 原Ruby由专用Godot服务或数据承担的单元只读；覆盖树列出实际GDScript入口，可用Godot内置编辑器继续开发。修改这些原Ruby不会假装同步到服务。
- “新建 Ruby 脚本”在当前库末尾追加加载序号，不重排依赖按原序号适配的闪翼原脚本。
- F8“保存并重新转换”保存草稿，然后在独立暂存目录使用随工程提供的纯GDScript转换器重新生成，并核对GDScript编译与事件绑定；成功后重新运行游戏使用新代码。编辑器不执行Ruby或事件。

## 文件归属与安全保存

原工程与legacy原文均不覆盖。工作副本登记在data/script_workspace.json；成功发布的库工作源码写入data/script_sources/。运行代码在runtime/generated，AST/语义/来源映射和事件绑定按同一次转换更新。

重新转换以当前地图和公共事件文件为输入，保留非脚本编辑；根据来源重新收集355/655、111和路线45。新建355、脚本条件和路线45可从实际事件/路线表单编辑后转换。插入普通指令保留绑定身份，复制事件分配独立身份；两个编辑器同时改同一段源码时拒绝自动取舍。完整且未修改的旧占位可恢复，已改动的占位或保留路线明确报告冲突。工作区事件位置已在其它编辑器变化时拒绝套用过期副本。

所有转换产物先写暂存区并编译；脚本失败时保留上次成功的运行代码/绑定，失败工作副本仍可重开修正。发布前后检查文件哈希，外部修改阻止覆盖；批量发布备份在.godot/rgm_editor/backups/scripts_*，替换失败回滚。手工改过的生成文件单独报告为manual_changed并阻止自动覆盖。需先自行备份、整理手工版本与生成版本，工具不会无声取舍。

## 迁移覆盖

data/script_coverage.json及script_coverage.md分别记录AST解析、生成、事件绑定、空槽、排除、诊断、用户修改、手工归属、语法节点和API候选位置。已有服务分类引用0.47逐脚本职责审计；不将unsupported编译状态直接当成该功能未迁移，也不将服务存在或文件数当作全部原方法已经行为验证。用户修改后的生成代码不自动标为runtime_verified。

## 数据与系统专用UI

“数据库 / 公共事件 F9”中的项目自定义数据使用货币名称/精确整数上限、闪翼系统初始选项、原角色预设、区域/楼层与地图关系、初始全局数据和来源诊断页面。货币标识和原记录ID保留；修改楼层关系同步重建lookup，重复区域/楼层拒绝。具名控件替换原位置，不增加重复兼容字段入口；未知数据和来源记录保留。

## 实际源码

| 职责 | 文件 |
| --- | --- |
| 编辑器入口 | EditorPanel.gd、EditorScriptDialog.gd |
| 工作副本与重新转换 | EditorScriptWorkspace.gd |
| 覆盖与归属 | EditorScriptCoverage.gd |
| 冲突、备份与批量发布 | EditorProjectTransaction.gd |
| 正式导出初始化 | ScriptWorkspaceExporter.gd、ProjectGenerator.gd、MigrationPipeline.gd |
| 数据专用页面 | EditorDatabaseForm.gd、EditorDatabaseSchema.gd、EditorDocuments.gd |

生成工程中编辑器文件位于addons/rgm_editor，随附转换器位于其compiler目录；迁移器源码的templates/editor路径是这些文件的源模板。

阶段实现、正式导出和独立核验见tests/VERIFICATION_v0.48.md。初次输出为../output/0.48/final/黎之闪翼（开发中）_Godot，工作区修复版为../output/0.48/fix-script-workspace/黎之闪翼（开发中）_Godot，最新性能反馈修复版为../output/0.48/fix-performance/黎之闪翼（开发中）_Godot；已有输出保留。

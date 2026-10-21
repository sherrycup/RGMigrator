# 0.50—0.51 脚本结构与开发入口

2026-10-20：本页作为当前开发入口，文件路径已随0.59去Flash前缀更新；历史旧名与当前名见tools/script_renames_v059.json。生成工程同表位于data/。迁移后的开发流程及碎屏新素材见INTEGRATION_v0.59.md。

运行代码在 `runtime/scripts/`，魔塔编辑器在 `addons/rgm_editor/`，迁移器在源仓库的 `scripts/importer/`。运行代码不依赖编辑器和迁移器。

运行目录以 `00_Game` 开始，接着是战斗、事件、地图、通用窗口、标题、Message、档案、菜单、演出与支持服务。`11_Development` 包含测试工具页面，正常游戏关闭测试模式时不展示。目录编号控制浏览顺序，实际加载、覆盖和 alias 顺序由原有注册信息决定。

各功能目录同时放置对应场景控制器、窗口和专用辅助类。例如标题在 `05_Title`，Message 在 `06_Message`，菜单的物品、技能、回路、笔记、灵视和地图系统分别在 `08_Menu` 的子目录。

当前 `Flash` 文件名前缀暂时保留。按用户确认，既定范围的迁移缺口和已知问题解决后，会统一改为功能名称，以改善文件排序；来源通过注释和迁移记录保留。此项已列入 0.5 收尾计划，现有路径仍以本说明和实际布局清单为准。编辑器继续使用 `Editor_` 前缀。

`data/script_layout.json` 列出稳定文件名到实际分组路径的完整映射，`ScriptPaths.gd` 支持需要按名称查找的动态入口。普通依赖直接引用实际路径。源仓库使用 `tools/script_layout.py --check` 检查分组、路径登记和运行时依赖边界。

## Game 对象与原 RM 的对应

| 原 RM 职责 | Godot 实际入口 |
| --- | --- |
| Game_System、Game_Temp、开关/变量/队伍 | `00_Game/RuntimeState.gd`，各状态和运行服务的统一入口 |
| Game_Actor、Game_Actors | `00_Game/ActorState.gd`、`Game_ActorState.gd`、`RuntimeState.actor(id)` |
| Game_Item、Game_Weapon、Game_Armor 等 | `00_Game/ObjectCatalog.gd`、`CustomDataState.gd`，保留原记录与对象身份 |
| Game_Screen、Game_Picture、天气 | `00_Game/ScreenState.gd`、`PictureState.gd`、`WeatherState.gd` |
| Game_Character、Game_Player、Game_Event、Game_Map | `03_Map/MapCharacter.gd`、`PlayerController.gd`、`MapEvent.gd`、`MapRuntime.gd` |
| Interpreter | `02_Event/EventInterpreter.gd`、`EventScheduler.gd`、`EventExecutionContext.gd` |
| 普通魔塔战斗和技能 | `01_Battle/Gameplay.gd`、`BattleSimulator.gd`、`Actions.gd`；原技能定义在 `runtime/generated/flash_skill_catalog.gd` |
| 标题、地图、菜单场景入口 | `05_Title/Title.gd`、`10_Support/Boot/Game.gd`、`08_Menu/Main/MenuCoordinator.gd` |

已有类名、唯一 RuntimeState、存档类标识和原数值规则保持。没有为复现 RM 名称创建另一份游戏状态。

存档兼容只识别明确登记的导航变化：适配器目标路径、生成程序固定文件头与 Semantics 导入路径，以及文件头带来的数据表达式来源行号偏移。指纹保留其余原始字节，生成方法仍检查完整源码；数据库、地图、玩法数据或生成方法正文发生变化时继续拒绝旧进度。当前存档中的 generated_hashes 仍保存实际文件 SHA，不跳过类链接、结构、资源和恢复校验。

## 常用修改位置

- 主菜单命令和解锁：`08_Menu/Main/MenuModel.gd`。
- 主菜单子页面创建：`08_Menu/Main/MenuPages.gd`。
- 主菜单输入、页面生命周期和绘制：`08_Menu/Main/MenuScreen.gd`。
- 物品、技能及回路业务入口：`01_Battle/Actions.gd`；实际数据操作仍访问同一份运行状态。
- 消息控制/布局/绘制：`06_Message/MessageController.gd`、`MessageLayout.gd`、`MessageView.gd`。
- 显伤后台计算：`01_Battle/DamageWorker.gd`；地图展示在 `03_Map/EnemyMapLabels.gd`。
- 存读档与撤回：`10_Support/Persistence/`。`SavePreparation.gd` 由 `tools/sync_save_preparation.py` 从 `SaveCodec.prepare` 生成。
- 生成代码执行及 Ruby 语义适配：`10_Support/Scripting/`；机器产物在 `runtime/generated`，来源映射在 `data/script_source_map.json`。

编辑器依次分为 `00_Plugin`、`01_Documents`、`02_Map`、`03_Event`、`04_Database`、`05_Assets`、`06_Scripts` 和 `07_Common`。随生成工程附带的重新转换器仍在编辑器的 `compiler/`，游戏运行不加载它。

编辑器脚本统一使用 `Editor_` 前缀，例如 `00_Plugin/Editor_Plugin.gd`、`03_Event/Editor_CommandList.gd` 和 `06_Scripts/Editor_ScriptWorkspace.gd`；`compiler/` 中随附的转换器也使用此命名。仓库的编辑器测试遵循相同前缀。运行时事件解释器和开发工具仍放在运行目录，按各自游戏职责命名。

## 代码维护

每个维护中的 `.gd` 文件首先提供中文职责与调用说明，放在 `@tool`、`class_name` 和 `extends` 之前。文件头列出静态/实例调用方式、构造与公开方法的完整签名、参数含义、类型、默认值、返回结果，以及存在的对外信号、Godot 回调与公开常量。内部辅助方法不列入对外接口。

职责集中登记在 `tools/script_descriptions.json`，中文参数说明和重点接口约定在 `tools/script_api_docs.json`；`tools/gdscript_interfaces.py` 从实际声明提取签名，避免手工复制后漂移。修改接口后运行 `tools/sync_script_headers.py`，`--check` 检查签名、参数、说明及编辑器前缀，并拒绝过时的手写接口覆盖。转换器及代码生成器同时为新生成的运行程序、技能定义、版本文件和编辑器工具保留详细文件头。

例如 `Editor_CommandList.configure(list, documents, characters)` 的文件头说明三个参数的含义和默认值、`draft()` 的深复制返回值及 `changed(list)` 信号；`MessageController.present(...)` 说明消息 payload 字段、请求编号、人物关联、提示模式和失败返回。角色、事件、存读档和脚本工作区的常用入口还标明状态归属、配置顺序及实际结果字段。

生成程序的当前详细说明、上一版单行说明和已登记的 Semantics 导入路径有精确的旧存档别名，统一由 `ProgramDocumentation.gd` 管理。数据表达式的来源行号核对实际生成语句后，只归一化这些已知文件头的行数；表达式、来源范围及其余 JSON 字节仍参与校验。其余代码和注释继续逐字节参与校验，手工改动文件头或方法正文仍会拒绝不匹配的存档。来源行号从带注释的实际生成文件计算。

生产代码统一展开复合语句、分支和长表达式，保留来源说明。`tools/format_scripts.py` 使用 gdtoolkit 4.5.0 做排版，并逐文件验证 AST 和注释保持一致；这是开发工具，生成游戏不需要 Python 或格式化依赖。

菜单解锁数据、页面构造和显示职责已分开，页面继续保留原有信号和存档回调。后续图形恢复从各功能目录继续修改。原图形还原、Message 缺口修复和原生 GDScript 事件编辑按 0.52 之后的规划推进，不属于本次结构整理的完成范围。

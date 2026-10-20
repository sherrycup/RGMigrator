# 0.52 可读事件 GDScript（2026-10-17 修正）

事件编辑框只保存和编辑实际执行的 GDScript 业务正文。新增地图事件、公共事件、脚本条件、自主路线和强制路线的脚本均使用同一规则。`extends`、入口函数、来源管理和执行包装由框架生成，详细职责和参数注释放在对应 `.gd` 模块。

## 编辑和保存

在魔塔编辑器中打开事件，新增或双击“脚本”。脚本条件选择“条件类型 → 脚本”，路线选择动作“脚本”。代码框提供语法着色、行号、编译检查与只读原来源。

例如角色初始化，现在事件正文只有：

```gdscript
Actor_Init.load(2)
```

`Actor_Init.load(actor_id, index=0)` 应用该角色的原初始化预设。实际业务实现位于 `runtime/scripts/00_Game/Game_ActorInit.gd`，使用当前正式角色，并保留原预设顺序、数值和错误处理；详细接口注释放在该文件。原工程 145 个入口均由已解析 AST 转成可读正文，事件不再携带 `program(env)`、`env.tick`、临时执行变量或长文件头。编辑后的正文直接编译执行，不通过旧单元编号执行隐藏的旧程序。

变量和开关也可以直接写：

```gdscript
ctx.set_variable(81, ctx.variable(81) + 1)
ctx.set_switch(82, true)
```

脚本条件必须明确返回布尔值：

```gdscript
return ctx.variable(81) >= 3
```

依次点击“编译检查”“应用指令”“应用事件”，再按 Ctrl+S 保存；停止并重新运行游戏读取保存内容。编译和应用草稿不运行事件。保存前整批检查所有原生脚本，错误保留磁盘旧文件。诊断行号指向编辑框的正文，不包括内部包装行。

0.52 早期由用户编写的完整 `extends RefCounted / static func run(ctx)` 模块仍可运行；自定义模块不被无条件重写。旧版自动迁移模板在编辑器内升级为业务正文，打开时只生成内存草稿，明确保存后才写回。

F8 保留原 Ruby 与旧生成文件的只读查看，禁止从旧转换入口覆盖用户的 GDScript。

## 主要接口

| 接口 | 参数和用途 |
| --- | --- |
| `Actor_Init.load(actor_id, index=0)` | 原角色编号、原初始化预设序号；例如 `Actor_Init.load(2)` |
| `ctx.actor(id)` | 当前正式角色对象，沿用角色自身的参数校验和变化通知 |
| `ctx.variable(id, fallback=0)` / `ctx.set_variable(id, value)` | 原变量编号和实际值 |
| `ctx.switch(id)` / `ctx.set_switch(id, value)` | 原开关编号和布尔值 |
| `ctx.self_switch(letter, value)` | 调用者事件的 A/B/C/D 独立开关 |
| `ctx.item_count(kind, id)` / `ctx.gain_item(kind, id, amount)` | kind 为 item/weapon/armor，amount 为有符号整数，背包数量限 0–99 |
| `ctx.temp` / `ctx.system` / `ctx.party` | 当前临时字段、系统字段和队伍服务 |
| `ctx.actors.at(id)` / `ctx.variables.at(id)` | 迁移接口中按原编号读取角色或变量 |
| `ctx.variables.put(id, value)` | 沿用原变量语义写入值 |
| `ctx.event` / `ctx.game_map` / `ctx.player` / `ctx.screen` | 当前调用事件、地图、玩家和屏幕效果服务 |
| `ctx.state` / `ctx.map` / `ctx.character` | 当前运行状态、地图节点、实际调用人物 |
| `ctx.map_id` / `ctx.event_id` / `ctx.common_event_id` | 当前地图、事件和公共事件编号 |
| `ctx.fields` | 当前解释器/路线重试期间保留的可保存数据 |
| `ctx.wait(seconds)` | 必须 await；返回 false 表示调用已取消，菜单暂停期间不累计 |
| `ctx.retry(seconds=0)` | 写 `return ctx.retry(...)`，由现有解释器/路线调度器重试本条 |
| `ctx.fail(message)` | 首错停止，保留之前已经发生的修改 |

自动迁移的复杂事件使用 `ctx.api` 中的数值、集合和真值辅助方法，保留原大整数、Ruby 真值及集合规则；这些是可复用的 GDScript 接口。原角色、公式和自定义服务的兼容适配继续存在，不据此宣称全部业务类已经完成原生重写。

## 等待和存档

事件正文可以直接写异步等待：

```gdscript
if not await ctx.wait(0.5):
    return
ctx.set_switch(83, true)
```

调用只启动一次，并行解释器互不复用任务。取消、重开、换图或覆盖路线使旧上下文失效。被强制路线覆盖的异步动作取消后不重放前半段，恢复时继续下一动作。

活动 await 和尚未被解释器接收的完成结果不能序列化，期间拒绝存档。需要可保存的等待时，将进度放在 `ctx.fields`，并用 `return ctx.retry(seconds)`；原游标、等待和字段按现有存档机制恢复。

## 身份、兼容和开发位置

复制脚本、事件、事件页和路线时生成新身份，移动保留身份。绑定 SHA256 核对实际业务正文。普通新脚本的 false 返回正常结束，重试必须明确调用 `ctx.retry`；自动迁移的旧事件保留原分组和 false 返回规则。

`data/native_event_sources.json` 保存自动升级前后精确字节及只读来源校验值。只有两边均精确匹配时沿用旧定义指纹；用户额外修改正文、绑定或其它 JSON 字节后，兼容别名失效。原对象图、资源和生成方法校验继续执行。

- `scripts/importer/EventBodyEmitter.gd`：由事件 AST 生成实际业务正文。
- `scripts/importer/NativeEventImporter.gd`：迁移绑定、升级旧模板及记录精确来源。
- `runtime/scripts/00_Game/Game_ActorInit.gd`：角色初始化业务模块。
- `runtime/scripts/02_Event/NativeScriptSource.gd`：内部编译包装、行号映射与保存前检查。
- `runtime/scripts/02_Event/EventScriptAPI.gd` / `EventScriptValue.gd`：同一运行现场的业务接口及必要语义适配。
- `runtime/scripts/02_Event/NativeEventContext.gd`：公开上下文和取消保护。
- `addons/rgm_editor/03_Event/Editor_EventScript.gd`：正文代码框。

编辑器和附带转换器继续使用 `Editor_` 前缀。新增目录索引用 `tools/script_layout.py --refresh-index`，不得改写历史兼容路径字面量。图形、Message、标题、菜单仍按后续版本规划推进。

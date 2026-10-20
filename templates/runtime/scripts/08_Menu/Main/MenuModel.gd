## 职责：计算闪翼主菜单命令及解锁可用状态，为界面提供只读规则结果。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/Main/MenuModel.gd").方法名(...)。
##
## 调用接口：
##   static func initialize(state: Object) -> void
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func enabled(state: Object, command: int) -> bool
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 command（int；必填）：单条事件、界面或路线指令。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 公开常量：COMMANDS、DEFAULT_LOCKS。
## 接口说明结束。

extends RefCounted
## Source 0198.initialize: command order and variable 5 are shared game data.
## This model owns menu availability; the screen owns focus and rendering.
const Scripts = preload("../../10_Support/Scripting/ScriptRuntime.gd")
const COMMANDS = ["物品资源", "记录档案", "角色装备", "查看笔记", "神秘圆盘", "查看成就", "合成工艺", "游戏设置", "角色技能", "返回标题"]
const DEFAULT_LOCKS = [1, 1, 0, 0, 0, 0, 0, 1, 0, 1]


static func initialize(state: Object) -> void:
	if state.variables.get("5") is Array:
		return
	Scripts.call_transaction(
		state,
		{"source": "0198.initialize.MENU_LOCK"},
		func(env): return env.index_set({"__state_table": "variable"}, 5, DEFAULT_LOCKS.duplicate())
	)


static func enabled(state: Object, command: int) -> bool:
	var locks: Variant = state.variables.get("5")
	return locks is Array and command >= 0 and command < locks.size() and locks[command] == 1

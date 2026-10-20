## 职责：读取事件所需的按键状态和输入结果，协调等待及输入生命周期。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/02_Event/EventInput.gd").方法名(...)。
##
## 调用接口：
##   static func configure() -> void
##     用途：配置本实例使用的数据和依赖。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func pressed(code: int) -> bool
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func triggered() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
## 公开常量：ACTIONS、KEYS。
## 接口说明结束。

extends RefCounted
## RMXP button numbers; trigger and held queries share the same mapping.
const ACTIONS := {
	2: "ui_down",
	4: "ui_left",
	6: "ui_right",
	8: "ui_up",
	11: "rm_a",
	12: "rm_b",
	13: "rm_c",
	14: "rm_x",
	15: "rm_y",
	16: "rm_z",
	17: "rm_l",
	18: "rm_r"
}
const KEYS := {
	"rm_a": [KEY_SHIFT],
	"rm_b": [KEY_ESCAPE, KEY_X, KEY_KP_0],
	"rm_c": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z],
	"rm_x": [KEY_A],
	"rm_y": [KEY_S],
	"rm_z": [KEY_D],
	"rm_l": [KEY_Q, KEY_PAGEUP],
	"rm_r": [KEY_W, KEY_PAGEDOWN]
}


static func configure() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.keycode = key
			InputMap.action_add_event(action, event)


static func pressed(code: int) -> bool:
	configure()
	return ACTIONS.has(code) and Input.is_action_pressed(ACTIONS[code])


static func triggered() -> int:
	configure()
	var result := 0
	# Native scans ascending numbers and keeps the last simultaneous trigger.
	for code in ACTIONS:
		if Input.is_action_just_pressed(ACTIONS[code]):
			result = code
	return result

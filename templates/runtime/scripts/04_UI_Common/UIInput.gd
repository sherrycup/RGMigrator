## 职责：统一界面按键识别及重复规则，确认和取消只响应首次按下，导航允许重复。
##
## 调用方式：
##   界面控制器先accepts(event)再转发key(event)，并由所属Viewport标记输入已处理。
##   确认和取消不接受echo重复；导航按客户端指定列表接受重复，Message允许方向导航；数字输入用左右选位、上下调整。
##
## 调用接口：
##   static func key(event: InputEvent) -> int
##     用途：读取逻辑键码，缺失时使用物理键码。
##     参数 event（InputEvent；必填）：Godot输入事件；非按键、释放及空键码会被拒绝。
##     返回：Godot Key数值；非按键输入返回KEY_NONE。
##
##   static func accepts( event: InputEvent, navigation: Array = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN] ) -> bool
##     用途：判断本次界面按键是否应转发。
##     参数 event（InputEvent；必填）：Godot输入事件；非按键、释放及空键码会被拒绝。
##     参数 navigation（Array；默认值 [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN]）：允许echo重复的Godot导航键列表；默认方向键及PageUp/PageDown。
##     返回：首次按下或允许重复的导航按下返回true，其余返回false。
##
## 接口说明结束。

extends RefCounted


static func key(event: InputEvent) -> int:
	if not event is InputEventKey:
		return KEY_NONE
	return event.keycode if event.keycode != KEY_NONE else event.physical_keycode


static func accepts(
	event: InputEvent,
	navigation: Array = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN]
) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and key(event) != KEY_NONE
		and (not event.echo or key(event) in navigation)
	)

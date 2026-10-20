## 职责：在测试模式下显示事件执行位置、等待及诊断信息。
##
## 调用方式：
##   脚本由所属场景或插件挂载；下列回调由 Godot 调用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 对外信号：
##   back_requested()：由持有方发出，通知对应状态或操作结果。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(_delta: float) -> void
##     _delta：为保持原接口位置保留，本实现未读取此参数。
##   func _unhandled_key_input(event: InputEvent) -> void
##     event：输入事件或当前游戏事件对象，类型见签名。
##
## 接口说明结束。

extends CanvasLayer
signal back_requested
var game: Node
var _counter: Label


func _ready() -> void:
	layer = 10
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 8
	panel.offset_right = -8
	panel.offset_top = 8
	add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "0.21＋0.22 事件联合验收（退出恢复原进度）"
	content.add_child(title)
	var guide := Label.new()
	guide.text = "方向键移动，Z确认柜台人物；左下触碰点删除一次。"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(guide)
	_counter = Label.new()
	content.add_child(_counter)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	for scenario in ["flow", "input"]:
		var button := Button.new()
		button.text = "联合流程" if scenario == "flow" else "文本与按键"
		button.pressed.connect(func() -> void: game.start_event_test_scenario(scenario))
		buttons.add_child(button)
	var toggle := Button.new()
	toggle.text = "启停公共并行"
	toggle.pressed.connect(
		func() -> void:
			RuntimeState.set_event_switch(9008, not bool(RuntimeState.switches.get("9008", false)))
	)
	buttons.add_child(toggle)
	var back := Button.new()
	back.text = "退出（F7）"
	back.pressed.connect(func() -> void: back_requested.emit())
	buttons.add_child(back)


func _process(_delta: float) -> void:
	visible = (
		not game._dialogue.is_open()
		or int(game._dialogue._packet.get("position", RuntimeState.message_position)) != 0
	)
	_counter.text = (
		"确认 %d · 地图并行 %d / %d · 公共并行 %d · 删除后继续 %d · 自动 %d"
		% [
			RuntimeState.variables.get("9001", 0),
			RuntimeState.variables.get("9002", 0),
			RuntimeState.variables.get("9003", 0),
			RuntimeState.variables.get("9006", 0),
			RuntimeState.variables.get("9004", 0),
			RuntimeState.variables.get("9005", 0)
		]
	)
	_counter.text += (
		"\n循环 %d/%d · 累计 %d · 按键编号 %d"
		% [
			RuntimeState.variables.get("9011", 0),
			RuntimeState.variables.get("9010", 0),
			RuntimeState.variables.get("9012", 0),
			RuntimeState.variables.get("9013", 0)
		]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		back_requested.emit()
		get_viewport().set_input_as_handled()

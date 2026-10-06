class_name DialogueOverlay
extends CanvasLayer

signal message_confirmed
signal choice_selected(index: int)
signal number_confirmed(value: int)
signal closed

var _panel: PanelContainer
var _content: VBoxContainer
var _open := false


func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 30
	_panel.offset_top = 300
	_panel.offset_right = -30
	_panel.offset_bottom = -30
	_panel.visible = false
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_panel.add_child(_content)


func is_open() -> bool:
	return _open


func show_message(lines: Array) -> void:
	_show()
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "\n".join(lines)
	_content.add_child(label)
	var button := Button.new()
	button.text = "继续"
	button.pressed.connect(func() -> void:
		_hide()
		message_confirmed.emit()
	)
	_content.add_child(button)
	button.grab_focus()


func show_choices(choices: Array, cancel_type: int) -> void:
	_show()
	var label := Label.new()
	label.text = "请选择："
	_content.add_child(label)
	for index in choices.size():
		var button := Button.new()
		button.text = str(choices[index])
		var choose := func(selected: int) -> void:
			_hide()
			choice_selected.emit(selected)
		button.pressed.connect(choose.bind(index))
		_content.add_child(button)
	if cancel_type > 0:
		var cancel := Button.new()
		cancel.text = "取消"
		cancel.pressed.connect(func() -> void:
			_hide()
			choice_selected.emit(-1 if cancel_type == 5 else cancel_type - 1)
		)
		_content.add_child(cancel)


func show_number(variable_id: int, digits: int) -> void:
	_show()
	var label := Label.new()
	label.text = "输入变量 %d 的数值（最多 %d 位）：" % [variable_id, digits]
	_content.add_child(label)
	var input := SpinBox.new()
	input.min_value = 0
	input.max_value = pow(10, clampi(digits, 1, 8)) - 1
	_content.add_child(input)
	var button := Button.new()
	button.text = "确认"
	button.pressed.connect(func() -> void:
		_hide()
		number_confirmed.emit(int(input.value))
	)
	_content.add_child(button)
	input.get_line_edit().grab_focus()


func show_diagnostic(message: String) -> void:
	_show()
	var title := Label.new()
	title.text = "不支持的 RMXP 事件"
	title.add_theme_font_size_override("font_size", 20)
	_content.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = message + "\n\n详情请查看生成工程中的 migration_report.md。"
	_content.add_child(body)
	var button := Button.new()
	button.text = "关闭"
	button.pressed.connect(func() -> void:
		_hide()
		closed.emit()
	)
	_content.add_child(button)
	button.grab_focus()


func _show() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_open = true
	_panel.visible = true


func _hide() -> void:
	_open = false
	_panel.visible = false
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

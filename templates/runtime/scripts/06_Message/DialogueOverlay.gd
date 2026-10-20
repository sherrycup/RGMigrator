## 职责：呈现原生事件的文章、选项和数字输入，处理输入并返回消息结果。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/06_Message/DialogueOverlay.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func is_open() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func show_message(lines: Array, request_id: int = -1, options: Dictionary = {}) -> void
##     参数 lines（Array；必填）：按顺序排列的文章行或文本行。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     参数 options（Dictionary；默认值 {}）：本次操作的附加选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func show_choices( choices: Array, cancel_type: int, request_id: int = -1, options: Dictionary = {} ) -> void
##     参数 choices（Array；必填）：按显示顺序排列的选项文本。
##     参数 cancel_type（int；必填）：原选择指令的取消处理类型。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     参数 options（Dictionary；默认值 {}）：本次操作的附加选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func show_number( variable_id: int, digits: int, request_id: int = -1, options: Dictionary = {} ) -> void
##     参数 variable_id（int；必填）：原游戏变量编号。
##     参数 digits（int；必填）：数字输入允许的位数。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     参数 options（Dictionary；默认值 {}）：本次操作的附加选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func show_button(variable_id: int, request_id: int = -1, options: Dictionary = {}) -> void
##     参数 variable_id（int；必填）：原游戏变量编号。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     参数 options（Dictionary；默认值 {}）：本次操作的附加选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func show_event(payload: Dictionary, request_id: int = -1) -> void
##     参数 payload（Dictionary；必填）：消息或调用请求的结构化内容。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func show_diagnostic(message: String, request_id: int = -1) -> void
##     参数 message（String；必填）：提示或诊断文本。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func dismiss() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   message_confirmed()：由持有方发出，通知对应状态或操作结果。
##   choice_selected(index: int)：由持有方发出，通知对应状态或操作结果。
##     index：集合或列表中的位置索引。
##   number_confirmed(value: int)：由持有方发出，通知对应状态或操作结果。
##     value：需要读取、校验或写入的值。
##   closed()：当前窗口或页面关闭。
##   event_response(request_id: int, kind: String, value: Variant)：由持有方发出，通知对应状态或操作结果。
##     request_id：用于匹配响应、取消和等待的请求编号。
##     kind：消息、操作或对象的种类标识。
##     value：需要读取、校验或写入的值。
##   event_failed(request_id: int, message: String)：由持有方发出，通知对应状态或操作结果。
##     request_id：用于匹配响应、取消和等待的请求编号。
##     message：提示或诊断文本。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(_delta: float) -> void
##     _delta：为保持原接口位置保留，本实现未读取此参数。
##   func _unhandled_key_input(event: InputEvent) -> void
##     event：输入事件或当前游戏事件对象，类型见签名。
##
## 接口说明结束。

class_name DialogueOverlay
extends CanvasLayer
const Message = preload("res://runtime/scripts/02_Event/EventMessage.gd")
const Buttons = preload("res://runtime/scripts/02_Event/EventInput.gd")
signal message_confirmed
signal choice_selected(index: int)
signal number_confirmed(value: int)
signal closed
signal event_response(request_id: int, kind: String, value: Variant)
signal event_failed(request_id: int, message: String)
var _panel: PanelContainer
var _content: VBoxContainer
var _open := false
var _ui_revision := 0
var _packet: Dictionary = {}
var _pages: Array[Dictionary] = []
var _page := 0
var _request_id := -1
var _key_frame := 0
var _number: SpinBox
var _skin_visual: Control
var _gold: PanelContainer
var _flash_view: Control
var _flash_request_id = -1


func _ready() -> void:
	layer = 20
	Buttons.configure()
	_panel = PanelContainer.new()
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_panel.add_child(_content)
	_panel.hide()
	_gold = PanelContainer.new()
	_gold.hide()
	add_child(_gold)
	get_viewport().size_changed.connect(_layout)
	RuntimeState.system_settings_changed.connect(_refresh_skin)
	if RuntimeState.flash_messages != null:
		_flash_view = load("res://runtime/scripts/06_Message/MessageOverlay.gd").new()
		add_child(_flash_view)
		RuntimeState.flash_messages.responded.connect(_flash_respond)
		RuntimeState.flash_messages.rejected.connect(
			func(request_id: int, message: String): event_failed.emit(request_id, message)
		)


func is_open() -> bool:
	return (
		_open
		or (
			RuntimeState.flash_messages != null
			and RuntimeState.flash_messages.message_window_showing()
		)
	)


func show_message(lines: Array, request_id: int = -1, options: Dictionary = {}) -> void:
	var packet := options.duplicate()
	packet.merge({"kind": "message", "lines": lines}, true)
	show_event(packet, request_id)


func show_choices(
	choices: Array, cancel_type: int, request_id: int = -1, options: Dictionary = {}
) -> void:
	var packet := options.duplicate()
	packet.merge({"kind": "choice", "choices": choices, "cancel": cancel_type, "lines": []}, true)
	show_event(packet, request_id)


func show_number(
	variable_id: int, digits: int, request_id: int = -1, options: Dictionary = {}
) -> void:
	var packet := options.duplicate()
	packet.merge(
		{"kind": "number", "variable": variable_id, "digits": clampi(digits, 1, 8), "lines": []},
		true
	)
	show_event(packet, request_id)


func show_button(variable_id: int, request_id: int = -1, options: Dictionary = {}) -> void:
	var packet := options.duplicate()
	packet.merge(
		{
			"kind": "button",
			"variable": variable_id,
			"lines": ["请按一个 RM 按键（方向键、Shift、Esc/X、Enter/Z、A/S/D、Q/W）。"]
		},
		true
	)
	show_event(packet, request_id)


func show_event(payload: Dictionary, request_id: int = -1) -> void:
	if _flash_view != null and payload.get("kind") in ["message", "choice", "number"]:
		_flash_request_id = request_id
		var result = RuntimeState.flash_messages.present(
			payload, request_id, int(payload.get("event_id", 0))
		)
		if result.ok:
			return
		RuntimeState.report_diagnostic(result.message)
		event_failed.emit(request_id, result.message)
		show_diagnostic(result.message, -1)
		return
	_packet = payload.duplicate(true)
	_request_id = request_id
	_key_frame = Engine.get_process_frames()
	_page = 0
	_pages.clear()
	var lines: Array = _packet.get("lines", [])
	var formatted := Message.format("\n".join(lines))
	var font := ThemeDB.fallback_font
	var width := maxf(80, get_viewport().get_visible_rect().size.x - 80)
	var pieces: Array[Dictionary] = []
	var plain := ""
	var row := 0
	var x := 0.0
	# Paginate wrapping as well as source lines; keep input on the final page.
	for piece in formatted.pieces:
		for letter in str(piece.text):
			var advance := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			if letter == "\n" or (x > 0 and x + advance > width):
				row += 1
				x = 0
				if row == 4:
					_pages.append({"pieces": pieces, "text": plain, "gold": formatted.gold})
					pieces = []
					plain = ""
					row = 0
				else:
					pieces.append({"text": "\n", "color": piece.color})
					plain += "\n"
				if letter == "\n":
					continue
			pieces.append({"text": letter, "color": piece.color})
			plain += letter
			x += advance
	if not plain.is_empty() or _pages.is_empty():
		_pages.append({"pieces": pieces, "text": plain, "gold": formatted.gold})
	_render_page()


func show_diagnostic(message: String, request_id: int = -1) -> void:
	show_event(
		{
			"kind": "diagnostic",
			"lines": ["不支持的 RMXP 事件", message, "详情请查看 migration_report.md。"],
			"position": 1,
			"frame": 0
		},
		request_id
	)


func dismiss() -> void:
	if RuntimeState.flash_messages != null:
		RuntimeState.flash_messages.cancel_request(_flash_request_id)
	_hide()


func _flash_respond(request_id: int, kind: String, value: Variant) -> void:
	match kind:
		"message":
			message_confirmed.emit()
		"choice":
			choice_selected.emit(int(value))
		"number":
			number_confirmed.emit(int(value))
	event_response.emit(request_id, kind, value)


func _render_page() -> void:
	_ui_revision += 1
	_clear(_content)
	_clear(_gold)
	_number = null
	_open = true
	_panel.show()
	var revision := _ui_revision
	var formatted: Dictionary = _pages[_page]
	var colored := false
	for piece in formatted.pieces:
		if piece.color != 0:
			colored = true
	if colored:
		var rich := RichTextLabel.new()
		rich.fit_content = true
		rich.scroll_active = false
		for piece in formatted.pieces:
			rich.push_color(Message.COLORS[piece.color])
			rich.add_text(piece.text)
			rich.pop()
		_content.add_child(rich)
	else:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = formatted.text
		_content.add_child(label)
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color("18264de6")
		if int(_packet.get("frame", RuntimeState.message_frame)) == 0
		else Color.TRANSPARENT
	)
	style.border_color = Color("bcccf4")
	style.set_border_width_all(
		2 if int(_packet.get("frame", RuntimeState.message_frame)) == 0 else 0
	)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_refresh_skin()
	var final_page := _page == _pages.size() - 1
	match str(_packet.kind) if final_page else "page":
		"choice":
			for index in _packet.choices.size():
				var choice := Message.format(_packet.choices[index])
				_add_button(choice.text, func() -> void: _respond(index), revision, choice)
			if int(_packet.cancel) > 0:
				_add_button("取消", _cancel_choice, revision)
		"number":
			var hint := Label.new()
			hint.text = "输入数值（最多%d位）：" % int(_packet.digits)
			_content.add_child(hint)
			_number = SpinBox.new()
			_number.min_value = 0
			_number.max_value = pow(10, int(_packet.digits)) - 1
			_number.value = clampi(
				int(RuntimeState.variables.get(str(int(_packet.variable)), 0)),
				0,
				int(_number.max_value)
			)
			_content.add_child(_number)
			_add_button(
				"确认",
				func() -> void:
					_number.apply()
					_respond(int(_number.value)),
				revision
			)
			_number.get_line_edit().text_submitted.connect(
				func(_text: String) -> void:
					if _open and revision == _ui_revision:
						_number.apply()
						_respond(int(_number.value))
			)
			_number.get_line_edit().grab_focus()
		"button":
			pass
		"diagnostic":
			_add_button("关闭", func() -> void: _respond(null), revision)
		_:
			_add_button(
				"继续" if final_page else "下一页（%d/%d）" % [_page + 1, _pages.size()],
				_continue,
				revision
			)
	_gold.visible = formatted.gold
	if formatted.gold:
		var label := Label.new()
		label.text = (
			"%d %s"
			% [
				RuntimeState.gold,
				preload("res://runtime/scripts/00_Game/RuntimeData.gd").system().get("gold", "G")
			]
		)
		_gold.add_child(label)
	_layout()
	call_deferred("_layout")


func _refresh_skin() -> void:
	if _skin_visual != null:
		_panel.remove_child(_skin_visual)
		_skin_visual.queue_free()
		_skin_visual = null
	if RuntimeState.system_settings.windowskin_override == null:
		if _open:
			var fallback := StyleBoxFlat.new()
			fallback.bg_color = (
				Color("18264de6")
				if int(_packet.get("frame", RuntimeState.message_frame)) == 0
				else Color.TRANSPARENT
			)
			fallback.border_color = Color("bcccf4")
			fallback.set_border_width_all(
				2 if int(_packet.get("frame", RuntimeState.message_frame)) == 0 else 0
			)
			fallback.set_content_margin_all(12)
			_panel.add_theme_stylebox_override("panel", fallback)
		return
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", empty)
	if int(_packet.get("frame", 0)) != 0 or RuntimeState.windowskin_name().is_empty():
		return
	_skin_visual = Control.new()
	_skin_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin_visual.z_index = -1
	_panel.add_child(_skin_visual)
	# PanelContainer applies its content margins to direct children.
	_skin_visual.draw.connect(
		func() -> void:
			var area := Rect2(Vector2(-12, -12), _skin_visual.size + Vector2(24, 24))
			var cache := preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
			var name_value := RuntimeState.windowskin_name()
			var background: Texture2D = cache.region(
				"Windowskins", name_value, Rect2(0, 0, 128, 128)
			)
			var frame: Texture2D = cache.windowskin(name_value)
			if background != null:
				_skin_visual.draw_texture_rect(
					background, area.grow(-2), false, Color(1, 1, 1, 0.9)
				)
			if frame != null:
				RenderingServer.canvas_item_add_nine_patch(
					_skin_visual.get_canvas_item(),
					area,
					Rect2(128, 0, 64, 64),
					frame.get_rid(),
					Vector2(16, 16),
					Vector2(16, 16),
					RenderingServer.NINE_PATCH_STRETCH,
					RenderingServer.NINE_PATCH_STRETCH,
					false
				)
	)
	_skin_visual.resized.connect(_skin_visual.queue_redraw)


func _add_button(text: String, action: Callable, revision: int, formatted: Dictionary = {}) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(
		func() -> void:
			if _open and revision == _ui_revision:
				action.call()
	)
	_content.add_child(button)
	if formatted.get("pieces", []).any(func(piece: Dictionary) -> bool: return piece.color != 0):
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color, Color.TRANSPARENT)
		var rich := RichTextLabel.new()
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.scroll_active = false
		rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rich.offset_top = 4
		rich.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
		for piece in formatted.pieces:
			rich.push_color(Message.COLORS[piece.color])
			rich.add_text(piece.text)
			rich.pop()
		rich.pop()
		button.add_child(rich)
	if not _content.get_children().any(
		func(node: Node) -> bool: return node is Button and node != button
	):
		button.grab_focus()


func _continue() -> void:
	if _page < _pages.size() - 1:
		_page += 1
		_render_page()
	else:
		_respond(null)


func _cancel_choice() -> void:
	var cancel := int(_packet.get("cancel", 0))
	if cancel > 0:
		_respond(-1 if cancel == 5 else cancel - 1)


func _respond(value: Variant) -> void:
	var kind: String = _packet.kind
	var id := _request_id
	_hide()
	match kind:
		"message":
			message_confirmed.emit()
		"choice":
			choice_selected.emit(int(value))
		"number":
			number_confirmed.emit(int(value))
		"diagnostic":
			closed.emit()
	event_response.emit(id, kind, value)


func _process(_delta: float) -> void:
	if _open and _packet.get("kind") == "button" and Engine.get_process_frames() > _key_frame:
		var code := Buttons.triggered()
		if code > 0:
			_respond(code)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _packet.kind == "button":
		return
	if event.keycode in [KEY_ESCAPE, KEY_X]:
		if _page < _pages.size() - 1 or _packet.kind == "message":
			_continue()
		elif _packet.kind == "choice":
			_cancel_choice()
		elif _packet.kind == "diagnostic":
			_respond(null)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and _number == null:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _content.is_ancestor_of(focused):
			focused.pressed.emit()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	if not _open:
		return
	var viewport := get_viewport().get_visible_rect().size
	var margin := 24.0
	var width := maxf(120, viewport.x - margin * 2)
	_panel.size.x = width
	var height := maxf(152, _panel.get_combined_minimum_size().y)
	var position := int(_packet.get("position", RuntimeState.message_position))
	var y := (
		margin
		if position == 0
		else ((viewport.y - height) / 2 if position == 1 else viewport.y - margin - height)
	)
	_panel.position = Vector2(margin, maxf(0, y))
	_panel.size = Vector2(width, height)
	_gold.size = _gold.get_combined_minimum_size()
	_gold.position = Vector2(
		viewport.x - margin - _gold.size.x,
		viewport.y - margin - _gold.size.y if position == 0 else margin
	)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _hide() -> void:
	_ui_revision += 1
	_open = false
	_panel.hide()
	_gold.hide()
	_clear(_content)
	_clear(_gold)

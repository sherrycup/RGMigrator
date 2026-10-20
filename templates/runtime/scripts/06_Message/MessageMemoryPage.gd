## 职责：展示已记录的闪翼消息历史，处理滚动、选取和返回。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/06_Message/MessageMemoryPage.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func check_text() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func plain_text(raw: String) -> String
##     参数 raw（String；必填）：尚未解释的原始值或文本。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   close_requested()：由持有方发出，通知对应状态或操作结果。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _draw() -> void
##
## 接口说明结束。

extends Control
## 0157/0200/0202: L history, Tab channels, latest entry selected, source limits.
signal close_requested
const Text = preload("MessageText.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
var page = "flash_history"
var mode_index = 0
var index = 0
var records: Array = []
var _content: Control
var _scroll: ScrollContainer
var _selected: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(refresh)
	check_text()


func check_text() -> void:
	records = RuntimeState.flash_messages.history(mode_index == 1)
	index = maxi(0, records.size() - 1)
	refresh()


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _content != null:
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	_label("剧情回顾", Rect2(24, 12, size.x - 48, 36), 24)
	_label("剧情文本" if mode_index == 0 else "主动信息", Rect2(size.x - 128, 64, 112, 32), 20)
	_label("Tab 切换", Rect2(size.x - 128, 108, 112, 32), 17)
	_label(
		"%d / %d" % [0 if records.is_empty() else index + 1, records.size()],
		Rect2(size.x - 128, size.y - 100, 112, 32),
		20
	)
	_label("↑↓条目 · Esc返回", Rect2(24, size.y - 48, size.x - 48, 32), 17)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(24, 64)
	_scroll.size = Vector2(maxf(1, size.x - 172), maxf(1, size.y - 132))
	_content.add_child(_scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	_scroll.add_child(list)
	_selected = null
	for entry_id in records.size():
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(row)
		var name = Label.new()
		name.text = str(records[entry_id][0])
		name.custom_minimum_size.x = 96
		name.add_theme_font_override("font", Resources.font())
		name.add_theme_font_size_override("font_size", 18)
		name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(name)
		var separator = VSeparator.new()
		row.add_child(separator)
		var text = RichTextLabel.new()
		text.fit_content = true
		text.scroll_active = false
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.x = maxf(40, _scroll.size.x - 128)
		text.add_theme_font_override("normal_font", Resources.font())
		text.add_theme_font_size_override("normal_font_size", 18)
		text.add_theme_color_override("font_shadow_color", Color.BLACK)
		text.add_theme_constant_override("shadow_offset_x", 1)
		text.add_theme_constant_override("shadow_offset_y", 1)
		_fill_record(text, str(records[entry_id][1]))
		row.add_child(text)
		if entry_id == index:
			row.draw.connect(
				func(): row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 1, 1, 32.0 / 255))
			)
			_selected = row
	if _selected != null:
		_scroll.call_deferred("ensure_control_visible", _selected)
	queue_redraw()


func _fill_record(target: RichTextLabel, raw: String) -> void:
	var parsed = Text.parse(raw.replace("\\n", "\n"), RuntimeState)
	if not parsed.ok:
		target.add_text(parsed.message)
		return
	var style = Text.defaults()
	style.font_size = 18
	style.color = 0
	var merge_next = false
	var buffer = ""
	for token in parsed.tokens:
		if token is Array and token[0].unicode_at(0) == 18:
			merge_next = true
			continue
		if token is String and token == "\n" and merge_next:
			merge_next = false
			continue
		merge_next = false
		if token is String:
			buffer += token
		else:
			var code = token[0].unicode_at(0)
			if code == 2:
				buffer += (
					str(RuntimeState.custom_data.currency())
					+ str(
						preload("../00_Game/RuntimeData.gd").system().get("words", {}).get(
							"gold", ""
						)
					)
				)
			elif code == 24:
				_append_history_text(target, buffer, style)
				buffer = ""
				var icon = Cache.icon(str(token[1]))
				if icon != null:
					target.add_image(icon)
			elif code == 6:
				buffer += "\n"
			elif code in [1, 20, 21, 23, 25, 26]:
				_append_history_text(target, buffer, style)
				buffer = ""
				Text.apply_style(style, token)
	_append_history_text(target, buffer, style)


func _append_history_text(target: RichTextLabel, value: String, style: Dictionary) -> void:
	if value.is_empty():
		return
	var tint = Text.color(int(style.color))
	tint.a *= clampf(float(style.opacity) / 255, 0, 1)
	target.push_color(tint)
	target.push_font(Text.font(style))
	target.push_font_size(int(style.font_size))
	target.add_text(value)
	target.pop()
	target.pop()
	target.pop()


func plain_text(raw: String) -> String:
	var parsed = Text.parse(raw.replace("\\n", "\n"), RuntimeState)
	if not parsed.ok:
		return parsed.message
	var result = ""
	for token in parsed.tokens:
		if token is String:
			result += token
		elif token[0].unicode_at(0) == 2:
			result += (
				str(RuntimeState.custom_data.currency())
				+ str(
					preload("../00_Game/RuntimeData.gd").system().get("words", {}).get("gold", "")
				)
			)
	return result


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		close_requested.emit()
	elif key == KEY_TAB:
		mode_index = 1 - mode_index
		check_text()
	elif key in [KEY_UP, KEY_DOWN] and not records.is_empty():
		index = posmod(index + (1 if key == KEY_DOWN else -1), records.size())
		refresh()
	elif key in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_scroll.scroll_vertical += int(_scroll.size.y) * (1 if key == KEY_PAGEDOWN else -1)


func _label(text: String, rect: Rect2, font_size: int) -> void:
	var label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", Resources.font())
	label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 128.0 / 255))

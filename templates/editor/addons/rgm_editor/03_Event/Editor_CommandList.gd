## 职责：编辑地图与公共事件的指令列表，处理结构层级、整段选择和增删复制。
##
## 调用方式：
##   var list_editor = preload("res://addons/rgm_editor/03_Event/Editor_CommandList.gd").new()，加入编辑器节点后调用 configure(...)。
##   连接 changed(list) 接收完整草稿；用 draft() 取出深复制结果，再交给文档服务保存。
##
## 调用接口：
##   func configure(list: Array, documents: RefCounted, characters: Dictionary = {}) -> void
##     用途：安装独立指令草稿并建立名称显示所需的文档连接。
##     参数 list（Array；必填）：完整原指令数组；控件会深复制，续行和结构记录保留。
##     参数 documents（RefCounted；必填）：当前 Editor_Documents 实例，用于查询名称与发出编辑通知。
##     参数 characters（Dictionary；默认值 {}）：可选的人物编号与名称信息，用于指令参数显示。
##     返回：无返回值；刷新当前列表。
##
##   func draft() -> Array
##     用途：返回当前完整事件指令草稿。
##     参数：无。
##     返回：与控件内部状态隔离的深复制 Array。
##
## 对外信号：
##   changed(list: Array)：列表草稿变化时发出；list 是当前完整指令数组，外层可据此更新文档草稿。
##     list：待编辑或处理的有序记录列表。
##
## 注意：地图事件和公共事件共用该控件；configure 不写回游戏数据。
## 接口说明结束。

@tool
extends VBoxContainer
## Shared native command authoring for map pages and common events.
const Commands = preload("Editor_Commands.gd")
const CommandDialog = preload("Editor_CommandDialog.gd")
signal changed(list: Array)
var _documents: RefCounted
var _list: Array = []
var _characters: Dictionary = {}
var _command_list: Tree
var _command_dialog: ConfirmationDialog
var _status: Label
var _adding_command = false
var _command_index = 0
var _commands_clipboard: Array = []
var _rows: Array[TreeItem] = []
var _blocks: Array[Vector2i] = []
var _selected_block = Vector2i(-1, -1)
var _structures: Array[Dictionary] = []


func configure(list: Array, documents: RefCounted, characters: Dictionary = {}) -> void:
	if _documents != null and _documents.changed.is_connected(_refresh_labels):
		_documents.changed.disconnect(_refresh_labels)
	_documents = documents
	_list = list.duplicate(true)
	_characters = characters.duplicate(true)
	if _documents != null:
		_documents.changed.connect(_refresh_labels)
	if _command_list == null:
		_build()
	_refresh_commands()


func draft() -> Array:
	return _list.duplicate(true)


func _build() -> void:
	var buttons = HFlowContainer.new()
	add_child(buttons)
	for entry in [
		["添加", _add_command],
		["编辑", _edit_command],
		["删除", _delete_command],
		["复制", _copy_command],
		["粘贴", _paste_command],
		["↑", _move_command.bind(-1)],
		["↓", _move_command.bind(1)]
	]:
		var button = Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	_command_list = Tree.new()
	_command_list.hide_root = true
	_command_list.columns = 2
	_command_list.set_column_expand(1, false)
	_command_list.set_column_custom_minimum_width(1, 90)
	_command_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_command_list)
	_command_list.select_mode = Tree.SELECT_MULTI
	_command_list.allow_search = false
	_command_list.add_theme_constant_override("draw_guides", 0)
	var selection = StyleBoxFlat.new()
	selection.bg_color = Color("2874b8")
	selection.expand_margin_left = _command_list.get_theme_constant("item_margin")
	for style in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		_command_list.add_theme_stylebox_override(style, selection)
	var cursor = StyleBoxFlat.new()
	cursor.bg_color = Color.TRANSPARENT
	cursor.border_color = Color(1, 1, 1, 0.5)
	cursor.set_border_width_all(1)
	_command_list.add_theme_stylebox_override("cursor", cursor)
	_command_list.add_theme_stylebox_override("cursor_unfocused", cursor)
	_command_list.gui_input.connect(_select_input)
	_command_list.item_activated.connect(_edit_command)
	_command_dialog = CommandDialog.new()
	add_child(_command_dialog)
	_command_dialog.accepted.connect(_accept_command)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


func _refresh_labels() -> void:
	_refresh_commands(_selected_command(), false)


func _refresh_commands(selected: int = -1, emit_change: bool = true) -> void:
	if emit_change:
		changed.emit(draft())
	_rows.clear()
	_blocks.clear()
	_structures.clear()
	_selected_block = Vector2i(-1, -1)
	_command_list.clear()
	var root = _command_list.create_item()
	var list: Array = _list
	# Visual blocks group continuation records, not the bodies of conditions/loops.
	var start = 0
	while start < list.size():
		var c: Dictionary = list[start]
		var end = start + 1
		var next_code: int = {101: 401, 108: 408, 209: 509, 302: 605, 355: 655}.get(
			int(c.get("code", 0)), -1
		)
		if int(c.get("code", 0)) == 355 and c.has("_script_binding"):
			end = Commands.span(list, start).y
		else:
			while (
				next_code >= 0
				and end < list.size()
				and int(list[end].get("code", 0)) == next_code
				and int(list[end].get("indent", 0)) == int(c.get("indent", 0))
			):
				end += 1
		for i in range(start, end):
			_blocks.append(Vector2i(start, end))
		start = end
	# Structural guides belong to complete branches/loops. Command bars belong
	# to the current indentation level and only span their continuation records.
	for i in list.size():
		if int(list[i].get("code", 0)) not in [102, 111, 112]:
			continue
		var span = Commands.span(list, i)
		if span.x >= 0:
			_structures.append(
				{
					"start": span.x,
					"end": span.y,
					"indent": clampi(int(list[i].get("indent", 0)), 0, 20)
				}
			)
	var gutter = Image.create(12, 1, false, Image.FORMAT_RGBA8)
	gutter.fill(Color.TRANSPARENT)
	var gutter_texture = ImageTexture.create_from_image(gutter)
	var continuation = -1
	var block_indent = -1
	var prefix = ""
	for i in list.size():
		var c: Dictionary = list[i]
		var code = int(c.get("code", 0))
		var item = _command_list.create_item(root)
		item.set_metadata(0, i)
		_rows.append(item)
		var summary = Commands.summary(c, _documents, _characters)
		var indent = "    ".repeat(clampi(int(c.get("indent", 0)), 0, 20))
		item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
		item.set_text(0, indent + summary.left(180))
		item.set_icon(0, gutter_texture)
		item.set_custom_draw_callback(0, _draw_command.bind("", ""))
		item.set_tooltip_text(
			0,
			(
				summary
				+ "\n原编号 %d / 第%d条\n原参数：%s" % [code, i + 1, JSON.stringify(c.get("parameters", []))]
			)
		)
		var reason = Commands.Catalog.reason(code, c.get("parameters", []))
		if (
			code in [355, 655]
			and _blocks[i].x < i
			and int(list[_blocks[i].x].get("code", 0)) == 355
			and reason.is_empty()
			and not c.has("_editor_original")
		):
			# Bound source groups may contain adjacent355 records as well as655.
			# Both are source lines of the same visible script block.
			var text = str(c.parameters[0]).replace("\n", " ↵ ")
			item.set_text(0, indent)
			item.set_description(0, indent + text)
			item.set_custom_draw_callback(0, _draw_command.bind(indent + "脚本：", text.left(180)))
		elif code in [101, 108, 355] and reason.is_empty() and not c.has("_editor_original"):
			continuation = {101: 401, 108: 408, 355: 655}[code]
			block_indent = int(c.get("indent", 0))
			prefix = Commands.summary(Commands.command(code, 0, [""]), _documents, _characters)
		elif (
			code == continuation
			and int(c.get("indent", 0)) == block_indent
			and reason.is_empty()
			and not c.has("_editor_original")
		):
			# Native text keeps branch guides in place; the body starts after the
			# measured first-line label. No padding is added to the source text.
			item.set_text(0, indent)
			item.set_description(0, indent + summary)
			item.set_custom_draw_callback(0, _draw_command.bind(indent + prefix, summary.left(180)))
		else:
			continuation = -1
		preload("Editor_CommandColors.gd").apply(
			_command_list, item, code, c.has("_editor_original") or not reason.is_empty()
		)
		if c.has("_editor_original"):
			item.set_text(1, "脚本占位")
			item.set_tooltip_text(1, "原代码与未知字段保留；编辑器不执行Ruby。")
		elif not reason.is_empty():
			item.set_text(1, "未支持·保留")
			item.set_tooltip_text(1, reason)
		item.set_meta("category_color", item.get_custom_color(0))
		item.set_meta(
			"status_color",
			(
				item.get_custom_color(1)
				if c.has("_editor_original") or not reason.is_empty()
				else _command_list.get_theme_color("font_color")
			)
		)
	if selected >= 0:
		_select_block(selected)


func _draw_command(item: TreeItem, rect: Rect2, prefix: String, text: String) -> void:
	var index = int(item.get_metadata(0))
	var block = _blocks[index]
	var canvas = _command_list.get_custom_drawing_canvas_item()
	var color = item.get_custom_color(0)
	# The callback rect excludes native inner margins; extend through those
	# margins so adjacent continuation segments meet at the row boundary.
	var top = (
		rect.position.y
		- _command_list.get_theme_constant("inner_item_margin_top")
		+ (4 if index == block.x else 0)
	)
	var bottom = (
		rect.end.y
		+ _command_list.get_theme_constant("inner_item_margin_bottom")
		- (4 if index == block.y - 1 else 0)
	)
	var font = _command_list.get_theme_font("font")
	var font_size = _command_list.get_theme_font_size("font_size")
	var gutter = 12 + _command_list.get_theme_constant("icon_h_separation")
	var branch_width = font.get_string_size("    ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var command_x = (
		rect.position.x + 6 + branch_width * clampi(int(_list[index].get("indent", 0)), 0, 20)
	)
	RenderingServer.canvas_item_add_line(
		canvas, Vector2(command_x, top), Vector2(command_x, bottom), color, 2
	)
	for structure in _structures:
		if index < structure.start or index >= structure.end:
			continue
		var x = rect.position.x + 6 + branch_width * structure.indent
		var structure_top = (
			rect.position.y
			- _command_list.get_theme_constant("inner_item_margin_top")
			+ (4 if index == structure.start else 0)
		)
		var structure_bottom = (
			rect.end.y
			+ _command_list.get_theme_constant("inner_item_margin_bottom")
			- (4 if index == structure.end - 1 else 0)
		)
		var guide_color = _rows[structure.start].get_meta("category_color")
		if item.is_selected(0):
			guide_color = Color.WHITE
		RenderingServer.canvas_item_add_line(
			canvas, Vector2(x, structure_top), Vector2(x, structure_bottom), guide_color, 1
		)
	var offset = gutter + font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text.is_empty() or rect.size.x <= offset:
		return
	var line = TextLine.new()
	line.add_string(text, font, font_size)
	line.width = rect.size.x - offset
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var position = rect.position + Vector2(offset, floor((rect.size.y - line.get_size().y) / 2))
	line.draw(canvas, position, color)


func _clear_block() -> void:
	if _selected_block.x >= 0:
		for i in range(_selected_block.x, _selected_block.y):
			var row = _rows[i]
			row.set_custom_color(0, row.get_meta("category_color"))
			row.set_custom_color(1, row.get_meta("status_color"))
	_command_list.deselect_all()
	_selected_block = Vector2i(-1, -1)


func _select_block(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	_clear_block()
	_selected_block = _blocks[index]
	# Solid full-width rows meet without borders, including empty continuations.
	for i in range(_selected_block.x, _selected_block.y):
		for column in 2:
			_rows[i].select(column, false)
			_rows[i].set_custom_color(column, Color.WHITE)
	_rows[_selected_block.x].select(0)
	_command_list.queue_redraw()


func _select_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_command_list.accept_event()
		if not event.pressed:
			return
		_command_list.grab_focus()
		var row = _command_list.get_item_at_position(event.position)
		if row == null:
			_clear_block()
			return
		_select_block(int(row.get_metadata(0)))
		if event.double_click:
			_edit_command()
	elif event is InputEventKey and event.pressed and not _rows.is_empty():
		if event.is_action_pressed("ui_accept"):
			_command_list.accept_event()
			_edit_command()
			return
		var index = _selected_command()
		var target = index
		match event.keycode:
			KEY_UP:
				target = maxi(0, index - 1)
			KEY_DOWN:
				target = mini(_rows.size() - 1, _blocks[index].y)
			KEY_HOME:
				target = 0
			KEY_END:
				target = _rows.size() - 1
			KEY_PAGEUP, KEY_PAGEDOWN:
				var direction = -1 if event.keycode == KEY_PAGEUP else 1
				var height = _command_list.get_item_area_rect(_rows[index]).size.y
				target = clampi(
					index + direction * maxi(1, int(_command_list.size.y / maxf(1, height))),
					0,
					_rows.size() - 1
				)
			_:
				return
		_command_list.accept_event()
		_select_block(target)
		_command_list.ensure_cursor_is_visible()


func _selected_command() -> int:
	var item = _command_list.get_selected()
	return (
		_blocks[int(item.get_metadata(0))].x
		if item != null and item.is_selected(0)
		else _list.size() - 1
	)


func _operation_span(index: int) -> Vector2i:
	if (
		index >= 0
		and index < _blocks.size()
		and int(_list[index].get("code", 0)) in [101, 108, 209, 302, 355]
	):
		return _blocks[index]
	return Commands.span(_list, index)


func _add_command() -> void:
	_adding_command = true
	_command_index = _selected_command()
	_command_dialog.open(_documents, 101, [], true, _character_targets())


func _character_targets() -> Dictionary:
	return _characters


func _edit_command() -> void:
	var list: Array = _list
	_command_index = _selected_command()
	var c: Dictionary = list[_command_index]
	var code = int(c.code)
	if code in Commands.MARKERS:
		return
	var p: Array = c.parameters.duplicate(true)
	var span = _operation_span(_command_index)
	if (
		code in [101, 108, 355]
		and not preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").is_native(
			c.get("_script_binding")
		)
	):
		for i in range(_command_index + 1, span.y):
			p[0] += "\n" + str(list[i].parameters[0])
	if code == 302:
		p = [p]
		for i in range(_command_index + 1, span.y):
			p.append(list[i].parameters.duplicate(true))
	_adding_command = false
	_command_dialog.open(_documents, code, p, false, _character_targets())
	if _command_dialog._native_editor.visible:
		_command_dialog._native_editor._legacy.text = JSON.stringify(
			c.get("_legacy_source", {}), "\t"
		)


func _insertion(list: Array, index: int) -> Vector2i:
	var c: Dictionary = list[index]
	var code = int(c.code)
	var indent = int(c.get("indent", 0))
	if code in [402, 403, 411]:
		return Vector2i(index + 1, indent + 1)
	if code in [404, 412, 413]:
		return Vector2i(index, indent + 1)
	return Vector2i(index, indent)


func _accept_command(code: int, p: Array) -> void:
	var list: Array = _list
	var index = _command_index
	var indent = int(list[index].get("indent", 0))
	var bound_script = not _adding_command and code == 355 and list[index].has("_script_binding")
	if bound_script:
		var span = _operation_span(index)
		var original_source = str(list[index].parameters[0])
		if not preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").is_native(
			list[index].get("_script_binding")
		):
			for position in range(index + 1, span.y):
				original_source += "\n" + str(list[position].parameters[0])
		if p == [original_source]:
			_refresh_commands(index)
			return
	var replacement: Array = []
	if code == 302:
		for i in p.size():
			replacement.append(Commands.command(302 if i == 0 else 605, indent, p[i]))
	else:
		replacement = Commands.expand(code, p, indent)
	if _adding_command:
		var place = _insertion(list, index)
		index = place.x
		for c in replacement:
			c.indent = place.y
	else:
		var span = _operation_span(index)
		if span.x < 0:
			_status.text = "原指令缺少对应结束标记，请保留原数据。"
			return
		if code in [111, 112]:
			var original: Dictionary = list[index].duplicate(true)
			original.parameters = p.duplicate(true)
			if code == 111 and int(p[0]) == 12:
				original._script_binding = (
					preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
					. binding(str(p[1]), original.get("_script_binding", {}))
				)
			elif code == 111:
				original.erase("_script_binding")
			list[index] = original
			_refresh_commands(index)
			return
		if code == 102:
			var bodies: Dictionary = {}
			var current = -1
			for i in range(index + 1, span.y - 1):
				var c: Dictionary = list[i]
				if int(c.indent) == indent and int(c.code) in [402, 403]:
					current = int(c.parameters[0]) if int(c.code) == 402 else 5
					bodies[current] = []
				elif current >= 0:
					bodies[current].append(c.duplicate(true))
			for key in bodies:
				if (
					(int(key) >= p[0].size() and int(key) != 5 or int(key) == 5 and int(p[1]) != 5)
					and bodies[key].any(func(c: Variant) -> bool: return int(c.code) != 0)
				):
					_status.text = "减少选项前，请先移走对应分支中的指令。"
					return
			replacement = [Commands.command(102, indent, p)]
			for i in p[0].size():
				replacement.append(Commands.command(402, indent, [i, p[0][i]]))
				replacement.append_array(bodies.get(i, []))
			if int(p[1]) == 5:
				replacement.append(Commands.command(403, indent))
				replacement.append_array(bodies.get(5, []))
			replacement.append(Commands.command(404, indent))
		for key in list[index]:
			if key not in ["code", "parameters", "indent"]:
				replacement[0][key] = list[index][key]
		if code == 355 and replacement[0].has("_script_binding"):
			replacement[0]._script_binding = replacement[0]._script_binding.duplicate(true)
			replacement[0]._script_binding.command_count = replacement.size()
		for i in range(span.y - span.x):
			list.remove_at(index)
	if code == 355 or code == 111 and int(p[0]) == 12:
		replacement[0]._script_binding = (
			preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
			. binding(str(p[1] if code == 111 else p[0]), replacement[0].get("_script_binding", {}))
		)
	for i in replacement.size():
		list.insert(index + i, replacement[i])
	_refresh_commands(index)
	if bound_script:
		_status.text = "GDScript 已应用到草稿；保存事件后重新运行生效。"


func _copy_command() -> void:
	var list: Array = _list
	var index = _selected_command()
	if int(list[index].code) in Commands.MARKERS:
		return
	var span = _operation_span(index)
	if span.x >= 0:
		_commands_clipboard = list.slice(span.x, span.y).duplicate(true)


func _paste_command() -> void:
	if _commands_clipboard.is_empty():
		return
	var list: Array = _list
	var place = _insertion(list, _selected_command())
	var base = int(_commands_clipboard[0].indent)
	for i in _commands_clipboard.size():
		var c: Dictionary = (
			preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
			. copy_with_new_ids(_commands_clipboard[i])
		)
		c.indent = int(c.indent) - base + place.y
		list.insert(place.x + i, c)
	_refresh_commands(place.x)


func _delete_command() -> void:
	var list: Array = _list
	var index = _selected_command()
	if int(list[index].code) in Commands.MARKERS:
		return
	var span = _operation_span(index)
	if span.x < 0:
		return
	for i in span.y - span.x:
		list.remove_at(index)
	_refresh_commands(mini(index, list.size() - 1))


func _move_command(direction: int) -> void:
	var list: Array = _list
	var index = _selected_command()
	if int(list[index].code) in Commands.MARKERS:
		return
	var span = _operation_span(index)
	if span.x < 0:
		return
	var other = Vector2i(-1, -1)
	if (
		direction > 0
		and span.y < list.size()
		and int(list[span.y].code) not in Commands.MARKERS
		and int(list[span.y].indent) == int(list[index].indent)
	):
		other = _operation_span(span.y)
	elif direction < 0:
		for i in range(index - 1, -1, -1):
			if int(list[i].indent) < int(list[index].indent):
				break
			if (
				int(list[i].indent) == int(list[index].indent)
				and int(list[i].code) not in Commands.MARKERS
			):
				var candidate = _operation_span(i)
				if candidate.y == index:
					other = candidate
					break
	if other.x < 0:
		return
	var first = span if span.x < other.x else other
	var second = other if span.x < other.x else span
	var a = list.slice(first.x, first.y).duplicate(true)
	var b = list.slice(second.x, second.y).duplicate(true)
	for i in second.y - first.x:
		list.remove_at(first.x)
	var merged = b + a
	for i in merged.size():
		list.insert(first.x + i, merged[i])
	_refresh_commands(first.x if direction < 0 else first.x + b.size())

## 职责：编辑事件页的条件、图形、触发和移动参数，保留未识别的扩展字段。
##
## 调用方式：
##   通过 preload("res://addons/rgm_editor/03_Event/Editor_EventPageForm.gd") 读取本文件的常量或作为父类使用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 接口说明结束。

@tool
extends "../04_Database/Editor_ValueForm.gd"
## Direct controls and extension fields edit a detached draft.
var _groups: VBoxContainer
var _controls: Dictionary = {}
var _graphic: Control
var _syncing = false
var _tile_button: Button
var _tile_dialog: ConfirmationDialog
var _extension_button: Button
var _extension_dialog: ConfirmationDialog
var _extension_form: VBoxContainer


func _build() -> void:
	if _groups != null:
		return
	super._build()
	_tree.hide()
	get_child(0).hide()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_groups = VBoxContainer.new()
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_groups)
	var conditions = _group("出现条件")
	for pair in [
		["开关 1", "switch1_valid", "switch1_id"],
		["开关 2", "switch2_valid", "switch2_id"],
		["变量", "variable_valid", "variable_id"],
		["独立开关", "self_switch_valid", "self_switch_ch"]
	]:
		var row = HBoxContainer.new()
		conditions.add_child(row)
		_toggle(row, pair[0], ["condition", pair[1]])
		if pair[2] == "self_switch_ch":
			_choice(row, ["condition", pair[2]])
		else:
			_reference(row, ["condition", pair[2]])
		if pair[2] == "variable_id":
			var minimum_row = HBoxContainer.new()
			conditions.add_child(minimum_row)
			_label(minimum_row, "　变量下限 ≥")
			_spin(minimum_row, ["condition", "variable_value"], -99999999, 99999999)
	var graphic = _group("图形")
	var graphic_row = HBoxContainer.new()
	graphic.add_child(graphic_row)
	_graphic = preload("../05_Assets/Editor_AssetPreview.gd").new()
	_graphic.custom_minimum_size = Vector2(190, 200)
	graphic_row.add_child(_graphic)
	_graphic.activated.connect(
		func() -> void:
			if int(_value.graphic.tile_id) > 0:
				_open_tile_graphic()
			else:
				edit_asset(["graphic", "character_name"])
	)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphic_row.add_child(details)
	var row = HBoxContainer.new()
	details.add_child(row)
	_label(row, "朝向")
	_choice(row, ["graphic", "direction"])
	row = HBoxContainer.new()
	details.add_child(row)
	_label(row, "帧")
	_spin(row, ["graphic", "pattern"], 0, 3)
	row = HBoxContainer.new()
	details.add_child(row)
	_label(row, "色相")
	_spin(row, ["graphic", "character_hue"], 0, 360)
	row = HBoxContainer.new()
	details.add_child(row)
	_label(row, "不透明度")
	_spin(row, ["graphic", "opacity"], 0, 255)
	row = HBoxContainer.new()
	details.add_child(row)
	_label(row, "混合方式")
	_choice(row, ["graphic", "blend_type"])
	row = HBoxContainer.new()
	graphic.add_child(row)
	var character_button = Button.new()
	character_button.text = "行走图素材…"
	row.add_child(character_button)
	character_button.pressed.connect(func() -> void: edit_asset(["graphic", "character_name"]))
	_tile_button = Button.new()
	_tile_button.text = "当前地图图块…"
	row.add_child(_tile_button)
	_tile_button.pressed.connect(_open_tile_graphic)
	row = HBoxContainer.new()
	graphic.add_child(row)
	_label(row, "图块编号")
	_spin(row, ["graphic", "tile_id"], 0, 999999)
	var note = Label.new()
	note.text = "0 = 使用行走图"
	row.add_child(note)
	var movement = _group("自主移动")
	row = HBoxContainer.new()
	movement.add_child(row)
	_label(row, "方式")
	_choice(row, ["move_type"])
	var route = Button.new()
	route.text = "设置移动路线…"
	row.add_child(route)
	route.pressed.connect(func() -> void: edit_path(["move_route"]))
	row = HBoxContainer.new()
	movement.add_child(row)
	_label(row, "速度")
	_spin(row, ["move_speed"], 1, 6)
	_label(row, "频度")
	_spin(row, ["move_frequency"], 1, 6)
	var behavior = _group("选项与触发")
	var grid = GridContainer.new()
	grid.columns = 2
	behavior.add_child(grid)
	for entry in [
		["行走动画", "walk_anime"],
		["踏步动画", "step_anime"],
		["固定朝向", "direction_fix"],
		["穿透", "through"],
		["置顶", "always_on_top"]
	]:
		_toggle(grid, entry[0], [entry[1]])
	row = HBoxContainer.new()
	behavior.add_child(row)
	_label(row, "触发方式")
	_choice(row, ["trigger"])
	_extension_button = Button.new()
	_extension_button.text = "工程扩展字段…"
	_extension_button.tooltip_text = "仅显示原工程额外保存的字段；常用事件属性在上方设置。"
	_groups.add_child(_extension_button)
	_extension_button.pressed.connect(_open_extensions)


func _open_tile_graphic() -> void:
	var tileset: Dictionary = _hints.get("", {}).get("tileset", {})
	if tileset.is_empty():
		return
	if _tile_dialog == null:
		_tile_dialog = preload("../02_Map/Editor_TileGraphicDialog.gd").new()
		add_child(_tile_dialog)
		_tile_dialog.accepted.connect(
			func(id: int) -> void:
				if id > 0 and id == int(_value.graphic.tile_id):
					return
				var graphic: Dictionary = _value.graphic.duplicate(true)
				graphic.tile_id = id
				graphic.character_name = ""
				graphic.character_hue = 0
				_put(["graphic"], graphic)
		)
	_tile_dialog.open(_documents, tileset, _value.graphic)


func _extension_values() -> Dictionary:
	var known = preload("../01_Documents/Editor_Documents.gd").new().new_page()
	var result: Dictionary = {}
	for key in _value:
		if str(key).begins_with("_"):
			continue
		if not known.has(key):
			result[key] = _value[key]
		elif key in ["condition", "graphic", "move_route"] and _value[key] is Dictionary:
			var extra: Dictionary = {}
			for child in _value[key]:
				if not str(child).begins_with("_") and not known[key].has(child):
					extra[child] = _value[key][child]
			if not extra.is_empty():
				result[key] = extra
	return result.duplicate(true)


func _open_extensions() -> void:
	var extra = _extension_values()
	if extra.is_empty():
		return
	if _extension_dialog == null:
		_extension_dialog = ConfirmationDialog.new()
		_extension_dialog.title = "工程扩展字段 · 常用属性在主窗口设置"
		_extension_dialog.get_ok_button().text = "应用扩展字段"
		add_child(_extension_dialog)
		_extension_form = preload("../04_Database/Editor_ValueForm.gd").new()
		_extension_form.custom_minimum_size = Vector2(620, 400)
		_extension_dialog.add_child(_extension_form)
		_extension_dialog.confirmed.connect(
			func() -> void:
				var edited: Dictionary = _extension_form.draft()
				var current: Dictionary = draft()
				var allowed = _extension_values()
				for key in allowed:
					if not edited.has(key):
						continue
					if key in ["condition", "graphic", "move_route"]:
						for child in allowed[key]:
							if edited[key].has(child):
								current[key][child] = edited[key][child]
					else:
						current[key] = edited[key]
				_put([], current)
		)
	_extension_form.configure(
		extra,
		{"condition": "出现条件的扩展字段", "graphic": "图形的扩展字段", "move_route": "移动路线的扩展字段"},
		_documents
	)
	_extension_dialog.popup_centered(Vector2i(700, 520))


func _group(text: String) -> VBoxContainer:
	var panel = PanelContainer.new()
	_groups.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	margin.add_child(box)
	var heading = Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	box.add_child(heading)
	return box


func _label(parent: Node, text: String) -> void:
	var label = Label.new()
	label.text = text
	parent.add_child(label)


func _key(path: Array) -> String:
	return "/".join(path.map(func(k: Variant) -> String: return str(k)))


func _toggle(parent: Node, text: String, path: Array) -> void:
	var check = CheckBox.new()
	check.text = text
	parent.add_child(check)
	_controls[_key(path)] = {"path": path, "control": check}
	check.toggled.connect(
		func(enabled: bool) -> void:
			if not _syncing:
				_put(path, enabled)
	)


func _spin(parent: Node, path: Array, minimum: int, maximum: int) -> void:
	var spin = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	_controls[_key(path)] = {"path": path, "control": spin}
	spin.value_changed.connect(
		func(v: float) -> void:
			if not _syncing:
				_put(path, int(v))
	)


func _reference(parent: Node, path: Array) -> void:
	var button = Button.new()
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.x = 90
	parent.add_child(button)
	_controls[_key(path)] = {"path": path, "control": button}
	button.pressed.connect(func() -> void: edit_path(path))


func _choice(parent: Node, path: Array) -> void:
	var choice = OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(choice)
	_controls[_key(path)] = {"path": path, "control": choice}
	choice.item_selected.connect(
		func(i: int) -> void:
			if not _syncing:
				_put(path, choice.get_item_metadata(i))
	)


func _refresh() -> void:
	super._refresh()
	if _groups == null or not _value is Dictionary:
		return
	_asset_scroll.hide()
	_syncing = true
	for entry in _controls.values():
		var value: Variant = _read_at(entry.path)
		var control: Control = entry.control
		if control is CheckBox:
			control.set_pressed_no_signal(bool(value))
		elif control is SpinBox:
			control.value = float(value)
		elif control is OptionButton:
			control.clear()
			var options: Dictionary = _hint(entry.path).get("options", {})
			for key in options:
				var native: Variant = str(key) if value is String else int(key)
				control.add_item(str(options[key]))
				control.set_item_metadata(control.item_count - 1, native)
				if native == value:
					control.select(control.item_count - 1)
			var found = false
			for i in control.item_count:
				if control.get_item_metadata(i) == value:
					found = true
			if not found:
				control.add_item("保留原值：" + str(value))
				control.set_item_metadata(control.item_count - 1, value)
				control.select(control.item_count - 1)
		else:
			control.text = _display(value, entry.path)
			control.tooltip_text = control.text
		if (
			entry.path.size() == 2
			and entry.path[0] == "condition"
			and not str(entry.path[1]).ends_with("valid")
		):
			var enabled = bool(
				_value.condition.get(
					{
						"switch1_id": "switch1_valid",
						"switch2_id": "switch2_valid",
						"variable_id": "variable_valid",
						"variable_value": "variable_valid",
						"self_switch_ch": "self_switch_valid"
					}[entry.path[1]],
					false
				)
			)
			if control is BaseButton:
				control.disabled = not enabled
			elif control is SpinBox:
				control.editable = enabled
	var graphic: Dictionary = _value.graphic
	var category = "Characters"
	var asset_name = str(graphic.character_name)
	var preview_settings = graphic.duplicate()
	preview_settings.tileset = _hints.get("", {}).get("tileset", {})
	var caption = "事件行走图"
	if int(graphic.tile_id) >= 384:
		var tileset: Dictionary = _hints.get("", {}).get("tileset", {})
		category = "Tilesets"
		asset_name = str(tileset.get("tileset_name", ""))
		caption = "事件图块 · %04d" % int(graphic.tile_id)
	elif int(graphic.tile_id) > 0:
		var tileset: Dictionary = _hints.get("", {}).get("tileset", {})
		var names: Array = tileset.get("autotile_names", [])
		category = "Autotiles"
		asset_name = (
			str(names[int(graphic.tile_id) / 48 - 1])
			if int(graphic.tile_id) / 48 - 1 in range(names.size())
			else ""
		)
		caption = "事件图块 · %04d" % int(graphic.tile_id)
	_graphic.configure(_documents, category, asset_name, preview_settings, false, true, caption)
	_tile_button.disabled = _hints.get("", {}).get("tileset", {}).is_empty()
	_tile_button.tooltip_text = (
		"从本地图绑定的数据库图块集点选事件外观。" if not _tile_button.disabled else "此处没有当前地图图块集。"
	)
	_extension_button.visible = not _extension_values().is_empty()
	_syncing = false

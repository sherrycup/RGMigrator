## 职责：组织图块集编辑工作区，编辑通行、层级及素材配置并提交当前条目。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/02_Map/Editor_TilesetEditor.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(value: Dictionary, documents: RefCounted) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draft() -> Dictionary
##     用途：取得可交给调用方的独立编辑草稿。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 对外信号：
##   sources_requested()：由持有方发出，通知对应状态或操作结果。
##
## 公开常量：BACKGROUND_FIELDS。
## 接口说明结束。

@tool
extends VBoxContainer
## Persistent tileset workspace; only applying the database item changes documents.
const Canvas = preload("Editor_MapCanvas.gd")
const Schema = preload("../04_Database/Editor_DatabaseSchema.gd")
const Preview = preload("../05_Assets/Editor_AssetPreview.gd")
const BACKGROUND_FIELDS = [
	"panorama_hue", "fog_hue", "fog_opacity", "fog_blend_type", "fog_zoom", "fog_sx", "fog_sy"
]
signal sources_requested
var _value: Dictionary = {}
var _documents: RefCounted
var _canvas: Control
var _palette_scroll: ScrollContainer
var _tabs: TabContainer
var _asset_scroll: ScrollContainer
var _name: LineEdit
var _id: SpinBox
var _label: Label
var _source_label: Label
var _directions: Array[CheckBox] = []
var _bush: CheckBox
var _counter: CheckBox
var _group: CheckBox
var _priority: SpinBox
var _terrain: SpinBox
var _loading = false
var _mode = "passages"
var _stroke_value = -1
var _direction_brush = 0
var _mode_buttons: Dictionary = {}
var _previews: Dictionary = {}
var _background_controls: Dictionary = {}
var _asset_dialog: ConfirmationDialog
var _asset_path: Array = []


func configure(value: Dictionary, documents: RefCounted) -> void:
	var selected = (
		int(_id.value)
		if _id != null and _documents == documents and _value.get("id") == value.get("id")
		else -1
	)
	_value = value.duplicate(true)
	_documents = documents
	if _canvas == null:
		_build()
	_loading = true
	_name.text = str(_value.get("name", ""))
	_canvas.configure_tileset(_value, documents)
	_canvas._tileset = _value
	var length = 384 + _canvas._normal_layout.tile_count
	for key in ["passages", "priorities", "terrain_tags"]:
		length = maxi(length, _value.get(key, {}).get("values", []).size())
	_id.max_value = length - 1
	_id.value = selected if selected >= 0 and selected < length else 384 if length > 384 else 48
	_canvas.set_property_mode(_mode)
	_stroke_value = -1
	_refresh_assets()
	_loading = false
	_select(int(_id.value))


func draft() -> Dictionary:
	return _value.duplicate(true)


func _build() -> void:
	var header = HBoxContainer.new()
	add_child(header)
	var title_label = Label.new()
	title_label.text = "名称"
	header.add_child(title_label)
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name)
	_name.text_changed.connect(
		func(text: String) -> void:
			if not _loading:
				_value.name = text
	)
	var sources = Button.new()
	sources.text = "普通图块素材…"
	header.add_child(sources)
	sources.pressed.connect(func() -> void: sources_requested.emit())
	var modes = HFlowContainer.new()
	add_child(modes)
	var buttons = ButtonGroup.new()
	for pair in [
		["通行 ○/×", "passages"],
		["方向通行", "directions"],
		["优先级 ★", "priorities"],
		["草丛", "bush"],
		["柜台", "counter"],
		["地形", "terrain_tags"]
	]:
		var button = Button.new()
		button.text = pair[0]
		button.toggle_mode = true
		button.button_group = buttons
		modes.add_child(button)
		_mode_buttons[pair[1]] = button
		button.pressed.connect(_set_mode.bind(str(pair[1])))
	_mode_buttons[_mode].button_pressed = true
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var palette_box = VBoxContainer.new()
	palette_box.custom_minimum_size.x = 400
	split.add_child(palette_box)
	var palette_title = Label.new()
	palette_title.text = "图块画布 · 顶行是自动图块"
	palette_box.add_child(palette_title)
	_palette_scroll = ScrollContainer.new()
	_palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_box.add_child(_palette_scroll)
	_canvas = Canvas.new()
	_canvas.set_palette_zoom(1.5)
	_palette_scroll.add_child(_canvas)
	_canvas.tile_selected.connect(_paint_tile)
	_canvas.stroke_finished.connect(func() -> void: _stroke_value = -1)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.x = 310
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_tabs)
	var property_scroll = ScrollContainer.new()
	property_scroll.name = "图块属性"
	property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(property_scroll)
	var fields = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_scroll.add_child(fields)
	_label = Label.new()
	fields.add_child(_label)
	_source_label = Label.new()
	_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(_source_label)
	var id_row = HBoxContainer.new()
	fields.add_child(id_row)
	var id_label = Label.new()
	id_label.text = "图块编号"
	id_row.add_child(id_label)
	_id = SpinBox.new()
	_id.min_value = 0
	_id.step = 1
	_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(_id)
	_id.value_changed.connect(
		func(n: float) -> void:
			if not _loading:
				_select(int(n))
	)
	_group = CheckBox.new()
	_group.text = "自动图块：48种形状共用设置"
	fields.add_child(_group)
	_group.button_pressed = true
	var bar = HFlowContainer.new()
	fields.add_child(bar)
	for mode in [0, 15]:
		var button = Button.new()
		button.text = "全部通行 ○" if mode == 0 else "全部禁止 ×"
		bar.add_child(button)
		button.pressed.connect(_all.bind(mode))
	var directions = GridContainer.new()
	directions.columns = 2
	fields.add_child(directions)
	for text in ["允许向下 ↓", "允许向左 ←", "允许向右 →", "允许向上 ↑"]:
		_directions.append(_check(directions, text, "directions"))
	var flags = HFlowContainer.new()
	fields.add_child(flags)
	_bush = _check(flags, "草丛（下半身半透明）", "bush")
	_counter = _check(flags, "柜台（隔格对话）", "counter")
	for entry in [["显示优先级（0…5）", 5, "priorities"], ["地形标记（0…7）", 7, "terrain_tags"]]:
		var row = HBoxContainer.new()
		fields.add_child(row)
		var label = Label.new()
		label.text = entry[0]
		label.custom_minimum_size.x = 160
		row.add_child(label)
		var spin = SpinBox.new()
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.min_value = 0
		spin.max_value = entry[1]
		spin.step = 1
		spin.allow_greater = true
		spin.allow_lesser = true
		row.add_child(spin)
		spin.value_changed.connect(func(_n: float) -> void: _commit(str(entry[2])))
		if entry[1] == 5:
			_priority = spin
		else:
			_terrain = spin
	var note = Label.new()
	note.text = "点格或拖动涂改当前属性。方向通行使用右侧设置；优先级和地形点格循环取值。优先级0为地面。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(note)
	_asset_scroll = ScrollContainer.new()
	_asset_scroll.name = "自动图块与背景"
	_asset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(_asset_scroll)
	var assets = VBoxContainer.new()
	assets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_scroll.add_child(assets)
	var hint = Label.new()
	hint.text = "双击图片更换素材。普通图块在左侧画布中显示。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assets.add_child(hint)
	var pictures = HFlowContainer.new()
	assets.add_child(pictures)
	for slot in 7:
		_add_preview(pictures, ["autotile_names", slot], "自动图块 %d" % (slot + 1), "Autotiles")
	for entry in [
		["panorama_name", "全景图像", "Panoramas"],
		["fog_name", "雾图像", "Fogs"],
		["battleback_name", "战斗背景（元数据）", "Battlebacks"]
	]:
		_add_preview(pictures, [entry[0]], entry[1], entry[2])
	for key in BACKGROUND_FIELDS:
		var row = HBoxContainer.new()
		assets.add_child(row)
		var label = Label.new()
		label.text = Schema.LABELS[key]
		label.custom_minimum_size.x = 130
		row.add_child(label)
		var control: Control
		if key == "fog_blend_type":
			var options = OptionButton.new()
			control = options
			for text in ["正常", "加算", "减算"]:
				options.add_item(text)
				options.set_item_metadata(options.item_count - 1, options.item_count - 1)
			options.item_selected.connect(
				func(index: int) -> void:
					if not _loading:
						_value[key] = int(options.get_item_metadata(index))
			)
		else:
			var spin = SpinBox.new()
			control = spin
			spin.step = 1
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.min_value = -256 if key in ["fog_sx", "fog_sy"] else 0
			spin.max_value = 360 if key.ends_with("_hue") else 255 if key == "fog_opacity" else 800
			spin.value_changed.connect(
				func(n: float) -> void:
					if not _loading:
						_value[key] = int(n)
						_refresh_assets()
			)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(control)
		_background_controls[key] = control


func _add_preview(parent: Node, path: Array, caption: String, category: String) -> void:
	var preview = Preview.new()
	preview.custom_minimum_size = Vector2(170, 140)
	parent.add_child(preview)
	preview.activated.connect(_edit_asset.bind(path))
	_previews[str(path)] = {
		"control": preview, "path": path, "caption": caption, "category": category
	}


func _refresh_assets() -> void:
	for entry in _previews.values():
		var path: Array = entry.path
		var name = (
			str(_value.get(path[0], ""))
			if path.size() == 1
			else str(_value.get("autotile_names", [])[path[1]])
		)
		entry.control.configure(
			_documents, entry.category, name, _asset_settings(path), false, true, entry.caption
		)
	var was_loading = _loading
	_loading = true
	for key in _background_controls:
		var control: Control = _background_controls[key]
		control.get_parent().visible = _value.has(key)
		if not _value.has(key):
			continue
		if control is SpinBox:
			control.value = float(_value[key])
		else:
			while control.item_count > 3:
				control.remove_item(3)
			var value = int(_value[key])
			var index = value
			if value < 0 or value > 2:
				control.add_item("原工程值 %d" % value)
				index = 3
				control.set_item_metadata(3, value)
			control.select(index)
	_loading = was_loading


func _asset_settings(path: Array) -> Dictionary:
	if path.size() != 1:
		return {}
	var prefix = str(path[0]).trim_suffix("_name")
	var settings: Dictionary = {}
	for key in ["hue", "opacity"]:
		if _value.has(prefix + "_" + key):
			settings[key] = _value[prefix + "_" + key]
	return settings


func _edit_asset(path: Array) -> void:
	if _asset_dialog == null:
		_asset_dialog = preload("../05_Assets/Editor_AssetDialog.gd").new()
		add_child(_asset_dialog)
		_asset_dialog.accepted.connect(_accept_asset)
	_asset_path = path.duplicate()
	var entry: Dictionary = _previews[str(path)]
	var name = (
		str(_value.get(path[0], "")) if path.size() == 1 else str(_value.autotile_names[path[1]])
	)
	_asset_dialog.open(_documents, entry.category, name, _asset_settings(path), entry.caption)


func _accept_asset(name: String, settings: Dictionary) -> void:
	if _asset_path.size() == 2:
		_value.autotile_names[_asset_path[1]] = name
		_canvas.configure_tileset(_value, _documents)
		_canvas._tileset = _value
		_canvas.set_property_mode(_mode)
		_canvas.select_tile(int(_id.value))
	else:
		_value[_asset_path[0]] = name
		var prefix = str(_asset_path[0]).trim_suffix("_name")
		for key in ["hue", "opacity"]:
			if _value.has(prefix + "_" + key) and settings.has(key):
				_value[prefix + "_" + key] = int(settings[key])
	_refresh_assets()


func _set_mode(mode: String) -> void:
	_mode = mode
	_mode_buttons[mode].button_pressed = true
	_stroke_value = -1
	_canvas.set_property_mode(mode)
	_tabs.current_tab = 0


func _check(parent: Node, title_text: String, field: String) -> CheckBox:
	var box = CheckBox.new()
	box.text = title_text
	parent.add_child(box)
	box.toggled.connect(func(_on: bool) -> void: _commit(field))
	return box


func _select(id: int) -> void:
	if _value.is_empty():
		return
	_loading = true
	_id.value = id
	_canvas.select_tile(id)
	var flags = _flag("passages", id)
	for i in 4:
		_directions[i].button_pressed = (flags & (1 << i)) == 0
	_bush.button_pressed = (flags & 64) != 0
	_counter.button_pressed = (flags & 128) != 0
	_priority.value = _flag("priorities", id)
	_terrain.value = _flag("terrain_tags", id)
	_group.visible = id >= 48 and id < 384
	_label.text = (
		("普通图块" if id >= 384 else "自动图块 %d" % int(id / 48) if id >= 48 else "保留槽位")
		+ " · ID %d" % id
	)
	var source: Dictionary = _canvas._normal_layout.locate(id)
	_source_label.text = (
		"素材：" + str(source.get("name", ""))
		if id >= 384
		else "自动图块槽位 %d" % int(id / 48) if id >= 48 else "空图块"
	)
	_source_label.tooltip_text = "；".join(_canvas._normal_layout.errors)
	_loading = false


func _flag(key: String, id: int) -> int:
	var values: Array = _value.get(key, {}).get("values", [])
	return int(values[id]) if id >= 0 and id < values.size() else 0


func _ensure_flags() -> void:
	var length = int(_id.max_value) + 1
	for key in ["passages", "priorities", "terrain_tags"]:
		var table: Dictionary = _value.get(key, Schema.table(length))
		var values: Array = table.get("values", [])
		if values.size() < length:
			while values.size() < length:
				values.append(0)
			table.values = values
			table.x_size = length
			table.y_size = 1
			table.z_size = 1
			table.dimensions = 1
		_value[key] = table


func _indices() -> Array:
	var id = int(_id.value)
	return (
		range(int(id / 48) * 48, int(id / 48) * 48 + 48)
		if id >= 48 and id < 384 and _group.button_pressed
		else [id]
	)


func _commit(field: String) -> void:
	if _loading or _value.is_empty() or _priority == null or _terrain == null:
		return
	_ensure_flags()
	var flags = 0
	for i in 4:
		if not _directions[i].button_pressed:
			flags |= 1 << i
	if _bush.button_pressed:
		flags |= 64
	if _counter.button_pressed:
		flags |= 128
	for id in _indices():
		if field in ["priorities", "terrain_tags"]:
			_value[field].values[id] = int(
				_priority.value if field == "priorities" else _terrain.value
			)
		else:
			var mask = 64 if field == "bush" else 128 if field == "counter" else 15
			_value.passages.values[id] = (_flag("passages", id) & ~mask) | (flags & mask)
	_direction_brush = flags & 15
	_canvas.queue_redraw()


func _paint_tile(id: int) -> void:
	if id == 0:
		_select(id)
		return
	_ensure_flags()
	var flags = _flag("passages", id)
	if _stroke_value < 0:
		match _mode:
			"passages":
				_stroke_value = 0 if (flags & 15) == 15 else 15
			"directions":
				_stroke_value = _direction_brush
			"priorities":
				_stroke_value = (_flag("priorities", id) + 1) % 6
			"bush":
				_stroke_value = 0 if (flags & 64) != 0 else 64
			"counter":
				_stroke_value = 0 if (flags & 128) != 0 else 128
			"terrain_tags":
				_stroke_value = (_flag("terrain_tags", id) + 1) % 8
	_select(id)
	for tile in _indices():
		if _mode in ["priorities", "terrain_tags"]:
			_value[_mode].values[tile] = _stroke_value
		else:
			var mask = 64 if _mode == "bush" else 128 if _mode == "counter" else 15
			_value.passages.values[tile] = (_flag("passages", tile) & ~mask) | _stroke_value
	_select(id)
	_canvas.queue_redraw()


func _all(flags: int) -> void:
	_loading = true
	for i in 4:
		_directions[i].button_pressed = flags == 0
	_loading = false
	_commit("directions")

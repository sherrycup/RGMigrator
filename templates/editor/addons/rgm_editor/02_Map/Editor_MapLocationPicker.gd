## 职责：在实际地图预览上选择坐标，将结果返回调用方草稿。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/02_Map/Editor_MapLocationPicker.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(documents: RefCounted, map_id: int, cell: Vector2i) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 map_id（int；必填）：地图的原编号。
##     参数 cell（Vector2i；必填）：图块、动画或表格的单元记录。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   chosen(map_id: int, cell: Vector2i)：由持有方发出，通知对应状态或操作结果。
##     map_id：地图的原编号。
##     cell：图块、动画或表格的单元记录。
##   map_browsed(map_id: int)：由持有方发出，通知对应状态或操作结果。
##     map_id：地图的原编号。
##
## 接口说明结束。

@tool
extends VBoxContainer
## Click a real map preview; all edits remain in the caller's draft.
signal chosen(map_id: int, cell: Vector2i)
signal map_browsed(map_id: int)
var _documents: RefCounted
var _maps: ItemList
var _canvas: Control
var _label: Label
var _map_id = 0
var _map: Dictionary = {}
var _cell = Vector2i(-1, -1)
var _location_map = 0
var _location_cell = Vector2i(-1, -1)


func configure(documents: RefCounted, map_id: int, cell: Vector2i) -> void:
	if _canvas == null:
		_build()
	var different = _documents != documents or _location_map != map_id or _location_cell != cell
	_documents = documents
	_location_map = map_id
	_location_cell = cell
	if not different:
		return
	_maps.clear()
	var selected = -1
	var manifest: Variant = documents.read("data/manifest.json")
	var available: Array = []
	if manifest is Dictionary:
		for name in manifest.get("maps", []):
			available.append(str(name).trim_prefix("Map").to_int())
	for entry in documents.lookup("Maps"):
		if manifest is Dictionary and int(entry.id) not in available:
			continue
		_maps.add_item(entry.name)
		var index = _maps.item_count - 1
		_maps.set_item_metadata(index, entry.id)
		if int(entry.id) == map_id:
			selected = index
	if selected < 0 and _maps.item_count > 0:
		selected = 0
	if selected >= 0:
		_maps.select(selected)
		_load(int(_maps.get_item_metadata(selected)))
	else:
		_label.text = "当前工程没有可选择的地图。"
		_map = {}
		_canvas.update_map({})


func _build() -> void:
	var bar = HBoxContainer.new()
	add_child(bar)
	for entry in [
		["适应地图", _fit],
		["−", func() -> void: _canvas.set_zoom(_canvas._zoom / 1.2)],
		["+", func() -> void: _canvas.set_zoom(_canvas._zoom * 1.2)]
	]:
		var button = Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		bar.add_child(button)
	_label = Label.new()
	_label.custom_minimum_size.x = 580
	_label.size.x = 580
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	var body = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_maps = ItemList.new()
	_maps.custom_minimum_size = Vector2(160, 260)
	body.add_child(_maps)
	_maps.item_selected.connect(
		func(index: int) -> void: _load(int(_maps.get_item_metadata(index)))
	)
	_canvas = preload("Editor_MapCanvas.gd").new()
	_canvas.custom_minimum_size = Vector2(390, 300)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_canvas)
	_canvas.cell_pressed.connect(
		func(cell: Vector2i, _double: bool, button: int) -> void:
			_canvas.finish_input()
			if button != MOUSE_BUTTON_LEFT:
				return
			_cell = cell
			_location_map = _map_id
			_location_cell = cell
			_canvas.select_cell(cell)
			_describe()
			chosen.emit(_map_id, cell)
	)
	resized.connect(
		func() -> void:
			if not _map.is_empty():
				_canvas.queue_redraw()
	)


func _load(id: int) -> void:
	var value: Variant = _documents.read("data/maps/Map%03d.json" % id)
	if not value is Dictionary:
		_label.text = "地图数据无法读取：%04d" % id
		_map = {}
		_canvas.update_map({})
		return
	_map_id = id
	_map = value.duplicate(true)
	_map.erase("_editor_hidden_layers")
	_map["_editor_map_id"] = id
	for index in _maps.item_count:
		if int(_maps.get_item_metadata(index)) == id:
			_maps.select(index)
			break
	_cell = _location_cell if id == _location_map else Vector2i(-1, -1)
	_canvas.configure(_map, _documents)
	_canvas.set_event_mode(true)
	_canvas.set_brush([], false)
	_canvas.select_cell(_cell)
	_describe()
	map_browsed.emit(id)
	call_deferred("_fit")


func _describe() -> void:
	_label.text = (
		"%s · %s\n左键点格指定位置；滚轮缩放，中键拖动画面。"
		% [
			_documents.reference_label("Maps", _map_id),
			"坐标 (%d, %d)" % [_cell.x, _cell.y] if _cell.x >= 0 else "请在地图上选择一格"
		]
	)


func _fit() -> void:
	if _map.is_empty():
		return
	var extent = Vector2(int(_map.width) * 32, int(_map.height) * 32)
	_canvas._zoom = clampf(
		minf((_canvas.size.x - 24) / extent.x, (_canvas.size.y - 24) / extent.y), 0.25, 3
	)
	_canvas._origin = (_canvas.size - extent * _canvas._zoom) / 2
	_canvas.queue_redraw()

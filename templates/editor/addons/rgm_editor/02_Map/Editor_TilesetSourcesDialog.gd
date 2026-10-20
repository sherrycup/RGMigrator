## 职责：选择图块集及自动元件来源，预览素材并更新调用方配置。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/02_Map/Editor_TilesetSourcesDialog.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func open(documents: RefCounted, value: Dictionary) -> void
##     用途：打开页面、对话框或目标记录。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   accepted(value: Dictionary)：用户确认了当前对话框草稿。
##     value：需要读取、校验或写入的值。
##
## 接口说明结束。

@tool
extends ConfirmationDialog
signal accepted(value: Dictionary)
const Layout = preload("res://runtime/scripts/03_Map/TilesetLayout.gd")
var _documents: RefCounted
var _value: Dictionary = {}
var _sources: Array = []
var _list: ItemList
var _canvas: Control
var _status: Label
var _picker: ConfirmationDialog
var _replacing = false
var _selected = 0


func open(documents: RefCounted, value: Dictionary) -> void:
	_documents = documents
	_value = value.duplicate(true)
	_sources = Layout.sources(
		value, func(name: String) -> Texture2D: return documents.asset_texture("Tilesets", name)
	)
	if _list == null:
		_build()
	_selected = 0
	_refresh()
	popup_centered(Vector2i(1000, 650))


func _build() -> void:
	title = "组合普通图块素材"
	get_ok_button().text = "应用组合及当前条目"
	confirmed.connect(_accept)
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(900, 520)
	add_child(box)
	var note = Label.new()
	note.custom_minimum_size.x = 900
	note.size.x = 900
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "素材按顺序纵向排列，使用原图，不生成合成图片。规格：宽256像素、高为32的倍数。尾部追加保留旧编号；换序会同步地图与图块事件，正在使用的素材不能移除。"
	box.add_child(note)
	var bar = HFlowContainer.new()
	box.add_child(bar)
	for entry in [
		["追加素材…", _pick.bind(false)],
		["替换所选素材…", _pick.bind(true)],
		["上移", _move.bind(-1)],
		["下移", _move.bind(1)],
		["移除", _remove]
	]:
		var button = Button.new()
		button.text = entry[0]
		bar.add_child(button)
		button.pressed.connect(entry[1])
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	_list = ItemList.new()
	_list.custom_minimum_size.x = 540
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_list)
	_list.item_selected.connect(func(i: int) -> void: _selected = i)
	_list.item_activated.connect(
		func(i: int) -> void:
			_selected = i
			_pick(true)
	)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 280
	split.add_child(scroll)
	_canvas = preload("Editor_MapCanvas.gd").new()
	scroll.add_child(_canvas)
	_status = Label.new()
	_status.custom_minimum_size.x = 900
	_status.size.x = 900
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_picker = preload("../05_Assets/Editor_AssetDialog.gd").new()
	add_child(_picker)
	_picker.accepted.connect(_accept_asset)


func _pick(replace: bool) -> void:
	if replace and _sources.is_empty():
		return
	_replacing = replace
	_picker.open(
		_documents, "Tilesets", str(_sources[_selected].name) if replace else "", {}, "普通图块素材"
	)


func _accept_asset(name: String, _settings: Dictionary) -> void:
	var texture: Texture2D = _documents.asset_texture("Tilesets", name)
	if texture == null or texture.get_width() != 256 or texture.get_height() % 32 != 0:
		_status.text = "请选择宽256像素、高为32的倍数的有效图块素材。"
		return
	if _replacing:
		_sources[_selected].name = name
		_sources[_selected].rows = int(texture.get_height() / 32)
	else:
		var key = 0
		var keys = _sources.map(func(s: Dictionary) -> String: return str(s.key))
		while "source_%d" % key in keys:
			key += 1
		_sources.append(
			{"key": "source_%d" % key, "name": name, "rows": int(texture.get_height() / 32)}
		)
		_selected = _sources.size() - 1
	_refresh()


func _move(offset: int) -> void:
	var index = _selected + offset
	if index < 0 or index >= _sources.size():
		return
	var source = _sources[_selected]
	_sources.remove_at(_selected)
	_sources.insert(index, source)
	_selected = index
	_refresh()


func _remove() -> void:
	if _sources.is_empty():
		return
	_sources.remove_at(_selected)
	_selected = maxi(0, mini(_selected, _sources.size() - 1))
	_refresh()


func _draft() -> Dictionary:
	var value = _value.duplicate(true)
	value.tileset_sources = _sources.duplicate(true)
	value.tileset_name = "" if _sources.is_empty() else str(_sources[0].name)
	return value


func _refresh() -> void:
	_list.clear()
	var first = 384
	for source in _sources:
		var count = int(source.rows) * 8
		_list.add_item(
			(
				"%d. %s · %d行 · 图块 %d–%d"
				% [
					_list.item_count + 1,
					str(source.name),
					int(source.rows),
					first,
					first + count - 1
				]
			)
		)
		first += count
	if not _sources.is_empty():
		_list.select(_selected)
	_canvas.configure_tileset(_draft(), _documents)
	_status.text = "%d张素材 · %d个普通图块。确认应用到编辑草稿，Ctrl+S后写入文件。" % [_sources.size(), first - 384]
	if not _canvas._normal_layout.errors.is_empty():
		_status.text += "\n" + "；".join(_canvas._normal_layout.errors)


func _accept() -> void:
	var id = int(_value.id)
	var before: Dictionary = _documents.records("Tilesets")[id]
	var plan = preload("Editor_TilesetOps.gd").prepare(_documents, id, before, _draft())
	if plan.ok:
		plan = _documents.apply_batch(plan.changes, "组合图块素材与编号同步")
	if not plan.ok:
		_status.text = str(plan.message)
		call_deferred("popup_centered", Vector2i(1000, 650))
		return
	accepted.emit(_documents.records("Tilesets")[id])

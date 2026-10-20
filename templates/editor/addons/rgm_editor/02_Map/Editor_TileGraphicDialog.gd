## 职责：从当前地图图块集中选择事件图形，返回图块编号及显示参数。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/02_Map/Editor_TileGraphicDialog.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func open(documents: RefCounted, tileset: Dictionary, graphic: Dictionary) -> void
##     用途：打开页面、对话框或目标记录。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 tileset（Dictionary；必填）：当前地图使用的图块集定义或对象。
##     参数 graphic（Dictionary；必填）：人物或图块图形配置。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   accepted(tile_id: int)：用户确认了当前对话框草稿。
##     tile_id：RM 图块编号。
##
## 接口说明结束。

@tool
extends ConfirmationDialog
## Select an event graphic from the current map's tileset without editing that tileset.
signal accepted(tile_id: int)
var _documents: RefCounted
var _tileset: Dictionary = {}
var _graphic: Dictionary = {}
var _selected = 0
var _heading: Label
var _palette: Control
var _scroll: ScrollContainer
var _preview: Control
var _status: Label
var _empty: Button


func open(documents: RefCounted, tileset: Dictionary, graphic: Dictionary) -> void:
	_documents = documents
	_tileset = tileset.duplicate(true)
	_graphic = graphic.duplicate(true)
	_selected = int(graphic.get("tile_id", 0))
	if _palette == null:
		_build()
	_heading.text = (
		"当前地图图块集：[%04d] %s" % [int(tileset.get("id", 0)), str(tileset.get("name", "未命名"))]
	)
	_palette.configure_tileset(_tileset, _documents)
	# RM event sprites use ordinary tiles (384+); autotiles remain map terrain.
	_palette._palette_ids = _palette._palette_ids.filter(
		func(id: Variant) -> bool: return int(id) >= 384
	)
	_palette.custom_minimum_size.y = ceili(_palette._palette_ids.size() / 8.0) * 32
	_palette.select_tile(_selected)
	var normalized = int(_selected / 48) * 48 if _selected >= 48 and _selected < 384 else _selected
	var index = _palette._palette_ids.find(normalized)
	_scroll.set_deferred("scroll_vertical", maxi(0, int(index / 8) * 32 - 64))
	_update_preview()
	popup_centered(Vector2i(840, 600))


func _build() -> void:
	title = "事件图形 · 当前地图图块"
	get_ok_button().text = "使用此图块"
	confirmed.connect(func() -> void: accepted.emit(_selected))
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 470)
	add_child(box)
	_heading = Label.new()
	_heading.custom_minimum_size.x = 760
	_heading.size.x = 760
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_heading)
	var note = Label.new()
	note.custom_minimum_size.x = 760
	note.size.x = 760
	note.text = "点选本地图的普通图块作为事件外观，或点击“清空图形”。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 280
	split.add_child(left)
	_empty = Button.new()
	_empty.text = "清空图形"
	left.add_child(_empty)
	_empty.pressed.connect(
		func() -> void:
			_selected = 0
			_palette.select_tile(0)
			_update_preview()
	)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_scroll)
	_palette = preload("Editor_MapCanvas.gd").new()
	_scroll.add_child(_palette)
	_palette.tile_selected.connect(
		func(id: int) -> void:
			_selected = id
			_update_preview()
	)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_preview = preload("../05_Assets/Editor_AssetPreview.gd").new()
	_preview.custom_minimum_size = Vector2(250, 280)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_preview)
	_status = Label.new()
	_status.custom_minimum_size.x = 450
	_status.size.x = 450
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)


func _update_preview() -> void:
	var category = "Tilesets"
	var asset_name = str(_tileset.get("tileset_name", ""))
	var caption = "事件图块 · %04d" % _selected
	if _selected == 0:
		asset_name = ""
		caption = "无事件图形"
	elif _selected < 384:
		category = "Autotiles"
		var names: Array = _tileset.get("autotile_names", [])
		var slot = int(_selected / 48) - 1
		asset_name = str(names[slot]) if slot in range(names.size()) else ""
	var settings = _graphic.duplicate()
	settings.tile_id = _selected
	settings.hue = (
		int(_graphic.get("character_hue", 0))
		if _selected > 0 and _selected == int(_graphic.get("tile_id", 0))
		else 0
	)
	settings.tileset = _tileset
	_preview.configure(_documents, category, asset_name, settings, false, false, caption)
	_status.text = (
		"选择空图形将清除事件外观。" if _selected == 0 else "图块编号：%04d\n确认后作为事件外观；取消保留原图形。" % _selected
	)

@tool
extends VBoxContainer
const Documents = preload("EditorDocuments.gd")
const Commands = preload("EditorCommands.gd")
const Scripts = preload("EditorScriptAdapter.gd")
const Ops = preload("EditorMapOps.gd")
const Canvas = preload("EditorMapCanvas.gd")
const Form = preload("EditorValueForm.gd")
const CommandDialog = preload("EditorCommandDialog.gd")
var _documents: RefCounted
var _map_id = 0
var _map: Dictionary = {}
var _path = ""
var _maps: Tree
var _events: ItemList
var _canvas: Control
var _palette: Control
var _status: Label
var _layer: OptionButton
var _tool: OptionButton
var _brush = 384
var _tile_brush: Array = [[384]]
var _stroke_before: Dictionary = {}
var _layer_buttons: Array = []
var _layer_modes: HFlowContainer
var _visibility_modes: HFlowContainer
var _visibility_buttons: Array=[]
var _layer_titles: Array=[]
var _event_mode=false
var _tool_buttons: Array = []
var _tilesets: OptionButton
var _map_title: Label
var _brush_label: Label
var _zoom_label: Label
var _event_tools: HFlowContainer
var _draw_tools: HFlowContainer
var _palette_box: VBoxContainer
var _palette_tileset = -1
var _palette_layout: Array=[]
var _cell = Vector2i.ZERO
var _stroke_start = Vector2i.ZERO
var _stroke = false
var _event_clipboard: Dictionary = {}
var _tile_clipboard: Array = []
var _region = Rect2i()
var _commands_clipboard: Array = []
var _event_dialog: ConfirmationDialog
var _event_name: LineEdit
var _event_x: SpinBox
var _event_y: SpinBox
var _event_id = 0
var _event_draft: Dictionary = {}
var _page = 0
var _pages: OptionButton
var _page_tabs: TabBar
var _refreshing_pages=false
var _settings: VBoxContainer
var _command_editor: VBoxContainer
var _command_list: Tree
var _command_dialog: ConfirmationDialog
var _adding_command = false
var _command_index = 0
var _map_dialog: ConfirmationDialog
var _map_form: VBoxContainer
var _new_map = false
var _context: PopupMenu
var _reload_dialog: ConfirmationDialog
var _undo: Button
var _redo: Button
var _built = false
var _database: ConfirmationDialog
var _scripts: Window

func _ready() -> void:
	setup()

func setup(documents: RefCounted = null) -> void:
	if _built: return
	_built = true
	_documents = documents if documents!=null else Documents.new()
	_documents.changed.connect(_update_status)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var toolbar = HFlowContainer.new(); add_child(toolbar)
	_button(toolbar,"保存 Ctrl+S",save_changes)
	_undo = _button(toolbar,"撤销",_undo_action)
	_redo = _button(toolbar,"重做",_redo_action)
	_button(toolbar,"重新载入",_ask_reload)
	_button(toolbar,"新建地图",_open_map_properties.bind(true))
	_button(toolbar,"地图属性",_open_map_properties.bind(false))
	_button(toolbar,"复制地图",_duplicate_map)
	_database=preload("EditorDatabaseDialog.gd").new(); add_child(_database)
	_database.confirmed.connect(func() -> void: _load_map(_map_id)); _database.canceled.connect(func() -> void: _load_map(_map_id))
	_button(toolbar,"数据库 / 公共事件 F9",func() -> void: _database.open(_documents))
	_scripts=preload("EditorScriptDialog.gd").new(); add_child(_scripts)
	_scripts.published.connect(func() -> void: _database._before={}; _load_maps(_map_id))
	_button(toolbar,"脚本工作区 F8",func() -> void: _scripts.open(_documents))
	# Hidden selection models keep one source of truth for button and keyboard actions.
	_layer = OptionButton.new(); _layer.hide(); add_child(_layer)
	_layer.item_selected.connect(_choose_layer)
	_tool = OptionButton.new(); _tool.hide(); add_child(_tool)
	for title in ["铅笔","矩形","填充","橡皮","选区","粘贴","吸管"]: _tool.add_item(title)
	_tool.item_selected.connect(_choose_tool)
	_layer_modes=HFlowContainer.new(); add_child(_layer_modes)
	_visibility_modes=HFlowContainer.new(); add_child(_visibility_modes)
	_draw_tools=HFlowContainer.new(); add_child(_draw_tools)
	var tools = ButtonGroup.new()
	for i in 6:
		var button = _button(_draw_tools,["铅笔 B","矩形 R","填充 F","橡皮 E","选区 S","粘贴 V"][i],_choose_tool.bind(i))
		button.toggle_mode=true; button.button_group=tools; _tool_buttons.append(button)
	_button(_draw_tools,"复制选区 Ctrl+C",_copy_selection)
	_button(_draw_tools,"粘贴 Ctrl+V",_paste_selection)
	_event_tools=HFlowContainer.new(); add_child(_event_tools)
	_button(_event_tools,"新建事件",_open_event.bind(true))
	_button(_event_tools,"编辑事件",_open_event.bind(false))
	_button(_event_tools,"复制事件",_copy_selection)
	_button(_event_tools,"粘贴事件",_paste_selection)
	_button(_event_tools,"删除事件",_delete_event)
	var split = HSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(split)
	var map_box = VBoxContainer.new(); map_box.custom_minimum_size.x=180; split.add_child(map_box)
	var map_label = Label.new(); map_label.text="地图列表"; map_box.add_child(map_label)
	_maps=Tree.new(); _maps.hide_root=true; _maps.size_flags_vertical=Control.SIZE_EXPAND_FILL; map_box.add_child(_maps)
	_maps.item_selected.connect(_map_selected)
	var work = HSplitContainer.new(); work.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(work)
	_palette_box=VBoxContainer.new(); _palette_box.custom_minimum_size.x=272; work.add_child(_palette_box)
	var tile_label = Label.new(); tile_label.text="图块面板 · 拖动选择多个图块"; _palette_box.add_child(tile_label)
	_tilesets=OptionButton.new(); _tilesets.clip_text=true; _palette_box.add_child(_tilesets)
	_tilesets.item_selected.connect(_change_tileset)
	_button(_palette_box,"编辑当前图块集…",func() -> void: _database.open_tileset(_documents,int(_map.get("tileset_id",1))))
	_brush_label=Label.new(); _palette_box.add_child(_brush_label)
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; _palette_box.add_child(scroll)
	_palette=Canvas.new(); scroll.add_child(_palette)
	_palette.brush_selected.connect(_select_brush)
	var right = VBoxContainer.new(); right.size_flags_horizontal=Control.SIZE_EXPAND_FILL; work.add_child(right)
	_map_title=Label.new(); _map_title.clip_text=true; right.add_child(_map_title)
	var heading = HBoxContainer.new(); right.add_child(heading)
	var view_label=Label.new(); view_label.text="视图"; view_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(view_label)
	_button(heading,"−",func() -> void: _canvas.set_zoom(_canvas._zoom/1.2))
	_zoom_label=Label.new(); heading.add_child(_zoom_label)
	_button(heading,"+",func() -> void: _canvas.set_zoom(_canvas._zoom*1.2))
	_button(heading,"100%",func() -> void: _canvas.set_zoom(1.0))
	_button(heading,"居中",func() -> void: _canvas.focus_cell(Vector2i(int(_map.get("width",0))/2,int(_map.get("height",0))/2)))
	_canvas=Canvas.new(); _canvas.custom_minimum_size=Vector2(300,250); _canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(_canvas)
	_canvas.cell_pressed.connect(_press_cell); _canvas.cell_dragged.connect(_drag_cell); _canvas.stroke_finished.connect(_finish_stroke)
	_canvas.cell_hovered.connect(func(cell: Vector2i) -> void: _cell=cell; _update_status())
	_canvas.zoom_changed.connect(func(_value: float) -> void: _update_status())
	var hint = Label.new(); hint.text="左键绘制 · 右键取样 · 中键平移 · 滚轮缩放 · Esc取消笔画"; hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; right.add_child(hint)
	_events=ItemList.new(); _events.custom_minimum_size.y=85; right.add_child(_events)
	_events.item_selected.connect(_select_event)
	_events.item_activated.connect(func(_i: int) -> void: _open_event(false))
	_rebuild_layers(); _choose_layer(0); _choose_tool(0)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_status)
	_build_event_dialog()
	_build_map_dialog()
	_context = PopupMenu.new(); add_child(_context)
	for entry in [["编辑事件",0],["新建事件",1],["复制事件",2],["粘贴事件",3],["删除事件",4],["移动所选事件到这里",5],["设置玩家起点",6]]: _context.add_item(entry[0],entry[1])
	_context.id_pressed.connect(_context_action)
	_reload_dialog = ConfirmationDialog.new(); _reload_dialog.dialog_text="重新载入会放弃尚未保存的地图、事件和数据库草稿。"; add_child(_reload_dialog)
	_reload_dialog.confirmed.connect(_reload_all)
	_load_maps()

func _button(parent: Node,text: String,callback: Callable) -> Button:
	var button = Button.new(); button.text=text; button.pressed.connect(callback); parent.add_child(button); return button

func _load_maps(preferred: int = 0) -> void:
	_maps.clear()
	var root = _maps.create_item()
	var manifest: Variant = _documents.read("data/manifest.json")
	var infos: Variant = _documents.read("data/map_infos.json")
	if not manifest is Dictionary or not infos is Dictionary: _status.text=_documents.error_message(); return
	var ids: Array = []
	for name in manifest.get("maps",[]): ids.append(str(name).trim_prefix("Map").to_int())
	ids.sort_custom(func(a: int,b: int) -> bool: return int(infos.get(str(a),{}).get("order",a))<int(infos.get(str(b),{}).get("order",b)))
	var items: Dictionary = {}
	var pending = ids.duplicate()
	while not pending.is_empty():
		var progress = false
		for id in pending.duplicate():
			var data: Dictionary = infos.get(str(id),{})
			var parent_id = int(data.get("parent_id",0))
			if parent_id>0 and parent_id in ids and not items.has(parent_id): continue
			var item = _maps.create_item(items.get(parent_id,root)); item.set_text(0,"%03d  %s" % [id,str(data.get("name","未命名"))]); item.set_metadata(0,id)
			items[id]=item; pending.erase(id); progress=true
		if not progress:
			for id in pending: var item =_maps.create_item(root); item.set_text(0,"%03d  %s" % [id,str(infos.get(str(id),{}).get("name","未命名"))]); item.set_metadata(0,id); items[id]=item
			pending.clear()
	var system: Variant = _documents.read("data/system.json")
	var target = preferred if items.has(preferred) else int(system.get("start_map_id",0)) if system is Dictionary else 0
	if not items.has(target) and not ids.is_empty(): target=int(ids[0])
	if items.has(target): items[target].select(0); _load_map(target)
	_update_status()

func _map_selected() -> void:
	var item =_maps.get_selected()
	if item!=null: _load_map(int(item.get_metadata(0)))

func _load_map(id: int) -> void:
	_finish_stroke()
	if id!=_map_id: _canvas.reset_view()
	_map_id=id; _path="data/maps/Map%03d.json" % id
	var value: Variant = _documents.read(_path)
	if not value is Dictionary: _status.text=_documents.error_message(); return
	_map=Scripts.adapt_map(value)
	# Existing generated projects are adapted in memory until the user saves.
	if _map!=value: _documents.apply(_path,_map,"脚本注释占位")
	_event_id=0; _region=Rect2i(); _stroke=false
	_refresh_map()

func _refresh_map() -> void:
	_rebuild_layers()
	var preview =_map.duplicate(); preview["_editor_map_id"]=_map_id
	_canvas.configure(preview,_documents)
	_canvas.set_layer(_layer.selected); _canvas.set_event_mode(_event_mode)
	_palette.configure(preview,_documents,true)
	var layout: Array=[]
	for segment in _palette._normal_layout.segments: layout.append([segment.key,segment.first,segment.end])
	if _palette_tileset!=int(_map.get("tileset_id",0)) or _palette_layout!=layout:
		_palette_tileset=int(_map.get("tileset_id",0))
		_palette_layout=layout
		_tile_clipboard.clear(); _event_clipboard.clear()
		_select_brush([[0]]); _palette.select_tile(0)
	_tilesets.clear()
	for entry in _documents.lookup("Tilesets"):
		_tilesets.add_item(entry.name,int(entry.id))
		if int(entry.id)==_palette_tileset: _tilesets.select(_tilesets.item_count-1)
	_map_title.text=_documents.reference_label("Maps",_map_id)+"  ·  %d × %d" % [int(_map.get("width",0)),int(_map.get("height",0))]
	_canvas.set_region(_region)
	_sync_brush()
	_events.clear()
	var keys =_map.get("events",{}).keys(); keys.sort_custom(func(a: Variant,b: Variant) -> bool: return int(a)<int(b))
	for key in keys:
		var event: Dictionary=_map.events[key]
		_events.add_item("%03d %s (%d,%d)" % [int(key),str(event.get("name","")),int(event.x),int(event.y)])
		_events.set_item_metadata(_events.item_count-1,int(key))
		if int(key)==_event_id: _events.select(_events.item_count-1)
	_canvas.select_cell(_cell)
	_update_status()

func _commit_map(label: String) -> void:
	_documents.apply(_path,_map,label)
	_refresh_map()

func _rebuild_layers() -> void:
	var names=Ops.layer_names(_map)
	if names!=_layer_titles:
		_layer_titles=names; _layer.clear(); _layer_buttons.clear(); _visibility_buttons.clear()
		for container in [_layer_modes,_visibility_modes]:
			for child in container.get_children(): container.remove_child(child); child.queue_free()
		var label=Label.new(); label.text="编辑模式 / 图层"; _layer_modes.add_child(label)
		var group=ButtonGroup.new()
		for i in names.size():
			_layer.add_item(str(names[i]))
			var button=_button(_layer_modes,"绘图 · "+str(names[i]),_choose_layer.bind(i))
			button.toggle_mode=true; button.button_group=group; _layer_buttons.append(button)
		_layer.add_item("事件")
		var events=_button(_layer_modes,"事件编辑",_choose_events)
		events.toggle_mode=true; events.button_group=group; _layer_buttons.append(events)
		_button(_layer_modes,"增加图块层",_add_layer)
		var visible_label=Label.new(); visible_label.text="显示（仅编辑器）"; _visibility_modes.add_child(visible_label)
		for i in names.size():
			var check=CheckBox.new(); check.text=str(names[i]); _visibility_modes.add_child(check); _visibility_buttons.append(check)
			check.toggled.connect(_set_layer_visible.bind(i))
		_layer.select(names.size() if _event_mode else 0)
	for i in _visibility_buttons.size(): _visibility_buttons[i].set_pressed_no_signal(not i in _map.get("_editor_hidden_layers",[]))
	_sync_layer_mode()

func _sync_layer_mode() -> void:
	for i in _layer_buttons.size(): _layer_buttons[i].set_pressed_no_signal(i==_layer.selected)
	if _draw_tools!=null: _draw_tools.visible=not _event_mode
	if _event_tools!=null: _event_tools.visible=_event_mode
	if _events!=null: _events.visible=_event_mode

func _choose_events() -> void:
	_choose_layer(Ops.layer_count(_map))

func _choose_layer(index: int) -> void:
	_finish_stroke()
	_event_mode=index>=Ops.layer_count(_map)
	_layer.select(Ops.layer_count(_map) if _event_mode else clampi(index,0,Ops.layer_count(_map)-1))
	_sync_layer_mode()
	if _canvas!=null: _canvas.set_layer(_layer.selected); _canvas.set_event_mode(_event_mode); _sync_brush()
	_update_status()

func _add_layer() -> void:
	_finish_stroke()
	var count=Ops.layer_count(_map)
	var result=Ops.set_layer_count(_map,count+1)
	if not result.ok: _status.text=result.message; return
	_commit_map("增加图块层"); _choose_layer(count)

func _set_layer_visible(enabled: bool, index: int) -> void:
	_finish_stroke()
	var hidden: Array=_map.get("_editor_hidden_layers",[]).duplicate()
	if enabled: hidden.erase(index)
	elif not index in hidden: hidden.append(index)
	_map["_editor_hidden_layers"]=hidden; _commit_map("图层显示（仅编辑器）")

func _choose_tool(index: int) -> void:
	_finish_stroke(); _tool.select(index)
	for i in _tool_buttons.size(): _tool_buttons[i].set_pressed_no_signal(i==index)
	_region=Rect2i()
	if _canvas!=null: _canvas.set_region(_region); _sync_brush()
	_update_status()

func _select_brush(tiles: Array) -> void:
	_finish_stroke(); _tile_brush=tiles.duplicate(true)
	_brush=int(tiles[0][0]) if not tiles.is_empty() else 0
	if tiles.size()==1 and tiles[0].size()==1: _palette.select_tile(_brush)
	if _tool!=null and _tool.selected in [3,4,5,6]: _choose_tool(0)
	_sync_brush(); _update_status()

func _sync_brush() -> void:
	var brush = _tile_clipboard if _tool.selected==5 else [[0]] if _tool.selected==3 else _tile_brush
	_canvas.set_brush(brush,_tool.selected not in [4,6] and not _event_mode)

func _change_tileset(index: int) -> void:
	_finish_stroke()
	_map.tileset_id=_tilesets.get_item_id(index); _commit_map("更换地图图块集")

func _press_cell(cell: Vector2i,double_click: bool,button: int) -> void:
	_cell=cell
	if _event_mode:
		var found =0
		for event in _map.get("events",{}).values():
			if int(event.x)==cell.x and int(event.y)==cell.y: found=int(event.id); break
		if button==MOUSE_BUTTON_LEFT:
			_event_id=found; _refresh_map()
			if found>0 and not double_click: _stroke=true; _stroke_before=_map.duplicate(true)
		if button==MOUSE_BUTTON_RIGHT:
			_context.position=Vector2i(get_viewport().get_mouse_position()); _context.popup()
		elif double_click: _event_id=found; _open_event(found==0)
		return
	if _layer.selected in _map.get("_editor_hidden_layers",[]): _status.text="请先显示当前图层再绘制。"; return
	if button==MOUSE_BUTTON_RIGHT or _tool.selected==6:
		var id = Ops.tile(_map,cell,_layer.selected)
		_select_brush([[id]]); _palette.select_tile(id); return
	_stroke=true; _stroke_start=cell; _stroke_before=_map.duplicate(true)
	_region=Rect2i(); _canvas.set_region(_region)
	_paint_cell(cell,[cell])

func _drag_cell(cell: Vector2i) -> void:
	var previous = _cell; _cell=cell
	if _stroke and _event_mode:
		var event: Dictionary=_map.events[str(_event_id)]; event.x=cell.x; event.y=cell.y
		_canvas.update_map(_map); _canvas.select_cell(cell); _update_status()
	elif _stroke and _tool.selected!=2: _paint_cell(cell,Ops.line_cells(previous,cell))

func _paint_cell(cell: Vector2i, cells: Array = []) -> void:
	var mode = _tool.selected
	if mode in [1,4]:
		_region=Rect2i(Vector2i(mini(cell.x,_stroke_start.x),mini(cell.y,_stroke_start.y)),Vector2i(absi(cell.x-_stroke_start.x)+1,absi(cell.y-_stroke_start.y)+1)); _canvas.set_region(_region); return
	if cells.is_empty(): cells=[cell]
	if mode==2: Ops.pattern(_map,Ops.flood_cells(_map,cell,_layer.selected),_layer.selected,_tile_brush,cell)
	elif mode==3: Ops.paint(_map,cells,_layer.selected,0)
	else: Ops.stamp(_map,cells,_layer.selected,_tile_clipboard if mode==5 else _tile_brush)
	_canvas.update_map(_map); _update_status()

func _finish_stroke() -> void:
	if not _stroke: return
	_stroke=false; _canvas.finish_input()
	if _event_mode:
		var moved=_map!=_stroke_before; _stroke_before={}
		if moved: _commit_map("拖动事件位置")
		return
	if _tool.selected==4: _canvas.set_region(_region); _stroke_before={}; return
	if _tool.selected==1:
		var cells: Array=[]
		for y in range(_region.position.y,_region.end.y):
			for x in range(_region.position.x,_region.end.x): cells.append(Vector2i(x,y))
		Ops.pattern(_map,cells,_layer.selected,_tile_brush,_region.position)
	_region=Rect2i(); _stroke_before={}
	_commit_map("绘制图块 · "+_tool.get_item_text(_tool.selected))

func _cancel_stroke() -> void:
	if not _stroke: return
	_stroke=false; _canvas.finish_input(); _map=_stroke_before; _stroke_before={}; _region=Rect2i()
	if _event_mode and _map.events.has(str(_event_id)): _cell=Vector2i(int(_map.events[str(_event_id)].x),int(_map.events[str(_event_id)].y))
	_refresh_map()

func _select_event(i: int) -> void:
	_event_id=int(_events.get_item_metadata(i))
	var event: Dictionary=_map.events[str(_event_id)]
	_cell=Vector2i(int(event.x),int(event.y)); _canvas.focus_cell(_cell); _update_status()

func _context_action(id: int) -> void:
	match id:
		0: _open_event(false)
		1: _open_event(true)
		2: _copy_selection()
		3: _paste_selection()
		4: _delete_event()
		5:
			if _map.events.has(str(_event_id)): _map.events[str(_event_id)].x=_cell.x; _map.events[str(_event_id)].y=_cell.y; _commit_map("移动事件")
		6: _set_start()

func _copy_selection() -> void:
	if _event_mode:
		if _map.events.has(str(_event_id)): _event_clipboard=_map.events[str(_event_id)].duplicate(true); _status.text="已复制事件。"
	else:
		_tile_clipboard.clear()
		var region =_region if _region.has_area() else Rect2i(_cell,Vector2i.ONE)
		for y in range(region.position.y,region.end.y):
			var row: Array=[]
			for x in range(region.position.x,region.end.x): row.append(Ops.tile(_map,Vector2i(x,y),_layer.selected))
			_tile_clipboard.append(row)
		_status.text="已复制%d×%d选区；点击粘贴或按Ctrl+V，再用粘贴工具连续绘制。" % [region.size.x,region.size.y]

func _paste_selection() -> void:
	if _event_mode and not _event_clipboard.is_empty():
		var event =_event_clipboard.duplicate(true); var id =Ops.next_event_id(_map)
		event.id=id; event.x=_cell.x; event.y=_cell.y; _map.events[str(id)]=event; _event_id=id; _commit_map("粘贴事件")
	elif not _event_mode and not _layer.selected in _map.get("_editor_hidden_layers",[]) and not _tile_clipboard.is_empty():
		_choose_tool(5); _paint_cell(_cell); _commit_map("粘贴图块")

func _delete_event() -> void:
	if not _map.get("events",{}).has(str(_event_id)): return
	_map.events.erase(str(_event_id)); _event_id=0; _commit_map("删除事件")

func _set_start() -> void:
	if not Ops.valid(_map,_cell): return
	var system: Variant=_documents.read("data/system.json")
	if not system is Dictionary: return
	system.start_map_id=_map_id; system.start_x=_cell.x; system.start_y=_cell.y
	_documents.apply("data/system.json",system,"设置玩家起点")
	_refresh_map()

func _build_event_dialog() -> void:
	_event_dialog=ConfirmationDialog.new(); _event_dialog.title="地图事件"; add_child(_event_dialog)
	_event_dialog.get_ok_button().text="应用事件"
	_event_dialog.confirmed.connect(_apply_event)
	var box =VBoxContainer.new(); box.custom_minimum_size=Vector2(950,580); _event_dialog.add_child(box)
	var bar =HBoxContainer.new(); box.add_child(bar)
	_event_name=LineEdit.new(); _event_name.placeholder_text="事件名称"; _event_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; bar.add_child(_event_name)
	_event_x=SpinBox.new(); _event_y=SpinBox.new()
	for entry in [["X",_event_x],["Y",_event_y]]:
		var label =Label.new(); label.text=entry[0]; bar.add_child(label); bar.add_child(entry[1])
	var page_bar =HBoxContainer.new(); box.add_child(page_bar)
	_pages=OptionButton.new(); page_bar.add_child(_pages); _pages.hide(); _pages.item_selected.connect(_choose_page)
	_page_tabs=TabBar.new(); box.add_child(_page_tabs); _page_tabs.tab_changed.connect(func(index: int) -> void: if not _refreshing_pages: _choose_page(index))
	_button(page_bar,"新建页",_new_page)
	_button(page_bar,"复制页",_copy_page)
	_button(page_bar,"删除页",_delete_page)
	_button(page_bar,"页左移",_move_page.bind(-1))
	_button(page_bar,"页右移",_move_page.bind(1))
	var note =Label.new(); note.text="满足条件时采用编号最大的页；编辑预览不运行事件。"; page_bar.add_child(note)
	var split =HSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(split)
	_settings=preload("EditorEventPageForm.gd").new(); _settings.custom_minimum_size.x=395; split.add_child(_settings)
	_command_editor=preload("EditorCommandList.gd").new(); _command_editor.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(_command_editor)
	_command_editor.configure([Commands.command(0)],_documents)
	_command_editor.changed.connect(func(list: Array) -> void:
		if not _event_draft.is_empty(): _event_draft.pages[_page].list=list)
	_command_list=_command_editor._command_list; _command_dialog=_command_editor._command_dialog

func _open_event(new_event: bool) -> void:
	if _map.is_empty(): return
	if new_event:
		var id =Ops.next_event_id(_map)
		_event_draft={"_class":"RPG::Event","id":id,"name":"EV%03d" % id,"x":_cell.x,"y":_cell.y,"pages":[_documents.new_page()]}
	elif _map.events.has(str(_event_id)): _event_draft=_map.events[str(_event_id)].duplicate(true)
	else: return
	_page=0; _event_name.text=str(_event_draft.get("name",""))
	_event_x.max_value=int(_map.width)-1; _event_y.max_value=int(_map.height)-1
	_event_x.value=int(_event_draft.x); _event_y.value=int(_event_draft.y)
	_refresh_pages(); _show_page()
	_event_dialog.popup_centered(Vector2i(1100,720))

func _refresh_pages() -> void:
	_refreshing_pages=true; _pages.clear(); _page_tabs.clear_tabs()
	for i in _event_draft.pages.size(): _pages.add_item("第%d页" % (i+1)); _page_tabs.add_tab("第%d页" % (i+1))
	_page=clampi(_page,0,_event_draft.pages.size()-1); _pages.select(_page); _page_tabs.current_tab=_page; _refreshing_pages=false

func _save_page_form() -> void:
	if _event_draft.is_empty(): return
	var page: Dictionary=_settings.draft()
	page.list=_event_draft.pages[_page].list
	_event_draft.pages[_page]=page

func _show_page() -> void:
	var page: Dictionary=_event_draft.pages[_page].duplicate(true); page.erase("list")
	var tilesets: Array=_documents.records("Tilesets"); var id=int(_map.get("tileset_id",0))
	_settings.configure(page,{},_documents,{"":{"tileset":tilesets[id] if id in range(tilesets.size()) and tilesets[id] is Dictionary else {}}})
	_refresh_commands()

func _choose_page(index: int) -> void:
	_save_page_form(); _page=index; _show_page()

func _new_page() -> void:
	_save_page_form(); _event_draft.pages.append(_documents.new_page()); _page=_event_draft.pages.size()-1; _refresh_pages(); _show_page()

func _copy_page() -> void:
	_save_page_form(); _event_draft.pages.insert(_page+1,_event_draft.pages[_page].duplicate(true)); _page+=1; _refresh_pages(); _show_page()

func _delete_page() -> void:
	if _event_draft.pages.size()==1: return
	_event_draft.pages.remove_at(_page); _refresh_pages(); _show_page()

func _move_page(direction: int) -> void:
	_save_page_form()
	var next =_page+direction
	if next<0 or next>=_event_draft.pages.size(): return
	var old: Variant=_event_draft.pages[next]; _event_draft.pages[next]=_event_draft.pages[_page]; _event_draft.pages[_page]=old; _page=next; _refresh_pages(); _show_page()

func _apply_event() -> void:
	_save_page_form()
	_event_draft.name=_event_name.text; _event_draft.x=int(_event_x.value); _event_draft.y=int(_event_y.value)
	var validation =_documents.validate(_path,{"width":_map.width,"height":_map.height,"data":_map.data,"events":{str(int(_event_draft.id)):_event_draft}},_map)
	if not validation.is_empty(): _status.text=validation; _event_dialog.call_deferred("popup_centered",Vector2i(1100,720)); return
	_event_id=int(_event_draft.id); _map.events[str(_event_id)]=_event_draft.duplicate(true); _commit_map("编辑事件")

func _refresh_commands(selected: int = -1) -> void:
	_command_editor.configure(_event_draft.pages[_page].list,_documents,_character_targets())
	if selected>=0: _command_editor._refresh_commands(selected)

func _character_targets() -> Dictionary:
	var result: Dictionary={}
	for key in _map.get("events",{}): result[str(int(key))]="[%04d] %s" % [int(key),str(_map.events[key].get("name","")) if not str(_map.events[key].get("name","")).strip_edges().is_empty() else "未命名事件"]
	return result

func _accept_command(code: int, p: Array) -> void:
	_command_editor._command_index=_command_index; _command_editor._adding_command=_adding_command
	_command_editor._accept_command(code,p)

func _add_command() -> void:
	_command_editor._add_command()

func _edit_command() -> void:
	_command_editor._edit_command()

func _copy_command() -> void:
	_command_editor._copy_command()

func _paste_command() -> void:
	_command_editor._paste_command()

func _delete_command() -> void:
	_command_editor._delete_command()

func _move_command(direction: int) -> void:
	_command_editor._move_command(direction)

func _build_map_dialog() -> void:
	_map_dialog=ConfirmationDialog.new(); _map_dialog.title="地图属性"; add_child(_map_dialog)
	_map_form=Form.new(); _map_form.custom_minimum_size=Vector2(600,380); _map_dialog.add_child(_map_form)
	_map_dialog.confirmed.connect(_apply_map_properties)

func _open_map_properties(new_map: bool) -> void:
	if _map.is_empty(): return
	_new_map=new_map
	var infos: Dictionary=_documents.read("data/map_infos.json")
	var value: Dictionary={"name":"新地图" if new_map else infos.get(str(_map_id),{}).get("name",""),"width":20 if new_map else int(_map.width),"height":15 if new_map else int(_map.height),"tileset_id":int(_map.get("tileset_id",1)),"parent_id":_map_id if new_map else int(infos.get(str(_map_id),{}).get("parent_id",0)),"autoplay_bgm":false if new_map else _map.get("autoplay_bgm",false),"bgm":_map.get("bgm",{"name":"","volume":100,"pitch":100}),"autoplay_bgs":false if new_map else _map.get("autoplay_bgs",false),"bgs":_map.get("bgs",{"name":"","volume":100,"pitch":100})}
	value.layer_count=3 if new_map else Ops.layer_count(_map); value.layer_names=["下层","中层","上层"] if new_map else Ops.layer_names(_map)
	_map_form.configure(value,{"layer_count":"图块层数（1…32）","layer_names":"图层名称（按顺序）","width":"宽度（格）","height":"高度（格）","tileset_id":"图块集","parent_id":"父地图","autoplay_bgm":"自动播放BGM","autoplay_bgs":"自动播放BGS"},_documents,{"layer_count":{"min":1,"max":32},"tileset_id":{"db":"Tilesets","min":1},"parent_id":{"db":"Maps","min":0,"empty":"无父地图"},"width":{"min":1,"max":500},"height":{"min":1,"max":500},"bgm/name":{"asset":"BGM"},"bgs/name":{"asset":"BGS"}})
	_map_dialog.popup_centered(Vector2i(760,530))

func _apply_map_properties() -> void:
	var value: Dictionary=_map_form.draft()
	var manifest: Dictionary=_documents.read("data/manifest.json"); var infos: Dictionary=_documents.read("data/map_infos.json")
	var id =_map_id; var data =_map.duplicate(true)
	if _new_map:
		id=1
		for name in manifest.maps: id=maxi(id,str(name).trim_prefix("Map").to_int()+1)
		data={"_class":"RPG::Map","width":1,"height":1,"tileset_id":value.tileset_id,"data":{"_rmxp_type":"table","dimensions":3,"x_size":1,"y_size":1,"z_size":3,"values":[0,0,0]},"events":{},"encounter_list":[],"encounter_step":30}
	var system: Dictionary=_documents.read("data/system.json")
	if int(system.start_map_id)==id and (int(system.start_x)>=int(value.width) or int(system.start_y)>=int(value.height)): _status.text="请先将玩家起点移到新的地图范围。"; return
	var resized =Ops.resize_map(data,int(value.width),int(value.height))
	if not resized.ok: _status.text=resized.message; return
	var layered=Ops.set_layer_count(data,int(value.get("layer_count",3)))
	if not layered.ok: _status.text=layered.message; return
	var names: Array=value.get("layer_names",Ops.layer_names(data)).duplicate()
	for i in Ops.layer_count(data):
		if i>=names.size(): names.append(Ops.layer_names(data)[i])
		elif not names[i] is String or str(names[i]).strip_edges().is_empty(): _status.text="图层名称须为非空文字。"; return
	data.layer_names=names.slice(0,Ops.layer_count(data))
	if int(value.parent_id)==id: _status.text="地图不能成为自己的父地图。"; return
	var parent =int(value.parent_id); var visited: Dictionary={id:true}
	while parent>0:
		if visited.has(parent): _status.text="地图层级不能形成循环。"; return
		if not infos.has(str(parent)): _status.text="父地图不存在。"; return
		visited[parent]=true; parent=int(infos[str(parent)].get("parent_id",0))
	for key in ["tileset_id","autoplay_bgm","bgm","autoplay_bgs","bgs"]: data[key]=value[key]
	var path ="data/maps/Map%03d.json" % id
	var changes: Dictionary={path:data}
	var info: Dictionary=infos.get(str(id),{"_class":"RPG::MapInfo","order":id,"expanded":true,"scroll_x":0,"scroll_y":0})
	info.name=value.name; info.parent_id=int(value.parent_id); infos[str(id)]=info
	changes["data/map_infos.json"]=infos
	if _new_map: manifest.maps.append("Map%03d" % id); changes["data/manifest.json"]=manifest
	var applied=_documents.apply_batch(changes,"新建地图" if _new_map else "地图属性")
	if not applied.ok: _status.text=applied.message; return
	_load_maps(id)

func _duplicate_map() -> void:
	if _map.is_empty(): return
	var manifest: Dictionary=_documents.read("data/manifest.json"); var infos: Dictionary=_documents.read("data/map_infos.json")
	var id =1
	for name in manifest.maps: id=maxi(id,str(name).trim_prefix("Map").to_int()+1)
	var changes: Dictionary={"data/maps/Map%03d.json" % id:_map}
	var info: Dictionary=infos.get(str(_map_id),{}).duplicate(true); info.name=str(info.get("name","地图"))+" 副本"; info.order=id; infos[str(id)]=info
	manifest.maps.append("Map%03d" % id); changes["data/map_infos.json"]=infos; changes["data/manifest.json"]=manifest
	var result=_documents.apply_batch(changes,"复制地图")
	if not result.ok: _status.text=result.message; return
	_load_maps(id)

func save_changes() -> bool:
	if _stroke: _finish_stroke()
	if _database!=null and not _database.apply_current(): return false
	if _scripts!=null and not _scripts.apply_current(): return false
	var result: Dictionary=_documents.save_all()
	_status.text=("已保存%d个文件。" % int(result.get("count",0))) if result.ok else str(result.message)
	if result.ok and int(result.get("count",0))>0 and Engine.is_editor_hint() and not EditorInterface.get_resource_filesystem().is_scanning(): EditorInterface.get_resource_filesystem().scan()
	return result.ok

func unsaved_status() -> String:
	var count =_documents.dirty_paths().size() if _documents!=null else 0
	var pending=_database.pending_status() if _database!=null else ""
	if _scripts!=null: pending+=_scripts.pending_status()
	return ("魔塔编辑器有%d个未保存的数据文件。" % count if count>0 else "")+pending

func _undo_action() -> void:
	_finish_stroke()
	if _documents.undo(): _load_maps(_map_id)

func _redo_action() -> void:
	_finish_stroke()
	if _documents.redo(): _load_maps(_map_id)

func _ask_reload() -> void:
	if not unsaved_status().is_empty(): _reload_dialog.popup_centered()
	else: _reload_all()

func _reload_all() -> void:
	_documents.reload(); _database._before={}; _database._reload_record(); _load_maps(_map_id)
	if _scripts!=null: _scripts.reload()

func _update_status() -> void:
	if _status==null: return
	var mode = "事件编辑" if _event_mode else "%s · %s" % [_layer.get_item_text(_layer.selected),_tool.get_item_text(_tool.selected)]
	_status.text="%s  |  坐标 (%d, %d)  |  未保存文件 %d" % [mode,_cell.x,_cell.y,_documents.dirty_paths().size()]
	if _canvas._normal_layout!=null and not _canvas._normal_layout.errors.is_empty(): _status.text+="  |  "+"；".join(_canvas._normal_layout.errors)
	var active_brush: Array = _tile_clipboard if _tool.selected==5 and not _tile_clipboard.is_empty() else [[0]] if _tool.selected==3 else _tile_brush
	_brush_label.text="%s %d × %d · 图块 %d" % ["粘贴" if _tool.selected==5 else "笔刷",active_brush[0].size(),active_brush.size(),int(active_brush[0][0])]
	_zoom_label.text="%d%%" % roundi(_canvas._zoom*100)
	_undo.disabled=not _documents.can_undo(); _redo.disabled=not _documents.can_redo()

func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if _event_dialog.visible or _map_dialog.visible or _database.visible or _reload_dialog.visible or _scripts.visible: return
	if event.keycode==KEY_F8:
		_scripts.open(_documents); get_viewport().set_input_as_handled(); return
	if event.keycode==KEY_F9:
		_database.open(_documents); get_viewport().set_input_as_handled(); return
	var focus =get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_S: save_changes()
			KEY_Z: _undo_action()
			KEY_Y: _redo_action()
			KEY_C: _copy_selection()
			KEY_V: _paste_selection()
			_: return
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_ESCAPE:
		_cancel_stroke(); get_viewport().set_input_as_handled()
	elif not _event_mode:
		var keys = [KEY_B,KEY_R,KEY_F,KEY_E,KEY_S,KEY_V]
		if event.keycode in keys: _choose_tool(keys.find(event.keycode)); get_viewport().set_input_as_handled()

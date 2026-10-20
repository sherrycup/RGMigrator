## 职责：回归验证：执行地图绘制、选择、尺寸和事件位置编辑场景。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary
##     用途：执行当前迁移流程或回归场景。
##     参数 parent（Node；必填）：父节点、父对象或继承关系的上级。
##     参数 original（RefCounted；必填）：修改前的原始记录或文本。
##     参数 capture（Callable；默认值 Callable()）：已捕获的现场数据或画面。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

@tool
extends RefCounted
var checks = 0
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func _mouse(canvas: Control, cell: Vector2i, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new(); event.button_index=button; event.pressed=pressed
	event.position=canvas._origin+(Vector2(cell)+Vector2(0.5,0.5))*32*canvas._zoom
	canvas._gui_input(event)

func _move(canvas: Control, cell: Vector2i) -> void:
	var event = InputEventMouseMotion.new(); event.position=canvas._origin+(Vector2(cell)+Vector2(0.5,0.5))*32*canvas._zoom
	canvas._gui_input(event)

func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary:
	var tree = parent.get_tree()
	var ops = load("res://addons/rgm_editor/02_Map/Editor_MapOps.gd")
	var folder = "res://.godot/map_edit_fixture_%d/" % Time.get_ticks_usec()
	var system: Dictionary = original.read("data/system.json"); system.start_map_id=1; system.start_x=0; system.start_y=0
	_write(folder+"data/system.json",system); _write(folder+"data/manifest.json",{"maps":["Map001"]})
	_write(folder+"data/map_infos.json",{"1":{"name":"地图制作验收","parent_id":0,"order":1}})
	var sets: Array = original.records("Tilesets")
	var set_id = 1
	for i in range(1,sets.size()):
		if sets[i] is Dictionary and original.asset_texture("Tilesets",str(sets[i].get("tileset_name","")))!=null: set_id=i; break
	_write(folder+"data/database/Tilesets.json",sets)
	_write(folder+"data/database/Actors.json",original.records("Actors"))
	_write(folder+"data/asset_index.json",original.read("data/asset_index.json"))
	var values: Array = []; values.resize(12*10*3); values.fill(0)
	var page = original.new_page(); page.graphic.character_name=""
	var map = {"_class":"RPG::Map","width":12,"height":10,"tileset_id":set_id,"data":{"_rmxp_type":"table","dimensions":3,"x_size":12,"y_size":10,"z_size":3,"values":values},"events":{"1":{"id":1,"name":"保留事件","x":11,"y":9,"pages":[page]}},"custom_marker":{"keep":[1,2,3]}}
	_write(folder+"data/maps/Map001.json",map)
	map=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/maps/Map001.json"))
	var docs = load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder)
	var panel = load("res://addons/rgm_editor/00_Plugin/Editor_Panel.gd").new(); panel.setup(docs); parent.add_child(panel)
	await tree.process_frame
	expect(panel._layer.selected==0 and panel._draw_tools.visible,"drawing is the initial visible mode")
	expect(panel._maps.is_visible_in_tree() and panel._palette.is_visible_in_tree(),"map tree and tile palette are simultaneously visible")
	expect(panel._tilesets.get_selected_id()==set_id,"map tileset selector displays actual source tileset")
	var canvas = panel._canvas; var palette = panel._palette
	# Drag a 2x2 selection in the actual palette rather than constructing a brush.
	_mouse(palette,Vector2i(0,1),true); _move(palette,Vector2i(1,2)); _mouse(palette,Vector2i(1,2),false)
	expect(panel._tile_brush==[[384,385],[392,393]],"palette drag creates native 2x2 source brush")
	_mouse(canvas,Vector2i(1,1),true); _mouse(canvas,Vector2i(1,1),false)
	expect(ops.tile(panel._map,Vector2i(1,1),0)==384 and ops.tile(panel._map,Vector2i(2,2),0)==393,"multi tile pencil places every selected tile")
	expect(JSON.parse_string(FileAccess.get_file_as_string(folder+"data/maps/Map001.json"))==map,"drawing leaves disk untouched before explicit Save")
	panel._undo.pressed.emit(); expect(ops.tile(panel._map,Vector2i(1,1),0)==0,"one undo removes whole multi tile stamp")
	panel._redo.pressed.emit(); expect(ops.tile(panel._map,Vector2i(2,2),0)==393,"redo restores whole brush")
	panel._select_brush([[384]])
	_mouse(canvas,Vector2i(0,0),true); _move(canvas,Vector2i(8,0)); _mouse(canvas,Vector2i(8,0),false)
	for x in 9: expect(ops.tile(panel._map,Vector2i(x,0),0)==384,"fast drag interpolates cell %d" % x)
	panel._undo.pressed.emit()
	for x in 9: expect(ops.tile(panel._map,Vector2i(x,0),0)==0,"one undo removes complete fast stroke %d" % x)
	panel._select_brush([[384,385],[392,393]]); panel._tool_buttons[1].pressed.emit()
	_mouse(canvas,Vector2i(7,5),true); _move(canvas,Vector2i(4,3))
	expect(ops.tile(panel._map,Vector2i(4,3),0)==0,"rectangle remains preview until release")
	if capture.is_valid(): await capture.call(panel,"map-rectangle-preview")
	_mouse(canvas,Vector2i(4,3),false)
	expect(ops.tile(panel._map,Vector2i(4,3),0)==384 and ops.tile(panel._map,Vector2i(7,5),0)==385,"reverse rectangle repeats multi tile pattern")
	panel._tool_buttons[4].pressed.emit(); _mouse(canvas,Vector2i(1,1),true); _move(canvas,Vector2i(2,2)); _mouse(canvas,Vector2i(2,2),false)
	panel._copy_selection(); panel._cell=Vector2i(8,1); panel._paste_selection()
	expect(ops.tile(panel._map,Vector2i(8,1),0)==384 and ops.tile(panel._map,Vector2i(9,2),0)==393,"region copy paste retains its entire matrix")
	_mouse(canvas,Vector2i(9,7),true); _mouse(canvas,Vector2i(9,7),false)
	expect(ops.tile(panel._map,Vector2i(10,8),0)==393,"paste tool stamps clipboard on click")
	panel._tool_buttons[3].pressed.emit(); _mouse(canvas,Vector2i(8,1),true); _mouse(canvas,Vector2i(8,1),false)
	expect(ops.tile(panel._map,Vector2i(8,1),0)==0 and ops.tile(panel._map,Vector2i(9,1),0)==385,"eraser only clears the pointed cell")
	_mouse(canvas,Vector2i(9,1),true,MOUSE_BUTTON_RIGHT); _mouse(canvas,Vector2i(9,1),false,MOUSE_BUTTON_RIGHT)
	expect(panel._tile_brush==[[385]] and panel._tool.selected==0,"eyedropper picks actual tile and returns to pencil")
	panel._select_brush([[392]]); panel._layer_buttons[1].pressed.emit(); panel._tool_buttons[2].pressed.emit()
	_mouse(canvas,Vector2i(0,0),true); _mouse(canvas,Vector2i(0,0),false)
	expect(panel._map.data.values.slice(120,240).all(func(id: Variant) -> bool: return int(id)==392),"fill operates on selected middle layer")
	expect(ops.tile(panel._map,Vector2i(9,1),0)==385 and ops.tile(panel._map,Vector2i(0,0),2)==0,"fill preserves other layers")
	panel._undo.pressed.emit()
	panel._layer_buttons[0].pressed.emit(); panel._tool_buttons[0].pressed.emit(); panel._select_brush([[48]])
	_mouse(canvas,Vector2i(0,8),true); _move(canvas,Vector2i(1,8)); _mouse(canvas,Vector2i(1,8),false)
	expect(ops.tile(panel._map,Vector2i(0,8),0)==91 and ops.tile(panel._map,Vector2i(1,8),0)==93,"automatic tile neighbours join after one brush stroke")
	_mouse(canvas,Vector2i(0,8),true,MOUSE_BUTTON_RIGHT)
	expect(panel._brush==91 and palette.palette_region().position==Vector2i(1,0),"right pick retains autotile shape and highlights source slot")
	panel._select_brush([[384]]); _mouse(canvas,Vector2i(0,4),true); _move(canvas,Vector2i(3,4)); panel._cancel_stroke()
	expect(ops.tile(panel._map,Vector2i(0,4),0)==0 and ops.tile(panel._map,Vector2i(3,4),0)==0,"Escape cancels draft stroke completely")
	canvas.set_zoom(1.5); _mouse(canvas,Vector2i(3,7),true); _mouse(canvas,Vector2i(3,7),false)
	expect(ops.tile(panel._map,Vector2i(3,7),0)==384 and panel._zoom_label.text=="150%","zoomed painting writes correct native coordinate")
	var pan = InputEventMouseButton.new(); pan.button_index=MOUSE_BUTTON_MIDDLE; pan.pressed=true; canvas._gui_input(pan)
	var motion = InputEventMouseMotion.new(); motion.relative=Vector2(47,31); var origin: Vector2=canvas._origin; canvas._gui_input(motion)
	pan.pressed=false; canvas._gui_input(pan)
	expect(canvas._origin==origin+Vector2(47,31),"middle mouse pans drawing canvas")
	_mouse(canvas,Vector2i(3,8),true); _mouse(canvas,Vector2i(3,8),false)
	expect(ops.tile(panel._map,Vector2i(3,8),0)==384,"zoom and pan preserve tile hit coordinates")
	panel._select_brush([[384,385],[392,393]])
	_mouse(canvas,Vector2i(11,0),true)
	var release = InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; canvas._input(release)
	expect(not panel._stroke and not canvas._drawing and ops.tile(panel._map,Vector2i(11,0),0)==384 and panel._map.data.values.size()==360,"release outside finishes clipped edge stamp without growing map table")
	panel._undo.pressed.emit(); expect(ops.tile(panel._map,Vector2i(11,0),0)==0,"edge stamp has one complete undo")
	# A refresh after import or save must keep the visible multi tile selection.
	_mouse(palette,Vector2i(0,1),true); _move(palette,Vector2i(1,2)); _mouse(palette,Vector2i(1,2),false)
	panel._refresh_map()
	expect(palette.palette_region().size==Vector2i(2,2) and panel._tile_brush==[[384,385],[392,393]],"refresh keeps multi tile palette selection")
	panel._layer_buttons[3].pressed.emit()
	expect(panel._event_tools.visible and panel._events.visible and not panel._draw_tools.visible,"event mode exposes dedicated event controls")
	panel._layer_buttons[0].pressed.emit(); canvas.set_zoom(1.0); canvas.reset_view()
	expect(panel._map.events==map.events and panel._map.custom_marker==map.custom_marker,"map tools preserve events and custom payload")
	if capture.is_valid():
		_move(canvas,Vector2i(6,7))
		expect(canvas._hover==Vector2i(6,7) and canvas._show_brush,"actual drawing canvas exposes brush hover preview")
		await capture.call(panel,"map-tools")
	expect(panel.save_changes(),"explicit Save writes edited map")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/maps/Map001.json"))
	docs.reload(); panel._load_maps(1)
	expect(panel._map==saved and not saved.has("_editor_map_id"),"reopening reads native saved map without preview fields")
	panel._open_map_properties(true); panel._map_form._put(["name"],"空白新地图"); panel._map_form._put(["width"],9); panel._map_form._put(["height"],7)
	panel._apply_map_properties(); panel._map_dialog.hide()
	expect(panel._map_id==2 and panel._map.width==9 and panel._map.height==7 and panel._map.events.is_empty(),"new map dialog creates a blank native map")
	panel._select_brush([[384]])
	_mouse(canvas,Vector2i(2,2),true); _mouse(canvas,Vector2i(2,2),false)
	panel._layer_buttons[3].pressed.emit(); panel._set_start(); panel._layer_buttons[0].pressed.emit()
	expect(panel.save_changes(),"new map and drawing save in complete batch")
	docs.reload(); panel._load_maps(2)
	expect(panel._map_id==2 and ops.tile(panel._map,Vector2i(2,2),0)==384,"new map can be reopened with painted tile")
	var new_map: Dictionary=panel._map.duplicate(true); var saved_system: Dictionary=docs.read("data/system.json")
	expect(int(saved_system.start_map_id)==2 and int(saved_system.start_x)==2 and int(saved_system.start_y)==2,"new map saves chosen player start")
	if capture.is_valid(): await capture.call(panel,"map-new")
	panel.queue_free(); await tree.process_frame
	return {"saved":saved,"new_map":new_map,"system":saved_system,"tileset":sets[set_id],"folder":folder}

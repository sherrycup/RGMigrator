@tool
extends RefCounted
var checks=0
var failures: Array[String]=[]
var textures: Dictionary={}

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func _mouse(canvas: Control, cell: Vector2i, pressed: bool) -> void:
	var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	event.position=canvas._origin+(Vector2(cell)+Vector2(0.5,0.5))*32*canvas._zoom; canvas._gui_input(event)

func _move(canvas: Control, cell: Vector2i) -> void:
	var event=InputEventMouseMotion.new(); event.position=canvas._origin+(Vector2(cell)+Vector2(0.5,0.5))*32*canvas._zoom; canvas._gui_input(event)

func _paint(dialog: Control, mode: String, cell: Vector2i, end: Vector2i = Vector2i(-1,-1)) -> void:
	dialog._mode_buttons[mode].pressed.emit(); _mouse(dialog._canvas,cell,true)
	if end.x>=0: _move(dialog._canvas,end)
	_mouse(dialog._canvas,cell if end.x<0 else end,false)

func _seed(docs: RefCounted) -> void:
	for key in textures: docs._textures["Tilesets/"+str(key)]=textures[key]

func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary:
	var tree=parent.get_tree(); var schema=load("res://addons/rgm_editor/EditorDatabaseSchema.gd")
	var ops=load("res://addons/rgm_editor/EditorMapOps.gd"); var source_ops=load("res://addons/rgm_editor/EditorTilesetOps.gd")
	var folder="res://.godot/tileset_layers_%d/" % Time.get_ticks_usec()
	for entry in [["房屋.png",256,64,Color("b26347")],["森林.png",256,32,Color("427653")],["高房屋.png",256,96,Color("a28a56")],["窄图.png",128,32,Color("4477aa")]]:
		var image=Image.create(entry[1],entry[2],false,Image.FORMAT_RGBA8); image.fill(entry[3])
		for y in int(entry[2]/32):
			for x in int(entry[1]/32): image.fill_rect(Rect2i(x*32+2,y*32+2,28,28),entry[3].lightened((x+y*8)*0.015))
		textures[entry[0]]=ImageTexture.create_from_image(image)
	var set=schema.new_record("Tilesets",1,original); set.name="房屋 + 森林"; set.tileset_name="房屋.png"
	for field in ["passages","priorities","terrain_tags"]: set[field]=schema.table(400)
	set.passages.values[384]=32; set.passages.custom_flag="保留"; set.custom_definition={"keep":true}
	var system: Dictionary=original.read("data/system.json"); system.start_map_id=1; system.start_x=0; system.start_y=0
	_write(folder+"data/system.json",system); _write(folder+"data/database/Actors.json",original.records("Actors"))
	_write(folder+"data/database/Tilesets.json",[null,set]); _write(folder+"data/manifest.json",{"maps":["Map001","Map002"]})
	_write(folder+"data/map_infos.json",{"1":{"name":"组合图块与扩展图层验收","parent_id":0,"order":1},"2":{"name":"共用图块集的另一张地图","parent_id":1,"order":2}})
	var index: Dictionary=original.read("data/asset_index.json")
	for name in textures: index["Graphics/Tilesets/"+str(name)]="res://assets/Graphics/Tilesets/"+str(name)
	_write(folder+"data/asset_index.json",index)
	var values: Array=[]; values.resize(12*8*3); values.fill(0); values[0]=384; values[1]=392
	var page=original.new_page(); page.graphic.tile_id=384; page.graphic.character_name=""; page.graphic.custom_graphic="保留"
	var map={"width":12,"height":8,"tileset_id":1,"data":{"_rmxp_type":"table","dimensions":3,"x_size":12,"y_size":8,"z_size":3,"values":values},"events":{"1":{"id":1,"name":"图块事件","x":10,"y":6,"pages":[page]}},"custom_map":{"keep":[1,2]}}
	for name in ["Map001","Map002"]: _write(folder+"data/maps/"+name+".json",map)
	set=JSON.parse_string(JSON.stringify(set)); map=JSON.parse_string(JSON.stringify(map))
	var docs=load("res://addons/rgm_editor/EditorDocuments.gd").new(folder); _seed(docs)
	var panel=load("res://addons/rgm_editor/EditorPanel.gd").new(); panel.setup(docs); parent.add_child(panel); await tree.process_frame
	var db=panel._database; db.open_tileset(docs,1); db._open_sources(); var sources=db._sources_dialog
	expect(sources.visible and sources._sources.size()==1,"legacy tileset opens as first source with stable legacy key")
	sources._replacing=false; sources._accept_asset("窄图.png",{})
	expect(sources._sources.size()==1 and sources._status.text.contains("256"),"wrong-width source is rejected without alignment")
	sources._accept_asset("森林.png",{})
	expect(sources._canvas._normal_layout.tile_count==24 and sources._canvas._palette_ids[-1]==407,"second separate image follows first in virtual palette")
	expect(docs.records("Tilesets")[1]==set and docs.read("data/maps/Map001.json")==map,"source browsing stays detached before applying")
	if capture.is_valid(): await capture.call(panel,"tileset-sources")
	sources._accept(); sources.hide()
	var combined: Dictionary=docs.records("Tilesets")[1]
	expect(combined.tileset_sources.size()==2 and combined.passages.values.size()==408,"apply extends all flags for composite sources")
	expect(combined.passages.values[384]==32 and docs.read("data/maps/Map001.json")==map,"append preserves existing IDs and all old flags")
	expect(JSON.parse_string(FileAccess.get_file_as_string(folder+"data/database/Tilesets.json"))==[null,set],"source confirmation remains unsaved on disk")
	expect(docs.undo() and docs.records("Tilesets")[1]==set,"one undo reverts composite definition")
	expect(docs.redo() and docs.records("Tilesets")[1]==combined,"redo restores composite definition")
	db._reload_record(); db._open_sources(); sources._replacing=false; sources._accept_asset("房屋.png",{}); sources._accept(); sources.hide()
	var duplicated: Dictionary=docs.records("Tilesets")[1]
	expect(duplicated.tileset_sources.size()==3 and duplicated.tileset_sources[0].key!=duplicated.tileset_sources[2].key,"same image can occupy distinct stable segments")
	docs.undo(); db._reload_record()
	# Paint all six property types through actual palette input and controls.
	var flags=db._tileset_editor; var palette=flags._canvas
	expect(flags.is_visible_in_tree() and not db._form.visible and not db._preview.visible,"tileset homepage replaces field placeholders with embedded palette and properties")
	expect(db._draft()==db._before,"opening tileset homepage leaves its detached record unchanged")
	for mode in flags._mode_buttons:
		flags._mode_buttons[mode].pressed.emit()
		expect(flags._canvas==palette and flags._canvas.is_visible_in_tree(),"mode reuses visible palette: "+mode)
	flags._tabs.current_tab=1
	expect(palette.is_visible_in_tree(),"asset settings reuse the homepage palette")
	flags._tabs.current_tab=0
	expect(palette.terrain_text(384)=="0" and palette.terrain_text(99999)=="0" and flags._terrain.get_line_edit().text=="0","JSON float terrain tags and integer input display zero without decimals")
	flags._terrain.value=7; flags._name.text_changed.emit("未应用名称")
	expect(not db.pending_status().is_empty() and docs.records("Tilesets")[1]==combined,"homepage controls only change the detached item")
	db._reload_record()
	expect(db._draft()==db._before and flags._canvas==palette,"explicit fixture reload restores homepage properties using the same palette")
	flags._edit_asset(["fog_name"]); var asset=flags._asset_dialog
	asset._settings.hue=120; asset._settings.opacity=137; asset.canceled.emit(); asset.hide()
	expect(db._draft()==db._before,"canceling an image picker preserves the current homepage draft")
	flags._edit_asset(["fog_name"]); asset._settings.hue=120; asset._settings.opacity=137; asset.confirmed.emit(); asset.hide()
	expect(flags.draft().fog_hue==120 and flags.draft().fog_opacity==137 and flags.draft().passages==combined.passages,"background image settings update only related fields")
	flags._background_controls["fog_sx"].value=-3
	expect(flags.draft().fog_sx==-3 and flags.draft().custom_definition==combined.custom_definition,"named background controls retain signed scrolling and unknown metadata")
	db._reload_record()
	var legacy=flags.draft(); legacy.fog_blend_type=77; legacy.priorities.values[48]=8; legacy.terrain_tags.values[48]=23
	flags.configure(legacy,docs); flags._select(48)
	expect(flags.draft()==legacy and flags._priority.value==8 and flags._terrain.value==23,"homepage opening retains legacy values outside standard ranges")
	flags._all(15)
	expect(flags.draft().priorities==legacy.priorities and flags.draft().terrain_tags==legacy.terrain_tags and flags.draft().fog_blend_type==77,"passage editing preserves unrelated legacy values and table metadata")
	db._reload_record()
	_paint(flags,"passages",Vector2i(0,1),Vector2i(2,1))
	expect((int(flags._value.passages.values[384])&15)==15 and (int(flags._value.passages.values[386])&15)==15,"continuous passage brush paints intervening cells")
	expect((int(flags._value.passages.values[384])&32)==32,"native/custom passage bits survive painting")
	_paint(flags,"priorities",Vector2i(0,3),Vector2i(2,3))
	expect(flags._value.priorities.values[400]==1 and flags._value.priorities.values[402]==1,"priority brush works in second source")
	_paint(flags,"bush",Vector2i(0,3)); _paint(flags,"counter",Vector2i(0,3)); _paint(flags,"terrain_tags",Vector2i(0,3))
	expect((int(flags._value.passages.values[400])&192)==192 and flags._value.terrain_tags.values[400]==1,"bush counter and terrain flags edit per cell")
	flags._select(400); flags._directions[0].button_pressed=false; flags._directions[3].button_pressed=false
	_paint(flags,"directions",Vector2i(1,3),Vector2i(2,3))
	expect((int(flags._value.passages.values[401])&15)==9 and (int(flags._value.passages.values[402])&15)==9,"direction brush copies chosen four-direction pattern")
	_paint(flags,"passages",Vector2i(1,0))
	expect(flags._value.passages.values.slice(48,96).all(func(n: Variant) -> bool: return (int(n)&15)==15),"one automatic slot updates all 48 connection shapes")
	flags._mode_buttons["priorities"].pressed.emit()
	if capture.is_valid(): await capture.call(panel,"tileset-priority-markers")
	flags._mode_buttons["terrain_tags"].pressed.emit()
	expect(palette.terrain_text(400)=="1","edited terrain overlay displays an integer")
	if capture.is_valid(): await capture.call(panel,"tileset-terrain-markers")
	expect(db.apply_current(),"homepage flags apply to composite item")
	expect(flags._canvas==palette,"applying the item keeps the palette instance")
	db.hide(); panel._load_map(1)
	# Dynamic layers keep fourth layer independent of event editing.
	panel._add_layer(); expect(ops.layer_count(panel._map)==4 and panel._layer.selected==3 and not panel._event_mode,"fourth tile layer is drawing mode")
	panel._select_brush([[400]]); _mouse(panel._canvas,Vector2i(2,2),true); _mouse(panel._canvas,Vector2i(2,2),false)
	expect(ops.tile(panel._map,Vector2i(2,2),3)==400 and panel._map.events==map.events,"fourth-layer stroke preserves event collection")
	panel._add_layer(); panel._select_brush([[384,385],[392,393]]); _mouse(panel._canvas,Vector2i(4,2),true); _mouse(panel._canvas,Vector2i(4,2),false)
	expect(ops.layer_count(panel._map)==5 and ops.tile(panel._map,Vector2i(5,3),4)==393,"fifth layer accepts multi-tile brush")
	panel._region=Rect2i(4,2,2,2); panel._copy_selection(); panel._cell=Vector2i(7,2); panel._paste_selection()
	expect(ops.tile(panel._map,Vector2i(8,3),4)==393,"copy paste uses actual fifth layer")
	panel._visibility_buttons[4].button_pressed=false
	var hidden_before: Dictionary=panel._map.duplicate(true); panel._select_brush([[400]]); _mouse(panel._canvas,Vector2i(0,3),true); _mouse(panel._canvas,Vector2i(0,3),false)
	expect(panel._map==hidden_before and 4 in panel._canvas._hidden_layers,"hidden selected layer blocks painting and is hidden only in editor")
	panel._visibility_buttons[4].button_pressed=true; panel._choose_events()
	expect(panel._event_mode and panel._layer.selected==5 and panel._event_tools.visible,"event mode remains separate after two added tile layers")
	panel._choose_layer(4)
	if capture.is_valid(): await capture.call(panel,"map-five-layers")
	var reduced=panel._map.duplicate(true); var rejected=ops.set_layer_count(reduced,3)
	expect(not rejected.ok and reduced==panel._map,"nonempty layers cannot be removed")
	panel._open_map_properties(false); panel._map_form._put(["width"],14); panel._map_form._put(["height"],10); panel._map_form._put(["layer_names",4],"屋顶与装饰")
	panel._apply_map_properties(); panel._map_dialog.hide()
	expect(panel._map.width==14 and ops.layer_count(panel._map)==5 and ops.tile(panel._map,Vector2i(8,3),4)==393,"resize keeps all actual layers")
	expect(panel._layer_buttons[4].text.contains("屋顶与装饰"),"layer name drives generated controls")
	panel._cell=Vector2i(13,9); panel._set_start(); panel._open_map_properties(false); panel._map_form._put(["width"],12)
	panel._apply_map_properties(); panel._map_dialog.hide(); expect(panel._map.width==14,"resize cannot discard saved player start")
	panel._cell=Vector2i.ZERO; panel._set_start()
	panel._open_map_properties(false); panel._map_form._put(["parent_id"],2); panel._apply_map_properties(); panel._map_dialog.hide()
	expect(docs.read("data/map_infos.json")["1"].parent_id==0,"parent cycle rejected without partial write")
	panel._open_map_properties(false); panel._map_form._put(["parent_id"],999); panel._apply_map_properties(); panel._map_dialog.hide()
	expect(docs.read("data/map_infos.json")["1"].parent_id==0,"missing parent rejected")
	panel._duplicate_map(); expect(panel._map_id==3 and ops.layer_count(panel._map)==5 and panel._map.custom_map==map.custom_map,"map duplication retains extra layers and unknown fields")
	panel._undo_action(); expect(not "Map003" in docs.read("data/manifest.json").maps and docs.read("data/maps/Map003.json")==null,"one undo removes duplicated map and metadata together")
	panel._redo_action(); panel._load_map(1)
	# Reorder remaps every shared map and event graphic in one draft transaction.
	panel._select_brush([[400]]); panel._tile_clipboard=[[400]]; panel._event_clipboard=panel._map.events["1"].duplicate(true)
	db.open_tileset(docs,1); db._open_sources(); sources._selected=1; sources._move(-1)
	var old_set: Dictionary=docs.records("Tilesets")[1]; var old_maps: Dictionary={}
	for name in docs.read("data/manifest.json").maps: old_maps[name]=docs.read("data/maps/"+str(name)+".json")
	sources._accept(); sources.hide(); var reordered: Dictionary=docs.records("Tilesets")[1]
	expect(reordered.tileset_sources[0].name=="森林.png" and reordered.passages.values[392]==old_set.passages.values[384],"reordering preserves flags by stable source and local cell")
	for name in old_maps:
		var remapped: Dictionary=docs.read("data/maps/"+str(name)+".json")
		expect(ops.tile(remapped,Vector2i.ZERO,0)==392 and remapped.events["1"].pages[0].graphic.tile_id==392,"reorder synchronizes map and event "+str(name))
		expect(remapped.custom_map==map.custom_map and remapped.events["1"].pages[0].graphic.custom_graphic=="保留","reorder preserves unknown map and graphic fields")
	expect(docs.undo() and docs.records("Tilesets")[1]==old_set and docs.read("data/maps/Map001.json")==old_maps.Map001,"one undo restores definitions and all map IDs")
	expect(docs.redo() and docs.records("Tilesets")[1]==reordered,"one redo restores whole remapping transaction")
	var removal=reordered.duplicate(true); removal.tileset_sources.remove_at(1)
	expect(not source_ops.prepare(docs,1,reordered,removal).ok,"removal of used source is blocked")
	var cropped=reordered.duplicate(true); cropped.tileset_sources[1].rows=1
	cropped.tileset_sources[1].name="森林.png"
	expect(not source_ops.prepare(docs,1,reordered,cropped).ok,"cropped source is rejected before references can disappear")
	var grown=reordered.duplicate(true); grown.tileset_sources[0].name="高房屋.png"; grown.tileset_sources[0].rows=3; grown.tileset_name="高房屋.png"
	var grown_plan=source_ops.prepare(docs,1,reordered,grown)
	expect(grown_plan.ok and grown_plan.changes["data/maps/Map001.json"].events["1"].pages[0].graphic.tile_id==408,"resized first source remaps later map and event IDs safely")
	var malformed=reordered.duplicate(true); malformed.tileset_sources[1].key=malformed.tileset_sources[0].key
	expect(not source_ops.prepare(docs,1,reordered,malformed).ok,"duplicate segment keys rejected")
	malformed=reordered.duplicate(true); malformed.tileset_sources[1].rows=1.5
	expect(not source_ops.prepare(docs,1,reordered,malformed).ok,"fractional source rows rejected")
	var invalid=docs.read("data/maps/Map001.json"); invalid.data.z_size=0
	var before_failure=docs.read("data/map_infos.json"); var changed_info=before_failure.duplicate(true); changed_info["1"].name="不得应用"
	expect(not docs.apply_batch({"data/map_infos.json":changed_info,"data/maps/Map001.json":invalid}).ok and docs.read("data/map_infos.json")==before_failure,"invalid batch rolls back all prospective changes")
	db._reload_record(); db._tileset_editor.sources_requested.emit()
	expect(sources.visible and sources._sources.size()==2,"homepage material button opens the composite source manager")
	sources.hide(); db.hide(); panel._load_map(1)
	expect(panel._brush==0 and panel._tile_clipboard.is_empty() and panel._event_clipboard.is_empty(),"changed segment numbering clears stale brush and tile/event clipboards")
	panel._visibility_buttons[4].button_pressed=false
	expect(panel.save_changes(),"explicit save commits maps metadata and composite database")
	var saved_set: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/database/Tilesets.json"))[1]
	var saved_map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/maps/Map001.json"))
	db._form.configure({},schema.LABELS,null)
	docs.reload(); _seed(docs); panel._load_maps(1)
	expect(panel._map==saved_map and docs.records("Tilesets")[1]==saved_set,"reopen reads full saved composite and five layers")
	expect(docs.dirty_paths().is_empty() and panel._map.data.z_size==5,"reopened saved state is clean")
	# Event selector and preview must use second image after reorder.
	panel._event_id=1; panel._open_event(false); panel._settings._open_tile_graphic()
	var picker=panel._settings._tile_dialog
	expect(picker._palette._normal_layout.locate(392).name=="房屋.png","event graphic palette resolves second source")
	picker._palette.tile_selected.emit(392); var atlas: AtlasTexture=picker._preview._image.texture
	expect(atlas!=null and atlas.atlas==textures["房屋.png"],"event preview uses selected source texture")
	if capture.is_valid(): await capture.call(panel,"event-composite-tile")
	picker.hide(); panel._event_dialog.hide(); panel.queue_free(); await tree.process_frame
	return {"map":saved_map,"tileset":saved_set,"folder":folder,"textures":textures}

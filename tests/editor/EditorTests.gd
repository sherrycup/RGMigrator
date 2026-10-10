extends SceneTree
var _checks =0
var _failures: Array[String]=[]
var _panel: Control
var _documents: RefCounted
var _folder: String
var Commands: GDScript
var Ops: GDScript
var Scripts: GDScript

func _init() -> void:
	call_deferred("run")

func expect(ok: bool,message: String) -> void:
	_checks+=1
	if not ok: _failures.append(message)

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: printerr("FAIL: editor tests timed out"); quit(1))
	Commands=load("res://addons/rgm_editor/EditorCommands.gd")
	Ops=load("res://addons/rgm_editor/EditorMapOps.gd")
	Scripts=load("res://addons/rgm_editor/EditorScriptAdapter.gd")
	var docs_script =load("res://addons/rgm_editor/EditorDocuments.gd")
	var original =docs_script.new()
	var manifest: Dictionary=original.read("data/manifest.json")
	var event_count =0; var page_count =0; var note_count =0
	for name in manifest.maps:
		var map: Dictionary=original.read("data/maps/"+str(name)+".json")
		var adapted: Dictionary=Scripts.adapt_map(map)
		expect(Scripts.adapt_map(adapted)==adapted,"script placeholder conversion is idempotent: "+str(name))
		for event in adapted.get("events",{}).values():
			event_count+=1
			for page in event.get("pages",[]):
				page_count+=1
				expect(page.get("list",[]) is Array and page.get("condition",{}) is Dictionary,"original event page opens")
				for c in page.list:
					if c.has("_editor_original"): note_count+=1
					expect(int(c.get("code",0)) not in [355,655] and not (int(c.get("code",0))==111 and not c.parameters.is_empty() and int(c.parameters[0])==12),"map Ruby execution replaced by preserved authoring note")
	print("OPENED: ",manifest.maps.size()," maps / ",event_count," events / ",page_count," pages / ",note_count," script notes")
	# Open the actual original events in the same window used by the plugin.
	var source_panel: Control=load("res://addons/rgm_editor/EditorPanel.gd").new()
	source_panel.setup(original); root.add_child(source_panel)
	for name in manifest.maps:
		source_panel._load_map(str(name).trim_prefix("Map").to_int())
		for key in source_panel._map.get("events",{}):
			source_panel._event_id=int(key); source_panel._open_event(false)
			for page_index in source_panel._event_draft.pages.size():
				source_panel._choose_page(page_index)
				expect(source_panel._settings.draft().get("condition",{})==source_panel._map.events[key].pages[page_index].get("condition",{}),"original page condition opens in actual typed form")
			source_panel._event_dialog.hide()
	source_panel.queue_free(); await process_frame
	await _test_route_authoring(original)
	for code in Commands.available(): expect(Commands.Catalog.reason(code,Commands.defaults(code)).is_empty(),"new command defaults valid: "+str(code))
	var raw: Dictionary={"events":{"1":{"pages":[{"list":[Commands.command(355,0,["x = 1"]),Commands.command(655,0,["y = 2"]),Commands.command(111,0,[12,"test"]),Commands.command(125,1,[0,0,1]),Commands.command(411),Commands.command(125,1,[1,0,2]),Commands.command(412),Commands.command(0)],"move_route":{"repeat":true,"skippable":false,"list":[{"code":45,"parameters":["move_script"]},{"code":3,"parameters":[]},{"code":0,"parameters":[]}]}}]}}}
	var adapted: Dictionary=Scripts.adapt_map(raw)
	expect(raw.events["1"].pages[0].list[0].code==355,"adapter never mutates source")
	expect(adapted.events["1"].pages[0].move_route._editor_original_route==raw.events["1"].pages[0].move_route,"entire original Ruby route preserved")
	expect(adapted.events["1"].pages[0].list[2]._editor_original.size()==5,"script conditional retains entire branch")
	var common: Array=[null,{"id":1,"trigger":0,"switch_id":1,"name":"公共事件","list":raw.events["1"].pages[0].list.duplicate(true)}]
	var common_notes: Array=Scripts.adapt_common(common)
	expect(common[1].list[0].code==355 and common_notes[1].list[0].code==108,"common Ruby becomes preserved comment without changing original")
	expect(common_notes[1].id==1 and common_notes[1].name=="公共事件","common event identity preserved for map calls")
	var tiny =blank_map(5,5)
	Ops.paint(tiny,[Vector2i(2,2)],0,48)
	expect(Ops.tile(tiny,Vector2i(2,2),0)==94,"isolated autotile uses native isolated quarter variant")
	Ops.paint(tiny,[Vector2i(2,3)],0,48)
	expect(Ops.tile(tiny,Vector2i(2,2),0)==90 and Ops.tile(tiny,Vector2i(2,3),0)==92,"autotiles reconnect adjacent cells")
	expect(Ops.flood_cells(tiny,Vector2i(0,0),0).size()==23,"fill follows contiguous same-slot cells")
	Ops.paint(tiny,[Vector2i(1,1)],2,384)
	Ops.resize_map(tiny,6,6)
	expect(Ops.tile(tiny,Vector2i(1,1),2)==384 and tiny.data.values.size()==108,"resize preserves x/y/layer table addressing")
	await _test_interface(original)
	_test_transactions()
	_test_runtime()
	if _panel!=null: _panel.queue_free(); await process_frame
	for failure in _failures: printerr("FAIL: ",failure)
	print("EDITOR TESTS: ","PASSED" if _failures.is_empty() else "FAILED"," / ",_checks," checks")
	quit(0 if _failures.is_empty() else 1)

func blank_map(width: int,height: int) -> Dictionary:
	var values: Array=[]; values.resize(width*height*3); values.fill(0)
	return {"_class":"RPG::Map","width":width,"height":height,"tileset_id":1,"data":{"_rmxp_type":"table","dimensions":3,"x_size":width,"y_size":height,"z_size":3,"values":values},"events":{},"bgm":{"name":"","volume":100,"pitch":100},"bgs":{"name":"","volume":100,"pitch":100}}

func write_file(path: String,value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file =FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value,"\t",false)); file.close()

func _field(tree: Tree, path: Array) -> TreeItem:
	var pending: Array = [tree.get_root()]
	while not pending.is_empty():
		var item: TreeItem = pending.pop_back()
		if item.get_metadata(0) == path: return item
		pending.append_array(item.get_children())
	return null

func _test_route_authoring(original: RefCounted) -> void:
	var dialog = load("res://addons/rgm_editor/EditorCommandDialog.gd").new(); root.add_child(dialog)
	dialog.open(original,209,[],true,{"17":"17 箱子"})
	expect(dialog._route_form.visible and dialog._form._hints["0"].options["17"] == "17 箱子","209 opens dedicated route panel with named target choices")
	var form = dialog._route_form
	var right: Button
	for button in form._buttons:
		if button.text == "向右移动": right = button
	for i in 3: right.pressed.emit()
	expect(form.draft().list.map(func(c: Variant) -> int: return int(c.code)) == [3,3,3,0],"route movement buttons create three ordered right steps")
	form._insert(15); form._param_form._put([0],5); form._accept_parameters()
	expect(form.draft().list[-2].parameters == [5],"wait action popup edits actual route parameter")
	var route: Dictionary = form.draft(); route["custom_marker"] = "preserve"; route.list[0]["custom_action"] = 7
	form.configure(route,original); form._repeat.button_pressed = true; form._skip.button_pressed = true
	expect(form.draft().repeat and form.draft().skippable and form.draft().custom_marker == "preserve","route flags retain unknown original metadata")
	form._list.get_root().get_first_child().select(0); form._copy_selected(); form._move_selected(1); form._delete_selected()
	expect(form.draft().list[0].custom_action == 7 and int(form.draft().list[-1].code) == 0,"route action copying/reordering/deletion preserves metadata and terminal marker")
	var captured: Array = []; dialog.accepted.connect(func(code: int, p: Array) -> void: captured.append({"code":code,"parameters":p}))
	dialog._accept(); dialog.hide()
	expect(captured.size() == 1 and Commands.Catalog.reason(209,captured[0].parameters).is_empty(),"route panel submits valid native209 parameters")
	var page = original.new_page(); page.erase("list"); page.move_route = route.duplicate(true)
	var settings = load("res://addons/rgm_editor/EditorValueForm.gd").new(); root.add_child(settings); settings.configure(page,{},original)
	expect(settings._array_buttons.all(func(b: Button) -> bool: return not b.visible) and settings._page_buttons.all(func(b: Button) -> bool: return not b.visible),"event page hides irrelevant array and pagination toolbar")
	_field(settings._tree,["move_route"]).select(0); settings._edit_selected()
	expect(settings._route_dialog.visible,"autonomous route field opens its own second-level route window")
	settings._route_dialog._form._insert(1)
	expect(settings.draft().move_route == route,"route popup uses detached draft until accepted")
	settings._route_dialog._accept()
	expect(int(settings.draft().move_route.list[-2].code) == 1 and settings.draft().move_route.custom_marker == "preserve","autonomous route confirmation applies route and preserves unknown fields")
	settings.queue_free(); dialog.queue_free(); await process_frame

func _test_interface(original: RefCounted) -> void:
	_folder="res://.godot/editor_fixture_"+str(Time.get_ticks_usec())+"/"
	_documents=load("res://addons/rgm_editor/EditorDocuments.gd").new(_folder)
	write_file(_folder+"data/manifest.json",{"maps":["Map001"]})
	write_file(_folder+"data/map_infos.json",{"1":{"name":"编辑器验收","parent_id":0,"order":1}})
	var system: Dictionary=original.read("data/system.json"); system.start_map_id=1; system.start_x=0; system.start_y=0
	write_file(_folder+"data/system.json",system)
	for db in ["Tilesets","Actors","CommonEvents"]: write_file(_folder+"data/database/"+db+".json",original.records(db))
	write_file(_folder+"data/asset_index.json",original.read("data/asset_index.json"))
	write_file(_folder+"data/maps/Map001.json",blank_map(6,5))
	_panel=load("res://addons/rgm_editor/EditorPanel.gd").new(); _panel.setup(_documents); root.add_child(_panel); await process_frame
	expect(_panel._map.width==6 and _panel._map_id==1,"editor opens native map without starting a game")
	expect(root.get_node("RuntimeState").game()==null,"editor preview has no live game")
	_panel._choose_layer(0); _panel._select_brush([[384]]); _panel._press_cell(Vector2i(1,1),false,MOUSE_BUTTON_LEFT); _panel._finish_stroke()
	expect(int(_documents.read("data/maps/Map001.json").data.values[7])==384,"pencil commits actual map draft")
	_panel._undo_action(); expect(Ops.tile(_panel._map,Vector2i(1,1),0)==0,"map undo restores tile")
	_panel._redo_action(); expect(Ops.tile(_panel._map,Vector2i(1,1),0)==384,"map redo restores paint")
	_panel._choose_layer(3); _panel._cell=Vector2i(2,2); _panel._open_event(true)
	_panel._event_name.text="验收NPC"
	# Exercise the form dialog rather than injecting already built JSON.
	_panel._add_command(); _panel._command_dialog._form._put([0],"你好\n第二行"); _panel._command_dialog._accept(); _panel._command_dialog.hide()
	expect(_panel._event_draft.pages[0].list[0].code==101 and _panel._event_draft.pages[0].list[1].code==401,"article form emits native text continuations")
	_panel._command_list.deselect_all(); _panel._add_command(); _panel._command_dialog._code=102; _panel._command_dialog._parameters=[["开门","离开"],5]; _panel._command_dialog._update_form(); _panel._command_dialog._accept(); _panel._command_dialog.hide()
	var list: Array=_panel._event_draft.pages[0].list
	var branch =0
	for i in list.size():
		if int(list[i].code)==402: branch=i; break
	_panel._command_index=branch; _panel._adding_command=true; _panel._accept_command(125,[0,0,5])
	_panel._command_index=2; _panel._adding_command=false; _panel._accept_command(102,[["打开门","走开","看看"],5])
	list=_panel._event_draft.pages[0].list
	expect(list.any(func(c: Variant) -> bool: return int(c.code)==125) and Commands.validate_structure(list).is_empty(),"choice edits retain branch commands and valid nesting")
	_panel._command_list.deselect_all(); _panel._add_command(); _panel._command_dialog._code=111; _panel._command_dialog._parameters=[0,1,0]; _panel._command_dialog._update_form(); _panel._command_dialog._form._put([0],1); await process_frame
	expect(_panel._command_dialog._form.draft().size()==5,"condition selector rebuilds typed variable comparison fields")
	_panel._command_dialog._accept(); _panel._command_dialog.hide()
	_panel._settings._put(["condition","self_switch_valid"],true)
	_panel._settings._put(["condition","self_switch_ch"],"B")
	_panel._settings._put(["trigger"],4)
	_panel._copy_page(); expect(_panel._event_draft.pages.size()==2,"event page copying supported")
	_panel._settings._put(["trigger"],0)
	_panel._apply_event(); _panel._event_dialog.hide()
	expect(_panel._map.events["1"].pages[0].trigger==4 and _panel._map.events["1"].pages[1].condition.self_switch_ch=="B","event apply retains per-page conditions and triggers")
	_panel._copy_selection(); _panel._cell=Vector2i(3,2); _panel._paste_selection()
	expect(_panel._map.events.size()==2 and _panel._map.events["2"].x==3,"event copy gets unique ID and destination")
	_panel._set_start(); expect(_documents.read("data/system.json").start_x==3,"map tool sets actual player start")
	expect(_panel.save_changes(),"editor saves maps and system")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(_folder+"data/maps/Map001.json"))
	expect(saved.events["1"].name=="验收NPC" and not saved.has("_editor_map_id"),"saved data is native runtime input without preview fields")
	_panel._open_map_properties(true); _panel._map_form._put(["name"],"新地图"); _panel._map_form._put(["width"],8); _panel._apply_map_properties(); _panel._map_dialog.hide()
	expect(_panel._map_id==2 and _panel._map.width==8,"new map updates manifest and properties")
	_panel._undo_action(); expect(_panel._map_id==1 and _documents.read("data/manifest.json").maps.size()==1,"map creation undo groups file changes")
	_panel._redo_action(); expect(_documents.read("data/maps/Map002.json").width==8 and _documents.read("data/manifest.json").maps.size()==2,"map creation redo restores complete batch")
	expect(_panel.save_changes(),"new map saves complete batch")

func _test_transactions() -> void:
	var map: Dictionary=_documents.read("data/maps/Map001.json")
	map["custom_payload"]={"floor_monsters":[1,2,3],"untouched":"preserve"}
	_documents.apply("data/maps/Map001.json",map)
	expect(_documents.save_all().ok,"unknown custom data saves")
	var before =FileAccess.get_file_as_string(_folder+"data/maps/Map001.json")
	var system: Dictionary=_documents.read("data/system.json"); system.start_x=1; _documents.apply("data/system.json",system)
	map.events["1"].x=100; _documents.apply("data/maps/Map001.json",map)
	expect(not _documents.save_all().ok and FileAccess.get_file_as_string(_folder+"data/maps/Map001.json")==before,"invalid coordinate blocks entire save batch")
	_documents.undo(); _documents.undo()
	map=_documents.read("data/maps/Map001.json"); map.events["1"].name="草稿"; _documents.apply("data/maps/Map001.json",map)
	var full =_folder+"data/maps/Map001.json"; var file =FileAccess.open(full,FileAccess.WRITE); file.store_string(before+"\n "); file.close()
	expect(not _documents.save_all().ok and FileAccess.get_file_as_string(full)==before+"\n ","external edit conflict never overwrites disk")
	write_file(full,JSON.parse_string(before)); _documents.reload()
	expect(not _documents.apply("../outside.json",{}).ok,"authoring paths cannot escape data")

func _test_runtime() -> void:
	var state: Node=root.get_node("RuntimeState")
	var interpreter: RefCounted=load("res://runtime/scripts/EventInterpreter.gd").new()
	var errors: Array=[]; interpreter.diagnostic_requested.connect(func(m: String) -> void: errors.append(m))
	state.begin_new_game(load("res://runtime/scripts/RuntimeData.gd").system())
	var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(_folder+"data/maps/Map001.json"))
	var list: Array=map.events["1"].pages[0].list
	interpreter.start(list,1)
	expect(interpreter.wait_state.kind=="message","saved editor event requests real message")
	interpreter.resume_message(); expect(interpreter.wait_state.kind=="choice","saved editor event requests real choices")
	var before =state.gold; interpreter.resume_choice(0)
	expect(state.gold==before+5 and not interpreter.running and errors.is_empty(),"saved event executes chosen branch through real interpreter")
	state.set_event_variable(9901,0)
	interpreter.start([Commands.command(111,0,[0,1,1]),Commands.command(0,1),Commands.command(411),Commands.command(0,1),Commands.command(412),Commands.command(122,0,[9901,9901,0,0,7]),Commands.command(0)],1)
	expect(int(state.variables.get("9901",0))==7,"RM empty-branch placeholders do not terminate later commands")

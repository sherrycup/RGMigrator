extends SceneTree
## Opens real source records, edits detached fixtures, then runs their saved data.
var _checks=0
var _failures: Array[String]=[]
var _folder=""
var _docs: RefCounted
var _dialog: ConfirmationDialog
var _animation_id=0
var Schema: GDScript
var Commands: GDScript

func _init() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
	_checks+=1
	if not ok: _failures.append(message)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: printerr("FAIL: database tests timed out"); quit(1))
	Schema=load("res://addons/rgm_editor/EditorDatabaseSchema.gd"); Commands=load("res://addons/rgm_editor/EditorCommands.gd")
	var source=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	_dialog=load("res://addons/rgm_editor/EditorDatabaseDialog.gd").new(); root.add_child(_dialog); _dialog.open(source)
	var count=0; var common_count=0; var notes=0
	for category in ([] if "--fixture-only" in OS.get_cmdline_user_args() else Schema.CATEGORIES.keys()):
		_choose(category)
		if category=="System":
			expect(_dialog._draft()==source.read("data/system.json"),"all original system fields survive opening")
			continue
		var records: Array=source.records(category)
		for i in range(1,records.size()):
			if not records[i] is Dictionary: continue
			count+=1; _dialog._load_record(i)
			var value: Dictionary=_dialog._draft()
			# Imported frame counters are retained unless edited; normalization matches valid originals.
			expect(value==records[i],"original %s[%d] opens without field loss" % [category,i])
			if category=="CommonEvents":
				common_count+=1
				expect(_dialog._form._hint(["trigger"]).options.size()==3,"common trigger has its own three modes")
				var remaining=0
				for c in value.list:
					if c.has("_editor_original"): notes+=1
					var valid=int(c.code) not in [355,655]
					if int(c.code)==355 and c.has("_script_binding"):
						var unit: Dictionary=source.read("data/script_units.json").get("units",{}).get(c._script_binding.unit_id,{})
						valid=unit.get("status")=="generated" and unit.get("source_sha256")==c._script_binding.source_sha256
						remaining=int(c._script_binding.command_count)-1
					elif int(c.code) in [355,655]: valid=remaining>0; remaining-=1
					expect(valid,"common Ruby is retained as a verified generated binding or an unsupported placeholder")
			if i%100==0: await process_frame
	print("DATABASE OPENED: ",count," records / ",common_count," common events / ",notes," script notes")
	expect(source.dirty_paths().is_empty(),"opening original database never writes or dirties valid source definitions")
	_dialog.hide(); _dialog.queue_free(); await process_frame
	_fixture(source)
	_dialog=load("res://addons/rgm_editor/EditorDatabaseDialog.gd").new(); root.add_child(_dialog); _dialog.open(_docs)
	_edit_definitions()
	var ids=_author_common_events()
	_test_guards()
	var saved: Dictionary=_docs.save_all()
	expect(saved.ok and int(saved.get("count",0))>=5,"database/common/system save together: "+str(saved.get("message","")))
	var reopened=load("res://addons/rgm_editor/EditorDocuments.gd").new(_folder)
	expect(reopened.records("Actors")[1].parameters.values[6]==1234,"growth value persists in native Table addressing")
	expect(reopened.records("Animations")[_animation_id].frames[0].cell_max==1,"normalized animation cell counter remains after navigation and disk reopen")
	expect(reopened.records("Items")[1].price==77 and int(reopened.records("Items")[1].common_event_id)==int(ids[0]),"price and public event link survive disk reopen")
	expect(reopened.read("data/system.json").variables[1]=="验收变量","system variable names persist without ID shift")
	_run_saved_runtime(reopened,ids)
	_test_conflict(reopened)
	_dialog.queue_free(); await process_frame
	for failure in _failures: printerr("FAIL: ",failure)
	print("DATABASE EDITOR TESTS: ","PASSED" if _failures.is_empty() else "FAILED"," / ",_checks," checks")
	quit(0 if _failures.is_empty() else 1)

func _apply() -> bool:
	var ok=_dialog.apply_current()
	if not ok: print("APPLY REJECTED: ",_dialog._category," / ",_dialog._status.text)
	return ok

func _choose(category: String) -> void:
	for i in _dialog._categories.item_count:
		if _dialog._categories.get_item_metadata(i)==category: _dialog._categories.select(i); _dialog._select_category(i); return

func _fixture(source: RefCounted) -> void:
	_folder=ProjectSettings.globalize_path("res://.godot/database_fixture_%d" % Time.get_ticks_usec())
	for path in ["data/system.json","data/manifest.json","data/map_infos.json","data/test_setup.json","data/asset_index.json"]:
		_write(path,source.read(path))
	for category in Schema.CATEGORIES:
		if category!="System": _write("data/database/"+category+".json",source.records(category))
	_docs=load("res://addons/rgm_editor/EditorDocuments.gd").new(_folder)

func _write(path: String, value: Variant) -> void:
	var full=_folder.path_join(path); DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file=FileAccess.open(full,FileAccess.WRITE); file.store_string(JSON.stringify(value,"\t")); file.close()

func _field(path: Array) -> void:
	var todo: Array=[_dialog._form._tree.get_root()]
	while not todo.is_empty():
		var item: TreeItem=todo.pop_back()
		if item.get_metadata(0)==path: item.select(0); _dialog._form._edit_selected(); return
		todo.append_array(item.get_children())
	expect(false,"field exists: "+str(path))

func _edit_definitions() -> void:
	_choose("Actors"); _dialog._load_record(1)
	var original: Dictionary=_dialog._before.duplicate(true)
	_field(["parameters"])
	var table: ConfirmationDialog=_dialog._form._table_dialog
	expect(table.visible and table._tree.columns==7,"growth opens six editable native parameter columns")
	table._value.values[6]=1234; table.confirmed.emit(); table.hide()
	expect(_dialog.pending_status()!="" and _docs.records("Actors")[1]==original,"table edits remain detached until apply")
	expect(_apply(),"apply growth record")
	expect(_docs.undo() and _docs.records("Actors")[1]==original,"database undo restores entire source record")
	expect(_docs.redo() and _docs.records("Actors")[1].parameters.values[6]==1234,"database redo retains typed table")
	_choose("Classes"); _dialog._load_record(1)
	_field(["weapon_set"])
	var picker: ConfirmationDialog=_dialog._form._set_dialog
	expect(picker.visible,"equipment permissions have multi-select editor")
	picker._ids=[1]; picker.confirmed.emit(); picker.hide()
	expect(_apply(),"apply equipment permissions")
	_dialog._form._hints["learnings"]={"item_default":{"_class":"RPG::Class::Learning","level":1,"skill_id":1}}
	_dialog._form._put(["learnings"],[])
	for item in _dialog._form._tree.get_root().get_children():
		if item.get_metadata(0)==["learnings"]: item.select(0); _dialog._form._add_selected(); break
	expect(_dialog._form.draft().learnings[0] is Dictionary,"empty learning lists create typed learning records")
	expect(_dialog._form._hint(["learnings",0,"skill_id"]).get("db")=="Skills","new nested learning field keeps named skill picker")
	expect(_apply(),"save learning record")
	_choose("Items"); _dialog._load_record(1); _dialog._form._put(["price"],77)
	expect(_apply(),"edit item price")
	_dialog._new_record(true); var clone=_dialog._id
	expect(clone>1 and _docs.records("Items")[clone].id==clone,"copy assigns new stable ID")
	_dialog._clear_record()
	expect(_docs.records("Items")[clone].id==clone and _docs.records("Items")[clone].name=="","clear retains slot and ID")
	_choose("System")
	_dialog._form._put(["variables",1],"验收变量")
	var size=_dialog._form.draft().variables.size()
	for item in _dialog._form._tree.get_root().get_children():
		if item.get_metadata(0)==["variables"]:
			var first=item.get_first_child(); first.select(0); _dialog._form._delete_selected(); _dialog._form._move_selected(1); break
	expect(_dialog._form.draft().variables.size()==size and _dialog._form.draft().variables[1]=="验收变量","indexed name arrays cannot delete or reorder IDs")
	expect(_apply(),"save system naming")
	_choose("Animations"); _dialog._new_record(false)
	_animation_id=_dialog._id
	_field(["frames",0,"cell_data"]); table=_dialog._form._table_dialog
	table._width.value=1
	expect(table._value.values==[-1,0,0,100,0,0,255,0],"new animation cells receive visible neutral defaults with hidden pattern")
	table.confirmed.emit(); table.hide()
	expect(_apply(),"save edited animation cell table")
	var animation: Dictionary=_docs.records("Animations")[_dialog._id]
	expect(animation.frame_max==1 and animation.frames[0].cell_max==1,"animation frame and cell counters sync automatically")
	expect(load("res://runtime/scripts/RmxpAnimationData.gd").compile(animation).ok,"authored animation uses real runtime compiler")
	_choose("Tilesets"); _dialog._load_record(1)
	var tiles: Control=_dialog._tileset_editor
	var priorities=tiles.draft().priorities; tiles._select(48); tiles._all(15)
	expect(_dialog.apply_current() and int(_docs.records("Tilesets")[1].passages.values[48])==15,"tile passage is editable directly on database homepage")
	expect(_docs.records("Tilesets")[1].priorities==priorities,"tile passage retains other tables")
	expect(tiles.visible and not _dialog._form.visible and not tiles._canvas._palette_ids.is_empty(),"tile flags replace placeholders with persistent source palette")
	tiles._select(384); tiles._all(15); tiles._terrain.value=7; tiles._priority.value=0
	tiles._select(96); tiles._all(0); tiles._bush.button_pressed=true
	expect(tiles._value.passages.values.slice(96,144).all(func(n: Variant) -> bool: return (int(n)&15)==0 and (int(n)&64)!=0),"autotile flag edits update all 48 shape IDs")
	expect(_apply(),"apply visual tile flags to shared definition")
	_choose("Troops"); var preserved=_dialog._draft(); _dialog._clear_record(); _dialog._new_record(false)
	expect(_dialog._draft()==preserved and _dialog._form._read_only,"native Troops preserved without turn based authoring")

func _append(code: int, p: Array) -> void:
	var list=_dialog._commands
	list._command_index=list._list.size()-1; list._adding_command=true; list._accept_command(code,p)

func _author_common_events() -> Array:
	var ids: Array=[]; _choose("CommonEvents")
	for trigger in range(3):
		_dialog._new_record(false); ids.append(_dialog._id)
		_dialog._form._put(["name"],"保存后公共事件%d" % trigger); _dialog._form._put(["trigger"],trigger)
		_dialog._form._put(["switch_id"],4001+trigger)
		_append(122,[4100+trigger,4100+trigger,1,0,10+trigger])
		if trigger==1: _append(121,[4002,4002,1])
		if trigger==2: _append(106,[20])
		expect(_apply(),"author trigger%d common event with native command editor" % trigger)
	# Choice/branch preservation uses the same editor as map events.
	_dialog._new_record(false); _append(102,[["第一项","第二项"],5])
	var list=_dialog._commands; list._command_index=1; list._adding_command=true; list._accept_command(125,[0,0,5])
	list._command_index=0; list._adding_command=false; list._accept_command(102,[["第一项改名","第二项","第三项"],5])
	expect(list.draft().any(func(c: Dictionary) -> bool: return int(c.code)==125 and int(c.indent)==1),"common choice edits keep branch body")
	expect(_apply(),"common choice structure validates")
	_choose("Items"); _dialog._load_record(1); _dialog._form._put(["common_event_id"],ids[0]); expect(_apply(),"item links authored common event by ID")
	return ids

func _test_guards() -> void:
	var rows: Array=_docs.records("Actors"); var old=rows.duplicate(true)
	rows[1].id=1.5; expect(not _docs.validate("data/database/Actors.json",rows,old).is_empty(),"fractional database IDs rejected")
	rows=old.duplicate(true); rows[1].parameters.values.pop_back(); expect(not _docs.validate("data/database/Actors.json",rows,old).is_empty(),"malformed table rejected before batch writes")
	rows=old.duplicate(true); rows[1].class_id=999999; expect(not _docs.validate("data/database/Actors.json",rows,old).is_empty(),"new dangling references rejected")
	_choose("CommonEvents"); _dialog._form._put(["trigger"],4)
	expect(not _dialog.apply_current(),"map trigger values cannot enter common database")
	_dialog._reload_record()
	var data: Array=_docs.records("CommonEvents"); old=data.duplicate(true); data[_dialog._id].list=[Commands.command(112),Commands.command(0)]
	expect(not _docs.validate("data/database/CommonEvents.json",data,old).is_empty(),"unclosed loop rejected before save")
	_choose("Actors"); _dialog._load_record(1); _dialog._form._put(["name"],"未应用名字")
	expect(not _dialog.pending_status().is_empty(),"pending fields participate in close/save status")
	_dialog.canceled.emit(); expect(_dialog._form.draft().name==_docs.records("Actors")[1].name and _docs.records("Actors")[1].name=="未应用名字","close retains current fields in the shared draft")

func _run_saved_runtime(docs: RefCounted, ids: Array) -> void:
	var data=load("res://runtime/scripts/RuntimeData.gd")
	for name in ["Actors","Classes","Items","CommonEvents","Tilesets"]: data._cache["res://data/database/"+name+".json"]=docs.records(name)
	data._cache["res://data/system.json"]=docs.read("data/system.json")
	# Native growth is the subject of this isolated authoring fixture; Flash's
	# custom actor parameters use their own source-flow regression.
	data._cache["res://data/custom_data.json"]={"profile":"native"}
	var state=root.get_node("RuntimeState"); state.begin_new_game(data.system(),{"enabled":false})
	var actor=state.actor(1,true)
	expect(actor!=null and int(actor.parameter_sources("maxhp").database)==1234,"new game reads edited actor growth")
	expect(int(data.record("Items",1).price)==77,"runtime reads saved item price")
	var fixture=load("res://runtime/scripts/EventFixture.gd").build()
	fixture.map.events={}
	var map=load("res://runtime/scripts/MapRuntime.gd").new(); root.add_child(map); map.load_definition(fixture.map,fixture.tileset); map.set_process(false)
	var native=fixture.map.duplicate(true); native.width=5; native.height=5
	native.data=Schema.table(5,5,3); native.data.values[2+2*5]=384
	var tile_map=load("res://runtime/scripts/MapRuntime.gd").new(); root.add_child(tile_map); tile_map.load_definition(native,docs.records("Tilesets")[1]); tile_map.set_process(false)
	expect(not tile_map.can_move(Vector2i(2,3),Vector2i.UP) and tile_map.terrain_tag(2,2)==7,"saved graphical tile edit controls actual map collision and terrain")
	tile_map.queue_free()
	var scheduler=load("res://runtime/scripts/EventScheduler.gd").new(); scheduler.configure(map)
	# Keep actual originals off, enable only saved authoring fixtures.
	state.switches={}; state.variables={}; state.set_event_switch(4002,true); state.set_event_switch(4003,true)
	scheduler.start_main([Commands.command(117,0,[ids[0]]),Commands.command(0)],0)
	scheduler.advance(0)
	expect(int(state.variables.get("4100",0))==10,"saved manual public event executes via117")
	expect(int(state.variables.get("4101",0))==11 and not bool(state.switches.get("4002",true)),"saved autorun uses its switch and stops itself")
	expect(int(state.variables.get("4102",0))==12,"saved parallel public event executes independently")
	scheduler.advance(0.5); expect(int(state.variables.get("4102",0))==12,"authored parallel wait obeys elapsed time")
	scheduler.advance(0.5); scheduler.advance(0); expect(int(state.variables.get("4102",0))==24,"saved parallel restarts after wait")
	scheduler.cancel_all(); map.queue_free(); state.audio.stop_all()

func _test_conflict(docs: RefCounted) -> void:
	var path="data/database/Items.json"; var old=docs.records("Items"); var changed=old.duplicate(true); changed[1].price=88; docs.apply(path,changed)
	var external=old.duplicate(true); external[1].name="外部修改"; _write(path,external)
	var result: Dictionary=docs.save_all()
	expect(not result.ok and result.message.contains("外部修改"),"database save refuses external overwrite")
	expect(JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join(path)))[1].name=="外部修改","external data survives rejected save")

@tool
extends RefCounted
var checks=0
var failures: Array[String]=[]
var metrics: Dictionary={}
var database: ConfirmationDialog

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func _choose(category: String) -> void:
	for index in database._categories.item_count:
		if database._categories.get_item_metadata(index)==category: database._categories.select(index); database._select_category(index); return

func _frames(tree: SceneTree) -> void:
	for index in 6: await tree.process_frame

func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary:
	var tree=parent.get_tree(); var folder="res://.godot/final_ui_%d/" % Time.get_ticks_usec()
	var schema=load("res://addons/rgm_editor/EditorDatabaseSchema.gd")
	var ops=load("res://addons/rgm_editor/EditorCapacityOps.gd")
	var colors=load("res://addons/rgm_editor/EditorCommandColors.gd")
	var commands=load("res://addons/rgm_editor/EditorCommands.gd")
	var manifest={"maps":["Map001"],"database":[]}
	for category in schema.CATEGORIES:
		if category!="System": manifest.database.append(category); _write(folder+"data/database/"+category+".json",original.records(category))
	_write(folder+"data/manifest.json",manifest)
	for path in ["data/map_infos.json","data/asset_index.json"]: _write(folder+path,original.read(path))
	_write(folder+"data/test_setup.json",{"enabled":false,"definitions":{"Items":[{"id":450}]}})
	var system: Dictionary=original.read("data/system.json"); system.switches=[null,"开门",""]; system.variables=[null,"数量",""]; system.start_map_id=1; system.start_x=0; system.start_y=0
	_write(folder+"data/system.json",system)
	var map: Dictionary=original.read("data/maps/Map001.json"); map.events={}; _write(folder+"data/maps/Map001.json",map)
	var docs=load("res://addons/rgm_editor/EditorDocuments.gd").new(folder)
	var items=[null,schema.new_record("Items",1,docs)]; items[1].name="原物品"; items[1].custom={"keep":7}; _write(folder+"data/database/Items.json",items)
	var animations=[null,schema.new_record("Animations",1,docs),schema.new_record("Animations",2,docs)]; animations[1].name="动画甲"; animations[2].name="动画乙"; animations[2].custom=5
	_write(folder+"data/database/Animations.json",animations)
	database=load("res://addons/rgm_editor/EditorDatabaseDialog.gd").new(); parent.add_child(database); database.open(docs)
	_choose("Items"); var form=database._form
	var names: Array=[]
	for button in database._capacity_button.get_parent().get_children():
		if button is Button: names.append(button.text)
	expect("应用条目" not in names and "设置最大编号…" in names,"toolbar has capacity management and no redundant Apply button")
	for maximum in [500,5000]:
		var started=Time.get_ticks_usec(); var history=docs._history.size()
		database._open_capacity(); database._maximum.value=maximum; database._capacity.confirmed.emit()
		metrics["expand_%d_ms" % maximum]=(Time.get_ticks_usec()-started)/1000.0
		var values: Array=docs.records("Items")
		expect(values.size()==maximum+1 and values[0]==null and values[1].custom.keep==7 and values[maximum]==null,"capacity expansion preserves existing IDs and lightweight empty slots "+str(maximum))
		expect(docs._history.size()==history+1 and database._records.item_count<=100,"expansion is one undo transaction with paged records "+str(maximum))
		expect(JSON.parse_string(FileAccess.get_file_as_string(folder+"data/database/Items.json")).size()==2,"expansion does not write the source file before Save")
	var started=Time.get_ticks_usec(); database._jump.value=350; database._jump_to(); metrics.jump_ms=(Time.get_ticks_usec()-started)/1000.0
	expect(database._id==350 and form.draft().id==350 and docs.records("Items")[350]==null,"jumping to an empty slot opens defaults without creating a record")
	form._controls[str(["name"])].control.text="350号血瓶"; form._controls[str(["name"])].control.text_changed.emit("350号血瓶"); form._controls[str(["price"])].control.value=25
	database._jump.value=450; database._jump_to()
	expect(docs.records("Items")[350].name=="350号血瓶" and database._before.is_empty(),"switching commits the edited slot and protects a reserved test ID")
	database._jump.value=351; database._jump_to(); form._controls[str(["name"])].control.text="351号宝石"; form._controls[str(["name"])].control.text_changed.emit("351号宝石")
	database.canceled.emit()
	expect(docs.records("Items")[351].name=="351号宝石" and database.pending_status().is_empty(),"closing retains the last edited entry in the shared draft")
	docs.undo(); database._reload_record(); expect(docs.records("Items")[351]==null,"undo restores the last slot to empty without renumbering")
	docs.redo(); database._reload_record(); expect(docs.records("Items")[351].id==351,"redo restores the same ID")
	started=Time.get_ticks_usec(); database._search.text="350号"; database._search.text_changed.emit("350号"); metrics.search_ms=(Time.get_ticks_usec()-started)/1000.0
	expect(database._records.item_count==1 and int(database._records.get_item_metadata(0))==350,"search locates a populated slot outside the first page")
	database._search.text=""; database._search.text_changed.emit(""); expect(not ops.resize(docs,"Items",docs.records("Items"),100).ok,"shrinking rejects populated tail slots")
	var scan=[null]; scan.resize(501); var event=schema.new_record("CommonEvents",1,docs); event.list=[commands.command(126,0,[480,0,0,1]),commands.command(0)]; var common=[null,event]
	docs.apply("data/database/CommonEvents.json",common)
	expect(not ops.resize(docs,"Items",scan,400).ok,"shrinking detects an event reference into an empty tail")
	event.list=[commands.command(0)]; docs.apply("data/database/CommonEvents.json",[null,event]);
	_write(folder+"shrink/data/system.json",{}); _write(folder+"shrink/data/manifest.json",{"maps":[],"database":[]})
	var clean=load("res://addons/rgm_editor/EditorDocuments.gd").new(folder+"shrink/")
	expect(ops.resize(clean,"Animations",[null,animations[1],animations[2],null,null],2).ok,"unused empty tail can shrink after reference checks")
	_choose("System"); var name_editor=form._names.variables
	name_editor._open_capacity(); name_editor._maximum.value=5000; name_editor._capacity.confirmed.emit()
	expect(name_editor.draft().size()==5001 and name_editor.draft()[0]==null and name_editor.draft()[4000]=="","name capacity expansion reserves empty names and index zero")
	name_editor._jump.value=2000; name_editor._jump_to(); name_editor._name.text="宝石数量"; name_editor._name.text_changed.emit("宝石数量")
	expect(name_editor._list.item_count<=100 and name_editor.draft()[2000]=="宝石数量","name jump and editing preserve high IDs with grouped rows")
	database.apply_current(); expect(docs.reference_label("variables",2000)=="[2000] 宝石数量","new named variable resolves consistently")
	var page=form._tabs.current_tab
	_choose("Animations"); form._tabs.current_tab=1; database._refresh_records(2); database._load_record(2); await _frames(tree)
	expect(form._tabs.current_tab==1 and form._animation.draft().id==2,"switching animations with different fields stays in animation editing")
	form._animation._value.name="动画乙更新"; form._put(["name"],"动画乙更新"); database.apply_current()
	expect(form._tabs.current_tab==1 and docs.records("Animations")[2].name=="动画乙更新","applying an animation draft preserves its page")
	_choose("Items"); _choose("Animations"); expect(form._tabs.current_tab==1,"returning to the animation category restores its purpose page")
	if capture.is_valid(): await capture.call(database,"animation-page-kept")
	_choose("CommonEvents"); database._load_record(1); await _frames(tree)
	expect(database._commands.size.y>form.size.y*1.5 and form.size.y<=160,"common event content gets the main editing area")
	var list: Array=[]
	for code in [101,111,121,201,223,241,311,125,108,355]:
		var p: Array=commands.defaults(code)
		if code==355: p=["puts 'keep'"]
		list.append(commands.command(code,0,p))
	list.append(commands.command(0)); database._commands.configure(list,docs)
	var rows=database._commands._command_list.get_root().get_children(); var distinct={}
	for index in rows.size():
		distinct[rows[index].get_custom_color(0).to_html()]=true
		expect(rows[index].get_tooltip_text(0).contains("原参数"),"colored row preserves native parameter tooltip "+str(index))
	expect(distinct.size()>=10 and database._commands.draft()==list,"all main instruction groups have distinct colors without payload changes")
	var light_tree=Tree.new(); light_tree.columns=2; light_tree.add_theme_color_override("font_color",Color.BLACK); parent.add_child(light_tree); var light_row=light_tree.create_item(); colors.apply(light_tree,light_row,121)
	expect(light_row.get_custom_color(0)==Color(colors.LIGHT.state),"light themes use a darker legible palette")
	light_tree.queue_free()
	if capture.is_valid(): await capture.call(database,"common-event-colors")
	database._commands.configure([commands.command(0)],docs)
	# Display marker geometry at two zoom levels on a real tileset.
	_choose("Tilesets"); await _frames(tree); var canvas=database._tileset_editor._canvas
	for zoom in [1.5,2.0]:
		canvas.set_palette_zoom(zoom)
		for mode in ["passages","directions","priorities","terrain_tags"]:
			database._tileset_editor._mode_buttons[mode].pressed.emit(); await _frames(tree)
			var event_input=InputEventMouseButton.new(); event_input.button_index=MOUSE_BUTTON_LEFT; event_input.pressed=true; event_input.position=Vector2(1.5,1.5)*32*zoom; canvas._gui_input(event_input)
			expect(canvas._selected_id==int(canvas._palette_ids[9]),"zoomed marker clicks map to the same source tile "+mode+str(zoom))
			if capture.is_valid() and zoom==2.0: await capture.call(database,"tile-marker-"+mode)
	database._tileset_editor._palette_scroll.scroll_vertical=320; await _frames(tree)
	var exposed: Rect2=canvas._palette_visible_rect()
	var scroll=database._tileset_editor._palette_scroll
	expect(absf(exposed.position.y-scroll.scroll_vertical)<=8 and exposed.size.y<=scroll.size.y+2,"palette redraws its actual scrolled viewport, including short tilesets")
	if capture.is_valid(): await capture.call(database,"tile-marker-scrolled")
	var panel=load("res://addons/rgm_editor/EditorPanel.gd").new(); panel.setup(docs); parent.add_child(panel); await _frames(tree)
	expect(panel._tool_buttons.size()==6 and not panel._draw_tools.get_children().any(func(node: Node) -> bool: return node is Button and node.text.contains("吸管")),"drawing toolbar omits the eyedropper button")
	panel._select_brush([[384]]); panel._choose_tool(3); var point=Vector2i(0,0); var input=InputEventMouseButton.new(); input.button_index=MOUSE_BUTTON_RIGHT; input.pressed=true; input.position=panel._canvas._origin+Vector2.ONE*16*panel._canvas._zoom; panel._canvas._gui_input(input)
	expect(panel._tool.selected==0 and panel._tile_brush[0][0]==panel.Ops.tile(panel._map,point,panel._layer.selected),"right click samples the current layer and returns to drawing")
	started=Time.get_ticks_usec(); expect(docs.save_all().ok,"explicit save persists the detached capacity and authored records"); metrics.save_ms=(Time.get_ticks_usec()-started)/1000.0
	var reopened=load("res://addons/rgm_editor/EditorDocuments.gd").new(folder); var reopened_items: Array=reopened.records("Items")
	expect(reopened_items.size()==5001 and reopened_items[349]==null and reopened_items[350].price==25 and reopened_items[351].id==351,"save and reopen retain sparse item slots and exact IDs")
	expect(reopened.read("data/system.json").variables[2000]=="宝石数量","expanded named variables survive save and reopen")
	var runtime=load("res://runtime/scripts/RuntimeData.gd"); var cached=runtime._cache.get("res://data/database/Items.json"); runtime._cache["res://data/database/Items.json"]=runtime.read_json(folder+"data/database/Items.json",[])
	expect(runtime.source_record("Items",349).is_empty() and runtime.source_record("Items",350).name=="350号血瓶","native runtime reads the saved sparse definitions by ID")
	if cached==null: runtime._cache.erase("res://data/database/Items.json")
	else: runtime._cache["res://data/database/Items.json"]=cached
	metrics.items_json_bytes=FileAccess.get_file_as_bytes(folder+"data/database/Items.json").size()
	for key in ["expand_500_ms","expand_5000_ms","jump_ms","search_ms"]: expect(float(metrics[key])<5000,"capacity interaction completes within a bounded time "+key)
	database.queue_free(); panel.queue_free(); await tree.process_frame
	return {"checks":checks,"failures":failures,"metrics":metrics}

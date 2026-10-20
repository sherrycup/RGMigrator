## 职责：回归验证：执行事件指令和移动路线的实际界面编写场景。
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
var checks=0
var failures: Array[String]=[]

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func _command_button(dialog: Window, code: int) -> Button:
	var pending: Array=[dialog._button_box]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		if node is Button and int(node.get_meta("command_code",-1))==code: return node
		pending.append_array(node.get_children())
	return null

func _double_click(control: Control) -> void:
	var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.double_click=true; event.position=control.size/2.0; control._gui_input(event)

func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary:
	var tree=parent.get_tree(); var folder="res://.godot/event_authoring_%d/" % Time.get_ticks_usec()
	var system: Dictionary=original.read("data/system.json"); system.switches[1]="开启大门"; system.variables[1]="钥匙数量"
	_write(folder+"data/system.json",system); _write(folder+"data/manifest.json",{"maps":["Map001"]}); _write(folder+"data/map_infos.json",{"1":{"name":"事件编辑验收","parent_id":0,"order":1}})
	for category in ["Tilesets","Actors","CommonEvents"]: _write(folder+"data/database/"+category+".json",original.records(category))
	_write(folder+"data/asset_index.json",original.read("data/asset_index.json"))
	var names=original.assets("Characters"); expect(names.size()>=2,"original project supplies replacement character textures")
	var first=str(names[0]); var replacement=str(names[1]); var page=original.new_page(); page.graphic.character_name=first; page.custom_marker={"keep":[7,8]}; page.graphic.custom_graphic=99
	var values: Array=[]; values.resize(8*6*3); values.fill(0)
	var map={"width":8,"height":6,"tileset_id":1,"data":{"_rmxp_type":"table","dimensions":3,"x_size":8,"y_size":6,"z_size":3,"values":values},"events":{"1":{"id":1,"name":"门卫","x":2,"y":2,"pages":[page]}}}
	_write(folder+"data/maps/Map001.json",map)
	map=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/maps/Map001.json")); page=map.events["1"].pages[0].duplicate(true)
	var docs=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder)
	var panel=load("res://addons/rgm_editor/00_Plugin/Editor_Panel.gd").new(); panel.setup(docs); parent.add_child(panel); await tree.process_frame
	panel._choose_layer(3); panel._event_id=1; panel._open_event(false)
	var settings=panel._settings
	expect(panel._page_tabs.visible and not panel._pages.visible,"event pages are tabs")
	expect(not settings._tree.visible and settings._graphic.visible,"event page uses grouped controls and bordered graphic")
	expect(settings._graphic._heading.text=="事件行走图" and settings._graphic._purpose.text.contains("地图"),"event preview visibly explains its purpose separately from the filename")
	expect(settings._controls.has("graphic/blend_type"),"native blend mode is available in the ordinary graphic controls")
	settings._controls["condition/switch1_valid"].control.button_pressed=true
	expect(settings.draft().condition.switch1_valid and settings._controls["condition/switch1_id"].control.text.contains("开启大门"),"condition checkbox enables the named switch control")
	settings._controls["move_speed"].control.value=5
	settings._controls["trigger"].control.select(4); settings._controls["trigger"].control.item_selected.emit(4)
	if capture.is_valid(): await capture.call(panel,"event-groups")
	_double_click(settings._graphic); var picker=settings._asset_dialog
	expect(picker.visible and picker._selected==first,"double click opens picker located at current asset")
	picker._search.text=replacement; picker._search.text_changed.emit(replacement); await tree.process_frame
	var found_index=-1
	for i in picker._list.item_count:
		if picker._list.get_item_metadata(i)==replacement: found_index=i
	expect(found_index>=0 and picker._list.item_count<names.size(),"search filters replacement with a thumbnail")
	if found_index>=0: picker._list.item_selected.emit(found_index)
	expect(settings.draft().graphic.character_name==first,"asset browsing does not alter event draft")
	picker.canceled.emit(); picker.hide(); expect(settings.draft().graphic.character_name==first,"cancel retains original image")
	_double_click(settings._graphic); picker._search.text=replacement; picker._search.text_changed.emit(replacement); await tree.process_frame
	for i in picker._list.item_count:
		if picker._list.get_item_metadata(i)==replacement: picker._list.item_selected.emit(i); break
	picker._hue.value=120; picker._opacity.value=192; await tree.process_frame
	var frame_event=InputEventMouseButton.new(); frame_event.button_index=MOUSE_BUTTON_LEFT; frame_event.pressed=true; frame_event.position=picker._preview._image_rect.position+picker._preview._image_rect.size*Vector2(0.625,0.875); picker._preview._gui_input(frame_event)
	expect(picker._settings.direction==8 and picker._settings.pattern==2,"sheet click selects exact direction and frame")
	if capture.is_valid(): await capture.call(panel,"character-picker")
	picker.confirmed.emit(); picker.hide()
	var graphic: Dictionary=settings.draft().graphic
	expect(graphic.character_name==replacement and graphic.character_hue==120 and graphic.opacity==192 and graphic.direction==8 and graphic.pattern==2,"confirmed picker applies native graphic fields")
	expect(graphic.custom_graphic==99 and settings.draft().custom_marker==page.custom_marker,"new UI retains unknown graphic and page fields")
	settings._extension_button.pressed.emit(); var extensions=settings._extension_form.draft()
	expect(settings._extension_dialog.visible and extensions.keys().size()==2 and extensions.graphic=={"custom_graphic":page.graphic.custom_graphic},"extension dialog contains only actual extra fields and no duplicate native controls")
	if capture.is_valid(): await capture.call(panel,"event-extension-fields")
	settings._extension_form._put(["graphic","custom_graphic"],101); settings._extension_dialog.canceled.emit(); settings._extension_dialog.hide()
	expect(settings.draft().graphic==graphic,"canceling extension edits retains native and extension values")
	settings._extension_button.pressed.emit(); settings._extension_form._put(["graphic","custom_graphic"],101); settings._extension_dialog.confirmed.emit(); settings._extension_dialog.hide()
	expect(settings.draft().graphic.custom_graphic==101 and settings.draft().graphic.character_name==replacement and settings.draft().move_speed==5,"applying extension values retains the ordinary page controls")
	graphic=settings.draft().graphic
	panel._copy_page(); expect(panel._page_tabs.tab_count==2,"copy creates visible event page tab")
	settings._controls["move_speed"].control.value=3
	panel._page_tabs.current_tab=0; expect(int(settings.draft().move_speed)==5,"page tabs retain previous page draft")
	panel._page_tabs.current_tab=1; expect(int(settings.draft().move_speed)==3,"returning tab retains its own draft")
	settings._tile_button.pressed.emit(); var tile_picker=settings._tile_dialog
	expect(tile_picker.visible and tile_picker._tileset==docs.records("Tilesets")[1] and tile_picker._heading.text.contains(str(tile_picker._tileset.name)),"event tile chooser uses and names the current map's database tileset")
	expect(tile_picker._palette._palette_ids.all(func(id: Variant) -> bool: return int(id)>=384) and tile_picker._empty.visible,"event selector offers ordinary RM tiles in their original grid and an explicit empty graphic button")
	var tile_index=mini(57,tile_picker._palette._palette_ids.size()-1); var selected_tile=int(tile_picker._palette._palette_ids[tile_index])
	var tile_event=InputEventMouseButton.new(); tile_event.button_index=MOUSE_BUTTON_LEFT; tile_event.pressed=true; tile_event.position=Vector2(tile_index%8,tile_index/8)*32+Vector2(16,16); tile_picker._palette._gui_input(tile_event)
	expect(tile_picker._selected==selected_tile and tile_picker._preview.texture!=null and settings.draft().graphic==graphic,"clicking a map tile previews it without changing the event draft")
	tile_picker.canceled.emit(); tile_picker.hide(); expect(settings.draft().graphic==graphic,"canceling tile choice retains the previous character graphic")
	settings._tile_button.pressed.emit(); tile_picker._palette._gui_input(tile_event)
	if capture.is_valid(): await capture.call(panel,"event-tile-picker")
	tile_picker.confirmed.emit(); tile_picker.hide()
	var tile_graphic: Dictionary=settings.draft().graphic
	expect(tile_graphic.tile_id==selected_tile and tile_graphic.character_name=="" and tile_graphic.character_hue==0 and tile_graphic.opacity==192 and tile_graphic.custom_graphic==101,"confirmed tile choice sets native tile graphic and retains opacity and unknown fields")
	expect(settings._graphic._heading.text.contains(str(selected_tile)) and settings._graphic._category=="Tilesets","event preview identifies the selected map tile")
	_double_click(settings._graphic); expect(tile_picker.visible and tile_picker._selected==selected_tile,"double clicking a tile graphic locates the current tile instead of opening character files")
	tile_picker.canceled.emit(); tile_picker.hide()
	settings._controls["graphic/character_hue"].control.value=72; var unchanged_tile: Dictionary=settings.draft().graphic
	_double_click(settings._graphic); tile_picker.confirmed.emit(); tile_picker.hide()
	expect(settings.draft().graphic==unchanged_tile and int(tile_picker._preview._settings.hue)==72,"confirming the existing tile preserves its native hue and other graphic values")
	settings._controls["graphic/character_hue"].control.value=0; tile_graphic=settings.draft().graphic
	settings.edit_asset(["graphic","character_name"]); picker=settings._asset_dialog; picker.canceled.emit(); picker.hide()
	expect(settings.draft().graphic==tile_graphic,"canceling a switch from tile to character preserves the current tile")
	settings.edit_asset(["graphic","character_name"]); picker._selected=replacement; picker.confirmed.emit(); picker.hide()
	expect(settings.draft().graphic.tile_id==0 and settings.draft().graphic.character_name==replacement,"choosing a character replaces the tile graphic")
	settings._tile_button.pressed.emit(); tile_picker._empty.pressed.emit(); tile_picker.confirmed.emit(); tile_picker.hide()
	expect(settings.draft().graphic.tile_id==0 and settings.draft().graphic.character_name=="","selecting the empty tile clears the event graphic without restoring the old character")
	settings._tile_button.pressed.emit(); tile_picker._palette._gui_input(tile_event); tile_picker.confirmed.emit(); tile_picker.hide(); tile_graphic=settings.draft().graphic
	if capture.is_valid(): await capture.call(panel,"event-tile-preview")
	panel._add_command(); var dialog=panel._command_dialog
	expect(dialog._palette.visible and not dialog._selector.visible,"new command uses category tabs and button grid")
	var available: Array=[]
	for tab in range(dialog._tabs.tab_count):
		dialog._tabs.current_tab=tab; dialog._rebuild_buttons()
		var pending: Array=[dialog._button_box]
		while not pending.is_empty():
			var node: Node=pending.pop_back()
			if node is Button: available.append(node.get_meta("command_code"))
			pending.append_array(node.get_children())
	available.sort(); expect(available==load("res://addons/rgm_editor/03_Event/Editor_Commands.gd").available(),"every supported command appears once in category buttons")
	dialog._tabs.current_tab=0; dialog._rebuild_buttons()
	if capture.is_valid(): await capture.call(panel,"command-buttons")
	_command_button(dialog,121).pressed.emit(); dialog._form._put([0],1); dialog._form._put([1],1); dialog._form._put([2],0); await tree.process_frame
	expect(dialog._parameter_box.visible and dialog._form._display(1,[0]).contains("开启大门"),"command button opens named native parameter form")
	if capture.is_valid(): await capture.call(panel,"command-parameters")
	dialog._accept(); dialog.hide()
	expect(panel._event_draft.pages[1].list[0].code==121,"button-selected command is inserted into active event page")
	expect(JSON.parse_string(FileAccess.get_file_as_string(folder+"data/maps/Map001.json"))==map,"modal edits leave disk unchanged before Apply and Save")
	panel._apply_event(); panel._event_dialog.hide(); expect(panel.save_changes(),"edited event explicitly saves")
	var reopened=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder); var saved: Dictionary=reopened.read("data/maps/Map001.json")
	expect(saved.events["1"].pages[0].graphic==JSON.parse_string(JSON.stringify(graphic)) and saved.events["1"].pages[1].list[0].code==121,"reopening preserves selected image and command")
	expect(saved.events["1"].pages[1].graphic==JSON.parse_string(JSON.stringify(tile_graphic)),"reopening preserves the selected map tile graphic")
	var map_runtime=load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); map_runtime.tileset=docs.records("Tilesets")[1]
	var character=load("res://runtime/scripts/03_Map/MapCharacter.gd").new(); character.map_runtime=map_runtime; character.set_graphic(str(tile_graphic.character_name),int(tile_graphic.character_hue),int(tile_graphic.tile_id))
	expect(character._sprite.texture!=null and character._sprite.hframes==1 and character._sprite.texture.get_size()==Vector2(32,32),"saved native tile graphic loads as a single 32-pixel runtime sprite")
	character.free(); map_runtime.free()
	# Route and actor image fields share the same selector, with their own parameter mapping.
	dialog.open(docs,209,[0,page.move_route],false); dialog._route_form._insert(41); dialog._route_form._edit_selected()
	var route_form=dialog._route_form._param_form
	if route_form==null: expect(false,"route graphic parameters available")
	else:
		route_form.edit_asset([0]); var route_picker=route_form._asset_dialog; route_picker._settings.direction=6; route_picker._settings.pattern=1; route_picker._settings.hue=90; route_picker._selected=replacement; route_picker.confirmed.emit(); route_picker.hide()
		expect(route_form.draft()==[replacement,90,6,1],"route image chooser maps native hue direction and pattern parameters")
	dialog._route_form._param_dialog.hide(); dialog.hide()
	var database=load("res://addons/rgm_editor/04_Database/Editor_DatabaseDialog.gd").new(); panel.add_child(database); database.open(docs)
	var actor_before: Dictionary=database._form.draft()
	_double_click(database._form._previews[str(["character_name"])]); var actor_picker=database._form._asset_dialog
	expect(actor_picker!=null and actor_picker.visible and actor_picker._selected==str(actor_before.character_name),"database preview double click locates the actor's current image")
	actor_picker._selected=replacement; actor_picker._settings.hue=90; actor_picker.confirmed.emit(); actor_picker.hide()
	expect(database._form.draft().character_name==replacement and database._form.draft().character_hue==90 and database._form._previews[str(["character_name"])]._name==replacement,"database image selection refreshes draft preview")
	expect(database._form._previews[str(["character_name"])].texture!=null,"database retains the loaded replacement texture during resource scans")
	var actor_captions: Array=[]
	for preview in database._form._previews.values(): actor_captions.append(preview._heading.text)
	expect(actor_captions.has("行走图") and actor_captions.has("战斗图（元数据）"),"actor image previews label character and battler purposes separately")
	if capture.is_valid(): await capture.call(panel,"database-image-preview")
	expect(database.apply_current() and panel.save_changes(),"database graphic edits explicitly apply and save")
	var actors: Array=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/database/Actors.json"))
	expect(actors[database._id].character_name==replacement and actors[database._id].character_hue==90 and actors[database._id].id==actor_before.id,"saved actor keeps stable ID and selected graphic")
	var previous_character: Variant=database._form.draft().character_hue
	database._form.edit_asset(["battler_name"]); var battler_picker=database._form._asset_dialog; battler_picker._settings.hue=180; battler_picker.confirmed.emit(); battler_picker.hide()
	expect(database._form.draft().battler_hue==180 and database._form.draft().character_hue==previous_character,"battler asset hue never changes the actor's character hue")
	database._form.edit_asset(["character_name"]); actor_picker=database._form._asset_dialog; actor_picker._settings.hue=45; actor_picker.confirmed.emit(); actor_picker.hide()
	expect(database._form.draft().character_hue==45 and database._form.draft().battler_hue==180,"character asset hue never changes battler metadata")
	for i in database._categories.item_count:
		if database._categories.get_item_metadata(i)=="Tilesets": database._categories.select(i); database._categories.item_selected.emit(i); break
	var tileset_captions: Array=[]
	var tile_editor=database._tileset_editor
	for entry in tile_editor._previews.values(): tileset_captions.append(entry.control._heading.text)
	for slot in 7: expect(tileset_captions.has("自动图块 %d" % (slot+1)),"tileset preview explicitly identifies autotile slot %d" % (slot+1))
	expect(tile_editor._canvas.is_visible_in_tree() and tileset_captions.has("全景图像") and tileset_captions.has("雾图像"),"tileset homepage displays ordinary palette and explicitly labeled image roles")
	if capture.is_valid(): await capture.call(panel,"database-tileset-labels")
	if capture.is_valid():
		tile_editor._tabs.current_tab=1
		await capture.call(panel,"database-tileset-autotile-labels")
		tile_editor._asset_scroll.set_deferred("scroll_vertical",10000)
		await capture.call(panel,"database-tileset-background-labels")
	database.hide()
	var legacy=docs.new_page(); legacy.erase("list"); legacy.trigger=77; legacy.graphic.pattern=9; legacy.move_speed=12
	settings.configure(legacy,{},docs)
	expect(not settings._extension_button.visible,"standard event pages hide the extension entry when no extra fields exist")
	expect(settings._tile_button.disabled,"a form without current map context disables tile picking")
	expect(settings._controls["trigger"].control.get_item_metadata(settings._controls["trigger"].control.selected)==77 and settings.draft().graphic.pattern==9 and settings.draft().move_speed==12,"grouped controls retain unknown legacy enums and values on opening")
	panel.queue_free(); await tree.process_frame
	return {"folder":folder,"graphic":graphic,"command":saved.events["1"].pages[1].list[0]}

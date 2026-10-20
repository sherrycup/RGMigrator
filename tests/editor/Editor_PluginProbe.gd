## 职责：回归验证：在实际 Godot 编辑器中检查魔塔插件页面及控件交互。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run(plugin: EditorPlugin,panel: Control) -> void
##     用途：执行当前迁移流程或回归场景。
##     参数 plugin（EditorPlugin；必填）：Godot EditorPlugin 插件实例。
##     参数 panel（Control；必填）：魔塔编辑器主面板实例。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

@tool
extends RefCounted
var _failures: Array[String]=[]
var _checks =0
var _captures =""
var _resolutions = [Vector2i(1600,1000),Vector2i(1280,800)]
var _database_only=false
var _readability_only=false
var _map_editing_only=false
var _event_authoring_only=false
var _tileset_layers_only=false
var _database_authoring_only=false
var _feedback_only=false
var _final_ui_only=false
var _structure_only=false
func expect(ok: bool,message: String) -> void:
	_checks+=1
	if not ok: _failures.append(message)

func run(plugin: EditorPlugin,panel: Control) -> void:
	var tree =plugin.get_tree()
	for arg in OS.get_cmdline_user_args():
		if arg=="--database-only": _database_only=true
		if arg=="--readability-only": _readability_only=true
		if arg=="--map-editing-only": _map_editing_only=true
		if arg=="--event-authoring-only": _event_authoring_only=true
		if arg=="--tileset-layers-only": _tileset_layers_only=true
		if arg=="--database-authoring-only": _database_authoring_only=true
		if arg=="--feedback-only": _feedback_only=true
		if arg=="--final-ui-only": _final_ui_only=true
		if arg=="--structure-only": _structure_only=true
		if arg.begins_with("--captures="): _captures=arg.trim_prefix("--captures=")
		if arg.begins_with("--resolution="):
			var size =arg.trim_prefix("--resolution=").split("x")
			_resolutions=[Vector2i(int(size[0]),int(size[1]))]
	if _captures.is_empty(): _captures=ProjectSettings.globalize_path("res://.godot/editor_captures")
	DirAccess.make_dir_recursive_absolute(_captures)
	while EditorInterface.get_resource_filesystem().is_scanning(): await tree.create_timer(0.2).timeout
	for i in 12: await tree.process_frame
	EditorInterface.set_main_screen_editor("魔塔编辑器")
	# Single-window mode renders plugin modal windows into the editor viewport.
	tree.root.gui_embed_subwindows=true
	OS.low_processor_usage_mode=false
	expect(Engine.is_editor_hint() and panel.is_visible_in_tree(),"plugin active inside editor")
	expect(not EditorInterface.is_playing_scene(),"game is not running")
	expect(panel._map_id>0 and not panel._map.is_empty(),"original project opens actual map")
	var manifest: Dictionary=panel._documents.read("data/manifest.json")
	for name in manifest.maps:
		var map: Dictionary=panel._documents.read("data/maps/"+str(name)+".json")
		if map.get("data",{}).get("values",[]).any(func(id: Variant) -> bool: return int(id)>=384): panel._load_map(str(name).trim_prefix("Map").to_int()); break
	var first: Dictionary = panel._documents.read("data/maps/Map001.json")
	var original_box = first.get("events",{}).has("17")
	if original_box: panel._load_map(1)
	var images: Array=[]
	for resolution in _resolutions:
		tree.root.size=resolution
		for i in 8:
			OS.low_processor_usage_mode=false
			await tree.process_frame
		RenderingServer.force_draw(false); await tree.process_frame
		var suffix ="%dx%d" % [resolution.x,resolution.y]
		var image =tree.root.get_texture().get_image()
		expect(not image.is_empty(),"native editor image "+suffix)
		expect(image.save_png(_captures.path_join("map-"+suffix+".png"))==OK,"capture actual main screen")
		images.append("map-"+suffix+".png")
		if _structure_only:
			var scenario=load("res://.godot/Editor_StructureGuideScenario.gd").new(); panel.hide()
			await scenario.run(panel.get_parent(),panel._documents,func(window: Window, name: String) -> void: await _capture(tree,window,name,resolution,images))
			_checks+=scenario.checks; _failures.append_array(scenario.failures); panel.show(); continue
		if _final_ui_only:
			var scenario=load("res://.godot/Editor_FinalUiScenario.gd").new(); panel.hide()
			await scenario.run(panel.get_parent(),panel._documents,func(fixture: Window, name: String) -> void:
				for frame in 8: await tree.process_frame
				RenderingServer.force_draw(false); await tree.process_frame
				expect(fixture.size.x<=resolution.x and fixture.size.y<=resolution.y,"final UI window fits "+name)
				var filename=name+"-"+suffix+".png"; expect(tree.root.get_texture().get_image().save_png(_captures.path_join(filename))==OK,"capture final UI "+name); images.append(filename))
			_checks+=scenario.checks; _failures.append_array(scenario.failures); print("FINAL UI METRICS: ",JSON.stringify(scenario.metrics)); panel.show(); continue
		if _feedback_only:
			var scenario=load("res://.godot/Editor_FeedbackScenario.gd").new()
			panel.hide()
			var result: Dictionary=await scenario.run(panel.get_parent(),panel._documents,func(window: Window, name: String) -> void: await _capture(tree,window,name,resolution,images))
			expect(result.mixed_samples>0 and result.audio_peak>0.00001,"native editor animation audio reaches the actual mixer")
			print("PROBE AUDIO: ",result.mixed_samples," samples / peak=",result.audio_peak)
			_checks+=scenario.checks; _failures.append_array(scenario.failures); panel.show(); continue
		if _database_authoring_only:
			var scenario=load("res://.godot/Editor_DatabaseAuthoringScenario.gd").new()
			await scenario.run(panel, panel._documents,func(database: Window, name: String) -> void:
				var window: Window=database
				for child in [database._form._table_dialog,database._form._set_dialog,database._form._dialog,database._form._extension_dialog]:
					if child!=null and child.visible: window=child
				await _capture(tree,window,name,resolution,images)
				if name=="animation-frame":
					var canvas: Control=database._form._animation._canvas
					expect(canvas.is_visible_in_tree(),"animation canvas is visible in the dedicated tab")
					for control in database._form._animation._cell_controls:
						expect(control.get_global_rect().end.y<=database._form._tabs.get_global_rect().end.y and control.get_global_rect().end.x<=database._form._tabs.get_global_rect().end.x,"animation parameters stay visible beside preview")
					var point=Vector2i(canvas.get_screen_transform().origin-Vector2(tree.root.position)+canvas.size/2+Vector2(12,-6))
					var pixels=tree.root.get_texture().get_image()
					if Rect2i(Vector2i.ZERO,pixels.get_size()).has_point(point):
						var color=pixels.get_pixelv(point); expect(color.r>0.45 and color.g>0.25 and color.b<0.4,"animation preview renders actual transformed source pixels")
					else: expect(false,"animation preview lies inside editor viewport"))
			_checks+=scenario.checks; _failures.append_array(scenario.failures); continue
		if _tileset_layers_only:
			var scenario=load("res://.godot/Editor_TilesetLayersScenario.gd").new(); panel.hide()
			await scenario.run(panel.get_parent(),panel._documents,func(fixture: Control, name: String) -> void:
				for frame in 8: await tree.process_frame
				RenderingServer.force_draw(false); await tree.process_frame
				for window in [fixture._database,fixture._database._sources_dialog,fixture._event_dialog,fixture._settings._tile_dialog]:
					if window!=null and window.visible: expect(window.size.x<=resolution.x and window.size.y<=resolution.y,"tileset layer popup fits viewport "+name)
				var database=fixture._database
				if database.visible and database._tileset_editor._tabs.current_tab==0:
					expect(database._tileset_editor._terrain.get_global_rect().end.y<=database._tileset_editor._tabs.get_global_rect().end.y,"homepage terrain control remains visible "+name)
				var filename=name+"-"+suffix+".png"; expect(tree.root.get_texture().get_image().save_png(_captures.path_join(filename))==OK,"capture tileset layers "+name); images.append(filename))
			_checks+=scenario.checks; _failures.append_array(scenario.failures); panel.show(); continue
		if _event_authoring_only:
			var scenario=load("res://.godot/Editor_EventAuthoringScenario.gd").new(); panel.hide()
			await scenario.run(panel.get_parent(),panel._documents,func(fixture: Control, name: String) -> void:
				for frame in 8: await tree.process_frame
				RenderingServer.force_draw(false); await tree.process_frame
				var windows: Array=[fixture._event_dialog,fixture._command_dialog,fixture._settings._asset_dialog,fixture._settings._tile_dialog,fixture._settings._extension_dialog]
				for window in windows:
					if window!=null and window.visible: expect(window.size.x<=resolution.x and window.size.y<=resolution.y,"event popup fits viewport "+name)
				var filename=name+"-"+suffix+".png"; expect(tree.root.get_texture().get_image().save_png(_captures.path_join(filename))==OK,"capture event authoring "+name); images.append(filename))
			_checks+=scenario.checks; _failures.append_array(scenario.failures); panel.show(); continue
		if _map_editing_only:
			var scenario = load("res://.godot/Editor_MapEditingScenario.gd").new()
			panel.hide()
			await scenario.run(panel.get_parent(),panel._documents,func(fixture: Control, name: String) -> void:
				for frame in 8: await tree.process_frame
				RenderingServer.force_draw(false); await tree.process_frame
				expect(fixture._canvas.size.x>=300 and fixture._canvas.size.y>=250,"map drawing canvas remains usable at "+suffix)
				expect(fixture._palette.get_global_rect().end.x<=fixture._canvas.get_global_rect().position.x,"palette and drawing canvas do not overlap")
				var file_name = name+"-"+suffix+".png"
				expect(tree.root.get_texture().get_image().save_png(_captures.path_join(file_name))==OK,"capture real map authoring "+name)
				images.append(file_name))
			_checks+=scenario.checks; _failures.append_array(scenario.failures)
			panel.show()
			continue
		if _readability_only:
			await _readability_probe(tree,panel,resolution,images)
			continue
		if _database_only:
			await _database_probe(tree,panel,resolution,images)
			continue
		if original_box:
			panel._event_id = 17; panel._open_event(false)
			for item in panel._command_list.get_root().get_children():
				if int(panel._event_draft.pages[0].list[int(item.get_metadata(0))].code) == 209:
					item.select(0); panel._edit_command(); break
		else:
			panel._cell=Vector2i(2,2); panel._open_event(true)
			panel._event_name.text="事件编辑验收"
			panel._add_command(); panel._command_dialog._selector.select(panel._command_dialog._selector.get_item_index(209)); panel._command_dialog._select_code(panel._command_dialog._selector.selected)
		for i in 8:
			OS.low_processor_usage_mode=false
			await tree.process_frame
		RenderingServer.force_draw(false); await tree.process_frame
		expect(panel._command_dialog._route_form.visible,"dedicated209 route actions shown")
		expect(panel._command_dialog.size.x <= resolution.x and panel._command_dialog.size.y <= resolution.y,"route popup fits editor viewport")
		image=tree.root.get_texture().get_image()
		expect(image.save_png(_captures.path_join("route-"+suffix+".png"))==OK,"capture actual route form")
		images.append("route-"+suffix+".png")
		print("PROBE: route captured ",suffix)
		panel._command_dialog.hide()
		print("PROBE: command dialog hidden ",suffix)
		panel._command_index=0; panel._adding_command=true; panel._accept_command(102,[["开门","离开"],5])
		print("PROBE: choice block inserted ",suffix)
		for i in 8:
			OS.low_processor_usage_mode=false
			await tree.process_frame
		print("PROBE: event frames ready ",suffix)
		RenderingServer.force_draw(false); await tree.process_frame
		print("PROBE: event draw ready ",suffix)
		image=tree.root.get_texture().get_image()
		expect(image.save_png(_captures.path_join("event-"+suffix+".png"))==OK,"capture actual event page")
		images.append("event-"+suffix+".png")
		for item in panel._settings._tree.get_root().get_children():
			if item.get_metadata(0) == ["move_route"]:
				item.select(0); panel._settings._edit_selected(); break
		for i in 8:
			OS.low_processor_usage_mode=false
			await tree.process_frame
		RenderingServer.force_draw(false); await tree.process_frame
		expect(panel._settings._route_dialog.visible,"autonomous route has second-level window")
		expect(panel._settings._route_dialog.size.x <= resolution.x and panel._settings._route_dialog.size.y <= resolution.y,"autonomous route popup fits viewport")
		image=tree.root.get_texture().get_image()
		expect(image.save_png(_captures.path_join("autonomous-"+suffix+".png"))==OK,"capture autonomous route popup")
		images.append("autonomous-"+suffix+".png")
		panel._settings._route_dialog.hide()
		panel._event_dialog.hide()
		await _database_probe(tree,panel,resolution,images)
	expect(not EditorInterface.is_playing_scene(),"editor operations never start game")
	var summary ={"checks":_checks,"failures":_failures,"images":images,"game_running":EditorInterface.is_playing_scene()}
	var file =FileAccess.open(_captures.path_join("result.json"),FileAccess.WRITE); file.store_string(JSON.stringify(summary,"\t")); file.close()
	for failure in _failures: printerr("FAIL: ",failure)
	print("EDITOR PLUGIN PROBE: ","PASSED" if _failures.is_empty() else "FAILED"," / ",_checks," checks")
	# Discard unsaved script adaptation from this read-only UI probe.
	panel._documents.reload()
	while EditorInterface.get_resource_filesystem().is_scanning(): await tree.create_timer(0.2).timeout
	tree.quit(0 if _failures.is_empty() else 1)

func _capture(tree: SceneTree, window: Window, name: String, resolution: Vector2i, images: Array) -> void:
	print("PROBE: database capture begin ",name," / size=",window.size)
	for i in 8:
		OS.low_processor_usage_mode=false
		await tree.process_frame
	RenderingServer.force_draw(false); await tree.process_frame
	expect(window.visible,"native database window visible: "+name)
	expect(window.size.x<=resolution.x and window.size.y<=resolution.y,"database popup fits viewport: "+name)
	var filename="%s-%dx%d.png" % [name,resolution.x,resolution.y]
	expect(tree.root.get_texture().get_image().save_png(_captures.path_join(filename))==OK,"capture database UI: "+name)
	images.append(filename)
	print("PROBE: database captured ",name)

func _category(dialog: ConfirmationDialog, name: String) -> void:
	for i in dialog._categories.item_count:
		if dialog._categories.get_item_metadata(i)==name: dialog._categories.select(i); dialog._select_category(i); return

func _field(dialog: ConfirmationDialog, path: Array) -> void:
	var todo: Array=[dialog._form._tree.get_root()]
	while not todo.is_empty():
		var item: TreeItem=todo.pop_back()
		if item.get_metadata(0)==path: item.select(0); dialog._form._edit_selected(); return
		todo.append_array(item.get_children())
	expect(false,"database field exists: "+str(path))

func _database_probe(tree: SceneTree, panel: Control, resolution: Vector2i, images: Array) -> void:
	var dialog: ConfirmationDialog=panel._database
	print("PROBE: database opening")
	dialog.open(panel._documents)
	print("PROBE: database opened")
	await _capture(tree,dialog,"database",resolution,images)
	_field(dialog,["parameters"])
	expect(dialog._form._table_dialog._tree.columns==7,"growth table displays six abilities")
	await _capture(tree,dialog._form._table_dialog,"growth",resolution,images)
	dialog._form._table_dialog.hide()
	_category(dialog,"Classes"); _field(dialog,["weapon_set"])
	await _capture(tree,dialog._form._set_dialog,"permissions",resolution,images)
	dialog._form._set_dialog.hide()
	_category(dialog,"CommonEvents")
	expect(dialog._commands.visible and not dialog._commands.draft().is_empty(),"original common event opens in shared command editor")
	expect(dialog._form._hint(["trigger"]).options.size()==3,"common trigger uses its own three options")
	await _capture(tree,dialog,"common",resolution,images)
	dialog._commands._add_command()
	await _capture(tree,dialog._commands._command_dialog,"common-command",resolution,images)
	dialog._commands._command_dialog.hide()
	_category(dialog,"Tilesets")
	var tiles: Control=dialog._tileset_editor
	expect(tiles._canvas._texture!=null and tiles.is_visible_in_tree() and not dialog._form.visible,"native tile image replaces database placeholders on homepage")
	await _capture(tree,dialog,"tileset",resolution,images)
	expect(tiles._palette_scroll.size.y>=250 and tiles._tabs.size.x>=310,"homepage palette and property pane have usable space")
	expect(tiles._palette_scroll.get_global_rect().end.x<=tiles._tabs.get_global_rect().position.x,"homepage palette and side controls do not overlap")
	var canvas: Control=tiles._canvas
	var origin=canvas.get_screen_transform().origin-Vector2(tree.root.position)
	var rendered=tree.root.get_texture().get_image(); var colored=0
	for y in range(1,8):
		for x in 8:
			var p=Vector2i(origin+Vector2(x*32+16,y*32+16)*canvas._zoom)
			if p.x>=0 and p.y>=0 and p.x<rendered.get_width() and p.y<rendered.get_height():
				var pixel=rendered.get_pixelv(p); var bg=Color("202735")
				if absf(pixel.r-bg.r)+absf(pixel.g-bg.g)+absf(pixel.b-bg.b)>0.08: colored+=1
	expect(colored>8,"tile palette actually renders source pixels, not just a loaded texture")
	var palette_instance=canvas.get_instance_id()
	tiles._palette_scroll.scroll_vertical=96; var scroll_position=tiles._palette_scroll.scroll_vertical
	for mode in tiles._mode_buttons:
		tiles._mode_buttons[mode].pressed.emit(); await tree.process_frame
		expect(canvas.get_instance_id()==palette_instance and tiles._palette_scroll.scroll_vertical==scroll_position,"native property mode retains canvas and scroll: "+mode)
	await _capture(tree,dialog,"tileset-terrain",resolution,images)
	tiles._tabs.current_tab=1
	await _capture(tree,dialog,"tileset-materials",resolution,images)
	expect(canvas.is_visible_in_tree(),"native asset tab retains tile palette")
	_category(dialog,"System")
	await _capture(tree,dialog,"system",resolution,images)
	expect(panel._documents.dirty_paths().is_empty(),"database preview leaves originals unchanged")
	dialog.hide()

func _readability_probe(tree: SceneTree, panel: Control, resolution: Vector2i, images: Array) -> void:
	var manifest: Dictionary=panel._documents.read("data/manifest.json")
	var selected={}
	var best=-1
	for map_name in manifest.maps:
		var map: Dictionary=panel._documents.read("data/maps/"+str(map_name)+".json")
		for key in map.get("events",{}):
			var event: Dictionary=map.events[key]
			for i in event.get("pages",[]).size():
				var list: Array=event.pages[i].get("list",[])
				var score=list.filter(func(c: Variant) -> bool: return int(c.get("code",0)) in [111,117,121,122,201]).size()
				if score>best and list.size()<=35: best=score; selected={"map":str(map_name).trim_prefix("Map").to_int(),"event":int(key),"page":i}
	if selected.is_empty(): expect(false,"readable original event exists"); return
	panel._load_map(selected.map); panel._event_id=selected.event; panel._open_event(false); panel._choose_page(selected.page)
	await _capture(tree,panel._event_dialog,"readable-event",resolution,images)
	var code=121
	panel._command_dialog.open(panel._documents,code,[1,1,0],false,panel._character_targets())
	await _capture(tree,panel._command_dialog,"readable-switch",resolution,images)
	var form: Control=panel._command_dialog._form
	var row: TreeItem=form._tree.get_root().get_first_child()
	expect(row.get_text(1).contains("[0001]"),"actual field includes stable reference ID")
	row.select(0); form._edit_selected()
	expect(form._edit_body.get_children().any(func(c: Node) -> bool: return c is LineEdit),"search box appears in native reference picker")
	await _capture(tree,form._dialog,"reference-picker",resolution,images)
	form._dialog.hide(); panel._command_dialog.hide(); panel._event_dialog.hide()
	var dialog: ConfirmationDialog=panel._database
	dialog.open(panel._documents); _category(dialog,"CommonEvents")
	expect(dialog.title.ends_with(load("res://runtime/scripts/00_Game/RuntimeVersion.gd").VERSION),"database title follows generated runtime version")
	await _capture(tree,dialog,"readable-common",resolution,images)
	dialog.hide()
	expect(panel._documents.dirty_paths().is_empty(),"readability preview does not alter original data")

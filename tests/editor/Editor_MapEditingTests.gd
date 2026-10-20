## 职责：回归验证：运行地图编辑交互场景并检查保存结果。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
var _captures = ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): _captures=arg.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	var scenario = load("res://.godot/Editor_MapEditingScenario.gd").new()
	var original = load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new()
	var result: Dictionary = await scenario.run(root,original)
	var viewport = SubViewport.new(); viewport.size=Vector2i(384,320); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST; root.add_child(viewport)
	var runtime = load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); viewport.add_child(runtime)
	runtime.load_definition(result.saved,result.tileset)
	scenario.expect(runtime.tile_id(1,1,0)==384 and runtime.tile_id(2,2,0)==393,"saved brush tiles feed actual MapRuntime")
	scenario.expect(runtime.tile_id(0,8,0)==91 and runtime.tile_id(1,8,0)==93,"actual runtime reads saved autotile variants")
	scenario.expect(runtime.map_width()==12 and runtime.map_height()==10 and runtime._event_nodes.size()==1,"actual runtime loads saved dimensions and preserved event")
	if not _captures.is_empty():
		scenario.expect(DisplayServer.get_name()!="headless","pixel checks require actual renderer")
		for frame in 4: await process_frame; await RenderingServer.frame_post_draw
		var image = viewport.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_captures)
		scenario.expect(image.save_png(_captures.path_join("saved-map-runtime.png"))==OK,"capture saved map through real runtime renderer")
		var samples = 0
		for cell in [Vector2i(1,1),Vector2i(2,1),Vector2i(1,2),Vector2i(2,2),Vector2i(0,8),Vector2i(1,8)]:
			var id: int = runtime.tile_id(cell.x,cell.y,0)
			for q in 4:
				var offset = Vector2i(q%2,int(q/2))*16+Vector2i(8,8)
				var source: Image; var point: Vector2i
				if id>=384:
					source=runtime._tileset_texture.get_image(); point=Vector2i((id-384)%8,int((id-384)/8))*32+offset
				else:
					var texture: Texture2D=runtime._autotile_textures[int(id/48)-1]
					if texture==null: continue
					source=texture.get_image()
					var part = int(runtime.AUTOTILE_PARTS[id%48][q])-1
					point=offset if texture.get_height()==32 else Vector2i(part%6,int(part/6))*16+Vector2i(8,8)
				var expected = source.get_pixelv(point)
				if expected.a<0.999: continue
				var actual = image.get_pixelv(cell*32+offset)
				scenario.expect(absf(actual.r-expected.r)<0.025 and absf(actual.g-expected.g)<0.025 and absf(actual.b-expected.b)<0.025,"saved source tile pixel at %s / quadrant %d" % [cell,q])
				samples+=1
		scenario.expect(samples>=8,"pixel comparison covers visible painted source tiles")
	viewport.queue_free(); await process_frame
	# Override only this process's fixture definitions, then use the real title/game path.
	var data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	data._cache["res://data/system.json"]=result.system.duplicate(true)
	data._cache["res://data/maps/Map002.json"]=result.new_map.duplicate(true)
	data._cache["res://data/database/CommonEvents.json"]=[null]
	var title = load("res://scenes/05_Title/Title.tscn").instantiate(); root.add_child(title); current_scene=title
	title._on_new_game()
	for frame in 6: await process_frame
	scenario.expect(current_scene!=null and current_scene.name=="Game","saved new map enters actual Game from title")
	if current_scene!=null and current_scene.name=="Game":
		var state = root.get_node("RuntimeState")
		scenario.expect(state.map_id==2 and state.player_x==2 and state.player_y==2,"new game uses saved edited player start")
		scenario.expect(current_scene._map.map_width()==9 and current_scene._map.map_height()==7 and current_scene._map.tile_id(2,2,0)==384,"actual game displays native saved new map dimensions and tile")
		if not _captures.is_empty():
			for frame in 4: await process_frame; await RenderingServer.frame_post_draw
			scenario.expect(root.get_texture().get_image().save_png(_captures.path_join("saved-new-map-game.png"))==OK,"capture actual new game on edited blank map")
		current_scene.queue_free(); current_scene=null; await process_frame
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("MAP EDITING TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

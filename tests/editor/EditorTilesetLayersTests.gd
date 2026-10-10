extends SceneTree
var _captures=""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): _captures=arg.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	var scenario=load("res://.godot/EditorTilesetLayersScenario.gd").new()
	var original=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var result: Dictionary=await scenario.run(root,original)
	var resources=load("res://runtime/scripts/UIResources.gd")
	for name in result.textures: resources._textures["Graphics/Tilesets/"+str(name)]=result.textures[name]
	var viewport=SubViewport.new(); viewport.size=Vector2i(448,320); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST; root.add_child(viewport)
	var runtime=load("res://runtime/scripts/MapRuntime.gd").new(); viewport.add_child(runtime); runtime.load_definition(result.map,result.tileset)
	scenario.expect(runtime.tile_id(8,3,4)==401,"actual runtime reads saved fifth layer after source reorder")
	scenario.expect(runtime.tile_texture(392).atlas==result.textures["房屋.png"],"runtime resolves tile event in second separate texture")
	scenario.expect(runtime._event_nodes[0]._texture.atlas==result.textures["房屋.png"],"actual MapEvent uses second source")
	scenario.expect(runtime.is_bush(2,2) and runtime.is_counter(2,2) and runtime.terrain_tag(2,2)==1,"extra layer feeds native bush counter terrain queries")
	scenario.expect(not runtime.can_move(Vector2i.ZERO,Vector2i.RIGHT),"remapped lower layer retains authored blocked passage")
	scenario.expect(not runtime.can_move(Vector2i(2,1),Vector2i.DOWN),"added priority layer respects its directional passage")
	scenario.expect(runtime._tile_rows.size()>0 and runtime._ground_tiles.any(func(c: Vector3i) -> bool: return c.x==8 and c.y==3),"fifth layer renders despite editor-only visibility metadata")
	var definitions=result.tileset.duplicate(true); var placed=result.map.duplicate(true)
	# Later layers retain RM priority 0 short-circuit and do not inherit behavior from names.
	definitions.priorities.values[393]=0; definitions.passages.values[393]=0
	placed.data.values[1+2*14+4*14*10]=393
	placed.data.values[1+2*14]=392
	runtime.load_definition(placed,definitions)
	scenario.expect(runtime.can_move(Vector2i(1,2),Vector2i.RIGHT),"priority zero on added layer follows original RM passage short-circuit")
	definitions.priorities.values[393]=1; runtime.load_definition(placed,definitions)
	scenario.expect(not runtime.can_move(Vector2i(1,2),Vector2i.RIGHT),"priority one falls through to blocked lower tile at destination")
	runtime.load_definition(result.map,result.tileset)
	if not _captures.is_empty():
		scenario.expect(DisplayServer.get_name()!="headless","pixel checks require Compatibility renderer")
		for frame in 4: await process_frame; await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image(); DirAccess.make_dir_recursive_absolute(_captures)
		scenario.expect(image.save_png(_captures.path_join("saved-composite-five-layers.png"))==OK,"capture saved composite map through real runtime")
		for sample in [[Vector2i(0,0),392],[Vector2i(1,0),400],[Vector2i(8,3),401],[Vector2i(2,2),384]]:
			var tile: Texture2D=runtime.tile_texture(sample[1]); var expected=tile.get_image().get_pixel(8,8); var actual=image.get_pixelv(sample[0]*32+Vector2i(8,8))
			scenario.expect(absf(actual.r-expected.r)<0.025 and absf(actual.g-expected.g)<0.025 and absf(actual.b-expected.b)<0.025,"saved runtime source/layer pixel "+str(sample))
		# Foreground rows from any layer participate in actual y sorting with characters.
		var person=load("res://runtime/scripts/MapCharacter.gd").new(); person.map_runtime=runtime; runtime.character_layer.add_child(person)
		person.set_graphic("",0,393); person.motion.relocate(Vector2i(2,2)); person._sync_position()
		for frame in 3: await process_frame; await RenderingServer.frame_post_draw
		image=viewport.get_texture().get_image(); var expected=runtime.tile_texture(384).get_image().get_pixel(8,8)
		var actual=image.get_pixel(2*32+8,2*32+8)
		scenario.expect(absf(actual.r-expected.r)<0.025 and absf(actual.g-expected.g)<0.025 and absf(actual.b-expected.b)<0.025,"priority foreground from fourth layer occludes character through native y sorting")
	viewport.queue_free(); await process_frame
	# Use the actual title/new-game path with the saved composite definitions.
	var data=load("res://runtime/scripts/RuntimeData.gd")
	var system: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(result.folder+"data/system.json"))
	data._cache["res://data/system.json"]=system
	data._cache["res://data/maps/Map001.json"]=result.map.duplicate(true)
	data._cache["res://data/database/Tilesets.json"]=[null,result.tileset.duplicate(true)]
	data._cache["res://data/database/CommonEvents.json"]=[null]
	var title=load("res://scenes/Title.tscn").instantiate(); root.add_child(title); current_scene=title; title._on_new_game()
	for frame in 6: await process_frame
	scenario.expect(current_scene!=null and current_scene.name=="Game","saved composite map starts through actual Title to Game")
	if current_scene!=null and current_scene.name=="Game":
		var state=root.get_node("RuntimeState")
		scenario.expect(state.map_id==1 and state.player_x==0 and state.player_y==0,"actual new game uses saved player start")
		scenario.expect(current_scene._map.tile_id(8,3,4)==401 and current_scene._map.tileset.tileset_sources.size()==2,"actual Game loads saved fifth layer and composite database")
		scenario.expect(current_scene._map._event_nodes[0]._texture.atlas==result.textures["房屋.png"],"actual Game event uses second source")
		if not _captures.is_empty():
			for frame in 4: await process_frame; await RenderingServer.frame_post_draw
			scenario.expect(root.get_texture().get_image().save_png(_captures.path_join("saved-composite-game.png"))==OK,"capture actual Game on saved composite map")
		current_scene.queue_free(); current_scene=null; await process_frame
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("TILESET LAYERS TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

extends SceneTree
var failures: Array[String] = []
var checks := 0
var captures := ""
var state: Node
var data: Script
var game: Node
var size: Vector2i

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: actual renderer required"); quit(1); return
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: actor render timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	state = root.get_node("RuntimeState"); data = load("res://runtime/scripts/RuntimeData.gd")
	var cached: Dictionary = data._cache.duplicate(true)
	var fixture: Dictionary = load(get_script().resource_path.get_base_dir().path_join("EventActorSceneTests.gd")).definitions()
	for database in fixture: data._cache["res://data/database/%s.json" % database] = fixture[database]
	var index: Dictionary = data.read_json("res://data/asset_index.json"); var original_index := index.duplicate(true)
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8); image.fill(Color("e09030"))
	var path := "res://.godot/event-actor-render.tres"; ResourceSaver.save(ImageTexture.create_from_image(image), path)
	index["Graphics/Characters/@actor_render"] = path
	image = Image.create(192, 128, false, Image.FORMAT_RGBA8); image.fill(Color("804020")); image.fill_rect(Rect2i(128, 0, 64, 64), Color("20a080"))
	path = "res://.godot/event-name-skin.tres"; ResourceSaver.save(ImageTexture.create_from_image(image), path); index["Graphics/Windowskins/@name_skin"] = path
	for resolution in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		size = resolution; root.content_scale_size = size; DisplayServer.window_set_size(size)
		var system: Dictionary = data.system().duplicate(true); system.party_members = [1, 2]
		state.begin_new_game(system, {"enabled": false}); state.resume_from_save = true
		game = load("res://scenes/Game.tscn").instantiate(); root.add_child(game); current_scene = game
		await frames(3); game.reset_event_execution()
		var map_fixture: Dictionary = load("res://runtime/scripts/MovementFixture.gd").build(); map_fixture.map.events = {}
		game._map.load_definition(map_fixture.map, map_fixture.tileset); game._scheduler.cancel_all(); game._scheduler.common_events = []
		game.set_process(false); game._player.move_to(6, 5); game._camera.sync(0, true); game._events_enabled = true
		await frames(3)
		var base := root.get_texture().get_image()
		commands([c(322, [1, "@actor_render", 0, "元数据", 0]), c(0)]); await frames(3)
		expect(game._player._name == "@actor_render" and changed_pixels(base, root.get_texture().get_image()) > 250, "322 updates actual leader sprite")
		capture("actor-graphic")
		commands([c(131, ["@name_skin"]), c(303, [1, 8]), c(122, [9630, 9630, 0, 0, 1]), c(0)]); await frames(3)
		var page: Control = game._menus.name_input
		expect(page != null and page.edit.get_global_rect().end.x <= size.x and page.edit.get_global_rect().end.y < size.y, "name input fits actual viewport")
		var point := Vector2i(page._window.global_position + Vector2(4, 4))
		expect(root.get_texture().get_image().get_pixelv(point).g > 0.5, "303 new window inherits131 native skin")
		page.edit.text = "魔塔勇者XZ"; await frames(2); capture("name-input")
		page.submit(); await frames(3)
		expect(state.actor(1).actor_name == "魔塔勇者XZ" and state.variables.get("9630", 0) == 1 and not paused, "actual input confirmation changes actor and resumes event")
		commands([c(135, [0]), c(351), c(0)]); await frames(3)
		expect(paused and game._menus.menu != null and game._menus.menu.size.x > 0, "native event menu renders while manual menu disabled")
		capture("event-menu"); game._menus.close_menu(); await frames(2)
		commands([c(302, [1, 2]), c(0)]); await frames(3)
		expect(paused and game._menus.shop != null, "302 still presents native shop through shared broker")
		capture("event-shop"); game._menus.close_shop(); await frames(2)
		commands([c(353), c(122, [9631, 9631, 0, 0, 1]), c(0)]); await frames(5)
		expect(current_scene.scene_file_path.ends_with("Gameover.tscn") and state.variables.get("9631", 0) == 0 and not paused, "353 renders actual gameover and stops event")
		capture("gameover")
		current_scene.return_to_title(); await frames(5)
		expect(current_scene.scene_file_path.ends_with("Title.tscn") and state.game() == null, "gameover button renders actual title with released map")
		capture("title")
		current_scene.queue_free(); current_scene = null; game = null; await frames(3)
	index.clear(); index.merge(original_index); data._cache.clear(); data._cache.merge(cached)
	state.audio.stop_all(); await frames(3); await create_timer(0.2).timeout
	for failure in failures: printerr("FAIL: ", failure)
	var result := FileAccess.open(captures.path_join("result.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks": checks, "failures": failures, "sizes": ["640x480", "800x480", "768x768"]}, "\t")); result.close()
	print("EVENT ACTOR SCENE RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func commands(list: Array) -> void:
	game._scheduler.start_main(list, 0); game._event_ui.pump(game.event_ui_available()); game._sync_event_input()
func frames(count: int) -> void:
	for index in count: await process_frame; await RenderingServer.frame_post_draw
func c(code: int, p: Array = []) -> Dictionary: return {"code": code, "parameters": p, "indent": 0}
func capture(name: String) -> void:
	expect(root.get_texture().get_image().save_png(captures.path_join("%dx%d-%s.png" % [size.x, size.y, name])) == OK, "capture saved")
func changed_pixels(before: Image, after: Image) -> int:
	var count := 0
	for y in before.get_height():
		for x in before.get_width():
			if not before.get_pixel(x, y).is_equal_approx(after.get_pixel(x, y)): count += 1
	return count
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message + " / " + str(size))

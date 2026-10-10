extends SceneTree
var failures: Array[String] = []
var checks := 0
var captures := ""
var state: Node
var data: Script
var game: Node
var size: Vector2i

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): captures = argument.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: actual renderer required"); quit(1); return
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: presentation render timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	state = root.get_node("RuntimeState"); data = load("res://runtime/scripts/RuntimeData.gd")
	var index: Dictionary = data.read_json("res://data/asset_index.json")
	var original := index.duplicate(true)
	var image := Image.create(192, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color("804020")); image.fill_rect(Rect2i(128, 0, 64, 64), Color("20a080")); image.fill_rect(Rect2i(128, 64, 32, 32), Color("b040a0"))
	var skin_path := "res://.godot/event-render-skin.tres"
	ResourceSaver.save(ImageTexture.create_from_image(image), skin_path)
	image = Image.create(32, 32, false, Image.FORMAT_RGBA8); image.fill(Color("2080c0"))
	var fog_path := "res://.godot/event-render-fog.tres"
	ResourceSaver.save(ImageTexture.create_from_image(image), fog_path)
	index["Graphics/Windowskins/@render_skin"] = skin_path
	index["Graphics/Fogs/@render_fog"] = fog_path; index["Graphics/Panoramas/@render_panorama"] = fog_path
	for resolution in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		size = resolution; root.content_scale_size = size; DisplayServer.window_set_size(size)
		state.begin_new_game(data.system()); state.resume_from_save = true
		game = load("res://scenes/Game.tscn").instantiate(); root.add_child(game); current_scene = game
		await frames(3); game.reset_event_execution()
		var fixture: Dictionary = load("res://runtime/scripts/MovementFixture.gd").build()
		fixture.map.width = 48; fixture.map.height = 36; fixture.map.events = {}
		var values: Array = []; values.resize(48 * 36 * 3); values.fill(0)
		for y in 36:
			for x in 48: values[x + y * 48] = 384 + x % 6
		fixture.map.data = load("res://runtime/scripts/MovementFixture.gd").table(values, 48, 36, 3)
		game._map.load_definition(fixture.map, fixture.tileset)
		for node in [game, game._map, game._player, game._camera, game._screen_renderer, game._effects]: node.set_process(false)
		game._player.move_to(4, 8); game._camera.sync(0, true)
		await refresh()
		var old := root.get_texture().get_image()
		commands([c(203, [6, 5, 4])]); game._camera.sync(0.5); await refresh()
		expect(is_equal_approx(state.map_view.display.x, 80), "203 moves actual camera80pixels halfway")
		expect(changed_pixels(old, root.get_texture().get_image()) > 1000, "203 changes actual map pixels")
		capture("scroll-half")
		game._camera.sync(0.5); await refresh()
		expect(state.map_view.scroll_remaining == 0 and is_equal_approx(state.map_view.display.x, 160), "203 actual camera reaches endpoint")
		await skin()
		commands([c(204, [1, "@render_fog", 0, 0, 0, 100, 0, 0])]); await refresh()
		var point := Vector2i(200, 180); var base := pixel(point)
		commands([c(206, [255, 20])]); game._effects.sync(0.5); await refresh()
		expect(game._effects.fog.visible and not pixel(point).is_equal_approx(base), "206 half opacity changes actual pixels")
		capture("fog-half")
		game._effects.sync(0.5); await refresh()
		expect(pixel(point).is_equal_approx(Color("2080c0")), "206 full fog reaches native texture pixels")
		commands([c(205, [[-255, -255, -255, 0], 20])]); game._effects.sync(0.5); await refresh()
		expect(pixel(point).b < 0.4, "205 native fog tone affects actual shader")
		capture("fog-tone-half")
		game._effects.sync(0.5); await refresh()
		expect(pixel(point).is_equal_approx(Color.BLACK), "205 full dark tone reaches black")
		var transparent: Dictionary = fixture.map.duplicate(true)
		transparent.data.values.fill(0)
		game._map.load_definition(transparent, fixture.tileset)
		commands([c(204, [1, "", 0, 255, 0, 100, 0, 0]), c(204, [0, "@render_panorama", 0])])
		await refresh()
		expect(game._effects.panorama.visible and pixel(point).is_equal_approx(Color("2080c0")), "204 renders panorama behind transparent map")
		capture("panorama")
		game.queue_free(); current_scene = null; await frames(3)
	index.clear(); index.merge(original)
	state.audio.stop_all(); await frames(2)
	for failure in failures: printerr("FAIL: ", failure)
	var result := FileAccess.open(captures.path_join("result.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks": checks, "failures": failures, "sizes": ["640x480", "800x480", "768x768"]}, "\t")); result.close()
	print("EVENT PRESENTATION RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func skin() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; game.add_child(layer)
	var window: Control = load("res://runtime/scripts/WindowBase.gd").new()
	layer.add_child(window); window.position = Vector2(20, 20); window.size = Vector2(240, 140)
	window.label("Skin", Rect2(0, 0, 100, 24)); window.select_rect(Rect2(0, 30, 100, 28))
	commands([c(131, ["@render_skin"])]); await refresh()
	expect(pixel(Vector2i(24, 24)).g > 0.5 and pixel(Vector2i(24, 24)).r < 0.2, "131 actual window frame uses new skin")
	expect(pixel(Vector2i(180, 100)).r > pixel(Vector2i(180, 100)).g, "131 actual window background uses new skin")
	capture("window-skin")
	game._dialogue.show_message(["Skin command"], 42); await refresh()
	var point := Vector2i(game._dialogue._panel.position + Vector2(4, 4))
	expect(game._dialogue._skin_visual != null and pixel(point).g > 0.5 and pixel(point).r < 0.2, "131 applies native frame to dialogue without changing text layout")
	capture("dialogue-skin")
	game._dialogue.dismiss(); commands([c(131, [""])]); await refresh()
	expect(window._skin_root.get_child_count() == 0 and not pixel(Vector2i(24, 24)).is_equal_approx(Color("20a080")), "131 empty skin removes actual frame")
	layer.queue_free(); await frames(2)

func commands(list: Array) -> void:
	var owner: RefCounted = load("res://runtime/scripts/EventInterpreter.gd").new(); owner.map_runtime = game._map
	owner.diagnostic_requested.connect(func(message: String) -> void: failures.append(message))
	owner.start(list + [c(0)], 1)
	expect(not owner.running, "native event command continues without artificial waiting")
func refresh() -> void:
	game._screen_renderer.sync(); game._effects.sync(0); await frames(3)
func frames(count: int) -> void:
	for step in count: await process_frame; await RenderingServer.frame_post_draw
func pixel(point: Vector2i) -> Color: return root.get_texture().get_image().get_pixelv(point)
func capture(name: String) -> void:
	expect(root.get_texture().get_image().save_png(captures.path_join("%dx%d-%s.png" % [size.x, size.y, name])) == OK, "capture saved")
func changed_pixels(before: Image, after: Image) -> int:
	var count := 0
	for y in before.get_height():
		for x in before.get_width():
			var a := before.get_pixel(x, y); var b := after.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length_squared() > 0.001: count += 1
	return count
func c(code: int, p: Array = []) -> Dictionary: return {"code": code, "parameters": p, "indent": 0}
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message + " / " + str(size))

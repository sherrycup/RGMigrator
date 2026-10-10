extends SceneTree
var failures: Array[String] = []
var checks := 0
var captures := ""
var tool: Control
var benchmark := false
func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): captures = argument.trim_prefix("--captures=")
		if argument == "--benchmark": benchmark = true
	call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func frames(count: int = 3) -> void:
	for index in count:
		await process_frame
		await RenderingServer.frame_post_draw
func capture(name_value: String, viewport: Viewport = null) -> Image:
	if viewport == null: viewport = root
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	expect(image.save_png(captures.path_join(name_value + ".png")) == OK, "screenshot " + name_value)
	return image
func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: actual rendering required"); quit(1); return
	create_timer(240).timeout.connect(func() -> void: printerr("FAIL: render timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	Engine.max_fps = 60
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	var system: Dictionary = data.system().duplicate(true)
	if FileAccess.file_exists("res://data/maps/Map585.json"):
		system.start_map_id = 585
		system.start_x = 5
		system.start_y = 2
	state.begin_new_game(system)
	state.resume_from_save = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	for resolution in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		root.size = resolution
		root.content_scale_size = resolution
		await frames()
		expect(game._menus.open_menu(), "open native menu")
		game._menus.menu.open_test_tools()
		await frames()
		await capture("tools-%dx%d" % [resolution.x, resolution.y])
		for index in 5: game._menus.menu.navigate(1)
		game._menus.menu.activate()
		await frames()
		tool = game._menus.menu._commerce
		expect(tool.size == Vector2(resolution) and tool.viewport.size == resolution, "tool logical size")
		tool._left_ui()
		tool.fields.cx.value = (resolution.x - 160) * 0.35
		tool.fields.cy.value = resolution.y * 0.4
		tool._apply_view()
		tool.camera.sync(0, true)
		await frames()
		var image := await capture("camera-%dx%d" % [resolution.x, resolution.y], tool.viewport)
		expect(image.get_pixel(10, resolution.y / 2).is_equal_approx(Color.BLACK), "map cropped out of left UI area")
		var anchor: Vector2 = tool.view.follow_center(Vector2(resolution)) + tool.view.view_rect(Vector2(resolution)).position
		var body := image.get_pixel(int(anchor.x), int(anchor.y - 8))
		expect(body.b > 0.7 and body.r > 0.4, "character actually drawn at custom follow anchor, got " + str(body))
		var origin: Vector2 = tool.view.display
		tool.avatar.move_to(30, 24)
		await frames(20)
		expect(tool.view.display.x > origin.x and tool.view.display.y > origin.y, "large map camera actually follows two axes")
		tool.avatar.move_to(20, 14)
		tool.camera.sync(0, true)
		tool.choices.panorama.select(1); tool.choices.fog.select(1); tool._apply_effects()
		tool.effects.configure({"fog_name": ""})
		tool.screen.weather(0, 0)
		await frames()
		var panorama_image := await capture("panorama-%dx%d" % [resolution.x, resolution.y], tool.viewport)
		var panorama_pixel := panorama_image.get_pixel(int(anchor.x + 40), int(anchor.y + 30))
		expect(panorama_pixel.b > 0.35 and panorama_pixel.r < 0.5, "panorama visible through empty cells, got " + str(panorama_pixel))
		tool._apply_effects()
		tool.screen.weather(2, 9)
		tool._timer_start()
		await frames(10)
		await capture("effects-%dx%d" % [resolution.x, resolution.y], tool.viewport)
		await capture("presentation-ui-%dx%d" % [resolution.x, resolution.y])
		if resolution == Vector2i(640, 480):
			var source_count := 0
			for role in ["panorama", "fog"]:
				if tool.choices[role].item_count > 2:
					tool.choices[role].select(2)
					source_count += 1
			if source_count > 0:
				tool._apply_effects()
				await frames()
				await capture("source-planes", tool.viewport)
				expect(tool.renderer.panorama.visible or tool.renderer.fog.visible, "original sample plane material loads")
		expect(tool.renderer.weather.particle_count() > 0 and tool.renderer.weather.particle_count() <= 256, "batched storm at actual size")
		for page in [1, 2]:
			tool.tabs.current_tab = page
			await frames()
			await capture("presentation-page%d-%dx%d" % [page, resolution.x, resolution.y])
		tool._fade(255)
		tool.transition._process(2)
		await frames()
		var black := await capture("fade-black-%dx%d" % [resolution.x, resolution.y], tool.viewport)
		expect(black.get_pixel(resolution.x / 2, resolution.y / 2).is_equal_approx(Color.BLACK), "fade actually covers rendered map")
		tool._fade(0); tool.transition._process(2)
		await frames()
		var frozen: Dictionary = await tool.transition.freeze_screen()
		expect(frozen.ok and tool.transition.frozen != null, "freeze owns real screenshot")
		tool.avatar.move_to(8, 8); tool.camera.sync(0, true)
		expect(tool.transition.transition(1).ok, "native screenshot transition")
		tool.transition._process(0.5)
		await frames()
		await capture("transition-half-%dx%d" % [resolution.x, resolution.y], tool.viewport)
		tool.transition._process(1)
		expect(tool.transition.frozen == null and tool.transition.rect.material == null, "transition releases screenshot and material")
		await masked_transition(resolution)
		game._menus.close_menu()
		await frames()
	if benchmark: await measure(game)
	state.audio.stop_all()
	for failure in failures: printerr("FAIL: ", failure)
	print("PRESENTATION RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func measure(game: Node) -> void:
	var state: Node = root.get_node("RuntimeState")
	# Measure a real imported map, not the tiny tool preview. Include storm at max power.
	state.screen.weather(2, 9)
	var path: Array[Vector2i] = []
	for y in game._map.map_height():
		for x in game._map.map_width():
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var a := Vector2i(x, y)
				var b: Vector2i = a + direction
				var safe := true
				for cell in [a, b]:
					for event in game._map._events_at.get(cell, []):
						if event.trigger in [1, 2]: safe = false
				if safe and game._map.can_move(a, direction) and game._map.can_move(b, -direction): path = [a, b]; break
			if not path.is_empty(): break
		if not path.is_empty(): break
	if path.is_empty(): expect(false, "benchmark needs safe walk path"); return
	game._player.move_to(path[0].x, path[0].y)
	var steps_before: int = state.steps
	await frames(120)
	var before := {"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "memory": OS.get_static_memory_usage(), "vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < 60000000:
		await process_frame
		if game._player.is_idle():
			var target: Vector2i = path[1] if game._player.tile_position == path[0] else path[0]
			var direction: Vector2i = target - game._player.tile_position
			game._player.move_straight({Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 6, Vector2i.UP: 8}[direction])
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	var elapsed := (last - start) / 1000000.0
	game._player.stop_after_step = true
	while not game._player.is_idle(): await process_frame
	game._player.stop_after_step = false
	samples.sort()
	var metrics := {"seconds": elapsed, "frames": samples.size(), "average_fps": samples.size() / elapsed, "p95_ms": samples[int(ceil(samples.size() * 0.95)) - 1], "weather": "storm9", "resolution": [root.size.x, root.size.y], "before": before}
	metrics.map_id = state.map_id
	metrics.walking_steps = state.steps - steps_before
	expect(metrics.walking_steps > 100, "benchmark includes real walking")
	for index in 20:
		game._menus.open_menu()
		await frames(2)
		game._menus.close_menu()
		await frames(2)
	await frames(20)
	metrics.after = {"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "memory": OS.get_static_memory_usage(), "vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	metrics.target_passed = metrics.average_fps >= 59 and metrics.p95_ms <= 20
	var file := FileAccess.open(captures.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t")); file.close()
	print("PERFORMANCE: ", JSON.stringify(metrics))

func masked_transition(resolution: Vector2i) -> void:
	tool.transition.cancel()
	tool.transition.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 12
	tool.viewport.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color.RED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	await frames()
	var result: Dictionary = await tool.transition.freeze_screen()
	expect(result.ok, "mask test freeze")
	rect.color = Color.BLUE
	var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	mask.fill_rect(Rect2i(0, 0, 32, 64), Color.BLACK)
	load("res://runtime/scripts/UIResources.gd")._textures["Graphics/Transitions/@test_mask"] = ImageTexture.create_from_image(mask)
	expect(tool.transition.transition(1, "@test_mask", 0).ok, "original-format grayscale mask")
	tool.transition._process(0.5)
	await frames()
	var image := await capture("mask-half-%dx%d" % [resolution.x, resolution.y], tool.viewport)
	expect(image.get_pixel(resolution.x / 4, resolution.y / 2).b > 0.9 and image.get_pixel(resolution.x * 3 / 4, resolution.y / 2).r > 0.9, "mask reveals dark area first and retains bright-area frozen pixels")
	tool.transition.cancel()
	tool.transition.set_process(true)
	layer.queue_free()
	await frames()

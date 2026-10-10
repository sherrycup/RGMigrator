extends SceneTree

# Run with a real rendering driver, not --headless. An offscreen viewport
# verifies pixels without interacting with the user's running game.
var failures: Array[String] = []
var capture_path := ""


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	call_deferred("run_suite")


func run_suite() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: MapRenderingTests requires a real renderer; headless cannot verify pixels.")
		quit(1)
		return
	create_timer(20.0).timeout.connect(func() -> void:
		printerr("FAIL: rendering test timed out")
		quit(1)
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var map_script := load("res://runtime/scripts/MapRuntime.gd")
	var map: Node2D = map_script.new()
	viewport.add_child(map)
	if not map.call("load_map", 585):
		printerr("FAIL: Map585 fixture is missing")
		quit(1)
		return
	map.call("_clear_events")
	# Do not retain any extra Texture2D references in the test: that would hide
	# the runtime's local-autotile-texture lifetime bug.
	for _frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	if rendered == null or rendered.is_empty():
		printerr("FAIL: real renderer returned no image")
		quit(1)
		return
	if not capture_path.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
		expect(rendered.save_png(capture_path) == OK, "render capture must save")
		print("CAPTURE: ", capture_path)
	var data := load("res://runtime/scripts/RuntimeData.gd")
	var floor_path: String = data.asset_path("Graphics/Autotiles/SF_Inside_A4-11")
	expect(ResourceLoader.has_cached(floor_path), "map must retain its autotile texture between draw calls")
	# Map585 (13,6) is tile 96 on layer 0 and empty on layers 1/2.
	# Autotile variant 0 uses source quadrants [26,27,32,33] (zero-based).
	var source := Image.load_from_file(ProjectSettings.globalize_path(floor_path))
	var actual := rendered.get_pixel(13 * 32 + 8, 6 * 32 + 8)
	var expected := source.get_pixel(2 * 16 + 8, 4 * 16 + 8)
	print("FLOOR PIXEL: actual=", actual, " expected=", expected)
	expect(absf(actual.r - expected.r) <= 0.02 and absf(actual.g - expected.g) <= 0.02 and absf(actual.b - expected.b) <= 0.02, "rendered floor must match the source autotile, not a white rectangle")
	# A redraw must preserve the same pixels without loading textures per tile.
	map.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var redrawn := viewport.get_texture().get_image()
	expect(redrawn.get_pixel(13 * 32 + 8, 6 * 32 + 8).is_equal_approx(actual), "autotile must survive a later redraw")
	map.free()
	viewport.free()
	await process_frame
	# Now exercise the real Title -> Game path, including events, player and camera.
	# Test-only start override: fresh exports keep their original System start map.
	var startup: Dictionary = data.system().duplicate(true)
	startup.start_map_id = 585
	startup.start_x = 13
	startup.start_y = 6
	data._cache["res://data/system.json"] = startup
	var title: PackedScene = load("res://scenes/Title.tscn")
	var title_node := title.instantiate()
	root.add_child(title_node)
	current_scene = title_node
	title_node.call("_on_new_game")
	for _frame in 30:
		await process_frame
		await RenderingServer.frame_post_draw
	var state := root.get_node("RuntimeState")
	expect(int(state.get("map_id")) == 585, "new game must enter the requested Map585")
	if current_scene != null and current_scene.name == "Game":
		var dialogue: Node = current_scene.get("_dialogue")
		# Newly enabled parallels expose Ruby-dependent source stories. Assert
		# their exact diagnostics and acknowledge actual controls before walking.
		for attempt in 20:
			if not dialogue.call("is_open"): break
			var diagnostic := ""
			var close_button: Button
			for child in dialogue.get("_content").get_children():
				if child is Label: diagnostic += child.text + "\n"
				if child is Button and child.text == "关闭": close_button = child
			var recognized := diagnostic.contains("Map585") and (diagnostic.contains("指令 111") or diagnostic.contains("指令 122") or diagnostic.contains("指令 231") or diagnostic.contains("指令 355"))
			expect(recognized and close_button != null and not diagnostic.contains("指令 116"), "only known excluded/unimplemented source story diagnostics may be acknowledged")
			if not recognized or close_button == null: break
			print("EXPECTED SOURCE DIAGNOSTIC: ", diagnostic)
			close_button.pressed.emit()
			await process_frame
			await RenderingServer.frame_post_draw
		expect(not dialogue.call("is_open"), "supported startup erase and all acknowledged source diagnostics release UI")
		expect(current_scene.get("_map").event_node(2) == null and current_scene.get("_map").has_erased_events(), "Map585 startup command 116 actually erases event 2")
		if not capture_path.is_empty():
			var game_capture := capture_path.get_basename() + "-game.png"
			expect(root.get_texture().get_image().save_png(game_capture) == OK, "actual game screenshot must save")
			print("GAME CAPTURE: ", game_capture)
		var player: Node2D = current_scene.get("_player")
		var active_map: Node2D = current_scene.get("_map")
		expect(bool(player.get("input_enabled")), "player input must be enabled at Map585 spawn")
		var start := Vector2i(int(state.get("player_x")), int(state.get("player_y")))
		var moved := false
		for move in [{"direction": Vector2i.DOWN, "action": "ui_down"}, {"direction": Vector2i.LEFT, "action": "ui_left"}, {"direction": Vector2i.RIGHT, "action": "ui_right"}, {"direction": Vector2i.UP, "action": "ui_up"}]:
			if not active_map.call("can_move", start, move["direction"]):
				continue
			player.set("_move_cooldown", 0.0)
			Input.action_press(move["action"])
			player.call("_process", 0.2)
			Input.action_release(move["action"])
			expect(player.call("moving"), "walking starts an interpolation, not an instant grid teleport")
			player.call("_process", 0.2)
			await process_frame
			await RenderingServer.frame_post_draw
			var destination := Vector2i(int(state.get("player_x")), int(state.get("player_y")))
			moved = destination == start + Vector2i(move["direction"])
			expect(player.position.is_equal_approx(Vector2(destination * 32 + Vector2i(16, 16))), "player sprite must follow its changed grid position")
			print("PLAYER MOVE: ", start, " -> ", destination)
			break
		expect(moved, "player must actually walk one passable tile from Map585 spawn, not only turn")
	else:
		expect(false, "title must enter the actual Game scene")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	await process_frame
	for failure in failures:
		printerr("FAIL: ", failure)
	print("MAP RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

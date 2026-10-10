extends SceneTree
var failures: Array[String] = []
var checks := 0
var captures := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): captures = argument.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: event rendering requires a real renderer")
		quit(1)
		return
	create_timer(45).timeout.connect(func() -> void: printerr("FAIL: event rendering timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	var state := root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	for size in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		root.content_scale_size = size
		DisplayServer.window_set_size(size)
		state.begin_new_game(data.system())
		state.resume_from_save = true
		var game: Node2D = load("res://scenes/Game.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await render_frames(3)
		game._scheduler.cancel_all()
		game._event_ui.cancel_all()
		game._sync_event_input()
		expect(game._menus.open_menu(), "open actual menu %s" % size)
		game._menus.menu.open_test_tools()
		await render_frames(3)
		capture(size, "tools")
		var menu: Control = game._menus.menu
		for index in 6: menu.navigate(1)
		var tools: Control = menu._commerce
		var row: int = tools.selected - tools._commands.scroll_row
		var buttons: Array[Button] = []
		for child in tools._panel.get_children():
			if child is Button: buttons.append(child)
		expect(row >= 0 and row < buttons.size(), "event row has a visible mouse target %s" % size)
		buttons[row].pressed.emit()
		game.set_process(false)
		game._player.set_process(false)
		game._process(0)
		game._process(1)
		game._process(0)
		game._event_lab_hud._process(0)
		await render_frames(3)
		expect(game._event_lab_hud != null and game._map.event_page(5) == 2, "real event commands execute in visible test map %s" % size)
		var hud: Control = game._event_lab_hud.get_child(0)
		expect(hud.get_global_rect().end.x <= size.x and hud.get_global_rect().end.y <= 156, "HUD fits reserved area %s" % size)
		capture(size, "map")
		game._player.move_to(5, 5)
		game._map.request_action(Vector2i(5, 5), Vector2i.UP)
		await render_frames(3)
		expect(game._dialogue.is_open(), "actual foreground message visible %s" % size)
		var panel: Control = game._dialogue._panel
		expect(panel.get_global_rect().end.x <= size.x and panel.get_global_rect().end.y <= size.y, "message panel fits viewport %s" % size)
		var message: Label = game._dialogue._content.get_child(0)
		expect(message.get_minimum_size().y <= message.size.y and message.size.x > 100, "wrapped message has usable layout %s" % size)
		capture(size, "message")
		game._dialogue._continue()
		game._process(1)
		game._dialogue._continue()
		var controls: Node = game._event_lab_hud.get_child(0).get_child(0).get_child(3)
		controls.get_child(0).pressed.emit()
		await render_frames(3)
		expect(game._interpreter.wait_kind() == "choice", "HUD starts actual combined choice %s" % size)
		capture(size, "choice")
		game._dialogue._content.get_child(2).pressed.emit()
		await render_frames(3)
		expect(game._dialogue._number != null, "number input joins the text %s" % size)
		capture(size, "number")
		game._dialogue._number.get_line_edit().text = "3"
		game._dialogue._content.get_child(game._dialogue._content.get_child_count() - 1).pressed.emit()
		for iteration in range(1, 4):
			game._process(0.5)
			await render_frames(3)
			expect(game._dialogue._pages[0].text.contains("第%d/3轮" % iteration), "visible actual loop mutation %s" % size)
			var body: Control = game._dialogue._content.get_child(0)
			expect(body is RichTextLabel and body.size.y > 20, "native colors have readable height %s" % size)
			capture(size, "loop%d" % iteration)
			game._dialogue._continue()
		await render_frames(3)
		expect(int(state.variables.get("9012", 0)) == 6 and game._dialogue._pages[0].text.contains("累计6"), "visible final calculation %s" % size)
		capture(size, "result")
		game._dialogue._continue()
		controls.get_child(1).pressed.emit()
		await render_frames(3)
		expect(game._dialogue._gold.visible and game._dialogue._panel.position.y < 50, "gold and top window visible %s" % size)
		capture(size, "transparent")
		game._dialogue._continue()
		await render_frames(3)
		capture(size, "key-input")
		Input.action_press("rm_l")
		game._dialogue._process(0)
		Input.action_release("rm_l")
		await render_frames(3)
		expect(int(state.variables.get("9013", 0)) == 17, "visible input uses RM key number %s" % size)
		capture(size, "key-result")
		game._dialogue._continue()
		await render_frames(3)
		capture(size, "page1")
		game._dialogue._continue()
		await render_frames(3)
		expect(game._dialogue.is_open() and game._dialogue._page == 1, "second message page %s" % size)
		capture(size, "page2")
		game._dialogue._continue()
		game.reset_event_execution()
		game.queue_free()
		current_scene = null
		await render_frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func capture(size: Vector2i, suffix: String) -> void:
	var img := root.get_texture().get_image()
	expect(img != null and not img.is_empty(), "renderer produces image")
	if img != null: expect(img.save_png(captures.path_join("%dx%d-%s.png" % [size.x, size.y, suffix])) == OK, "capture saves")

func render_frames(count: int) -> void:
	for frame in count:
		await process_frame
		await RenderingServer.frame_post_draw

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

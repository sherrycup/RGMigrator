extends "EventSaveTests.gd"
## Actual Compatibility output, using the same production save fixture.
var captures := ""

func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: actual renderer required"); quit(1); return
	create_timer(65).timeout.connect(func() -> void: printerr("FAIL: event save render timeout"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	DirAccess.make_dir_recursive_absolute(captures)
	state = root.get_node("RuntimeState"); data = load("res://runtime/scripts/RuntimeData.gd")
	saves = load("res://runtime/scripts/SaveService.gd"); codec = load("res://runtime/scripts/SaveCodec.gd")
	saves.directory_override = ProjectSettings.globalize_path("res://.godot/event_save_render_%d" % Time.get_ticks_usec())
	install_fixture()
	for size in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		root.content_scale_size = size; DisplayServer.window_set_size(size)
		await mount(); prepare_restart(); await frames(3)
		var before := root.get_texture().get_image()
		capture(size, "before-load")
		expect(saves.save_slot(1, state).ok, "actual renderer saves event positions and attributes")
		await unmount(); expect(saves.load_slot(1, state).ok, "actual renderer reads event save"); await mount(false); await frames(3)
		capture(size, "after-load")
		var after := root.get_texture().get_image()
		expect(changed_pixels(before, after) < 20, "restored event positions/opacity/graphic render identically")
		game._scheduler.cancel_all()
		game._scheduler.start_main([c(352), add(9730), c(0)], 0)
		game._event_ui.pump(game.event_ui_available()); await frames(3)
		var menu: Control = game._menus.menu
		expect(menu != null and menu.page == "save" and menu._commerce.size.x > 0 and menu._commerce.get_global_rect().end.x <= size.x + 1, "352 actual save page fits viewport")
		capture(size, "event-save-page")
		menu.handle_back(); await frames(2); game._scheduler.advance(0, false)
		expect(state.variables.get("9730") == 1 and not paused, "actual cancel closes save page and resumes caller")
		game._scheduler.cancel_all(); game._event_ui.cancel_all(); game._dialogue.dismiss(); game._sync_event_input()
		state.inventory["item:%d" % item_id] = 1
		expect(game._menus.open_menu(), "actual item menu opens")
		game._menus.menu._push("inventory"); await frames(2)
		var inventory: Control = game._menus.menu._commerce
		for index in inventory._entries.size():
			if inventory._entries[index].kind == "item" and int(inventory._entries[index].id) == item_id: inventory.list_index = index
		inventory.refresh(); await frames(2); capture(size, "common-event-item")
		inventory.activate(); game._scheduler.advance(0); await frames(2)
		expect(state.variables.get("9710") == 1 and game._menus.menu == null, "actual item selection returns to map and executes one common event")
		var actor_id := int(state.party[0]); state.change_skill(actor_id, skill_id, true); state.actor(actor_id).sp = 5
		game._sync_event_input(); expect(game._menus.open_menu(), "actual skill menu opens")
		game._menus.menu._push("skills"); await frames(2)
		var skills: Control = game._menus.menu._commerce
		skills.selected = skills._ids.find(skill_id); skills._selection_id = skill_id; skills.refresh(); await frames(2)
		capture(size, "common-event-skill")
		data.record("Skills", skill_id).scope = 3
		skills.activate(); await frames(2)
		expect(skills._target_selection != null and state.actor(actor_id).sp == 5, "actual single-target selector waits before spending SP")
		capture(size, "skill-targets")
		skills.activate(); game._scheduler.advance(0); await frames(2)
		expect(state.variables.get("9710") == 2 and state.actor(actor_id).sp == 3 and game._menus.menu == null, "actual skill selection pays SP and returns to map")
		data.record("Skills", skill_id).scope = 0
		await unmount()
	state.audio.stop_all(); await frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	var file := FileAccess.open(captures.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "sizes": ["640x480", "800x480", "768x768"]}, "\t")); file.close()
	print("EVENT SAVE RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func frames(count: int) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func capture(size: Vector2i, name_value: String) -> void:
	var path := captures.path_join("%dx%d-%s.png" % [size.x, size.y, name_value])
	expect(root.get_texture().get_image().save_png(path) == OK, "capture " + name_value)

func changed_pixels(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size(): return 1000000
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var first := a.get_pixel(x, y); var second := b.get_pixel(x, y)
			if absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) > 0.1: count += 1
	return count

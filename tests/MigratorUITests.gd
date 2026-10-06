extends SceneTree


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: real rendering required")
		quit(1)
		return
	root.size = Vector2i(1000, 720)
	root.content_scale_size = root.size
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var log: Control = scene.get("_log")
	var mode: CheckBox = scene.get("_test_mode")
	var passed := mode.button_pressed and log.get_global_rect().end.y <= 720 and log.size.y >= 240
	mode.button_pressed = false
	passed = passed and not mode.button_pressed
	mode.button_pressed = true
	var capture := ProjectSettings.globalize_path("res://.godot/test-logs/v019-migrator.png")
	passed = root.get_texture().get_image().save_png(capture) == OK and passed
	print("MIGRATOR UI TESTS: ", "PASSED" if passed else "FAILED", " / ", capture)
	scene.queue_free()
	current_scene = null
	await process_frame
	quit(0 if passed else 1)

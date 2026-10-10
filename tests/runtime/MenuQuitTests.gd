extends SceneTree
## Separate process: verifies that the real Exit command terminates Godot.


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	create_timer(10.0).timeout.connect(func() -> void: printerr("FAIL: Exit command did not terminate the game"); quit(1))
	var title: Node = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title.call("_on_new_game")
	for _frame in 4:
		await process_frame
	# Exit is verified independently of the source opening story.
	current_scene.call("reset_event_execution")
	root.get_node("RuntimeState").menu_disabled = false
	await process_frame
	var dialogue: Node = current_scene.get("_dialogue")
	if dialogue.call("is_open"):
		for child in dialogue.get("_content").get_children():
			if child is Button and child.text == "关闭":
				child.emit_signal("pressed")
	var coordinator: Node = current_scene.get("_menus")
	if not coordinator.call("open_menu"):
		printerr("FAIL: could not open menu for Exit test")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	var menu: Control = coordinator.get("menu")
	menu.call("navigate", 1)
	menu.call("navigate", 1)
	menu.call("activate")
	menu.call("navigate", -1)
	menu.quit_requested.connect(func() -> void: print("QUIT MENU REQUESTED"))
	menu.call("activate")

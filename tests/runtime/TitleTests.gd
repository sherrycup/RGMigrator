extends SceneTree
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(10.0).timeout.connect(func() -> void: printerr("FAIL: title quit timed out"); quit(1))
	var title: Control = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await create_timer(0.3).timeout
	var has_new_game := false
	var exit_button: Button
	for button in title.find_children("*", "Button", true, false):
		if button.text == "新游戏":
			has_new_game = true
		if button.text == "退出":
			exit_button = button
	if not has_new_game or exit_button == null:
		printerr("FAIL: title buttons missing")
		quit(1)
		return
	print("TITLE TESTS: PASSED; requesting actual quit button")
	exit_button.pressed.emit()

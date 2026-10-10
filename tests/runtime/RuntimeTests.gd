extends SceneTree

var failures: Array[String] = []
var diagnostics: Array[String] = []
var completions := 0
var messages: Array = []


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	var state := root.get_node("RuntimeState")
	var data := load("res://runtime/scripts/RuntimeData.gd")
	var event_script := load("res://runtime/scripts/EventInterpreter.gd")
	var title: PackedScene = load("res://scenes/Title.tscn")
	var instance := title.instantiate()
	root.add_child(instance)
	current_scene = instance
	expect(instance.get_script() != null, "title script must load")
	instance.call("_on_new_game")
	await process_frame
	await process_frame
	expect(current_scene != null and current_scene.name == "Game", "New Game must open the game scene")
	if current_scene == null or current_scene.get_script() == null:
		expect(false, "game script must load")
		finish()
		return
	var map: Node = current_scene.get("_map")
	expect(map != null, "map runtime must initialize")
	if map == null:
		finish()
		return
	expect(state.get("map_id") == int(data.system()["start_map_id"]), "new game must use System start map")
	expect(map.call("map_width") > 0, "starting map must have dimensions")
	expect(not map.call("can_move", Vector2i.ZERO, Vector2i.LEFT), "map boundary must block movement")
	var saved_map: Dictionary = map.get("map_data")
	var saved_tileset: Dictionary = map.get("tileset")
	map.set("map_data", {"width": 2, "height": 1, "data": table([1, 1, 0, 0, 0, 0], 2, 3)})
	map.set("tileset", {"passages": table([0, 4], 2), "priorities": table([5, 0], 2)})
	expect(not map.call("_passable_at", Vector2i.ZERO, 4), "upper empty layers must not override ground passage")
	expect(map.call("_passable_at", Vector2i.ZERO, 2), "directional passages must allow other directions")
	map.set("map_data", saved_map)
	map.set("tileset", saved_tileset)
	current_scene.reset_event_execution()
	for map_name in data.manifest().get("maps", []):
		var id := str(map_name).trim_prefix("Map").to_int()
		expect(map.call("load_map", id), "map must load: " + str(map_name))
		# Map changes start/stop audio; let the deferred playback lifecycle run.
		await process_frame
	# Interpreter uses independent state; source event arrays must remain immutable.
	state.call("begin_new_game", data.system())
	var interpreter: RefCounted = event_script.new()
	interpreter.set("map_runtime", map)
	interpreter.connect("diagnostic_requested", func(message: String) -> void: diagnostics.append(message))
	interpreter.connect("completed", func() -> void: completions += 1)
	interpreter.connect("message_requested", func(lines: Array) -> void: messages.append(lines))
	var commands := [cmd(121, [1, 1, 0]), cmd(122, [2, 2, 0, 0, 8]), cmd(126, [3, 0, 0, 2]), cmd(0)]
	interpreter.call("start", commands, 7, 2)
	expect(completions == 1, "event must complete exactly once")
	expect(commands.size() == 4, "completion must not clear original event list")
	expect(state.get("switches").get("1", false), "switch ON")
	expect(state.get("variables").get("2", 0) == 8, "variable constant operand")
	expect(state.get("inventory").get("item:3", 0) == 2, "add item uses correct operand indices")
	interpreter.call("start", commands, 7, 2)
	expect(completions == 2, "same source event must run again")
	interpreter.call("start", [cmd(111, [0, 9, 0]), cmd(122, [3, 3, 0, 0, 1], 1), cmd(411), cmd(122, [3, 3, 0, 0, 2], 1), cmd(412), cmd(0)], 7)
	expect(state.get("variables").get("3", 0) == 2, "false condition must execute ELSE")
	interpreter.call("start", [cmd(111, [1, 2, 0, 8, 0]), cmd(122, [4, 4, 0, 0, 9], 1), cmd(411), cmd(122, [4, 4, 0, 0, 0], 1), cmd(412), cmd(0)], 7)
	expect(state.get("variables").get("4", 0) == 9, "variable comparison must use RMXP parameter order")
	interpreter.call("start", [cmd(101, ["第一行"]), cmd(401, ["第二行"]), cmd(0)], 7)
	expect(messages.back() == ["第一行", "第二行"], "message continuation")
	interpreter.call("resume_message")
	interpreter.call("start", [cmd(102, [["是", "否"], 5]), cmd(402, [0, "是"]), cmd(122, [5, 5, 0, 0, 1], 1), cmd(402, [1, "否"]), cmd(122, [5, 5, 0, 0, 2], 1), cmd(404), cmd(0)], 7)
	interpreter.call("resume_choice", 1)
	expect(state.get("variables").get("5", 0) == 2, "choice must execute only selected branch")
	interpreter.call("start", [cmd(103, [6, 3]), cmd(0)], 7)
	interpreter.call("resume_number", 123)
	expect(state.get("variables").get("6", 0) == 123, "number input")
	interpreter.call("start", [cmd(355, ["raise 'must never execute'"]), cmd(121, [9, 9, 0]), cmd(0)], 7, 2)
	expect(diagnostics.size() == 1, "unsupported Ruby must emit a diagnostic")
	expect(diagnostics[0].contains("事件 7") and diagnostics[0].contains("第 2 页") and diagnostics[0].contains("355"), "diagnostic must include event/page/command context")
	expect(not state.get("switches").get("9", false), "unsupported command must stop subsequent execution")
	# Exercise dialogue controls and bound callbacks without a display server.
	var ui: Node = current_scene.get("_dialogue")
	ui.call("show_choices", ["测试一", "测试二"], 0)
	var content: Node = ui.get("_content")
	expect(content.get_child_count() == 3, "cancel_type=0 must not add a Cancel button")
	content.get_child(1).emit_signal("pressed")
	expect(not ui.call("is_open"), "choice button callback must close dialogue")
	finish()


func cmd(code: int, parameters: Array = [], indent: int = 0) -> Dictionary:
	return {"code": code, "parameters": parameters, "indent": indent}


func table(values: Array, width: int, depth: int = 1) -> Dictionary:
	return {"x_size": width, "y_size": 1, "z_size": depth, "values": values}


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	# Stop asynchronous audio and let deferred scene/playback deletion settle.
	root.get_node("RuntimeState").audio.stop_all()
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	await create_timer(0.15).timeout
	for failure in failures:
		printerr("FAIL: ", failure)
	print("RUNTIME TESTS: ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)

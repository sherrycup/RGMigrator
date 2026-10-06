extends SceneTree

var failures: Array[String] = []
var fixture: Dictionary
var data: Script
var state: Node


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	create_timer(30.0).timeout.connect(func() -> void: printerr("FAIL: menu tests timed out"); quit(1))
	data = load("res://runtime/scripts/RuntimeData.gd")
	state = root.get_node("RuntimeState")
	var actor_script := load("res://runtime/scripts/ActorState.gd")
	fixture = _fixture()
	var before := JSON.stringify(fixture)
	var actor: RefCounted = actor_script.new()
	actor.configure(1, fixture.Actors[1], lookup)
	var view: Dictionary = actor.snapshot()
	expect(view.level == 2 and view.experience == 30 and view.next_experience == 49, "XP experience curve must be cumulative with per-level truncation")
	expect(view.hp == 120 and view.sp == 34, "initial HP/SP must use [kind, level] table values")
	expect(view.parameters.str == 25 and view.parameters.dex == 16 and view.parameters.agi == 22 and view.parameters.int == 26, "weapon and armor parameter bonuses")
	expect(view.parameters.atk == 12 and view.parameters.pdef == 10 and view.parameters.mdef == 7, "standard equipment attack and defense")
	expect(view.class_name == "测试职业" and view.equipment[0].name == "测试剑", "database reference names")
	view.equipment[0].name = "modified snapshot"
	expect(JSON.stringify(fixture) == before, "snapshots must never expose mutable database definitions")
	actor.hp = 23
	expect(actor.snapshot().hp == 23, "viewing status must not reset HP")
	actor.configure(2, fixture.Actors[2], lookup)
	expect(actor.snapshot().next_experience == null, "maximum level has no next experience requirement")
	expect(actor.snapshot().parameters.atk == 0, "empty equipment uses the standard unarmed value")
	var broken: Dictionary = fixture.Actors[1].duplicate(true)
	broken.class_id = 999
	broken.weapon_id = 999
	broken.parameters.values = []
	actor.configure(3, broken, lookup)
	view = actor.snapshot()
	expect(view.parameters.maxhp == null and view.parameters.atk == null, "invalid references must not invent statistics")
	expect(view.diagnostics.size() >= 3 and str(view.diagnostics).contains("Actors[3]"), "invalid references must be precisely diagnosed")
	# Real Title -> Game with the source's actual map and startup diagnostics.
	var title: Node = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title.call("_on_new_game")
	await frames(3)
	var game: Node = current_scene
	var dialogue: Node = game.get("_dialogue")
	if dialogue.call("is_open"):
		for child in dialogue.get("_content").get_children():
			if child is Button and child.text == "关闭":
				child.emit_signal("pressed")
				break
	await frames(2)
	# Inject a standard fixture only into this process. Source/export files stay untouched.
	for database in fixture:
		data._cache["res://data/database/%s.json" % database] = fixture[database]
	var system: Dictionary = data.system().duplicate(true)
	system.party_members = [1, 2]
	state.call("begin_new_game", system, {"enabled": false})
	var registered: RefCounted = state.call("actor", 1)
	registered.hp = 17
	expect(state.call("actor", 1) == registered and state.call("actor", 1).hp == 17, "actor registry preserves identity and state")
	var interpreter: RefCounted = game.get("_interpreter")
	interpreter.call("start", [command(129, [1, 1, 0]), command(129, [1, 0, 0]), command(0)], 77)
	expect(state.call("actor", 1) == registered and registered.hp == 17, "remove and rejoin without reset preserves state")
	interpreter.call("start", [command(129, [1, 0, 1]), command(0)], 77)
	expect(state.call("actor", 1) != registered and state.call("actor", 1).hp == 120, "join initialization flag resets actor even if already present")
	state.call("begin_new_game", system, {"enabled": false})
	state.set("gold", 12345)
	state.set("steps", 42)
	state.get("switches")["12"] = true
	state.get("inventory")["item:3"] = 4
	var coordinator: Node = game.get("_menus")
	var map_id: int = game.get("_map").get_instance_id()
	var position := Vector2i(state.get("player_x"), state.get("player_y"))
	var facing: Vector2i = game.get("_player").get("facing")
	state.set("menu_disabled", true)
	expect(not coordinator.call("open_menu"), "menu_disabled is enforced")
	state.set("menu_disabled", false)
	dialogue.call("show_message", ["测试消息"])
	expect(not coordinator.call("open_menu"), "dialogue owns focus")
	dialogue.call("show_diagnostic", "测试诊断")
	expect(not coordinator.call("open_menu"), "diagnostic owns focus")
	for child in dialogue.get("_content").get_children():
		if child is Button:
			child.emit_signal("pressed")
	interpreter.set("running", true)
	expect(not coordinator.call("open_menu"), "running event owns focus")
	interpreter.set("running", false)
	await frames(2)
	await press(KEY_ESCAPE)
	var menu: Control = coordinator.get("menu")
	expect(menu != null and menu.get_script() != null, "Esc creates an executable menu scene")
	if menu == null or menu.get_script() == null:
		finish()
		return
	expect(paused and not game.get("_player").get("input_enabled"), "menu pauses map processing and input")
	expect(menu.get("_views").size() == 2, "menu displays both fixture actors")
	expect(menu.get("_gold").text == "12345" and menu.get("_steps").text == "42", "menu counters show runtime state")
	var seconds: float = state.get("play_seconds")
	await create_timer(0.1).timeout
	expect(state.get("play_seconds") > seconds, "play clock includes paused menu time")
	var rebuilds: int = menu.get("content_rebuilds")
	await frames(5)
	expect(menu.get("content_rebuilds") == rebuilds, "idle menu does not rebuild windows every frame")
	await press(KEY_ENTER)
	expect(menu.get("page") == "actors", "Status command opens actor selection")
	await press(KEY_DOWN)
	await press(KEY_Z)
	expect(menu.get("page") == "status" and menu.get("actor_index") == 1, "selected actor opens status")
	await press(KEY_X)
	expect(menu.get("page") == "actors" and menu.get("actor_index") == 1, "back restores actor selection")
	await press(KEY_X)
	expect(menu.get("page") == "menu" and menu.get("command_index") == 3, "back restores command selection")
	await press(KEY_DOWN)
	state.save_disabled = true
	state.state_changed.emit()
	await frames(2)
	await press(KEY_ENTER)
	expect(menu.get("page") == "menu" and menu.get("_hint").text.contains("禁止存档"), "save_disabled prevents save scene")
	state.save_disabled = false
	await press(KEY_ESCAPE)
	expect(not paused and coordinator.get("menu") == null, "close unpauses map")
	expect(game.get("_map").get_instance_id() == map_id, "menu does not reload map instance")
	expect(Vector2i(state.get("player_x"), state.get("player_y")) == position and game.get("_player").get("facing") == facing, "position and facing survive menu")
	expect(state.get("switches")["12"] and state.get("inventory")["item:3"] == 4, "switches and inventory survive menu")
	interpreter.call("start", [command(125, [0, 0, 5]), command(129, [2, 1]), command(0)], 77)
	await frames(2)
	await press(KEY_X)
	menu = coordinator.get("menu")
	expect(menu.get("_gold").text == "12350" and menu.get("_views").size() == 1, "existing events update the same menu state")
	state.set("party", [])
	state.state_changed.emit()
	await frames(2)
	expect(menu.get("_views").is_empty() and not menu.get("_commands").current_enabled(), "empty party disables status")
	state.call("change_party", 999, true)
	expect(state.get("party").is_empty(), "missing actor cannot create a bogus party member")
	await press(KEY_DOWN)
	await press(KEY_DOWN)
	await press(KEY_ENTER)
	expect(menu.get("page") == "end", "end-game command opens its own page")
	await press(KEY_ENTER)
	expect(menu.get("page") == "menu", "end-game cancel restores menu")
	await press(KEY_ENTER)
	await press(KEY_UP)
	await press(KEY_UP)
	await press(KEY_ENTER)
	await frames(3)
	expect(current_scene != null and current_scene.name == "Title" and not paused, "return to title clears pause")
	seconds = state.get("play_seconds")
	await create_timer(0.1).timeout
	expect(is_equal_approx(state.get("play_seconds"), seconds), "title time excluded from play clock")
	current_scene.call("_on_new_game")
	await frames(3)
	expect(state.get("gold") == int(data.test_config().get("initial_gold", 0)) and state.get("steps") == 0 and state.get("play_seconds") < 1.0, "new game resets session counters and prepares configured test gold")
	current_scene.queue_free()
	current_scene = null
	await frames(3)
	finish()


func frames(count: int) -> void:
	for _index in count:
		await process_frame


func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func lookup(database: String, id: int) -> Dictionary:
	var entries: Array = fixture.get(database, [])
	return entries[id] if id > 0 and id < entries.size() and entries[id] is Dictionary else {}


func _fixture() -> Dictionary:
	var values: Array = []
	for level in 100:
		values.append_array([100 + level * 10, 30 + level * 2, 20 + level, 10 + level, 15 + level, 18 + level])
	var actor := {"id": 1, "name": "测试角色", "class_id": 1, "initial_level": 2, "final_level": 99, "exp_basis": 30, "exp_inflation": 30,
		"parameters": {"x_size": 6, "y_size": 100, "values": values}, "weapon_id": 1, "armor1_id": 1}
	var second := actor.duplicate(true)
	second.id = 2
	second.name = "满级角色"
	second.initial_level = 99
	second.weapon_id = 0
	second.armor1_id = 0
	return {"Actors": [null, actor, second], "Classes": [null, {"id": 1, "name": "测试职业"}], "States": [null],
		"Weapons": [null, {"id": 1, "name": "测试剑", "atk": 12, "pdef": 2, "mdef": 1, "str_plus": 2, "dex_plus": 3, "agi_plus": 4, "int_plus": 5}],
		"Armors": [null, {"id": 1, "name": "测试盾", "pdef": 8, "mdef": 6, "str_plus": 1, "dex_plus": 1, "agi_plus": 1, "int_plus": 1}]}


func command(code: int, parameters: Array = []) -> Dictionary:
	return {"code": code, "parameters": parameters, "indent": 0}


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	await create_timer(0.2).timeout
	for failure in failures:
		printerr("FAIL: ", failure)
	print("MENU TESTS: ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)

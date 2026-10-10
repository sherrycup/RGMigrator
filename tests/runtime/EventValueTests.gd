extends SceneTree
var failures: Array[String] = []
var checks := 0
var state: Node
var data: Script
var fixture: Script
var values: Script
var catalog: Script
var interpreter: Script

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: value tests timeout"); quit(1))
	state = root.get_node("RuntimeState")
	data = load("res://runtime/scripts/RuntimeData.gd")
	fixture = load("res://runtime/scripts/EventFixture.gd")
	values = load("res://runtime/scripts/EventValueResolver.gd")
	catalog = load("res://runtime/scripts/EventCommandCatalog.gd")
	interpreter = load("res://runtime/scripts/EventInterpreter.gd")
	state.begin_new_game(data.system())
	test_variables()
	test_conditions()
	test_validation()
	test_persistence()
	await test_ui_and_game()
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT VALUE TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func c(code: int, p: Array = [], indent: int = 0) -> Dictionary: return fixture.command(code, p, indent)
func value(id: int) -> int: return int(state.variables.get(str(id), 0))
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
func frames(count: int = 2) -> void:
	for frame in count: await process_frame

func test_variables() -> void:
	for entry in [[5, 2, 2, 1], [-5, 2, -3, 1], [5, -2, -3, -1], [-5, -2, 2, -1]]:
		expect(values.calculate(entry[0], 4, entry[1]) == entry[2], "Ruby division %s" % [entry])
		expect(values.calculate(entry[0], 5, entry[1]) == entry[3], "Ruby remainder %s" % [entry])
	for operation in range(4, 6): expect(values.calculate(-7, operation, 0) == -7, "zero divisor leaves value unchanged")
	for operation in range(4): expect(values.calculate(6, operation, 3) == [3, 9, 3, 18][operation], "assignment/add/subtract/multiply")
	expect(values.calculate(99999999, 1, 1) == 99999999 and values.calculate(-99999999, 2, 1) == -99999999, "native variable cap")
	expect(values.calculate(9007199254740991, 3, 9007199254740991) == 99999999, "multiply cannot overflow before clamp")
	var owner: RefCounted = interpreter.new()
	owner.start([c(122, [8100, 8105, 0, 2, -3, 3]), c(0)], 1)
	for id in range(8100, 8106): expect(value(id) == value(8100) and value(id) >= -3 and value(id) <= 3, "one inclusive random operand shared by range")
	owner.start([c(122, [8106, 8106, 0, 2, -2, -2]), c(0)], 1)
	expect(value(8106) == -2, "singleton random endpoint")
	var actor: RefCounted = state.actor(int(state.party[0]))
	var expected: Array = [actor.level, actor.experience, actor.hp, actor.sp]
	for key in values.PARAMETER_KEYS: expected.append(actor.get_parameter(key))
	for subtype in range(14):
		owner.start([c(122, [8107, 8107, 0, 4, actor.id, subtype]), c(0)], 1)
		expect(expected[subtype] != null and value(8107) == expected[subtype], "actor operand %d" % subtype)
	var item := int(data.test_config().stock[0].id)
	state.inventory["item:%d" % item] = 7
	owner.start([c(122, [8108, 8108, 0, 3, item]), c(0)], 1)
	expect(value(8108) == 7, "inventory operand uses runtime stock")
	state.gold = 456; state.steps = 23; state.play_seconds = 83.9; state.save_count = 5
	state.timer.start(10); state.timer.advance(1.25)
	for subtype in range(7):
		var result: Dictionary = values.operand([0, 0, 0, 7, subtype], null, 0)
		expect(result.ok and result.value == [state.map_id, state.party.size(), 456, 23, 83, 8, 5][subtype], "other operand %d" % subtype)
	# Independent hand-authored armor/state fixture; native eva has additive states.
	var records := {"Classes:1": {"name": "test", "learnings": []}, "Armors:1": {"eva": 7, "auto_state_id": 2}, "States:1": {"eva": -3}, "States:2": {"eva": 5}}
	var actor_test: RefCounted = load("res://runtime/scripts/ActorState.gd").new()
	actor_test.configure(1, {"class_id": 1, "initial_level": 1, "final_level": 1, "armor1_id": 1, "parameters": {"x_size": 6, "y_size": 2, "values": [0, 0, 0, 0, 0, 0, 100, 50, 10, 10, 10, 10]}}, func(db: String, id: int) -> Dictionary: return records.get("%s:%d" % [db, id], {}))
	actor_test.add_state(1)
	expect(actor_test.get_parameter("eva") == 9, "eva sums armor, ordinary state, equipment state once")

func test_conditions() -> void:
	state.set_event_switch(8150, true); state.set_event_variable(8151, 10); state.set_event_variable(8152, 10)
	state.set_event_self_switch(state.map_id, 1, "B", true)
	for params in [[0, 8150, 0], [0, 8150, 1], [2, "B", 0], [2, "B", 1]]:
		expect(values.condition(params, null, 1).value == (int(params[2]) == 0), "switch/self-switch on/off")
	for operation in range(6):
		expect(values.condition([1, 8151, 1, 8152, operation], null, 0).value == [true, true, true, false, false, false][operation], "six variable comparisons %d" % operation)
	state.timer.start(2); state.timer.advance(2)
	expect(values.condition([3, 0, 1], null, 0).value, "expired native timer remains working until stop")
	state.timer.stop()
	expect(not values.condition([3, 0, 1], null, 0).value, "stopped timer cannot satisfy branch")
	var actor: RefCounted = state.actor(int(state.party[0]))
	var skill := int(data.test_config().toggle_skill_id)
	actor.learn_skill(skill)
	for params in [[4, actor.id, 0], [4, actor.id, 1, actor.actor_name], [4, actor.id, 2, skill], [4, actor.id, 3, actor.equipment[0]], [4, actor.id, 4, actor.equipment[1]]]:
		expect(values.condition(params, null, 0).value, "actor party/name/skill/equipment %s" % [params])
	var state_id := int(data.test_config().toggle_state_id)
	actor.add_state(state_id)
	expect(values.condition([4, actor.id, 5, state_id], null, 0).value, "actor state branch")
	state.gold = 456
	expect(values.condition([7, 456, 0], null, 0).value and values.condition([7, 456, 1], null, 0).value, "gold equality satisfies both comparisons")
	for entry in [[8, "item", "Items"], [9, "weapon", "Weapons"], [10, "armor", "Armors"]]:
		var id := 0
		for record in data.database(entry[2]):
			if record is Dictionary and int(record.get("id", 0)) > 0: id = int(record.id); break
		state.inventory["%s:%d" % [entry[1], id]] = 1
		expect(values.condition([entry[0], id], null, 0).value, "item/weapon/armor ownership")
	var buttons: Script = load("res://runtime/scripts/EventInput.gd")
	buttons.configure()
	for code in buttons.ACTIONS:
		Input.action_press(buttons.ACTIONS[code])
		expect(values.condition([11, code], null, 0).value, "native held key %d" % code)
		Input.action_release(buttons.ACTIONS[code])

func test_validation() -> void:
	var owner: RefCounted = interpreter.new()
	var errors: Array[String] = []
	owner.diagnostic_requested.connect(func(text: String) -> void: errors.append(text))
	for entry in [[121, [1, 2, 7]], [121, [2, 1, 0]], [122, [8100, 8103, 8, 0, 3]], [122, [8100, 8103, 0, 2, 3, 1]], [122, [8100, 8103, 0, 4, 999999, 0]], [126, [999999, 0, 0, 3]], [125, [0, 0, 1.5]], [103, [1, 9]], [104, [3, 0]], [105, [0]], [111, [1, 1, 0, 1, 9]], [124, [0, -1]]]:
		var before: String = JSON.stringify([state.variables, state.switches, state.inventory, state.gold])
		owner.start([c(entry[0], entry[1]), c(122, [8199, 8199, 0, 0, 1]), c(0)], 7, 2)
		expect(not owner.running and JSON.stringify([state.variables, state.switches, state.inventory, state.gold]) == before, "invalid command is atomic %s" % [entry])
		expect(errors.back().contains("事件 7") and errors.back().contains("第 1 条"), "invalid command retains source")
	expect(not catalog.supported(111, [5, 0, 0]) and not catalog.supported(122, [1, 1, 0, 5, 0, 0]) and not catalog.supported(111, [12, "Ruby"]), "battle operands and scripts remain excluded")
	state.gold = 9999998
	owner.start([c(125, [0, 0, 5]), c(0)], 1)
	expect(state.gold == 9999999, "gold upper cap")
	owner.start([c(125, [1, 0, 99999999]), c(0)], 1)
	expect(state.gold == 0, "gold lower cap")
	var item := int(data.test_config().stock[0].id)
	owner.start([c(126, [item, 0, 0, 100]), c(0)], 1)
	expect(state.inventory["item:%d" % item] == 99, "inventory upper cap")

func test_persistence() -> void:
	var codec: Script = load("res://runtime/scripts/SaveCodec.gd")
	var saves: Script = load("res://runtime/scripts/SaveService.gd")
	state.message_position = 0; state.message_frame = 1; state.save_count = 7
	var snapshot: Dictionary = codec.capture(state)
	var old := snapshot.duplicate(true)
	for field in ["save_count", "message_position", "message_frame"]: old.erase(field)
	var prepared: Dictionary = codec.prepare(old)
	expect(prepared.ok and prepared.state.save_count == 0 and prepared.state.message_position == 2 and prepared.state.message_frame == 0, "legacy schema defaults")
	for field in ["save_count", "message_position", "message_frame"]:
		var bad := snapshot.duplicate(true); bad[field] = -1
		expect(not codec.prepare(bad).ok, "save rejects bad optional state %s" % field)
	saves.directory_override = "res://.godot/event_save_%d" % Time.get_ticks_usec()
	expect(saves.save_slot(1, state).ok and state.save_count == 8, "successful save increments count")
	var read: Dictionary = saves.read_slot(1)
	expect(read.ok and read.prepared.state.save_count == 8 and read.prepared.state.message_position == 0 and read.prepared.state.message_frame == 1, "count/options included in successful save")
	state.save_disabled = true
	expect(not saves.save_slot(1, state).ok and state.save_count == 8, "failed save does not increment")
	state.save_disabled = false
	state.begin_new_game(data.system())
	expect(state.save_count == 0 and state.message_position == 2 and state.message_frame == 0, "new game resets message options and save count")

func test_ui_and_game() -> void:
	state.resume_from_save = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game); current_scene = game
	await frames(3)
	game.set_process(false); game._scheduler.cancel_all(); game._event_ui.cancel_all()
	game.enter_event_test_map(); game._player.set_process(false)
	game._process(0); game._process(1); game._process(0)
	var ui: Node = game._dialogue
	var actor: RefCounted = state.actor(int(state.party[0]))
	state.set_event_variable(8180, 12)
	var message: Script = load("res://runtime/scripts/EventMessage.gd")
	var formatted: Dictionary = message.format("V=\\V[8180]; N=\\N[%d]; \\C[2]红\\C[0]; \\G; \\\\V[8180]; [color=red]literal" % actor.id)
	expect(formatted.text.contains("V=12") and formatted.text.contains(actor.actor_name) and formatted.text.contains("\\V[8180]") and formatted.text.contains("[color=red]literal") and formatted.gold, "native escapes and literal slash/BBCode")
	expect(formatted.pieces.any(func(piece: Dictionary) -> bool: return piece.color == 2 and piece.text.contains("红")), "color escape produces colored pieces")
	# Character operands are queried from actual attached map/player nodes.
	for subtype in range(6):
		var result: Dictionary = values.operand([0, 0, 0, 6, -1, subtype], game._map, 0)
		var expected: Array = [5, 6, state.player_direction, int(round(state.player_motion.visual_cell.x * 32 - state.map_view.display.x + 16)), int(round(state.player_motion.visual_cell.y * 32 - state.map_view.display.y + 156 + 32)), game._map.terrain_tag(5, 6)]
		expect(result.ok and result.value == expected[subtype], "character grid/direction/screen/terrain operand %d" % subtype)
	expect(values.condition([6, -1, state.player_direction], game._map, 0).value and not values.operand([0, 0, 0, 6, 99999, 0], game._map, 0).ok, "character direction condition and missing operand")
	# Real broker + overlay + formal common event and loop, including cancel.
	game.start_event_test_scenario("flow")
	expect(game._interpreter.wait_kind() == "choice" and ui._packet.lines.size() == 1, "101 coalesces following fitting choice")
	var stale: Button = ui._content.get_child(1)
	ui._cancel_choice()
	expect(ui._packet.kind == "message" and ui._pages[0].text.contains("取消分支"), "native cancel branch is separate")
	ui._continue()
	expect(not game._interpreter.running, "cancel ends formal event")
	game.start_event_test_scenario("flow")
	ui._content.get_child(2).pressed.emit()
	expect(game._interpreter.wait_kind() == "number:9010" and ui._packet.lines.size() == 1, "101 coalesces following number")
	ui._number.get_line_edit().text = "2"
	ui._content.get_child(ui._content.get_child_count() - 1).pressed.emit()
	for index in range(1, 3):
		expect(game._interpreter.wait_kind() == "time", "loop enters common wait")
		game._process(0.5)
		expect(ui.is_open() and value(9011) == index and ui._pages[0].text.contains("第%d/2轮" % index), "real text follows actual variable mutation")
		stale.pressed.emit()
		expect(ui.is_open(), "stale callback cannot dismiss current iteration")
		ui._continue()
	expect(value(9012) == 3 and ui._pages[0].text.contains("循环已结束"), "loop break shows final accumulated result")
	ui._continue()
	game.start_event_test_scenario("input")
	expect(state.message_position == 0 and state.message_frame == 1 and ui._gold.visible, "top transparent message and gold window")
	var style: StyleBoxFlat = ui._panel.get_theme_stylebox("panel")
	expect(style.bg_color.a == 0, "transparent frame keeps text only")
	ui._continue()
	expect(game._interpreter.wait_kind() == "button:9013", "105 waits for new key")
	var buttons: Script = load("res://runtime/scripts/EventInput.gd")
	await frames(2)
	Input.action_press("rm_c")
	ui._process(0)
	expect(value(9013) == 13 and ui._packet.kind == "message", "fresh C writes native button number")
	Input.action_release("rm_c")
	ui._continue()
	expect(ui._pages.size() == 2 and game._interpreter.wait_kind() == "message", "five source lines create two pages")
	ui._continue()
	expect(ui.is_open() and ui._page == 1, "page advance does not resume interpreter")
	ui._continue()
	expect(not game._interpreter.running, "last page completes formal event")
	# Existing held key never triggers a newly opened button request.
	Input.action_press("rm_c"); await frames(2)
	game._scheduler.start_main([c(105, [8181]), c(0)], 0); game._event_ui.pump()
	await frames(2)
	expect(game._interpreter.wait_kind() == "button:8181", "held confirmation does not fill subsequent button input")
	Input.action_release("rm_c"); await frames(1)
	Input.action_press("rm_b"); ui._process(0)
	expect(value(8181) == 12, "fresh B button code")
	Input.action_release("rm_b")
	for cancel in range(6):
		var commands: Array = [c(102, [["one", "two", "three", "four"], cancel])]
		for branch in range(4): commands.append(c(402, [branch])); commands.append(c(122, [8182, 8182, 0, 0, branch + 10], 1))
		commands.append_array([c(403), c(122, [8182, 8182, 0, 0, 99], 1), c(404), c(0)])
		game._scheduler.start_main(commands, 0); game._event_ui.pump()
		ui._cancel_choice()
		if cancel == 0:
			expect(ui.is_open() and game._interpreter.wait_kind() == "choice", "cancel=0 cannot dismiss or resume")
			ui._content.get_child(1).pressed.emit()
		expect(value(8182) == (10 if cancel == 0 else (99 if cancel == 5 else cancel + 9)), "native cancel target %d" % cancel)
		expect(game._interpreter.context.branches.is_empty(), "choice end clears branch state %d" % cancel)
	state.set_event_variable(8183, 987)
	game._scheduler.start_main([c(103, [8183, 2]), c(0)], 0); game._event_ui.pump()
	expect(ui._number.value == 99, "number initial value clamps to digit range")
	var request: int = game._event_ui.active.id
	game._event_ui.resolve(request, -1); game._event_ui.resolve(request, null)
	expect(game._event_ui.active.id == request and game._interpreter.wait_kind() == "number:8183", "invalid numeric response keeps valid request")
	ui._number.get_line_edit().text = "42"
	ui._content.get_child(ui._content.get_child_count() - 1).pressed.emit()
	expect(value(8183) == 42, "edited numeric field commits exact integer")
	game._scheduler.start_main([c(101, ["1"]), c(401, ["2"]), c(401, ["3"]), c(401, ["4"]), c(102, [["one"], 0]), c(0)], 0); game._event_ui.pump()
	expect(game._interpreter.wait_kind() == "message", "four text lines cannot coalesce a choice")
	ui._continue()
	expect(game._interpreter.wait_kind() == "choice", "non-fitting choice is a subsequent window")
	ui._content.get_child(1).pressed.emit()
	ui.show_message(["long ".repeat(300)])
	expect(ui._pages.size() > 2, "long source line is automatically paginated by display width")
	ui.dismiss()
	game.exit_event_test_map(); game.queue_free(); current_scene = null
	await frames(3)

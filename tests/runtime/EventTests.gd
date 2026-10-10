extends SceneTree
## Deterministic command execution plus the real Game/UI/menu lifecycle.
var failures: Array[String] = []
var checks := 0
var state: Node
var fixture: Script
var interpreter_script: Script
var scheduler_script: Script
var data: Script

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(45).timeout.connect(func() -> void: printerr("FAIL: event test timeout"); quit(1))
	state = root.get_node("RuntimeState")
	fixture = load("res://runtime/scripts/EventFixture.gd")
	interpreter_script = load("res://runtime/scripts/EventInterpreter.gd")
	scheduler_script = load("res://runtime/scripts/EventScheduler.gd")
	data = load("res://runtime/scripts/RuntimeData.gd")
	state.begin_new_game(data.system())
	test_waits()
	test_control_flow()
	test_scheduler()
	test_ui_ownership()
	await test_game()
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func c(code: int, parameters: Array = [], indent: int = 0) -> Dictionary:
	return fixture.command(code, parameters, indent)

func add_variable(id: int, amount: int = 1) -> Dictionary:
	return c(122, [id, id, 1, 0, amount])

func value(id: int) -> int:
	return int(state.variables.get(str(id), 0))

func test_waits() -> void:
	for rate in [30, 40, 60, 120]:
		state.set_event_variable(8001, 0)
		var owner: RefCounted = interpreter_script.new()
		owner.start([c(106, [20]), add_variable(8001), c(0)], 1)
		expect(owner.running and owner.wait_kind() == "time", "106 registers a nonblocking wait at %d FPS" % rate)
		for frame in rate - 1: owner.advance(1.0 / rate)
		expect(value(8001) == 0, "106 does not finish before one second at %d FPS" % rate)
		owner.advance(1.0 / rate)
		expect(value(8001) == 1 and not owner.running, "20 raw units finish at one second at %d FPS" % rate)
	var owner: RefCounted = interpreter_script.new()
	owner.start([c(106, [0]), add_variable(8001), c(0)], 1)
	expect(not owner.running and value(8001) == 2, "zero wait continues immediately")
	owner.start([c(106, [20]), c(0)], 1)
	owner.advance(NAN)
	owner.advance(-1)
	expect(owner.wait_state.remaining == 1.0, "invalid delta does not corrupt wait")
	owner.cancel()
	owner.advance(5)
	expect(not owner.running, "canceled time wait never resumes")
	var catalog: Script = load("res://runtime/scripts/EventCommandCatalog.gd")
	for invalid in [-1, 1000, 1.5, NAN, "20", null]:
		expect(not catalog.supported(106, [invalid]), "catalog rejects invalid wait parameter")
	expect(catalog.supported(106, [20.0]) and catalog.supported(116), "JSON integer and erase are supported")
	expect(catalog.reason(301).contains("不在迁移范围") and not catalog.supported(355) and not catalog.route_reason(45).is_empty(), "battle and script exclusions are explicit")

func test_control_flow() -> void:
	var owner: RefCounted = interpreter_script.new()
	owner.common_events = [null, {"list": [c(106, [20]), c(115), add_variable(8010), c(0)]}]
	state.set_event_variable(8010, 0)
	owner.start([c(117, [1]), add_variable(8010), c(0)], 17, 3)
	expect(owner.context.stack.size() == 1 and owner.context.event_id == 17 and owner.context.common_id == 1, "common event inherits caller and independent stack")
	owner.advance(1)
	expect(value(8010) == 1 and not owner.running and owner.context.stack.is_empty(), "115 returns from child only and parent continues")
	state.set_event_variable(8011, 0)
	owner.start([c(112), c(112, [], 1), add_variable(8011), c(113, [], 2), add_variable(8011, 100), c(413, [], 1), add_variable(8011), c(113, [], 1), add_variable(8011, 100), c(413), c(0)], 17)
	expect(value(8011) == 2 and not owner.running, "nested break exits nearest loop without entering skipped bodies")
	state.set_event_variable(8012, 0)
	owner.start([c(119, ["target"]), add_variable(8012, 100), c(118, ["target"]), add_variable(8012), c(0)], 17)
	expect(value(8012) == 1, "label jump reaches destination")
	var errors: Array[String] = []
	owner.diagnostic_requested.connect(func(message: String) -> void: errors.append(message))
	owner.common_events = [null, {"list": [c(117, [2]), c(0)]}, {"list": [c(355, ["x"]), c(0)]}]
	owner.start([c(117, [1]), c(0)], 17, 3)
	expect(errors.size() == 1 and errors[0].contains("事件 17 / 第 3 页") and errors[0].contains("1 → 2") and errors[0].contains("第 1 条指令 355"), "diagnostic preserves page, nested common chain and exact child command")
	owner.common_events = [null, {"list": [c(117, [1]), c(0)]}]
	owner.start([c(117, [1]), c(0)], 1)
	expect(not owner.running and errors.size() == 2, "recursive common call has a bounded depth")
	owner.start([c(123, ["A", 0]), c(116), c(0)], 0)
	owner.advance(0)
	expect(not owner.running and errors.size() == 2, "global common context treats self-switch and erase as native no-ops")

func test_scheduler() -> void:
	state.switches = {}
	state.variables = {}
	state.self_switches = {}
	var spec: Dictionary = fixture.build()
	var map: Node2D = load("res://runtime/scripts/MapRuntime.gd").new()
	root.add_child(map)
	map.load_definition(spec.map, spec.tileset)
	map.set_process(false)
	for node in map._event_nodes: node.set_process(false)
	var player: Node2D = load("res://runtime/scripts/MapCharacter.gd").new()
	map.ensure_character_layer().add_child(player)
	player.set_process(false)
	player.map_runtime = map
	player.move_to(5, 5)
	map.player_character = player
	var scheduler: RefCounted = scheduler_script.new()
	scheduler.configure(map, spec.common_events)
	map.trigger_allowed = func() -> bool: return not scheduler.main.running
	map.event_requested.connect(func(commands: Array, id: int) -> void: scheduler.start_main(commands, id, map.event_page(id), "", true))
	var npc: Node = map.event_node(1)
	npc.motion.turn(8, true)
	expect(map.request_action(player.tile_position, Vector2i.UP), "confirmation reaches NPC over counter")
	expect(npc.locked and npc.motion.direction == 2 and not npc.move_straight(6), "foreground NPC locks and faces player")
	expect(not map.request_action(player.tile_position, Vector2i.UP), "running foreground cannot trigger twice")
	scheduler.main.cancel()
	scheduler.cancel_all()
	expect(not npc.locked and npc.motion.direction == 8, "cancellation unlocks and restores original direction")
	state.set_event_switch(9008, true)
	scheduler.advance(0)
	expect(scheduler.main.wait_kind() == "time" and scheduler.parallels.size() == 3, "map autorun and map/common parallels start together")
	expect(value(9002) == 1 and value(9003) == 1 and value(9006) == 1, "parallel instances execute independently")
	scheduler.advance(0.5)
	scheduler.advance(0)
	expect(value(9002) == 2 and value(9003) == 1 and value(9006) == 1, "short parallel wait completes before long waits")
	scheduler.advance(0.5)
	scheduler.advance(0)
	expect(value(9005) == 1 and map.event_page(5) == 2 and not scheduler.main.running, "autorun switches its page and foreground remainder continues")
	expect(value(9003) == 2 and value(9006) == 2, "other waits retain independent durations")
	state.set_event_switch(9008, false)
	scheduler.advance(0)
	expect(not scheduler.parallels.has("common:1"), "switch OFF cancels common parallel")
	state.set_event_switch(9008, true)
	scheduler.advance(0)
	expect(value(9006) == 3, "re-enabling common parallel starts a fresh list")
	# A refreshed parallel page must cancel before its following command.
	var refresh_spec: Dictionary = fixture.build()
	refresh_spec.map.events = {"1": fixture.event(4, 4, 4, [c(123, ["A", 0]), add_variable(8020), c(0)], {}, "")}
	refresh_spec.map.events["1"].pages.append({"condition": {"self_switch_valid": true, "self_switch_ch": "A"}, "trigger": 0, "list": [c(0)]})
	map.load_definition(refresh_spec.map, refresh_spec.tileset)
	scheduler.advance(0, false)
	expect(map.event_page(1) == 2 and value(8020) == 0 and not scheduler.parallels.has("event:1:1"), "self-switch refresh cancels obsolete parallel at command boundary")
	# Erasure in a common call inherits caller; main list continues next update.
	state.self_switches = {}
	map.load_definition(spec.map, spec.tileset)
	scheduler.common_events = [null, {"list": [c(116), add_variable(8021), c(0)]}]
	scheduler.main.common_events = scheduler.common_events
	scheduler.start_main([c(117, [1]), add_variable(8021), c(0)], 2)
	expect(map.event_node(2) == null and scheduler.main.running and value(8021) == 0, "erase removes caller and yields without aborting common stack")
	scheduler.advance(0, false)
	expect(value(8021) == 2 and not scheduler.main.running, "erase remainder and caller both continue")
	map.refresh_events()
	expect(map.event_node(2) == null and map.has_erased_events(), "refresh never resurrects erased event")
	map.load_definition(spec.map, spec.tileset)
	expect(map.event_node(2) != null and not map.has_erased_events(), "new map instance resets temporary erasure")
	# Event touching player uses the entity's blocked move path.
	var touch: Node = map.event_node(1)
	touch.trigger = 2
	touch.move_to(4, 5)
	player.move_to(5, 5)
	expect(not touch.move_straight(6) and scheduler.main.running, "event contact with player starts foreground on blocked motion")
	scheduler.cancel_all()
	player.move_to(2, 7)
	expect(map.trigger_player_touch(Vector2i(2, 7)), "player contact triggers below-player event")
	scheduler.cancel_all()
	# Bad autoruns stop until their condition/page becomes inactive.
	var faulty: Dictionary = fixture.build()
	faulty.map.events = {"1": fixture.event(3, 3, 3, [c(355), c(0)], {"switch1_valid": true, "switch1_id": 8022}, "")}
	state.set_event_switch(8022, true)
	map.load_definition(faulty.map, faulty.tileset)
	var errors: Array[String] = []
	scheduler.main.diagnostic_requested.connect(func(message: String) -> void: errors.append(message))
	for frame in 10: scheduler.advance(0)
	expect(errors.size() == 1, "failing autorun does not emit a diagnostic every frame")
	state.set_event_switch(8022, false)
	scheduler.advance(0)
	state.set_event_switch(8022, true)
	scheduler.advance(0)
	expect(errors.size() == 2, "condition reactivation permits one fresh attempt")
	# No-wait loops yield with a shared budget so other parallel lists progress.
	var busy: Dictionary = fixture.build()
	busy.map.events = {"1": fixture.event(3, 3, 4, [c(112), add_variable(8023), c(413)], {}, ""), "2": fixture.event(4, 3, 4, [add_variable(8024), c(106, [20]), c(0)], {}, "")}
	map.load_definition(busy.map, busy.tileset)
	scheduler.frame_budget = 12
	scheduler.advance(0, false)
	expect(value(8023) > 0 and value(8023) < 12 and value(8024) == 1, "infinite loop yields fairly within the frame budget")
	var old_parallel: RefCounted = scheduler.parallels["event:1:1"].owner
	map.load_definition(spec.map, spec.tileset)
	expect(not old_parallel.running, "map change cancels old parallel context")
	# A switch-driven common autorun repeats while ON, with no current map event.
	map.load_definition({"width": 12, "height": 9, "data": spec.map.data, "events": {}}, spec.tileset)
	scheduler.common_events = [null, {"id": 1, "trigger": 1, "switch_id": 8025, "list": [add_variable(8026), c(106, [20]), c(0)]}]
	scheduler.main.common_events = scheduler.common_events
	state.set_event_switch(8025, true)
	scheduler.advance(0)
	expect(value(8026) == 1 and scheduler.main.context.event_id == 0 and scheduler.main.context.common_id == 1, "common autorun starts with global context")
	scheduler.advance(1)
	scheduler.advance(0)
	expect(value(8026) == 2, "common autorun repeats while condition remains ON")
	state.set_event_switch(8025, false)
	scheduler.advance(1)
	scheduler.advance(0)
	expect(value(8026) == 2 and not scheduler.main.running, "common autorun finishes current foreground list and stops restarting when OFF")
	# Transfers preserve source diagnostics but remove current-event targeting.
	var saved_id: int = state.map_id
	var destination: Dictionary = spec.map.duplicate(true)
	destination.tileset_id = 0
	destination.events = {"1": fixture.event(4, 4, 0, [c(0)], {}, "")}
	data._cache["res://data/maps/Map991.json"] = destination
	scheduler.start_main([c(201, [0, 991, 4, 5, 0, 1]), c(123, ["B", 0]), c(116), add_variable(8027), c(355), c(0)], 1, 2)
	expect(state.map_id == 991 and scheduler.main.context.event_id == 0 and scheduler.main.context.source_map_id == saved_id, "transfer drops current event but retains original source coordinates")
	# 201 yields until relocation completes; 116 then yields its own native update.
	scheduler.advance(0, false)
	scheduler.advance(0, false)
	expect(value(8027) == 1 and map.event_node(1) != null and not state.self_switches.has(state.self_switch_key(991, 1, "B")), "post-transfer self-switch/erase cannot affect same ID on destination")
	expect(errors.back().contains("Map%03d / 事件 1 / 第 2 页" % saved_id), "post-transfer diagnostic reports original event page")
	data._cache.erase("res://data/maps/Map991.json")
	state.map_id = saved_id
	scheduler.dispose()
	map.load_definition(spec.map, spec.tileset)
	expect(scheduler.main == null, "disposed scheduler detaches map callbacks")
	map.free()

func test_ui_ownership() -> void:
	var broker: RefCounted = load("res://runtime/scripts/EventUIBroker.gd").new()
	var first: RefCounted = interpreter_script.new()
	var second: RefCounted = interpreter_script.new()
	broker.bind_interpreter(first)
	broker.bind_interpreter(second)
	first.start([c(101, ["first"]), add_variable(8030), c(0)], 1)
	second.start([c(101, ["second"]), add_variable(8031), c(0)], 2)
	broker.pump()
	var old_id: int = broker.active.id
	var token: int = first.wait_token()
	expect(broker.active.payload[0] == ["first"], "first queued interpreter owns the UI")
	broker.resolve(old_id)
	broker.pump()
	broker.resolve(old_id)
	expect(value(8030) == 1 and value(8031) == 0 and second.wait_kind() == "message", "duplicate old response cannot resume another owner")
	first.start([c(101, ["replacement"]), c(0)], 1)
	first.resume_message(token)
	expect(first.wait_kind() == "message", "old wait token cannot resume a new execution on same interpreter")
	second.cancel()
	broker.pump()
	expect(broker.active.payload[0] == ["replacement"], "canceled active owner releases UI to next valid request")
	first.cancel()
	broker.pump()
	expect(not broker.busy(), "canceled waits leave no pending UI")

func test_game() -> void:
	state.begin_new_game(data.system())
	state.resume_from_save = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.set_process(false)
	game._scheduler.cancel_all()
	var original: Dictionary = fixture.build()
	original.map.events = {"1": fixture.event(4, 4, 0, [c(0)], {}, ""), "2": fixture.event(4, 5, 4, [add_variable(8040), c(106, [100]), c(0)], {}, "")}
	game._map.load_definition(original.map, original.tileset)
	game._scheduler.common_events = []
	game._scheduler.main.common_events = []
	game._map.erase_event(1)
	game._scheduler.advance(0, false)
	var original_map: Node = game._map
	var original_scheduler: RefCounted = game._scheduler
	var original_owner: RefCounted = original_scheduler.parallels["event:2:1"].owner
	var remaining: float = original_owner.wait_state.remaining
	state.set_event_variable(8041, 75)
	game._player.move_to(5, 6)
	expect(not load("res://runtime/scripts/SaveService.gd").save_slot(1, state).ok, "direct save rejects unpersisted event runtime before writing")
	expect(game._menus.open_menu(), "ordinary menu remains available with time-only parallels")
	await frames(4)
	expect(original_owner.wait_state.remaining == remaining, "menu pauses event wait with the map")
	game._menus.menu.open_test_tools()
	for index in 6: game._menus.menu.navigate(1)
	game._menus.menu.activate()
	expect(not game._event_lab_backup.is_empty() and game._map != original_map, "test-tools keyboard entry opens the formal event map")
	game._player.set_process(false)
	game._process(0)
	expect(game._interpreter.wait_kind() == "time" and not game._player.input_enabled, "autorun wait blocks player input")
	game._process(1)
	game._process(0)
	expect(value(9005) == 1 and game._player.input_enabled, "autorun changes page and restores input")
	game._player.move_to(5, 5)
	expect(game._map.request_action(Vector2i(5, 5), Vector2i.UP), "real map confirmation starts foreground")
	var old_button: Button = game._dialogue._content.get_child(1)
	var parallel_before := value(9002)
	game._process(0.5)
	game._process(0)
	expect(value(9002) > parallel_before and game._dialogue.is_open(), "parallel time advances behind foreground message")
	old_button.pressed.emit()
	expect(game._interpreter.wait_kind() == "time", "real continue button resumes caller into common wait")
	game._process(1)
	expect(game._dialogue.is_open() and value(9001) == 1, "common wait returns into second real message")
	old_button.pressed.emit()
	expect(game._dialogue.is_open() and game._interpreter.wait_kind() == "message", "stale real button cannot hide or resume replacement message")
	var button: Button = game._dialogue._content.get_child(1)
	button.pressed.emit()
	expect(game._player.input_enabled, "final response unlocks foreground input")
	game._player.move_to(2, 7)
	game._map.trigger_player_touch(Vector2i(2, 7))
	button = game._dialogue._content.get_child(1)
	button.pressed.emit()
	game._process(0)
	expect(value(9004) == 1 and game._map.event_node(2) == null, "actual touch message erases then continues")
	game._map.refresh_events()
	expect(game._map.event_node(2) == null, "actual deleted touch event remains absent on refresh")
	game.exit_event_test_map()
	expect(game._map == original_map and game._scheduler == original_scheduler, "exiting fixture restores original live map and scheduler")
	expect(original_map.event_node(1) == null and original_owner.running and original_owner.wait_state.remaining == remaining, "original erasure and parallel wait remain intact")
	expect(value(8041) == 75 and value(9001) == 0 and state.player_x == 5 and state.player_y == 6, "original variables and player position restored without fixture writes")
	game._process(0)
	expect(game._effects.model == state.map_effects and game._camera.model == state.map_view, "restored renderers bind restored state models")
	state.begin_new_game(data.system())
	expect(not original_owner.running and not game._events_enabled and not game._event_ui.busy(), "new game cancels every old wait and UI before reset")
	game.queue_free()
	current_scene = null
	await frames(4)

func frames(count: int) -> void:
	for frame in count: await process_frame

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

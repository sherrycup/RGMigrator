## 职责：回归验证：验证人物移动、强制路线、碰撞与换图生命周期。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func c(code: int, p: Array = []) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；默认值 []）：对应事件指令的参数数组。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func route(commands: Array, repeat: bool = false, skip: bool = false) -> Dictionary
##     参数 commands（Array；必填）：保持原顺序的事件指令列表。
##     参数 repeat（bool；默认值 false）：是否重复播放或重复执行。
##     参数 skip（bool；默认值 false）：需要跳过的条目数或步骤。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func definition() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func page_event(x: int, y: int, type: int = 0, custom: Dictionary = {}) -> Dictionary
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 type（int；默认值 0）：当前操作的类型标识。
##     参数 custom（Dictionary；默认值 {}）：自定义数据运行服务或当前自定义配置。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func build_map() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func reset_event(x: int = 4, y: int = 4) -> void
##     参数 x（int；默认值 4）：横向坐标。
##     参数 y（int；默认值 4）：纵向坐标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func finish(character: Node, count: int = 80, delta: float = 0.1) -> void
##     用途：结束本次处理并返回结果。
##     参数 character（Node；必填）：地图人物对象或原人物参数。
##     参数 count（int；默认值 80）：处理数量或重复次数。
##     参数 delta（float；默认值 0.1）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_validation() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_movement() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_turns_and_properties() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_wait_and_restore() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_autonomous() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_commands() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_parallel_routes() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_game() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func frames(count: int) -> void
##     用途：让测试现场推进指定帧数。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
## Targeted native-command tests. No user-facing demonstration scene is added.
var failures: Array[String] = []
var checks := 0
var state: Node
var data: Script
var catalog: Script
var route_script: Script
var interpreter: Script
var map: Node2D
var player: Node2D
var event: Node2D

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: event movement timeout"); quit(1))
	state = root.get_node("RuntimeState")
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	catalog = load("res://runtime/scripts/02_Event/EventCommandCatalog.gd")
	route_script = load("res://runtime/scripts/02_Event/CharacterRoute.gd")
	interpreter = load("res://runtime/scripts/02_Event/EventInterpreter.gd")
	state.begin_new_game(data.system())
	build_map()
	test_validation()
	test_movement()
	test_turns_and_properties()
	test_wait_and_restore()
	test_autonomous()
	test_commands()
	test_parallel_routes()
	map.queue_free()
	await frames(2)
	await test_game()
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT MOVEMENT TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func c(code: int, p: Array = []) -> Dictionary:
	return {"code": code, "parameters": p, "indent": 0}

func route(commands: Array, repeat: bool = false, skip: bool = false) -> Dictionary:
	var list := commands.duplicate(true)
	list.append(c(0))
	return {"repeat": repeat, "skippable": skip, "list": list}

func definition() -> Dictionary:
	var values: Array = []
	values.resize(20 * 14)
	values.fill(384)
	return {"width": 20, "height": 14, "tileset_id": 0, "events": {
		"1": page_event(4, 4), "2": page_event(10, 8)},
		"data": {"x_size": 20, "y_size": 14, "z_size": 1, "values": values}}

func page_event(x: int, y: int, type: int = 0, custom: Dictionary = {}) -> Dictionary:
	return {"x": x, "y": y, "pages": [{"condition": {}, "move_type": type, "move_frequency": 6, "move_speed": 4,
		"move_route": route([]) if custom.is_empty() else custom, "graphic": {"character_name": "@movement_character", "direction": 2}, "list": [c(0)]}]}

func build_map() -> void:
	var resources: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build()
	map = load("res://runtime/scripts/03_Map/MapRuntime.gd").new()
	root.add_child(map)
	map.load_definition(definition(), resources.tileset)
	map.set_process(false)
	for item in map.event_contexts(): item.node.set_process(false)
	player = load("res://runtime/scripts/03_Map/PlayerController.gd").new()
	map.ensure_character_layer().add_child(player)
	player.configure(map)
	player.set_process(false)
	player.input_enabled = false
	map.player_character = player
	player.move_to(14, 10)
	event = map.event_node(1)

func reset_event(x: int = 4, y: int = 4) -> void:
	event.routes.configure(0, 6, route([]))
	event.locked = false
	event.motion.reset()
	event.move_to(x, y)
	event.set_always_on_top(false)
	event.set_route_graphic("@movement_character", 0, 2, 0)
	event.motion.turn(2, true)

func finish(character: Node, count: int = 80, delta: float = 0.1) -> void:
	for index in count:
		character.advance_motion(delta)
		if not character.routes.forcing: return

func test_validation() -> void:
	var parameters := {14: [0, 0], 15: [20], 27: [8701], 28: [8701], 29: [4], 30: [6], 41: ["@movement_character", 0, 2, 0], 42: [127], 43: [1], 44: [{"name": "", "volume": 80, "pitch": 100}]}
	for code in range(45): expect(catalog.route_reason(code, parameters.get(code, [])).is_empty(), "native non-script route code %d validates" % code)
	for malformed in [{}, {"repeat": 1, "skippable": false, "list": [c(0)]}, route([c(15, [-1])]), route([c(29, [7])]), route([c(30, [0])]), route([c(41, ["x", 361, 2, 0])]), route([c(42, [256])]), route([c(43, [3])]), route([c(44, [{"name": "", "pitch": 10}])]), route([c(1, [99])]), route([c(0)]), {"repeat": false, "skippable": false, "list": [c(1)]}]:
		expect(not catalog.route_validation(malformed).ok, "invalid route rejected before execution")
	var before: Dictionary = event.motion_snapshot()
	state.set_event_switch(8701, false)
	var rejected: Dictionary = event.force_move_route(route([c(27, [8701]), c(45, ["Ruby"])]))
	expect(not rejected.ok and rejected.route_index == 2 and event.motion_snapshot() == before and not state.switches.get("8701", false), "script exclusion preflights entire route atomically")
	expect(not event.force_move_route(route([c(27, [8701]), c(41, ["@missing_route_graphic", 0, 2, 0])])).ok and not state.switches.get("8701", false), "missing graphic does not partially apply route")
	for command in [c(201, [0, 1, 0, 0]), c(202, [0, 1, 0, 1, 0]), c(207, [-1, -1]), c(208, [2]), c(209, [-2, route([])]), c(210, [1]), c(509, [{"code": 1, "parameters": "bad"}])]:
		expect(not catalog.supported(command.code, command.parameters), "strict native main command parameter validation")

func test_movement() -> void:
	var offsets := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
	for index in 8:
		reset_event()
		expect(event.force_move_route(route([c(index + 1)])).ok and event.moving(), "route movement starts %d" % (index + 1))
		event.advance_motion(0.1)
		expect(event.motion.visual_cell.is_equal_approx(Vector2(4, 4) + Vector2(offsets[index]) * 0.5), "native per-axis half movement %d" % (index + 1))
		finish(event)
		expect(event.tile_position == Vector2i(4, 4) + offsets[index] and not event.routes.forcing, "native route endpoint %d" % (index + 1))
	reset_event()
	event.turn(2)
	event.force_move_route(route([c(12)])); finish(event)
	expect(event.tile_position == Vector2i(4, 5) and event.motion.direction == 2, "forward follows current direction")
	reset_event()
	event.turn(2)
	event.force_move_route(route([c(13)]))
	finish(event)
	expect(event.tile_position == Vector2i(4, 3) and event.motion.direction == 2 and not event.direction_fix, "backward step preserves facing and restores direction fix")
	reset_event()
	event.force_move_route(route([c(35), c(3)])); finish(event)
	expect(event.tile_position == Vector2i(5, 4) and event.motion.direction == 2, "fixed facing does not prevent movement")
	reset_event()
	event.force_move_route(route([c(14, [0, 0])]))
	event.advance_motion(0.12)
	expect(event.jumping() and event.motion.jump_height > 0, "zero-offset native jump animates in place")
	finish(event)
	expect(event.tile_position == Vector2i(4, 4), "zero jump lands in place")
	reset_event()
	event.force_move_route(route([c(14, [3, -2])]))
	finish(event)
	expect(event.tile_position == Vector2i(7, 2), "jump crosses intervening terrain")
	for seed_value in range(8):
		seed(seed_value); reset_event()
		event.force_move_route(route([c(9)])); finish(event)
		expect(event.tile_position in [Vector2i(4, 5), Vector2i(3, 4), Vector2i(5, 4), Vector2i(4, 3)], "random step is cardinal")
	player.move_to(8, 2)
	reset_event()
	map.map_data.data.values[5 + 20 * 4] = 385
	event.force_move_route(route([c(10)])); finish(event)
	expect(event.tile_position == Vector2i(4, 3), "approach retries the other axis after primary obstruction")
	map.map_data.data.values[5 + 20 * 4] = 384
	reset_event(); event.force_move_route(route([c(11)])); finish(event)
	expect(event.tile_position == Vector2i(3, 4), "away uses longer axis")
	reset_event()
	map.map_data.data.values[5 + 20 * 4] = 385
	expect(map.can_move_diagonal(Vector2i(4, 4), Vector2i(1, 1), false, 1), "diagonal accepts the other two-leg passable path")
	map.map_data.data.values[4 + 20 * 5] = 385
	expect(not map.can_move_diagonal(Vector2i(4, 4), Vector2i(1, 1), false, 1), "diagonal cannot cut two blocked corners")
	event.turn(8)
	event.force_move_route(route([c(6)]))
	expect(not event.moving() and event.motion.direction == 2, "failed diagonal still applies native facing adjustment")
	event.cancel_move_route()
	expect(map.can_move_diagonal(Vector2i(4, 4), Vector2i(1, 1), true, 1), "through ignores terrain on diagonal")
	expect(not map.can_move_diagonal(Vector2i(0, 0), Vector2i(-1, -1), true, 1), "through still respects map bounds")
	map.map_data.data.values[5 + 20 * 4] = 384
	map.map_data.data.values[4 + 20 * 5] = 384
	map.map_data.data.values[4 + 20 * 4] = 385
	expect(event.jump(0, 0), "native in-place jump works even on a blocked tile")
	event.advance_motion(1)
	map.map_data.data.values[4 + 20 * 4] = 384

func test_turns_and_properties() -> void:
	var expected := {16: 2, 17: 4, 18: 6, 19: 8, 20: 4, 21: 6, 22: 8, 25: 6, 26: 4}
	player.move_to(9, 4)
	for code in expected:
		reset_event(); event.force_move_route(route([c(code)])); finish(event)
		expect(event.motion.direction == expected[code], "native facing command %d" % code)
	for code in [23, 24]:
		reset_event(); event.force_move_route(route([c(code)])); finish(event)
		expect(event.motion.direction in ([4, 6] if code == 23 else [2, 4, 6, 8]), "random facing command %d" % code)
	reset_event()
	event.force_move_route(route([c(27, [8701]), c(29, [6]), c(30, [2]), c(32), c(33), c(35), c(37), c(39), c(42, [123]), c(43, [2]), c(15, [20])]))
	expect(state.switches.get("8701", false) and event.move_speed == 6 and event.routes.move_frequency == 2, "route speed/frequency/switch mutations")
	expect(not event.walk_anime and event.step_anime and event.direction_fix and event.through, "route animation/facing/through toggles ON/OFF")
	expect(event.always_on_top and event.z_index == 1024 and event.opacity == 123 and event.blend_type == 2, "route top/opacity/blend use renderer state")
	event.force_move_route(route([c(28, [8701]), c(31), c(34), c(36), c(38), c(40), c(41, ["@movement_character", 120, 8, 3]), c(44, [{"name": ""}])]))
	finish(event)
	expect(not state.switches.get("8701", false) and event.walk_anime and not event.step_anime and not event.direction_fix and not event.through and not event.always_on_top, "inverse route property toggles restore")
	expect(event._hue == 120 and event.motion.direction == 8 and event.motion.options.idle_pattern == 3 and event.tile_id == 0, "route graphic preserves hue/direction/idle pattern")
	event.turn(6)
	event.set_route_graphic("@movement_character", 0, 8, 3)
	expect(event.motion.direction == 6, "same original graphic direction does not undo native runtime facing")
	var se_name := ""
	for key in data.asset_index():
		if str(key).begins_with("Audio/SE/") and not data.asset_path(str(key)).is_empty(): se_name = str(key).trim_prefix("Audio/SE/"); break
	if not se_name.is_empty():
		event.force_move_route(route([c(44, [{"name": se_name, "volume": 65, "pitch": 110}])]))
		expect(not state.audio._effects.is_empty() and is_equal_approx(state.audio._effects[-1].pitch_scale, 1.1), "route SE uses shared native audio service")
		state.audio.stop("SE")

func test_wait_and_restore() -> void:
	for rate in [30, 40, 60, 120]:
		reset_event(); state.set_event_switch(8702, false)
		event.force_move_route(route([c(15, [20]), c(27, [8702])]))
		for frame in rate - 1: event.advance_motion(1.0 / rate)
		expect(not state.switches.get("8702", false), "route wait does not finish early at %d FPS" % rate)
		event.advance_motion(1.0 / rate)
		expect(state.switches.get("8702", false) and not event.routes.forcing, "route wait20 is one second at %d FPS" % rate)
	reset_event(); map.map_data.data.values[4 + 20 * 5] = 385
	event.force_move_route(route([c(1), c(18)]))
	event.advance_motion(1)
	expect(event.routes.forcing and event.routes.snapshot().index == 0 and not event.moving(), "blocked non-skippable movement retries same command")
	map.map_data.data.values[4 + 20 * 5] = 384
	finish(event)
	expect(event.tile_position == Vector2i(4, 5) and event.motion.direction == 6, "unblocking permits route to continue")
	reset_event(); map.map_data.data.values[4 + 20 * 5] = 385
	event.force_move_route(route([c(1), c(18)], false, true)); finish(event)
	expect(event.tile_position == Vector2i(4, 4) and event.motion.direction == 6, "skippable obstruction advances to next command")
	map.map_data.data.values[4 + 20 * 5] = 384
	reset_event()
	var original := route([c(3), c(1), c(17)], true)
	var immutable := JSON.stringify(original)
	event.routes.configure(3, 6, original)
	event.advance_motion(0.01); event.advance_motion(0.2)
	var saved_index: int = event.routes.snapshot().index
	event.force_move_route(route([c(15, [20]), c(4)]))
	event.force_move_route(route([c(2)]))
	finish(event)
	expect(not event.routes.forcing and event.routes.snapshot().index == saved_index, "replacing forced route retains original autonomous cursor")
	expect(JSON.stringify(original) == immutable, "shared original definition is never mutated")
	event.advance_motion(0.01)
	expect(event.motion.target == event.motion.cell + Vector2i.LEFT or event.motion.direction == 4, "original route resumes after forced replacement")
	reset_event(); event.force_move_route(route([c(15, [1])], true))
	for frame in 30: event.advance_motion(0.1)
	expect(event.routes.forcing and event.routes.repeat_forced(), "repeat option keeps forced ownership")
	event.cancel_move_route()
	expect(not event.routes.forcing, "explicit lifecycle cancellation releases repeat route")

func test_autonomous() -> void:
	reset_event(); event.routes.configure(3, 3, route([c(3)], true))
	event.advance_motion(2.54)
	expect(event.is_idle(), "frequency3 waits 102 native40fps updates")
	event.advance_motion(0.02)
	expect(event.moving(), "frequency3 threshold is time-based")
	finish(event); reset_event()
	event.routes.configure(3, 3, route([c(27, [8705])], true))
	event.advance_motion(2.55)
	expect(event.routes.snapshot().stopped >= 2.55, "repeat end preserves native stopped count for property-only autonomy")
	reset_event()
	event.routes.configure(3, 6, route([c(3)], true)); event.lock()
	event.advance_motion(1)
	expect(event.is_idle(), "foreground lock suspends autonomous movement")
	event.force_move_route(route([c(3)])); finish(event)
	expect(event.tile_position == Vector2i(5, 4), "forced route can move the locked speaking event")
	event.unlock()
	expect(event.motion.direction == 6, "route clearing prelock direction prevents unlock undoing its facing")
	reset_event(); event.routes.configure(1, 6, route([])); seed(100)
	for step in 20: event.advance_motion(0.2)
	expect(event.tile_position != Vector2i(4, 4), "native random autonomous movement actually progresses")
	reset_event(); player.move_to(8, 4); event.routes.configure(2, 6, route([])); seed(80)
	for step in 5: event.advance_motion(0.2)
	expect(event.tile_position.x > 4, "native approach autonomous movement progresses toward player")
	reset_event()
	var same: Node = event
	event.force_move_route(route([c(15, [20])]))
	map.refresh_events()
	expect(map.event_node(1) == same and event.routes.forcing, "same-page refresh preserves route identity and wait")
	map.map_data.events["1"].pages.append({"condition": {"switch1_valid": true, "switch1_id": 8703}, "graphic": {"character_name": "@movement_character"}, "list": [c(0)]})
	map.refresh_events()
	state.set_event_switch(8703, true); map.flush_event_refresh()
	expect(map.event_node(1) == same and not event.routes.forcing and event.routes.move_type == 0, "page change cancels forced route and installs new autonomy")
	map.map_data.events["1"].pages.pop_back(); state.set_event_switch(8703, false); map.refresh_events()
	reset_event()
	event.turn(6)
	map.map_data.events["1"].pages.append({"condition": {"switch1_valid": true, "switch1_id": 8704}, "graphic": {"character_name": "@movement_character", "direction": 2}, "list": [c(0)]})
	map.refresh_events(); state.set_event_switch(8704, true); map.flush_event_refresh()
	expect(event.motion.direction == 6, "same authored facing across pages preserves runtime facing")
	map.map_data.events["1"].pages.pop_back(); state.set_event_switch(8704, false); map.refresh_events()
	reset_event()

func test_commands() -> void:
	player.move_to(14, 10)
	var owner: RefCounted = interpreter.new(); owner.map_runtime = map
	var errors: Array[String] = []
	owner.diagnostic_requested.connect(func(message: String) -> void: errors.append(message))
	owner.start([c(202, [0, 0, 6, 5, 8]), c(0)], 1)
	expect(event.tile_position == Vector2i(6, 5) and event.motion.direction == 8, "202 directly sets current event and facing")
	state.set_event_variable(8711, 7); state.set_event_variable(8712, 6)
	owner.start([c(202, [1, 1, 8711, 8712, 4]), c(0)], 0)
	expect(event.tile_position == Vector2i(7, 6) and event.motion.direction == 4, "202 variable coordinates")
	var other: Node = map.event_node(2)
	var other_position: Vector2i = other.tile_position
	owner.start([c(202, [1, 2, 2, 0, 6]), c(0)], 0)
	expect(event.tile_position == other_position and other.tile_position == Vector2i(7, 6), "202 atomic exchange between events")
	owner.start([c(202, [1, 2, -1, 0, 0]), c(0)], 0)
	expect(event.tile_position == Vector2i(14, 10) and player.tile_position == other_position, "202 exchange with player")
	var before: Vector2i = event.tile_position
	owner.start([c(202, [1, 2, 999, 0, 0]), c(0)], 0)
	expect(event.tile_position == before and not owner.running and errors.back().contains("交换目标"), "missing exchange target is atomic with source diagnostic")
	owner.start([c(202, [1, 0, 100, 1, 0]), c(0)], 0)
	expect(event.tile_position == before, "out-of-map relocation is atomic")
	event.configure_motion({"direction_fix": true}); event.motion.turn(8, true)
	owner.start([c(202, [1, 0, 7, 7, 2]), c(0)], 0)
	expect(event.motion.direction == 8, "202 respects native direction fix")
	event.configure_motion({"direction_fix": false})
	owner.start([c(208, [0]), c(0)], 0)
	expect(player.transparent and not player.visible, "208 hides shared player visual without removing occupancy")
	owner.start([c(208, [1]), c(0)], 0)
	expect(not player.transparent and player.visible, "208 shows player again")
	reset_event(); other.move_to(10, 8)
	state.set_event_variable(8713, 0)
	owner.start([c(209, [1, route([c(15, [10]), c(3)])]), c(209, [2, route([c(15, [20]), c(2)])]), c(210), c(122, [8713, 8713, 0, 0, 1]), c(0)], 0)
	expect(owner.wait_kind() == "routes" and map.has_forced_routes(), "210 observes all forced characters")
	finish(event)
	owner.advance(0)
	expect(int(state.variables.get("8713", 0)) == 0 and owner.running, "finishing first route does not release global wait")
	finish(other); owner.advance(0)
	expect(int(state.variables.get("8713", 0)) == 1 and not owner.running, "last route releases interpreter exactly once")
	reset_event()
	var shared := route([c(3), c(15, [20])])
	owner.start([c(209, [1, shared]), c(509, [c(3)]), c(509, [c(15, [20])]), c(210), c(0)], 0)
	finish(event); owner.advance(0)
	expect(event.tile_position == Vector2i(5, 4) and not owner.running, "509 display continuations do not replay movements")
	reset_event(); owner.start([c(209, [1, shared]), c(509, [c(2)]), c(0)], 0)
	expect(event.tile_position == Vector2i(4, 4) and not event.routes.forcing and not owner.running and errors.back().contains("不匹配"), "mismatched continuation rejects before starting route")
	owner.start([c(509, [c(1)]), c(0)], 0)
	expect(not owner.running and errors.back().contains("紧随209"), "orphan509 has explicit diagnostic")
	reset_event(); owner.start([c(209, [0, route([c(15, [1])], true)]), c(210), c(0)], 1)
	for frame in 30: event.advance_motion(0.1); owner.advance(0.1)
	expect(owner.running and owner.wait_kind() == "routes" and state.diagnostics.any(func(s: String) -> bool: return s.contains("重复强制路线")), "repeat wait warns once and never fabricates completion")
	map.erase_event(1); owner.advance(0)
	expect(not owner.running and not map.has_forced_routes(), "erase cancels route and releases wait without stale character reference")
	map.load_definition(definition(), load("res://runtime/scripts/11_Development/MovementFixture.gd").build().tileset)
	event = map.event_node(1)
	for item in map.event_contexts(): item.node.set_process(false)
	var animation_id: int = data.test_config().definitions.Animations[0].id
	owner.start([c(207, [0, animation_id]), c(0)], 1)
	expect(not map._animations.is_empty() and not owner.running, "207 starts actual current-event animation without an invented wait")
	var animation: Node = map._animations[-1]
	animation.set_process(false)
	map.erase_event(1); animation.advance(0.01)
	expect(animation._ended, "207 animation ends when original target is erased")
	owner.start([c(207, [9999, animation_id]), c(0)], 0)
	expect(not owner.running and errors.back().contains("目标不存在"), "207 missing target is diagnosed")
	owner.start([c(207, [-1, 0]), c(0)], 0)
	expect(not owner.running, "207 animation0 is native no-op")

func test_parallel_routes() -> void:
	var custom := definition()
	custom.events["1"].pages[0].trigger = 4
	custom.events["1"].pages[0].list = [c(209, [0, route([c(15, [10]), c(3)])]), c(210), c(122, [8720, 8720, 1, 0, 1]), c(106, [999]), c(0)]
	custom.events["2"].pages[0].trigger = 4
	custom.events["2"].pages[0].list = [c(209, [0, route([c(15, [20]), c(2)])]), c(210), c(122, [8721, 8721, 1, 0, 1]), c(106, [999]), c(0)]
	map.load_definition(custom, load("res://runtime/scripts/11_Development/MovementFixture.gd").build().tileset)
	for item in map.event_contexts(): item.node.set_process(false)
	var scheduler: RefCounted = load("res://runtime/scripts/02_Event/EventScheduler.gd").new()
	scheduler.configure(map, [])
	scheduler.advance(0)
	expect(map.has_forced_routes() and scheduler.parallels.size() == 2, "parallel map events own independent character routes")
	var first: Node = map.event_node(1)
	var second: Node = map.event_node(2)
	for frame in 45:
		first.advance_motion(1.0 / 60); second.advance_motion(1.0 / 60); scheduler.advance(1.0 / 60)
	expect(first.tile_position == Vector2i(5, 4) and int(state.variables.get("8720", 0)) == 0, "each210 still waits for the other parallel route")
	for frame in 40:
		first.advance_motion(1.0 / 60); second.advance_motion(1.0 / 60); scheduler.advance(1.0 / 60)
	expect(second.tile_position == Vector2i(9, 8) and int(state.variables.get("8720", 0)) == 1 and int(state.variables.get("8721", 0)) == 1, "both parallel interpreters resume once after global route completion")
	scheduler.dispose()
	custom.events["1"].pages[0].trigger = 2
	custom.events["1"].pages[0].move_type = 3
	custom.events["1"].pages[0].move_route = route([c(3)], true)
	custom.events["1"].pages[0].list = [c(122, [8722, 8722, 1, 0, 1]), c(0)]
	custom.events["2"].pages[0].trigger = 0
	map.load_definition(custom, load("res://runtime/scripts/11_Development/MovementFixture.gd").build().tileset)
	for item in map.event_contexts(): item.node.set_process(false)
	player.move_to(5, 4)
	var touched: Array[int] = []
	var listener := func(_commands: Array, id: int) -> void: touched.append(id)
	map.event_requested.connect(listener)
	map.event_node(1)._process(0.01)
	expect(touched == [1] and map.event_node(1).is_idle(), "autonomous route contact with player triggers event without manually moving it")
	map.event_requested.disconnect(listener)

func test_game() -> void:
	state.begin_new_game(data.system()); state.resume_from_save = true
	var game: Node2D = load("res://scenes/03_Map/Game.tscn").instantiate()
	root.add_child(game); current_scene = game
	await frames(3)
	game.reset_event_execution()
	var tileset: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build().tileset
	game._map.load_definition(definition(), tileset)
	game._scheduler.cancel_all(); game._events_enabled = true
	game.set_process(false); game._player.set_process(false)
	for item in game._map.event_contexts(): item.node.set_process(false)
	game._player.move_to(14, 10); game._sync_event_input()
	var target: Node = game._map.event_node(1)
	expect(game._menus.open_menu(), "ordinary idle map permits menu")
	target.force_move_route(route([c(15, [20]), c(3)]))
	var remaining: float = target.routes.snapshot().waiting
	await frames(3)
	expect(target.routes.snapshot().waiting == remaining, "paused tree does not consume route wait")
	game._menus.close_menu()
	expect(game.event_save_reason().contains("测试地图"), "detached fixture map is protected without banning menu")
	finish(target)
	expect(game.event_save_reason().contains("测试地图"), "fixture remains outside production save data after route completion")
	game._player.routes.configure(0, 3, route([])); game._player.move_to(14, 10)
	var steps: int = state.steps
	game._player.force_move_route(route([c(2)])); finish(game._player)
	expect(state.steps == steps and game._player.tile_position == Vector2i(13, 10), "forced player movement does not count native party steps")
	game._player.move_straight(2); game._player.advance_motion(0.2)
	expect(state.steps == steps + 1, "ordinary player walk still counts steps once")
	var destination := definition()
	data._cache["res://data/maps/Map992.json"] = destination
	state.set_event_variable(8714, 0)
	game._scheduler.start_main([c(201, [0, 992, 3, 3, 8, 1]), c(122, [8714, 8714, 0, 0, 1]), c(0)], 1)
	expect(game._interpreter.wait_kind() == "transfer" and int(state.variables.get("8714", 0)) == 0, "201 waits for actual deferred transfer completion")
	await frames(2); game._process(0)
	expect(state.map_id == 992 and game._player.tile_position == Vector2i(3, 3) and state.player_direction == 8 and int(state.variables.get("8714", 0)) == 1, "201 direct destination/direction resumes old foreground list")
	var generation: int = game._map.generation
	var same: Node = game._map.event_node(1)
	game._map.erase_event(2)
	state.set_event_variable(8715, 992); state.set_event_variable(8716, 5); state.set_event_variable(8717, 6)
	game._scheduler.start_main([c(201, [1, 8715, 8716, 8717, 0, 1]), c(0)], 0)
	await frames(2); game._process(0)
	expect(game._map.generation == generation and game._map.event_node(1) == same and game._map.event_node(2) == null, "same-map transfer preserves pages/routes/deletion and generation")
	expect(game._player.tile_position == Vector2i(5, 6) and state.player_direction == 8, "201 variable coordinates and preserve-direction0")
	game._scheduler.start_main([c(201, [0, 992, 100, 0, 2, 1]), c(0)], 0)
	expect(game._map.generation == generation and game._player.tile_position == Vector2i(5, 6), "invalid201 is atomic")
	game._event_ui.cancel_all(); game._scheduler.cancel_all(); game._dialogue.dismiss()
	var first: Dictionary = game.begin_event_transfer(992, 1, 1, 2, false)
	game.cancel_event_transfer()
	await frames(2)
	expect(not game.event_transfer_status(first.id).ok and game._player.tile_position == Vector2i(5, 6), "cancelled deferred transfer never applies destination")
	var completed: Dictionary = game.begin_event_transfer(992, 2, 2, 2, false)
	await frames(2)
	var following: Dictionary = game.begin_event_transfer(992, 3, 3, 2, false)
	expect(game.event_transfer_status(completed.id).ok and not game.event_transfer_status(completed.id).pending, "starting a subsequent transfer preserves earlier completion identity")
	game.cancel_event_transfer(); await frames(2)
	expect(not game.event_transfer_status(following.id).ok, "independent following transfer cancellation status")
	game._player.force_move_route(route([c(39), c(41, ["@movement_character", 90, 4, 2])]))
	expect(game._player.always_on_top and game._player.routes.has_runtime_state(), "completed player route retains unsaved special display state")
	state.begin_new_game(data.system())
	expect(not game._player.always_on_top and not game._player.routes.has_runtime_state(), "new-game reset clears old route cursor/frequency/top/history")
	var actor: RefCounted = state.actor(int(state.party[0])) if not state.party.is_empty() else null
	expect(actor == null or game._player._name == actor.character_name, "new-game reset restores leader graphic after route41")
	data._cache.erase("res://data/maps/Map992.json")
	game.queue_free(); current_scene = null
	await frames(3)

func frames(count: int) -> void:
	for index in count: await process_frame

## 职责：回归验证：执行原推箱子事件链并验证路线、通行和结果。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func test_original(data: Script, original: Dictionary) -> void
##     参数 data（Script；必填）：待读取、转换或恢复的数据。
##     参数 original（Dictionary；必填）：修改前的原始记录或文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func test_classification() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
var _checks = 0
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok: _failures.append(message)

func run() -> void:
	var data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	var state: Node = root.get_node("RuntimeState")
	state.begin_new_game(data.system())
	var original: Dictionary = data.map(1)
	if original.get("events", {}).has("17"):
		var definition: Dictionary = original.events["17"]
		if definition.pages[0].list.any(func(c: Variant) -> bool: return int(c.get("code", 0)) == 209):
			await test_original(data, original)
	await test_classification()
	for failure in _failures: printerr("FAIL: ", failure)
	print("PUSH BOX TESTS: ", "PASSED" if _failures.is_empty() else "FAILED", " / ", _checks, " checks")
	quit(0 if _failures.is_empty() else 1)

func test_original(data: Script, original: Dictionary) -> void:
	var map = load("res://runtime/scripts/03_Map/MapRuntime.gd").new()
	root.add_child(map)
	map.load_definition(original, data.record("Tilesets", int(original.tileset_id)))
	map.set_process(false)
	for context in map.event_contexts(): context.node.set_process(false)
	var player = load("res://runtime/scripts/03_Map/PlayerController.gd").new()
	map.ensure_character_layer().add_child(player)
	player.configure(map); player.set_process(false); map.player_character = player
	var box = map.event_node(17)
	var start: Vector2i = box.tile_position
	var owner = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	owner.map_runtime = map
	var errors: Array[String] = []
	owner.diagnostic_requested.connect(func(message: String) -> void: errors.append(message))
	map.event_requested.connect(func(commands: Array, id: int) -> void: owner.start(commands, id))
	expect(box.tile_id == 582 and map.tile_priority(582) == 0, "original box uses priority-zero tile graphic")
	expect(box.front_interaction(), "solid original box triggers from adjacent cell")
	for direction in [8, 2]:
		box.move_to(start.x, start.y)
		var delta: Vector2i = {8: Vector2i.UP, 2: Vector2i.DOWN}[direction]
		player.move_to(start.x - delta.x, start.y - delta.y)
		expect(not player.move_straight(direction), "player is blocked by box before touch")
		expect(map.trigger_player_touch(start, true), "blocked-player touch starts original event17")
		# If the trigger fails, still exercise the unmodified original route data
		# so the failure is attributed to triggering rather than 209 editing.
		if not owner.running: owner.start(box.commands, 17)
		for i in 40:
			box.advance_motion(0.05)
			owner.advance(0.05)
		expect(box.tile_position == start + delta, "original 111/209/509/210 pushes box by one cell")
		expect(not owner.running and errors.is_empty(), "original box reaches public-event return without diagnostics")
		expect(player.tile_position == start - delta, "pushing does not teleport player into box")
	map.queue_free(); await process_frame

func test_classification() -> void:
	var resources: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build()
	var tileset: Dictionary = resources.tileset.duplicate(true)
	tileset.passages.values[385] = 15
	tileset.priorities.values[385] = 0
	var values: Array = []; values.resize(25); values.fill(384)
	var page = {"condition": {}, "graphic": {"tile_id": 385, "character_name": ""}, "list": [{"code": 108, "parameters": ["touch"], "indent": 0}, {"code": 0, "parameters": [], "indent": 0}], "trigger": 1}
	var map = load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); root.add_child(map)
	map.load_definition({"width": 5, "height": 5, "data": {"x_size": 5, "y_size": 5, "z_size": 1, "values": values}, "events": {"1": {"x": 2, "y": 2, "pages": [page]}}}, tileset)
	var event = map.event_node(1)
	expect(event.front_interaction(), "priority-zero solid tile is front trigger")
	event.through = true
	expect(not event.front_interaction(), "through tile on passable ground is overlap trigger")
	event.through = false
	map.tileset.passages.values[385] = 0; map.tileset.priorities.values[385] = 1
	expect(not event.front_interaction(), "display priority does not turn passable tile into front trigger")
	map.tileset.passages.values[385] = 1
	expect(not event.front_interaction(), "partially directional passage follows native overlap test")
	map.queue_free(); await process_frame

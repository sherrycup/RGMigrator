## 职责：回归验证：验证菜单技能使用、目标选择与原动画播放。
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
##   func test_animations(fixture: Dictionary) -> void
##     参数 fixture（Dictionary；必填）：独立测试夹具或其数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func test_menu() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func make_fixture() -> Dictionary
##     用途：构建与正式工程隔离的测试现场。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func command(code: int, parameters: Array = [], indent: int = 0) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 parameters（Array；默认值 []）：按对应接口或事件指令约定排列的参数。
##     参数 indent（int；默认值 0）：事件指令的结构缩进层级。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func expect(condition: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 condition（bool；必填）：是否创建须返回布尔值的脚本条件模板。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
var data: Script
var state: Node
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	state = root.get_node("RuntimeState")
	var setup: Dictionary = data.test_config()
	state.begin_new_game(data.system())
	expect(setup.schema_version == 3 and setup.definitions.Skills.size() == 3, "new exports prepare three skills")
	for actor_id in state.party:
		for skill_id in setup.learn_skills:
			expect(state.has_skill(int(actor_id), int(skill_id)), "test skill granted per party actor")
	var original := JSON.stringify(data.database("Skills"))
	state.begin_new_game(data.system(), {"enabled": false})
	expect(not data.record("Skills", int(setup.learn_skills[0])).has("name"), "disabled overlay removes test definitions")
	expect(JSON.stringify(data.database("Skills")) == original, "overlay leaves source skills unchanged")
	var fixture := make_fixture()
	data._cache.clear()
	for database in fixture:
		data._cache["res://data/database/%s.json" % database] = fixture[database]
	var before := JSON.stringify(fixture)
	state.begin_new_game({"party_members": [1.0]}, {"enabled": false})
	var actor: RefCounted = state.actor(1)
	expect(actor.get_skill_ids() == [1, 3], "initial class learnings respect level, sort and deduplicate")
	expect(not actor.has_skill(2), "higher-level skill not initialized early")
	expect(actor.learn_skill(2).ok and actor.get_skill_ids() == [1, 2, 3], "learn inserts sorted ID")
	expect(not actor.learn_skill(2).changed, "duplicate learn is a no-op")
	var copy: Array = actor.get_skill_ids()
	copy.clear()
	expect(actor.get_skill_ids().size() == 3, "query returns independent array")
	expect(actor.forget_skill(2).changed and not actor.forget_skill(2).changed, "forget and repeated forget")
	expect(not actor.learn_skill(999).ok and not actor.learn_skill(0).ok and not actor.forget_skill(-1).ok, "bad references rejected")
	state.change_party(1, false)
	expect(state.change_skill(1, 2, true).ok, "off-party actor can learn")
	state.change_party(1, true, false)
	expect(state.has_skill(1, 2), "join without initialization keeps skills")
	state.change_party(1, false)
	state.change_party(1, true, true)
	expect(not state.has_skill(1, 2), "initialized join restores initial learnings")
	var interpreter: RefCounted = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	interpreter.start([command(318, [1, 0, 2]), command(111, [4, 1, 2, 2]), command(121, [40, 40, 0], 1), command(411), command(121, [40, 40, 1], 1), command(412)], 5, 2)
	expect(state.has_skill(1, 2) and state.switches.get("40", false), "318 + learned conditional true branch")
	interpreter.start([command(318, [1, 1, 2]), command(111, [4, 1, 2, 2]), command(121, [40, 40, 0], 1), command(411), command(121, [40, 40, 1], 1), command(412)], 5, 2)
	expect(not state.has_skill(1, 2) and not state.switches.get("40", true), "forget + learned conditional else branch")
	var diagnostic: Array[String] = []
	interpreter.diagnostic_requested.connect(func(message: String) -> void: diagnostic.append(message))
	interpreter.start([command(318, [1, 0, 999]), command(121, [41, 41, 0])], 5, 2)
	expect(not diagnostic.is_empty() and diagnostic.back().contains("Skills[999]") and diagnostic.back().contains("事件 5") and not state.switches.has("41"), "invalid event stops at precise source location")
	interpreter.start([command(111, [4, 1, 2, 999]), command(411), command(121, [42, 42, 0], 1), command(412)], 5)
	expect(not state.switches.has("42"), "invalid conditional does not run else")
	var resources: Script = load("res://runtime/scripts/04_UI_Common/UIResources.gd")
	data._cache["res://data/system.json"] = {"words": {"str": "攻击", "dex": "防御", "int": "魔防"}}
	for entry in [["str", "力量"], ["dex", "灵巧"], ["int", "魔力"], ["atk", "攻击力"], ["pdef", "物理防御"], ["mdef", "魔法防御"]]:
		expect(resources.word(entry[0], "wrong") == entry[1], "standard parameter label " + entry[0])
	expect(JSON.stringify(fixture) == before, "all actor and interpreter operations keep database immutable")
	await test_animations(fixture)
	await test_menu()
	await create_timer(0.2).timeout
	for failure in failures:
		printerr("FAIL: ", failure)
	print("SKILL ANIMATION TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func test_animations(fixture: Dictionary) -> void:
	var animation_data: Script = load("res://runtime/scripts/09_Effects/RmxpAnimationData.gd")
	var player_script: Script = load("res://runtime/scripts/09_Effects/RmxpAnimationPlayer.gd")
	expect(animation_data.resolve(0).empty, "zero animation is a successful no-op")
	expect(not animation_data.resolve(999).ok, "invalid nonzero animation diagnosed")
	var malformed: Dictionary = fixture.Animations[1].duplicate(true)
	malformed.frames[0].cell_data.values = [0]
	expect(not animation_data.compile(malformed).ok, "truncated cell table rejected")
	var host := Node2D.new()
	root.add_child(host)
	var target := ColorRect.new()
	target.position = Vector2(100, 120)
	target.size = Vector2(40, 80)
	host.add_child(target)
	var provider := func() -> CanvasItem: return target
	var result: Dictionary = player_script.play(host, 1, provider)
	expect(result.ok, "valid independent animation starts")
	if not result.ok:
		host.queue_free()
		return
	var player: Node2D = result.player
	player.set_process(false)
	expect(player.frame_index == 0 and player.position == Vector2(120, 160), "first frame and target center anchor")
	var cell: Sprite2D = player._cells[0]
	expect(cell.region_rect == Rect2(192, 0, 192, 192) and cell.flip_h and cell.scale == Vector2.ONE * 0.5 and cell.rotation_degrees == -45.0, "XP cell region, mirror, scale, rotation")
	expect(is_equal_approx(cell.modulate.a, 128.0 / 255), "cell opacity")
	expect(target.material != null, "target flash installed")
	var other: Dictionary = player_script.play(host, 1, provider)
	other.player.set_process(false)
	player.stop()
	expect(target.material != null, "stopping one concurrent flash preserves another")
	other.player.stop()
	expect(target.material == null, "last flash restores target material")
	await process_frame
	result = player_script.play(host, 1, provider, false)
	player = result.player
	player.set_process(false)
	var timings: Array = []
	player.timing_reached.connect(func(frame: int, _timing: Dictionary) -> void: timings.append(frame))
	player.advance(0.05)
	expect(player.frame_index == 1 and timings == [1], "20fps progression and miss timing condition")
	expect(player._screen_flash.visible, "screen flash visible")
	target.position.x += 20
	player.advance(0.049)
	expect(player.frame_index == 1 and player.position.x == 140, "fractional delta and moving target")
	player.advance(0.001)
	expect(player.frame_index == 2 and not timings.has(2), "hit-only timing skipped for miss")
	player.advance(2)
	expect(player._ended, "animation finishes without frame-rate dependency")
	await process_frame
	var map_script: Script = load("res://runtime/scripts/03_Map/MapRuntime.gd")
	var map: Node = map_script.new()
	host.add_child(map)
	var character: Node2D = load("res://runtime/scripts/03_Map/PlayerController.gd").new()
	host.add_child(character)
	character.set_process(false)
	map.player_character = character
	var event_node: Node2D = load("res://runtime/scripts/03_Map/MapEvent.gd").new()
	event_node.event_id = 7
	map.add_child(event_node)
	map._event_nodes.append(event_node)
	expect(map.animation_target(-1) == character and map.animation_target(0, 7) == event_node and map.animation_target(7) == event_node, "207 player/current event/specified event resolution")
	var interpreter: RefCounted = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	interpreter.map_runtime = map
	interpreter.start([command(207, [-1, 1]), command(121, [50, 50, 0])], 7)
	expect(map._animations.size() == 1 and state.switches.get("50", false), "207 starts nonblocking animation then continues")
	var first_instance: Node = map._animations[0]
	first_instance.set_process(false)
	first_instance.advance(0.05)
	interpreter.start([command(207, [7, 1]), command(207, [7, 2]), command(0, [])], 7)
	expect(map._animations.size() == 3, "two consecutive 207 commands on the same event add independent instances")
	var second_instance: Node = map._animations[1]
	var third_instance: Node = map._animations[2]
	second_instance.set_process(false)
	third_instance.set_process(false)
	second_instance.advance(0.05)
	expect(second_instance != third_instance and second_instance.frame_index == 1 and third_instance.frame_index == 0 and not second_instance._ended, "later same-target animation cannot overwrite earlier progress")
	expect(second_instance._data.id == 1 and third_instance._data.id == 2, "same event simultaneously retains two different animation IDs")
	expect(first_instance.frame_index == 1 and not first_instance._ended, "different-target animations also remain active")
	third_instance.stop()
	expect(not second_instance._ended and not first_instance._ended, "stopping newest 207 instance does not stop prior animations")
	var hp: int = state.actor(1).hp
	var sp: int = state.actor(1).sp
	expect(hp == state.actor(1).snapshot().parameters.maxhp and sp == state.actor(1).snapshot().parameters.maxsp, "playing animation never applies skill effects or cost")
	first_instance.advance(2)
	second_instance.advance(2)
	await process_frame
	await process_frame
	interpreter.start([command(207, [7, 2])], 7)
	expect(map._animations.size() == 1 and is_instance_valid(map._animations[0]), "207 prunes naturally expired players before starting another")
	map._animations[0].set_process(false)
	map._animations[0].advance(2)
	await process_frame
	await process_frame
	var lab: Control = load("res://runtime/scripts/11_Development/AnimationLab.gd").new()
	root.add_child(lab)
	await process_frame
	var lab_first: Dictionary = lab.play_at(0, 1)
	var lab_second: Dictionary = lab.play_at(0, 2)
	expect(lab_first.ok and lab_second.ok and lab._instances.size() == 2, "original animation viewer stacks different IDs at one target")
	lab_first.player.set_process(false)
	lab_second.player.set_process(false)
	lab_first.player.advance(2)
	lab_second.player.advance(2)
	await process_frame
	await process_frame
	lab._process(0)
	expect(lab._instances.is_empty() and lab._count.text.contains("：0"), "viewer cleans naturally expired instances and updates live counter")
	var lab_again: Dictionary = lab.play_at(1, 1)
	expect(lab_again.ok and lab._instances.size() == 1, "viewer can play again after all previous players are freed")
	lab.stop_all()
	lab.queue_free()
	host.queue_free()
	await process_frame
	expect(player_script._flashes.is_empty(), "scene disposal clears flash ownership")


func test_menu() -> void:
	state.begin_new_game({"party_members": [1]}, {"enabled": false})
	var menu: Control = load("res://scenes/08_Menu/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.navigate(-1)
	menu.navigate(-1)
	menu.activate()
	expect(menu.page == "actors" and menu.command_index == 1, "skill command selects actor")
	menu.activate()
	expect(menu.page == "skills" and menu._commerce._ids == [1, 3], "read-only learned list")
	var before: Array = state.actor(1).get_skill_ids()
	var sp: int = state.actor(1).sp
	menu.activate()
	expect(state.actor(1).get_skill_ids() == before and state.actor(1).sp == sp, "confirm in list cannot cast or spend SP")
	state.change_skill(1, 2, true)
	await process_frame
	await process_frame
	expect(menu._commerce._ids == [1, 2, 3], "list refreshes after learned state notification")
	menu.handle_back()
	expect(menu.page == "actors", "back from list restores actor selection")
	menu.handle_back()
	expect(menu.page == "menu" and menu.command_index == 1, "back restores skill command")
	menu.queue_free()
	await process_frame
	state.begin_new_game({"party_members": []}, {"enabled": false})
	menu = load("res://scenes/08_Menu/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.navigate(-1)
	menu.navigate(-1)
	menu.activate()
	expect(menu.page == "menu", "empty party disables skill entry")
	menu.queue_free()
	await process_frame


func make_fixture() -> Dictionary:
	var values: Array = []
	for level in 100:
		values.append_array([120, 30, 20, 10, 15, 18])
	var skill := {"id": 1, "name": "只读技能", "description": "测试", "icon_name": "@test_sp", "animation1_id": 1, "animation2_id": 0,
		"sp_cost": 999, "power": 999, "common_event_id": 99, "plus_state_set": [1]}
	var skills: Array = [null]
	for id in range(1, 4):
		var entry := skill.duplicate(true)
		entry.id = id
		skills.append(entry)
	var frames: Array = []
	for index in 4:
		frames.append({"cell_max": 1, "cell_data": {"x_size": 1, "y_size": 8, "values": [1, 0, 0, 50, 45, 1, 128, index % 3]}})
	var timings: Array = []
	for index in 3:
		timings.append({"frame": index, "condition": [0, 2, 1][index], "se": {}, "flash_scope": index + 1, "flash_duration": 1,
			"flash_color": {"red": 255, "green": 100, "blue": 80, "alpha": 128}})
	var original_animation := {"id": 1, "animation_name": "@test_animation", "position": 1, "animation_hue": 120, "frame_max": 4, "frames": frames, "timings": timings}
	var other_animation := original_animation.duplicate(true)
	other_animation.id = 2
	other_animation.animation_hue = 240
	return {"Actors": [null, {"id": 1, "name": "测试角色", "class_id": 1, "initial_level": 2, "final_level": 99,
		"parameters": {"x_size": 6, "y_size": 100, "values": values}}],
		"Classes": [null, {"id": 1, "name": "职业", "learnings": [{"level": 1, "skill_id": 3}, {"level": 2, "skill_id": 1}, {"level": 2, "skill_id": 1}, {"level": 3, "skill_id": 2}]}],
		"Skills": skills, "Weapons": [null], "Armors": [null], "States": [null],
		"Animations": [null, original_animation, other_animation]}


func command(code: int, parameters: Array = [], indent: int = 0) -> Dictionary:
	return {"code": code, "parameters": parameters, "indent": indent}


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

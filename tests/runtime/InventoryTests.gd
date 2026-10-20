## 职责：回归验证：验证背包增减、装备、物品目标和公共事件预约。
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
##   func run_suite() -> void
##     用途：执行本脚本组织的回归检查。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func reset() -> void
##     用途：重置本服务持有的状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_items() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_equipment() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_keyboard() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func make_fixture() -> Dictionary
##     用途：构建与正式工程隔离的测试现场。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func frames(count: int) -> void
##     用途：让测试现场推进指定帧数。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func press(key: Key) -> void
##     用途：模拟一次按键输入。
##     参数 key（Key；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(condition: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 condition（bool；必填）：是否创建须返回布尔值的脚本条件模板。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree

var data: Script
var state: Node
var fixture: Dictionary
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	create_timer(45.0).timeout.connect(func() -> void: printerr("FAIL: inventory timeout"); quit(1))
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	state = root.get_node("RuntimeState")
	# Exercise the actual exported configuration first, without changing files.
	var setup: Dictionary = data.test_config()
	state.begin_new_game(data.system())
	expect(state.testing_enabled and setup.stock.size() == 9, "export defaults to nine test supply definitions")
	for entry in setup.stock:
		var key := "%s:%d" % [entry.kind, entry.id]
		expect(state.inventory.get(key) == entry.quantity, "new game prepares " + key)
		var database: String = {"item": "Items", "weapon": "Weapons", "armor": "Armors"}[entry.kind]
		expect(data.source_record(database, int(entry.id)).is_empty(), "test ID cannot overwrite source " + key)
	for view in state.party_snapshots():
		expect(view.hp == maxi(1, int(view.parameters.maxhp * 0.5)) and view.sp == int(view.parameters.maxsp * 0.5), "source party starts at half HP/SP for test")
	if not state.party.is_empty():
		var actor_id := int(state.party[0])
		var hp: int = state.actor(actor_id).hp
		expect(state.use_item(int(setup.stock[0].id), actor_id).ok and state.actor(actor_id).hp > hp, "real JSON party ID accepts supplied potion")
		expect(state.equip(actor_id, 0, int(setup.stock[3].id)).ok, "real JSON party ID equips test weapon")
	state.inventory.clear()
	state.begin_new_game(data.system())
	expect(state.inventory.size() == 9, "new game resets rather than stacking supplies")
	var changed: Dictionary = setup.duplicate(true)
	changed.stock[0].quantity = 7
	state.begin_new_game(data.system(), changed)
	expect(state.inventory["item:%d" % int(changed.stock[0].id)] == 7, "editable test quantity")
	state.begin_new_game(data.system(), {"enabled": false})
	expect(not state.testing_enabled and state.inventory.is_empty(), "disabled config preserves original empty inventory")
	expect(data.record("Items", int(setup.stock[0].id)).is_empty(), "disabled overlay cannot leak test records")
	for view in state.party_snapshots():
		expect(view.hp == view.parameters.maxhp and view.sp == view.parameters.maxsp, "disabled test mode initializes full HP/SP")
	# Independent standard rules fixture, not either magic-tower project's formulas.
	fixture = make_fixture()
	for database in fixture:
		data._cache["res://data/database/%s.json" % database] = fixture[database]
	var before := JSON.stringify(fixture)
	test_items()
	test_equipment()
	expect(JSON.stringify(fixture) == before, "item/equipment use and previews leave database immutable")
	var collision := {"enabled": true, "definitions": {"Items": [{"id": 1, "name": "collision"}]}, "stock": []}
	state.begin_new_game({"party_members": [1]}, collision)
	expect(not state.testing_enabled and not state.diagnostics.is_empty() and data.record("Items", 1).name == "恢复药", "conflicting test IDs are rejected with diagnostic")
	state.begin_new_game({"party_members": [1]}, {"enabled": "false"})
	expect(not state.testing_enabled, "invalid enabled type cannot enable injection")
	state.begin_new_game({"party_members": []}, setup)
	expect(state.party_snapshots().is_empty() and not state.use_item(int(setup.stock[2].id), 1).ok, "empty party rejects all-target items safely")
	await test_keyboard()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("INVENTORY TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func reset() -> void:
	state.begin_new_game({"party_members": [1.0, 2.0]}, {"enabled": false})
	state.inventory = {"item:1": 10, "item:2": 10, "item:3": 1, "weapon:2": 2, "weapon:3": 1, "armor:1": 1, "armor:2": 1}


func test_items() -> void:
	reset()
	var actor: RefCounted = state.actor(1)
	expect(not state.use_item(1, 1).ok and state.inventory["item:1"] == 10, "full HP/SP does not consume")
	actor.hp = 20
	actor.sp = 0
	expect(state.use_item(1, 1).ok and actor.hp == 60 and actor.sp == 10 and state.inventory["item:1"] == 9, "flat + rate recovery floors then applies, consumes one")
	actor.hp = 119
	actor.sp = 39
	state.use_item(1, 1)
	expect(actor.hp == 120 and actor.sp == 40, "recovery clamps to max")
	actor.hp = 30
	state.actor(2).hp = 40
	var result: Dictionary = state.use_item(2, 1)
	expect(result.ok and result.targets == 2 and actor.hp == 60 and state.actor(2).hp == 70 and state.inventory["item:2"] == 9, "all-target restores both and consumes once")
	actor.hp = 0
	expect(not state.use_item(1, 1).ok and actor.hp == 0, "living-target item does not revive")
	actor.hp = 1
	state.use_item(3, 1)
	expect(state.inventory["item:3"] == 1 and actor.hp == 11, "nonconsumable recovery leaves count")
	state.inventory["item:1"] = 0
	expect(not state.use_item(1, 1).ok and actor.hp == 11, "zero count fails without mutation")
	state.inventory["item:1"] = 10
	expect(not state.use_item(1, 999).ok, "out-of-party target rejected")
	for id in range(4, fixture.Items.size()):
		state.inventory["item:%d" % id] = 1
		var hp: int = actor.hp
		expect(not state.use_item(id, 1).ok and state.inventory["item:%d" % id] == 1 and actor.hp == hp, "unsupported item rejected atomically #%d" % id)
	state.party.append(999)
	var hp: int = actor.hp
	expect(not state.use_item(2, 1).ok and actor.hp == hp and state.inventory["item:2"] == 9, "invalid all-target member cancels entire transaction")
	state.inventory["item:999"] = 1
	expect(state.inventory_entries().filter(func(e: Dictionary) -> bool: return e.id == 999 and e.missing).size() == 1, "missing inventory reference is browsable")


func test_equipment() -> void:
	reset()
	var actor: RefCounted = state.actor(1)
	var before := JSON.stringify([state.inventory, actor.snapshot()])
	var preview: Dictionary = state.equip_preview(1, 0, 2)
	expect(preview.ok and preview.before.atk == 10 and preview.after.atk == 25, "equipment preview predicts changed attack")
	expect(JSON.stringify([state.inventory, actor.snapshot()]) == before, "preview never mutates inventory or character")
	expect(state.equip(1, 0, 2).ok and actor.equipment[0] == 2 and actor.snapshot().parameters.atk == 25, "equip commits same result as preview")
	expect(state.inventory["weapon:2"] == 1 and state.inventory["weapon:1"] == 1, "swap consumes new gear and returns old")
	expect(state.equip(1, 0, 0).ok and actor.equipment[0] == 0 and state.inventory["weapon:2"] == 2, "unequip returns gear")
	expect(not state.equip(1, 0, 3).ok, "class restriction enforced")
	expect(not state.equip(1, 1, 2).ok, "armor type restriction enforced")
	expect(not state.equip(2, 0, 2).ok and not state.equip(2, 0, 0).ok, "fixed slots block both changing and removal")
	expect(not state.equip(1, 5, 1).ok and not state.equip(999, 0, 1).ok, "invalid actor and slot safe")
	state.inventory["weapon:1"] = 0
	expect(not state.equip(1, 0, 1).ok, "cannot equip absent inventory")
	state.equip(1, 0, 2)
	state.inventory["weapon:2"] = 99
	expect(not state.equip(1, 0, 0).ok and actor.equipment[0] == 2, "full return stack cannot destroy equipped item")
	actor.hp = 120
	expect(state.equip(1, 1, 1).ok and actor.snapshot().parameters.maxhp == 60 and actor.hp == 60, "automatic state adjusts max HP and clamps current HP")
	expect(state.equip(1, 1, 0).ok and actor.snapshot().parameters.maxhp == 120 and actor.hp == 60, "removing automatic state restores max but never heals")
	actor.state_ids.append(1)
	state.equip(1, 1, 1)
	expect(actor.snapshot().parameters.maxhp == 60, "automatic and manual state are deduplicated")
	state.equip(1, 1, 0)
	expect(actor.snapshot().parameters.maxhp == 60, "removing gear does not erase independent manual state")
	state.inventory["weapon:999"] = 1
	expect(not state.equip(1, 0, 999).ok, "missing new equipment reference rejects")


func test_keyboard() -> void:
	# Real Title -> Map; standard fixture overrides remain process-only.
	var title: Node = load("res://scenes/05_Title/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title.call("_on_new_game")
	await frames(4)
	var game: Node = current_scene
	var dialogue: Node = game.get("_dialogue")
	if dialogue.is_open():
		for child in dialogue.get("_content").get_children():
			if child is Button and child.text == "关闭":
				child.emit_signal("pressed")
	reset()
	state.actor(1).hp = 20
	var map_identity: int = game.get("_map").get_instance_id()
	var position := Vector2i(state.player_x, state.player_y)
	state.switches["12"] = true
	state.variables["8"] = 27
	await frames(2)
	await press(KEY_ESCAPE)
	var coordinator: Node = game.get("_menus")
	var menu: Control = coordinator.get("menu")
	expect(menu != null, "keyboard opens menu")
	if menu == null:
		return
	for _i in 3: await press(KEY_UP)
	await press(KEY_ENTER)
	expect(menu.page == "inventory", "item command opens inventory")
	await press(KEY_Z)
	expect(menu._commerce.page == "target", "item opens target selection")
	await press(KEY_SPACE)
	expect(state.actor(1).hp == 60 and state.inventory["item:1"] == 9, "keyboard item use commits")
	await press(KEY_X)
	expect(menu._commerce.page == "list" and menu._commerce.list_index == 0, "target back retains inventory selection")
	await press(KEY_X)
	expect(menu.page == "menu" and menu.command_index == 0, "inventory back retains menu selection")
	await press(KEY_DOWN)
	await press(KEY_DOWN)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	expect(menu.page == "equipment" and menu._commerce.page == "slots", "equipment selects actor then slot")
	await press(KEY_ENTER)
	await press(KEY_DOWN)
	expect(menu._commerce.page == "candidates" and state.actor(1).equipment[0] == 1, "highlight candidate previews only")
	await press(KEY_X)
	expect(menu._commerce.page == "slots" and state.actor(1).equipment[0] == 1, "cancel preview leaves gear unchanged")
	await press(KEY_ENTER)
	await press(KEY_DOWN)
	await press(KEY_ENTER)
	expect(state.actor(1).equipment[0] == 2 and menu._commerce.page == "slots", "confirm exchanges gear")
	await press(KEY_X)
	expect(menu.page == "actors" and menu.actor_index == 0, "equipment returns to same actor")
	await press(KEY_X)
	await press(KEY_DOWN)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	expect(menu.page == "status" and menu._views[0].parameters.atk == 25, "status reflects equipment transaction")
	await press(KEY_X)
	await press(KEY_X)
	await press(KEY_X)
	expect(not paused and coordinator.menu == null and game.get("_map").get_instance_id() == map_identity, "closing menu retains original map")
	expect(position == Vector2i(state.player_x, state.player_y) and state.switches["12"] and state.variables["8"] == 27, "position/switches/variables preserved")
	game.queue_free()
	current_scene = null
	await frames(3)
	# AudioServer disposes stopped Ogg playbacks on its audio tick, not a SceneTree frame.
	# Keep the test process alive briefly after freeing the real scene; do not mute audio.
	await create_timer(0.2).timeout


func make_fixture() -> Dictionary:
	var values: Array = []
	for _level in 100: values.append_array([120, 40, 20, 20, 20, 20])
	var actor := {"id": 1, "name": "测试角色", "class_id": 1, "initial_level": 1, "parameters": {"x_size": 6, "y_size": 100, "values": values}, "weapon_id": 1}
	var second := actor.duplicate(true)
	second.id = 2
	second.weapon_fix = true
	var potion := {"id": 1, "name": "恢复药", "occasion": 2, "scope": 3, "consumable": true, "recover_hp": 10, "recover_hp_rate": 25, "recover_sp": 10, "hit": 100}
	var all_potion := potion.duplicate(true)
	all_potion.id = 2
	all_potion.scope = 4
	all_potion.recover_hp = 0
	var reusable := potion.duplicate(true)
	reusable.id = 3
	reusable.consumable = false
	reusable.recover_hp_rate = 0
	var items := [null, potion, all_potion, reusable]
	for change in [{"common_event_id": 1}, {"occasion": 1}, {"scope": 5}, {"parameter_type": 1}, {"plus_state_set": [1]}, {"minus_state_set": [1]}, {"variance": 10}, {"hit": 90}, {"pdef_f": 1}, {"element_set": [1]}, {"recover_hp": -10}]:
		var unsupported := potion.duplicate(true)
		unsupported.merge(change, true)
		unsupported.id = items.size()
		items.append(unsupported)
	return {"Actors": [null, actor, second], "Classes": [null, {"id": 1, "name": "职业", "weapon_set": [1.0, 2.0], "armor_set": [1.0, 2.0]}],
		"Items": items, "Weapons": [null, {"id": 1, "name": "旧剑", "atk": 10}, {"id": 2, "name": "新剑", "atk": 25}, {"id": 3, "name": "限制剑", "atk": 99}],
		"Armors": [null, {"id": 1, "name": "半血盾", "kind": 0, "pdef": 10, "auto_state_id": 1}, {"id": 2, "name": "头盔", "kind": 1}],
		"States": [null, {"id": 1, "name": "半血", "maxhp_rate": 50}]}


func frames(count: int) -> void:
	for _i in count: await process_frame


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


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

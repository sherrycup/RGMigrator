## 职责：回归验证：验证角色属性、滚动界面与实际角色操作入口。
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
##   func test_scrolling(fixture: Dictionary) -> void
##     参数 fixture（Dictionary；必填）：独立测试夹具或其数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func test_real_interface() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func make_fixture() -> Dictionary
##     用途：构建与正式工程隔离的测试现场。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func press(key: Key, unicode: int = 0) -> void
##     用途：模拟一次按键输入。
##     参数 key（Key；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     参数 unicode（int；默认值 0）：Unicode 字符码值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func frames(count: int) -> void
##     用途：让测试现场推进指定帧数。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
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
var codec: Script
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(50).timeout.connect(func() -> void: printerr("FAIL: actor mutation timeout"); quit(1))
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	codec = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	state = root.get_node("RuntimeState")
	var cached: Dictionary = data._cache.duplicate(true)
	var fixture := make_fixture()
	for name in fixture:
		data._cache["res://data/database/%s.json" % name] = fixture[name]
	var system: Dictionary = data.system().duplicate(true)
	system.party_members = [1]
	state.begin_new_game(system, {"enabled": false})
	var original := JSON.stringify(fixture)
	var actor: RefCounted = state.actor(1)
	expect(actor.level == 1 and actor.exp == 0 and actor.hp == 110 and actor.sp == 21, "standard initial level/experience/vitals")
	expect(actor.database_str == 11 and actor.equip_str == 3 and actor.base_str == 14 and actor.str_plus == 0 and actor.str == 14, "base includes equipment but actor plus starts zero")
	expect(actor.atk == 20 and actor.pdef == 7 and actor.mdef == 9 and actor.maxhp == 110, "weapon ATK, summed defenses, no invented equipment HP")
	for key in actor.Parameters.KEYS:
		var before: int = actor.get_parameter(key)
		expect(state.change_actor_parameter(1, key, 1).ok and actor.get_parameter(key) == before + 1, "independent permanent increment: " + key)
		expect(actor.get_parameter_plus(key) == 1 and state.set_actor_parameter_plus(1, key, 0).ok, "independent bonus reset: " + key)
	actor.str += 1
	actor.atk += 1
	actor.maxhp += 1
	expect(actor.str == 15 and actor.str_plus == 1 and actor.atk == 21 and actor.atk_plus == 1 and actor.maxhp == 111 and actor.hp == 110, "native property += delegates to computed setters, does not heal")
	var sources: Dictionary = actor.parameter_sources("str")
	sources.plus = 999
	sources.state_rates.append(200)
	expect(actor.str_plus == 1 and actor.parameter_sources("str").state_rates.is_empty(), "source snapshots are detached")
	state.inventory = {"weapon:1": 0, "armor:1": 0}
	expect(state.equip(1, 0, 0).ok and actor.str_plus == 1 and actor.atk_plus == 1 and actor.atk == 1 and actor.str == 13, "unequip removes equipment, retains permanent bonus")
	expect(state.equip(1, 0, 1).ok and actor.str == 15, "reequip does not double-count permanent bonus")
	actor.add_state(1)
	expect(actor.str == 30 and actor.set_parameter("str", 32).ok and actor.str_plus == 2, "exact final setter accounts for 200 percent multiplier")
	var before: Dictionary = actor.persistent_data()
	expect(not actor.set_parameter("str", 33).ok and actor.persistent_data() == before, "unreachable rounded target fails atomically")
	expect(actor.add_parameter_plus("str", 1).ok and actor.str == 34, "permanent +1 can produce final +2")
	actor.remove_state(1)
	actor.add_state(2)
	before = actor.persistent_data()
	expect(actor.str == 1 and not actor.set_parameter("str", 2).ok and actor.persistent_data() == before, "zero multiplier and final minimum")
	actor.clear_states()
	for request in [["str", 0], ["atk", 1000], ["unknown", 10], ["str", 1.5], ["str", NAN]]:
		before = actor.persistent_data()
		expect(not actor.set_parameter(request[0], request[1]).ok and actor.persistent_data() == before, "invalid final assignment rejected")
	expect(not actor.set_parameter_plus("str", 1000).ok and not actor.add_experience(0.5).ok and not actor.set_level(INF).ok, "bonus/growth finite integer bounds")
	actor.hp = 99999
	actor.sp = -1
	expect(actor.hp == actor.maxhp and actor.sp == 0, "direct HP/SP clamp to calculated caps")
	actor.hp = 0.5
	expect(actor.hp == actor.maxhp, "fractional HP rejected")
	actor.set_vital("hp", 5)
	actor.set_vital("sp", 2)
	expect(actor.set_level(3).ok and actor.level == 3 and actor.exp == actor.experience_for_level(3) and actor.has_skill(1) and actor.has_skill(2), "level jump learns every crossed learning")
	expect(actor.hp == 5 and actor.sp == 2 and actor.database_str == 13, "level growth reads target table, does not heal")
	expect(actor.set_level(1).ok and actor.has_skill(1) and actor.has_skill(2) and actor.exp == 0, "lowering level retains skills and resets threshold EXP")
	actor.exp += int(actor.experience_for_level(2))
	expect(actor.level == 2 and actor.exp == actor.experience_for_level(2), "native EXP property performs growth")
	expect(actor.set_experience(99999999).ok and actor.level == 5 and actor.exp == 9999999 and actor.next_level_experience() == null, "max EXP/final level and no next threshold")
	expect(actor.set_experience(-1).ok and actor.level == 1 and actor.exp == 0, "negative EXP clamps zero and lowers level")
	actor.add_state(1)
	expect(actor.recover_vitals().ok and actor.hp == actor.maxhp and actor.sp == actor.maxsp and actor.has_state(1), "vital recovery keeps lightweight states")
	actor.clear_states()
	expect(actor.set_parameter("maxhp", 10).ok and actor.hp == 10, "lower cap immediately clamps current HP")
	actor.set_parameter_plus("maxhp", 0)
	expect(actor.hp == 10, "raising cap never heals")
	actor.name = "成长测试"
	expect(actor.actor_name == "成长测试" and state.rename_actor(1, "原生角色").ok, "native name alias and registry rename")
	var resources: Script = load("res://runtime/scripts/04_UI_Common/UIResources.gd")
	resources._textures["Graphics/Characters/__actor_test__"] = ImageTexture.create_from_image(Image.create(128, 128, false, Image.FORMAT_RGBA8))
	expect(state.set_actor_graphic(1, "__actor_test__", 120).ok and actor.character_hue == 120, "shared graphic + hue validation")
	expect(not state.set_actor_graphic(1, "__actor_missing__", 0).ok and actor.character_name == "__actor_test__", "missing graphic cannot partly replace identity")
	expect(not state.set_actor_graphic(1, "", -1).ok and state.set_actor_graphic(1, "", 360).ok and actor.character_hue == 0, "empty graphic fallback and normalized hue")
	state.inventory = {"weapon:1": 0, "armor:1": 99}
	actor._definition = actor._definition.duplicate(true)
	actor._definition.weapon_fix = true
	before = {"actor": actor.persistent_data(), "inventory": state.inventory.duplicate(true)}
	expect(not state.change_actor_class(1, 2).ok and before == {"actor": actor.persistent_data(), "inventory": state.inventory}, "full backpack aborts class/equipment transaction together")
	state.inventory["armor:1"] = 0
	var skills: Array = actor.get_skill_ids()
	expect(state.change_actor_class(1, 2).ok and actor.class_id == 2 and actor.equipment == [0, 0, 0, 0, 0] and state.inventory_count("weapon", 1) == 1 and state.inventory_count("armor", 1) == 1, "class change returns all incompatible equipment, even fixed slot")
	expect(actor.str_plus == 3 and actor.level == 1 and actor.exp == 0 and actor.get_skill_ids() == skills, "class change preserves permanent/growth/skills")
	expect(not state.change_actor_class(1, 999).ok, "missing class rejected")
	state.set_actor_graphic(1, "__actor_test__", 120)
	var snapshot: Dictionary = codec.capture(state)
	var result: Dictionary = codec.prepare(JSON.parse_string(JSON.stringify(snapshot)))
	expect(result.ok, "new mutation snapshot accepts JSON float integers")
	if result.ok:
		state.restore_prepared(result)
		expect(codec.capture(state) == snapshot, "all new persistent actor fields restore exactly")
	var legacy := snapshot.duplicate(true)
	for field in ["parameter_plus", "character_name", "character_hue"]:
		legacy.actors[0].erase(field)
	result = codec.prepare(legacy)
	expect(result.ok and result.actors[1].str_plus == 0 and result.actors[1].character_name == "", "old schema 1 defaults zero bonus/database graphic, not gear-derived bonus")
	for field in ["parameter_plus", "character_name", "character_hue"]:
		var damaged := snapshot.duplicate(true)
		damaged.actors[0][field] = {"str": 1} if field == "parameter_plus" else (17 if field == "character_name" else -1)
		expect(not codec.prepare(damaged).ok and codec.capture(state) == snapshot, "malformed additive save field fails detached: " + field)
	for value in [1000, 1.5, NAN]:
		var damaged := snapshot.duplicate(true)
		damaged.actors[0].parameter_plus.str = value
		expect(not codec.prepare(damaged).ok and codec.capture(state) == snapshot, "invalid saved permanent bonus rejected before commit")
	state.change_party(1, false)
	expect(state.change_actor_parameter(1, "atk", 1).ok, "off-party actor mutable")
	state.change_party(1, true, false)
	expect(state.actor(1).atk_plus == 2, "rejoin preserves actor mutation")
	state.change_party(1, true, true)
	expect(state.actor(1).atk_plus == 0 and state.actor(1).actor_name == "测试角色", "initialized rejoin resets all mutations")
	var broken: Dictionary = fixture.Actors[1].duplicate(true)
	broken.parameters.values[3 * 6] = "bad"
	var detached: RefCounted = load("res://runtime/scripts/00_Game/ActorState.gd").new()
	detached.configure(1, broken, data.record)
	before = detached.persistent_data()
	expect(not detached.set_level(3).ok and detached.persistent_data() == before, "missing target level parameters reject growth without partial updates")
	fixture.Classes[1].learnings.append({"level": 4, "skill_id": 999})
	before = detached.persistent_data()
	expect(not detached.set_level(4).ok and detached.persistent_data() == before, "bad learning reference aborts entire growth")
	fixture.Classes[1].learnings.pop_back()
	expect(JSON.stringify(fixture) == original, "mutations/save/class changes do not edit source database")
	await test_scrolling(fixture)
	data._cache = cached
	resources._textures.erase("Graphics/Characters/__actor_test__")
	await test_real_interface()
	for failure in failures: printerr("FAIL: ", failure)
	print("ACTOR MUTATION TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func test_scrolling(fixture: Dictionary) -> void:
	for id in range(3, 25):
		fixture.Items.append({"id": id, "name": "物品%d" % id, "price": 10})
		fixture.Skills.append({"id": id, "name": "特技%d" % id})
	state.begin_new_game(data.system(), {"enabled": false})
	state.party = [1]
	var actor: RefCounted = state.actor(1)
	var goods: Array = []
	for id in range(3, 25):
		state.inventory["item:%d" % id] = 1
		goods.append([0, id])
		actor.learn_skill(id)
	var shop: Control = load("res://runtime/scripts/08_Menu/Shop/ShopScene.gd").new()
	shop.goods = goods
	root.add_child(shop)
	shop.activate()
	for _i in 15: shop.navigate(1)
	var row: int = shop._list.scroll_row
	var index: int = shop.selected
	shop.navigate(-1)
	expect(row > 0 and shop._list.scroll_row == row and shop.selected == index - 1, "buy up moves cursor, retains scrolled viewport")
	while shop.selected > row: shop.navigate(-1)
	shop.navigate(-1)
	expect(shop._list.scroll_row == row - 1, "buy scrolls only after crossing upper viewport edge")
	shop.back()
	shop.navigate(1)
	shop.activate()
	for _i in 15: shop.navigate(1)
	row = shop._list.scroll_row
	shop.navigate(-1)
	expect(row > 0 and shop._list.scroll_row == row, "sell retains viewport on upward cursor movement")
	shop.queue_free()
	var inventory: Control = load("res://runtime/scripts/08_Menu/Item/InventoryScene.gd").new()
	root.add_child(inventory)
	for _i in 15: inventory.navigate(1)
	row = inventory._selection.scroll_row
	inventory.navigate(-1)
	expect(row > 0 and inventory._selection.scroll_row == row, "inventory retained viewport across rebuild")
	inventory.queue_free()
	var skills: Control = load("res://runtime/scripts/08_Menu/Skill/SkillScene.gd").new()
	skills.actor_id = 1
	root.add_child(skills)
	for _i in 15: skills.navigate(1)
	row = skills._list.scroll_row
	skills.navigate(-1)
	expect(row > 0 and skills._list.scroll_row == row, "skill retained viewport across rebuild")
	skills.queue_free()
	await frames(3)


func test_real_interface() -> void:
	var system: Dictionary = data.system().duplicate(true)
	if not data.map(585).is_empty():
		system.start_map_id = 585
		system.start_x = 13
		system.start_y = 6
	# Exercise actor UI over the real map graphics; source Ruby-dependent
	# parallel stories are covered separately by EventTests and source rendering.
	var quiet_map: Dictionary = data.map(int(system.start_map_id)).duplicate(true)
	quiet_map.events = {}
	data._cache["res://data/maps/Map%03d.json" % int(system.start_map_id)] = quiet_map
	state.begin_new_game(system)
	state.resume_from_save = true
	var actor_id := int(state.party[0])
	var actor: RefCounted = state.actor(actor_id)
	var game: Node = load("res://scenes/03_Map/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	var identity: int = game._map.get_instance_id()
	var position_before := Vector2i(state.player_x, state.player_y)
	var facing: Vector2i = game._player.facing
	await press(KEY_ESCAPE)
	await press(KEY_F6)
	var menu: Control = game._menus.menu
	expect(menu != null and menu.page == "test_tools", "Esc then F6 reaches visible test hub")
	await press(KEY_ENTER)
	expect(menu.page == "actor_tools", "keyboard selects actor mutation tools")
	var tools: Control = menu._commerce
	await press(KEY_ENTER)
	expect(actor.atk_plus == 1 and tools.message.contains("永久修正"), "actual keyboard action changes registry, not private UI copy")
	tools.action(9)
	var hp: int = actor.hp
	tools.action(8)
	expect(actor.hp <= hp, "actual growth action does not auto-heal (lower source cap may truncate)")
	tools.action(12)
	tools._name_edit.grab_focus()
	tools._name_edit.select_all()
	await press(KEY_X, 120)
	expect(tools._name_edit.text == "x" and is_instance_valid(tools._identity), "text input X is not mistaken for menu cancel")
	tools._name_edit.text = "原生测试姓名"
	tools.identity_action(0)
	expect(actor.actor_name == "原生测试姓名", "identity form applies runtime rename")
	await press(KEY_ESCAPE)
	expect(tools._identity == null and menu.page == "actor_tools", "text focus Esc closes only identity form")
	await press(KEY_ESCAPE)
	expect(menu.page == "test_tools", "actor tools return one level to hub")
	# Every mouse button must select its own row, not the loop's last index.
	for index in 3:
		var hub: Control = menu._commerce
		var buttons: Array[Node] = hub._panel.find_children("*", "Button", true, false)
		buttons[index].pressed.emit()
		expect(menu.page == ["actor_tools", "shop", "state_tools"][index], "mouse hub row maps to correct tool")
		menu.handle_back()
	await press(KEY_ESCAPE)
	expect(menu.page == "menu", "hub returns to original command menu")
	var saves: Script = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	saves.directory_override = ProjectSettings.globalize_path("res://.godot/actor_mutation_%d" % Time.get_ticks_usec())
	expect(saves.save_slot(1, state).ok, "file save accepts real new actor mutation data")
	var expected: Dictionary = codec.capture(state)
	state.begin_new_game(system)
	expect(state.actor(actor_id).atk_plus == 0 and state.actor(actor_id).actor_name != "原生测试姓名", "new game resets real actor mutations")
	var loaded: Dictionary = saves.load_slot(1, state)
	if not loaded.ok: printerr("LOAD REASON: ", loaded.message)
	var restored: Dictionary = codec.capture(state)
	for key in expected:
		if JSON.stringify(expected[key], "", true) != JSON.stringify(restored[key], "", true):
			print("RESTORE DIFF: ", key, " before=", JSON.stringify(expected[key]), " after=", JSON.stringify(restored[key]))
	expect(loaded.ok and JSON.stringify(restored, "", true) == JSON.stringify(expected, "", true), "file load restores actor mutations without regrant")
	# Graphic changes must update the retained map player, not just a menu snapshot.
	var graphic: String = state.actor(actor_id).character_name
	if not graphic.is_empty() and load("res://runtime/scripts/04_UI_Common/UIResources.gd").texture("Graphics/Characters/" + graphic) != null:
		expect(state.set_actor_graphic(actor_id, graphic, 120).ok and game._player.material is ShaderMaterial, "map player observes shared runtime hue immediately")
	await press(KEY_ESCAPE)
	expect(game._map.get_instance_id() == identity and Vector2i(state.player_x, state.player_y) == position_before and game._player.facing == facing and not paused, "mutations/menu roundtrip retain original map coordinates/facing")
	game.queue_free()
	current_scene = null
	await frames(3)
	state.begin_new_game(system, {"enabled": false})
	menu = load("res://scenes/08_Menu/Menu.tscn").instantiate()
	root.add_child(menu)
	menu.open_test_tools()
	menu.open_actor_tools()
	expect(menu.page == "menu", "production mode cannot enter test hub or actor tools")
	menu.queue_free()
	await frames(3)
	await create_timer(0.2).timeout


func make_fixture() -> Dictionary:
	var values: Array = []
	for level in 100: values.append_array([100 + level * 10, 20 + level, 10 + level, 12 + level, 14 + level, 16 + level])
	return {"Actors": [null, {"id": 1, "name": "测试角色", "class_id": 1, "initial_level": 1, "final_level": 5,
		"exp_basis": 30, "exp_inflation": 30, "weapon_id": 1, "armor1_id": 1, "character_name": "",
		"parameters": {"x_size": 6, "y_size": 100, "values": values}}],
		"Classes": [null, {"id": 1, "name": "剑士", "weapon_set": [1], "armor_set": [1], "learnings": [{"level": 2, "skill_id": 1}, {"level": 3, "skill_id": 2}]}, {"id": 2, "name": "法师", "weapon_set": [], "armor_set": []}],
		"Items": [null, {"id": 1, "name": "药", "price": 10}, {"id": 2, "name": "药2", "price": 10}],
		"Weapons": [null, {"id": 1, "name": "剑", "atk": 20, "str_plus": 2, "pdef": 2, "mdef": 3, "maxhp_plus": 500}],
		"Armors": [null, {"id": 1, "name": "盾", "kind": 0, "str_plus": 1, "pdef": 5, "mdef": 6}],
		"Skills": [null, {"id": 1, "name": "特技1"}, {"id": 2, "name": "特技2"}],
		"States": [null, {"id": 1, "name": "倍率", "str_rate": 200}, {"id": 2, "name": "零倍率", "str_rate": 0}]}


func press(key: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = key
	Input.parse_input_event(event)
	await frames(2)


func frames(count: int) -> void:
	for _i in count: await process_frame


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

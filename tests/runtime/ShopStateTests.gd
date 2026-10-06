extends SceneTree
var data: Script
var state: Node
var service: Script
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(50).timeout.connect(func() -> void: printerr("FAIL: shop/state tests timed out"); quit(1))
	data = load("res://runtime/scripts/RuntimeData.gd")
	service = load("res://runtime/scripts/ShopService.gd")
	state = root.get_node("RuntimeState")
	var fixture := make_fixture()
	var cached: Dictionary = data._cache.duplicate(true)
	for name in fixture:
		data._cache["res://data/database/%s.json" % name] = fixture[name]
	state.begin_new_game({"party_members": [1.0]}, {"enabled": false})
	var original := JSON.stringify(fixture)
	var goods: Array = [[0.0, 1.0], [1, 1], [2, 1], [0, 1]]
	expect(service.catalog(goods).entries.size() == 3, "XP pairs normalize floats and duplicate goods")
	for bad in [[[3, 1]], [[0, 999]], [[0, 1, 0, 200]], [[0.5, 1]], [null], [[0, -1]]]:
		expect(not service.catalog(bad).ok, "malformed/custom-price/missing goods rejected")
	state.gold = 100
	state.inventory = {"item:1": 2, "weapon:1": 0}
	expect(service.quote_buy(state, goods, "item", 1).maximum == 33, "affordability floors by database price")
	expect(state.shop_buy(goods, "item", 1, 3).ok and state.gold == 91 and state.inventory_count("item", 1) == 5, "buy commits gold and quantity together")
	expect(state.shop_sell("item", 1, 2).ok and state.gold == 93 and state.inventory_count("item", 1) == 3, "sell floors half of odd price")
	var unchanged := JSON.stringify([state.gold, state.inventory])
	for request in [["item", 2, 1], ["item", 1, 0], ["item", 1, -1], ["item", 1, 99], ["unknown", 1, 1]]:
		expect(not state.shop_buy(goods, request[0], request[1], request[2]).ok and JSON.stringify([state.gold, state.inventory]) == unchanged, "failed buy cannot partially mutate state")
	expect(not state.shop_sell("weapon", 1, 1).ok and JSON.stringify([state.gold, state.inventory]) == unchanged, "equipped-only weapon not sold from actor")
	state.gold = 0
	state.inventory["item:1"] = 98
	expect(not state.shop_buy(goods, "item", 1, 1).ok, "zero funds reject nonzero price")
	expect(state.shop_buy([[0, 2]], "item", 2, 99).ok and state.inventory_count("item", 2) == 99 and state.gold == 0, "zero-price buying allowed without division by zero")
	expect(not state.shop_sell("item", 2, 1).ok, "zero-price goods cannot be sold")
	state.gold = 100
	expect(service.quote_buy(state, goods, "item", 1).maximum == 1 and not state.shop_buy(goods, "item", 1, 2).ok, "99-item cap enforced before commit")
	state.gold = service.MAX_GOLD
	expect(not state.shop_sell("item", 1, 1).ok, "gold cap refuses sale without losing item")
	state.gold = 100
	var quote: Dictionary = service.quote_buy(state, goods, "weapon", 1)
	state.gold = 0
	expect(quote.maximum > 0 and not state.shop_buy(goods, "weapon", 1, 1).ok, "transaction rechecks balance after stale quote")
	var actor: RefCounted = state.actor(1)
	var hp: int = actor.hp
	var sp: int = actor.sp
	expect(not actor.has_state(1) and actor.add_state(1).changed and actor.has_state(1), "add_state / has_state")
	expect(actor.hp == hp and actor.sp == sp and not actor.has_state(2), "zero_hp/slip/plus_state_set are data only; no trigger rules")
	expect(not actor.add_state(1).changed and actor.get_state_ids(false) == [1], "duplicate state add is idempotent")
	var copy: Array = actor.get_state_ids()
	copy.clear()
	expect(actor.get_state_ids() == [1], "state queries return detached sorted IDs")
	expect(not actor.add_state(999).ok and not actor.remove_state(0).ok, "bad state references rejected")
	actor.equipment[1] = 1
	expect(actor.has_state(2) and actor.get_state_ids() == [1, 2] and actor.get_state_ids(false) == [1], "equipment source included only in effective queries")
	actor.add_state(2)
	expect(actor.remove_state(2).changed and actor.has_state(2), "removing ordinary source preserves equipment source")
	expect(actor.clear_states().changed and actor.get_state_ids(false).is_empty() and actor.get_state_ids() == [2], "clearing ordinary states preserves equipment-only state")
	actor.add_state(2)
	actor.equipment[1] = 0
	expect(actor.has_state(2), "unequipping preserves separately added ordinary state")
	expect(actor.clear_states().changed and not actor.clear_states().changed and actor.get_state_ids().is_empty(), "clear ordinary states is idempotent")
	state.change_party(1, false)
	expect(state.change_state(1, 1, true).ok and state.has_state(1, 1), "off-party state API")
	state.change_party(1, true, false)
	expect(state.has_state(1, 1), "join without init preserves state")
	state.change_party(1, true, true)
	expect(not state.has_state(1, 1), "initialized join resets ordinary states")
	expect(JSON.stringify(fixture) == original, "shop and state operations keep databases immutable")
	var interpreter: RefCounted = load("res://runtime/scripts/EventInterpreter.gd").new()
	var diagnostics: Array[String] = []
	interpreter.diagnostic_requested.connect(func(text: String) -> void: diagnostics.append(text))
	interpreter.start([command(302, [0, 1]), command(605, [1, 999])], 12, 2)
	expect(diagnostics.size() == 1 and diagnostics[0].contains("第 2 条指令 605") and diagnostics[0].contains("事件 12 / 第 2 页"), "bad continuation identifies the exact goods command and event page")
	interpreter.start([command(605, [0, 1])], 12)
	expect(diagnostics.back().contains("第 1 条指令 605") and not interpreter.running, "orphan goods continuation rejected")
	data._cache = cached
	await test_actual_interface()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("SHOP STATE TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func test_actual_interface() -> void:
	var setup: Dictionary = data.test_config()
	var system: Dictionary = data.system()
	state.begin_new_game(system)
	expect(state.gold == setup.initial_gold and state.gold == 2000, "real new game supplies configured test currency")
	var actor_id := int(state.party[0])
	var initial_state := int(setup.initial_states[0])
	var toggled := int(setup.toggle_state_id)
	expect(state.has_state(actor_id, initial_state) and not state.has_state(actor_id, toggled), "real test state overlay prepared once")
	state.resume_from_save = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	var map_identity: int = game._map.get_instance_id()
	var position_before := Vector2i(state.player_x, state.player_y)
	var direction_before: Vector2i = game._player.facing
	state.switches["91"] = true
	state.variables["92"] = 456
	expect(game._menus.open_menu(), "test menu opens")
	var menu: Control = game._menus.menu
	menu.open_state_tools()
	expect(menu.page == "state_tools", "state test entry reachable without RM editing")
	var tools: Control = menu._commerce
	tools.action(0)
	expect(state.has_state(actor_id, toggled), "state add button shares actor registry")
	tools.action(2)
	expect(tools.message.ends_with("是"), "state query button")
	tools.action(1)
	expect(not state.has_state(actor_id, toggled), "state remove button")
	tools.action(3)
	expect(state.state_ids_for(actor_id, false).is_empty(), "clear button removes initial normal state")
	menu.handle_back()
	menu.open_test_shop()
	expect(menu.page == "shop", "test shop opens without adding production menu command")
	var shop: Control = menu._commerce
	await press(KEY_ENTER)
	expect(shop.mode == "buy", "keyboard enters buy list")
	await press(KEY_ENTER)
	expect(shop.mode == "number", "keyboard enters quantity confirmation")
	await press(KEY_UP)
	expect(shop.quantity == 11, "quantity up adds ten")
	await press(KEY_LEFT)
	expect(shop.quantity == 10, "quantity left subtracts one")
	var before := JSON.stringify([state.gold, state.inventory])
	await press(KEY_ESCAPE)
	expect(shop.mode == "buy" and JSON.stringify([state.gold, state.inventory]) == before, "quantity cancel does not transact")
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	expect(state.gold == 1900 and state.inventory_count("item", int(setup.stock[0].id)) == 11, "real keyboard confirmation buys one")
	await press(KEY_ESCAPE)
	await press(KEY_DOWN)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	expect(shop.mode == "sell" and state.gold == 1950 and state.inventory_count("item", int(setup.stock[0].id)) == 10, "real keyboard sale uses half price")
	# Clock-only notifications must not rebuild the windows.
	await frames(3)
	var rebuilds: int = shop.content_rebuilds
	state.state_changed.emit()
	await frames(3)
	expect(shop.content_rebuilds == rebuilds, "unrelated state signal does not rebuild shop contents")
	# If an external script removes the selected goods during confirmation,
	# never sell the next row under the old item name/quantity.
	await press(KEY_ENTER)
	var inventory_before: Dictionary = state.inventory.duplicate(true)
	var gold_before: int = state.gold
	var removed_key := "%s:%d" % [shop._number_item.kind, int(shop._number_item.id)]
	state.inventory[removed_key] = 0
	state.state_changed.emit()
	await frames(3)
	expect(shop.mode == "sell" and shop._number_item.is_empty() and state.gold == gold_before, "removed pending sale cancels instead of changing item identity")
	state.inventory = inventory_before
	state.state_changed.emit()
	await frames(3)
	await press(KEY_ESCAPE)
	await press(KEY_ESCAPE)
	expect(menu.page == "menu", "leaving test shop returns to same menu")
	game._menus.close_menu()
	expect(game._map.get_instance_id() == map_identity and Vector2i(state.player_x, state.player_y) == position_before and game._player.facing == direction_before and state.switches["91"] and state.variables["92"] == 456, "shop preserves map identity, position, direction, switches and variables")
	# Actual map interpreter calls shop, waits, then resumes subsequent commands.
	game._start_event([command(302, setup.shop_goods[0]), command(605, setup.shop_goods[3]), command(121, [93, 93, 0]), command(0)], 9)
	expect(game._menus.shop != null and game._interpreter.running and not state.switches.has("93") and paused, "302 + 605 pauses event and map until shop closes")
	expect(not game._menus.open_menu() and not game.can_save(), "event shop owns input; menu/save mutually excluded")
	game._menus.close_shop()
	await frames(3)
	expect(state.switches.get("93", false) and not game._interpreter.running and not paused and game._player.input_enabled, "closing event shop resumes next instruction and player")
	var errors: Array[String] = []
	game._interpreter.diagnostic_requested.connect(func(text: String) -> void: errors.append(text))
	game._start_event([command(302, [0, 999999]), command(121, [94, 94, 0])], 10)
	expect(not errors.is_empty() and errors.back().contains("指令 302") and not state.switches.has("94"), "bad shop data stops at precise event location")
	for button in game._dialogue._content.get_children():
		if button is Button and button.text == "关闭":
			button.pressed.emit()
			break
	state.change_state(actor_id, toggled, true)
	var saves: Script = load("res://runtime/scripts/SaveService.gd")
	saves.directory_override = ProjectSettings.globalize_path("res://.godot/shop_save_%d" % Time.get_ticks_usec())
	var gold: int = state.gold
	var count: int = state.inventory_count("item", int(setup.stock[0].id))
	expect(saves.save_slot(1, state).ok, "post-shop and state progress saves")
	state.begin_new_game(system)
	expect(saves.load_slot(1, state).ok and state.gold == gold and state.inventory_count("item", int(setup.stock[0].id)) == count and state.has_state(actor_id, toggled), "save restores trade results and registered state without test regrant")
	game.queue_free()
	current_scene = null
	await frames(3)
	state.begin_new_game(system, {"enabled": false})
	menu = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	menu.open_test_shop()
	menu.open_state_tools()
	expect(state.gold == 0 and menu.page == "menu" and not state.has_state(actor_id, toggled), "production new game has no test gold/state/tools")
	menu.queue_free()
	await frames(3)
	await create_timer(0.2).timeout


func make_fixture() -> Dictionary:
	var values: Array = []
	for _level in 100: values.append_array([100, 30, 10, 10, 10, 10])
	return {"Actors": [null, {"id": 1, "name": "测试角色", "class_id": 1, "initial_level": 1, "final_level": 99, "weapon_id": 1,
		"parameters": {"x_size": 6, "y_size": 100, "values": values}}], "Classes": [null, {"id": 1, "weapon_set": [1], "armor_set": [1]}],
		"Items": [null, {"id": 1, "name": "药", "price": 3}, {"id": 2, "name": "免费物品", "price": 0}],
		"Weapons": [null, {"id": 1, "name": "剑", "price": 10, "atk": 10}],
		"Armors": [null, {"id": 1, "name": "盾", "price": 20, "kind": 0, "auto_state_id": 2}], "Skills": [null],
		"States": [null, {"id": 1, "name": "仅登记", "zero_hp": true, "slip_damage": true, "plus_state_set": [2]}, {"id": 2, "name": "装备来源"}]}


func command(code: int, parameters: Array = []) -> Dictionary:
	return {"code": code, "parameters": parameters, "indent": 0}


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


func frames(count: int) -> void:
	for _index in count: await process_frame


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

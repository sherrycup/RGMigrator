extends SceneTree
## Production Game/SaveService tests, also used by two independent processes.
var state: Node
var data: Script
var saves: Script
var codec: Script
var game: Node
var failures: Array[String] = []
var checks := 0
var item_id := 0
var skill_id := 0
var map_id := 0
var phase := ""

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("FAIL: event save timeout"); quit(1))
	state = root.get_node("RuntimeState"); data = load("res://runtime/scripts/RuntimeData.gd")
	saves = load("res://runtime/scripts/SaveService.gd"); codec = load("res://runtime/scripts/SaveCodec.gd")
	var directory := ProjectSettings.globalize_path("res://.godot/event_save_%d" % Time.get_ticks_usec())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--save-directory="): directory = arg.trim_prefix("--save-directory=")
	if not directory.begins_with(ProjectSettings.globalize_path("res://.godot/")): quit(1); return
	saves.directory_override = directory
	install_fixture()
	if phase == "read":
		expect(saves.load_slot(1, state).ok, "separate process reads event save")
		await mount(false)
		check_restored()
	elif phase == "write":
		await mount()
		prepare_restart()
		expect(saves.save_slot(1, state).ok, "separate process writes all event runtime")
	else:
		await mount()
		prepare_restart()
		var saved: Dictionary = saves.save_slot(1, state)
		expect(saved.ok, "save during background routes/parallel: " + str(saved.get("message", "")))
		await unmount()
		expect(saves.load_slot(1, state).ok, "JSON event scene decodes before commit")
		await mount(false)
		check_restored()
		await save_ui()
		await item_skill_use()
		validation()
	await unmount()
	state.audio.stop_all()
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT SAVE TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks / ", phase)
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func c(code: int, p: Array = [], indent: int = 0) -> Dictionary:
	return {"code": code, "parameters": p, "indent": indent}

func add(id: int, amount: int = 1, indent: int = 0) -> Dictionary:
	return c(122, [id, id, 1, 0, amount], indent)

func route(commands: Array, repeat: bool = false) -> Dictionary:
	return {"repeat": repeat, "skippable": false, "list": commands + [c(0)]}

func install_fixture() -> void:
	map_id = int(data.system().start_map_id)
	var source: Dictionary = data.map(map_id).duplicate(true)
	source.id = map_id; source.width = 18; source.height = 12
	var tiles: Array = []; tiles.resize(18 * 12 * 3); tiles.fill(0)
	source.data = {"x_size": 18, "y_size": 12, "z_size": 3, "data": tiles}
	source.events = {}
	var fixture: Script = load("res://runtime/scripts/EventFixture.gd")
	for id in range(1, 6):
		var event: Dictionary = fixture.event(2 + id, 3 + id % 2, 0, [c(0)], {}, "@persist")
		event.id = id
		source.events[str(id)] = event
	source.events["2"].pages[0].trigger = 4
	source.events["2"].pages[0].list = [add(9702), c(106, [60]), c(0)]
	source.events["5"].pages[0].condition = {"switch1_valid": true, "switch1_id": 9705}
	data._cache["res://data/maps/Map%03d.json" % map_id] = source
	var commons: Array = [null,
		{"id": 1, "trigger": 0, "list": [add(9701), c(106, [40]), c(0)]},
		{"id": 2, "trigger": 2, "switch_id": 9706, "list": [add(9706), c(106, [80]), c(0)]},
		{"id": 3, "trigger": 0, "list": [add(9710), c(0)]}]
	data._cache["res://data/database/CommonEvents.json"] = commons
	var items: Array = data.database("Items").duplicate(true)
	item_id = maxi(1, items.size()); items.resize(item_id + 1)
	items[item_id] = {"id": item_id, "name": "回城卷轴", "occasion": 2, "scope": 0, "common_event_id": 3, "consumable": true, "icon_name": "", "description": "测试公共事件"}
	data._cache["res://data/database/Items.json"] = items
	var skills: Array = data.database("Skills").duplicate(true)
	skill_id = maxi(1, skills.size()); skills.resize(skill_id + 1)
	skills[skill_id] = {"id": skill_id, "name": "回城术", "occasion": 2, "scope": 0, "common_event_id": 3, "sp_cost": 2, "icon_name": "", "description": "测试公共事件"}
	data._cache["res://data/database/Skills.json"] = skills
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8); image.fill(Color("c07030"))
	load("res://runtime/scripts/UIResources.gd")._textures["Graphics/Characters/@persist"] = ImageTexture.create_from_image(image)

func mount(new_game: bool = true) -> void:
	if new_game:
		state.begin_new_game(data.system(), {"enabled": false})
		state.player_motion.relocate(Vector2i(15, 9)); state.resume_from_save = true
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.set_process(false); game._player.set_process(false)
	for entry in game._map.event_contexts(): entry.node.set_process(false)
	await process_frame
	if new_game: game._scheduler.advance(0, false)
	game._sync_event_input()

func unmount() -> void:
	if is_instance_valid(game):
		if game._menus.menu != null: game._menus.close_menu()
		game.free(); game = null
	paused = false
	await process_frame

func prepare_restart() -> void:
	var first: Node = game._map.event_node(1)
	first.configure_motion({"through": true})
	first.force_move_route(route([c(3), c(3), c(3), c(29, [5]), c(30, [5]), c(33), c(35), c(42, [137]), c(43, [1]), c(39), c(41, ["@persist", 120, 8, 2])]))
	for i in 40: first.advance_motion(0.025)
	expect(first.tile_position == Vector2i(6, 4) and not first.routes.forcing, "right three cells completed before saving")
	var fourth: Node = game._map.event_node(4)
	fourth.routes.configure(3, 6, route([c(15, [40]), c(1)], true))
	fourth.force_move_route(route([c(3), c(15, [20]), c(3)]))
	fourth.advance_motion(0.05)
	expect(fourth.motion.moving(), "second character saved in mid-step")
	game._map.erase_event(3)
	state.set_event_switch(9706, true)
	game._scheduler.advance(0.5, false)
	var commands := [add(9700, 100), c(112), add(9703, 1, 1), c(117, [1], 1), c(111, [1, 9703, 0, 2, 1], 1), c(113, [], 2), c(412, [], 1), c(413), add(9704), c(0)]
	game._scheduler.start_main(commands, 1, 1, "", true)
	game._scheduler.advance(0, false)
	game._scheduler.advance(0.75, false)
	expect(game._interpreter.context.stack.size() == 1 and game._interpreter.wait_state.remaining == 1.25, "nested common event/loop saved at exact remaining wait")
	expect(state.variables.get("9700") == 100 and state.variables.get("9701") == 1, "rewards already applied once before save")

func check_restored() -> void:
	var first: Node = game._map.event_node(1)
	expect(first.tile_position == Vector2i(6, 4), "every event restores current position, not source spawn")
	expect(first.motion.direction == 8 and first.motion.options.opacity == 137 and first.motion.options.blend_type == 1 and first.motion.options.move_speed == 5 and first.motion.options.direction_fix and first.motion.options.step_anime and first.always_on_top and first._name == "@persist" and first._hue == 120 and first.motion.options.idle_pattern == 2 and first.routes.move_frequency == 5, "completed route keeps direction/opacity/speed/graphic/frequency/top and all flags")
	game._map.refresh_events()
	expect(first.tile_position == Vector2i(6, 4) and first.motion.options.opacity == 137, "same-page refresh retains restored event attributes")
	var fourth: Node = game._map.event_node(4)
	expect(fourth.tile_position == Vector2i(6, 3) and fourth.motion.target == Vector2i(7, 3) and is_equal_approx(fourth.motion.visual_cell.x, 6.25), "mid-step cell/target/smooth position restored")
	expect(fourth.routes.forcing and fourth.routes.snapshot().index == 1, "forced route cursor survives restart")
	expect(game._map.event_node(3) == null and game._map.has_erased_events(), "temporary erasure remains after load")
	expect(game.capture_event_state().events.size() == 5, "snapshot includes every current-map event, including inactive and erased")
	expect(game.capture_event_state().events.values().all(func(entry: Dictionary) -> bool: return entry.position is Array and entry.position.size() == 2), "every event has an explicit saved position even without an active page")
	expect(game._interpreter.wait_state.remaining == 1.25 and game._interpreter.context.stack.size() == 1, "foreground stack and wait restored")
	var parallel: RefCounted = game._scheduler.parallels["event:2:1"].owner
	expect(is_equal_approx(parallel.wait_state.remaining, 1.75), "map parallel resumes remaining time instead of restarting")
	expect(game._scheduler.parallels.has("common:2") and is_equal_approx(game._scheduler.parallels["common:2"].owner.wait_state.remaining, 3.25), "common parallel restores independently")
	game._scheduler.advance(1.25, false)
	expect(state.variables.get("9700") == 100 and state.variables.get("9701") == 2 and state.variables.get("9703") == 2, "loop resumes without duplicating prefix reward")
	game._scheduler.advance(2, false)
	expect(state.variables.get("9704") == 1 and not game._interpreter.running, "nested return and restored loop break complete exactly once")
	for i in 70: fourth.advance_motion(0.025)
	expect(fourth.tile_position == Vector2i(8, 3) and not fourth.routes.forcing and fourth.routes.move_type == 3, "remaining forced moves finish and restore original autonomous route")
	state.set_event_switch(9706, false)
	game._scheduler.advance(0, false)

func save_ui() -> void:
	game._scheduler.cancel_all()
	game._scheduler.start_main([c(134, [0]), add(9711, 100), c(352), add(9712), c(0)], 1)
	game._event_ui.pump(game.event_ui_available())
	expect(game._menus.menu != null and game._menus.menu.page == "save" and paused, "352 opens actual save page and pauses map")
	expect(state.save_disabled and game.can_save(), "native 352 explicitly permits event save despite menu save prohibition")
	var saved: Dictionary = game.save_slot(2)
	expect(saved.ok, "352 saves before continuation: " + str(saved.get("message", "")))
	await process_frame
	game._scheduler.advance(0, false)
	expect(state.variables.get("9711") == 100 and state.variables.get("9712") == 1, "successful event save closes page and continues once")
	await unmount()
	expect(saves.load_slot(2, state).ok, "352 save can be loaded")
	await mount(false)
	expect(game._menus.menu == null and game._interpreter.wait_kind() == "" and state.variables.get("9712", 0) == 0, "load does not reopen consumed save UI or prematurely award key")
	game._scheduler.advance(0, false)
	expect(state.variables.get("9711") == 100 and state.variables.get("9712") == 1, "load resumes immediately after352 without repeating money")
	expect(not saves.save_slot(3, state).ok, "134 still prohibits ordinary direct saves after event override closes")
	state.save_disabled = false
	game._scheduler.cancel_all()
	game._scheduler.start_main([c(352), add(9713), c(0)], 0)
	game._event_ui.pump(game.event_ui_available())
	game._menus.menu.handle_back()
	game._scheduler.advance(0, false)
	expect(state.variables.get("9713") == 1 and game._menus.menu == null, "cancel event save resumes correct caller once")
	# Foreground save and pending parallel dialogue must retain queue ownership.
	game._scheduler.cancel_all()
	game._scheduler.start_main([c(352), c(0)], 0)
	game._event_ui.pump(game.event_ui_available())
	var parallel: RefCounted = game._scheduler.parallels.get("event:2:1", {}).get("owner")
	if parallel == null:
		game._scheduler._reconcile(); parallel = game._scheduler.parallels["event:2:1"].owner
	parallel.start([c(102, [["继续", "离开"], 0]), c(402, [0]), add(9720, 1, 1), c(402, [1]), add(9720, 10, 1), c(404), c(0)], 2)
	parallel.advance(0)
	expect(saves.save_slot(3, state).ok, "pending parallel choice is serializable behind save window")
	await unmount(); expect(saves.load_slot(3, state).ok, "choice queue save loads"); await mount(false)
	game._event_ui.pump(game.event_ui_available())
	expect(game._event_ui.active.get("kind") == "choice" and game._dialogue.is_open(), "restored choice presented with original owner")
	var id: int = game._event_ui.active.id
	game._dialogue.dismiss()
	game._event_response(id, "choice", 1)
	game._scheduler.advance(0, false)
	expect(state.variables.get("9720") == 10, "restored choice routes value to correct branch")
	game._event_response(id, "choice", 0)
	expect(state.variables.get("9720") == 10, "old queue callback cannot repeat restored reward")
	game._event_ui.cancel_all(); game._scheduler.cancel_all()

func item_skill_use() -> void:
	var actor_id := int(state.party[0])
	state.inventory["item:%d" % item_id] = 2
	state.change_skill(actor_id, skill_id, true); state.actor(actor_id).sp = 5
	game._sync_event_input()
	expect(game._menus.open_menu(), "menu opens for common-event items")
	var menu: Control = game._menus.menu
	menu._push("inventory")
	var inventory: Control = menu._commerce
	inventory.list_index = inventory._entries.find(inventory._entries.filter(func(entry: Dictionary) -> bool: return entry.kind == "item" and int(entry.id) == item_id)[0])
	inventory.refresh(); inventory.activate()
	expect(game._menus.menu == null and state.inventory["item:%d" % item_id] == 1 and not state.common_event_reservation.is_empty(), "real item menu consumes once and closes for reservation")
	expect(not state.use_item(item_id, 0).ok and state.inventory["item:%d" % item_id] == 1, "busy reservation refuses repeated use without consuming")
	game._scheduler.advance(0)
	expect(state.variables.get("9710") == 1 and state.common_event_reservation.is_empty(), "reserved item common event runs once on map")
	game._scheduler.advance(0)
	expect(state.variables.get("9710") == 1, "reservation cannot replay next update")
	game._sync_event_input()
	expect(game._menus.open_menu(), "menu opens for common-event skill")
	menu = game._menus.menu; menu.actor_index = 0; menu._push("skills")
	var skills: Control = menu._commerce
	skills.selected = skills._ids.find(skill_id); skills._selection_id = skill_id; skills.refresh(); skills.activate()
	expect(game._menus.menu == null and state.actor(actor_id).sp == 3 and not state.common_event_reservation.is_empty(), "real skill menu costs SP once and returns to map")
	game._scheduler.advance(0)
	expect(state.variables.get("9710") == 2, "skill common event executes once")
	state.actor(actor_id).sp = 1
	expect(not state.use_skill(actor_id, skill_id).ok and state.actor(actor_id).sp == 1 and state.common_event_reservation.is_empty(), "insufficient SP leaves actor and reservation unchanged")
	var skill: Dictionary = data.record("Skills", skill_id)
	skill.scope = 3; skill.power = 10; state.actor(actor_id).sp = 5
	expect(not state.use_skill(actor_id, skill_id, actor_id).ok and state.actor(actor_id).sp == 5, "unsupported mixed skill effect refuses partial event and cost")
	skill.power = 0; game._sync_event_input()
	expect(game._menus.open_menu(), "single-target common-event skill menu opens")
	menu = game._menus.menu; menu._push("skills"); skills = menu._commerce
	skills.selected = skills._ids.find(skill_id); skills._selection_id = skill_id; skills.refresh(); skills.activate()
	expect(skills._target_selection != null and state.actor(actor_id).sp == 5, "single-target selection does not prematurely spend SP")
	skills.activate(); game._scheduler.advance(0)
	expect(state.variables.get("9710") == 3 and state.actor(actor_id).sp == 3 and game._menus.menu == null, "single-target confirmation reserves once and charges once")
	skill.scope = 0
	state.use_item(item_id, 0)
	expect(saves.save_slot(4, state).ok, "common reservation can be saved before it starts")
	await unmount(); expect(saves.load_slot(4, state).ok, "reserved common event loads"); await mount(false)
	game._scheduler.advance(0)
	expect(state.variables.get("9710") == 4 and state.inventory["item:%d" % item_id] == 0, "restored reservation executes without repeating item cost")

func validation() -> void:
	var snapshot: Dictionary = codec.capture(state)
	var mutations := ["position", "route", "wait", "missing", "ui", "common", "conflict"]
	for kind in mutations:
		var bad: Dictionary = snapshot.duplicate(true)
		match kind:
			"position": bad.event_state.events["1"].character.motion.cell[0] = 9999
			"route": bad.event_state.events["1"].character.routes.index = 9999
			"wait": bad.event_state.executions.main = {"bad": true}
			"missing": bad.event_state.events.erase("4")
			"ui": bad.event_state.requests.append({"owner": "absent", "kind": "message", "payload": []})
			"common": bad.event_state.executions["common:999"] = null
			"conflict": bad.event_state.events["1"].position[0] = 0
		var before := JSON.stringify([state.inventory, state.variables, state.player_motion.persistent_data()])
		expect(not codec.prepare(bad).ok and before == JSON.stringify([state.inventory, state.variables, state.player_motion.persistent_data()]), "malformed %s rejects before state mutation" % kind)
	var old: Dictionary = snapshot.duplicate(true); old.erase("event_state"); old.erase("common_event_reservation")
	expect(codec.prepare(old).ok, "old native schema1 saves have compatible defaults")
	var map_before: Dictionary = data.map(map_id).duplicate(true)
	expect(map_before.events["1"].x == 3 and map_before.events["1"].pages[0].graphic.character_hue == 0, "event runtime never writes source definitions")
	game._map.load_map(map_id)
	expect(game._map.event_node(1).tile_position == Vector2i(3, 4) and game._map.event_node(1).motion.options.opacity == 255 and game._map.event_node(3) != null, "ordinary map reconstruction resets relocation/route properties/temporary erasure by native rules")

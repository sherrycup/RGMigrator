extends SceneTree
var data: Script
var saves: Script
var codec: Script
var state: Node
var failures: Array[String] = []
var checks := 0
var system: Dictionary
var location := ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: printerr("FAIL: save tests timeout"); quit(1))
	data = load("res://runtime/scripts/RuntimeData.gd")
	saves = load("res://runtime/scripts/SaveService.gd")
	codec = load("res://runtime/scripts/SaveCodec.gd")
	state = root.get_node("RuntimeState")
	location = ProjectSettings.globalize_path("res://.godot/save_tests_%d" % Time.get_ticks_usec())
	saves.directory_override = location
	system = data.system().duplicate(true)
	if not data.map(585).is_empty():
		system.start_map_id = 585
		system.start_x = 13
		system.start_y = 6
	state.begin_new_game(system)
	var original := JSON.stringify(data.database("Actors"))
	var setup: Dictionary = data.test_config()
	var actor: RefCounted = state.actor(int(state.party[0]))
	actor.hp = 3
	actor.sp = 1
	state.gold = 123
	state.steps = 7
	state.play_seconds = 123.5
	state.player_direction = 8
	state.switches["12"] = true
	state.variables["13"] = -123
	var map: Dictionary = data.map(state.map_id)
	if not map.get("events", {}).is_empty():
		state.self_switches["%d:%s:A" % [state.map_id, map.events.keys()[0]]] = true
	state.inventory["item:%d" % int(setup.stock[0].id)] = 2
	actor.forget_skill(int(setup.toggle_skill_id))
	var expected: Dictionary = codec.capture(state)
	var first_save: Dictionary = saves.save_slot(1, state)
	if not first_save.ok: printerr("SAVE REASON: ", first_save.message)
	expect(first_save.ok, "save actual source actor, equipment and testing overlay")
	var result: Dictionary = saves.read_slot(1)
	expect(result.ok, "versioned checksum file reads")
	if not result.ok:
		printerr("FAIL: ", result.message)
		await finish()
		return
	expect(saves.slot_info(1).party.contains(actor.actor_name), "slot summary comes from validated progress")
	expect(saves.has_valid_save() and not saves.read_slot(2).ok, "continue enabled only with valid slot")
	state.begin_new_game(system)
	expect(saves.load_slot(1, state).ok, "load restores committed snapshot")
	expect(JSON.stringify(codec.capture(state), "", true) == JSON.stringify(expected, "", true), "all persistent fields restore exactly; no grant or init reset")
	expect(state.resume_from_save and state.actor(int(state.party[0])).hp == 3, "restoration marks Game continuation and preserves HP")
	expect(not state.has_skill(int(state.party[0]), int(setup.toggle_skill_id)) and state.inventory["item:%d" % int(setup.stock[0].id)] == 2, "forget state and used stock survive load")
	expect(JSON.stringify(data.database("Actors")) == original, "loading never modifies source definitions")
	# Backup is the prior successful contents, not damaged or unvalidated input.
	state.gold = 999
	expect(saves.save_slot(1, state).ok and FileAccess.file_exists(saves.slot_path(1) + ".bak"), "overwrite keeps previous good backup")
	expect(saves.write_text(saves.slot_path(1), "broken JSON") == OK, "damage only our disposable test slot")
	result = saves.read_slot(1)
	expect(result.ok and result.recovered and result.prepared.state.gold == 123, "bad primary selects previous backup")
	var backup_view: Control = load("res://runtime/scripts/SaveSlots.gd").new()
	backup_view.mode = "load"
	root.add_child(backup_view)
	var requests := {"count": 0}
	backup_view.load_requested.connect(func(_slot: int) -> void: requests.count += 1)
	backup_view.activate()
	expect(backup_view._confirmation == "backup" and requests.count == 0, "backup load asks for confirmation before emitting request")
	backup_view.activate()
	expect(requests.count == 0 and backup_view._confirm == null, "default backup confirmation cancels")
	backup_view.activate()
	backup_view.navigate(-1)
	backup_view.activate()
	expect(requests.count == 1, "backup load emits only after explicit confirmation")
	backup_view.queue_free()
	await frames(2)
	expect(saves.save_slot(1, state).ok and saves.read_path(saves.slot_path(1) + ".bak").prepared.state.gold == 123, "overwriting damaged primary preserves known-good backup")
	# Primary without backup must fail without any live-state/overlay mutation.
	saves.write_text(saves.slot_path(2), "broken")
	var before: String = JSON.stringify(codec.capture(state), "", true)
	expect(not saves.load_slot(2, state).ok and JSON.stringify(codec.capture(state), "", true) == before, "bad slot load is transactional")
	state.save_disabled = true
	expect(not saves.save_slot(3, state).ok, "save_disabled enforced below UI")
	state.save_disabled = false
	expect(not saves.save_slot(0, state).ok and not saves.save_slot(5, state).ok, "slot bounds enforced")
	var primary_bytes := FileAccess.get_file_as_string(saves.slot_path(1))
	saves.write_text(location.path_join("blocked"), "not a directory")
	saves.directory_override = location.path_join("blocked/subdir")
	expect(not saves.save_slot(1, state).ok, "filesystem write failure returns structured error")
	saves.directory_override = location
	expect(FileAccess.get_file_as_string(saves.slot_path(1)) == primary_bytes, "write failure never changes existing good slot")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(1)))
	parsed.schema_version = 999
	saves.write_text(saves.slot_path(3), JSON.stringify(parsed))
	expect(not saves.read_slot(3).ok, "unknown schema refused")
	parsed.schema_version = 1
	parsed.project_id = "other-project"
	saves.write_text(saves.slot_path(3), JSON.stringify(parsed))
	expect(not saves.read_slot(3).ok, "foreign project refused")
	parsed.project_id = saves.project_id()
	parsed.data_fingerprint = "changed"
	saves.write_text(saves.slot_path(3), JSON.stringify(parsed))
	expect(not saves.read_slot(3).ok, "changed data refused")
	parsed.data_fingerprint = saves.fingerprint()
	parsed.payload += " "
	saves.write_text(saves.slot_path(3), JSON.stringify(parsed))
	expect(not saves.read_slot(3).ok, "checksum mismatch refused")
	await malformed_cases(expected)
	standard_fixture()
	# Empty party and standard non-testing state are supported.
	state.begin_new_game(system, {"enabled": false})
	state.party = []
	expect(saves.save_slot(4, state).ok and saves.load_slot(4, state).ok and state.party.is_empty() and not state.testing_enabled, "empty party and production save roundtrip")
	# Actual menu -> slot confirmation -> title -> load -> Game route.
	state.begin_new_game(system)
	state.actor(int(state.party[0])).hp = 3
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	state.resume_from_save = true
	root.add_child(game)
	current_scene = game
	await frames(3)
	expect(not game._dialogue.is_open() and game._player.facing == Vector2i.DOWN, "loaded Game restores direction without replaying startup autorun")
	var coordinator: Node = game._menus
	expect(coordinator.open_menu(), "menu opens before saving")
	var menu: Control = coordinator.menu
	menu.navigate(1)
	menu.activate()
	expect(menu.page == "save", "menu exposes save page")
	var slots: Control = menu._commerce
	slots.activate()
	expect(slots._confirm != null and slots._confirm.index == 1, "overwrite confirmation defaults to cancel")
	slots.back()
	expect(slots._confirm == null, "Esc cancels overwrite without leaving slots")
	slots.activate()
	slots.navigate(-1)
	slots.activate()
	expect(slots.message.contains("已保存"), "actual save button succeeds")
	menu.handle_back()
	expect(menu.page == "menu" and menu.command_index == 4, "save back restores command selection")
	coordinator.return_to_title()
	await frames(4)
	var title: Control = current_scene
	var continue_button: Button
	var unavailable_notice := false
	for button in title.find_children("*", "Button", true, false):
		if button.text == "继续游戏": continue_button = button
	for label in title.find_children("*", "Label", true, false):
		if label.text.contains("存在不可用存档"):
			unavailable_notice = true
	expect(continue_button != null and not continue_button.disabled, "title Continue enabled after valid save")
	expect(unavailable_notice, "title reports corrupt or incompatible slots rather than hiding their existence")
	continue_button.pressed.emit()
	expect(title._slots != null, "title Continue opens slot view")
	title._slots.activate()
	await frames(4)
	expect(current_scene.name == "Game" and state.actor(int(state.party[0])).hp == 3, "title load returns saved progress not a new game")
	expect(not current_scene._dialogue.is_open() and not state.resume_from_save, "load consumes resume flag without startup event replay")
	current_scene.queue_free()
	current_scene = null
	await frames(3)
	await finish()


func malformed_cases(source: Dictionary) -> void:
	for field in ["map_id", "player_direction", "gold", "actors", "inventory", "party", "testing", "switches", "variables", "self_switches", "play_seconds", "menu_disabled"]:
		var bad := source.duplicate(true)
		bad[field] = null
		expect(not codec.prepare(bad).ok, "reject missing/wrong typed " + field)
	for field in ["id", "class_id", "level", "experience", "hp", "equipment", "skill_ids", "state_ids", "name"]:
		var bad := source.duplicate(true)
		bad.actors[0][field] = null
		expect(not codec.prepare(bad).ok, "reject actor field " + field)
	var bad := source.duplicate(true)
	bad.player_x = 999999
	expect(not codec.prepare(bad).ok, "reject out of bounds position")
	bad = source.duplicate(true)
	bad.actors[0].equipment[0] = 999999
	expect(not codec.prepare(bad).ok, "reject missing equipment")
	bad = source.duplicate(true)
	bad.actors[0].skill_ids = [999999]
	expect(not codec.prepare(bad).ok, "reject missing skill")
	bad = source.duplicate(true)
	bad.inventory["item:999999"] = 1
	expect(not codec.prepare(bad).ok, "reject missing inventory item")
	bad = source.duplicate(true)
	bad.inventory[bad.inventory.keys()[0]] = 100
	expect(not codec.prepare(bad).ok, "reject inventory overflow")
	bad = source.duplicate(true)
	bad.testing.definitions.Skills[0].name = "changed"
	expect(not codec.prepare(bad).ok, "reject changed test definitions")
	var before: String = JSON.stringify(codec.capture(state), "", true)
	expect(not saves.load_slot(3, state).ok and JSON.stringify(codec.capture(state), "", true) == before, "compatibility failure cannot partially commit state")


func standard_fixture() -> void:
	var original_cache: Dictionary = data._cache.duplicate()
	var values: Array = []
	for level in 100: values.append_array([100 + level, 40, 20, 10, 15, 18])
	var first := {"id": 1, "name": "标准角色", "class_id": 1, "initial_level": 2, "final_level": 99, "exp_basis": 30, "exp_inflation": 30,
		"parameters": {"x_size": 6, "y_size": 100, "values": values}, "weapon_id": 1, "armor1_id": 1}
	var second := first.duplicate(true)
	second.id = 2
	var fixture := {"Actors": [null, first, second], "Classes": [null, {"id": 1, "learnings": [{"level": 1, "skill_id": 1}]}, {"id": 2, "name": "其他职业"}],
		"Skills": [null, {"id": 1}], "Weapons": [null, {"id": 1, "atk": 10}], "Armors": [null, {"id": 1, "kind": 0, "pdef": 5}], "States": [null, {"id": 1, "maxhp_rate": 150}]}
	for database in fixture: data._cache["res://data/database/%s.json" % database] = fixture[database]
	var fixture_before := JSON.stringify(fixture)
	var initialization := system.duplicate(true)
	initialization.party_members = [1]
	state.begin_new_game(initialization, {"enabled": false})
	var actor: RefCounted = state.actor(1)
	actor.actor_name = "已改名"
	actor.hp = 17
	actor.state_ids.assign([1])
	state.actor(2).hp = 5
	var saved: Dictionary = codec.capture(state)
	var prepared: Dictionary = codec.prepare(saved)
	expect(prepared.ok and prepared.actors[1].level == 2 and prepared.actors[1].experience == 30, "standard fixture restores level and cumulative experience")
	expect(prepared.ok and prepared.actors[1].snapshot().parameters.maxhp == 153 and prepared.actors[1].hp == 17, "restored state IDs participate in standard parameters without healing")
	expect(prepared.ok and prepared.actors[1].equipment == [1, 1, 0, 0, 0] and prepared.actors[1].actor_name == "已改名", "standard fixture retains slots and renamed actor")
	expect(prepared.ok and prepared.actors[2].hp == 5 and prepared.state.party == [1], "off-party actor state included without joining party")
	var bad := saved.duplicate(true)
	bad.actors[0].experience = 0
	expect(not codec.prepare(bad).ok, "standard fixture rejects inconsistent experience")
	bad = saved.duplicate(true)
	bad.actors[0].hp = 154
	expect(not codec.prepare(bad).ok, "standard fixture rejects HP exceeding status-adjusted cap")
	bad = saved.duplicate(true)
	bad.actors[0].skill_ids = [1, 1]
	expect(not codec.prepare(bad).ok, "standard fixture rejects duplicate learned skill IDs")
	bad = saved.duplicate(true)
	bad.actors[0].level = 99
	bad.actors[0].experience = actor._experience_curve[99]
	expect(codec.prepare(bad).ok, "standard fixture supports maximum level")
	expect(JSON.stringify(fixture) == fixture_before, "save preparation leaves fixture database immutable")
	data._cache = original_cache


func frames(count: int) -> void:
	for _index in count: await process_frame


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)


func finish() -> void:
	paused = false
	await create_timer(0.2).timeout
	for failure in failures: printerr("FAIL: ", failure)
	print("SAVE TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

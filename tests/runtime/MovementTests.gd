extends SceneTree
var failures: Array[String] = []
var checks := 0
var motion_script: Script
var fixture_script: Script
var state: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: movement test timeout"); quit(1))
	motion_script = load("res://runtime/scripts/CharacterMotion.gd")
	fixture_script = load("res://runtime/scripts/MovementFixture.gd")
	state = root.get_node("RuntimeState")
	test_motion()
	await test_map()
	await test_player()
	for failure in failures: printerr("FAIL: ", failure)
	print("MOVEMENT TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)


func test_motion() -> void:
	var motion: RefCounted = motion_script.new()
	expect(motion.is_idle() and motion.options.move_speed == 4 and motion.pixels_per_second() == 160, "default speed4 is 160 native pixels/sec")
	for rate in [30, 40, 60, 120]:
		motion.reset()
		expect(motion.begin_move(6), "cardinal start at FPS %d" % rate)
		for frame in int(rate / 10): motion.advance(1.0 / rate)
		expect(motion.visual_cell.is_equal_approx(Vector2(0.5, 0)) and motion.cell == Vector2i.ZERO, "half tile independent of FPS %d" % rate)
		for frame in int(rate / 10): motion.advance(1.0 / rate)
		expect(motion.cell == Vector2i(1, 0) and motion.is_idle(), "exact tile endpoint independent of FPS %d" % rate)
	for speed in range(1, 7):
		motion.reset()
		motion.configure({"move_speed": speed})
		motion.begin_move(2)
		motion.advance(32.0 / motion.pixels_per_second())
		expect(motion.cell == Vector2i.DOWN and motion.is_idle(), "speed range exact endpoint %d" % speed)
	var before: Dictionary = motion.snapshot()
	for invalid in [{"move_speed": 0}, {"move_speed": 7}, {"move_speed": 4.5}, {"opacity": 256}, {"opacity": NAN}, {"blend_type": 3}, {"idle_pattern": -1}, {"through": 1}, {"custom": 1}]:
		expect(not motion.configure(invalid).ok and motion.snapshot() == before, "invalid option is atomic")
	motion.reset()
	motion.configure({"direction_fix": true})
	motion.begin_move(6)
	expect(motion.direction == 2 and motion.target == Vector2i.RIGHT, "direction fix prevents turning, not movement")
	expect(not motion.begin_move(8), "overlapping move does not replace active interpolation")
	expect(motion.advance(4) == "walk" and motion.advance(4) == "", "long frame finishes once")
	motion.configure({"step_anime": true})
	motion.advance(0.5)
	expect(motion.pattern > 0, "step animation while idle")
	motion.configure({"step_anime": false, "walk_anime": false, "idle_pattern": 2})
	motion.advance(0.2)
	expect(motion.pattern == 2, "stopped frame is configurable")
	motion.begin_move(2)
	motion.advance(0.2)
	expect(motion.pattern == 2, "disabled walk animation keeps frame")
	motion.reset()
	motion.begin_jump(Vector2i(2, 0))
	motion.advance(0.2)
	expect(motion.jumping() and motion.jump_height > 0 and motion.cell == Vector2i.ZERO, "jump has independent arc and logical landing")
	expect(motion.advance(2) == "jump" and motion.cell == Vector2i(2, 0) and motion.jump_height == 0, "jump endpoint exact and height cleared")
	motion.begin_move(2)
	motion.relocate(Vector2i(7, 6))
	expect(motion.is_idle() and motion.visual_cell == Vector2(7, 6), "relocation cancels old movement")
	before = motion.snapshot()
	motion.advance(NAN)
	motion.advance(-1)
	expect(motion.snapshot() == before, "invalid time cannot corrupt motion")
	before.options.through = true
	expect(not motion.options.through, "motion query has detached settings")


func test_map() -> void:
	var fixture: Dictionary = fixture_script.build()
	var before := JSON.stringify(fixture)
	var map: Node2D = load("res://runtime/scripts/MapRuntime.gd").new()
	root.add_child(map)
	map.load_definition(fixture.map, fixture.tileset)
	map.set_process(false)
	var avatar: Node2D = load("res://runtime/scripts/MapCharacter.gd").new()
	avatar.map_runtime = map
	map.ensure_character_layer().add_child(avatar)
	avatar.set_process(false)
	avatar.set_graphic("@movement_character")
	avatar.move_to(2, 4)
	map.player_character = avatar
	expect(map.valid(1, 1) and not map.valid(-1, 1) and not map.valid(12, 0), "map bounds query")
	expect(map.tile_id(2, 2, 0) == 386 and map.tile_id(-1, 2, 0) == 0 and map.tile_id(2, 2, 4) == 0, "layer lookup and invalid coordinates")
	expect(map.terrain_tag(2, 2) == 7 and map.terrain_tag(7, 2) == 0, "terrain tags come from database table")
	expect(map.is_bush(2, 2) and not map.is_bush(0, 0) and map.is_counter(5, 4), "bush/counter flags distinct from passage bits")
	expect(not map.can_move(Vector2i(1, 1), Vector2i.LEFT) and map.can_move(Vector2i(1, 1), Vector2i.LEFT, true), "through bypasses wall")
	expect(not map.can_move(Vector2i(0, 1), Vector2i.LEFT, true) and not map.can_move(Vector2i(1, 1), Vector2i(1, 1)), "through still obeys bounds and cardinal directions")
	expect(not map.can_move(Vector2i(2, 6), Vector2i.RIGHT) and not map.can_move(Vector2i(3, 6), Vector2i.LEFT), "source exit and reverse destination direction checked")
	expect(map.can_move(Vector2i(2, 6), Vector2i.LEFT), "one-way tile does not block unrelated directions")
	expect(not map.can_move(Vector2i(5, 2), Vector2i.DOWN), "named character occupies its tile")
	var events: Array = []
	map.event_requested.connect(func(_commands: Array, id: int) -> void: events.append(id))
	expect(map.request_action(Vector2i(5, 5), Vector2i.UP) and events == [1], "interaction reaches person across a counter")
	expect(map.request_action(Vector2i(7, 7), Vector2i.UP) and events.back() == 3, "front interaction reaches adjacent person")
	expect(not map.request_action(Vector2i(2, 7), Vector2i.UP), "action does not start touch-only marker")
	expect(map.trigger_player_touch(Vector2i(2, 7)) and events.back() == 2, "landing on underfoot trigger")
	expect(not map.trigger_player_touch(Vector2i(2, 7), true), "blocked movement does not start an underfoot trigger")
	expect(map.event_ids_at(5, 3) == [1], "event ID lookup is spatially indexed")
	var ids: Array = map.event_ids_at(5, 3)
	ids.clear()
	expect(map.event_ids_at(5, 3) == [1], "query does not mutate spatial index")
	var npc: Node2D = map.animation_target(1)
	expect(npc.move_straight(4), "native event character can use same movement component")
	expect(map.event_ids_at(4, 3) == [1] and map.event_ids_at(5, 3) == [1], "moving character reserves both cells")
	npc.advance_motion(0.2)
	expect(map.event_ids_at(5, 3).is_empty() and map.event_ids_at(4, 3) == [1], "arrival releases source reservation")
	map.refresh_events()
	expect(npc.tile_position == Vector2i(4, 3), "same-page refresh does not reset native position")
	expect(avatar.move_straight(6), "ordinary move begins")
	avatar.advance_motion(0.1)
	expect(avatar.position.is_equal_approx(Vector2(96, 144)) and avatar.tile_position == Vector2i(2, 4), "visual halfway vs logical grid distinct")
	avatar.advance_motion(0.1)
	expect(avatar.tile_position == Vector2i(3, 4), "ordinary arrival commits target")
	expect(not avatar.move_to(-1, 0) and avatar.tile_position == Vector2i(3, 4), "invalid native relocation rejected")
	expect(not avatar.jump(-5, 0), "jump cannot leave map")
	avatar.move_to(5, 5)
	expect(avatar.jump(0, -3), "jump may cross obstacle to legal landing")
	avatar.advance_motion(2)
	expect(avatar.tile_position == Vector2i(5, 2), "native jump lands correctly")
	expect(not map.load_map(999999) and JSON.stringify(map.map_data) == JSON.stringify(fixture.map), "missing map leaves current instance intact")
	expect(JSON.stringify(fixture) == before, "map/character setup never modifies source definitions")
	var tile_fixture := fixture.duplicate(true)
	var tile_event: Dictionary = fixture_script.event(6, 6, "", 0, "图块事件")
	tile_event.pages[0].graphic.tile_id = 385
	tile_fixture.map.events["4"] = tile_event
	map.load_definition(tile_fixture.map, tile_fixture.tileset)
	expect(not map.can_move(Vector2i(6, 5), Vector2i.DOWN), "tile-event graphic obeys its passage metadata")
	expect(map.animation_target(4)._texture != null, "tile-event graphic has an actual texture")
	map.queue_free()
	await frames(3)


func test_player() -> void:
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	state.begin_new_game(data.system())
	state.resume_from_save = true # This test is not testing the sample's startup event.
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	var fixture: Dictionary = fixture_script.build()
	game._map.load_definition(fixture.map, fixture.tileset)
	game._player.move_to(2, 4)
	game._player.set_process(false)
	expect(game._player.motion == state.player_motion, "RuntimeState and player share one motion state")
	expect(game._player.get_index() == game._map.character_layer.get_child_count() - 1, "equal-depth leader renders above same-cell events without bypassing foreground sort")
	expect(state.player() == game._player, "native player accessor returns the live scene character")
	game._player.move_speed = 3
	game._player.direction_fix = true
	expect(state.player_motion.options.move_speed == 3 and state.player_motion.options.direction_fix, "native properties use the same validated player options")
	game._player.configure_motion(motion_script.DEFAULTS)
	game._update_camera_limits()
	var view: Vector2 = game.get_viewport_rect().size
	expect(game._camera.limit_right - game._camera.limit_left == maxi(384, int(view.x)) and game._camera.limit_bottom - game._camera.limit_top == maxi(288, int(view.y)), "small map camera is centered within the logical viewport")
	var steps_before: int = state.steps
	expect(game._player.move_straight(6), "real player starts walking")
	game._player._process(0.1)
	expect(state.player_x == 2 and state.steps == steps_before and not game._menus.can_open(), "half step does not commit grid/steps or open menu")
	expect(not load("res://runtime/scripts/SaveService.gd").save_slot(1, state).ok, "direct save rejects in-flight motion before writing")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._menus._input(escape)
	expect(game._menus._pending_menu and game._player.stop_after_step, "mid-step Esc queues menu and stops next held step")
	game._player._process(0.1)
	game._menus._process(0)
	expect(state.player_x == 3 and state.steps == steps_before + 1 and game._menus.menu != null, "arrival counts once and then opens queued menu")
	var position: Vector2 = game._player.position
	await frames(5)
	expect(game._player.position == position and state.steps == steps_before + 1, "paused menu preserves exact settled position")
	var menu: Control = game._menus.menu
	menu.open_test_tools()
	for index in 4: menu.navigate(1)
	menu.activate()
	expect(menu.page == "movement_tools", "F6 exposes isolated native movement area")
	var tools: Control = menu._commerce
	expect(tools._speed.get_line_edit().focus_mode == Control.FOCUS_CLICK and tools._speed.editable and tools._speed.gui_input.is_connected(tools._release_speed_focus), "speed spinner releases native mouse focus while keeping its arrows editable")
	var flags := JSON.stringify([state.switches, state.variables, state.inventory, state.party])
	expect(tools.map != game._map and tools.avatar.motion != state.player_motion, "testing area is not the live map or live motion")
	tools.avatar.move_straight(6)
	tools.avatar.advance_motion(0.2)
	tools._speed.value = 6
	tools.action(2)
	expect(state.player_motion.options.move_speed == 6 and state.player_x == 3 and state.steps == steps_before + 1, "apply preview settings without relocating real player or adding steps")
	expect(JSON.stringify([state.switches, state.variables, state.inventory, state.party]) == flags, "verification area leaves inventory/switches/variables/party unchanged")
	var codec: Script = load("res://runtime/scripts/SaveCodec.gd")
	var snapshot: Dictionary = codec.capture(state)
	var prepared: Dictionary = codec.prepare(snapshot)
	expect(prepared.ok and prepared.state.player_options.move_speed == 6, "player settings roundtrip through save validation")
	var legacy := snapshot.duplicate(true)
	legacy.erase("player_options")
	var decoded: Dictionary = codec.prepare(legacy)
	expect(decoded.ok and decoded.state.player_options == motion_script.DEFAULTS, "old native save gets default player settings")
	for bad in [null, {}, {"move_speed": 8}, {"through": "yes"}]:
		var invalid := snapshot.duplicate(true)
		invalid.player_options = bad
		expect(not codec.prepare(invalid).ok and state.player_motion.options.move_speed == 6, "bad saved movement settings reject without partial commit")
	state.restore_prepared(prepared)
	expect(game._player.motion == state.player_motion and state.player_motion.options.move_speed == 6, "restoring uses shared motion identity")
	game._menus.close_menu()
	game._player.move_to(1, 1)
	game._player._move_cooldown = 0
	Input.action_press("ui_left")
	game._player._process(0.1)
	Input.action_release("ui_left")
	expect(state.player_x == 1 and state.steps == steps_before + 1 and state.player_direction == 4, "blocked move turns without a step")
	state.begin_new_game(data.system())
	expect(state.player_motion.options == motion_script.DEFAULTS, "new game resets testing/native player options")
	game.queue_free()
	expect(state.player() == null, "queued old game cannot leak a usable player accessor")
	current_scene = null
	await frames(4)
	expect(state.player() == null, "freed old game has no player reference")


func frames(count: int) -> void:
	for index in count: await process_frame


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

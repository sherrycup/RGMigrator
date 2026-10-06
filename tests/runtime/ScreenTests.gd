extends SceneTree
var failures: Array[String] = []
var checks := 0
var state: Node
var picture_script: Script
var screen_script: Script
var codec: Script


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(50).timeout.connect(func() -> void: printerr("FAIL: screen test timeout"); quit(1))
	state = root.get_node("RuntimeState")
	picture_script = load("res://runtime/scripts/PictureState.gd")
	screen_script = load("res://runtime/scripts/ScreenState.gd")
	codec = load("res://runtime/scripts/SaveCodec.gd")
	var screen: RefCounted = screen_script.new()
	expect(screen.picture_ids().is_empty() and screen.effects_snapshot().shake == 0, "neutral initial state")
	expect(screen.show_picture(1, "测试图", {"x": 20, "y": 40}).ok and screen.show_picture(50, "尾图").ok, "map IDs 1..50")
	var first: RefCounted = screen.picture(1)
	expect(first.snapshot().origin == 0 and first.snapshot().blend_type == 0 and first.snapshot().zoom_x == 100, "standard pose defaults")
	var saved: Dictionary = screen.snapshot()
	for invalid in [0, 51, -1]: expect(not screen.show_picture(invalid, "无效").ok and screen.snapshot() == saved, "invalid ID atomic")
	for invalid in ["", "../escape", "a/../b", "C:/bad", "a\\b", "x\n"]: expect(not screen.show_picture(1, invalid).ok and screen.snapshot() == saved, "safe asset names")
	for pose in [{"origin": 2}, {"blend_type": 3}, {"opacity": 256}, {"x": NAN}, {"y": INF}, {"zoom_x": -1}, {"unknown": 1}]:
		expect(not first.move(pose, 1).ok and screen.snapshot() == saved, "invalid pose rejected")
	expect(not first.move({}, -1).ok and not first.rotate(NAN).ok and not first.start_tone_change([0, 0, 0], 1).ok, "invalid effect parameters")
	expect(first.move({"x": 120, "y": 140, "zoom_x": 200, "zoom_y": 50, "opacity": 55, "origin": 1, "blend_type": 2}, 2).ok, "timed move starts")
	expect(first.snapshot().origin == 1 and first.snapshot().blend_type == 2 and first.snapshot().x == 20, "origin/blend immediate, position interpolated")
	first.rotate(-90)
	first.start_tone_change([-100, 100, 0, 200], 2)
	screen.advance(1)
	var view: Dictionary = first.snapshot()
	expect(view.x == 70 and view.y == 90 and view.zoom_x == 150 and view.zoom_y == 75 and view.opacity == 155, "linear independent pose interpolation")
	expect(view.tone[0] == -50 and view.tone[3] == 100 and view.angle == 270, "tone interpolation and negative rotation wrap")
	expect(screen.picture(50).snapshot().x == 0, "other ID unaffected")
	screen.advance(5)
	view = first.snapshot()
	expect(view.x == 120 and view.opacity == 55 and view.move_remaining == 0 and view.tone_remaining == 0 and view.tone[0] == -100, "long frame reaches exact endpoints")
	first.move({"x": 200}, 0)
	expect(first.snapshot().x == 200, "zero duration is immediate")
	first.move({"x": 400}, 2)
	screen.advance(0.5)
	first.move({"x": 100}, 1)
	screen.advance(0.5)
	expect(first.snapshot().x == 175, "new tween starts from current interpolated value")
	var detached: Dictionary = screen.snapshot()
	detached.pictures[0].tone[0] = 255
	detached.pictures.clear()
	expect(screen.picture_ids().size() == 2 and first.snapshot().tone[0] == -100, "deep snapshot does not mutate model")
	screen.start_tone_change([-100, 20, 80, 200], 2)
	screen.start_flash([255, 100, 50, 200], 2)
	screen.start_shake(10, 1, 2)
	screen.advance(0.25)
	var effects: Dictionary = screen.effects_snapshot()
	expect(effects.tone[0] == -12.5 and effects.flash_color[3] == 175 and is_equal_approx(effects.shake, 10), "screen time-driven tone/flash/shake")
	var snapshot: Dictionary = screen.snapshot()
	var decoded: Dictionary = screen_script.decode(JSON.parse_string(JSON.stringify(snapshot)))
	expect(decoded.ok, "JSON screen roundtrip validates")
	if not decoded.ok:
		printerr("FAIL: ", decoded.message)
		quit(1)
		return
	var restored: RefCounted = decoded.screen
	screen.advance(0.375)
	restored.advance(0.375)
	expect(equivalent(restored.snapshot(), screen.snapshot()), "mid-transition restore continues identical timeline")
	for _i in 40: restored.advance(0.25)
	expect(restored.effects_snapshot().shake == 0 and restored.effects_snapshot().flash_color[3] == 0, "effects finish without residual offset/flash")
	saved = screen.snapshot()
	expect(not screen.start_shake(101, 1, 1).ok and not screen.start_flash([0, 0, 0, 256], 1).ok and not screen.start_tone_change([0, 0, 0, -1], 1).ok and screen.snapshot() == saved, "screen effect validation atomic")
	screen.show_picture(1, "替换", {"opacity": 123})
	expect(screen.picture(1) != first and screen.picture(1).snapshot().rotate_speed == 0 and screen.picture(1).snapshot().tone_remaining == 0 and screen.picture(50) != null, "replacement resets only same ID")
	screen.erase_picture(1)
	expect(screen.picture(1) == null and screen.picture(50) != null and screen.erase_picture(1).ok, "erase is independent and idempotent")
	for field in ["tone", "tone_target", "flash_color", "shake", "shake_phase", "shake_speed", "shake_power", "tone_remaining", "flash_remaining", "shake_remaining", "pictures"]:
		var broken: Dictionary = snapshot.duplicate(true)
		broken[field] = null
		expect(not screen_script.decode(broken).ok, "corrupt screen rejected: " + field)
	for field in ["number", "name", "origin", "x", "zoom_y", "opacity", "angle", "rotate_speed", "tone", "tone_target", "move_target", "move_remaining", "tone_remaining"]:
		var broken: Dictionary = snapshot.duplicate(true)
		broken.pictures[0][field] = null
		expect(not screen_script.decode(broken).ok, "corrupt picture rejected: " + field)
	var duplicate: Dictionary = snapshot.duplicate(true)
	duplicate.pictures.append(duplicate.pictures[0].duplicate(true))
	expect(not screen_script.decode(duplicate).ok, "duplicate picture IDs rejected")
	var expired: Dictionary = snapshot.duplicate(true)
	expired.flash_remaining = 0
	expect(not screen_script.decode(expired).ok, "finished flash cannot keep opaque overlay")
	expired = snapshot.duplicate(true)
	expired.shake_remaining = 0
	expect(not screen_script.decode(expired).ok, "finished shake cannot keep camera offset")
	await check_live_game()
	for failure in failures: printerr("FAIL: ", failure)
	print("SCREEN TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)


func check_live_game() -> void:
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	state.begin_new_game(data.system())
	expect(state.show_picture(1, "@test_picture", {"x": 100, "y": 400, "origin": 1}).ok, "native test asset available without RTP")
	var before: Dictionary = state.screen.snapshot()
	expect(not state.show_picture(1, "__missing_picture__").ok and state.screen.snapshot() == before, "missing asset leaves original picture intact and reports")
	state.move_picture(1, {"x": 300}, 4)
	state.rotate_picture(1, 60)
	state.tint_picture(1, [-10, 40, 20, 90], 2)
	state.screen.start_tone_change([-20, -20, 0, 60], 3)
	state.screen.start_flash([255, 100, 100, 180], 2)
	state.screen.start_shake(12, 3, 3)
	state.screen.advance(0.25)
	var captured: Dictionary = codec.capture(state)
	var prepared: Dictionary = codec.prepare(JSON.parse_string(JSON.stringify(captured)))
	expect(prepared.ok and prepared.screen != state.screen, "save validation builds detached screen candidate")
	if not prepared.ok:
		printerr("FAIL: ", prepared.message)
		return
	before = state.screen.snapshot()
	var bad: Dictionary = captured.duplicate(true)
	bad.screen.pictures[0].opacity = INF
	expect(not codec.prepare(bad).ok and state.screen.snapshot() == before, "bad picture save cannot mutate live state")
	var legacy: Dictionary = captured.duplicate(true)
	legacy.erase("screen")
	var older: Dictionary = codec.prepare(legacy)
	expect(older.ok and older.screen.picture_ids().is_empty() and older.screen.effects_snapshot().shake == 0, "older native schema-1 save defaults neutral")
	state.restore_prepared(prepared)
	expect(JSON.stringify(state.screen.snapshot()) == JSON.stringify(before), "restore keeps pose/effects/in-flight transitions")
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(4)
	expect(game._screen_renderer.sprites.size() == 1, "renderer creates restored picture")
	var map_identity: int = game._map.get_instance_id()
	var position: Vector2 = game._player.position
	var direction: Vector2i = game._player.facing
	var flags := JSON.stringify([state.inventory, state.switches, state.variables, state.party])
	var menus: Node = game._menus
	expect(menus.open_menu(), "idle map can open menu")
	before = state.screen.snapshot()
	await frames(8)
	expect(state.screen.snapshot() == before, "normal menu pauses effect clock")
	var menu: Control = menus.menu
	menu.open_test_tools()
	for _i in 3: menu.navigate(1)
	menu.activate()
	expect(menu.page == "screen_tools", "F6 hub exposes picture/screen tools")
	var lab: Control = menu._commerce
	await frames(6)
	expect(state.screen.snapshot() != before, "test lab explicitly advances paused effects")
	lab.select_asset("@test_picture")
	lab.action(11)
	lab.action(1)
	await frames(3)
	expect(state.screen.picture_ids().size() == 2 and game._screen_renderer.sprites.size() == 2, "dual picture lab uses independent renderer instances")
	for action_index in range(2, 11):
		lab.action(action_index)
		if action_index == 6: expect(state.screen.picture(1).snapshot().tone_target[0] == -80, "test picture-tone button actually starts non-neutral tone")
		if action_index == 7: expect(state.screen.effects_snapshot().tone_target[0] == -80, "test map-tone button actually starts non-neutral tone")
	lab.action(0)
	lab.action(6)
	lab.action(6)
	expect(state.screen.picture(1).snapshot().tone_target[0] == 0, "second picture-tone click restores neutral even mid-transition")
	lab.action(7)
	expect(state.screen.effects_snapshot().tone_target[0] == 0, "second map-tone click restores neutral even mid-transition")
	lab.action(10)
	expect(state.screen.picture(1) == null and state.screen.picture(2) != null, "tools exercise all picture/screen operations")
	menu.back()
	before = state.screen.snapshot()
	await frames(6)
	expect(state.screen.snapshot() == before, "returning to ordinary menu pauses lab clock again")
	menus.close_menu()
	await frames(4)
	expect(game._map.get_instance_id() == map_identity and game._player.position == position and game._player.facing == direction and JSON.stringify([state.inventory, state.switches, state.variables, state.party]) == flags, "menu preserves map identity/player/game data")
	before = state.screen.snapshot()
	expect(game._map.transfer(state.map_id, state.player_x, state.player_y) and state.screen.snapshot() == before, "map transfer keeps screen state")
	# Existing erase-picture command still works; show/move/tone are not newly connected.
	var interpreter: RefCounted = load("res://runtime/scripts/EventInterpreter.gd").new()
	interpreter.map_runtime = game._map
	interpreter.start([{"code": 235, "indent": 0, "parameters": [2]}, {"code": 0, "indent": 0, "parameters": []}], 1)
	await frames(2)
	expect(game._screen_renderer.sprites.is_empty(), "existing erase path removes only picture node")
	var messages: Array[String] = []
	interpreter.diagnostic_requested.connect(func(message: String) -> void: messages.append(message))
	for code in [231, 232, 233, 234, 223, 224, 225]:
		interpreter.start([{"code": code, "indent": 0, "parameters": []}, {"code": 122, "indent": 0, "parameters": [999, 999, 0, 0, 7]}], 1)
		expect(not interpreter.running and not messages.is_empty() and messages.back().contains("指令 %d" % code) and not state.variables.has("999"), "deferred event remains diagnosed and stops: %d" % code)
	menus.return_to_title()
	await frames(4)
	expect(not state.playing and current_scene.get_script() == load("res://runtime/scripts/Title.gd"), "title leaves renderer lifecycle")
	state.begin_new_game(data.system(), {"enabled": false})
	expect(state.screen.picture_ids().is_empty() and state.screen.effects_snapshot().tone[0] == 0 and not state.show_picture(1, "@test_picture").ok, "new game resets screen and formal mode blocks synthetic test asset")
	current_scene.queue_free()
	current_scene = null
	await frames(3)
	await create_timer(0.2).timeout


func frames(count: int) -> void:
	for _i in count: await process_frame


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func equivalent(first: Variant, second: Variant) -> bool:
	# JSON decimal round-trips may change the last bit of sinusoidal shake values.
	if (first is int or first is float) and (second is int or second is float): return is_equal_approx(float(first), float(second))
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size(): return false
		for key in first:
			if not second.has(key) or not equivalent(first[key], second[key]): return false
		return true
	if first is Array and second is Array:
		if first.size() != second.size(): return false
		for index in first.size():
			if not equivalent(first[index], second[index]): return false
		return true
	return first == second

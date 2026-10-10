extends SceneTree
var failures: Array[String] = []
var checks := 0
var state: Node
var data: Script
var interpreter_script: Script
var catalog: Script

func _initialize() -> void: call_deferred("run")

func run() -> void:
	state = root.get_node("RuntimeState")
	data = load("res://runtime/scripts/RuntimeData.gd")
	interpreter_script = load("res://runtime/scripts/EventInterpreter.gd")
	catalog = load("res://runtime/scripts/EventCommandCatalog.gd")
	state.begin_new_game(data.system())
	parameters_and_atomicity()
	timelines()
	weather_and_saves()
	await integration()
	state.audio.stop_all()
	await frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT SCREEN TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func parameters_and_atomicity() -> void:
	var valid := [[221, []], [222, [""]], [223, [tone(-40, 20, 0, 100), 20]], [224, [color(255, 80, 20, 160), 20]],
		[225, [5, 4, 20]], [231, [1, "@test_picture", 1, 0, -10, 20, 150, 80, 200, 2]],
		[232, [1, 20, 0, 1, 41, 42, 100, 100, 255, 0]], [233, [50, -90]], [234, [50, tone(0, 0, 0, 0), 0]], [235, [50]], [236, [3, 9, 40]]]
	for item in valid: expect(catalog.reason(item[0], item[1]).is_empty(), "native parameter shape supported %d" % item[0])
	expect(catalog.color_values(tone(-20, 30, 40, 50)) == [-20.0, 30.0, 40.0, 50.0], "native Tone decoded in channel order")
	expect(catalog.color_values(color(20, 30, 40, 50), false) == [20.0, 30.0, 40.0, 50.0], "native Color uses alpha, not gray")
	var invalid := [[221, [1]], [222, ["../escape"]], [222, [20, "mask"]], [223, [color(0, 0, 0, 0), 20]],
		[223, [tone(-256, 0, 0, 0), 20]], [224, [color(0, 0, 0, 256), 20]], [224, [color(0, 0, 0, 10), 1.5]],
		[225, [10, 4, 20]], [225, [5, -1, 20]], [231, [0, "@test_picture", 0, 0, 1, 2, 100, 100, 255, 0]],
		[231, [51, "@test_picture", 0, 0, 1, 2, 100, 100, 255, 0]], [231, [1, "../bad", 0, 0, 1, 2, 100, 100, 255, 0]],
		[232, [1, 20, 2, 0, 1, 2, 100, 100, 255, 0]], [232, [1, 20, 0, 1, 0, 1, 100, 100, 255, 0]],
		[232, [1, 20, 0, 0, 1, 2, 100, 100, 256, 0]], [233, [1, 91]], [234, [1, tone(0, 0, 0, -1), 20]],
		[235, []], [236, [4, 1, 20]], [236, [1, 10, 20]], [236, [1, 1, NAN]]]
	state.show_picture(1, "@test_picture", {"x": 90})
	for item in invalid:
		var before: Dictionary = state.screen.snapshot()
		var reported := {"text": ""}
		var owner: RefCounted = interpreter_script.new()
		owner.diagnostic_requested.connect(func(message: String) -> void: reported.text = message)
		owner.start([c(item[0], item[1]), c(0)], 7, 2)
		expect(not reported.text.is_empty() and state.screen.snapshot() == before, "invalid screen command is atomic %d" % item[0])
		var compact: String = reported.text.replace(" ", "")
		expect(compact.contains("事件7") and compact.contains("第2页") and compact.contains("指令%d" % item[0]), "screen error keeps source location")
	var missing := {"text": ""}
	var owner: RefCounted = interpreter_script.new()
	owner.diagnostic_requested.connect(func(message: String) -> void: missing.text = message)
	owner.start([c(231, [1, "__missing_picture__", 0, 0, 0, 0, 100, 100, 255, 0]), c(0)], 7)
	expect(not missing.text.is_empty() and state.screen.picture(1).snapshot().x == 90, "missing picture does not replace original")
	state.variables["41"] = "bad"
	owner.start([c(232, [1, 20, 0, 1, 41, 42, 100, 100, 255, 0]), c(0)], 7)
	expect(state.screen.picture(1).snapshot().move_remaining == 0 and missing.text.contains("变量"), "bad variable coordinates cannot partially change picture")
	state.variables.erase("41")
	owner.start([c(231, [1, "", 0, 0, 0, 0, 100, 100, 255, 0]), c(232, [1, 20, 0, 0, 100, 50, 100, 100, 255, 0]), c(233, [1, 2]), c(234, [1, tone(10, 20, 30, 0), 20]), c(235, [1]), c(0)], 7)
	expect(not owner.running and state.screen.picture(1) == null, "empty name and operations on unseen picture have native empty semantics")

func timelines() -> void:
	for rate in [30, 40, 60, 120]:
		state.screen = load("res://runtime/scripts/ScreenState.gd").new()
		var owner: RefCounted = interpreter_script.new()
		state.set_event_variable(41, -100); state.set_event_variable(42, 80)
		var commands := [c(231, [1, "@test_picture", 0, 0, 100, 40, 100, 100, 255, 0]),
			c(232, [1, 20, 1, 1, 41, 42, 200, 50, 100, 2]), c(233, [1, 3]), c(234, [1, tone(-100, 40, 80, 120), 20]),
			c(223, [tone(-80, 20, 60, 100), 20]), c(224, [color(255, 80, 20, 200), 20]), c(225, [5, 4, 20]),
			c(236, [3, 8, 40]), c(122, [43, 43, 0, 0, 1]), c(0)]
		var definition := commands.duplicate(true)
		owner.start(commands, 1)
		expect(not owner.running and state.variables.get("43", 0) == 1, "effects do not implicitly wait FPS%d" % rate)
		var start: Dictionary = state.screen.picture(1).snapshot()
		expect(start.origin == 1 and start.blend_type == 2 and start.x == 100, "origin/blend apply immediately while position interpolates")
		expect(start.rotate_speed == 60 and state.screen.effects_snapshot().shake_power == 10 and state.screen.effects_snapshot().shake_speed == 2, "native rotation/shake units converted exactly once")
		for index in int(rate / 2): state.screen.advance(1.0 / rate)
		var half: Dictionary = state.screen.picture(1).snapshot()
		expect(is_equal_approx(half.x, 0) and is_equal_approx(half.y, 60) and is_equal_approx(half.zoom_x, 150) and is_equal_approx(half.opacity, 177.5), "picture halfway FPS%d" % rate)
		expect(is_equal_approx(half.angle, 30) and is_equal_approx(half.tone[0], -50), "rotation and picture tone halfway FPS%d" % rate)
		var effects: Dictionary = state.screen.effects_snapshot()
		expect(is_equal_approx(effects.tone[0], -40) and is_equal_approx(effects.flash_color[3], 100), "screen tone/flash halfway FPS%d" % rate)
		expect(is_equal_approx(state.screen.weather_snapshot().weather_density, 18), "weather40 means1second, halfway density18 FPS%d" % rate)
		for index in int(rate / 2): state.screen.advance(1.0 / rate)
		var end: Dictionary = state.screen.picture(1).snapshot()
		expect(is_equal_approx(end.x, -100) and is_equal_approx(end.angle, 60) and is_equal_approx(end.tone[0], -100), "picture endpoints FPS%d" % rate)
		expect(is_zero_approx(state.screen.effects_snapshot().flash_color[3]) and is_zero_approx(state.screen.effects_snapshot().shake), "flash/shake finish without residual FPS%d" % rate)
		expect(state.screen.weather_snapshot().weather_density == 36 and state.screen.weather_snapshot().weather_remaining == 0, "weather endpoint FPS%d" % rate)
		expect(commands == definition, "native command definition stays read-only")
		owner.start([c(233, [1, -2]), c(0)], 1); state.screen.advance(0.5)
		expect(is_equal_approx(state.screen.picture(1).snapshot().angle, 40), "negative rotation uses native sign")
		owner.start([c(233, [1, 0]), c(0)], 1); state.screen.advance(0.5)
		expect(is_equal_approx(state.screen.picture(1).snapshot().angle, 40), "rotation0 stops")
	state.screen.start_shake(10, 2, 1); state.screen.advance(0.125)
	expect(is_equal_approx(state.screen.effects_snapshot().shake, 10), "native strength5 speed4 has10px peak and0.5sec period")
	var owner: RefCounted = interpreter_script.new()
	owner.start([c(223, [tone(-20, 30, 0, 0), 0]), c(224, [color(255, 0, 0, 100), 0]), c(236, [1, 0, 0]), c(0)], 1)
	expect(state.screen.effects_snapshot().tone == [-20.0, 30.0, 0.0, 0.0] and state.screen.effects_snapshot().flash_color[3] == 0 and state.screen.weather_snapshot().weather_density == 4, "zero duration is immediate and power0 is minimum weather")
	owner.start([c(236, [0, 0, 20]), c(0)], 1)
	state.screen.advance(0.25)
	expect(state.screen.weather_snapshot().weather_type == 1 and state.screen.weather_snapshot().weather_density == 2, "weather fade-out retains old type for0.5second")
	state.screen.advance(0.25)
	expect(state.screen.weather_snapshot().weather_type == 0 and state.screen.weather_snapshot().weather_density == 0, "weather turns off at completion")

func weather_and_saves() -> void:
	state.begin_new_game(data.system())
	state.screen.weather(3, 9, 2); state.screen.advance(0.5)
	var codec: Script = load("res://runtime/scripts/SaveCodec.gd")
	var saved: Dictionary = codec.capture(state)
	expect(saved.screen.has("weather") and not saved.map_effects.has("weather_type"), "save has one screen-owned weather state")
	var parsed: Dictionary = codec.prepare(JSON.parse_string(JSON.stringify(saved)))
	expect(parsed.ok and parsed.screen.weather_snapshot() == state.screen.weather_snapshot(), "screen weather saves halfway")
	var legacy := saved.duplicate(true)
	legacy.map_effects.merge(legacy.screen.weather, true); legacy.screen.erase("weather")
	var old: Dictionary = codec.prepare(legacy)
	expect(old.ok and old.screen.weather_snapshot() == state.screen.weather_snapshot() and not old.state.map_effects.has("weather_type"), "old map weather migrates and obsolete fields are stripped")
	if old.ok:
		old.screen.advance(0.5)
		expect(old.screen.weather_snapshot().weather_remaining == 1 and old.screen.weather_snapshot().weather_density == 20, "legacy halfway weather continues original timeline")
	var both := saved.duplicate(true); both.map_effects.merge(both.screen.weather, true)
	expect(codec.prepare(both).ok, "matching transitional weather copies normalize to one owner")
	both.map_effects.weather_remaining = 1
	var before: Dictionary = state.screen.snapshot()
	expect(not codec.prepare(both).ok and state.screen.snapshot() == before, "conflicting weather copies fail detached")
	for field in ["weather_type", "weather_remaining", "weather_density", "weather_target"]:
		var corrupt := saved.duplicate(true); corrupt.screen.weather[field] = -1
		expect(not codec.prepare(corrupt).ok and state.screen.snapshot() == before, "invalid weather save rejected " + field)
	var partial := legacy.duplicate(true); partial.map_effects.erase("weather_density")
	expect(not codec.prepare(partial).ok, "partial old weather fields cannot silently default")
	var inconsistent := saved.duplicate(true); inconsistent.screen.weather.weather_density_target = 2
	expect(not codec.prepare(inconsistent).ok and state.screen.snapshot() == before, "inconsistent weather density target fails detached")
	var empty := saved.duplicate(true); empty.screen.erase("weather")
	expect(codec.prepare(empty).screen.weather_snapshot().weather_type == 0, "old schema1 without any weather defaults neutral")
	state.restore_prepared(parsed)
	expect(state.screen.weather_snapshot() == saved.screen.weather, "restore adopts validated screen weather")
	state.begin_new_game(data.system())
	expect(state.screen.weather_snapshot().weather_type == 0, "new game clears weather")

func integration() -> void:
	state.begin_new_game(data.system()); state.resume_from_save = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game); current_scene = game
	await frames(3)
	game.reset_event_execution()
	var fixture: Dictionary = load("res://runtime/scripts/MovementFixture.gd").build()
	game._map.load_definition(fixture.map, fixture.tileset)
	game._events_enabled = true
	for node in [game, game._map, game._player, game._camera, game._screen_renderer, game._effects, game._transition]: node.set_process(false)
	for event in game._map.event_contexts(): event.node.set_process(false)
	state.screen.weather(1, 9, 2)
	game._effects.sync(0.5)
	expect(state.screen.weather_snapshot().weather_remaining == 2, "map renderer cannot advance formal weather clock")
	game._screen_renderer._process(0.5); game._effects.sync(0.5)
	expect(state.screen.weather_snapshot().weather_remaining == 1.5 and game._effects.weather.density == 10, "screen clock advances once and map renderer consumes it")
	expect(game._menus.open_menu(), "background screen effects allow normal menu")
	var before: Dictionary = state.screen.snapshot()
	game._screen_renderer._process(0.5); game._effects.sync(0.5)
	expect(state.screen.snapshot() == before, "ordinary menu pauses shared screen/weather clock")
	game._menus.close_menu()
	var tilesets: Variant = data.database("Tilesets")
	data._cache["res://data/database/Tilesets.json"] = [null, fixture.tileset]
	var destination: Dictionary = fixture.map.duplicate(true); destination.tileset_id = 1; destination.events = {}
	data._cache["res://data/maps/Map992.json"] = destination
	var screen: RefCounted = state.screen
	game._scheduler.start_main([c(201, [0, 992, 3, 4, 6, 1]), c(0)], 1)
	await frames(2); game._process(0)
	expect(state.map_id == 992 and state.screen == screen and state.screen.snapshot() == before and game._effects.screen_model == screen, "map transfer preserves screen weather instead of reinitializing")
	if DisplayServer.get_name() == "headless":
		state.set_event_variable(44, 0)
		game._scheduler.start_main([c(221), c(122, [44, 44, 0, 0, 1]), c(0)], 0)
		await frames(2); game._process(0)
		expect(not game._interpreter.running and state.variables.get("44", 0) == 0 and not game.event_screen_transition_active(), "headless capture reports failure and does not fake completion")
		game._dialogue.dismiss(); game._event_ui.cancel_all()
	var request: Dictionary = game.begin_event_screen_transition(222, "__missing_mask__")
	expect(not request.ok and not game.event_screen_transition_active(), "missing transition validated before any capture")
	state.begin_new_game(data.system()); game._process(0)
	expect(game._effects.screen_model == state.screen and state.screen.weather_snapshot().weather_type == 0, "new screen ownership propagates to renderer after reset")
	data._cache.erase("res://data/maps/Map992.json"); data._cache["res://data/database/Tilesets.json"] = tilesets
	game.queue_free(); current_scene = null
	await frames(3)

func c(code: int, p: Array = []) -> Dictionary: return {"code": code, "parameters": p, "indent": 0}
func tone(red: float, green: float, blue: float, gray: float) -> Dictionary: return {"_class": "Tone", "red": red, "green": green, "blue": blue, "gray": gray}
func color(red: float, green: float, blue: float, alpha: float) -> Dictionary: return {"_class": "Color", "red": red, "green": green, "blue": blue, "alpha": alpha}
func frames(count: int) -> void:
	for index in count: await process_frame
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

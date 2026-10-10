extends SceneTree
var failures: Array[String] = []
var checks := 0
var state: Node
var data: Script
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func frames(count: int = 2) -> void:
	for index in count: await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: printerr("FAIL: presentation timeout"); quit(1))
	state = root.get_node("RuntimeState")
	data = load("res://runtime/scripts/RuntimeData.gd")
	var view_script: Script = load("res://runtime/scripts/MapViewState.gd")
	var effects_script: Script = load("res://runtime/scripts/MapEffectsState.gd")
	for resolution in [Vector2(640, 480), Vector2(800, 480), Vector2(768, 768)]:
		var view: RefCounted = view_script.new()
		view.advance(0, Vector2(800, 600), Vector2(2048, 1536), resolution)
		expect(view.display.is_equal_approx(Vector2(800, 600) - resolution / 2), "large map centers in logical resolution %s" % resolution)
		view.advance(0, Vector2(-100, -100), Vector2(2048, 1536), resolution, true)
		expect(view.display == Vector2.ZERO, "upper left clamps without revealing exterior")
		view.advance(0, Vector2(9000, 9000), Vector2(2048, 1536), resolution, true)
		expect(view.display == Vector2(2048, 1536) - resolution, "lower right clamp uses visible area")
		view.advance(0, Vector2.ZERO, Vector2(320, 240), resolution, true)
		expect(view.display == (Vector2(320, 240) - resolution) / 2, "small map centered independently on both axes")
	var view: RefCounted = view_script.new()
	expect(view.configure({"view_rect": [160, 0, 640, 480], "follow_center": [240, 192]}).ok, "off-center UI area accepted")
	view.advance(0, Vector2(800, 600), Vector2(2048, 1536), Vector2(800, 480), true)
	expect(view.display == Vector2(560, 408) and view.view_rect(Vector2(800, 480)).position == Vector2(160, 0), "follow anchor is local, not whole-window center")
	var previous: Dictionary = view.snapshot()
	for invalid in [{"view_rect": [0, 0, 0, 480]}, {"follow_center": [700, 0]}, {"follow_center": [NAN, 1]}, {"x": 1}, {"follow_enabled": 1}]:
		expect(not view.configure(invalid).ok and view.snapshot() == previous, "bad view options atomic")
	expect(view.scroll(6, 4, 1, Vector2(2048, 1536), Vector2(800, 480)).ok, "manual native scroll starts")
	expect(not view.scroll(4, 1, 1, Vector2(2048, 1536), Vector2(800, 480)).ok, "overlapping scroll explicitly rejected")
	view.advance(0.5, Vector2.ZERO, Vector2(2048, 1536), Vector2(800, 480))
	expect(view.display == Vector2(624, 408) and not view.options.follow_enabled, "half scroll independent of player")
	var decoded: Dictionary = view_script.decode(view.snapshot())
	expect(decoded.ok and decoded.value.scroll_remaining == 0.5, "scroll remaining roundtrips")
	decoded.value.advance(0.5, Vector2.ZERO, Vector2(2048, 1536), Vector2(800, 480))
	expect(decoded.value.display == Vector2(688, 408), "restored scroll completes endpoint")
	view.resume_follow()
	expect(view.scroll_remaining == 0 and view.options.follow_enabled, "explicit follow resumes")
	for rate in [30, 40, 60, 120]:
		var effects: RefCounted = effects_script.new()
		var weather: RefCounted = load("res://runtime/scripts/WeatherState.gd").new()
		effects.configure({"fog_sx": 2, "fog_sy": -1, "fog_opacity": 128})
		effects.tint_fog([100, -20, 40, 80], 1)
		effects.fade_fog(0, 1)
		weather.weather(3, 8, 1)
		for index in rate:
			effects.advance(1.0 / rate)
			weather.advance(1.0 / rate)
		expect(is_equal_approx(effects.data.fog_ox, -10) and is_equal_approx(effects.data.fog_oy, 5), "RM fog speeds mapped to seconds FPS%d" % rate)
		expect(is_equal_approx(effects.data.fog_opacity, 0) and is_equal_approx(weather.data.weather_power, 8) and is_equal_approx(effects.data.fog_tone[0], 100), "effect endpoints FPS%d" % rate)
	var effects: RefCounted = effects_script.new()
	var weather: RefCounted = load("res://runtime/scripts/WeatherState.gd").new()
	var tileset := {"panorama_name": "sky", "fog_name": "mist", "fog_zoom": 150, "fog_sx": 2}
	var immutable := tileset.duplicate(true)
	expect(effects.setup_map(1, tileset).ok and tileset == immutable and effects.data.fog_zoom == 150, "tileset definition is read-only")
	effects.fade_fog(0, 2)
	weather.weather(1, 7)
	effects.advance(1); weather.advance(1)
	expect(effects_script.decode(effects.snapshot()).ok and load("res://runtime/scripts/WeatherState.gd").decode(weather.snapshot()).ok, "fog/weather save halfway")
	var before: Dictionary = effects.snapshot()
	for invalid in [{"fog_zoom": 0}, {"fog_blend_type": 1.5}, {"panorama_name": "../outside"}, {"fog_opacity": INF}]:
		expect(not effects.configure(invalid).ok and effects.snapshot() == before, "invalid effects rejected atomically")
	expect(not weather.weather(9, 1).ok and not weather.weather(1, 10).ok, "bad weather rejected")
	weather.weather(0, 0, 1)
	expect(weather.data.weather_type == 1, "fade-out keeps original particle type")
	effects.advance(1); weather.advance(1)
	expect(weather.data.weather_type == 0 and weather.data.weather_power == 0, "weather disabled without residual particles")
	weather.weather(1, 0)
	expect(weather.data.weather_type == 1 and weather.data.weather_density == 4, "RM power0 is minimum weather, not disabled")
	effects.setup_map(2, {})
	expect(effects.data.fog_name.is_empty() and effects.data.fog_ox == 0, "new map resets tileset fog, not source data")
	var timer_script: Script = load("res://runtime/scripts/GameTimer.gd")
	var timer: RefCounted = timer_script.new()
	var expiries := [0]
	timer.expired.connect(func() -> void: expiries[0] += 1)
	expect(timer.start(61).ok and timer.text() == "01:01", "timer format")
	timer.advance(60.5)
	expect(timer.text() == "00:01" and timer.running, "timer uses ceiling for fractional remaining time")
	timer.advance(99); timer.advance(99)
	expect(expiries[0] == 1 and timer.remaining == 0 and timer.visible and not timer.running, "expires once, remains at zero without battle action")
	expect(not timer.start(-1).ok and not timer.start(NAN).ok, "bad timer start rejected")
	timer.stop()
	expect(not timer.visible and timer_script.decode(timer.snapshot()).ok, "stopped timer hides and saves")
	await integration()
	for message in failures: printerr("FAIL: ", message)
	print("PRESENTATION TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func integration() -> void:
	state.begin_new_game(data.system())
	state.resume_from_save = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	if game._dialogue.is_open(): game._dialogue._hide()
	game._interpreter.running = false
	game._player.input_enabled = true
	game._player.set_process(false)
	state.timer.start(10)
	state.screen.weather(1, 6)
	state.map_effects.fade_fog(0, 4)
	var map_id: int = state.map_id
	var position := Vector2i(state.player_x, state.player_y)
	var ids := [game._map.get_instance_id(), game._player.get_instance_id()]
	expect(state.configure_map_view({"view_rect": [160, 0, 480, 480], "follow_center": [180, 160]}).ok, "public configure applies to live map")
	expect(game._menus.open_menu(), "menu opens without replacing map")
	var remaining: float = state.timer.remaining
	var fog_remaining: float = state.map_effects.data.fog_opacity_remaining
	await create_timer(0.1).timeout
	expect(state.timer.remaining == remaining and state.map_effects.data.fog_opacity_remaining == fog_remaining, "ordinary menu pauses timer/fog/weather")
	game._menus.menu.open_test_tools()
	for index in 5: game._menus.menu.navigate(1)
	game._menus.menu.activate()
	await frames(3)
	expect(game._menus.menu.page == "presentation_tools", "F6 exposes sixth presentation entry")
	var tool: Control = game._menus.menu._commerce
	expect(tool.map.map_width() == 48 and tool.map.map_height() == 36 and tool.map != game._map and tool.view != state.map_view, "independent large map, camera and effects")
	tool._left_ui()
	tool._edge()
	tool.camera.sync(0, true)
	expect(tool.view.display.x > 0 and tool.view.display.y > 0, "preview large map scrolls in both dimensions")
	tool.choices.panorama.select(1); tool.choices.fog.select(1); tool._apply_effects(); tool._weather(2)
	tool.renderer.sync(1)
	expect(tool.renderer.panorama.visible and tool.renderer.fog.visible and tool.renderer.weather.particle_count() > 0, "preview native planes and batched weather")
	expect(state.timer.remaining == remaining and state.map_effects.data.fog_opacity_remaining == fog_remaining and Vector2i(state.player_x, state.player_y) == position, "preview leaves live state paused")
	game._menus.close_menu()
	expect([game._map.get_instance_id(), game._player.get_instance_id()] == ids and state.map_id == map_id, "same live instances after close")
	var codec: Script = load("res://runtime/scripts/SaveCodec.gd")
	var saved: Dictionary = codec.capture(state)
	var parsed: Dictionary = codec.prepare(saved)
	expect(parsed.ok and parsed.map_view.options.follow_center == [180.0, 160.0] and parsed.timer.remaining > 0 and parsed.screen.weather_snapshot().weather_type == 1, "native view/effects/timer save validated detached")
	var legacy := saved.duplicate(true)
	for key in ["map_view", "map_effects", "timer"]: legacy.erase(key)
	legacy.screen.erase("weather")
	var old: Dictionary = codec.prepare(legacy)
	expect(old.ok and old.map_view.options.view_rect.is_empty() and old.screen.weather_snapshot().weather_type == 0 and not old.timer.visible, "older schema1 optional fields default")
	var invalid := saved.duplicate(true)
	invalid.timer.remaining = -10
	expect(not codec.prepare(invalid).ok and state.timer.remaining >= 0, "invalid save does not partially restore")
	await audio_test()
	game.queue_free()
	await frames(3)
	expect(state.game() == null, "game accessor releases disposed scenes")
	state.begin_new_game(data.system())
	expect(state.map_view.options.follow_center.is_empty() and state.screen.weather_snapshot().weather_type == 0 and not state.timer.visible, "new game resets temporary systems")
	state.audio.stop_all()
	await frames(3)

func audio_test() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 11025
	var bytes := PackedByteArray()
	bytes.resize(11025 * 10)
	for index in 55125: bytes.encode_s16(index * 2, int(sin(index * TAU * 440 / 11025) * 8000))
	wav.data = bytes
	var path := "res://.godot/presentation-audio.tres"
	expect(ResourceSaver.save(wav, path) == OK, "disposable native audio fixture")
	var asset_index: Dictionary = data.read_json("res://data/asset_index.json")
	var snapshot := asset_index.duplicate(true)
	for kind in ["BGM", "BGS", "ME", "SE"]: asset_index["Audio/%s/@tone" % kind] = path
	var audio: Node = state.audio
	expect(audio.play("BGM", {"name": "@tone", "volume": 80, "pitch": 120}).ok, "native audio start")
	expect(is_equal_approx(audio.channels.BGM.pitch_scale, 1.2), "audio pitch applied")
	var player: Node = audio.channels.BGM
	expect(not audio.play("BGM", {"name": "@missing"}).ok and audio.channels.BGM == player, "missing audio preserves previous channel")
	expect(audio.play("BGS", {"name": "@tone"}).ok and audio.play("ME", {"name": "@tone"}).ok and audio.channels.BGM.stream_paused, "ME pauses BGM, BGS independent")
	audio.stop("ME")
	expect(not audio.channels.BGM.stream_paused, "ME stop resumes previous BGM")
	for index in 35: audio.play("SE", {"name": "@tone"})
	expect(audio._effects.size() == 32, "SE concurrency bounded without node leak")
	audio.stop("SE")
	expect(audio._effects.is_empty(), "SE stop leaves BGM/BGS")
	var memory: Dictionary = audio.memorize()
	expect(memory.has("BGM") and memory.has("BGS"), "memory captures definitions/position")
	audio.fade_out("BGM", 1)
	audio._process(0.5)
	expect(is_equal_approx(db_to_linear(audio.channels.BGM.volume_db), 0.4), "fade halfway linear volume")
	audio._process(0.5)
	expect(not audio.channels.has("BGM") and audio.channels.has("BGS"), "fade stops channel only")
	expect(audio.restore_memory().ok and audio.channels.has("BGM"), "restore starts remembered position")
	audio.stop_all()
	asset_index.clear(); asset_index.merge(snapshot)
	await frames(3)

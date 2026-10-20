## 职责：回归验证：验证地图、系统与音频演出事件参数及持久化。
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
##   func fixtures() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func parameters() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func skin_and_map() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func audio_commands() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func save_contract() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func integration() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func execute(commands: Array) -> Dictionary
##     用途：执行该脚本或已准备的操作。
##     参数 commands（Array；必填）：保持原顺序的事件指令列表。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func c(code: int, p: Array = []) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；默认值 []）：对应事件指令的参数数组。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func audio(volume: int = 100, pitch: int = 100) -> Dictionary
##     参数 volume（int；默认值 100）：音频音量参数。
##     参数 pitch（int；默认值 100）：音频音调参数。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func tone(r: float, g: float, b: float, gray: float) -> Dictionary
##     参数 r（float；必填）：红色通道或当前测试记录，类型见签名。
##     参数 g（float；必填）：绿色通道值。
##     参数 b（float；必填）：第二个操作数或参与比较的值。
##     参数 gray（float；必填）：色调的灰度分量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func frames(count: int) -> void
##     用途：让测试现场推进指定帧数。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
var failures: Array[String] = []
var checks := 0
var state: Node
var data: Script
var catalog: Script
var interpreter: Script
var index: Dictionary
var original_index: Dictionary

func _initialize() -> void: call_deferred("run")

func run() -> void:
	state = root.get_node("RuntimeState")
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	catalog = load("res://runtime/scripts/02_Event/EventCommandCatalog.gd")
	interpreter = load("res://runtime/scripts/02_Event/EventInterpreter.gd")
	state.begin_new_game(data.system())
	fixtures()
	parameters()
	await skin_and_map()
	await audio_commands()
	save_contract()
	await integration()
	state.audio.stop_all()
	index.clear(); index.merge(original_index)
	await frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT PRESENTATION TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func fixtures() -> void:
	index = data.read_json("res://data/asset_index.json")
	original_index = index.duplicate(true)
	var image := Image.create(192, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color("804020"))
	image.fill_rect(Rect2i(128, 0, 64, 64), Color("20a080"))
	var texture := ImageTexture.create_from_image(image)
	var path := "res://.godot/event-skin.tres"
	expect(ResourceSaver.save(texture, path) == OK, "disposable skin fixture")
	index["Graphics/Windowskins/@skin"] = path
	index["Graphics/Panoramas/@panorama"] = path
	index["Graphics/Fogs/@fog"] = path
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 11025
	var bytes := PackedByteArray(); bytes.resize(11025 * 12 * 2)
	wav.data = bytes
	path = "res://.godot/event-audio.tres"
	expect(ResourceSaver.save(wav, path) == OK, "disposable audio fixture")
	for kind in ["BGM", "BGS", "ME", "SE"]: index["Audio/%s/@tone" % kind] = path

func parameters() -> void:
	var valid := [[131, ["@skin"]], [203, [6, 4, 4]], [204, [0, "@panorama", 120]], [204, [1, "@fog", 90, 100, 2, 200, -4, 8]],
		[205, [tone(-40, 20, 80, 30), 20]], [206, [128, 20]], [241, [audio()]], [242, [2]], [245, [audio()]], [246, [0]], [247, []], [248, []], [249, [audio()]], [250, [audio()]], [251, []]]
	for item in valid: expect(catalog.supported(item[0], item[1]), "native parameter supported %d" % item[0])
	expect(not catalog.supported(204, [2, "battle"]) and catalog.reason(204, [2, "battle"]).contains("战斗"), "only 204 battle background excluded")
	var invalid := [[131, ["../bad"]], [203, [5, 2, 4]], [203, [6, 2, 0]], [203, [6, 1.5, 4]], [204, [0, "@panorama", 361]],
		[204, [1, "@fog", 0, 256, 0, 100, 0, 0]], [204, [1, "@fog", 0, 100, 3, 100, 0, 0]], [204, [1, "@fog", 0, 100, 0, 0, 0, 0]],
		[205, [[0, 0, 0, -1], 20]], [206, [-1, 20]], [241, [{"name": "@tone", "volume": 101, "pitch": 100}]], [245, [{"name": "@tone", "volume": 100, "pitch": 49}]],
		[249, [{"name": "../bad", "volume": 100, "pitch": 100}]], [250, []], [242, [-1]], [246, [1.5]], [247, [0]], [248, [0]], [251, [0]]]
	for item in invalid:
		var before: Dictionary = state.map_effects.snapshot()
		var owner := execute([c(item[0], item[1]), c(122, [99, 99, 0, 0, 9]), c(0)])
		expect(not owner.error.is_empty() and state.map_effects.snapshot() == before and state.variables.get("99", 0) != 9, "invalid command stops atomically %d" % item[0])
		expect(owner.error.replace(" ", "").contains("事件7") and owner.error.contains("第 2 页"), "failure includes event/page source")

func skin_and_map() -> void:
	var definitions: Dictionary = data.system().duplicate(true)
	var window: Control = load("res://runtime/scripts/04_UI_Common/WindowBase.gd").new()
	root.add_child(window)
	window.label("Keep content", Rect2(0, 0, 150, 30))
	window.select_rect(Rect2(0, 0, 100, 32))
	var result := execute([c(131, ["@skin"]), c(0)])
	expect(result.error.is_empty() and state.windowskin_name() == "@skin" and window._skin_name == "@skin", "131 updates existing window")
	expect(window.content.get_child_count() == 1 and window._cursor.visible, "skin change preserves content/selection")
	result = execute([c(131, ["__missing__"]), c(0)])
	expect(not result.error.is_empty() and state.windowskin_name() == "@skin", "missing skin leaves original")
	expect(data.system() == definitions, "131 does not modify imported System")
	result = execute([c(204, [0, "@panorama", 120]), c(204, [1, "@fog", 90, 100, 2, 200, -4, 8]), c(0)])
	expect(result.error.is_empty() and state.map_effects.data.panorama_hue == 120 and state.map_effects.data.fog_blend_type == 2, "204 panorama/fog native fields")
	var before: Dictionary = state.map_effects.snapshot()
	result = execute([c(204, [1, "__missing__", 90, 255, 0, 100, 0, 0]), c(0)])
	expect(not result.error.is_empty() and state.map_effects.snapshot() == before, "missing fog preserves all map settings")
	for rate in [30, 40, 60, 120]:
		state.map_effects.tint_fog([0, 0, 0, 0]); state.map_effects.fade_fog(100)
		result = execute([c(205, [tone(-80, 40, 100, 120), 20]), c(206, [200, 20]), c(0)])
		expect(result.error.is_empty() and not result.owner.running, "fog changes are nonblocking")
		for step in int(rate / 2): state.map_effects.advance(1.0 / rate)
		expect(is_equal_approx(state.map_effects.data.fog_tone[0], -40) and is_equal_approx(state.map_effects.data.fog_opacity, 150), "fog halfway at FPS%d" % rate)
		for step in int(rate / 2): state.map_effects.advance(1.0 / rate)
		expect(state.map_effects.data.fog_tone_remaining == 0 and state.map_effects.data.fog_opacity == 200, "fog endpoints at FPS%d" % rate)
		var view: RefCounted = load("res://runtime/scripts/00_Game/MapViewState.gd").new()
		view.advance(0, Vector2(320, 240), Vector2(1600, 1200), Vector2(640, 480), true)
		expect(view.scroll_native(6, 5, 4, Vector2(1600, 1200), Vector2(640, 480)).ok, "native scroll starts")
		for step in int(rate / 2): view.advance(1.0 / rate, Vector2(320, 240), Vector2(1600, 1200), Vector2(640, 480))
		expect(is_equal_approx(view.display.x, 80) and is_equal_approx(view.scroll_remaining, 0.5), "speed4 is160px/s FPS%d" % rate)
		for step in int(rate / 2): view.advance(1.0 / rate, Vector2(320, 240), Vector2(1600, 1200), Vector2(640, 480))
		view.advance(1, Vector2(320, 240), Vector2(1600, 1200), Vector2(640, 480))
		expect(is_equal_approx(view.display.x, 160) and view.scroll_remaining == 0, "scroll completion holds camera while player stationary")
		view.advance(0.1, Vector2(288, 240), Vector2(1600, 1200), Vector2(640, 480))
		expect(is_equal_approx(view.display.x, 128), "native camera follows movement beyond center")
		view.display.x = 940; view.scroll_native(6, 5, 4, Vector2(1600, 1200), Vector2(640, 480))
		view.advance(0.1, Vector2(288, 240), Vector2(1600, 1200), Vector2(640, 480))
		expect(is_equal_approx(view.display.x, 956), "edge scroll keeps native speed rather than stretching clipped distance")
	var moving_view: RefCounted = load("res://runtime/scripts/00_Game/MapViewState.gd").new()
	moving_view.advance(0, Vector2(320, 240), Vector2(1600, 1200), Vector2(640, 480), true)
	moving_view.scroll_native(6, 5, 4, Vector2(1600, 1200), Vector2(640, 480))
	moving_view.advance(0.25, Vector2(400, 240), Vector2(1600, 1200), Vector2(640, 480))
	var moving_start: float = moving_view.display.x
	moving_view.advance(0.25, Vector2(400, 240), Vector2(1600, 1200), Vector2(640, 480))
	expect(is_equal_approx(moving_view.display.x - moving_start, 40), "player movement cannot change native scroll velocity")
	var restored_view: Dictionary = load("res://runtime/scripts/00_Game/MapViewState.gd").decode(moving_view.snapshot())
	expect(restored_view.ok and restored_view.value.native_velocity == Vector2(160, 0), "native scroll velocity survives snapshot")
	result = execute([c(131, [""]), c(0)])
	expect(state.windowskin_name().is_empty() and window._skin_root.get_child_count() == 0, "explicit empty skin clears frame")
	window.queue_free(); await frames(2)

func audio_commands() -> void:
	state.audio.stop_all()
	var result := execute([c(241, [audio(80, 120)]), c(245, [audio(60, 90)]), c(247), c(249, [audio()]), c(250, [audio()]), c(0)])
	expect(result.error.is_empty() and state.audio.channels.BGM.stream_paused and state.audio.channels.has("BGS"), "ME pauses BGM while BGS remains independent")
	expect(is_equal_approx(state.audio.channels.BGM.pitch_scale, 1.2) and is_equal_approx(state.audio.channels.BGS.pitch_scale, 0.9), "native audio volume/pitch")
	expect(state.audio.memory.has("BGM") and state.audio.memory.has("BGS"), "247 remembers both channels")
	result = execute([c(250, [{"name": "", "volume": 100, "pitch": 100}]), c(0)])
	expect(state.audio._effects.size() == 1, "empty SE is a native no-op")
	result = execute([c(251), c(0)])
	expect(state.audio._effects.is_empty() and state.audio.channels.has("BGM"), "251 stops only SE")
	state.audio.stop("ME")
	expect(not state.audio.channels.BGM.stream_paused, "ME completion resumes BGM")
	var player: Node = state.audio.channels.BGM
	player.seek(2.5)
	result = execute([c(241, [audio(80, 120)]), c(0)])
	expect(state.audio.channels.BGM == player, "replaying same native BGM preserves channel identity")
	expect(state.audio.channels.BGM.get_playback_position() >= 2.4, "replaying same native BGM preserves clock")
	result = execute([c(241, [{"name": "__missing__", "volume": 100, "pitch": 100}]), c(122, [99, 99, 0, 0, 9]), c(0)])
	expect(not result.error.is_empty() and state.audio.channels.BGM == player and state.variables.get("99", 0) != 9, "missing audio reports error and preserves channel")
	result = execute([c(242, [2]), c(246, [2]), c(0)])
	expect(not result.owner.running and result.error.is_empty(), "audio fades do not implicitly wait")
	state.audio._process(1)
	expect(is_equal_approx(db_to_linear(state.audio.channels.BGM.volume_db), 0.4) and is_equal_approx(db_to_linear(state.audio.channels.BGS.volume_db), 0.3), "fade parameters are seconds")
	state.audio._process(1)
	expect(not state.audio.channels.has("BGM") and not state.audio.channels.has("BGS"), "fade completes at exact duration")
	result = execute([c(248), c(0)])
	expect(result.error.is_empty() and state.audio.channels.has("BGM") and state.audio.channels.has("BGS"), "248 restores remembered channels")
	var old_bgm: Node = state.audio.channels.BGM
	var old_bgs: Node = state.audio.channels.BGS
	var source: String = index["Audio/BGS/@tone"]
	index["Audio/BGS/@tone"] = "res://.godot/missing-audio.tres"
	result = execute([c(248), c(0)])
	expect(not result.error.is_empty() and state.audio.channels.BGM == old_bgm and state.audio.channels.BGS == old_bgs, "restore preflights both channels atomically")
	index["Audio/BGS/@tone"] = source
	result = execute([c(242, [0]), c(246, [0]), c(0)])
	expect(state.audio.channels.is_empty(), "zero duration stops immediately")
	result = execute([c(247), c(241, [audio()]), c(248), c(0)])
	expect(state.audio.channels.is_empty(), "empty memorized channels restore silence")
	await frames(2)

func save_contract() -> void:
	var codec: Script = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	state.set_windowskin("@skin")
	state.audio.play("BGM", audio(80, 120), 2.5)
	state.audio.memorize(); state.audio.fade_out("BGM", 4); state.audio._process(1)
	var saved: Dictionary = codec.capture(state)
	var prepared: Dictionary = codec.prepare(saved)
	expect(prepared.ok, "skin/audio/fade save validates")
	expect(saved.system_settings.windowskin_name == "@skin" and is_equal_approx(saved.audio.fades.BGM.remaining, 3), "save includes runtime system override and audio fade")
	state.begin_new_game(data.system())
	state.restore_prepared(prepared)
	expect(state.windowskin_name() == "@skin" and state.audio.memory.has("BGM") and state.audio.channels.has("BGM") and state.audio.fades.BGM.remaining == 3, "restore commits skin/audio/memory/fade")
	expect(state.audio.channels.BGM.get_playback_position() >= 2.4, "restore keeps audio playback position")
	var legacy := saved.duplicate(true); legacy.erase("audio"); legacy.erase("system_settings"); legacy.map_view.erase("native_follow"); legacy.map_view.erase("native_velocity")
	var old: Dictionary = codec.prepare(legacy)
	expect(old.ok and old.system_settings.windowskin_override == null and old.audio.playing.is_empty(), "schema1 old optional fields have compatible defaults")
	var invalid := saved.duplicate(true); invalid.audio.fades.BGM.remaining = -1
	expect(not codec.prepare(invalid).ok and state.windowskin_name() == "@skin", "invalid audio save rejected without mutating live state")
	invalid = saved.duplicate(true); invalid.system_settings.windowskin_name = "__missing__"
	expect(not codec.prepare(invalid).ok and state.windowskin_name() == "@skin", "missing persisted skin rejected atomically")
	invalid = saved.duplicate(true); invalid.audio.playing.BGM.position = NAN
	expect(not codec.prepare(invalid).ok, "invalid persistent playback position rejected")
	invalid = saved.duplicate(true); invalid.audio.playing.SE = invalid.audio.playing.BGM
	expect(not codec.prepare(invalid).ok, "transient ME/SE not accepted in persistent channels")
	state.begin_new_game(data.system())
	expect(state.system_settings.windowskin_override == null and state.audio.memory.is_empty() and state.audio.channels.is_empty(), "new game clears system/audio overrides")

func integration() -> void:
	state.resume_from_save = true
	var game: Node = load("res://scenes/03_Map/Game.tscn").instantiate()
	root.add_child(game); current_scene = game; await frames(3)
	game.reset_event_execution()
	var fixture: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build()
	game._map.load_definition(fixture.map, fixture.tileset)
	for node in [game, game._map, game._player, game._camera, game._screen_renderer, game._effects]: node.set_process(false)
	for event in game._map.event_contexts(): event.node.set_process(false)
	state.map_view = load("res://runtime/scripts/00_Game/MapViewState.gd").new()
	game._camera.model = state.map_view; game._camera.sync(0, true)
	var owner: RefCounted = interpreter.new(); owner.map_runtime = game._map
	owner.start([c(203, [6, 1, 4]), c(203, [8, 1, 4]), c(122, [98, 98, 0, 0, 3]), c(0)], 7)
	expect(owner.wait_kind() == "scroll_ready" and state.variables.get("98", 0) == 0, "consecutive scroll waits before second command")
	var before: Dictionary = state.map_view.snapshot()
	expect(game._menus.open_menu(), "background scroll allows normal menu")
	game._camera._process(1)
	expect(state.map_view.snapshot() == before, "menu pauses scroll clock")
	game._menus.close_menu(); game._camera._process(0.2); owner.advance(0)
	expect(state.variables.get("98", 0) == 3 and not owner.running and state.map_view.scroll_remaining > 0, "second scroll starts once first completes then event continues")
	state.map_effects.tint_fog([0, 0, 0, 0]); execute([c(205, [tone(-100, 0, 0, 0), 20]), c(0)])
	game._menus.open_menu(); game._effects.sync(0.5)
	expect(state.map_effects.data.fog_tone_remaining == 1, "menu pauses fog clock")
	game._menus.close_menu(); game._effects.sync(0.5)
	expect(is_equal_approx(state.map_effects.data.fog_tone[0], -50), "fog resumes same interpolation after menu")
	game.queue_free(); current_scene = null; await frames(3)

func execute(commands: Array) -> Dictionary:
	var messages := {"text": ""}
	var owner: RefCounted = interpreter.new()
	owner.diagnostic_requested.connect(func(message: String) -> void: messages.text = message)
	owner.start(commands, 7, 2)
	return {"error": messages.text, "owner": owner}

func c(code: int, p: Array = []) -> Dictionary: return {"code": code, "parameters": p, "indent": 0}
func audio(volume: int = 100, pitch: int = 100) -> Dictionary: return {"_class": "RPG::AudioFile", "name": "@tone", "volume": volume, "pitch": pitch}
func tone(r: float, g: float, b: float, gray: float) -> Dictionary: return {"_class": "Tone", "red": r, "green": g, "blue": b, "gray": gray}
func frames(count: int) -> void:
	for step in count: await process_frame
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

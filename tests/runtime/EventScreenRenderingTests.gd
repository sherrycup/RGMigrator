## 职责：回归验证：验证图片、天气、震动和过渡事件的实际渲染。
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
##   func pictures_and_effects() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func weather() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func transitions(fixture: Dictionary) -> void
##     参数 fixture（Dictionary；必填）：独立测试夹具或其数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func run_commands(commands: Array) -> void
##     参数 commands（Array；必填）：保持原顺序的事件指令列表。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func frames(count: int) -> void
##     用途：让测试现场推进指定帧数。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func pixel(point: Vector2i) -> Color
##     参数 point（Vector2i；必填）：位置或几何点。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   func capture(name: String) -> void
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func changed_pixels(before: Image, after: Image) -> int
##     参数 before（Image；必填）：操作前的状态或比较基准。
##     参数 after（Image；必填）：操作后状态或比较目标。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func c(code: int, p: Array = []) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；默认值 []）：对应事件指令的参数数组。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func tone(red: float, green: float, blue: float, gray: float) -> Dictionary
##     参数 red（float；必填）：红色通道值。
##     参数 green（float；必填）：绿色通道值。
##     参数 blue（float；必填）：蓝色通道值。
##     参数 gray（float；必填）：色调的灰度分量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func color(red: float, green: float, blue: float, alpha: float) -> Dictionary
##     参数 red（float；必填）：红色通道值。
##     参数 green（float；必填）：绿色通道值。
##     参数 blue（float；必填）：蓝色通道值。
##     参数 alpha（float；必填）：颜色或图像的透明分量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
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
## Native event execution in the existing Game, with actual GPU pixel checks.
var failures: Array[String] = []
var checks := 0
var captures := ""
var state: Node
var data: Script
var game: Node
var size: Vector2i

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): captures = argument.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: actual renderer required"); quit(1); return
	create_timer(90).timeout.connect(func() -> void: printerr("FAIL: event screen render timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	state = root.get_node("RuntimeState"); data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	for resolution in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		size = resolution; root.content_scale_size = size; DisplayServer.window_set_size(size)
		state.begin_new_game(data.system()); state.resume_from_save = true
		game = load("res://scenes/03_Map/Game.tscn").instantiate(); root.add_child(game); current_scene = game
		await frames(3); game.reset_event_execution()
		var fixture: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build()
		fixture.map.events["3"].pages[0].trigger = 4
		fixture.map.events["3"].pages[0].list = [c(106, [20]), c(122, [8893, 8893, 1, 0, 1]), c(0)]
		game._map.load_definition(fixture.map, fixture.tileset); game._events_enabled = true
		for node in [game, game._map, game._player, game._camera, game._screen_renderer, game._effects, game._transition]: node.set_process(false)
		for event in game._map.event_contexts(): event.node.set_process(false)
		game._player.move_to(2, 4); game._camera.sync(0)
		await pictures_and_effects()
		await weather()
		await transitions(fixture)
		game.queue_free(); current_scene = null
		await frames(3)
	state.audio.stop_all(); await frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	var result := FileAccess.open(captures.path_join("result.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "sizes": ["640x480", "800x480", "768x768"]}, "\t")); result.close()
	print("EVENT SCREEN RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func pictures_and_effects() -> void:
	await refresh()
	var point := Vector2i(140, 190)
	var base := pixel(point)
	run_commands([c(231, [1, "@test_picture", 0, 0, 120, 140, 100, 100, 255, 0])]); await refresh()
	var normal := pixel(point)
	expect(normal.is_equal_approx(Color("59c9eb")), "231 actually renders native coordinates %s" % size)
	capture("picture-before")
	run_commands([c(223, [tone(-80, 0, 0, 0), 0])]); await refresh()
	expect(pixel(point).is_equal_approx(normal), "screen tone preserves screen-space picture")
	expect(game._screen_renderer._tone_rect.visible, "223 activates actual map tone shader")
	run_commands([c(234, [1, tone(-80, 0, 0, 0), 0])]); await refresh()
	expect(pixel(point).r < normal.r - 0.2, "234 independently tints actual picture pixels")
	capture("screen-and-picture-tone")
	run_commands([c(223, [tone(0, 0, 0, 0), 0]), c(231, [1, "@test_picture", 0, 0, 120, 140, 100, 100, 255, 1])]); await refresh()
	var added := pixel(point)
	expect(added.r >= normal.r and added.b > normal.b, "231 additive blend really changes pixels")
	run_commands([c(231, [1, "@test_picture", 0, 0, 120, 140, 100, 100, 255, 2])]); await refresh()
	expect(pixel(point).b < base.b and pixel(point).g < base.g, "231 subtractive blend really changes pixels")
	state.set_event_variable(8891, 300); state.set_event_variable(8892, 220)
	run_commands([c(231, [1, "@test_picture", 1, 1, 8891, 8892, 100, 100, 255, 0]), c(233, [1, 9])]); await refresh()
	var rotated_point := Vector2i(310, 220)
	var before_rotation := pixel(rotated_point)
	state.screen.advance(0.5); await refresh()
	expect(game._screen_renderer.sprites[1].rotation_degrees == -90 and pixel(rotated_point).is_equal_approx(Color.WHITE) and not before_rotation.is_equal_approx(Color.WHITE), "233 rotates source stripe by90degrees in actual pixels")
	capture("picture-rotation")
	run_commands([c(233, [1, 0]), c(232, [1, 20, 1, 0, 400, 260, 150, 50, 128, 0])])
	state.screen.advance(0.5); await refresh()
	expect(game._screen_renderer.sprites[1].position == Vector2(350, 240) and game._screen_renderer.sprites[1].scale == Vector2(1.25, 0.75), "232 has actual halfway position and scale")
	capture("picture-half")
	run_commands([c(224, [color(255, 0, 0, 128), 20])]); await refresh()
	var flash_point := Vector2i(350, 240)
	var flash := pixel(flash_point)
	expect(game._screen_renderer._flash_rect.visible and flash.r > flash.g, "224 flashes over picture layer")
	capture("screen-flash")
	state.screen.advance(1); await refresh()
	expect(not game._screen_renderer._flash_rect.visible, "224 releases flash without a stale overlay")
	run_commands([c(225, [5, 4, 20])]); state.screen.advance(0.125); await refresh()
	expect(is_equal_approx(game._camera.offset.x, -10), "225 strength/speed adapter shifts actual camera")
	state.screen.advance(1); await refresh()
	expect(game._camera.offset.x == 0, "225 releases actual camera offset")
	run_commands([c(235, [1])]); await refresh()
	expect(game._screen_renderer.sprites.is_empty(), "235 removes actual picture sprite")

func weather() -> void:
	state.configure_map_view({"view_rect": [120, 40, size.x - 140, size.y - 60]}); game._camera.sync(0)
	await refresh(); var clean := root.get_texture().get_image()
	for type in [1, 2, 3]:
		run_commands([c(236, [type, 9, 0])]); await refresh()
		expect(game._effects.weather.type == type and game._effects.weather.particle_count() > 0, "236 draws native weather type%d %s" % [type, size])
		expect(changed_pixels(clean, root.get_texture().get_image()) > 40, "weather changes actual pixels type%d" % type)
		expect(pixel(Vector2i(60, size.y / 2)).is_equal_approx(Color.BLACK), "weather clips to map display region")
		capture("weather-%d" % type)
	run_commands([c(236, [0, 0, 20])]); state.screen.advance(0.25); await refresh()
	expect(game._effects.weather.type == 3 and game._effects.weather.particle_count() > 0, "weather fading retains original particles")
	state.screen.advance(0.25); await refresh()
	expect(game._effects.weather.particle_count() == 0 and not game._effects.weather.visible, "weather completion removes actual particles")
	state.configure_map_view({"view_rect": []}); game._camera.sync(0); await refresh()

func transitions(fixture: Dictionary) -> void:
	run_commands([c(231, [1, "@test_picture", 0, 0, 120, 140, 100, 100, 255, 0])]); await refresh()
	game._process(0)
	var parallel: RefCounted = game._scheduler.parallels["event:3:1"].owner
	var parallel_remaining: float = parallel.wait_state.remaining
	state.set_event_variable(8894, 0)
	game._scheduler.start_main([c(221), c(231, [1, "@test_picture", 0, 0, 300, 140, 100, 100, 255, 0]), c(222, [""]), c(122, [8894, 8894, 0, 0, 1]), c(0)], 1)
	await frames(3)
	expect(game._transition.frozen != null and game._interpreter.wait_kind() == "screen_transition", "221 obtains a real frozen image before resuming")
	game._process(0); await refresh()
	expect(game._transition.remaining == 0.5 and state.variables.get("8894", 0) == 0 and pixel(Vector2i(140, 190)).is_equal_approx(Color("59c9eb")), "222 ordinary transition keeps old screenshot and waits0.5second")
	capture("transition-frozen")
	state.screen.weather(1, 5, 1)
	state.timer.start(10)
	game._player.configure_motion({"through": true}); game._player.force_move_route({"repeat": false, "skippable": false, "list": [c(3), c(0)]})
	var position: Vector2 = game._player.motion.visual_cell
	var tile_clock: float = game._map._autotile_seconds
	game._screen_renderer._process(0.25); game._effects.sync(0.25); game._player._process(0.25); game._map._process(0.25); game._process(0.25)
	expect(state.screen.weather_snapshot().weather_remaining == 1 and state.timer.remaining == 10 and game._player.motion.visual_cell == position and game._map._autotile_seconds == tile_clock and parallel.wait_state.remaining == parallel_remaining, "222 holds map, weather, timer, character and parallel clocks")
	game._transition._process(0.25); game._process(0); await refresh()
	expect(game._interpreter.running and state.variables.get("8894", 0) == 0, "half transition cannot resume event")
	capture("transition-half")
	game._transition._process(0.25); game._process(0); await refresh()
	expect(game._transition.frozen == null and not game._interpreter.running and state.variables.get("8894", 0) == 1 and pixel(Vector2i(320, 190)).is_equal_approx(Color("59c9eb")), "transition completion releases image and executes continuation once")
	capture("transition-finished")
	game._player._process(0.25); game._player.cancel_move_route()
	state.screen.weather(0, 0); state.timer.stop(); await refresh()
	var masks: Array = load("res://runtime/scripts/10_Support/Cache/RmxpCache.gd").list_names("Transitions")
	expect(not masks.is_empty(), "source project provides actual transition mask")
	if not masks.is_empty():
		game._scheduler.start_main([c(221), c(223, [tone(100, 0, 0, 0), 0]), c(222, [masks[0]]), c(122, [8894, 8894, 0, 0, 2]), c(0)], 1)
		await frames(3); game._process(0); await refresh()
		var frozen := root.get_texture().get_image()
		expect(game._transition.remaining == 1.0 and game._transition.rect.material.get_shader_parameter("masked"), "named native222 uses source mask and1second")
		game._transition._process(0.5); game._process(0); await refresh()
		var halfway := root.get_texture().get_image()
		expect(changed_pixels(frozen, halfway) > 40 and state.variables.get("8894", 0) == 1, "actual masked halfway reveals new map while continuation waits")
		capture("transition-mask-half")
		game._transition._process(0.5); game._process(0); await refresh()
		expect(changed_pixels(halfway, root.get_texture().get_image()) > 40 and state.variables.get("8894", 0) == 2, "mask reaches full reveal before continuation")
		capture("transition-mask-finished")
	var owner: RefCounted = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new(); owner.map_runtime = game._map
	game._dialogue.show_diagnostic("已有消息，准备过渡等待关闭。")
	owner.start([c(221), c(106, [20]), c(0)], 1)
	expect(owner.wait_kind() == "screen_ready" and not game.event_screen_transition_active(), "221 retries after existing message closes")
	game._dialogue.dismiss(); owner.advance(0); await frames(3); owner.advance(0)
	expect(owner.wait_kind() == "time" and game._transition.frozen != null, "capture completion resumes correct independent interpreter")
	owner.cancel()
	expect(game._transition.frozen == null, "cancelled interpreter releases its prepared screenshot")
	var cancelled: Dictionary = game.begin_event_screen_transition(221)
	var replacement := {"id": 0, "during_capture": false}
	RenderingServer.frame_pre_draw.connect(func() -> void:
		replacement.during_capture = game._transition.busy
		game.cancel_event_screen_transition(cancelled.id)
		replacement.id = game.begin_event_screen_transition(221).id
	, CONNECT_ONE_SHOT)
	await frames(4)
	expect(replacement.during_capture and not game.event_screen_transition_status(cancelled.id).ok and game.event_screen_transition_status(replacement.id).ok and game._transition.frozen != null, "cancelled async capture cannot complete or clear its replacement")
	game.cancel_event_screen_transition(cancelled.id)
	expect(game._transition.frozen != null, "stale request cannot cancel newer prepared image")
	game.cancel_event_screen_transition(replacement.id)
	var prepared: Dictionary = game.begin_event_screen_transition(221); await frames(3)
	game._scheduler.cancel_all()
	expect(game.event_save_reason().contains("瞬时截图"), "prepared screenshot has a save gate even without running events")
	var saves: Script = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	var old_directory: String = saves.directory_override
	var isolated := captures.path_join("forbidden-saves")
	saves.directory_override = isolated
	var count_before: int = state.save_count
	var denied: Dictionary = saves.save_slot(1, state)
	saves.directory_override = old_directory
	expect(not denied.ok and denied.message.contains("瞬时截图"), "direct save service also rejects transient screenshot")
	expect(not DirAccess.dir_exists_absolute(isolated) and state.save_count == count_before, "transient save refusal writes no file and does not increment counter")
	var absent: Dictionary = game.begin_event_screen_transition(222, "__missing_transition__")
	expect(not absent.ok and game._transition.frozen != null and game.event_screen_transition_status(prepared.id).ok, "missing mask leaves original screenshot intact")
	game.cancel_event_screen_transition()
	state.set_event_variable(8895, 0)
	game._scheduler.start_main([c(222, [""]), c(122, [8895, 8895, 0, 0, 1]), c(0)], 1)
	await refresh()
	expect(game._transition.frozen != null and game._transition.remaining == 0.5 and state.variables.get("8895", 0) == 0, "222 without221 captures current image and waits for actual reveal")
	game._transition._process(0.5); game._process(0); await refresh()
	expect(game._transition.frozen == null and state.variables.get("8895", 0) == 1, "implicit capture transition completes before continuation")
	var original_tilesets: Variant = data.database("Tilesets"); data._cache["res://data/database/Tilesets.json"] = [null, fixture.tileset]
	var destination: Dictionary = fixture.map.duplicate(true); destination.tileset_id = 1; destination.events = {}
	data._cache["res://data/maps/Map991.json"] = destination
	game._scheduler.start_main([c(221), c(201, [0, 991, 3, 4, 6, 1]), c(222, [""]), c(122, [8894, 8894, 0, 0, 3]), c(0)], 1)
	await frames(3); game._process(0); await frames(3); game._process(0); await refresh()
	expect(state.map_id == 991 and game._transition.remaining == 0.5 and state.variables.get("8894", 0) == 2, "221→201 without fade→222 preserves screenshot across map change")
	game._transition._process(0.5); game._process(0); await refresh()
	expect(state.variables.get("8894", 0) == 3 and game._transition.frozen == null, "combined transfer transition resumes once")
	data._cache.erase("res://data/maps/Map991.json"); data._cache["res://data/database/Tilesets.json"] = original_tilesets
	var reset_request: Dictionary = game.begin_event_screen_transition(221)
	state.begin_new_game(data.system()); await frames(3); game._process(0)
	expect(not game.event_screen_transition_status(reset_request.id).ok and game._transition.frozen == null and game._effects.screen_model == state.screen, "new game cancels stale screen capture and rebinds sole weather owner")

func run_commands(commands: Array) -> void:
	var list := commands.duplicate(true); list.append(c(0))
	expect(game._scheduler.start_main(list, 1), "formal foreground starts")
func refresh() -> void:
	game._screen_renderer.sync(); game._effects.sync(0)
	await frames(3)
func frames(count: int) -> void:
	for index in count: await process_frame; await RenderingServer.frame_post_draw
func pixel(point: Vector2i) -> Color: return root.get_texture().get_image().get_pixelv(point)
func capture(name: String) -> void:
	expect(root.get_texture().get_image().save_png(captures.path_join("%dx%d-%s.png" % [size.x, size.y, name])) == OK, "actual capture saved")
func changed_pixels(before: Image, after: Image) -> int:
	var count := 0
	for y in before.get_height():
		for x in before.get_width():
			var a := before.get_pixel(x, y); var b := after.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length_squared() > 0.001: count += 1
	return count
func c(code: int, p: Array = []) -> Dictionary: return {"code": code, "parameters": p, "indent": 0}
func tone(red: float, green: float, blue: float, gray: float) -> Dictionary: return {"_class": "Tone", "red": red, "green": green, "blue": blue, "gray": gray}
func color(red: float, green: float, blue: float, alpha: float) -> Dictionary: return {"_class": "Color", "red": red, "green": green, "blue": blue, "alpha": alpha}
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message + " / " + str(size))

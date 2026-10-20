## 职责：回归验证：验证人物路线、深度和换图事件的实际渲染。
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
##   func c(code: int, p: Array = []) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；默认值 []）：对应事件指令的参数数组。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func route(commands: Array) -> Dictionary
##     参数 commands（Array；必填）：保持原顺序的事件指令列表。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func sprite_pixel(target: Node) -> Color
##     参数 target（Node；必填）：操作或效果作用的目标。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   func capture(size: Vector2i, name: String) -> void
##     参数 size（Vector2i；必填）：对象、画布或区域尺寸。
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func render_frames(count: int) -> void
##     用途：等待指定数量的真实渲染帧。
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
## Real-renderer verification of routes, depth and 201; no demo scene or tool entry.
var failures: Array[String] = []
var checks := 0
var captures := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): captures = argument.trim_prefix("--captures=")
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: actual renderer required"); quit(1); return
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: movement render timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	var state := root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	for size in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		root.content_scale_size = size
		DisplayServer.window_set_size(size)
		state.begin_new_game(data.system()); state.resume_from_save = true
		var game: Node2D = load("res://scenes/03_Map/Game.tscn").instantiate()
		root.add_child(game); current_scene = game
		await render_frames(3)
		game.reset_event_execution()
		var fixture: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build()
		game._map.load_definition(fixture.map, fixture.tileset)
		game._events_enabled = true
		game.set_process(false); game._player.set_process(false)
		game._transition.set_process(false)
		for event in game._map.event_contexts(): event.node.set_process(false)
		game._player.move_to(2, 4)
		state.configure_map_view({"view_rect": [], "follow_center": [], "follow_enabled": true})
		game._camera.sync(0)
		var target: Node = game._map.event_node(1)
		target.move_to(4, 5)
		target.set_route_graphic("@movement_character", 0, 2, 0)
		await render_frames(3)
		var before := sprite_pixel(target)
		expect(before.a > 0.9 and before.is_equal_approx(Color("8ac7ed")), "original procedural sprite really draws %s" % size)
		capture(size, "route-before")
		state.set_event_variable(8801, 0)
		game._scheduler.start_main([c(209, [1, route([c(3), c(41, ["@movement_character", 120, 8, 0])])]), c(210), c(122, [8801, 8801, 0, 0, 1]), c(0)], 1)
		target.advance_motion(0.1); game._process(0.1)
		await render_frames(3)
		expect(target.motion.visual_cell.is_equal_approx(Vector2(4.5, 5)) and int(state.variables.get("8801", 0)) == 0, "actual halfway route keeps interpreter waiting %s" % size)
		capture(size, "route-half")
		target.advance_motion(0.1); game._process(0.1)
		await render_frames(3)
		expect(target.tile_position == Vector2i(5, 5) and int(state.variables.get("8801", 0)) == 1, "actual route and210 finish once %s" % size)
		expect(not sprite_pixel(target).is_equal_approx(before), "route41 hue changes actual pixels %s" % size)
		capture(size, "route-after")
		# Existing high-priority fixture tile at(8,2) hides a normal character.
		target.set_route_graphic("@movement_character", 0, 2, 0)
		target.move_to(8, 2); target.set_always_on_top(false)
		await render_frames(3)
		var covered := sprite_pixel(target)
		target.force_move_route(route([c(39)]))
		await render_frames(3)
		expect(target.always_on_top and not sprite_pixel(target).is_equal_approx(covered), "route39 draws over high-priority tile %s" % size)
		capture(size, "route-top")
		target.force_move_route(route([c(40)]))
		await render_frames(3)
		expect(sprite_pixel(target).is_equal_approx(covered), "route40 restores original tile depth %s" % size)
		# Capture-backed201 reveals the new map only while the command is waiting.
		var original_tilesets: Variant = data.database("Tilesets")
		data._cache["res://data/database/Tilesets.json"] = [null, fixture.tileset]
		var destination: Dictionary = fixture.map.duplicate(true)
		destination.tileset_id = 1
		destination.events = {}
		for index in destination.data.values.size(): destination.data.values[index] = 386 if index < 12 * 9 else 0
		data._cache["res://data/maps/Map993.json"] = destination
		state.set_event_variable(8802, 0)
		game._scheduler.start_main([c(201, [0, 993, 3, 4, 6, 0]), c(122, [8802, 8802, 0, 0, 1]), c(0)], 1)
		await render_frames(3)
		expect(game._transition.frozen != null and game._transition.remaining == 0.5 and state.map_id == 993, "201 captures old image before actual map change %s" % size)
		expect(game._interpreter.wait_kind() == "transfer" and int(state.variables.get("8802", 0)) == 0, "201 foreground continuation waits for visible completion %s" % size)
		capture(size, "transfer-frozen")
		game._transition._process(0.25); game._process(0.25)
		await render_frames(3)
		expect(game._interpreter.running and int(state.variables.get("8802", 0)) == 0, "half transition cannot resume event %s" % size)
		capture(size, "transfer-half")
		game._transition._process(0.25); game._process(0.25)
		await render_frames(3)
		expect(game._transition.frozen == null and not game._interpreter.running and int(state.variables.get("8802", 0)) == 1, "201 releases screenshot and resumes exactly once %s" % size)
		expect(game._player.tile_position == Vector2i(3, 4) and state.player_direction == 6, "actual destination and native direction apply %s" % size)
		capture(size, "transfer-finished")
		var cancelled: Dictionary = game.begin_event_transfer(993, 1, 1, 2, true)
		var cancellation := {"during_capture": false}
		var cancel_capture := func() -> void:
			cancellation.during_capture = game._transition.busy
			game.cancel_event_transfer()
		RenderingServer.frame_pre_draw.connect(cancel_capture, CONNECT_ONE_SHOT)
		await render_frames(3)
		expect(cancellation.during_capture and not game.event_transfer_status(cancelled.id).ok and game._player.tile_position == Vector2i(3, 4), "cancelled asynchronous screenshot cannot apply old destination %s" % size)
		var following: Dictionary = game.begin_event_transfer(993, 4, 4, 8, true)
		await render_frames(3)
		game._transition._process(0.5); game._process(0)
		expect(game.event_transfer_status(following.id).ok and game._player.tile_position == Vector2i(4, 4), "new capture after cancellation owns its completion %s" % size)
		data._cache.erase("res://data/maps/Map993.json")
		data._cache["res://data/database/Tilesets.json"] = original_tilesets
		game.queue_free(); current_scene = null
		await render_frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	var result := FileAccess.open(captures.path_join("result.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "sizes": ["640x480", "800x480", "768x768"]}, "\t"))
	result.close()
	print("EVENT MOVEMENT RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func c(code: int, p: Array = []) -> Dictionary:
	return {"code": code, "parameters": p, "indent": 0}

func route(commands: Array) -> Dictionary:
	var list := commands.duplicate(true); list.append(c(0))
	return {"repeat": false, "skippable": false, "list": list}

func sprite_pixel(target: Node) -> Color:
	var position: Vector2 = target._sprite.get_global_transform_with_canvas().origin
	var image := root.get_texture().get_image()
	var point := Vector2i(position)
	if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height(): return Color.TRANSPARENT
	return image.get_pixelv(point)

func capture(size: Vector2i, name: String) -> void:
	var image := root.get_texture().get_image()
	expect(image != null and not image.is_empty(), "actual image exists")
	if image != null: expect(image.save_png(captures.path_join("%dx%d-%s.png" % [size.x, size.y, name])) == OK, "capture saved")

func render_frames(count: int) -> void:
	for frame in count: await process_frame; await RenderingServer.frame_post_draw

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

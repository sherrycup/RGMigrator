## 职责：回归验证：验证格子移动、人物方向与地图滚动的实际渲染。
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
##   func render_frames(count: int) -> void
##     用途：等待指定数量的真实渲染帧。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func close(first: Color, second: Color) -> bool
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 second（Color；必填）：第二个值或参与操作的对象。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func expect(condition: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 condition（bool；必填）：是否创建须返回布尔值的脚本条件模板。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
var failures: Array[String] = []
var captures := ""
var checks := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): captures = argument.trim_prefix("--captures=")
	call_deferred("run")


func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: movement visual checks require a real renderer")
		quit(1)
		return
	create_timer(60).timeout.connect(func() -> void: printerr("FAIL: movement rendering timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(captures)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 288)
	viewport.world_2d = World2D.new()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fixture: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build()
	var map: Node2D = load("res://runtime/scripts/03_Map/MapRuntime.gd").new()
	viewport.add_child(map)
	map.load_definition(fixture.map, fixture.tileset)
	map.set_process(false)
	var avatar: Node2D = load("res://runtime/scripts/03_Map/MapCharacter.gd").new()
	avatar.map_runtime = map
	map.ensure_character_layer().add_child(avatar)
	avatar.set_process(false)
	avatar.set_graphic("@movement_character")
	avatar.move_to(3, 2)
	await render_frames(3)
	var image := viewport.get_texture().get_image()
	expect(close(image.get_pixel(107, 70), Color("8ac7ed")), "native character top is opaque original texture")
	var bottom := image.get_pixel(107, 90)
	var bush_expected := Color("409655").lerp(Color("627ab1"), 0.5)
	expect(close(bottom, bush_expected), "bush clips only bottom12 pixels to half opacity")
	image.save_png(captures.path_join("native-bush.png"))
	avatar.move_to(8, 2)
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(close(image.get_pixel(267, 72), Color("fff19a")), "positive priority roof renders above a character behind it")
	image.save_png(captures.path_join("native-priority-behind.png"))
	avatar.move_to(8, 4)
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(close(image.get_pixel(267, 130), Color("8ac7ed")), "character farther south is in front of upper tiles")
	image.save_png(captures.path_join("native-priority-front.png"))
	avatar.move_to(3, 5)
	var start: Vector2 = avatar.position
	avatar.move_straight(6)
	avatar.advance_motion(0.1)
	await render_frames(3)
	expect(avatar.position.x == start.x + 16 and avatar._sprite.frame == 8, "halfway motion uses right-facing original sprite row")
	image = viewport.get_texture().get_image()
	image.save_png(captures.path_join("native-half-step.png"))
	avatar.advance_motion(0.1)
	avatar.configure_motion({"step_anime": true})
	avatar.advance_motion(0.25)
	await render_frames(3)
	expect(avatar._sprite.frame == 10, "four-frame selection advances using real sprite")
	viewport.get_texture().get_image().save_png(captures.path_join("native-step-frame.png"))
	var resources: Script = load("res://runtime/scripts/04_UI_Common/UIResources.gd")
	var colors := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for row in 4:
		for frame in 4: colors.fill_rect(Rect2i(frame * 32, row * 32, 32, 32), Color(float(frame) / 3, float(row) / 3, 0.25))
	colors.fill_rect(Rect2i(0, 0, 32, 32), Color.RED)
	resources._textures["Graphics/Characters/@movement_colors"] = ImageTexture.create_from_image(colors)
	avatar.configure_motion({"step_anime": false})
	avatar.motion.pattern = 3
	avatar.turn(8)
	avatar.set_graphic("@movement_colors")
	await render_frames(3)
	image = viewport.get_texture().get_image()
	var pixel := image.get_pixel(avatar.tile_position.x * 32 + 16, avatar.tile_position.y * 32 + 16)
	expect(pixel.r > 0.95 and pixel.g > 0.95 and pixel.b < 0.3, "native four directions/four frames use correct atlas coordinates")
	avatar.motion.pattern = 0
	avatar.turn(2)
	avatar.set_graphic("@movement_colors", 120)
	await render_frames(3)
	image = viewport.get_texture().get_image()
	pixel = image.get_pixel(avatar.tile_position.x * 32 + 16, avatar.tile_position.y * 32 + 16)
	expect(pixel.g > 0.95 and pixel.r < 0.05 and pixel.b < 0.05, "native hue is per instance and rotates red to green")
	avatar.set_graphic("@movement_colors", 0)
	avatar.configure_motion({"opacity": 128})
	await render_frames(3)
	image = viewport.get_texture().get_image()
	pixel = image.get_pixel(avatar.tile_position.x * 32 + 16, avatar.tile_position.y * 32 + 16)
	expect(close(pixel, Color("405c70").lerp(Color.RED, 128.0 / 255)), "native character opacity blends over the actual map")
	avatar.configure_motion({"opacity": 255, "blend_type": 1})
	await render_frames(3)
	image = viewport.get_texture().get_image()
	pixel = image.get_pixel(avatar.tile_position.x * 32 + 16, avatar.tile_position.y * 32 + 16)
	expect(close(pixel, Color(1, 92.0 / 255, 112.0 / 255)), "native character additive blend")
	avatar.configure_motion({"blend_type": 2})
	await render_frames(3)
	image = viewport.get_texture().get_image()
	pixel = image.get_pixel(avatar.tile_position.x * 32 + 16, avatar.tile_position.y * 32 + 16)
	expect(close(pixel, Color(0, 92.0 / 255, 112.0 / 255)), "native character subtractive blend")
	avatar.configure_motion({"blend_type": 0})
	avatar.configure_motion({"transparent": true})
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(close(image.get_pixel(avatar.tile_position.x * 32 + 16, avatar.tile_position.y * 32 + 16), Color("405c70")), "transparent character leaves map visible")
	avatar.configure_motion({"transparent": false})
	var tile_fixture := fixture.duplicate(true)
	var tile_event: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").event(6, 6, "", 0, "图块排序")
	tile_event.pages[0].graphic.tile_id = 386
	tile_fixture.map.events["4"] = tile_event
	map.load_definition(tile_fixture.map, tile_fixture.tileset)
	avatar.move_to(6, 6)
	await render_frames(3)
	expect(close(viewport.get_texture().get_image().get_pixel(208, 208), Color.RED), "priority0 tile event stays beneath a same-cell character")
	tile_event.pages[0].graphic.tile_id = 388
	map.load_definition(tile_fixture.map, tile_fixture.tileset)
	await render_frames(3)
	expect(close(viewport.get_texture().get_image().get_pixel(208, 208), Color("fff19a")), "positive priority tile event sorts above the same-cell character")
	var animated := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	animated.fill_rect(Rect2i(0, 0, 32, 32), Color.RED)
	animated.fill_rect(Rect2i(32, 0, 32, 32), Color.GREEN)
	resources._textures["Graphics/Autotiles/@movement_autotile"] = ImageTexture.create_from_image(animated)
	fixture.tileset.autotile_names = ["@movement_autotile"]
	fixture.map.data.values[1 + 12] = 48
	map.load_definition(fixture.map, fixture.tileset)
	await render_frames(3)
	expect(close(viewport.get_texture().get_image().get_pixel(48, 48), Color.RED), "single-tile autotile initial frame")
	map._process(0.25)
	await render_frames(3)
	expect(close(viewport.get_texture().get_image().get_pixel(48, 48), Color.GREEN), "animated autotile retained commands redraw at native interval")
	viewport.get_texture().get_image().save_png(captures.path_join("native-autotile-frame.png"))
	avatar.set_graphic("")
	expect(avatar.material == null, "missing/empty graphic clears its previous texture material")
	viewport.queue_free()
	await render_frames(3)
	for failure in failures: printerr("FAIL: ", failure)
	print("MOVEMENT RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)


func render_frames(count: int) -> void:
	for index in count:
		await process_frame
		await RenderingServer.frame_post_draw


func close(first: Color, second: Color) -> bool:
	return absf(first.r - second.r) <= 0.025 and absf(first.g - second.g) <= 0.025 and absf(first.b - second.b) <= 0.025


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

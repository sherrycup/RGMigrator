extends SceneTree

var failures: Array[String] = []
var capture_directory := ""
var measure := false
var game: Node
var coordinator: Node
var samples: Array[float] = []
var metrics: Dictionary = {}
var _walk_from := Vector2i.ZERO
var _walk_to := Vector2i.ZERO
var _walk_direction := Vector2i.RIGHT
var _walk_through := false
var _benchmark_page_pending := -1


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_directory = argument.trim_prefix("--captures=")
		if argument == "--benchmark":
			measure = true
	call_deferred("run_suite")


func run_suite() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: menu visual tests require an actual rendering driver")
		quit(1)
		return
	create_timer(240.0).timeout.connect(func() -> void: printerr("FAIL: menu rendering timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute(capture_directory)
	load("res://runtime/scripts/SaveService.gd").directory_override = capture_directory.path_join("disposable-saves")
	Engine.max_fps = 60
	var data := load("res://runtime/scripts/RuntimeData.gd")
	var system: Dictionary = data.system().duplicate(true)
	if FileAccess.file_exists("res://data/maps/Map585.json"):
		system.start_map_id = 585
		system.start_x = 13
		system.start_y = 6
	data._cache["res://data/system.json"] = system
	var title: Node = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await render_frames(3)
	await capture("title-test-mode", root.size)
	title.call("_on_new_game")
	await render_frames(12)
	game = current_scene
	var dialogue: Node = game.get("_dialogue")
	if dialogue.call("is_open"):
		for child in dialogue.get("_content").get_children():
			if child is Label:
				print("SOURCE DIAGNOSTIC: ", child.text)
			if child is Button and child.text == "关闭":
				child.emit_signal("pressed")
	await render_frames(3)
	coordinator = game.get("_menus")
	for resolution in [Vector2i(640, 480), Vector2i(800, 480), Vector2i(768, 768)]:
		# Each size checks a fresh supplied inventory, not leftovers from the prior size.
		root.get_node("RuntimeState").begin_new_game(system)
		# Reusing Game for a new inventory fixture must also create a fresh map:
		# native 116 now erases its source event, and erased scenes cannot be saved.
		expect(game._map.load_map(root.get_node("RuntimeState").map_id), "fresh source map for each independent menu fixture")
		game.reset_event_execution()
		root.size = resolution
		root.content_scale_size = resolution
		await render_frames(3)
		expect(coordinator.call("open_menu"), "real map opens menu")
		await render_frames(4)
		var menu: Control = coordinator.get("menu")
		expect(menu.size.is_equal_approx(Vector2(resolution)), "UI uses actual logical resolution")
		expect(menu._gold.position.y + menu._gold.size.y <= menu._gold.get_parent().size.y, "gold label fully fits its clipped counter window")
		await capture("menu-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("activate")
		menu.call("activate")
		await render_frames(3)
		expect(menu.get("page") == "status", "real source actor status opens")
		await capture("status-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("back")
		menu.call("back")
		for _i in 3: menu.call("navigate", -1)
		menu.call("activate")
		await render_frames(3)
		expect(menu.get("page") == "inventory", "real source seeded inventory opens")
		await capture("inventory-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("activate")
		await render_frames(3)
		await capture("item-target-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("activate")
		await render_frames(3)
		var state: Node = root.get_node("RuntimeState")
		var setup: Dictionary = data.test_config()
		var item_id := int(setup.stock[0].id)
		expect(state.inventory["item:%d" % item_id] == 9, "actual source potion consumes once at %s: inventory=%s" % [resolution, state.inventory["item:%d" % item_id]])
		var actor: RefCounted = state.actor(int(state.party[0]))
		expect(int(actor.hp) > int(actor.snapshot().parameters.maxhp * 0.5), "actual source potion heals actor")
		await capture("item-used-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("handle_back")
		menu.call("handle_back")
		menu.call("navigate", 1)
		menu.call("navigate", 1)
		menu.call("activate")
		menu.call("activate")
		await render_frames(3)
		expect(menu.get("page") == "equipment", "real source equipment opens")
		await capture("equipment-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("activate")
		menu.call("navigate", 1)
		await render_frames(3)
		expect(menu.get("_commerce").get("_preview").get("ok", false), "actual source equipment preview is eligible")
		await capture("equip-preview-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("activate")
		await render_frames(3)
		expect(actor.equipment[0] == int(setup.stock[3].id), "actual source equipment commits")
		await capture("equip-applied-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.call("handle_back")
		menu.call("handle_back")
		menu.call("navigate", -1)
		menu.call("activate")
		menu.call("activate")
		await render_frames(3)
		expect(menu.page == "skills", "real source read-only skill list opens")
		var skill_view: Control = menu._commerce
		var skill_id := int(setup.learn_skills[0])
		skill_view.selected = skill_view._ids.find(skill_id)
		skill_view._selection_id = skill_id
		skill_view.refresh()
		await capture("skills-%dx%d" % [resolution.x, resolution.y], resolution)
		var original_sp: int = actor.sp
		var original_hp: int = actor.hp
		skill_view._test_action(1)
		await render_frames(4)
		await capture("animation-preview-%dx%d" % [resolution.x, resolution.y], resolution)
		expect(actor.sp == original_sp and actor.hp == original_hp, "preview has no skill effects")
		skill_view.back()
		skill_view._test_action(4)
		await render_frames(3)
		expect(not actor.has_skill(int(setup.toggle_skill_id)), "test forget button uses interpreter")
		skill_view._test_action(3)
		await render_frames(3)
		expect(actor.has_skill(int(setup.toggle_skill_id)), "test learn button uses interpreter")
		skill_view._test_action(5)
		await render_frames(3)
		var lab: Control = skill_view._lab
		expect(lab != null and not lab._ids.is_empty(), "original animation viewer lists source definitions")
		lab.action(2)
		await render_frames(2)
		expect(lab._instances.size() == 2, "two-position preview has two independent source animation instances")
		await capture("original-animation-dual-%dx%d" % [resolution.x, resolution.y], resolution)
		lab.stop_all()
		await render_frames(2)
		lab.action(3)
		await render_frames(2)
		expect(lab._instances.size() == 2 and not lab._instances[0]._ended, "same-target preview retains the earlier source instance")
		await capture("original-animation-stacked-%dx%d" % [resolution.x, resolution.y], resolution)
		skill_view.back()
		await render_frames(3)
		expect(skill_view._lab == null, "leaving animation lab cancels its instances")
		menu.handle_back()
		menu.handle_back()
		for _i in 3: menu.navigate(1)
		menu.activate()
		await render_frames(3)
		expect(menu.page == "save", "save slot page renders")
		var slots: Control = menu._commerce
		if slots._infos[0].exists:
			slots.activate()
			slots.navigate(-1)
			slots.activate()
		else:
			slots.activate()
		await render_frames(3)
		expect(slots.message.contains("已保存"), "visual save action creates valid slot")
		await capture("save-slots-%dx%d" % [resolution.x, resolution.y], resolution)
		slots.activate()
		await render_frames(3)
		await capture("save-overwrite-%dx%d" % [resolution.x, resolution.y], resolution)
		slots.back()
		menu.handle_back()
		menu.open_test_shop()
		await render_frames(3)
		var shop: Control = menu._commerce
		await capture("shop-commands-%dx%d" % [resolution.x, resolution.y], resolution)
		shop.activate()
		shop.selected = 3
		shop.refresh()
		await render_frames(3)
		await capture("shop-buy-equipment-%dx%d" % [resolution.x, resolution.y], resolution)
		shop.activate()
		shop.navigate(1)
		await capture("shop-number-%dx%d" % [resolution.x, resolution.y], resolution)
		var before_purchase: int = state.gold
		shop.activate()
		expect(state.gold == before_purchase - 400, "real shop buys two test swords")
		await capture("shop-purchased-%dx%d" % [resolution.x, resolution.y], resolution)
		shop.back()
		shop.navigate(1)
		shop.activate()
		await capture("shop-sell-%dx%d" % [resolution.x, resolution.y], resolution)
		shop.back()
		shop.back()
		# Long lists use real source goods. Selecting does not transact or edit JSON.
		menu.open_test_shop()
		shop = menu._commerce
		for definition in data.database("Items"):
			if definition is Dictionary and int(definition.get("id", 0)) > 0 and load("res://runtime/scripts/ShopService.gd").catalog([[0, int(definition.id)]]).ok:
				shop.goods.append([0, int(definition.id)])
				if shop.goods.size() >= 32: break
		shop.refresh()
		shop.activate()
		for _i in 20: shop.navigate(1)
		var scrolled: int = shop._list.scroll_row
		await capture("shop-scrolled-down-%dx%d" % [resolution.x, resolution.y], resolution)
		shop.navigate(-1)
		expect(scrolled > 0 and shop._list.scroll_row == scrolled, "real source upward selection retains viewport")
		await capture("shop-cursor-up-%dx%d" % [resolution.x, resolution.y], resolution)
		shop.back()
		shop.back()
		menu.open_state_tools()
		await render_frames(3)
		var state_tools: Control = menu._commerce
		state_tools.action(0)
		state_tools.action(2)
		await capture("state-added-query-%dx%d" % [resolution.x, resolution.y], resolution)
		expect(state.has_state(int(state.party[0]), int(setup.toggle_state_id)), "visual state tools attach state")
		state_tools.action(1)
		state_tools.action(2)
		await capture("state-removed-query-%dx%d" % [resolution.x, resolution.y], resolution)
		expect(not state.has_state(int(state.party[0]), int(setup.toggle_state_id)), "visual state tools remove state")
		menu.handle_back()
		menu.open_test_tools()
		await capture("test-tools-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.activate()
		expect(menu.page == "actor_tools", "real source actor mutation tools render")
		var tools: Control = menu._commerce
		tools.action(2)
		expect(actor.atk_plus == 1, "real source mutation changes permanent bonus")
		await capture("actor-growth-%dx%d" % [resolution.x, resolution.y], resolution)
		tools.open_identity()
		tools._name_edit.text = "原生测试角色"
		tools.identity_action(0)
		tools._hue_edit.value = 120
		tools.identity_action(2)
		await capture("actor-identity-%dx%d" % [resolution.x, resolution.y], resolution)
		tools.close_identity()
		menu.handle_back()
		menu.handle_back()
		menu.navigate(-1)
		menu.activate()
		menu.activate()
		expect(menu.page == "status" and actor.actor_name == "原生测试角色", "status shows shared renamed actor")
		await capture("actor-updated-status-%dx%d" % [resolution.x, resolution.y], resolution)
		menu.back()
		menu.back()
		menu.open_screen_tools()
		await render_frames(3)
		var screen_lab: Control = menu._commerce
		expect(screen_lab.assets.size() > 1, "source Pictures are available in native test picker")
		screen_lab.action(1)
		await capture("pictures-source-dual-%dx%d" % [resolution.x, resolution.y], resolution)
		expect(game._screen_renderer.sprites.size() == 2, "actual source picture sprites use distinct IDs")
		screen_lab.select_asset("@test_picture")
		screen_lab.action(1)
		screen_lab.action(4)
		screen_lab.action(6)
		screen_lab.action(7)
		expect(state.screen.picture(1).snapshot().tone_target[0] == -80 and state.screen.effects_snapshot().tone_target[0] == -80, "preview buttons select non-neutral RGB/gray targets")
		await create_timer(1.1).timeout
		await capture("pictures-tone-rotation-%dx%d" % [resolution.x, resolution.y], resolution)
		screen_lab.action(8)
		screen_lab.action(9)
		await capture("screen-flash-shake-%dx%d" % [resolution.x, resolution.y], resolution)
		screen_lab.action(11)
		coordinator.call("close_menu")
		await render_frames(3)
		await capture("actor-updated-map-%dx%d" % [resolution.x, resolution.y], resolution)
		coordinator.open_menu()
		menu = coordinator.menu
		menu.open_movement_tools()
		await render_frames(4)
		var movement_lab: Control = menu._commerce
		expect(movement_lab.avatar != null and movement_lab.map != game._map, "native movement lab has isolated real-rendered map")
		var speed_before: float = movement_lab._speed.value
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = movement_lab._speed.get_global_transform_with_canvas() * Vector2(movement_lab._speed.size.x - 5, 7)
		click.global_position = click.position
		click.pressed = true
		root.push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click, true)
		await render_frames(2)
		expect(movement_lab._speed.value == speed_before + 1, "native mouse speed click at %s: %s -> %s; widget size=%s point=%s" % [resolution, speed_before, movement_lab._speed.value, movement_lab._speed.size, click.position])
		Input.action_press("ui_right")
		await create_timer(0.15).timeout
		Input.action_release("ui_right")
		expect(movement_lab.avatar.tile_position.x > 2, "walking still works after native speed arrow click")
		movement_lab.avatar.move_to(2, 4)
		movement_lab._speed.value = speed_before
		expect(movement_lab._viewport.size.y >= 288, "entire verification map fits at the minimum logical resolution")
		var movement_image: Image = movement_lab._viewport.get_texture().get_image()
		var red_point := Vector2i(movement_lab._viewport.size / 2) + Vector2i(-112, 64)
		expect(movement_image.get_pixelv(red_point).is_equal_approx(Color("b94e57")), "verification directional tile preserves its original color")
		var displayed_red := Vector2i(movement_lab._container.global_position + movement_lab._container.size / 2) + Vector2i(-112, 64)
		expect(root.get_texture().get_image().get_pixelv(displayed_red).is_equal_approx(Color("b94e57")), "displayed preview preserves the red tile, not only its offscreen texture")
		await capture("movement-lab-%dx%d" % [resolution.x, resolution.y], resolution)
		movement_lab.avatar.move_to(3, 2)
		movement_lab.avatar.motion.pattern = 1
		movement_lab.avatar._sync_position()
		await capture("movement-bush-%dx%d" % [resolution.x, resolution.y], resolution)
		movement_lab.avatar.move_to(5, 5)
		movement_lab.avatar.turn(8)
		movement_lab.map.request_action(Vector2i(5, 5), Vector2i.UP)
		await render_frames(2)
		expect(movement_lab._message.text.contains("柜台"), "rendered testing area uses production counter interaction")
		await capture("movement-counter-%dx%d" % [resolution.x, resolution.y], resolution)
		coordinator.close_menu()
		await render_frames(3)
	await check_source_animation(data)
	await check_character_graphics()
	await check_screen_pixels()
	# Deliberately missing skin: fallback must render and report, not fetch RTP.
	var previous_skin: String = str(system.get("windowskin_name", ""))
	system.windowskin_name = "__missing_skin_fixture__"
	coordinator.call("open_menu")
	await render_frames(3)
	await capture("skin-fallback", Vector2i(768, 768))
	expect(str(root.get_node("RuntimeState").get("diagnostics")).contains("__missing_skin_fixture__"), "missing skin is diagnosed")
	coordinator.call("close_menu")
	system.windowskin_name = previous_skin
	await render_frames(3)
	if measure:
		await benchmark()
	coordinator.return_to_title()
	await render_frames(4)
	var load_title: Control = current_scene
	await capture("title-continue", root.size)
	load_title._on_continue()
	await render_frames(3)
	await capture("load-slots", root.size)
	load_title._close_slots()
	load_title.queue_free()
	current_scene = null
	await render_frames(4)
	await create_timer(0.2).timeout
	for failure in failures:
		printerr("FAIL: ", failure)
	print("MENU RENDER TESTS: ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)


func check_source_animation(data: Script) -> void:
	var definitions: Array = data.database("Animations")
	var decoder: Script = load("res://runtime/scripts/RmxpAnimationData.gd")
	for definition in definitions:
		if not definition is Dictionary or str(definition.get("animation_name", "")).is_empty():
			continue
		var id := int(definition.id)
		var decoded: Dictionary = decoder.resolve(id)
		if not decoded.ok:
			continue
		var result: Dictionary = game._map.play_animation(id)
		expect(result.ok, "real source animation asset plays on map player")
		await render_frames(2)
		await capture("source-animation-%d" % id, root.size)
		if result.has("player") and is_instance_valid(result.player):
			result.player.stop()
		await render_frames(3)
		return
	expect(false, "sample has at least one available original animation")


func check_character_graphics() -> void:
	var resources := load("res://runtime/scripts/UIResources.gd")
	var source := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 4:
			source.fill_rect(Rect2i(x * 32, y * 32, 32, 32), Color(float(x) / 3, float(y) / 3, 0.25))
	source.fill_rect(Rect2i(0, 0, 32, 32), Color.RED)
	resources._textures["Graphics/Characters/__test__"] = ImageTexture.create_from_image(source)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var character: TextureRect = load("res://runtime/scripts/CharacterSprite.gd").new()
	character.size = Vector2(32, 32)
	viewport.add_child(character)
	character.call("configure", "__test__", 0, 8, 3)
	await render_frames(3)
	var pixel := viewport.get_texture().get_image().get_pixel(16, 16)
	expect(pixel.r > 0.95 and pixel.g > 0.95 and pixel.b < 0.3, "four-direction/four-frame atlas coordinates")
	character.call("configure", "__test__", 120, 2, 0)
	await render_frames(3)
	pixel = viewport.get_texture().get_image().get_pixel(16, 16)
	expect(pixel.g > 0.95 and pixel.r < 0.05 and pixel.b < 0.05, "120 degree hue rotates red to green without changing value")
	viewport.queue_free()
	await render_frames(3)
	resources._textures.erase("Graphics/Characters/__test__")


func check_screen_pixels() -> void:
	var state: Node = root.get_node("RuntimeState")
	var screen_script: Script = load("res://runtime/scripts/ScreenState.gd")
	var resources: Script = load("res://runtime/scripts/UIResources.gd")
	var previous: RefCounted = state.screen
	state.screen = screen_script.new()
	# Isolate compositing from source artwork; still use the actual OpenGL renderer.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 160)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.2, 0.4, 0.6)
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var camera := Camera2D.new()
	camera.position = Vector2(viewport.size) / 2
	viewport.add_child(camera)
	var marker := ColorRect.new()
	marker.position = Vector2(20, 60)
	marker.size = Vector2(8, 8)
	marker.color = Color.YELLOW
	viewport.add_child(marker)
	var renderer: Node = load("res://runtime/scripts/ScreenRenderer.gd").new()
	renderer.camera = camera
	viewport.add_child(renderer)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 50
	viewport.add_child(ui_layer)
	var ui := ColorRect.new()
	ui.color = Color.YELLOW
	ui.size = Vector2(16, 16)
	ui_layer.add_child(ui)
	var source := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	resources._textures["Graphics/Pictures/__red_fixture__"] = ImageTexture.create_from_image(source)
	source = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	source.fill(Color.GREEN)
	resources._textures["Graphics/Pictures/__green_fixture__"] = ImageTexture.create_from_image(source)
	paused = true
	state.show_picture(1, "__red_fixture__", {"x": 32, "y": 32})
	state.show_picture(2, "__green_fixture__", {"x": 48, "y": 40})
	await render_frames(3)
	var image := viewport.get_texture().get_image()
	expect(image.get_pixel(36, 36).r > 0.95 and image.get_pixel(52, 44).g > 0.95, "screen pixels: independent pictures, higher ID draws over lower")
	state.screen.start_shake(10, 1, 2)
	state.screen.advance(0.25)
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(image.get_pixel(32, 64).r > 0.95 and image.get_pixel(22, 64).b > 0.5, "screen pixels: paused test preview actually shifts map rendering")
	expect(image.get_pixel(36, 36).r > 0.95 and image.get_pixel(52, 44).g > 0.95, "screen pixels: camera shake does not move pictures")
	state.screen.start_shake(0, 0, 0)
	await render_frames(3)
	expect(absf(camera.offset.x) < 0.001 and viewport.get_texture().get_image().get_pixel(22, 64).r > 0.95, "screen pixels: shake reset restores map viewport")
	expect(renderer.sprites[1].texture == resources.texture("Graphics/Pictures/__red_fixture__"), "shared texture cache retains original resource")
	state.move_picture(2, {"origin": 1, "x": 120, "y": 100, "zoom_x": 200, "zoom_y": 200})
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(image.get_pixel(90, 78).g > 0.95 and image.get_pixel(153, 100).b > 0.5, "screen pixels: centered origin and independent scale")
	state.erase_picture(2)
	state.move_picture(1, {"x": 80, "y": 80, "origin": 1})
	state.rotate_picture(1, 90)
	state.screen.advance(1)
	state.rotate_picture(1, 0)
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(image.get_pixel(80, 65).r > 0.95 and image.get_pixel(94, 80).b > 0.5, "screen pixels: rotation changes rectangular footprint")
	state.tint_picture(1, [-255, 255, 0, 0])
	state.screen.start_tone_change([-51, 0, 0, 255])
	await render_frames(3)
	image = viewport.get_texture().get_image()
	var pixel := image.get_pixel(170, 140)
	expect(absf(pixel.g - pixel.b) < 0.015 and pixel.r < pixel.g - 0.15, "screen pixels: map RGB/gray tone applied")
	expect(image.get_pixel(80, 80).g > 0.95 and image.get_pixel(80, 80).r < 0.05, "screen pixels: per-picture tone independent of map tone")
	expect(image.get_pixel(8, 8).r > 0.95 and image.get_pixel(8, 8).g > 0.95 and image.get_pixel(8, 8).b < 0.05, "screen pixels: UI excluded from map tone")
	state.screen.start_tone_change([0, 0, 0, 0])
	state.tint_picture(1, [0, 0, 0, 0])
	state.move_picture(1, {"opacity": 128})
	await render_frames(3)
	image = viewport.get_texture().get_image()
	pixel = image.get_pixel(80, 80)
	expect(absf(pixel.r - 0.602) < 0.02 and absf(pixel.g - 0.199) < 0.02, "screen pixels: normal alpha blending")
	state.move_picture(1, {"opacity": 255, "blend_type": 1})
	await render_frames(3)
	pixel = viewport.get_texture().get_image().get_pixel(80, 80)
	expect(pixel.r > 0.95 and absf(pixel.g - 0.4) < 0.02, "screen pixels: additive blending")
	state.move_picture(1, {"blend_type": 2})
	await render_frames(3)
	pixel = viewport.get_texture().get_image().get_pixel(80, 80)
	expect(pixel.r < 0.02 and absf(pixel.g - 0.4) < 0.02, "screen pixels: subtractive blending")
	state.screen.start_flash([255, 255, 255, 128], 2)
	await render_frames(3)
	image = viewport.get_texture().get_image()
	expect(image.get_pixel(80, 80).r > 0.45 and image.get_pixel(170, 140).r > 0.55, "screen pixels: flash covers map and pictures")
	expect(image.get_pixel(8, 8).b < 0.05, "screen pixels: flash excludes UI")
	expect(image.save_png(capture_directory.path_join("screen-compositing-fixture.png")) == OK, "screen compositing screenshot saved")
	viewport.queue_free()
	state.screen = previous
	paused = false
	await render_frames(4)
	resources._textures.erase("Graphics/Pictures/__red_fixture__")
	resources._textures.erase("Graphics/Pictures/__green_fixture__")


func benchmark() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Warm up map, menu and glyph caches before resource and timing baselines.
	for _iteration in 20:
		coordinator.call("open_menu")
		benchmark_page(_iteration)
		await render_frames(2)
		coordinator.call("close_menu")
		await render_frames(2)
	if not prepare_benchmark_walk(): return
	await create_timer(3.0).timeout
	var before := resource_counts()
	var map_identity: int = game.get("_map").get_instance_id()
	var steps_before: int = root.get_node("RuntimeState").steps
	var started := Time.get_ticks_usec()
	var last := started
	var previous_segment := -1
	while Time.get_ticks_usec() - started < 60000000:
		var segment := int((Time.get_ticks_usec() - started) / 3000000)
		if segment != previous_segment:
			if segment % 2 == 1:
				request_benchmark_menu(int(segment / 2))
			else:
				coordinator.call("close_menu")
			previous_segment = segment
		advance_benchmark_walk()
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	coordinator.call("close_menu")
	await render_frames(5)
	var after := resource_counts()
	var elapsed := float(last - started) / 1000000.0
	var sorted := samples.duplicate()
	sorted.sort()
	var fps := samples.size() / elapsed
	var walked_steps: int = root.get_node("RuntimeState").steps - steps_before
	var p95: float = sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)]
	metrics = {"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "resolution": [768, 768], "duration_seconds": elapsed,
		"frames": samples.size(), "average_fps": fps, "p95_frame_ms": p95, "walked_steps": walked_steps, "walk_through": _walk_through, "walk_from": [_walk_from.x, _walk_from.y], "walk_to": [_walk_to.x, _walk_to.y], "resources_before": before, "resources_after": after,
		"passed": fps >= 59.0 and p95 <= 20.0, "workload": "Map585 smooth four-frame player walking + ten menu workloads including isolated movement map and picture/screen effects. Queued menu at whole-tile arrival; every 3s, warmed caches, 60 FPS cap"}
	var file := FileAccess.open(capture_directory.path_join("menu-benchmark.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	file.close()
	print("BENCHMARK: ", JSON.stringify(metrics))
	expect(fps >= 59.0 and p95 <= 20.0, "768x768 performance target: average >=59 FPS, P95 <=20ms")
	expect(walked_steps >= 20, "performance workload must actually finish player steps, not just render a stationary map")
	expect(after.nodes <= before.nodes + 2 and after.resources <= before.resources + 2, "repeated menu opens must not retain nodes/resources")
	expect(game.get("_map").get_instance_id() == map_identity, "benchmark menu switches do not reload map")
	await benchmark_uncapped()


func prepare_benchmark_walk() -> bool:
	game._player.configure_motion({"move_speed": 4, "through": false, "direction_fix": false, "walk_anime": true})
	var map: Node = game._map
	# Action-only decorations are safe while walking. Do not suppress or execute
	# source touch commands just to benchmark rendering. A documented through
	# fallback can use a wall corridor on a densely event-populated tower map.
	for through in [false, true]:
		for y in range(1, map.map_height() - 1):
			for x in range(1, map.map_width() - 1):
				var cell := Vector2i(x, y)
				for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
					var target: Vector2i = cell + direction
					if safe_walk_cell(map, cell) and safe_walk_cell(map, target) and map.can_move(cell, direction, through) and map.can_move(target, -direction, through):
						_walk_from = cell
						_walk_to = target
						_walk_direction = direction
						_walk_through = through
						game._player.configure_motion({"through": through})
						game._player.move_to(x, y)
						print("BENCHMARK WALK: ", cell, " <-> ", target, " through=", through)
						return true
	expect(false, "benchmark has a safe walk edge without touch triggers")
	return false


func safe_walk_cell(map: Node, cell: Vector2i) -> bool:
	if not map.valid(cell.x, cell.y): return false
	for id in map.event_ids_at(cell.x, cell.y):
		if map.animation_target(id).trigger in [1, 2]: return false
	return true


func request_benchmark_menu(iteration: int) -> void:
	_benchmark_page_pending = iteration
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	coordinator._input(event)


func advance_benchmark_walk() -> void:
	if coordinator.menu != null:
		if _benchmark_page_pending >= 0:
			benchmark_page(_benchmark_page_pending)
			_benchmark_page_pending = -1
		return
	if coordinator._pending_menu: return
	if game._player.is_idle():
		var direction := _walk_direction if game._player.tile_position == _walk_from else -_walk_direction
		game._player.move_straight(6 if direction == Vector2i.RIGHT else 4 if direction == Vector2i.LEFT else 2 if direction == Vector2i.DOWN else 8)


func benchmark_uncapped() -> void:
	Engine.max_fps = 0
	await create_timer(2).timeout
	var started := Time.get_ticks_usec()
	var last := started
	var intervals: Array[float] = []
	var render_cpu: Array[float] = []
	var render_gpu: Array[float] = []
	var previous := -1
	while Time.get_ticks_usec() - started < 30000000:
		var segment := int((Time.get_ticks_usec() - started) / 1500000)
		if segment != previous:
			coordinator.close_menu()
			if segment % 2 == 1:
				request_benchmark_menu(int(segment / 2))
			previous = segment
		advance_benchmark_walk()
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - last) / 1000)
		last = now
		render_cpu.append(RenderingServer.get_frame_setup_time_cpu() + RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	coordinator.close_menu()
	var elapsed := float(last - started) / 1000000
	var over_budget := 0
	for frame in intervals:
		if frame > 1000.0 / 60:
			over_budget += 1
	var result := {"resolution": [768, 768], "duration_seconds": elapsed, "frames": intervals.size(), "average_fps": intervals.size() / elapsed,
		"p95_frame_ms": percentile(intervals, 0.95), "p99_frame_ms": percentile(intervals, 0.99), "max_frame_ms": intervals.max(),
		"over_16_667ms_percent": 100.0 * over_budget / intervals.size(), "render_cpu_p95_ms": percentile(render_cpu, 0.95),
		"render_gpu_p95_ms": percentile(render_gpu, 0.95), "render_gpu_available": render_gpu.max() > 0,
		"workload": "Same smooth player walking + ten menu workloads including movement lab, Map585 and picture/screen effects every 1.5s; no max_fps cap, vsync disabled. CPU/GPU numbers are rendering only."}
	var file := FileAccess.open(capture_directory.path_join("menu-uncapped.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("UNCAPPED: ", JSON.stringify(result))
	Engine.max_fps = 60
	await render_frames(3)


func percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * fraction)) - 1)]


func benchmark_page(iteration: int) -> void:
	var menu: Control = coordinator.get("menu")
	if menu == null: return
	if iteration % 10 == 9:
		menu.open_movement_tools()
		menu._commerce.avatar.configure_motion({"step_anime": true})
	elif iteration % 10 == 8:
		menu.open_screen_tools()
		var tools: Control = menu._commerce
		tools.select_asset("@test_picture")
		tools.action(1)
		tools.action(2)
		tools.action(4)
		tools.action(6)
		tools.action(7)
		tools.action(8)
		tools.action(9)
	elif iteration % 10 == 7:
		menu.open_actor_tools()
	elif iteration % 10 == 5:
		menu.open_test_shop()
		menu._commerce.activate()
		menu._commerce.selected = 3
		menu._commerce.refresh()
	elif iteration % 10 == 6:
		menu.open_state_tools()
		menu._commerce.action(2)
	elif iteration % 10 == 3:
		menu.navigate(1)
		menu.activate()
	elif iteration % 10 in [2, 4]:
		menu.navigate(-1)
		menu.navigate(-1)
		menu.activate()
		menu.activate()
		var setup: Dictionary = load("res://runtime/scripts/RuntimeData.gd").test_config()
		menu._commerce._selection_id = int(setup.learn_skills[0])
		menu._commerce.refresh()
		if iteration % 10 == 4:
			menu._commerce._test_action(5)
			menu._commerce._lab.action(2)
		else:
			menu._commerce._test_action(1)
	elif iteration % 10 == 0:
		for _i in 3: menu.call("navigate", -1)
		menu.call("activate")
	else:
		menu.call("navigate", -1)
		menu.call("activate")
		menu.call("activate")
		menu.call("activate")
		menu.call("navigate", 1)


func resource_counts() -> Dictionary:
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))}


func capture(name: String, resolution: Vector2i) -> void:
	await render_frames(2)
	var image := root.get_texture().get_image()
	expect(image.get_size() == resolution, "capture is native resolution, not enlarged output")
	expect(image.save_png(capture_directory.path_join(name + ".png")) == OK, "screenshot saved: " + name)
	print("CAPTURE: ", name)


func render_frames(count: int) -> void:
	for _index in count:
		await process_frame
		await RenderingServer.frame_post_draw


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

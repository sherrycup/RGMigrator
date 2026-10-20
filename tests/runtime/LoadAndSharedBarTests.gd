## 职责：回归验证：实际标题和地图读档的进度、音乐与静音兼容、失败状态隔离，以及地图和物品页的唯一物品栏。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var saves: Script
var state: Node
var checks = 0
var failures: Array[String] = []
var captures = 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(640, 640)
	root.content_scale_size = Vector2i(640, 640)
	state = root.get_node("RuntimeState")
	state.flash_preferences.apply_display = false
	state.begin_new_game(Data.system(), {"enabled": false})
	saves = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	var graph = load("res://runtime/scripts/10_Support/Persistence/SaveGraph.gd")
	state.map_id = 23
	state.player_x = 9
	state.player_y = 6
	state.party = [2]
	state.variables["14"] = [2, 0]
	state.variables["5"] = [1, 1, 0, 1, 1, 0, 0, 1, 1, 1]
	state.inventory = {"item:2": 2}
	load("res://runtime/scripts/00_Game/Game_ActorInit.gd").apply(state.custom_data.live_view(), 2)
	state.gold = 321
	expect(saves.save_slot(1, state).ok, "seed fully validated source-map save")
	var path = saves.slot_path(1)
	var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
	var decoded = graph.decode(JSON.parse_string(envelope.payload))
	decoded.value.audio = {"playing": {}, "memory": {}, "fades": {}}
	envelope.payload = JSON.stringify(graph.encode(decoded.value).value)
	envelope.sha256 = envelope.payload.sha256_text()
	saves.write_text(path, JSON.stringify(envelope))
	var title = load("res://runtime/scripts/05_Title/Title.gd").new()
	root.add_child(title)
	current_scene = title
	title._load_game(1)
	var game = await _wait_loaded(title, "legacy")
	if game == null:
		_finish()
		return
	expect(state.gold == 321 and state.map_id == 23, "title load installs exact saved state")
	var music = state.audio.channels.get("BGM")
	expect(
		music != null and state.audio.definitions.BGM.name == "试炼区",
		"legacy empty audio recovers real map autoplay"
	)
	expect(
		music != null and music.playing and not music.stream_paused and music.volume_db > -40,
		"map music is playing, unpaused and audible"
	)
	await _capture("map-music")
	await _shared_bar(game)
	var event = game.event_map()._event_nodes[0]
	var saved_event_id = event.event_id
	event.direction_fix = true
	event.motion.direction = 6
	state.audio.stop("BGM")
	expect(saves.save_slot(2, state).ok, "save deliberate music stop")
	game._menus.load_flash_archive(2)
	game = await _wait_loaded(game, "silence")
	expect(
		game != null and not state.audio.channels.has("BGM"), "map load respects explicit silence"
	)
	if game == null:
		_finish()
		return
	expect(
		game.event_map().event_node(saved_event_id).motion.direction == 6,
		"saved event direction is restored in the new map, not consumed by the old scene"
	)
	var bgm = Data.system().title_bgm
	expect(
		state.audio.play("BGM", bgm, 5.0).ok and saves.save_slot(3, state).ok,
		"save another real track and its position"
	)
	game._menus.load_flash_archive(3)
	game = await _wait_loaded(game, "saved-track")
	expect(
		game != null and state.audio.definitions.BGM.name == bgm.name,
		"saved music has priority over map default"
	)
	expect(
		state.audio.channels.BGM.get_playback_position() >= 4.0,
		"actual scene switch preserves saved playback position"
	)
	var audio = load("res://runtime/scripts/10_Support/Audio/AudioRuntime.gd")
	expect(
		not (
			audio
			. decode_persistent({"playing": {}, "memory": {}, "fades": {}, "stopped": {"BGM": 1}})
			. ok
		),
		"malformed stop marker is rejected"
	)
	saves.write_text(saves.slot_path(4), "damaged")
	var before = state.gold
	game._menus.load_flash_archive(4)
	var deadline = Time.get_ticks_msec() + 60000
	while _progress() != null and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(
		state.game() == game and state.gold == before and not paused,
		"failed read preserves scene/state and releases pause"
	)
	game.queue_free()
	await process_frame
	_finish()


func _wait_loaded(previous: Node, label: String) -> Node:
	var start = Time.get_ticks_usec()
	var last = start
	var maximum = 0.0
	var frames = 0
	var texts: Dictionary = {}
	var deadline = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		var progress = _progress()
		if progress != null:
			texts[progress._label.text] = true
			if frames == 3:
				await _capture("loading-" + label)
		await process_frame
		var now = Time.get_ticks_usec()
		maximum = maxf(maximum, (now - last) / 1000.0)
		last = now
		frames += 1
		if current_scene != null and current_scene != previous and _progress() == null:
			print(
				"LOAD TIMING: ",
				JSON.stringify(
					{
						"case": label,
						"total_ms": (now - start) / 1000.0,
						"maximum_frame_ms": maximum,
						"frames": frames,
						"animated_text_states": texts.size()
					}
				)
			)
			expect(
				frames >= 3 and texts.size() >= 1,
				"load shows feedback before publication: " + label
			)
			expect(
				not paused and state.game() == current_scene,
				"new game owns input after load: " + label
			)
			return current_scene
	expect(false, "load deadline: " + label)
	return null


func _progress() -> Node:
	for node in root.get_children():
		if (
			node.get_script() != null
			and node.get_script().resource_path.ends_with("/SaveLoadProgress.gd")
			and not node.is_queued_for_deletion()
		):
			return node
	return null


func _shared_bar(game: Node) -> void:
	var hud = game._flash_hud
	var original = hud.item_canvas
	var frame = hud._item_frame
	expect(hud._item_layer.layer == 9, "normal map bar stays below Message layer20")
	_key(KEY_ESCAPE)
	var menu = game._menus.menu
	expect(menu != null, "open actual map menu")
	menu.set_process(false)
	_step(game, 8)
	menu.index = 0
	_key(KEY_ENTER)
	_step(game, 8)
	var page = menu.child
	expect(
		hud._item_layer.layer == 55,
		"same bar is raised above menu drawings only during item editing"
	)
	expect(page != null and not page._content.regions.has("presets"), "no duplicate preset window")
	expect(
		hud.item_canvas == original and hud._item_frame == frame and hud.itembar_process == 8,
		"same map bar node/frame is visible in items"
	)
	_key(KEY_ENTER)
	_key(KEY_A)
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	expect(
		page.slot == 1 and not hud.itembar_navigation_ready(),
		"shared cursor rejects duplicate rapid movement"
	)
	_step(game, 8)
	_key(KEY_ENTER)
	_step(game, 1)
	expect(
		hud._itembar_slot == page.slot and hud.slots[1][0] == page.selected_id(),
		"same shared bar receives the selected preset"
	)
	await _capture("shared-bar")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_step(game, 8)
	_key(KEY_ESCAPE)
	_step(game, 8)
	await process_frame
	expect(
		hud._item_layer.layer == 9, "return restores ordinary message occlusion on the same layer"
	)
	expect(
		game._menus.menu == null and hud.item_canvas == original and hud._itembar_slot == -1,
		"return to identical map bar without editing cursor"
	)


func _step(game: Node, count: int) -> void:
	for i in count:
		var menu = game._menus.menu
		if menu != null:
			menu._tick()
			if menu.child != null and menu.child.get("_content") != null:
				menu.child._content.set_process(false)
				menu.child._content._process(1.0 / 60)
		game._flash_hud._process(1.0 / 60)


func _key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(image.save_png("res://.godot/v058-load-" + label + ".png") == OK, "actual GPU " + label)
	captures += 1


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _finish() -> void:
	for message in failures:
		printerr("FAIL: ", message)
	print(
		"LOAD AND SHARED BAR: ",
		"PASSED" if failures.is_empty() else "FAILED",
		" / ",
		checks,
		" checks / ",
		captures,
		" GPU states"
	)
	quit(0 if failures.is_empty() else 1)

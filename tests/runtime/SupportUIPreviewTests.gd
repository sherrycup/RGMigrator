## 职责：回归验证：用真实地图和键盘核对援护UI临时预览、完整存档状态隔离、生命周期及无背景物品快捷栏。
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
var Codec: Script
var state: Node
var game: Node
var hud: CanvasLayer
var checks = 0
var captures = 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(640, 640)
	root.content_scale_size = Vector2i(640, 640)
	state = root.get_node("RuntimeState")
	Codec = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	state.flash_preferences.apply_display = false
	state.begin_new_game(Data.system(), {"enabled": false})
	state.set_process(false)
	state.party = [2]
	state.variables["14"] = [2, 0]
	state.variables["5"] = [1, 1, 0, 1, 1, 0, 0, 1, 1, 1]
	state.map_id = 10
	state.player_x = 5
	state.player_y = 5
	state.switches["3"] = true
	state.switches["160"] = false
	state.actor(2)
	load("res://runtime/scripts/00_Game/Game_ActorInit.gd").apply(state.custom_data.live_view(), 2)
	state.inventory = {"item:2": 2}
	game = load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	game._events_enabled = false
	root.add_child(game)
	await process_frame
	game.reset_event_execution()
	game.set_process(false)
	game._player.set_process(false)
	game._player.input_enabled = true
	hud = game._flash_hud
	hud.set_process(false)
	_step(8)
	expect(
		not hud.support_preview_enabled and hud.rows[1].is_empty(),
		"preview defaults off on an actual locked solo game"
	)
	await _capture("solo")
	var before = Codec.capture(state).duplicate(true)
	_key(KEY_F7)
	_step(8)
	expect(
		hud.support_preview_enabled and hud.rows[1].id == 3,
		"actual F7 displays source support actor3"
	)
	expect(
		hud.rows[1].hp == 3200 and hud.rows[1].maxhp == 4000 and hud.rows[1].level == 8,
		"preview uses original actor3 preset, not invented sample stats"
	)
	expect(
		hud._portraits[1].visible and hud.rows[1].name == Data.record("Actors", 3).character_name,
		"support portrait uses the source graphic"
	)
	expect(not state.actors.has(3), "display actor is never registered as a formal actor")
	var preview = hud._preview_actor
	hud.refresh_rows()
	expect(hud._preview_actor == preview, "unchanged preview reuses its detached actor")
	expect(
		Codec.capture(state) == before,
		"enabling and rendering preview leaves the complete save capture unchanged"
	)
	_key(KEY_F7, true)
	expect(hud.support_preview_enabled, "held-key echo does not toggle repeatedly")
	await _capture("support")
	_key(KEY_ESCAPE)
	game._menus.menu.set_process(false)
	_step(8)
	_key(KEY_ENTER)
	_step(8)
	var page = game._menus.menu.child
	expect(page.page == "flash_items", "actual menu opens the item page")
	var surface = page._content
	expect(
		not surface.regions.has("presets") and surface.regions.items.panel,
		"item view reuses the map bar instead of constructing another region"
	)
	expect(
		hud.slots.size() == 9 and hud._item_frame != null,
		"nine item frames and slot numbers are retained"
	)
	_key(KEY_ENTER)
	_key(KEY_A)
	_step(8)
	expect(
		page.stage == "preset" and hud._itembar_slot == page.slot,
		"preset selection cursor survives the transparent outer region"
	)
	await _capture("items")
	_key(KEY_F7)
	_step(8)
	expect(
		not hud.support_preview_enabled and hud.rows[1].is_empty(),
		"F7 works while the actual menu owns pause and keyboard input"
	)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_step(8)
	var menu = game._menus.menu
	expect(menu.child == null, "item page returns to the main menu normally")
	for i in 8:
		_key(KEY_DOWN)
	_key(KEY_ENTER)
	_step(8)
	expect(
		menu.child != null and menu.child.page == "flash_skills",
		"actual skill configuration page is open"
	)
	_key(KEY_F7)
	_step(8)
	expect(
		hud.visible_target() and hud.rows[1].id == 3,
		"skill configuration shows the same preview in its real HUD"
	)
	await _capture("skills")
	_key(KEY_ESCAPE)
	_step(8)
	_key(KEY_ESCAPE)
	_step(8)
	await process_frame
	expect(game._menus.menu == null and not paused, "normal cancellation releases menu pause")
	_key(KEY_F7)
	_step(8)
	expect(
		(
			not hud.support_preview_enabled
			and hud._preview_actor == null
			and not hud._portraits[1].visible
		),
		"turning off drops the preview actor and hides its portrait"
	)
	await _capture("off")
	_key(KEY_F7, false, true)
	_step(8)
	expect(hud.support_preview_enabled, "physical F7 input is supported")
	state.execution_reset.emit()
	_step(8)
	expect(
		not hud.support_preview_enabled and hud._preview_actor == null,
		"new-game/load execution reset clears the session-only flag"
	)
	state.change_party(3, true)
	state.variables["14"] = [2, 3]
	state.switches["160"] = true
	state.actor(3).set_project_parameter("maxhp", 4000)
	state.actor(3).hp = 777
	state.state_changed.emit()
	_step(8)
	_key(KEY_F7)
	_step(8)
	expect(
		hud.rows[1].hp == 777 and hud._preview_actor == null,
		"an unlocked real support actor keeps its real live stats"
	)
	_key(KEY_F7)
	_step(8)
	expect(hud.rows[1].hp == 777, "turning preview off never hides an unlocked real support actor")
	state.variables["14"] = [3, 0]
	state.party = [3]
	state.switches["160"] = false
	state.state_changed.emit()
	_key(KEY_F7)
	_step(8)
	expect(
		hud.rows[0].id == 3 and hud.rows[1].id == 2, "actor3 as main gets a distinct actor2 preview"
	)
	game._event_lab_hud = CanvasLayer.new()
	_key(KEY_F7)
	expect(
		hud.support_preview_enabled,
		"the event acceptance map retains its existing F7 exit shortcut"
	)
	game._event_lab_hud.free()
	game._event_lab_hud = null
	game.queue_free()
	await process_frame
	for message in failures:
		printerr("FAIL: ", message)
	print(
		"SUPPORT UI PREVIEW: ",
		"PASSED" if failures.is_empty() else "FAILED",
		" / ",
		checks,
		" checks / ",
		captures,
		" GPU states"
	)
	quit(0 if failures.is_empty() else 1)


func _step(count: int) -> void:
	for i in count:
		var menu = game._menus.menu
		if menu != null:
			menu._tick()
			if menu.child != null and menu.child.get("_content") != null:
				menu.child._content.set_process(false)
				menu.child._content._process(1.0 / 60)
		hud._process(1.0 / 60)


func _key(code: int, echo: bool = false, physical: bool = false) -> void:
	var event = InputEventKey.new()
	if physical:
		event.physical_keycode = code
	else:
		event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(
		image != null and image.save_png("res://.godot/v058-ui-" + label + ".png") == OK,
		"actual GPU " + label
	)
	captures += 1


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

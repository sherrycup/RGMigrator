## 职责：验证0.54原气泡边缘、长文分页、选项、数字输入、保存恢复与真实地图事件及GPU画面。
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
var Presentation: Script
const Graph = preload("res://runtime/scripts/10_Support/Persistence/SaveGraph.gd")
var checks = 0
var failures: Array[String] = []
var state: Node
var controller: RefCounted
var game: Node
var responses: Array = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640, 640)
	root.content_scale_size = Vector2i(640, 640)
	state = root.get_node("RuntimeState")
	Presentation = load("res://runtime/scripts/09_Effects/PresentationState.gd")
	state.flash_preferences.apply_display = false
	state.begin_new_game(Data.system(), {"enabled": false})
	state.party = [2]
	state.variables["14"] = [2, 0]
	state.map_id = 10
	state.actor(2)
	controller = state.flash_messages
	controller.responded.connect(func(id, kind, value): responses.append([id, kind, value]))
	game = load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	root.add_child(game)
	game._events_enabled = false
	game.set_process(false)
	game._player.set_process(false)
	game._dialogue._flash_view.set_process(false)
	game.reset_event_execution()
	controller.viewport_size = Vector2(640, 640)
	_test_edges()
	_test_pages()
	_test_choices_and_number()
	_test_presentation()
	await _test_event_and_gpu()
	game.queue_free()
	await process_frame
	for failure in failures:
		printerr("FAIL: ", failure)
	print("FLASH MESSAGE V054: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func _test_edges() -> void:
	for hud in [true, false]:
		state.switches["6"] = not hud
		for point in [Vector2(-100, -50), Vector2(0, 0), Vector2(640, 640), Vector2(900, 900)]:
			controller.reset()
			var status = controller.present({"kind": "message", "lines": ["\\m[名字]\\p[%d,%d]\\>边缘气泡" % [point.x, point.y]]})
			expect(status.ok, "edge packet accepted")
			var entry = controller.boxes[0]
			var geometry = entry.layout.geometry(state, controller.viewport_size, entry.model)
			var frame = Rect2(geometry.rect.position + Vector2(0, 25), entry.layout.box_size)
			expect(frame.position.x >= (224 if hud else 0) and frame.end.x <= 640 and frame.position.y >= 0 and frame.end.y <= 640, "entire source frame remains inside map region")
			expect(geometry.arrow.position.x >= 8 and geometry.arrow.end.x <= entry.layout.box_size.x - 8, "arrow attaches inside clamped bubble")
	controller.reset()
	state.switches["6"] = true
	var status = controller.present({"kind": "message", "lines": ["\\p[-90,-30]\\mo[3]可出屏幕"]})
	expect(status.ok and controller.boxes[0].layout.rectangle(state, controller.viewport_size, controller.boxes[0].model).position.x < 0, "source mode3 deliberately retains out-of-screen movement")
	controller.reset()
	status = controller.present({"kind": "message", "lines": ["\\fg[TestFace,99]错误头像"]})
	expect(not status.ok and controller.boxes.is_empty(), "face group bounds checked before history and live state")
	status = controller.present({"kind": "message", "lines": ["\\fg[TestFace,0]\\m[艾蕾]头像与名字"]})
	expect(status.ok and controller.boxes[0].layout.text_origin == Vector2(112, 56), "source96px face/name offsets restored")
	controller.reset()
	controller.present({"kind": "message", "lines": ["\\>" + "切换状态栏".repeat(20)]})
	state.switches["6"] = false
	controller.relayout(Vector2(640, 640))
	expect(controller.boxes[0].layout.box_size.x <= 416, "same-size viewport reflows when HUD reservation changes")
	state.switches["6"] = true

func _test_pages() -> void:
	controller.reset()
	controller.relayout(Vector2(360, 240))
	var text = "很长的气泡需要按可用高度换页。".repeat(24)
	var history_count = controller.history().size()
	controller.present({"kind": "message", "lines": ["\\mo[2]\\>" + text]}, 5401)
	var entry = controller.boxes[0]
	expect(entry.layout.box_size.x <= 360 and entry.layout.box_size.y <= 190 and not entry.model.page_breaks.is_empty(), "long text bounds use available pixel height")
	for i in 100:
		controller.tick()
	var first = entry.model.plain_text()
	expect(entry.model.state == 2 and first.length() < text.length() and entry.model.page_pending_token == entry.model.cursor, "automatic page pauses before any glyph on next page")
	for i in 20:
		controller.tick()
	expect(entry.model.plain_text() == first and not entry.released, "page pause cannot advance interpreter or invisible glyphs")
	controller.confirm()
	controller.confirm()
	expect(entry.model.pageon > 0 and entry.model.state != -1, "confirmation during scrolling cannot close message")
	_finish_text(entry)
	expect(entry.model.plain_text() == text and entry.model.state == 3 and controller.history().size() == history_count + 1, "all pages retain glyphs and record history once")
	controller.confirm()
	for i in 11:
		controller.tick()
	expect(responses.count([5401, "message", null]) == 1 and controller.boxes.is_empty(), "only final close releases response once")
	controller.present({"kind": "message", "lines": ["\\mo[2]\\>" + text]}, 5402)
	entry = controller.boxes[0]
	for i in 60:
		controller.tick()
	controller.relayout(Vector2(640, 640))
	_finish_text(entry)
	expect(entry.model.plain_text() == text and entry.layout.box_size.x <= 640, "resize reflows same tokens without dropping or repeating letters")
	controller.cancel_request(5402)
	expect(controller.boxes.is_empty() and not responses.has([5402, "message", null]), "cancelled page never responds")

func _test_choices_and_number() -> void:
	controller.reset()
	controller.relayout(Vector2(320, 240))
	var choices = ["第一项".repeat(12), "第二项", "第三项".repeat(10)]
	controller.present({"kind": "choice", "lines": ["\\mo[2]\\>问题".repeat(3)], "choices": choices, "cancel": 5}, 5403)
	var entry = controller.boxes[0]
	_finish_text(entry)
	expect(entry.layout.choice_rects.size() == 3 and entry.layout.choice_rects[0].size.y > entry.layout.rows[0].height, "wrapped option has its own complete rectangle")
	controller.handle_key(KEY_DOWN)
	var rect: Rect2 = entry.layout.choice_rects[1]
	expect(entry.choice_index == 1 and rect.position.y >= entry.model.page_scroll and rect.end.y <= entry.model.page_scroll + entry.layout.text_size.y + 0.01, "cursor navigation scrolls actual selected option into view")
	controller.handle_key(KEY_ESCAPE)
	for i in 11:
		controller.tick()
	expect(responses.has([5403, "choice", -1]), "cancel returns correct branch after close")
	controller.relayout(Vector2(640, 640))
	state.variables["99"] = 129
	controller.present({"kind": "number", "lines": ["\\mo[2]\\>输入数值"], "variable": 99, "digits": 3}, 5404)
	entry = controller.boxes[0]
	_finish_text(entry)
	controller.handle_key(KEY_RIGHT)
	controller.handle_key(KEY_DOWN)
	expect(entry.digit_index == 1 and entry.number == 119 and entry.layout.footer_height == 32, "digit cursor adjusts only chosen decimal place with reserved footer")
	controller.confirm()
	for i in 11:
		controller.tick()
	expect(responses.has([5404, "number", 119]) and state.variables["99"] == 129, "view returns number; interpreter owns variable write")

func _test_presentation() -> void:
	controller.reset()
	controller.relayout(Vector2(360, 240))
	controller.present({"kind": "message", "lines": ["\\mo[2]\\>" + "分页保存".repeat(90)]}, 5405)
	var entry = controller.boxes[0]
	for i in 100:
		controller.tick()
	var text = entry.model.plain_text()
	var saved = Presentation.capture(state)
	var prepared = Presentation.prepare(saved)
	expect(prepared.ok and entry.model.page_pending_token >= 0, "paused page saves in validated production presentation envelope")
	if prepared.ok:
		controller.reset()
		Presentation.restore(state, prepared.value, game)
		entry = controller.boxes[0]
		expect(entry.model.plain_text() == text and entry.model.state == 2 and entry.model.page_pending_token == entry.model.cursor, "restore retains same page pause, painted text and cursor")
		_finish_text(entry)
		expect(entry.model.plain_text() == "分页保存".repeat(90), "restored page finishes remaining text once")
	var invalid = Graph.clone(prepared.value)
	invalid.messages[0].message_ui.page_pending_token = 999999
	expect(not Presentation.prepare(Presentation._pack(invalid)).ok, "malformed saved page rejected before restore")
	controller.reset()
	controller.relayout(Vector2(640, 640))
	controller.present({"kind": "message", "lines": ["\\mo[1]\\mu[2,-4]x"]}, -1, 0, true)
	controller.advance(0)
	for i in 6:
		controller.tick()
	expect(controller.boxes[0].model.offset == Vector2(0, 12), "authoring40 movement duration preserved from rxdata")
	controller.reset()

func _test_event_and_gpu() -> void:
	# 真实地图中已有文章，从生产解释器/请求代理/覆盖层到同一控制器。
	var map = Data.map(3)
	var source: Array = map.events["22"].pages[0].list
	var article: Array = []
	for command in source:
		if command.code == 101 or (not article.is_empty() and command.code == 401):
			article.append(command.duplicate(true))
		elif not article.is_empty():
			break
	expect(not article.is_empty(), "real Map003EV022 article located")
	var interpreter = game._interpreter
	state.variables["98"] = 0
	article.append({"code": 122, "indent": 0, "parameters": [98, 98, 1, 0, 1]})
	article.append({"code": 0, "indent": 0, "parameters": []})
	interpreter.start(article, 22)
	game._event_ui.pump(true)
	expect(controller.boxes.size() == 1 and controller.boxes[0].layout.name_text == "老人", "real map article reaches original bubble with name")
	_finish_text(controller.boxes[0])
	controller.confirm()
	for i in 4000:
		if i % 32 == 0:
			await process_frame
		controller.tick()
		game._event_ui.pump(true)
		interpreter.advance(1.0 / 60)
		if not controller.boxes.is_empty() and controller.boxes[0].model.state in [2, 3]:
			controller.confirm()
		if not interpreter.running and controller.boxes.is_empty():
			break
	expect(state.variables["98"] == 1 and not interpreter.running, "map interpreter continues once after close, reward cannot repeat")
	if state.variables["98"] != 1 or interpreter.running:
		print("V054 EVENT DIAGNOSTIC: ", {"value": state.variables["98"], "running": interpreter.running, "wait": interpreter.wait_kind(), "boxes": controller.boxes.size(), "broker": game._event_ui.active, "commands": article})
	for i in 30:
		controller.tick()
		interpreter.advance(1.0 / 60)
	expect(state.variables["98"] == 1, "completed dialogue cannot replay variable reward")
	var history_before = controller.history().size()
	interpreter.start([
		{"code": 117, "indent": 0, "parameters": [19]},
		{"code": 122, "indent": 0, "parameters": [98, 98, 1, 0, 1]},
		{"code": 0, "indent": 0, "parameters": []}], 0)
	for i in 5000:
		if i % 32 == 0:
			await process_frame
		controller.tick()
		game._event_ui.pump(true)
		interpreter.advance(1.0 / 60)
		if not controller.boxes.is_empty() and controller.boxes[0].model.state in [2, 3]:
			controller.confirm()
		if not interpreter.running and controller.boxes.is_empty():
			break
	expect(not interpreter.running and state.variables["98"] == 2 and state.variables["101"] == 0 and controller.history().size() > history_before, "real117 common19 expands source copyright and continues exactly once")
	controller.reset()
	controller.present({"kind": "message", "lines": ["\\p[1]\\>跟随事件"]})
	var entry = controller.boxes[0]
	var character = game.event_map().event_node(1)
	if character != null:
		var before = entry.layout.anchor(state)
		var old_position = character.position
		character.position += Vector2(12, -8)
		expect(entry.layout.anchor(state) == before + Vector2(12, -8), "actual event anchor follows canvas position")
		character.position = old_position
	controller.reset()
	if DisplayServer.get_name() != "headless":
		controller.reset()
		controller.present({"kind": "message", "lines": ["\\fg[TestFace,0]\\m[艾蕾]\\p[628,608]\\>原素材气泡、名字和头像。\\C[5]控制码保留。"]})
		_finish_text(controller.boxes[0])
		await _capture("dialogue")
		controller.reset()
		state.switches["6"] = false
		controller.present({"kind": "choice", "lines": ["\\m[老人]\\p[420,420]\\>请选择接下来的行动："], "choices": ["继续前进并检查下一层的入口，同时记录当前地图中的线索与道路。", "查看周围", "返回"], "cancel": 5})
		_finish_text(controller.boxes[0])
		var event = InputEventKey.new()
		event.pressed = true
		event.keycode = KEY_DOWN
		root.push_input(event, true)
		expect(controller.boxes[0].choice_index == 1, "actual Viewport keyboard reaches bubble navigation")
		for i in 24:
			controller.tick()
		await _capture("choice")
		controller.reset()
		controller.present({"kind": "number", "lines": ["\\m[输入]\\p[320,420]\\>左右选位，上下调整"], "variable": 99, "digits": 3})
		_finish_text(controller.boxes[0])
		controller.handle_key(KEY_RIGHT)
		await _capture("number")
		controller.reset()
		controller.present({"kind": "message", "lines": ["\\mo[1]\\AL\\p[384,536]\\>获得 黄钥匙 +1\\bo[255]\\w[20]\\t[20]"]}, -1, 0, true)
		for i in 4:
			controller.tick()
		await _capture("hint")
		controller.reset()
		state.switches["6"] = false
		controller.present({"kind": "message", "lines": ["\\m[老人]\\p[620,620]\\>" + "长文本按可用高度分页，确认后继续。".repeat(55)]})
		for i in 100:
			controller.tick()
		expect(controller.boxes[0].model.state == 2, "actual640px canvas reaches automatic page pause")
		await _capture("pages")
		expect(game._menus.open_flash_history(), "actual history entry opens while page is paused")
		var scroll = controller.boxes[0].model.page_scroll
		game._dialogue._flash_view._process(1)
		expect(controller.boxes[0].model.page_scroll == scroll and controller.boxes[0].model.state == 2, "history pauses live bubble clock")
		await _capture("history")
		game._menus.menu.handle_key(KEY_TAB)
		expect(game._menus.menu.mode_index == 1, "history switches to independent hint channel")
		game._menus.close_menu()
		controller.reset()

func _finish_text(entry: Dictionary) -> void:
	for i in 12000:
		if entry.model.state == 3 or entry.model.finished():
			return
		if entry.model.state == 2:
			controller.confirm()
		controller.tick()
	expect(false, "text must finish within bounded ticks")

func _capture(label: String) -> void:
	game._dialogue._flash_view._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var path = "res://.godot/v054-" + label + ".png"
	expect(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "GPU capture " + label)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

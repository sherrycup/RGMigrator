## 职责：回归验证共用字体塑形、分页、窗口内容滚动、裁切、输入及过渡生命周期。
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
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Layout = preload("res://runtime/scripts/04_UI_Common/UILayout.gd")
const Text = preload("res://runtime/scripts/04_UI_Common/UITextLayout.gd")
const Block = preload("res://runtime/scripts/04_UI_Common/UITextBlock.gd")
const Transition = preload("res://runtime/scripts/04_UI_Common/UITransition.gd")
const Keys = preload("res://runtime/scripts/04_UI_Common/UIInput.gd")
var checks = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	expect(root.get_texture().get_image().save_png("res://.godot/v053-ui-"+name+".png") == OK, "actual GPU capture: "+name)

func run() -> void:
	root.size = Vector2i(640, 640)
	root.get_node("RuntimeState").begin_new_game(load("res://runtime/scripts/00_Game/RuntimeData.gd").system())
	expect(Layout.DESIGN_SIZE == Vector2(640,640) and Layout.usable_rect(Vector2(640,640),true) == Rect2(224,0,416,640), "original final source canvas and map HUD area")
	expect(Layout.usable_rect(Vector2(120,90),true).size.x == 48, "narrow viewport retains a usable text area")
	expect(Layout.fit_rect(Rect2(-10,80,300,100),Rect2(20,10,100,90)) == Rect2(20,10,100,90), "oversized rectangle fits the actual bounds")
	var style = {"font_name":"楷体", "font_size":22}
	var native_font = Text.font(style)
	expect(is_same(native_font,load("res://runtime/scripts/06_Message/MessageText.gd").font(style)), "Message and common UI use the same actual font")
	expect(Text.measure("中文 AV",style) == native_font.get_string_size("中文 AV",HORIZONTAL_ALIGNMENT_LEFT,-1,22), "measurement matches the actual shaped font")
	var source = "中文换行 Mixed text alpha beta gamma\nÁÁÁÁÁÁÁÁ and 世界。\f下一页保留。"
	var formatted = Text.layout(source,style,130,65)
	expect(formatted.ok and formatted.pages.size()>2 and not formatted.overflow, "pixel width and height determine pages; explicit page break is preserved")
	var previous = -1
	var lines = 0
	for page in formatted.pages:
		expect(page.height <= 65, "page uses the available pixel height")
		for line in page.lines:
			lines += 1
			expect(line.width <= 130.01 and line.start >= previous, "native shaped line is ordered and fits the available width")
			expect(line.start >= source.length() or source.unicode_at(line.start) != 769, "wrapping never splits a combining sequence: %d..%d %s" % [line.start,line.end,source.substr(line.start,line.end-line.start)])
			previous = line.end
	expect(lines > 4 and previous == source.length(), "all source text reaches the last page without a fixed four-line truncation")
	expect(not Text.layout("text",style,0,20).ok, "zero text area is rejected without a wrap loop")
	var big = Text.layout("中",{"font_size":80},10,10)
	expect(big.ok and big.overflow, "oversized single glyph is reported for clipping instead of discarded")
	var block = Block.new()
	block.position = Vector2(24,210)
	block.size = Vector2(270,100)
	block.configure(source, style.merged({"font_color":Color.WHITE,"line_space":4}))
	root.add_child(block)
	expect(block.clip_contents and block.page_count()>=2, "shared text control clips and exposes pages")
	block.set_page(999)
	expect(block.page == block.page_count()-1, "page selection clamps to the current layout")
	var list = load("res://runtime/scripts/04_UI_Common/WindowCommand.gd").new()
	list.position = Vector2(24,24)
	list.size = Vector2(300,160)
	root.add_child(list)
	var commands: Array = []
	for i in 12: commands.append({"text":"原窗口项目 %02d"%(i+1),"enabled":i!=8})
	list.configure(commands,11)
	expect(list.scroll_row == 8 and not list._rows[0].visible and list._rows[11].visible, "actual content scrolls to the selected item")
	expect(list._rows[11].position.y == 96 and list._cursor.position.y == 112, "text and cursor show the same selected row")
	var contents: Control = list.content
	list.move_selection(-1)
	expect(is_same(contents,list.content) and list.index == 10, "navigation reuses the existing window contents")
	await _capture("scroll-last-page")
	block.set_page(0)
	await _capture("text-first-page")
	list.size.y = 224
	await process_frame
	expect(list.scroll_row == 6 and list._rows[10].visible, "window resize reflows the scroll viewport")
	list.active = false
	expect(not list._cursor.visible and not list.is_processing(), "inactive window stops cursor animation immediately")
	list.active = true
	list.select(0)
	expect(list.scroll_row == 0 and list._rows[0].visible and not list._rows[11].visible, "scroll returns to the first page")
	list.select_rect(Rect2(-12,-12,40,40))
	expect(list._cursor.position == Vector2(16,16) and list._cursor.size == Vector2(28,28), "cursor remains clipped inside the window content area")
	list.column_count = 2
	list.select(11)
	expect(list.item_rect(11).position.x == 134 and list.item_rect(11).size.x == 134, "shared selection supports column geometry")
	list.configure([])
	expect(not list.current_enabled() and not list._cursor.visible, "empty command list has no enabled selection or cursor")
	var event = InputEventKey.new()
	event.physical_keycode = KEY_DOWN
	event.pressed = true
	event.echo = true
	expect(Keys.key(event) == KEY_DOWN and Keys.accepts(event), "physical-key fallback accepts repeated navigation")
	event.keycode = KEY_ENTER
	expect(not Keys.accepts(event), "held confirm does not execute an action repeatedly")
	event.keycode = KEY_ESCAPE
	expect(not Keys.accepts(event), "held cancel does not close a second page")
	event.echo = false
	expect(Keys.accepts(event), "first cancel press is accepted")
	event.pressed = false
	expect(not Keys.accepts(event) and not Keys.accepts(InputEventMouseButton.new()), "release and mouse events are not keyboard commands")
	var panel = Control.new()
	root.add_child(panel)
	var transition = Transition.new()
	transition.play(panel,{"position":Vector2(64,32)},1.0)
	transition.advance(0.25)
	expect(panel.position == Vector2(16,8), "nonblocking transition advances by supplied time")
	transition.advance(0.25)
	expect(panel.position == Vector2(16,8), "same engine frame cannot advance animation twice")
	transition.play(panel,{"position":Vector2(32,0)},1.0)
	transition.advance(0.25)
	expect(panel.position == Vector2(16,8), "replacement transition cannot reuse elapsed time in the same frame")
	await process_frame
	transition.advance(0.25)
	expect(panel.position == Vector2(20,6), "replacement starts from the current visual position")
	transition.cancel()
	transition.advance(100)
	expect(panel.position == Vector2(20,6) and not transition.active(), "cancellation preserves current properties")
	transition.play(panel,{"position":Vector2.ONE},0)
	expect(panel.position == Vector2.ONE and not transition.active(), "zero-duration transition completes immediately")
	transition.play(panel,{"position":Vector2.ZERO},1)
	panel.queue_free()
	await process_frame
	expect(not transition.advance(0.1), "freed page invalidates its transition without a stale callback")
	list.queue_free()
	block.queue_free()
	await process_frame
	var title = load("res://runtime/scripts/05_Title/TitleScreen.gd").new()
	root.add_child(title)
	await process_frame
	expect(title._artwork != null and title.mouse_filter == Control.MOUSE_FILTER_IGNORE, "native title has one keyboard selection owner and original artwork")
	if DisplayServer.get_name() != "headless":
		for frame in 20: await process_frame
	await _capture("title")
	title.index = 5
	title.activate()
	expect(title.child != null and title.page_progress == 0, "actual title starts its owned nonblocking child transition")
	title.back()
	title._tick()
	expect(title.child == null and title.ready_for_input(), "returning during the title transition cancels the old page")
	title.queue_free()
	await process_frame
	var state = root.get_node("RuntimeState")
	state.party = [2,3]
	state.variables["14"] = [2,3]
	state.actor(2)
	state.actor(3)
	var initializer = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	var source_api = load("res://runtime/scripts/02_Event/NativeScriptSource.gd")
	var initialize_body = "Actor_Init.load(2)\nActor_Init.load(3)\n"
	initializer.start([{"code":355,"indent":0,"parameters":[initialize_body],"_script_binding":source_api.binding(initialize_body)},{"code":0,"indent":0,"parameters":[]}],0)
	expect(not initializer.running and state.actor(2).hp > 0 and state.actor(3).hp > 0, "actual menu receives initialized original actor values")
	var menu = load("res://runtime/scripts/08_Menu/Main/MenuScreen.gd").new()
	root.add_child(menu)
	await process_frame
	expect(menu._artwork != null and menu.mouse_filter == Control.MOUSE_FILTER_IGNORE, "actual menu uses original drawing and one keyboard selection owner")
	await _capture("menu")
	menu.queue_free()
	await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("UI COMMON V053: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks)
	quit(0 if failures.is_empty() else 1)

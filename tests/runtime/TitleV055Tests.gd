## 职责：回归验证原标题图形、16帧输入门控、附页返回及真实键盘与新游戏流程。
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
const Layout = preload("res://runtime/scripts/05_Title/TitleLayout.gd")
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var Cache: Script
var Saves: Script
var checks = 0
var failures: Array[String] = []
var _captures = 0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Cache = load("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
	Saves = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	root.size = Vector2i(640,640)
	root.content_scale_size = Vector2i(640,640)
	var state = root.get_node("RuntimeState")
	state.flash_preferences.apply_display = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--flow="):
			await _flow(argument.trim_prefix("--flow="))
			_finish()
			return
	var canvas = Vector2(640,640)
	var center = Layout.command_pose(0,0,16,canvas)
	expect(center.position == Vector2(320,544) and center.zoom == 1 and center.opacity == 1,"native command center and emphasis")
	var side = Layout.command_pose(1,0,16,canvas)
	expect(side.position == Vector2(480,544) and is_equal_approx(side.zoom,0.8) and is_equal_approx(side.opacity,128.0/255),"native side command scale/alpha")
	expect(Layout.command_pose(-2,0,16,canvas).opacity == 0,"outer reused slots invisible at rest")
	expect(Layout.command_pose(1,0.5,16,canvas).position == Vector2(400,544),"continuous half carousel movement")
	expect(Layout.command_pose(0,0,0,canvas).position.y == 640 and Layout.command_pose(0,0,0,canvas).opacity == 0,"subpage commands move down96 and fade out")
	expect(Layout.mode_pose(1,1,16,canvas).position == Vector2(320,320) and Layout.mode_pose(0,1,16,canvas).position == Vector2(96,128),"source difficulty diagonal224x192")
	expect(Layout.mode_pose(3,3,16,canvas).opacity == 128.0/255,"EX selectable with original half opacity")
	expect(Layout.tag_rect(8,canvas) == Rect2(480,0,320,48),"tag enters from right at20 pixels/tick")
	for id in 7:
		var texture = Cache.title("title/com_%d" % id)
		expect(texture != null and texture.get_size() == Vector2(241,49),"original command texture%d" % id)
	for id in 4:
		var texture = Cache.title("mode/mode_%d" % (id+1))
		expect(texture != null and texture.get_size() == Vector2(288,160),"actual Mode_1 through4 texture%d" % id)
	var title = _title()
	await process_frame
	var screen = title._flash
	_freeze(screen)
	_ticks(screen,16)
	expect(screen.index == 0 and screen.page == "title","fresh title selects new game")
	expect(screen._background.texture != null and screen._logo.position == Vector2(80,60),"first background visible and source logo settled")
	expect(_buttons(screen) == 0,"Flash title draws original command images without Godot buttons")
	await _capture("title")
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	expect(screen.index == 1 and not screen.ready_for_input(),"actual viewport keys gated during carousel")
	_ticks(screen,8)
	await _capture("carousel-half")
	_ticks(screen,8)
	_key(KEY_ENTER)
	expect(screen.page == "title" and screen.child == null,"no-save continue selectable gray and cannot activate")
	_key(KEY_RIGHT)
	_ticks(screen,16)
	_key(KEY_ENTER)
	expect(screen.index == 2 and screen.page == "title","source disabled chapter remains selectable")
	await _capture("disabled-command")
	for step in 5:
		_key(KEY_RIGHT)
		_ticks(screen,16)
	expect(screen.index == 0,"carousel wraps all seven commands")
	_key(KEY_LEFT)
	_ticks(screen,16)
	expect(screen.index == 6,"carousel wraps backward")
	_key(KEY_RIGHT)
	_ticks(screen,16)
	_key(KEY_ENTER)
	_key(KEY_RIGHT)
	expect(screen.page == "mode" and screen.difficulty == 1,"mode defaults Hard and gates opening input")
	_ticks(screen,16)
	expect(screen.title_progress == 0 and screen.logo_progress == 0,"one title clock completes native page/logo transition")
	await _capture("difficulty-hard")
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	expect(screen.difficulty == 2 and screen.mode_ticks == 0,"difficulty ignores repeated input during16 ticks")
	_ticks(screen,16)
	_key(KEY_RIGHT)
	_ticks(screen,16)
	_key(KEY_RIGHT)
	expect(screen.difficulty == 3 and screen.mode_ticks == 16,"EX selectable and upper boundary clamped")
	await _capture("difficulty-ex")
	_key(KEY_ESCAPE)
	_key(KEY_ENTER)
	expect(screen.page == "title" and not screen.ready_for_input(),"closing page rejects confirm")
	_ticks(screen,16)
	_key(KEY_ENTER)
	_ticks(screen,16)
	expect(screen.difficulty == 3,"difficulty persists after returning to title")
	var selected: Array = []
	screen.new_game_requested.disconnect(title._on_flash_new_game)
	screen.new_game_requested.connect(func(id: int): selected.append(id))
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	expect(selected == [3],"new-game confirm emits once with exact mode")
	title.queue_free()
	await process_frame
	title = _title()
	await process_frame
	screen = title._flash
	_freeze(screen)
	_ticks(screen,16)
	for command in [5,4,3]:
		screen.index = command
		screen.activate()
		var page = screen.child
		_freeze(page)
		_ticks(screen,16)
		expect(page != null and page.entrance == 16,"native child%d entrance complete" % command)
		if command == 5:
			expect(page._panel_texture != null and page._panel_texture.get_size() == Vector2(592,400) and _buttons(page) == 0,"settings original panel and artwork")
			var volume = state.flash_preferences.bgm_volume
			_key(KEY_LEFT)
			expect(state.flash_preferences.bgm_volume == maxi(0,volume-1),"real settings edits same preference instance")
			await _capture("settings-1")
			_key(KEY_E)
			await _capture("settings-2")
			_key(KEY_E)
			await _capture("settings-3")
			expect(page.sheet == 3,"unfinished pages retain original three-page selector")
		elif command == 4:
			var bgm = state.audio.definitions.duplicate(true)
			var channels = state.audio.channels.duplicate()
			expect(page.progress == 28 and page.playing and is_equal_approx(page._pointer_angle,0),"native six initial ticks settle pointer")
			await _capture("music")
			_key(KEY_DOWN)
			_key(KEY_DOWN)
			expect(page.index == 1 and page.progress == 0,"CD28-tick transition gates repeated input")
			_ticks(screen,14)
			await _capture("music-half")
			_ticks(screen,14)
			expect(page.progress == 28 and page._disc_offsets == [-320.0,0.0,320.0],"native discs reuse slots after movement")
			expect(state.audio.definitions == bgm and state.audio.channels == channels,"source empty lookup leaves BGM untouched")
			_key(KEY_UP)
			_ticks(screen,28)
			_key(KEY_UP)
			_ticks(screen,28)
			expect(page.index == 9,"music wraps to original tenth slot")
		else:
			var gold = state.gold
			await _capture("merit")
			_key(KEY_DOWN)
			_ticks(screen,16)
			expect(page.index == 3,"native merit down selects fourth category")
			_key(KEY_UP)
			_ticks(screen,16)
			expect(page.index == 1,"native merit up returns to middle category")
			_key(KEY_ENTER)
			_ticks(screen,16)
			expect(page.book and page.book_progress == 16 and state.gold == gold,"original sample book has no invented payout")
			await _capture("merit-book")
			_key(KEY_ESCAPE)
			_key(KEY_ESCAPE)
			expect(not page.book and screen.child == page,"repeated cancel keeps parent while book closes")
			_ticks(screen,16)
		_key(KEY_ESCAPE)
		_ticks(screen,16)
		expect(screen.child == null and screen.index == command and screen.ready_for_input(),"child%d returns source command cursor after16 ticks" % command)
		await process_frame
	await _capture("return-title")
	root.size = Vector2i(800,640)
	root.content_scale_size = Vector2i(800,640)
	await process_frame
	await process_frame
	expect(screen.size.x == 800 and screen._logo.position.x == 160,"resize centers native logo")
	root.size = Vector2i(640,640)
	root.content_scale_size = Vector2i(640,640)
	await process_frame
	var bounded = true
	for tick in 520:
		_ticks(screen,1)
		if tick % 8 == 0:
			await process_frame
		bounded = bounded and screen._frames.size() <= 32 and screen._background_pending.size() <= 8 and screen.frame < 480
	expect(bounded,"480-frame background loop bounds32 cached textures and8 requests")
	if DisplayServer.get_name() != "headless":
		var intervals: Array[float] = []
		var first_texture = screen._background.texture
		var previous = Time.get_ticks_usec()
		screen.set_process(true)
		for tick in 180:
			await process_frame
			var now = Time.get_ticks_usec()
			intervals.append((now-previous)/1000.0)
			previous = now
		screen.set_process(false)
		intervals.sort()
		expect(screen._background.texture != first_texture and screen._background.texture != null,"background advances original frame assets during actual rendered frames")
		print("TITLE FRAME MS: ",JSON.stringify({"samples":intervals.size(),"p50":intervals[90],"p95":intervals[171],"maximum":intervals.back()}))
	title.queue_free()
	await process_frame
	_seed_save()
	title = _title()
	await process_frame
	screen = title._flash
	_freeze(screen)
	expect(screen.index == 1 and screen._continue_enabled,"valid save defaults title to continue")
	_key(KEY_ENTER)
	_ticks(screen,16)
	var archive = screen.child
	expect(archive != null and archive.mode == "load" and not archive.allow_mode_switch,"continue shares formal load-only archive")
	await _capture("continue")
	DirAccess.remove_absolute(Saves.slot_path(1))
	screen._request_load(1)
	var failed_load_deadline = Time.get_ticks_msec() + 60000
	while not screen.ready_for_input() and Time.get_ticks_msec() < failed_load_deadline:
		await process_frame
	expect(screen.ready_for_input() and not archive.message.is_empty(),"failed actual load releases input gate and shows diagnostic")
	_key(KEY_ESCAPE)
	_ticks(screen,16)
	expect(screen.child == null and not screen._continue_enabled,"cancel after failed load refreshes availability")
	title.queue_free()
	await process_frame
	_finish()

func _seed_save() -> void:
	var state = root.get_node("RuntimeState")
	state.begin_new_game(Data.system(),{"enabled":false})
	state.map_id = 10
	state.party = [2,3]
	state.variables["14"] = [2,3]
	state.variables["82"] = "title-load-marker"
	state.gold = 987
	state.actor(2)
	state.actor(3)
	expect(Saves.save_slot(1,state).ok,"create valid production save in isolated directory")

func _flow(mode: String) -> void:
	var state = root.get_node("RuntimeState")
	if mode == "continue":
		_seed_save()
	var title = _title()
	current_scene = title
	await process_frame
	var screen = title._flash
	_freeze(screen)
	_ticks(screen,16)
	if mode == "quit":
		screen.index = 6
		_key(KEY_ENTER)
		return
	_key(KEY_ENTER)
	_ticks(screen,16)
	if mode != "continue":
		var wanted = int(mode)
		while screen.difficulty != wanted:
			_key(KEY_LEFT if wanted < screen.difficulty else KEY_RIGHT)
			_ticks(screen,16)
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	for tick in 180:
		await process_frame
		if current_scene != null and current_scene != title:
			break
	var game = current_scene
	expect(game != null and game != title and game.get_script().resource_path.ends_with("/Game.gd"),"real title keyboard opens production Game scene")
	if game != null and game != title:
		game.reset_event_execution()
		game.set_process(false)
		game._player.set_process(false)
		game._events_enabled = false
		if mode == "continue":
			expect(state.variables.get("82") == "title-load-marker" and state.gold == 987 and state.map_id == 10,"continue restores saved state without new-game reset")
		else:
			expect(state.variables.get("141",0) == int(mode) and state.map_id > 0,"new-game stores exact original difficulty and opens initial map")
		game.queue_free()
		await process_frame

func _title() -> Control:
	var title = load("res://runtime/scripts/05_Title/Title.gd").new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	return title

func _freeze(node: Node) -> void:
	node.set_process(false)
	for child in node.get_children():
		_freeze(child)

func _ticks(screen: Control, ticks: int) -> void:
	for tick in ticks:
		screen._tick()
		if screen.child != null and screen.child.get_script().resource_path.ends_with("TitleExtrasPage.gd"):
			screen.child._process(1.0/60)

func _key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func _buttons(node: Node) -> int:
	var count = int(node is Button)
	for child in node.get_children():
		count += _buttons(child)
	return count

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(image != null and image.get_width() >= 640 and image.save_png("res://.godot/v055-"+label+".png") == OK,"GPU rendered "+label)
	_captures += 1

func _finish() -> void:
	for message in failures:
		printerr("FAIL: ",message)
	print("FLASH TITLE V055: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / ",_captures," GPU states")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

## 职责：回归验证：真实地图菜单、档案原图、八帧过渡、存读档、失败恢复及事件调用者继续。
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
var Saves: Script
var checks = 0
var failures: Array[String] = []
var _captures = 0
var _game: Node
var _state: Node

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640,640)
	root.content_scale_size = Vector2i(640,640)
	Saves = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	_state = root.get_node("RuntimeState")
	_state.flash_preferences.apply_display = false
	_state.begin_new_game(Data.system(),{"enabled":false})
	_state.map_id = 10
	_state.party = [2,3]
	_state.variables["14"] = [2,3]
	_state.variables["3"] = 0
	_state.switches["160"] = true
	_state.actor(2).set_project_parameter("maxhp",300)
	_state.actor(2).hp = 222
	_state.actor(2).set_project_parameter("maxsp",40)
	_state.actor(2).sp = 30
	_state.actor(3).set_project_parameter("maxhp",200)
	_state.actor(3).hp = 150
	_state.actor(3).set_project_parameter("maxsp",20)
	_state.actor(3).sp = 5
	_state.gold = 987
	_game = load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	_game._events_enabled = false
	root.add_child(_game)
	await process_frame
	_game.reset_event_execution()
	_game.set_process(false)
	_game._player.set_process(false)
	_game._events_enabled = false
	_game._player.input_enabled = true
	_game._flash_hud._process(8.0/60)
	_game._flash_hud.set_process(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--flow="):
			await _map_flow(argument.trim_prefix("--flow="))
			_finish()
			return
	await _capture("map")
	_key(KEY_ESCAPE)
	var menu = _game._menus.menu
	expect(menu!=null and paused and not _game._player.input_enabled,"actual viewport Esc opens native menu and owns map pause")
	menu.set_process(false)
	_step(menu,4)
	await _capture("menu-half")
	_step(menu,4)
	expect(menu.ready_for_input() and menu.window_process==8 and _buttons(menu)==0,"eight logical ticks finish original menu without Godot buttons")
	expect(_game._menus._flash_backdrop==null and not _game._flash_hud.visible_target(),"source menu retains live paused map, hides HUD and does not invent snapshot blur")
	await _capture("menu")
	if DisplayServer.get_name()!="headless":
		var intervals: Array[float] = []
		var previous = Time.get_ticks_usec()
		menu.set_process(true)
		for frame in 120:
			await process_frame
			var now = Time.get_ticks_usec()
			intervals.append((now-previous)/1000.0)
			previous = now
		intervals.sort()
		menu.set_process(false)
		print("MENU FRAME MS: ",JSON.stringify({"samples":120,"p50":intervals[60],"p95":intervals[114],"maximum":intervals.back()}))
	var nodes = _nodes(menu)
	var artwork = menu._artwork
	_key(KEY_LEFT)
	expect(menu.index==8 and not menu.enabled(8),"native staggered left navigation selects original locked skill command")
	_key(KEY_ENTER)
	expect(menu.child==null,"locked command cannot create a functional page")
	await _capture("locked")
	for i in 40:
		_key(KEY_DOWN)
	expect(menu._artwork==artwork and _nodes(menu)==nodes and menu.index==8,"repeated navigation reuses one independent command drawing surface")
	_state.variables["5"][2] = 1
	menu.index = 2
	menu.activate()
	expect(menu.child==null,"original empty equipment branch stays empty even when unlocked")
	menu.index = 7
	menu.activate()
	expect(menu.child!=null and not menu.ready_for_input(),"child entry owns its eight-tick input gate")
	_key(KEY_E)
	expect(menu.child.sheet==1,"opening transition ignores child navigation")
	_step(menu,8)
	_key(KEY_E)
	expect(menu.child.sheet==2 and paused,"completed menu transition routes actual settings keys while map stays paused")
	await _capture("config")
	_key(KEY_ESCAPE)
	_step(menu,8)
	expect(menu.child==null and menu.index==7 and paused,"settings return preserves native cursor and pause")
	menu.index = 1
	menu.activate()
	var archive = menu.child
	archive.set_process(false)
	_step(menu,4)
	await _capture("archive-half")
	_step(menu,4)
	expect(archive.window_process==8 and archive._slots==[1] and _game.can_save(),"empty archive exposes one true first-empty slot and production save permission")
	var points = archive._view.positions()
	expect(points.files==Vector2(16,136) and points.snapshot==Vector2(296,136) and points.players==Vector2(80,488),"original map archive positions settle at native window coordinates")
	expect(archive._view._cards.clip_contents and archive._view._cards.size==Vector2(240,256) and _buttons(archive)==0,"archive owns original clipped grid and independent drawn cursor")
	await _capture("archive-new")
	var writes = {"count":0}
	var sounds: Array = []
	menu.sound_requested.connect(func(key: String): sounds.append(key))
	archive.save_callback = func(slot: int):
		writes.count += 1
		return _game.save_slot(slot)
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	expect(writes.count==1 and FileAccess.file_exists(Saves.slot_path(1)),"real confirm writes one exact slot and repeated submit is blocked")
	expect(sounds==["decision_se"],"successful save plays one decision sound without an extra cancel during return")
	_step(menu,8)
	expect(menu.child==null and paused and Saves.slot_info(1).archive.players[0].hp==222,"successful save returns through eight-tick parent transition with actor snapshot")
	if DisplayServer.get_name()!="headless":
		var snap = load("res://runtime/scripts/07_Archive/ArchiveData.gd").preview(Saves.slot_info(1).archive)
		expect(snap!=null and snap.get_data()==_state.flash_archive_snapshot.get_data(),"save retains full pre-menu map screenshot without menu or confirmation overlay")
	menu.activate()
	archive = menu.child
	archive.set_process(false)
	_step(menu,8)
	expect(archive._slots==[1,2] and archive._current.players.size()==2,"reopened archive shows persisted record and next empty card")
	await _capture("archive-save")
	_key(KEY_ENTER)
	expect(archive._confirmation=="overwrite" and not archive._confirmation_accepted,"overwrite confirmation starts at cancel")
	await _capture("overwrite")
	_key(KEY_ENTER)
	expect(archive._confirmation.is_empty() and menu.child==archive,"cancel confirmation leaves same native archive open")
	_state.save_disabled = true
	_key(KEY_ENTER)
	_key(KEY_LEFT)
	_key(KEY_ENTER)
	expect(not archive.message.is_empty() and archive.ready_for_input() and not archive._closing,"failed authoritative save keeps page usable and reports original prohibition")
	_state.save_disabled = false
	_key(KEY_TAB)
	_step(menu,8)
	expect(archive.mode=="load" and archive._slots==[1] and not _game.can_save(),"native Tab switches to real load catalog and disables save gate")
	await _capture("archive-load")
	var path = Saves.slot_path(1)
	var original = FileAccess.get_file_as_string(path)
	Saves.write_text(path,"broken after catalog")
	_key(KEY_ENTER)
	var failed_load_deadline = Time.get_ticks_msec() + 60000
	while not menu.ready_for_input() and Time.get_ticks_msec() < failed_load_deadline:
		await process_frame
	expect(menu.ready_for_input() and archive.ready_for_input() and not archive.message.is_empty() and _state.gold==987,"actual load rereads damaged bytes, releases both submit gates, and preserves current state")
	await _capture("load-failure")
	Saves.write_text(path,original)
	_key(KEY_ESCAPE)
	_step(menu,8)
	expect(menu.child==null and menu.index==1 and paused,"failed load returns to original command instead of losing the map caller")
	# Populate a third column using actual production envelopes; rendering and scrolling must stay bounded.
	for id in range(2,11):
		expect(Saves.save_slot(id,_state).ok,"seed real archive%d" % id)
	menu.activate()
	archive = menu.child
	archive.set_process(false)
	_step(menu,8)
	var view = archive._panel
	var count = _nodes(archive)
	for column in 2:
		_key(KEY_RIGHT)
		_key(KEY_RIGHT)
		_step(menu,8)
	expect(archive.selected==8 and archive._scroll_offset==120 and archive._panel==view and _nodes(archive)==count,"third column scrolls native clipped cards without rebuilding nodes or duplicate key movement")
	await _capture("archive-scroll")
	_key(KEY_DOWN)
	_step(menu,4)
	await _capture("cursor-half")
	_step(menu,4)
	_key(KEY_LEFT)
	_step(menu,8)
	expect(archive.selected==5,"left returns same row across original card columns")
	var saved = archive._infos[archive.selected]
	_key(KEY_DOWN)
	_step(menu,8)
	expect(is_same(saved,archive._infos[5]) and archive._preview_cache.size()<=8,"navigation retains catalog identity and bounded decoded screenshot cache")
	_key(KEY_ESCAPE)
	_step(menu,8)
	_key(KEY_ESCAPE)
	expect(paused and _game._menus.menu==menu,"exit keeps pause while native closing animation is active")
	_step(menu,8)
	expect(_game._menus.menu==null and not paused and _game._player.input_enabled,"close completes once and releases formal map input")
	await process_frame
	_game._flash_hud._process(8.0/60)
	await _capture("return-map")
	await _event_window(351)
	await _event_window(352)
	await _event_window(352,true)
	var close_counts = {"menu":0,"archive":0}
	var lifecycle_menu = load("res://runtime/scripts/08_Menu/Main/MenuScreen.gd").new()
	root.add_child(lifecycle_menu)
	lifecycle_menu.set_process(false)
	lifecycle_menu._process(1.0)
	lifecycle_menu.close_requested.connect(func():close_counts.menu+=1)
	lifecycle_menu.back()
	lifecycle_menu._process(1.0)
	lifecycle_menu._process(1.0)
	expect(close_counts.menu==1,"large frame deltas emit menu close once even if holder keeps the node alive")
	lifecycle_menu.queue_free()
	var lifecycle_archive = load("res://runtime/scripts/07_Archive/ArchivePage.gd").new()
	lifecycle_archive.mode = "load"
	root.add_child(lifecycle_archive)
	lifecycle_archive.set_process(false)
	lifecycle_archive._process(1.0)
	lifecycle_archive.back_requested.connect(func():close_counts.archive+=1)
	lifecycle_archive.back()
	lifecycle_archive._process(1.0)
	lifecycle_archive._process(1.0)
	expect(close_counts.archive==1,"large frame deltas emit standalone archive return once across later frames")
	lifecycle_archive.queue_free()
	_game.queue_free()
	await process_frame
	# Title uses the same archive view with its own source geometry and one16-frame parent clock.
	var title = load("res://runtime/scripts/05_Title/Title.gd").new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	await process_frame
	var screen = title._flash
	screen.set_process(false)
	screen.handle_key(KEY_ENTER)
	screen.child.set_process(false)
	for tick in 8:
		screen._tick()
		screen.child._process(1.0/60)
	expect(screen.child.window_process==8 and screen.child._view.positions().chapter.x==8 and screen.child._view.positions().files.x==8,"title continue shares native archive with original left chapter and eight-frame geometry")
	expect(screen.page_progress==8 and screen.ready_for_input() and screen.title_progress==8 and screen.child.z_index>screen._artwork.z_index,"title file and tag finish their source eight ticks above still-fading16-tick commands")
	await _capture("title-continue")
	screen.handle_key(KEY_ESCAPE)
	for tick in 16:screen._tick()
	expect(screen.child==null and screen.index==1,"title archive returns to actual continue cursor")
	title.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	for message in failures:printerr("FAIL: ",message)
	print("MENU ARCHIVE V056: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / ",_captures," GPU states")
	quit(0 if failures.is_empty() else 1)

func _event_window(code: int, save: bool = false) -> void:
	_game.reset_event_execution()
	var baseline = int(_state.variables.get("92",0))
	_game._scheduler.start_main([{"code":code,"indent":0,"parameters":[]},{"code":122,"indent":0,"parameters":[92,92,1,0,1]},{"code":0,"indent":0,"parameters":[]}],0)
	_game._event_ui.pump(_game.event_ui_available())
	var page = _game._menus.menu
	expect(page!=null and paused,"native event%d opens actual paused window" % code)
	page.set_process(false)
	for tick in 8:
		if code==351:page._tick()
		else:page._process(1.0/60)
	if save:
		page.selected = page._slots.size()-1
		page.refresh(false)
		_state.save_disabled = true
		expect(_game.can_save(),"352 permits the original event-save override while ordinary saving is disabled")
		_key(KEY_ENTER)
		_key(KEY_ENTER)
		await process_frame
	else:
		_key(KEY_ESCAPE)
	expect(paused,"event caller remains waiting during native return%d" % code)
	for tick in 8:
		if code==351:page._tick()
		else:page._process(1.0/60)
	# 正式调度器可能已耗尽本帧共享预算；窗口关闭后按真实帧恢复，不绕过预算直接执行。
	for frame in 60:
		_game._scheduler.advance(0,false)
		if not _game._interpreter.running:
			break
		await process_frame
	expect(_game._menus.menu==null and not paused and _state.variables.get("92",0)==baseline+1,"event%d resumes exact caller and executes continuation once" % code)
	_game._scheduler.advance(0,false)
	expect(_state.variables.get("92",0)==baseline+1,"event%d cannot repeat continuation" % code)
	if save:
		expect(Saves.slot_info(11).ok and Saves.slot_info(11).archive.players[0].hp==222,"actual 352 save writes the exact selected production archive")
		_state.save_disabled = false
	await process_frame

func _step(menu: Control, ticks: int) -> void:
	for tick in ticks:
		menu._tick()
		_game._flash_hud._process(1.0/60)
		if menu.child!=null and menu.child.get_script().resource_path.ends_with("ArchivePage.gd"):
			menu.child._process(1.0/60)

func _map_flow(mode: String) -> void:
	current_scene = _game
	if mode in ["load","backup"]:
		_state.gold = 123
		expect(Saves.save_slot(1,_state).ok,"map flow seeds authoritative archive")
		if mode=="backup":
			_state.gold = 456
			expect(Saves.save_slot(1,_state).ok,"map flow creates actual verified backup")
			Saves.write_text(Saves.slot_path(1),"damaged primary")
		_state.gold = 987
	_key(KEY_ESCAPE)
	var menu = _game._menus.menu
	menu.set_process(false)
	_step(menu,8)
	if mode in ["load","backup"]:
		menu.index = 1
		menu.activate()
		menu.child.set_process(false)
		_step(menu,8)
		_key(KEY_TAB)
		_step(menu,8)
	else:
		menu.index = 9
	_key(KEY_ENTER)
	if mode=="backup":
		expect(menu.child._confirmation=="backup" and not menu.child._confirmation_accepted,"recoverable primary requires explicit default-cancel backup confirmation")
		_key(KEY_LEFT)
		_key(KEY_ENTER)
	_key(KEY_ENTER)
	var load_deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < load_deadline:
		await process_frame
		if current_scene!=null and current_scene!=_game and not paused:
			break
	var scene = current_scene
	if mode in ["load","backup"]:
		expect(scene!=null and scene!=_game and scene.get_script().resource_path.ends_with("/Game.gd") and _state.gold==123 and _state.actor(2).hp==222,"actual map archive confirm restores exact saved state in new Game scene")
		if scene!=_game:
			scene.reset_event_execution()
	else:
		expect(scene!=null and scene!=_game and scene.get_script().resource_path.ends_with("/Title.gd") and not paused and not _state.playing,"actual return-title command closes map ownership and opens original title")
	if scene!=null:
		scene.queue_free()
		await process_frame

func _key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(image!=null and image.save_png("res://.godot/v056-"+label+".png")==OK,"actual GPU "+label)
	_captures += 1

func _buttons(node: Node) -> int:
	var count = int(node is Button)
	for child in node.get_children():count += _buttons(child)
	return count

func _nodes(node: Node) -> int:
	var count = 1
	for child in node.get_children():count += _nodes(child)
	return count

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:failures.append(message)

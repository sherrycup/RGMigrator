## 职责：以独立写入和读取进程验证分页对话的正式存档、请求恢复和前后事件不重复执行。
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
var checks = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var phase = "write"
	var directory = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--save-directory="):
			directory = argument.trim_prefix("--save-directory=")
	if directory.is_empty():
		printerr("Isolated save directory required")
		quit(1)
		return
	var saves = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	saves.directory_override = directory
	load("res://runtime/scripts/00_Game/Preferences.gd").directory_override = directory
	var state = root.get_node("RuntimeState")
	state.flash_preferences.apply_display = false
	if phase == "write":
		state.begin_new_game(Data.system(), {"enabled": false})
		state.map_id = 10
		state.party = [2]
		state.variables["14"] = [2, 0]
		state.actor(2)
	else:
		var loaded = saves.load_slot(14, state)
		expect(loaded.ok, "read production save with paused page: " + str(loaded.get("message", "")))
		if not loaded.ok:
			_finish(phase)
			return
	var game = load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	root.add_child(game)
	game._events_enabled = false
	game.set_process(false)
	game._player.set_process(false)
	game._dialogue._flash_view.set_process(false)
	var controller = state.flash_messages
	if phase == "write":
		game.reset_event_execution()
		state.variables["97"] = 0
		state.variables["98"] = 0
		game._scheduler.start_main([
			{"code": 122, "indent": 0, "parameters": [97, 97, 1, 0, 1]},
			{"code": 101, "indent": 0, "parameters": ["\\m[保存测试]\\>" + "分页对话保存后应从原位置继续。".repeat(80)]},
			{"code": 122, "indent": 0, "parameters": [98, 98, 1, 0, 1]},
			{"code": 0, "indent": 0, "parameters": []}], 0, 1, "message054", true)
		for i in 1000:
			game._interpreter.advance(1.0 / 60)
			game._event_ui.pump(true)
			controller.tick()
			if not controller.boxes.is_empty() and controller.boxes[0].model.page_pending_token >= 0:
				break
			await process_frame
		expect(controller.boxes.size() == 1 and controller.boxes[0].model.state == 2 and state.variables["97"] == 1 and state.variables["98"] == 0, "write at actual pending page between two event changes")
		var saved = saves.save_slot(14, state)
		expect(saved.ok, "write production envelope: " + str(saved.get("message", "")))
	else:
		expect(controller.boxes.size() == 1 and controller.boxes[0].model.state == 2 and controller.boxes[0].model.page_pending_token >= 0, "new process restores pending page and request binding")
		expect(state.variables["97"] == 1 and state.variables["98"] == 0, "already executed side effect preserved without replay")
		for i in 12000:
			if i % 32 == 0:
				await process_frame
			controller.tick()
			game._event_ui.pump(true)
			game._interpreter.advance(1.0 / 60)
			if not controller.boxes.is_empty() and controller.boxes[0].model.state in [2, 3]:
				controller.confirm()
			if not game._interpreter.running and controller.boxes.is_empty():
				break
		expect(state.variables["97"] == 1 and state.variables["98"] == 1 and not game._interpreter.running, "restored pages finish; following side effect executes exactly once")
	game.queue_free()
	await process_frame
	_finish(phase)

func _finish(phase: String) -> void:
	for failure in failures:
		printerr("FAIL: ", failure)
	print("MESSAGE RESTART V054: ", "PASSED" if failures.is_empty() else "FAILED", " / ", phase, " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

## 职责：回归验证：在独立进程中检查真实退出命令能结束游戏。
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
##   func run_suite() -> void
##     用途：执行本脚本组织的回归检查。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
## Separate process: verifies that the real Exit command terminates Godot.


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	create_timer(10.0).timeout.connect(func() -> void: printerr("FAIL: Exit command did not terminate the game"); quit(1))
	var title: Node = load("res://scenes/05_Title/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title.call("_on_new_game")
	for _frame in 4:
		await process_frame
	# Exit is verified independently of the source opening story.
	current_scene.call("reset_event_execution")
	root.get_node("RuntimeState").menu_disabled = false
	await process_frame
	var dialogue: Node = current_scene.get("_dialogue")
	if dialogue.call("is_open"):
		for child in dialogue.get("_content").get_children():
			if child is Button and child.text == "关闭":
				child.emit_signal("pressed")
	var coordinator: Node = current_scene.get("_menus")
	if not coordinator.call("open_menu"):
		printerr("FAIL: could not open menu for Exit test")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	var menu: Control = coordinator.get("menu")
	menu.call("navigate", 1)
	menu.call("navigate", 1)
	menu.call("activate")
	menu.call("navigate", -1)
	menu.quit_requested.connect(func() -> void: print("QUIT MENU REQUESTED"))
	menu.call("activate")

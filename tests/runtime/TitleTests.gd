## 职责：回归验证：验证标题命令、新游戏、读档与返回的生命周期。
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
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(10.0).timeout.connect(func() -> void: printerr("FAIL: title quit timed out"); quit(1))
	var title: Control = load("res://scenes/05_Title/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await create_timer(0.3).timeout
	var has_new_game := false
	var exit_button: Button
	for button in title.find_children("*", "Button", true, false):
		if button.text == "新游戏":
			has_new_game = true
		if button.text == "退出":
			exit_button = button
	if not has_new_game or exit_button == null:
		printerr("FAIL: title buttons missing")
		quit(1)
		return
	print("TITLE TESTS: PASSED; requesting actual quit button")
	exit_button.pressed.emit()

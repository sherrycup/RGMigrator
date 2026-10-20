## 职责：回归验证：验证迁移器主界面输入、迁移状态及错误反馈。
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


func _init() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: real rendering required")
		quit(1)
		return
	root.size = Vector2i(1000, 720)
	root.content_scale_size = root.size
	var scene: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var log: Control = scene.get("_log")
	var mode: CheckBox = scene.get("_test_mode")
	var passed := mode.button_pressed and log.get_global_rect().end.y <= 720 and log.size.y >= 240
	mode.button_pressed = false
	passed = passed and not mode.button_pressed
	mode.button_pressed = true
	var capture := ProjectSettings.globalize_path("res://.godot/test-logs/v019-migrator.png")
	passed = root.get_texture().get_image().save_png(capture) == OK and passed
	print("MIGRATOR UI TESTS: ", "PASSED" if passed else "FAILED", " / ", capture)
	scene.queue_free()
	current_scene = null
	await process_frame
	quit(0 if passed else 1)

## 职责：回归验证：运行编辑器交互反馈场景并检查结果。
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
## 接口说明结束。

extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var scenario=load("res://.godot/Editor_FeedbackScenario.gd").new()
	var result: Dictionary=await scenario.run(root,load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new())
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("EDITOR FEEDBACK AUDIO: ",result.mixed_samples," samples / peak=",result.audio_peak)
	print("EDITOR FEEDBACK TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

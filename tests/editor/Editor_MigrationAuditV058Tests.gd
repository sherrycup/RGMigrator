## 职责：在隔离工程中启动真实脚本工作区，核对0.58审计分类、覆盖关系、代码改动失效与GPU显示。
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
## 接口说明结束。

extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await load("res://tests/editor/Editor_MigrationAuditV058Probe.gd").new().run(root)

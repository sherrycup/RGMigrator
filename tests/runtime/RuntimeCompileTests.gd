## 职责：回归验证：递归编译分组目录下的全部游戏运行脚本。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
## Scan the complete grouped tree; do not silently skip nested scripts.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var files: Array[String] = []
	_collect("res://runtime/scripts", files)
	var failed := false
	for path in files:
		var production: Script = load(path)
		if production == null or production.reload(true) != OK or not production.can_instantiate():
			printerr("FAIL: runtime compile ", path)
			failed = true
	print("RUNTIME COMPILE: ", "FAILED" if failed else "PASSED", " / ", files.size(), " scripts")
	quit(1 if failed else 0)


func _collect(directory: String, files: Array[String]) -> void:
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".gd"):
			files.append(directory.path_join(filename))
	for folder in DirAccess.get_directories_at(directory):
		if not folder.begins_with("."):
			_collect(directory.path_join(folder), files)

## 职责：回归验证：将当前运行模板安装到独立测试工程并刷新引用。
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

const ProjectGenerator = preload("res://scripts/importer/ProjectGenerator.gd")
const RmxpIniReader = preload("res://scripts/importer/RmxpIniReader.gd")
const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const TestSetupGenerator = preload("res://scripts/importer/TestSetupGenerator.gd")
const Report = preload("res://scripts/importer/MigrationReportWriter.gd")


func _init() -> void:
	# Only generated disposable outputs listed by our last test run are touched.
	var results: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/test-results.json"))
	var allowed := ProjectSettings.globalize_path("res://.godot/")
	for output: String in results.get("exports", []):
		if not output.begins_with(allowed):
			quit(1)
			return
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("migration_report.json")))
		var ini := RmxpIniReader.new(RmxpTextCodec.new(936)).read(str(report["source_path"]).path_join("Game.ini"))
		var generated := ProjectGenerator.new().generate(output, str(report["project_title"]), ini, Callable(), str(report["source_path"]))
		report.tool_version = preload("res://scripts/Version.gd").DISPLAY_NAME
		Report.new().write(output, report)
		# Disposable fixtures only; upgrade their generated configuration as well.
		var testing := TestSetupGenerator.new().generate(output, true)
		if not testing.get("ok", false):
			printerr(testing)
			quit(1)
			return
		if not generated["warnings"].is_empty():
			printerr(generated["warnings"])
			quit(1)
			return
		print("Refreshed test runtime: ", output)
	quit(0)

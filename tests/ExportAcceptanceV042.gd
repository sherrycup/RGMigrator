## 职责：正式导出验收：从原 RM 工程执行 0.42 迁移，检查生成配置、报告及必需交付文件。
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
const Validator = preload("res://scripts/importer/RmxpValidator.gd")
const Pipeline = preload("res://scripts/importer/MigrationPipeline.gd")
const Version = preload("res://scripts/Version.gd")

func _init() -> void:
	var workspace := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var source_root := workspace.path_join("rm_template")
	var output_root := workspace.path_join("output/0.42/verified")
	if DirAccess.dir_exists_absolute(output_root):
		printerr("Refusing to overwrite an existing acceptance directory: ",output_root); quit(1); return
	if DirAccess.make_dir_recursive_absolute(output_root) != OK: quit(1); return
	var summary := {"version":Version.VERSION,"output_root":output_root,"projects":[],"ok":true}
	for source in ["魔塔样板7630·改","小蛋挞(读1号存档即可)"]:
		print("ACCEPTANCE SOURCE: ",source)
		var preflight := Validator.new().preflight(source_root.path_join(source),output_root,936)
		if not preflight.get("ok",false): printerr(JSON.stringify(preflight)); summary.ok=false; break
		var result := Pipeline.new().run(preflight)
		var report: Dictionary = result.get("report",{})
		summary.projects.append({"source_path":source_root.path_join(source),"output_path":result.get("output_path",""),"ok":result.ok,"maps":report.get("maps",0),"assets":report.get("assets",0),"script_migration":report.get("script_migration",{}),"errors":report.get("errors",[])})
		print("ACCEPTANCE EXPORTED: ",result.get("output_path","")," / ok=",result.ok)
		if not result.ok: summary.ok=false; break
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/test-logs"))
	var file := FileAccess.open("res://.godot/test-logs/v042-final-export.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("ACCEPTANCE EXPORT: ","PASSED" if summary.ok else "FAILED")
	quit(0 if summary.ok else 1)

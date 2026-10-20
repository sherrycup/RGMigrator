## 职责：正式导出验收：从原 RM 工程执行 0.46 迁移，检查生成配置、报告及必需交付文件。
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
const Validator=preload("res://scripts/importer/RmxpValidator.gd")
const Pipeline=preload("res://scripts/importer/MigrationPipeline.gd")
const Version=preload("res://scripts/Version.gd")
func _init() -> void:
	ProjectSettings.set_setting("rgmigrator/codec_temp_directory",ProjectSettings.globalize_path("res://.godot/codec"))
	var workspace=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var source=workspace.path_join("rm_template/魔塔样板7630·改")
	var destination=workspace.path_join("output/0.46/final")
	if DirAccess.dir_exists_absolute(destination):
		printerr("Refusing to overwrite existing delivery: ",destination); quit(1); return
	if DirAccess.make_dir_recursive_absolute(destination)!=OK: quit(1); return
	var preflight=Validator.new().preflight(source,destination,936)
	if not preflight.get("ok",false): printerr(JSON.stringify(preflight)); quit(1); return
	var result=Pipeline.new().run(preflight); var report: Dictionary=result.get("report",{}); var output: String=result.get("output_path","")
	var summary={"version":Version.VERSION,"source":source,"output_path":output,"ok":result.ok,"maps":report.get("maps",0),"assets":report.get("assets",0),"script_migration":report.get("script_migration",{}),"flash_gameplay":report.get("flash_gameplay",{}),"errors":report.get("errors",[])}
	if result.ok:
		var config=ConfigFile.new()
		summary.ok=config.load(output.path_join("project.godot"))==OK and config.get_value("rendering","renderer/rendering_method","")=="gl_compatibility" and config.get_value("display","window/size/viewport_height",0)==640 and config.get_value("application","run/max_fps",0)==60
		for path in ["addons/rgm_editor/plugin.cfg","runtime/generated/skill_catalog.gd","runtime/scripts/07_Archive/ArchivePage.gd","runtime/scripts/09_Effects/ScreenEffects.gd","data/source_corrections.json","migration_docs/SCRIPT_MIGRATION_v0.46.md","migration_docs/FLASH_UI_GDSCRIPT_v0.46.md"]:
			if not FileAccess.file_exists(output.path_join(path)): summary.ok=false; summary.errors.append("正式输出缺少："+path)
	var file=FileAccess.open("res://.godot/test-logs/v046-release-export.json",FileAccess.WRITE); file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("ACCEPTANCE EXPORTED: ",output," / ok=",summary.ok); print("ACCEPTANCE EXPORT: ","PASSED" if summary.ok else "FAILED")
	quit(0 if summary.ok else 1)

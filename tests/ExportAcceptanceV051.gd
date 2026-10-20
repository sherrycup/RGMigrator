## 职责：正式导出验收：从原 RM 工程执行 0.51 迁移，检查生成配置、报告及必需交付文件。
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
	var delivery_subdir="candidate"
	var converter=OS.get_environment("RGMIGRATOR_FFMPEG")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--delivery-subdir="): delivery_subdir=argument.trim_prefix("--delivery-subdir=")
		if argument.begins_with("--audio-converter="): converter=argument.trim_prefix("--audio-converter=")
	if converter.is_empty() or not FileAccess.file_exists(converter):
		printerr("Flash acceptance export requires the existing migration-only MP2 converter (--audio-converter= or RGMIGRATOR_FFMPEG)."); quit(1); return
	ProjectSettings.set_setting("rgmigrator/audio_converter_executable",converter)
	var allowed=RegEx.new(); allowed.compile("^[a-zA-Z0-9_-]+$")
	if allowed.search(delivery_subdir)==null:
		printerr("Invalid delivery subdirectory"); quit(1); return
	var destination=workspace.path_join("output/0.51/"+delivery_subdir)
	if DirAccess.dir_exists_absolute(destination):
		printerr("Refusing to overwrite existing delivery: ",destination); quit(1); return
	if DirAccess.make_dir_recursive_absolute(destination)!=OK: quit(1); return
	var preflight=Validator.new().preflight(source,destination,936)
	if not preflight.get("ok",false): printerr(JSON.stringify(preflight)); quit(1); return
	var result=Pipeline.new().run(preflight); var report: Dictionary=result.get("report",{}); var output: String=result.get("output_path","")
	var summary={"version":Version.VERSION,"source":source,"output_path":output,"ok":result.ok,"maps":report.get("maps",0),"assets":report.get("assets",0),"script_migration":report.get("script_migration",{}),"flash_gameplay":report.get("flash_gameplay",{}),"errors":report.get("errors",[])}
	if result.ok:
		var conversions: Variant=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("data/asset_conversions.json")))
		if not conversions is Dictionary or conversions.get("entries",[]).size()!=1: summary.ok=false; summary.errors.append("标题MP2转换记录缺失。")
		var config=ConfigFile.new()
		summary.ok=summary.ok and config.load(output.path_join("project.godot"))==OK and config.get_value("rendering","renderer/rendering_method","")=="gl_compatibility" and config.get_value("display","window/size/viewport_height",0)==640 and config.get_value("application","run/max_fps",0)==60
		for path in ["addons/rgm_editor/plugin.cfg","SCRIPT_STRUCTURE.md","data/script_layout.json","runtime/scripts/08_Menu/Main/MenuModel.gd","runtime/scripts/08_Menu/Main/MenuPages.gd","runtime/generated/skill_catalog.gd","runtime/scripts/07_Archive/ArchivePage.gd","runtime/scripts/09_Effects/ScreenEffects.gd","data/source_corrections.json","migration_docs/SCRIPT_MIGRATION_v0.47.md","migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.json","runtime/scripts/10_Support/Persistence/SaveGraph.gd","runtime/scripts/10_Support/Persistence/History.gd","runtime/scripts/10_Support/Persistence/MapSnapshot.gd","runtime/scripts/10_Support/Utilities/MoviePlayer.gd","addons/rgm_editor/06_Scripts/Editor_ScriptDialog.gd","addons/rgm_editor/compiler/Editor_ScriptMigrationInventory.gd","data/script_workspace.json","data/script_coverage.json","script_coverage.md","migration_docs/SCRIPT_MIGRATION_v0.48.md","migration_docs/PERFORMANCE_v0.5.md","tests/VERIFICATION_v0.5.md","tests/runtime/IntegrationV049Tests.gd","tests/runtime/FailureIsolationProbe.gd","runtime/scripts/01_Battle/DamageWorker.gd","migration_docs/PERFORMANCE_v0.5.md","tests/runtime/SnapshotV050Tests.gd","tests/runtime/DamageOrderV050Probe.gd"]:
			if not FileAccess.file_exists(output.path_join(path)): summary.ok=false; summary.errors.append("正式输出缺少："+path)
	var suffix="" if delivery_subdir=="final" else "-"+delivery_subdir
	var file=FileAccess.open("res://.godot/test-logs/v051-release-export"+suffix+".json",FileAccess.WRITE); file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("ACCEPTANCE EXPORTED: ",output," / ok=",summary.ok); print("ACCEPTANCE EXPORT: ","PASSED" if summary.ok else "FAILED")
	quit(0 if summary.ok else 1)

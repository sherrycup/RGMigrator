extends SceneTree
const Validator=preload("res://scripts/importer/RmxpValidator.gd")
const Pipeline=preload("res://scripts/importer/MigrationPipeline.gd")
const Version=preload("res://scripts/Version.gd")
func _init() -> void:
	ProjectSettings.set_setting("rgmigrator/codec_temp_directory",ProjectSettings.globalize_path("res://.godot/codec"))
	var workspace=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var source=workspace.path_join("rm_template/魔塔样板7630·改")
	var delivery_subdir="final"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--delivery-subdir="): delivery_subdir=argument.trim_prefix("--delivery-subdir=")
	var allowed=RegEx.new(); allowed.compile("^[a-zA-Z0-9_-]+$")
	if allowed.search(delivery_subdir)==null:
		printerr("Invalid delivery subdirectory"); quit(1); return
	var destination=workspace.path_join("output/0.48/"+delivery_subdir)
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
		for path in ["addons/rgm_editor/plugin.cfg","runtime/generated/flash_skill_catalog.gd","runtime/scripts/FlashArchivePage.gd","runtime/scripts/FlashScreenEffects.gd","data/source_corrections.json","migration_docs/SCRIPT_MIGRATION_v0.47.md","migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.json","runtime/scripts/SaveGraph.gd","runtime/scripts/FlashHistory.gd","runtime/scripts/FlashMapSnapshot.gd","runtime/scripts/FlashMoviePlayer.gd","addons/rgm_editor/EditorScriptDialog.gd","addons/rgm_editor/compiler/ScriptMigrationInventory.gd","data/script_workspace.json","data/script_coverage.json","script_coverage.md","migration_docs/SCRIPT_MIGRATION_v0.48.md"]:
			if not FileAccess.file_exists(output.path_join(path)): summary.ok=false; summary.errors.append("正式输出缺少："+path)
	var suffix="" if delivery_subdir=="final" else "-"+delivery_subdir
	var file=FileAccess.open("res://.godot/test-logs/v048-release-export"+suffix+".json",FileAccess.WRITE); file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("ACCEPTANCE EXPORTED: ",output," / ok=",summary.ok); print("ACCEPTANCE EXPORT: ","PASSED" if summary.ok else "FAILED")
	quit(0 if summary.ok else 1)

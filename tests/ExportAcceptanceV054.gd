## 职责：从只读原RM正式迁移0.54，核对Message、原生事件、素材和交付文档。
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
	var delivery_subdir="final"
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
	var destination=workspace.path_join("output/0.54/"+delivery_subdir)
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
	if result.ok:
		var native_stats = {"native":0, "legacy":0, "mismatched":0}
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("data/manifest.json")))
		for map_name in manifest.maps:
			_native_audit(JSON.parse_string(FileAccess.get_file_as_string(output.path_join("data/maps/" + map_name + ".json"))), native_stats)
		for data_path in ["data/database/CommonEvents.json", "data/flash_gameplay.json"]:
			_native_audit(JSON.parse_string(FileAccess.get_file_as_string(output.path_join(data_path))), native_stats)
		summary.native_events = native_stats
		var upgrade_index = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("data/native_event_sources.json")))
		var upgrade_ok = upgrade_index is Dictionary and upgrade_index.get("entries", {}).size() == 38
		if upgrade_ok:
			for data_path in upgrade_index.entries:
				var evidence: Dictionary = upgrade_index.entries[data_path]
				upgrade_ok = upgrade_ok and FileAccess.get_sha256(output.path_join(data_path)) == evidence.native_sha256 and FileAccess.get_sha256(output.path_join(evidence.legacy_path)) == evidence.legacy_sha256
		summary.native_upgrade_bytes_verified = upgrade_ok
		if not upgrade_ok:
			summary.ok = false
			summary.errors.append("自动升级前后精确字节证据未匹配最终文件。")
		if native_stats.native < 145 or native_stats.legacy > 0 or native_stats.mismatched > 0:
			summary.ok = false
			summary.errors.append("事件未全部升级为实际 GDScript，或源码校验值不匹配。")
		for required in ["data/native_event_sources.json", "addons/rgm_editor/03_Event/Editor_EventScript.gd", "addons/rgm_editor/compiler/Editor_NativeEventImporter.gd", "runtime/scripts/02_Event/NativeEventContext.gd", "runtime/scripts/00_Game/Game_ActorInit.gd", "runtime/scripts/02_Event/EventScriptAPI.gd", "runtime/scripts/02_Event/EventScriptValue.gd", "addons/rgm_editor/compiler/Editor_EventBodyEmitter.gd", "tests/runtime/ReadableEventV052Tests.gd", "runtime/scripts/02_Event/NativeScriptSource.gd", "runtime/scripts/02_Event/NativeEventTask.gd", "migration_docs/EVENT_GDSCRIPT_v0.52.md", "tests/VERIFICATION_v0.52.md", "tests/VERIFICATION_v0.52.json", "tests/runtime/NativeMigrationV052Tests.gd", "tests/runtime/NativeEventV052Tests.gd", "tests/runtime/NativeFatalV052Probe.gd", "tests/editor/Editor_NativeEventV052Tests.gd", "tests/editor/Editor_NativePluginV052Probe.gd"]:
			if not FileAccess.file_exists(output.path_join(required)):
				summary.ok = false
				summary.errors.append("原生事件交付缺少：" + required)
	if result.ok:
		for required in ["runtime/scripts/04_UI_Common/UILayout.gd", "runtime/scripts/04_UI_Common/UITextLayout.gd", "runtime/scripts/04_UI_Common/UITextBlock.gd", "runtime/scripts/04_UI_Common/UITransition.gd", "runtime/scripts/04_UI_Common/UIInput.gd", "migration_docs/UI_FOUNDATION_v0.53.md", "tests/runtime/UICommonV053Tests.gd", "tests/editor/Editor_UIContrastV053Tests.gd", "tests/editor/Editor_UIV053Probe.gd", "tests/VERIFICATION_v0.54.md", "tests/VERIFICATION_v0.53.json"]:
			if not FileAccess.file_exists(output.path_join(required)):
				summary.ok = false
				summary.errors.append("共用UI交付缺少：" + required)
		summary.ui_foundation = summary.ok
	if result.ok:
		for required in ["runtime/scripts/06_Message/MessageLayout.gd", "tests/runtime/MessageV054Tests.gd", "migration_docs/MESSAGE_v0.54.md", "tests/VERIFICATION_v0.54.md"]:
			if not FileAccess.file_exists(output.path_join(required)):
				summary.ok = false
				summary.errors.append("Message交付缺少：" + required)
		summary.message_restoration = summary.ok
	var suffix="" if delivery_subdir=="final" else "-"+delivery_subdir
	var file=FileAccess.open("res://.godot/test-logs/v054-release-export"+suffix+".json",FileAccess.WRITE); file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("ACCEPTANCE EXPORTED: ",output," / ok=",summary.ok); print("ACCEPTANCE EXPORT: ","PASSED" if summary.ok else "FAILED")
	quit(0 if summary.ok else 1)

func _native_audit(value: Variant, stats: Dictionary) -> void:
	if value is Array:
		for item in value: _native_audit(item, stats)
	elif value is Dictionary:
		if value.has("_script_binding"):
			var tag: Dictionary = value._script_binding
			if tag.get("language") == "rgm-native-event-v1":
				stats.native += 1
				var text = str(value.parameters[1] if int(value.get("code", 0)) == 111 else value.parameters[0])
				if tag.get("source_sha256") != text.sha256_text() or text.contains("static func run(ctx)") or text.contains("ctx.migrated") or tag.get("source_form") != "body":
					stats.mismatched += 1
			else: stats.legacy += 1
		for key in value:
			if not str(key).begins_with("_legacy") and not str(key).begins_with("_editor_original"):
				_native_audit(value[key], stats)

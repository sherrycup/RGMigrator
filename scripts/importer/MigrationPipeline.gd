class_name MigrationPipeline
extends RefCounted

const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const RmxpAssetCopier = preload("res://scripts/importer/RmxpAssetCopier.gd")
const RmxpDataConverter = preload("res://scripts/importer/RmxpDataConverter.gd")
const ProjectGenerator = preload("res://scripts/importer/ProjectGenerator.gd")
const MigrationReportWriter = preload("res://scripts/importer/MigrationReportWriter.gd")
const RGMigratorVersion = preload("res://scripts/Version.gd")
const TestSetupGenerator = preload("res://scripts/importer/TestSetupGenerator.gd")
const CustomDataImporter = preload("res://scripts/importer/CustomDataImporter.gd")
const FlashGameplayImporter = preload("res://scripts/importer/FlashGameplayImporter.gd")
const ScriptWorkspaceExporter = preload("res://scripts/importer/ScriptWorkspaceExporter.gd")


func run(preflight: Dictionary, progress: Callable = Callable()) -> Dictionary:
	var messages: Array[String] = []
	if not preflight.get("ok", false):
		return {"ok": false, "messages": ["预检未通过，不能迁移。"]}
	var output_path := str(preflight.get("output_path", ""))
	if DirAccess.dir_exists_absolute(output_path) and not _directory_is_empty(output_path):
		return {"ok": false, "messages": ["目标目录已存在且非空：%s" % output_path]}
	if DirAccess.make_dir_recursive_absolute(output_path) != OK:
		return {"ok": false, "messages": ["无法创建输出目录：%s" % output_path]}
	var source_path := str(preflight["source_path"])
	var codec := RmxpTextCodec.new(int(preflight.get("encoding", 0)))
	_emit(progress, messages, "创建输出工程：%s" % output_path)

	var asset_copier := RmxpAssetCopier.new()
	var asset_result := asset_copier.copy(source_path, output_path, func(message: String) -> void: _emit(progress, messages, message))
	var scripts_mirror := asset_copier.copy_scripts_mirror(source_path, output_path)
	if scripts_mirror.get("copied", false):
		_emit(progress, messages, "优先保留 Scripts/ 脚本镜像（%d 个文件）" % scripts_mirror.get("count", 0))

	var converter := RmxpDataConverter.new(codec)
	converter.set_asset_index(asset_result.get("asset_index", {}))
	var data_result := converter.convert(source_path, output_path, func(message: String) -> void: _emit(progress, messages, message), not scripts_mirror.get("copied", false))

	var generator := ProjectGenerator.new()
	var generator_result := generator.generate(output_path, str(preflight["project_title"]), preflight.get("ini", {}), func(message: String) -> void: _emit(progress, messages, message), source_path)
	var test_setup := TestSetupGenerator.new().generate(output_path, bool(preflight.get("test_mode", true)))
	_emit(progress,messages,"迁移项目自定义数据、属性、货币和楼层定义。")
	var custom_data: Dictionary=CustomDataImporter.new().generate(source_path,output_path,converter.script_sources,converter.script_inventory.raw_maps,codec,converter.script_inventory.raw_common)
	var flash_gameplay: Dictionary=FlashGameplayImporter.new().generate(output_path,converter.script_sources)
	_emit(progress, messages, "盘点脚本加载顺序、事件片段与依赖，解析并生成已支持的GDScript单元。")
	var script_migration: Dictionary = converter.script_inventory.generate(output_path, converter.script_sources)
	generator.write_flash_source_guide(output_path)
	var workspace_result=ScriptWorkspaceExporter.new().generate(output_path)

	var warnings: Array = []
	var mirror_differences: Array = script_migration.get("mirror_audit", {}).get("differences", [])
	if not mirror_differences.is_empty(): warnings.append("Scripts镜像与Scripts.rxdata有%d处内容不同；两份均保留，加载順序及差异见script_inventory.md，本版未静默合并。" % mirror_differences.size())
	var errors: Array = data_result.get("errors", []).duplicate()
	errors.append_array(script_migration.get("errors", []))
	errors.append_array(custom_data.get("errors",[]))
	errors.append_array(flash_gameplay.get("errors",[]))
	errors.append_array(workspace_result.get("errors",[]))
	if not test_setup.get("ok", false):
		errors.append(test_setup.get("message", "测试配置生成失败"))
	errors.append_array(asset_result.get("errors", []))
	errors.append_array(generator_result.get("warnings", []))
	if not codec.error_message.is_empty():
		errors.append(codec.error_message)
	warnings.append_array(asset_result.get("warnings", []))
	warnings.append_array(data_result.get("warnings", []))
	warnings.append_array(generator_result.get("warnings", []))
	var game_section: Dictionary = preflight.get("ini", {}).get("Game", {})
	var rtp := str(game_section.get("RTP1", "")).strip_edges()
	if not rtp.is_empty():
		warnings.append("源工程声明 RTP1=%s；未复制 RTP，缺失窗口皮肤会使用简易样式。" % rtp)
	var report := {
		"tool_version": RGMigratorVersion.DISPLAY_NAME,
		"generated_at": Time.get_datetime_string_from_system(),
		"source_path": source_path,
		"output_path": output_path,
		"project_title": preflight.get("project_title", ""),
		"encoding": codec.label(),
		"maps": data_result.get("converted_maps", 0),
		"data_files": data_result.get("converted_files", 0),
		"assets": asset_result.get("copied_assets", 0),
		"scripts": scripts_mirror.get("count", 0) if scripts_mirror.get("copied", false) else data_result.get("exported_scripts", 0),
		"window": {"width": generator_result.get("width", 640), "height": generator_result.get("height", 480)},
		"test_setup": test_setup,
		"script_migration": script_migration,
		"script_workspace":workspace_result,
		"custom_data":custom_data,
		"flash_gameplay":flash_gameplay,
		"warnings": warnings,
		"errors": errors,
		"ok": errors.is_empty(),
		"unsupported_commands": data_result.get("unsupported_commands", [])
	}
	var report_warnings := MigrationReportWriter.new().write(output_path, report)
	errors.append_array(report_warnings)
	for warning in report_warnings:
		_emit(progress, messages, warning)
	for warning in warnings:
		_emit(progress, messages, "[color=#f7d37b]%s[/color]" % warning)
	for error in errors:
		_emit(progress, messages, "[color=#ff8585]%s[/color]" % error)
	return {"ok": errors.is_empty(), "messages": messages, "output_path": output_path, "report": report}


func _emit(progress: Callable, messages: Array[String], message: String) -> void:
	messages.append(message)
	if progress.is_valid():
		progress.call(message)


func _directory_is_empty(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return true
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			dir.list_dir_end()
			return false
		entry = dir.get_next()
	dir.list_dir_end()
	return true

class_name RmxpValidator
extends RefCounted

const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const RmxpIniReader = preload("res://scripts/importer/RmxpIniReader.gd")


func preflight(source_path: String, export_root: String, requested_encoding: int) -> Dictionary:
	var messages: Array[String] = []
	var errors: Array[String] = []
	if source_path.is_empty() or not DirAccess.dir_exists_absolute(source_path):
		errors.append("请先选择存在的 RMXP 工程根目录。")
	if export_root.is_empty() or not DirAccess.dir_exists_absolute(export_root):
		errors.append("请先选择存在的导出位置。")
	if not errors.is_empty():
		return _result(false, messages, errors)

	for relative in ["Game.rxproj", "Game.ini", "Data", "Data/System.rxdata"]:
		var absolute := source_path.path_join(relative)
		var exists := DirAccess.dir_exists_absolute(absolute) if relative == "Data" else FileAccess.file_exists(absolute)
		if not exists:
			errors.append("缺少 RMXP 必需项目：%s" % relative)
	if not errors.is_empty():
		return _result(false, messages, errors)

	var codec := RmxpTextCodec.new(requested_encoding)
	var ini := RmxpIniReader.new(codec).read(source_path.path_join("Game.ini"))
	var game_section: Dictionary = ini.get("Game", {})
	var title := str(game_section.get("Title", "")).strip_edges()
	if title.is_empty():
		title = source_path.get_file()
		messages.append("[color=#f7d37b]Game.ini 未提供标题，使用目录名：%s[/color]" % title)
	var proposed_name := _safe_project_name(title) + "_Godot"
	var output_path := export_root.path_join(proposed_name)
	var normalized_source := source_path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	var normalized_output := output_path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	if normalized_output == normalized_source or normalized_output.begins_with(normalized_source + "/"):
		errors.append("导出位置不能位于源工程内部，源工程必须保持只读。")
	if FileAccess.file_exists(output_path):
		errors.append("目标路径已被文件占用：%s" % output_path)
	if not codec.error_message.is_empty():
		errors.append(codec.error_message)
	if DirAccess.dir_exists_absolute(output_path) and not _directory_is_empty(output_path):
		errors.append("目标目录已存在且非空：%s" % output_path)

	var data_path := source_path.path_join("Data")
	var map_files := _files_matching(data_path, "Map*.rxdata")
	map_files.erase("MapInfos.rxdata")
	if map_files.is_empty():
		errors.append("Data 目录中没有 Map###.rxdata 地图文件。")
	var database_files := _files_matching(data_path, "*.rxdata")
	var graphics_count := _count_files(source_path.path_join("Graphics"))
	var audio_count := _count_files(source_path.path_join("Audio"))
	var scripts_path := source_path.path_join("Scripts")
	var script_mirror_count := _count_files(scripts_path, ["rb", "md"])
	var rtp := str(game_section.get("RTP1", "")).strip_edges()
	if not rtp.is_empty():
		messages.append("[color=#f7d37b]检测到 RTP1=%s；不复制 RTP。[/color]" % rtp)
	if not FileAccess.file_exists(data_path.path_join("MapInfos.rxdata")):
		messages.append("[color=#f7d37b]未发现 MapInfos.rxdata，地图层级名称将不可用。[/color]")
	messages.append("编码：%s" % codec.label())
	messages.append("工程标题：%s" % title)
	messages.append("数据文件：%d；地图：%d；图像：%d；音频：%d；脚本镜像文件：%d" % [database_files.size(), map_files.size(), graphics_count, audio_count, script_mirror_count])

	var result := _result(errors.is_empty(), messages, errors)
	result.merge({
		"source_path": source_path,
		"export_root": export_root,
		"output_path": output_path,
		"project_title": title,
		"encoding": codec.codepage,
		"ini": ini,
		"map_files": map_files,
		"database_files": database_files,
		"graphics_count": graphics_count,
		"audio_count": audio_count
	})
	return result


func _result(ok: bool, messages: Array[String], errors: Array[String] = []) -> Dictionary:
	var all_messages: Array[String] = []
	all_messages.append_array(messages)
	for error in errors:
		all_messages.append("[color=#ff8585]%s[/color]" % error)
	return {"ok": ok, "messages": all_messages, "errors": errors}


func _safe_project_name(value: String) -> String:
	var name := value.strip_edges()
	for illegal in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		name = name.replace(illegal, "_")
	while name.ends_with(".") or name.ends_with(" "):
		name = name.left(name.length() - 1)
	return name if not name.is_empty() else "RMXP_Project"


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


func _files_matching(path: String, pattern: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.match(pattern):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _count_files(path: String, extensions: Array[String] = []) -> int:
	if not DirAccess.dir_exists_absolute(path):
		return 0
	var count := 0
	var dir := DirAccess.open(path)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				count += _count_files(child, extensions)
			elif extensions.is_empty() or entry.get_extension().to_lower() in extensions:
				count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return count

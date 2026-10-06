class_name RmxpAssetCopier
extends RefCounted

var warnings: Array[String] = []
var errors: Array[String] = []
var copied_assets := 0
var copied_legacy_files := 0
var _output_root := ""
var _probe_index := 0


func copy(source_root: String, output_root: String, progress: Callable = Callable()) -> Dictionary:
	warnings.clear()
	errors.clear()
	copied_assets = 0
	copied_legacy_files = 0
	_output_root = output_root
	_probe_index = 0
	var index := {}
	var legacy_root := output_root.path_join("legacy")
	DirAccess.make_dir_recursive_absolute(legacy_root)
	var ignore := FileAccess.open(legacy_root.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.store_string("# Original files for reference only; not Godot resources.\n")
		ignore.close()
	for root_name in ["Graphics", "Audio"]:
		var source := source_root.path_join(root_name)
		if not DirAccess.dir_exists_absolute(source):
			warnings.append("源工程没有 %s 目录。" % root_name)
			continue
		if progress.is_valid():
			progress.call("复制非 RTP 素材：%s" % root_name)
		_copy_tree(source, output_root.path_join("assets/rmxp").path_join(root_name), source_root, index, true)
	for root_name in ["Font", "Info", "MapSnapshots"]:
		var source := source_root.path_join(root_name)
		if not DirAccess.dir_exists_absolute(source):
			continue
		if progress.is_valid():
			progress.call("保留扩展文件：%s" % root_name)
		_copy_tree(source, output_root.path_join("legacy/extras").path_join(root_name), source_root, index, false)
	var index_path := output_root.path_join("data/asset_index.json")
	DirAccess.make_dir_recursive_absolute(index_path.get_base_dir())
	var output := FileAccess.open(index_path, FileAccess.WRITE)
	if output == null:
		errors.append("无法写入素材索引：%s" % index_path)
	else:
		output.store_string(JSON.stringify(index, "\t", true) + "\n")
		output.close()
	return {
		"warnings": warnings,
		"errors": errors,
		"copied_assets": copied_assets,
		"copied_legacy_files": copied_legacy_files,
		"asset_index": index
	}


func copy_scripts_mirror(source_root: String, output_root: String) -> Dictionary:
	var source := source_root.path_join("Scripts")
	if not DirAccess.dir_exists_absolute(source):
		return {"copied": false, "count": 0}
	var before := copied_legacy_files
	_copy_tree(source, output_root.path_join("legacy/ruby_scripts"), source_root, {}, false)
	return {"copied": copied_legacy_files > before, "count": copied_legacy_files - before}


func _copy_tree(source: String, destination: String, source_root: String, asset_index: Dictionary, is_asset: bool) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	var dir := DirAccess.open(source)
	if dir == null:
		errors.append("无法读取目录：%s" % source)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var input_path := source.path_join(entry)
			var output_path := destination.path_join(entry)
			if dir.current_is_dir():
				_copy_tree(input_path, output_path, source_root, asset_index, is_asset)
			else:
				# Engine sidecars are caches, not original assets. Never migrate them.
				if entry.ends_with(".import") or entry.ends_with(".uid"):
					entry = dir.get_next()
					continue
				if is_asset and _unsupported_asset(input_path):
					var relative := input_path.replace("\\", "/").trim_prefix(source_root.replace("\\", "/").trim_suffix("/") + "/")
					var output_root := destination.replace("\\", "/").get_slice("/assets/rmxp/", 0)
					output_path = output_root.path_join("legacy/unsupported_assets").path_join(relative)
					warnings.append("素材格式不支持或未通过隔离解码检查，已原样保留至 legacy/unsupported_assets：%s" % relative)
					if _copy_file(input_path, output_path):
						copied_assets += 1
					entry = dir.get_next()
					continue
				if is_asset:
					output_path = _correct_image_extension(input_path, output_path)
				if not _copy_file(input_path, output_path):
					entry = dir.get_next()
					continue
				if is_asset:
					copied_assets += 1
					_add_asset_index(asset_index, input_path, source_root, output_path, input_path.get_extension())
				else:
					copied_legacy_files += 1
		entry = dir.get_next()
	dir.list_dir_end()


func _copy_file(source_path: String, destination_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		errors.append("无法读取文件：%s" % source_path)
		return false
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		source.close()
		errors.append("无法写入文件：%s" % destination_path)
		return false
	destination.store_buffer(source.get_buffer(source.get_length()))
	var success := destination.get_error() == OK
	destination.close()
	source.close()
	if not success:
		errors.append("文件写入不完整：%s" % destination_path)
	return success


func _unsupported_asset(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	if extension in ["mid", "midi", "wma", "mp2", "rmi"]:
		return true
	if extension == "mp3":
		return not _probe_audio(path)
	if extension != "wav":
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var length := file.get_length()
	if file.get_buffer(4).get_string_from_ascii() != "RIFF":
		return true
	file.seek(8)
	if file.get_buffer(4).get_string_from_ascii() != "WAVE":
		return true
	var found_format := false
	var found_data := false
	var metadata := false
	while file.get_position() + 8 <= length:
		var chunk := file.get_buffer(4).get_string_from_ascii()
		var size := file.get_32()
		var position := file.get_position()
		if position + size > length:
			return true
		if chunk == "fmt ":
			if size < 16 or file.get_16() not in [1, 3]:
				return true
			found_format = true
		elif chunk == "data":
			found_data = size > 0
		elif chunk not in ["JUNK", "PAD "]:
			metadata = true
		file.seek(mini(length, position + size + (size % 2)))
	file.close()
	if not found_format or not found_data:
		return true
	# RIFF auxiliary metadata can fail the engine decoder even for valid PCM.
	return metadata and not _probe_audio(path)


func _probe_audio(path: String) -> bool:
	_probe_index += 1
	var folder := _output_root.path_join("legacy/audio_validation")
	DirAccess.make_dir_recursive_absolute(folder)
	var result_path := folder.path_join("probe_%d.json" % _probe_index)
	var log_path := folder.path_join("probe_%d.log" % _probe_index)
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://scripts/importer/AudioProbe.gd", "--log-file", log_path, "--", path, result_path])
	var process := OS.create_process(OS.get_executable_path(), arguments)
	if process < 0:
		warnings.append("无法启动隔离音频检查，安全保留原件而不导入：%s" % path)
		return false
	var deadline := Time.get_ticks_msec() + 30000
	while OS.is_process_running(process) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(20)
	if OS.is_process_running(process):
		OS.kill(process)
		warnings.append("音频隔离检查超时，已保留原件：%s" % path)
		return false
	if not FileAccess.file_exists(result_path):
		warnings.append("音频隔离检查异常退出，已保留原件：%s" % path)
		return false
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path))
	var log_text := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	# Includes malformed ID3 tags: a partial stream isn't a clean import result.
	return result is Dictionary and result.get("ok", false) and not "ERROR:" in log_text and not "Unicode parsing error" in log_text


func _correct_image_extension(source: String, destination: String) -> String:
	var extension := source.get_extension().to_lower()
	if extension not in ["png", "jpg", "jpeg"]:
		return destination
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		return destination
	var header := file.get_buffer(8)
	var actual := ""
	if header.size() >= 8 and header == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		actual = "png"
	elif header.size() >= 3 and header[0] == 255 and header[1] == 216 and header[2] == 255:
		actual = "jpg"
	if actual.is_empty() or extension == actual or (extension == "jpeg" and actual == "jpg"):
		return destination
	# Include the complete original filename and a hash: cannot collide with a sibling .png.
	var candidate := destination + ".rgm_" + source.sha256_text().left(12) + "." + actual
	var suffix := 0
	while FileAccess.file_exists(candidate) or FileAccess.file_exists(source.get_base_dir().path_join(candidate.get_file())):
		suffix += 1
		candidate = destination + ".rgm_%s_%d.%s" % [source.sha256_text().left(12), suffix, actual]
	warnings.append("图像文件头与扩展名不符，已修正导出副本及索引：%s → %s" % [source.get_file(), candidate.get_file()])
	return candidate


func _add_asset_index(index: Dictionary, source_path: String, source_root: String, output_path: String, extension: String) -> void:
	var relative := source_path.replace("\\", "/").trim_prefix(source_root.replace("\\", "/").trim_suffix("/") + "/")
	var resource_path := "res://" + output_path.get_file()
	# output_path is absolute; retain the output-relative canonical path instead.
	var assets_marker := "/assets/"
	var position := output_path.replace("\\", "/").find(assets_marker)
	if position >= 0:
		resource_path = "res://" + output_path.replace("\\", "/").substr(position + 1)
	index[relative] = resource_path
	var without_extension := relative.left(relative.length() - extension.length() - 1) if not extension.is_empty() else relative
	if not index.has(without_extension):
		index[without_extension] = resource_path
	var lower := without_extension.to_lower()
	if not index.has(lower):
		index[lower] = resource_path

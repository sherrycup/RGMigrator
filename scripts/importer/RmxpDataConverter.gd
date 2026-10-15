class_name RmxpDataConverter
extends RefCounted

const EditorScripts = preload("res://templates/editor/addons/rgm_editor/EditorScriptAdapter.gd")
const ScriptInventory = preload("res://scripts/importer/ScriptMigrationInventory.gd")

const RmxpMarshalReader = preload("res://scripts/importer/RmxpMarshalReader.gd")
const RmxpTableDecoder = preload("res://scripts/importer/RmxpTableDecoder.gd")
const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const RAW_STRING_KEY := "_rmxp_raw_string"
const EventCommands = preload("res://templates/runtime/scripts/EventCommandCatalog.gd")

var _codec: RmxpTextCodec
var _asset_index: Dictionary = {}
var _missing_assets: Dictionary = {}
var warnings: Array[String] = []
var errors: Array[String] = []
var unsupported_commands: Array[Dictionary] = []
var converted_files := 0
var converted_maps := 0
var exported_scripts := 0
var script_sources: Array[Dictionary] = []
var script_inventory: RefCounted


func _init(text_codec: RmxpTextCodec) -> void:
	_codec = text_codec


func set_asset_index(asset_index: Dictionary) -> void:
	_asset_index = asset_index


func convert(source_root: String, output_root: String, progress: Callable = Callable(), export_scripts_from_data: bool = true) -> Dictionary:
	warnings.clear()
	errors.clear()
	_missing_assets.clear()
	unsupported_commands.clear()
	converted_files = 0
	converted_maps = 0
	exported_scripts = 0
	script_sources.clear()
	script_inventory = ScriptInventory.new()
	var data_root := source_root.path_join("Data")
	var output_data := output_root.path_join("data")
	DirAccess.make_dir_recursive_absolute(output_data.path_join("database"))
	DirAccess.make_dir_recursive_absolute(output_data.path_join("maps"))
	DirAccess.make_dir_recursive_absolute(output_root.path_join("legacy/ruby_scripts"))
	var files := _list_rxdata(data_root)
	# Read ordered scripts first so raw event grouping can respect the source
	# Interpreter's known contiguous355 override before editor adaptation.
	if files.has("Scripts.rxdata"): files.erase("Scripts.rxdata"); files.push_front("Scripts.rxdata")
	var manifest := {
		"format": "rgmigrator-rmxp-v1",
		"encoding": _codec.label(),
		"maps": [],
		"database": []
	}
	for filename in files:
		if progress.is_valid():
			progress.call("读取数据：Data/%s" % filename)
		var reader := RmxpMarshalReader.new(_codec)
		var source_path := data_root.path_join(filename)
		var raw: Variant = reader.read_file(source_path)
		if reader.failed:
			errors.append("无法解析 Data/%s：%s" % [filename, reader.error_message])
			continue
		if filename == "Scripts.rxdata":
			var destination := output_root.path_join("legacy/ruby_scripts" if export_scripts_from_data else "legacy/ordered_scripts")
			DirAccess.make_dir_recursive_absolute(destination)
			_export_scripts(raw, destination)
			script_inventory.configure_scripts(script_sources)
			continue
		var converted: Variant = _convert_value(raw)
		_audit_asset_references(converted)
		if filename == "MapInfos.rxdata":
			_write_json(output_data.path_join("map_infos.json"), converted)
			manifest["map_infos"] = "map_infos.json"
		elif filename.begins_with("Map"):
			script_inventory.collect_map(converted, filename.get_basename())
			converted = EditorScripts.adapt_map(converted)
			var map_name := filename.get_basename()
			_write_json(output_data.path_join("maps").path_join("%s.json" % map_name), converted)
			manifest["maps"].append(map_name)
			converted_maps += 1
			_scan_map_commands(converted, map_name)
		else:
			var output_name := filename.get_basename()
			if filename == "System.rxdata":
				_write_json(output_data.path_join("system.json"), converted)
				manifest["system"] = "system.json"
			else:
				if output_name in ["CommonEvents", "CommonEvent"] and converted is Array:
					script_inventory.collect_common(converted,output_name)
					converted = EditorScripts.adapt_common(converted)
				_write_json(output_data.path_join("database").path_join("%s.json" % output_name), converted)
				manifest["database"].append(output_name)
				if output_name in ["CommonEvents", "CommonEvent"] and converted is Array:
					for event in converted:
						if event is Dictionary:
							_scan_command_list(event.get("list", []), "公共事件", str(event.get("id", 0)), 0)
				if output_name == "Troops" and converted is Array:
					for troop in converted:
						if not troop is Dictionary: continue
						var pages: Array = troop.get("pages", [])
						for index in pages.size():
							_scan_command_list(pages[index].get("list", []), "敌群（回合制战斗不迁移）", str(troop.get("id", 0)), index + 1)
		converted_files += 1
	for missing in _missing_assets:
		warnings.append("缺少非 RTP 素材或仍依赖 RTP：%s" % missing)
	_write_json(output_data.path_join("manifest.json"), manifest)
	return {
		"manifest": manifest,
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"unsupported_commands": unsupported_commands,
		"converted_files": converted_files,
		"converted_maps": converted_maps,
		"exported_scripts": exported_scripts
	}


func _list_rxdata(data_root: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(data_root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.get_extension().to_lower() == "rxdata":
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _convert_value(value: Variant) -> Variant:
	if value is Array:
		var converted: Array = []
		for item in value:
			converted.append(_convert_value(item))
		return converted
	if value is PackedByteArray:
		return {"_rmxp_bytes_hex": value.hex_encode()}
	if not (value is Dictionary):
		return value
	if value.has(RAW_STRING_KEY):
		return _codec.decode(value[RAW_STRING_KEY])
	if value.get("_rmxp_user_defined", "") == "Table":
		var table: Variant = RmxpTableDecoder.decode(value)
		if table is Dictionary and table.has("_rmxp_table_error"):
			errors.append(str(table["_rmxp_table_error"]))
		return table
	if value.get("_rmxp_user_defined", "") in ["Color", "Tone"]:
		var bytes: PackedByteArray = value.get("payload", PackedByteArray())
		if bytes.size() == 32:
			return {"_class": value["_rmxp_user_defined"], "red": bytes.decode_double(0), "green": bytes.decode_double(8), "blue": bytes.decode_double(16), "alpha" if value["_rmxp_user_defined"] == "Color" else "gray": bytes.decode_double(24)}
	if value.has("_rmxp_hash"):
		return _convert_hash(value)
	if value.has("_rmxp_object"):
		var object_value := {"_class": value["_rmxp_object"]}
		var fields: Dictionary = value.get("_rmxp_ivars", {})
		for raw_key in fields:
			var key := str(raw_key)
			if key.begins_with("@"):
				key = key.substr(1)
			object_value[key] = _convert_value(fields[raw_key])
		return object_value
	if value.has("_rmxp_struct"):
		var struct_value := {"_class": value["_rmxp_struct"]}
		for key in value.get("_rmxp_members", {}):
			struct_value[str(key)] = _convert_value(value["_rmxp_members"][key])
		return struct_value
	if value.has("_rmxp_bignum") or value.has("_rmxp_float"):
		return value
	if value.has("_rmxp_regexp"):
		return {"_rmxp_regexp_hex": value["_rmxp_regexp"].hex_encode(), "options": value.get("options", 0)}
	if value.has("_rmxp_user_defined"):
		return {
			"_class": value["_rmxp_user_defined"],
			"_rmxp_user_defined_hex": value.get("payload", PackedByteArray()).hex_encode()
		}
	var generic := {}
	for key in value:
		if not str(key).begins_with("_rmxp_"):
			generic[str(key)] = _convert_value(value[key])
	return generic


func _convert_hash(value: Dictionary) -> Variant:
	var entries: Array = value.get("_rmxp_hash", [])
	var simple := true
	var result := {}
	for pair in entries:
		if not (pair is Array) or pair.size() != 2:
			simple = false
			break
		var key: Variant = _convert_value(pair[0])
		if not (key is String or key is int):
			simple = false
			break
		result[str(key)] = _convert_value(pair[1])
	if simple:
		return result
	var serialized_entries: Array = []
	for pair in entries:
		serialized_entries.append({"key": _convert_value(pair[0]), "value": _convert_value(pair[1])})
	return {"_rmxp_hash_entries": serialized_entries}


func _export_scripts(raw: Variant, destination: String) -> void:
	if not (raw is Array):
		warnings.append("Scripts.rxdata 不是预期的脚本数组。")
		return
	for index in raw.size():
		var entry: Variant = raw[index]
		if not (entry is Array) or entry.size() < 3:
			warnings.append("Scripts.rxdata 第 %d 项格式无效。" % index)
			continue
		var title := _string_from_value(entry[1])
		var packed := _bytes_from_value(entry[2])
		if packed.is_empty():
			warnings.append("脚本 %d（%s）缺少压缩源码。" % [index, title])
			continue
		var source_bytes := packed.decompress_dynamic(128 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE)
		# A valid zlib stream can contain an empty separator script.
		if source_bytes.is_empty() and packed != PackedByteArray([120,156,3,0,0,0,0,1]) and packed != PackedByteArray([120,218,3,0,0,0,0,1]) and packed != PackedByteArray([120,1,3,0,0,0,0,1]):
			warnings.append("脚本 %d（%s）无法用 zlib 解压。" % [index, title])
			continue
		var safe_title := _safe_filename(title)
		var path := destination.path_join("%04d_%s.rb" % [index + 1, safe_title])
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			warnings.append("无法写出脚本：%s" % path)
			continue
		var source := _codec.decode(source_bytes)
		file.store_string(source)
		file.close()
		script_sources.append({"unit_id": "script_%04d" % (index+1), "source": source, "source_path": "legacy/%s/%s" % [destination.get_file(),path.get_file()], "origin": {"kind": "script", "source_file": "Data/Scripts.rxdata", "load_order": index+1, "script_id": _convert_value(entry[0]), "name": title}})
		exported_scripts += 1


func _string_from_value(value: Variant) -> String:
	if value is Dictionary and value.has(RAW_STRING_KEY):
		return _codec.decode(value[RAW_STRING_KEY])
	return str(_convert_value(value))


func _bytes_from_value(value: Variant) -> PackedByteArray:
	if value is Dictionary and value.has(RAW_STRING_KEY):
		return value[RAW_STRING_KEY]
	return PackedByteArray()


func _safe_filename(value: String) -> String:
	var result := value.strip_edges()
	for illegal in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(illegal, "_")
	return result if not result.is_empty() else "unnamed"


func _scan_map_commands(map: Variant, map_name: String) -> void:
	if not (map is Dictionary):
		return
	var events: Variant = map.get("events", {})
	if not (events is Dictionary):
		return
	for event_id in events:
		var event: Variant = events[event_id]
		if not (event is Dictionary):
			continue
		var pages: Variant = event.get("pages", [])
		if not (pages is Array):
			continue
		for page_index in pages.size():
			var page: Variant = pages[page_index]
			if not (page is Dictionary):
				continue
			_scan_command_list(page.get("list", []), map_name, str(event_id), page_index + 1)
			_scan_route(page.get("move_route", {}), map_name, str(event_id), page_index + 1, 0)


func _scan_command_list(commands: Variant, map_name: String, event_id: String, page: int) -> void:
	if not (commands is Array):
		return
	for command_index in commands.size():
		var command: Variant = commands[command_index]
		if not (command is Dictionary):
			continue
		var code := int(command.get("code", 0))
		var raw: Variant = command.get("parameters", [])
		var parameters: Array = raw if raw is Array else []
		var reason := EventCommands.reason(code, parameters) if raw is Array else "事件参数不是数组"
		if not reason.is_empty():
			unsupported_commands.append({
				"map": map_name,
				"event_id": event_id,
				"page": page,
				"command_index": command_index + 1,
				"code": code,
				"reason": reason
			})
		if code == 209 and parameters.size() > 1: _scan_route(parameters[1], map_name, event_id, page, command_index + 1)


func _scan_route(route: Variant, map_name: String, event_id: String, page: int, command_index: int) -> void:
	if not route is Dictionary: return
	var raw: Variant = route.get("list", [])
	if not raw is Array: return
	var commands: Array = raw
	for index in commands.size():
		if not commands[index] is Dictionary: continue
		var code := int(commands[index].get("code", 0))
		var p: Variant = commands[index].get("parameters", [])
		var reason := EventCommands.route_reason(code, p) if p is Array else "路线参数不是数组"
		if reason.is_empty(): continue
		unsupported_commands.append({"map": map_name, "event_id": event_id, "page": page, "command_index": command_index, "code": 209, "route_index": index + 1, "route_code": code, "reason": reason})


func _unsupported_reason(code: int) -> String:
	match code:
		301:
			return "战斗处理"
		302:
			return "商店处理"
		303:
			return "姓名输入处理"
		351:
			return "打开菜单画面"
		352:
			return "打开存档画面"
		353:
			return "游戏结束"
		355, 655:
			return "Ruby 脚本"
	return "未支持的事件指令"


func _write_json(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append("无法写入 JSON：%s" % path)
		return
	file.store_string(JSON.stringify(value, "\t", false) + "\n")
	if file.get_error() != OK:
		errors.append("JSON 写入不完整：%s" % path)
	file.close()


func _audit_asset_references(value: Variant) -> void:
	if value is Array:
		for item in value:
			_audit_asset_references(item)
		return
	if not (value is Dictionary):
		return
	var categories := {
		"title_name": "Graphics/Titles",
		"tileset_name": "Graphics/Tilesets",
		"autotile_names": "Graphics/Autotiles",
		"character_name": "Graphics/Characters",
		"battler_name": "Graphics/Battlers",
		"animation_name": "Graphics/Animations",
		"icon_name": "Graphics/Icons",
		"panorama_name": "Graphics/Panoramas",
		"fog_name": "Graphics/Fogs",
		"battleback_name": "Graphics/Battlebacks",
		"windowskin_name": "Graphics/Windowskins"
	}
	for key in categories:
		if value.has(key):
			var names: Array = value[key] if value[key] is Array else [value[key]]
			for name in names:
				var asset_name := str(name)
				if not asset_name.is_empty():
					var expected := "%s/%s" % [categories[key], asset_name]
					if not _asset_index.has(expected) and not _asset_index.has(expected.get_basename()):
						_missing_assets[expected] = true
	var audio_categories := {
		"title_bgm": "Audio/BGM", "battle_bgm": "Audio/BGM", "battle_end_me": "Audio/ME",
		"gameover_me": "Audio/ME", "bgm": "Audio/BGM", "bgs": "Audio/BGS",
		"me": "Audio/ME", "se": "Audio/SE"
	}
	for key in audio_categories:
		if value.has(key) and value[key] is Dictionary:
			var audio_name := str(value[key].get("name", ""))
			if not audio_name.is_empty():
				var expected := "%s/%s" % [audio_categories[key], audio_name]
				if not _asset_index.has(expected) and not _asset_index.has(expected.get_basename()):
					_missing_assets[expected] = true
	for child in value.values():
		_audit_asset_references(child)

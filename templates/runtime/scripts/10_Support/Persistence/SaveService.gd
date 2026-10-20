## 职责：协调存档位读写、备份和兼容性指纹，完整验证后恢复正式运行状态。
##
## 调用方式：
##   静态服务：preload("res://runtime/scripts/10_Support/Persistence/SaveService.gd").save_slot(slot, RuntimeState) 或 load_slot(slot, RuntimeState)。
##   界面先用 slot_info(slot) 展示摘要，实际读取仍走完整验证。
##
## 调用接口：
##   static func project_id() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func directory() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func slot_path(slot: int) -> String
##     参数 slot（int；必填）：存档位正整数；有效上限通过 maximum_slots() 查询。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func maximum_slots() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func existing_slots() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func fingerprint() -> String
##     用途：计算当前工程定义的存档兼容性指纹。
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func save_slot(slot: int, state: Node) -> Dictionary
##     用途：捕获现场、完整校验并以临时文件和备份写入档位。
##     参数 slot（int；必填）：存档位正整数；有效上限通过 maximum_slots() 查询。
##     参数 state（Node；必填）：需要保存的正式 RuntimeState 实例。
##     返回：成功返回 ok、message、path；失败返回 ok=false 与 message。
##
##   static func read_slot(slot: int) -> Dictionary
##     用途：读取主档，必要时验证并回退备份。
##     参数 slot（int；必填）：存档位正整数；有效上限通过 maximum_slots() 查询。
##     返回：读取结果字典；recovered 表示是否使用备份，不立即改写正式状态。
##
##   static func read_path(path: String) -> Dictionary
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func read_slot_cooperatively( slot: int, definitions: RefCounted, pulse: Callable ) -> Dictionary
##     用途：在主线程分帧完整校验存档及备份，规则来自规范SavePreparation。
##     参数 slot（int；必填）：实际存档编号。
##     参数 definitions（RefCounted；必填）：当前只读自定义数据定义服务。
##     参数 pulse（Callable；必填）：异步pulse() -> bool，按帧让出并检查归属和取消。
##     返回：与read_slot相同的结果字典，取消时ok=false。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   static func load_slot(slot: int, state: Node) -> Dictionary
##     用途：验证存档后恢复正式游戏现场。
##     参数 slot（int；必填）：存档位正整数；有效上限通过 maximum_slots() 查询。
##     参数 state（Node；必填）：需要恢复到的正式 RuntimeState 实例。
##     返回：读取结果字典，成功含 prepared、saved_at、path，并可能带 recovered；失败含 message。
##
##   static func slot_info(slot: int) -> Dictionary
##     用途：读取经过校验的存档摘要并复用相同字节缓存。
##     参数 slot（int；必填）：存档位正整数；有效上限通过 maximum_slots() 查询。
##     返回：摘要字典，包括 ok、exists，以及成功时的 party、map_id、play_seconds 等。
##
##   static func has_valid_save() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func write_text(path: String, content: String) -> Error
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     参数 content（String；必填）：需要写入或显示的文本内容。
##     返回：Error 类型的对象或值，供调用方继续使用。
##
##   static func fail(message: String) -> Dictionary
##     用途：构造或登记带原因的失败结果。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：SLOT_COUNT、FORMAT、SCHEMA、MAX_BYTES、INFO_CACHE_LIMIT、ADAPTER_TARGET_ALIASES。
## 注意：directory_override 仅供独立测试使用；正常游戏使用工程自己的用户存档目录。
## 接口说明结束。

extends RefCounted
## Four slots, checksummed versioned JSON, backup, validate-before-commit loading.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Codec = preload("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
const Version = preload("res://runtime/scripts/00_Game/RuntimeVersion.gd")
const ProgramDocs = preload("../Scripting/ProgramDocumentation.gd")
const SLOT_COUNT := 4
const FORMAT := "rgmigrator-save"
const SCHEMA := 1
const MAX_BYTES := 8 * 1024 * 1024
const INFO_CACHE_LIMIT := 16
## Adapter locations are navigation metadata; these two paths identify the
## same unchanged adapter across the 0.50 directory move.
const ADAPTER_TARGET_ALIASES := {
	"runtime/scripts/00_Game/CustomDataState.gd": "runtime/scripts/CustomDataState.gd"
}
static var directory_override := ""  # Disposable test directories only; production uses user://.
static var _fingerprint := ""
static var _info_cache: Dictionary = {}
static var _info_order: Array[String] = []


static func project_id() -> String:
	return str(
		ProjectSettings.get_setting(
			"rgmigrator/project_id",
			str(ProjectSettings.get_setting("application/config/name", "RMXP Game")).sha256_text()
		)
	)


static func directory() -> String:
	var test_directory = str(ProjectSettings.get_setting("rgmigrator/test_save_directory", ""))
	return (
		directory_override
		if not directory_override.is_empty()
		else (
			test_directory
			if not test_directory.is_empty()
			else "user://rgmigrator_saves/" + project_id().sha256_text().left(24)
		)
	)


static func slot_path(slot: int) -> String:
	return directory().path_join("slot%d.json" % slot)


static func maximum_slots() -> int:
	return (
		4096
		if Data.read_json("res://data/custom_data.json", {}).get("profile") == "flash"
		else SLOT_COUNT
	)


static func existing_slots() -> Array:
	if maximum_slots() == SLOT_COUNT:
		return range(1, SLOT_COUNT + 1)
	var result: Array = []
	if not DirAccess.dir_exists_absolute(directory()):
		return result
	var matcher = RegEx.new()
	matcher.compile("^slot([0-9]+)\\.json(?:\\.bak)?$")
	for name in DirAccess.get_files_at(directory()):
		var found = matcher.search(name)
		if found == null:
			continue
		var id = int(found.get_string(1))
		if id >= 1 and id <= maximum_slots() and not id in result:
			result.append(id)
	result.sort()
	return result


static func fingerprint() -> String:
	if not _fingerprint.is_empty():
		return _fingerprint
	var files: Array[String] = [
		"res://data/system.json", "res://data/manifest.json", "res://data/map_infos.json"
	]
	for file in [
		"res://data/custom_data.json",
		"res://data/custom_units.json",
		"res://data/flash_gameplay.json"
	]:
		if FileAccess.file_exists(file):
			files.append(file)
	for name in Data.manifest().get("database", []):
		files.append("res://data/database/%s.json" % name)
	for name in Data.manifest().get("maps", []):
		files.append("res://data/maps/%s.json" % name)
	files.sort()
	var hashes := ""
	for path in files:
		hashes += path + ":" + _definition_hash(path) + "\n"
	_fingerprint = hashes.sha256_text()
	return _fingerprint


static func _definition_hash(path: String) -> String:
	var byte_hash := FileAccess.get_sha256(path)
	var native_upgrade: Dictionary = Data.read_json("res://data/native_event_sources.json", {})
	var upgrade: Dictionary = native_upgrade.get("entries", {}).get(path.trim_prefix("res://"), {})
	var legacy_path = str(upgrade.get("legacy_path", ""))
	if (
		upgrade.get("native_sha256") == byte_hash
		and legacy_path.begins_with("legacy/native_events/data/")
		and not legacy_path.contains("..")
	):
		if FileAccess.get_sha256("res://" + legacy_path) == upgrade.get("legacy_sha256"):
			if path == "res://data/flash_gameplay.json":
				return _gameplay_definition_hash("res://" + legacy_path)
			return upgrade.legacy_sha256
	if path == "res://data/flash_gameplay.json":
		return _gameplay_definition_hash(path)
	if path == "res://data/custom_units.json":
		return _custom_units_hash(path)
	if path != "res://data/custom_data.json":
		return byte_hash
	var source := FileAccess.get_file_as_string(path)
	var manifest: Variant = JSON.parse_string(source)
	if not manifest is Dictionary or not manifest.get("adapters") is Array:
		return byte_hash
	# The importer writes top-level arrays at one-tab indentation. Restrict
	# alias replacement to adapter target fields and preserve every other byte;
	# parsing and reserializing would change JSON integer spelling.
	var start := source.find('\n\t"adapters": [\n')
	var end := source.find("\n\t]", start) if start >= 0 else -1
	if start < 0 or end < 0:
		return byte_hash
	end += 3
	var adapters := source.substr(start, end - start)
	for target in ADAPTER_TARGET_ALIASES:
		var field := '\n\t\t\t"target": '
		adapters = adapters.replace(
			field + JSON.stringify(target), field + JSON.stringify(ADAPTER_TARGET_ALIASES[target])
		)
	return (source.substr(0, start) + adapters + source.substr(end)).sha256_text()


static func _gameplay_definition_hash(path: String) -> String:
	# Only the generated catalog's exact navigation field changed in0.59.
	# Preserve every other byte, including skills, event sources and input SHA.
	var source = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(source)
	if not parsed is Dictionary or not parsed.get("generated_skill_catalog") is Dictionary:
		return FileAccess.get_sha256(path)
	if parsed.generated_skill_catalog.get("path") != "res://runtime/generated/skill_catalog.gd":
		return source.sha256_text()
	var start = source.find('\n\t"generated_skill_catalog": {\n')
	var end = source.find("\n\t}", start) if start >= 0 else -1
	if start < 0 or end < 0:
		return source.sha256_text()
	var block = source.substr(start, end - start)
	var field = '\n\t\t"path": '
	block = block.replace(
		field + '"res://runtime/generated/skill_catalog.gd"',
		field + '"res://runtime/generated/flash_skill_catalog.gd"'
	)
	return (source.substr(0, start) + block + source.substr(end)).sha256_text()


static func _custom_units_hash(path: String) -> String:
	# Source-map line numbers are navigation metadata. Reverse only the exact
	# known compiler header shifts, after checking the real generated tick.
	# Preserve every other original JSON byte, including expression values.
	var source := FileAccess.get_file_as_string(path)
	var manifest: Variant = JSON.parse_string(source)
	if not manifest is Dictionary or not manifest.get("units") is Dictionary:
		return FileAccess.get_sha256(path)
	for id in manifest.units:
		if not str(id).begins_with("data_") or not str(id).trim_prefix("data_").is_valid_int():
			continue
		var unit: Variant = manifest.units[id]
		var program_path := "res://runtime/generated/" + str(id) + ".gd"
		if (
			not unit is Dictionary
			or unit.get("generated_path") != program_path
			or not unit.get("source_map") is Array
			or not FileAccess.file_exists(program_path)
		):
			continue
		var program := FileAccess.get_file_as_string(program_path)
		if ProgramDocs.header_info(program).lines == 0:
			continue
		var start := source.find("\n\t\t" + JSON.stringify(str(id)) + ": {\n")
		var end := source.find("\n\t\t}", start) if start >= 0 else -1
		if start < 0 or end < 0:
			continue
		var block := source.substr(start, end - start)
		var map_start := block.find('\n\t\t\t"source_map": [\n')
		var map_end := block.find("\n\t\t\t]", map_start) if map_start >= 0 else -1
		if map_start < 0 or map_end < 0:
			continue
		var mapping := block.substr(map_start, map_end - map_start)
		for row in unit.source_map:
			if (
				not row is Dictionary
				or row.get("generated_function") != "program"
				or not row.get("span") is Dictionary
				or not (row.get("generated_line") is int or row.get("generated_line") is float)
			):
				continue
			var line := int(row.get("generated_line", 0))
			var original_line: int = ProgramDocs.canonical_line(
				program, row.span, row.generated_line
			)
			if original_line < 0:
				continue
			var field := '\n\t\t\t\t\t"generated_line": '
			mapping = mapping.replace(field + str(line) + ",", field + str(original_line) + ",")
		block = block.substr(0, map_start) + mapping + block.substr(map_end)
		source = source.substr(0, start) + block + source.substr(end)
	return source.sha256_text()


static func save_slot(slot: int, state: Node) -> Dictionary:
	var game: Node = state.game()
	if (
		slot < 1
		or slot > maximum_slots()
		or (state.save_disabled and (game == null or not game.event_save_override()))
		or not state.playing
	):
		return fail("槽位无效或当前禁止存档。")
	if not state.player_motion.is_idle():
		return fail("人物正在行走或跳跃，请等待到达完整格后存档。")
	if game != null and not game.event_save_reason().is_empty():
		return fail(game.event_save_reason())
	if state.get("flash_history") != null:
		state.flash_history.flush_pending()
	var snapshot := Codec.capture(state)
	if state.save_count >= Codec.MAX_INTEGER:
		return fail("存档次数超出可保存范围。")
	snapshot.save_count = state.save_count + 1
	var prepared := Codec.prepare(snapshot)
	if not prepared.ok:
		return prepared
	var encoded = (
		preload("SaveGraph.gd").encode(snapshot)
		if state.custom_data.manifest.get("profile") == "flash"
		else {"ok": true, "value": snapshot}
	)
	if not encoded.ok:
		return fail(encoded.message)
	var payload := JSON.stringify(encoded.value, "", true)
	var envelope := {
		"format": FORMAT,
		"schema_version": SCHEMA,
		"runtime_version": Version.VERSION,
		"project_id": project_id(),
		"data_fingerprint": fingerprint(),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"payload": payload,
		"sha256": payload.sha256_text()
	}
	var content := JSON.stringify(envelope, "\t", true)
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return fail("存档超过大小限制。")
	var ancestor := ProjectSettings.globalize_path(directory())
	for _index in 128:
		if FileAccess.file_exists(ancestor):
			return fail("存档目录被文件阻断：" + ancestor)
		if DirAccess.dir_exists_absolute(ancestor):
			break
		var parent := ancestor.get_base_dir()
		if parent == ancestor or parent.is_empty():
			break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(directory()) != OK:
		return fail("无法创建存档目录：" + directory())
	var path := slot_path(slot)
	var temporary := path + ".tmp-%d" % OS.get_process_id()
	var error := write_text(temporary, content)
	if error != OK:
		return fail("临时存档写入失败（%s）；原槽位未修改。" % error_string(error))
	var verified := read_path(temporary)
	if not verified.ok:
		return fail("临时存档校验失败：%s；原槽位未修改。" % verified.message)
	if FileAccess.file_exists(path):
		if read_path(path).ok:
			var backup_temporary := path + ".bak.tmp-%d" % OS.get_process_id()
			if (
				DirAccess.copy_absolute(path, backup_temporary) != OK
				or DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK
			):
				return fail("备份失败；原槽位未修改。")
		else:
			# Do not replace a known-good backup with damaged primary contents.
			var recovery := path + ".damaged-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
			if DirAccess.copy_absolute(path, recovery) != OK:
				return fail("无法保留原损坏存档；没有覆盖槽位。")
	# Same-directory rename; never delete the primary before replacing it.
	if DirAccess.rename_absolute(temporary, path) != OK:
		return fail("替换存档失败；原件或备份仍可恢复。")
	state.save_count = snapshot.save_count
	_cache_info(slot, _info_stamp(slot), _summarize(verified))
	state.state_changed.emit()
	return {
		"ok": true, "message": "已保存至存档 %d。" % slot, "path": ProjectSettings.globalize_path(path)
	}


static func read_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > maximum_slots():
		return fail("无效槽位。")
	var path := slot_path(slot)
	var primary := read_path(path)
	if primary.ok:
		primary["recovered"] = false
		return primary
	var backup := read_path(path + ".bak")
	if backup.ok:
		backup["recovered"] = true
		backup["message"] = "主存档不可用，将读取上一份备份。"
		return backup
	primary["exists"] = FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	return primary


static func read_path(path: String) -> Dictionary:
	var payload = _read_payload(path)
	if not payload.ok:
		return payload
	var prepared = Codec.prepare(payload.value, null, true)
	if not prepared.ok:
		return prepared
	return {"ok": true, "prepared": prepared, "saved_at": payload.saved_at, "path": path}


static func read_slot_cooperatively(
	slot: int, definitions: RefCounted, pulse: Callable
) -> Dictionary:
	if slot < 1 or slot > maximum_slots():
		return fail("无效槽位。")
	var primary: Dictionary = {}
	for backup in [false, true]:
		if not await pulse.call():
			return {"ok": false, "cancelled": true, "message": "读取已取消。"}
		var path = slot_path(slot) + (".bak" if backup else "")
		var payload = _read_payload(path)
		var result = payload
		if payload.ok:
			var prepared = await preload("SavePreparation.gd").prepare_cooperatively(
				payload.value, definitions, true, pulse
			)
			result = (
				{"ok": true, "prepared": prepared, "saved_at": payload.saved_at, "path": path}
				if prepared.ok
				else prepared
			)
		if result.ok:
			result["recovered"] = backup
			if backup:
				result["message"] = "主存档不可用，将读取上一份备份。"
			return result
		if not backup:
			primary = result
	primary["exists"] = (
		FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")
	)
	return primary


static func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fail("空槽位。")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return fail("无法读取文件或文件过大。")
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return fail("存档 JSON 损坏。")
	var envelope: Dictionary = json.data
	if (
		envelope.get("format") != FORMAT
		or not Codec.integer(envelope.get("schema_version"), 1)
		or int(envelope.schema_version) != SCHEMA
	):
		return fail("不支持的存档格式/版本（不读取旧 RM 存档）。")
	if (
		envelope.get("project_id") != project_id()
		or envelope.get("data_fingerprint") != fingerprint()
	):
		return fail("存档不属于当前工程，或数据库/地图已发生变化。")
	if (
		not envelope.get("payload") is String
		or not envelope.get("sha256") is String
		or envelope.payload.sha256_text() != envelope.sha256
	):
		return fail("存档完整性校验失败。")
	if not envelope.get("saved_at") is String or envelope.saved_at.length() > 64:
		return fail("保存时间无效。")
	if json.parse(envelope.payload) != OK:
		return fail("进度 JSON 损坏。")
	return {"ok": true, "value": json.data, "saved_at": envelope.saved_at}


static func load_slot(slot: int, state: Node) -> Dictionary:
	var result := read_slot(slot)
	if result.ok:
		state.restore_prepared(result.prepared)
	return result


static func slot_info(slot: int) -> Dictionary:
	var key := ProjectSettings.globalize_path(slot_path(slot))
	var stamp := _info_stamp(slot)
	if _info_cache.has(key) and _info_cache[key].stamp == stamp:
		_info_order.erase(key)
		_info_order.append(key)
		return _info_cache[key].value.duplicate(true)
	var result := read_slot(slot)
	var info := _summarize(result)
	_cache_info(slot, stamp, info)
	return info.duplicate(true)


static func _summarize(result: Dictionary) -> Dictionary:
	if not result.ok:
		return {"ok": false, "exists": result.get("exists", false), "message": result.message}
	var names: Array[String] = []
	for id in result.prepared.state.party:
		names.append(result.prepared.actors[int(id)].actor_name)
	return {
		"ok": true,
		"exists": true,
		"saved_at": result.saved_at,
		"party": "、".join(names),
		"play_seconds": result.prepared.state.play_seconds,
		"map_id": result.prepared.state.map_id,
		"recovered": result.get("recovered", false),
		"archive": result.prepared.state.get("flash_archive", {})
	}


static func has_valid_save() -> bool:
	for slot in existing_slots():
		if slot_info(slot).ok:
			return true
	return false


static func _info_stamp(slot: int) -> String:
	# Hash bytes, not just second-resolution mtime: equal-size external edits and
	# backup replacements must invalidate summaries. Actual loading never uses them.
	var stamp := project_id() + ":" + fingerprint()
	for path in [slot_path(slot), slot_path(slot) + ".bak"]:
		if not FileAccess.file_exists(path):
			stamp += ":missing"
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			stamp += ":unreadable"
			continue
		var length := file.get_length()
		file.close()
		stamp += (
			":" + (FileAccess.get_sha256(path) if length <= MAX_BYTES else "oversize-%d" % length)
		)
	return stamp


static func _cache_info(slot: int, stamp: String, info: Dictionary) -> void:
	var key := ProjectSettings.globalize_path(slot_path(slot))
	_info_cache[key] = {"stamp": stamp, "value": info.duplicate(true)}
	_info_order.erase(key)
	_info_order.append(key)
	while _info_order.size() > INFO_CACHE_LIMIT:
		_info_cache.erase(_info_order.pop_front())


static func write_text(path: String, content: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	return error


static func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

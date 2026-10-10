extends RefCounted
## Four slots, checksummed versioned JSON, backup, validate-before-commit loading.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Codec = preload("res://runtime/scripts/SaveCodec.gd")
const Version = preload("res://runtime/scripts/RuntimeVersion.gd")
const SLOT_COUNT := 4
const FORMAT := "rgmigrator-save"
const SCHEMA := 1
const MAX_BYTES := 8 * 1024 * 1024
static var directory_override := "" # Disposable test directories only; production uses user://.
static var _fingerprint := ""


static func project_id() -> String:
	return str(ProjectSettings.get_setting("rgmigrator/project_id", str(ProjectSettings.get_setting("application/config/name", "RMXP Game")).sha256_text()))


static func directory() -> String:
	return directory_override if not directory_override.is_empty() else "user://rgmigrator_saves/" + project_id().sha256_text().left(24)


static func slot_path(slot: int) -> String:
	return directory().path_join("slot%d.json" % slot)


static func fingerprint() -> String:
	if not _fingerprint.is_empty():
		return _fingerprint
	var files: Array[String] = ["res://data/system.json", "res://data/manifest.json", "res://data/map_infos.json"]
	for name in Data.manifest().get("database", []):
		files.append("res://data/database/%s.json" % name)
	for name in Data.manifest().get("maps", []):
		files.append("res://data/maps/%s.json" % name)
	files.sort()
	var hashes := ""
	for path in files:
		hashes += path + ":" + FileAccess.get_sha256(path) + "\n"
	_fingerprint = hashes.sha256_text()
	return _fingerprint


static func save_slot(slot: int, state: Node) -> Dictionary:
	var game: Node = state.game()
	if slot < 1 or slot > SLOT_COUNT or (state.save_disabled and (game == null or not game.event_save_override())) or not state.playing:
		return fail("槽位无效或当前禁止存档。")
	if not state.player_motion.is_idle(): return fail("人物正在行走或跳跃，请等待到达完整格后存档。")
	if game != null and not game.event_save_reason().is_empty(): return fail(game.event_save_reason())
	var snapshot := Codec.capture(state)
	if state.save_count >= Codec.MAX_INTEGER: return fail("存档次数超出可保存范围。")
	snapshot.save_count = state.save_count + 1
	var prepared := Codec.prepare(snapshot)
	if not prepared.ok:
		return prepared
	var payload := JSON.stringify(snapshot, "", true)
	var envelope := {"format": FORMAT, "schema_version": SCHEMA, "runtime_version": Version.VERSION, "project_id": project_id(),
		"data_fingerprint": fingerprint(), "saved_at": Time.get_datetime_string_from_system(false, true), "payload": payload, "sha256": payload.sha256_text()}
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
			if DirAccess.copy_absolute(path, backup_temporary) != OK or DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK:
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
	state.state_changed.emit()
	return {"ok": true, "message": "已保存至存档 %d。" % slot, "path": ProjectSettings.globalize_path(path)}


static func read_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
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
	if envelope.get("format") != FORMAT or not Codec.integer(envelope.get("schema_version"), 1) or int(envelope.schema_version) != SCHEMA:
		return fail("不支持的存档格式/版本（不读取旧 RM 存档）。")
	if envelope.get("project_id") != project_id() or envelope.get("data_fingerprint") != fingerprint():
		return fail("存档不属于当前工程，或数据库/地图已发生变化。")
	if not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text() != envelope.sha256:
		return fail("存档完整性校验失败。")
	if not envelope.get("saved_at") is String or envelope.saved_at.length() > 64:
		return fail("保存时间无效。")
	if json.parse(envelope.payload) != OK:
		return fail("进度 JSON 损坏。")
	var prepared := Codec.prepare(json.data)
	if not prepared.ok:
		return prepared
	return {"ok": true, "prepared": prepared, "saved_at": envelope.saved_at, "path": path}


static func load_slot(slot: int, state: Node) -> Dictionary:
	var result := read_slot(slot)
	if result.ok:
		state.restore_prepared(result.prepared)
	return result


static func slot_info(slot: int) -> Dictionary:
	var result := read_slot(slot)
	if not result.ok:
		return {"ok": false, "exists": result.get("exists", false), "message": result.message}
	var names: Array[String] = []
	for id in result.prepared.state.party:
		names.append(result.prepared.actors[int(id)].actor_name)
	return {"ok": true, "exists": true, "saved_at": result.saved_at, "party": "、".join(names),
		"play_seconds": result.prepared.state.play_seconds, "map_id": result.prepared.state.map_id, "recovered": result.recovered}


static func has_valid_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if read_slot(slot).ok:
			return true
	return false


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

## 职责：提供闪翼独立文件数据的编码、读写与错误处理。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/10_Support/Persistence/FileStore.gd").方法名(...)。
##
## 调用接口：
##   static func write(path: String, kind: String, value: Variant) -> Dictionary
##     用途：写入指定文件或目标数据。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func read(path: String, kind: String, validator: Callable = Callable()) -> Dictionary
##     用途：读取指定文件或记录。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 validator（Callable；默认值 Callable()）：完整检查目标数据的回调。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 公开常量：MAX_BYTES。
## 接口说明结束。

extends RefCounted
## Project-scoped, checksummed data files with same-directory atomic replacement.
const Graph = preload("SaveGraph.gd")
const MAX_BYTES = 32 * 1024 * 1024


static func write(path: String, kind: String, value: Variant) -> Dictionary:
	var encoded = Graph.encode(value)
	if not encoded.ok:
		return encoded
	var payload = JSON.stringify(encoded.value)
	var content = JSON.stringify(
		{
			"format": "rgm-flash-data",
			"version": 1,
			"kind": kind,
			"project": str(ProjectSettings.get_setting("rgmigrator/project_id", "")),
			"payload": payload,
			"sha256": payload.sha256_text()
		}
	)
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return _fail("数据文件超过大小限制。")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return _fail("无法创建数据目录。")
	var temp = path + ".tmp-%d" % OS.get_process_id()
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return _fail("数据临时文件写入失败。")
	file.store_string(content)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or not _read(temp, kind).ok:
		return _fail("数据临时文件校验失败。")
	if FileAccess.file_exists(path) and _read(path, kind).ok:
		var backup = path + ".bak.tmp"
		if (
			DirAccess.copy_absolute(path, backup) != OK
			or DirAccess.rename_absolute(backup, path + ".bak") != OK
		):
			return _fail("数据备份失败；原件保持。")
	elif FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".damaged-%d" % Time.get_ticks_usec()) != OK:
			return _fail("无法保留损坏数据；原件保持。")
	if DirAccess.rename_absolute(temp, path) != OK:
		return _fail("数据替换失败；原件保持。")
	return {"ok": true, "path": path}


static func read(path: String, kind: String, validator: Callable = Callable()) -> Dictionary:
	var result = _read(path, kind)
	if result.ok and validator.is_valid():
		var reason: String = validator.call(result.value)
		if not reason.is_empty():
			result = _fail(reason)
	if result.ok:
		result.recovered = false
		return result
	var backup = _read(path + ".bak", kind)
	if backup.ok and validator.is_valid():
		var reason: String = validator.call(backup.value)
		if not reason.is_empty():
			backup = _fail(reason)
	if backup.ok:
		backup.recovered = true
		return backup
	return result


static func _read(path: String, kind: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _fail("数据文件缺失或超过大小限制。")
	var json = JSON.new()
	var content = file.get_as_text()
	file.close()
	if json.parse(content) != OK or not json.data is Dictionary:
		return _fail("数据JSON损坏。")
	var row: Dictionary = json.data
	if (
		row.get("format") != "rgm-flash-data"
		or row.get("version") != 1
		or row.get("kind") != kind
		or row.get("project") != str(ProjectSettings.get_setting("rgmigrator/project_id", ""))
	):
		return _fail("数据格式或所属工程不一致。")
	if not row.get("payload") is String or row.payload.sha256_text() != row.get("sha256"):
		return _fail("数据完整性校验失败。")
	if json.parse(row.payload) != OK:
		return _fail("数据对象图损坏。")
	return Graph.decode(json.data)


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

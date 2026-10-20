## 职责：校验文件冲突并统一发布编辑器多文件修改，保留可恢复备份。
##
## 调用方式：
##   静态接口：preload("res://addons/rgm_editor/01_Documents/Editor_ProjectTransaction.gd").方法名(...)。
##
## 调用接口：
##   static func allowed(path: String) -> bool
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func stamp(root: String, path: String) -> Dictionary
##     参数 root（String；必填）：数据根、节点根或工程根位置。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func publish(root: String, changes: Dictionary, expected: Dictionary) -> Dictionary
##     参数 root（String；必填）：数据根、节点根或工程根位置。
##     参数 changes（Dictionary；必填）：待应用的字段变化集合。
##     参数 expected（Dictionary；必填）：测试预期的结果值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

@tool
extends RefCounted


## Publish text artifacts together, with conflict checks and recoverable backups.
static func allowed(path: String) -> bool:
	return (
		not path.contains("..")
		and not path.contains("\\")
		and not path.contains(":")
		and (
			path.begins_with("data/")
			or path.begins_with("runtime/generated/") and path.ends_with(".gd")
			or path in ["script_inventory.md", "script_coverage.md"]
		)
	)


static func stamp(root: String, path: String) -> Dictionary:
	var full = root.path_join(path)
	return {
		"exists": FileAccess.file_exists(full),
		"sha256": FileAccess.get_sha256(full) if FileAccess.file_exists(full) else ""
	}


static func publish(root: String, changes: Dictionary, expected: Dictionary) -> Dictionary:
	for path in changes:
		if not allowed(path) or not changes[path] is String:
			return {"ok": false, "message": "转换产物路径或类型无效：" + path}
		if not expected.has(path) or stamp(root, path) != expected[path]:
			return {"ok": false, "message": "文件已被外部修改，未覆盖：" + path, "path": path}
	var transaction = str(Time.get_ticks_usec())
	var backup = root.path_join(".godot/rgm_editor/backups/scripts_" + transaction)
	var staged: Dictionary = {}
	for path in changes:
		var full = root.path_join(path)
		if expected[path].exists:
			var target = backup.path_join(path)
			if (
				DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK
				or DirAccess.copy_absolute(full, target) != OK
			):
				_cleanup(staged)
				return {"ok": false, "message": "无法创建转换备份：" + path}
		if DirAccess.make_dir_recursive_absolute(full.get_base_dir()) != OK:
			_cleanup(staged)
			return {"ok": false, "message": "无法建立转换目录。"}
		var pending = full + ".rgm_pending_" + transaction
		var file = FileAccess.open(pending, FileAccess.WRITE)
		if file == null:
			_cleanup(staged)
			return {"ok": false, "message": "无法写入转换暂存文件：" + path}
		file.store_string(changes[path])
		file.flush()
		var error = file.get_error()
		file.close()
		staged[path] = pending
		if error != OK:
			_cleanup(staged)
			return {"ok": false, "message": "转换暂存写入失败：" + path}
	# Check again after all compilation/staging, before touching any live artifact.
	for path in changes:
		if stamp(root, path) != expected[path]:
			_cleanup(staged)
			return {"ok": false, "message": "转换期间文件已改变，未覆盖：" + path, "path": path}
	var committed: Array = []
	for path in staged:
		var full = root.path_join(path)
		if expected[path].exists and DirAccess.remove_absolute(full) != OK:
			_rollback(root, committed, expected, backup)
			_cleanup(staged)
			return {"ok": false, "message": "无法替换转换产物：" + path}
		committed.append(path)
		if DirAccess.rename_absolute(staged[path], full) != OK:
			var recovered = _rollback(root, committed, expected, backup)
			_cleanup(staged)
			return {
				"ok": false,
				"message": "替换失败；" + ("已恢复原文件。" if recovered else "恢复未完成，请使用备份：" + backup),
				"backup": backup
			}
	return {"ok": true, "count": changes.size(), "backup": backup}


static func _cleanup(staged: Dictionary) -> void:
	for pending in staged.values():
		if FileAccess.file_exists(pending):
			DirAccess.remove_absolute(pending)


static func _rollback(root: String, paths: Array, expected: Dictionary, backup: String) -> bool:
	var ok = true
	for path in paths:
		var full = root.path_join(path)
		if FileAccess.file_exists(full) and DirAccess.remove_absolute(full) != OK:
			ok = false
			continue
		if expected[path].exists and DirAccess.copy_absolute(backup.path_join(path), full) != OK:
			ok = false
	return ok

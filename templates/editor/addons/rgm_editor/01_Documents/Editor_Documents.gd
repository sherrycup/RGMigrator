## 职责：管理编辑器数据草稿、修改历史和显式保存，隔离正式游戏运行状态。
##
## 调用方式：
##   var docs = preload("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(root_path)，所有编辑页面共享此文档服务。
##   read 读取草稿副本，apply/apply_batch 只修改文档历史，save_all 才向工程 data 写入。
##
## 调用接口：
##   func _init(root_path: String = "res://") -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 root_path（String；默认值 "res://"）：当前生成工程或独立测试工程的根目录。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func read(path: String) -> Variant
##     用途：读取当前文档的独立草稿副本。
##     参数 path（String；必填）：相对工程根的 data/... JSON 路径；服务会检查允许范围。
##     返回：Dictionary 或 Array 的副本；读取失败返回 null，并可读取 error_message()。
##
##   func apply(path: String, value: Variant, label: String = "编辑") -> Dictionary
##     用途：校验并记录单文档草稿变化。
##     参数 path（String；必填）：相对工程根的 data/... JSON 路径；服务会检查允许范围。
##     参数 value（Variant；必填）：当前文档的新完整草稿值。
##     参数 label（String；默认值 "编辑"）：显示在撤销历史中的本次编辑说明。
##     返回：含 ok 及操作信息的结果字典；不写入磁盘。
##
##   func apply_batch(changes: Dictionary, label: String = "批量编辑") -> Dictionary
##     用途：把多份文档变化作为一次编辑历史应用。
##     参数 changes（Dictionary；必填）：相对 data 路径到新完整草稿值的字典。
##     参数 label（String；默认值 "批量编辑"）：显示在撤销历史中的本次编辑说明。
##     返回：批量校验结果字典。
##
##   func undo() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func redo() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func group_recent(count: int) -> void
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func can_undo() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func can_redo() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func dirty_paths() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func error_message() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func reload() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func save_all() -> Dictionary
##     用途：保存已修改的允许文档并更新保存基线。
##     参数：无。
##     返回：保存结果字典，失败时保留说明及可恢复状态。
##
##   func records(name: String) -> Array
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func reference_label(category: String, id: int, empty: String = "") -> String
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 empty（String；默认值 ""）：是否允许或保留空值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func lookup(name: String) -> Array
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func assets(category: String) -> Array
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func asset_audio(category: String, name: String) -> AudioStream
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：AudioStream 类型的对象或值，供调用方继续使用。
##
##   func asset_texture(category: String, name: String) -> Texture2D
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：Texture2D 类型的对象或值，供调用方继续使用。
##
##   func new_page() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func validate(path: String, value: Variant, before: Variant) -> String
##     用途：检查目标草稿是否保持原记录约定。
##     参数 path（String；必填）：相对工程根的 data/... JSON 路径；服务会检查允许范围。
##     参数 value（Variant；必填）：待检查的新草稿。
##     参数 before（Variant；必填）：修改前的文档值，用于检查编号及扩展数据保留。
##     返回：空串为通过，非空串为失败原因。
##
## 对外信号：
##   changed()：当前模型或草稿已经变化，界面可据此刷新。
##
## 注意：编辑器文档不访问 RuntimeState，不在编辑时执行游戏事件。
## 接口说明结束。

@tool
extends RefCounted
## Drafts and history never touch RuntimeState. Only explicit Save writes data.
const Commands = preload("../03_Event/Editor_Commands.gd")
const DatabaseSchema = preload("../04_Database/Editor_DatabaseSchema.gd")
signal changed
var _root = "res://"
var _documents: Dictionary = {}
var _history: Array = []
var _cursor = 0
var _textures: Dictionary = {}
var _asset_index: Dictionary = {}
var _last_error = ""


func _init(root_path: String = "res://") -> void:
	_root = root_path.trim_suffix("/") + "/"


func read(path: String) -> Variant:
	if _documents.has(path):
		return _copy(_documents[path].value)
	if not _allowed(path):
		_last_error = "编辑路径不在data目录。"
		return null
	var full = _root + path
	if not FileAccess.file_exists(full):
		_last_error = "文件不存在：" + path
		return null
	var text = FileAccess.get_file_as_string(full)
	var parser = JSON.new()
	if parser.parse(text) != OK:
		_last_error = "%s：第%d行JSON错误。" % [path, parser.get_error_line()]
		return null
	if not parser.data is Dictionary and not parser.data is Array:
		_last_error = "数据根节点须为对象或数组：" + path
		return null
	var original: Variant = parser.data.duplicate(true)
	var upgrade_path = _root + "addons/rgm_editor/compiler/Editor_NativeEventImporter.gd"
	if (
		(path.begins_with("data/maps/") or path == "data/database/CommonEvents.json")
		and FileAccess.file_exists(upgrade_path)
	):
		var registry: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(_root + "data/script_units.json")
		)
		if registry is Dictionary:
			load(upgrade_path).upgrade(
				parser.data,
				_root,
				registry.get("units", {}),
				registry.get("interpreter_policy", {})
			)
	_documents[path] = {
		"value": parser.data, "saved": original, "hash": text.sha256_text(), "exists": true
	}
	return parser.data.duplicate(true)


func apply(path: String, value: Variant, label: String = "编辑") -> Dictionary:
	if not _allowed(path) or not value is Dictionary and not value is Array:
		return {"ok": false, "message": "无效编辑数据或路径。"}
	if not _documents.has(path):
		if FileAccess.file_exists(_root + path):
			if read(path) == null:
				return {"ok": false, "message": _last_error}
		else:
			_documents[path] = {"value": null, "saved": null, "hash": "", "exists": false}
	var before: Variant = _documents[path].value
	if before == value:
		return {"ok": true}
	_history.resize(_cursor)
	_history.append(
		{"path": path, "before": _copy(before), "after": value.duplicate(true), "label": label}
	)
	if _history.size() > 60:
		_history.pop_front()
	_cursor = _history.size()
	_documents[path].value = value.duplicate(true)
	changed.emit()
	return {"ok": true}


func apply_batch(changes: Dictionary, label: String = "批量编辑") -> Dictionary:
	var entries: Array = []
	for path in changes:
		if (
			not _allowed(str(path))
			or not changes[path] is Dictionary and not changes[path] is Array
		):
			return {"ok": false, "message": "无效编辑路径或数据。"}
		if not _documents.has(path):
			if FileAccess.file_exists(_root + str(path)):
				if read(path) == null:
					return {"ok": false, "message": _last_error}
			else:
				_documents[path] = {"value": null, "saved": null, "hash": "", "exists": false}
		var before: Variant = _documents[path].value
		if before != changes[path]:
			entries.append(
				{"path": path, "before": _copy(before), "after": changes[path].duplicate(true)}
			)
	for entry in entries:
		_documents[entry.path].value = entry.after
	for entry in entries:
		var reason = validate(entry.path, entry.after, entry.before)
		if not reason.is_empty():
			for previous in entries:
				_documents[previous.path].value = previous.before
			return {"ok": false, "message": entry.path + "：" + reason}
	if entries.is_empty():
		return {"ok": true}
	_history.resize(_cursor)
	_history.append({"entries": entries, "label": label})
	if _history.size() > 60:
		_history.pop_front()
	_cursor = _history.size()
	changed.emit()
	return {"ok": true}


func undo() -> bool:
	if _cursor == 0:
		return false
	_cursor -= 1
	var entry: Dictionary = _history[_cursor]
	for part in entry.get("entries", [entry]):
		_documents[part.path].value = _copy(part.before)
	changed.emit()
	return true


func redo() -> bool:
	if _cursor >= _history.size():
		return false
	var entry: Dictionary = _history[_cursor]
	_cursor += 1
	for part in entry.get("entries", [entry]):
		_documents[part.path].value = part.after.duplicate(true)
	changed.emit()
	return true


func group_recent(count: int) -> void:
	if count < 2 or count > _cursor:
		return
	var entries: Array = _history.slice(_cursor - count, _cursor)
	_history.resize(_cursor - count)
	_history.append({"entries": entries})
	_cursor = _history.size()


func can_undo() -> bool:
	return _cursor > 0


func can_redo() -> bool:
	return _cursor < _history.size()


func dirty_paths() -> Array:
	var result: Array = []
	for path in _documents:
		if _documents[path].value != _documents[path].saved:
			result.append(path)
	return result


func error_message() -> String:
	return _last_error


func reload() -> void:
	_documents.clear()
	_history.clear()
	_cursor = 0
	_last_error = ""
	_asset_index.clear()
	_textures.clear()
	changed.emit()


func save_all() -> Dictionary:
	var paths = dirty_paths()
	if paths.is_empty():
		return {"ok": true, "count": 0}
	# Preflight the entire batch before any original is touched.
	for path in paths:
		var doc: Dictionary = _documents[path]
		var full = _root + str(path)
		if (
			FileAccess.file_exists(full) != bool(doc.exists)
			or (doc.exists and FileAccess.get_file_as_string(full).sha256_text() != doc.hash)
		):
			return {"ok": false, "message": "文件已被外部修改，请先备份草稿并重新载入：" + path}
		var reason = validate(path, doc.value, doc.saved)
		if not reason.is_empty():
			return {"ok": false, "message": path + "：" + reason}
		var native = preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").validate_tree(
			doc.value, path
		)
		if not native.ok:
			var details = JSON.stringify(native.get("diagnostics", []))
			return {
				"ok": false,
				"message":
				str(native.get("location", path)) + "：" + native.message + "\n" + details,
				"diagnostics": native.get("diagnostics", [])
			}
	var transaction = str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec())
	var backup_root = _root + ".godot/rgm_editor/backups/" + transaction + "/"
	var staged: Array = []
	for path in paths:
		var full = _root + str(path)
		if _documents[path].exists:
			var backup = backup_root + str(path)
			DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
			if DirAccess.copy_absolute(full, backup) != OK:
				_cleanup(staged)
				return {"ok": false, "message": "无法创建编辑备份。"}
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		var temp = full + ".rgm_pending_" + transaction
		var file = FileAccess.open(temp, FileAccess.WRITE)
		if file == null:
			_cleanup(staged)
			return {"ok": false, "message": "无法写入暂存文件：" + str(path)}
		file.store_string(JSON.stringify(_documents[path].value, "\t", false) + "\n")
		file.flush()
		var status = file.get_error()
		file.close()
		staged.append({"path": path, "temp": temp})
		if status != OK:
			_cleanup(staged)
			return {"ok": false, "message": "写入编辑数据失败。"}
	var committed: Array = []
	for entry in staged:
		var path: String = entry.path
		var full = _root + path
		if FileAccess.file_exists(full) and DirAccess.remove_absolute(full) != OK:
			_rollback(committed, backup_root)
			_cleanup(staged)
			return {"ok": false, "message": "无法替换文件：" + path}
		committed.append(path)
		if DirAccess.rename_absolute(entry.temp, full) != OK:
			_rollback(committed, backup_root)
			_cleanup(staged)
			return {"ok": false, "message": "替换失败，已恢复原文件：" + path}
	for path in paths:
		_documents[path].saved = _documents[path].value.duplicate(true)
		_documents[path].hash = FileAccess.get_file_as_string(_root + str(path)).sha256_text()
		_documents[path].exists = true
	changed.emit()
	return {"ok": true, "count": paths.size(), "backup": backup_root}


func records(name: String) -> Array:
	var value: Variant = read("data/database/%s.json" % name)
	return value if value is Array else []


func reference_label(category: String, id: int, empty: String = "") -> String:
	if id == 0 and not empty.is_empty():
		return "[0000] %s" % empty
	var path = (
		"data/map_infos.json"
		if category == "Maps"
		else (
			"data/system.json"
			if category in ["switches", "variables", "elements"]
			else "data/database/%s.json" % category
		)
	)
	if not _documents.has(path):
		read(path)
	var values: Variant = _documents.get(path, {}).get("value")
	if category in ["switches", "variables", "elements"]:
		values = values.get(category, []) if values is Dictionary else []
	var entry: Variant = null
	if category == "Maps" and values is Dictionary:
		entry = values.get(str(id))
	elif values is Array and id > 0 and id < values.size():
		entry = values[id]
	if entry == null:
		return "[%04d] 缺失引用" % id
	var title = str(entry.get("name", "")) if entry is Dictionary else str(entry)
	return "[%04d] %s" % [id, title if not title.strip_edges().is_empty() else "未命名"]


func lookup(name: String) -> Array:
	var result: Array = []
	if name == "Maps":
		var infos: Variant = read("data/map_infos.json")
		if infos is Dictionary:
			for key in infos:
				result.append({"id": int(key), "name": reference_label(name, int(key))})
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		return result
	var values: Variant = (
		read("data/system.json") if name in ["switches", "variables", "elements"] else records(name)
	)
	if name in ["switches", "variables", "elements"]:
		values = values.get(name, []) if values is Dictionary else []
	if values is Array:
		for i in range(1, values.size()):
			if values[i] != null:
				result.append({"id": i, "name": reference_label(name, i)})
	return result


func assets(category: String) -> Array:
	if _asset_index.is_empty():
		var loaded: Variant = read("data/asset_index.json")
		if loaded is Dictionary:
			_asset_index = loaded
	var index: Variant = _asset_index
	var by_path: Dictionary = {}
	if not index is Dictionary:
		return []
	var prefix := (
		("Audio/" if category in ["BGM", "BGS", "ME", "SE"] else "Graphics/") + category + "/"
	)
	for key in index:
		if not str(key).to_lower().begins_with(prefix.to_lower()):
			continue
		var name := str(key).substr(prefix.length())
		if (
			name.get_extension().to_lower()
			not in ["png", "jpg", "jpeg", "bmp", "webp", "wav", "ogg", "mp3", "mid", "midi"]
		):
			continue
		var path := str(index[key])
		if not by_path.has(path) or name.length() > str(by_path[path]).length():
			by_path[path] = name
	var result := by_path.values()
	result.sort()
	return result


func asset_audio(category: String, name: String) -> AudioStream:
	if category not in ["BGM", "BGS", "ME", "SE"] or name.is_empty():
		return null
	if _asset_index.is_empty():
		var loaded: Variant = read("data/asset_index.json")
		if loaded is Dictionary:
			_asset_index = loaded
	var key = "Audio/%s/%s" % [category, name]
	var path = str(_asset_index.get(key, ""))
	if path.is_empty():
		for entry in _asset_index:
			if (
				str(entry).to_lower() == key.to_lower()
				or str(entry).get_basename().to_lower() == key.to_lower()
			):
				path = str(_asset_index[entry])
				break
	if path.is_empty() or not path.begins_with("res://assets/") or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func asset_texture(category: String, name: String) -> Texture2D:
	if name.is_empty():
		return null
	var texture_key := category + "/" + name
	if _textures.has(texture_key):
		return _textures[texture_key]
	# Already loaded images remain usable during scans. Only new resource loads wait.
	if Engine.is_editor_hint() and EditorInterface.get_resource_filesystem().is_scanning():
		return null
	if _asset_index.is_empty():
		var loaded: Variant = read("data/asset_index.json")
		if loaded is Dictionary:
			_asset_index = loaded
	var index: Variant = _asset_index
	if not index is Dictionary:
		return null
	var key = "Graphics/" + category + "/" + name
	var path = str(index.get(key, ""))
	if path.is_empty():
		for k in index:
			if (
				str(k).to_lower() == key.to_lower()
				or str(k).get_basename().to_lower() == key.to_lower()
			):
				path = str(index[k])
				break
	if path.is_empty() or not path.begins_with("res://assets/"):
		return null
	if Engine.is_editor_hint() and not FileAccess.file_exists(path + ".import"):
		return null
	_textures[texture_key] = load(path) as Texture2D
	return _textures[texture_key]


func new_page() -> Dictionary:
	return {
		"_class": "RPG::Event::Page",
		"condition":
		{
			"_class": "RPG::Event::Page::Condition",
			"switch1_valid": false,
			"switch2_valid": false,
			"variable_valid": false,
			"self_switch_valid": false,
			"switch1_id": 1,
			"switch2_id": 1,
			"variable_id": 1,
			"variable_value": 0,
			"self_switch_ch": "A"
		},
		"graphic":
		{
			"_class": "RPG::Event::Page::Graphic",
			"tile_id": 0,
			"character_name": "",
			"character_hue": 0,
			"direction": 2,
			"pattern": 0,
			"opacity": 255,
			"blend_type": 0
		},
		"move_type": 0,
		"move_speed": 4,
		"move_frequency": 3,
		"move_route":
		{
			"_class": "RPG::MoveRoute",
			"repeat": true,
			"skippable": false,
			"list": [Commands.route_command(0)]
		},
		"walk_anime": true,
		"step_anime": false,
		"direction_fix": false,
		"through": false,
		"always_on_top": false,
		"trigger": 0,
		"list": [Commands.command(0)]
	}


func validate(path: String, value: Variant, before: Variant) -> String:
	if value == null:
		return "不能保存已撤销的新文件。"
	if path == "data/system.json":
		if not value is Dictionary:
			return "系统数据须为对象。"
		return DatabaseSchema.reason("System", value, before if before is Dictionary else {}, self)
	if path == "data/custom_data.json":
		if not value is Dictionary:
			return "项目自定义数据须为对象。"
		return DatabaseSchema.reason(
			"CustomData", value, before if before is Dictionary else {}, self
		)
	if path.begins_with("data/database/"):
		if not value is Array:
			return "数据库须为数组。"
		if value.is_empty() or value[0] != null:
			return "数据库编号0须保留空槽位。"
		var category = path.get_file().trim_suffix(".json")
		for i in range(1, value.size()):
			if value[i] == null:
				continue
			if (
				not value[i] is Dictionary
				or not DatabaseSchema._integer(value[i].get("id"))
				or int(value[i].id) != i
			):
				return "数据库ID须与数组槽位一致：%d" % i
			var old: Dictionary = (
				before[i]
				if before is Array and i < before.size() and before[i] is Dictionary
				else {}
			)
			if value[i] != old:
				var reason = DatabaseSchema.reason(category, value[i], old, self)
				if not reason.is_empty():
					return "条目%d：%s" % [i, reason]
	if path.begins_with("data/maps/"):
		if not value is Dictionary or not value.get("events", {}) is Dictionary:
			return "地图格式无效。"
		var width = int(value.get("width", 0))
		var height = int(value.get("height", 0))
		var table: Dictionary = value.get("data", {})
		if (
			not DatabaseSchema._integer(table.get("z_size"))
			or int(table.z_size) not in range(1, 33)
		):
			return "地图图块层数须为1…32的整数。"
		if (
			width < 1
			or height < 1
			or table.get("values", []).size() != width * height * int(table.get("z_size", 0))
		):
			return "地图尺寸与图块数量不一致。"
		if value.has("layer_names"):
			if not value.layer_names is Array or value.layer_names.size() != int(table.z_size):
				return "图层名称数量须与图块层数一致。"
			for name in value.layer_names:
				if not name is String or str(name).strip_edges().is_empty():
					return "图层名称须为非空文字。"
		for key in value.events:
			var event: Dictionary = value.events[key]
			if (
				int(key) != int(event.get("id", 0))
				or int(key) <= 0
				or int(event.get("x", -1)) not in range(width)
				or int(event.get("y", -1)) not in range(height)
			):
				return "事件ID或坐标无效：" + str(key)
			if not event.get("pages", []) is Array or event.pages.is_empty():
				return "事件至少需要一页。"
			var old_pages: Array = (
				before.get("events", {}).get(key, {}).get("pages", [])
				if before is Dictionary
				else []
			)
			for i in event.pages.size():
				var old: Dictionary = old_pages[i] if i < old_pages.size() else {}
				var reason = _page_reason(event.pages[i], old)
				if not reason.is_empty():
					return "事件%s第%d页：%s" % [key, i + 1, reason]
	return ""


func _page_reason(page: Dictionary, before: Dictionary) -> String:
	if int(page.get("trigger", -1)) not in range(5):
		return "触发方式无效。"
	if page.get("list", []) != before.get("list", []):
		var reason = Commands.validate_structure(page.get("list", []))
		if not reason.is_empty():
			return reason
	if page.get("move_route", {}) != before.get("move_route", {}):
		var validation = Commands.Catalog.route_validation(page.get("move_route", {}))
		if not validation.ok:
			return str(validation.message)
	return ""


func _allowed(path: String) -> bool:
	return (
		path.begins_with("data/")
		and path.ends_with(".json")
		and not path.contains("..")
		and not path.contains("\\")
		and not path.contains(":")
	)


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _cleanup(staged: Array) -> void:
	for entry in staged:
		if FileAccess.file_exists(entry.temp):
			DirAccess.remove_absolute(entry.temp)


func _rollback(paths: Array, backup_root: String) -> void:
	for path in paths:
		var full = _root + str(path)
		if FileAccess.file_exists(full):
			DirAccess.remove_absolute(full)
		if _documents[path].exists:
			DirAccess.copy_absolute(backup_root + str(path), full)

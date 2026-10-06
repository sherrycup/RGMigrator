class_name RuntimeData
extends RefCounted

static var _cache: Dictionary = {}
static var _test_records: Dictionary = {}
static var testing_enabled := false


static func read_json(path: String, fallback: Variant = {}) -> Variant:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		return fallback
	_cache[path] = parsed
	return parsed


static func manifest() -> Dictionary:
	return read_json("res://data/manifest.json", {})


static func system() -> Dictionary:
	return read_json("res://data/system.json", {})


static func map(map_id: int) -> Dictionary:
	return read_json("res://data/maps/Map%03d.json" % map_id, {})


static func database(name: String) -> Variant:
	return read_json("res://data/database/%s.json" % name, [])


static func record(name: String, id: int) -> Dictionary:
	var key := "%s:%d" % [name, id]
	if testing_enabled and _test_records.has(key):
		return _test_records[key]
	return source_record(name, id)


static func source_record(name: String, id: int) -> Dictionary:
	var entries: Variant = database(name)
	if entries is Array and id > 0 and id < entries.size() and entries[id] is Dictionary:
		return entries[id]
	return {}


static func test_config() -> Dictionary:
	var path := "res://data/test_setup.json"
	if not FileAccess.file_exists(path):
		return {"enabled": false}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {"enabled": false, "error": "data/test_setup.json 不是有效 JSON 对象；未准备测试物资。"}
	return parser.data


static func configure_testing(override: Dictionary = {}) -> Dictionary:
	_test_records.clear()
	testing_enabled = false
	var setup := test_config() if override.is_empty() else override.duplicate(true)
	var errors: Array[String] = []
	if setup.has("error"):
		errors.append(str(setup.error))
	if not setup.get("enabled", false) is bool:
		errors.append("测试配置 enabled 必须为 true 或 false。")
	if not errors.is_empty() or not bool(setup.get("enabled", false)):
		return {"enabled": false, "errors": errors}
	if not setup.get("definitions", {}) is Dictionary or not setup.get("stock", []) is Array:
		return {"enabled": false, "errors": ["测试配置 definitions/stock 类型错误。"]}
	for database in setup.get("definitions", {}):
		if database not in ["Items", "Weapons", "Armors", "Skills", "Animations", "States"] or not setup.definitions[database] is Array:
			errors.append("测试配置只允许 Items、Weapons、Armors、Skills、Animations、States 定义数组。")
			continue
		for definition in setup.definitions[database]:
			if not definition is Dictionary or not definition.get("id", 0) is float and not definition.get("id", 0) is int:
				errors.append("测试物资定义必须包含数值 id。")
				continue
			var id := int(definition.get("id", 0))
			var key := "%s:%d" % [database, id]
			if id <= 0 or not source_record(database, id).is_empty() or _test_records.has(key):
				errors.append("测试物资 ID 无效或冲突：%s；未覆盖原数据。" % key)
				continue
			_test_records[key] = definition.duplicate(true)
	if not errors.is_empty():
		_test_records.clear()
		return {"enabled": false, "errors": errors}
	testing_enabled = true
	setup["errors"] = errors
	return setup


static func is_test_record(database: String, id: int) -> bool:
	return testing_enabled and _test_records.has("%s:%d" % [database, id])


static func testing_snapshot() -> Dictionary:
	var definitions := {}
	for key in _test_records:
		var database: String = key.get_slice(":", 0)
		if not definitions.has(database):
			definitions[database] = []
		definitions[database].append(_test_records[key].duplicate(true))
	return {"enabled": testing_enabled, "definitions": definitions}


static func install_testing(enabled: bool, records: Dictionary) -> void:
	testing_enabled = enabled
	_test_records = records.duplicate(true)


static func asset_index() -> Dictionary:
	return read_json("res://data/asset_index.json", {})


static func asset_path(rmxp_path: String) -> String:
	var index := asset_index()
	var normalized := rmxp_path.replace("\\", "/")
	if index.has(normalized):
		return str(index[normalized])
	var without_extension := normalized.get_basename()
	if index.has(without_extension):
		return str(index[without_extension])
	var lower := without_extension.to_lower()
	return str(index.get(lower, ""))


static func field(value: Variant, key: String, fallback: Variant = null) -> Variant:
	if value is Dictionary:
		return value.get(key, fallback)
	return fallback

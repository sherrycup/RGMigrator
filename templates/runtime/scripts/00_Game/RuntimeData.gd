## 职责：读取生成工程的数据与素材索引，提供只读原记录及运行时数据查询。
##
## 调用方式：
##   通过 preload("res://runtime/scripts/00_Game/RuntimeData.gd").system()、map(id)、record(name, id) 读取定义。
##
## 调用接口：
##   static func bind_custom_data(value: RefCounted) -> void
##     参数 value（RefCounted；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func read_json(path: String, fallback: Variant = {}) -> Variant
##     用途：读取并缓存 JSON 资源。
##     参数 path（String；必填）：工程内 JSON 资源路径。
##     参数 fallback（Variant；默认值 {}）：读取或解析失败时返回的值。
##     返回：解析值；文件缺失或不合法时返回 fallback。
##
##   static func manifest() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func system() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func map(map_id: int) -> Dictionary
##     参数 map_id（int；必填）：地图的原编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func database(name: String) -> Variant
##     参数 name（String；必填）：原数据库分类名称，如 Actors、Items、Skills。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func record(name: String, id: int) -> Dictionary
##     用途：按分类与原编号取得当前有效记录。
##     参数 name（String；必填）：原数据库分类名称，如 Actors、Items、Skills。
##     参数 id（int；必填）：该分类下的原记录编号。
##     返回：只读记录视图；缺失时返回空字典。
##
##   static func source_record(name: String, id: int) -> Dictionary
##     参数 name（String；必填）：原数据库分类名称，如 Actors、Items、Skills。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func test_config() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func configure_testing(override: Dictionary = {}) -> Dictionary
##     参数 override（Dictionary；默认值 {}）：本次调用使用的覆盖值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func is_test_record(database: String, id: int) -> bool
##     参数 database（String；必填）：数据库分类或当前数据库定义。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func testing_snapshot() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func install_testing(enabled: bool, records: Dictionary) -> void
##     参数 enabled（bool；必填）：是否启用对应功能。
##     参数 records（Dictionary；必填）：待处理的记录集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func asset_index() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func asset_path(rmxp_path: String) -> String
##     参数 rmxp_path（String；必填）：RM 素材或工程内的原始路径。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func field(value: Variant, key: String, fallback: Variant = null) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 fallback（Variant；默认值 null）：变量缺失或调用已取消时的默认值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 注意：source_record 读取原定义；record 可包含当前自定义覆盖。调用方按只读数据使用。
## 接口说明结束。

class_name RuntimeData
extends RefCounted

static var _cache: Dictionary = {}
static var _test_records: Dictionary = {}
static var testing_enabled := false
static var _custom_state: WeakRef


static func bind_custom_data(value: RefCounted) -> void:
	_custom_state = weakref(value)


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
	var entries: Variant = read_json("res://data/database/%s.json" % name, [])
	var registry: RefCounted = _flash_skill_registry() if name == "Skills" else null
	if registry == null or not entries is Array:
		return entries
	# A live Skills view must never mutate the original cached database array.
	# source_record reads that raw array directly, so this does not recurse.
	var result: Array = entries.duplicate(true)
	for id in result.size():
		if result[id] is Dictionary:
			result[id] = record("Skills", id).duplicate(true)
	for key in registry.definitions:
		if not str(key).is_valid_int() or int(key) < 0:
			continue
		var id = int(key)
		if result.size() <= id:
			result.resize(id + 1)
		result[id] = record("Skills", id).duplicate(true)
	return result


static func record(name: String, id: int) -> Dictionary:
	var key := "%s:%d" % [name, id]
	if testing_enabled and _test_records.has(key):
		return _test_records[key]
	var source = source_record(name, id)
	var custom: RefCounted = _custom_state.get_ref() if _custom_state != null else null
	var result: Dictionary = source
	if custom != null and custom.values.records.has(key):
		result = source.duplicate(true).merged(custom.values.records[key], true)
		if custom.values.records[key].has("name") and result.has("_custom_data"):
			result._custom_data.tags = preload("CustomDataTags.gd").parse(str(result.name))
	if name == "Skills":
		var registry: RefCounted = _flash_skill_registry()
		if registry != null and registry.includes(id):
			if result.is_empty():
				result = {
					"_class": "RPG::Skill",
					"occasion": 1,
					"common_event_id": 0,
					"hit": 100,
					"variance": 15,
					"menu_se": {"name": "", "volume": 80, "pitch": 100}
				}
			result = result.duplicate(true).merged(registry.database_fields(id), true)
	return result


static func source_record(name: String, id: int) -> Dictionary:
	# Source definitions remain raw even when Skills has a live registry view.
	var entries: Variant = read_json("res://data/database/%s.json" % name, [])
	if (
		entries is Array
		and (id > 0 or id == 0 and name == "Skills")
		and id < entries.size()
		and entries[id] is Dictionary
	):
		return entries[id]
	return {}


static func _flash_skill_registry() -> RefCounted:
	var custom: RefCounted = _custom_state.get_ref() if _custom_state != null else null
	if custom == null or custom.manifest.get("profile") != "flash":
		return null
	var registry = preload("../01_Battle/BattleRegistry.gd").new()
	# Skills can be read by initialization scripts before the first prediction.
	# Install the actual generated GDScript catalog once on that cold path too.
	if not registry.is_configured() and FileAccess.file_exists("res://data/flash_gameplay.json"):
		var rules: Dictionary = read_json("res://data/flash_gameplay.json", {})
		var installed: Dictionary = preload("../01_Battle/BattleCatalog.gd").install_catalog(
			registry, rules.get("skills", {})
		)
		if not installed.ok:
			push_error(installed.message)
			return null
	return registry


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
		if (
			database not in ["Items", "Weapons", "Armors", "Skills", "Animations", "States"]
			or not setup.definitions[database] is Array
		):
			errors.append("测试配置只允许 Items、Weapons、Armors、Skills、Animations、States 定义数组。")
			continue
		for definition in setup.definitions[database]:
			if (
				not definition is Dictionary
				or not definition.get("id", 0) is float and not definition.get("id", 0) is int
			):
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

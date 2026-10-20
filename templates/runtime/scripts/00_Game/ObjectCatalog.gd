## 职责：组织闪翼物品、装备和敌人等对象定义，保留原数据编号及对象身份。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/ObjectCatalog.gd").方法名(...)。
##
## 调用接口：
##   static func construct(custom: RefCounted, type_name: String, args: Array) -> Variant
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 type_name（String；必填）：原脚本类名或数据类型名。
##     参数 args（Array；必填）：按调用顺序排列的参数值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func object_ref(custom: RefCounted, database: String, id: int) -> Variant
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 database（String；必填）：数据库分类或当前数据库定义。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func class_name_for(database: String) -> String
##     参数 database（String；必填）：数据库分类或当前数据库定义。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func is_a(database: String, type_name: String) -> bool
##     参数 database（String；必填）：数据库分类或当前数据库定义。
##     参数 type_name（String；必填）：原脚本类名或数据类型名。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func equipment_ref(custom: RefCounted, kind: Variant, id: Variant) -> Variant
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 kind（Variant；必填）：消息、操作或对象的种类标识。
##     参数 id（Variant；必填）：本接口所处理对象的编号。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func value( custom: RefCounted, database: String, id: int, field: String, fields: Dictionary = {} ) -> Variant
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 database（String；必填）：数据库分类或当前数据库定义。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 field（String；必填）：需要读取、修改或校验的字段名。
##     参数 fields（Dictionary；默认值 {}）：字段名称或字段值集合。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func validate_saved(value: Variant) -> String
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 公开常量：DATABASES、CLASSES。
## 接口说明结束。

extends RefCounted
## Source 0053-0057 object getters and 0086 finite equipment type selection.
const DATABASES = ["Weapons", "Deputies", "Armors", "Ornaments"]
const CLASSES = {
	"Game_Item": "Items",
	"Game_Weapon": "Weapons",
	"Game_Deputy": "Deputies",
	"Game_Armor": "Armors",
	"Game_Ornament": "Ornaments"
}


static func construct(custom: RefCounted, type_name: String, args: Array) -> Variant:
	if type_name == "Game_Object":
		if (
			args.size() != 4
			or not args[0] is String
			or not custom._integer(args[1])
			or args[1] < 0
			or not args[2] is String
			or not args[3] is String
		):
			return custom.reject("Game_Object需要key/id/filename/path四项参数。")
		var path = (args[3] + args[2]).replace("\\", "/").trim_prefix("./")
		if path.contains("..") or path.contains(":") or path.begins_with("/"):
			return custom.reject("对象数据文件必须属于目标工程资源。")
		var source: Dictionary = {}
		for entry in custom.manifest.get("sources", []):
			if entry.path == path:
				source = entry
				break
		var fields = {"id": int(args[1]), "name": "", "price": 0, "setting": {}}
		if not source.is_empty():
			var databases = {
				"item": "Items", "weapon": "Weapons", "armor": "Armors", "ornament": "Ornaments"
			}
			if not databases.has(args[0]):
				return custom.reject("对象数据标签尚未提取，请重新迁移该数据文件。")
			var record = custom.record(databases[args[0]], int(args[1]))
			var external: Dictionary = record.get("_custom_data", {}).get("external", {})
			if (
				not external.is_empty()
				and (external.get("file") != path or external.get("key") != args[0])
			):
				return custom.reject("对象文件/标签与已迁移数据不一致。")
			var settings: Dictionary = external.get("settings", {}).duplicate(true)
			fields.name = settings.get("name")
			fields.price = settings.get("price")
			settings.erase("name")
			settings.erase("price")
			settings.erase("description")
			fields.setting = settings
		return {"__custom_ref": "generic_project_object", "fields": fields}
	if not CLASSES.has(type_name):
		return custom.reject("项目物品构造器尚未迁移：" + type_name)
	if args.size() != 1 or not custom._integer(args[0]) or args[0] < 0:
		return custom.reject("项目物品构造器需要一个非负整数编号。")
	var ref: Variant = object_ref(custom, CLASSES[type_name], int(args[0]))
	if ref != null:
		ref.fields = _fields(custom, ref.database, ref.id)
	return ref


static func object_ref(custom: RefCounted, database: String, id: int) -> Variant:
	if database not in CLASSES.values() or id < 0:
		return custom.reject("项目物品类别/编号无效。")
	if database == "Deputies":
		return custom.reject("原闪翼缺少Game_Deputy定义及Deputy.exdata，副手对象无法实例化。")
	# Source wrappers still exist when RPG data is absent; their getters rescue
	# to defaults. In particular Game_Equipment creates the ID-zero object.
	var ref = custom.data_ref("project_object", id, database)
	ref.fields = _fields(custom, database, id)
	return ref


static func class_name_for(database: String) -> String:
	for type_name in CLASSES:
		if CLASSES[type_name] == database:
			return type_name
	return ""


static func is_a(database: String, type_name: String) -> bool:
	return (
		not class_name_for(database).is_empty()
		and type_name in [class_name_for(database), "Game_Object", "Object"]
	)


static func equipment_ref(custom: RefCounted, kind: Variant, id: Variant) -> Variant:
	if not custom._integer(kind) or not custom._integer(id) or kind < 0 or kind > 3 or id < 0:
		return custom.reject("装备类别/编号无效。")
	if id > 999:
		return null
	var key = DATABASES[int(kind)] + ":" + str(int(id))
	var cache: Dictionary = custom.values.objects.equipment
	if not cache.has(key):
		var ref: Variant = object_ref(custom, DATABASES[int(kind)], int(id))
		if ref == null:
			return null
		cache[key] = ref
	return cache[key]


static func value(
	custom: RefCounted, database: String, id: int, field: String, fields: Dictionary = {}
) -> Variant:
	var record: Dictionary = custom.record(database, id)
	if database not in CLASSES.values() or database == "Deputies" or id < 0:
		return custom.reject("项目物品类别/编号无效。")
	if fields.is_empty():
		fields = (
			custom
			. values
			. get("objects", {})
			. get("equipment", {})
			. get(database + ":" + str(id), {})
			. get("fields", {})
		)
	var settings: Dictionary = fields.get(
		"setting", record.get("_custom_data", {}).get("external", {}).get("settings", {})
	)
	var setting_key = (
		"hp"
		if field == "hp_plus"
		else (
			"agi"
			if field == "agi_plus"
			else "int" if field == "int_plus" else "resist_table" if field == "resist" else field
		)
	)
	if field == "id":
		return id
	if field == "setting":
		var copied = settings if not fields.is_empty() else settings.duplicate(true)
		if fields.is_empty():
			for key in ["name", "price", "description", "class_set"]:
				copied.erase(key)
		return copied
	if field == "class_set":
		if fields.has("class_set"):
			return _setting(custom, fields.class_set, false)
		if settings.has("class_set"):
			return _setting(custom, settings.class_set)
		var classes: Array = []
		if database in ["Weapons", "Armors"]:
			for definition in preload("RuntimeData.gd").database("Classes"):
				if (
					definition is Dictionary
					and (
						definition
						. get("weapon_set" if database == "Weapons" else "armor_set", [])
						. has(id)
					)
				):
					classes.append(int(definition.id))
		return classes
	if field in ["name", "type"]:
		var name = str(fields.get("name", settings.get("name", "")))
		if database == "Items":
			var expression = RegEx.new()
			expression.compile("<(.+)>")
			var matched = expression.search(name)
			if field == "type":
				return matched.get_string(1) if matched != null else ""
			name = name.get_slice("<", 0)
		return name
	if field == "price":
		return fields.get("price", settings.get("price", 0))
	if field == "description":
		if fields.has("description"):
			return fields.description
		var lines: Array = []
		if settings.has("description"):
			lines.assign(str(settings.description).split("\n"))
			# Ruby String#split with no explicit limit omits trailing empty rows.
			while not lines.is_empty() and lines[-1] == "":
				lines.pop_back()
		return lines
	if (
		settings.has(setting_key)
		and settings[setting_key] != null
		and (not settings[setting_key] is bool or settings[setting_key])
	):
		return _setting(custom, settings[setting_key], fields.is_empty())
	if field == "resist":
		return [0, 0, 0, 0, 0]
	if field in ["hp", "hp_plus"]:
		return 0
	if database == "Ornaments":
		if field == "icon_name":
			return ""
		if field in ["patk", "matk", "pdef", "mdef", "agi", "agi_plus", "int", "int_plus"]:
			return 0
	if database == "Weapons" and field in ["patk", "matk"]:
		return record.get("atk" if field == "patk" else "pdef", 0)
	if field in ["agi", "agi_plus", "int", "int_plus"]:
		return record.get("agi_plus" if field.begins_with("agi") else "int_plus", 0)
	if (
		field
		in [
			"icon_name",
			"occasion",
			"scope",
			"animation1_id",
			"animation2_id",
			"common_event_id",
			"consumable",
			"kind",
			"pdef",
			"mdef"
		]
	):
		return record.get(
			field,
			(
				3
				if field == "occasion"
				else false if field == "consumable" else "" if field in ["icon_name", "kind"] else 0
			)
		)
	return custom.reject("项目物品接口尚未迁移：" + field)


static func _fields(custom: RefCounted, database: String, id: int) -> Dictionary:
	var settings: Dictionary = preload("../10_Support/Persistence/SaveGraph.gd").clone(
		custom.record(database, id).get("_custom_data", {}).get("external", {}).get("settings", {})
	)
	var description: Array = []
	if settings.has("description"):
		description.assign(str(settings.description).split("\n"))
		while not description.is_empty() and description[-1] == "":
			description.pop_back()
	var fields = {
		"name": str(settings.get("name", "")),
		"price": settings.get("price", 0),
		"description": description,
		"setting": settings
	}
	for key in ["name", "price", "description"]:
		settings.erase(key)
	if database in ["Weapons", "Armors", "Ornaments"]:
		if settings.has("class_set"):
			fields.class_set = settings.class_set
			settings.erase("class_set")
		else:
			fields.class_set = []
			if database in ["Weapons", "Armors"]:
				for definition in preload("RuntimeData.gd").database("Classes"):
					if (
						definition is Dictionary
						and (
							definition
							. get("weapon_set" if database == "Weapons" else "armor_set", [])
							. has(id)
						)
					):
						fields.class_set.append(int(definition.id))
	return fields


static func validate_saved(value: Variant) -> String:
	if (
		not value is Dictionary
		or value.keys() != ["equipment"]
		or not value.get("equipment") is Dictionary
		or value.equipment.size() > 4000
	):
		return "装备对象缓存无效。"
	for key in value.equipment:
		var ref: Variant = value.equipment[key]
		if (
			not key is String
			or not ref is Dictionary
			or ref.get("__custom_ref") != "project_object"
			or ref.get("database") not in DATABASES
			or not ref.get("id") is int
			or ref.id < 0
			or ref.id > 999
			or key != ref.database + ":" + str(ref.id)
			or not ref.get("fields") is Dictionary
			or not ref.fields.get("setting") is Dictionary
			or not ref.fields.get("name") is String
			or not ref.fields.get("description") is Array
		):
			return "装备对象身份或字段无效。"
	return ""


static func _setting(custom: RefCounted, value: Variant, clone_plain: bool = true) -> Variant:
	if value is Dictionary and value.has("_generated_data_expression"):
		var result: Dictionary = custom._owner.get_ref().evaluate_custom_expression(
			value._generated_data_expression
		)
		return result.value if result.ok else custom.reject(result.message)
	return (
		value.duplicate(true) if clone_plain and (value is Array or value is Dictionary) else value
	)

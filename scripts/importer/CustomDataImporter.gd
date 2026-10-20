## 职责：静态提取原 RM 脚本中的自定义数据、初始值与适配信息，并记录无法静态求值的来源。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/CustomDataImporter.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func generate( source_root: String, output_root: String, scripts: Array, maps: Dictionary, codec: RefCounted, common: Dictionary = {} ) -> Dictionary
##     用途：从已校验输入生成目标数据或工程文件。
##     参数 source_root（String；必填）：只读 RM 源工程的根目录。
##     参数 output_root（String；必填）：生成工程的输出根目录。
##     参数 scripts（Array；必填）：原脚本来源或脚本记录集合。
##     参数 maps（Dictionary；必填）：地图编号到地图数据的集合。
##     参数 codec（RefCounted；必填）：当前使用的文本或数据编解码服务。
##     参数 common（Dictionary；默认值 {}）：公共事件记录集合。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted
## Source-driven custom data extraction. Only statically known data operations
## are folded here; dynamic gameplay stays diagnosed for later stages.
const Parser = preload("res://scripts/importer/RubyParser.gd")
const Values = preload("res://scripts/importer/RubyDataValues.gd")
const Compiler = preload("res://scripts/importer/RubyGDScriptCompiler.gd")
var _root = ""
var _source = ""
var _codec: RefCounted
var _manifest: Dictionary
var _methods: Dictionary = {}
var _documents: Dictionary = {}
var _units: Dictionary = {}
var _maps: Dictionary = {}
var _common: Dictionary = {}
var _errors: Array[String] = []
var _expression_count = 0


func generate(
	source_root: String,
	output_root: String,
	scripts: Array,
	maps: Dictionary,
	codec: RefCounted,
	common: Dictionary = {}
) -> Dictionary:
	_source = source_root
	_root = output_root
	_codec = codec
	_maps = maps
	_documents = {}
	_methods = {}
	_units = {}
	_errors = []
	_expression_count = 0
	_common = common
	_manifest = {
		"format": "rgm-custom-data-v1",
		"profile": "standard",
		"sources": [],
		"diagnostics": [],
		"constants": {},
		"globals": {},
		"actor_presets": {},
		"system_defaults": {},
		"currencies": [],
		"floors": {},
		"comments": [],
		"adapters": []
	}
	for entry in scripts:
		if (
			str(entry.source).contains("def gain_kin")
			and str(entry.source).contains("def gain_spar")
		):
			_manifest.profile = "flash"
		if (
			str(entry.source).contains("def set(id,hp,atk,pdef,atkspeed")
			and str(entry.source).contains("module Monster")
		):
			_manifest.profile = "antinomy"
	for entry in scripts:
		var parsed = Parser.new().parse(entry.source, entry.origin)
		if not parsed.ok:
			_data_fragments(entry)
			continue
		_index(parsed.ast.body, "", entry)
		if _manifest.profile == "antinomy" and int(entry.origin.load_order) == 1:
			_initial_data(parsed.ast.body, entry.origin)
	if _manifest.profile == "flash":
		_manifest.currencies = [
			{"key": "gold", "label": "金币", "maximum": "9999999"},
			{"key": "kin", "label": "KIN", "maximum": "9999999"}
		]
		for i in 5:
			_manifest.currencies.append(
				{
					"key": "spar:" + str(i),
					"label": ["地", "水", "火", "风", "时"][i] + "耀晶石",
					"maximum": "9999999"
				}
			)
		_external_data()
		_extract_defaults("Game_System", "initialize")
		_actor_presets()
		_floor_tree()
		_adapter(
			"Game_Party",
			[
				"kin",
				"spar",
				"gain_currency",
				"gain_kin",
				"lose_kin",
				"gain_spar",
				"lose_spar",
				"hatred",
				"hatred="
			]
		)
		_adapter(
			"Game_Troop",
			[
				"enemies",
				"variety",
				"enemy_check",
				"enemy_event",
				"clear_enemies",
				"load_enemies",
				"update"
			]
		)
		_adapter("DataBase", ["maptree", "get_floor_type"])
		# Presets are data here; applying the derived actor formulas is stage 0.45.
	elif _manifest.profile == "antinomy":
		_manifest.currencies = [{"key": "gold", "label": "金币", "maximum": _gold_maximum()}]
		_startup("Monster", "Load")
		_adapter("Monster", ["set", "eset"])
		_descriptions()
		_enemy_skills()
	_actor_defaults()
	for file in DirAccess.get_files_at(source_root.path_join("Data")):
		if not file.ends_with(".rxdata"):
			_preserve("Data/" + file)
	_preserve_directory("Info")
	_comments()
	for database in _documents:
		_write("data/database/" + database + ".json", _documents[database])
	var database_manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_root.path_join("data/manifest.json"))
	)
	for database in _documents:
		if database not in database_manifest.get("database", []):
			database_manifest.database.append(database)
	_write("data/manifest.json", database_manifest)
	_manifest["summary"] = {
		"profile": _manifest.profile,
		"sources": _manifest.sources.size(),
		"record_fields": _field_count(),
		"expressions": _expression_count,
		"floor_maps": _manifest.floors.get("maps", {}).size(),
		"comment_tags": _manifest.comments.size(),
		"diagnostics": _manifest.diagnostics.size()
	}
	_write("data/custom_data.json", _manifest)
	_write("data/custom_units.json", {"format": Compiler.FORMAT, "units": _units})
	_write("custom_data_inventory.md", _report())
	return {
		"ok": _errors.is_empty(),
		"errors": _errors,
		"summary": _manifest.summary,
		"diagnostics": _manifest.diagnostics
	}


func _index(body: Array, owner: String, entry: Dictionary) -> void:
	for n in body:
		if n.kind in ["class", "module"]:
			_index(n.body, n.name if owner.is_empty() else owner + "::" + n.name, entry)
		elif n.kind == "method":
			_methods[owner + "#" + n.name] = {
				"node": n, "origin": entry.origin, "sha256": str(entry.source).sha256_text()
			}
		elif (
			owner == "Kernel"
			and n.kind == "assign"
			and n.left.kind == "name"
			and n.left.name[0] == n.left.name[0].to_upper()
		):
			var value = _fold(n.right)
			if value.ok:
				_manifest.constants[n.left.name] = value.value
		elif (
			owner == "Kernel"
			and n.kind == "assign"
			and n.operator == "="
			and n.left.kind == "index"
			and n.left.receiver.kind == "name"
			and n.left.arguments.size() == 1
		):
			var name: String = n.left.receiver.name
			if not _manifest.constants.get(name) is Dictionary:
				continue
			var key = _fold(n.left.arguments[0])
			var value = _fold(n.right)
			if key.ok and value.ok and (key.value is String or key.value is int):
				_manifest.constants[name][str(key.value)] = value.value


func _data_fragments(entry: Dictionary) -> void:
	# A rejected whole library stays rejected in script_units. Independently
	# parsed data fragments have their own exact source span and hash evidence.
	var source: String = entry.source
	var type_pattern = RegEx.new()
	type_pattern.compile("(?m)^\\s*(?:class|module)\\s+([A-Za-z_][A-Za-z0-9_:]*)")
	var type_match = type_pattern.search(source)
	if type_match == null:
		return
	var owner = type_match.get_string(1)
	if (
		owner
		not in [
			"Kernel",
			"Game_Party",
			"Game_System",
			"Game_Troop",
			"Game_Object",
			"DataBase",
			"Game_Actor",
			"Game_Battler",
			"Game_Item",
			"Game_Weapon",
			"Game_Armor",
			"Game_Ornament",
			"Game_Deputy",
			"Game_Enemy"
		]
	):
		return
	var header_pattern = RegEx.new()
	header_pattern.compile("(?m)^([ \\t]*)def\\s+((?:self\\.)?[A-Za-z_][A-Za-z0-9_!?=]*)[^\\n]*")
	var headers = header_pattern.search_all(source)
	if owner == "Kernel":
		var prefix = source.left(
			headers[0].get_start() if not headers.is_empty() else source.length()
		)
		var kernel_data = Parser.new().parse(prefix + "\nend\n", entry.origin)
		if kernel_data.ok:
			_index(kernel_data.ast.body, "", entry)
		else:
			_diagnostic("kernel_data", "常量初始化片段未完整解析，保留原文并逐项提取已确定初值。", entry.origin)
		var constant_pattern = RegEx.new()
		constant_pattern.compile("(?m)^\\s*([A-Z][A-Z0-9_]*)\\s*=([^\\n]*)")
		for match_value in constant_pattern.search_all(prefix):
			var value = Values.new().parse(
				match_value.get_string(2).get_slice("#", 0).strip_edges(), entry.origin
			)
			if value.ok and not _manifest.constants.has(match_value.get_string(1)):
				_manifest.constants[match_value.get_string(1)] = value.value
	for index in headers.size():
		var header = headers[index]
		var start = header.get_start()
		var finish = (
			headers[index + 1].get_start() if index + 1 < headers.size() else source.length()
		)
		var candidate = source.substr(start, finish - start)
		var name = header.get_string(2).trim_prefix("self.")
		var line = source.left(start).count("\n") + 1
		var metadata = {
			"node":
			{
				"span":
				{
					"line": line,
					"column": 1,
					"end_line": line + candidate.count("\n"),
					"end_column": 1
				},
				"body": []
			},
			"origin": entry.origin,
			"sha256": source.sha256_text(),
			"fragment_parsed": false,
			"fragment_source": candidate
		}
		var offset = 0
		for part in candidate.split("\n"):
			offset += part.length() + 1
			if part.strip_edges() != "end":
				continue
			var parsed = Parser.new().parse(candidate.left(offset), entry.origin)
			if parsed.ok and parsed.ast.body.size() == 1 and parsed.ast.body[0].kind == "method":
				metadata.node = parsed.ast.body[0]
				_relocate(metadata.node, line - 1)
				metadata.fragment_parsed = true
				break
		_methods[owner + "#" + name] = metadata


static func _relocate(value: Variant, lines: int) -> void:
	if value is Dictionary:
		if value.get("span") is Dictionary:
			value.span.line += lines
			value.span.end_line += lines
		for key in value:
			if key != "span":
				_relocate(value[key], lines)
	elif value is Array:
		for child in value:
			_relocate(child, lines)


func _fold(node: Dictionary, locals: Dictionary = {}, ruby_hash: bool = false) -> Dictionary:
	var evaluator = Values.new()
	evaluator.constants = _manifest.constants.merged(_manifest.globals)
	evaluator.ruby_hash = ruby_hash
	var value: Variant = evaluator.expression(node, locals)
	return {"ok": evaluator.failure.is_empty(), "value": value, "message": evaluator.failure}


func _initial_data(body: Array, origin: Dictionary) -> void:
	for n in body:
		if n.kind != "assign":
			_diagnostic("global_data_deferred", "启动数据语句尚不能静态确定。", origin, n.span)
			continue
		var value = _fold(n.right, {}, true)
		if not value.ok:
			if not _manifest.has("deferred_globals"):
				_manifest.deferred_globals = []
			if n.left.kind == "name":
				_manifest.deferred_globals.append(n.left.name)
			_diagnostic("global_data_deferred", value.message, origin, n.span)
			continue
		if n.left.kind == "name" and n.left.name.begins_with("$"):
			_manifest.globals[n.left.name] = value.value
		elif n.left.kind == "index" and n.left.receiver.kind == "name":
			var name: String = n.left.receiver.name
			var args: Array = []
			for a in n.left.arguments:
				var v = _fold(a)
				if v.ok:
					args.append(v.value)
			var target: Variant = _manifest.globals.get(name)
			if (
				target is Array
				and args.size() in [1, 2]
				and args[0] is int
				and args[0] >= 0
				and args[0] < 100000
			):
				while target.size() < int(args[0]):
					target.append(null)
				if args.size() == 1:
					if target.size() == int(args[0]):
						target.append(value.value)
					else:
						target[int(args[0])] = value.value
				elif args[1] is int and args[1] >= 0 and value.value is Array:
					for count in mini(int(args[1]), target.size() - int(args[0])):
						target.remove_at(int(args[0]))
					for i in value.value.size():
						target.insert(int(args[0]) + i, value.value[i])
			else:
				_diagnostic("global_data_deferred", "该启动数据下标写入需要后续适配。", origin, n.span)


func _external_data() -> void:
	var path = str(_manifest.constants.get("EXTERNAL_DATA_PATH", ""))
	for config in [
		["ITEM", "item", "Items"],
		["WEAPON", "weapon", "Weapons"],
		["ARMOR", "armor", "Armors"],
		["ORNAMENT", "ornament", "Ornaments"],
		["ENEMY", "enemy", "Enemies"],
		["DEPUTY", "deputy", "Deputies"]
	]:
		var constant = "EXTERNAL_DATA_" + config[0]
		if not _manifest.constants.has(constant):
			continue
		var relative = path + str(_manifest.constants[constant])
		if not _inside(relative):
			_diagnostic("external_path", "自定义数据路径不在原工程内：" + relative)
			continue
		if not FileAccess.file_exists(_source.path_join(relative)):
			_diagnostic("external_missing", "配置文件不存在，未用其他示例文件替代：" + relative)
			continue
		_preserve(relative)
		var bytes = FileAccess.get_file_as_bytes(_source.path_join(relative))
		var text = bytes.get_string_from_utf8() if _utf8(bytes) else _codec.decode_bytes(bytes)
		text = text.trim_prefix("\ufeff").replace("\r\n", "\n")
		var pattern = RegEx.new()
		pattern.compile("(?s)<" + config[1] + "_id:([0-9]+)>(.*?)</" + config[1] + ">")
		var ids = {}
		for match_value in pattern.search_all(text):
			var id = int(match_value.get_string(1))
			var block = match_value.get_string(2)
			var fields: Dictionary = {}
			var source_fields: Dictionary = {}
			if ids.has(id):
				_diagnostic("external_duplicate", "原读取器采用首个数据块；保留后续重复块：" + relative + ":" + str(id))
				continue
			ids[id] = true
			var desc = RegEx.new()
			desc.compile("(?s)description:(.*?)/")
			var description = desc.search(block)
			if description != null:
				fields.description = description.get_string(1)
				block = desc.sub(block, "", true)
			for line in block.split("\n"):
				var raw = line.get_slice("#", 0)
				if raw.strip_edges().is_empty() or not raw.contains(":"):
					continue
				var key = raw.get_slice(":", 0)
				var expression = raw.get_slice(":", 1)
				var origin = {
					"kind": "data_expression",
					"source_file": relative,
					"database": config[2],
					"record_id": id,
					"field": key,
					"line":
					(
						text.left(match_value.get_start(2)).count("\n")
						+ 1
						+ (
							match_value
							. get_string(2)
							. left(match_value.get_string(2).find(line))
							. count("\n")
						)
					)
				}
				source_fields[key] = {"source": expression, "origin": origin}
				if key in ["name", "price"]:
					fields[key] = expression if key == "name" else int(expression)
				elif not expression.strip_edges().is_empty():
					if key.contains("_name"):
						fields[key] = expression
					else:
						if key.contains("_set") or key.contains("_table"):
							expression = "[" + expression + "]"
						var value = _expression(expression, origin)
						if value.ok:
							fields[key] = value.value
						else:
							source_fields[key]["diagnostic"] = value.message
			var record = _record(config[2], id, true)
			if not record.is_empty():
				_metadata(record).external = {
					"file": relative,
					"key": config[1],
					"source_fields": source_fields,
					"settings": fields.duplicate(true)
				}
				for key in fields:
					var value: Variant = fields[key]
					if value == null or value is bool and not value:
						var fallback = _setting_fallback("Game_" + str(config[1]).capitalize(), key)
						if not fallback.is_empty() and record.has(fallback):
							value = record[fallback]
					_set_field(
						config[2],
						id,
						key,
						value,
						{"source_file": relative, "record_id": id, "field": key}
					)


func _setting_fallback(owner: String, key: String) -> String:
	var entry: Dictionary = _methods.get(owner + "#" + key, {})
	var field = _find_setting_fallback(entry.get("node", {}), key)
	if not field.is_empty():
		return field
	for line in str(entry.get("fragment_source", "")).split("\n"):
		if not line.strip_edges().begins_with("return @setting["):
			continue
		var parsed = Parser.new().parse(line.strip_edges(), entry.get("origin", {}))
		if parsed.ok:
			field = _find_setting_fallback(parsed.ast, key)
			if not field.is_empty():
				return field
	return ""


func _find_setting_fallback(node: Variant, key: String) -> String:
	if node is Array:
		for child in node:
			var found = _find_setting_fallback(child, key)
			if not found.is_empty():
				return found
	elif node is Dictionary:
		if (
			node.get("kind") == "binary"
			and node.get("operator") == "||"
			and node.left.get("kind") == "index"
			and node.left.receiver.get("name") == "@setting"
			and node.right.get("kind") == "call"
		):
			var index = _fold(node.left.arguments[0])
			if index.ok and index.value == key:
				return node.right.name
		for value in node.values():
			var found = _find_setting_fallback(value, key)
			if not found.is_empty():
				return found
	return ""


func _expression(source: String, origin: Dictionary) -> Dictionary:
	var parsed = Parser.new().parse(source, origin)
	if not parsed.ok or parsed.ast.body.size() != 1 or not _pure_expression(parsed.ast.body[0]):
		_diagnostic("data_expression", "数据表达式含未确认的调用或副作用；原文保留。", origin)
		return {"ok": false, "message": "数据表达式需后续适配。"}
	_expression_count += 1
	var id = "data_%05d" % _expression_count
	var path = "res://runtime/generated/" + id + ".gd"
	var compiled = Compiler.new().compile(source, origin, path)
	if not compiled.ok:
		_diagnostic("data_expression", str(compiled.diagnostics), origin)
		return {"ok": false, "message": "数据表达式暂不能生成；原文已保留。"}
	DirAccess.make_dir_recursive_absolute(_root.path_join("runtime/generated"))
	_write_text(path.trim_prefix("res://"), compiled.generated_source)
	_units[id] = {
		"origin": origin,
		"status": "generated",
		"generated": true,
		"pure_expression": true,
		"compiler_format": Compiler.FORMAT,
		"source": source,
		"source_sha256": source.sha256_text(),
		"generated_path": path,
		"definitions": {"safe": true, "types": [], "methods": [], "constants": []},
		"event_integrated": false,
		"runtime_verified": false,
		"source_map": compiled.source_map
	}
	var evaluator = Values.new()
	evaluator.constants = _manifest.constants
	var folded = evaluator.parse(source, origin)
	if folded.ok:
		return {"ok": true, "value": folded.value}
	return {"ok": true, "value": {"_generated_data_expression": id}}


static func _pure_expression(value: Variant) -> bool:
	if value is Array:
		for child in value:
			if not _pure_expression(child):
				return false
	elif value is Dictionary:
		if (
			value.has("kind")
			and (
				value.kind
				not in [
					"literal",
					"big_integer",
					"name",
					"symbol",
					"self",
					"string",
					"array",
					"hash",
					"unary",
					"binary",
					"ternary",
					"range",
					"index",
					"call"
				]
			)
		):
			return false
		if value.get("kind") == "call":
			if (
				value.name in ["new", "clear", "delete", "update", "load_enemies", "clear_enemies"]
				or value.name.begins_with("gain_")
				or value.name.begins_with("lose_")
			):
				return false
			if not value.arguments.is_empty() and value.name not in ["include?", "key?"]:
				return false
		for key in value:
			if key not in ["span", "origin"] and not _pure_expression(value[key]):
				return false
	return true


func _startup(owner: String, name: String, depth: int = 0) -> void:
	if depth > 8 or not _methods.has(owner + "#" + name):
		return
	var entry: Dictionary = _methods[owner + "#" + name]
	for n in entry.node.body:
		if n.kind == "name" and n.name in ["equipLoad", "itemLoad"]:
			_startup(owner, n.name, depth + 1)
			continue
		if n.kind == "call" and n.get("receiver", {}).is_empty():
			if n.name in ["set", "eset"]:
				var args: Array = []
				var valid = true
				for a in n.arguments:
					var value = _fold(a)
					valid = valid and value.ok
					args.append(value.get("value"))
				if valid:
					_data_set(n.name, args, entry.origin.merged({"span": n.span}))
				else:
					_diagnostic("startup_dynamic", "启动属性参数不是常量。", entry.origin, n.span)
			elif n.name in ["equipLoad", "itemLoad"]:
				_startup(owner, n.name, depth + 1)
		elif n.kind == "assign" and n.left.kind == "call":
			var target = _record_target(n.left.receiver)
			var value = _fold(n.right)
			if target.ok and value.ok:
				_set_field(
					target.database,
					target.id,
					n.left.name,
					value.value,
					entry.origin.merged({"span": n.span})
				)
		elif n.kind not in ["for", "assign"]:
			_diagnostic("startup_deferred", "启动语句需后续适配。", entry.origin, n.span)


func _data_set(name: String, args: Array, origin: Dictionary) -> void:
	var required = 5 if name == "set" else 6
	if args.size() < required or not args[0] is int or args[0] < 1:
		return
	var id: int = args[0]
	var database = "Enemies" if name == "set" else "Weapons"
	var keys = (
		["maxhp", "atk", "pdef", "agi", "eva", "gold", "exp"]
		if name == "set"
		else ["str_plus", "dex_plus", "atk", "pdef", "mdef"]
	)
	var values = args.slice(1)
	var defaults = [0, -1, -1, 1]
	if name == "set":
		while values.size() < 8:
			values.append(defaults[values.size() - 4])
		for i in 3:
			values[i] *= values[7]
	for i in keys.size():
		if name == "set" and i in [5, 6] and values[i] < 0:
			continue
		_set_field(database, id, keys[i], values[i], origin)
	if name == "eset" and args.size() > 6 and args[6] != null:
		_set_field(database, id, "name", args[6], origin)


func _record_target(node: Dictionary) -> Dictionary:
	if node.kind != "index" or node.receiver.kind != "name" or node.arguments.size() != 1:
		return {"ok": false}
	var db = (
		{
			"$data_enemies": "Enemies",
			"$data_weapons": "Weapons",
			"$data_items": "Items",
			"$data_armors": "Armors"
		}
		. get(node.receiver.name, "")
	)
	var id = _fold(node.arguments[0])
	return {
		"ok": not db.is_empty() and id.ok and id.value is int,
		"database": db,
		"id": id.get("value", 0)
	}


func _set_field(database: String, id: int, key: String, value: Variant, origin: Dictionary) -> void:
	var record = _record(database, id, database in ["Ornaments", "Deputies"])
	if record.is_empty():
		_diagnostic("data_reference", "自定义数据引用不存在：%s[%d]" % [database, id], origin)
		return
	var metadata = _metadata(record)
	if not metadata.has("original_fields"):
		metadata.original_fields = {}
		metadata.sources = {}
	if not metadata.original_fields.has(key):
		metadata.original_fields[key] = {"present": record.has(key), "value": record.get(key)}
	metadata.sources[key] = origin
	if key == "name" and value is String:
		metadata.tags = _tags(value)
	record[key] = value


func _record(database: String, id: int, create: bool = false) -> Dictionary:
	if not _documents.has(database):
		var path = _root.path_join("data/database/" + database + ".json")
		_documents[database] = (
			JSON.parse_string(FileAccess.get_file_as_string(path))
			if FileAccess.file_exists(path)
			else []
		)
	var records: Variant = _documents[database]
	if not records is Array or id < 1 or id > 100000:
		return {}
	if create:
		while records.size() <= id:
			records.append(null)
		if records[id] == null:
			records[id] = {"id": id, "_class": "Custom::" + database}
	return records[id] if id < records.size() and records[id] is Dictionary else {}


func _extract_defaults(owner: String, name: String) -> void:
	if not _methods.has(owner + "#" + name):
		return
	for n in _methods[owner + "#" + name].node.body:
		if n.kind == "assign" and n.left.kind == "name" and n.left.name.begins_with("@"):
			var value = _fold(n.right)
			if value.ok:
				_manifest.system_defaults[n.left.name.trim_prefix("@")] = value.value


func _actor_presets() -> void:
	var entry: Dictionary = _methods.get("Actor_Init#load", {})
	if entry.is_empty():
		return
	for n in entry.node.body:
		if n.kind != "case" or n.value.get("name") != "actor_id":
			continue
		for branch in n.branches:
			for pattern in branch.patterns:
				var actor = _fold(pattern)
				if not actor.ok or not actor.value is int:
					continue
				var presets = {}
				for inner in branch.body:
					if inner.kind != "case" or inner.value.get("name") != "times":
						continue
					for choice in inner.branches:
						var fields = {}
						for statement in choice.body:
							if statement.kind == "assign" and statement.left.kind == "call":
								var value = _fold(statement.right)
								if value.ok:
									fields[statement.left.name] = value.value
						for preset in choice.patterns:
							var index = _fold(preset)
							if index.ok:
								presets[str(index.value)] = fields
				_manifest.actor_presets[str(actor.value)] = presets


func _actor_defaults() -> void:
	var fields = {}
	for key in ["Game_Battler#initialize", "Game_Actor#initialize", "Game_Actor#setup"]:
		for n in _methods.get(key, {}).get("node", {}).get("body", []):
			if n.kind == "assign" and n.left.kind == "name" and n.left.name.begins_with("@"):
				var value = _fold(n.right)
				if value.ok:
					fields[n.left.name.trim_prefix("@")] = value.value
		# A complex setup method may still contain independently parseable,
		# literal initial extension assignments. Retain exact source provenance.
		var method: Dictionary = _methods.get(key, {})
		for line in str(method.get("fragment_source", "")).split("\n"):
			var parsed = Parser.new().parse(line.strip_edges(), method.get("origin", {}))
			if not parsed.ok or parsed.ast.body.size() != 1:
				continue
			var n: Dictionary = parsed.ast.body[0]
			if (
				n.kind == "assign"
				and n.left.kind == "name"
				and n.left.name in ["@hprate", "@sprate", "@equip_id"]
			):
				var value = _fold(n.right)
				if value.ok:
					fields[n.left.name.trim_prefix("@")] = value.value
	_manifest["actor_defaults"] = fields
	# Only raw project attributes are exposed at this stage, never substituted
	# native or guessed derived combat values.
	var keys = [
		"tp_plus", "hprate", "sprate", "equip_id", "resist_plus", "skill_parameters", "delay_const"
	]
	for id in range(1, _record_list("Actors").size()):
		var record = _record("Actors", id)
		if record.is_empty():
			continue
		var attributes = {}
		for key in keys:
			if fields.has(key):
				attributes[key] = (
					fields[key].duplicate(true)
					if fields[key] is Array or fields[key] is Dictionary
					else fields[key]
				)
		if not attributes.is_empty():
			_metadata(record)["attributes"] = attributes


func _record_list(database: String) -> Array:
	_record(database, 1)
	return _documents.get(database, [])


func _gold_maximum() -> String:
	var entry: Dictionary = _methods.get("Game_Party#gain_gold", {})
	if entry.is_empty():
		return "9999999"
	var value = _find_large(entry.node)
	return value if not value.is_empty() else "9999999"


func _find_large(value: Variant) -> String:
	if value is Dictionary:
		if value.get("kind") == "big_integer":
			return str(value.value)
		for child in value.values():
			var found = _find_large(child)
			if not found.is_empty():
				return found
	elif value is Array:
		for child in value:
			var found = _find_large(child)
			if not found.is_empty():
				return found
	return ""


func _floor_tree() -> void:
	var infos = JSON.parse_string(
		FileAccess.get_file_as_string(_root.path_join("data/map_infos.json"))
	)
	if not infos is Dictionary:
		return
	var floors = {"lookup": {}, "maps": {}}
	var floor_pattern = RegEx.new()
	floor_pattern.compile("^(-*\\d+):(-*\\d+)")
	var template = RegEx.new()
	template.compile("^<(.+?):.*>$")
	for id in infos:
		var match_value = floor_pattern.search(str(infos[id].get("name", "")))
		if match_value != null:
			var pair = [int(match_value.get_string(1)), int(match_value.get_string(2))]
			floors.lookup[str(pair[0]) + ":" + str(pair[1])] = int(id)
			floors.maps[id] = {"I": pair, "templates": {}}
	for id in infos:
		var match_value = template.search(str(infos[id].get("name", "")))
		var parent = str(int(infos[id].get("parent_id", 0)))
		if match_value != null and floors.maps.has(parent):
			floors.maps[parent].templates[match_value.get_string(1)] = int(id)
	_manifest.floors = floors


func _descriptions() -> void:
	var records: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(_root.path_join("data/database/Skills.json"))
	)
	if not records is Array:
		return
	_documents.Skills = records
	for record in records:
		if not record is Dictionary or record.get("description") != "txt":
			continue
		var name = str(record.get("name", "")).get_slice("Lv", 0).get_slice(":", 0).get_slice(
			"|", 0
		)
		var relative = "Info/Skill/" + name + ".txt"
		if not _inside(relative) or not FileAccess.file_exists(_source.path_join(relative)):
			_diagnostic("description_missing", "原自定义技能说明文件缺失：" + relative)
			continue
		_preserve(relative)
		var bytes = FileAccess.get_file_as_bytes(_source.path_join(relative))
		if bytes.size() >= 3 and bytes[0] == 239 and bytes[1] == 187 and bytes[2] == 191:
			bytes = bytes.slice(3)
		else:
			_diagnostic("description_encoding", "源读取器会截掉前三字节，缺少UTF-8 BOM；未猜测说明文本：" + relative)
			continue
		_set_field(
			"Skills",
			int(record.id),
			"description",
			bytes.get_string_from_utf8(),
			{"source_file": relative}
		)


func _enemy_skills() -> void:
	var records: Array = _documents.get("Enemies", [])
	var table: Array = []
	var j = 0
	for record in records:
		if not record is Dictionary:
			continue
		j += 1
		while table.size() <= j:
			table.append(null)
		table[j] = []
		var ranks: Dictionary = record.get("element_ranks", {})
		var values: Array = ranks.get("values", [])
		for i in range(1, mini(int(ranks.get("x_size", 0)), values.size())):
			if int(values[i]) == 1:
				table[j].append(i)
	_manifest.globals["$enemies_skills"] = table


func _comments() -> void:
	for map_name in _maps:
		for event in _maps[map_name].get("events", {}).values():
			var pages: Array = event.get("pages", [])
			for i in pages.size():
				_comment_list(
					pages[i].get("list", []),
					{"kind": "map_event", "map": map_name, "event_id": event.id, "page": i + 1}
				)
	for database in _common:
		for event in _common[database]:
			if event is Dictionary:
				_comment_list(
					event.get("list", []),
					{"kind": "common_event", "database": database, "common_event_id": event.id}
				)


func _comment_list(commands: Array, origin: Dictionary) -> void:
	var index = 0
	while index < commands.size():
		var command: Dictionary = commands[index]
		if int(command.get("code", 0)) != 108:
			index += 1
			continue
		var first = index
		var text = str(command.get("parameters", [""])[0])
		index += 1
		while index < commands.size() and int(commands[index].get("code", 0)) == 408:
			text += "\n" + str(commands[index].get("parameters", [""])[0])
			index += 1
		var kind = (
			"portrait"
			if _manifest.profile == "antinomy" and text.begins_with("立绘")
			else "data_reference" if text.begins_with("::") else "comment"
		)
		_manifest.comments.append(
			{
				"origin": origin.merged({"command_index": first + 1}),
				"text": text,
				"source_sha256": text.sha256_text(),
				"kind": kind,
				"behavior_stage":
				(
					"0.46"
					if kind == "portrait"
					else "0.45" if kind == "data_reference" else "native_comment"
				)
			}
		)


func _adapter(owner: String, names: Array) -> void:
	for name in names:
		var method: Dictionary = _methods.get(owner + "#" + name, {})
		if not method.is_empty():
			_manifest.adapters.append(
				{
					"owner": owner,
					"method": name,
					"treatment": "service_adapter",
					"origin": method.origin,
					"span": method.node.span,
					"source_sha256": method.sha256,
					"target": "runtime/scripts/00_Game/CustomDataState.gd"
				}
			)


static func _tags(name: String) -> Array:
	return preload("res://templates/runtime/scripts/00_Game/CustomDataTags.gd").parse(name)


func _preserve(relative: String) -> void:
	if (
		not _inside(relative)
		or _manifest.sources.any(func(s: Dictionary) -> bool: return s.path == relative)
	):
		return
	var bytes = FileAccess.get_file_as_bytes(_source.path_join(relative))
	var path = "legacy/custom_data/" + relative
	DirAccess.make_dir_recursive_absolute(_root.path_join(path).get_base_dir())
	var file = FileAccess.open(_root.path_join(path), FileAccess.WRITE)
	if file == null:
		_errors.append("自定义原文无法保留：" + relative)
		return
	file.store_buffer(bytes)
	file.close()
	_manifest.sources.append(
		{"path": relative, "preserved_path": path, "bytes": bytes.size(), "sha256": _sha256(bytes)}
	)


func _preserve_directory(relative: String) -> void:
	if not DirAccess.dir_exists_absolute(_source.path_join(relative)):
		return
	for file in DirAccess.get_files_at(_source.path_join(relative)):
		_preserve(relative + "/" + file)
	for folder in DirAccess.get_directories_at(_source.path_join(relative)):
		_preserve_directory(relative + "/" + folder)


func _write(path: String, value: Variant) -> void:
	_write_text(path, value if value is String else JSON.stringify(value, "\t", false) + "\n")


func _write_text(path: String, value: String) -> void:
	var file = FileAccess.open(_root.path_join(path), FileAccess.WRITE)
	if file == null:
		_errors.append("自定义数据无法写入：" + path)
		return
	file.store_string(value)
	file.close()


func _diagnostic(
	code: String, message: String, origin: Dictionary = {}, span: Dictionary = {}
) -> void:
	_manifest.diagnostics.append({"code": code, "message": message, "origin": origin, "span": span})


static func _metadata(record: Dictionary) -> Dictionary:
	if not record.has("_custom_data"):
		record._custom_data = {}
	return record._custom_data


static func _inside(path: String) -> bool:
	return not path.is_absolute_path() and not path.replace("\\", "/").split("/").has("..")


static func _utf8(bytes: PackedByteArray) -> bool:
	return bytes.get_string_from_utf8().to_utf8_buffer() == bytes


static func _sha256(bytes: PackedByteArray) -> String:
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


func _field_count() -> int:
	var count = 0
	for records in _documents.values():
		if records is Array:
			for record in records:
				if record is Dictionary:
					count += record.get("_custom_data", {}).get("sources", {}).size()
	return count


func _report() -> String:
	var lines: Array[String] = [
		"# 自定义数据与属性",
		"",
		"原Ruby只读分析；来源、扩展字段和适配方法见data/custom_data.json。",
		"",
		"概要：" + JSON.stringify(_manifest.summary),
		"",
		"## 源文件",
		"",
		"| 原路径 | 字节 | SHA256 |",
		"| --- | --- | --- |"
	]
	for source in _manifest.sources:
		lines.append("| " + source.path + " | " + str(source.bytes) + " | " + source.sha256 + " |")
	lines.append_array(["", "## 诊断", "", "未知字段及缺失配置不替换、不删除。属性标签的战斗效果按0.45，立绘注释按0.46接入。"])
	for d in _manifest.diagnostics:
		lines.append("- " + d.code + ": " + d.message + " " + JSON.stringify(d.origin))
	return "\n".join(lines) + "\n"

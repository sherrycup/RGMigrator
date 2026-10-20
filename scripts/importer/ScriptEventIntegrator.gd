## 职责：将成功生成的脚本绑定到地图事件、公共事件和移动路线，并保留未转换的原记录。
##
## 调用方式：
##   静态接口：preload("res://scripts/importer/ScriptEventIntegrator.gd").方法名(...)。
##
## 调用接口：
##   static func key(origin: Dictionary) -> String
##     参数 origin（Dictionary；必填）：原脚本、地图或数据库字段的来源信息。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func bind_list(commands: Array, origin: Dictionary, bindings: Dictionary) -> void
##     参数 commands（Array；必填）：保持原顺序的事件指令列表。
##     参数 origin（Dictionary；必填）：原脚本、地图或数据库字段的来源信息。
##     参数 bindings（Dictionary；必填）：原事件与生成脚本之间的绑定集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func bind_route(route: Dictionary, origin: Dictionary, bindings: Dictionary) -> void
##     参数 route（Dictionary；必填）：人物移动路线数据。
##     参数 origin（Dictionary；必填）：原脚本、地图或数据库字段的来源信息。
##     参数 bindings（Dictionary；必填）：原事件与生成脚本之间的绑定集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func integrate( root: String, maps: Dictionary, common: Dictionary, units: Dictionary, errors: Array[String], policy: Dictionary = {} ) -> int
##     参数 root（String；必填）：数据根、节点根或工程根位置。
##     参数 maps（Dictionary；必填）：地图编号到地图数据的集合。
##     参数 common（Dictionary；必填）：公共事件记录集合。
##     参数 units（Dictionary；必填）：脚本编译或迁移单元集合。
##     参数 errors（Array[String]；必填）：需要收集或展示的错误列表。
##     参数 policy（Dictionary；默认值 {}）：原解释器的返回值重试及执行策略，沿用迁移记录。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func definitions( body: Array, owner: String = "Object", singleton_scope: bool = false ) -> Dictionary
##     参数 body（Array；必填）：脚本语句体或处理内容。
##     参数 owner（String；默认值 "Object"）：持有此对象的调用方或运行状态。
##     参数 singleton_scope（bool；默认值 false）：是否处于单例方法定义作用域。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 接口说明结束。

extends RefCounted
## Bind fresh RM records only after compilation; never restore an edited placeholder.
const Adapter = preload("res://templates/editor/addons/rgm_editor/03_Event/Editor_ScriptAdapter.gd")


static func key(origin: Dictionary) -> String:
	return (
		"%s:%s:%s:%d:%d:%d:%s:%d"
		% [
			origin.kind,
			origin.get("database", "CommonEvents" if origin.kind == "common_event" else ""),
			origin.get("map", ""),
			int(origin.get("event_id", origin.get("common_event_id", 0))),
			int(origin.get("page", 0)),
			int(origin.get("command_index", 0)),
			origin.get("route_kind", ""),
			int(origin.get("route_index", 0))
		]
	)


static func bind_list(commands: Array, origin: Dictionary, bindings: Dictionary) -> void:
	for index in commands.size():
		var command: Dictionary = commands[index]
		var location := origin.merged({"command_index": index + 1})
		var binding: Dictionary = bindings.get(key(location), {})
		if not binding.is_empty():
			command["_script_binding"] = binding.duplicate(true)
		if int(command.get("code", 0)) == 209 and command.get("parameters", []).size() > 1:
			bind_route(command.parameters[1], location.merged({"route_kind": "forced"}), bindings)


static func bind_route(route: Dictionary, origin: Dictionary, bindings: Dictionary) -> void:
	route["_script_runtime_route"] = true
	for index in route.get("list", []).size():
		var binding: Dictionary = bindings.get(key(origin.merged({"route_index": index + 1})), {})
		if not binding.is_empty():
			route.list[index]["_script_binding"] = binding.duplicate(true)


static func integrate(
	root: String,
	maps: Dictionary,
	common: Dictionary,
	units: Dictionary,
	errors: Array[String],
	policy: Dictionary = {}
) -> int:
	var bindings := {}
	for id in units:
		var unit: Dictionary = units[id]
		if unit.generated and unit.origin.kind != "script":
			bindings[key(unit.origin)] = {
				"unit_id": id,
				"source_sha256": unit.source_sha256,
				"command_count": unit.origin.get("source_command_indices", [0]).size()
			}
	for name in maps:
		var map: Dictionary = maps[name].duplicate(true)
		for event in map.get("events", {}).values():
			for index in event.get("pages", []).size():
				var origin := {
					"kind": "map_event", "map": name, "event_id": event.id, "page": index + 1
				}
				bind_list(event.pages[index].get("list", []), origin, bindings)
				bind_route(
					event.pages[index].get("move_route", {}),
					origin.merged({"command_index": 0, "route_kind": "autonomous"}),
					bindings
				)
		map = Adapter.adapt_map(map)
		_mark(map, units)
		preload("NativeEventImporter.gd").record_upgrade(
			map, root, "data/maps/" + name + ".json", units, policy
		)
		_write(root.path_join("data/maps/" + name + ".json"), map, errors)
	for database in common:
		var events: Array = common[database].duplicate(true)
		for event in events:
			if event is Dictionary:
				bind_list(
					event.get("list", []),
					{
						"kind": "common_event",
						"database": database,
						"common_event_id": event.id,
						"page": 0
					},
					bindings
				)
		events = Adapter.adapt_common(events)
		_mark(events, units)
		preload("NativeEventImporter.gd").record_upgrade(
			events, root, "data/database/" + database + ".json", units, policy
		)
		_write(root.path_join("data/database/" + database + ".json"), events, errors)
	var integrated := 0
	for unit in units.values():
		if unit.event_integrated:
			integrated += 1
	return integrated


static func _mark(value: Variant, units: Dictionary) -> void:
	if value is Array:
		for entry in value:
			_mark(entry, units)
	elif value is Dictionary:
		if value.has("_script_binding"):
			units[value._script_binding.unit_id].event_integrated = true
		for name in value:
			if not str(name).begins_with("_editor_original"):
				_mark(value[name], units)


static func _write(path: String, value: Variant, errors: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append("无法写入脚本接入数据：" + path)
		return
	file.store_string(JSON.stringify(value, "", false) + "\n")
	if file.get_error() != OK:
		errors.append("脚本接入数据写入失败：" + path)


static func definitions(
	body: Array, owner: String = "Object", singleton_scope: bool = false
) -> Dictionary:
	var result := {"safe": true, "types": [], "methods": [], "constants": []}
	var module_function = false
	for node in body:
		match node.kind:
			"class", "module":
				var name: String = node.name if owner == "Object" else owner + "::" + node.name
				result.types.append(name)
				var nested := definitions(node.body, name)
				result.safe = result.safe and nested.safe
				result.types.append_array(nested.types)
				result.methods.append_array(nested.methods)
				result.constants.append_array(nested.constants)
			"method":
				var method_owner: String = (
					owner
					if (
						node.receiver
						in [
							"",
							"self",
							owner,
							owner.get_slice("::", owner.get_slice_count("::") - 1)
						]
					)
					else node.receiver
				)
				result.methods.append(
					{
						"owner": method_owner,
						"name": node.name,
						"singleton": not node.receiver.is_empty() or singleton_scope
					}
				)
				if module_function and node.receiver == "" and not singleton_scope:
					result.methods.append({"owner": owner, "name": node.name, "singleton": true})
			"singleton_class":
				if node.receiver.get("kind") != "self":
					result.safe = false
				var nested = definitions(node.body, owner, true)
				result.safe = result.safe and nested.safe
				result.methods.append_array(nested.methods)
				result.constants.append_array(nested.constants)
			"alias":
				result.methods.append(
					{"owner": owner, "name": node.name, "singleton": singleton_scope}
				)
			"name":
				if node.name == "module_function":
					module_function = true
				else:
					result.safe = false
			"call":
				if node.receiver.is_empty() and node.name == "module_function":
					if node.arguments.is_empty():
						module_function = true
					else:
						for argument in node.arguments:
							if argument.kind == "symbol":
								result.methods.append(
									{"owner": owner, "name": argument.value, "singleton": true}
								)
				elif (
					node.receiver.is_empty()
					and node.name in ["attr_reader", "attr_writer", "attr_accessor"]
				):
					for argument in node.arguments:
						if argument.kind != "symbol":
							result.safe = false
							continue
						if node.name in ["attr_reader", "attr_accessor"]:
							result.methods.append(
								{
									"owner": owner,
									"name": argument.value,
									"singleton": singleton_scope
								}
							)
						if node.name in ["attr_writer", "attr_accessor"]:
							result.methods.append(
								{
									"owner": owner,
									"name": argument.value + "=",
									"singleton": singleton_scope
								}
							)
				elif not node.receiver.is_empty() or node.name not in ["include", "extend"]:
					result.safe = false
			"if", "unless", "case":
				result.safe = false
				for branch in node.branches:
					var nested = definitions(branch.body, owner, singleton_scope)
					result.types.append_array(nested.types)
					result.methods.append_array(nested.methods)
					result.constants.append_array(nested.constants)
				var otherwise = definitions(node.else_body, owner, singleton_scope)
				result.types.append_array(otherwise.types)
				result.methods.append_array(otherwise.methods)
				result.constants.append_array(otherwise.constants)
			"assign":
				if node.left.kind == "name" and _constant_name(node.left.get("name", "")):
					result.constants.append(
						node.left.name if owner == "Object" else owner + "::" + node.left.name
					)
					if node.operator != "=" or not _constant(node.right):
						result.safe = false
				else:
					result.safe = false
			_:
				result.safe = false
	return result


static func _constant(node: Variant) -> bool:
	if node is Array:
		return node.all(func(n: Variant) -> bool: return _constant(n))
	if not node is Dictionary:
		return true
	if (
		node.has("kind")
		and node.kind not in ["literal", "array", "hash", "pair", "unary", "range", "name"]
	):
		return false
	if node.get("kind") == "name" and not _constant_name(node.get("name", "")):
		return false
	for value in node.values():
		if value is Array or value is Dictionary:
			if not _constant(value):
				return false
	return true


static func _constant_name(name: String) -> bool:
	return not name.is_empty() and name[0] != name[0].to_lower() and name[0] == name[0].to_upper()

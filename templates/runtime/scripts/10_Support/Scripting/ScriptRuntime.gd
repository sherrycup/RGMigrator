## 职责：加载并执行生成的 GDScript，维护原脚本类、方法、alias 及存档源码校验。
##
## 调用方式：
##   普通事件通过已登记绑定进入本服务；独立单元可调用 execute_unit(unit_id, RuntimeState)。
##
## 调用接口：
##   static func execute_unit(unit_id: String, state: Object) -> Dictionary
##     用途：按登记加载并执行生成单元。
##     参数 unit_id（String；必填）：script_units 或 custom_units 中的稳定单元标识。
##     参数 state（Object；必填）：当前正式 RuntimeState，复用其脚本会话。
##     返回：包含 ok 与执行结果或来源诊断的字典；失败按当前首错策略处理。
##
##   static func prewarm() -> Dictionary
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func validate_binding(binding: Variant, source: String) -> Dictionary
##     参数 binding（Variant；必填）：事件入口的 GDScript 身份、源码校验值、来源与策略。
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func execute_bound( binding: Variant, source: String, state: Object, context: Dictionary ) -> Dictionary
##     参数 binding（Variant；必填）：事件入口的 GDScript 身份、源码校验值、来源与策略。
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 context（Dictionary；必填）：当前事件或脚本执行上下文。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func error_text(result: Dictionary) -> String
##     参数 result（Dictionary；必填）：已完成操作的结果数据。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func save_reason(state: Object) -> String
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func call_method( receiver: Dictionary, method: String, arguments: Array, state: Object ) -> Dictionary
##     参数 receiver（Dictionary；必填）：方法调用的接收者。
##     参数 method（String；必填）：需要查询、登记或调用的方法名称。
##     参数 arguments（Array；必填）：按声明顺序传入的参数列表。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func call_transaction(state: Object, context: Dictionary, operation: Callable) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 context（Dictionary；必填）：当前事件或脚本执行上下文。
##     参数 operation（Callable；必填）：需要执行的操作类型。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func dispatch_snapshot_exports(result: Dictionary) -> Dictionary
##     参数 result（Dictionary；必填）：已完成操作的结果数据。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func cancel_native(owner: Object) -> void
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func native_pending_reason(state: Object) -> String
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func native_owner_pending(owner: Object) -> bool
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func new_object(class_name_value: String, arguments: Array, state: Object) -> Dictionary
##     参数 class_name_value（String；必填）：需要操作的原脚本类名。
##     参数 arguments（Array；必填）：按声明顺序传入的参数列表。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func script_data(state: Object) -> Dictionary
##     用途：导出当前脚本会话的可保存类、方法及源码校验信息。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func validate_saved_data(value: Dictionary) -> String
##     用途：检查存档类、方法归属、实际方法及完整源码哈希。
##     参数 value（Dictionary；必填）：存档中由 script_data 导出的脚本会话记录。
##     返回：空串表示通过，非空串为拒绝原因。
##
##   static func validate_saved_objects(value: Variant, classes: Dictionary, seen: Array = []) -> String
##     用途：验证存档对象与已登记脚本类的关系。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 classes（Dictionary；必填）：脚本类定义和继承关系表。
##     参数 seen（Array；默认值 []）：遍历中已访问的容器，用于保留共享与循环关系。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func evaluate_data_expression(id: String, state: Object) -> Dictionary
##     参数 id（String；必填）：本接口所处理对象的编号。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 注意：执行的是生成 GDScript；原 Ruby 仅用于来源与绑定校验。闪翼路径直接修改正式状态，首错停止。
## 接口说明结束。

extends RefCounted
## Pure generated GDScript entry; original text identifies stale bindings only.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Semantics = preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")
const ProgramDocs = preload("ProgramDocumentation.gd")
const NativeSource = preload("../../02_Event/NativeScriptSource.gd")
const NativeTask = preload("../../02_Event/NativeEventTask.gd")
static var _native_tasks: Dictionary = {}
static var _definition_registry: Variant = null
static var _definition_symbols: Dictionary = {}
static var _definition_order: Dictionary = {}


static func _index_definitions(registry: Dictionary) -> void:
	if is_same(registry, _definition_registry):
		return
	_definition_registry = registry
	_definition_symbols = {}
	_definition_order = {}
	for id in registry.get("units", {}):
		var unit: Dictionary = registry.units[id]
		if unit.get("origin", {}).get("kind") != "script":
			continue
		_definition_order[id] = _definition_order.size()
		var definitions: Dictionary = unit.get("definitions", {})
		var symbols: Dictionary = {}
		for name in definitions.get("types", []):
			symbols["type:" + name] = true
		for name in definitions.get("constants", []):
			symbols["constant:" + name] = true
		for method in definitions.get("methods", []):
			symbols["method:" + str(method.singleton) + ":" + method.name] = true
		for symbol in symbols:
			if not _definition_symbols.has(symbol):
				_definition_symbols[symbol] = []
			_definition_symbols[symbol].append(id)


static func _definition_candidates(
	name: String, owner: String, singleton: bool, registry: Dictionary
) -> Array:
	_index_definitions(registry)
	if not owner.is_empty():
		return _definition_symbols.get("method:" + str(singleton) + ":" + name, [])
	var candidates: Dictionary = {}
	for id in _definition_symbols.get("constant:" + name, []):
		candidates[id] = true
	var prefix = ""
	for part in name.split("::"):
		prefix = part if prefix.is_empty() else prefix + "::" + part
		for id in _definition_symbols.get("type:" + prefix, []):
			candidates[id] = true
	var ordered = candidates.keys()
	ordered.sort_custom(func(a, b): return _definition_order[a] < _definition_order[b])
	return ordered


static func execute_unit(unit_id: String, state: Object) -> Dictionary:
	return _script_result(_execute_unit(unit_id, state), state)


static func _script_result(result: Dictionary, state: Object) -> Dictionary:
	if (
		not result.ok
		and state.has_method("fatal_script_error")
		and state.get("custom_data") != null
		and state.custom_data.manifest.get("profile") == "flash"
	):
		state.fatal_script_error(error_text(result))
	return result


static func _execute_unit(unit_id: String, state: Object) -> Dictionary:
	var registry: Dictionary = Data.read_json("res://data/script_units.json", {})
	var unit: Dictionary = registry.get("units", {}).get(unit_id, {})
	if unit_id.begins_with("data_"):
		unit = Data.read_json("res://data/custom_units.json", {}).get("units", {}).get(unit_id, {})
	if unit.is_empty() or unit.get("status") != "generated":
		return {
			"ok": false,
			"message": "脚本单元未转换：" + unit_id,
			"origin": unit.get("origin", {}),
			"diagnostics": unit.get("diagnostics", [])
		}
	var path: String = unit.get("generated_path", "")
	if not path.begins_with("res://runtime/generated/") or not FileAccess.file_exists(path):
		return {"ok": false, "message": "生成脚本缺失或路径无效：" + path, "origin": unit.get("origin", {})}
	var script: GDScript = Semantics.program(path)
	if script == null or not script.can_instantiate() or not script.has_method("execute"):
		return {"ok": false, "message": "生成脚本无法加载：" + path, "origin": unit.get("origin", {})}
	if unit.get("compiler_format", "") == "rgm-gdscript-v2":
		var env: RefCounted = _session(state)
		var query = (
			{}
			if (
				state.get("custom_data") != null
				and state.custom_data.manifest.get("profile") == "flash"
			)
			else _query_plan(unit, path, state)
		)
		if not query.is_empty():
			if not env.begin_query(unit.get("origin", {}), query):
				return env.failure
			var value: Variant = script.program(env)
			var result: Dictionary = env.finish_query(value)
			if not result.get("retry_full_transaction", false):
				return result
		return script.execute(state, env)
	return script.execute(state)


static func _query_plan(unit: Dictionary, path: String, state: Object) -> Dictionary:
	if state.get("custom_data") == null or state.custom_data.manifest.get("profile") != "flash":
		return {}
	var plan = preload("ScriptQueryProof.gd").plan(unit)
	if plan.is_empty():
		return {}
	var workspace: Variant = Data.read_json("res://data/script_workspace.json", {})
	if not workspace is Dictionary or not workspace.get("generated_hashes") is Dictionary:
		return {}
	var owned: Dictionary = workspace.generated_hashes
	if (
		owned.get(path.trim_prefix("res://"), "")
		!= Semantics._programs.get(path, {}).get("sha256", null)
	):
		return {}
	return plan


static func prewarm() -> Dictionary:
	var failures: Array = []
	_index_definitions(Data.read_json("res://data/script_units.json", {}))
	for registry in [
		Data.read_json("res://data/script_units.json", {}),
		Data.read_json("res://data/custom_units.json", {})
	]:
		for unit in registry.get("units", {}).values():
			if unit.get("status") != "generated":
				continue
			var path: String = unit.get("generated_path", "")
			if not path.begins_with("res://runtime/generated/") or Semantics.program(path) == null:
				failures.append(path)
	return {"ok": failures.is_empty(), "failures": failures}


static func validate_binding(binding: Variant, source: String) -> Dictionary:
	if NativeSource.is_native(binding):
		if (
			not binding.get("native_id") is String
			or not binding.native_id.is_valid_identifier()
			or not binding.get("policy", {}) is Dictionary
			or not binding.get("origin", {}) is Dictionary
		):
			return {"ok": false, "message": "原生事件绑定身份、来源或策略无效。"}
		if source.sha256_text() != binding.get("source_sha256"):
			return {
				"ok": false,
				"message": "事件 GDScript 与保存的绑定不同步。",
				"origin": binding.get("origin", {})
			}
		return NativeSource.compile(source, str(binding.get("native_id", "event"))).merged(
			{"origin": binding.get("origin", {})}
		)
	if not binding is Dictionary or not binding.get("unit_id") is String:
		return {"ok": false, "message": "脚本尚未转换或缺少迁移绑定。"}
	var registry: Dictionary = Data.read_json("res://data/script_units.json", {})
	var unit: Dictionary = registry.get("units", {}).get(binding.unit_id, {})
	if unit.get("status") != "generated" or unit.get("compiler_format") != "rgm-gdscript-v2":
		return {
			"ok": false, "message": "脚本单元尚未转换：" + binding.unit_id, "origin": unit.get("origin", {})
		}
	if (
		source.sha256_text() != unit.get("source_sha256")
		or binding.get("source_sha256") != unit.get("source_sha256")
	):
		return {
			"ok": false, "message": "脚本原文已改变，迁移绑定过期；需重新编译：" + binding.unit_id, "origin": unit.origin
		}
	var path: String = unit.get("generated_path", "")
	if (
		path != "res://runtime/generated/" + binding.unit_id + ".gd"
		or not FileAccess.file_exists(path)
	):
		return {"ok": false, "message": "生成脚本文件缺失或路径无效：" + binding.unit_id}
	return {
		"ok": true,
		"unit": unit,
		"policy": registry.get("interpreter_policy", {}),
		"unit_id": binding.unit_id
	}


static func execute_bound(
	binding: Variant, source: String, state: Object, context: Dictionary
) -> Dictionary:
	if NativeSource.is_native(binding):
		return _execute_native(binding, source, state, context)
	var checked := validate_binding(binding, source)
	if not checked.ok:
		if state.has_method("fatal_script_error"):
			state.fatal_script_error(error_text(checked))
		return checked
	var env: RefCounted = _session(state)
	if env == null:
		return {"ok": false, "message": "脚本调用缺少运行状态。"}
	var previous: Dictionary = env.execution_context
	env.execution_context = context.merged({"policy": checked.policy})
	var source_origin: Dictionary = checked.unit.origin
	if source_origin.has("route_index"):
		env.execution_context.index = int(source_origin.route_index) - 1
	elif source_origin.has("command_index"):
		env.execution_context.index = (
			int(source_origin.get("source_command_indices", [source_origin.command_index])[-1]) - 1
		)
	var result := execute_unit(checked.unit_id, state)
	env.execution_context = previous
	if not result.ok and state.has_method("fatal_script_error"):
		state.fatal_script_error(error_text(result))
	result["policy"] = checked.policy
	result["unit_id"] = checked.unit_id
	return result


static func _execute_native(
	binding: Dictionary, source: String, state: Object, context: Dictionary
) -> Dictionary:
	var checked = validate_binding(binding, source)
	if not checked.ok:
		checked.origin = binding.get("origin", {}).merged(
			{
				"native_id": binding.get("native_id", ""),
				"invocation":
				{
					"map_id": context.get("map_id", 0),
					"event_id": context.get("event_id", 0),
					"common_event_id": context.get("common_id", 0),
					"command_index": int(context.get("index", 0)) + 1
				}
			}
		)
		if state.has_method("fatal_script_error"):
			state.fatal_script_error(error_text(checked))
		return checked
	if not context.has("owner") or not context.has("generation"):
		return {"ok": false, "message": "原生事件缺少调用归属。"}
	for stale in _native_tasks.keys():
		if not _native_tasks[stale].context.active():
			_native_tasks.erase(stale)
	var key = (
		"%d:%d:%d:%d:%s"
		% [
			context.owner.get_instance_id(),
			context.generation,
			context.get("index", 0),
			context.get("stack_depth", 0),
			binding.get("native_id", "")
		]
	)
	if not _native_tasks.has(key):
		var task = NativeTask.new()
		_native_tasks[key] = task
		task.start(checked.script, state, context, binding)
	if not _native_tasks.has(key):
		return {"ok": true, "cancelled": true, "value": null, "policy": {}}
	var task: RefCounted = _native_tasks[key]
	if not task.done:
		return {
			"ok": true,
			"pending": true,
			"value": null,
			"policy": {},
			"script_fields": context.get("fields", {})
		}
	var result: Dictionary = task.result
	_native_tasks.erase(key)
	result.policy = binding.get("policy", {"false_result_waits": false})
	if result.get("retry", false):
		result.policy = {"false_result_waits": true}
	if not result.ok and state.has_method("fatal_script_error"):
		state.fatal_script_error(error_text(result))
	return result


static func error_text(result: Dictionary) -> String:
	return (
		"%s / 源码 %s / L%d:C%d"
		% [
			result.get("message", "脚本执行失败"),
			JSON.stringify(result.get("origin", {})),
			result.get("span", {}).get("line", 0),
			result.get("span", {}).get("column", 0)
		]
	)


static func save_reason(state: Object) -> String:
	var pending = native_pending_reason(state)
	if not pending.is_empty():
		return pending
	var env: RefCounted = state.get("script_session")
	var roots = {
		"globals": env.globals if env != null else {},
		"constants": env.constants if env != null else {},
		"variables": state.variables,
		"custom_data": state.custom_data.values
	}
	return (
		preload("../Persistence/SaveGraph.gd").reason(roots)
		if state.custom_data.manifest.get("profile") == "flash"
		else preload("../../00_Game/CustomDataState.gd").plain_reason(roots)
	)


static func call_method(
	receiver: Dictionary, method: String, arguments: Array, state: Object
) -> Dictionary:
	var session: RefCounted = _session(state)
	if session == null:
		return {"ok": false, "message": "缺少脚本运行上下文。"}
	if not session.begin({"kind": "explicit_method", "method": method}):
		return session.failure
	var draft: Dictionary = receiver if session._direct else session.copy_value(receiver, [])
	if not session.failure.is_empty():
		return session.finish(null)
	var value: Variant = session.invoke(
		draft, method, arguments, draft.get("__ruby_class", draft.get("__ruby_type", "Object"))
	)
	var result: Dictionary = session.finish(value)
	if result.ok and not is_same(receiver, draft):
		receiver.clear()
		receiver.merge(draft)
	return _dispatch_external(result, state)


static func call_transaction(state: Object, context: Dictionary, operation: Callable) -> Dictionary:
	var session: RefCounted = _session(state)
	if session == null or not operation.is_valid():
		return {"ok": false, "message": "业务操作缺少脚本上下文。"}
	if not session.begin(context.merged({"kind": "explicit_action"})):
		return session.failure
	return _dispatch_external(session.finish(operation.call(session)), state)


static func _dispatch_external(result: Dictionary, state: Object) -> Dictionary:
	if not result.ok:
		return _script_result(result, state)
	if not str(result.get("history_request", "")).is_empty():
		var action = (
			state.flash_history.undo()
			if result.history_request == "undo"
			else state.flash_history.record()
		)
		if not action.ok:
			return _script_result(action, state)
		result.history_request = ""
	return _script_result(dispatch_snapshot_exports(result), state)


static func dispatch_snapshot_exports(result: Dictionary) -> Dictionary:
	if not result.ok:
		return result
	for request in result.get("snapshot_requests", []):
		var snapshot = (
			load("res://runtime/scripts/10_Support/Persistence/MapSnapshot.gd").new()
		)
		snapshot.set_scale(request.scale)
		snapshot.set_mode(request.mode)
		var args: Array = request.args.duplicate(true)
		if request.method == "snaps" and args[0] is Dictionary and args[0].has("__ruby_range"):
			var bounds: Dictionary = args[0].__ruby_range
			args[0] = range(
				int(bounds.first), int(bounds.last) + (0 if bounds.get("exclusive", false) else 1)
			)
		var exported: Dictionary = snapshot.callv(request.method, args)
		if not exported.ok:
			return {"ok": false, "message": exported.message, "origin": result.get("origin", {})}
	result.snapshot_requests = []
	return result


static func cancel_native(owner: Object) -> void:
	for key in _native_tasks.keys():
		if _native_tasks[key].context._owner.get_ref() == owner:
			_native_tasks.erase(key)


static func native_pending_reason(state: Object) -> String:
	for task in _native_tasks.values():
		if task.context.active() and is_same(task.context._state, state):
			return "原生 GDScript 正在 await 或等待解释器接收结果；请等待脚本完成后存档。"
	return ""


static func native_owner_pending(owner: Object) -> bool:
	for task in _native_tasks.values():
		if task.context.active() and task.context._owner.get_ref() == owner:
			return true
	return false


static func new_object(class_name_value: String, arguments: Array, state: Object) -> Dictionary:
	var session: RefCounted = _session(state)
	if session == null:
		return {"ok": false, "message": "缺少脚本运行上下文。"}
	if not session.begin({"kind": "explicit_constructor", "class": class_name_value}):
		return session.failure
	var value: Variant = session.invoke(session.type_ref(class_name_value), "new", arguments)
	return session.finish(value)


static func _session(state: Object) -> RefCounted:
	if state == null:
		return null
	if state.get("script_session") == null:
		var session = Semantics.new(state)
		var custom: Dictionary = Data.read_json("res://data/custom_data.json", {})
		session.globals = preload("../../00_Game/CustomDataState.gd").native_value(
			custom.get("globals", {})
		)
		session.constants = preload("../../00_Game/CustomDataState.gd").native_value(
			custom.get("constants", {})
		)
		state.set("script_session", session)
	var env: RefCounted = state.get("script_session")
	env.definition_loader = _load_definition.bind(weakref(env))
	return env


static func script_data(state: Object) -> Dictionary:
	var env: RefCounted = _session(state)
	if state.custom_data.manifest.get("profile") != "flash":
		return {"globals": env.globals.duplicate(true), "constants": env.constants.duplicate(true)}
	var hashes = {}
	for entry in env.methods.values():
		if (
			entry.get("path") is String
			and not hashes.has(entry.path)
			and FileAccess.file_exists(entry.path)
		):
			hashes[entry.path] = FileAccess.get_sha256(entry.path)
	return {
		"globals": env.globals,
		"constants": env.constants,
		"classes": env.classes,
		"methods": env.methods,
		"loaded_units": env.loaded_units,
		"generated_hashes": hashes,
		"regex": env._regex_data
	}


static func validate_saved_data(value: Dictionary) -> String:
	if not value.has("classes"):
		return ""
	if (
		not value.classes is Dictionary
		or not value.get("methods") is Dictionary
		or not value.get("loaded_units") is Dictionary
		or value.classes.size() > 10000
		or value.methods.size() > 50000
	):
		return "脚本定义快照无效。"
	for name in value.classes:
		var row: Variant = value.classes[name]
		if (
			not name is String
			or not row is Dictionary
			or row.get("kind") not in ["class", "module"]
			or not row.get("parent") is String
		):
			return "脚本类定义无效。"
		var cursor: String = name
		var seen = {}
		for i in 129:
			if cursor.is_empty():
				break
			if seen.has(cursor) or not value.classes.has(cursor):
				return "脚本继承关系无效。"
			seen[cursor] = true
			cursor = str(value.classes[cursor].get("parent", ""))
			if i == 128:
				return "脚本继承超过深度限制。"
	var units: Dictionary = Data.read_json("res://data/script_units.json", {}).get("units", {})
	for id in value.loaded_units:
		if (
			not id is String
			or units.get(id, {}).get("status") != "generated"
			or not value.loaded_units[id] is bool
		):
			return "脚本加载记录无效。"
	var checked_hashes: Dictionary = {}
	for key in value.methods:
		var method: Variant = value.methods[key]
		if (
			not key is String
			or not method is Dictionary
			or not method.get("path") is String
			or not method.get("function") is String
			or not method.get("owner") is String
			or not value.classes.has(method.owner)
		):
			return "脚本方法记录无效。"
		var path: String = method.path
		var id = path.get_file().trim_suffix(".gd")
		if (
			path != "res://runtime/generated/" + id + ".gd"
			or units.get(id, {}).get("status") != "generated"
			or units[id].get("generated_path") != path
		):
			return "脚本方法来源不属于生成工程。"
		var script: Script = load(path)
		if script == null or not script.has_method(method.function):
			return "存档脚本方法已经失效。"
		if value.has("generated_hashes"):
			if not checked_hashes.has(path):
				checked_hashes[path] = _compatible_program_hashes(path)
			if (
				not value.generated_hashes is Dictionary
				or not checked_hashes[path].has(value.generated_hashes.get(path))
			):
				return "存档方法的生成源码已经改变。"
	return ""


static func _compatible_program_hashes(path: String) -> Array:
	return ProgramDocs.source_hashes(FileAccess.get_file_as_string(path))


static func validate_saved_objects(value: Variant, classes: Dictionary, seen: Array = []) -> String:
	var index: Dictionary = {}
	for i in seen.size():
		preload("../Persistence/SaveGraph.gd")._remember(index, seen[i], i)
	return _validate_objects(value, classes, seen, index)


static func _validate_objects(
	value: Variant, classes: Dictionary, seen: Array, index: Dictionary
) -> String:
	if not value is Array and not value is Dictionary:
		return ""
	var graph = preload("../Persistence/SaveGraph.gd")
	var signature = graph._shape(value)
	if graph._find(index, value, signature) >= 0:
		return ""
	graph._remember(index, value, seen.size(), signature)
	seen.append(value)
	if value is Dictionary and value.has("__ruby_class"):
		if (
			not value.__ruby_class is String
			or not classes.has(value.__ruby_class)
			or not value.get("fields") is Dictionary
		):
			return "自定义对象的类或字段未绑定到已迁移定义。"
	for child in value if value is Array else value.values():
		if not child is Array and not child is Dictionary:
			continue
		var reason = _validate_objects(child, classes, seen, index)
		if not reason.is_empty():
			return reason
	return ""


static func evaluate_data_expression(id: String, state: Object) -> Dictionary:
	var unit: Dictionary = Data.read_json("res://data/custom_units.json", {}).get("units", {}).get(
		id, {}
	)
	if (
		unit.is_empty()
		or not unit.get("pure_expression", false)
		or unit.get("generated_path") != "res://runtime/generated/" + id + ".gd"
		or not id.begins_with("data_")
		or id.contains("/")
		or id.contains("..")
		or unit.get("status") != "generated"
		or unit.get("source_sha256") != str(unit.get("source", "")).sha256_text()
	):
		return {"ok": false, "message": "自定义表达式缺失或绑定过期：" + id}
	var env: RefCounted = _session(state)
	var key = "data:" + id
	if env.loading_units.has(key):
		env.fail("自定义数据表达式循环引用：" + id)
		return env.failure
	env.loading_units[key] = true
	if env._snapshot.is_empty() and not env._active:
		var result = execute_unit(id, state)
		env.loading_units.erase(key)
		return result
	var script: GDScript = load(unit.generated_path)
	if script == null:
		env.loading_units.erase(key)
		return {"ok": false, "message": "自定义表达式文件无法加载：" + id}
	var previous_origin: Dictionary = env.origin
	var previous_span: Dictionary = env.span
	env.origin = unit.get("origin", {})
	var value: Variant = script.program(env)
	env.origin = previous_origin
	env.span = previous_span
	env.loading_units.erase(key)
	return env.failure if not env.failure.is_empty() else {"ok": true, "value": value}


static func _load_definition(
	name: String, owner: String, singleton: bool, session: WeakRef
) -> void:
	var env: RefCounted = session.get_ref()
	if env == null:
		return
	var registry: Dictionary = Data.read_json("res://data/script_units.json", {})
	for id in _definition_candidates(name, owner, singleton, registry):
		var unit: Dictionary = registry.units[id]
		if env.loaded_units.has(id):
			continue
		if unit.origin.kind != "script":
			continue
		var definitions: Dictionary = unit.get("definitions", {})
		var matches: bool = _definitions_match(definitions, name, owner, singleton)
		if not matches or env.loaded_units.has(id):
			continue
		if unit.get("status") != "generated" or not definitions.get("safe", false):
			env.fail("依赖脚本尚未迁移或含未接入的初始化：%s / %s" % [id, JSON.stringify(unit.origin)])
			return
		if env.loading_units.has(id):
			if owner.is_empty() and env.classes.has(name):
				continue
			env.fail("脚本定义依赖循环：" + id)
			return
		env.loading_units[id] = true
		var script: GDScript = Semantics.program(unit.generated_path)
		var previous_origin: Dictionary = env.origin
		var previous_span: Dictionary = env.span
		var previous_context: Dictionary = env.execution_context
		env.origin = unit.origin
		env.execution_context = {}
		if script != null and script.has_method("program"):
			script.program(env)
		else:
			env.fail("依赖生成文件无法加载：" + id)
		env.origin = previous_origin
		env.span = previous_span
		env.execution_context = previous_context
		env.loading_units.erase(id)
		if not env.failure.is_empty():
			return
		env.loaded_units[id] = true


static func _definitions_match(
	definitions: Dictionary, name: String, owner: String, singleton: bool
) -> bool:
	if owner.is_empty():
		if name in definitions.get("types", []) or name in definitions.get("constants", []):
			return true
		for type_name in definitions.get("types", []):
			if name.begins_with(type_name + "::"):
				return true
		return false
	for method in definitions.get("methods", []):
		if method.name != name or method.singleton != singleton:
			continue
		if method.owner == owner:
			return true
		if method.owner != "*":
			continue
		# Failed AST units still block matching owners; unrelated constructors
		# must not override methods of separately declared classes.
		var candidates: Array = method.get("owner_candidates", [])
		if (
			owner == "Object"
			or candidates.is_empty()
			or owner in candidates
			or owner.get_slice("::", owner.get_slice_count("::") - 1) in candidates
		):
			return true
	return false

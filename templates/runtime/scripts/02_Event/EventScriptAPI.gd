## 职责：为事件业务正文提供游戏对象、集合、数值与来源管理接口，复用当前运行状态。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/02_Event/EventScriptAPI.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(context: RefCounted) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 context（RefCounted；必填）：当前事件或脚本执行上下文。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func boxed(value: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func raw(value: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func operation(kind: String, arguments: Array) -> Variant
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 arguments（Array；必填）：按声明顺序传入的参数列表。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func named(name: String) -> Variant
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func write(name: String, value: Variant) -> Variant
##     用途：写入指定文件或目标数据。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func invoke(receiver: Variant, method: String, arguments: Array = []) -> Variant
##     用途：按给定名称和参数分派对应调用。
##     参数 receiver（Variant；必填）：方法调用的接收者。
##     参数 method（String；必填）：需要查询、登记或调用的方法名称。
##     参数 arguments（Array；默认值 []）：按声明顺序传入的参数列表。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func root_call(method: String, arguments: Array = []) -> Variant
##     参数 method（String；必填）：需要查询、登记或调用的方法名称。
##     参数 arguments（Array；默认值 []）：按声明顺序传入的参数列表。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func at(receiver: Variant, indexes: Array) -> Variant
##     参数 receiver（Variant；必填）：方法调用的接收者。
##     参数 indexes（Array；必填）：需要处理的索引集合。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func put(receiver: Variant, index: Variant, value: Variant) -> Variant
##     参数 receiver（Variant；必填）：方法调用的接收者。
##     参数 index（Variant；必填）：集合或列表中的位置索引。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func binary(operator: String, left: Variant, right: Variant) -> Variant
##     参数 operator（String；必填）：原脚本运算符名称。
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func truth(value: Variant) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func iterable(value: Variant) -> Array
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func regex(pattern: String, flags: String = "") -> Variant
##     参数 pattern（String；必填）：匹配模式或图形帧编号。
##     参数 flags（String；默认值 ""）：组合标志位或选项标志集合。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func text(value: Variant) -> String
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func integer(value: Variant) -> int
##     用途：检查数值是否为允许范围内的有效整数。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func contains(value: Variant, item: Variant) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 item（Variant；必填）：物品、列表项或树节点，具体类型见签名。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func maximum(value: Array) -> Variant
##     参数 value（Array；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func split(value: Variant, separator: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 separator（Variant；必填）：字符串分隔文本或已编译的正则描述。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func attribute(name: Variant) -> Variant
##     参数 name（Variant；必填）：对象、资源或字段名称。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func set_attribute(name: Variant, value: Variant) -> Variant
##     参数 name（Variant；必填）：对象、资源或字段名称。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func name_value(value: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func add(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func subtract(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func multiply(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func greater(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func at_least(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func equal(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func case_equal(left: Variant, right: Variant) -> Variant
##     参数 left（Variant；必填）：左侧操作数或区域左边界。
##     参数 right（Variant；必填）：右侧操作数或区域右边界。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted
const Value = preload("EventScriptValue.gd")
var _context: WeakRef


func _init(context: RefCounted) -> void:
	_context = weakref(context)


func boxed(value: Variant) -> Variant:
	return Value.new(self, value) if value is Dictionary or value is Array else value


func raw(value: Variant) -> Variant:
	if value is Value:
		return value._value
	if value is Array and value.any(func(item): return item is Value):
		return value.map(func(item): return raw(item))
	return value


func operation(kind: String, arguments: Array) -> Variant:
	var ctx: RefCounted = _context.get_ref()
	if ctx == null or not ctx.active():
		return null
	var runtime: Script = load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
	var env: RefCounted = runtime._session(ctx._state)
	var previous: Dictionary = env.execution_context
	env.execution_context = ctx._execution.merged({"policy": ctx.result.policy})
	if not env.begin(ctx._origin):
		ctx.result = env.failure
		env.execution_context = previous
		return null
	var args = arguments.map(func(item): return raw(item))
	var value: Variant = null
	match kind:
		"named":
			value = env.read_name(str(args[0]), {}, env.root_receiver(), "Object")
		"write":
			value = env.write_name(str(args[0]), args[1], {}, env.root_receiver(), "Object")
		"call":
			value = env.invoke(args[0], str(args[1]), args[2].map(func(item): return raw(item)))
		"root":
			value = env.invoke(
				env.root_receiver(), str(args[0]), args[1].map(func(item): return raw(item))
			)
		"index":
			value = env.indexes_get(args[0], args[1].map(func(item): return raw(item)))
		"put":
			value = env.index_set(args[0], args[1], args[2])
		"binary":
			value = env.binary(str(args[0]), args[1], args[2])
		"unary":
			value = env.unary(str(args[0]), args[1])
		"regex":
			value = env.regex_value(str(args[0]), str(args[1]))
		"attribute_read":
			value = env.flash_attribute_read(args[0])
		"attribute_write":
			value = env.flash_attribute_write(args[0], args[1])
		"name_value":
			value = env.flash_name_value(args[0])
		"iterable":
			value = env.iterable(args[0])
		"actor_preset":
			value = env._custom.gameplay().apply_actor_preset(int(args[0]), int(args[1]))
		_:
			env.fail("未知事件业务接口：" + kind)
	if not env.failure.is_empty() or env._custom != null and not env._custom.failure.is_empty():
		env.span = _source_span(ctx)
	var completed: Dictionary = env.finish(value)
	env.execution_context = previous
	if not completed.ok:
		ctx.result = completed
		return null
	for key in completed:
		if key in ["value", "policy", "wait_seconds", "common_event_id"]:
			continue
		if key.ends_with("request") or key.ends_with("requests"):
			var request: Variant = completed[key]
			if request is int and request == 0 or request is String and request.is_empty():
				continue
			if request is Array and not request.is_empty():
				ctx.result[key] = ctx.result.get(key, []) + request
				continue
			if (
				request == null
				or request is Dictionary and request.is_empty()
				or request is Array and request.is_empty()
			):
				continue
		ctx.result[key] = completed[key]
	if float(completed.get("wait_seconds", 0)) > 0:
		ctx.result.wait_seconds = completed.wait_seconds
	if int(completed.get("common_event_id", 0)) > 0:
		ctx.result.common_event_id = completed.common_event_id
	return boxed(value)


func _source_span(context: RefCounted) -> Dictionary:
	var path = str(context._execution.get("native_path", ""))
	for trace in Engine.capture_script_backtraces():
		for index in trace.get_frame_count():
			if trace.get_frame_file(index) == path:
				var offset = int(preload("NativeScriptSource.gd")._line_offsets.get(path, 0))
				return {"line": maxi(1, trace.get_frame_line(index) - offset), "column": 1}
	return {}


func named(name: String) -> Variant:
	return operation("named", [name])


func write(name: String, value: Variant) -> Variant:
	return operation("write", [name, value])


func invoke(receiver: Variant, method: String, arguments: Array = []) -> Variant:
	return operation("call", [receiver, method, arguments])


func root_call(method: String, arguments: Array = []) -> Variant:
	return operation("root", [method, arguments])


func at(receiver: Variant, indexes: Array) -> Variant:
	return operation("index", [receiver, indexes])


func put(receiver: Variant, index: Variant, value: Variant) -> Variant:
	return operation("put", [receiver, index, value])


func binary(operator: String, left: Variant, right: Variant) -> Variant:
	return operation("binary", [operator, left, right])


func truth(value: Variant) -> bool:
	return preload("../10_Support/Scripting/ScriptSemantics.gd").truth(raw(value))


func iterable(value: Variant) -> Array:
	var entries: Variant = operation("iterable", [value])
	var items: Variant = raw(entries)
	return items.map(func(item): return boxed(item)) if items is Array else []


func regex(pattern: String, flags: String = "") -> Variant:
	return operation("regex", [pattern, flags])


func text(value: Variant) -> String:
	return str(raw(value)) if value != null else ""


func integer(value: Variant) -> int:
	return int(raw(operation("call", [value, "to_i", []])))


func contains(value: Variant, item: Variant) -> bool:
	return truth(invoke(value, "include?", [item]))


func maximum(value: Array) -> Variant:
	return invoke(value, "max")


func split(value: Variant, separator: Variant) -> Variant:
	return invoke(value, "split", [separator])


func attribute(name: Variant) -> Variant:
	return operation("attribute_read", [name])


func set_attribute(name: Variant, value: Variant) -> Variant:
	return operation("attribute_write", [name, value])


func name_value(value: Variant) -> Variant:
	return operation("name_value", [value])


func add(left: Variant, right: Variant) -> Variant:
	return binary("+", left, right)


func subtract(left: Variant, right: Variant) -> Variant:
	return binary("-", left, right)


func multiply(left: Variant, right: Variant) -> Variant:
	return binary("*", left, right)


func greater(left: Variant, right: Variant) -> Variant:
	return binary(">", left, right)


func at_least(left: Variant, right: Variant) -> Variant:
	return binary(">=", left, right)


func equal(left: Variant, right: Variant) -> Variant:
	return binary("==", left, right)


func case_equal(left: Variant, right: Variant) -> Variant:
	return binary("===", left, right)

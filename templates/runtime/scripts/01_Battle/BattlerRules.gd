## 职责：实现闪翼战斗单位的属性、抗性和能力规则，保持原脚本计算约定。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/01_Battle/BattlerRules.gd").方法名(...)。
##
## 调用接口：
##   static func parameter( base: Variant, plus: Variant, key: String, states: Array, record: Callable ) -> int
##     参数 base（Variant；必填）：计算前的基础值。
##     参数 plus（Variant；必填）：附加的属性增量。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 states（Array；必填）：状态记录或状态集合。
##     参数 record（Callable；必填）：数据库、来源或运行记录。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func resist(base: Array, plus: Array, states: Array, record: Callable) -> Array
##     参数 base（Array；必填）：计算前的基础值。
##     参数 plus（Array；必填）：附加的属性增量。
##     参数 states（Array；必填）：状态记录或状态集合。
##     参数 record（Callable；必填）：数据库、来源或运行记录。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func change( current: Dictionary, ids: Array, adding: bool, force: bool, parameter_getter: Callable, record: Callable ) -> Dictionary
##     参数 current（Dictionary；必填）：当前值、对象或状态。
##     参数 ids（Array；必填）：待处理对象的编号集合。
##     参数 adding（bool；必填）：是否处于新增模式。
##     参数 force（bool；必填）：是否请求强制执行；仍受接口自身校验约束。
##     参数 parameter_getter（Callable；必填）：读取角色指定属性的回调。
##     参数 record（Callable；必填）：数据库、来源或运行记录。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func query(states: Array, name: String, record: Callable) -> Variant
##     参数 states（Array；必填）：状态记录或状态集合。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 record（Callable；必填）：数据库、来源或运行记录。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 公开常量：KEYS。
## 接口说明结束。

extends RefCounted
## Source 0065–0067, shared by actor and map-enemy adapters.
## State operations work on a detached value and commit only after validation.
const Fields = preload("../00_Game/ActorFields.gd")
const KEYS = ["maxhp", "maxsp", "patk", "pdef", "matk", "mdef", "agi", "int"]


static func parameter(
	base: Variant, plus: Variant, key: String, states: Array, record: Callable
) -> int:
	var value: float = maxf(float(base) + float(plus), 0)
	var cap = 999999 if key == "maxsp" else 99999
	if key != "maxhp":
		value = minf(value, cap)
	var rate = "atk_rate" if key in ["patk", "matk"] else key + "_rate"
	for id in states:
		value *= float(record.call(int(id)).get(rate, 100)) / 100.0
	return maxi(int(value), 0) if key == "maxhp" else clampi(int(value), 0, cap)


static func resist(base: Array, plus: Array, states: Array, record: Callable) -> Array:
	var result: Array = []
	for i in 5:
		result.append(clampf(float(base[i]) + float(plus[i]), 0, 100))
	for id in states:
		var definition: Dictionary = record.call(int(id))
		for i in 3:
			result[i] *= float(definition.get(["hit_rate", "str_rate", "dex_rate"][i], 100)) / 100.0
	for i in 5:
		result[i] = clampf(result[i], 0, 100)
	return result


static func change(
	current: Dictionary,
	ids: Array,
	adding: bool,
	force: bool,
	parameter_getter: Callable,
	record: Callable
) -> Dictionary:
	var work = current.duplicate(true)
	work["steps"] = 0
	work["reason"] = ""
	for raw in ids:
		if not raw is int or raw <= 0:
			return {"ok": false, "message": "状态编号必须为正整数。"}
		var accepted = (
			_add(work, raw, force, parameter_getter, record)
			if adding
			else _remove(work, raw, parameter_getter, record)
		)
		if not accepted:
			return {"ok": false, "message": work.reason}
	work.erase("steps")
	work.erase("reason")
	return {"ok": true, "state": work}


static func query(states: Array, name: String, record: Callable) -> Variant:
	if name == "state_animation_id":
		return 0 if states.is_empty() else record.call(int(states[0])).get("animation_id", 0)
	if name == "restriction":
		var result = 0
		for id in states:
			result = maxi(result, int(record.call(int(id)).get("restriction", 0)))
		return result
	for id in states:
		if record.call(int(id)).get(name.trim_suffix("?"), false):
			return true
	return false


static func _step(work: Dictionary) -> bool:
	work.steps += 1
	if work.steps <= 1024:
		return true
	work.reason = "闪翼状态关联超过执行预算；未提交状态。"
	return false


static func _add(
	work: Dictionary, id: int, force: bool, getter: Callable, record: Callable
) -> bool:
	if not _step(work):
		return false
	var definition: Dictionary = record.call(id)
	# Source add_state returns for an absent database record.
	if definition.is_empty():
		return true
	for field in ["plus_state_set", "minus_state_set"]:
		if not definition.get(field, []) is Array:
			work.reason = "状态关联必须为编号数组。"
			return false
	if not force:
		for existing in work.states:
			if (
				record.call(int(existing)).get("minus_state_set", []).has(id)
				and not definition.get("minus_state_set", []).has(existing)
			):
				return true
	if not work.states.has(id):
		work.states.append(id)
		if definition.get("zero_hp", false):
			work.hp = 0
		var links: Array = definition.get("plus_state_set", []).duplicate()
		for raw in definition.get("minus_state_set", []):
			if not links.has(raw):
				links.append(raw)
		for raw in links:
			if not raw is int or raw <= 0 or record.call(raw).is_empty():
				work.reason = "状态关联引用不存在。"
				return false
		links.sort()
		for linked in links:
			if (
				definition.get("plus_state_set", []).has(linked)
				and not _add(work, linked, false, getter, record)
			):
				return false
			if (
				definition.get("minus_state_set", []).has(linked)
				and not _remove(work, linked, getter, record)
			):
				return false
		work.states.sort_custom(
			func(a, b):
				var left: Dictionary = record.call(int(a))
				var right: Dictionary = record.call(int(b))
				if left.get("rating", 0) != right.get("rating", 0):
					return left.get("rating", 0) > right.get("rating", 0)
				if left.get("restriction", 0) != right.get("restriction", 0):
					return left.get("restriction", 0) > right.get("restriction", 0)
				return a < b
		)
	return _clamp(work, getter)


static func _remove(work: Dictionary, id: int, getter: Callable, record: Callable) -> bool:
	if not _step(work):
		return false
	if work.states.has(id):
		if work.hp == 0 and record.call(id).get("zero_hp", false):
			var other_zero = false
			for existing in work.states:
				if existing != id and record.call(int(existing)).get("zero_hp", false):
					other_zero = true
			if not other_zero:
				work.hp = 1
		work.states.erase(id)
	return _clamp(work, getter)


static func _clamp(work: Dictionary, getter: Callable) -> bool:
	var maxhp: Variant = getter.call("maxhp", work.states)
	var maxsp: Variant = getter.call("maxsp", work.states)
	if not Fields.number(maxhp) or not Fields.number(maxsp):
		work.reason = "状态变更后无法计算生命/魔力上限。"
		return false
	work.hp = min(work.hp, maxhp)
	work.sp = min(work.sp, maxsp)
	return true

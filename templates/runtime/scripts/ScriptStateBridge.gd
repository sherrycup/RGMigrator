extends RefCounted
## Small, explicit bridge to the existing state. Validate the whole unit first.
static func apply(state: Object, operations: Array, origin: Dictionary = {}) -> Dictionary:
	if state == null or not state.has_method("set_event_variable") or not state.has_method("set_event_switch"):
		return _fail("脚本缺少有效 RuntimeState。", origin)
	if not state.get("variables") is Dictionary or not state.get("switches") is Dictionary:
		return _fail("脚本状态缺少原生开关/变量表。", origin)
	var pending := {}; var writes: Array = []; var result: Variant = null
	for operation in operations:
		if not operation is Dictionary or operation.get("operation") != "state_write" or operation.get("target") not in ["variable", "switch"]:
			return _fail("脚本IR操作无效。", origin)
		var raw_id: Variant = operation.get("id")
		if not _integer(raw_id) or raw_id <= 0 or raw_id > 2147483647: return _fail("脚本状态编号无效。", origin, operation)
		var id := int(raw_id); var target: String = operation.target; var op: String = operation.get("operator", "")
		var value: Variant = operation.get("value"); var key := "%s:%d" % [target,id]
		if target == "switch":
			if not value is bool or op != "=": return _fail("脚本开关值或操作无效。", origin, operation)
		else:
			if not _integer(value) or abs(value) > 2147483647 or op not in ["=", "+=", "-="]: return _fail("脚本变量值或操作无效。", origin, operation)
			value = int(value)
			if op != "=":
				var previous: Variant = pending.get(key, state.variables.get(str(id), 0))
				if not _integer(previous) or abs(previous) > 2147483647: return _fail("原变量超出0.40整数转换范围。", origin, operation)
				value = int(previous) + (value if op == "+=" else -value)
				if abs(value) > 2147483647: return _fail("脚本整数计算超出0.40范围；未写入任何状态。", origin, operation)
		pending[key] = value; result = value; writes.append({"target": target, "id": id, "value": value})
	for write in writes:
		if write.target == "switch": state.set_event_switch(write.id, write.value)
		else: state.set_event_variable(write.id, write.value)
	return {"ok": true, "value": result, "writes": writes.size(), "origin": origin}

static func _integer(value: Variant) -> bool:
	return value is int or value is float and is_finite(value) and value == floor(value)

static func _fail(message: String, origin: Dictionary, operation: Dictionary = {}) -> Dictionary:
	return {"ok": false, "message": message, "origin": origin, "span": operation.get("span", {})}

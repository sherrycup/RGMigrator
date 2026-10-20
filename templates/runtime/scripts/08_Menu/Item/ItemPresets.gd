## 职责：解析闪翼物品分类和预设信息，为物品页面与效果处理提供规则。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/Item/ItemPresets.gd").方法名(...)。
##
## 调用接口：
##   static func variable_id(state: Object) -> int
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func slots(state: Object) -> Array
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func normalize(state: Object) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func set_slot(state: Object, slot: int, item_id: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     参数 item_id（int；必填）：物品的原数据库编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func native_item(id: int, state: Object) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func category(item: Dictionary) -> String
##     参数 item（Dictionary；必填）：物品、列表项或树节点，具体类型见签名。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 接口说明结束。

extends RefCounted
## Source 0183 normalized_config/set/set_null; one saved variable4 hash.
const Scripts = preload("../../10_Support/Scripting/ScriptRuntime.gd")
const Data = preload("../../00_Game/RuntimeData.gd")


static func variable_id(state: Object) -> int:
	return int(state.custom_data.gameplay().rules.constants.get("ITEM_CONFIG", 4))


static func slots(state: Object) -> Array:
	var value: Variant = state.variables.get(str(variable_id(state)), {})
	var result: Array = []
	for slot in range(1, 10):
		var pair: Variant = (
			value.get("__ruby_hash", {}).get(str(TYPE_INT) + ":" + str(slot))
			if value is Dictionary and value.has("__ruby_hash")
			else value.get(str(slot), value.get(slot)) if value is Dictionary else null
		)
		var id = (
			int(pair[0])
			if (
				pair is Array
				and not pair.is_empty()
				and (pair[0] is int or pair[0] is float or pair[0] is String)
			)
			else 0
		)
		result.append([id, state.inventory_count("item", id) if id > 0 else 0])
	return result


static func normalize(state: Object) -> Dictionary:
	var value: Variant = state.variables.get(str(variable_id(state)))
	if value is Dictionary and value.has("__ruby_hash"):
		var current = slots(state)
		var same = true
		for slot in range(1, 10):
			if value.__ruby_hash.get(str(TYPE_INT) + ":" + str(slot)) != current[slot - 1]:
				same = false
				break
		if same:
			return {"ok": true, "changed": false}
	return _update(state, 0, -1)


static func set_slot(state: Object, slot: int, item_id: int) -> Dictionary:
	if slot < 1 or slot > 9 or item_id < 0:
		return {"ok": false, "message": "物品槽位或编号无效。"}
	if item_id > 0 and state.inventory_count("item", item_id) <= 0:
		return {"ok": false, "message": "背包没有该物品。"}
	return _update(state, slot, item_id)


static func _update(state: Object, selected: int, id: int) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0183.normalized_config/set/set_null"},
		func(env):
			var key = variable_id(state)
			var config: Variant = env._variables.get(str(key))
			if not config is Dictionary or not config.has("__ruby_hash"):
				config = env.hash_pairs([])
			for slot in range(1, 10):
				var pair: Variant = env.index_get(config, slot)
				var item = (
					int(pair[0])
					if (
						pair is Array
						and not pair.is_empty()
						and (pair[0] is int or pair[0] is float or pair[0] is String)
					)
					else 0
				)
				if slot == selected:
					item = id
				var amount = int(env._custom.party_call("item_number", [item])) if item > 0 else 0
				env.index_set(config, slot, [item, amount])
			return env.index_set({"__state_table": "variable"}, key, config)
	)


static func native_item(id: int, state: Object) -> Dictionary:
	# RPG::Item is separate from the external Game_Item wrapper. Undo only that
	# wrapper's import overlay; current explicit database edits still take priority.
	var source = Data.source_record("Items", id)
	var result = source.duplicate(true)
	for field in source.get("_custom_data", {}).get("original_fields", {}):
		var original: Dictionary = source._custom_data.original_fields[field]
		if original.get("present", false):
			result[field] = original.value
		else:
			result.erase(field)
	result.merge(state.custom_data.values.records.get("Items:" + str(id), {}), true)
	return result


static func category(item: Dictionary) -> String:
	var parts = str(item.get("description", "")).split("@", true)
	var value = str(parts[1]) if parts.size() > 1 else "普通物品"
	var pattern = RegEx.new()
	pattern.compile("\\s")
	return pattern.sub(value, "", true)

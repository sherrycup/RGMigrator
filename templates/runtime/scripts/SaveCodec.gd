extends RefCounted
## Snapshot validation is detached from live state, including the testing overlay.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Actor = preload("res://runtime/scripts/ActorState.gd")
const Screen = preload("res://runtime/scripts/ScreenState.gd")
const Motion = preload("res://runtime/scripts/CharacterMotion.gd")
const MapView = preload("res://runtime/scripts/MapViewState.gd")
const Effects = preload("res://runtime/scripts/MapEffectsState.gd")
const Countdown = preload("res://runtime/scripts/GameTimer.gd")
const MAX_INTEGER := 9007199254740991


static func integer(value: Variant, minimum: int = 0, maximum: int = MAX_INTEGER) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and floor(float(value)) == float(value)


static func capture(state: Node) -> Dictionary:
	var actors: Array = []
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		actors.append(state.actors[id].persistent_data())
	return {"map_id": state.map_id, "player_x": state.player_x, "player_y": state.player_y, "player_direction": state.player_direction,
		"gold": state.gold, "steps": state.steps, "play_seconds": state.play_seconds, "party": state.party.duplicate(), "actors": actors,
		"switches": state.switches.duplicate(true), "variables": state.variables.duplicate(true), "self_switches": state.self_switches.duplicate(true),
		"inventory": state.inventory.duplicate(true), "save_disabled": state.save_disabled, "menu_disabled": state.menu_disabled,
		"testing": Data.testing_snapshot(), "screen": state.screen.snapshot(), "player_options": state.player_motion.options.duplicate(),
		"map_view": state.map_view.snapshot(), "map_effects": state.map_effects.snapshot(), "timer": state.timer.snapshot()}


static func prepare(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return fail("进度必须是对象。")
	var saved: Dictionary = value.duplicate(true)
	for field in ["map_id", "player_x", "player_y", "player_direction", "gold", "steps"]:
		if not integer(saved.get(field)):
			return fail("%s 必须为有效整数。" % field)
		saved[field] = int(saved[field])
	if saved.player_direction not in [2, 4, 6, 8]:
		return fail("角色朝向无效。")
	var player_options: Variant = saved.get("player_options", Motion.DEFAULTS.duplicate())
	if not Motion.validate(player_options, true): return fail("人物移动/显示参数无效。")
	saved.player_options = player_options.duplicate()
	if not saved.get("play_seconds") is float and not saved.get("play_seconds") is int:
		return fail("游戏时间必须为数字。")
	if not is_finite(float(saved.play_seconds)) or saved.play_seconds < 0 or saved.play_seconds > MAX_INTEGER:
		return fail("游戏时间无效。")
	for field in ["save_disabled", "menu_disabled"]:
		if not saved.get(field) is bool:
			return fail("%s 必须为布尔值。" % field)
	var map := Data.map(int(saved.map_id))
	if map.is_empty() or saved.player_x >= int(map.get("width", 0)) or saved.player_y >= int(map.get("height", 0)):
		return fail("Map%03d 不存在或角色坐标越界。" % saved.map_id)
	var overlay := testing_records(saved.get("testing"))
	if not overlay.ok:
		return overlay
	var records: Dictionary = overlay.records
	var lookup := func(database: String, id: int) -> Dictionary: return records.get("%s:%d" % [database, id], Data.source_record(database, id))
	if not saved.get("actors") is Array or saved.actors.size() > 10000:
		return fail("角色列表无效。")
	var actors := {}
	for entry in saved.actors:
		if not entry is Dictionary or not integer(entry.get("id"), 1) or actors.has(int(entry.id)):
			return fail("角色 ID 无效或重复。")
		var id := int(entry.id)
		if Data.source_record("Actors", id).is_empty() or not integer(entry.get("class_id"), 1) or Data.source_record("Classes", int(entry.class_id)).is_empty():
			return fail("Actors[%d] 或其职业引用不存在。" % id)
		if not entry.get("name") is String or entry.name.length() > 1024:
			return fail("Actors[%d].name 无效。" % id)
		for field in ["level", "experience", "hp", "sp"]:
			if not integer(entry.get(field)):
				return fail("Actors[%d].%s 无效。" % [id, field])
		if not entry.get("equipment") is Array or entry.equipment.size() != 5:
			return fail("Actors[%d] 必须包含五个装备槽。" % id)
		for slot in 5:
			var equipment: Variant = entry.equipment[slot]
			if not integer(equipment):
				return fail("Actors[%d] 装备 ID 无效。" % id)
			if equipment != 0:
				var definition: Dictionary = lookup.call("Weapons" if slot == 0 else "Armors", int(equipment))
				if definition.is_empty() or (slot > 0 and int(definition.get("kind", -1)) != slot - 1):
					return fail("Actors[%d] 第 %d 槽装备引用无效。" % [id, slot + 1])
		for field in ["skill_ids", "state_ids"]:
			var reason := id_list(entry.get(field), "Skills" if field == "skill_ids" else "States", lookup)
			if not reason.is_empty():
				return fail("Actors[%d].%s：%s" % [id, field, reason])
		# Additive extension of schema 1: old ver0.14/0.15 saves have zero
		# actor bonuses and database graphics. Never infer bonuses from equipment.
		if entry.has("parameter_plus"):
			if not entry.parameter_plus is Dictionary or entry.parameter_plus.size() != Actor.Parameters.KEYS.size():
				return fail("Actors[%d].parameter_plus 必须包含九个属性修正。" % id)
			for key in Actor.Parameters.KEYS:
				if not integer(entry.parameter_plus.get(key), -Actor.Parameters.maximum(key), Actor.Parameters.maximum(key)):
					return fail("Actors[%d].%s_plus 无效。" % [id, key])
				entry.parameter_plus[key] = int(entry.parameter_plus[key])
		for field in ["character_name", "character_hue"]:
			if not entry.has(field):
				continue
			if field == "character_name" and (not entry[field] is String or entry[field].length() > 1024):
				return fail("Actors[%d].character_name 无效。" % id)
			if field == "character_hue" and not integer(entry[field], 0, 360):
				return fail("Actors[%d].character_hue 无效。" % id)
		var instance := Actor.new()
		instance.configure(id, Data.source_record("Actors", id), lookup)
		var reason := instance.restore_persistent(entry)
		if not reason.is_empty():
			return fail("Actors[%d]：%s" % [id, reason])
		actors[id] = instance
	var party_reason := id_list(saved.get("party"), "Actors", lookup)
	if not party_reason.is_empty():
		return fail("队伍：" + party_reason)
	for index in saved.party.size():
		saved.party[index] = int(saved.party[index])
		if not actors.has(saved.party[index]):
			return fail("队伍角色缺少运行状态。")
	for field in ["switches", "variables", "self_switches", "inventory"]:
		if not saved.get(field) is Dictionary or saved[field].size() > 100000:
			return fail("%s 必须是有效字典。" % field)
		for key in saved[field]:
			var entry: Variant = saved[field][key]
			if not key is String:
				return fail("%s 的键必须为字符串。" % field)
			if field == "inventory":
				var database: String = {"item": "Items", "weapon": "Weapons", "armor": "Armors"}.get(key.get_slice(":", 0), "")
				if key.get_slice_count(":") != 2 or database.is_empty() or not positive_key(key.get_slice(":", 1)) or lookup.call(database, int(key.get_slice(":", 1))).is_empty() or not integer(entry, 0, 99):
					return fail("背包引用或数量无效：" + key)
				saved.inventory[key] = int(entry)
			elif field == "self_switches":
				if key.get_slice_count(":") != 3 or not positive_key(key.get_slice(":", 0)) or not positive_key(key.get_slice(":", 1)) or key.get_slice(":", 2) not in ["A", "B", "C", "D"] or not entry is bool:
					return fail("独立开关无效：" + key)
				var event_map := Data.map(int(key.get_slice(":", 0)))
				if not event_map.get("events", {}).has(key.get_slice(":", 1)):
					return fail("独立开关地图/事件引用不存在：" + key)
			else:
				if not positive_key(key) or (field == "switches" and not entry is bool):
					return fail("开关/变量无效：" + key)
				if field == "variables" and not integer(entry, -MAX_INTEGER):
					return fail("变量必须是有效整数：" + key)
				if field == "variables":
					saved.variables[key] = int(entry)
	# Additive schema-1 field: old native saves default to an empty neutral screen.
	var screen_value: Variant = saved.get("screen", Screen.new().snapshot())
	var screen_result := Screen.decode(screen_value)
	if not screen_result.ok: return fail(screen_result.message)
	for entry in screen_value.pictures:
		if entry.name.begins_with("@test_") and not saved.testing.enabled:
			return fail("正式存档包含测试图片。")
	saved.screen = screen_result.screen.snapshot()
	var extensions := {}
	for entry in [["map_view", MapView], ["map_effects", Effects], ["timer", Countdown]]:
		var script: Script = entry[1]
		var result: Dictionary = script.decode(saved.get(entry[0], script.new().snapshot()))
		if not result.ok: return fail(result.message)
		extensions[entry[0]] = result.value
	if int(extensions.map_effects.data.map_id) not in [0, saved.map_id]: return fail("地图表现所属地图与进度不一致。")
	return {"ok": true, "state": saved, "actors": actors, "test_records": records, "screen": screen_result.screen,
		"map_view": extensions.map_view, "map_effects": extensions.map_effects, "timer": extensions.timer}


static func testing_records(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("enabled") is bool or not value.get("definitions") is Dictionary:
		return fail("测试模式信息无效。")
	if not value.enabled:
		return {"ok": true, "records": {}} if value.definitions.is_empty() else fail("非测试存档包含测试定义。")
	# Only definitions matter, not current enabled/stock/HP ratios. Restore grants exactly once.
	var raw: Variant = Data.test_config().get("definitions", {})
	if not raw is Dictionary:
		return fail("当前测试定义不是有效对象。")
	var expected: Dictionary = raw.duplicate(true)
	for database in expected.keys():
		if expected[database] is Array and expected[database].is_empty():
			expected.erase(database)
	if expected.is_empty() or JSON.stringify(value.definitions, "", true) != JSON.stringify(expected, "", true):
		return fail("测试定义已修改或不存在，不能恢复此测试存档。")
	var records := {}
	for database in value.definitions:
		if database not in ["Items", "Weapons", "Armors", "Skills", "Animations", "States"] or not value.definitions[database] is Array:
			return fail("测试定义类型无效。")
		for definition in value.definitions[database]:
			if not definition is Dictionary or not integer(definition.get("id"), 1) or not Data.source_record(database, int(definition.id)).is_empty():
				return fail("测试定义 ID 无效或冲突。")
			var key := "%s:%d" % [database, definition.id]
			if records.has(key):
				return fail("测试定义 ID 重复。")
			records[key] = definition.duplicate(true)
	return {"ok": true, "records": records}


static func id_list(value: Variant, database: String, lookup: Callable) -> String:
	if not value is Array or value.size() > 10000:
		return "必须是 ID 数组。"
	var seen := {}
	for id in value:
		if not integer(id, 1) or seen.has(int(id)) or lookup.call(database, int(id)).is_empty():
			return "存在无效、重复或缺失的 ID。"
		seen[int(id)] = true
	return ""


static func positive_key(key: String) -> bool:
	return key.length() <= 16 and key.is_valid_int() and key == str(int(key)) and integer(int(key), 1)


static func fail(message: String) -> Dictionary:
	return {"ok": false, "message": "存档数据：" + message}

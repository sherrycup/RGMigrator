extends RefCounted
## Pure parameter calculation. Equipment bonuses are never stored as actor bonuses.
const KEYS := ["maxhp", "maxsp", "str", "dex", "agi", "int", "atk", "pdef", "mdef"]
const TABLE_KEYS := ["maxhp", "maxsp", "str", "dex", "agi", "int"]
const MAX_EXPERIENCE := 9999999


static func integer(value: Variant, minimum: int = -9007199254740991, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and value >= minimum and value <= maximum


static func maximum(key: String) -> int:
	return 9999 if key in ["maxhp", "maxsp"] else 999


static func minimum(key: String) -> int:
	return 1 if key in ["maxhp", "str", "dex", "agi", "int"] else 0


static func calculate(database: Dictionary, equipment: Array[Dictionary], states: Array[Dictionary], bonuses: Dictionary, invalid_equipment: bool) -> Dictionary:
	var values := {}
	var sources := {}
	for key: String in KEYS:
		var raw: Variant = database.get(key, 0)
		var equip: Variant = 0
		var reason := ""
		if invalid_equipment or not integer(raw):
			reason = "基础属性或装备引用无效。"
		for slot in equipment.size():
			if key in ["maxhp", "maxsp"] or key == "atk" and slot != 0:
				continue
			var field := key + "_plus" if key in TABLE_KEYS else key
			var addition: Variant = equipment[slot].get(field, 0)
			if not integer(addition):
				reason = "装备字段 %s 不是有效整数。" % field
			else:
				equip += int(addition)
		var bonus: Variant = bonuses.get(key, 0)
		if not integer(bonus, -maximum(key), maximum(key)):
			reason = "永久修正 %s_plus 超出范围。" % key
		var rates: Array[int] = []
		for state in states:
			var rate: Variant = state.get(key + "_rate", 100)
			if state.is_empty() or not integer(rate, 0, 1000000):
				reason = "状态字段 %s_rate 缺失或无效。" % key
			else:
				rates.append(int(rate))
		var base: Variant = null
		var value: Variant = null
		if reason.is_empty():
			base = clampi(int(raw) + int(equip), minimum(key), maximum(key))
			value = apply_bonus(key, int(base), int(bonus), rates)
		values[key] = value
		sources[key] = {"database": raw, "equipment": equip, "base": base, "plus": bonus, "state_rates": rates, "value": value, "minimum": minimum(key), "maximum": maximum(key), "reason": reason}
	return {"values": values, "sources": sources}


static func apply_bonus(key: String, base: int, bonus: int, rates: Array) -> int:
	var value := clampi(base + bonus, minimum(key), maximum(key))
	for rate in rates:
		value = int(value * int(rate) / 100.0)
	return clampi(value, minimum(key), maximum(key))

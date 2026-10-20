## 职责：按数据库、装备、状态及加成计算角色参数，统一整数范围和限幅规则。
##
## 调用方式：
##   纯静态计算：preload("res://runtime/scripts/00_Game/ActorParameters.gd").calculate(...) 或 apply_bonus(...)。
##
## 调用接口：
##   static func integer( value: Variant, minimum: int = -9007199254740991, maximum: int = 9007199254740991 ) -> bool
##     用途：检查数值是否为允许范围内的有效整数。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 minimum（int；默认值 -9007199254740991）：允许值的下限。
##     参数 maximum（int；默认值 9007199254740991）：允许值的上限。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func maximum(key: String) -> int
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func minimum(key: String) -> int
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func calculate( database: Dictionary, equipment: Array[Dictionary], states: Array[Dictionary], bonuses: Dictionary, invalid_equipment: bool ) -> Dictionary
##     参数 database（Dictionary；必填）：数据库分类或当前数据库定义。
##     参数 equipment（Array[Dictionary]；必填）：角色当前装备配置。
##     参数 states（Array[Dictionary]；必填）：状态记录或状态集合。
##     参数 bonuses（Dictionary；必填）：角色属性加成集合。
##     参数 invalid_equipment（bool；必填）：是否存在无效装备引用。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func apply_bonus(key: String, base: int, bonus: int, rates: Array) -> int
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 base（int；必填）：计算前的基础值。
##     参数 bonus（int；必填）：需要应用的附加值。
##     参数 rates（Array；必填）：按原规则依次应用的倍率集合。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
## 公开常量：KEYS、TABLE_KEYS、MAX_EXPERIENCE。
## 注意：计算不保存角色现场；返回值用于角色模型或预览。
## 接口说明结束。

extends RefCounted
## Pure parameter calculation. Equipment bonuses are never stored as actor bonuses.
const KEYS := ["maxhp", "maxsp", "str", "dex", "agi", "int", "atk", "pdef", "mdef"]
const TABLE_KEYS := ["maxhp", "maxsp", "str", "dex", "agi", "int"]
const MAX_EXPERIENCE := 9999999


static func integer(
	value: Variant, minimum: int = -9007199254740991, maximum: int = 9007199254740991
) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and floor(float(value)) == float(value)
		and value >= minimum
		and value <= maximum
	)


static func maximum(key: String) -> int:
	return 9999 if key in ["maxhp", "maxsp"] else 999


static func minimum(key: String) -> int:
	return 1 if key in ["maxhp", "str", "dex", "agi", "int"] else 0


static func calculate(
	database: Dictionary,
	equipment: Array[Dictionary],
	states: Array[Dictionary],
	bonuses: Dictionary,
	invalid_equipment: bool
) -> Dictionary:
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
		sources[key] = {
			"database": raw,
			"equipment": equip,
			"base": base,
			"plus": bonus,
			"state_rates": rates,
			"value": value,
			"minimum": minimum(key),
			"maximum": maximum(key),
			"reason": reason
		}
	return {"values": values, "sources": sources}


static func apply_bonus(key: String, base: int, bonus: int, rates: Array) -> int:
	var value := clampi(base + bonus, minimum(key), maximum(key))
	for rate in rates:
		value = int(value * int(rate) / 100.0)
	return clampi(value, minimum(key), maximum(key))

extends RefCounted
## Plain persisted fields for source 0065/0068/0072. No scene or live-state access.
const KEYS=["maxhp","maxsp","patk","pdef","matk","mdef","agi","int"]
const FIELDS=["tp_plus","resist_plus","skill_parameters","delay_const","parameter_plus","equip_skills","skill_sets","blastic","battle_down_rest_left","battle_animation","damage","animation_id","element"]

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size()!=FIELDS.size(): return "闪翼角色属性结构无效。"
	for field in FIELDS:
		if not value.has(field): return "闪翼角色属性缺失："+field
	for field in ["tp_plus","parameter_plus"]:
		if not value[field] is Dictionary or value[field].size()!=KEYS.size(): return "角色八项属性结构无效："+field
		for key in KEYS:
			if not number(value[field].get(key)): return "角色属性必须为有效数值："+field+"."+key
	if not value.resist_plus is Array or value.resist_plus.size()!=5: return "角色抗性必须有五个分量。"
	for n in value.resist_plus:
		if not number(n): return "角色抗性必须为有效数值。"
	if not value.skill_parameters is Dictionary: return "角色技能参数必须为Hash。"
	for field in ["delay_const","battle_down_rest_left","battle_animation","animation_id"]:
		if not integer(value[field]) or value[field]<0: return "角色计数必须为非负整数："+field
	if not number(value.damage) or value.damage<0: return "角色周期伤害无效。"
	if not value.element is Array: return "角色元素必须为编号数组。"
	for id in value.element:
		if not integer(id) or id<=0: return "角色元素编号无效。"
	if value.blastic!=null and (not integer(value.blastic) or value.blastic<0 or value.blastic>10): return "角色原力器引用无效。"
	if not value.equip_skills is Dictionary: return "角色技能槽必须为Hash。"
	for turn in value.equip_skills:
		if not str(turn).is_valid_int(): return "角色技能槽回合无效。"
		var ids: Array=value.equip_skills[turn] if value.equip_skills[turn] is Array else [value.equip_skills[turn]]
		for id in ids:
			if not integer(id) or id<=0: return "角色技能槽引用无效。"
	if not value.skill_sets is Dictionary or value.skill_sets.size()!=2: return "角色技能配置分组无效。"
	for side in ["atk","sup"]:
		if not value.skill_sets.get(side) is Array or value.skill_sets[side].size()!=9: return "角色技能配置组必须有九组。"
		for group in value.skill_sets[side]:
			if not group is Array: return "角色技能配置组必须为Array。"
			for pair in group:
				if not pair is Array or pair.size()!=2 or not integer(pair[0]) or not integer(pair[1]) or pair[1]<=0: return "角色技能配置项无效。"
	return ""

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and abs(float(value))<=9007199254740991.0

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and abs(float(value))<=9007199254740991.0

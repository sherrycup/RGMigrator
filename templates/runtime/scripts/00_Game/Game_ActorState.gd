## 职责：维护闪翼角色扩展属性、成长点数、装备槽与技能配置，并计算派生能力。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/00_Game/Game_ActorState.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func configure(actor_id: int, definition: Dictionary, lookup: Callable) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 definition（Dictionary；必填）：对象的只读定义或原数据库记录。
##     参数 lookup（Callable；必填）：按分类与编号查找只读数据库记录的回调。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func attach_project_fields(fields: Dictionary) -> void
##     参数 fields（Dictionary；必填）：字段名称或字段值集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func get_parameter(key: String) -> Variant
##     用途：按名称取得角色计算后的属性值。
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func set_project_parameter(key: String, value: Variant) -> Dictionary
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func get_resist() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func set_resist(values: Array) -> Dictionary
##     参数 values（Array；必填）：待处理的一组值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func equip_project(slot: int, record_id: int) -> Dictionary
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     参数 record_id（int；必填）：原数据库条目编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func next_level_experience() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func equip_project_skill(skill_id: int, turn: int) -> Dictionary
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 turn（int；必填）：当前战斗回合或行动轮次。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func cancel_project_skill(skill_id: int, turn: int) -> void
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 turn（int；必填）：当前战斗回合或行动轮次。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func project_skill_slot(skill_id: int) -> Array
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func trans_project_skill(skill_id: int, turn: int) -> Dictionary
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 turn（int；必填）：当前战斗回合或行动轮次。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func swap_project_skills( first_id: int, second_id: int, first_turn: int, second_turn: int ) -> Dictionary
##     参数 first_id（int；必填）：第一个角色或对象编号。
##     参数 second_id（int；必填）：第二个角色或对象编号。
##     参数 first_turn（int；必填）：第一方行动轮次。
##     参数 second_turn（int；必填）：第二方行动轮次。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_project_class(value: Variant) -> Dictionary
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func clear_project_skills() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func save_project_skill_set(index: int, side: String) -> Dictionary
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 side（String；必填）：当前对象或行动所属的一方。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func load_project_skill_set(index: int, side: String) -> Dictionary
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 side（String；必填）：当前对象或行动所属的一方。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_experience(value: Variant) -> Dictionary
##     用途：设置角色总经验并更新相应等级状态。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func add_experience(amount: Variant) -> Dictionary
##     用途：按增量修改角色总经验。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func add_level(amount: Variant) -> Dictionary
##     用途：按增量修改角色等级。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func get_parameter_plus(key: String) -> Variant
##     用途：读取指定属性的附加值。
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func set_parameter_plus(key: String, value: Variant) -> Dictionary
##     用途：设置指定属性的附加值。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_level(value: Variant) -> Dictionary
##     用途：设置角色等级并更新派生状态。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func battle_down() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func inflict_battle_down(rest_count: int = -1) -> void
##     参数 rest_count（int；默认值 -1）：剩余次数或额外位置参数数量。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func recover_battle_down() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func tick_battle_down_recovery() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func snapshot( equipment_override: Array = [], level_override: int = -1, bonuses_override: Dictionary = {} ) -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数 equipment_override（Array；默认值 []）：本次计算临时采用的装备配置。
##     参数 level_override（int；默认值 -1）：本次计算临时采用的角色等级。
##     参数 bonuses_override（Dictionary；默认值 {}）：本次计算临时采用的属性加成。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func automatic_state_ids() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func add_project_state(state_id: int, force: bool = false) -> Dictionary
##     参数 state_id（int；必填）：状态的原数据库编号。
##     参数 force（bool；默认值 false）：是否请求强制执行；仍受接口自身校验约束。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func clear_states() -> Dictionary
##     用途：清除当前对象的状态集合。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func reset_project_all() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func recover_all() -> Dictionary
##     用途：恢复角色生命与精神并清理对应异常状态。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_vital(key: String, value: Variant) -> Dictionary
##     用途：设置角色生命或精神等当前资源值。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func add_vital(key: String, amount: Variant) -> Dictionary
##     用途：按增量修改角色当前资源值。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func change_hp_native(amount: int, allow_death: bool, zero_hp_ids: Array) -> Dictionary
##     参数 amount（int；必填）：需要增加、扣除或应用的数量。
##     参数 allow_death（bool；必填）：是否允许该操作将生命值降为零。
##     参数 zero_hp_ids（Array；必填）：本次需要按零生命处理的角色编号集合。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func project_state_query(name: String) -> Variant
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func get_state_ids(include_equipment: bool = true) -> Array[int]
##     用途：取得当前有效的状态编号集合。
##     参数 include_equipment（bool；默认值 true）：计算时是否包含装备影响。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func periodic_damage(attacker: RefCounted) -> int
##     参数 attacker（RefCounted；必填）：当前行动的攻击方。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func persistent_data() -> Dictionary
##     用途：导出参与保存与恢复的状态数据。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func restore_persistent(saved: Dictionary) -> String
##     用途：从持久化数据恢复本实例状态。
##     参数 saved（Dictionary；必填）：从存档读取、尚待完整验证的数据。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func detached_copy() -> Dictionary
##     用途：创建脱离当前运行现场的对象副本。
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func commit_event_state(prepared: RefCounted) -> void
##     用途：将经过该接口校验的事件状态写入当前对象。
##     参数 prepared（RefCounted；必填）：已经过准备或校验的数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 公开常量：PROJECT_KEYS。
## 接口说明结束。

extends "ActorState.gd"
## Flash actor fields and formulas. The standard actor holds vitals and identity;
## raw extension values are shared with CustomDataState, never a second registry.
const Custom = preload("CustomDataState.gd")
const Data = preload("RuntimeData.gd")
const Fields = preload("ActorFields.gd")
const Battler = preload("../01_Battle/BattlerRules.gd")
const PROJECT_KEYS = ["maxhp", "maxsp", "patk", "pdef", "matk", "mdef", "agi", "int"]
var project_fields: Dictionary = {}
var project_rules: Dictionary = {}
var _rules_override: Dictionary = {}
var _project_ready = false
var _hp_states_enabled = false
var _synchronizing_hp = false
var _raw_vitals = false


func _vital_number(value: Variant) -> bool:
	return Fields.number(value) if _project_ready else super._vital_number(value)


func _bound_vital(value: Variant, cap: Variant) -> Variant:
	if not _project_ready:
		return super._bound_vital(value, cap)
	return value if _raw_vitals else min(max(value, 0), cap)


func configure(actor_id: int, definition: Dictionary, lookup: Callable) -> void:
	_project_ready = false
	_hp_states_enabled = false
	super.configure(actor_id, definition, lookup)
	project_rules = (
		_rules_override
		if not _rules_override.is_empty()
		else Custom.native_value(Data.read_json("res://data/flash_gameplay.json", {}))
	)
	_rules_override = {}
	project_fields = (
		Custom
		. native_value(definition.get("_custom_data", {}).get("attributes", {}))
		. duplicate(true)
	)
	_initialize_project_fields()
	equipment.resize(6)
	equipment.fill(0)
	state_ids.clear()
	_skill_ids.clear()
	experience = int(project_rules.get("storage", {}).get("actor_init_exp", {}).get(str(id), 0))
	project_fields.battle_animation = int(
		project_rules.get("storage", {}).get("actor_init_animation", {}).get(str(id), 1)
	)
	_project_ready = true
	hp = get_parameter("maxhp")
	sp = get_parameter("maxsp")
	_hp_states_enabled = true
	changed.emit()


func _after_hp_assignment() -> void:
	if not _hp_states_enabled or _synchronizing_hp or hp == null:
		return
	_synchronizing_hp = true
	for state in Data.database("States"):
		if not state is Dictionary or not state.get("zero_hp", false):
			continue
		var state_id = int(state.id)
		if hp == 0 and not state_ids.has(state_id):
			add_state_native(state_id)
		elif hp > 0 and state_ids.has(state_id):
			remove_state(state_id)
	_synchronizing_hp = false


func _initialize_project_fields() -> void:
	if not project_fields.has("tp_plus"):
		project_fields.tp_plus = {}
		for key in PROJECT_KEYS:
			project_fields.tp_plus[key] = 0
	if not project_fields.has("resist_plus"):
		project_fields.resist_plus = [0, 0, 0, 0, 0]
	if not project_fields.has("skill_parameters"):
		project_fields.skill_parameters = {}
	if not project_fields.has("delay_const"):
		project_fields.delay_const = 100
	if not project_fields.has("parameter_plus"):
		project_fields.parameter_plus = {}
		for key in PROJECT_KEYS:
			project_fields.parameter_plus[key] = 0
	if not project_fields.has("equip_skills"):
		project_fields.equip_skills = {"-2": [], "-1": []}
	if not project_fields.has("skill_sets"):
		project_fields.skill_sets = {
			"atk": [[], [], [], [], [], [], [], [], []], "sup": [[], [], [], [], [], [], [], [], []]
		}
	if not project_fields.has("blastic"):
		project_fields.blastic = null
	if not project_fields.has("battle_down_rest_left"):
		project_fields.battle_down_rest_left = 0
	if not project_fields.has("battle_animation"):
		project_fields.battle_animation = int(
			project_rules.get("storage", {}).get("actor_init_animation", {}).get(str(id), 1)
		)
	if not project_fields.has("damage"):
		project_fields.damage = 0
	if not project_fields.has("animation_id"):
		project_fields.animation_id = 0
	if not project_fields.has("element"):
		project_fields.element = []


func attach_project_fields(fields: Dictionary) -> void:
	project_fields = fields
	_initialize_project_fields()


func get_parameter(key: String) -> Variant:
	if not _project_ready:
		return super.get_parameter(key)
	var project_key = "patk" if key == "atk" else key
	if project_key not in PROJECT_KEYS:
		return super.get_parameter(key)
	return _parameter_value(project_key, equipment)


func _parameter_value(key: String, selected: Array) -> int:
	return _parameter_with_states(key, state_ids, selected)


func _parameter_with_states(key: String, states: Array, selected: Array = []) -> int:
	return Battler.parameter(
		_project_base_parameter(key, equipment if selected.is_empty() else selected),
		project_fields.parameter_plus.get(key, 0),
		key,
		states,
		func(id): return _record("States", id)
	)


func _project_base_parameter(key: String, selected: Array) -> float:
	# Preserve the source's pdef/patk and mdef/matk point-key relationship.
	var point_key = "patk" if key == "pdef" else "matk" if key == "mdef" else key
	var value = float(project_fields.tp_plus.get(point_key, 0))
	var slots: Array = (
		[2, 3, 4, 5]
		if key in ["maxhp", "pdef", "mdef"]
		else [0, 4, 5] if key in ["patk", "matk"] else [0, 2, 3, 4, 5]
	)
	if key == "maxsp":
		return value
	for slot in slots:
		if slot >= selected.size() or int(selected[slot]) == 0:
			continue
		var kind: int = (
			(slot / 2 + 1)
			if key in ["maxhp", "pdef", "mdef"]
			else int((slot / 2) * 1.5) if key in ["patk", "matk"] else roundi((slot / 2) * 1.6)
		)
		var entry = _equipment_record(kind, int(selected[slot]))
		var field = "hp_plus" if key == "maxhp" else key + "_plus" if key in ["agi", "int"] else key
		value += _equipment_parameter(kind, entry, field)
	return value


func _equipment_record(kind: int, record_id: int) -> Dictionary:
	return (
		{}
		if kind < 0 or kind > 3
		else _record(["Weapons", "Deputies", "Armors", "Ornaments"][kind], record_id, true)
	)


func _equipment_parameter(kind: int, entry: Dictionary, key: String) -> float:
	if entry.is_empty():
		return 0
	var settings: Dictionary = entry.get("_custom_data", {}).get("external", {}).get("settings", {})
	var setting_key = (
		"hp"
		if key == "hp_plus"
		else key.trim_suffix("_plus") if key in ["agi_plus", "int_plus"] else key
	)
	if (
		settings.has(setting_key)
		and settings[setting_key] != null
		and (not settings[setting_key] is bool or settings[setting_key])
	):
		return float(settings[setting_key])
	# Source base_maxhp requests hp_plus while both source wrappers expose hp.
	# The adapter names this existing getter explicitly; no new bonus is invented.
	if key == "hp_plus":
		return 0
	if key == "patk" and kind == 0:
		return float(entry.get("atk", 0))
	if key == "matk" and kind == 0:
		return float(entry.get("pdef", 0))
	if kind == 3:
		return 0
	return float(entry.get(key, 0))


func set_project_parameter(key: String, value: Variant) -> Dictionary:
	if key not in PROJECT_KEYS or not Fields.number(value):
		return _result(false, false, "闪翼属性参数无效。")
	var plus: Variant = project_fields.parameter_plus.get(key, 0) + value - get_parameter(key)
	if not Fields.number(plus):
		return _result(false, false, "闪翼属性增量超出支持范围。")
	if key != "maxhp":
		plus = min(
			max(plus, -999999 if key == "maxsp" else -99999), 999999 if key == "maxsp" else 99999
		)
	project_fields.parameter_plus[key] = plus
	# Source writes the backing vital here, without hp= zero-state effects.
	if key == "maxhp" and hp != null:
		_install_vitals(min(hp, get_parameter(key)), sp)
	if key == "maxsp" and sp != null:
		_install_vitals(hp, min(sp, get_parameter(key)))
	changed.emit()
	return _result(true, true, "属性已更新。")


func get_resist() -> Array:
	# base_resist's source calls Array.plus without assigning its return value.
	return Battler.resist(
		[0, 0, 0, 0, 0],
		project_fields.resist_plus,
		state_ids,
		func(id): return _record("States", id)
	)


func set_resist(values: Array) -> Dictionary:
	if values.size() != 5:
		return _result(false, false, "抗性必须有五个分量。")
	var current = get_resist()
	for i in 5:
		if not Fields.number(values[i]):
			return _result(false, false, "抗性分量必须为有效数值。")
	var changed_values: Array = []
	for i in 5:
		changed_values.append(
			clampf(
				float(project_fields.resist_plus[i]) + float(values[i]) - float(current[i]),
				-100,
				100
			)
		)
	project_fields.resist_plus = changed_values
	changed.emit()
	return _result(true, true, "抗性已更新。")


func equip_project(slot: int, record_id: int) -> Dictionary:
	if slot < 0 or slot >= 6 or record_id < 0 or record_id > 999:
		return _result(false, false, "闪翼装备槽位/编号无效。")
	var kind = [0, 1, 2, 2, 3, 3][slot]
	if record_id > 0 and kind == 1:
		return _result(false, false, "原工程缺少副手类及定义；没有可迁移的副手实现。")
	if record_id > 0 and _equipment_record(kind, record_id).is_empty():
		return _result(false, false, "装备定义不存在。")
	var modified = int(equipment[slot]) != record_id
	equipment[slot] = record_id
	if modified:
		changed.emit()
	return _result(true, modified, "装备槽已更新。")


func next_level_experience() -> Variant:
	var table: Array = project_rules.get("storage", {}).get("actor_exp_next", {}).get(
		str(id), [0, 0]
	)
	return table[level] if level < table.size() else null


func equip_project_skill(skill_id: int, turn: int) -> Dictionary:
	# Source rejects unlearned skills and duplicate scalar active entries silently.
	if skill_id <= 0 or not has_skill(skill_id):
		return _result(true, false, "未学习此技能。")
	if project_fields.equip_skills.values().has(skill_id):
		return _result(true, false, "此主动技能已经配置。")
	project_fields.equip_skills[str(turn)] = [skill_id] if turn in [-1, -2] else skill_id
	changed.emit()
	return _result(true, true, "技能配置已更新。")


func cancel_project_skill(skill_id: int, turn: int) -> void:
	if turn in [-1, -2]:
		project_fields.equip_skills.get(str(turn), []).erase(skill_id)
	else:
		for key in project_fields.equip_skills:
			var value: Variant = project_fields.equip_skills[key]
			if (value is int or value is float) and value == skill_id:
				project_fields.equip_skills.erase(key)
				break
	changed.emit()


func project_skill_slot(skill_id: int) -> Array:
	for key in project_fields.equip_skills:
		var value: Variant = project_fields.equip_skills[key]
		if (
			value is Array and value.has(skill_id)
			or (value is int or value is float) and value == skill_id
		):
			return [true, int(key)]
	return [false, null]


func trans_project_skill(skill_id: int, turn: int) -> Dictionary:
	var slot = project_skill_slot(skill_id)
	if not slot[0]:
		return _result(true, false, "此技能未配置。")
	cancel_project_skill(skill_id, int(slot[1]))
	return equip_project_skill(skill_id, turn)


func swap_project_skills(
	first_id: int, second_id: int, first_turn: int, second_turn: int
) -> Dictionary:
	cancel_project_skill(first_id, first_turn)
	cancel_project_skill(second_id, second_turn)
	var first = equip_project_skill(first_id, second_turn)
	return equip_project_skill(second_id, first_turn) if first.ok else first


func set_project_class(value: Variant) -> Dictionary:
	if not Parameters.integer(value, 1) or _record("Classes", int(value)).is_empty():
		return _result(false, false, "职业引用不存在。")
	var modified = class_id != int(value)
	class_id = int(value)
	if modified:
		changed.emit()
	return _result(true, modified, "职业已更新；保留原装备和技能。")


func clear_project_skills() -> void:
	project_fields.equip_skills = {"-2": [], "-1": []}
	changed.emit()


func save_project_skill_set(index: int, side: String) -> Dictionary:
	var sets: Variant = project_fields.skill_sets.get(side)
	if not sets is Array or index < 0 or index >= sets.size():
		return _result(false, false, "技能配置组不存在。")
	var result: Array = []
	for key in project_fields.equip_skills:
		var value: Variant = project_fields.equip_skills[key]
		for id in value if value is Array else [value]:
			result.append([int(key), int(id)])
	sets[index] = result
	changed.emit()
	return _result(true, true, "技能配置组已保存。")


func load_project_skill_set(index: int, side: String) -> Dictionary:
	var sets: Variant = project_fields.skill_sets.get(side)
	if not sets is Array or index < 0 or index >= sets.size() or not sets[index] is Array:
		return _result(false, false, "技能配置组不存在。")
	for pair in sets[index]:
		if (
			not pair is Array
			or pair.size() != 2
			or not Parameters.integer(pair[0])
			or not Parameters.integer(pair[1], 1)
		):
			return _result(false, false, "技能配置组内容无效。")
	clear_project_skills()
	for pair in sets[index]:
		equip_project_skill(int(pair[1]), int(pair[0]))
	return _result(true, true, "技能配置组已载入。")


func set_experience(value: Variant) -> Dictionary:
	if not Parameters.integer(value):
		return _result(false, false, "经验必须为整数。")
	experience = clampi(int(value), 0, 9999999)
	changed.emit()
	return _result(true, true, "经验已更新；升级由原公共事件判定。")


func add_experience(amount: Variant) -> Dictionary:
	return (
		set_experience(experience + int(amount))
		if Parameters.integer(amount)
		else _result(false, false, "经验增量必须为整数。")
	)


func add_level(amount: Variant) -> Dictionary:
	return (
		set_level(maxi(1, level + int(amount)))
		if Parameters.integer(amount)
		else _result(false, false, "等级增量必须为整数。")
	)


func get_parameter_plus(key: String) -> Variant:
	return (
		project_fields.parameter_plus.get(key)
		if _project_ready and key in PROJECT_KEYS
		else super.get_parameter_plus(key)
	)


func set_parameter_plus(key: String, value: Variant) -> Dictionary:
	if not _project_ready:
		return super.set_parameter_plus(key, value)
	if key not in PROJECT_KEYS or not Fields.number(value):
		return _result(false, false, "闪翼角色没有此属性：" + key)
	project_fields.parameter_plus[key] = value
	if key == "maxhp":
		_install_vitals(min(hp, get_parameter(key)), sp)
	if key == "maxsp":
		_install_vitals(hp, min(sp, get_parameter(key)))
	changed.emit()
	return _result(true, true, "属性增量已更新。")


func set_level(value: Variant) -> Dictionary:
	if not Parameters.integer(value):
		return _result(false, false, "等级必须为整数。")
	level = clampi(int(value), 1, int(_definition.get("final_level", 99)))
	changed.emit()
	return _result(true, true, "等级已更新。")


func battle_down() -> bool:
	var state_id = int(project_rules.get("constants", {}).get("CANT_BATTLE", 5))
	return state_ids.has(state_id)


func inflict_battle_down(rest_count: int = -1) -> void:
	project_fields.battle_down_rest_left = maxi(
		(
			rest_count
			if rest_count >= 0
			else int(
				project_rules.get("storage", {}).get("actor_battle_down_recovery", {}).get(
					str(id), 1
				)
			)
		),
		0
	)
	var state_id = int(project_rules.get("constants", {}).get("CANT_BATTLE", 5))
	if not state_ids.has(state_id):
		state_ids.append(state_id)
	hp = 0
	changed.emit()


func recover_battle_down() -> void:
	state_ids.erase(int(project_rules.get("constants", {}).get("CANT_BATTLE", 5)))
	project_fields.battle_down_rest_left = 0
	if hp == 0:
		hp = mini(1, int(get_parameter("maxhp")))
	changed.emit()


func tick_battle_down_recovery() -> void:
	if not battle_down():
		return
	project_fields.battle_down_rest_left -= 1
	if project_fields.battle_down_rest_left <= 0:
		recover_battle_down()


func snapshot(
	equipment_override: Array = [], level_override: int = -1, bonuses_override: Dictionary = {}
) -> Dictionary:
	if not _project_ready:
		return super.snapshot(equipment_override, level_override, bonuses_override)
	var selected = equipment if equipment_override.is_empty() else equipment_override
	var parameters: Dictionary = {}
	var sources: Dictionary = {}
	var equipped: Array = []
	var state_names: Array = []
	for key in PROJECT_KEYS:
		parameters[key] = _parameter_value(key, selected)
		sources[key] = {
			"base": _project_base_parameter(key, selected),
			"plus": project_fields.parameter_plus.get(key, 0),
			"reason": "",
			"source": "0065/0069"
		}
	parameters.atk = parameters.patk
	sources.atk = sources.patk.duplicate(true)
	for slot in selected.size():
		var kind = [0, 1, 2, 2, 3, 3][slot]
		var entry = _equipment_record(kind, int(selected[slot]))
		equipped.append(
			{
				"id": selected[slot],
				"name":
				str(
					entry.get(
						"name", "—" if int(selected[slot]) == 0 else "缺失 #%d" % selected[slot]
					)
				),
				"icon_name": str(entry.get("icon_name", "")),
				"database": ["Weapons", "Deputies", "Armors", "Ornaments"][kind]
			}
		)
	for state_id in state_ids:
		state_names.append(str(_record("States", state_id).get("name", "缺失状态 #%d" % state_id)))
	var threshold = next_level_experience()
	return {
		"id": id,
		"name": actor_name,
		"class_name": str(_record("Classes", class_id).get("name", "")),
		"level": level,
		"hp": hp,
		"sp": sp,
		"parameters": parameters,
		"parameter_sources": sources,
		"experience": experience,
		"next_experience": maxi(int(threshold) - experience, 0) if threshold != null else null,
		"equipment": equipped,
		"states": state_names,
		"skill_ids": get_skill_ids(),
		"diagnostics": diagnostics.duplicate(),
		"character_name": character_name,
		"character_hue": character_hue,
		"project_resist": get_resist()
	}


func automatic_state_ids() -> Array:
	# Source equip writes only its six-slot array; it does not add armor states.
	return [] if _project_ready else super.automatic_state_ids()


func _change_states(
	ids: Array, adding: bool, forced_hp: Variant = null, keep_ordinary_source: bool = false
) -> Dictionary:
	if not _project_ready:
		return super._change_states(ids, adding, forced_hp, keep_ordinary_source)
	return _change_project_states(ids, adding, false, forced_hp)


func add_project_state(state_id: int, force: bool = false) -> Dictionary:
	return _change_project_states([state_id], true, force)


func _change_project_states(
	ids: Array, adding: bool, force: bool, forced_hp: Variant = null
) -> Dictionary:
	var before = {"states": state_ids.duplicate(), "hp": hp, "sp": sp}
	var work = before.duplicate(true)
	if forced_hp != null:
		work.hp = forced_hp
	var result = Battler.change(
		work, ids, adding, force, _parameter_with_states, func(id): return _record("States", id)
	)
	if not result.ok:
		return _result(false, false, result.message)
	var modified: bool = before != result.state
	state_ids.assign(result.state.states)
	_install_vitals(result.state.hp, result.state.sp)
	if modified:
		changed.emit()
	return _result(true, modified, "闪翼状态已更新。")


func _install_vitals(new_hp: Variant, new_sp: Variant) -> void:
	var previous_enabled = _hp_states_enabled
	_hp_states_enabled = false
	_raw_vitals = true
	hp = new_hp
	sp = new_sp
	_raw_vitals = false
	_hp_states_enabled = previous_enabled


func clear_states() -> Dictionary:
	if not _project_ready:
		return super.clear_states()
	var before = state_ids.duplicate()
	state_ids.clear()
	_install_vitals(max(min(hp, get_parameter("maxhp")), 1), min(sp, get_parameter("maxsp")))
	return _result(true, not before.is_empty(), "闪翼状态已清空。")


func reset_project_all() -> Dictionary:
	# Source fills using the current rates before removing each old state.
	_install_vitals(get_parameter("maxhp"), get_parameter("maxsp"))
	return _change_project_states(state_ids.duplicate(), false, false)


func recover_all() -> Dictionary:
	return reset_project_all() if _project_ready else super.recover_all()


func set_vital(key: String, value: Variant) -> Dictionary:
	if not _project_ready:
		return super.set_vital(key, value)
	if key not in ["hp", "sp"] or not Fields.number(value):
		return _result(false, false, "闪翼生命/魔力值无效。")
	var before: Variant = get(key)
	set(key, value)
	return _result(true, before != get(key), "生命/魔力已更新。")


func add_vital(key: String, amount: Variant) -> Dictionary:
	if not _project_ready:
		return super.add_vital(key, amount)
	return (
		set_vital(key, get(key) + amount)
		if key in ["hp", "sp"] and Fields.number(amount)
		else _result(false, false, "生命/魔力增量无效。")
	)


func change_hp_native(amount: int, allow_death: bool, zero_hp_ids: Array) -> Dictionary:
	if not _project_ready:
		return super.change_hp_native(amount, allow_death, zero_hp_ids)
	if hp <= 0:
		return _result(true, false, "原生HP增减跳过HP为0的角色。")
	var target: Variant = min(max(hp + amount, 0 if allow_death else 1), get_parameter("maxhp"))
	return _change_project_states(zero_hp_ids, target == 0, false, target)


func project_state_query(name: String) -> Variant:
	return Battler.query(state_ids, name, func(id): return _record("States", id))


func get_state_ids(include_equipment: bool = true) -> Array[int]:
	return state_ids.duplicate() if _project_ready else super.get_state_ids(include_equipment)


func periodic_damage(attacker: RefCounted) -> int:
	var value = (
		maxi(int(attacker.get_parameter("patk")) - get_parameter("pdef"), 0)
		+ maxi(int(attacker.get_parameter("matk")) - get_parameter("mdef"), 0)
	)
	project_fields["damage"] = value
	return value


func persistent_data() -> Dictionary:
	var result = super.persistent_data()
	result["flash_actor_fields"] = project_fields.duplicate(true)
	return result


func restore_persistent(saved: Dictionary) -> String:
	if not saved.get("flash_actor_fields") is Dictionary:
		return "缺少闪翼角色数据。"
	if not Custom.plain_reason(saved.flash_actor_fields).is_empty():
		return "闪翼角色数据不是普通树形数据。"
	var field_reason = Fields.validate(saved.flash_actor_fields)
	if not field_reason.is_empty():
		return field_reason
	project_fields = Custom.native_value(saved.flash_actor_fields).duplicate(true)
	_initialize_project_fields()
	if not saved.get("equipment") is Array or saved.equipment.size() != 6:
		return "闪翼角色需要六个装备槽。"
	for field in ["level", "experience"]:
		if not Parameters.integer(saved.get(field), 0):
			return "闪翼角色数值无效：" + field
	for field in ["hp", "sp"]:
		if not Fields.number(saved.get(field)) or saved[field] < 0:
			return "闪翼角色数值无效：" + field
	if int(saved.level) < 1:
		return "闪翼角色等级无效。"
	if saved.level > int(_definition.get("final_level", 99)) or saved.experience > 9999999:
		return "闪翼角色等级/经验超过源上限。"
	actor_name = str(saved.name)
	class_id = int(saved.class_id)
	level = int(saved.level)
	experience = int(saved.experience)
	equipment.assign(saved.equipment)
	state_ids.assign(saved.state_ids)
	_skill_ids.assign(saved.skill_ids)
	_parameter_plus = saved.parameter_plus.duplicate(true)
	character_name = str(saved.character_name)
	character_hue = int(saved.character_hue)
	battler_name = str(saved.battler_name)
	battler_hue = int(saved.battler_hue)
	# Source equip and direct field writes can leave HP above the current cap;
	# reading/copying a state must preserve that value until a source clamp runs.
	_install_vitals(saved.hp, saved.sp)
	return ""


func detached_copy() -> Dictionary:
	var instance: RefCounted = get_script().new()
	# Copy an existing actor without running new-game setup, equipment hooks or
	# rebuilding the same experience/rules tables for every script read.
	instance.id = id
	instance._definition = _definition
	instance._lookup = _lookup
	instance.final_level = final_level
	instance._experience_curve = _experience_curve
	instance.project_rules = project_rules
	instance._project_ready = _project_ready
	var reason: String = instance.restore_persistent(persistent_data())
	instance._hp_states_enabled = _hp_states_enabled
	return {"ok": true, "actor": instance} if reason.is_empty() else _result(false, false, reason)


func commit_event_state(prepared: RefCounted) -> void:
	var fields: Dictionary = prepared.project_fields.duplicate(true)
	project_fields.clear()
	project_fields.merge(fields)
	var enabled = _hp_states_enabled
	_hp_states_enabled = false
	_raw_vitals = true
	super.commit_event_state(prepared)
	_raw_vitals = false
	_hp_states_enabled = enabled

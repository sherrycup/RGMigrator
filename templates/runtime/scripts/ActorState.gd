extends RefCounted
## Standard RMXP actor state, independent of both database records and scene nodes.
signal changed
const Parameters = preload("res://runtime/scripts/ActorParameters.gd")

var id := 0
var actor_name := ""
var class_id := 0
var level := 1
var final_level := 99
var experience := 0
var character_name := ""
var character_hue := 0
var battler_name := ""
var battler_hue := 0
var _parameter_plus: Dictionary = {}
var last_mutation_result: Dictionary = {}
var equipment: Array[int] = []
var state_ids: Array[int] = []
var _skill_ids: Array[int] = []
var diagnostics: Array[String] = []
var hp: Variant = null:
	set(value):
		if value != null:
			if not Parameters.integer(value):
				_report("HP 必须是有效整数；未修改。")
				return
			var cap: Variant = get_parameter("maxhp")
			if cap == null:
				_report("HP 上限无法计算；未修改。")
				return
			value = clampi(int(value), 0, int(cap))
		if hp != value:
			hp = value
			changed.emit()
var sp: Variant = null:
	set(value):
		if value != null:
			if not Parameters.integer(value):
				_report("SP 必须是有效整数；未修改。")
				return
			var cap: Variant = get_parameter("maxsp")
			if cap == null:
				_report("SP 上限无法计算；未修改。")
				return
			value = clampi(int(value), 0, int(cap))
		if sp != value:
			sp = value
			changed.emit()
var _definition: Dictionary
var _lookup: Callable
var _experience_curve: PackedInt64Array


func configure(actor_id: int, definition: Dictionary, lookup: Callable) -> void:
	id = actor_id
	_definition = definition
	_lookup = lookup
	actor_name = str(definition.get("name", ""))
	character_name = str(definition.get("character_name", ""))
	character_hue = int(definition.get("character_hue", 0))
	battler_name = str(definition.get("battler_name", ""))
	battler_hue = int(definition.get("battler_hue", 0))
	_parameter_plus.clear()
	for key in Parameters.KEYS:
		_parameter_plus[key] = 0
	class_id = int(definition.get("class_id", 0))
	final_level = clampi(int(definition.get("final_level", 99)), 1, 99)
	level = clampi(int(definition.get("initial_level", 1)), 1, final_level)
	equipment.clear()
	state_ids.clear()
	_skill_ids.clear()
	diagnostics.clear()
	var profession := _record("Classes", class_id)
	for learning in profession.get("learnings", []):
		if learning is Dictionary and int(learning.get("level", 1)) <= level:
			learn_skill(int(learning.get("skill_id", 0)))
	for field in ["weapon_id", "armor1_id", "armor2_id", "armor3_id", "armor4_id"]:
		equipment.append(int(definition.get(field, 0)))
	_experience_curve.resize(101)
	_experience_curve.fill(0)
	var power := 2.4 + float(definition.get("exp_inflation", 30)) / 100.0
	for next_level in range(2, final_level + 1):
		var increment := float(definition.get("exp_basis", 30)) * pow(float(next_level + 3), power) / pow(5.0, power)
		_experience_curve[next_level] = _experience_curve[next_level - 1] + int(increment)
	experience = _experience_curve[level]
	# Native setup fills vitals before installing armor automatic states.
	var initial := snapshot([equipment[0], 0, 0, 0, 0])
	hp = initial.parameters.get("maxhp")
	sp = initial.parameters.get("maxsp")
	if hp != null and sp != null and not automatic_state_ids().is_empty():
		var automatic := apply_equipment_states([])
		if not automatic.ok: _report(automatic.message)
	changed.emit()


func learn_skill(skill_id: int) -> Dictionary:
	if skill_id <= 0 or _record("Skills", skill_id).is_empty():
		return {"ok": false, "changed": false, "message": "Actors[%d] 引用不存在的 Skills[%d]。" % [id, skill_id]}
	if has_skill(skill_id):
		return {"ok": true, "changed": false, "message": "已经学会此特技。"}
	_skill_ids.append(skill_id)
	_skill_ids.sort()
	changed.emit()
	return {"ok": true, "changed": true, "message": "已学会特技。"}


func forget_skill(skill_id: int) -> Dictionary:
	if skill_id <= 0 or _record("Skills", skill_id).is_empty():
		return {"ok": false, "changed": false, "message": "Actors[%d] 引用不存在的 Skills[%d]。" % [id, skill_id]}
	var existed := has_skill(skill_id)
	_skill_ids.erase(skill_id)
	if existed:
		changed.emit()
	return {"ok": true, "changed": existed, "message": "已遗忘特技。" if existed else "尚未学会此特技，无需遗忘。"}


func has_skill(skill_id: int) -> bool:
	return _skill_ids.has(skill_id)


func get_skill_ids() -> Array[int]:
	return _skill_ids.duplicate()


func add_state(state_id: int) -> Dictionary:
	return _change_states([state_id], true, null, true)

func add_state_native(state_id: int) -> Dictionary:
	return _change_states([state_id], true)

func remove_state(state_id: int) -> Dictionary:
	return _change_states([state_id], false)

func clear_states() -> Dictionary:
	return _change_states(state_ids.duplicate(), false)

func _validate_state_graph(ids: Array) -> Dictionary:
	var pending := ids.duplicate()
	pending.append_array(get_state_ids())
	var visited := {}
	while not pending.is_empty():
		var raw: Variant = pending.pop_back()
		if not Parameters.integer(raw, 1): return _result(false, false, "状态引用无效。")
		var state_id := int(raw)
		if visited.has(state_id): continue
		visited[state_id] = true
		if visited.size() > 10000: return _result(false, false, "状态关联过多。")
		var definition := _record("States", state_id)
		if definition.is_empty() or not definition.get("zero_hp", false) is bool: return _result(false, false, "状态或zero_hp定义无效。")
		for field in ["plus_state_set", "minus_state_set"]:
			var links: Variant = definition.get(field, [])
			if not links is Array: return _result(false, false, "状态关联必须是ID列表。")
			pending.append_array(links)
	return {"ok": true}

func automatic_state_ids() -> Array:
	var result := []
	for slot in range(1, equipment.size()):
		var state_id := int(_record("Armors", equipment[slot], true).get("auto_state_id", 0))
		if state_id > 0 and not result.has(state_id): result.append(state_id)
	return result

func _state_add(work: Dictionary, state_id: int) -> bool:
	work.steps += 1
	if work.steps > 1024: return false
	var definition := _record("States", state_id)
	var effective: Array = work.ids.duplicate(); effective.append_array(work.automatic)
	for current in effective:
		if _record("States", current).get("minus_state_set", []).any(func(raw: Variant) -> bool: return int(raw) == state_id) and not definition.get("minus_state_set", []).any(func(raw: Variant) -> bool: return int(raw) == int(current)): return true
	if effective.has(state_id): return true
	work.ids.append(state_id)
	if definition.get("zero_hp", false): work.hp = 0
	# RM applies links in database ID order, plus then minus for each ID.
	var linked: Array = definition.get("plus_state_set", []).duplicate()
	for raw in definition.get("minus_state_set", []):
		if not linked.has(raw): linked.append(raw)
	linked.sort()
	for raw in linked:
		var target := int(raw)
		if definition.get("plus_state_set", []).has(raw) and not _state_add(work, target): return false
		if definition.get("minus_state_set", []).has(raw) and not _state_remove(work, target): return false
	return _clamp_state_work(work)

func _state_remove(work: Dictionary, state_id: int) -> bool:
	work.steps += 1
	if work.steps > 1024: return false
	if not work.ids.has(state_id): return true
	work.ids.erase(state_id)
	if work.hp == 0 and _record("States", state_id).get("zero_hp", false):
		var effective: Array = work.ids.duplicate(); effective.append_array(work.automatic)
		if not effective.any(func(raw: Variant) -> bool: return bool(_record("States", int(raw)).get("zero_hp", false))): work.hp = 1
	return _clamp_state_work(work)

func _clamp_state_work(work: Dictionary) -> bool:
	# Native links clamp vitals after each add/remove, including nested links.
	var previous := state_ids.duplicate()
	state_ids.assign(work.ids)
	var values: Dictionary = snapshot().parameters
	state_ids.assign(previous)
	if values.values().has(null): return false
	work.hp = mini(int(work.hp), int(values.maxhp)); work.sp = mini(int(work.sp), int(values.maxsp))
	return true

func _change_states(ids: Array, adding: bool, forced_hp: Variant = null, keep_ordinary_source: bool = false) -> Dictionary:
	var validation := _validate_state_graph(ids)
	if not validation.ok: return validation
	var work := {"ids": state_ids.duplicate(), "automatic": automatic_state_ids(), "hp": hp if forced_hp == null else forced_hp, "sp": sp, "steps": 0}
	for raw in ids:
		if adding and keep_ordinary_source and work.automatic.has(int(raw)) and not work.ids.has(int(raw)):
			# The general API preserves an explicitly requested ordinary source;
			# native 313 keeps RM's no-op when the state is already automatic.
			work.ids.append(int(raw))
		var accepted := _state_add(work, int(raw)) if adding else _state_remove(work, int(raw))
		if not accepted: return _result(false, false, "状态关联循环超过预算；角色未修改。")
	work.ids.sort()
	var previous := state_ids.duplicate(); var previous_hp: Variant = hp; var previous_sp: Variant = sp
	state_ids.assign(work.ids)
	var view := snapshot()
	if view.parameters.values().has(null):
		state_ids.assign(previous)
		return _result(false, false, "状态变更后的属性无法计算；未修改。")
	hp = work.hp
	sp = work.sp
	var modified: bool = previous != state_ids or previous_hp != hp or previous_sp != sp
	if modified: changed.emit()
	return _result(true, modified, "状态已更新；保留装备来源，执行HP为0和状态关联，不执行回合制效果。")

func change_hp_native(amount: int, allow_death: bool, zero_hp_ids: Array) -> Dictionary:
	if hp == null: return _result(false, false, "当前HP无效。")
	if hp <= 0: return _result(true, false, "原生HP增减跳过HP为0的角色。")
	var cap: Variant = get_parameter("maxhp")
	if cap == null: return _result(false, false, "HP上限无法计算。")
	var target := clampi(int(hp) + amount, 0 if allow_death else 1, int(cap))
	return _change_states(zero_hp_ids, target == 0, target)

func apply_equipment_states(previous_auto: Array) -> Dictionary:
	var current := automatic_state_ids()
	var validation := _validate_state_graph(previous_auto + current)
	if not validation.ok: return validation
	var work := {"ids": state_ids.duplicate(), "automatic": [], "hp": hp, "sp": sp, "steps": 0}
	for state_id in current:
		if previous_auto.has(state_id): work.automatic.append(state_id)
	for state_id in current:
		if previous_auto.has(state_id): continue
		var ordinary: bool = work.ids.has(state_id)
		if not _state_add(work, state_id): return _result(false, false, "装备状态关联循环超过预算。")
		if not ordinary: work.ids.erase(state_id)
		work.automatic.append(state_id)
	if work.hp == 0 and previous_auto.any(func(raw: Variant) -> bool: return bool(_record("States", int(raw)).get("zero_hp", false))):
		var effective: Array = work.ids + current
		if not effective.any(func(raw: Variant) -> bool: return bool(_record("States", int(raw)).get("zero_hp", false))): work.hp = 1
	var previous := state_ids.duplicate()
	state_ids.assign(work.ids)
	if snapshot().parameters.values().has(null):
		state_ids.assign(previous)
		return _result(false, false, "装备状态关联后的属性无法计算。")
	hp = work.hp; sp = work.sp
	return {"ok": true}

func recover_all() -> Dictionary:
	var validation := _validate_state_graph(state_ids)
	if not validation.ok: return validation
	# RM fills using the current caps before removing ordinary states.
	var previous_caps: Dictionary = snapshot().parameters
	if previous_caps.values().has(null): return _result(false, false, "全回复前的属性无法计算；未修改。")
	var previous := state_ids.duplicate()
	state_ids.clear()
	var view := snapshot()
	if view.parameters.values().has(null):
		state_ids.assign(previous)
		return _result(false, false, "全回复后的属性无法计算；未修改。")
	hp = mini(int(previous_caps.maxhp), int(view.parameters.maxhp)); sp = mini(int(previous_caps.maxsp), int(view.parameters.maxsp))
	changed.emit()
	return _result(true, true, "HP/SP全回复，清除普通状态，保留装备来源。")

func detached_copy() -> Dictionary:
	var instance: RefCounted = load("res://runtime/scripts/ActorState.gd").new()
	instance.configure(id, _definition, _lookup)
	var reason: String = instance.restore_persistent(persistent_data())
	return {"ok": true, "actor": instance} if reason.is_empty() else _result(false, false, reason)

func commit_event_state(prepared: RefCounted) -> void:
	for field in ["actor_name", "class_id", "level", "experience", "character_name", "character_hue", "battler_name", "battler_hue"]: set(field, prepared.get(field))
	equipment.assign(prepared.equipment); state_ids.assign(prepared.state_ids); _skill_ids.assign(prepared.get_skill_ids())
	_parameter_plus = prepared._parameter_plus.duplicate()
	hp = prepared.hp; sp = prepared.sp
	changed.emit()

func has_state(state_id: int) -> bool:
	return state_id > 0 and get_state_ids().has(state_id)


func get_state_ids(include_equipment: bool = true) -> Array[int]:
	var result: Array[int] = state_ids.duplicate()
	if include_equipment:
		for slot in range(1, equipment.size()):
			var automatic := int(_record("Armors", equipment[slot], true).get("auto_state_id", 0))
			if automatic > 0 and not result.has(automatic):
				result.append(automatic)
	result.sort()
	return result


func _state_list_changed() -> void:
	# Existing parameter display already applies state rates. Keep current values
	# within its caps for save consistency; never heal or execute state effects.
	var parameters: Dictionary = snapshot().parameters
	if hp != null and parameters.maxhp != null:
		hp = mini(int(hp), int(parameters.maxhp))
	if sp != null and parameters.maxsp != null:
		sp = mini(int(sp), int(parameters.maxsp))
	changed.emit()


func persistent_data() -> Dictionary:
	return {"id": id, "name": actor_name, "class_id": class_id, "level": level, "experience": experience,
		"hp": hp, "sp": sp, "equipment": equipment.duplicate(), "skill_ids": get_skill_ids(), "state_ids": state_ids.duplicate(),
		"parameter_plus": _parameter_plus.duplicate(), "character_name": character_name, "character_hue": character_hue, "battler_name": battler_name, "battler_hue": battler_hue}


func restore_persistent(saved: Dictionary) -> String:
	# Called only on a new, detached actor. Failure cannot change the live registry.
	class_id = int(saved.class_id)
	actor_name = saved.name
	level = int(saved.level)
	experience = int(saved.experience)
	if level < 1 or level > final_level or experience < _experience_curve[level] or (level < final_level and experience >= _experience_curve[level + 1]):
		return "等级与累计经验不一致。"
	equipment.assign(saved.equipment)
	_skill_ids.assign(saved.skill_ids)
	_skill_ids.sort()
	state_ids.assign(saved.state_ids)
	_parameter_plus = saved.get("parameter_plus", _parameter_plus).duplicate()
	character_name = saved.get("character_name", character_name)
	character_hue = int(saved.get("character_hue", character_hue))
	battler_name = saved.get("battler_name", battler_name)
	battler_hue = int(saved.get("battler_hue", battler_hue))
	var view := snapshot()
	if view.parameters.maxhp == null or view.parameters.maxsp == null:
		return "属性数据不完整，无法恢复 HP/SP。"
	if saved.hp > view.parameters.maxhp or saved.sp > view.parameters.maxsp:
		return "HP/SP 超出当前属性上限。"
	hp = int(saved.hp)
	sp = int(saved.sp)
	return ""


func slot_fixed(slot: int) -> bool:
	var fields := ["weapon_fix", "armor1_fix", "armor2_fix", "armor3_fix", "armor4_fix"]
	return slot < 0 or slot >= fields.size() or bool(_definition.get(fields[slot], false))


func snapshot(equipment_override: Array = [], level_override: int = -1, bonuses_override: Dictionary = {}) -> Dictionary:
	var at_level := level if level_override < 0 else level_override
	var selected: Array = equipment if equipment_override.is_empty() else equipment_override
	var profession := _record("Classes", class_id)
	var equipped: Array[Dictionary] = []
	var invalid_equipment := false
	for slot in selected.size():
		var kind := "Weapons" if slot == 0 else "Armors"
		var entry := _record(kind, int(selected[slot]), true)
		if selected[slot] != 0 and entry.is_empty():
			invalid_equipment = true
		equipped.append({"id": selected[slot], "name": str(entry.get("name", "—" if selected[slot] == 0 else "缺失 #%d" % selected[slot])), "icon_name": str(entry.get("icon_name", "")), "definition": entry})
	var states: Array[Dictionary] = []
	var state_names: Array[String] = []
	var effective_states: Array = state_ids.duplicate()
	for slot in range(1, equipped.size()):
		var automatic := int(equipped[slot].definition.get("auto_state_id", 0))
		if automatic > 0 and not effective_states.has(automatic):
			effective_states.append(automatic)
	for state_id in effective_states:
		var entry := _record("States", state_id)
		states.append(entry)
		state_names.append(str(entry.get("name", "缺失状态 #%d" % state_id)))
	states.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("rating", 0)) > int(b.get("rating", 0)))
	var raw := {}
	for index in Parameters.TABLE_KEYS.size():
		raw[Parameters.TABLE_KEYS[index]] = _base_parameter(index, at_level)
	var definitions: Array[Dictionary] = []
	for item in equipped:
		definitions.append(item.definition)
	var calculated := Parameters.calculate(raw, definitions, states, _parameter_plus if bonuses_override.is_empty() else bonuses_override, invalid_equipment)
	for key in calculated.sources:
		if not calculated.sources[key].reason.is_empty():
			_report("Actors[%d].%s：%s" % [id, key, calculated.sources[key].reason])
	var parameters: Dictionary = calculated.values
	# Never hand database Dictionaries to consumers of a runtime snapshot.
	for item in equipped:
		item.erase("definition")
	return {"id": id, "name": actor_name, "class_name": str(profession.get("name", "缺失职业 #%d" % class_id)), "level": level,
		"hp": hp, "sp": sp, "parameters": parameters, "parameter_sources": calculated.sources, "experience": experience,
		"next_experience": null if level >= final_level else maxi(0, _experience_curve[level + 1] - experience),
		"equipment": equipped, "states": state_names, "skill_ids": get_skill_ids(), "diagnostics": diagnostics.duplicate(),
		"character_name": character_name, "character_hue": character_hue}


func _base_parameter(kind: int, at_level: int = -1) -> Variant:
	if at_level < 0:
		at_level = level
	var table: Dictionary = _definition.get("parameters", {})
	var width := int(table.get("x_size", 0))
	var height := int(table.get("y_size", 0))
	var values: Array = table.get("values", [])
	var offset := kind + at_level * width
	if width <= kind or height <= at_level or offset >= values.size() or not Parameters.integer(values[offset]):
		_report("Actors[%d].parameters[%d,%d] 缺失或无效，无法计算属性。" % [id, kind, at_level])
		return null
	return int(values[offset])


func parameter_sources(key: String) -> Dictionary:
	return snapshot().parameter_sources.get(key, {}).duplicate(true)


func get_parameter(key: String) -> Variant:
	if key == "eva": return evasion()
	return snapshot().parameters.get(key)


func get_base_parameter(key: String) -> Variant:
	return parameter_sources(key).get("base")


func get_equipment_parameter(key: String) -> Variant:
	return parameter_sources(key).get("equipment")


func get_parameter_plus(key: String) -> Variant:
	return _parameter_plus.get(key)


func set_parameter_plus(key: String, value: Variant) -> Dictionary:
	if key not in Parameters.KEYS or not Parameters.integer(value, -Parameters.maximum(key), Parameters.maximum(key)):
		return _result(false, false, "永久修正的属性名或整数范围无效。")
	var proposed := _parameter_plus.duplicate()
	proposed[key] = int(value)
	var view := snapshot([], -1, proposed)
	if view.parameters.values().has(null):
		return _result(false, false, "角色属性数据不完整；永久修正未修改。")
	var modified: bool = _parameter_plus[key] != int(value)
	_parameter_plus = proposed
	_clamp_vitals(view.parameters)
	if modified:
		changed.emit()
	return _result(true, modified, "永久修正已更新；最终值同时受装备、状态倍率和上下限影响。")


func add_parameter_plus(key: String, amount: Variant) -> Dictionary:
	if key not in Parameters.KEYS or not Parameters.integer(amount):
		return _result(false, false, "永久增量的属性名或整数无效。")
	return set_parameter_plus(key, int(_parameter_plus[key]) + int(amount))


func set_parameter(key: String, value: Variant) -> Dictionary:
	if key not in Parameters.KEYS or not Parameters.integer(value, Parameters.minimum(key), Parameters.maximum(key)):
		return _result(false, false, "最终属性的名称或目标范围无效。")
	var source := parameter_sources(key)
	if source.get("value") == null:
		return _result(false, false, "属性无法计算；未修改永久修正。")
	if int(source.value) == int(value):
		return _result(true, false, "最终值已经是目标值。")
	# Exact final-value assignment is distinct from adding a permanent bonus.
	# Integer state multipliers can make some targets unreachable: fail atomically.
	var low := -Parameters.maximum(key)
	var high := Parameters.maximum(key)
	while low < high:
		var middle := low + int((high - low) / 2)
		if Parameters.apply_bonus(key, int(source.base), middle, source.state_rates) < int(value):
			low = middle + 1
		else:
			high = middle
	if Parameters.apply_bonus(key, int(source.base), low, source.state_rates) != int(value):
		return _result(false, false, "现有状态倍率、取整或修正范围使目标值无法精确达到；可改用永久增量接口。")
	return set_parameter_plus(key, low)


func experience_for_level(value: int) -> Variant:
	return _experience_curve[value] if value >= 1 and value <= final_level else null


func next_level_experience() -> Variant:
	return null if level >= final_level else _experience_curve[level + 1]


func set_experience(value: Variant) -> Dictionary:
	if not Parameters.integer(value):
		return _result(false, false, "经验必须是有效整数。")
	var target := clampi(int(value), 0, Parameters.MAX_EXPERIENCE)
	var target_level := level
	while target_level < final_level and _experience_curve[target_level + 1] > 0 and target >= _experience_curve[target_level + 1]:
		target_level += 1
	while target_level > 1 and target < _experience_curve[target_level]:
		target_level -= 1
	return _commit_growth(target_level, target)


func add_experience(amount: Variant) -> Dictionary:
	return set_experience(experience + int(amount)) if Parameters.integer(amount) else _result(false, false, "经验增量必须是整数。")


func set_level(value: Variant) -> Dictionary:
	if not Parameters.integer(value):
		return _result(false, false, "等级必须是有效整数。")
	var target := clampi(int(value), 1, final_level)
	return _commit_growth(target, int(_experience_curve[target]))


func add_level(amount: Variant) -> Dictionary:
	return set_level(level + int(amount)) if Parameters.integer(amount) else _result(false, false, "等级增量必须是整数。")


func _commit_growth(target_level: int, target_experience: int) -> Dictionary:
	var view := snapshot([], target_level)
	if view.parameters.values().has(null):
		return _result(false, false, "目标等级的属性数据不完整；等级和经验未修改。")
	var profession := _record("Classes", class_id)
	if profession.is_empty():
		return _result(false, false, "职业引用缺失；等级和经验未修改。")
	var learned := get_skill_ids()
	for learning in profession.get("learnings", []):
		if not learning is Dictionary:
			return _result(false, false, "职业学习表无效。")
		var learning_level: Variant = learning.get("level", 1)
		if not Parameters.integer(learning_level, 1, 99):
			return _result(false, false, "职业学习等级无效。")
		if learning_level > level and learning_level <= target_level:
			var skill_id: Variant = learning.get("skill_id", 0)
			if not Parameters.integer(skill_id, 1) or _record("Skills", int(skill_id)).is_empty():
				return _result(false, false, "升级特技引用无效；等级、经验和特技均未修改。")
			if not learned.has(int(skill_id)):
				learned.append(int(skill_id))
	learned.sort()
	var modified := level != target_level or experience != target_experience or _skill_ids != learned
	level = target_level
	experience = target_experience
	_skill_ids = learned
	_clamp_vitals(view.parameters)
	if modified:
		changed.emit()
	return _result(true, modified, "等级与经验已更新；降级不遗忘特技，升级不自动恢复 HP/SP。")


func set_vital(key: String, value: Variant) -> Dictionary:
	if key not in ["hp", "sp"] or not Parameters.integer(value):
		return _result(false, false, "HP/SP 名称或整数无效。")
	var cap: Variant = get_parameter("max" + key)
	if cap == null:
		return _result(false, false, "HP/SP 上限无法计算。")
	var target := clampi(int(value), 0, int(cap))
	var modified: bool = get(key) != target
	set(key, target)
	return _result(true, modified, "HP/SP 已更新；不触发状态效果或战斗结算。")


func add_vital(key: String, amount: Variant) -> Dictionary:
	if key not in ["hp", "sp"] or get(key) == null or not Parameters.integer(amount):
		return _result(false, false, "当前 HP/SP 或增量无效。")
	return set_vital(key, int(get(key)) + int(amount))


func recover_vitals() -> Dictionary:
	var values: Dictionary = snapshot().parameters
	if values.maxhp == null or values.maxsp == null:
		return _result(false, false, "HP/SP 上限无法计算；未恢复。")
	var modified: bool = hp != values.maxhp or sp != values.maxsp
	hp = values.maxhp
	sp = values.maxsp
	return _result(true, modified, "HP/SP 已回满；保留已有状态，不触发状态效果。")


func rename(value: Variant) -> Dictionary:
	if not value is String or value.length() > 1024:
		return _result(false, false, "姓名必须是长度不超过 1024 的文本。")
	var modified: bool = actor_name != value
	actor_name = value
	if modified:
		changed.emit()
	return _result(true, modified, "姓名已更新。")


func set_graphic(value: Variant, hue: Variant = 0) -> Dictionary:
	if not value is String or value.length() > 1024 or not Parameters.integer(hue, 0, 360):
		return _result(false, false, "角色图名称或色相无效。")
	var modified: bool = character_name != value or character_hue != int(hue) % 360
	character_name = value
	character_hue = int(hue) % 360
	if modified:
		changed.emit()
	return _result(true, modified, "角色图已更新。")


func set_event_graphic(character: String, hue: int, battler: String, battler_color: int) -> Dictionary:
	if character.length() > 1024 or battler.length() > 1024 or hue < 0 or hue > 360 or battler_color < 0 or battler_color > 360: return _result(false, false, "角色图形名称或色相无效。")
	character_name = character; character_hue = hue % 360
	battler_name = battler; battler_hue = battler_color % 360
	changed.emit()
	return _result(true, true, "角色行走图已更新；战斗图仅保存数据。")

func _clamp_vitals(values: Dictionary) -> void:
	if hp != null and values.maxhp != null:
		hp = clampi(int(hp), 0, int(values.maxhp))
	if sp != null and values.maxsp != null:
		sp = clampi(int(sp), 0, int(values.maxsp))


func _result(ok: bool, modified: bool, message: String) -> Dictionary:
	last_mutation_result = {"ok": ok, "changed": modified, "message": message}
	return last_mutation_result.duplicate()


func _get(property: StringName) -> Variant:
	var key := String(property)
	if key == "exp":
		return experience
	if key == "name":
		return actor_name
	if key in Parameters.KEYS:
		return get_parameter(key)
	if key.ends_with("_plus") and key.trim_suffix("_plus") in Parameters.KEYS:
		return get_parameter_plus(key.trim_suffix("_plus"))
	for prefix in ["base_", "equip_", "database_"]:
		if key.begins_with(prefix) and key.trim_prefix(prefix) in Parameters.KEYS:
			return parameter_sources(key.trim_prefix(prefix)).get({"base_": "base", "equip_": "equipment", "database_": "database"}[prefix])
	return null


func _set(property: StringName, value: Variant) -> bool:
	var key := String(property)
	var result: Dictionary
	if key == "exp":
		result = set_experience(value)
	elif key == "name":
		result = rename(value)
	elif key in Parameters.KEYS:
		result = set_parameter(key, value)
	elif key.ends_with("_plus") and key.trim_suffix("_plus") in Parameters.KEYS:
		result = set_parameter_plus(key.trim_suffix("_plus"), value)
	else:
		return false
	if not result.ok:
		_report(result.message)
	return true


func _record(database: String, record_id: int, allow_empty: bool = false) -> Dictionary:
	if record_id == 0 and allow_empty:
		return {}
	var result: Dictionary = _lookup.call(database, record_id)
	if result.is_empty():
		_report("Actors[%d] 引用了不存在的 %s[%d]。" % [id, database, record_id])
	return result


func _report(message: String) -> void:
	if not diagnostics.has(message):
		diagnostics.append(message)


func evasion() -> Variant:
	var value := 0
	for slot in range(1, equipment.size()):
		if equipment[slot] == 0: continue
		var armor := _record("Armors", equipment[slot])
		if armor.is_empty() or not Parameters.integer(armor.get("eva", 0)): return null
		value += int(armor.get("eva", 0))
	for state_id in get_state_ids():
		var state := _record("States", state_id)
		if state.is_empty() or not Parameters.integer(state.get("eva", 0)): return null
		value += int(state.get("eva", 0))
	return value

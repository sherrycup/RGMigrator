## 职责：执行事件中的角色与队伍修改，统一参数校验和角色状态通知。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/ActorEventService.gd").方法名(...)。
##
## 调用接口：
##   static func execute(state: Node, code: int, p: Array) -> Dictionary
##     用途：执行该脚本或已准备的操作。
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；必填）：对应事件指令的参数数组。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func fail(message: String) -> Dictionary
##     用途：构造或登记带原因的失败结果。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：PARAMETER_KEYS。
## 接口说明结束。

extends RefCounted
## Stage native actor commands off-line; commit only after every target succeeds.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Actor = preload("res://runtime/scripts/00_Game/ActorState.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const Catalog = preload("res://runtime/scripts/02_Event/EventCommandCatalog.gd")
const PARAMETER_KEYS := ["maxhp", "maxsp", "str", "dex", "agi", "int"]


static func execute(state: Node, code: int, p: Array) -> Dictionary:
	var reason := Catalog.reason(code, p)
	if not reason.is_empty():
		return fail(reason)
	var targets: Array = (
		state.party.duplicate()
		if code in [311, 312, 313, 314, 315, 316] and int(p[0]) == 0
		else [int(p[0])]
	)
	var amount := 0
	if code in [311, 312, 315, 316, 317]:
		var offset := 2 if code == 317 else 1
		var raw: Variant = (
			p[offset + 2]
			if int(p[offset + 1]) == 0
			else state.variables.get(str(int(p[offset + 2])), 0)
		)
		if not Actor.Parameters.integer(raw, -99999999, 99999999):
			return fail("增减操作数变量不是有效整数。")
		amount = int(raw) * (1 if int(p[offset]) == 0 else -1)
	var stock: Dictionary = state.inventory.duplicate(true)
	var membership: Array = state.party.duplicate()
	var prepared := {}
	for raw in targets:
		var id := int(raw)
		if prepared.has(id):
			continue
		var definition := Data.record("Actors", id)
		if definition.is_empty():
			return fail("Actors[%d]不存在。" % id)
		var staged: RefCounted
		if state.actors.has(id) and not (code == 129 and int(p[1]) == 0 and int(p[2]) == 1):
			var copy: Dictionary = state.actors[id].detached_copy()
			if not copy.ok:
				return copy
			staged = copy.actor
		else:
			staged = state.create_actor(id, definition, Data.record)
			var initial: Dictionary = staged.apply_equipment_states(staged.automatic_state_ids())
			if not initial.ok:
				return initial
		if (
			(
				not staged.has_method("attach_project_fields")
				and staged.snapshot().parameters.values().has(null)
			)
			or staged.hp == null
			or staged.sp == null
		):
			return fail("Actors[%d]的属性无法计算。" % id)
		var result := {"ok": true}
		match code:
			129:
				if int(p[1]) == 0:
					if (
						not membership.has(id)
						and (staged.has_method("attach_project_fields") or membership.size() < 4)
					):
						membership.append(id)
				else:
					membership.erase(id)
			311:
				result = staged.change_hp_native(amount, p[4], _zero_hp_ids())
			312:
				result = staged.add_vital("sp", amount)
			313:
				result = (
					staged.add_state_native(int(p[2]))
					if int(p[1]) == 0
					else staged.remove_state(int(p[2]))
				)
			314:
				result = staged.recover_all()
			315:
				result = staged.add_experience(amount)
			316:
				result = staged.add_level(amount)
			317:
				var key: String = PARAMETER_KEYS[int(p[1])]
				var limit: int = Actor.Parameters.maximum(key)
				result = staged.set_parameter_plus(
					key, clampi(int(staged.get_parameter_plus(key)) + amount, -limit, limit)
				)
			318:
				result = (
					staged.learn_skill(int(p[2]))
					if int(p[1]) == 0
					else staged.forget_skill(int(p[2]))
				)
			319:
				result = _equip(staged, stock, int(p[1]), int(p[2]))
			320:
				result = staged.rename(p[1])
			321:
				result = _profession(staged, stock, int(p[1]))
			322:
				if not p[1].is_empty():
					var texture: Texture2D = Cache.character(p[1])
					if (
						texture == null
						or texture.get_width() % 4 != 0
						or texture.get_height() % 4 != 0
					):
						return fail("Characters/%s缺失或不是四方向四帧格式；角色图形未修改。" % p[1])
				result = staged.set_event_graphic(p[1], int(p[2]), p[3], int(p[4]))
		if not result.ok:
			return result
		prepared[id] = staged
	# No target, inventory or membership has changed before this boundary.
	state.inventory = stock
	state.party = membership
	for id in prepared:
		if state.actors.has(id):
			state.actors[id].commit_event_state(prepared[id])
		else:
			state.actors[id] = prepared[id]
			prepared[id].changed.connect(func() -> void: state.state_changed.emit())
		if state.actors[id].has_method("attach_project_fields"):
			state.custom_data.values.actors[str(id)] = state.actors[id].project_fields
	state.state_changed.emit()
	var all_dead := false
	if code == 311 and not state.party.is_empty():
		all_dead = state.party.all(
			func(raw: Variant) -> bool:
				return state.actors.has(int(raw)) and state.actors[int(raw)].hp <= 0
		)
	return {"ok": true, "gameover": all_dead}


static func _zero_hp_ids() -> Array:
	var result := []
	var definitions: Array = Data.database("States").duplicate()
	definitions.append_array(Data.testing_snapshot().get("definitions", {}).get("States", []))
	for definition in definitions:
		if (
			definition is Dictionary
			and definition.get("zero_hp", false)
			and int(definition.get("id", 0)) > 0
		):
			var id := int(definition.id)
			if not result.has(id):
				result.append(id)
	return result


static func _equip(actor: RefCounted, stock: Dictionary, slot: int, id: int) -> Dictionary:
	if actor.has_method("equip_project"):
		return actor.equip_project(slot, id)
	var old := int(actor.equipment[slot])
	var kind := "weapon" if slot == 0 else "armor"
	var database := "Weapons" if slot == 0 else "Armors"
	if id > 0:
		var definition := Data.record(database, id)
		if definition.is_empty() or (slot > 0 and int(definition.get("kind", -1)) != slot - 1):
			return fail("装备引用或槽位类型无效。")
		var available: Variant = stock.get("%s:%d" % [kind, id], 0)
		if not Actor.Parameters.integer(available, 0, 99):
			return fail("装备库存无效。")
		if available == 0:
			return {"ok": true}
	if old == id:
		return {"ok": true}
	if old > 0:
		if Data.record(database, old).is_empty():
			return fail("原装备引用缺失。")
		var amount: Variant = stock.get("%s:%d" % [kind, old], 0)
		if not Actor.Parameters.integer(amount, 0, 98):
			return fail("原装备无法安全收回；装备和背包未修改。")
	var previous_auto: Array = actor.automatic_state_ids()
	actor.equipment[slot] = id
	var view: Dictionary = actor.snapshot()
	if view.parameters.values().has(null):
		return fail("装备变更后的属性无效。")
	var linked: Dictionary = actor.apply_equipment_states(previous_auto)
	if not linked.ok:
		return linked
	actor.set_vital("hp", actor.hp)
	actor.set_vital("sp", actor.sp)
	if id > 0:
		stock["%s:%d" % [kind, id]] = int(stock.get("%s:%d" % [kind, id], 0)) - 1
	if old > 0:
		stock["%s:%d" % [kind, old]] = int(stock.get("%s:%d" % [kind, old], 0)) + 1
	return {"ok": true}


static func _profession(actor: RefCounted, stock: Dictionary, id: int) -> Dictionary:
	if actor.has_method("set_project_class"):
		return actor.set_project_class(id)
	var profession := Data.record("Classes", id)
	if profession.is_empty():
		return fail("目标职业不存在。")
	for slot in 5:
		var equipment_id := int(actor.equipment[slot])
		if equipment_id == 0:
			continue
		var database := "Weapons" if slot == 0 else "Armors"
		if Data.record(database, equipment_id).is_empty():
			return fail("当前装备引用缺失。")
		var allowed: Variant = profession.get("weapon_set" if slot == 0 else "armor_set", [])
		if not allowed is Array:
			return fail("职业装备表无效。")
		if (
			Data.is_test_record(database, equipment_id)
			or allowed.any(func(raw: Variant) -> bool: return int(raw) == equipment_id)
		):
			continue
		var result := _equip(actor, stock, slot, 0)
		if not result.ok:
			return result
	actor.class_id = id
	return {"ok": true}


static func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

extends RefCounted
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const InputButtons = preload("res://runtime/scripts/EventInput.gd")
const Decimal = preload("res://runtime/scripts/DecimalInteger.gd")
const PARAMETER_KEYS := ["maxhp", "maxsp", "str", "dex", "agi", "int", "atk", "pdef", "mdef", "eva"]

static func character(map: Node, event_id: int, id: int) -> Node:
	if id == -1: return RuntimeState.player()
	if map == null: return null
	return map.event_node(event_id if id == 0 else id)

static func condition(p: Array, map: Node, event_id: int) -> Dictionary:
	var result := false
	if int(p[0]) == 4:
		if Data.record("Actors", int(p[1])).is_empty(): return _fail("条件引用的 Actors[%d] 不存在。" % int(p[1]))
		var database: String = {2: "Skills", 3: "Weapons", 4: "Armors", 5: "States"}.get(int(p[2]), "")
		if not database.is_empty() and int(p[3]) > 0 and Data.record(database, int(p[3])).is_empty(): return _fail("条件引用的 %s[%d] 不存在。" % [database, int(p[3])])
	if int(p[0]) in [8, 9, 10]:
		var database: String = ["Items", "Weapons", "Armors"][int(p[0]) - 8]
		if Data.record(database, int(p[1])).is_empty(): return _fail("条件引用的 %s[%d] 不存在。" % [database, int(p[1])])
	match int(p[0]):
		0: result = bool(RuntimeState.switches.get(str(int(p[1])), false)) == (int(p[2]) == 0)
		1:
			if not numeric_variable(RuntimeState.variables.get(str(int(p[1])),0)) or int(p[2])!=0 and not numeric_variable(RuntimeState.variables.get(str(int(p[3])),0)): return _fail("数值条件引用了自定义集合或非整数变量。")
			var left := int(RuntimeState.variables.get(str(int(p[1])), 0))
			var right := int(p[3]) if int(p[2]) == 0 else int(RuntimeState.variables.get(str(int(p[3])), 0))
			result = [left == right, left >= right, left <= right, left > right, left < right, left != right][int(p[4])]
		2: result = event_id > 0 and bool(RuntimeState.self_switches.get(RuntimeState.self_switch_key(RuntimeState.map_id, event_id, p[1]), false)) == (int(p[2]) == 0)
		3:
			var seconds := int(RuntimeState.timer.remaining)
			result = RuntimeState.timer.working and (seconds >= int(p[1]) if int(p[2]) == 0 else seconds <= int(p[1]))
		4:
			var actor: RefCounted = RuntimeState.actor(int(p[1]))
			if actor != null:
				match int(p[2]):
					0: result = RuntimeState.party.has(int(p[1]))
					1: result = actor.actor_name == p[3]
					2: result = actor.has_skill(int(p[3]))
					3: result = actor.equipment[0] == int(p[3])
					4:
						for slot in range(1, actor.equipment.size()):
							if actor.equipment[slot] == int(p[3]): result = true
					5: result = actor.has_state(int(p[3]))
		6:
			var node := character(map, event_id, int(p[1]))
			result = node != null and node.motion.direction == int(p[2])
		7:
			if not RuntimeState.custom_data.valid_currency(RuntimeState.gold): return _fail("金币状态无效。")
			result = Decimal.compare(RuntimeState.gold,int(p[1]))>=0 if int(p[2])==0 else Decimal.compare(RuntimeState.gold,int(p[1]))<=0
		8, 9, 10: result = int(RuntimeState.inventory.get("%s:%d" % [["item", "weapon", "armor"][int(p[0]) - 8], int(p[1])], 0)) > 0
		11: result = InputButtons.pressed(int(p[1]))
	return {"ok": true, "value": result}

static func operand(p: Array, map: Node, event_id: int) -> Dictionary:
	var value: Variant = null
	match int(p[3]):
		0: value = int(p[4])
		1: value = RuntimeState.variables.get(str(int(p[4])), 0)
		2: value = randi_range(int(p[4]), int(p[5]))
		3:
			if Data.record("Items", int(p[4])).is_empty(): return _fail("变量引用的物品不存在。")
			value = int(RuntimeState.inventory.get("item:%d" % int(p[4]), 0))
		4:
			if Data.record("Actors", int(p[4])).is_empty(): return _fail("变量引用的角色不存在。")
			var actor: RefCounted = RuntimeState.actor(int(p[4]))
			if actor == null: return _fail("变量引用的角色不存在。")
			match int(p[5]):
				0: value = actor.level
				1: value = actor.experience
				2: value = actor.hp
				3: value = actor.sp
				_: value = actor.get_parameter(PARAMETER_KEYS[int(p[5]) - 4])
		6:
			var node := character(map, event_id, int(p[4]))
			if node == null: return _fail("变量引用的人物不存在。")
			match int(p[5]):
				0: value = node.motion.cell.x
				1: value = node.motion.cell.y
				2: value = node.motion.direction
				3, 4:
					var view: RefCounted = RuntimeState.map_view
					var offset: Vector2 = view.view_rect(node.get_viewport_rect().size).position
					var point: Vector2 = node.motion.visual_cell * 32 - view.display + offset + Vector2(16, 32 - node.motion.jump_height)
					value = int(round(point.x if int(p[5]) == 3 else point.y))
				5:
					if map == null: return _fail("地形取值缺少地图上下文。")
					value = map.terrain_tag(node.motion.cell.x, node.motion.cell.y)
		7:
			value = [RuntimeState.map_id, RuntimeState.party.size(), RuntimeState.gold, RuntimeState.steps, int(RuntimeState.play_seconds), int(RuntimeState.timer.remaining), RuntimeState.save_count][int(p[4])]
	if value == null: return _fail("变量操作数数据缺失，无法计算；未修改变量。")
	if value is String: return _fail("金币超出原生事件变量精确整数范围；请使用迁移脚本货币接口。")
	if not numeric_variable(value): return _fail("数值操作数引用了自定义集合或非整数变量。")
	return {"ok": true, "value": int(value)}

static func numeric_variable(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and abs(float(value))<=9007199254740991

static func calculate(current: int, operation: int, operand_value: int) -> int:
	var value := current
	match operation:
		0: value = operand_value
		1: value += operand_value
		2: value -= operand_value
		3: value = int(clampf(float(value) * float(operand_value), -99999999, 99999999))
		4, 5:
			if operand_value != 0:
				# Ruby integer division floors; remainder has the divisor's sign.
				var quotient := current / operand_value
				if current % operand_value != 0 and (current < 0) != (operand_value < 0): quotient -= 1
				value = quotient if operation == 4 else current - quotient * operand_value
	return clampi(value, -99999999, 99999999)

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

## 职责：计算闪翼灵视对象、详情和可见信息，为灵视页面提供数据。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/Sight/SightModel.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(owner: Object, map: Node) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 map（Node；必填）：当前接口使用的地图数据或地图对象。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func reset_free() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func events() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func event_at_cursor() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func enemy_groups() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func item_groups() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func set_focus(value: int) -> void
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func update_group() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func select_group() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func move_cursor(direction: Vector2i, viewport_size: Vector2) -> void
##     参数 direction（Vector2i；必填）：当前操作使用的方向或选择移动量。
##     参数 viewport_size（Vector2；必填）：当前视口的宽度与高度，单位为像素。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func view_bounds(viewport_size: Vector2) -> Rect2i
##     参数 viewport_size（Vector2；必填）：当前视口的宽度与高度，单位为像素。
##     返回：Rect2i 类型的对象或值，供调用方继续使用。
##
##   func enemy_snapshot() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func skill_presentation(action: Dictionary, skill_set: Dictionary) -> Dictionary
##     参数 action（Dictionary；必填）：战斗行动或当前操作的数据。
##     参数 skill_set（Dictionary；必填）：角色当前技能组或技能槽配置。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func description() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 公开常量：FOCUS_NAMES、ITEM_NAMES。
## 接口说明结束。

extends RefCounted
## 0231–0240/0202: inspect current map, source focus axes and ordinary battle data.
const Bridge = preload("../../03_Map/MapBridge.gd")
const Enemy = preload("../../00_Game/EnemyState.gd")
const Presets = preload("../Item/ItemPresets.gd")
const Data = preload("../../00_Game/RuntimeData.gd")
const FOCUS_NAMES = ["自由", "敌人", "物品", "BUFF"]
const ITEM_NAMES = ["宝石", "钥匙", "药品"]
var cursor = Vector2i.ZERO
var focus = 0
var stage = "map"
var list_index = 0
var skill_index = 0
var focused_ids: Array = []
var groups: Array = []
var description_visible = true
var failure = ""
var _owner: WeakRef
var _map: WeakRef


func _init(owner: Object, map: Node) -> void:
	_owner = weakref(owner)
	_map = weakref(map)
	reset_free()


func reset_free() -> void:
	var owner = _owner.get_ref()
	focus = 0
	stage = "map"
	cursor = Vector2i(owner.player_x, owner.player_y)
	focused_ids = []
	groups = []
	list_index = 0
	skill_index = 0
	description_visible = true


func events() -> Array:
	var owner = _owner.get_ref()
	var map = _map.get_ref()
	var result: Array = []
	if owner == null or map == null:
		return result
	for entry in map.event_contexts():
		var id = int(entry.event_id)
		if Bridge.is_dead(owner.custom_data, owner.map_id, id):
			continue
		result.append(
			{
				"id": id,
				"name": Bridge.event_name(owner.custom_data, owner.map_id, id),
				"cell": entry.node.tile_position,
				"node": entry.node
			}
		)
	result.sort_custom(func(a, b): return a.id < b.id)
	return result


func event_at_cursor() -> Dictionary:
	for entry in events():
		if entry.cell == cursor:
			return entry
	return {}


func enemy_groups() -> Array:
	var owner = _owner.get_ref()
	var result: Array = []
	if not owner.switches.get("3", false):
		return result
	var by_id: Dictionary = {}
	var floor = owner.custom_data._floor(owner.map_id)
	for event in events():
		var entry: Dictionary = floor.entries.get(str(event.id), {})
		if entry.is_empty() or entry.get("battle", {}).get("defeated", false):
			continue
		var id = int(entry.fields.id)
		if not by_id.has(id):
			by_id[id] = {
				"id": id,
				"name":
				str(
					owner.custom_data.gameplay().enemy_fields(owner.map_id, event.id).get(
						"name", ""
					)
				),
				"event_ids": [],
				"node": event.node
			}
		by_id[id].event_ids.append(event.id)
	for id in by_id:
		result.append(by_id[id])
	return result


func item_groups() -> Array:
	var result: Array = []
	for name in ITEM_NAMES:
		var ids: Array = []
		for event in events():
			if event.name.contains(name):
				ids.append(event.id)
		result.append({"id": result.size() + 1, "name": name, "event_ids": ids})
	return result


func set_focus(value: int) -> void:
	focus = posmod(value, 4)
	cursor = Vector2i(_owner.get_ref().player_x, _owner.get_ref().player_y)
	skill_index = 0
	list_index = 0
	groups = enemy_groups() if focus == 1 else item_groups() if focus == 2 else []
	stage = "list" if focus in [1, 2] else "map"
	update_group()
	# Source BUFF hook resets free cursor; it has no list or status filtering yet.


func update_group() -> void:
	focused_ids = (
		[]
		if groups.is_empty()
		else groups[clampi(list_index, 0, groups.size() - 1)].event_ids.duplicate()
	)


func select_group() -> bool:
	var owner = _owner.get_ref()
	var target: Variant = null
	var minimum = 2147483647
	for event in events():
		if event.id not in focused_ids:
			continue
		var distance = absi(owner.player_x - event.cell.x) + absi(owner.player_y - event.cell.y)
		if distance < minimum:
			minimum = distance
			target = event.cell
	if target == null:
		return false
	cursor = target
	stage = "targets"
	skill_index = 0
	return true


func move_cursor(direction: Vector2i, viewport_size: Vector2) -> void:
	if stage == "targets":
		var axis: Array = []
		for event in events():
			if event.id in focused_ids and event.cell not in axis:
				axis.append(event.cell)
		var vertical = direction.y != 0
		axis.sort_custom(
			func(a, b):
				return (
					(a.y < b.y if a.y != b.y else a.x < b.x)
					if vertical
					else (a.x < b.x if a.x != b.x else a.y < b.y)
				)
		)
		var current = axis.find(cursor)
		if current < 0:
			return
		for i in range(1, axis.size() + 1):
			var value: Vector2i = axis[posmod(
				current + i * (direction.y if vertical else direction.x), axis.size()
			)]
			if (value.y if vertical else value.x) != (cursor.y if vertical else cursor.x):
				cursor = value
				skill_index = 0
				return
		return
	var bounds = view_bounds(viewport_size)
	cursor += direction
	if cursor.x < bounds.position.x:
		cursor.x = bounds.end.x - 1
	elif cursor.x >= bounds.end.x:
		cursor.x = bounds.position.x
	if cursor.y < bounds.position.y:
		cursor.y = bounds.end.y - 1
	elif cursor.y >= bounds.end.y:
		cursor.y = bounds.position.y
	skill_index = 0


func view_bounds(viewport_size: Vector2) -> Rect2i:
	var owner = _owner.get_ref()
	var map = _map.get_ref()
	var rect = owner.map_view.view_rect(viewport_size)
	var left = maxi(0, int(floor(owner.map_view.display.x / 32)))
	var top = maxi(0, int(floor(owner.map_view.display.y / 32)))
	return Rect2i(
		left,
		top,
		maxi(1, mini(map.map_width() - left, int(rect.size.x / 32))),
		maxi(1, mini(map.map_height() - top, int(rect.size.y / 32)))
	)


func enemy_snapshot() -> Dictionary:
	var owner = _owner.get_ref()
	var event = event_at_cursor()
	if event.is_empty() or not owner.custom_data._floor(owner.map_id).entries.has(str(event.id)):
		return {}
	var gameplay = owner.custom_data.gameplay()
	var enemy = gameplay.enemy_input(owner.map_id, event.id)
	if enemy.is_empty() or enemy.defeated:
		return {}
	var result: Variant = gameplay.predict(owner.map_id, event.id)
	if not result is Dictionary:
		failure = owner.custom_data.failure
		return {}
	var party = gameplay.party_snapshot()
	var fields = gameplay.enemy_fields(owner.map_id, event.id)
	var enemy_skill_set = gameplay.simulator.resolve_enemy_skills(enemy.actions, enemy.patience)
	var source_entry = owner.custom_data._floor(owner.map_id).entries[str(event.id)]
	var enemy_state = Enemy.new(owner.custom_data, source_entry, fields, owner.map_id, event.id)
	return {
		"event": event,
		"enemy": enemy,
		"fields": fields,
		"result": result,
		"attributes": gameplay.simulator.enemy_attributes(party[0], party[1], enemy),
		"skill_set": enemy_skill_set,
		"skills": enemy_skill_set.visible_entries,
		"drops": enemy_state.invoke("drop_table", []),
		"timeline": gameplay.simulator.legacy_log(result)
	}


func skill_presentation(action: Dictionary, skill_set: Dictionary) -> Dictionary:
	var gameplay = _owner.get_ref().custom_data.gameplay()
	var id = 0 if int(action.get("kind", 0)) == 0 else int(action.get("skill_id", 0))
	var definition: Dictionary = gameplay.simulator.skills.get(str(id), Data.record("Skills", id))
	var name = "普通攻击" if int(action.get("kind", 0)) == 0 else str(definition.get("name", ""))
	name = name.replace("：", ":").get_slice(":", 0).strip_edges()
	var description = (
		"最为朴素的攻击方式，没有其他的能力。"
		if int(action.get("kind", 0)) == 0
		else str(definition.get("description", ""))
	)
	for rule in skill_set.get("rage_progress", {}).get(str(id), []):
		description += (
			("\n" if not description.is_empty() else "") + "耐心低于%d：%s" % [rule[0], rule[1]]
		)
	var origin = str(action.get("origin", "base"))
	var label = "Grant" if origin == "grant" else "Override" if origin == "override" else ""
	if not label.is_empty():
		description = "来源：狂暴（" + label + "）\n" + description
	var type = (
		"rage"
		if definition.get("kind") == "rage"
		else (
			"passive"
			if definition.get("kind") in gameplay.simulator.PASSIVES + gameplay.simulator.REACTIONS
			else (
				"ordinary"
				if (
					id == 0
					or (
						int(action.get("condition_turn_a", 0)) == 0
						and int(action.get("condition_turn_b", 0)) == 1
					)
				)
				else (
					"passive"
					if (
						int(action.get("condition_turn_a", 0)) == 0
						and int(action.get("condition_turn_b", 0)) == 0
					)
					else "active"
				)
			)
		)
	)
	return {
		"id": id,
		"name": name,
		"description": description.replace("\\n", "\n"),
		"type": type,
		"origin": label,
		"stiffness": int(definition.get("stiffness", definition.get("power", 0))),
		"turn": int(action.get("condition_turn_a", 0)),
		"period": int(action.get("condition_turn_b", 0)),
		"color":
		{
			"ordinary": Color8(96, 192, 255),
			"active": Color8(255, 216, 96),
			"passive": Color8(96, 128, 224),
			"rage": Color8(255, 96, 112)
		}[type]
	}


func description() -> String:
	var event = event_at_cursor()
	if event.is_empty():
		return ""
	var expression = RegEx.new()
	expression.compile("^物品([0-9]+):*([0-9]*)")
	var match_value = expression.search(event.name)
	if match_value != null:
		return (
			str(
				Presets.native_item(int(match_value.get_string(1)), _owner.get_ref()).get(
					"description", ""
				)
			)
			. get_slice("@", 0)
		)
	expression.compile("^门([0-9]+)")
	match_value = expression.search(event.name)
	if match_value != null:
		var id = int(match_value.get_string(1))
		var colors: Array = _owner.get_ref().custom_data.gameplay().rules.constants.get(
			"DOOR_COLOR", []
		)
		if id in [1, 2, 3, 5] and id < colors.size():
			return str(colors[id]) + "颜色的门，打开需要1把" + str(colors[id]) + "钥匙"
	return ""  # Original arbitrary-name descriptions and doors0/4 are empty.

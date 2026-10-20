## 职责：将闪翼原脚本的人物属性和操作映射到当前地图人物实例。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/CharacterBridge.gd").方法名(...)。
##
## 调用接口：
##   static func invoke(custom: RefCounted, ref: Dictionary, name: String, args: Array) -> Variant
##     用途：按给定名称和参数分派对应调用。
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 ref（Dictionary；必填）：待查询或修改的脚本对象引用。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 args（Array；必填）：按调用顺序排列的参数值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func validate(edits: Array) -> String
##     用途：检查输入数据是否符合该服务的约定。
##     参数 edits（Array；必填）：待发布的文本或数据修改集合。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func commit(edits: Array) -> void
##     参数 edits（Array；必填）：待发布的文本或数据修改集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## Native character/animation access from 0005 and 0093-0096.
## Validate and stage every effect; publish only after the script transaction succeeds.
const Data = preload("../00_Game/RuntimeData.gd")


static func invoke(custom: RefCounted, ref: Dictionary, name: String, args: Array) -> Variant:
	var state: Node = custom._owner.get_ref()
	var game: Node = state.game()
	var map: Node = game.event_map() if game != null else null
	var target_id = -1 if ref.__custom_ref == "player" else int(ref.event)
	var target: Node = (
		map.animation_target(target_id) if map != null and state.map_id == ref.id else null
	)
	if target == null:
		return custom.reject("脚本缺少当前地图人物：%d/%d" % [ref.id, target_id])
	if name == "speed_change" and args.size() == 1:
		name = "move_speed="
	if name.ends_with("=") and args.size() == 1:
		var field = name.trim_suffix("=")
		if field == "name" and target_id > 0 and args[0] is String:
			preload("MapBridge.gd").set_event_name(custom, int(ref.id), target_id, args[0])
			custom.character_edits.append(
				{
					"target": weakref(target),
					"map": weakref(map),
					"id": target_id,
					"field": "refresh",
					"value": null
				}
			)
			return args[0]
		if field == "animation_id":
			if not custom._integer(args[0]) or args[0] < 0:
				return custom.reject("动画编号必须为非负整数。")
			var resolved: Dictionary = (
				load("res://runtime/scripts/09_Effects/RmxpAnimationData.gd").resolve(int(args[0]))
			)
			if not resolved.ok:
				return custom.reject(resolved.message)
		elif target.motion.DEFAULTS.has(field):
			var options = {field: args[0]}
			if not target.motion.validate(options):
				return custom.reject("人物参数无效：" + field)
			custom.character_edits.append(
				{
					"target": weakref(target),
					"map": weakref(map),
					"id": target_id,
					"field": "motion_options",
					"value": options
				}
			)
			return args[0]
		else:
			return custom.reject("人物写接口尚未接入：" + field)
		custom.character_edits.append(
			{
				"target": weakref(target),
				"map": weakref(map),
				"id": target_id,
				"field": field,
				"value": args[0]
			}
		)
		return args[0]
	if args.is_empty():
		if name == "refresh" and target_id == -1:
			var ids = custom.gameplay().role_actor_ids()
			var actor = (
				custom.staged_actor(int(ids[0]))
				if not custom.party_ids.is_empty() and ids[0] > 0
				else null
			)
			custom.character_edits.append(
				{
					"target": weakref(target),
					"map": weakref(map),
					"id": target_id,
					"field": "player_refresh",
					"value":
					{
						"name": actor.character_name if actor != null else "",
						"hue": actor.character_hue if actor != null else 0
					}
				}
			)
			return null
		if name in ["move_down", "move_left", "move_right", "move_up"]:
			for edit in custom.character_edits:
				if edit.target.get_ref() == target and edit.field == "move_straight":
					return custom.reject("同一事务中的连续人物移动需要路线接口；未提交部分位移。")
			var direction: int = {"move_down": 2, "move_left": 4, "move_right": 6, "move_up": 8}[name]
			var offset: Vector2i = target.motion.DIRECTIONS[direction]
			var started: bool = (
				target.motion.is_idle()
				and map.can_move(
					target.motion.cell, offset, bool(target.motion.options.through), target_id
				)
			)
			var position: Vector2i = target.motion.cell + offset if started else target.motion.cell
			custom.character_edits.append(
				{
					"target": weakref(target),
					"map": weakref(map),
					"id": target_id,
					"field": "move_straight",
					"value": direction,
					"position": [position.x, position.y]
				}
			)
			return null
		if name == "event" and target_id > 0:
			return custom.data_ref("event_definition", int(ref.id), "", target_id)
		if target_id > 0 and name in ["erase", "refresh", "die"]:
			if name == "die":
				preload("MapBridge.gd").set_event_name(
					custom,
					int(ref.id),
					target_id,
					str(custom.gameplay().rules.constants.DEFAULT_DEAD_CODE)
				)
				custom.values.system.get("event_page", {}).get(str(ref.id), {}).erase(
					str(target_id)
				)
			custom.character_edits.append(
				{
					"target": weakref(target),
					"map": weakref(map),
					"id": target_id,
					"field": "erase" if name == "erase" else "refresh",
					"value": null
				}
			)
			return null
		if name == "dead?" and target_id > 0:
			return preload("MapBridge.gd").is_dead(custom, int(ref.id), target_id)
		if name in ["x", "y", "position"]:
			var position: Array = [target.motion.target.x, target.motion.target.y]
			for edit in custom.character_edits:
				if edit.target.get_ref() == target:
					if edit.field == "move_to":
						position = edit.value
					elif edit.field == "move_straight":
						position = edit.position
			return position if name == "position" else position[0 if name == "x" else 1]
		if name in ["direction", "animation_id"] or target.motion.DEFAULTS.has(name):
			var value: Variant = (
				target.motion.direction
				if name == "direction"
				else target.motion.options.get(name, 0)
			)
			for edit in custom.character_edits:
				if edit.target.get_ref() == target:
					if edit.field == name:
						value = edit.value
					elif edit.field == "motion_options" and edit.value.has(name):
						value = edit.value[name]
					elif (
						name == "direction"
						and edit.field == "move_straight"
						and not target.motion.options.direction_fix
					):
						value = edit.value
			return value
		if name == "name" and target_id > 0:
			return preload("MapBridge.gd").event_name(custom, int(ref.id), target_id)
		if name == "id":
			return target_id
	return custom.reject("人物读接口尚未接入：" + name)


static func validate(edits: Array) -> String:
	for edit in edits:
		var target: Node = edit.target.get_ref()
		var map: Node = edit.map.get_ref()
		if (
			target == null
			or map == null
			or target.is_queued_for_deletion()
			or map.is_queued_for_deletion()
		):
			return "脚本人物目标已失效；事务未提交。"
	return ""


static func commit(edits: Array) -> void:
	var tiles: Dictionary = {}
	var refreshed: Dictionary = {}
	for edit in edits:
		var target: Node = edit.target.get_ref()
		var map: Node = edit.map.get_ref()
		if edit.field == "opacity":
			target.opacity = int(edit.value)
		elif edit.field == "motion_options":
			target.configure_motion(edit.value)
		elif edit.field == "animation_id":
			map.play_animation(int(edit.value), int(edit.id))
		elif edit.field == "erase":
			map.erase_event(int(edit.id))
		elif edit.field == "refresh":
			refreshed[map.get_instance_id()] = map
		elif edit.field == "player_refresh":
			target.set_graphic(str(edit.value.name), int(edit.value.hue))
			target.opacity = 255
			target.blend_type = 0
		elif edit.field == "tile":
			var key = map.get_instance_id()
			if not tiles.has(key):
				tiles[key] = {"map": map, "changes": {}}
			tiles[key].changes["%d:%d:%d" % [edit.value[0], edit.value[1], edit.value[2]]] = (
				edit.value[3]
			)
		elif edit.field == "move_to":
			target.move_to(int(edit.value[0]), int(edit.value[1]))
			var state: Node = map.get_node("/root/RuntimeState")
			if int(edit.id) == -1:
				state.player_x = int(edit.value[0])
				state.player_y = int(edit.value[1])
		elif edit.field == "move_straight":
			target.move_straight(int(edit.value))
		elif edit.field == "follower_call":
			map.get_node("/root/RuntimeState").flash_followers.callv(
				edit.value.method, edit.value.args
			)
	for batch in tiles.values():
		batch.map.apply_flash_tiles(batch.changes)
	for map in refreshed.values():
		map.refresh_events()

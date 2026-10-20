## 职责：管理单个地图事件的有效页、触发方式、图形和自主移动。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/MapEvent.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func configure(event_data: Dictionary, page: Dictionary, id: int, current_map_id: int) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 event_data（Dictionary；必填）：原地图事件的完整记录。
##     参数 page（Dictionary；必填）：事件页或界面页数据。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 current_map_id（int；必填）：当前正在运行的地图编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func front_interaction() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func lock() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func unlock() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func route_locked() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func clear_route_lock_direction() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_route_graphic(name_value: String, hue: int, direction: int, pattern: int) -> void
##     参数 name_value（String；必填）：待设置的名称文本。
##     参数 hue（int；必填）：素材色相参数。
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 pattern（int；必填）：匹配模式或图形帧编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func move_straight(direction: int, turn_on_failure: bool = true) -> bool
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 turn_on_failure（bool；默认值 true）：移动失败时是否仍改变朝向。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func move_diagonal(offset: Vector2i) -> bool
##     参数 offset（Vector2i；必填）：相对基准的偏移量。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func jump(x: int, y: int) -> bool
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 场景树回调（Godot 自动调用）：
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

class_name MapEvent
extends "res://runtime/scripts/03_Map/MapCharacter.gd"
var event_id := 0
var map_id := 0
var trigger := 0
var commands: Array = []
var blocking := false
var page_index := 1
var tile_id := 0
var locked := false
var _prelock_direction := 2
var _page_signature := ""


func configure(event_data: Dictionary, page: Dictionary, id: int, current_map_id: int) -> void:
	if event_id != id or map_id != current_map_id:
		motion.relocate(Vector2i(int(event_data.get("x", 0)), int(event_data.get("y", 0))))
	event_id = id
	character_id = id
	map_id = current_map_id
	trigger = int(page.get("trigger", 0))
	commands = page.get("list", [])
	var signature := JSON.stringify(page)
	if signature == _page_signature:
		return
	_page_signature = signature
	var graphic: Dictionary = page.get("graphic", {})
	tile_id = int(graphic.get("tile_id", 0))
	var name_value := str(graphic.get("character_name", ""))
	blocking = not name_value.is_empty() and tile_id == 0
	fallback_visible = not name_value.is_empty()
	motion.configure(
		{
			"move_speed": clampi(int(page.get("move_speed", 4)), 1, 6),
			"walk_anime": bool(page.get("walk_anime", true)),
			"step_anime": bool(page.get("step_anime", false)),
			"direction_fix": bool(page.get("direction_fix", false)),
			"through": bool(page.get("through", false)),
			"opacity": clampi(int(graphic.get("opacity", 255)), 0, 255),
			"blend_type": clampi(int(graphic.get("blend_type", 0)), 0, 2)
		}
	)
	_apply_graphic_pose(
		int(graphic.get("direction", 2)), clampi(int(graphic.get("pattern", 0)), 0, 3)
	)
	always_on_top = bool(page.get("always_on_top", false))
	set_graphic(name_value, int(graphic.get("character_hue", 0)), tile_id)
	var route: Variant = page.get(
		"move_route", {"repeat": false, "skippable": false, "list": [{"code": 0}]}
	)
	routes.configure(
		page.get("move_type", 0),
		page.get("move_frequency", 3),
		route,
		(
			"Map%03d / 事件 %d / 第 %d 页"
			% [current_map_id, id, event_data.get("pages", []).find(page) + 1]
		)
	)


func front_interaction() -> bool:
	if blocking and not through:
		return true
	return map_runtime != null and not map_runtime.can_overlap_trigger(tile_position)


func lock() -> void:
	if locked:
		return
	locked = true
	_prelock_direction = motion.direction
	if map_runtime.player_character == null:
		return
	var difference: Vector2i = map_runtime.player_character.tile_position - tile_position
	if difference == Vector2i.ZERO:
		return
	turn(
		(
			(6 if difference.x > 0 else 4)
			if absi(difference.x) > absi(difference.y)
			else (2 if difference.y > 0 else 8)
		)
	)


func unlock() -> void:
	if not locked:
		return
	locked = false
	if _prelock_direction > 0:
		motion.turn(_prelock_direction, true)
	_sync_position()


func route_locked() -> bool:
	return locked


func clear_route_lock_direction() -> void:
	_prelock_direction = 0


func set_route_graphic(name_value: String, hue: int, direction: int, pattern: int) -> void:
	tile_id = 0
	blocking = not name_value.is_empty()
	fallback_visible = blocking
	super.set_route_graphic(name_value, hue, direction, pattern)


func move_straight(direction: int, turn_on_failure: bool = true) -> bool:
	if locked and not routes.forcing:
		return false
	var moved := super.move_straight(direction, turn_on_failure)
	if not moved and motion.is_idle() and motion.DIRECTIONS.has(direction):
		map_runtime.request_event_touch(self, tile_position + motion.DIRECTIONS[direction])
	return moved


func move_diagonal(offset: Vector2i) -> bool:
	return false if locked and not routes.forcing else super.move_diagonal(offset)


func jump(x: int, y: int) -> bool:
	return false if locked and not routes.forcing else super.jump(x, y)


func _process(delta: float) -> void:
	if (
		RuntimeState.game() != null
		and RuntimeState.game().event_map() == map_runtime
		and RuntimeState.map_time_paused()
	):
		return
	advance_motion(delta)
	if motion.is_idle() and map_runtime != null:
		map_runtime.request_event_touch(self, tile_position)

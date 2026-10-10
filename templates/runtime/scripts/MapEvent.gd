class_name MapEvent
extends "res://runtime/scripts/MapCharacter.gd"
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
	if signature == _page_signature: return
	_page_signature = signature
	var graphic: Dictionary = page.get("graphic", {})
	tile_id = int(graphic.get("tile_id", 0))
	var name_value := str(graphic.get("character_name", ""))
	blocking = not name_value.is_empty() and tile_id == 0
	fallback_visible = not name_value.is_empty()
	motion.configure({"move_speed": clampi(int(page.get("move_speed", 4)), 1, 6), "walk_anime": bool(page.get("walk_anime", true)), "step_anime": bool(page.get("step_anime", false)), "direction_fix": bool(page.get("direction_fix", false)), "through": bool(page.get("through", false)), "opacity": clampi(int(graphic.get("opacity", 255)), 0, 255), "blend_type": clampi(int(graphic.get("blend_type", 0)), 0, 2)})
	_apply_graphic_pose(int(graphic.get("direction", 2)), clampi(int(graphic.get("pattern", 0)), 0, 3))
	always_on_top = bool(page.get("always_on_top", false))
	set_graphic(name_value, int(graphic.get("character_hue", 0)), tile_id)
	var route: Variant = page.get("move_route", {"repeat": false, "skippable": false, "list": [{"code": 0}]})
	routes.configure(page.get("move_type", 0), page.get("move_frequency", 3), route,
		"Map%03d / 事件 %d / 第 %d 页" % [current_map_id, id, event_data.get("pages", []).find(page) + 1])


func front_interaction() -> bool:
	if blocking and not through: return true
	return map_runtime != null and not map_runtime.can_overlap_trigger(tile_position)


func lock() -> void:
	if locked: return
	locked = true
	_prelock_direction = motion.direction
	if map_runtime.player_character == null: return
	var difference: Vector2i = map_runtime.player_character.tile_position - tile_position
	if difference == Vector2i.ZERO: return
	turn((6 if difference.x > 0 else 4) if absi(difference.x) > absi(difference.y) else (2 if difference.y > 0 else 8))


func unlock() -> void:
	if not locked: return
	locked = false
	if _prelock_direction > 0: motion.turn(_prelock_direction, true)
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
	if locked and not routes.forcing: return false
	var moved := super.move_straight(direction, turn_on_failure)
	if not moved and motion.is_idle() and motion.DIRECTIONS.has(direction): map_runtime.request_event_touch(self, tile_position + motion.DIRECTIONS[direction])
	return moved


func move_diagonal(offset: Vector2i) -> bool:
	return false if locked and not routes.forcing else super.move_diagonal(offset)


func jump(x: int, y: int) -> bool:
	return false if locked and not routes.forcing else super.jump(x, y)


func _process(delta: float) -> void:
	if RuntimeState.game() != null and RuntimeState.game().event_map() == map_runtime and RuntimeState.map_time_paused(): return
	advance_motion(delta)
	if motion.is_idle() and map_runtime != null: map_runtime.request_event_touch(self, tile_position)

extends Camera2D
var model: RefCounted
var map: Node2D
var player: Node2D
var _map_id := -999
var _revision := -1

func _ready() -> void:
	# One owner of camera position. ScreenRenderer owns only shake offset.
	position_smoothing_enabled = false

func sync(delta: float = 0.0, snap: bool = false) -> void:
	if model == null or map == null or player == null: return
	var extent := Vector2(map.map_width(), map.map_height()) * 32
	var focus := Vector2(player.motion.visual_cell) * 32 + Vector2(16, 16)
	var changed := _map_id != int(map.get("_loaded_id"))
	# A restored model keeps its manual scroll. A real map change recenters.
	if changed and _map_id != -999:
		if model.native_follow: model.resume_follow()
		model.scroll_remaining = 0
		model.initialized = false
	model.advance(delta, focus, extent, get_viewport_rect().size, snap or (changed and not model.initialized))
	_map_id = int(map.get("_loaded_id"))
	_revision = model.revision
	var rect: Rect2 = model.view_rect(get_viewport_rect().size)
	position = model.display + get_viewport_rect().size / 2 - rect.position
	# Limits remain available to callers, but manual positioning enforces view-size bounds.
	limit_enabled = false
	limit_left = int(minf(0, (extent.x - rect.size.x) / 2))
	limit_top = int(minf(0, (extent.y - rect.size.y) / 2))
	limit_right = int(maxf(extent.x, rect.size.x + limit_left))
	limit_bottom = int(maxf(extent.y, rect.size.y + limit_top))
	force_update_scroll()

func _process(delta: float) -> void:
	sync(0.0 if model == RuntimeState.map_view and RuntimeState.map_time_paused() else delta)

func scroll(direction: int, tiles: Variant, seconds: Variant) -> Dictionary:
	return model.scroll(direction, tiles, seconds, Vector2(map.map_width(), map.map_height()) * 32, get_viewport_rect().size)

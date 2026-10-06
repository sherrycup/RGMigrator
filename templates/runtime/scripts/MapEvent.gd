class_name MapEvent
extends "res://runtime/scripts/MapCharacter.gd"
var event_id := 0
var map_id := 0
var trigger := 0
var commands: Array = []
var blocking := false
var page_index := 1
var tile_id := 0
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
	motion.configure({"move_speed": clampi(int(page.get("move_speed", 4)), 1, 6), "walk_anime": bool(page.get("walk_anime", true)), "step_anime": bool(page.get("step_anime", false)), "direction_fix": bool(page.get("direction_fix", false)), "through": bool(page.get("through", false)), "opacity": clampi(int(graphic.get("opacity", 255)), 0, 255), "blend_type": clampi(int(graphic.get("blend_type", 0)), 0, 2), "idle_pattern": clampi(int(graphic.get("pattern", 0)), 0, 3)})
	motion.turn(int(graphic.get("direction", 2)), true)
	motion.pattern = motion.options.idle_pattern
	set_graphic(name_value, int(graphic.get("character_hue", 0)), tile_id)


func front_interaction() -> bool:
	return blocking or (tile_id > 0 and map_runtime.tile_priority(tile_id) > 0)

class_name MapRuntime
extends Node2D

const RuntimeData = preload("res://runtime/scripts/RuntimeData.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const MapEvent = preload("res://runtime/scripts/MapEvent.gd")
const RmxpPlayer = preload("res://runtime/scripts/RmxpAnimationPlayer.gd")
const TileRow = preload("res://runtime/scripts/MapTileRow.gd")

signal event_requested(commands: Array, event_id: int)
signal map_changed(map_id: int)

const TILE_SIZE := 32
const AUTOTILE_PARTS := [
	[27, 28, 33, 34], [5, 28, 33, 34], [27, 6, 33, 34], [5, 6, 33, 34],
	[27, 28, 33, 12], [5, 28, 33, 12], [27, 6, 33, 12], [5, 6, 33, 12],
	[27, 28, 11, 34], [5, 28, 11, 34], [27, 6, 11, 34], [5, 6, 11, 34],
	[27, 28, 11, 12], [5, 28, 11, 12], [27, 6, 11, 12], [5, 6, 11, 12],
	[25, 26, 31, 32], [25, 6, 31, 32], [25, 26, 31, 12], [25, 6, 31, 12],
	[15, 16, 21, 22], [15, 16, 21, 12], [15, 16, 11, 22], [15, 16, 11, 12],
	[29, 30, 35, 36], [29, 30, 11, 36], [5, 30, 35, 36], [5, 30, 11, 36],
	[39, 40, 45, 46], [5, 40, 45, 46], [39, 6, 45, 46], [5, 6, 45, 46],
	[25, 30, 31, 36], [15, 16, 45, 46], [13, 14, 19, 20], [13, 14, 19, 12],
	[17, 18, 23, 24], [17, 18, 11, 24], [41, 42, 47, 48], [5, 42, 47, 48],
	[37, 38, 43, 44], [37, 6, 43, 44], [13, 18, 19, 24], [13, 14, 43, 44],
	[37, 42, 43, 48], [17, 18, 47, 48], [13, 18, 43, 48], [13, 18, 43, 48]
]

var map_data: Dictionary = {}
var tileset: Dictionary = {}
var _tileset_texture: Texture2D
var _autotile_textures: Array[Texture2D] = []
var _event_nodes: Array[MapEvent] = []
var _bgm: AudioStreamPlayer
var _bgs: AudioStreamPlayer
var player_character: Node2D
var _animations: Array[Node] = []
var character_layer: Node2D
var _events_at: Dictionary = {}
var _ground_tiles: Array[Vector3i] = []
var _tile_rows: Array[Node2D] = []
var _autotile_seconds := 0.0
var _autotile_frame := 0
var _animated_ground := false
var _loaded_id := 0
var background_visible := true


func load_map(map_id: int) -> bool:
	var definition := RuntimeData.map(map_id)
	if definition.is_empty() or int(definition.get("width", 0)) <= 0 or int(definition.get("height", 0)) <= 0: return false
	map_data = definition
	_loaded_id = map_id
	RuntimeState.map_id = map_id
	_load_tileset()
	_finish_load()
	map_changed.emit(map_id)
	return true


func ensure_character_layer() -> Node2D:
	if character_layer == null:
		character_layer = Node2D.new()
		character_layer.y_sort_enabled = true
		add_child(character_layer)
	return character_layer


func load_definition(definition: Dictionary, tileset_definition: Dictionary) -> void:
	# Detached testing/native map input; never replaces the real database or map ID.
	map_data = definition.duplicate(true)
	tileset = tileset_definition.duplicate(true)
	_loaded_id = -1
	_load_textures()
	_finish_load()


func _finish_load() -> void:
	for animation in _animations:
		if is_instance_valid(animation):
			animation.stop()
	_animations.clear()
	ensure_character_layer()
	_clear_events()
	_build_tile_rows()
	_build_events()
	queue_redraw()


func map_width() -> int:
	return int(map_data.get("width", 0))


func map_height() -> int:
	return int(map_data.get("height", 0))


func valid(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < map_width() and y < map_height()


func tile_id(x: int, y: int, layer: int) -> int:
	return _table_value(map_data.get("data", {}), x, y, layer) if valid(x, y) else 0


func tile_priority(id: int) -> int:
	return _table_value(tileset.get("priorities", {}), id, 0, 0)


func terrain_tag(x: int, y: int) -> int:
	if not valid(x, y): return 0
	for layer in range(int(map_data.get("data", {}).get("z_size", 0)) - 1, -1, -1):
		var tag := _table_value(tileset.get("terrain_tags", {}), tile_id(x, y, layer), 0, 0)
		if tag > 0: return tag
	return 0


func is_bush(x: int, y: int) -> bool:
	return _has_tile_flag(x, y, 0x40)


func is_counter(x: int, y: int) -> bool:
	return _has_tile_flag(x, y, 0x80)


func _has_tile_flag(x: int, y: int, mask: int) -> bool:
	if not valid(x, y): return false
	for layer in int(map_data.get("data", {}).get("z_size", 0)):
		if (_passage(tile_id(x, y, layer)) & mask) != 0: return true
	return false


func event_ids_at(x: int, y: int) -> Array[int]:
	var result: Array[int] = []
	for event in _events_at.get(Vector2i(x, y), []):
		if is_instance_valid(event): result.append(event.event_id)
	result.sort()
	return result


func can_move(from: Vector2i, direction: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool:
	if _direction_bit(direction) == 0 or not valid(from.x, from.y): return false
	var target := from + direction
	if not valid(target.x, target.y): return false
	if through: return true
	if _blocked_by_event(target, ignore_event_id) or _blocked_by_player(target, ignore_event_id): return false
	var direction_bit := _direction_bit(direction)
	var reverse_bit := _direction_bit(-direction)
	return _passable_at(from, direction_bit, ignore_event_id) and _passable_at(target, reverse_bit, ignore_event_id)


func can_stand(cell: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool:
	if not valid(cell.x, cell.y): return false
	if through: return true
	if _blocked_by_event(cell, ignore_event_id) or _blocked_by_player(cell, ignore_event_id): return false
	for bit in [1, 2, 4, 8]:
		if _passable_at(cell, bit, ignore_event_id): return true
	return false


func _passable_at(tile: Vector2i, bit: int, ignore_event_id: int = -1) -> bool:
	if not valid(tile.x, tile.y): return false
	for event in _events_at.get(tile, []):
		if event.event_id != ignore_event_id and not event.through and event.tile_id > 0:
			if (_passage(event.tile_id) & bit) != 0: return false
			if tile_priority(event.tile_id) == 0: return true
	var table: Dictionary = map_data.get("data", {})
	var priorities: Dictionary = tileset.get("priorities", {})
	for layer in range(int(table.get("z_size", 0)) - 1, -1, -1):
		var tile_id := _table_value(table, tile.x, tile.y, layer)
		if tile_id == 0: continue
		if (_passage(tile_id) & bit) != 0:
			return false
		if _table_value(priorities, tile_id, 0, 0) == 0:
			return true
	return true


func request_action(position: Vector2i, facing: Vector2i) -> bool:
	if _emit_at(position, [0], false): return true
	var target := position + facing
	if _emit_at(target, [0], true): return true
	if is_counter(target.x, target.y): return _emit_at(target + facing, [0], true)
	return false


func trigger_player_touch(position: Vector2i, blocked: bool = false) -> bool:
	return _emit_at(position, [1, 2], blocked)


func _emit_at(cell: Vector2i, triggers: Array, in_front: bool) -> bool:
	for event in _events_at.get(cell, []):
		if event.trigger in triggers and event.front_interaction() == in_front and event.is_idle() and not event.commands.is_empty():
			event_requested.emit(event.commands, event.event_id)
			return true
	return false


func autorun_event() -> Dictionary:
	for event_node in _event_nodes:
		if event_node.trigger == 3:
			return {"commands": event_node.commands, "event_id": event_node.event_id}
	return {}


func event_page(event_id: int) -> int:
	for event_node in _event_nodes:
		if event_node.event_id == event_id:
			return event_node.page_index
	return 1


func refresh_events() -> void:
	_build_events()


func animation_target(character_id: int, current_event_id: int = 0) -> CanvasItem:
	if character_id == -1:
		return player_character
	var resolved := current_event_id if character_id == 0 else character_id
	for event in _event_nodes:
		if event.event_id == resolved:
			return event
	return null


func play_animation(animation_id: int, character_id: int = -1, current_event_id: int = 0, hit: bool = true) -> Dictionary:
	var result := RmxpPlayer.play(self, animation_id, animation_target.bind(character_id, current_event_id), hit)
	if result.get("ok", false) and result.has("player"):
		for index in range(_animations.size() - 1, -1, -1):
			if not is_instance_valid(_animations[index]) or _animations[index].is_queued_for_deletion():
				_animations.remove_at(index)
		_animations.append(result.player)
	return result


func transfer(map_id: int, x: int, y: int) -> bool:
	var candidate := RuntimeData.map(map_id)
	if x < 0 or y < 0 or x >= int(candidate.get("width", 0)) or y >= int(candidate.get("height", 0)): return false
	if not load_map(map_id):
		return false
	RuntimeState.player_motion.relocate(Vector2i(x, y))
	if player_character != null: player_character._sync_position()
	return true


func show_picture(parameters: Array) -> void:
	# Legacy internal helper, not connected to an additional event command.
	RuntimeState.show_picture(int(_param(parameters, 0, 0)), str(_param(parameters, 1, "")), {"origin": int(_param(parameters, 2, 0)),
		"x": float(_param(parameters, 4, 0)), "y": float(_param(parameters, 5, 0)), "zoom_x": float(_param(parameters, 6, 100)),
		"zoom_y": float(_param(parameters, 7, 100)), "opacity": float(_param(parameters, 8, 255)), "blend_type": int(_param(parameters, 9, 0))})


func move_picture(parameters: Array) -> void:
	RuntimeState.move_picture(int(_param(parameters, 0, 0)), {"origin": int(_param(parameters, 2, 0)),
		"x": float(_param(parameters, 4, 0)), "y": float(_param(parameters, 5, 0)), "zoom_x": float(_param(parameters, 6, 100)),
		"zoom_y": float(_param(parameters, 7, 100)), "opacity": float(_param(parameters, 8, 255)), "blend_type": int(_param(parameters, 9, 0))}, float(_param(parameters, 1, 0)) / 40.0)


func erase_picture(number: int) -> void:
	RuntimeState.erase_picture(number)


func play_audio(code: int, audio: Variant) -> void:
	if not (audio is Dictionary):
		return
	var kind: String = {241: "BGM", 245: "BGS", 249: "ME", 250: "SE"}.get(code, "")
	var result: Dictionary = RuntimeState.audio.play(kind, audio)
	if not result.ok: RuntimeState.report_diagnostic(result.message)


func stop_sound_effect() -> void:
	RuntimeState.audio.stop("SE")


func _param(parameters: Array, index: int, fallback: Variant) -> Variant:
	return parameters[index] if index >= 0 and index < parameters.size() else fallback


func _load_tileset() -> void:
	tileset = {}
	_tileset_texture = null
	_autotile_textures.clear()
	_autotile_textures.resize(7)
	var all_tilesets: Variant = RuntimeData.database("Tilesets")
	var index := int(map_data.get("tileset_id", 0))
	if all_tilesets is Array and index >= 0 and index < all_tilesets.size() and all_tilesets[index] is Dictionary:
		tileset = all_tilesets[index]
	_load_textures()


func _load_textures() -> void:
	_tileset_texture = null
	_autotile_textures.clear()
	_autotile_textures.resize(7)
	var name := str(tileset.get("tileset_name", ""))
	_tileset_texture = Cache.tileset(name)
	# Canvas draw commands keep texture RIDs, not Texture2D references. Keep the
	# resources alive for the whole map; a local load() in _draw_autotile() can
	# free them before the renderer consumes the commands, producing white tiles.
	var names: Array = tileset.get("autotile_names", [])
	for slot in mini(names.size(), _autotile_textures.size()):
		var autotile_name := str(names[slot])
		if autotile_name.is_empty():
			continue
		_autotile_textures[slot] = Cache.autotile(autotile_name)


func _clear_events() -> void:
	for event_node in _event_nodes:
		if is_instance_valid(event_node):
			if event_node.get_parent() != null: event_node.get_parent().remove_child(event_node)
			event_node.queue_free()
	_event_nodes.clear()
	_events_at.clear()


func _build_events() -> void:
	var events: Variant = map_data.get("events", {})
	if not (events is Dictionary):
		return
	var previous := {}
	for node in _event_nodes:
		previous[node.event_id] = node
	_event_nodes.clear()
	for key in events:
		var event_data: Variant = events[key]
		if not (event_data is Dictionary):
			continue
		var page := _active_page(event_data, int(key))
		if page.is_empty():
			continue
		var event_node: MapEvent = previous.get(int(key))
		if event_node == null:
			event_node = MapEvent.new()
			event_node.map_runtime = self
			ensure_character_layer().add_child(event_node)
			event_node.occupancy_changed.connect(_reindex_events)
		previous.erase(int(key))
		event_node.configure(event_data, page, int(key), _loaded_id)
		event_node.page_index = event_data.get("pages", []).find(page) + 1
		_event_nodes.append(event_node)
	for removed in previous.values():
		removed.get_parent().remove_child(removed)
		removed.queue_free()
	# Equal foot depth uses child order. Keep the leader in front of a same-cell
	# event without a global z_index that would defeat foreground tile sorting.
	if is_instance_valid(player_character) and player_character.get_parent() == character_layer:
		character_layer.move_child(player_character, -1)
	_reindex_events()


func _reindex_events() -> void:
	_events_at.clear()
	for event in _event_nodes:
		for cell in event.occupied_cells():
			if not _events_at.has(cell): _events_at[cell] = []
			_events_at[cell].append(event)


func _active_page(event_data: Dictionary, event_id: int) -> Dictionary:
	var pages: Variant = event_data.get("pages", [])
	if not (pages is Array):
		return {}
	for index in range(pages.size() - 1, -1, -1):
		var page: Variant = pages[index]
		if page is Dictionary and _page_conditions_met(page.get("condition", {}), event_id):
			return page
	return {}


func _page_conditions_met(condition: Variant, event_id: int) -> bool:
	if not (condition is Dictionary):
		return true
	if bool(condition.get("switch1_valid", false)) and not bool(RuntimeState.switches.get(str(condition.get("switch1_id", 0)), false)):
		return false
	if bool(condition.get("switch2_valid", false)) and not bool(RuntimeState.switches.get(str(condition.get("switch2_id", 0)), false)):
		return false
	if bool(condition.get("variable_valid", false)) and int(RuntimeState.variables.get(str(condition.get("variable_id", 0)), 0)) < int(condition.get("variable_value", 0)):
		return false
	if bool(condition.get("self_switch_valid", false)):
		var key := RuntimeState.self_switch_key(RuntimeState.map_id, event_id, str(condition.get("self_switch_ch", "A")))
		if not bool(RuntimeState.self_switches.get(key, false)):
			return false
	if bool(condition.get("item_valid", false)) and int(RuntimeState.inventory.get("item:%s" % condition.get("item_id", 0), 0)) <= 0:
		return false
	return true


func _blocked_by_event(position: Vector2i, ignore_event_id: int = -1) -> bool:
	for event_node in _events_at.get(position, []):
		if event_node.event_id != ignore_event_id and not event_node.through and event_node.blocking:
			return true
	return false


func _blocked_by_player(cell: Vector2i, ignore_event_id: int) -> bool:
	return ignore_event_id != -1 and player_character != null and not player_character.motion.options.through and cell in player_character.occupied_cells()


func _top_tile(x: int, y: int) -> int:
	var table: Variant = map_data.get("data", {})
	if not (table is Dictionary):
		return 0
	for layer in range(max(0, int(table.get("z_size", 0)) - 1), -1, -1):
		var value := _table_value(table, x, y, layer)
		if value > 0:
			return value
	return 0


func _passage(tile_id: int) -> int:
	var table: Variant = tileset.get("passages", {})
	if not (table is Dictionary):
		return 0
	return _table_value(table, tile_id, 0, 0)


func _table_value(table: Dictionary, x: int, y: int, z: int) -> int:
	var x_size := int(table.get("x_size", 0))
	var y_size := int(table.get("y_size", 1))
	var z_size := int(table.get("z_size", 1))
	if x < 0 or y < 0 or z < 0 or x >= x_size or y >= y_size or z >= z_size:
		return 0
	var values: Variant = table.get("values", [])
	var index := x + x_size * (y + y_size * z)
	if values is Array and index >= 0 and index < values.size():
		return int(values[index])
	return 0


func _direction_bit(direction: Vector2i) -> int:
	if direction == Vector2i.DOWN:
		return 0x01
	if direction == Vector2i.LEFT:
		return 0x02
	if direction == Vector2i.RIGHT:
		return 0x04
	if direction == Vector2i.UP:
		return 0x08
	return 0


func _build_tile_rows() -> void:
	for row in _tile_rows:
		row.get_parent().remove_child(row)
		row.queue_free()
	_tile_rows.clear()
	_ground_tiles.clear()
	_animated_ground = false
	_autotile_seconds = 0
	_autotile_frame = 0
	var rows := {}
	for layer in int(map_data.get("data", {}).get("z_size", 0)):
		for y in map_height():
			for x in map_width():
				var id := tile_id(x, y, layer)
				if id <= 0: continue
				var cell := Vector3i(x, y, id)
				var animated := _animated_tile(id)
				var priority := tile_priority(id)
				if priority == 0:
					_ground_tiles.append(cell)
					_animated_ground = _animated_ground or animated
				else:
					var depth := y + priority
					if not rows.has(depth):
						var row := TileRow.new()
						row.map_runtime = self
						row.position.y = depth * 32 - 16
						ensure_character_layer().add_child(row)
						_tile_rows.append(row)
						rows[depth] = row
					rows[depth].cells.append(cell)
					rows[depth].animated = rows[depth].animated or animated


func _animated_tile(id: int) -> bool:
	var slot := int(id / 48) - 1
	if id >= 384 or slot < 0 or slot >= _autotile_textures.size(): return false
	var texture: Texture2D = _autotile_textures[slot]
	return texture != null and texture.get_width() > (32 if texture.get_height() == 32 else 96)


func _process(delta: float) -> void:
	_autotile_seconds += delta
	if _autotile_seconds < 0.25: return
	_autotile_frame += int(_autotile_seconds / 0.25)
	_autotile_seconds = fmod(_autotile_seconds, 0.25)
	if _animated_ground: queue_redraw()
	for row in _tile_rows:
		if row.animated: row.queue_redraw()


func _draw() -> void:
	if background_visible: draw_rect(Rect2(Vector2.ZERO, Vector2(map_width(), map_height()) * TILE_SIZE), Color("202d37"))
	for cell in _ground_tiles:
		draw_tile(self, cell.z, Vector2(cell.x * 32, cell.y * 32))

func set_background_visible(value: bool) -> void:
	if background_visible != value:
		background_visible = value
		queue_redraw()


func draw_tile(canvas: CanvasItem, id: int, destination: Vector2) -> void:
	if id <= 0: return
	if id >= 384 and _tileset_texture != null:
		var index := id - 384
		var source := Rect2((index % 8) * 32, int(index / 8) * 32, 32, 32)
		if source.end.y <= _tileset_texture.get_height():
			canvas.draw_texture_rect_region(_tileset_texture, Rect2(destination, Vector2(32, 32)), source)
	elif id < 384:
		var slot := int(id / 48) - 1
		if slot < 0 or slot >= _autotile_textures.size(): return
		var texture: Texture2D = _autotile_textures[slot]
		if texture == null: return
		if texture.get_height() == 32:
			var frame := _autotile_frame % maxi(1, int(texture.get_width() / 32))
			canvas.draw_texture_rect_region(texture, Rect2(destination, Vector2(32, 32)), Rect2(frame * 32, 0, 32, 32))
			return
		var variant := id % 48
		var frame := _autotile_frame % maxi(1, int(texture.get_width() / 96))
		for quadrant in 4:
			var part := int(AUTOTILE_PARTS[variant][quadrant]) - 1
			var source := Rect2(frame * 96 + (part % 6) * 16, int(part / 6) * 16, 16, 16)
			canvas.draw_texture_rect_region(texture, Rect2(destination + Vector2((quadrant % 2) * 16, int(quadrant / 2) * 16), Vector2(16, 16)), source)

extends Node2D
## Native common display/motion with a separate per-character route cursor.
const Motion = preload("res://runtime/scripts/CharacterMotion.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const Portrait = preload("res://runtime/scripts/CharacterSprite.gd")
signal arrived(kind: String)
signal occupancy_changed
var motion: RefCounted = Motion.new()
var routes: RefCounted = preload("res://runtime/scripts/CharacterRoute.gd").new(self)
var always_on_top := false
var map_runtime: Node
var character_id := -1
var _texture: Texture2D
var _sprite: Sprite2D
var _visual_material: ShaderMaterial
var _material_blend := -1
var _name := ""
var _hue := 0
var _tile_id := 0
var _original_direction := 2
var _original_pattern := 0
var _sort_offset := 0.0
var _last_frame := -1
var _last_options := {}
var _last_pose := Vector4(INF, INF, INF, INF)
var _last_jump := -1.0
var _material_values := Vector3(INF, INF, INF)
var fallback_visible := true
static var _shaders := {}
var tile_position: Vector2i:
	get: return motion.cell
var facing: Vector2i:
	get: return Motion.DIRECTIONS[motion.direction]
	set(value):
		for direction in Motion.DIRECTIONS:
			if Motion.DIRECTIONS[direction] == value: motion.turn(direction, true)
		_sync_position()
var move_speed: int:
	get: return int(motion.options.move_speed)
	set(value): configure_motion({"move_speed": value})
var through: bool:
	get: return bool(motion.options.through)
	set(value): configure_motion({"through": value})
var direction_fix: bool:
	get: return bool(motion.options.direction_fix)
	set(value): configure_motion({"direction_fix": value})
var walk_anime: bool:
	get: return bool(motion.options.walk_anime)
	set(value): configure_motion({"walk_anime": value})
var step_anime: bool:
	get: return bool(motion.options.step_anime)
	set(value): configure_motion({"step_anime": value})
var transparent: bool:
	get: return bool(motion.options.transparent)
	set(value): configure_motion({"transparent": value})
var opacity: int:
	get: return int(motion.options.opacity)
	set(value): configure_motion({"opacity": value})
var blend_type: int:
	get: return int(motion.options.blend_type)
	set(value): configure_motion({"blend_type": value})


func set_graphic(name_value: String, hue: int = 0, tile_id: int = 0) -> void:
	_name = name_value
	_hue = hue
	_tile_id = tile_id
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.use_parent_material = true
		add_child(_sprite)
	_texture = null
	if tile_id >= 384 and map_runtime != null:
		_texture = map_runtime.tile_texture(tile_id)
	elif not name_value.is_empty():
		_texture = Cache.character(name_value)
		if _texture == null:
			var location := "Map%03d 人物 %d" % [RuntimeState.map_id, character_id]
			if character_id > 0 and "map_id" in self: location = "Map%03d 事件 %d" % [get("map_id"), character_id]
			RuntimeState.report_diagnostic("%s：Graphics/Characters/%s 缺失，不补取 RTP。" % [location, name_value])
	_sprite.texture = _texture
	_sprite.hframes = 4 if tile_id == 0 else 1
	_sprite.vframes = 4 if tile_id == 0 else 1
	_last_frame = -1
	_last_options = {}
	_sync_position()


func is_idle() -> bool:
	return motion.is_idle()


func moving() -> bool:
	return motion.moving()


func motion_snapshot() -> Dictionary:
	return motion.snapshot()


func persistent_data() -> Dictionary:
	return {"motion": motion.persistent_data(), "routes": routes.persistent_data(), "name": _name, "hue": _hue, "tile_id": _tile_id,
		"original_direction": _original_direction, "original_pattern": _original_pattern, "always_on_top": always_on_top, "fallback_visible": fallback_visible}


func restore_persistent(value: Dictionary) -> void:
	motion = Motion.decode(value.motion, map_runtime.map_width(), map_runtime.map_height()).value
	if character_id == -1: RuntimeState.player_motion = motion
	routes.restore_persistent(value.routes)
	_original_direction = int(value.original_direction); _original_pattern = int(value.original_pattern)
	always_on_top = value.always_on_top; fallback_visible = value.fallback_visible
	set_graphic(value.name, int(value.hue), int(value.tile_id))
	if character_id > 0:
		set("tile_id", int(value.tile_id))
		set("blocking", not value.name.is_empty() and int(value.tile_id) == 0)
	_sync_position()


func jumping() -> bool:
	return motion.jumping()


func configure_motion(value: Dictionary) -> Dictionary:
	var result: Dictionary = motion.configure(value)
	if result.ok: _sync_position()
	return result


func turn(direction: int) -> bool:
	var changed: bool = motion.turn(direction)
	_sync_position()
	return changed


func move_straight(direction: int, turn_on_failure: bool = true) -> bool:
	if not motion.is_idle() or not Motion.DIRECTIONS.has(direction) or map_runtime == null: return false
	if turn_on_failure: motion.turn(direction)
	_sync_position()
	if not map_runtime.can_move(motion.cell, Motion.DIRECTIONS[direction], bool(motion.options.through), character_id): return false
	var started: bool = motion.begin_move(direction)
	if started: occupancy_changed.emit()
	return started


func move_diagonal(offset: Vector2i) -> bool:
	if not motion.is_idle() or map_runtime == null or absi(offset.x) != 1 or absi(offset.y) != 1: return false
	motion.turn_diagonal(offset)
	_sync_position()
	if not map_runtime.can_move_diagonal(motion.cell, offset, bool(motion.options.through), character_id): return false
	var started: bool = motion.begin_diagonal(offset)
	if started:
		_sync_position()
		occupancy_changed.emit()
	return started


func force_move_route(route: Dictionary, source: String = "", on_error: Callable = Callable()) -> Dictionary:
	return routes.force(route, source, on_error)


func cancel_move_route(stop_autonomous: bool = false) -> void:
	routes.cancel()
	if stop_autonomous: routes.move_type = 0


func reset_route_state() -> void:
	routes.configure(0, 3, {"repeat": false, "skippable": false, "list": [{"code": 0}]})
	_original_direction = 2
	_original_pattern = 0
	set_always_on_top(false)


func route_locked() -> bool:
	return false


func clear_route_lock_direction() -> void:
	pass


func set_always_on_top(value: bool) -> void:
	always_on_top = value
	_sync_position()


func set_route_graphic(name_value: String, hue: int, direction: int, pattern: int) -> void:
	_apply_graphic_pose(direction, pattern)
	set_graphic(name_value, hue)
	occupancy_changed.emit()


func _apply_graphic_pose(direction: int, pattern: int) -> void:
	if _original_direction != direction:
		motion.turn(direction, true)
		_original_direction = direction
		clear_route_lock_direction()
	if _original_pattern != pattern:
		motion.configure({"idle_pattern": pattern})
		motion.pattern = pattern
		_original_pattern = pattern


func move_to(x: int, y: int) -> bool:
	if map_runtime == null or not map_runtime.valid(x, y): return false
	motion.relocate(Vector2i(x, y))
	_sync_position()
	occupancy_changed.emit()
	return true


func jump(x: int, y: int) -> bool:
	if not motion.is_idle() or map_runtime == null: return false
	var destination: Vector2i = motion.cell + Vector2i(x, y)
	if absi(x) > absi(y): motion.turn(6 if x > 0 else 4)
	elif y != 0: motion.turn(2 if y > 0 else 8)
	_sync_position()
	if not map_runtime.valid(destination.x, destination.y): return false
	if (x != 0 or y != 0) and not map_runtime.can_stand(destination, bool(motion.options.through), character_id): return false
	var started: bool = motion.begin_jump(Vector2i(x, y))
	if started: occupancy_changed.emit()
	return started


func occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = [motion.cell]
	if not motion.is_idle() and motion.target != motion.cell: result.append(motion.target)
	return result


func _process(delta: float) -> void:
	advance_motion(delta)


func advance_motion(delta: float) -> String:
	var completed: String = motion.advance(delta)
	var pose := Vector4(motion.visual_cell.x, motion.visual_cell.y, motion.direction, motion.pattern)
	if pose != _last_pose or motion.jump_height != _last_jump or motion.options != _last_options: _sync_position()
	if not completed.is_empty():
		occupancy_changed.emit()
		arrived.emit(completed)
	routes.advance(delta)
	return completed


func _sync_position() -> void:
	z_index = 1024 if always_on_top else 0
	_sort_offset = (map_runtime.tile_priority(_tile_id) - 1) * 32.0 if _tile_id > 0 and map_runtime != null else 0.0
	position = motion.visual_cell * 32 + Vector2(16, 16 + _sort_offset)
	_last_pose = Vector4(motion.visual_cell.x, motion.visual_cell.y, motion.direction, motion.pattern)
	_last_jump = motion.jump_height
	if _sprite == null:
		queue_redraw()
		return
	var options: Dictionary = motion.options
	visible = not options.transparent
	modulate.a = float(options.opacity) / 255.0
	_sprite.visible = _texture != null and not bool(_sprite.get_meta("flash_unravel_hidden",false))
	if _texture == null:
		material = null
		_visual_material = null
		_material_blend = -1
		if _last_frame != motion.direction or _last_options != options:
			_last_frame = motion.direction
			_last_options = options.duplicate()
			queue_redraw()
		return
	var height := _texture.get_height() / (4.0 if _tile_id == 0 else 1.0)
	_sprite.position = Vector2(0, 16 - height / 2 - motion.jump_height - _sort_offset)
	var frame: int = ({2: 0, 4: 1, 6: 2, 8: 3}[motion.direction] * 4 + motion.pattern) if _tile_id == 0 else 0
	if _last_frame != frame:
		_sprite.frame = frame
		_last_frame = frame
	var blend: int = int(options.blend_type)
	if _visual_material == null or _material_blend != blend:
		if not _shaders.has(blend):
			var shader := Shader.new()
			shader.code = Portrait.HUE_SHADER.replace("shader_type canvas_item;", "shader_type canvas_item;\nrender_mode unshaded, %s;\nuniform float bush_depth = 0.0;\nuniform float frame_height = 32.0;\nvarying float local_y;\nvoid vertex() { local_y = VERTEX.y; }" % ["blend_mix", "blend_add", "blend_sub"][blend]).replace("COLOR = vec4(hi * mix(vec3(1.0), wheel, s), c.a);", "COLOR = vec4(hi * mix(vec3(1.0), wheel, s), c.a * (bush_depth > 0.0 && local_y >= frame_height / 2.0 - bush_depth ? 0.5 : 1.0));")
			_shaders[blend] = shader
		_material_blend = blend
		_visual_material = ShaderMaterial.new()
		_visual_material.shader = _shaders[blend]
		material = _visual_material
		_material_values = Vector3(INF, INF, INF)
	var bush: bool = map_runtime != null and map_runtime.is_bush(motion.cell.x, motion.cell.y) and not motion.jumping() and not always_on_top
	var values := Vector3(float(_hue) / 360.0, height, 12.0 if bush and _tile_id == 0 else 0.0)
	if values.x != _material_values.x: _visual_material.set_shader_parameter("hue", values.x)
	if values.y != _material_values.y: _visual_material.set_shader_parameter("frame_height", values.y)
	if values.z != _material_values.z: _visual_material.set_shader_parameter("bush_depth", values.z)
	_material_values = values
	if options != _last_options: _last_options = options.duplicate()


func animation_bounds() -> Rect2:
	var frame := _texture.get_size() / (4.0 if _tile_id == 0 else 1.0) if _texture != null else Vector2(32, 32)
	return Rect2(Vector2(-frame.x / 2, 16 - frame.y - motion.jump_height - _sort_offset), frame)


func _draw() -> void:
	if _texture == null and fallback_visible:
		draw_circle(Vector2(0, -motion.jump_height), 11, Color("ffd166"))
		draw_line(Vector2(0, -motion.jump_height), Vector2(facing) * 13 - Vector2(0, motion.jump_height), Color("1a1a1a"), 3)


func _exit_tree() -> void:
	routes.cancel()

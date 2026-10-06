extends RefCounted
## Grid decisions and time-based visual motion; no event interpreter or renderer.
const DIRECTIONS := {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}
const DEFAULTS := {"move_speed": 4, "walk_anime": true, "step_anime": false, "direction_fix": false, "through": false, "transparent": false, "opacity": 255, "blend_type": 0, "idle_pattern": 0}
var cell := Vector2i.ZERO
var target := Vector2i.ZERO
var visual_cell := Vector2.ZERO
var direction := 2
var pattern := 0
var options := DEFAULTS.duplicate()
var jump_height := 0.0
var _kind := ""
var _start := Vector2.ZERO
var _duration := 0.0
var _elapsed := 0.0
var _animation := 0.0
var _idle_seconds := 0.0


static func validate(value: Variant, complete: bool = false) -> bool:
	if not value is Dictionary or (complete and value.size() != DEFAULTS.size()): return false
	for key in value:
		if not DEFAULTS.has(key): return false
		var field: Variant = value[key]
		if DEFAULTS[key] is bool:
			if not field is bool: return false
		else:
			if not (field is int or field is float) or not is_finite(float(field)) or floor(float(field)) != float(field): return false
			var bounds: Array = {"move_speed": [1, 6], "opacity": [0, 255], "blend_type": [0, 2], "idle_pattern": [0, 3]}[key]
			if field < bounds[0] or field > bounds[1]: return false
	return true


func configure(value: Dictionary) -> Dictionary:
	if not validate(value): return {"ok": false, "message": "人物参数无效：速度 1–6、透明度 0–255、混合 0–2、静止帧 0–3；开关须为布尔值。"}
	for key in value:
		options[key] = value[key] if DEFAULTS[key] is bool else int(value[key])
	return {"ok": true}


func reset() -> void:
	options = DEFAULTS.duplicate()
	direction = 2
	pattern = 0
	_animation = 0
	relocate(Vector2i.ZERO)


func relocate(destination: Vector2i) -> void:
	cell = destination
	target = destination
	visual_cell = Vector2(destination)
	_start = visual_cell
	_kind = ""
	_elapsed = 0
	jump_height = 0
	_idle_seconds = 0
	pattern = int(options.idle_pattern)


func is_idle() -> bool:
	return _kind.is_empty()


func moving() -> bool:
	return _kind == "walk"


func jumping() -> bool:
	return _kind == "jump"


func turn(value: int, force: bool = false) -> bool:
	if not DIRECTIONS.has(value) or (options.direction_fix and not force): return false
	direction = value
	return true


func pixels_per_second() -> float:
	return pow(2.0, int(options.move_speed)) * 10.0


func begin_move(value: int) -> bool:
	if not is_idle() or not DIRECTIONS.has(value): return false
	turn(value)
	_start = visual_cell
	target = cell + DIRECTIONS[value]
	_duration = 32.0 / pixels_per_second()
	_elapsed = 0
	_idle_seconds = 0
	_kind = "walk"
	return true


func begin_jump(offset: Vector2i) -> bool:
	if not is_idle() or offset == Vector2i.ZERO: return false
	if abs(offset.x) > abs(offset.y): turn(6 if offset.x > 0 else 4)
	elif offset.y != 0: turn(2 if offset.y > 0 else 8)
	_start = visual_cell
	target = cell + offset
	_duration = maxf(0.24, Vector2(offset).length() * 32.0 / pixels_per_second())
	_elapsed = 0
	_idle_seconds = 0
	_kind = "jump"
	return true


func advance(delta: float) -> String:
	if not is_finite(delta) or delta <= 0: return ""
	var finished := ""
	var was_walking := moving()
	if not is_idle():
		_elapsed = minf(_duration, _elapsed + delta)
		var t := _elapsed / _duration
		visual_cell = _start.lerp(Vector2(target), t)
		jump_height = 4.0 * (24.0 + minf(64.0, _start.distance_to(Vector2(target)) * 4.0)) * t * (1 - t) if jumping() else 0.0
		if _duration - _elapsed <= 0.000000001:
			cell = target
			visual_cell = Vector2(cell)
			finished = _kind
			_kind = ""
			jump_height = 0
	var cycle: bool = options.step_anime or (was_walking and options.walk_anime)
	if cycle:
		_idle_seconds = 0
		_animation += delta
		var interval := maxf(0.06, (18.0 - int(options.move_speed) * 2.0) / (60.0 if was_walking else 40.0))
		var frames := int(_animation / interval)
		if frames > 0:
			pattern = (pattern + frames) % 4
			_animation = fmod(_animation, interval)
	elif is_idle():
		_idle_seconds += delta
		if _idle_seconds >= 0.12:
			pattern = int(options.idle_pattern)
			_animation = 0
	return finished


func snapshot() -> Dictionary:
	return {"x": cell.x, "y": cell.y, "target_x": target.x, "target_y": target.y, "real_x": visual_cell.x * 32, "real_y": visual_cell.y * 32, "direction": direction, "pattern": pattern, "moving": moving(), "jumping": jumping(), "jump_height": jump_height, "options": options.duplicate()}

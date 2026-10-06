extends Node2D
## Batched native drawing; no per-drop nodes or textures; bounded allocation.
var area := Vector2(640, 480)
var type := 0
var power := 0.0
var density := 0.0
var display := Vector2.ZERO
var _last_display := Vector2.ZERO
var _particles := PackedVector2Array()
var _phase := 0.0
var _rng := RandomNumberGenerator.new()

func advance(delta: float) -> void:
	var count := 0 if type == 0 or density <= 0 else clampi(int(ceil(density * area.x * area.y / (640 * 480))), 1, 256)
	while _particles.size() < count: _particles.append(Vector2(_rng.randf_range(0, area.x), _rng.randf_range(0, area.y)))
	if _particles.size() > count: _particles.resize(count)
	if count == 0:
		if visible: hide(); queue_redraw()
		_last_display = display
		return
	show()
	_phase = fposmod(_phase + delta, TAU)
	var velocity: Vector2 = {1: Vector2(-120, 480), 2: Vector2(-220, 650), 3: Vector2(-30 + sin(_phase) * 18, 65)}.get(type, Vector2.ZERO)
	for index in _particles.size():
		var pos: Vector2 = _particles[index] + velocity * delta - (display - _last_display)
		pos.x = wrapf(pos.x, -24, area.x + 24)
		pos.y = wrapf(pos.y, -24, area.y + 24)
		_particles[index] = pos
	_last_display = display
	queue_redraw()

func particle_count() -> int: return _particles.size()

func _draw() -> void:
	if type == 0 or density <= 0: return
	if type == 2: draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, power / 9 * 0.22))
	for pos in _particles:
		if type == 3: draw_circle(pos, 2, Color(1, 1, 1, 0.85))
		else: draw_line(pos, pos + (Vector2(7, -20) if type == 2 else Vector2(4, -12)), Color(0.7, 0.85, 1, 0.7), 2 if type == 2 else 1)

class_name PlayerController
extends "res://runtime/scripts/MapCharacter.gd"
var input_enabled := true
var stop_after_step := false
var _move_cooldown := 0.0
var _wait_action_release := false
var _graphic_signature := ""


func configure(runtime: Node) -> void:
	map_runtime = runtime
	motion = RuntimeState.player_motion
	character_id = -1
	RuntimeState.register_player(self)
	if not RuntimeState.state_changed.is_connected(_refresh_graphic): RuntimeState.state_changed.connect(_refresh_graphic)
	_refresh_graphic()
	_sync_position()


func _refresh_graphic() -> void:
	var actor: RefCounted = RuntimeState.actor(int(RuntimeState.party[0])) if not RuntimeState.party.is_empty() else null
	var name_value: String = "" if actor == null else actor.character_name
	var hue: int = 0 if actor == null else actor.character_hue
	var signature := "%s:%d" % [name_value, hue]
	if signature == _graphic_signature: return
	_graphic_signature = signature
	set_graphic(name_value, hue)


func configure_motion(value: Dictionary) -> Dictionary:
	return RuntimeState.configure_player(value)


func _process(delta: float) -> void:
	var completed := advance_motion(delta)
	if completed == "walk":
		RuntimeState.record_step()
		map_runtime.trigger_player_touch(motion.cell)
	elif completed == "jump":
		map_runtime.trigger_player_touch(motion.cell)
	_move_cooldown = maxf(0, _move_cooldown - delta)
	var action_pressed := Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	if not action_pressed: _wait_action_release = false
	if not input_enabled or stop_after_step or map_runtime == null or not motion.is_idle(): return
	if action_pressed and not _wait_action_release:
		_wait_action_release = true
		map_runtime.request_action(motion.cell, facing)
		return
	if _move_cooldown > 0: return
	var direction := _input_direction()
	if direction != Vector2i.ZERO:
		var id: int = {Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 6, Vector2i.UP: 8}[direction]
		if not move_straight(id):
			map_runtime.trigger_player_touch(motion.cell + direction, true)
			_move_cooldown = 0.12


func resume_after_menu() -> void:
	stop_after_step = false
	_wait_action_release = true
	_move_cooldown = maxf(_move_cooldown, 0.12)


func _input_direction() -> Vector2i:
	if Input.is_action_pressed("ui_up"): return Vector2i.UP
	if Input.is_action_pressed("ui_down"): return Vector2i.DOWN
	if Input.is_action_pressed("ui_left"): return Vector2i.LEFT
	if Input.is_action_pressed("ui_right"): return Vector2i.RIGHT
	return Vector2i.ZERO

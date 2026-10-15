class_name PlayerController
extends "res://runtime/scripts/MapCharacter.gd"
var input_enabled := true
var stop_after_step := false
var _move_cooldown := 0.0
var _wait_action_release := false
var _graphic_signature := ""
var _count_walk := false


func _ready() -> void:
	arrived.connect(_on_arrived)


func configure(runtime: Node) -> void:
	map_runtime = runtime
	motion = RuntimeState.player_motion
	character_id = -1
	RuntimeState.register_player(self)
	if not RuntimeState.state_changed.is_connected(_refresh_graphic): RuntimeState.state_changed.connect(_refresh_graphic)
	_refresh_graphic()
	_sync_position()
	if RuntimeState.flash_followers!=null: RuntimeState.flash_followers.bind(self,runtime)


func _refresh_graphic() -> void:
	var actor: RefCounted = RuntimeState.actor(int(RuntimeState.party[0])) if not RuntimeState.party.is_empty() else null
	if actor!=null and actor.has_method("equip_project"):
		var ids: Array=RuntimeState.custom_data.gameplay().role_actor_ids()
		actor=RuntimeState.actor(int(ids[0])) if ids[0]>0 else null
	var name_value: String = "" if actor == null else actor.character_name
	var hue: int = 0 if actor == null else actor.character_hue
	var signature := "%s:%d" % [name_value, hue]
	if signature == _graphic_signature:
		_sync_position()
		return
	_graphic_signature = signature
	set_graphic(name_value, hue)


func configure_motion(value: Dictionary) -> Dictionary:
	return RuntimeState.configure_player(value)


func _process(delta: float) -> void:
	if RuntimeState.map_time_paused(): return
	if RuntimeState.flash_followers!=null: RuntimeState.flash_followers.advance(delta)
	var was_forcing: bool = routes.forcing
	advance_motion(delta)
	_move_cooldown = maxf(0, _move_cooldown - delta)
	var action_pressed := Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	if not action_pressed: _wait_action_release = false
	if not input_enabled or stop_after_step or was_forcing or routes.forcing or map_runtime == null or not motion.is_idle(): return
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


func move_straight(direction: int, turn_on_failure: bool = true) -> bool:
	var started := super.move_straight(direction, turn_on_failure)
	if started:
		_count_walk = not routes.forcing
		if RuntimeState.flash_followers!=null: RuntimeState.flash_followers.accept_action(direction,[turn_on_failure])
	return started


func move_diagonal(offset: Vector2i) -> bool:
	var started := super.move_diagonal(offset)
	if started:
		_count_walk = not routes.forcing
		if RuntimeState.flash_followers!=null: RuntimeState.flash_followers.accept_action({Vector2i(-1,1):1,Vector2i(1,1):3,Vector2i(-1,-1):7,Vector2i(1,-1):9}[offset])
	return started

func jump(x: int,y: int) -> bool:
	var started=super.jump(x,y)
	if started and RuntimeState.flash_followers!=null: RuntimeState.flash_followers.accept_action(5,[x,y])
	return started

func move_to(x: int,y: int) -> bool:
	var moved=super.move_to(x,y)
	if moved and RuntimeState.flash_followers!=null: RuntimeState.flash_followers.moveto_party_actors(x,y)
	return moved


func _on_arrived(kind: String) -> void:
	if kind == "walk" and _count_walk:
		RuntimeState.record_step()
		if RuntimeState.custom_data.manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json"):
			var result: Dictionary=preload("FlashActions.gd").after_step(RuntimeState)
			if not result.ok: RuntimeState.report_diagnostic("地图步行效果未提交："+str(result.get("message","")))
	_count_walk = false
	if map_runtime != null: map_runtime.trigger_player_touch(motion.cell)


func reset_route_state() -> void:
	super.reset_route_state()
	_count_walk = false
	_graphic_signature = ""


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

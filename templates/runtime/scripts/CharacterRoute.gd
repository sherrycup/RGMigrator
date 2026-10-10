extends RefCounted
## Per-character route cursor. Definitions are read-only; no Ruby evaluation.
const Catalog = preload("res://runtime/scripts/EventCommandCatalog.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
var move_type := 0
var move_frequency := 3
var forcing := false
var _character: WeakRef
var _route: Dictionary = {"repeat": false, "skippable": false, "list": [{"code": 0}]}
var _index := 0
var _original: Dictionary = {}
var _original_index := 0
var _source := ""
var _original_source := ""
var _on_error: Callable
var _wait := 0.0
var _stop := 0.0
var _faulted := false
var _changed := false

func _init(character: Node) -> void:
	_character = weakref(character)

static func preflight(route: Variant) -> Dictionary:
	var result := Catalog.route_validation(route)
	if not result.ok: return result
	for index in route.list.size():
		var command: Dictionary = route.list[index]
		var p: Array = command.get("parameters", [])
		var message := ""
		if int(command.code) == 41 and not str(p[0]).is_empty() and Cache.character(str(p[0])) == null:
			message = "Characters/%s 缺失，不补取RTP" % str(p[0])
		elif int(command.code) == 44 and not str(p[0].get("name", "")).is_empty():
			var path := Data.asset_path("Audio/SE/" + str(p[0].name))
			if path.is_empty() or not ResourceLoader.exists(path) or not load(path) is AudioStream: message = "SE/%s 缺失或无法解码，不补取RTP" % str(p[0].name)
		if not message.is_empty(): return {"ok": false, "message": message, "route_index": index + 1}
	return {"ok": true}

func configure(type: Variant, frequency: Variant, route: Variant, source: String = "") -> Dictionary:
	cancel()
	_source = source
	_index = 0
	_changed = false
	if not preload("res://runtime/scripts/ActorParameters.gd").integer(type, 0, 3) or not preload("res://runtime/scripts/ActorParameters.gd").integer(frequency, 1, 6):
		_faulted = true
		move_type = 0
		RuntimeState.report_diagnostic(source + " / 自主移动类型须为0..3，频度须为1..6的整数。")
		return {"ok": false, "message": "自主移动类型或频度无效"}
	move_type = int(type)
	move_frequency = int(frequency)
	_route = route if route is Dictionary else {"repeat": false, "skippable": false, "list": [{"code": 0}]}
	if type != 3: return {"ok": true}
	var result := preflight(route)
	if not result.ok:
		_faulted = true
		RuntimeState.report_diagnostic("%s / 自主路线第%d条：%s" % [source, result.get("route_index", 0), result.message])
	return result

func force(route: Dictionary, source: String = "", on_error: Callable = Callable()) -> Dictionary:
	var character: Node = _character.get_ref()
	if character == null or not character.is_inside_tree() or character.map_runtime == null: return {"ok": false, "message": "路线目标人物未在有效地图中"}
	var result := preflight(route)
	if not result.ok: return result
	if not forcing:
		_original = _route
		_original_index = _index
		_original_source = _source
	_route = route
	_index = 0
	_source = source
	_on_error = on_error
	forcing = true
	_wait = 0
	_faulted = false
	if character != null:
		character.clear_route_lock_direction()
		if character.character_id > 0: _changed = true
	_execute()
	return {"ok": true}

func cancel() -> void:
	if forcing and not _original.is_empty():
		_route = _original
		_index = _original_index
		_source = _original_source
	forcing = false
	_original = {}
	_on_error = Callable()
	_wait = 0
	_stop = 0
	_faulted = false

func repeat_forced() -> bool:
	return forcing and bool(_route.repeat)

func has_runtime_state() -> bool:
	return forcing or move_type != 0 or _changed

func snapshot() -> Dictionary:
	return {"move_type": move_type, "move_frequency": move_frequency, "forcing": forcing, "index": _index, "original_index": _original_index, "waiting": _wait, "stopped": _stop, "faulted": _faulted}

func persistent_data() -> Dictionary:
	var value := snapshot()
	value.merge({"route": _route.duplicate(true), "original": _original.duplicate(true), "source": _source, "original_source": _original_source, "changed": _changed})
	return value

static func validate_persistent(value: Variant) -> bool:
	var numbers := preload("res://runtime/scripts/ActorParameters.gd")
	if not value is Dictionary or not numbers.integer(value.get("move_type"), 0, 3) or not numbers.integer(value.get("move_frequency"), 1, 6): return false
	for key in ["forcing", "faulted", "changed"]:
		if not value.get(key) is bool: return false
	for key in ["source", "original_source"]:
		if not value.get(key) is String or value[key].length() > 8192: return false
	for key in ["waiting", "stopped"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])) or value[key] < 0 or value[key] > 1000000000: return false
	if not value.get("original") is Dictionary or not value.get("route") is Dictionary: return false
	# Unsupported source autonomous routes remain faulted and diagnosable; forced
	# routes and runnable custom routes have already passed native preflight.
	if (value.forcing or (value.move_type == 3 and not value.faulted)) and not preflight(value.route).ok: return false
	if not value.route.get("list") is Array or not numbers.integer(value.get("index"), 0, value.route.list.size()): return false
	if value.forcing:
		if not value.original.get("list") is Array or not numbers.integer(value.get("original_index"), 0, value.original.list.size()): return false
	elif not value.original.is_empty() or not numbers.integer(value.get("original_index"), 0): return false
	return true

func restore_persistent(value: Dictionary) -> void:
	move_type = int(value.move_type); move_frequency = int(value.move_frequency); forcing = value.forcing
	_route = value.route.duplicate(true); _original = value.original.duplicate(true)
	_index = int(value.index); _original_index = int(value.original_index)
	_source = value.source; _original_source = value.original_source
	_wait = float(value.waiting); _stop = float(value.stopped); _faulted = value.faulted; _changed = value.changed
	_on_error = Callable()

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or _faulted: return
	var character: Node = _character.get_ref()
	if character == null or not character.is_inside_tree() or character.is_queued_for_deletion() or character.map_runtime == null: return
	if _wait > 0:
		_wait = maxf(0, _wait - delta)
		if _wait > 0.0000001: return
	if not character.is_idle():
		_stop = 0
		return
	if forcing:
		_execute()
		return
	if character.route_locked(): return
	_stop += delta
	if _stop + 0.0000001 < (40.0 - move_frequency * 2) * (6 - move_frequency) / 40.0: return
	match move_type:
		1:
			var pick := randi_range(0, 5)
			if pick < 4: _move(9)
			elif pick == 4: _move(12)
			else: _stop = 0
		2:
			var player: Node = character.map_runtime.player_character
			if player == null: return
			var distance: Vector2i = character.tile_position - player.tile_position
			if distance.x + distance.y >= 20: _move(9)
			else:
				var pick := randi_range(0, 5)
				_move(10 if pick < 4 else (9 if pick == 4 else 12))
		3: _execute()

func _execute() -> void:
	var character: Node = _character.get_ref()
	if character == null or not character.is_inside_tree() or character.is_queued_for_deletion() or character.map_runtime == null or not character.is_idle() or _faulted: return
	# Long runs of switches/properties yield; repeat/end also yields one update.
	for budget in 64:
		if _index >= _route.get("list", []).size(): return
		var command: Dictionary = _route.list[_index]
		var code := int(command.code)
		var p: Array = command.get("parameters", [])
		if code == 0:
			if _route.repeat: _index = 0
			else:
				if forcing: cancel()
				_stop = 0
			return
		if code <= 14:
			if code == 14 and (int(p[0]) != 0 or int(p[1]) != 0) and not character.motion.options.direction_fix: _stop = 0
			var moved: bool = character.jump(int(p[0]), int(p[1])) if code == 14 else _move(code)
			if moved or _route.skippable: _index += 1
			if moved: _stop = 0
			return
		if code == 15:
			_wait = float(p[0]) / 20.0
			_index += 1
			return
		if code <= 26:
			if _turn(code): _stop = 0
			_index += 1
			return
		var result: Dictionary = {"ok": true}
		match code:
			27, 28: RuntimeState.set_event_switch(int(p[0]), code == 27)
			29: result = character.configure_motion({"move_speed": int(p[0])})
			30: move_frequency = int(p[0]); _changed = true
			31, 32: result = character.configure_motion({"walk_anime": code == 31})
			33, 34: result = character.configure_motion({"step_anime": code == 33})
			35, 36: result = character.configure_motion({"direction_fix": code == 35})
			37, 38: result = character.configure_motion({"through": code == 37})
			39, 40: character.set_always_on_top(code == 39); _changed = true
			41:
				character.set_route_graphic(str(p[0]), int(p[1]), int(p[2]), int(p[3]))
				_changed = true
			42: result = character.configure_motion({"opacity": int(p[0])})
			43: result = character.configure_motion({"blend_type": int(p[0])})
			44: result = RuntimeState.audio.play("SE", p[0])
		if not result.ok:
			_fail("移动路线第%d条（%d）：%s" % [_index + 1, code, result.message])
			return
		_index += 1

func _fail(message: String) -> void:
	var handled := false
	if _on_error.is_valid(): handled = bool(_on_error.call(message))
	if not handled: RuntimeState.report_diagnostic(_source + " / " + message)
	cancel()
	_faulted = true

func _move(code: int) -> bool:
	var character: Node = _character.get_ref()
	if code <= 4:
		if not character.motion.options.direction_fix: _stop = 0
		return character.move_straight([2, 4, 6, 8][code - 1])
	if code <= 8: return character.move_diagonal([Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)][code - 5])
	if code == 9: return character.move_straight([2, 4, 6, 8][randi_range(0, 3)], false)
	if code in [10, 11]:
		var delta := _player_difference()
		if delta == Vector2i.ZERO: return false
		if code == 11: delta = -delta
		if not character.motion.options.direction_fix: _stop = 0
		var horizontal := absi(delta.x) > absi(delta.y) or (absi(delta.x) == absi(delta.y) and randi_range(0, 1) == 0)
		var first := (6 if delta.x > 0 else 4) if horizontal else (2 if delta.y > 0 else 8)
		if character.move_straight(first): return true
		if horizontal and delta.y != 0: return character.move_straight(2 if delta.y > 0 else 8)
		if not horizontal and delta.x != 0: return character.move_straight(6 if delta.x > 0 else 4)
		return false
	if code == 12: return character.move_straight(character.motion.direction, false)
	var fixed: bool = character.motion.options.direction_fix
	character.motion.options.direction_fix = true
	var moved: bool = character.move_straight(10 - character.motion.direction, false)
	character.motion.options.direction_fix = fixed
	return moved

func _player_difference() -> Vector2i:
	var character: Node = _character.get_ref()
	var player: Node = character.map_runtime.player_character
	return Vector2i.ZERO if player == null else player.tile_position - character.tile_position

func _turn(code: int) -> bool:
	var character: Node = _character.get_ref()
	var direction: int = character.motion.direction
	var value := direction
	match code:
		16, 17, 18, 19: value = [2, 4, 6, 8][code - 16]
		20: value = {2: 4, 4: 8, 8: 6, 6: 2}[direction]
		21: value = {2: 6, 6: 8, 8: 4, 4: 2}[direction]
		22: value = 10 - direction
		23: value = ({2: 4, 4: 8, 8: 6, 6: 2} if randi_range(0, 1) == 0 else {2: 6, 6: 8, 8: 4, 4: 2})[direction]
		24: value = [2, 4, 6, 8][randi_range(0, 3)]
		25, 26:
			var delta := _player_difference()
			if delta == Vector2i.ZERO: return false
			value = (6 if delta.x > 0 else 4) if absi(delta.x) > absi(delta.y) else (2 if delta.y > 0 else 8)
			if code == 26: value = 10 - value
	return character.turn(value)

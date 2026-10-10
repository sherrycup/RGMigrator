extends RefCounted
## One foreground interpreter, independent map/common parallel interpreters.
const Interpreter = preload("res://runtime/scripts/EventInterpreter.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")
signal interpreter_created(interpreter: RefCounted)
signal main_completed
var map_runtime: Node
var main: RefCounted
var parallels: Dictionary = {}
var common_events: Array = []
var frame_budget := 2048
var _faults: Dictionary = {}
var _main_key := ""
var _locked: WeakRef
var _offset := 0
var _generation := -1

func configure(map: Node, common_override: Variant = null) -> void:
	map_runtime = map
	var source: Variant = common_override if common_override != null else Data.database("CommonEvents")
	if not source is Array: source = Data.database("CommonEvent")
	common_events = source if source is Array else []
	main = Interpreter.new()
	main.map_runtime = map
	main.common_events = common_events
	main.completed.connect(_main_finished)
	main.diagnostic_requested.connect(_main_failed)
	_generation = map.generation
	map.map_changed.connect(_map_changed)
	map.events_changed.connect(_events_changed)

func start_main(commands: Array, event_id: int, page: int = 1, key: String = "", defer_run: bool = false) -> bool:
	if main.running or commands.is_empty(): return false
	_main_key = key
	var node: Node = map_runtime.event_node(event_id)
	if node != null and node.trigger < 3:
		node.lock()
		_locked = weakref(node)
	main.managed = defer_run
	main.start(commands, event_id, page)
	return true

func advance(delta: float, allow_autorun: bool = true) -> void:
	if RuntimeState.map_time_paused(): return
	if _generation != map_runtime.generation: _map_changed(0)
	map_runtime.flush_event_refresh()
	_reconcile()
	if allow_autorun and not main.running:
		if not RuntimeState.common_event_reservation.is_empty():
			var reservation: Dictionary = RuntimeState.common_event_reservation
			var definition: Dictionary = Data.record("CommonEvents", int(reservation.id))
			if definition.is_empty(): RuntimeState.report_diagnostic("预约公共事件%d不存在。" % int(reservation.id))
			elif not definition.get("list", []).is_empty():
				start_main(definition.list, 0, 1, "reserved:%d" % int(reservation.id), true)
				main.context.common_id = int(reservation.id)
			RuntimeState.common_event_reservation.clear()
		for event in map_runtime.event_contexts():
			if main.running: break
			var key := "event:%d:%d" % [event.event_id, event.page]
			if event.trigger == 3 and event.commands.size() > 1 and not _faults.has(key):
				start_main(event.commands, event.event_id, event.page, key, true)
				break
		if not main.running:
			for event in common_events:
				if not event is Dictionary or int(event.get("trigger", 0)) != 1 or not _common_enabled(event): continue
				var key := "common:%d" % int(event.get("id", 0))
				if _faults.has(key) or event.get("list", []).size() <= 1: continue
				start_main(event.list, 0, 1, key, true)
				main.context.common_id = int(event.id)
				break
	var budget := maxi(1, frame_budget)
	budget -= main.advance(delta, mini(256, budget))
	if RuntimeState.map_time_paused(): return
	var keys := parallels.keys()
	if keys.is_empty(): return
	var quota := maxi(1, int(budget / keys.size()))
	for index in keys.size():
		var key: String = keys[(index + _offset) % keys.size()]
		if not parallels.has(key): continue
		var entry: Dictionary = parallels[key]
		var owner: RefCounted = entry.owner
		if not owner.running and not _faults.has(key):
			owner.start(entry.commands, entry.event_id, entry.page)
			owner.context.common_id = entry.common_id
		budget -= owner.advance(delta, mini(quota, maxi(0, budget)))
		if RuntimeState.map_time_paused(): return
	_offset = (_offset + 1) % keys.size()
	map_runtime.flush_event_refresh()
	_reconcile()

func has_running_events() -> bool:
	return main.running or not parallels.is_empty()

func suppress_loaded_autoruns() -> void:
	for event in map_runtime.event_contexts():
		if event.trigger == 3: _faults["event:%d:%d" % [event.event_id, event.page]] = true

func cancel_all() -> void:
	if main != null:
		main.cancel()
		main.managed = false
	_unlock()
	for entry in parallels.values(): entry.owner.cancel()
	parallels.clear()
	_faults.clear()
	_main_key = ""

func dispose() -> void:
	cancel_all()
	if is_instance_valid(map_runtime):
		if map_runtime.map_changed.is_connected(_map_changed): map_runtime.map_changed.disconnect(_map_changed)
		if map_runtime.events_changed.is_connected(_events_changed): map_runtime.events_changed.disconnect(_events_changed)
	if main == null: return
	for descriptor in main.get_signal_list():
		for connection in main.get_signal_connection_list(descriptor.name):
			main.disconnect(descriptor.name, connection.callable)
	main = null

func _events_changed() -> void:
	if _generation != map_runtime.generation: _map_changed(0)
	_reconcile()

func _main_failed(_message: String) -> void:
	if not _main_key.is_empty(): _faults[_main_key] = true

func _common_enabled(event: Dictionary) -> bool:
	return bool(RuntimeState.switches.get(str(int(event.get("switch_id", 0))), false))

func _reconcile() -> void:
	var wanted := {}
	var active_keys := {}
	for event in map_runtime.event_contexts():
		var key := "event:%d:%d" % [event.event_id, event.page]
		if event.trigger in [3, 4]: active_keys[key] = true
		if event.trigger == 4 and event.commands.size() > 1:
			wanted[key] = {"commands": event.commands, "event_id": event.event_id, "page": event.page, "common_id": 0}
	for event in common_events:
		if not event is Dictionary or not _common_enabled(event): continue
		var key := "common:%d" % int(event.get("id", 0))
		if int(event.get("trigger", 0)) in [1, 2]: active_keys[key] = true
		if int(event.get("trigger", 0)) == 2 and event.get("list", []).size() > 1:
			wanted[key] = {"commands": event.list, "event_id": 0, "page": 1, "common_id": int(event.id)}
	for key in _faults.keys():
		if not active_keys.has(key): _faults.erase(key)
	for key in parallels.keys():
		if not wanted.has(key):
			parallels[key].owner.cancel()
			parallels.erase(key)
	for key in wanted:
		if parallels.has(key): continue
		var owner := Interpreter.new()
		owner.managed = true
		owner.map_runtime = map_runtime
		owner.common_events = common_events
		owner.diagnostic_requested.connect(_parallel_failed.bind(key))
		var entry: Dictionary = wanted[key]
		entry.owner = owner
		parallels[key] = entry
		interpreter_created.emit(owner)

func _parallel_failed(_message: String, key: String) -> void:
	_faults[key] = true

func _map_changed(_id: int) -> void:
	_unlock()
	for entry in parallels.values(): entry.owner.cancel()
	parallels.clear()
	_faults.clear()
	_generation = map_runtime.generation
	# Foreground list continues after transfer, but has no current map event.
	if main != null and main.running: main.context.event_id = 0

func _main_finished() -> void:
	_unlock()
	main.managed = false
	_main_key = ""
	main_completed.emit()

func _unlock() -> void:
	if _locked == null: return
	var node: Node = _locked.get_ref()
	if is_instance_valid(node) and not node.is_queued_for_deletion(): node.unlock()
	_locked = null

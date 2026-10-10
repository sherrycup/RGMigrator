extends RefCounted
## Detached JSON snapshots of map characters, execution stacks and UI ownership.
const Motion = preload("res://runtime/scripts/CharacterMotion.gd")
const Route = preload("res://runtime/scripts/CharacterRoute.gd")
const Numbers = preload("res://runtime/scripts/ActorParameters.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const CONTEXT_FIELDS := ["commands", "index", "event_id", "source_event_id", "source_map_id", "page", "common_id", "stack", "branches", "loops", "waiting_indent", "shop_command_index"]
const LOCAL_FIELDS := ["_choice_count", "_choice_cancel", "_number_digits", "_name_actor_id", "_name_maximum", "_route_wait_warned"]
const WAITS := ["", "time", "routes", "scroll_ready", "message", "choice", "shop", "name", "menu", "save"]

static func capture(game: Node) -> Dictionary:
	var map: Node = game.event_map()
	map.flush_event_refresh()
	var events := {}
	for key in map.map_data.get("events", {}):
		var node: Node = map.event_node(int(key))
		var character: Variant = node.persistent_data() if node != null else map._dormant_events.get(int(key))
		var definition: Dictionary = map.map_data.events[key]
		events[str(key)] = {"page": node.page_index if node != null else 0,
			"position": character.motion.cell if character != null else [int(definition.get("x", 0)), int(definition.get("y", 0))], "character": character,
			"locked": node.locked if node != null else false, "prelock_direction": node._prelock_direction if node != null else 2}
	var erased: Array = []
	for id in map._erased_events: erased.append(int(id))
	var scheduler: RefCounted = game._scheduler
	scheduler._reconcile()
	var owners := {"main": scheduler.main}
	for key in scheduler.parallels: owners[key] = scheduler.parallels[key].owner
	var ui: RefCounted = game._event_ui
	var consumed: RefCounted = null
	if not ui.active.is_empty() and ui._valid(ui.active) and ui.active.kind in ["menu", "save"]:
		consumed = ui.active.owner.get_ref()
	var executions := {}
	for key in owners: executions[key] = _interpreter(owners[key], owners[key] == consumed)
	var requests: Array = []
	var source: Array = ([] if ui.active.is_empty() else [ui.active]) + ui._pending
	for request in source:
		if not ui._valid(request): continue
		if request.kind == "diagnostic":
			requests.append({"kind": "diagnostic", "payload": request.payload, "owner": ""})
			continue
		var owner: RefCounted = request.owner.get_ref()
		if owner == consumed and request == ui.active: continue
		for key in owners:
			if owners[key] == owner: requests.append({"kind": request.kind, "payload": request.payload.duplicate(true), "owner": key})
	var locked: Node = scheduler._locked.get_ref() if scheduler._locked != null else null
	return _canonical({"map_id": RuntimeState.map_id, "events": events, "erased": erased, "player": game._player.persistent_data(),
		"executions": executions, "requests": requests, "main_key": scheduler._main_key, "locked_id": locked.event_id if is_instance_valid(locked) else 0,
		"faults": scheduler._faults.duplicate(), "offset": scheduler._offset})

static func _canonical(value: Variant) -> Variant:
	if value is float and is_finite(value) and floor(value) == value and absf(value) <= 9007199254740991.0: return int(value)
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_canonical(entry))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _canonical(value[key])
		return result
	return value

static func _interpreter(owner: RefCounted, consume_ui: bool) -> Variant:
	if not owner.running: return null
	var context := {}
	for field in CONTEXT_FIELDS:
		var value: Variant = owner.context.get(field)
		context[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	var locals := {}
	for field in LOCAL_FIELDS: locals[field] = owner.get(field)
	return {"context": context, "locals": locals, "wait": {"kind": "" if consume_ui else owner.wait_kind(), "remaining": 0.0 if consume_ui else owner.wait_state.remaining}}

static func decode(value: Variant, map: Dictionary, lookup: Callable = Callable()) -> Dictionary:
	if value is Dictionary and value.is_empty(): return {"ok": true, "value": {}}
	if not value is Dictionary or not Numbers.integer(value.get("map_id"), 1) or int(value.map_id) != int(map.get("id", value.map_id)): return _fail("事件现场所属地图无效。")
	if not value.get("events") is Dictionary or value.events.size() != map.get("events", {}).size() or not value.get("erased") is Array: return _fail("地图事件记录不完整。")
	var erased := {}
	for id in value.erased:
		if not Numbers.integer(id, 1) or not value.events.has(str(int(id))) or erased.has(int(id)): return _fail("暂时删除事件记录无效。")
		erased[int(id)] = true
	for key in value.events:
		if not key is String or not map.get("events", {}).has(key): return _fail("事件ID不存在。")
		var entry: Variant = value.events[key]
		if not entry is Dictionary or not Numbers.integer(entry.get("page"), 0, map.events[key].get("pages", []).size()) or not entry.get("locked") is bool or not Numbers.integer(entry.get("prelock_direction"), 0, 8) or int(entry.prelock_direction) not in [0, 2, 4, 6, 8]: return _fail("事件页或朝向锁无效。")
		if not entry.get("position") is Array or entry.position.size() != 2 or not Numbers.integer(entry.position[0], 0, int(map.width) - 1) or not Numbers.integer(entry.position[1], 0, int(map.height) - 1): return _fail("事件位置无效。")
		if entry.page > 0 and erased.has(int(key)): return _fail("已删除事件仍处于活动页。")
		if entry.get("character") == null:
			if entry.page != 0 or entry.locked: return _fail("活动事件缺少人物属性。")
		else:
			var result := _character(entry.character, map)
			if not result.ok: return result
			if entry.position != entry.character.motion.cell: return _fail("事件位置与运动记录冲突。")
	var player := _character(value.get("player"), map)
	if not player.ok: return player
	if not value.get("executions") is Dictionary or not value.executions.has("main") or value.executions.size() > 10000: return _fail("事件执行实例无效。")
	for key in value.executions:
		if not key is String or (key != "main" and not _instance_key(key, value.events)): return _fail("并行事件身份无效。")
		if key.begins_with("common:") and _common_missing(int(key.get_slice(":", 1)), lookup): return _fail("并行公共事件不存在。")
		if key.begins_with("event:"):
			var entry: Dictionary = value.events[key.get_slice(":", 1)]
			if entry.page <= 0 or int(map.events[key.get_slice(":", 1)].pages[int(entry.page) - 1].get("trigger", 0)) != 4: return _fail("并行实例不是并行事件页。")
		var execution: Variant = value.executions[key]
		if execution != null and not _execution_valid(execution): return _fail("事件指针、调用栈或等待状态无效。")
		if execution != null:
			var context: Dictionary = execution.context
			if Data.map(int(context.source_map_id)).is_empty(): return _fail("执行来源地图不存在。")
			for frame in [context] + context.stack:
				if int(frame.common_id) > 0 and _common_missing(int(frame.common_id), lookup): return _fail("调用栈公共事件不存在。")
			if key.begins_with("common:") and int(context.common_id) != int(key.get_slice(":", 1)) and context.stack.is_empty(): return _fail("并行公共事件身份与执行列表不一致。")
	if not value.get("requests") is Array or value.requests.size() > 10000: return _fail("事件界面队列无效。")
	var seen := {}
	for request in value.requests:
		if not request is Dictionary or not request.get("payload") is Array or not request.get("owner") is String: return _fail("事件界面请求无效。")
		if request.get("kind") == "diagnostic":
			if request.payload.size() != 1 or not request.payload[0] is String: return _fail("诊断请求无效。")
			continue
		if request.get("kind") not in ["message", "choice", "number", "button", "shop", "name", "menu", "save"] or not value.executions.has(request.owner) or value.executions[request.owner] == null or seen.has(request.owner): return _fail("界面请求没有唯一执行者。")
		var execution: Dictionary = value.executions[request.owner]
		if execution.wait.kind.get_slice(":", 0) != request.kind or not _payload_valid(request): return _fail("界面请求和事件等待不一致。")
		seen[request.owner] = true
	for key in value.executions:
		var execution: Variant = value.executions[key]
		if execution != null and execution.wait.kind.get_slice(":", 0) in ["message", "choice", "number", "button", "shop", "name", "menu", "save"] and not seen.has(key): return _fail("界面等待丢失了请求。")
	if not value.get("main_key") is String or value.main_key.length() > 256 or not Numbers.integer(value.get("locked_id"), 0) or (value.locked_id != 0 and not value.events.has(str(int(value.locked_id)))) or not value.get("faults") is Dictionary or value.faults.size() > 10000 or not Numbers.integer(value.get("offset"), 0, 10000): return _fail("事件调度状态无效。")
	for key in value.faults:
		if not key is String or key.length() > 256 or not value.faults[key] is bool: return _fail("事件故障记录无效。")
	return {"ok": true, "value": value.duplicate(true)}

static func _common_missing(id: int, lookup: Callable) -> bool:
	return (lookup.call("CommonEvents", id) if lookup.is_valid() else Data.record("CommonEvents", id)).is_empty()

static func _character(value: Variant, map: Dictionary) -> Dictionary:
	if not value is Dictionary: return _fail("人物记录无效。")
	var result := Motion.decode(value.get("motion"), int(map.width), int(map.height))
	if not result.ok: return result
	if not Route.validate_persistent(value.get("routes")): return _fail("人物路线进度无效。")
	if not value.get("name") is String or value.name.length() > 1024 or not preload("res://runtime/scripts/EventCommandCatalog.gd")._asset_name(value.name) or not Numbers.integer(value.get("hue"), 0, 360) or not Numbers.integer(value.get("tile_id"), 0, 1000000) or (value.tile_id != 0 and value.tile_id < 384): return _fail("人物图形无效。")
	if not value.name.is_empty() and value.tile_id == 0 and Cache.character(value.name) == null: return _fail("存档人物图形缺失：" + value.name)
	if not Numbers.integer(value.get("original_direction"), 2, 8) or int(value.original_direction) not in [2, 4, 6, 8] or not Numbers.integer(value.get("original_pattern"), 0, 3) or not value.get("always_on_top") is bool or not value.get("fallback_visible") is bool: return _fail("人物显示属性无效。")
	return {"ok": true}

static func _instance_key(key: String, events: Dictionary) -> bool:
	var parts := key.split(":")
	if parts.size() == 2 and parts[0] == "common": return parts[1].is_valid_int() and int(parts[1]) > 0
	return parts.size() == 3 and parts[0] == "event" and parts[1].is_valid_int() and parts[2].is_valid_int() and events.has(parts[1]) and int(parts[2]) == int(events[parts[1]].page)

static func _frame_valid(frame: Variant) -> bool:
	if not frame is Dictionary or not frame.get("commands") is Array or frame.commands.size() > 100000 or not Numbers.integer(frame.get("index"), 0, frame.commands.size()) or not Numbers.integer(frame.get("event_id"), 0) or not Numbers.integer(frame.get("common_id"), 0): return false
	for command in frame.commands:
		if not command is Dictionary or not Numbers.integer(command.get("code"), 0, 9999) or not Numbers.integer(command.get("indent", 0), 0, 999) or not command.get("parameters", []) is Array: return false
	for field in ["branches", "loops"]:
		if not frame.get(field) is Dictionary or frame[field].size() > 1000: return false
		for key in frame[field]:
			if not str(key).is_valid_int() or int(str(key)) < 0 or int(str(key)) > 999 or not Numbers.integer(frame[field][key], -1 if field == "branches" else 0, 4 if field == "branches" else frame.commands.size()): return false
	return true

static func _execution_valid(value: Variant) -> bool:
	if not value is Dictionary or not _frame_valid(value.get("context")) or not value.get("wait") is Dictionary or not value.get("locals") is Dictionary: return false
	var context: Dictionary = value.context
	for field in ["source_event_id", "source_map_id", "page", "waiting_indent", "shop_command_index"]:
		if not Numbers.integer(context.get(field), 0): return false
	if not context.get("stack") is Array or context.stack.size() > 32: return false
	for frame in context.stack:
		if not _frame_valid(frame): return false
	var kind: Variant = value.wait.get("kind")
	if not kind is String or (kind not in WAITS and not ((kind.begins_with("number:") or kind.begins_with("button:")) and kind.get_slice(":", 1).is_valid_int() and int(kind.get_slice(":", 1)) > 0)): return false
	var remaining: Variant = value.wait.get("remaining")
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or remaining < 0 or remaining > 1000000000 or (kind != "time" and remaining != 0): return false
	for field in LOCAL_FIELDS:
		if field == "_route_wait_warned":
			if not value.locals.get(field) is bool: return false
		elif not Numbers.integer(value.locals.get(field), 0, 1000000): return false
	return value.locals._choice_count <= 4 and value.locals._choice_cancel <= 5 and Numbers.integer(value.locals._number_digits, 1, 8) and Numbers.integer(value.locals._name_maximum, 1, 99)

static func _payload_valid(request: Dictionary) -> bool:
	var p: Array = request.payload
	match request.kind:
		"menu", "save": return p.is_empty()
		"name": return p.size() == 2 and Numbers.integer(p[0], 1) and Numbers.integer(p[1], 1, 99)
		"shop": return p.size() == 1 and p[0] is Array and preload("res://runtime/scripts/ShopService.gd").catalog(p[0]).ok
		"message": return p.size() == 2 and p[0] is Array and p[0].all(func(line: Variant) -> bool: return line is String) and _options_valid(p[1])
		"choice", "number":
			if p.size() == 1 and p[0] is Dictionary:
				var value: Dictionary = p[0]
				if value.get("kind") != request.kind or not value.get("lines") is Array or not value.lines.all(func(line: Variant) -> bool: return line is String) or not _options_valid(value): return false
				return (value.get("choices") is Array and value.choices.size() <= 4 and value.choices.all(func(line: Variant) -> bool: return line is String) and Numbers.integer(value.get("cancel"), 0, 5)) if request.kind == "choice" else (Numbers.integer(value.get("variable"), 1) and Numbers.integer(value.get("digits"), 1, 8))
			if p.size() != 3 or not _options_valid(p[2]): return false
			return (p[0] is Array and p[0].size() <= 4 and p[0].all(func(line: Variant) -> bool: return line is String) and Numbers.integer(p[1], 0, 5)) if request.kind == "choice" else (Numbers.integer(p[0], 1) and Numbers.integer(p[1], 1, 8))
		"button": return p.size() == 2 and Numbers.integer(p[0], 1) and _options_valid(p[1])
	return false

static func _options_valid(value: Variant) -> bool:
	return value is Dictionary and Numbers.integer(value.get("position"), 0, 2) and Numbers.integer(value.get("frame"), 0, 1)

static func restore(game: Node, value: Dictionary) -> void:
	if value.is_empty(): return
	var map: Node = game.event_map()
	map._erased_events.clear()
	for id in value.erased: map._erased_events[int(id)] = true
	map.refresh_events()
	map._dormant_events.clear()
	for key in value.events:
		var entry: Dictionary = value.events[key]
		var node: Node = map.event_node(int(key))
		if node != null and entry.character != null:
			node.restore_persistent(entry.character)
			node.locked = entry.locked; node._prelock_direction = int(entry.prelock_direction)
		elif entry.character != null: map._dormant_events[int(key)] = entry.character.duplicate(true)
	game._player.restore_persistent(value.player)
	map._reindex_events()
	var scheduler: RefCounted = game._scheduler
	scheduler._reconcile()
	var owners := {"main": scheduler.main}
	for key in scheduler.parallels: owners[key] = scheduler.parallels[key].owner
	for key in value.executions:
		if owners.has(key): _restore_interpreter(owners[key], value.executions[key])
	scheduler._main_key = value.main_key; scheduler._faults = value.faults.duplicate(); scheduler._offset = int(value.offset)
	var locked: Node = map.event_node(int(value.locked_id))
	scheduler._locked = weakref(locked) if locked != null else null
	var ui: RefCounted = game._event_ui
	for request in value.requests:
		if request.kind == "diagnostic": ui.report(request.payload[0])
		elif owners.has(request.owner): ui._queue(weakref(owners[request.owner]), request.kind, request.payload.duplicate(true))
	game._events_enabled = true
	game._player.resume_after_menu()
	game._sync_event_input()

static func _restore_interpreter(owner: RefCounted, value: Variant) -> void:
	owner.cancel()
	if value == null: return
	owner.managed = true
	for field in CONTEXT_FIELDS:
		var entry: Variant = value.context[field]
		owner.context.set(field, entry.duplicate(true) if entry is Array or entry is Dictionary else int(entry))
	_normalize_frame(owner.context)
	for frame in owner.context.stack: _normalize_frame(frame)
	for field in LOCAL_FIELDS: owner.set(field, value.locals[field] if field == "_route_wait_warned" else int(value.locals[field]))
	owner.wait_state.begin(value.wait.kind, float(value.wait.remaining))
	owner.running = true

static func _normalize_frame(frame: Variant) -> void:
	for field in ["branches", "loops"]:
		var normalized := {}
		for key in frame[field]: normalized[int(str(key))] = int(frame[field][key])
		frame[field] = normalized
	for field in ["index", "event_id", "common_id"]: frame[field] = int(frame[field])

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

extends RefCounted
## Single owner for foreground and parallel UI. Callbacks carry request identity.
signal requested(kind: String, payload: Array, request_id: int)
signal dismissed(kind: String)
signal terminal_requested(kind: String)
var active: Dictionary = {}
var _pending: Array[Dictionary] = []
var _serial := 0

func bind_interpreter(owner: RefCounted) -> void:
	var reference: WeakRef = weakref(owner)
	owner.message_requested.connect(func(lines: Array) -> void: _queue(reference, "message", [lines, _options()]))
	owner.unblocking_message_requested.connect(func(lines: Array,event_id: int) -> void:
		var result=preload("ScriptRuntime.gd").call_transaction(RuntimeState,{"source":"0161 Interpreter.command_101","operation":"parallel_hint"},func(env):
			var ids: Variant=env._custom.temp_fields.get("event_id",[0,0])
			if not ids is Array or ids.size()!=2: return env.fail("消息事件ID绑定需要两项。")
			ids[1]=event_id
			env._custom.temp_fields.event_id=ids; env._custom.temp_fields.unblocking_text="\n".join(lines); return true)
		if not result.ok:
			var current: RefCounted=reference.get_ref()
			if current!=null: current.reject_dialogue(result.message))
	owner.choices_requested.connect(func(choices: Array, cancel: int) -> void: _queue(reference, "choice", [choices, cancel, _options()]))
	owner.number_requested.connect(func(id: int, digits: int) -> void: _queue(reference, "number", [id, digits, _options()]))
	owner.dialogue_requested.connect(func(payload: Dictionary) -> void: _queue(reference, payload.kind, [payload.duplicate(true)]))
	owner.button_requested.connect(func(id: int) -> void: _queue(reference, "button", [id, _options()]))
	owner.name_requested.connect(func(id: int, maximum: int) -> void: _queue(reference, "name", [id, maximum]))
	owner.menu_requested.connect(func() -> void: _queue(reference, "menu", []))
	owner.save_requested.connect(func() -> void: _queue(reference, "save", []))
	owner.scene_requested.connect(func(kind: String) -> void:
		var current: RefCounted = reference.get_ref()
		if current != null and current.running and current.wait_kind() == "scene": terminal_requested.emit(kind)
	)
	owner.shop_requested.connect(func(goods: Array) -> void: _queue(reference, "shop", [goods]))
	owner.diagnostic_requested.connect(report)

func report(message: String) -> void:
	_serial += 1
	_pending.append({"kind": "diagnostic", "payload": [message], "id": _serial})

func busy() -> bool:
	return not active.is_empty() or not _pending.is_empty()

func next_kind() -> String:
	for request in _pending:
		if _valid(request): return request.kind
	return ""

func pump(available: bool = true) -> void:
	if not active.is_empty() and not _valid(active):
		var kind: String = active.kind
		active = {}
		dismissed.emit(kind)
	for index in range(_pending.size() - 1, -1, -1):
		if not _valid(_pending[index]): _pending.remove_at(index)
	if not available or not active.is_empty() or _pending.is_empty(): return
	active = _pending.pop_front()
	requested.emit(active.kind, active.payload, active.id)

func resolve(request_id: int, value: Variant = null) -> void:
	if active.is_empty() or int(active.id) != request_id: return
	if active.kind == "name" and not value is String: return
	if active.kind in ["choice", "number", "button"] and not preload("res://runtime/scripts/ActorParameters.gd").integer(value): return
	var request := active
	active = {}
	if not _valid(request): return
	if request.kind == "diagnostic": return
	var owner: RefCounted = request.owner.get_ref()
	match request.kind:
		"message": owner.resume_message(request.token)
		"choice": owner.resume_choice(int(value), request.token)
		"number": owner.resume_number(int(value), request.token)
		"shop": owner.resume_shop(request.token)
		"name", "menu", "save": owner.resume_scene_ui(request.kind, value, request.token)
		"button": owner.resume_button(int(value), request.token)
	if owner.running and owner.wait_token() == request.token: active = request

func reject(request_id: int, message: String) -> void:
	if active.is_empty() or int(active.id) != request_id: return
	var request := active
	active = {}
	if _valid(request):
		if request.kind == "shop": request.owner.get_ref().reject_shop(message)
		elif request.kind in ["name", "menu", "save"]: request.owner.get_ref().reject_scene_ui(request.kind, message)
		elif request.kind in ["message","choice","number"]: request.owner.get_ref().reject_dialogue(message)

func cancel_all() -> void:
	_pending.clear()
	if not active.is_empty():
		var kind: String = active.kind
		active = {}
		dismissed.emit(kind)

func _queue(reference: WeakRef, kind: String, payload: Array) -> void:
	var owner: RefCounted = reference.get_ref()
	if owner == null: return
	if RuntimeState.custom_data.manifest.get("profile")=="flash" and not payload.is_empty() and payload[-1] is Dictionary:
		payload[-1]["event_id"]=owner.context.event_id
	_serial += 1
	_pending.append({"owner": reference, "kind": kind, "payload": payload, "id": _serial, "token": owner.wait_token(), "wait": owner.wait_kind()})

func _valid(request: Dictionary) -> bool:
	if request.kind == "diagnostic": return true
	var owner: RefCounted = request.owner.get_ref()
	return owner != null and owner.running and owner.wait_token() == request.token and owner.wait_kind() == request.wait

func _options() -> Dictionary:
	return {"position": RuntimeState.message_position, "frame": RuntimeState.message_frame}

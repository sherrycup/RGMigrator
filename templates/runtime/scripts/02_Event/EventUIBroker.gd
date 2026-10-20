## 职责：仲裁事件界面请求及输入归属，协调消息、菜单和场景等待。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/02_Event/EventUIBroker.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func bind_interpreter(owner: RefCounted) -> void
##     参数 owner（RefCounted；必填）：持有此对象的调用方或运行状态。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func report(message: String) -> void
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func busy() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func next_kind() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func pump(available: bool = true) -> void
##     参数 available（bool；默认值 true）：当前允许使用的对象或功能集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func resolve(request_id: int, value: Variant = null) -> void
##     参数 request_id（int；必填）：用于匹配响应、取消和等待的请求编号。
##     参数 value（Variant；默认值 null）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func reject(request_id: int, message: String) -> void
##     参数 request_id（int；必填）：用于匹配响应、取消和等待的请求编号。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func cancel_all() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   requested(kind: String, payload: Array, request_id: int)：由持有方发出，通知对应状态或操作结果。
##     kind：消息、操作或对象的种类标识。
##     payload：消息或调用请求的结构化内容。
##     request_id：用于匹配响应、取消和等待的请求编号。
##   dismissed(kind: String)：由持有方发出，通知对应状态或操作结果。
##     kind：消息、操作或对象的种类标识。
##   terminal_requested(kind: String)：由持有方发出，通知对应状态或操作结果。
##     kind：消息、操作或对象的种类标识。
##
## 接口说明结束。

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
	owner.message_requested.connect(
		func(lines: Array) -> void: _queue(reference, "message", [lines, _options()])
	)
	owner.unblocking_message_requested.connect(
		func(lines: Array, event_id: int) -> void:
			var result = preload("../10_Support/Scripting/ScriptRuntime.gd").call_transaction(
				RuntimeState,
				{"source": "0161 Interpreter.command_101", "operation": "parallel_hint"},
				func(env):
					var ids: Variant = env._custom.temp_fields.get("event_id", [0, 0])
					if not ids is Array or ids.size() != 2:
						return env.fail("消息事件ID绑定需要两项。")
					ids[1] = event_id
					env._custom.temp_fields.event_id = ids
					env._custom.temp_fields.unblocking_text = "\n".join(lines)
					return true
			)
			if not result.ok:
				var current: RefCounted = reference.get_ref()
				if current != null:
					current.reject_dialogue(result.message)
	)
	owner.choices_requested.connect(
		func(choices: Array, cancel: int) -> void:
			_queue(reference, "choice", [choices, cancel, _options()])
	)
	owner.number_requested.connect(
		func(id: int, digits: int) -> void: _queue(reference, "number", [id, digits, _options()])
	)
	owner.dialogue_requested.connect(
		func(payload: Dictionary) -> void:
			_queue(reference, payload.kind, [payload.duplicate(true)])
	)
	owner.button_requested.connect(
		func(id: int) -> void: _queue(reference, "button", [id, _options()])
	)
	owner.name_requested.connect(
		func(id: int, maximum: int) -> void: _queue(reference, "name", [id, maximum])
	)
	owner.menu_requested.connect(func() -> void: _queue(reference, "menu", []))
	owner.save_requested.connect(func() -> void: _queue(reference, "save", []))
	owner.scene_requested.connect(
		func(kind: String) -> void:
			var current: RefCounted = reference.get_ref()
			if current != null and current.running and current.wait_kind() == "scene":
				terminal_requested.emit(kind)
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
		if _valid(request):
			return request.kind
	return ""


func pump(available: bool = true) -> void:
	if not active.is_empty() and not _valid(active):
		var kind: String = active.kind
		active = {}
		dismissed.emit(kind)
	for index in range(_pending.size() - 1, -1, -1):
		if not _valid(_pending[index]):
			_pending.remove_at(index)
	if not available or not active.is_empty() or _pending.is_empty():
		return
	active = _pending.pop_front()
	requested.emit(active.kind, active.payload, active.id)


func resolve(request_id: int, value: Variant = null) -> void:
	if active.is_empty() or int(active.id) != request_id:
		return
	if active.kind == "name" and not value is String:
		return
	if (
		active.kind in ["choice", "number", "button"]
		and not preload("res://runtime/scripts/00_Game/ActorParameters.gd").integer(value)
	):
		return
	var request := active
	active = {}
	if not _valid(request):
		return
	if request.kind == "diagnostic":
		return
	var owner: RefCounted = request.owner.get_ref()
	match request.kind:
		"message":
			owner.resume_message(request.token)
		"choice":
			owner.resume_choice(int(value), request.token)
		"number":
			owner.resume_number(int(value), request.token)
		"shop":
			owner.resume_shop(request.token)
		"name", "menu", "save":
			owner.resume_scene_ui(request.kind, value, request.token)
		"button":
			owner.resume_button(int(value), request.token)
	if owner.running and owner.wait_token() == request.token:
		active = request


func reject(request_id: int, message: String) -> void:
	if active.is_empty() or int(active.id) != request_id:
		return
	var request := active
	active = {}
	if _valid(request):
		if request.kind == "shop":
			request.owner.get_ref().reject_shop(message)
		elif request.kind in ["name", "menu", "save"]:
			request.owner.get_ref().reject_scene_ui(request.kind, message)
		elif request.kind in ["message", "choice", "number"]:
			request.owner.get_ref().reject_dialogue(message)


func cancel_all() -> void:
	_pending.clear()
	if not active.is_empty():
		var kind: String = active.kind
		active = {}
		dismissed.emit(kind)


func _queue(reference: WeakRef, kind: String, payload: Array) -> void:
	var owner: RefCounted = reference.get_ref()
	if owner == null:
		return
	if (
		RuntimeState.custom_data.manifest.get("profile") == "flash"
		and not payload.is_empty()
		and payload[-1] is Dictionary
	):
		payload[-1]["event_id"] = owner.context.event_id
	_serial += 1
	_pending.append(
		{
			"owner": reference,
			"kind": kind,
			"payload": payload,
			"id": _serial,
			"token": owner.wait_token(),
			"wait": owner.wait_kind()
		}
	)


func _valid(request: Dictionary) -> bool:
	if request.kind == "diagnostic":
		return true
	var owner: RefCounted = request.owner.get_ref()
	return (
		owner != null
		and owner.running
		and owner.wait_token() == request.token
		and owner.wait_kind() == request.wait
	)


func _options() -> Dictionary:
	return {"position": RuntimeState.message_position, "frame": RuntimeState.message_frame}

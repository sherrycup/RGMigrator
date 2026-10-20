## 职责：推进闪翼消息队列、等待和输入状态，协调文本流、布局及显示。
##
## 调用方式：
##   使用 RuntimeState.flash_messages 这一消息控制器；由消息覆盖层负责绘制。
##   事件请求通常经 EventUIBroker 进入；present 返回消息框 id，用户响应通过信号回传。
##
## 调用接口：
##   func _init(owner: Object) -> void
##     用途：记录持有消息现场的运行状态。
##     参数 owner（Object；必填）：正式 RuntimeState；内部通过 WeakRef 保持归属。
##     返回：通过 .new(owner) 获得控制器实例。
##
##   func present( payload: Dictionary, request_id: int = -1, event_id: int = 0, hint: bool = false, consume_field: String = "" ) -> Dictionary
##     用途：校验消息请求并创建文章、选择或数字输入框。
##     参数 payload（Dictionary；必填）：kind 为 message/choice/number；lines 为文本数组；choice 另需 choices、cancel，number 另需 variable、digits。
##     参数 request_id（int；默认值 -1）：事件请求身份；-1 表示调用方没有绑定等待请求。
##     参数 event_id（int；默认值 0）：关联地图事件编号，用于人物锚点和等待判定。
##     参数 hint（bool；默认值 false）：true 按提示消息处理，仅接受 message。
##     参数 consume_field（String；默认值 ""）：消息成功记录后需要清理的临时来源字段；空串表示没有。
##     返回：成功返回 {ok:true, id:消息框编号}；失败返回 {ok:false, message:原因}。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func tick() -> void
##     用途：推进一次原 60 Hz 消息逻辑帧。
##     参数：无。
##     返回：无返回值；可能发出 responded、rejected 或 changed。
##
##   func confirm() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func handle_key(key: int) -> bool
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：true 表示本次输入已被处理，false 表示未由该入口处理。
##
##   func relayout(next_size: Vector2) -> void
##     用途：视口尺寸变化时重排活动气泡，保留已绘制词元、分页状态及分支选择。
##     参数 next_size（Vector2；必填）：新的Viewport逻辑像素宽高；尺寸相同则不重排。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func message_window_showing() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func interpreter_waiting(event_id: int, blocking: bool) -> bool
##     参数 event_id（int；必填）：当前地图上的事件编号；0 的具体含义由调用入口约定。
##     参数 blocking（bool；必填）：是否等待该请求完成后继续事件。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func cancel_request(request_id: int) -> void
##     参数 request_id（int；必填）：用于匹配响应、取消和等待的请求编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func reset() -> void
##     用途：重置本服务持有的状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func history(hint: bool = false) -> Array
##     用途：读取消息历史条目。
##     参数 hint（bool；默认值 false）：false 读取文章历史，true 读取短提示历史。
##     返回：历史条目数组。
##
## 对外信号：
##   responded(request_id: int, kind: String, value: Variant)：消息请求得到响应，参数携带原请求编号、消息种类和用户结果。
##     request_id：用于匹配响应、取消和等待的请求编号。
##     kind：消息、操作或对象的种类标识。
##     value：需要读取、校验或写入的值。
##   rejected(request_id: int, message: String)：消息请求失败，参数携带原请求编号和错误说明。
##     request_id：用于匹配响应、取消和等待的请求编号。
##     message：提示或诊断文本。
##   changed()：当前模型或草稿已经变化，界面可据此刷新。
##
## 注意：控制器持有活动消息状态，视图只读取绘制；不要另建脱离事件身份的消息现场。
## 接口说明结束。

extends RefCounted
## Source 0191. RuntimeState owns every live box; the view only paints them.
signal responded(request_id: int, kind: String, value: Variant)
signal rejected(request_id: int, message: String)
signal changed
const Box = preload("MessageBoxState.gd")
const Layout = preload("MessageLayout.gd")
const Scripts = preload("../10_Support/Scripting/ScriptRuntime.gd")
var boxes: Array = []
var viewport_size = Vector2(640, 640)
var _owner: WeakRef
var _serial = 0
var _clock = 0.0
var _layout_hud: Variant = null


func _init(owner: Object) -> void:
	_owner = weakref(owner)


func present(
	payload: Dictionary,
	request_id: int = -1,
	event_id: int = 0,
	hint: bool = false,
	consume_field: String = ""
) -> Dictionary:
	var owner = _owner.get_ref()
	if owner == null:
		return {"ok": false, "message": "消息运行状态已释放。"}
	var kind = str(payload.get("kind", "message"))
	var source_lines: Variant = payload.get("lines", [])
	if (
		kind not in ["message", "choice", "number"]
		or hint and kind != "message"
		or not source_lines is Array
	):
		return {"ok": false, "message": "消息种类或文章行参数无效。"}
	for line in source_lines:
		if not line is String:
			return {"ok": false, "message": "消息文章行必须是字符串。"}
	if kind == "choice":
		var choices: Variant = payload.get("choices")
		if (
			not choices is Array
			or choices.is_empty()
			or not preload("../00_Game/ActorParameters.gd").integer(payload.get("cancel"), 0, 5)
		):
			return {"ok": false, "message": "消息选择项或取消类型无效。"}
		for line in choices:
			if not line is String:
				return {"ok": false, "message": "消息选择项必须是字符串。"}
	if (
		kind == "number"
		and (
			not preload("../00_Game/ActorParameters.gd").integer(payload.get("variable"), 1)
			or not preload("../00_Game/ActorParameters.gd").integer(payload.get("digits"), 1, 8)
		)
	):
		return {"ok": false, "message": "消息数值变量或位数无效。"}
	var lines: Array = source_lines.duplicate()
	if kind == "choice":
		lines.append_array(payload.get("choices", []))
	var raw = "\n".join(lines)
	var model = Box.new(raw, owner, hint)
	if not model.failure.is_empty():
		return {"ok": false, "message": model.failure}
	if (
		kind in ["choice", "number"]
		and model.tokens.any(
			func(token): return token is Array and token[0].unicode_at(0) in [17, 29]
		)
	):
		return {"ok": false, "message": "选择或数值输入不能使用提前关闭/自动关闭控制码；需要用户确认结果。"}
	var layout = Layout.new(
		model, owner, viewport_size, Layout.choice_lines(payload), 32 if kind == "number" else 0
	)
	if not layout.failure.is_empty():
		return {"ok": false, "message": layout.failure}
	var history = _record(owner, payload, raw, layout.name_text, hint, consume_field)
	if not history.ok:
		return history
	_serial += 1
	var entry = {
		"id": _serial,
		"model": model,
		"layout": layout,
		"request_id": request_id,
		"event_id": event_id,
		"hint": hint,
		"kind": kind,
		"payload": payload.duplicate(true),
		"released": false,
		"choice_index": 0,
		"result": null,
		"number": 0,
		"digit_index": 0,
		"input_ready": false
	}
	if kind == "number":
		entry.number = clampi(
			int(owner.variables.get(str(int(payload.variable)), 0)),
			0,
			int(pow(10, int(payload.digits))) - 1
		)
	boxes.append(entry)
	changed.emit()
	return {"ok": true, "id": _serial}


func advance(delta: float) -> void:
	var owner = _owner.get_ref()
	if owner == null or not is_finite(delta) or delta < 0:
		return
	if (
		owner.script_session != null
		and (owner.script_session._active or not owner.script_session._snapshot.is_empty())
	):
		return
	_consume_temp(owner)
	_clock += delta * 60
	var frames = mini(120, int(_clock))
	_clock -= frames
	for frame in frames:
		tick()


func tick() -> void:
	var owner = _owner.get_ref()
	if owner == null:
		return
	for entry in boxes.duplicate():
		if entry not in boxes:
			continue
		var model: RefCounted = entry.model
		model.tick()
		if model.state == 3 and not entry.get("input_ready", false):
			entry.input_ready = true
			_reveal_choice(entry)
		if model.state == 3 and entry.kind == "choice" and not entry.layout.choice_rects.is_empty():
			entry.cursor_ticks = mini(8, int(entry.get("cursor_ticks", 8)) + 1)
			var target: float = entry.layout.choice_rects[entry.choice_index].position.y
			entry.cursor_y = lerpf(
				float(entry.get("cursor_from", target)), target, float(entry.cursor_ticks) / 8
			)
			entry.cursor_phase = posmod(int(entry.get("cursor_phase", 0)) + 1, 48)
		for effect in model.effects:
			if effect.kind == "se":
				var result = owner.audio.play("SE", effect)
				if not result.ok:
					owner.report_diagnostic(result.message)
		if not model.failure.is_empty():
			owner.report_diagnostic(model.failure)
			boxes.erase(entry)
			if entry.request_id >= 0 and not entry.released:
				rejected.emit(int(entry.request_id), model.failure)
			continue
		if (
			entry.kind == "message"
			and not entry.hint
			and not entry.released
			and not interpreter_waiting(entry.event_id, true)
		):
			_respond(entry, null)
		if model.finished():
			if not entry.hint and not entry.released:
				if entry.kind in ["choice", "number"] and entry.result == null:
					if entry.request_id >= 0:
						rejected.emit(int(entry.request_id), "输入窗口在返回结果前被关闭。")
				else:
					_respond(entry, entry.result)
			boxes.erase(entry)
	changed.emit()


func confirm() -> bool:
	var accepted = false
	for entry in boxes.duplicate():
		if entry.hint:
			if entry.model.state == 2:
				entry.model.confirm()
			continue
		if entry.model.finished():
			continue
		accepted = true
		var model: RefCounted = entry.model
		if model.process > 0:
			continue
		if model.pageon > 0:
			continue
		if model.state == 3 and entry.kind in ["choice", "number"]:
			entry.result = entry.choice_index if entry.kind == "choice" else entry.number
			model.state = -1
			continue
		model.confirm()
	return accepted


func handle_key(key: int) -> bool:
	if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
		return confirm()
	for entry in boxes:
		if entry.hint or entry.model.state != 3:
			continue
		if entry.kind == "choice":
			var choices: Array = entry.payload.get("choices", [])
			if key in [KEY_UP, KEY_DOWN] and not choices.is_empty():
				entry.choice_index = posmod(
					entry.choice_index + (1 if key == KEY_DOWN else -1), choices.size()
				)
				_reveal_choice(entry)
				changed.emit()
				return true
			if key in [KEY_ESCAPE, KEY_X] and int(entry.payload.get("cancel", 0)) > 0:
				var cancel = int(entry.payload.cancel)
				entry.result = -1 if cancel == 5 else cancel - 1
				entry.model.state = -1
				return true
		elif entry.kind == "number":
			if key >= KEY_0 and key <= KEY_9:
				entry.number = (
					(int(entry.number) * 10 + key - KEY_0) % int(pow(10, int(entry.payload.digits)))
				)
				changed.emit()
				return true
			if key == KEY_BACKSPACE:
				entry.number = int(entry.number) / 10
				changed.emit()
				return true
			if key in [KEY_UP, KEY_DOWN]:
				var place = int(
					pow(10, int(entry.payload.digits) - 1 - int(entry.get("digit_index", 0)))
				)
				var digit = int(entry.number) / place % 10
				entry.number += (posmod(digit + (1 if key == KEY_UP else -1), 10) - digit) * place
				changed.emit()
				return true
			if key in [KEY_LEFT, KEY_RIGHT]:
				entry.digit_index = posmod(
					int(entry.get("digit_index", 0)) + (1 if key == KEY_RIGHT else -1),
					int(entry.payload.digits)
				)
				changed.emit()
				return true
	return message_window_showing()


func relayout(next_size: Vector2) -> void:
	var owner = _owner.get_ref()
	if owner == null:
		return
	var reserve_hud = not owner.switches.get("6", false)
	if next_size == viewport_size and reserve_hud == _layout_hud:
		return
	_layout_hud = reserve_hud
	viewport_size = next_size
	for entry in boxes:
		var model: RefCounted = entry.model
		var layout = Layout.new(
			model,
			owner,
			next_size,
			Layout.choice_lines(entry.payload),
			32 if entry.kind == "number" else 0
		)
		if not layout.failure.is_empty():
			continue
		entry.layout = layout
		# 重新分页后用游标定位当前页，缩小窗口也不让正在打的行落到裁切区外。
		var start = 0
		for index in model.page_breaks:
			if int(index) <= model.cursor and int(index) != model.page_pending_token:
				start = maxi(start, int(index))
		model.page_start_token = start
		model.page_scroll = float(
			layout.positions.get(model.page_start_token, {}).get("row_top", 0)
		)
		model.pageon = 0
		if model.page_pending_token >= 0 and not model.page_breaks.has(model.page_pending_token):
			model.page_pending_token = -1
			model.state = model.page_resume_state
		if model.state == 3:
			_reveal_choice(entry)
	changed.emit()


func _reveal_choice(entry: Dictionary) -> void:
	if entry.kind != "choice" or entry.layout.choice_rects.is_empty():
		return
	var rect: Rect2 = entry.layout.choice_rects[entry.choice_index]
	entry.cursor_from = float(entry.get("cursor_y", rect.position.y))
	entry.cursor_ticks = 0
	var model: RefCounted = entry.model
	if rect.position.y < model.page_scroll:
		model.page_scroll = rect.position.y
	elif rect.end.y > model.page_scroll + entry.layout.text_size.y:
		model.page_scroll = (
			maxf(0, rect.end.y - entry.layout.text_size.y)
			if rect.size.y <= entry.layout.text_size.y
			else rect.position.y
		)


func message_window_showing() -> bool:
	for entry in boxes:
		if not entry.hint:
			return true
	var owner = _owner.get_ref()
	return owner != null and owner.flash_temp_fields.get("message_text") != null


func interpreter_waiting(event_id: int, blocking: bool) -> bool:
	var found = false
	for entry in boxes:
		if entry.event_id != event_id or entry.hint == blocking:
			continue
		found = true
		if entry.model.interpreter_waiting and not entry.model.finished():
			return true
	return not found


func cancel_request(request_id: int) -> void:
	for entry in boxes.duplicate():
		if entry.request_id == request_id and not entry.released:
			boxes.erase(entry)
	changed.emit()


func reset() -> void:
	boxes.clear()
	_clock = 0
	changed.emit()


func history(hint: bool = false) -> Array:
	var owner = _owner.get_ref()
	return (
		(
			owner
			. custom_data
			. values
			. system
			. get("ub_message_list" if hint else "message_list", [])
			. duplicate(true)
		)
		if owner != null
		else []
	)


func _respond(entry: Dictionary, value: Variant) -> void:
	entry.released = true
	if entry.request_id >= 0:
		responded.emit(entry.request_id, entry.kind, value)


func _record(
	owner: Object,
	payload: Dictionary,
	raw: String,
	name_text: String,
	hint: bool,
	consume_field: String
) -> Dictionary:
	return Scripts.call_transaction(
		owner,
		{"source": "0191 Message_Controller", "operation": "record_message"},
		func(env):
			var key = "ub_message_list" if hint else "message_list"
			var constants: Dictionary = (
				preload("../00_Game/RuntimeData.gd")
				. read_json("res://data/flash_gameplay.json", {})
				. get("constants", {})
			)
			var maximum = int(
				constants.get(
					"Storage::MEM_UB_MESSAGE" if hint else "Storage::MEM_MESSAGE",
					50 if hint else 100
				)
			)
			var records: Array = env._custom.values.system.get(key, [])
			var rows: Array = []
			if payload.get("kind") == "choice":
				if not payload.get("lines", []).is_empty():
					rows.append([name_text, "".join(payload.lines)])
				rows.append(
					[
						"分支",
						"".join(
							payload.get("choices", []).map(
								func(value): return "→ " + str(value) + "\\n"
							)
						)
					]
				)
			else:
				rows.append([name_text, raw])
			for row in rows:
				while records.size() >= maxi(1, maximum):
					records.pop_front()
				records.append(row)
			env._custom.values.system[key] = records
			if not consume_field.is_empty():
				env._custom.temp_fields[consume_field] = null
				var ids: Variant = env._custom.temp_fields.get("event_id", [0, 0])
				if not ids is Array or ids.size() != 2:
					return env.fail("消息事件ID绑定需要两项。")
				ids[1 if hint else 0] = 0
				env._custom.temp_fields.event_id = ids
			return true
	)


func _consume_temp(owner: Object) -> void:
	for field in ["message_text", "unblocking_text"]:
		var raw: Variant = owner.flash_temp_fields.get(field)
		if raw == null:
			continue
		if not raw is String:
			owner.report_diagnostic("消息临时字段必须为文本：" + field)
			continue
		var ids: Variant = owner.flash_temp_fields.get("event_id", [0, 0])
		var hint = field == "unblocking_text"
		if (
			not ids is Array
			or ids.size() != 2
			or not preload("../00_Game/ActorParameters.gd").integer(ids[0], 0)
			or not preload("../00_Game/ActorParameters.gd").integer(ids[1], 0)
		):
			owner.report_diagnostic("消息事件ID绑定需要两项有效编号。")
			continue
		var result = present(
			{"kind": "message", "lines": [raw]}, -1, int(ids[1 if hint else 0]), hint, field
		)
		if not result.ok:
			owner.report_diagnostic(result.message)

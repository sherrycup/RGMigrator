extends RefCounted
## Source 0191. RuntimeState owns every live box; the view only paints them.
signal responded(request_id: int,kind: String,value: Variant)
signal rejected(request_id: int,message: String)
signal changed
const Box=preload("FlashMessageBoxState.gd")
const Layout=preload("FlashMessageLayout.gd")
const Scripts=preload("ScriptRuntime.gd")
var boxes: Array=[]
var viewport_size=Vector2(640,640)
var _owner: WeakRef
var _serial=0
var _clock=0.0

func _init(owner: Object) -> void: _owner=weakref(owner)

func present(payload: Dictionary,request_id: int=-1,event_id: int=0,hint: bool=false,consume_field: String="") -> Dictionary:
	var owner=_owner.get_ref()
	if owner==null: return {"ok":false,"message":"消息运行状态已释放。"}
	var kind=str(payload.get("kind","message")); var source_lines: Variant=payload.get("lines",[])
	if kind not in ["message","choice","number"] or hint and kind!="message" or not source_lines is Array: return {"ok":false,"message":"消息种类或文章行参数无效。"}
	for line in source_lines:
		if not line is String: return {"ok":false,"message":"消息文章行必须是字符串。"}
	if kind=="choice":
		var choices: Variant=payload.get("choices")
		if not choices is Array or choices.is_empty() or not preload("ActorParameters.gd").integer(payload.get("cancel"),0,5): return {"ok":false,"message":"消息选择项或取消类型无效。"}
		for line in choices:
			if not line is String: return {"ok":false,"message":"消息选择项必须是字符串。"}
	if kind=="number" and (not preload("ActorParameters.gd").integer(payload.get("variable"),1) or not preload("ActorParameters.gd").integer(payload.get("digits"),1,8)): return {"ok":false,"message":"消息数值变量或位数无效。"}
	var lines: Array=source_lines.duplicate()
	if kind=="choice": lines.append_array(payload.get("choices",[]))
	var raw="\n".join(lines)
	var model=Box.new(raw,owner,hint)
	if not model.failure.is_empty(): return {"ok":false,"message":model.failure}
	if kind in ["choice","number"] and model.tokens.any(func(token):return token is Array and token[0].unicode_at(0) in [17,29]): return {"ok":false,"message":"选择或数值输入不能使用提前关闭/自动关闭控制码；需要用户确认结果。"}
	var layout=Layout.new(model,owner,viewport_size)
	if not layout.failure.is_empty(): return {"ok":false,"message":layout.failure}
	if kind=="number": layout.box_size.y+=32; layout.text_size.y+=32
	var history=_record(owner,payload,raw,layout.name_text,hint,consume_field)
	if not history.ok: return history
	_serial+=1
	var entry={"id":_serial,"model":model,"layout":layout,"request_id":request_id,"event_id":event_id,"hint":hint,"kind":kind,"payload":payload.duplicate(true),"released":false,"choice_index":0,"result":null,"number":0}
	if kind=="number": entry.number=clampi(int(owner.variables.get(str(int(payload.variable)),0)),0,int(pow(10,int(payload.digits)))-1)
	boxes.append(entry); changed.emit()
	return {"ok":true,"id":_serial}

func advance(delta: float) -> void:
	var owner=_owner.get_ref()
	if owner==null or not is_finite(delta) or delta<0: return
	if owner.script_session!=null and (owner.script_session._active or not owner.script_session._snapshot.is_empty()): return
	_consume_temp(owner)
	_clock+=delta*60
	var frames=mini(120,int(_clock)); _clock-=frames
	for frame in frames: tick()

func tick() -> void:
	var owner=_owner.get_ref()
	if owner==null: return
	for entry in boxes.duplicate():
		if entry not in boxes: continue
		var model: RefCounted=entry.model
		model.tick()
		for effect in model.effects:
			if effect.kind=="se":
				var result=owner.audio.play("SE",effect)
				if not result.ok: owner.report_diagnostic(result.message)
		if not model.failure.is_empty():
			owner.report_diagnostic(model.failure); boxes.erase(entry)
			if entry.request_id>=0 and not entry.released: rejected.emit(int(entry.request_id),model.failure)
			continue
		if entry.kind=="message" and not entry.hint and not entry.released and not interpreter_waiting(entry.event_id,true): _respond(entry,null)
		if model.finished():
			if not entry.hint and not entry.released:
				if entry.kind in ["choice","number"] and entry.result==null:
					if entry.request_id>=0: rejected.emit(int(entry.request_id),"输入窗口在返回结果前被关闭。")
				else: _respond(entry,entry.result)
			boxes.erase(entry)
	changed.emit()

func confirm() -> bool:
	var accepted=false
	for entry in boxes.duplicate():
		if entry.hint:
			if entry.model.state==2: entry.model.confirm()
			continue
		if entry.model.finished(): continue
		accepted=true
		var model: RefCounted=entry.model
		if model.process>0: continue
		if model.state==3 and entry.kind in ["choice","number"]:
			entry.result=entry.choice_index if entry.kind=="choice" else entry.number
			model.state=-1; continue
		model.confirm()
	return accepted

func handle_key(key: int) -> bool:
	if key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_Z]: return confirm()
	for entry in boxes:
		if entry.hint or entry.model.state!=3: continue
		if entry.kind=="choice":
			var choices: Array=entry.payload.get("choices",[])
			if key in [KEY_UP,KEY_DOWN] and not choices.is_empty(): entry.choice_index=posmod(entry.choice_index+(1 if key==KEY_DOWN else -1),choices.size()); changed.emit(); return true
			if key in [KEY_ESCAPE,KEY_X] and int(entry.payload.get("cancel",0))>0:
				var cancel=int(entry.payload.cancel); entry.result=-1 if cancel==5 else cancel-1; entry.model.state=-1; return true
		elif entry.kind=="number":
			if key>=KEY_0 and key<=KEY_9: entry.number=(int(entry.number)*10+key-KEY_0)%int(pow(10,int(entry.payload.digits))); changed.emit(); return true
			if key==KEY_BACKSPACE: entry.number=int(entry.number)/10; changed.emit(); return true
			if key in [KEY_UP,KEY_DOWN]: entry.number=clampi(entry.number+(1 if key==KEY_UP else -1),0,int(pow(10,int(entry.payload.digits)))-1); changed.emit(); return true
	return message_window_showing()

func message_window_showing() -> bool:
	for entry in boxes:
		if not entry.hint: return true
	var owner=_owner.get_ref()
	return owner!=null and owner.flash_temp_fields.get("message_text")!=null

func interpreter_waiting(event_id: int,blocking: bool) -> bool:
	var found=false
	for entry in boxes:
		if entry.event_id!=event_id or entry.hint==blocking: continue
		found=true
		if entry.model.interpreter_waiting and not entry.model.finished(): return true
	return not found

func cancel_request(request_id: int) -> void:
	for entry in boxes.duplicate():
		if entry.request_id==request_id and not entry.released: boxes.erase(entry)
	changed.emit()

func reset() -> void:
	boxes.clear(); _clock=0; changed.emit()

func history(hint: bool=false) -> Array:
	var owner=_owner.get_ref()
	return owner.custom_data.values.system.get("ub_message_list" if hint else "message_list",[]).duplicate(true) if owner!=null else []

func _respond(entry: Dictionary,value: Variant) -> void:
	entry.released=true
	if entry.request_id>=0: responded.emit(entry.request_id,entry.kind,value)

func _record(owner: Object,payload: Dictionary,raw: String,name_text: String,hint: bool,consume_field: String) -> Dictionary:
	return Scripts.call_transaction(owner,{"source":"0191 Message_Controller","operation":"record_message"},func(env):
		var key="ub_message_list" if hint else "message_list"
		var constants: Dictionary=preload("RuntimeData.gd").read_json("res://data/flash_gameplay.json",{}).get("constants",{})
		var maximum=int(constants.get("Storage::MEM_UB_MESSAGE" if hint else "Storage::MEM_MESSAGE",50 if hint else 100))
		var records: Array=env._custom.values.system.get(key,[])
		var rows: Array=[]
		if payload.get("kind")=="choice":
			if not payload.get("lines",[]).is_empty(): rows.append([name_text,"".join(payload.lines)])
			rows.append(["分支","".join(payload.get("choices",[]).map(func(value):return "→ "+str(value)+"\\n"))])
		else: rows.append([name_text,raw])
		for row in rows:
			while records.size()>=maxi(1,maximum): records.pop_front()
			records.append(row)
		env._custom.values.system[key]=records
		if not consume_field.is_empty():
			env._custom.temp_fields[consume_field]=null
			var ids: Variant=env._custom.temp_fields.get("event_id",[0,0])
			if not ids is Array or ids.size()!=2: return env.fail("消息事件ID绑定需要两项。")
			ids[1 if hint else 0]=0; env._custom.temp_fields.event_id=ids
		return true)

func _consume_temp(owner: Object) -> void:
	for field in ["message_text","unblocking_text"]:
		var raw: Variant=owner.flash_temp_fields.get(field)
		if raw==null: continue
		if not raw is String: owner.report_diagnostic("消息临时字段必须为文本："+field); continue
		var ids: Variant=owner.flash_temp_fields.get("event_id",[0,0]); var hint=field=="unblocking_text"
		if not ids is Array or ids.size()!=2 or not preload("ActorParameters.gd").integer(ids[0],0) or not preload("ActorParameters.gd").integer(ids[1],0): owner.report_diagnostic("消息事件ID绑定需要两项有效编号。"); continue
		var result=present({"kind":"message","lines":[raw]},-1,int(ids[1 if hint else 0]),hint,field)
		if not result.ok: owner.report_diagnostic(result.message)

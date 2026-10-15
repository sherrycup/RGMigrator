extends RefCounted
## Source 0152–0155 timing/control state. A renderer consumes glyph/effect output.
const Text=preload("FlashMessageText.gd")
var tokens: Array=[]
var metadata: Dictionary={}
var cursor=0
var state=0 # Source: typing0, instant1, pause2, complete3, closing-1.
var process=10
var speed=1
var waiting=0
var auto_terminate=0
var interpreter_waiting=true
var move_time=0
var movement: Array=[0,0]
var offset=Vector2.ZERO
var back_opacity=255
var style: Dictionary=Text.defaults()
var painted: Array=[]
var effects: Array=[]
var pageon=0.0
var page_scroll=0.0
var page_targets: Dictionary={}
var failure=""
var hint=false
var _state_owner: WeakRef
var _hint_opacity: Variant=null

func _init(raw: String,owner: Object,is_hint: bool=false) -> void:
	_state_owner=weakref(owner); hint=is_hint
	var parsed=Text.parse(raw,owner)
	if not parsed.ok: failure=parsed.message; return
	tokens=parsed.tokens; metadata=parsed.metadata
	if mode() in [1,2]: back_opacity=0

func mode() -> int: return int(metadata.get("mo",0))
func extend_enabled() -> bool: return metadata.get("extend",true)
func finished() -> bool: return state==-1 and process>=10
func opacity() -> float:
	if finished(): return 0.0
	if process==0 and state!=-1 and _hint_opacity!=null: return clampf(float(_hint_opacity)/255,0,1)
	return 0.0 if mode()==1 else clampf((55.0+20*(10-process))/255,0,1)
func zoom() -> float:
	return (0.0 if finished() else 1.0) if mode() in [1,2] else (10-process)*0.1

func frame_opacity() -> float:
	if finished(): return 0.0
	if hint and _hint_opacity!=null and process==0 and state!=-1: return clampf(float(_hint_opacity)/255,0,1)
	if mode() in [1,2]: return clampf(float(back_opacity)/255,0,1)
	return opacity() if process>0 or state==-1 else clampf(float(back_opacity)/255,0,1)

func confirm() -> void:
	if process>0 or finished(): return
	if state==2: state=0 # Source pause lacked an internal resume key; repaired.
	elif state==3 and auto_terminate==0 and not hint: state=-1
	elif state==0 and extend_enabled(): state=1

func tick() -> void:
	effects.clear()
	if not failure.is_empty() or finished(): return
	if pageon>0:
		var amount=minf(pageon,2); pageon-=amount; page_scroll+=amount; return
	if state==-1: process=10 if mode()==1 else process+1; return
	if process>0:
		process=0 if mode() in [1,2] else process-1; return
	if state==2: return
	if state==3:
		if auto_terminate>0:
			auto_terminate-=1
			if auto_terminate==0: state=-1
		return
	# Original detects end of row before decrementing glyph wait.
	if cursor>=tokens.size(): state=3; return
	if waiting>0: waiting-=1; return
	if move_time>0:
		move_time-=1; offset-=Vector2(movement[0],movement[1]); return
	var count=0
	while cursor<tokens.size():
		count+=1
		if count>100000: failure="单帧即时文本超过100000个控制/字符。"; return
		var token: Variant=tokens[cursor]; cursor+=1
		if token is String:
			if token=="\n": continue
			painted.append({"kind":"glyph","text":token,"style":style.duplicate(),"token_index":cursor-1})
			if state!=1: break
			continue
		var code=token[0].unicode_at(0)
		match code:
			1,20,21,23,25,26,27,28: Text.apply_style(style,token); return
			3: speed=int(token[1]); return
			4:
				var args=str(token[1]).split(",",true)
				effects.append({"kind":"se","name":args[0],"volume":int(args[1]) if args.size()>1 else 100,"pitch":int(args[2]) if args.size()>2 else 100}); return
			5: waiting=Text.frame_duration(int(token[1])); return
			29: auto_terminate=Text.frame_duration(int(token[1])); return
			30,31:
				move_time=Text.frame_duration(int(token[1])); movement[0 if code==30 else 1]=int(token[2]) if token.size()>2 and not str(token[2]).is_empty() else 1; return
			33:
				if hint: _hint_opacity=int(token[1]); back_opacity=int(token[1])
				else: back_opacity=int(token[1])
				return
			24:
				painted.append({"kind":"icon","name":str(token[1]),"style":style.duplicate(),"token_index":cursor-1}); return
			22: painted.append({"kind":"fill","width":int(token[1]),"style":style.duplicate(),"token_index":cursor-1}); return
			2:
				var owner=_state_owner.get_ref(); var text=str(owner.custom_data.currency())+str(preload("RuntimeData.gd").system().get("words",{}).get("gold",""))
				painted.append({"kind":"glyph","text":text,"style":style.duplicate(),"token_index":cursor-1})
			6:
				painted.append({"kind":"page","style":style.duplicate(),"token_index":cursor-1})
				pageon=maxf(0,float(page_targets.get(cursor-1,0))-page_scroll); return
			7: interpreter_waiting=false
			14: state=1
			15: state=0
			16: state=2; return
			17: state=-1; return
			18: pass # Row merge handled by the layout; no painted control glyph.
			19: pass # Source mark has an empty body.
		if state!=1: break
	waiting+=speed

func plain_text() -> String:
	var result=""
	for value in painted:
		if value.kind=="glyph": result+=value.text
	return result

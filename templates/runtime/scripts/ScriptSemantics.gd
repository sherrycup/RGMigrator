extends RefCounted
const Decimal=preload("DecimalInteger.gd")
const CustomData=preload("CustomDataState.gd")
const RegexValues=preload("RubyRegexValues.gd")
const Graph=preload("SaveGraph.gd")
const FlashValues=preload("FlashValueExtensions.gd")
static var _programs: Dictionary={}

static func program(path: String) -> GDScript:
	if not FileAccess.file_exists(path): return null
	var digest=FileAccess.get_sha256(path)
	var cached: Dictionary=_programs.get(path,{})
	if not cached.is_empty() and cached.sha256==digest: return cached.script
	var script: GDScript=load(path)
	if script==null: return null
	if not cached.is_empty() or script.source_code.sha256_text()!=digest:
		script.source_code=FileAccess.get_file_as_string(path)
		if script.reload(true)!=OK: return null
	if not script.can_instantiate(): return null
	_programs[path]={"sha256":digest,"script":script}
	return script
## Helpers for generated GDScript. This is not an AST/bytecode interpreter.
var state: Object
var classes: Dictionary = {"Object":{"parent":"","kind":"class"}}
var methods: Dictionary = {}
var globals: Dictionary = {}
var constants: Dictionary = {}
var failure: Dictionary = {}
var origin: Dictionary = {}
var span: Dictionary = {}
var execution_context: Dictionary = {}
var definition_loader: Callable
var loaded_units: Dictionary = {}
var loading_units: Dictionary = {}
var _pending_wait := 0.0
var _pending: Dictionary = {}
var _pending_gold: Variant = null
var _snapshot: Dictionary = {}
var _custom: RefCounted
var _variables: Dictionary={}
var _steps := 0
var _depth := 0
var _regex_data: Variant=null
var _regex_scope_depth=0
var _common_call=0
var _method_programs: Dictionary={}
var _query_mode=false
var _query_guard: Dictionary={}
var _query_retry=false
var _direct=false
var _active=false

func _init(runtime_state: Object) -> void:
	state = runtime_state

static func truth(value: Variant) -> bool:
	return value != null and (not value is bool or value)

static func text(value: Variant) -> String:
	if value is Dictionary and value.has("__decimal_integer"): return str(value.__decimal_integer)
	if value == null: return ""
	if value is bool: return "true" if value else "false"
	return str(value)

static func words(value: String) -> Array:
	var matcher := RegEx.new(); matcher.compile("\\S+")
	var result: Array = []
	for match_value in matcher.search_all(value): result.append(match_value.get_string())
	return result

func stringify(value: Variant, depth: int = 0) -> Variant:
	if value is Dictionary and value.has("__decimal_integer"): return str(value.__decimal_integer)
	if depth>96: return fail("递归字符串转换超过96层。")
	if value is Array:
		var result := ""
		for item in value:
			var converted: Variant = stringify(item,depth+1)
			if not failure.is_empty(): return null
			result += converted
		return result
	if value is Dictionary:
		if value.has("__ruby_type"): return value.__ruby_type
		if value.has("__ruby_class") and not _lookup(value.__ruby_class,"to_s",false).is_empty():
			var result: Variant = invoke(value,"to_s",[],value.__ruby_class)
			return result if result is String else fail("to_s必须返回字符串。")
		return fail("Hash/对象默认字符串表示尚未适配。")
	return text(value)

func hash_pairs(pairs: Array) -> Dictionary:
	var result := {"__ruby_hash":{},"__keys":{}}
	for pair in pairs:
		var key := _hash_key(pair[0])
		if not failure.is_empty(): break
		result.__ruby_hash[key] = pair[1]; result.__keys[key] = pair[0]
	return result

func begin(source_origin: Dictionary) -> bool:
	if _has_custom_data() and state.custom_data.manifest.get("profile")=="flash": return _begin_direct(source_origin)
	if not _snapshot.is_empty(): return fail("不允许嵌套脚本事务。") != null
	_query_mode=false; _query_guard={}; _query_retry=false
	origin = source_origin; failure = {}; span = {}; _pending = {}; _steps = 0
	_method_programs.clear()
	_pending_gold = null
	var originals={"variables":state.variables,"globals":globals,"constants":constants,"fields":execution_context.get("fields",{}),"custom":state.custom_data.values if _has_custom_data() else {},"temp":state.flash_temp_fields if _has_custom_data() else {}}
	originals.field_roots=[originals.fields]
	if state.has_method("game"):
		var game: Node=state.game()
		if game!=null and game.has_method("script_field_roots"): originals.field_roots.append_array(game.script_field_roots())
	var draft: Dictionary=copy_value(originals,[])
	_custom=state.get("custom_data").fork(false) if _has_custom_data() else null
	_variables=draft.variables; globals=draft.globals; constants=draft.constants
	if execution_context.has("fields"): execution_context.fields=draft.fields
	if _custom!=null:
		_custom.values=draft.custom; _custom.temp_fields=draft.temp
		_custom.script_variables=_variables; _custom.script_switches=_pending; _custom.execution_context=execution_context
	_pending_wait=0.0; _common_call=0
	if execution_context.has("fields"): _regex_data=execution_context.fields.get("__rgm_regex")
	_snapshot={"classes":classes.duplicate(true),"methods":methods.duplicate(true),"globals":originals.globals,"constants":originals.constants,"loaded":loaded_units.duplicate(),"fields":copy_value(originals.fields,[]),"regex":_regex_data,"regex_depth":_regex_scope_depth}
	_snapshot.field_roots=originals.field_roots; _snapshot.field_copies=draft.field_roots
	if not failure.is_empty(): _snapshot = {}; return false
	return true

func _begin_direct(source_origin: Dictionary) -> bool:
	if state.has_method("fatal_script_error") and not state._fatal_script_message.is_empty():
		failure={"ok":false,"message":state._fatal_script_message,"origin":source_origin}; return false
	if _active: return fail("不允许嵌套脚本执行。")!=null
	_direct=true; _active=true; _query_mode=false; _query_guard={}; _query_retry=false
	origin=source_origin; failure={}; span={}; _pending={}; _pending_gold=null; _steps=0
	_method_programs.clear(); _pending_wait=0; _common_call=0
	_variables=state.variables
	_custom=state.custom_data.live_view(); _custom.execution_context=execution_context
	_custom.script_switches=_pending
	if execution_context.has("fields"): _regex_data=execution_context.fields.get("__rgm_regex")
	return true

func _flush_direct_effects() -> void:
	if not _direct or _custom==null: return
	if not _custom.character_edits.is_empty():
		preload("FlashCharacterBridge.gd").commit(_custom.character_edits); _custom.character_edits.clear()
	if not _custom.screen_edits.is_empty() and state.flash_effects!=null:
		state.flash_effects.install(_custom.screen_edits); _custom.screen_edits.clear()
	if not _custom.keyboard_draft.is_empty() and state.flash_keyboard!=null:
		state.flash_keyboard.install(_custom.keyboard_draft); _custom.keyboard_draft.clear()
	for key in _custom.pending_effects:
		if key=="common_event": state.common_event_reservation=_custom.pending_effects[key]
		else: state.flash_temp_fields[key]=_custom.pending_effects[key]
	_custom.pending_effects.clear()
	for key in _pending:
		var parts: PackedStringArray=str(key).split(":")
		if parts[0]=="variable": state.variables[parts[1]]=_pending[key]
		elif parts[0]=="self": state.self_switches[str(key).trim_prefix("self:")]=_pending[key]
		else: state.switches[parts[1]]=_pending[key]
		state.event_state_changed.emit(parts[0],str(key).trim_prefix(parts[0]+":"))
	_pending.clear()

func _finish_direct(value: Variant) -> Dictionary:
	_flush_direct_effects()
	if failure.is_empty() and state.has_method("fatal_script_error") and not state._fatal_script_message.is_empty(): fail(state._fatal_script_message)
	if failure.is_empty() and not _custom.failure.is_empty(): fail(_custom.failure)
	if _custom.preference_changed:
		var stored=preload("FlashFileStore.gd").write(state.flash_preferences.storage_path(),"preferences",_custom.preference_data)
		if not stored.ok: fail(stored.message)
	var fields: Dictionary=execution_context.get("fields",{})
	var result={"ok":true,"value":value,"writes":0,"origin":origin,"wait_seconds":_pending_wait,"script_fields":fields,"snapshot_requests":_custom.snapshot_requests,"common_event_id":_common_call,"history_request":_custom.history_request,"movie_request":_custom.movie_request,"flash_effect_request":_custom.last_screen_request,"flash_scene_request":_custom.scene_request} if failure.is_empty() else failure
	_active=false; _direct=false; _custom=null; _pending.clear()
	if state.has_signal("state_changed"): state.emit_signal("state_changed")
	if not result.ok and state.has_method("fatal_script_error"):
		state.fatal_script_error("%s / 源码 %s / L%d:C%d" % [result.message,JSON.stringify(origin),span.get("line",0),span.get("column",0)])
	return result

func begin_query(source_origin: Dictionary,plan: Dictionary) -> bool:
	if not _snapshot.is_empty(): return fail("不允许嵌套脚本事务。")!=null
	origin=source_origin; failure={}; span={}; _pending={}; _pending_gold=null; _steps=0
	_method_programs.clear(); _query_mode=true; _query_guard=plan.get("span",{}); _query_retry=false
	_pending_wait=0; _common_call=0
	if execution_context.has("fields"): _regex_data=execution_context.fields.get("__rgm_regex")
	_snapshot={"classes":classes,"fields":execution_context.get("fields",{}),"regex":_regex_data,"regex_depth":_regex_scope_depth}
	classes=classes.duplicate()
	if execution_context.has("fields"): execution_context.fields=execution_context.fields.duplicate()
	_custom=CustomData.new(state,false); _custom.manifest=state.custom_data.manifest; _custom.values=state.custom_data.values
	_custom._gameplay=preload("FlashGameplay.gd").new(_custom,state.custom_data.gameplay())
	_custom.temp_fields=state.flash_temp_fields; _variables=state.variables
	_custom.script_variables=_variables; _custom.execution_context=execution_context
	return true

func finish_query(value: Variant) -> Dictionary:
	if failure.is_empty() and not _custom.failure.is_empty(): fail(_custom.failure)
	if failure.is_empty() and (typeof(value)>TYPE_STRING or value is float and not is_finite(value)): _retry_query()
	var fields: Dictionary=_snapshot.fields
	if failure.is_empty():
		if execution_context.has("fields"): fields.clear(); fields.merge(execution_context.fields)
	else:
		classes=_snapshot.classes; _regex_data=_snapshot.regex; _regex_scope_depth=_snapshot.regex_depth
	if execution_context.has("fields"): execution_context.fields=fields
	var result={"ok":true,"value":value,"writes":0,"origin":origin,"wait_seconds":0.0,"script_fields":fields,"snapshot_requests":[],"common_event_id":0,"history_request":"","movie_request":{},"flash_effect_request":0,"flash_scene_request":{}} if failure.is_empty() else failure.duplicate()
	if _query_retry: result.retry_full_transaction=true
	_snapshot={}; _custom=null; _query_mode=false; _query_guard={}; _query_retry=false
	return result

func _retry_query() -> Variant:
	_query_retry=true
	return fail("该表达式需要完整脚本事务。")

func _query_call(receiver: Variant,name: String,args: Array) -> bool:
	if not receiver is Dictionary: return false
	if receiver.get("__custom_ref")=="map": return name=="check_event" and args.size() in [2,3]
	if not args.is_empty(): return false
	if receiver.get("__event_context",false): return name=="_this"
	match receiver.get("__custom_ref",""):
		"temp": return not name.ends_with("=") and name not in ["attr_addition_clear","puts_start","puts_end"]
		"map_event": return name in ["event","x","y"]
		"event_definition": return name=="name"
	return false

func finish(value: Variant) -> Dictionary:
	if _direct: return _finish_direct(value)
	if failure.is_empty():
		var reason=_data_reason(_variables)
		if not reason.is_empty(): fail(reason)
		for id in _variables:
			if not CustomData.same_value(_variables[id],state.variables.get(id,0)): _pending["variable:"+str(id)]=_variables[id]
	if failure.is_empty() and _custom!=null and not _custom.failure.is_empty(): fail(_custom.failure)
	if failure.is_empty() and _custom!=null:
		var reason=_data_reason(_custom.values)
		if not reason.is_empty(): fail(reason)
		var temp_reason=_data_reason(_custom.temp_fields)
		if not temp_reason.is_empty(): fail("临时字段不能提交："+temp_reason)
		if _custom.values.has("blastics"):
			var blastic_reason=preload("FlashBlastic.gd").validate(_custom,_custom.values.blastics)
			if not blastic_reason.is_empty(): fail(blastic_reason)
			var tile_reason=preload("FlashMapBridge.gd").validate_saved_tiles(_custom.values.system.get("map_data",{}))
			if not tile_reason.is_empty(): fail(tile_reason)
		var effect_reason=preload("FlashCharacterBridge.gd").validate(_custom.character_edits)
		if not effect_reason.is_empty(): fail(effect_reason)
		if not _custom.screen_edits.is_empty():
			if not _custom.scene_request.is_empty(): fail("同一脚本片段同时包含剧情演出和页面切换，请拆为独立事件指令。")
			var screen_reason=state.flash_effects.validate(_custom.screen_edits)
			if not screen_reason.is_empty(): fail(screen_reason)
	if failure.is_empty() and _custom!=null and not _custom.preference_data.is_empty():
		var preferences: RefCounted=state.flash_preferences
		var preference_reason=preload("FlashPreferences.gd").validate(_custom.preference_data)
		if not preference_reason.is_empty(): fail(preference_reason)
		elif not CustomData.same_value(_custom.preference_data,{"vars":preferences.vars,"music_lock":preferences.music_lock}):
			var stored=preload("FlashFileStore.gd").write(preferences.storage_path(),"preferences",_custom.preference_data)
			if not stored.ok: fail(stored.message)
	if not failure.is_empty():
		classes = _snapshot.classes; methods = _snapshot.methods; globals = _snapshot.globals; constants = _snapshot.constants
		loaded_units = _snapshot.loaded
		_regex_data=_snapshot.regex; _regex_scope_depth=_snapshot.regex_depth
		if execution_context.has("fields"): execution_context.fields.clear(); execution_context.fields.merge(_snapshot.fields)
		_snapshot = {}; _pending.clear(); _pending_gold = null; _custom=null; return failure
	var pairs=[]
	for i in _snapshot.field_roots.size():
		var original: Dictionary=_snapshot.field_roots[i]; var copied: Dictionary=_snapshot.field_copies[i]
		if pairs.any(func(pair):return is_same(pair[0],copied)): continue
		original.clear(); original.merge(copied); pairs.append([copied,original])
	var roots={"variables":_variables,"globals":globals,"constants":constants,"fields":execution_context.get("fields",{}),"value":value,"pending":_pending}
	if _custom!=null: roots.custom=_custom.values; roots.temp=_custom.temp_fields
	roots=Graph.rebind(roots,pairs)
	_variables=roots.variables; globals=roots.globals; constants=roots.constants; _pending=roots.pending
	if _custom!=null: _custom.values=roots.custom; _custom.temp_fields=roots.temp; _custom.script_variables=_variables
	value=roots.value
	if execution_context.has("fields"): execution_context.fields=roots.fields
	if state.has_method("commit_script_data"): state.commit_script_data(_pending,_custom)
	else:
		for key in _pending:
			var parts: PackedStringArray = key.split(":")
			if parts[0] == "variable": state.set_event_variable(int(parts[1]),_pending[key])
			else: state.set_event_switch(int(parts[1]),_pending[key])
	var history_request: String=_custom.history_request if _custom!=null else ""
	var movie_request: Dictionary=_custom.movie_request if _custom!=null else {}
	var snapshot_requests: Array=_custom.snapshot_requests if _custom!=null else []
	var screen_request: int=_custom.last_screen_request if _custom!=null else 0
	var scene_request: Dictionary=_custom.scene_request.duplicate(true) if _custom!=null else {}
	var script_fields: Dictionary=execution_context.get("fields",{})
	_custom=null
	if _pending_gold!=null and state.gold!=_pending_gold:
		state.gold = _pending_gold
		if state.has_signal("state_changed"): state.emit_signal("state_changed")
	var writes := _pending.size(); _pending.clear(); _snapshot = {}
	if _pending_gold!=null: writes += 1
	_pending_gold = null
	return {"ok":true,"value":value,"writes":writes,"origin":origin,"wait_seconds":_pending_wait,"script_fields":script_fields,"snapshot_requests":snapshot_requests,"common_event_id":_common_call,"history_request":history_request,"movie_request":movie_request,"flash_effect_request":screen_request,"flash_scene_request":scene_request}

func root_receiver() -> Variant:
	if execution_context.is_empty(): return object_ref("Object")
	var name := "Game_Character" if execution_context.get("kind")=="route" else "Interpreter"
	# This facade exposes only verified native context, not a fabricated RGSS class.
	if not classes.has(name): classes[name] = {"parent":"Object","kind":"class"}
	return {"__ruby_class":name,"fields":execution_context.get("fields",{}),"__event_context":true}

func ensure_definition(name: String, owner: String = "", singleton: bool = false) -> void:
	if _query_mode: _retry_query(); return
	if definition_loader.is_valid() and failure.is_empty(): definition_loader.call(name,owner,singleton)

func tick(location: Dictionary) -> bool:
	if _direct and state.has_method("fatal_script_error") and not state._fatal_script_message.is_empty(): return false
	span = location; _steps += 1
	if _query_mode and not _query_guard.is_empty():
		for key in ["line","column","end_line","end_column"]:
			if int(location.get(key,0))!=int(_query_guard.get(key,0)): _retry_query(); return false
	if _steps > 100000: fail("脚本执行超过100000步；未提交状态。")
	return failure.is_empty()

func fail(message: String) -> Variant:
	if failure.is_empty(): failure = {"ok":false,"message":message,"origin":origin,"span":span}
	return null

func declare_type(name: String, parent: String, kind: String) -> void:
	if _query_mode: _retry_query(); return
	if not parent.is_empty() and not classes.has(parent): ensure_definition(parent)
	if not parent.is_empty() and not classes.has(parent) and name.contains("::"):
		var ruby_namespace: String = name.left(name.rfind("::"))+"::"
		if classes.has(ruby_namespace+parent): parent = ruby_namespace+parent
	if classes.has(name):
		if classes[name].kind != kind or not parent.is_empty() and classes[name].parent != parent: fail("类重开类型/父类不一致："+name)
		return
	if not parent.is_empty() and not classes.has(parent): fail("父类尚未加载："+parent); return
	classes[name] = {"parent":parent if not parent.is_empty() else "Object","kind":kind}

func define_method(owner: String, name: String, singleton: bool, path: String, function: String, source: Dictionary) -> void:
	if _query_mode: _retry_query(); return
	methods[_key(owner,name,singleton)] = {"owner":owner,"path":path,"function":function,"origin":source,"version":path+":"+function}

func alias_method(owner: String, name: String, target: String, singleton: bool = false) -> void:
	if _query_mode: _retry_query(); return
	var implementation := _lookup(owner,target,singleton)
	if implementation.is_empty(): fail("alias目标尚未加载：%s#%s" % [owner,target]); return
	methods[_key(owner,name,singleton)] = implementation.duplicate(true)

func copy_module_function(owner: String,name: String) -> void:
	if _query_mode: _retry_query(); return
	var implementation := _lookup(owner,name,false)
	if implementation.is_empty(): fail("module_function目标尚未定义："+owner+"#"+name); return
	methods[_key(owner,name,true)]=implementation.duplicate(true)

func type_ref(name: String) -> Variant:
	if _custom!=null:
		var ref: Variant=_custom.named(name)
		if ref!=null: return ref
	if not classes.has(name): ensure_definition(name)
	if not classes.has(name): return fail("类/模块尚未加载："+name)
	return {"__ruby_type":name}

func include_module(owner: String, module: Variant, singleton: bool = false) -> void:
	if _query_mode: _retry_query(); return
	if not module is Dictionary or not module.has("__ruby_type") or classes.get(module.__ruby_type,{}).get("kind")!="module": fail("include/extend要求已加载模块。"); return
	var key := "extensions" if singleton else "includes"
	if not classes.has(owner): fail("mixin缺少所属类。"); return
	if not classes[owner].has(key): classes[owner][key] = []
	classes[owner][key].push_front(module.__ruby_type)

func object_ref(name: String) -> Variant:
	if not classes.has(name): return fail("类尚未加载："+name)
	return {"__ruby_class":name,"fields":{}}

func read_name(name: String, locals: Dictionary, receiver: Variant, owner: String) -> Variant:
	if name.length()>1 and name[0]=="$" and name.substr(1).is_valid_int() and int(name.substr(1))>0:
		var group=int(name.substr(1)); return _regex_data.groups[group] if _regex_data!=null and group<_regex_data.groups.size() else null
	if name in ["$~","$&","$`","$'","$+"]:
		if _regex_data==null: return null
		if name=="$~": return _regex_data
		if name=="$&": return _regex_data.groups[0]
		if name=="$`": return _regex_data.pre
		if name=="$'": return _regex_data.post
		for i in range(_regex_data.groups.size()-1,0,-1):
			if _regex_data.groups[i]!=null: return _regex_data.groups[i]
		return null
	if _custom!=null:
		var ref: Variant=_custom.named(name)
		if ref!=null: return ref
	if name in ["$game_variables","$game_switches"]: return {"__state_table":"variable" if name == "$game_variables" else "switch"}
	if name=="$game_self_switches": return {"__state_table":"self"}
	if name == "$game_party": return {"__service":"party"}
	if name.begins_with("$"):
		if _custom!=null and name in _custom.manifest.get("deferred_globals",[]): return fail("该源全局数据初始化尚未迁移："+name)
		return globals.get(name)
	if name.begins_with("@@"): return fail("类变量共享语义尚未接入："+name)
	if name.begins_with("@"):
		if receiver is Dictionary and receiver.get("__event_context",false):
			match name:
				"@event_id": return execution_context.get("event_id",0)
				"@map_id": return execution_context.get("map_id",0)
				"@index": return execution_context.get("index",0)
				"@wait_count": return int(round(_pending_wait*execution_context.get("policy",{}).get("frame_rate",40)))
				"@x", "@y", "@direction":
					var character: Object = execution_context.get("character")
					if not is_instance_valid(character): return fail("脚本缺少有效人物上下文："+name)
					return character.direction if name=="@direction" else character.tile_position.x if name=="@x" else character.tile_position.y
			if execution_context.get("kind")=="route" or name in ["@list","@parameters","@branch","@main","@depth","@child_interpreter","@message_waiting","@button_input_variable_id","@move_route_waiting"]: return fail("该原生实例字段读取尚未适配："+name)
		if receiver is Dictionary and receiver.has("fields"): return receiver.fields.get(name)
		return fail("缺少实例上下文："+name)
	if locals.has(name): return locals[name]
	if constants.has(owner+"::"+name): return constants[owner+"::"+name]
	if constants.has(name): return constants[name]
	if not name.is_empty() and name[0]==name[0].to_upper() and name[0]!=name[0].to_lower(): ensure_definition(owner+"::"+name if owner!="Object" else name)
	if constants.has(owner+"::"+name): return constants[owner+"::"+name]
	if constants.has(name): return constants[name]
	if classes.has(owner+"::"+name): return type_ref(owner+"::"+name)
	if classes.has(name): return type_ref(name)
	return invoke(receiver,name,[],owner)

func write_name(name: String, value: Variant, locals: Dictionary, receiver: Variant, owner: String) -> Variant:
	if _query_mode: return _retry_query()
	if _flash_profile() and name=="$scene":
		if not value is Dictionary or value.get("__custom_ref")!="flash_scene": return fail("$scene需要已注册的闪翼独立页面。")
		return preload("FlashSceneRegistry.gd").stage(_custom,value)
	if _flash_profile() and name=="$Key":
		if not value is int or value<0 or value>255: return fail("$Key需要0—255的原键位编号。")
		if _custom.keyboard_draft.is_empty(): _custom.keyboard_draft=state.flash_keyboard.snapshot()
		_custom.keyboard_draft.key=value; return value
	if name=="$~":
		if value!=null and not (value is Dictionary and value.has("__ruby_match")): return fail("$~必须为MatchData或nil。")
		_regex_data=value
		if _regex_scope_depth==0 and execution_context.has("fields"): execution_context.fields["__rgm_regex"]=value
		return value
	if name in ["$game_variables","$game_switches","$game_party"]: return fail("不能替换共享游戏服务："+name)
	if name.begins_with("$"): globals[name] = value
	elif name.begins_with("@@"): return fail("类变量共享语义尚未接入。")
	elif name.begins_with("@"):
		if receiver is Dictionary and receiver.get("__event_context",false):
			if name=="@wait_count":
				if not value is int or value<0 or value>1000000000: return fail("脚本等待帧数须为0..1000000000整数。")
				_pending_wait = float(value)/execution_context.get("policy",{}).get("frame_rate",40)
				return value
			if name in ["@event_id","@map_id","@index","@x","@y","@direction"]: return fail("该原生现场字段写入尚未适配："+name)
			if execution_context.get("kind")=="route": return fail("人物自定义实例字段的保存与生命周期将在后续版本接入："+name)
		if not receiver is Dictionary or not receiver.has("fields"): return fail("缺少实例上下文。")
		receiver.fields[name] = value
	elif not name.is_empty() and name[0] == name[0].to_upper() and name[0] != name[0].to_lower(): constants[owner+"::"+name if owner != "Object" else name] = value
	else: locals[name] = value
	return value

func index_get(receiver: Variant, index: Variant) -> Variant:
	if receiver is Dictionary and receiver.has("__ruby_match"):
		return index_get(receiver.groups,index)
	if receiver is String and index is Dictionary and index.has("__ruby_regex"):
		var data: Variant=regex_match(index.__ruby_regex,receiver)
		return data.groups[0] if data!=null else null
	if receiver is Dictionary and receiver.has("__custom_ref"):
		var value: Variant=_custom.index_get(receiver,index)
		return fail(_custom.failure) if not _custom.failure.is_empty() else value
	if receiver is Dictionary and receiver.has("__ruby_range"): return fail("Range不支持数组下标访问。")
	if receiver is Dictionary and receiver.has("__ruby_class"): return invoke(receiver,"[]",[index],receiver.__ruby_class)
	if receiver is Dictionary and receiver.has("__ruby_hash"): return receiver.__ruby_hash.get(_hash_key(index))
	if receiver is Dictionary and receiver.has("__state_table"):
		if receiver.__state_table=="self":
			var key=_self_switch_key(index)
			return _pending.get("self:"+key,state.self_switches.get(key,false)) if failure.is_empty() else null
		if not _valid_id(index): return fail("开关/变量编号必须为正整数。")
		var target: String = receiver.__state_table; var key := target+":"+str(index)
		return _variables.get(str(index),0) if target=="variable" else _pending.get(key,state.switches.get(str(index),false))
	if receiver is Dictionary: return receiver.get(index,receiver.get(str(index)))
	if receiver is Array or receiver is String:
		if receiver is String:
			if not index is int: return fail("字符串字节索引必须为整数。")
			var bytes=receiver.to_utf8_buffer(); var offset: int=index if index>=0 else bytes.size()+index
			return int(bytes[offset]) if offset>=0 and offset<bytes.size() else null
		if receiver is Array and index is Array and _flash_profile():
			var selected: Array=[]
			for slot in index:
				if not slot is int: return fail("数组子列索引必须为整数。")
				selected.append(index_get(receiver,slot))
			return selected
		if not index is int: return fail("集合下标必须为整数。")
		var offset: int = index if index >= 0 else receiver.size()+index if receiver is Array else receiver.length()+index
		var size: int = receiver.size() if receiver is Array else receiver.length()
		return receiver[offset] if offset >= 0 and offset < size else null
	return fail("对象不支持下标读取。")

func indexes_get(receiver: Variant,indexes: Array) -> Variant:
	if receiver is Dictionary and receiver.get("__custom_ref")=="map_tiles" and indexes.size()==3:
		if not indexes.all(func(value):return _custom._integer(value)): return fail("图块坐标必须为整数。")
		var bridge: GDScript=preload("FlashMapBridge.gd")
		var map: Node=bridge.current_map(_custom)
		if map==null: return fail(_custom.failure)
		var value: Variant=bridge.read_tile(_custom,map,int(indexes[0]),int(indexes[1]),int(indexes[2]))
		return value if _custom.failure.is_empty() else fail(_custom.failure)
	if receiver is Dictionary and receiver.get("__custom_ref")=="equipment" and indexes.size()==2:
		var value: Variant=preload("FlashObjectCatalog.gd").equipment_ref(_custom,indexes[0],indexes[1])
		return value if _custom.failure.is_empty() else fail(_custom.failure)
	if indexes.size()==1: return index_get(receiver,indexes[0])
	if indexes.size()==2 and receiver is String and indexes[0] is Dictionary and indexes[0].has("__ruby_regex") and indexes[1] is int:
		var data: Variant=regex_match(indexes[0].__ruby_regex,receiver)
		return index_get(data.groups,indexes[1]) if data!=null else null
	if indexes.size()==2 and (receiver is Array or receiver is String) and indexes[0] is int and indexes[1] is int:
		var data: Variant=receiver if receiver is Array else receiver.to_utf8_buffer()
		var start: int=indexes[0] if indexes[0]>=0 else data.size()+indexes[0]
		if start<0 or start>data.size() or indexes[1]<0: return null
		var sliced: Variant=data.slice(start,mini(start+indexes[1],data.size()))
		if receiver is Array: return sliced
		var decoded: String=sliced.get_string_from_utf8()
		if decoded.to_utf8_buffer()!=sliced: return fail("字节切片不是完整UTF-8字符；无法无损转为Godot字符串。")
		return decoded
	if receiver is Dictionary and receiver.has("__ruby_class"): return invoke(receiver,"[]",indexes,receiver.__ruby_class)
	if receiver is Dictionary and _flash_profile():
		var values: Array=[]
		for key in indexes: values.append(index_get(receiver,key))
		return values
	return fail("该多参数下标接口尚未适配。")

func index_set(receiver: Variant, index: Variant, value: Variant) -> Variant:
	if _query_mode: return _retry_query()
	if receiver is Dictionary and (receiver.has("__ruby_regex") or receiver.has("__ruby_match")): return fail("RegExp/MatchData不支持下标写入。")
	if receiver is Dictionary and receiver.get("__custom_ref")=="flash_global_variables": return _custom.invoke(receiver,"[]=",[index,value])
	if receiver is Dictionary and receiver.has("__custom_ref"): return fail("不能替换项目数据库或楼层对象；请修改具体字段或使用数据服务。")
	if receiver is Dictionary and receiver.has("__ruby_range"): return fail("Range不支持数组下标写入。")
	if receiver is Dictionary and receiver.has("__ruby_class"):
		invoke(receiver,"[]=",[index,value],receiver.__ruby_class); return value
	if receiver is Dictionary and receiver.has("__ruby_hash"):
		var key := _hash_key(index)
		if not failure.is_empty(): return null
		receiver.__ruby_hash[key] = value; receiver.__keys[key] = index; return value
	if receiver is Dictionary and receiver.has("__state_table"):
		if receiver.__state_table=="self":
			var key=_self_switch_key(index)
			if not failure.is_empty(): return null
			if not value is bool: return fail("独立开关必须为布尔值。")
			_pending["self:"+key]=value
			if _direct: _flush_direct_effects()
			return value
		if not _valid_id(index): return fail("开关/变量编号必须为正整数。")
		var target: String = receiver.__state_table
		if target=="variable":
			var reason="" if _direct else CustomData.plain_reason(value)
			if not reason.is_empty(): return fail(reason)
			_variables[str(index)]=value
		if target=="switch" and not value is bool: return fail("原生开关必须为布尔值。")
		_pending[target+":"+str(index)] = value
		if _direct: _flush_direct_effects()
		return value
	if receiver is Dictionary: receiver[index] = value; return value
	if receiver is Array:
		if not index is int: return fail("数组下标必须为整数。")
		var offset: int = index if index >= 0 else receiver.size()+index
		if offset < 0 or offset > 100000: return fail("数组写入下标超出范围。")
		while receiver.size() <= offset: receiver.append(null)
		receiver[offset] = value; return value
	return fail("对象不支持下标写入。")

func unary(operator: String, value: Variant) -> Variant:
	if operator in ["!","not"]: return not truth(value)
	if operator=="-" and value is Array and _flash_profile():
		var vector_result=FlashValues.vector(value,-1,"*")
		return vector_result.value if vector_result.ok else fail(vector_result.message)
	if value is Dictionary and value.has("__decimal_integer"):
		return value if operator=="+" else big_integer(str(Decimal.negate(value.__decimal_integer))) if operator=="-" else fail("该大整数一元运算尚未接入。")
	if not _number(value): return fail("一元运算需要数值。")
	match operator:
		"+": return value
		"-": return -value
		"~":
			if value is int: return ~value
	return fail("不支持的一元运算。")

func binary(operator: String, left: Variant, right: Variant) -> Variant:
	if _query_mode and (typeof(left)>TYPE_STRING or typeof(right)>TYPE_STRING): return _retry_query()
	if _flash_profile() and left is Array and operator in ["*","-"]:
		var vector_result=FlashValues.vector(left,right,operator)
		return vector_result.value if vector_result.ok else fail(vector_result.message)
	if _flash_profile() and _number(left) and right is Array and operator=="===":
		return right.any(func(value):return _equal(left,value))
	if operator in ["=~","!~"] or operator=="===" and left is Dictionary and left.has("__ruby_regex"):
		var descriptor: Variant=left.__ruby_regex if left is Dictionary and left.has("__ruby_regex") else right.__ruby_regex if right is Dictionary and right.has("__ruby_regex") else null
		var string_value: Variant=right if left is Dictionary and left.has("__ruby_regex") else left
		if descriptor==null or not string_value is String: return fail("正则匹配要求一个RegExp和一个字符串。")
		var data: Variant=regex_match(descriptor,string_value)
		return data==null if operator=="!~" else data!=null if operator=="===" else data.starts[0] if data!=null else null
	if operator=="===" and left is Dictionary and left.has("__ruby_range"):
		var bounds: Dictionary=left.__ruby_range
		return _number(right) and right>=bounds.first and (right<bounds.last if bounds.exclusive else right<=bounds.last)
	if left is Dictionary and left.has("__decimal_integer") or right is Dictionary and right.has("__decimal_integer"):
		var a: Variant=left.__decimal_integer if left is Dictionary and left.has("__decimal_integer") else left
		var b: Variant=right.__decimal_integer if right is Dictionary and right.has("__decimal_integer") else right
		if Decimal.normalize(a).is_empty() or Decimal.normalize(b).is_empty(): return fail("大整数运算要求整数参数。")
		var order=Decimal.compare(a,b)
		match operator:
			"+": return big_integer(str(Decimal.add(a,b)))
			"-": return big_integer(str(Decimal.add(a,Decimal.negate(b))))
			"==","===": return order==0
			"!=": return order!=0
			"<": return order<0
			"<=": return order<=0
			">": return order>0
			">=": return order>=0
		return fail("该大整数运算尚未接入："+operator)
	if left is Dictionary and left.has("__ruby_class") and not _lookup(left.__ruby_class,operator,false).is_empty(): return invoke(left,operator,[right],left.__ruby_class)
	if operator in ["==","!=","==="]:
		if operator=="===" and left is Dictionary and left.has("__ruby_type"): return fail("类的case相等语义尚未适配。")
		var equal := _equal(left,right)
		return not equal if operator=="!=" else equal
	if operator == "+" and left is String and right is String: return left+right
	if operator == "+" and left is Array and right is Array: return left+right
	if operator=="<<" and left is Array: left.append(right); return left
	if operator=="*" and right is int and right>=0 and (left is Array or left is String):
		var size: int = left.size() if left is Array else left.length()
		if size*right>100000: return fail("集合重复结果过大。")
		if left is String: return left.repeat(right)
		var repeated: Array = []
		for ignored in right: repeated.append_array(left)
		return repeated
	if not _number(left) or not _number(right): return fail("运算符 %s 的参数类型尚未适配。" % operator)
	if operator in ["/","%"] and right==0: return fail("除数不能为0。")
	if operator=="*" and abs(float(left)*float(right))>Decimal.SAFE: return fail("乘积超出精确支持范围。")
	var result: Variant
	match operator:
		"+": result = left+right
		"-": result = left-right
		"*": result = left*right
		"/": result = _integer_quotient(left,right) if left is int and right is int else float(left)/float(right)
		"%": result = left-_integer_quotient(left,right)*right if left is int and right is int else left-floor(float(left)/float(right))*right
		"**": result = pow(left,right); result = int(result) if left is int and right is int and right>=0 else result
		"<": return left<right
		">": return left>right
		"<=": return left<=right
		">=": return left>=right
		"<=>": return -1 if left<right else (1 if left>right else 0)
		_:
			if not left is int or not right is int: return fail("位运算需要整数。")
			if operator in ["<<",">>"] and (right<0 or right>30): return fail("移位范围超出支持范围。")
			match operator:
				"&": result = left & right
				"|": result = left | right
				"^": result = left ^ right
				"<<": result = left << right
				">>": result = left >> right
				_: return fail("尚未支持的运算符："+operator)
	if _number(result) and (not is_finite(float(result)) or abs(float(result))>Decimal.SAFE): return fail("数值结果超出当前精确支持范围。")
	return result

func sequence(first: Variant, last: Variant, exclusive: bool) -> Variant:
	if not first is int or not last is int or abs(last-first)>100000: return fail("仅支持有限整数范围。")
	return {"__ruby_range":{"first":first,"last":last,"exclusive":exclusive}}

func iterable(value: Variant) -> Array:
	if value is Array: return value
	if value is Dictionary:
		var result: Array = []
		if value.has("__ruby_range"):
			var bounds: Dictionary = value.__ruby_range
			return range(bounds.first,bounds.last if bounds.exclusive else bounds.last+1)
		if value.has("__ruby_hash"):
			for key in value.__ruby_hash: result.append([value.__keys[key],value.__ruby_hash[key]])
			return result
		for key in value: result.append([key,value[key]])
		return result
	fail("for迭代对象尚未适配。"); return []

func invoke(receiver: Variant, name: String, args: Array, owner: String = "Object") -> Variant:
	var result: Variant=_invoke(receiver,name,args,owner)
	if _direct: _flush_direct_effects()
	return result

func _invoke(receiver: Variant, name: String, args: Array, owner: String = "Object") -> Variant:
	if _query_mode and not _query_call(receiver,name,args): return _retry_query()
	if _flash_profile() and args.is_empty() and name=="__TITLE": return str(ProjectSettings.get_setting("application/config/name",""))
	if _flash_profile() and name in ["__API","__HWND"]: return fail("原窗口句柄/原生API由Godot的窗口、输入、图像和视频服务替换，不暴露进程地址："+name)
	if _flash_profile() and args.is_empty() and name=="puts_start": globals["$console_debug_time"]=Time.get_ticks_usec(); return null
	if _flash_profile() and args.is_empty() and name=="puts_end":
		print("cost time: ",(Time.get_ticks_usec()-int(globals.get("$console_debug_time",Time.get_ticks_usec())))/1000000.0); return null
	if _flash_profile() and name in ["run_ube","run_ubp","run_img"] and receiver is Dictionary and receiver.get("__event_context",false):
		if name=="run_img": return fail("原0330.run_img写入Game_Screen未定义的ub，缺少图片编号；请使用Game.unravel_picture(number,args)。")
		var id=-1 if name=="run_ubp" else int(execution_context.get("event_id",0))
		if id==0: return fail("run_ube需要有效的当前地图事件。")
		return load("res://runtime/scripts/FlashScreenEffects.gd").stage(_custom,"character_unravel",[id,args])
	if receiver is Array and name in ["max","min"] and args.is_empty():
		if receiver.is_empty(): return null
		var chosen: Variant=receiver[0]
		for value in receiver.slice(1):
			var comparison: Variant=binary(">" if name=="max" else "<",value,chosen)
			if not failure.is_empty(): return null
			if truth(comparison): chosen=value
		return chosen
	if name in ["p","puts"] and receiver is Dictionary and receiver.has("__ruby_class"):
		for argument in args: print(JSON.stringify(argument) if name=="p" else str(argument))
		return args[0] if name=="p" and args.size()==1 else null
	if not failure.is_empty(): return null
	if name == "nil?" and args.is_empty(): return receiver==null
	if _flash_profile() and name in ["is_a?","kind_of?"] and args.size()==1:
		if not args[0] is Dictionary: return fail("类型判断需要类对象。")
		var type_name: String=str(args[0].get("__ruby_type",args[0].get("database","")))
		if type_name=="Object": return true
		if receiver is Dictionary and receiver.get("__custom_ref")=="project_object": return _custom.invoke(receiver,name,args)
		if receiver is Dictionary and receiver.get("__custom_ref")=="floor_tree_entries": return type_name=="Hash"
		if receiver is Dictionary and receiver.get("__custom_ref")=="record": return type_name=="RPG::"+str({"Classes":"Class","Enemies":"Enemy","Items":"Item","Weapons":"Weapon","Armors":"Armor","Actors":"Actor","Skills":"Skill","States":"State"}.get(receiver.database,str(receiver.database).trim_suffix("s")))
		if receiver is Dictionary and receiver.get("__custom_ref") in ["actor","floor_enemy"]: return type_name in (["Game_Actor","Game_Battler"] if receiver.__custom_ref=="actor" else ["Game_Enemy","Game_Battler"])
		match type_name:
			"Array": return receiver is Array
			"Hash": return receiver is Dictionary and not receiver.has("__custom_ref") and not receiver.has("__ruby_class") and not receiver.has("__ruby_type") and not receiver.has("__decimal_integer") and not receiver.has("__ruby_range")
			"String": return receiver is String
			"Numeric": return _number(receiver) or receiver is Dictionary and receiver.has("__decimal_integer")
			"Float": return receiver is float
			"Integer": return receiver is int or receiver is Dictionary and receiver.has("__decimal_integer")
			"Fixnum": return receiver is int and receiver>=-1073741824 and receiver<=1073741823
			"Bignum": return receiver is int and (receiver < -1073741824 or receiver>1073741823) or receiver is Dictionary and receiver.has("__decimal_integer")
			"NilClass": return receiver==null
			"TrueClass": return receiver is bool and receiver
			"FalseClass": return receiver is bool and not receiver
		var actual: String=receiver.get("__ruby_class","") if receiver is Dictionary else ""
		var visited={}
		while not actual.is_empty() and not visited.has(actual):
			if actual==type_name: return true
			visited[actual]=true; actual=str(classes.get(actual,{}).get("parent",""))
		return false
	if _flash_profile() and name=="in?":
		for value in args:
			if _equal(receiver,value): return true
		return false
	if _flash_profile() and name=="to_param" and args.is_empty(): return "l" if receiver is int or receiver is Dictionary and receiver.has("__decimal_integer") else "v" if receiver==null else "p"
	if _flash_profile() and name=="random_element" and receiver is Array and args.is_empty(): return null if receiver.is_empty() else receiver[randi_range(0,receiver.size()-1)]
	if _flash_profile() and name=="old_val":
		if receiver is Array and args.size()==1 and args[0] is Array: return fail("原Array.old_val不接受编号数组。")
		if receiver is Dictionary and args.size()!=1: return fail("原Hash.old_val仅接受一个键。")
		return indexes_get(receiver,args)
	if _flash_profile() and name in ["plus","minus","prod"] and args.size()==1:
		var operator: String={"plus":"+","minus":"-","prod":"*"}[name]
		if receiver is Array:
			var vector_result=FlashValues.vector(receiver,args[0],operator)
			return vector_result.value if vector_result.ok else fail(vector_result.message)
		if _number(receiver) or receiver is Dictionary and receiver.has("__decimal_integer"): return binary(operator,receiver,args[0])
	if _flash_profile() and name=="bwise" and receiver is Array and args.size()==1 and args[0] is String:
		var vector_result=FlashValues.bwise(receiver,args[0])
		return vector_result.value if vector_result.ok else fail(vector_result.message)
	if _flash_profile() and name=="to_opc" and args.is_empty() and _number(receiver): return min(max(receiver,0),255)
	if receiver is Dictionary and receiver.get("__event_context",false) and name=="command_117" and args.is_empty():
		var parameters: Variant=receiver.fields.get("@parameters")
		if execution_context.get("kind")!="event" or origin.get("command_code")==111 or not parameters is Array or parameters.size()!=1 or not parameters[0] is int or parameters[0]<=0: return fail("command_117需要当前解释器的脚本指令和一个有效公共事件编号。")
		if _custom==null or _custom.record("CommonEvents",parameters[0]).is_empty(): return fail("脚本公共事件不存在："+str(parameters[0]))
		if int(execution_context.get("stack_depth",0))>=32: return fail("公共事件调用超过32层。")
		_common_call=parameters[0]; return true
	if receiver is Dictionary and receiver.has("__ruby_regex") and name=="match" and args.size()==1 and args[0] is String: return regex_match(receiver.__ruby_regex,args[0])
	if receiver is Dictionary and receiver.has("__ruby_range") and name in ["include?","member?"] and args.size()==1: return binary("===",receiver,args[0])
	if name=="split" and receiver is String and args.size() in [1,2] and args[0] is Dictionary and args[0].has("__ruby_regex"):
		if args.size()==2 and not args[1] is int: return fail("split长度必须为整数。")
		var split_result=RegexValues.split(args[0].__ruby_regex,receiver,int(args[1]) if args.size()==2 else 0)
		return split_result.value if split_result.ok else fail(split_result.message)
	if name=="to_i" and args.is_empty():
		if _number(receiver): return int(receiver)
		if receiver is String:
			var matcher=RegEx.new(); matcher.compile("^[ \\t\\r\\n\\f\\v]*([+-]?[0-9]+)")
			var found=matcher.search(receiver)
			if found==null: return 0
			var numeric=Decimal.compact(found.get_string(1).trim_prefix("+"))
			return big_integer(numeric) if numeric is String else numeric
	if name=="to_i" and receiver is String and args.size()==1 and args[0] is int:
		var parsed=preload("FlashUtils.gd").integer_text(receiver,args[0])
		return parsed.value if parsed.ok else fail(parsed.message)
	if _flash_profile() and name in ["_main_actor","_attack_actor","_support_actors","_this","_enemies","_map","_events","_ss","_actors"] and args.is_empty() and receiver is Dictionary and receiver.get("__event_context",false):
		if name=="_map": return _custom.data_ref("map",state.map_id)
		if name=="_events": return _custom.data_ref("map_events",state.map_id)
		if name=="_ss": return {"__state_table":"self"}
		if name=="_actors": return _custom.party_call("actors",[])
		if name=="_this": return _custom.data_ref("map_event",int(execution_context.get("map_id",state.map_id)),"",int(execution_context.get("event_id",0))) if int(execution_context.get("event_id",0))>0 else null
		if name=="_enemies": return _custom.data_ref("floor_entries",state.map_id)
		if name=="_main_actor":
			var index=int(_custom.values.system.get("main_actor_index",0))
			return _custom.data_ref("actor",int(_custom.party_ids[index])) if index>=0 and index<_custom.party_ids.size() else null
		return _custom.gameplay().invoke(_custom.data_ref("gameplay_module",0,"BattleSystem::PartyRoles"),"main_actor" if name=="_attack_actor" else "support_actor",[])
	if _custom!=null and receiver is Dictionary and (receiver.has("__custom_ref") or receiver.get("__service")=="party"):
		var value: Variant=_custom.invoke(receiver if receiver.has("__custom_ref") else _custom.data_ref("party"),name,args)
		if not _custom.failure.is_empty(): return fail(_custom.failure)
		if name=="gold" and value is String: return big_integer(value)
		return value
	if receiver is Dictionary and not receiver.has("__ruby_class") and not receiver.has("__ruby_type") and args.is_empty() and receiver.has(name): return receiver[name]
	if receiver is Dictionary and not receiver.has("__ruby_class") and not receiver.has("__ruby_type") and not receiver.has("__ruby_hash"):
		if name in ["include?","key?","has_key?"] and args.size()==1: return receiver.has(args[0]) or receiver.has(str(args[0]))
		if name in ["keys","values"] and args.is_empty(): return receiver.keys() if name=="keys" else receiver.values()
		if name in ["size","length"] and args.is_empty(): return receiver.size()
		if name=="empty?" and args.is_empty(): return receiver.is_empty()
	if receiver is Dictionary and receiver.has("__service"):
		if receiver.__service=="party" and name=="gold" and args.is_empty(): return _pending_gold if _pending_gold!=null else state.gold
		if receiver.__service=="party" and name in ["gain_gold","lose_gold"] and args.size()==1:
			if not args[0] is int or abs(float(args[0]))>2147483647: return fail("金币增减必须为支持范围内整数。")
			var current: Variant = _pending_gold if _pending_gold!=null else state.gold
			if not current is int or current<0 or current>9999999: return fail("现有金币状态无效。")
			_pending_gold = clampi(current+(args[0] if name=="gain_gold" else -args[0]),0,9999999)
			return _pending_gold
		return fail("游戏服务调用尚未接入："+name)
	if receiver is Array or receiver is String or receiver is Dictionary and receiver.has("__ruby_hash"):
		if receiver is Dictionary and receiver.has("__ruby_hash"):
			if name in ["size","length"] and args.is_empty(): return receiver.__ruby_hash.size()
			if name=="empty?" and args.is_empty(): return receiver.__ruby_hash.is_empty()
			if name in ["include?","key?"] and args.size()==1: return receiver.__ruby_hash.has(_hash_key(args[0]))
		if name in ["size","length"] and args.is_empty():
			if receiver is String:
				for character in receiver:
					if character.unicode_at(0)>127: return fail("非ASCII字符串的Ruby 1.8字节长度尚未适配。")
				return receiver.length()
			return receiver.size()
		if name=="empty?" and args.is_empty(): return receiver.is_empty()
		if name=="include?" and args.size()==1:
			if receiver is String:
				if not args[0] is String: return fail("字符串include?要求字符串参数。")
				return receiver.contains(args[0])
			for item in receiver:
				if _equal(item,args[0]): return true
			return false
		if name=="push" and receiver is Array and args.size()==1: receiver.append(args[0]); return receiver
	if name=="abs" and _number(receiver) and args.is_empty(): return abs(receiver)
	if name=="to_s" and args.is_empty() and not (receiver is Dictionary and receiver.has("__ruby_class")): return stringify(receiver)
	var singleton: bool = receiver is Dictionary and receiver.has("__ruby_type")
	var type_name: String = receiver.get("__ruby_type",receiver.get("__ruby_class",owner)) if receiver is Dictionary else owner
	if receiver is Dictionary and name in ["_v","_s"] and args.is_empty() and execution_context.get("policy",{}).get("custom_binding",false): return {"__state_table":"variable" if name=="_v" else "switch"}
	if singleton and name=="new":
		if classes.get(type_name,{}).get("kind")=="module": return fail("模块不能按普通类实例化。")
		var object: Variant = object_ref(type_name)
		if not _lookup(type_name,"initialize",false).is_empty(): invoke(object,"initialize",args,type_name)
		elif not args.is_empty(): return fail("无initialize方法但提供了构造参数。")
		return object
	var lookup_owner := type_name
	while not lookup_owner.is_empty():
		ensure_definition(name,lookup_owner,singleton)
		if not failure.is_empty(): return null
		# Ruby resolves the nearest own definition before walking its parent.
		# Loading a shadowed parent implementation can introduce unrelated native
		# dependencies and contradict that lookup order.
		if methods.has(_key(lookup_owner,name,singleton)): break
		lookup_owner = classes.get(lookup_owner,{}).get("parent","")
	var spec := _lookup(type_name,name,singleton)
	if spec.is_empty(): return fail("方法尚未迁移/加载：%s%s%s" % [type_name,"." if singleton else "#",name])
	_depth += 1
	if _depth>96: _depth -= 1; return fail("方法调用超过96层。")
	var previous_origin := origin; var previous_span := span; origin = spec.origin
	var previous_regex=enter_regex_scope()
	if not _method_programs.has(spec.path): _method_programs[spec.path]=program(spec.path)
	var script: GDScript = _method_programs[spec.path]
	var value: Variant = script.call(spec.function,self,receiver,args) if script != null else fail("生成方法文件无法加载："+spec.path)
	leave_regex_scope(previous_regex)
	origin = previous_origin; span = previous_span; _depth -= 1
	return value

func regex_value(pattern: String,flags: String) -> Variant:
	var checked=RegexValues.compile(pattern,flags)
	return {"__ruby_regex":{"source":pattern,"flags":flags}} if checked.ok else fail(checked.message)

func regex_match(descriptor: Dictionary,value: String) -> Variant:
	var result=RegexValues.match_value(descriptor,value)
	if not result.ok: return fail(result.message)
	_regex_data=result.data
	if _regex_scope_depth==0 and execution_context.has("fields"): execution_context.fields["__rgm_regex"]=_regex_data
	return _regex_data

func enter_regex_scope() -> Variant:
	var previous: Variant=_regex_data
	_regex_data=null; _regex_scope_depth+=1
	return previous

func leave_regex_scope(previous: Variant) -> void:
	_regex_data=previous; _regex_scope_depth-=1

func _flash_profile() -> bool:
	return _custom!=null and _custom.manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json")

func flash_attribute_read(name: Variant) -> Variant:
	if not _flash_profile() or not (name is String or name is StringName) or str(name) not in ["maxhp","maxsp","patk","pdef","matk","mdef","agi","int","resist"]: return fail("未迁移的角色能力名："+str(name))
	var actor: Variant=invoke(root_receiver(),"_main_actor",[])
	return invoke(actor,str(name),[]) if failure.is_empty() else null

func flash_attribute_write(name: Variant,value: Variant) -> Variant:
	if not _flash_profile() or not (name is String or name is StringName) or str(name) not in ["maxhp","maxsp","patk","pdef","matk","mdef","agi","int","resist"]: return fail("未迁移的角色能力名："+str(name))
	var actor: Variant=invoke(root_receiver(),"_main_actor",[])
	return invoke(actor,str(name)+"=",[value]) if failure.is_empty() else null

func flash_name_value(source: Variant) -> Variant:
	if not _flash_profile() or not source is String: return fail("宝石能力需要已迁移的名称数据。")
	var values: Dictionary=_custom.gameplay().rules.get("event_attribute_values",{})
	if not values.has(source): return fail("宝石名称表达式尚未迁移："+source)
	var value: Variant=values[source]
	return value.duplicate(true) if value is Array or value is Dictionary else value

func invoke_block(receiver: Variant, name: String, block: Callable) -> Variant:
	if receiver is Dictionary and receiver.has("__ruby_range") and name in ["each","map"]:
		var values := iterable(receiver); var result: Variant = invoke_block(values,name,block)
		return result if name=="map" else receiver
	if receiver is Array and name in ["each","map","each_with_index"]:
		var mapped: Array = []; var position := 0
		while position<receiver.size():
			if not tick(span): return null
			mapped.append(block.call([receiver[position],position] if name=="each_with_index" else [receiver[position]]))
			if not failure.is_empty(): return null
			position += 1
		return mapped if name=="map" else receiver
	var entries: Array = []
	if receiver is Dictionary and name in ["each","map"]:
		if receiver.has("__ruby_hash"):
			for key in receiver.__ruby_hash: entries.append([receiver.__keys[key],receiver.__ruby_hash[key]])
		else:
			if receiver.keys().any(func(key):return str(key).begins_with("__")): return fail("该对象不是Ruby Hash迭代器。")
			for key in receiver: entries.append([key,receiver[key]])
	elif receiver is int and name=="times" and receiver>=0 and receiver<=100000:
		for position in receiver: entries.append([position])
	else: return fail("迭代块的接收者类型尚未适配。")
	var mapped: Array = []
	for arguments in entries:
		if not tick(span): return null
		if receiver is Dictionary:
			var table: Dictionary=receiver.__ruby_hash if receiver.has("__ruby_hash") else receiver
			if table.size()!=entries.size(): return fail("迭代期间新增/删除Hash键尚未支持。")
			arguments[1] = table.get(_hash_key(arguments[0]) if receiver.has("__ruby_hash") else arguments[0])
		mapped.append(block.call(arguments))
		if not failure.is_empty(): return null
	return mapped if name=="map" else receiver

func _lookup(owner: String, name: String, singleton: bool) -> Dictionary:
	var visited := {}
	while not owner.is_empty() and not visited.has(owner):
		visited[owner] = true; var key := _key(owner,name,singleton)
		if methods.has(key): return methods[key]
		for module_name in classes.get(owner,{}).get("extensions" if singleton else "includes",[]):
			var module_key := _key(module_name,name,false)
			if methods.has(module_key): return methods[module_key]
		owner = classes.get(owner,{}).get("parent","")
	return {}

func _key(owner: String, name: String, singleton: bool) -> String:
	return owner+("." if singleton else "#")+name

func _valid_id(value: Variant) -> bool:
	return value is int and value>0 and value<=2147483647

func _self_switch_key(value: Variant) -> String:
	if not value is Array or value.size()!=3 or not _valid_id(value[0]) or not _valid_id(value[1]) or not value[2] is String or value[2] not in ["A","B","C","D"]:
		fail("独立开关键必须为[地图ID,事件ID,A—D]。"); return ""
	return str(value[0])+":"+str(value[1])+":"+value[2]

func _number(value: Variant) -> bool:
	return value is int or value is float

func _hash_key(value: Variant) -> String:
	if value!=null and typeof(value) not in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME]: fail("复杂Hash键的hash/eql?语义尚未支持。"); return ""
	return str(typeof(value))+":"+JSON.stringify(value)

func _equal(left: Variant, right: Variant, depth: int = 0) -> bool:
	if (left is Array or left is Dictionary) and is_same(left,right): return true
	if depth>96: fail("递归集合比较超过96层。"); return false
	if typeof(left)!=typeof(right) and not (_number(left) and _number(right)): return false
	if left is Array:
		if left.size()!=right.size(): return false
		for position in left.size():
			if not _equal(left[position],right[position],depth+1): return false
		return true
	if left is Dictionary:
		if left.has("__custom_ref") and right.has("__custom_ref"):
			if left.__custom_ref in ["project_object","generic_project_object"] or right.__custom_ref in ["project_object","generic_project_object"]: return is_same(left,right)
			return left.__custom_ref==right.__custom_ref and left.get("id")==right.get("id") and left.get("database")==right.get("database") and left.get("event")==right.get("event")
		if left.has("__ruby_range") and right.has("__ruby_range"): return left.__ruby_range==right.__ruby_range
		if left.has("__ruby_type") and right.has("__ruby_type"): return left.__ruby_type==right.__ruby_type
		if left.has("__state_table") and right.has("__state_table"): return left.__state_table==right.__state_table
		if left.has("__service") and right.has("__service"): return left.__service==right.__service
		if left.has("__ruby_hash") and right.has("__ruby_hash"):
			if left.__ruby_hash.size()!=right.__ruby_hash.size(): return false
			for key in left.__ruby_hash:
				if not right.__ruby_hash.has(key) or not _equal(left.__ruby_hash[key],right.__ruby_hash[key],depth+1): return false
			return true
		return is_same(left,right)
	return left==right

func copy_value(value: Variant, graph: Array = [], depth: int = 0) -> Variant:
	var index: Dictionary={}
	for i in graph.size(): Graph._remember(index,graph[i].original,i)
	return _copy_graph(value,graph,depth,index)

func _copy_graph(value: Variant,graph: Array,depth: int,index: Dictionary) -> Variant:
	if not value is Array and not value is Dictionary: return value
	var signature=Graph._shape(value)
	var found=Graph._find(index,value,signature)
	if found>=0: return graph[found].copy
	if depth>96: fail("状态集合嵌套超过96层。"); return null
	var copied: Variant = [] if value is Array else {}
	copied.assign(value)
	Graph._remember(index,value,graph.size(),signature); graph.append({"original":value,"copy":copied})
	if value is Array:
		for i in value.size():
			var item: Variant=value[i]
			if item is Array or item is Dictionary: copied[i]=_copy_graph(item,graph,depth+1,index)
	else:
		for key in value:
			var child: Variant=value[key]
			if child is Array or child is Dictionary: copied[key]=_copy_graph(child,graph,depth+1,index)
	return copied

func big_integer(value: String) -> Variant:
	var number: Variant=Decimal.compact(value)
	return {"__decimal_integer":number} if number is String else number if number!=null else fail("大整数格式无效。")

func _has_custom_data() -> bool:
	return state.get("custom_data")!=null

static func _integer_quotient(a: int,b: int) -> int:
	var quotient=a/b
	return quotient-1 if a%b!=0 and (a<0)!=(b<0) else quotient

func _data_reason(value: Variant) -> String:
	return Graph.reason(value) if _has_custom_data() and state.custom_data.manifest.get("profile")=="flash" else CustomData.plain_reason(value)

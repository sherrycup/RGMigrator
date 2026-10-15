extends RefCounted
## Generates executable GDScript statements/functions, never runtime AST dispatch.
const Parser = preload("res://scripts/importer/RubyParser.gd")
const FORMAT := "rgm-gdscript-v2"
const BUILTINS := ["size","length","empty?","include?","key?","has_key?","keys","values","push","abs","to_s","to_i","split","match","nil?","new","gold","gain_gold","lose_gold","_v","_s","plus","minus","prod","bwise","to_opc","p","puts","max","min","move_down","move_left","move_right","move_up","in?","to_param","random_element","old_val","is_a?","kind_of?"]
var _lines: Array[String] = []
var _functions: Array[String] = []
var _errors: Array = []
var _mapping: Array = []
var _lowered: Array = []
var _origin := {}
var _path := ""
var _owner := "Object"
var _locals: Array = []
var _known_methods: Array = []
var _counter := 0
var _indent := 1
var _loop_depth := 0
var _method_depth := 0
var _function := "program"
var _module_function := false
var _singleton_scope := false

func compile(source: String, origin: Dictionary = {}, generated_path: String = "", known_methods: Array = []) -> Dictionary:
	var parsed := Parser.new().parse(source,origin)
	if not parsed.ok: return {"ok":false,"ast":parsed.ast,"diagnostics":parsed.diagnostics,"generated_source":"","ir":[]}
	return compile_ast(parsed.ast,generated_path,known_methods)

func compile_ast(ast: Dictionary, generated_path: String, known_methods: Array = []) -> Dictionary:
	_lines = []; _functions = []; _errors = []; _mapping = []; _lowered = []; _origin = ast.origin; _path = generated_path
	_owner = "Object"; _locals = []; _known_methods = []; _counter = 0; _indent = 1; _loop_depth = 0; _method_depth = 0
	_function = "program"
	_module_function=false; _singleton_scope=false
	_collect_methods(ast)
	_known_methods.append_array(known_methods)
	_lines.append_array(["extends RefCounted",'const Semantics = preload("res://runtime/scripts/ScriptSemantics.gd")',"", "static func execute(state: Object, session: RefCounted = null) -> Dictionary:","\tvar env: RefCounted = session if session != null else Semantics.new(state)","\tif not env.begin(%s): return env.failure" % _literal(_origin),"\tvar value: Variant = program(env)","\treturn env.finish(value)","", "static func program(env: RefCounted) -> Variant:","\tvar receiver: Variant = env.root_receiver()","\tvar locals: Dictionary = {}","\tvar result: Variant = null"])
	_body(ast.body); _emit("return result")
	var generated := "\n".join(_lines)+"\n\n"+"\n\n".join(_functions)+"\n"
	var generated_lines := generated.split("\n")
	for entry in _mapping:
		var function: String = entry.get("generated_method",entry.get("generated_function","program"))
		for position in generated_lines.size():
			if generated_lines[position].begins_with("static func "+function+"("):
				if entry.has("generated_method"): entry["generated_line"] = position+1
				elif function!="program": entry.generated_line += position
				break
	return {"ok":_errors.is_empty(),"empty":ast.body.is_empty(),"ast":ast,"ir":{"format":FORMAT,"lowered_statements":_lowered,"source_map":_mapping},"source_map":_mapping,"diagnostics":_errors,"generated_source":generated if _errors.is_empty() else ""}

func method_names(ast: Dictionary) -> Array:
	_known_methods = []; _collect_methods(ast); return _known_methods.duplicate()

func _body(body: Array) -> void:
	for node in body:
		if not _errors.is_empty(): break
		_emit("if not env.tick(%s): return null" % _literal(node.span))
		_mapping.append({"origin":_origin,"span":node.span,"generated_line":_lines.size()+1,"generated_function":_function,"owner":_owner,"kind":node.kind})
		match node.kind:
			"class", "module":
				if _method_depth>0: _error(node,"nested_type","方法中的类/模块定义尚未转换。"); continue
				var previous := _owner
				var previous_module_function := _module_function; var previous_singleton := _singleton_scope
				_module_function=false; _singleton_scope=false
				var previous_locals: Array = _locals; _locals = []
				var saved_receiver := _temp("receiver"); var saved_locals := _temp("locals")
				var saved_regex := _temp("env.enter_regex_scope()")
				_owner = node.name if previous=="Object" else previous+"::"+node.name
				_emit("env.declare_type(%s, %s, %s)" % [_literal(_owner),_literal(node.parent),_literal(node.kind)])
				_emit("receiver = env.type_ref(%s)" % _literal(_owner)); _emit("locals = {}"); _emit("result = null")
				_body(node.body); _owner = previous; _locals = previous_locals
				_module_function=previous_module_function; _singleton_scope=previous_singleton
				_emit("receiver = "+saved_receiver); _emit("locals = "+saved_locals)
				_emit("env.leave_regex_scope("+saved_regex+")")
			"method": _method(node)
			"singleton_class":
				if node.receiver.get("kind")!="self": _error(node,"singleton_class","只支持class << self。"); continue
				var previous_singleton := _singleton_scope
				_singleton_scope=true; _body(node.body); _singleton_scope=previous_singleton
			"alias":
				_emit("env.alias_method(%s, %s, %s, %s)" % [_literal(_owner),_literal(node.name),_literal(node.target),"true" if _singleton_scope else "false"])
				_emit("result = null")
			"if", "unless": _conditional(node,node.kind=="unless")
			"case": _case_statement(node)
			"name":
				if node.name=="module_function": _module_function=true; _emit("result = null")
				else: _emit("result = "+_expression(node))
			"modifier":
				if node.operator in ["if","unless"]:
					_conditional({"branches":[{"condition":node.condition,"body":node.body}],"else_body":[]},node.operator=="unless")
				else: _loop({"kind":node.operator,"condition":node.condition,"body":node.body})
			"while", "until", "for": _loop(node)
			"return":
				if _method_depth==0: _error(node,"return_context","顶层/块的非局部return尚未转换。"); continue
				var values: Array[String]=[]
				for argument in node.arguments: values.append(_expression(argument))
				_emit("return "+("["+", ".join(values)+"]" if values.size()>1 else values[0] if values.size()==1 else "null"))
			"break", "next":
				if _loop_depth==0 or not node.arguments.is_empty(): _error(node,"loop_control","块或带值的循环控制尚未转换。"); continue
				_emit("break" if node.kind=="break" else "continue")
			"call":
				if node.receiver.is_empty() and node.name=="module_function":
					if node.arguments.is_empty(): _module_function=true
					else:
						for argument in node.arguments:
							if argument.kind!="symbol": _error(argument,"module_function","module_function只支持静态方法名。"); continue
							_emit("env.copy_module_function(%s, %s)" % [_literal(_owner),_literal(argument.value)])
				elif node.receiver.is_empty() and node.name in ["attr_reader","attr_writer","attr_accessor"]: _attributes(node)
				elif node.receiver.is_empty() and node.name in ["include","extend"]:
					if node.arguments.size()!=1: _error(node,"mixin","mixin只接受一个静态模块。"); continue
					var value := _expression(node.arguments[0]); _emit("env.include_module(%s, %s, %s)" % [_literal(_owner),value,"true" if node.name=="extend" else "false"])
				else: _emit("result = "+_expression(node))
			_:
				_emit("result = "+_expression(node))
		_emit("if not env.failure.is_empty(): return null")

func _conditional(node: Dictionary, invert: bool) -> void:
	_emit("result = null")
	# Each condition is emitted only in the branch where Ruby would evaluate it.
	var nesting := 0
	for branch in node.branches:
		var condition := _expression(branch.condition)
		_emit("if %sSemantics.truth(%s):" % ["not " if invert else "",condition])
		_indent += 1
		if branch.body.is_empty(): _emit("pass")
		else: _body(branch.body)
		_indent -= 1; _emit("else:"); _indent += 1; nesting += 1
	if node.else_body.is_empty(): _emit("pass")
	else: _body(node.else_body)
	_indent -= nesting

func _case_statement(node: Dictionary) -> void:
	var subject=_expression(node.value) if not node.value.is_empty() else ""
	_emit("result = null")
	var nesting=0
	for branch in node.branches:
		var matched=_temp("false")
		for pattern in branch.patterns:
			_emit("if not "+matched+":"); _indent+=1
			var value=_expression(pattern)
			_emit(matched+" = Semantics.truth("+("env.binary(\"===\", "+value+", "+subject+")" if not subject.is_empty() else value)+")")
			_indent-=1
		_emit("if "+matched+":"); _indent+=1
		if branch.body.is_empty(): _emit("pass")
		else: _body(branch.body)
		_indent-=1; _emit("else:"); _indent+=1; nesting+=1
	if node.else_body.is_empty(): _emit("pass")
	else: _body(node.else_body)
	_indent-=nesting

func _loop(node: Dictionary) -> void:
	var iterator := ""
	if node.kind=="for":
		iterator = _expression(node.iterator); _locals.append(node.target)
		var iteration_name := "iteration_%d" % _counter; _counter += 1
		_emit("for %s in env.iterable(%s):" % [iteration_name,iterator]); _indent += 1
		_emit("locals[%s] = %s" % [_literal(node.target),iteration_name])
	else:
		_emit("while true:"); _indent += 1
		var condition := _expression(node.condition)
		_emit("if %sSemantics.truth(%s): break" % ["" if node.kind=="until" else "not ",condition])
	_emit("if not env.tick(%s): return null" % _literal(node.get("span",{})))
	_loop_depth += 1; _body(node.body); _loop_depth -= 1
	_indent -= 1; _emit("result = "+iterator if node.kind=="for" else "result = null")

func _method(node: Dictionary) -> void:
	if _method_depth>0: _error(node,"nested_definition","方法中的动态定义尚未转换。"); return
	if not node.exception.is_empty(): _error(node,"exception","异常控制路径已解析，尚未生成等价GDScript。"); return
	if node.receiver not in ["","self"]: _error(node,"singleton","仅支持def self.method的单例定义。"); return
	var function := "method_%d" % _counter; _counter += 1
	var saved := _save_frame(); _lines = []; _indent = 1; _locals = []; _loop_depth = 0; _method_depth = 1
	_function = function
	_lines.append("static func %s(env: RefCounted, receiver: Variant, arguments: Array) -> Variant:" % function)
	_emit("var locals: Dictionary = {}"); _emit("var result: Variant = null")
	var required := 0; var has_rest := false; var optional_seen := false; var position := 0
	for parameter in node.parameters:
		if parameter.name in _locals or parameter.mode=="block" or optional_seen and parameter.mode=="required":
			_error(parameter,"parameter_semantics","重复参数、块参数或可选参数之后的必需参数尚未支持。"); break
		_locals.append(parameter.name)
		if parameter.mode=="required": required += 1
		if parameter.mode=="optional": optional_seen = true
		if parameter.mode=="rest": has_rest = true
	_emit('if arguments.size() < %d%s: return env.fail("方法参数数量不匹配。")' % [required,"" if has_rest else " or arguments.size() > %d" % node.parameters.size()])
	_locals = []
	for parameter in node.parameters:
		_locals.append(parameter.name)
		if parameter.mode=="rest": _emit("locals[%s] = arguments.slice(%d)" % [_literal(parameter.name),position])
		elif parameter.mode=="optional":
			_emit("if arguments.size() > %d:" % position); _indent += 1
			_emit("locals[%s] = arguments[%d]" % [_literal(parameter.name),position]); _indent -= 1
			_emit("else:"); _indent += 1
			var value := _expression(parameter.default); _emit("locals[%s] = %s" % [_literal(parameter.name),value]); _indent -= 1
		else: _emit("locals[%s] = arguments[%d]" % [_literal(parameter.name),position])
		position += 1
	_body(node.body); _emit("return result")
	var text := "\n".join(_lines); _restore_frame(saved); _functions.append(text)
	var singleton: bool=node.receiver=="self" or _singleton_scope
	_emit("env.define_method(%s, %s, %s, %s, %s, %s)" % [_literal(_owner),_literal(node.name),"true" if singleton else "false",_literal(_path),_literal(function),_literal(_origin.merged({"span":node.span}))])
	if node.receiver=="" and _module_function and not singleton:
		_emit("env.define_method(%s, %s, true, %s, %s, %s)" % [_literal(_owner),_literal(node.name),_literal(_path),_literal(function),_literal(_origin.merged({"span":node.span}))])
	_mapping.append({"origin":_origin,"span":node.span,"owner":_owner,"ruby_method":node.name,"generated_method":function,"generated_path":_path,"singleton":singleton})
	_emit("result = null")

func _attributes(node: Dictionary) -> void:
	for argument in node.arguments:
		if argument.kind != "symbol": _error(argument,"attribute","attr成员必须为静态符号。"); continue
		var field: String = argument.value
		if node.name in ["attr_reader","attr_accessor"]:
			_method({"name":field,"receiver":"","parameters":[],"exception":{},"span":node.span,"body":[{"kind":"name","scope":"instance","name":"@"+field,"span":node.span}]})
		if node.name in ["attr_writer","attr_accessor"]:
			_method({"name":field+"=","receiver":"","parameters":[{"name":"value","mode":"required","span":node.span}],"exception":{},"span":node.span,"body":[{"kind":"assign","operator":"=","left":{"kind":"name","scope":"instance","name":"@"+field,"span":node.span},"right":{"kind":"name","scope":"identifier","name":"value","span":node.span},"span":node.span}]})

func _expression(node: Dictionary) -> String:
	if node.is_empty(): return "null"
	match node.kind:
		"literal":
			if node.value is int and abs(float(node.value))>9007199254740991: return _temp("env.big_integer(%s)" % _literal(str(node.value)))
			if node.value is int or node.value is float:
				if abs(float(node.value))>9007199254740991: _error(node,"numeric_range","数值字面量超出JSON精确支持范围。")
			return _literal(node.value)
		"big_integer": return _temp("env.big_integer(%s)" % _literal(str(node.value)))
		"symbol": return "StringName(%s)" % _literal(node.value)
		"self": return "receiver"
		"name":
			var name: String = node.name
			if name.begins_with("@") and _method_depth==0 and (_origin.get("kind","script")=="script" or _owner!="Object"): _error(node,"class_instance_variable","类体的实例变量尚未转换。"); return "null"
			if name.begins_with("@@"): _error(node,"class_variable","类变量共享语义待后续适配。"); return "null"
			if name.begins_with("$game_") and name not in ["$game_variables","$game_switches","$game_self_switches","$game_party","$game_actors","$game_system","$game_troops","$game_troop","$game_temp","$game_player","$game_map","$game_equipment","$game_blastics"] or name.begins_with("$data_") and name not in ["$data_actors","$data_classes","$data_items","$data_weapons","$data_armors","$data_enemies","$data_skills","$data_states"]:
				_error(node,"game_object","该游戏对象尚未桥接："+name); return "null"
			if node.scope=="identifier" and name in _locals and not _constant(name): return _temp("locals.get(%s)" % _literal(name))
			if node.scope=="identifier" and name not in _locals and not _constant(name):
				if name not in _known_methods and name not in ["_v","_s"]: _error(node,"unbound_call","隐式调用尚未绑定："+name); return "null"
				return _temp("env.invoke(receiver, %s, [], %s)" % [_literal(name),_literal(_owner)])
			return _temp("env.read_name(%s, locals, receiver, %s)" % [_literal(name),_literal(_owner)])
		"array":
			var items: Array[String] = []
			for item in node.elements: items.append(_expression(item))
			return _temp("["+", ".join(items)+"]")
		"hash":
			var items: Array[String] = []
			for pair in node.pairs: items.append("["+_expression(pair.key)+", "+_expression(pair.value)+"]")
			return _temp("env.hash_pairs(["+", ".join(items)+"])")
		"string", "words", "regex":
			var parts: Array[String] = []
			for part in node.parts:
				parts.append(_literal(part.value) if part.kind=="text" else _temp("env.stringify(%s)" % _expression(part.value)))
			if node.kind=="words":
				if node.parts.size()!=1: _error(node,"word_interpolation","插值词数组尚未转换。"); return "null"
				return _temp("Semantics.words(%s)" % _literal(node.parts[0].value))
			if node.kind=="regex": return _temp("env.regex_value(%s, %s)" % [" + ".join(parts) if not parts.is_empty() else '\"\"',_literal(node.flags)])
			return _temp(" + ".join(parts) if not parts.is_empty() else '\"\"')
		"unary": return _temp("env.unary(%s, %s)" % [_literal(node.operator),_expression(node.value)])
		"binary":
			var left := _expression(node.left)
			if node.operator in ["&&","and","||","or"]:
				var result := _temp(left); _emit("if %sSemantics.truth(%s):" % ["not " if node.operator in ["||","or"] else "",result]); _indent += 1
				var right := _expression(node.right); _emit(result+" = "+right); _indent -= 1; return result
			return _temp("env.binary(%s, %s, %s)" % [_literal(node.operator),left,_expression(node.right)])
		"range": return _temp("env.sequence(%s, %s, %s)" % [_expression(node.left),_expression(node.right),"true" if node.operator=="..." else "false"])
		"index":
			if node.arguments.size()>1:
				var indexes: Array[String]=[]
				var receiver=_expression(node.receiver)
				for argument in node.arguments: indexes.append(_expression(argument))
				return _temp("env.indexes_get(%s, [%s])" % [receiver,", ".join(indexes)])
			if node.arguments.is_empty(): _error(node,"slice","下标参数不可为空。"); return "null"
			return _temp("env.index_get(%s, %s)" % [_expression(node.receiver),_expression(node.arguments[0])])
		"assign": return _assignment(node)
		"ternary":
			var condition := _expression(node.condition); var result := _temp("null")
			_emit("if Semantics.truth(%s):" % condition); _indent += 1
			var yes := _expression(node.yes); _emit(result+" = "+yes); _indent -= 1
			_emit("else:"); _indent += 1
			var no := _expression(node.no); _emit(result+" = "+no); _indent -= 1; return result
		"call":
			if not node.block.is_empty(): return _block_call(node)
			if node.name=="eval" and node.receiver.is_empty(): return _flash_eval(node)
			if node.name not in BUILTINS and node.name not in _known_methods and not _custom_call(node): _error(node,"unbound_call","调用接口尚未绑定："+node.name); return "null"
			var receiver := "receiver" if node.receiver.is_empty() else _expression(node.receiver); var args: Array[String] = []
			for arg in node.arguments: args.append(_expression(arg))
			return _temp("env.invoke(%s, %s, [%s], %s)" % [receiver,_literal(node.name),", ".join(args),_literal(_owner)])
	_error(node,"unsupported_semantics","AST节点已解析但语义尚未转换："+node.kind)
	return "null"

func _flash_eval(node: Dictionary) -> String:
	# Resolve specific source idioms at compilation time. The generated runtime
	# receives typed arguments, never Ruby source strings or an executable AST.
	if node.arguments.size()==1:
		var argument: Dictionary=node.arguments[0]
		if argument.kind=="string":
			var parts: Array=argument.parts
			if parts.size()==5 and parts[0].get("value")=="_main_actor." and parts[1].kind=="expression" and parts[2].get("value")==".plus(" and parts[3].kind=="expression" and parts[4].get("value")==")":
				var key=_expression(parts[1].value); var added=_expression(parts[3].value)
				var current=_temp("env.flash_attribute_read("+key+")")
				return _temp("env.invoke("+current+", \"plus\", ["+added+"])")
			if parts.size()==3 and parts[0].get("value")=="_main_actor." and parts[1].kind=="expression" and parts[2].get("value")=="=new_attr" and "new_attr" in _locals:
				return _temp("env.flash_attribute_write(%s, %s)" % [_expression(parts[1].value),_temp('locals.get("new_attr")')])
		if _origin.get("kind")=="common_event" and int(_origin.get("common_event_id",0))==23 and int(_origin.get("command_index",0))==28 and argument.kind=="index" and argument.receiver.get("name")=="code" and argument.arguments.size()==1 and argument.arguments[0].get("value")==1:
			return _temp("env.flash_name_value("+_expression(argument)+")")
	_error(node,"dynamic_eval","该eval尚未静态转换为GDScript；不执行动态Ruby。")
	return "null"

func _assignment(node: Dictionary) -> String:
	var left: Dictionary = node.left; var current := "null"; var receiver := ""; var index := ""
	if left.kind=="name":
		if left.name in ["$&","$`","$'","$+"] or left.name.begins_with("$") and left.name.substr(1).is_valid_int() and int(left.name.substr(1))>0:
			_error(node,"readonly_backreference","正则捕获变量不可写。"); return "null"
		if left.scope=="identifier" and not _constant(left.name) and left.name not in _locals: _locals.append(left.name); _emit("locals[%s] = null" % _literal(left.name))
		if node.operator!="=": current = _expression(left)
	elif left.kind=="index" and left.arguments.size()==1:
		receiver = _expression(left.receiver); index = _expression(left.arguments[0])
		if node.operator!="=": current = _temp("env.index_get(%s, %s)" % [receiver,index])
	elif left.kind=="call" and left.arguments.is_empty() and not left.receiver.is_empty():
		if left.name+"=" not in _known_methods and not _data_setter(left): _error(node,"setter","成员写入接口尚未绑定："+left.name); return "null"
		receiver = _expression(left.receiver)
		if node.operator!="=": current = _temp("env.invoke(%s, %s, [], %s)" % [receiver,_literal(left.name),_literal(_owner)])
	else: _error(node,"assignment_target","赋值目标尚未支持。"); return "null"
	var result := _temp(current)
	if node.operator in ["||=","&&="]:
		_emit("if %sSemantics.truth(%s):" % ["not " if node.operator=="||=" else "",current]); _indent += 1
	var value := _expression(node.right)
	if node.operator not in ["=","||=","&&="]: value = _temp("env.binary(%s, %s, %s)" % [_literal(node.operator.trim_suffix("=")),current,value])
	if left.kind=="name": _emit(result+" = env.write_name(%s, %s, locals, receiver, %s)" % [_literal(left.name),value,_literal(_owner)])
	elif left.kind=="index": _emit(result+" = env.index_set(%s, %s, %s)" % [receiver,index,value])
	else: _emit("env.invoke(%s, %s, [%s], %s)" % [receiver,_literal(left.name+"="),value,_literal(_owner)]); _emit(result+" = "+value)
	if node.operator in ["||=","&&="]: _indent -= 1
	return result

func _block_call(node: Dictionary) -> String:
	if not str(node.block.get("rest_parameter","")).is_empty():
		_error(node,"block_rest_parameter","块的可变参数尚未适配。"); return "null"
	if node.name not in ["each","map","times","each_with_index"] or not node.arguments.is_empty() or node.receiver.is_empty():
		_error(node,"block_interface","块调用接口尚未适配。"); return "null"
	var receiver := _expression(node.receiver)
	var function := "block_%d" % _counter; _counter += 1
	var saved := _save_frame(); _lines = []; _indent = 1; _loop_depth = 0; _method_depth = 0; _function = function
	_locals = saved.locals.duplicate()
	_lines.append("static func %s(arguments: Array, env: RefCounted, receiver: Variant, captured: Dictionary) -> Variant:" % function)
	_emit("var locals: Dictionary = captured.duplicate()"); _emit("var result: Variant = null")
	if node.block.parameters.size()>1:
		_emit("if arguments.size()==1 and arguments[0] is Array: arguments = arguments[0]")
	for position in node.block.parameters.size():
		var name: String = node.block.parameters[position]
		if name not in _locals: _locals.append(name)
		if node.block.parameters.size()==1: _emit("locals[%s] = arguments if arguments.size()>1 else (arguments[0] if not arguments.is_empty() else null)" % _literal(name))
		else: _emit("locals[%s] = arguments[%d] if arguments.size()>%d else null" % [_literal(name),position,position])
	_body(node.block.body)
	_emit("for key in captured: captured[key] = locals.get(key)")
	_emit("return result")
	var text := "\n".join(_lines); _restore_frame(saved); _functions.append(text)
	return _temp("env.invoke_block(%s, %s, Callable(load(%s), %s).bind(env, receiver, locals))" % [receiver,_literal(node.name),_literal(_path),_literal(function)])

func _collect_methods(value: Variant) -> void:
	if value is Dictionary:
		if value.get("kind")=="method": _known_methods.append(value.name)
		if value.get("kind")=="alias": _known_methods.append(value.name)
		if value.get("kind")=="call" and value.get("name") in ["attr_reader","attr_writer","attr_accessor"]:
			for argument in value.arguments:
				if argument.kind=="symbol": _known_methods.append(argument.value); _known_methods.append(argument.value+"=")
		for key in value: _collect_methods(value[key])
	elif value is Array:
		for item in value: _collect_methods(item)

func _save_frame() -> Dictionary:
	return {"lines":_lines,"indent":_indent,"locals":_locals,"loop":_loop_depth,"method":_method_depth,"function":_function}

func _restore_frame(saved: Dictionary) -> void:
	_lines = saved.lines; _indent = saved.indent; _locals = saved.locals; _loop_depth = saved.loop; _method_depth = saved.method
	_function = saved.function

func _constant(name: String) -> bool:
	return not name.is_empty() and name[0]==name[0].to_upper() and name[0]!=name[0].to_lower()

func _temp(expression: String) -> String:
	var name := "value_%d" % _counter; _counter += 1; _emit("var %s: Variant = %s" % [name,expression])
	_emit("if not env.failure.is_empty(): return null")
	return name

func _emit(line: String) -> void:
	_lines.append("\t".repeat(_indent)+line)
	var operation := "statement"
	if line.begins_with("if ") or line=="else:": operation = "branch"
	elif line.begins_with("while ") or line.begins_with("for "): operation = "loop"
	elif line.begins_with("return "): operation = "return"
	elif line.contains("env.index_set(") or line.contains("env.write_name("): operation = "write"
	elif line.contains("env.invoke("): operation = "call"
	elif line.contains("env.read_name(") or line.contains("env.index_get("): operation = "read"
	_lowered.append({"operation":operation,"function":_function,"indent":_indent,"code":line})

func _literal(value: Variant) -> String:
	return JSON.stringify(value,"",false,true)

func _data_setter(node: Dictionary) -> bool:
	var receiver: Dictionary=node.get("receiver",{})
	if receiver.get("kind")=="index" and receiver.get("receiver",{}).get("kind")=="name":
		var name: String=receiver.receiver.name
		return name.begins_with("$data_") or name=="$game_actors" and node.name in ["tp_plus","hprate","sprate","equip_id","resist_plus","skill_parameters","delay_const","maxhp","maxsp","patk","pdef","matk","mdef","agi","int","hp","sp","exp","level","resist","equip_skills","skill_sets","battle_animation","blastic"]
	return receiver.get("kind")=="name" and receiver.get("name") in ["$game_system","$game_temp"] or receiver.get("name")=="$game_player" and node.name in ["opacity","animation_id"]

func _custom_call(node: Dictionary) -> bool:
	if _data_setter(node) and node.get("arguments",[]).is_empty(): return true
	var receiver: Dictionary=node.get("receiver",{})
	if receiver.get("kind")=="index" and receiver.get("receiver",{}).get("name")=="$game_actors":
		return node.name in ["id","name","next_exp","battle_down?","inflict_battle_down!","recover_battle_down!","reset_all"]
	var name: String=receiver.get("name","")
	if name=="$game_party": return node.name in ["kin","spar","gain_currency","gain_kin","lose_kin","gain_spar","lose_spar","hatred","actors","gain_exp","item_number","gain_item","lose_item","item_can_use?","in_map_use?","add_actor","remove_actor","add_battle_actor","remove_battle_actor"]
	if name=="Actor_Init": return node.name=="load"
	if name=="Level_Up": return node.name=="level_up"
	if name=="BattleSystem::PartyRoles": return node.name in ["main_actor","support_actor","main_id","support_id","set_roles","sync_with_party!","swap_roles!","switch_locked?","party_defeated?"]
	if name=="Utils": return node.name in ["MHT_Distance","Check_Area","Find_Event","h_to_i","Unit"]
	if name=="Monster": return node.name in ["set","eset"]
	if name=="DataBase": return node.name in ["maptree","get_floor_type"]
	return false

func _error(node: Dictionary, code: String, message: String) -> void:
	var span: Dictionary = node.get("span",{})
	_errors.append({"stage":"semantic","code":code,"message":message,"line":span.get("line",1),"column":span.get("column",1),"origin":_origin})

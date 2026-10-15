extends RefCounted
## Strict statement/expression AST; unlike an editor scope scanner, never closes
## incomplete blocks silently. Unsupported source is retained by the inventory.
const Lexer = preload("res://scripts/importer/RubyLexer.gd")
const FORMAT := "rgm-ruby-ast-v2"
const PRECEDENCE := {"or":2,"and":2,"=":10,"+=":10,"-=":10,"*=":10,"/=":10,"%=":10,"||=":10,"&&=":10,"rescue":12,"?":15,"..":20,"...":20,"||":25,"&&":30,"==":40,"!=":40,"===":40,"=~":40,"!~":40,"<=>":40,"<":45,">":45,"<=":45,">=":45,"|":50,"^":50,"&":60,"<<":65,">>":65,"+":70,"-":70,"*":80,"/":80,"%":80,"**":100}
var _tokens: Array = []
var _cursor := 0
var _errors: Array = []
var _origin := {}
var _depth := 0
var _singleton_self := false

func parse(source: String, origin: Dictionary = {}) -> Dictionary:
	_origin = origin.duplicate(true); _cursor = 0; _errors = []; _depth = 0; _singleton_self = false
	var lexed := Lexer.new().tokenize(source); _tokens = lexed.tokens
	_errors.append_array(lexed.diagnostics)
	var ast := _node("program", _peek(), {"format":FORMAT,"origin":_origin,"body":[]})
	if _errors.is_empty(): ast.body = _body([])
	ast.span = _span(_tokens[0], _peek())
	for diagnostic in _errors: diagnostic["origin"] = _origin
	return {"ok":_errors.is_empty(),"ast":ast,"diagnostics":_errors.duplicate(true)}

func _body(stops: Array) -> Array:
	var result: Array = []; _separators()
	while _peek().kind != "eof" and _peek().text not in stops and _errors.is_empty():
		var before := _cursor
		result.append(_statement())
		if _cursor == before: _error(_peek(), "progress", "语法分析无法前进。"); break
		if _peek().kind != "separator" and _peek().kind != "eof" and _peek().text not in stops:
			_error(_peek(), "separator", "语句之间需要换行或分号。"); break
		_separators()
	return result

func _statement() -> Dictionary:
	var start := _peek(); var result: Dictionary
	match start.text:
		"class", "module":
			_take()
			if start.text == "class" and _accept("<<"):
				var singleton_receiver := _expression(0)
				_header(); var previous_singleton := _singleton_self; _singleton_self = singleton_receiver.kind == "self"
				var singleton_body := _body(["end"]); _expect("end"); _singleton_self = previous_singleton
				return _node("singleton_class",start,{"receiver":singleton_receiver,"body":singleton_body})
			var name := _constant_path(); var parent := ""
			if _accept("<"):
				if start.text=="module": _error(start,"module_parent","module不能声明父类。")
				parent = _constant_path()
			_header(); var body := _body(["end"]); _expect("end")
			return _node(start.text,start,{"name":name,"parent":parent,"body":body})
		"def": return _method()
		"alias":
			_take(); var new_name := _method_name(); var old_name := _method_name()
			return _node("alias",start,{"name":new_name,"target":old_name})
		"if", "unless": return _conditional()
		"while", "until":
			_take(); var condition := _expression(0); _accept("do"); _header()
			var body := _body(["end"]); _expect("end")
			return _node(start.text,start,{"condition":condition,"body":body})
		"for":
			_take(); var target := _take(); _expect("in"); var iterator := _expression(0); _accept("do"); _header()
			var body := _body(["end"]); _expect("end")
			return _node("for",start,{"target":target.text,"iterator":iterator,"body":body})
		"begin":
			_take(); _separators(); result = _exception_body(start); _expect("end"); return result
		"case": return _case()
		"undef", "redo", "retry", "BEGIN", "END", "__FILE__", "__LINE__":
			_error(start,"unsupported_keyword","此关键字结构尚未解析："+start.text); _take(); return _node("unsupported",start)
		"return", "break", "next", "yield", "super", "raise":
			_take(); var args: Array = []
			if start.text in ["yield","super"] and _accept("("): args = _arguments(")")
			elif _starts_expression(_peek()) and _peek().text not in ["if","unless"]: args = _command_arguments()
			result = _node(start.text,start,{"arguments":args})
		_:
			result = _expression(0)
			if result.kind in ["name","call"] and _starts_expression(_peek()) and _peek().text not in ["{","if","unless","do","end","else","elsif","rescue","ensure","when"]:
				result = _as_call(result, _command_arguments())
			if _peek().text == "," and result.kind in ["name","index","call"]:
				var targets: Array = [result]
				while _accept(","): targets.append(_expression(11))
				_expect("=")
				result = _node("multi_assign",start,{"targets":targets,"values":_command_arguments()})
			if _peek().text in ["do", "{"]:
				if result.kind == "assign" and result.right.kind == "call": result.right = _expression(0,_attach_block(result.right))
				else: result = _expression(0,_attach_block(result))
	if _peek().text in ["do","{"] and result.kind in ["return","raise","yield"] and not result.arguments.is_empty() and result.arguments[-1].kind == "call":
		result.arguments[-1] = _expression(0,_attach_block(result.arguments[-1]))
	if _peek().text in ["if","unless","while","until"]:
		var modifier := _take(); _separators(); var condition := _expression(0)
		return _node("modifier",start,{"operator":modifier.text,"condition":condition,"body":[result]})
	return result

func _method() -> Dictionary:
	var start := _take(); var receiver := ""; var name := _method_name()
	if _accept("."): receiver = name; name = _method_name()
	if receiver.is_empty() and _singleton_self: receiver = "self"
	var parameters: Array = []
	var parenthesized := _accept("(")
	while _errors.is_empty() and _peek().kind not in ["separator","eof"] and (not parenthesized or _peek().text != ")"):
		var point := _peek(); var mode := "required"
		if _accept("*"): mode = "rest"
		elif _accept("&"): mode = "block"
		var parameter := _take()
		if parameter.kind != "identifier": _error(parameter,"parameter","参数名无效。"); break
		var value: Dictionary = {}
		if _accept("="): mode = "optional"; value = _expression(11)
		parameters.append(_node("parameter",point,{"name":parameter.text,"mode":mode,"default":value}))
		if not _accept(","): break
	if parenthesized: _expect(")")
	_header(); var body := _exception_body(start); _expect("end")
	return _node("method",start,{"name":name,"receiver":receiver,"parameters":parameters,"body":body.body,"exception":body if not body.rescues.is_empty() or not body.ensure_body.is_empty() else {}})

func _conditional() -> Dictionary:
	var start := _take(); var condition := _expression(0); _accept("then"); _header()
	var branches: Array = [{"condition":condition,"body":_body(["elsif","else","end"])}]
	while _accept("elsif"):
		if start.text=="unless": _error(start,"unless_elsif","unless不能包含elsif。")
		condition = _expression(0); _accept("then"); _header()
		branches.append({"condition":condition,"body":_body(["elsif","else","end"])})
	var alternative: Array = []
	if _accept("else"): _header(); alternative = _body(["end"])
	_expect("end")
	return _node(start.text,start,{"branches":branches,"else_body":alternative})

func _exception_body(start: Dictionary) -> Dictionary:
	var body := _body(["rescue","ensure","else","end"]); var rescues: Array = []; var alternative: Array = []; var cleanup: Array = []
	while _accept("rescue"):
		var types: Array = []; var binding := ""
		if _peek().kind == "identifier" and _peek().text != "end":
			types.append(_constant_path())
			while _accept(","): types.append(_constant_path())
		if _accept("=>"): binding = _take().text
		_header(); rescues.append({"types":types,"binding":binding,"body":_body(["rescue","else","ensure","end"])})
	if _accept("else"): _header(); alternative = _body(["ensure","end"])
	if _accept("ensure"): _header(); cleanup = _body(["end"])
	return _node("begin",start,{"body":body,"rescues":rescues,"else_body":alternative,"ensure_body":cleanup})

func _case() -> Dictionary:
	var start := _take(); var value: Dictionary = {}
	if _peek().kind != "separator": value = _expression(0)
	_header(); var branches: Array = []
	while _accept("when"):
		var patterns := _command_arguments(); _accept("then"); _header()
		branches.append({"patterns":patterns,"body":_body(["when","else","end"])})
	var alternative: Array = []
	if _accept("else"): _header(); alternative = _body(["end"])
	_expect("end"); return _node("case",start,{"value":value,"branches":branches,"else_body":alternative})

func _expression(minimum: int, initial: Dictionary = {}) -> Dictionary:
	_depth += 1
	if _depth > 96: _error(_peek(),"depth","表达式嵌套超过96层。"); _depth -= 1; return {}
	var left := _prefix() if initial.is_empty() else initial
	while _errors.is_empty():
		var next := _peek(); var op: String = next.text
		if op == "{" and left.kind == "call": left = _attach_block(left); continue
		if left.kind == "call" and left.arguments.is_empty() and _starts_expression(next) and op not in ["(","[","{","if","unless","while","until","do"]:
			left = _as_call(left,_command_arguments(3)); continue
		if op in [".","::"]:
			_take(); var name := _method_name(false); var args: Array = []
			if op=="::" and left.kind=="name" and not name.is_empty() and name[0]==name[0].to_upper() and name[0]!=name[0].to_lower():
				left = _node("name",left.span,{"name":left.name+"::"+name,"scope":"identifier"}); continue
			if _accept("("): args = _arguments(")")
			left = _node("call",left.span,{"receiver":left,"name":name,"arguments":args,"block":{}}); continue
		if op == "(" and left.kind in ["name","call"]:
			_take(); left = _as_call(left,_arguments(")")); continue
		if op == "[":
			_take(); left = _node("index",left.span,{"receiver":left,"arguments":_arguments("]")}); continue
		var power: int = PRECEDENCE.get(op,-1)
		if power < minimum: break
		_take(); _separators()
		if power==10 and left.kind not in ["name","index","call"]:
			_error(next,"assignment_target","无效的赋值目标。"); break
		if op in ["..","..."] and left.kind=="range":
			_error(next,"range_chain","范围运算不能连续串联。"); break
		if op == "?":
			var yes := _expression(0); _expect(":"); _separators(); var no := _expression(power)
			left = _node("ternary",left.span,{"condition":left,"yes":yes,"no":no}); continue
		var right := _expression(power if power == 10 or op == "**" else power+1)
		left = _node("assign" if power == 10 else ("rescue_modifier" if op == "rescue" else "range" if op in ["..","..."] else "binary"),left.span,{"operator":op,"left":left,"right":right})
	_depth -= 1
	return left

func _prefix() -> Dictionary:
	var token := _take()
	if token.text in ["+","-","!","~","not"]: return _node("unary",token,{"operator":token.text,"value":_expression(4 if token.text == "not" else (90 if token.text == "-" else 110))})
	if token.text in ["nil","true","false"]: return _node("literal",token,{"value":null if token.text == "nil" else token.text == "true"})
	if token.text == "self": return _node("self",token)
	if token.text == "defined?":
		var enclosed := _accept("("); var value := _expression(110)
		if enclosed: _expect(")")
		return _node("defined",token,{"value":value})
	if token.text in ["*","&"]: return _node("splat" if token.text == "*" else "block_argument",token,{"value":_expression(11)})
	if token.kind == "number": return _node("literal",token,{"value":token.value})
	if token.kind == "big_integer": return _node("big_integer",token,{"value":token.value})
	if token.kind == "symbol": return _node("symbol",token,{"value":token.value})
	if token.kind in ["string","words","regex"]:
		var parts: Array = []
		for part in token.value.parts:
			if part.kind == "text": parts.append(part); continue
			var parsed: Dictionary = get_script().new().parse(part.source,_origin)
			if not parsed.ok or parsed.ast.body.size() != 1:
				_error(token,"interpolation","插值必须是一个可解析表达式。"); break
			var expression: Dictionary = parsed.ast.body[0]; _relocate(expression,part.position)
			parts.append({"kind":"expression","value":expression})
		return _node(token.kind,token,{"parts":parts,"flags":token.value.flags})
	if token.kind in ["identifier","global","instance"]: return _node("name",token,{"name":token.text,"scope":token.kind})
	if token.text == "(":
		_separators(); var expression := _expression(0); _separators(); _expect(")"); return expression
	if token.text == "[": return _node("array",token,{"elements":_arguments("]")})
	if token.text == "{":
		var pairs: Array = []; _separators()
		while _peek().text != "}" and _peek().kind != "eof" and _errors.is_empty():
			var key := _expression(0); _expect("=>"); var value := _expression(0)
			pairs.append({"key":key,"value":value})
			if not _accept(","): break
			_separators()
		_separators(); _expect("}"); return _node("hash",token,{"pairs":pairs})
	_error(token,"expression","尚未支持或不完整的表达式："+token.text)
	return _node("unsupported",token,{"text":token.text})

func _arguments(close: String) -> Array:
	var result: Array = []; _separators()
	while _peek().text != close and _peek().kind != "eof" and _errors.is_empty():
		result.append(_expression(0))
		if not _accept(","): break
		_separators()
	_separators(); _expect(close); return result

func _command_arguments(minimum: int = 0) -> Array:
	var result: Array = [_expression(minimum)]
	while _accept(","): _separators(); result.append(_expression(minimum))
	return result

func _as_call(expression: Dictionary, arguments: Array) -> Dictionary:
	if expression.kind == "call": expression.arguments = arguments; return expression
	return _node("call",expression.span,{"receiver":{},"name":expression.get("name",""),"arguments":arguments,"block":{}})

func _attach_block(expression: Dictionary) -> Dictionary:
	var start := _take(); var close := "}" if start.text == "{" else "end"; var params: Array = []
	_separators(); var rest_parameter := ""
	if _accept("|"):
		while _peek().text != "|" and _errors.is_empty():
			var rest := _accept("*"); var parameter: String = _take().text; params.append(parameter)
			if rest: rest_parameter = parameter
			if not _accept(","): break
		_expect("|")
	_separators(); var body := _body([close]); _expect(close)
	var call := _as_call(expression,expression.get("arguments",[]))
	call.block = _node("block",start,{"parameters":params,"body":body,"rest_parameter":rest_parameter}); return call

func _constant_path() -> String:
	var token := _take(); var result: String = token.text
	if token.kind!="identifier" or result.is_empty() or result[0]==result[0].to_lower(): _error(token,"constant","类/模块名称必须为常量名称。")
	while _accept("::"):
		token = _take()
		if token.kind!="identifier" or token.text.is_empty() or token.text[0]==token.text[0].to_lower(): _error(token,"constant","常量路径中的名称无效。")
		result += "::"+token.text
	return result

func _method_name(allow_assignment: bool = true) -> String:
	var token := _take(); var result: String = str(token.value) if token.kind == "symbol" else str(token.text)
	if result == "[": _expect("]"); result = "[]"
	if allow_assignment and _accept("="): result += "="
	return result

func _starts_expression(token: Dictionary) -> bool:
	return token.kind in ["number","big_integer","string","words","regex","symbol","global","instance"] or token.kind == "identifier" and token.text not in ["end","else","elsif","ensure","rescue","when","then","do","in","if","unless","while","until","and","or"] or token.text in ["(","[","{","!","~"]

func _header() -> void:
	if _peek().kind not in ["separator","eof"]: _error(_peek(),"header","块头之后需要换行或分号。")
	_separators()

func _separators() -> void:
	while _peek().kind == "separator": _cursor += 1

func _peek() -> Dictionary:
	return _tokens[mini(_cursor,_tokens.size()-1)]

func _take() -> Dictionary:
	var token := _peek(); _cursor += 1; return token

func _accept(text: String) -> bool:
	if _peek().text != text: return false
	_cursor += 1; return true

func _expect(text: String) -> void:
	if not _accept(text): _error(_peek(),"syntax","需要 '%s'，得到 '%s'。" % [text,_peek().text])

func _span(start: Dictionary, end: Dictionary) -> Dictionary:
	return {"line":start.line,"column":start.column,"end_line":end.get("end_line",end.line),"end_column":end.get("end_column",end.column)}

func _node(kind: String, start: Dictionary, fields: Dictionary = {}) -> Dictionary:
	return {"kind":kind,"span":_span(start,_tokens[maxi(0,mini(_cursor-1,_tokens.size()-1))])}.merged(fields)

func _relocate(value: Variant, point: Dictionary) -> void:
	if value is Dictionary:
		if value.has("span"):
			var span: Dictionary = value.span
			if span.line == 1: span.column += point.column-1
			if span.end_line == 1: span.end_column += point.column-1
			span.line += point.line-1; span.end_line += point.line-1
		for key in value:
			if key != "span": _relocate(value[key],point)
	elif value is Array:
		for item in value: _relocate(item,point)

func _error(token: Dictionary, code: String, message: String) -> void:
	if _errors.is_empty(): _errors.append({"stage":"parse","code":code,"message":message,"line":token.line,"column":token.column})

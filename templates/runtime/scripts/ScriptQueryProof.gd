extends RefCounted
## Conservative effect proof only. Execution always calls generated GDScript.
static func plan(unit: Dictionary) -> Dictionary:
	if int(unit.get("origin",{}).get("command_code",0)) not in [111,355]: return {}
	var ast: Variant=unit.get("ast")
	if not ast is Dictionary or not ast.get("body") is Array: return {}
	var body: Array=ast.body
	if body.size()!=1 or not body[0] is Dictionary: return {}
	var node: Dictionary=body[0]
	if _expression(node): return {"kind":"expression"}
	if node.get("kind")!="if" or not node.get("else_body",[]).is_empty(): return {}
	var branches: Array=node.get("branches",[])
	if branches.size()!=1 or not _expression(branches[0].get("condition",{})): return {}
	var span: Dictionary=node.get("span",{})
	if int(span.get("line",0))<1: return {}
	var statements: Array=branches[0].get("body",[])
	if not statements.is_empty() and statements[0].get("kind") not in ["assign","call"]: return {}
	# The compiler emits tick before each statement. Stop before entering a
	# matched body and retry it through the ordinary, complete transaction.
	for statement in statements:
		if statement.get("span",{})==span or int(statement.get("span",{}).get("line",0))<1: return {}
	return {"kind":"guard","span":span}

static func _expression(node: Dictionary) -> bool:
	if node.get("kind")=="literal": return typeof(node.get("value"))<=TYPE_STRING
	if _temp_getter(node) or _event_name(node): return true
	if _map_check(node): return true
	if node.get("kind")=="unary" and node.get("operator")=="!": return _map_check(node.get("value",{}))
	if node.get("kind")=="index" and _event_name(node.get("receiver",{})):
		var arguments: Array=node.get("arguments",[])
		if arguments.size()!=1 or arguments[0].get("kind")!="regex": return false
		for part in arguments[0].get("parts",[]):
			if part.get("kind")!="text": return false
		return true
	if node.get("kind")=="binary" and node.get("operator") in ["==","!=","<",">","<=",">="]:
		return _temp_getter(node.get("left",{})) and node.get("right",{}).get("kind")=="literal"
	return false

static func _temp_getter(node: Dictionary) -> bool:
	return _call(node) and node.get("receiver",{}).get("kind")=="name" and node.receiver.get("name")=="$game_temp" and not str(node.get("name","")).ends_with("=") and node.get("name") not in ["attr_addition_clear","puts_start","puts_end"]

static func _event_name(node: Dictionary) -> bool:
	if not _call(node) or node.get("name")!="name": return false
	var event: Dictionary=node.get("receiver",{})
	return _call(event) and event.get("name")=="event" and event.get("receiver",{}).get("kind")=="name" and event.receiver.get("name")=="_this"

static func _call(node: Dictionary) -> bool:
	return node.get("kind")=="call" and node.get("arguments",[]).is_empty() and node.get("block",{}).is_empty()

static func _coordinate(node: Dictionary) -> bool:
	if _call(node) and node.get("name") in ["x","y"] and node.get("receiver",{}).get("kind")=="name" and node.receiver.get("name")=="_this": return true
	return node.get("kind")=="binary" and node.get("operator") in ["+","-"] and _coordinate(node.get("left",{})) and node.get("right",{}).get("kind")=="literal" and (node.right.get("value") is int or node.right.get("value") is float)

static func _map_check(node: Dictionary) -> bool:
	if node.get("kind")!="call" or node.get("name")!="check_event" or not node.get("block",{}).is_empty(): return false
	if node.get("receiver",{}).get("kind")!="name" or node.receiver.get("name")!="$game_map": return false
	var arguments: Array=node.get("arguments",[])
	if arguments.size() not in [2,3] or not _coordinate(arguments[0]) or not _coordinate(arguments[1]): return false
	if arguments.size()==2: return true
	if arguments[2].get("kind")=="literal": return arguments[2].get("value") is String
	if arguments[2].get("kind")!="regex": return false
	for part in arguments[2].get("parts",[]):
		if part.get("kind")!="text": return false
	return true

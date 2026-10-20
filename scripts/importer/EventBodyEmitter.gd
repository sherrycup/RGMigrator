## 职责：把已解析事件 AST 生成为实际执行的可读 GDScript 业务正文，不向事件复制转换器执行模板。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/EventBodyEmitter.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func emit(ast: Dictionary) -> Dictionary
##     参数 ast（Dictionary；必填）：带来源范围的 Ruby 抽象语法树。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：OBJECTS、METHODS、ACTIONS。
## 接口说明结束。

extends RefCounted
var _lines: Array[String] = []
var _declared: Dictionary = {}
var _locals: Dictionary = {}
var _errors: Array[String] = []
var _counter = 0
const OBJECTS = {
	"$game_temp": "ctx.temp",
	"$game_system": "ctx.system",
	"$game_party": "ctx.party",
	"$game_actors": "ctx.actors",
	"$game_variables": "ctx.variables",
	"$game_self_switches": "ctx.self_switches",
	"$game_map": "ctx.game_map",
	"$game_player": "ctx.player",
	"$data_enemies": "ctx.enemies",
	"_this": "ctx.event",
	"_main_actor": "ctx.main_actor",
	"_attack_actor": "ctx.attack_actor",
	"_map": "ctx.game_map",
	"_ss": "ctx.self_switches",
	"_v": "ctx.variables",
	"GameEngine::Screen": "ctx.screen",
	"Actor_Init": "Actor_Init",
	"Storage": "ctx.storage"
}
const METHODS = {
	"begin_battle!": "begin_battle",
	"finish_battle!": "finish_battle",
	"dead?": "is_dead",
	"box_in_place?": "is_box_in_place",
	"int": "intelligence",
	"Voiceover": "voiceover",
	"Unravel": "unravel"
}
const ACTIONS = [
	"refresh",
	"refresh_damage",
	"attr_addition_clear",
	"erase",
	"die",
	"move_down",
	"move_left",
	"move_right",
	"move_up",
	"wake",
	"freeze",
	"Unravel",
	"Voiceover",
	"begin_battle!",
	"finish_battle!",
	"dead?",
	"box_in_place?"
]


func emit(ast: Dictionary) -> Dictionary:
	_lines = []
	_declared = {}
	_locals = {}
	_errors = []
	_counter = 0
	_collect(ast)
	_body(ast.get("body", []), 0, true)
	return {"ok": _errors.is_empty(), "source": "\n".join(_lines) + "\n", "errors": _errors}


func _collect(value: Variant) -> void:
	if value is Array:
		for item in value:
			_collect(item)
	elif value is Dictionary:
		if (
			value.get("kind") == "assign"
			and value.left.get("kind") == "name"
			and value.left.get("scope") == "identifier"
		):
			_locals[value.left.name] = true
		if value.get("kind") == "for":
			_locals[value.target] = true
		if value.get("kind") == "block":
			for name in value.parameters:
				_locals[name] = true
		for key in value:
			if key != "origin":
				_collect(value[key])


func _line(text: String, depth: int) -> void:
	_lines.append("\t".repeat(depth) + text)


func _body(nodes: Array, depth: int, tail: bool) -> void:
	if nodes.is_empty():
		_line("return null" if tail else "pass", depth)
		return
	for index in nodes.size():
		_statement(nodes[index], depth, tail and index == nodes.size() - 1)


func _statement(node: Dictionary, depth: int, tail: bool) -> void:
	match node.kind:
		"if":
			for index in node.branches.size():
				var branch: Dictionary = node.branches[index]
				_line(
					(
						("if " if index == 0 else "elif ")
						+ "ctx.api.truth("
						+ _expr(branch.condition)
						+ "):"
					),
					depth
				)
				_body(branch.body, depth + 1, tail)
			if not node.get("else_body", []).is_empty() or tail:
				_line("else:", depth)
				_body(node.get("else_body", []), depth + 1, tail)
		"modifier":
			_line(
				(
					"if "
					+ ("not " if node.operator == "unless" else "")
					+ "ctx.api.truth("
					+ _expr(node.condition)
					+ "):"
				),
				depth
			)
			_body(node.body, depth + 1, tail)
			if tail:
				_line("return null", depth)
		"case":
			_line("match " + _expr(node.value) + ":", depth)
			for branch in node.branches:
				var patterns: Array[String] = []
				for pattern in branch.patterns:
					patterns.append(_expr(pattern))
				_line(", ".join(patterns) + ":", depth + 1)
				_body(branch.body, depth + 2, tail)
			if tail:
				_line("_:", depth + 1)
				_line("return null", depth + 2)
		"for":
			_declared[node.target] = true
			_line(
				"for " + node.target + " in ctx.api.iterable(" + _expr(node.iterator) + "):", depth
			)
			_body(node.body, depth + 1, false)
			if tail:
				_line("return " + _expr(node.iterator), depth)
		"assign":
			_assignment(node, depth, tail)
		"call":
			if not node.get("block", {}).is_empty():
				var name = "entry_%d" % _counter
				_counter += 1
				_line("for " + name + " in ctx.api.iterable(" + _expr(node.receiver) + "):", depth)
				for index in node.block.parameters.size():
					var parameter: String = node.block.parameters[index]
					_line(
						(
							"var "
							+ parameter
							+ ": Variant = "
							+ (
								name + ".at(%d)" % index
								if node.block.parameters.size() > 1
								else name
							)
						),
						depth + 1
					)
					_declared[parameter] = true
				_body(node.block.body, depth + 1, false)
				if tail:
					_line("return " + _expr(node.receiver), depth)
			else:
				var code = _expr(node)
				var actor_load = node.receiver.get("name") == "Actor_Init" and node.name == "load"
				_line(("return " if tail and not actor_load else "") + code, depth)
		_:
			_line(("return " if tail else "") + _expr(node), depth)


func _assignment(node: Dictionary, depth: int, tail: bool) -> void:
	var left: Dictionary = node.left
	var value = _expr(node.right)
	if node.operator != "=":
		value = (
			"ctx.api.binary(%s, %s, %s)"
			% [JSON.stringify(str(node.operator).trim_suffix("=")), _expr(left), value]
		)
	var saved = ""
	if tail:
		saved = "assigned_%d" % _counter
		_counter += 1
		_line("var " + saved + ": Variant = " + value, depth)
		value = saved
	if left.kind == "name":
		if _locals.has(left.name):
			_line(
				(
					("" if _declared.has(left.name) else "var ")
					+ str(left.name)
					+ ("" if _declared.has(left.name) else ": Variant")
					+ " = "
					+ value
				),
				depth
			)
			_declared[left.name] = true
		else:
			_line("ctx.api.write(%s, %s)" % [JSON.stringify(left.name), value], depth)
	elif left.kind == "call":
		_line(
			_expr(left.receiver) + "." + str(METHODS.get(left.name, left.name)) + " = " + value,
			depth
		)
	elif left.kind == "index":
		_line(_expr(left.receiver) + ".put(" + _expr(left.arguments[0]) + ", " + value + ")", depth)
	else:
		_errors.append("不支持的赋值目标：" + str(left.kind))
	if tail:
		_line("return " + saved, depth)


func _expr(node: Dictionary) -> String:
	if node.is_empty():
		return "null"
	match node.kind:
		"literal":
			if (
				node.value is float
				and node.value == floor(node.value)
				and abs(node.value) <= 9007199254740991
			):
				return str(int(node.value))
			return JSON.stringify(node.value)
		"name":
			if _locals.has(node.name):
				return str(node.name)
			if node.name == "@event_id":
				return "ctx.event_id"
			return OBJECTS.get(node.name, "ctx.api.named(" + JSON.stringify(node.name) + ")")
		"array":
			var parts: Array[String] = []
			for item in node.elements:
				parts.append(_expr(item))
			return "[" + ", ".join(parts) + "]"
		"hash":
			if not node.pairs.is_empty():
				_errors.append("非空散列表正文需要显式映射")
			return "{}"
		"string", "regex":
			var parts: Array[String] = []
			for part in node.parts:
				parts.append(
					(
						JSON.stringify(part.value)
						if part.kind == "text"
						else "ctx.api.text(" + _expr(part.value) + ")"
					)
				)
			var text = " + ".join(parts) if not parts.is_empty() else '\"\"'
			return (
				"ctx.api.regex(" + text + ", " + JSON.stringify(node.flags) + ")"
				if node.kind == "regex"
				else text
			)
		"index":
			var args: Array[String] = []
			for item in node.arguments:
				args.append(_expr(item))
			return "ctx.api.at(" + _expr(node.receiver) + ", [" + ", ".join(args) + "])"
		"binary":
			if node.operator in ["&&", "||"]:
				return (
					"(ctx.api.truth(%s) %s ctx.api.truth(%s))"
					% [
						_expr(node.left),
						"and" if node.operator == "&&" else "or",
						_expr(node.right)
					]
				)
			var math_name: String = (
				{
					"+": "add",
					"-": "subtract",
					"*": "multiply",
					">": "greater",
					">=": "at_least",
					"==": "equal",
					"===": "case_equal"
				}
				. get(node.operator, "")
			)
			return (
				"ctx.api.%s(%s, %s)" % [math_name, _expr(node.left), _expr(node.right)]
				if not math_name.is_empty()
				else (
					"ctx.api.binary(%s, %s, %s)"
					% [JSON.stringify(node.operator), _expr(node.left), _expr(node.right)]
				)
			)
		"unary":
			return (
				"not ctx.api.truth(" + _expr(node.value) + ")"
				if node.operator == "!"
				else (
					'ctx.api.operation("unary", [%s, %s])'
					% [JSON.stringify(node.operator), _expr(node.value)]
				)
			)
		"range":
			return (
				"range(%s, %s%s)"
				% [_expr(node.left), _expr(node.right), " + 1" if node.operator == ".." else ""]
			)
		"ternary":
			return (
				"(%s if ctx.api.truth(%s) else %s)"
				% [_expr(node.yes), _expr(node.condition), _expr(node.no)]
			)
		"call":
			return _call(node)
	_errors.append("不支持的事件正文节点：" + str(node.kind))
	return "null"


func _call(node: Dictionary) -> String:
	var receiver = _expr(node.receiver)
	var args: Array[String] = []
	for item in node.arguments:
		args.append(_expr(item))
	if node.receiver.is_empty():
		if node.name == "eval":
			var parts: Array = node.arguments[0].get("parts", [])
			if parts.size() == 5:
				return (
					'ctx.api.invoke(ctx.api.attribute(%s), "plus", [%s])'
					% [_expr(parts[1].value), _expr(parts[3].value)]
				)
			if parts.size() == 3:
				return "ctx.api.set_attribute(%s, new_attr)" % _expr(parts[1].value)
			return "ctx.api.name_value(" + args[0] + ")"
		return "ctx.api.root_call(%s, [%s])" % [JSON.stringify(node.name), ", ".join(args)]
	match node.name:
		"to_i":
			return "ctx.api.integer(" + receiver + ")"
		"to_s":
			return "ctx.api.text(" + receiver + ")"
		"include?":
			return "ctx.api.contains(" + receiver + ", " + args[0] + ")"
		"max":
			return "ctx.api.maximum(" + receiver + ")"
		"split":
			return "ctx.api.split(" + receiver + ", " + args[0] + ")"
		"new":
			return "ctx.api.invoke(" + receiver + ', "new", [' + ", ".join(args) + "])"
	var method: String = METHODS.get(node.name, node.name)
	if args.is_empty() and node.name not in ACTIONS:
		return receiver + "." + method
	return receiver + "." + method + "(" + ", ".join(args) + ")"

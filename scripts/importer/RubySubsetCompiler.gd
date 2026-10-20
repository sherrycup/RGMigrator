## 职责：提供受支持 Ruby 子集的编译入口，汇总语义信息、生成代码和失败诊断。
##
## 调用方式：
##   迁移器及编辑器重新转换使用的严格编译服务；原 Ruby 只读解析，不执行。
##
## 调用接口：
##   func compile(source: String, origin: Dictionary = {}) -> Dictionary
##     用途：解析原脚本并生成可执行 GDScript。
##     参数 source（String；必填）：完整原 Ruby 工作源码。
##     参数 origin（Dictionary；默认值 {}）：脚本槽位或事件/路线来源记录。
##     返回：包含 ok、generated_source、diagnostics、AST/IR 或来源映射等本编译器实际提供的字段。
##
## 公开常量：FORMAT。
## 接口说明结束。

extends RefCounted
## Strict 0.40 subset. No Ruby execution and no partial generation on failure.
const FORMAT := "rgm-ruby-subset-v1"
var _tokens: Array[Dictionary] = []
var _cursor := 0
var _origin: Dictionary = {}
var _diagnostics: Array[Dictionary] = []


func compile(source: String, origin: Dictionary = {}) -> Dictionary:
	_origin = origin.duplicate(true)
	_tokens.clear()
	_diagnostics.clear()
	_cursor = 0
	_lex(source.replace("\r\n", "\n").replace("\r", "\n"))
	var statements: Array = []
	while _diagnostics.is_empty() and _peek().kind != "eof":
		if _peek().kind == "separator":
			_cursor += 1
			continue
		var start := _take()
		if start.kind != "global" or start.text not in ["$game_variables", "$game_switches"]:
			_error(start, "unsupported_target", "0.40仅转换 $game_variables / $game_switches 的常量下标赋值。")
			break
		if not _expect("["):
			break
		var index := _take()
		if (
			index.kind != "integer"
			or not index.text.is_valid_int()
			or index.text.begins_with("0")
			or index.text.length() > 10
			or int(index.text) <= 0
			or int(index.text) > 2147483647
		):
			_error(index, "unsupported_index", "下标必须是1..2147483647的十进制整数常量。")
			break
		if not _expect("]"):
			break
		var op := _take()
		if op.text not in ["=", "+=", "-="]:
			_error(op, "unsupported_operator", "赋值仅支持 =、+=、-=。")
			break
		var literal := _take()
		var sign_value := 1
		var signed_literal := false
		if literal.text in ["+", "-"]:
			signed_literal = true
			sign_value = -1 if literal.text == "-" else 1
			literal = _take()
		var value: Variant
		var kind := "variable" if start.text == "$game_variables" else "switch"
		if kind == "switch":
			if literal.text not in ["true", "false"] or signed_literal or op.text != "=":
				_error(literal, "unsupported_value", "开关仅支持 = true / false。")
				break
			value = literal.text == "true"
		else:
			if (
				literal.kind != "integer"
				or not literal.text.is_valid_int()
				or literal.text.length() > 1 and literal.text.begins_with("0")
				or literal.text.length() > 10
				or int(literal.text) > 2147483647
			):
				_error(literal, "unsupported_value", "变量仅支持绝对值不超过2147483647的十进制整数常量。")
				break
			value = int(literal.text) * sign_value
		if _peek().kind not in ["separator", "eof"]:
			_error(_peek(), "unsupported_expression", "此处存在尚未支持的表达式或语句；整段不生成。")
			break
		statements.append(
			{
				"kind": "indexed_assignment",
				"target": kind,
				"id": int(index.text),
				"operator": op.text,
				"value": value,
				"span":
				{
					"line": start.line,
					"column": start.column,
					"end_line": literal.line,
					"end_column": literal.column + literal.text.length()
				}
			}
		)
	var ast := {"kind": "program", "format": FORMAT, "origin": _origin, "statements": statements}
	if not _diagnostics.is_empty():
		return {
			"ok": false,
			"ast": ast,
			"ir": [],
			"generated_source": "",
			"diagnostics": _diagnostics.duplicate(true)
		}
	var ir: Array = []
	for node in statements:
		ir.append(
			{
				"operation": "state_write",
				"target": node.target,
				"id": node.id,
				"operator": node.operator,
				"value": node.value,
				"span": node.span
			}
		)
	var generated := (
		'extends RefCounted\nconst Bridge = preload("res://runtime/scripts/10_Support/Scripting/ScriptStateBridge.gd")\n\nstatic func execute(state: Object) -> Dictionary:\n\treturn Bridge.apply(state, %s, %s)\n'
		% [_gd_literal(ir), _gd_literal(_origin)]
	)
	return {
		"ok": true,
		"empty": statements.is_empty(),
		"ast": ast,
		"ir": ir,
		"generated_source": generated,
		"diagnostics": []
	}


func _gd_literal(value: Variant) -> String:
	# JSON's true/false are valid GDScript; this subset never emits JSON null.
	return JSON.stringify(value, "", false, true)


func _peek() -> Dictionary:
	return _tokens[mini(_cursor, _tokens.size() - 1)]


func _take() -> Dictionary:
	var token := _peek()
	_cursor += 1
	return token


func _expect(text: String) -> bool:
	var token := _take()
	if token.text == text:
		return true
	_error(token, "syntax", "需要 '%s'，得到 '%s'。" % [text, token.text])
	return false


func _error(token: Dictionary, code: String, message: String) -> void:
	_diagnostics.append(
		{
			"code": code,
			"message": message,
			"line": token.line,
			"column": token.column,
			"token": token.text,
			"origin": _origin.duplicate(true)
		}
	)


func _lex(source: String) -> void:
	var index := 0
	var line := 1
	var column := 1
	while index < source.length():
		var c := source[index]
		if c in [" ", "\t"]:
			index += 1
			column += 1
			continue
		if c == "#":
			while index < source.length() and source[index] != "\n":
				index += 1
				column += 1
			continue
		var start := index
		var start_column := column
		var kind := "symbol"
		if c == "\n" or c == ";":
			kind = "separator"
			index += 1
		elif c == "$" or c == "_" or c.to_lower() >= "a" and c.to_lower() <= "z":
			kind = "global" if c == "$" else "identifier"
			index += 1
			while (
				index < source.length()
				and (
					source[index] == "_"
					or source[index].to_lower() >= "a" and source[index].to_lower() <= "z"
					or source[index] >= "0" and source[index] <= "9"
				)
			):
				index += 1
		elif c >= "0" and c <= "9":
			kind = "integer"
			index += 1
			while index < source.length() and source[index] >= "0" and source[index] <= "9":
				index += 1
		else:
			index += 1
			if c in ["+", "-"] and index < source.length() and source[index] == "=":
				index += 1
		_tokens.append(
			{
				"kind": kind,
				"text": source.substr(start, index - start),
				"line": line,
				"column": start_column
			}
		)
		if c == "\n":
			line += 1
			column = 1
		else:
			column += index - start
	_tokens.append({"kind": "eof", "text": "<EOF>", "line": line, "column": column})

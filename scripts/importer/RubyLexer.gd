## 职责：将 Ruby 源码切分为带字符位置的词法单元，保留注释、字面量及扫描诊断。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/RubyLexer.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func tokenize(source: String) -> Dictionary
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：FORMAT、OPERATORS。
## 接口说明结束。

extends RefCounted
## Unicode positions are one based; offsets count characters, not UTF-8 bytes.
const FORMAT := "rgm-ruby-tokens-v2"
const OPERATORS := [
	"<=>",
	"===",
	"**=",
	"<<=",
	">>=",
	"&&=",
	"||=",
	"...",
	"==",
	"!=",
	"<=",
	">=",
	"=~",
	"!~",
	"=>",
	"::",
	"**",
	"<<",
	">>",
	"&&",
	"||",
	"+=",
	"-=",
	"*=",
	"/=",
	"%=",
	"&=",
	"|=",
	"^=",
	"..",
	"+@",
	"-@"
]
var _source := ""
var _offset := 0
var _line := 1
var _column := 1
var _tokens: Array = []
var _errors: Array = []
var _names := RegEx.new()


func tokenize(source: String) -> Dictionary:
	_source = source.replace("\r\n", "\n").replace("\r", "\n")
	_offset = 0
	_line = 1
	_column = 1
	_tokens = []
	_errors = []
	_names.compile("^[\\p{L}\\p{N}_]$")
	while _offset < _source.length() and _errors.is_empty():
		var c := _at()
		var start := _mark()
		if c in [" ", "\t", "\uFEFF"]:
			_advance()
			continue
		if c == "\\" and _at(1) == "\n":
			_advance()
			_advance()
			continue
		if c == "#":
			while _at() not in ["", "\n"]:
				_advance()
			continue
		if _column == 1 and _source.substr(_offset, 6) == "=begin":
			var closed := false
			while _offset < _source.length():
				if _column == 1 and _source.substr(_offset, 4) == "=end":
					closed = true
					while _at() not in ["", "\n"]:
						_advance()
					break
				_advance()
			if not closed:
				_error(start, "unclosed_comment", "缺少 =end。")
			continue
		if c in ["\n", ";"]:
			_advance()
			_emit("separator", start)
			continue
		if c in ["'", '"']:
			_advance()
			_quoted(start, c, c, "string", c == '"')
			continue
		if (
			c == "%"
			and _at(1) in ["q", "Q", "w", "W", "r"]
			and _at(2) in ["(", "[", "{", "<", "/", "!"]
		):
			var mode := _at(1)
			_advance()
			_advance()
			var opener := _at()
			_advance()
			var closer: String = {"(": ")", "[": "]", "{": "}", "<": ">"}.get(opener, opener)
			_quoted(
				start,
				opener,
				closer,
				"words" if mode in ["w", "W"] else ("regex" if mode == "r" else "string"),
				mode in ["Q", "W", "r"]
			)
			continue
		if c == "/" and _regex_position():
			_advance()
			_quoted(start, "/", "/", "regex", true)
			continue
		if c == ":" and _at(1) != ":" and _name_start(_at(1)):
			_advance()
			_identifier()
			if _at() == "=" and _at(1) not in [">", "=", "~"]:
				_advance()
			_emit("symbol", start, _source.substr(start.offset + 1, _offset - start.offset - 1))
			continue
		if (
			c == ":"
			and _at(1) == "@"
			and (_name_start(_at(2)) or _at(2) == "@" and _name_start(_at(3)))
		):
			_advance()
			_advance()
			if _at() == "@":
				_advance()
			_identifier()
			_emit("symbol", start, _source.substr(start.offset + 1, _offset - start.offset - 1))
			continue
		if c == ":" and _at(1) != ":":
			var symbol_operator := ""
			for candidate in [
				"[]=",
				"[]",
				"<=>",
				"===",
				"==",
				"=~",
				"!~",
				"!=",
				"<=",
				">=",
				"<<",
				">>",
				"+@",
				"-@",
				"**",
				"+",
				"-",
				"*",
				"/",
				"%",
				"<",
				">",
				"!",
				"~",
				"&",
				"|",
				"^"
			]:
				if _source.substr(_offset + 1, candidate.length()) == candidate:
					symbol_operator = candidate
					break
			if not symbol_operator.is_empty():
				for ignored in symbol_operator.length() + 1:
					_advance()
				_emit("symbol", start, symbol_operator)
				continue
		if c in ["$", "@"] or _name_start(c):
			if c in ["$", "@"]:
				_advance()
				if c == "@" and _at() == "@":
					_advance()
			if (
				c == "$"
				and (_at() >= "0" and _at() <= "9" or _at() in ["~", "&", "`", "'", "+", "!"])
			):
				while _at() >= "0" and _at() <= "9":
					_advance()
				if _offset == start.offset + 1:
					_advance()
				_emit("global", start)
				continue
			if not _name_start(_at()):
				_error(start, "special_variable", "尚未支持特殊全局变量。")
				continue
			_identifier()
			_emit("global" if c == "$" else ("instance" if c == "@" else "identifier"), start)
			continue
		if c >= "0" and c <= "9":
			_advance()
			while _at() != "" and (_names.search(_at()) != null):
				_advance()
			if _at() == "." and _at(1) >= "0" and _at(1) <= "9":
				_advance()
				while _at() >= "0" and _at() <= "9" or _at() == "_":
					_advance()
			var raw := _source.substr(start.offset, _offset - start.offset).replace("_", "")
			if raw.begins_with("0x") or raw.begins_with("0X"):
				var hex := RegEx.new()
				hex.compile("^0[xX][0-9a-fA-F]+$")
				if hex.search(raw) == null:
					_error(start, "number", "无效的十六进制整数。")
				elif raw.length() > 17:
					_emit("big_integer", start, raw)
				else:
					_emit("number", start, raw.hex_to_int())
			elif raw.is_valid_int() and (raw.length() == 1 or not raw.begins_with("0")):
				if raw.length() > 18:
					_emit("big_integer", start, raw)
				else:
					_emit("number", start, int(raw))
			elif raw.is_valid_float() and raw.contains("."):
				_emit("number", start, float(raw))
			else:
				_error(start, "number", "尚未支持或无效的数值字面量。")
			continue
		var found := false
		for op in OPERATORS:
			if op in ["+@", "-@"] and (_name_start(_at(2)) or _at(2) == "@"):
				continue
			if _source.substr(_offset, op.length()) == op:
				for ignored in op.length():
					_advance()
				_emit("operator", start)
				found = true
				break
		if found:
			continue
		if (
			c
			in [
				"(",
				")",
				"[",
				"]",
				"{",
				"}",
				",",
				".",
				":",
				"?",
				"=",
				"+",
				"-",
				"*",
				"/",
				"%",
				"<",
				">",
				"!",
				"~",
				"&",
				"|",
				"^"
			]
		):
			_advance()
			_emit("operator", start)
			continue
		_error(start, "character", "尚未支持的字符：" + c)
	_emit("eof", _mark())
	return {"ok": _errors.is_empty(), "tokens": _tokens, "diagnostics": _errors, "source": _source}


func _quoted(
	start: Dictionary, opener: String, closer: String, kind: String, interpolate: bool
) -> void:
	var parts: Array = []
	var content := ""
	var nesting := 0
	while _offset < _source.length():
		var c := _at()
		if c == closer and nesting == 0:
			_advance()
			parts.append({"kind": "text", "value": content})
			var flags := ""
			if kind == "regex":
				while _at() in ["i", "m", "x", "o"]:
					flags += _at()
					_advance()
			_emit(kind, start, {"parts": parts, "flags": flags})
			return
		if c == "\\":
			_advance()
			var escaped := _at()
			if escaped == "":
				break
			if kind == "words" and escaped in [" ", "\n", "\t"]:
				_error(_mark(), "word_escape", "带转义空白的词数组尚未解析。")
				return
			if kind == "regex":
				content += "\\" + escaped
			elif interpolate:
				if escaped in ["c", "C", "M", "x", "u"] or escaped >= "0" and escaped <= "7":
					_error(_mark(), "escape", "该转义序列尚未解析；不会按普通字符生成。")
					return
				content += str(
					(
						{
							"n": "\n",
							"r": "\r",
							"t": "\t",
							"b": "\b",
							"f": "\f",
							"v": "\u000b",
							"a": "\u0007",
							"e": "\u001b",
							"\n": ""
						}
						. get(escaped, escaped)
					)
				)
			elif escaped in ["\\", closer]:
				content += escaped
			else:
				content += "\\" + escaped
			_advance()
			continue
		if interpolate and c == "#" and _at(1) == "{":
			parts.append({"kind": "text", "value": content})
			content = ""
			_advance()
			_advance()
			var point := _mark()
			var expression := ""
			var depth := 1
			var quote := ""
			while _offset < _source.length():
				c = _at()
				if not quote.is_empty():
					if c == "\\":
						expression += c
						_advance()
						c = _at()
					elif c == quote:
						quote = ""
				elif c in ["'", '"']:
					quote = c
				elif c == "{":
					depth += 1
				elif c == "}":
					depth -= 1
					if depth == 0:
						_advance()
						break
				expression += c
				_advance()
			if depth != 0:
				_error(point, "interpolation", "字符串插值缺少结束括号。")
				return
			parts.append({"kind": "expression", "source": expression, "position": point})
			continue
		if opener != closer and c == opener:
			nesting += 1
		elif opener != closer and c == closer:
			nesting -= 1
		content += c
		_advance()
	_error(start, "unclosed_literal", "字符串/正则字面量未闭合。")


func _regex_position() -> bool:
	if _tokens.is_empty():
		return true
	var previous: Dictionary = _tokens.back()
	return (
		previous.kind == "separator"
		or (
			previous.text
			in ["=", "(", "[", ",", "=>", "=~", "!~", "return", "when", "if", "unless", "&&", "||"]
		)
	)


func _identifier() -> void:
	while _at() != "" and _names.search(_at()) != null:
		_advance()
	if _at() in ["?", "!"] and _at(1) != "=":
		_advance()


func _name_start(c: String) -> bool:
	return not c.is_empty() and not (c >= "0" and c <= "9") and _names.search(c) != null


func _at(ahead: int = 0) -> String:
	return _source.substr(_offset + ahead, 1)


func _advance() -> void:
	if _at() == "\n":
		_line += 1
		_column = 1
	else:
		_column += 1
	_offset += 1


func _mark() -> Dictionary:
	return {"offset": _offset, "line": _line, "column": _column}


func _emit(kind: String, start: Dictionary, value: Variant = null) -> void:
	_tokens.append(
		{
			"kind": kind,
			"text": _source.substr(start.offset, _offset - start.offset),
			"value": value,
			"offset": start.offset,
			"line": start.line,
			"column": start.column,
			"end_line": _line,
			"end_column": _column
		}
	)


func _error(start: Dictionary, code: String, message: String) -> void:
	_errors.append(
		{
			"stage": "lex",
			"code": code,
			"message": message,
			"line": start.line,
			"column": start.column
		}
	)

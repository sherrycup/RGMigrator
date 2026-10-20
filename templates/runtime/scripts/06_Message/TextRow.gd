## 职责：维护闪翼单行文本的字词、样式和绘制信息。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/06_Message/TextRow.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/06_Message/TextRow.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(raw: String, state: Object) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 raw（String；必填）：尚未解释的原始值或文本。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func getchar() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func peer() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func shift(amount: int = 1) -> int
##     参数 amount（int；默认值 1）：需要增加、扣除或应用的数量。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func goto_head() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func goto_tail() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func eof() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func invoke(custom: RefCounted, ref: Dictionary, name: String, args: Array) -> Variant
##     用途：按给定名称和参数分派对应调用。
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 ref（Dictionary；必填）：待查询或修改的脚本对象引用。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 args（Array；必填）：按调用顺序排列的参数值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted
## Source 0151 cursor and 0149 row width/height; mutable cursor is per row.
const Text = preload("MessageText.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const TextLayout = preload("../04_UI_Common/UITextLayout.gd")
var text = ""
var halign = 0
var valign = 2
var text_width = 0.0
var text_height = 20.0
var line_space = 4
var tokens: Array = []
var cursor = 0
var failure = ""


class Context:
	extends RefCounted
	var custom_data: RefCounted
	var variables: Dictionary

	func actor(id: int) -> RefCounted:
		return custom_data.staged_actor(id)


func _init(raw: String, state: Object) -> void:
	var parsed = Text.parse(raw, state, false)
	if not parsed.ok:
		failure = parsed.message
		return
	var style = Text.defaults()
	for token in parsed.tokens:
		if token is Array and token[0].unicode_at(0) in [27, 28]:
			Text.apply_style(style, token)
			continue
		tokens.append(token)
		text += (
			token
			if token is String
			else (
				token[0]
				+ (
					"[" + (",".join(token.slice(1).map(func(value): return str(value)))) + "]"
					if token.size() > 1
					else ""
				)
			)
		)
	halign = style.halign
	valign = style.valign
	line_space = style.line_space
	var maximum = 0.0
	for token in tokens:
		var glyph = ""
		if token is String:
			glyph = token
		else:
			var code = token[0].unicode_at(0)
			if code == 17:
				break
			if code == 2:
				glyph = str(state.custom_data.currency()) + _gold_word()
			elif code == 22:
				text_width += int(token[1])
			elif code == 24:
				var name = str(token[1])
				var icon = Cache.icon(name)
				if icon == null and not name.is_empty():
					failure = "消息图标缺失：" + name
					return
				text_width += icon.get_width() + 4 if icon != null else 36
				maximum = maxf(maximum, icon.get_height() if icon != null else 32)
			else:
				Text.apply_style(style, token)
		if not glyph.is_empty():
			var measured = TextLayout.measure(glyph, style)
			text_width += measured.x
			maximum = maxf(maximum, measured.y)
	text_height = maximum


func _gold_word() -> String:
	return str(preload("../00_Game/RuntimeData.gd").system().get("words", {}).get("gold", ""))


func getchar() -> Variant:
	if eof():
		return null
	cursor += 1
	return tokens[cursor - 1]


func peer() -> Variant:
	return tokens[cursor] if cursor < tokens.size() else null


func shift(amount: int = 1) -> int:
	cursor = clampi(cursor + amount, 0, tokens.size())
	return cursor


func goto_head() -> void:
	cursor = 0


func goto_tail() -> void:
	cursor = tokens.size()


func eof() -> bool:
	return cursor >= tokens.size()


func snapshot() -> Dictionary:
	return {
		"text": text,
		"halign": halign,
		"valign": valign,
		"text_width": text_width,
		"text_height": text_height,
		"line_space": line_space,
		"tokens": tokens.duplicate(true),
		"cursor": cursor
	}


static func invoke(custom: RefCounted, ref: Dictionary, name: String, args: Array) -> Variant:
	if ref.__custom_ref == "flash_text_row_type":
		if name != "new" or args.size() != 1 or not args[0] is String:
			return custom.reject("文本行构造需要一个字符串。")
		var context = Context.new()
		context.custom_data = custom
		context.variables = (
			custom.script_variables
			if custom.script_variables != null
			else custom._owner.get_ref().variables
		)
		var row = load("res://runtime/scripts/06_Message/TextRow.gd").new(args[0], context)
		if not row.failure.is_empty():
			return custom.reject(row.failure)
		return {"__custom_ref": "flash_text_row", "value": row.snapshot()}
	var value: Dictionary = ref.get("value", {})
	if (
		args.is_empty()
		and name in ["text", "halign", "valign", "text_width", "text_height", "line_space"]
	):
		return value[name]
	if args.is_empty() and name == "eof?":
		return value.cursor >= value.tokens.size()
	if args.is_empty() and name in ["getchar", "peer"]:
		if value.cursor >= value.tokens.size():
			return null
		var result: Variant = value.tokens[int(value.cursor)]
		if name == "getchar":
			value.cursor += 1
		return result
	if name in [">>", "<<"] and args.size() <= 1:
		if not args.is_empty() and not custom._integer(args[0]):
			return custom.reject("文本行位移必须为整数。")
		value.cursor = clampi(
			(
				int(value.cursor)
				+ (int(args[0]) if not args.is_empty() else 1) * (1 if name == ">>" else -1)
			),
			0,
			value.tokens.size()
		)
		return value.cursor
	if args.is_empty() and name in ["goto_head", "goto_tail"]:
		value.cursor = 0 if name == "goto_head" else value.tokens.size()
		return value.cursor
	return custom.reject("文本行接口未迁移：" + name)

## 职责：编辑事件实际执行的 GDScript，提供语法着色、编译诊断、上下文提示及只读来源。
##
## 调用方式：
##   在事件、脚本条件或路线对话框中 configure(source, legacy)；source 是实际运行 GDScript，legacy 为可选只读来源。
##   check 返回编译结果并定位编辑器中的真实 GDScript 行；source() 返回当前草稿，持有对话框负责应用与保存。
##
## 调用接口：
##   func configure(source: String, legacy: String = "") -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     参数 legacy（String；默认值 ""）：只读原 Ruby 迁移来源，不能作为运行代码发布。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func source() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func check() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 接口说明结束。

@tool
extends VBoxContainer
const Source = preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
var code: CodeEdit
var status: Label
var _legacy: TextEdit


func configure(source: String, legacy: String = "") -> void:
	_build()
	code.text = source
	_legacy.text = legacy
	_legacy.visible = false
	status.text = "草稿未发布。编译检查通过并应用后，还需保存事件；重新运行游戏读取保存内容。"


func _build() -> void:
	if code != null:
		return
	custom_minimum_size = Vector2(620, 330)
	var help = Label.new()
	help.text = "事件正文 · Actor_Init.load(id) / ctx.actor / ctx.variable / ctx.set_variable\n等待：if not await ctx.wait(秒): return　重试：return ctx.retry(秒)"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 600
	help.size.x = 600
	add_child(help)
	var bar = HBoxContainer.new()
	add_child(bar)
	var check_button = Button.new()
	check_button.text = "编译检查"
	bar.add_child(check_button)
	check_button.pressed.connect(check)
	var original = Button.new()
	original.text = "只读迁移来源"
	bar.add_child(original)
	original.pressed.connect(func(): _legacy.visible = not _legacy.visible)
	code = CodeEdit.new()
	code.custom_minimum_size = Vector2(620, 260)
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.gutters_draw_line_numbers = true
	code.indent_use_spaces = false
	var highlighter = CodeHighlighter.new()
	highlighter.function_color = Color("dcdcaa")
	highlighter.member_variable_color = Color("9cdcfe")
	highlighter.number_color = Color("b5cea8")
	highlighter.symbol_color = Color("d4d4d4")
	for keyword in [
		"extends",
		"static",
		"func",
		"return",
		"var",
		"const",
		"if",
		"else",
		"elif",
		"for",
		"in",
		"while",
		"await",
		"not",
		"and",
		"or",
		"true",
		"false",
		"null",
		"pass"
	]:
		highlighter.add_keyword_color(keyword, Color(0.9, 0.65, 0.9))
	highlighter.add_color_region('"', '"', Color(0.7, 0.85, 0.65))
	highlighter.add_color_region("'", "'", Color(0.7, 0.85, 0.65))
	highlighter.add_color_region("#", "", Color(0.55, 0.6, 0.65), true)
	code.syntax_highlighter = highlighter
	var background = StyleBoxFlat.new()
	background.bg_color = Color("1b1f27")
	code.add_theme_stylebox_override("normal", background)
	code.add_theme_stylebox_override("focus", background)
	code.add_theme_color_override("font_color", Color("e4e8ef"))
	code.add_theme_color_override("font_selected_color", Color.WHITE)
	code.add_theme_color_override("selection_color", Color("3a4b60"))
	code.add_theme_color_override("caret_color", Color.WHITE)
	code.add_theme_color_override("current_line_color", Color("252c38"))
	add_child(code)
	_legacy = TextEdit.new()
	_legacy.editable = false
	_legacy.custom_minimum_size.y = 100
	add_child(_legacy)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 600
	status.size.x = 600
	add_child(status)
	code.text_changed.connect(func(): status.text = "草稿已修改，尚未保存。")


func source() -> String:
	return code.text


func check() -> bool:
	var result = Source.compile(code.text)
	if result.ok:
		status.text = "编译通过；应用到事件草稿后保存，重新运行生效。"
		return true
	status.text = result.message
	if not result.get("diagnostics", []).is_empty():
		var diagnostic: Dictionary = result.diagnostics[0]
		status.text += "\n第 %d 行：%s" % [diagnostic.line, diagnostic.message]
		code.set_caret_line(maxi(0, int(diagnostic.line) - 1))
		code.grab_focus()
	return false

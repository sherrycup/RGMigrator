## 职责：验证事件脚本实际语法高亮、背景和选中颜色，检查方法名可辨认。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
var checks = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _contrast(first: Color, second: Color) -> float:
	var a = first.srgb_to_linear().get_luminance()
	var b = second.srgb_to_linear().get_luminance()
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func _color_at(colors: Dictionary, column: int) -> Color:
	var result = Color.BLACK
	var positions = colors.keys()
	positions.sort()
	for position in positions:
		if int(position)>column: break
		result = colors[position].get("color",result)
	return result

func run() -> void:
	var editor = load("res://addons/rgm_editor/03_Event/Editor_EventScript.gd").new()
	root.add_child(editor)
	editor.configure("Actor_Init.load(2)\nctx.set_variable(1, 53)\nreturn 'hello'\n# 中文注释\n")
	await process_frame
	var code: CodeEdit = editor.code
	var background: Color = code.get_theme_stylebox("normal").bg_color
	var highlighter: CodeHighlighter = code.syntax_highlighter
	expect(_contrast(_color_at(highlighter.get_line_syntax_highlighting(0),11),background)>=4.5,"actual Actor_Init.load method token is readable on the code background")
	expect(_contrast(_color_at(highlighter.get_line_syntax_highlighting(1),4),background)>=4.5,"actual ctx.set_variable method token is readable")
	expect(_contrast(code.get_theme_color("font_color"),background)>=4.5,"ordinary code text is readable")
	expect(_contrast(code.get_theme_color("font_selected_color"),code.get_theme_color("selection_color"))>=4.5,"selected method text is readable")
	expect(_contrast(_color_at(highlighter.get_line_syntax_highlighting(2),9),background)>=4.5,"single-quoted string is highlighted readably")
	var state = root.get_node("RuntimeState")
	var previous: Variant = state.variables.get("1")
	expect(editor.check() and state.variables.get("1")==previous,"syntax checking does not execute the visible event body")
	editor.queue_free()
	for message in failures: printerr("FAIL: ",message)
	print("EDITOR UI CONTRAST V053: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks)
	quit(0 if failures.is_empty() else 1)

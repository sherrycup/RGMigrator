## 职责：实际EditorPlugin与GPU回归：检查方法名高亮可读和业务正文编辑、保存、重开。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run(plugin: EditorPlugin, panel: Control) -> void
##     用途：执行当前迁移流程或回归场景。
##     参数 plugin（EditorPlugin；必填）：Godot EditorPlugin 插件实例。
##     参数 panel（Control；必填）：魔塔编辑器主面板实例。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

@tool
extends RefCounted
var checks = 0
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run(plugin: EditorPlugin, panel: Control) -> void:
	var tree = plugin.get_tree()
	var window = EditorInterface.get_base_control().get_window()
	window.gui_embed_subwindows = true
	window.size = Vector2i(1280, 900)
	window.position = Vector2i(-10000, -10000)
	expect(not panel._map.is_empty() and not panel._map.events.is_empty(), "actual plugin loads original map events")
	if panel._map.is_empty() or panel._map.events.is_empty():
		tree.quit(1)
		return
	panel._event_id = int(panel._map.events.keys()[0])
	panel._open_event(false)
	expect(panel._event_dialog.visible, "actual map event dialog opens")
	panel._command_editor._add_command()
	var dialog: ConfirmationDialog = panel._command_dialog
	dialog._select_code(dialog._selector.get_item_index(355))
	expect(dialog.visible and dialog._native_editor.visible and dialog._native_editor.code is CodeEdit, "actual plugin opens native script editor")
	var source = "Actor_Init.load(2)\nctx.set_variable(8600, 53)\n"
	dialog._native_editor.code.text = source
	expect(dialog._native_editor.check(), "actual edited GDScript compiles without running it")
	var code: CodeEdit = dialog._native_editor.code
	var background: Color = code.get_theme_stylebox("normal").bg_color
	var token_colors: Dictionary = code.syntax_highlighter.get_line_syntax_highlighting(0)
	var method_color = Color.BLACK
	var offsets = token_colors.keys()
	offsets.sort()
	for offset in offsets:
		if int(offset) > 11: break
		method_color = token_colors[offset].get("color", method_color)
	expect(_contrast(method_color, background) >= 4.5, "actual plugin method token is readable")
	expect(_contrast(code.get_theme_color("font_selected_color"), code.get_theme_color("selection_color")) >= 4.5, "actual plugin selected method is readable")
	if DisplayServer.get_name() != "headless":
		for frame in 8: await tree.process_frame
		expect(dialog.position.y >= 0 and dialog.position.y + dialog.size.y <= window.size.y, "code dialog including apply controls fits the editor viewport")
		RenderingServer.force_draw(false)
		await tree.process_frame
		expect(window.get_texture().get_image().save_png("res://.godot/v053-ui-plugin.png") == OK, "actual plugin GPU capture written")
		code.grab_focus()
		code.select(0, 11, 0, 15)
		await tree.process_frame
		RenderingServer.force_draw(false)
		await tree.process_frame
		expect(window.get_texture().get_image().save_png("res://.godot/v053-ui-plugin-selected.png") == OK, "selected method GPU capture written")
		code.deselect()
	dialog.confirmed.emit()
	dialog.hide()
	var entries: Array = panel._command_editor.draft()
	expect(entries.any(func(value): return int(value.get("code", 0)) == 355 and value.get("parameters", []) == [source]), "native source applied to real event draft")
	panel._apply_event()
	panel._event_dialog.hide()
	expect(panel.save_changes(), "actual plugin saves event source and binding")
	panel._open_event(false)
	entries = panel._command_editor.draft()
	var found = -1
	for index in entries.size():
		if entries[index].get("parameters", []) == [source]: found = index; break
	expect(found >= 0, "reopened real event contains saved GDScript")
	if found >= 0:
		panel._command_editor._command_list.get_root().get_child(found).select(0)
		panel._command_editor._edit_command()
		expect(dialog._native_editor.code.text == source, "reopened code editor displays saved authority")
		dialog.hide()
	panel._event_dialog.hide()
	var file = FileAccess.open("res://.godot/v053-ui-plugin.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(), "checks":checks, "failures":failures}, "\t"))
	for message in failures: printerr("FAIL: ", message)
	print("UI PLUGIN V053: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks)
	tree.quit(0 if failures.is_empty() else 1)

func _contrast(first: Color, second: Color) -> float:
	var a = first.srgb_to_linear().get_luminance()
	var b = second.srgb_to_linear().get_luminance()
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

## 职责：回归验证：实际编辑事件 GDScript，验证保存重开、复制、编译诊断和失败时保留旧文件。
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
##   func module(value: int) -> String
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
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
var failures: Array[String] = []
var checks = 0
var Source: Script

func _init() -> void:
	call_deferred("run")

func module(value: int) -> String:
	return "ctx.set_variable(8190, %d)\n" % value

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run() -> void:
	Source = load("res://runtime/scripts/02_Event/NativeScriptSource.gd")
	var Documents: Script = load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd")
	var documents: RefCounted = Documents.new()
	var map: Dictionary = documents.read("data/maps/Map001.json")
	var event_id: String = map.events.keys()[0]
	var editor: VBoxContainer = load("res://addons/rgm_editor/03_Event/Editor_CommandList.gd").new()
	root.add_child(editor)
	editor.configure([{"code":0, "indent":0, "parameters":[]}], documents)
	editor._add_command()
	var dialog: ConfirmationDialog = editor._command_dialog
	dialog._select_code(dialog._selector.get_item_index(355))
	expect(dialog._native_editor.visible and not dialog._form.visible and dialog._native_editor.code is CodeEdit, "new script opens actual GDScript CodeEdit")
	dialog._native_editor.code.text = module(41)
	dialog._accept()
	var commands: Array = editor.draft()
	expect(Source.is_native(commands[0]._script_binding) and commands[0].parameters == [module(41)], "apply publishes GDScript to event draft with matching binding")
	dialog.hide()
	editor._command_list.get_root().get_child(0).select(0)
	editor._copy_command()
	editor._paste_command()
	commands = editor.draft()
	expect(commands.size() == 3 and commands[0]._script_binding.native_id != commands[1]._script_binding.native_id, "clipboard paste gives independent stable identity")
	var original_id: String = commands[0]._script_binding.native_id
	editor._command_list.get_root().get_child(0).select(0)
	editor._edit_command()
	expect(dialog._native_editor.code.text == module(41), "reopen shows actual native source")
	dialog._native_editor.code.text = module(42)
	dialog._accept()
	dialog.hide()
	commands = editor.draft()
	expect(commands[0].parameters == [module(42)] and commands[1].parameters == [module(41)] and commands[0]._script_binding.native_id == original_id, "editing copied source preserves its identity without editing original")
	editor._command_list.get_root().get_child(0).select(0)
	editor._move_command(1)
	expect(editor.draft()[1]._script_binding.native_id == original_id, "moving a script preserves its identity")
	editor._move_command(-1)
	commands = editor.draft()
	var route: VBoxContainer = load("res://addons/rgm_editor/03_Event/Editor_RouteForm.gd").new()
	root.add_child(route)
	route.configure({"repeat":false, "skippable":false, "list":[{"code":0,"parameters":[]}]}, documents)
	route._insert(45)
	expect(route._native_editor.visible and not route._param_form.visible, "route45 uses same native editor")
	route._native_editor.code.text = module(43)
	route._accept_parameters()
	var route_data: Dictionary = route.draft()
	expect(Source.is_native(route_data.list[0]._script_binding) and route_data.list[0].parameters == [module(43)], "route source and binding update together")
	route._list.get_root().get_child(0).select(0)
	route._copy_selected()
	route_data = route.draft()
	expect(route_data.list[0]._script_binding.native_id != route_data.list[1]._script_binding.native_id, "copied route scripts have independent identity")
	var condition: ConfirmationDialog = load("res://addons/rgm_editor/03_Event/Editor_CommandDialog.gd").new()
	root.add_child(condition)
	var conditional = "return ctx.switch(1)\n"
	condition.open(documents, 111, [12, conditional], false)
	expect(condition._native_editor.visible and condition._native_editor.source() == conditional, "script condition opens actual GDScript")
	condition.hide()
	map.events[event_id].pages[0].list = commands
	map.events[event_id].pages[0].move_route = route_data
	map.events[event_id].pages[0].move_type = 3
	documents.apply("data/maps/Map001.json", map, "原生事件编辑验收")
	var saved: Dictionary = documents.save_all()
	expect(saved.ok, "native map and autonomous route save atomically: " + str(saved))
	var reloaded: RefCounted = Documents.new()
	var reopened: Dictionary = reloaded.read("data/maps/Map001.json")
	expect(reopened.events[event_id].pages[0].list[0].parameters == [module(42)], "new document instance reads saved native source")
	expect(reopened.events[event_id].pages[0].move_route.list[0].parameters == [module(43)], "autonomous route source survives reopen")
	var disk_hash = FileAccess.get_sha256("res://data/maps/Map001.json")
	var broken = reopened.duplicate(true)
	var invalid = "# 验证正文行号\nctx.set_variable(8190, 42)\nvar =\n"
	broken.events[event_id].pages[0].list[0].parameters = [invalid]
	broken.events[event_id].pages[0].list[0]._script_binding = Source.binding(invalid, broken.events[event_id].pages[0].list[0]._script_binding)
	reloaded.apply("data/maps/Map001.json", broken)
	var rejected: Dictionary = reloaded.save_all()
	expect(not rejected.ok and not rejected.get("diagnostics", []).is_empty(), "compile failure gives source line diagnostics")
	expect(FileAccess.get_sha256("res://data/maps/Map001.json") == disk_hash, "compile failure leaves published map bytes unchanged")
	expect(rejected.diagnostics[0].line == 3, "diagnostic points to edited GDScript line rather than old Ruby line")
	var workspace: RefCounted = load("res://addons/rgm_editor/06_Scripts/Editor_ScriptWorkspace.gd").new(documents)
	expect(not workspace.recompile().ok and FileAccess.get_sha256("res://data/maps/Map001.json") == disk_hash, "Ruby reconversion cannot overwrite native authoring")
	# Execute the saved document, not the editor draft or a generated probe substitute.
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	state.begin_new_game(data.system())
	state.map_id = 1
	var execution: RefCounted = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	execution.start(reopened.events[event_id].pages[0].list, int(event_id), 1)
	expect(not execution.running and state.variables.get("8190") == 41, "saved two independent scripts actually run in saved order")
	var report = {"ok":failures.is_empty(), "checks":checks, "expected_compile_errors":1, "map":"data/maps/Map001.json", "event_id":event_id, "native_id":original_id}
	var file = FileAccess.open("res://.godot/v052-native-authoring.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	if DisplayServer.get_name() != "headless":
		root.gui_embed_subwindows = true
		root.size = Vector2i(1100, 800)
		dialog.open(documents, 355, [module(42)], false)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/v052-native-editor.png")
	for message in failures: printerr("FAIL: ", message)
	print("EDITOR NATIVE V052: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks)
	quit(0 if failures.is_empty() else 1)

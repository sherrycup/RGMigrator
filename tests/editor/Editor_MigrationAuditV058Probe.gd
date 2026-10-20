## 职责：驱动真实编辑器脚本工作区，验证职责审计与编译诊断分离，并通过修改隔离副本验证失效提示。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run(plugin: Node, _panel: Control = null) -> void
##     用途：执行当前迁移流程或回归场景。
##     参数 plugin（Node；必填）：当前隔离窗口或实际EditorPlugin节点；使用所属SceneTree承载真实工作区窗口。
##     参数 _panel（Control；默认值 null）：为保持原接口位置保留，本实现未读取此参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 注意：只在明确可重建的测试工程执行；短暂修改目标文件以测试失效，随后恢复精确字节。
## 接口说明结束。

@tool
extends RefCounted
var checks = 0
var captures = 0
var failures: Array[String] = []

func run(plugin: Node, _panel: Control = null) -> void:
	var tree = plugin.get_tree()
	var window = tree.root
	window.size = Vector2i(1280, 900)
	window.content_scale_size = Vector2i(1280, 900)
	window.gui_embed_subwindows = true
	var Documents = load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd")
	var Workspace = load("res://addons/rgm_editor/06_Scripts/Editor_ScriptWorkspace.gd")
	var Coverage = load("res://addons/rgm_editor/06_Scripts/Editor_ScriptCoverage.gd")
	var documents = Documents.new()
	var model = Workspace.new(documents)
	var report = model.coverage()
	expect(report.version == load("res://runtime/scripts/00_Game/RuntimeVersion.gd").VERSION and report.counts.audited_sources == 339 and report.counts.audit_stale == 0, "fresh export has339 current reviewed sources and the actual tool version")
	var item = _row(report, "script_0026")
	expect(item.audit_label == "已实现" and item.status == "unsupported" and item.audit_current, "restored source0026 remains compiler-unsupported while its Godot service is correctly classified")
	expect(item.service_paths.has("runtime/scripts/03_Map/MapOcclusion.gd"), "tilemap source opens the actual new occlusion implementation")
	expect(_row(report, "script_0257").audit_label == "源未完成" and _row(report, "script_0278").audit_label == "已排除", "old undefined skill scene and excludedBOSS remain explicit boundaries")
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_audit.json"))
	var window_skill: Array = audit.override_chains.filter(func(row):return row.owner == "Window_Skill" and row.name == "initialize")
	expect(window_skill.size() == 1 and str(window_skill[0].effective).begins_with("script_0207:"), "later0207 skill window wins over original0119")
	var window_item: Array = audit.override_chains.filter(func(row):return row.owner == "Window_Item" and row.name == "initialize")
	expect(window_item.size() == 1 and str(window_item[0].effective).begins_with("script_0180:"), "later0180 item window wins over0116 even though it required lexical service review")
	expect(audit.methods.any(func(method):return method.kind == "alias" and not str(method.get("captured_version", "")).is_empty()), "alias rows retain captured versions rather than resolving blindly to the final name")
	expect(audit.methods.any(func(method):return method.resolution == "lexical_service_review"), "unparsed source declarations are explicit lexical candidates")
	var dialog: Window = load("res://addons/rgm_editor/06_Scripts/Editor_ScriptDialog.gd").new()
	window.add_child(dialog)
	dialog.open(documents)
	dialog._search.text = "script_0026"
	dialog._filter("script_0026")
	expect(dialog._list.item_count == 1 and dialog._list.get_item_text(0).contains("已实现"), "real source list shows reviewed service status")
	expect(not dialog._source.editable and dialog._source.text.contains("check_up_under"), "originalRuby stays read-only and visible for provenance")
	expect(dialog._summary.text.contains("职责审计 339") and dialog._summary.text.contains("编译诊断"), "real coverage summary separates responsibilities from compiler diagnostics")
	_expand(dialog, "script_0026")
	await _capture(tree, "editor-audit")
	var target = "res://runtime/scripts/03_Map/MapOcclusion.gd"
	var original = FileAccess.get_file_as_string(target)
	var checksum = FileAccess.get_sha256(target)
	var edited = FileAccess.open(target, FileAccess.WRITE)
	edited.store_string(original + "\n# isolated0.58 audit-staleness probe\n")
	edited.close()
	model.reload()
	report = model.coverage()
	expect(not _row(report, "script_0026").audit_current and report.counts.audit_stale > 0, "changing actualGodot code invalidates the service audit without hiding old compiler diagnostics")
	dialog._model.reload()
	dialog._refresh_list("script_0026")
	dialog._refresh_report()
	expect(dialog._list.get_item_text(0).contains("需复验"), "real source list marks edited implementation for revalidation")
	_expand(dialog, "script_0026")
	await _capture(tree, "editor-audit-stale")
	# The probe only edits the explicitly disposable generated fixture.
	edited = FileAccess.open(target, FileAccess.WRITE)
	edited.store_string(original)
	edited.close()
	expect(FileAccess.get_sha256(target) == checksum, "probe restores exact implementation bytes")
	model.reload()
	expect(model.coverage().counts.audit_stale == 0, "restoring the original code restores the audit freshness")
	dialog.hide()
	dialog.queue_free()
	await tree.process_frame
	for message in failures: printerr("FAIL: ", message)
	print("EDITOR MIGRATION AUDIT V058: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks / ", captures, " GPU states")
	tree.quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _row(report: Dictionary, id: String) -> Dictionary:
	for row in report.units:
		if row.unit_id == id: return row
	return {}

func _expand(dialog: Window, id: String) -> void:
	dialog._coverage.get_parent().get_parent().current_tab = 2
	var group = dialog._coverage.get_root().get_first_child()
	group.collapsed = false
	for item in group.get_children():
		if item.get_metadata(0).get("unit_id", "") == id:
			item.collapsed = false
			item.select(0)
			for child in item.get_children():
				var metadata = child.get_metadata(0)
				if metadata is Dictionary and str(metadata.get("path", "")).ends_with("MapOcclusion.gd"):
					child.select(0)
					break
			dialog._coverage.ensure_cursor_is_visible()
			return

func _capture(tree: SceneTree, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 3: await tree.process_frame
	await RenderingServer.frame_post_draw
	var image = tree.root.get_texture().get_image()
	expect(image != null and image.save_png("res://.godot/v058-" + label + ".png") == OK, "actual editor GPU capture " + label)
	captures += 1

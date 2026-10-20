## 职责：回归验证：检查脚本公开接口、源文件路径和版本与开发契约一致。
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
##   func check_file(doc: String, path: String, signatures: RegEx) -> void
##     参数 doc（String；必填）：当前核对的开发接口文档文本。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     参数 signatures（RegEx；必填）：用于检查函数签名的正则表达式或签名集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func check_generated_version() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
## Checks the agent contract against source without loading generated-only classes.
const Version = preload("res://scripts/Version.gd")
const RuntimeVersion = preload("res://templates/runtime/scripts/00_Game/RuntimeVersion.gd")
const Generator = preload("res://scripts/importer/ProjectGenerator.gd")
const Report = preload("res://scripts/importer/MigrationReportWriter.gd")
var failures: Array[String] = []
var checks := 0
var script_count := 0
var method_count := 0

func _init() -> void:
	var doc := FileAccess.get_file_as_string("res://AGENTS.md").replace("\r\n", "\n")
	expect(doc.begins_with("# RGMigrator " + Version.VERSION), "AGENTS version matches source")
	expect(RuntimeVersion.VERSION == Version.VERSION, "template runtime version matches source")
	expect(str(ProjectSettings.get_setting("application/config/name")) == Version.DISPLAY_NAME, "migrator project title matches source")
	expect(FileAccess.get_file_as_string("res://README.md").begins_with("# " + Version.DISPLAY_NAME), "README current version matches source")
	var files: Array[String] = ["scripts/Main.gd", "scripts/Version.gd"]
	for directory in ["templates/runtime/scripts", "scripts/importer", "templates/editor/addons/rgm_editor"]:
		_collect_sources(directory, files)
	files.sort()
	var signatures := RegEx.new()
	signatures.compile("^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\\(.*\\)\\s*->\\s*[^:]+")
	for path in files:
		check_file(doc, path, signatures)
	var headings := RegEx.new()
	headings.compile("(?m)^### ([A-Za-z0-9_]+\\.gd)$")
	expect(headings.search_all(doc).size() == files.size(), "no stale or undocumented script headings")
	expect(doc.contains("全部%d个生产脚本" % files.size()), "declared script count matches scanned files")
	expect(doc.contains("天气唯一状态由ScreenState持有") and FileAccess.get_file_as_string("res://templates/runtime/scripts/00_Game/ScreenState.gd").contains("func weather("), "weather ownership matches screen implementation")
	check_generated_version()
	for message in failures: printerr("FAIL: ", message)
	print("DOCUMENTATION TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks,
		" checks / ", script_count, " scripts / ", method_count, " public methods")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func check_file(doc: String, path: String, signatures: RegEx) -> void:
	script_count += 1
	var heading := "\n### " + path.get_file() + "\n"
	expect(doc.count(heading) == 1, "unique script heading: " + path)
	var start := doc.find(heading)
	if start < 0: return
	var end := doc.find("\n### ", start + heading.length())
	var section := doc.substr(start, end - start) if end >= 0 else doc.substr(start)
	expect(section.contains("源文件：" + path + "。"), "documented source path: " + path)
	var parent := ""
	var class_name_line := ""
	var signals: Array[String] = []
	var constructors: Array[String] = []
	var methods: Array[String] = []
	var fields: Array[String] = []
	var constants: Array[String] = []
	var members := RegEx.new()
	members.compile("^(?:(?:static )?var|const) ([A-Za-z][A-Za-z0-9_]*)")
	for source_line in _contract_lines(FileAccess.get_file_as_string("res://" + path)):
		var line := source_line.trim_suffix("\r")
		if line.begins_with("extends "): parent = line
		if line.begins_with("class_name "): class_name_line = line
		if line.begins_with("signal "): signals.append(line)
		var member := members.search(line)
		if member != null:
			if line.begins_with("const "):
				if not line.contains("preload("): constants.append("`" + member.get_string(1) + "`")
			else: fields.append("`" + member.get_string(1) + "`")
		var match_value := signatures.search(line)
		if match_value == null: continue
		var name_value := match_value.get_string(1)
		var signature := match_value.get_string().strip_edges()
		if name_value == "_init" and not signature.contains("_init()"):
			constructors.append(signature)
		elif not name_value.begins_with("_"):
			methods.append(signature)
			method_count += 1
	var expected := parent + "\n"
	expect(section.contains("公开字段：" + ("无" if fields.is_empty() else "、".join(fields)) + "。"), "public fields: " + path)
	expect(section.contains("常量（不含依赖脚本引用）：" + ("无" if constants.is_empty() else "、".join(constants)) + "。"), "constants: " + path)
	if not class_name_line.is_empty(): expected += class_name_line + "\n"
	for signature in signals + constructors + methods: expected += signature + "\n"
	if methods.is_empty() and constructors.is_empty(): expected += "# 本类未声明自定义公共方法。\n"
	var opening := "```gdscript\n"
	var block_start := section.find(opening)
	var block_end := section.find("```", block_start + opening.length())
	expect(block_start >= 0 and block_end >= 0, "interface code block: " + path)
	if block_start < 0 or block_end < 0: return
	var actual := section.substr(block_start + opening.length(), block_end - block_start - opening.length())
	expect(actual == expected, "exact inheritance/signals/constructor/method contract: " + path)

func check_generated_version() -> void:
	var output := ProjectSettings.globalize_path("res://.godot/version_contract_%d" % Time.get_ticks_usec())
	var generated := Generator.new().generate(output, "Version fixture", {})
	expect(generated.warnings.is_empty(), "fixture generator succeeds")
	var config := FileAccess.get_file_as_string(output.path_join("project.godot"))
	expect(config.begins_with("; Generated by " + Version.DISPLAY_NAME), "generated config version")
	expect(config.contains('"4.5"') and config.contains("gl_compatibility"), "engine requirements unchanged by tool version")
	expect(FileAccess.get_file_as_string(output.path_join("runtime/scripts/00_Game/RuntimeVersion.gd")).contains('const VERSION := "' + Version.VERSION + '"'), "generated runtime version")
	expect(FileAccess.get_sha256(output.path_join("runtime/scripts/00_Game/RuntimeVersion.gd")) == FileAccess.get_sha256("res://templates/runtime/scripts/00_Game/RuntimeVersion.gd"), "current runtime-version template keeps exact exported bytes, including line endings")
	expect(FileAccess.get_file_as_string(output.path_join("README.md")).contains(Version.DISPLAY_NAME), "generated README version")
	var generated_sources: Array[String] = []
	var generated_root := ProjectSettings.localize_path(output).trim_prefix("res://")
	_collect_sources(generated_root.path_join("runtime/scripts"), generated_sources)
	_collect_sources(generated_root.path_join("addons"), generated_sources)
	var headers_ok := true
	var editor_names_and_tools_ok := true
	for path in generated_sources:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n")
		headers_ok = headers_ok and text.begins_with("## 职责：")
		if path.contains("/addons/"):
			editor_names_and_tools_ok = editor_names_and_tools_ok and path.get_file().begins_with("Editor_") and text.get_slice("\n\n", 1).begins_with("@tool\n")
	var layout_index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://templates/runtime/script_layout.json"))
	# Production groups plus the eleven bundled compiler/version scripts.
	expect(generated_sources.size() == layout_index.runtime.size() + layout_index.editor.size() + 11 and headers_ok, "all generated runtime and editor files start with responsibility comments")
	expect(editor_names_and_tools_ok, "generated editor copies have uniform names and a valid tool directive after their header, including CRLF sources")
	expect(Report.new().write(output, {"tool_version": Version.DISPLAY_NAME}).is_empty(), "fixture report succeeds")
	expect(FileAccess.get_file_as_string(output.path_join("migration_report.md")).begins_with("# " + Version.DISPLAY_NAME), "generated report version")
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("migration_report.json")))
	expect(report is Dictionary and report.get("tool_version") == Version.DISPLAY_NAME, "generated JSON report version")


func _collect_sources(directory: String, files: Array[String]) -> void:
	for filename in DirAccess.get_files_at("res://" + directory):
		if filename.ends_with(".gd"): files.append(directory.path_join(filename))
	for folder in DirAccess.get_directories_at("res://" + directory):
		if not folder.begins_with("."): _collect_sources(directory.path_join(folder), files)


func _contract_lines(source: String) -> Array[String]:
	var result: Array[String] = []
	var declaration: Array[String] = []
	for raw_line in source.split("\n"):
		var line: String = raw_line.trim_suffix("\r")
		if not declaration.is_empty():
			declaration.append(line.strip_edges())
			if line.strip_edges().ends_with(":"):
				result.append(" ".join(declaration))
				declaration.clear()
		elif (line.begins_with("func ") or line.begins_with("static func ")) and not line.ends_with(":"):
			declaration.append(line)
		else:
			result.append(line)
	return result

extends SceneTree
## Checks the agent contract against source without loading generated-only classes.
const Version = preload("res://scripts/Version.gd")
const RuntimeVersion = preload("res://templates/runtime/scripts/RuntimeVersion.gd")
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
	for directory in ["templates/runtime/scripts", "scripts/importer"]:
		for filename in DirAccess.get_files_at("res://" + directory):
			if filename.ends_with(".gd"): files.append(directory.path_join(filename))
	files.sort()
	var signatures := RegEx.new()
	signatures.compile("^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\\(.*\\)\\s*->\\s*[^:]+")
	for path in files:
		check_file(doc, path, signatures)
	var headings := RegEx.new()
	headings.compile("(?m)^### ([A-Za-z0-9_]+\\.gd)$")
	expect(headings.search_all(doc).size() == files.size(), "no stale or undocumented script headings")
	expect(doc.contains("全部%d个生产脚本" % files.size()), "declared script count matches scanned files")
	expect(doc.contains("不存在 ScreenState.weather()"), "weather ownership gap remains explicit")
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
	for source_line in FileAccess.get_file_as_string("res://" + path).split("\n"):
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
	expect(FileAccess.get_file_as_string(output.path_join("runtime/scripts/RuntimeVersion.gd")).contains('const VERSION := "' + Version.VERSION + '"'), "generated runtime version")
	expect(FileAccess.get_file_as_string(output.path_join("README.md")).contains(Version.DISPLAY_NAME), "generated README version")
	expect(Report.new().write(output, {"tool_version": Version.DISPLAY_NAME}).is_empty(), "fixture report succeeds")
	expect(FileAccess.get_file_as_string(output.path_join("migration_report.md")).begins_with("# " + Version.DISPLAY_NAME), "generated report version")
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("migration_report.json")))
	expect(report is Dictionary and report.get("tool_version") == Version.DISPLAY_NAME, "generated JSON report version")

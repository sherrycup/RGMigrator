extends SceneTree

const ProjectGenerator = preload("res://scripts/importer/ProjectGenerator.gd")
const RmxpIniReader = preload("res://scripts/importer/RmxpIniReader.gd")
const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const TestSetupGenerator = preload("res://scripts/importer/TestSetupGenerator.gd")
const Report = preload("res://scripts/importer/MigrationReportWriter.gd")


func _init() -> void:
	# Only generated disposable outputs listed by our last test run are touched.
	var results: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/test-results.json"))
	var allowed := ProjectSettings.globalize_path("res://.godot/")
	for output: String in results.get("exports", []):
		if not output.begins_with(allowed):
			quit(1)
			return
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("migration_report.json")))
		var ini := RmxpIniReader.new(RmxpTextCodec.new(936)).read(str(report["source_path"]).path_join("Game.ini"))
		var generated := ProjectGenerator.new().generate(output, str(report["project_title"]), ini, Callable(), str(report["source_path"]))
		report.tool_version = preload("res://scripts/Version.gd").DISPLAY_NAME
		Report.new().write(output, report)
		# Disposable fixtures only; upgrade their generated configuration as well.
		var testing := TestSetupGenerator.new().generate(output, true)
		if not testing.get("ok", false):
			printerr(testing)
			quit(1)
			return
		if not generated["warnings"].is_empty():
			printerr(generated["warnings"])
			quit(1)
			return
		print("Refreshed test runtime: ", output)
	quit(0)

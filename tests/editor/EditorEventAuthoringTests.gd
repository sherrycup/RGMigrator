extends SceneTree
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var docs=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var scenario=load("res://.godot/EditorEventAuthoringScenario.gd").new()
	await scenario.run(root,docs)
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("EVENT AUTHORING TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

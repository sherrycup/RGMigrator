extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var scenario=load("res://.godot/EditorFinalUiScenario.gd").new()
	var result: Dictionary=await scenario.run(root,load("res://addons/rgm_editor/EditorDocuments.gd").new())
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("FINAL UI METRICS: ",JSON.stringify(result.metrics))
	print("FINAL UI TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

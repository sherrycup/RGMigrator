extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var scenario=load("res://.godot/EditorFeedbackScenario.gd").new()
	var result: Dictionary=await scenario.run(root,load("res://addons/rgm_editor/EditorDocuments.gd").new())
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("EDITOR FEEDBACK AUDIO: ",result.mixed_samples," samples / peak=",result.audio_peak)
	print("EDITOR FEEDBACK TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

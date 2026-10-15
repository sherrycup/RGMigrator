extends SceneTree
func _init() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,800); root.gui_embed_subwindows=true
	var docs: RefCounted=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var scenario: RefCounted=load("res://.godot/EditorStructureGuideScenario.gd").new()
	await scenario.run(root,docs)
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("STRUCTURE GUIDE TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

extends SceneTree
func _init() -> void:
	var failed:=false
	for file in DirAccess.get_files_at("res://addons/rgm_editor"):
		if not file.ends_with(".gd"): continue
		var script: GDScript=load("res://addons/rgm_editor/"+file)
		if script==null or not script.can_instantiate(): failed=true; printerr("FAIL: ",file)
	print("EDITOR COMPILE: ","FAILED" if failed else "PASSED")
	quit(1 if failed else 0)

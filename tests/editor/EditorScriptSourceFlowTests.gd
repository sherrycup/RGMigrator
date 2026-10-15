extends SceneTree
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var Documents: Script=load("res://addons/rgm_editor/EditorDocuments.gd")
	var Workspace: Script=load("res://addons/rgm_editor/EditorScriptWorkspace.gd")
	var root_path=ProjectSettings.globalize_path("res://.godot/script_source_flow_"+str(Time.get_ticks_usec()))
	for folder in ["data","legacy/ordered_scripts","legacy/ruby_scripts","runtime/generated","migration_docs"]: _copy_tree(ProjectSettings.globalize_path("res://"+folder),root_path.path_join(folder))
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("data/script_units.json")))
	var file=FileAccess.open(root_path.path_join("data/script_workspace.json"),FileAccess.WRITE); file.store_string(JSON.stringify(Workspace.initial(root_path,registry),"\t",false)); file.close()
	var documents: RefCounted=Documents.new(root_path); var model: RefCounted=Workspace.new(documents)
	var original_hashes: Dictionary={}
	for row in model.entries():
		if row.origin.kind=="script":
			var path=str(registry.units[row.unit_id].source_path)
			original_hashes[path]=FileAccess.get_sha256(root_path.path_join(path))
	expect(original_hashes.size()==339,"all original Flash script slots are listed in original order")
	expect(model.coverage().counts.bound==144,"coverage starts from 144 actual original event bindings")
	var result: Dictionary=model.recompile()
	expect(result.ok,"all actual source/event scripts recompile from current project: "+str(result.get("message","")))
	if result.ok:
		expect(result.summary.scripts==339 and result.summary.fragments==144 and result.summary.event_integrated_units==144,"reconversion retains real source units and bindings")
		for path in original_hashes: expect(FileAccess.get_sha256(root_path.path_join(path))==original_hashes[path],"original remains immutable "+path)
		var added: Dictionary=model.add_script("工作区验证")
		expect(added.ok and model.set_source(added.unit_id,"$game_variables[4999] = 48").ok and model.save().ok,"new script saves with appended immutable load order")
		result=model.recompile(); expect(result.ok,"new script is compiled with existing source load order: "+str(result.get("message","")))
		if result.ok:
			var state: Node=root.get_node("RuntimeState"); state.variables.erase("4999")
			var generated: GDScript=load(root_path.path_join("runtime/generated/"+added.unit_id+".gd"))
			var ran: Dictionary=generated.execute(state)
			expect(ran.ok and int(state.variables.get("4999",0))==48,"new generated script changes the real RuntimeState")
			var reopened: RefCounted=Workspace.new(Documents.new(root_path))
			expect(reopened.source(added.unit_id)=="$game_variables[4999] = 48" and int(reopened._registry.units[added.unit_id].origin.load_order)==340,"new source and loading position survive reopening")
			expect(reopened.coverage().counts.changed>=1 and not reopened._registry.units[added.unit_id].runtime_verified,"new source reports changed status without fabricated behavior coverage")
	for failure in failures: printerr("FAIL: ",failure)
	print("EDITOR SCRIPT SOURCE FLOW: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func _copy_tree(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	for name in DirAccess.get_files_at(source): DirAccess.copy_absolute(source.path_join(name),destination.path_join(name))
	for name in DirAccess.get_directories_at(source): _copy_tree(source.path_join(name),destination.path_join(name))

## 职责：回归验证：验证脚本工作副本、保存重开、冲突保护及重新转换发布。
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
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func write(path: String, text: String) -> void
##     用途：写入指定文件或目标数据。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     参数 text（String；必填）：需要解析、显示或保存的文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func json(path: String) -> Dictionary
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func finish() -> void
##     用途：结束本次处理并返回结果。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var checks=0
var failures: Array[String]=[]
var directory=""

func _init() -> void: call_deferred("run")

func run() -> void:
	var Inventory: Script=load("res://addons/rgm_editor/compiler/Editor_ScriptMigrationInventory.gd")
	var Workspace: Script=load("res://addons/rgm_editor/06_Scripts/Editor_ScriptWorkspace.gd")
	var Documents: Script=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd")
	var Transaction: Script=load("res://addons/rgm_editor/01_Documents/Editor_ProjectTransaction.gd")
	var Adapter: Script=load("res://addons/rgm_editor/03_Event/Editor_ScriptAdapter.gd")
	directory=ProjectSettings.globalize_path("res://.godot/workspace_test_"+str(Time.get_ticks_usec()))
	var scripts: Array[Dictionary]=[
		{"unit_id":"script_0001","source":"class WorkspaceCalc\n def self.number\n  2\n end\nend\n","source_path":"legacy/ordered_scripts/0001_calc.rb","origin":{"kind":"script","name":"计算","load_order":1,"script_id":11}},
		{"unit_id":"script_0002","source":"def broken(\n","source_path":"legacy/ordered_scripts/0002_native.rb","origin":{"kind":"script","name":"未转换","load_order":2,"script_id":12}}
	]
	var map={"id":1,"width":1,"height":1,"data":{"x_size":1,"y_size":1,"z_size":3,"values":[0,0,0]},"events":{"1":{"id":1,"name":"测试","x":0,"y":0,"pages":[{"trigger":0,"move_route":{"repeat":false,"skippable":false,"list":[{"code":0,"parameters":[]}]},"list":[{"code":355,"indent":0,"parameters":["$game_variables[401] = 3"]},{"code":0,"indent":0,"parameters":[]}]}]}}}
	var common: Array=[null,{"id":1,"name":"条件","trigger":0,"switch_id":1,"list":[{"code":111,"indent":0,"parameters":[12,"* broken"]},{"code":122,"indent":1,"parameters":[402,402,0,0,10]},{"code":411,"indent":0,"parameters":[]},{"code":122,"indent":1,"parameters":[402,402,0,0,20]},{"code":412,"indent":0,"parameters":[]},{"code":0,"indent":0,"parameters":[]}]}]
	write("data/custom_data.json",JSON.stringify({"profile":"native"}))
	write("data/manifest.json",JSON.stringify({"maps":["Map001"]}))
	for folder in ["data/maps","data/database","legacy/ruby_scripts"]: DirAccess.make_dir_recursive_absolute(directory.path_join(folder))
	for entry in scripts: write(entry.source_path,entry.source)
	var inventory: RefCounted=Inventory.new(); inventory.configure_scripts(scripts); inventory.collect_map(map,"Map001"); inventory.collect_common(common)
	expect(inventory.generate(directory,scripts).ok,"fixture uses the production compiler and event integration")
	var registry: Dictionary=json("data/script_units.json")
	write("data/script_workspace.json",JSON.stringify(Workspace.initial(directory,registry)))
	var documents: RefCounted=Documents.new(directory); var model: RefCounted=Workspace.new(documents)
	expect(model.entries().size()==4,"script list includes ordered libraries and event fragments")
	expect(model.source("script_0001",true)==scripts[0].source,"original Ruby is an independent immutable view")
	expect(not model.set_source("script_0002","$game_variables[1] = 2").ok,"unconverted service libraries cannot pretend Ruby edits update native adapters")
	var report: Dictionary=model.coverage()
	expect(report.counts.generated==2 and report.counts.bound==1 and report.counts.diagnostic_units==2,"coverage separates generation, binding and diagnostic units")
	expect(not report.units.any(func(row: Dictionary) -> bool: return row.runtime_verified),"parser/compiler counts never claim behavior coverage")
	var original_hash=FileAccess.get_sha256(directory.path_join(scripts[0].source_path))
	expect(model.set_source("script_0001",scripts[0].source.replace("  2","  7")).ok,"library working copy can be edited")
	expect(model.rename("script_0001","计算工作副本").ok,"display name edits retain original load order")
	expect(not model.recompile().ok,"unsaved drafts block publishing")
	expect(model.save().ok,"explicit save persists working copies")
	var reopened: RefCounted=Workspace.new(Documents.new(directory))
	expect(reopened.source("script_0001").contains("  7") and reopened.entries()[0].name=="计算工作副本","saved edits survive reopening")
	var compiled: Dictionary=model.recompile()
	expect(compiled.ok,"recompile publishes a changed library: "+str(compiled.get("message","")))
	if not compiled.ok: finish(); return
	expect(FileAccess.get_sha256(directory.path_join(scripts[0].source_path))==original_hash,"publishing leaves original Ruby unchanged")
	expect(model.source("script_0001",true)==scripts[0].source and model.generated("script_0001").contains("result = 7"),"original view and regenerated result remain distinct")
	var event_id=""
	for row in model.entries():
		if row.origin.kind=="map_event": event_id=row.unit_id
	expect(model.set_source(event_id,"$game_variables[401] = 29").ok and model.save().ok,"event script working copy saves separately")
	compiled=model.recompile(); expect(compiled.ok,"event edits refresh source and binding: "+str(compiled.get("message","")))
	var current: Dictionary=json("data/maps/Map001.json"); var command: Dictionary=current.events["1"].pages[0].list[0]
	expect(command.parameters[0]=="$game_variables[401] = 29" and command._script_binding.source_sha256==json("data/script_units.json").units[command._script_binding.unit_id].source_sha256,"published event text and executable binding match")
	var generated: GDScript=load(directory.path_join("runtime/generated/"+command._script_binding.unit_id+".gd"))
	var state: Node=root.get_node("RuntimeState")
	state.variables.erase("401")
	var ran: Dictionary=generated.execute(state)
	expect(ran.ok and int(state.variables.get("401",0))==29,"the freshly generated code changes actual runtime state")
	# Moving/inserting other commands must retain the identity of an existing
	# bound script, and published working text must not overwrite later map edits.
	current.events["1"].pages[0].list[0].parameters=["$game_variables[401] = 76"]
	current.events["1"].pages[0].list.push_front({"code":106,"indent":0,"parameters":[4]})
	write("data/maps/Map001.json",JSON.stringify(current))
	compiled=model.recompile(); expect(compiled.ok,"recompilation accepts a shifted bound script edited in the map: "+str(compiled.get("message","")))
	current=json("data/maps/Map001.json"); command=current.events["1"].pages[0].list[1]
	expect(int(current.events["1"].pages[0].list[0].code)==106 and command._script_binding.unit_id==event_id and command.parameters[0]=="$game_variables[401] = 76" and model.source(event_id)==command.parameters[0],"non-script insertions preserve source identity and later map edits")
	current.events["2"]=current.events["1"].duplicate(true); current.events["2"].id=2
	write("data/maps/Map001.json",JSON.stringify(current))
	compiled=model.recompile(); expect(compiled.ok,"copied event bindings receive independent identities: "+str(compiled.get("message","")))
	current=json("data/maps/Map001.json")
	expect(current.events["1"].pages[0].list[1]._script_binding.unit_id!=current.events["2"].pages[0].list[1]._script_binding.unit_id,"copied events do not overwrite a shared generated unit")
	model.set_source(event_id,"$game_variables[401] = 81"); model.save()
	current.events["1"].pages[0].list[1].parameters=["$game_variables[401] = 82"]; write("data/maps/Map001.json",JSON.stringify(current))
	expect(not model.recompile().ok,"simultaneous workspace and map source edits require a merge")
	current.events["1"].pages[0].list[1].parameters=["$game_variables[401] = 76"]; write("data/maps/Map001.json",JSON.stringify(current)); model.set_source(event_id,"$game_variables[401] = 76"); model.save()
	var condition_id=""
	for row in model.entries():
		if row.origin.kind=="common_event": condition_id=row.unit_id
	expect(model.set_source(condition_id,"$game_variables[401] == 29").ok and model.save().ok,"unsupported condition can be corrected in its working copy")
	compiled=model.recompile(); expect(compiled.ok,"corrected condition restores executable branches: "+str(compiled.get("message","")))
	var events: Array=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("data/database/CommonEvents.json")))
	expect(events[1].list.size()==6 and int(events[1].list[0].code)==111 and events[1].list[0].has("_script_binding") and events[1].list[3].parameters[-1]==20,"both branches and edited non-script values survive restoration")
	var route_form: Control=load("res://addons/rgm_editor/03_Event/Editor_RouteForm.gd").new(); root.add_child(route_form)
	current=json("data/maps/Map001.json"); route_form.configure(current.events["1"].pages[0].move_route,documents)
	route_form._insert(45); route_form._param_form._put([0],"$game_variables[403] = 18"); route_form._accept_parameters()
	current.events["1"].pages[0].move_route=route_form.draft(); write("data/maps/Map001.json",JSON.stringify(current))
	compiled=model.recompile(); expect(compiled.ok,"an authored route script converts from the actual route form: "+str(compiled.get("message","")))
	current=json("data/maps/Map001.json"); var route_command: Dictionary=current.events["1"].pages[0].move_route.list[0]
	expect(int(route_command.code)==45 and route_command.has("_script_binding"),"new autonomous script has a real runtime binding")
	generated=load(directory.path_join("runtime/generated/"+route_command._script_binding.unit_id+".gd")); ran=generated.execute(state)
	expect(ran.ok and int(state.variables.get("403",0))==18,"authored route code changes the actual runtime state")
	var route_id=str(route_command._script_binding.unit_id)
	expect(model.source(route_id,true).is_empty() and model.coverage().units.any(func(row: Dictionary) -> bool: return row.unit_id==route_id and row.changed),"new authored source is reported as changed without claiming original RM provenance")
	route_form.hide(); route_form.queue_free(); await process_frame
	var old_registry_hash=FileAccess.get_sha256(directory.path_join("data/script_units.json")); var old_map_hash=FileAccess.get_sha256(directory.path_join("data/maps/Map001.json")); var old_generated_hash=FileAccess.get_sha256(directory.path_join("runtime/generated/script_0001.gd"))
	model.set_source("script_0001","class Missing\n"); model.save(); compiled=model.recompile()
	expect(not compiled.ok and not compiled.get("diagnostics",[]).is_empty(),"invalid Ruby produces source diagnostics")
	expect(FileAccess.get_sha256(directory.path_join("data/script_units.json"))==old_registry_hash and FileAccess.get_sha256(directory.path_join("data/maps/Map001.json"))==old_map_hash and FileAccess.get_sha256(directory.path_join("runtime/generated/script_0001.gd"))==old_generated_hash,"failed conversion leaves all live code and bindings intact")
	expect(Workspace.new(Documents.new(directory)).source("script_0001")=="class Missing\n","failed source stays saved for correction")
	model.set_source("script_0001",scripts[0].source); model.save()
	var manual=FileAccess.get_file_as_string(directory.path_join("runtime/generated/script_0001.gd"))+"\n# hand-written\n"; write("runtime/generated/script_0001.gd",manual)
	compiled=model.recompile(); expect(not compiled.ok and compiled.get("path")=="runtime/generated/script_0001.gd","manual GDScript changes block automatic overwrite")
	expect(FileAccess.get_file_as_string(directory.path_join("runtime/generated/script_0001.gd"))==manual,"manual edits remain untouched")
	expect(model.coverage().counts.manual_files==1,"coverage reports actual file ownership conflicts")
	var rejected=Transaction.publish(directory,{"legacy/source.rb":"bad"},{"legacy/source.rb":{"exists":false,"sha256":""}})
	expect(not rejected.ok and not Transaction.allowed("data/../outside.json"),"publishing cannot write original source or escape the project")
	var expected={"data/check.json":Transaction.stamp(directory,"data/check.json")}; write("data/check.json","{}")
	expect(not Transaction.publish(directory,{"data/check.json":"{\"new\":true}"},expected).ok and json("data/check.json")=={},"external conflicts abort before writing")
	var placeholder: Dictionary=Adapter._adapt_list(common[1].list)[0]; placeholder.parameters[0]+="\nuser change"
	expect(not Workspace.restore_common([null,{"list":[placeholder]}]).ok,"modified placeholders are retained and diagnosed")
	var route={"repeat":true,"skippable":false,"list":[{"code":45,"parameters":["broken("]},{"code":1,"parameters":[]},{"code":0,"parameters":[]}]}
	var adapted: Dictionary=Adapter._adapt_route(route); adapted.list[0].code=2
	expect(not Workspace.restore_map({"events":{"1":{"pages":[{"list":[],"move_route":adapted}]}}}).ok,"route restoration refuses to overwrite edited actions")
	model._workspace.new_scripts.append({"unit_id":"../../escape","origin":{"kind":"script","load_order":99,"name":"bad"}})
	expect(not model.recompile().ok,"invalid source IDs cannot escape the conversion staging directory")
	finish()

func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory.path_join(path).get_base_dir())
	var file=FileAccess.open(directory.path_join(path),FileAccess.WRITE); file.store_string(text); file.close()

func json(path: String) -> Dictionary:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(path)))
	return value if value is Dictionary else {}

func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func finish() -> void:
	for failure in failures: printerr("FAIL: ",failure)
	print("EDITOR SCRIPT WORKSPACE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

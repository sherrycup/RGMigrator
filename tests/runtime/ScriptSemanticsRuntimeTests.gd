extends SceneTree
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	var runtime: Script = load("res://runtime/scripts/ScriptRuntime.gd")
	state.begin_new_game(data.system())
	var registry: Dictionary = data.read_json("res://data/script_units.json",{})
	var library := ""; var generated := 0
	for id in registry.get("units",{}):
		var unit: Dictionary = registry.units[id]
		if unit.status!="generated": continue
		generated += 1
		var script: GDScript = load(unit.generated_path)
		expect(script!=null and script.can_instantiate(),"generated file compiles: "+id)
		if unit.origin.get("name")=="Skill 3": library = id
	if not library.is_empty():
		expect(runtime.execute_unit(library,state).ok,"actual custom module definitions load")
		var receiver := {"__ruby_class":"Skill","fields":{}}
		var yes: Dictionary = runtime.call_method(receiver,"real_time_readdition",[61],state)
		var no: Dictionary = runtime.call_method(receiver,"real_time_readdition",[62],state)
		expect(yes.ok and yes.value==true and no.ok and no.value==false,"real custom method keeps original 61-only behavior")
		var env: RefCounted = state.script_session
		expect(env.methods.has("Skill#real_time_readdition"),"generated method version is registered")
		state.begin_new_game(data.system())
		expect(state.script_session==null,"new game clears loaded custom definitions/objects")
		var missing: Dictionary = runtime.call_method(receiver,"real_time_readdition",[61],state)
		expect(missing.ok and missing.value==true,"fully migrated declaration library can reload lazily after new game")
	var mapping: Dictionary = data.read_json("res://data/script_source_map.json",{})
	expect(not mapping.get("entries",[]).is_empty(),"Ruby to GDScript source mapping is exported")
	var codec: Script = load("res://runtime/scripts/SaveCodec.gd")
	var saved: Dictionary = codec.capture(state); var prepared: Dictionary = codec.prepare(saved)
	expect(prepared.ok,"native save format remains valid with script session present")
	if prepared.ok: state.restore_prepared(prepared)
	if state.custom_data.manifest.get("profile")=="flash":
		expect(state.script_session!=null and state.script_session.methods==saved.script_data.methods and state.script_session.loaded_units==saved.script_data.loaded_units,"Flash restore retains validated generated method versions and loaded units")
	else:
		expect(state.script_session!=null and state.script_session.methods.is_empty() and state.script_session.loaded_units.is_empty(),"native restore retains plain data and resets transient method definitions")
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT SEMANTICS RUNTIME: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / generated=",generated)
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

extends SceneTree
var checks := 0
var failures: Array[String] = []
var checked_units: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	var scripts: Script = load("res://runtime/scripts/ScriptRuntime.gd")
	var interpreter: Script = load("res://runtime/scripts/EventInterpreter.gd")
	state.begin_new_game(data.system())
	var registry: Dictionary = data.read_json("res://data/script_units.json",{})
	var inspected := 0
	for id in registry.units:
		var unit: Dictionary = registry.units[id]
		if not unit.event_integrated or unit.origin.get("command_code")!=355: continue
		if unit.origin.get("database","CommonEvents")!="CommonEvents": continue
		# Independent native-write examples; exclude unported gameplay/object calls.
		var matcher := RegEx.new(); matcher.compile("^\\$game_variables\\[([0-9]+)\\]\\s*=\\s*0$")
		var lines: Array[String] = []
		for line in str(unit.source).split("\n"):
			if not line.strip_edges().is_empty() and not line.strip_edges().begins_with("#"): lines.append(line.strip_edges())
		var match_value := matcher.search("\n".join(lines))
		if match_value==null: continue
		var commands: Array
		if unit.origin.kind=="map_event": commands = data.map(str(unit.origin.map).trim_prefix("Map").to_int()).events[str(int(unit.origin.event_id))].pages[int(unit.origin.page)-1].list
		else: commands = data.database("CommonEvents")[int(unit.origin.common_event_id)].list
		var position := -1
		for index in commands.size():
			if commands[index].get("_script_binding",{}).get("unit_id")==id: position = index; break
		expect(position>=0,"binding is in actual source event: "+id)
		if position<0: continue
		var count := int(commands[position]._script_binding.command_count)
		var isolated: Array = commands.slice(position,position+count).duplicate(true)
		isolated.append({"code":0,"parameters":[],"indent":0})
		var variable := int(match_value.get_string(1)); state.set_event_variable(variable,37)
		var owner: RefCounted = interpreter.new()
		var errors: Array = []
		owner.diagnostic_requested.connect(func(message: String) -> void: errors.append(message))
		if unit.origin.kind=="common_event":
			var definitions: Array = []; var common_id := int(unit.origin.common_event_id)
			definitions.resize(common_id+1); definitions[common_id] = {"list":isolated}
			owner.common_events = definitions
			owner.start([{"code":117,"parameters":[common_id],"indent":0},{"code":0,"parameters":[],"indent":0}],7)
		else: owner.start(isolated,int(unit.origin.get("event_id",0)),int(unit.origin.get("page",1)))
		expect(not owner.running and owner.wait_kind()=="completed" and state.variables.get(str(variable))==0 and errors.is_empty(),"actual map/common355 executes through interpreter: "+id)
		checked_units.append(id); inspected += 1
		if inspected>=6: break
	expect(inspected>0,"actual project has verified native state write entrance")
	# The original main-actor death helper is now implemented; exercise its real false branch.
	for id in registry.units:
		var unit: Dictionary = registry.units[id]
		if not unit.event_integrated or unit.origin.get("command_code")!=111 or unit.source!="_main_actor.dead?": continue
		state.party=[2]; state.variables["14"]=[2,0]
		state.actor(2).set_project_parameter("maxhp",100); state.actor(2).hp=100; state.actor(2).recover_battle_down()
		var owner: RefCounted = interpreter.new(); var errors: Array = []
		owner.diagnostic_requested.connect(func(message: String) -> void: errors.append(message))
		owner.start([{"code":111,"indent":0,"parameters":[12,unit.source],"_script_binding":{"unit_id":id,"source_sha256":unit.source_sha256,"command_count":1}},{"code":121,"indent":1,"parameters":[8100,8100,0]},{"code":411,"indent":0,"parameters":[]},{"code":121,"indent":1,"parameters":[8101,8101,0]},{"code":412,"indent":0,"parameters":[]},{"code":0,"indent":0,"parameters":[]}],int(unit.origin.get("event_id",0)),1)
		for frame in 120:
			if not owner.running: break
			owner.advance(1.0/60.0)
			await process_frame
		expect(owner.wait_kind()=="completed" and state.switches.get("8101",false) and not state.switches.get("8100",false) and errors.is_empty(),"actual implemented actor-death condition selects its false branch: "+str([owner.wait_kind(),state.switches,errors]))
		break
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT EVENT SOURCE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / ",JSON.stringify(checked_units))
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

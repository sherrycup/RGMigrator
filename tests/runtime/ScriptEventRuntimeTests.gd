extends SceneTree
var failures: Array[String] = []
var checks := 0
var notices: Array[String] = []
var completed_count := 0
var failed_count := 0

class CharacterFixture extends Node:
	var character_id := 7
	var tile_position := Vector2i(6,3)
	var direction := 2
	var map_runtime: Node
	func is_idle() -> bool: return true
	func clear_route_lock_direction() -> void: pass
	func route_locked() -> bool: return false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	var interpreter: Script = load("res://runtime/scripts/EventInterpreter.gd")
	var persistence: Script = load("res://runtime/scripts/EventPersistence.gd")
	var scripts: Script = load("res://runtime/scripts/ScriptRuntime.gd")
	var route_script: Script = load("res://runtime/scripts/CharacterRoute.gd")
	state.map_id = 1; state.gold = 100; state.variables = {}; state.switches = {}
	var registry: Dictionary = data.read_json("res://data/script_units.json",{})
	var pages: Array = data.map(1).events["7"].pages
	var owner: RefCounted = interpreter.new()
	owner.diagnostic_requested.connect(func(message: String) -> void: notices.append(message))
	owner.completed.connect(func() -> void: completed_count += 1)
	owner.failed.connect(func() -> void: failed_count += 1)
	owner.start(pages[0].list,7,1)
	expect(owner.running and owner.wait_kind()=="time" and is_equal_approx(owner.wait_state.remaining,1.0),"event uses source50FPS wait without blocking")
	expect(state.gold==125 and owner.context.script_fields.get("@tag")==7,"event lazily invokes custom library reward once")
	expect(state.script_session.loaded_units.size()==2 and state.script_session.methods["Object#reward_original"].path.ends_with("script_0001.gd"),"lazy library loading preserves ordered override and captured alias version")
	var saved: Dictionary = persistence._interpreter(owner,false)
	expect(persistence._execution_valid(saved),"post-script wait and cursor are saveable")
	owner.advance(0.4)
	expect(owner.running and state.gold==125 and not state.switches.get("1",false),"waiting yields without duplicate reward or early branch")
	owner.cancel(); state.script_session = null
	var restored: RefCounted = interpreter.new()
	persistence._restore_interpreter(restored,JSON.parse_string(JSON.stringify(saved)))
	restored.advance(1.0)
	expect(not restored.running and state.gold==125 and state.switches.get("1",false) and not state.switches.get("2",false),"cold-session save resume executes Ruby-truthy zero branch, no duplicate gold")
	expect(state.variables.get("1")==7 and state.variables.get("2")==1 and state.variables.get("4")==7,"common event inherits caller event/map; its instance fields do not overwrite caller")
	owner.start(pages[1].list,7,2)
	expect(owner.wait_kind()=="script_retry" and state.variables.get("3")==1,"adjacent355 false yields at last source record")
	owner.advance(0.0); owner.advance(0.0)
	expect(owner.running and state.variables.get("3")==1,"poll retry runs tail only, earlier side effect not repeated")
	var polling: Dictionary = persistence._interpreter(owner,false)
	expect(persistence._execution_valid(polling),"false retry cursor and wait can be saved")
	state.switches["3"] = true; owner.advance(0.0)
	expect(not owner.running and state.switches.get("4",false),"external switch resumes poll and following native command")
	owner.start(pages[2].list,7,3)
	expect(completed_count==1 and failed_count==1,"failed script emits abort instead of successful completion")
	expect(owner.wait_kind()=="failed" and not state.switches.get("5",false) and not state.switches.get("6",false) and not notices.is_empty(),"unsupported whole condition stops rather than choosing a branch")
	var common: Array = data.database("CommonEvents")
	owner.managed = true; owner.start([{"code":117,"parameters":[1]},{"code":0,"parameters":[]}],7)
	state.map_id = 2; owner.advance(0.0)
	expect(state.variables.get("1")==0 and state.variables.get("2")==2 and owner.context.source_map_id==1,"common child after transfer uses current native map and invalidates caller event, while diagnostic origin survives")
	state.map_id = 1; owner.managed = false
	owner.start(common[2].list,7)
	expect(owner.wait_kind()=="failed" and not state.variables.has("8") and notices[-1].contains("公共事件") and notices[-1].contains("L"),"runtime method failure rolls back earlier writes and includes source position")
	owner.start(common[3].list,7)
	owner.advance(0.0)
	expect(state.variables.get("9")==2 and owner.running,"single355 original false behavior re-evaluates program once per update")
	owner.cancel(); var token: int = owner.wait_token(); state.switches["9"] = true
	expect(owner.advance(1.0)==0 and owner.wait_token()==token,"cancel prevents pending poll from writing state")
	registry.interpreter_policy.false_result_waits = false
	owner.start(common[4].list,7)
	expect(not owner.running and state.switches.get("8",false),"source policy ignoring false continues next command")
	registry.interpreter_policy.false_result_waits = true
	for id in [5,6,7]:
		owner.start(common[id].list,7)
		expect(not owner.running,"nil/empty array/class library result continues: "+str(id))
	registry.interpreter_policy.custom_binding = true
	owner.start(common[9].list,7)
	expect(not owner.running and state.variables.get("10")==10 and state.switches.get("10",false),"Universal_Bind native variable/switch helpers retain shared state")
	registry.interpreter_policy.custom_binding = false
	for id in range(11,16):
		state.switches.erase("20"); state.switches.erase("21")
		owner.start(common[id].list,7)
		expect(not owner.running and state.switches.get("20",false)==(id>=13) and state.switches.get("21",false)==(id<13),"Ruby condition truth for false/nil/empty array/empty string/one: "+str(id))
	var gold_before: int = state.gold
	owner.start(common[16].list,7)
	expect(owner.running and owner.wait_kind()=="script_retry" and state.gold==gold_before+5,"final655 false yields after applying program once")
	owner.advance(0.0)
	expect(not owner.running and state.switches.get("22",false) and state.gold==gold_before+5,"final655 resumes following command without repeating reward")
	owner.start(common[17].list,7)
	expect(not owner.running and state.switches.get("23",false),"comment-only program returns nil and advances normally")
	owner.start(common[18].list,7)
	expect(not owner.running and state.variables.get("25")==2 and state.script_session.loaded_units.has("script_0003"),"qualified declaration constant loads its migrated library")
	var stale: Array = pages[0].list.duplicate(true); stale[0].parameters[0] = "reward(999)"
	var before: int = state.gold; owner.start(stale,7)
	expect(owner.wait_kind()=="failed" and state.gold==before and notices[-1].contains("过期"),"edited source invalidates binding before any reward")
	var character := CharacterFixture.new(); root.add_child(character); character.map_runtime = root
	var route: RefCounted = route_script.new(character)
	var source_route: Dictionary = pages[0].move_route
	expect(route.force(source_route,"Map001 / event7").ok and route.forcing and state.variables.get("5")==6,"route45 sees actual character position")
	route.advance(0.4)
	expect(route.forcing and not state.switches.get("7",false),"route script wait suspends native following actions")
	var progress: Dictionary = route.persistent_data()
	expect(route_script.validate_persistent(progress),"route wait and consumed script cursor persist")
	var resumed: RefCounted = route_script.new(character); resumed.restore_persistent(progress); resumed.advance(0.6)
	expect(not resumed.forcing and state.switches.get("7",false),"route false return is ignored and wait resumes next action")
	var broken: Dictionary = source_route.duplicate(true); broken.list[0].erase("_script_binding")
	state.switches.erase("7")
	expect(not resumed.force(broken).ok and not resumed.forcing and not state.switches.get("7",false),"unbound route45 rejects entire forced route before movement")
	var partial: Dictionary = source_route.duplicate(true); partial["_editor_original_route"] = source_route
	expect(not route_script.preflight(partial).ok,"legacy filtered placeholder route cannot run partial actions")
	character.free()
	var malformed: Dictionary = saved.duplicate(true); malformed.context.script_fields = {"x":{"__ruby_class":"Unported","fields":{}}}
	expect(not persistence._execution_valid(malformed),"unsupported custom object save is rejected")
	var cyclic: Array = []; cyclic.append(cyclic)
	owner.managed = true; owner.start(common[8].list,7); owner.advance(0.0)
	owner.context.script_fields["@cycle"] = cyclic
	expect(persistence._interpreter(owner,false).has("script_error"),"cyclic custom field is rejected before snapshot recursion")
	cyclic.clear(); owner.cancel()
	state.script_session.globals["$custom_progress"] = 9
	var codec: Script = load("res://runtime/scripts/SaveCodec.gd")
	expect(not codec.prepare(codec.capture(state)).ok,"unported custom global state cannot be silently lost on save")
	state.script_session = null
	registry.units["script_9999"] = {"origin":{"kind":"script","name":"Unsupported later override"},"status":"unsupported","definitions":{"safe":false,"types":[],"methods":[{"owner":"Object","name":"reward","singleton":false}]}}
	owner.managed = false; var unchanged_gold: int = state.gold; owner.start(pages[0].list,7)
	expect(owner.wait_kind()=="failed" and state.gold==unchanged_gold and state.script_session.loaded_units.is_empty(),"unsupported later override fails and rolls back lazy definitions, never silently runs older method")
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT EVENT RUNTIME: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

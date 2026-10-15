extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func run() -> void:
	var state=root.get_node("RuntimeState")
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2,3]; state.variables["14"]=[2,3]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",1000); actor.hp=800
	var shared={"value":7}; shared.self=shared
	state.variables["90"]=shared; state.flash_temp_fields.direct_shared=shared
	var custom=state.custom_data.values; var variables=state.variables; var temp=state.flash_temp_fields
	var env=Scripts._session(state)
	expect(env.begin({"kind":"direct_test"}),"script starts in direct mode")
	expect(env._direct and env._snapshot.is_empty(),"no rollback snapshot is created")
	expect(is_same(env._variables,variables) and is_same(env._custom.values,custom) and is_same(env._custom.temp_fields,temp),"variables, custom records and temporary fields share live roots")
	expect(is_same(env._custom.staged_actor(2),actor),"actor access returns the actual actor")
	env.invoke(env._custom.data_ref("actor",2),"hp=",[680])
	expect(actor.hp==680,"HP changes before script completion")
	env.invoke(env._custom.data_ref("temp"),"event_erase=",[false])
	expect(state.flash_temp_fields.event_erase==false,"temporary flag changes before completion")
	env.index_set({"__state_table":"variable"},91,shared)
	env.index_set({"__state_table":"switch"},92,true)
	env.index_set({"__state_table":"self"},[10,22,"A"],true)
	expect(is_same(state.variables["91"],shared) and state.switches["92"] and state.self_switches["10:22:A"],"variable and both switch kinds publish immediately")
	expect(env._pending.is_empty(),"no deferred variable or switch commit remains")
	var units=Data.read_json("res://data/custom_units.json",{}).get("units",{})
	var id="data_direct_probe_"+str(Time.get_ticks_usec()); var path="res://runtime/generated/"+id+".gd"
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("extends RefCounted\nstatic func program(_env): return 7\n"); file.close()
	units[id]={"status":"generated","pure_expression":true,"generated_path":path,"source":"7","source_sha256":"7".sha256_text()}
	var nested=Scripts.evaluate_data_expression(id,state)
	expect(nested.ok and nested.value==7 and env._active,"data expressions reuse an active direct script without starting a nested execution")
	units.erase(id); DirAccess.remove_absolute(path)
	var before=int(state.inventory.get("item:1",0))
	env.invoke(env._custom.data_ref("party"),"gain_item",[1,1,false])
	expect(state.inventory["item:1"]==mini(99,before+1),"inventory changes immediately")
	var gold=state.gold; env.invoke(env._custom.data_ref("party"),"gain_gold",[7])
	expect(state.gold==gold+7,"currency changes immediately")
	# Deliberately non-saveable data proves script completion no longer runs
	# the save-graph validator. Explicit save validation remains independent.
	var resource=Resource.new(); state.variables["93"]=resource
	var result=env.finish(null)
	expect(result.ok,"script completion skips whole-state result validation")
	expect(is_same(state.variables,variables) and is_same(state.custom_data.values,custom) and is_same(state.flash_temp_fields,temp),"completion never replaces shared state roots")
	expect(is_same(state.variables["90"],state.variables["91"]) and is_same(shared.self,shared) and is_same(state.flash_temp_fields.direct_shared,shared),"cross-root aliases and cycles retain identity")
	expect(not env._active and env._custom==null,"execution scratch references are released")
	state.variables.erase("93"); state.variables.erase("90"); state.variables.erase("91"); state.flash_temp_fields.erase("direct_shared")
	var receiver={"__ruby_class":"Object","fields":{"@x":1}}
	expect(Scripts.call_transaction(state,{"kind":"direct_call"},func(live):return live.index_set({"__state_table":"variable"},94,18)).ok and state.variables["94"]==18,"native business entry uses the same direct execution path")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH DIRECT EXECUTION: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

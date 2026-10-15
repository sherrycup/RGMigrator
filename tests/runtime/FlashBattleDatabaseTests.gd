extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Simulator=preload("res://runtime/scripts/FlashBattleSimulator.gd")
const Semantics=preload("res://runtime/scripts/ScriptSemantics.gd")
var failures: Array=[]
var checks=0

class BoundProfile extends RefCounted:
	var manifest={"profile":"antinomy"}
	var values={"records":{}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	Data.bind_custom_data(state.custom_data)
	var source: Array=Data.read_json("res://data/database/Skills.json",[])
	var original=source.duplicate(true)
	var original_42=Data.source_record("Skills",42).duplicate(true)
	var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/flash_gameplay.json"))
	var sim=Simulator.new(); sim.configure(rules)
	for id in [0,40,41,42,43,44,45,46,61,62,81,101,121]:
		expect(same_values(Data.record("Skills",id),Data.source_record("Skills",id)),"default imported source skill remains same after dynamic view: "+str(id))
	expect(sim.define_skill(42,func(s):
		s.display("GDS Heavy","Edited ordinary skill")
		s.action("party",2.25,2,30)
		s.value.icon_name="HeavyIcon"
		s.value.animation1_id=21
		s.value.animation2_id=3
		s.value.element_set=[9,13]
	).ok,"GDScript replaces an original source definition")
	var live=Data.record("Skills",42)
	expect(live.name=="GDS Heavy" and live.description=="Edited ordinary skill" and live.power==30 and live.atk_f==225 and live.scope==2,"display and compatible combat fields come from one registered definition")
	expect(live.icon_name=="HeavyIcon" and live.animation1_id==21 and live.animation2_id==3 and live.element_set==[9,13,32] and live.sp_cost==0,"registered presentation fields and party tag synchronize in memory")
	expect(Data.source_record("Skills",42)==original_42 and source==original,"source_record and raw cached array remain unchanged after registration")
	var new_id=source.size()+3
	expect(Data.source_record("Skills",new_id).is_empty() and sim.define_skill(new_id,func(s):s.display("New GDS Support"); s.action("support",1.75)).ok,"GDScript can register an ID absent from source JSON")
	var added=Data.record("Skills",new_id)
	expect(added.id==new_id and added.name=="New GDS Support" and added.atk_f==175 and added.scope==1 and added.element_set==[31],"record exposes new registered skill with source compatibility fields")
	expect(added._class=="RPG::Skill" and added.occasion==1 and added.common_event_id==0 and added.hit==100 and added.menu_se.name=="","new registered skill has native database defaults for ordinary menu consumers")
	var view: Array=Data.database("Skills")
	expect(view.size()>new_id and view[new_id]==added and view[42]==live,"UI database view includes both original replacements and new IDs")
	view[42].name="private UI mutation"; view[42].element_set.append(99); view[new_id].name="private new-row mutation"
	expect(Data.record("Skills",42).name=="GDS Heavy" and not Data.record("Skills",42).element_set.has(99) and Data.record("Skills",new_id).name=="New GDS Support","UI view edits cannot mutate registry records or subsequent reads")
	expect(source==original and Data.source_record("Skills",new_id).is_empty(),"adding sparse live rows never grows the original cached array")
	var native_profile=BoundProfile.new(); Data.bind_custom_data(native_profile)
	expect(Data.record("Skills",42)==original_42 and Data.record("Skills",new_id).is_empty(),"Antinomy/native profile ignores shared Flash module definitions")
	expect(Data.database("Skills")==original and Data.database("Skills").size()==source.size(),"native database array is unaffected by Flash dynamic IDs")
	Data.bind_custom_data(state.custom_data)
	expect(Data.record("Skills",new_id).name=="New GDS Support","restoring Flash profile exposes the same process registration")
	var env=Semantics.new(state); env.begin({"kind":"dynamic_skill_test"})
	var native=env._custom.record("Skills",new_id)
	expect(native.id==new_id and native.name=="New GDS Support","shared Ruby database bridge reads the registered new ID")
	var skill_ref: Variant=env._custom.index_get(env._custom.data_ref("database",0,"Skills"),new_id)
	expect(skill_ref!=null and env._custom.invoke(skill_ref,"name",[])=="New GDS Support","actual $data_skills index/getter bridge reads new GDScript definitions")
	var actor=env._custom.staged_actor(2)
	env._custom.invoke(env._custom.data_ref("actor",2),"learn_skill",[new_id])
	expect(env._custom.failure.is_empty() and actor.has_skill(new_id),"script actor bridge learns the newly registered GDScript skill")
	expect(env.finish(null).ok and state.actor(2).has_skill(new_id),"dynamic skill learning commits to the shared live actor")
	# Restore the original module catalog so this test also checks clean reinstall.
	sim.registry.configure({})
	sim.configure(rules)
	expect(same_values(Data.record("Skills",42),original_42) and Data.record("Skills",new_id).is_empty() and source==original,"catalog reload restores original live view without touching source data")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH BATTLE DATABASE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func same_values(a: Dictionary,b: Dictionary) -> bool:
	# JSON imports use Float numbers while generated GDScript retains Integer IDs.
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))

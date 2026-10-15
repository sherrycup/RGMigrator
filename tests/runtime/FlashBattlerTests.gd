extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
const Semantics=preload("res://runtime/scripts/ScriptSemantics.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.variables["14"]=[2,0]; state.map_id=10
	var states: Array=Data.database("States").duplicate(true)
	for i in range(1,6):
		states[i].zero_hp=i==5; states[i].plus_state_set=[]; states[i].minus_state_set=[]
		for rate in ["maxhp_rate","maxsp_rate","atk_rate","pdef_rate","mdef_rate","agi_rate","int_rate","hit_rate","str_rate","dex_rate"]: states[i][rate]=100
		states[i].rating=i; states[i].restriction=0
		states[i].cant_get_exp=false; states[i].cant_evade=false; states[i].slip_damage=false
	states[1].maxhp_rate=50; states[1].maxsp_rate=50; states[1].minus_state_set=[2]
	states[1].animation_id=3; states[1].restriction=2; states[1].cant_evade=true
	states[2].restriction=4; states[2].cant_get_exp=true; states[2].slip_damage=true
	states[3].plus_state_set=[4]; states[3].minus_state_set=[1]
	Data._cache["res://data/database/States.json"]=states
	var actor=state.actor(2)
	actor.set_project_parameter("maxhp",100); actor.set_project_parameter("maxsp",20)
	actor.hp=80.75; actor.sp=9.25
	expect(actor.hp==80.75 and actor.sp==9.25,"source actor HP/SP retain fractional values")
	var ref=state.custom_data.data_ref("actor",2)
	var result=Scripts.call_method(ref,"add_state",[1],state)
	expect(result.ok and actor.get_parameter("maxhp")==50 and actor.hp==50 and actor.sp==9.25,"state rate clamps vitals without truncating SP")
	result=Scripts.call_method(ref,"add_state",[2],state)
	expect(result.ok and actor.state_ids==[1],"opposing existing minus-state blocks a normal addition")
	result=Scripts.call_method(ref,"add_state",[2,true],state)
	expect(result.ok and actor.state_ids==[2,1],"force bypasses state exclusion and preserves source rating order")
	expect(Scripts.call_method(ref,"state_animation_id",[],state).value==states[2].animation_id,"state animation uses source first state")
	expect(Scripts.call_method(ref,"restriction",[],state).value==4,"restriction uses the strongest active state")
	for name in ["cant_get_exp?","cant_evade?","slip_damage?"]:
		expect(Scripts.call_method(ref,name,[],state).value==true,"source state flag: "+name)
	result=Scripts.call_method(ref,"add_state",[3],state)
	expect(result.ok and actor.state_ids==[4,3,2] and actor.get_parameter("maxhp")==100,"linked plus/minus states follow database ID order")
	result=Scripts.call_method(ref,"clear_state",[],state)
	expect(result.ok and actor.state_ids.is_empty() and actor.hp==50,"clear_state does not refill HP")
	Scripts.call_method(ref,"add_state",[1],state)
	actor.hp=7.5; actor.sp=2.5
	result=Scripts.call_method(ref,"reset_all",[],state)
	expect(result.ok and actor.state_ids.is_empty() and actor.hp==50 and actor.sp==10 and actor.get_parameter("maxhp")==100,"reset_all fills current reduced caps before removing states")
	actor.set_project_parameter("maxhp",0)
	expect(actor.hp==0 and not actor.state_ids.has(5),"maxhp= clamps backing HP without calling hp= zero-state effects")
	actor.hp=0
	expect(actor.state_ids.has(5),"explicit hp= synchronizes source zero-HP states")
	result=Scripts.call_method(ref,"clear_state",[],state)
	expect(result.ok and actor.hp==1 and actor.get_parameter("maxhp")==0,"source clear_state preserves its minimum-one behavior at zero maxHP")
	actor.set_project_parameter("maxhp",100); actor.hp=80.75; actor.sp=9.25
	var saved=load("res://runtime/scripts/SaveCodec.gd").capture(state)
	expect(load("res://runtime/scripts/SaveCodec.gd").prepare(saved).ok,"fractional actor vitals pass detached save validation")
	actor.set_project_parameter("maxhp",40); actor._install_vitals(80.75,9.25)
	var copied=actor.detached_copy()
	expect(copied.ok and copied.actor.hp==80.75,"copy preserves source direct-field HP above a changed cap")
	saved=load("res://runtime/scripts/SaveCodec.gd").capture(state)
	expect(load("res://runtime/scripts/SaveCodec.gd").prepare(saved).ok,"save preserves legitimate source over-cap vitals")
	actor.set_project_parameter("maxhp",100); actor.hp=80.75
	actor.set_project_parameter("patk",20); actor.set_project_parameter("pdef",2); actor.set_project_parameter("agi",10)
	var env=Semantics.new(state); env.begin({"kind":"source_battler_test"})
	var custom=env._custom; var floor=custom._floor(10)
	var event_id=int(floor.entries.keys()[0]); var entry: Dictionary=floor.entries[str(event_id)]
	entry.fields.maxhp=80; entry.fields.maxsp=20; entry.fields.atk=10; entry.fields.pdef=3; entry.fields.mdef=4; entry.fields.agi=10
	entry.fields.eva=30
	var enemy=custom.data_ref("floor_enemy",10,"",event_id)
	expect(custom.invoke(enemy,"maxhp",[])==80 and custom.invoke(enemy,"sp",[])==20,"source enemy initializes full vitals from its actual parameters")
	custom.invoke(enemy,"maxhp=",[100]); custom.invoke(enemy,"patk=",[18])
	expect(custom.invoke(enemy,"maxhp",[])==100 and custom.invoke(enemy,"patk",[])==18 and entry.battler.parameter_plus.maxhp==20,"enemy setters maintain independent eight-parameter bonuses")
	custom.invoke(enemy,"sp=",[8.75]); custom.invoke(enemy,"hp=",[79.75]); custom.invoke(enemy,"eva=",[25.75])
	expect(custom.invoke(enemy,"sp",[])==8.75 and custom.invoke(enemy,"hp",[])==79 and custom.invoke(enemy,"eva",[])==25,"final 0072 overrides truncate enemy HP/patience while inherited SP retains fractions")
	custom.invoke(enemy,"add_state",[1]); custom.invoke(enemy,"add_state",[2,true])
	expect(custom.invoke(enemy,"maxhp",[])==50 and custom.invoke(enemy,"hp",[])==50 and custom.invoke(enemy,"states",[])==[2,1],"enemy rates, force and battle-state clamp share source semantics")
	custom.invoke(enemy,"resist=",[[20,30,40,50,60]])
	expect(custom.invoke(enemy,"resist",[])==[20.0,30.0,40.0,50.0,60.0],"enemy resist uses five independent increments")
	var dealt=custom.invoke(enemy,"periodic_damage",[custom.data_ref("actor",2)])
	expect(dealt==max(actor.get_parameter("patk")-3,0)+max(actor.get_parameter("matk")-4,0),"periodic damage preserves source physical-plus-magical formula")
	custom.invoke(enemy,"reset_all",[])
	expect(custom.invoke(enemy,"states",[]).is_empty() and custom.invoke(enemy,"battle_system_legacy_hp",[])==50 and custom.invoke(enemy,"hp",[])==50,"enemy legacy backing HP and final battle HP remain distinct source fields")
	var database=custom.data_ref("record",int(entry.fields.id),"Enemies")
	custom.invoke(database,"exp=",[77])
	expect(custom.invoke(enemy,"exp",[])==77,"existing enemy reward getter follows the current runtime database")
	var constants: Dictionary=custom.gameplay().rules.constants
	custom.invoke(database,"actions=",[[{"kind":1,"condition_level":10,"skill_id":int(constants.HOOK_SKILL_ID),"condition_turn_a":0,"condition_turn_b":1,"rating":1}]])
	custom.invoke(enemy,"load_skills",[])
	expect(custom.invoke(enemy,"skills",[])==[int(constants.HOOK_SKILL_ID)] and custom._floor(10).indices.hook.has(entry.position),"enemy load_skills refreshes source ability and floor index from live actions")
	var predicted=custom.gameplay().predict(10,event_id)
	expect(predicted!=null and typeof(predicted.damage) in [TYPE_INT,TYPE_FLOAT],"ordinary simulation accepts fractional source actor HP")
	expect(env.finish(null).ok,"all battler edits commit as one shared transaction")
	saved=load("res://runtime/scripts/SaveCodec.gd").capture(state)
	expect(load("res://runtime/scripts/SaveCodec.gd").prepare(saved).ok,"enemy additive fields and states round-trip in a detached save")
	var before=state.custom_data.snapshot()
	var isolated=state.custom_data.fork()
	isolated.invoke(enemy,"sp=",["invalid"])
	expect(not isolated.failure.is_empty() and before==state.custom_data.snapshot(),"enemy setter rejects a malformed argument before modifying a value; fatal policy is checked in a separate process")
	var bad=saved.duplicate(true)
	bad.custom_data.floors["10"].entries[str(event_id)].battler.states=[99999]
	expect(not load("res://runtime/scripts/SaveCodec.gd").prepare(bad).ok,"corrupt enemy state reference fails before live restore")
	actor=state.actor(2); actor.clear_states(); actor.set_project_parameter("maxhp",100); actor.hp=80.75; actor.sp=9.25
	var native=state.apply_actor_event(311,[2,1,0,10,true])
	expect(native.ok and actor.hp==70.75,"native actor HP event retains source fractional vitals")
	native=state.apply_actor_event(312,[2,0,0,2])
	expect(native.ok and actor.sp==11.25,"native actor SP event retains source fractional vitals")
	native=state.apply_actor_event(319,[2,4,1])
	expect(native.ok and actor.equipment[4]==1,"native equipment event uses the actual Flash sixth-slot type rules")
	actor.learn_skill(40); actor.learn_skill(41); actor.clear_project_skills()
	Scripts.call_method(ref,"equip_skill",[40,1],state); Scripts.call_method(ref,"equip_skill",[41,2],state)
	result=Scripts.call_method(ref,"swap_skill",[40,41,1,2],state)
	expect(result.ok and actor.project_fields.equip_skills["1"]==41 and actor.project_fields.equip_skills["2"]==40,"source swap_skill cancels both old entries before re-equipping")
	result=Scripts.call_method(ref,"trans_skill",[40,3],state)
	expect(result.ok and not actor.project_fields.equip_skills.has("2") and actor.project_fields.equip_skills["3"]==40,"source trans_skill moves an equipped skill's turn")
	var before_skills=actor.project_fields.equip_skills.duplicate(true)
	isolated=state.custom_data.fork()
	isolated.invoke(ref,"equip_skill",[40,"bad"])
	expect(not isolated.failure.is_empty() and actor.project_fields.equip_skills==before_skills,"skill setter rejects a malformed turn before modifying its configuration")
	result=Scripts.call_method(ref,"set_blastic",[0],state)
	expect(result.ok and actor.project_fields.blastic==0,"source set_blastic accepts the real ID-zero device")
	result=Scripts.call_method(ref,"remove_blastic",[0],state)
	expect(result.ok and actor.project_fields.blastic==null,"source remove_blastic clears the device association")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH BATTLER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

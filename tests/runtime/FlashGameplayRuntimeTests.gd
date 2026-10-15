extends SceneTree
const Actor=preload("res://runtime/scripts/FlashActorState.gd")
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Custom=preload("res://runtime/scripts/CustomDataState.gd")
const Simulator=preload("res://runtime/scripts/FlashBattleSimulator.gd")
const Semantics=preload("res://runtime/scripts/ScriptSemantics.gd")
var failures: Array[String]=[]
var checks=0

func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	var actor=state.actor(2)
	expect(actor is Actor and actor.equipment.size()==6,"Flash selects the source actor with six equipment slots")
	var init_script: GDScript=load("res://runtime/generated/script_0317.gd")
	var init_env=Semantics.new(state)
	init_script.program(init_env)
	expect(init_env.failure.is_empty(),"Actor_Init generated definitions load")
	init_env.begin({"kind":"source_method_test"})
	init_script.program(init_env)
	init_env.invoke(init_env.type_ref("Actor_Init"),"load",[2],"Actor_Init")
	expect(init_env.finish(null).ok and actor.level==2 and actor.get_parameter("maxhp")==250 and actor.hp==100,"actual generated Actor_Init method applies its original preset")
	actor=state.actor(2,true)
	actor.project_fields.tp_plus.patk=20; actor.project_fields.tp_plus.pdef=999
	actor.project_fields.tp_plus.maxhp=100; actor.hp=100
	expect(actor.get_parameter("patk")==20 and actor.get_parameter("pdef")==20,"source pdef uses the patk point key, not an invented correction")
	expect(state.custom_data.actor_attributes(2).tp_plus.patk==20,"actor and script extensions share the same raw attributes")
	expect(actor.set_project_parameter("pdef",5).ok and actor.get_parameter("pdef")==5 and actor.get_parameter("patk")==20,"derived setters preserve independent additive bonuses")
	actor.set_experience(41)
	expect(actor.experience==41 and actor.level==1 and actor.next_level_experience()==30,"experience changes do not bypass source public-event growth")
	var env=Semantics.new(state)
	env.begin({"kind":"test"})
	var ref=env._custom.data_ref("actor",2)
	env._custom.invoke(ref,"patk=",[35]); env._custom.invoke(ref,"hp=",[75])
	expect(actor.get_parameter("patk")==35 and actor.hp==75,"direct script edits immediately update authoritative actor state")
	expect(env.finish(null).ok,"successful direct actor edit completes without replacing the actor")
	# Failure/no-rollback coverage: FlashFailureIsolationProbe / actor
	env.begin({"kind":"test"}); ref=env._custom.data_ref("actor",2)
	env._custom.invoke(ref,"patk=",[35]); env._custom.invoke(ref,"hp=",[75])
	expect(env.finish(null).ok and actor.get_parameter("patk")==35 and actor.hp==75,"successful script commits one shared actor state")
	var detached=actor.detached_copy()
	expect(detached.ok and detached.actor.get_parameter("patk")==35 and detached.actor.hp==75,"event transactions preserve Flash formulas in detached copies")
	state.party=[2]; state.variables["14"]=[2,0]; state.map_id=10
	env.begin({"kind":"test"})
	var gameplay=env._custom.gameplay()
	gameplay.apply_actor_preset(2)
	var preset=env._custom.staged_actor(2)
	expect(preset.level==2 and preset.get_parameter("maxhp")==250 and preset.hp==100 and preset.get_parameter("patk")==5 and preset.get_parameter("pdef")==2,"Actor_Init applies the source preset through real derived setters")
	var floor_data=env._custom._floor(10)
	var enemy_event=int(floor_data.entries.keys()[0])
	var fields: Dictionary=floor_data.entries[str(enemy_event)].fields
	fields.maxhp=35; fields.hp=35; fields.atk=9; fields.pdef=3; fields.agi=10
	preset.set_project_parameter("patk",20); preset.set_project_parameter("pdef",5); preset.set_project_parameter("agi",10)
	var predicted=gameplay.predict(10,enemy_event)
	var repeated=gameplay.predict(10,enemy_event)
	expect(predicted!=null and predicted==repeated and gameplay.simulation_count==1 and preset.hp==100,"unchanged source inputs reuse one prediction without player damage")
	var begun=gameplay.begin_battle(10,enemy_event)
	var begun_twice=gameplay.begin_battle(10,enemy_event)
	expect(begun==begun_twice and floor_data.entries[str(enemy_event)].battle.hp==0 and preset.hp==100,"begin fixes the result and commits only enemy HP once")
	preset.hp-=begun.damage
	var finished=gameplay.finish_battle(10,enemy_event)
	expect(finished!=null and gameplay.finish_battle(10,enemy_event)==null and preset.hp==92,"public-event HP settlement followed by idempotent finish preserves the source boundary")
	expect(env.finish(null).ok and actor.hp==92 and state.custom_data.values.floors["10"].entries[str(enemy_event)].battle.hp==0,"actor vitals and enemy state commit together")
	var captured=load("res://runtime/scripts/SaveCodec.gd").capture(state)
	var prepared=load("res://runtime/scripts/SaveCodec.gd").prepare(captured)
	expect(prepared.ok,"ordinary Flash fields and six equipment slots validate in a detached save: "+str(prepared.get("message","")))
	if prepared.ok:
		state.restore_prepared(prepared)
		expect(state.actor(2).hp==92 and state.actor(2).get_parameter("patk")==20 and is_same(state.actor(2).project_fields,state.custom_data.actor_attributes(2)),"restore reattaches the same actor fields used by script and menu")
	var corrupted=captured.duplicate(true)
	corrupted.custom_data.actors["2"].parameter_plus.patk+=1
	expect(not load("res://runtime/scripts/SaveCodec.gd").prepare(corrupted).ok,"inconsistent duplicated actor data is rejected before changing live state")
	var actions: GDScript=load("res://runtime/scripts/FlashActions.gd")
	var blastic: GDScript=load("res://runtime/scripts/FlashBlastic.gd")
	state.inventory["item:71"]=2; state.inventory["item:72"]=1; state.inventory["item:74"]=1
	var insert: Dictionary=actions.exchange_crystal(state,0,0,71)
	expect(insert.ok and state.inventory["item:71"]==1 and state.custom_data.values.blastics["0"].element[0]==[0,0,1,0,0],"crystal insertion updates the original ID-0 device and the shared backpack")
	var replace: Dictionary=actions.exchange_crystal(state,0,0,72)
	expect(replace.ok and state.inventory["item:71"]==2 and state.inventory["item:72"]==0 and state.custom_data.values.blastics["0"].element[0]==[0,0,3,0,0],"replacement returns old crystal, consumes new crystal, removes old elements before adding")
	# Deliberate invalid script calls: crystal-duplicate / crystal-element / crystal-locked.
	var valid: Dictionary=actions.exchange_crystal(state,0,1,74)
	expect(valid.ok and state.custom_data.values.blastics["0"].element[0]==[1,0,3,0,0],"source category and hole restriction accept a distinct Earth function")
	var remove: Dictionary=actions.exchange_crystal(state,0,0,0)
	expect(remove.ok and state.inventory["item:72"]==1 and state.custom_data.values.blastics["0"].element[0]==[1,0,0,0,0],"removal restores the backpack and subtracts only the removed crystal")
	var unlock=load("res://runtime/scripts/ScriptRuntime.gd").call_method(state.custom_data.data_ref("blastic",0),"unlock",[2],state)
	expect(unlock.ok and state.custom_data.values.blastics["0"].lock[0][2]==true and state.custom_data.values.blastics["0"].lock[0] is Array,"corrected unlock targets the flat-indexed hole, preserving both lock rows")
	var echoes: Array=blastic.echoes(state.custom_data,[4,2,0,0,0],true)
	expect(echoes[0].id==11 and echoes[0].active and echoes.filter(func(row):return not row.active).size()<=3,"echoes retain source thresholds and the three-row preview cap")
	var with_crystals=load("res://runtime/scripts/SaveCodec.gd").capture(state)
	expect(load("res://runtime/scripts/SaveCodec.gd").prepare(with_crystals).ok,"crystal state validates with ordinary Flash actor fields")
	with_crystals.custom_data.blastics["0"].element[0][0]+=1
	expect(not load("res://runtime/scripts/SaveCodec.gd").prepare(with_crystals).ok,"inconsistent saved crystal sums reject before restore")
	var equip: Dictionary=actions.equip(state,2,4,1)
	expect(equip.ok and state.actor(2).equipment[4]==1 and state.actor(2).snapshot().equipment[4].database=="Ornaments","corrected actor equipment setter and snapshot use the six typed source slots")
	state.inventory["item:32"]=1; state.inventory["item:36"]=1; state.inventory["item:23"]=1; state.inventory["item:21"]=1
	var max_before=state.actor(2).get_parameter("maxhp"); var hp_before=state.actor(2).hp
	var used_potion: Dictionary=actions.use_item(state,32)
	expect(used_potion.ok and used_potion.value==true and state.actor(2).get_parameter("maxhp")==max_before+75 and state.actor(2).hp==hp_before and state.inventory["item:32"]==0,"Storage.potion preserves its original MAXHP formula, distinct from common-event HP addition")
	var matk_before=state.actor(2).get_parameter("matk")
	var used_gem: Dictionary=actions.use_item(state,36)
	expect(used_gem.ok and used_gem.value==true and state.actor(2).get_parameter("matk")==matk_before+1 and state.inventory["item:36"]==0,"Storage.gem applies source typed attributes and consumes its actual mapped item")
	state.actor(2).add_state(1)
	var cure: Dictionary=actions.use_item(state,23)
	expect(cure.ok and cure.value==true and not state.actor(2).get_state_ids().has(1) and state.inventory["item:23"]==0,"source cure removes the shared actor state and consumes the potion")
	var empty: Dictionary=actions.use_item(state,21)
	expect(empty.ok and empty.value==null and state.inventory["item:21"]==1,"source unfinished upper branch retains nil result and performs no invented transfer or consumption")
	env.begin({"kind":"cache_source_test"})
	gameplay=env._custom.gameplay()
	var other_event=enemy_event; var other_entry: Dictionary=env._custom._floor(10).entries[str(other_event)]
	other_entry.fields.atk=other_entry.definition_baseline.atk
	other_entry.battle.hp=35; other_entry.battle.defeated=false; other_entry.battle.cache=null
	var other_id=int(other_entry.fields.id)
	var original_gold=int(gameplay.enemy_fields(10,other_event).gold)
	env._custom.invoke(env._custom.data_ref("record",other_id,"Enemies"),"gold=",[original_gold+7])
	expect(env._custom.invoke(env._custom.data_ref("floor_enemy",10,"",other_event),"gold",[])==original_gold+7,"existing map enemy reward getter consumes the current database overlay")
	var old_attack=int(gameplay.enemy_fields(10,other_event).atk)
	var cached=gameplay.predict(10,other_event); var computed_count=gameplay.simulation_count
	env._custom.invoke(env._custom.data_ref("record",other_id,"Enemies"),"atk=",[old_attack+1])
	var changed_prediction=gameplay.predict(10,other_event)
	expect(cached!=null and changed_prediction!=null and gameplay.enemy_input(10,other_event).patk==old_attack+1 and gameplay.simulation_count==computed_count+1,"existing enemy stats and cache follow database updates rather than its creation copy")
	expect(env.finish(null).ok,"database overlay edits finish in the direct source path")
	var sim=Simulator.new(); sim.configure(Custom.native_value(Data.read_json("res://data/flash_gameplay.json",{})))
	expect(sim.validate().is_empty(),"source skill registry is valid")
	var main=battler(1,100,20,5,10)
	var enemy=battler(8,35,9,3,10); enemy.actions=[]; enemy.patience=70
	var before=main.duplicate(true); var enemy_before=enemy.duplicate(true)
	var result=sim.predict(main,{},enemy)
	expect(result.ok and result.result.outcome=="victory" and result.result.damage==8 and result.result.enemy_damage==35 and result.result.main_turns==3 and result.result.enemy_turns==2,"ordinary combat: three 17-point attacks and two 4-point attacks")
	expect(main==before and enemy==enemy_before,"prediction does not mutate inputs")
	main.equip_skills={"1":[41]}; enemy=battler(8,21,9,3,1); enemy.actions=[]
	result=sim.predict(main,{},enemy)
	expect(result.ok and result.result.main_turns==1 and result.result.action_log[1].damage==21,"three-hit action subtracts defense per hit")
	main=battler(1,100,20,5,10); main.equip_skills={"-2":[101,101],"-1":[61]}
	enemy=battler(8,20,9,10,1); enemy.actions=[]
	result=sim.predict(main,{},enemy)
	expect(result.ok and result.result.action_log[1].damage==11 and result.result.action_log[2].damage==1 and result.result.action_log[2].phase=="settlement.reaction_damage","passive IDs deduplicate; pursuit uses the source 10% reaction phase")
	main=battler(1,100,0,5,10)
	var support=battler(2,2,0,0,10)
	enemy=battler(8,100,20,0,20); enemy.actions=[action(45,1,0)]
	result=sim.predict(main,support,enemy)
	expect(result.ok and result.result.outcome=="support_down" and result.result.damage==9 and result.result.support_damage==2 and result.result.enemy_damage==0,"party-target action includes support and ends immediately when support falls")
	main=battler(1,100,0,50,10); enemy=battler(8,100,0,50,10); enemy.actions=[]
	result=sim.predict(main,{},enemy)
	expect(result.ok and result.result.outcome in ["main_action_cap","enemy_action_cap"] and maxi(result.result.main_turns,result.result.enemy_turns)==80 and result.result.patience_delta==-1,"zero-damage combat ends at the actual 80-action cap")
	var rage=sim.skills["0"].duplicate(true); rage.id=200; rage.kind="rage"; rage.rage_rules=[{"patience_limit":50,"description":"change action","effects":[["override",41,40,null,null,null],["grant",43,null,null,true,5]]}]
	sim.skills["200"]=rage
	expect(sim.validate().is_empty(),"native GDScript development can register a validated source rage rule")
	var resolved=sim.resolve_enemy_skills([action(40,1,0),action(200,0,0),action(42,0,1)],40)
	expect(resolved.entries.size()==3 and resolved.entries[0].skill_id==41 and resolved.entries[0].base_skill_id==40 and resolved.entries[2].skill_id==43 and resolved.entries[2].origin=="grant","rage retains original skill identity and replaces only the default slot")
	expect(sim.resolve_enemy_skills([action(40,1,0),action(200,0,0)],50).entries[0].skill_id==40,"rage limit is strict: patience equal to limit stays inactive")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH GAMEPLAY RUNTIME: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func battler(id: int,hp: int,atk: int,defense: int,speed: int) -> Dictionary:
	return {"id":id,"hp":hp,"maxhp":hp,"patk":atk,"pdef":defense,"agi":speed,"matk":atk,"equip_skills":{},"battle_down":false}

func action(id: int,turn: int,period: int) -> Dictionary:
	return {"kind":1,"condition_level":1,"skill_id":id,"condition_turn_a":turn,"condition_turn_b":period,"rating":5}

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

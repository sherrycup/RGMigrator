extends SceneTree
## Source 0072/0073 parity tests; synthetic battlers isolate timing and formulas.
const Simulator=preload("res://runtime/scripts/FlashBattleSimulator.gd")
const StatusAPI=preload("res://runtime/scripts/FlashBattleStateContainer.gd")
const Cache=preload("res://runtime/scripts/FlashBattleCache.gd")
var checks=0
var failures: Array=[]

class DotSimulator extends Simulator:
	func build_context(main: Dictionary,support: Dictionary,enemy: Dictionary,result: Dictionary) -> Dictionary:
		var context=super.build_context(main,support,enemy,result)
		context.enemy.state_container.add(preload("res://runtime/scripts/FlashBattleStateContainer.gd").create_status("burn","dot",1,{"damage":3.75}))
		return context

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/flash_gameplay.json"))
	var sim=Simulator.new(); sim.configure(rules)
	expect(sim.validate().is_empty() and sim.skills.size()==13,"original catalog loads precisely 13 real presets")
	for id in [0,40,41,42,43,44,45,46,61,62,81,101,121]:
		expect(sim.registry.includes(id),"source catalog has ID "+str(id))
	expect(sim.skills["41"].hit_count==3 and sim.skills["41"].atk_rate==0.5 and sim.skills["41"].stiffness==20,"Rake source parameters")
	expect(sim.skills["62"].target=="enemy" and sim.skills["62"].hit_count==4 and sim.skills["62"].atk_rate==0.65 and sim.skills["62"].stiffness==10,"Fourfold fixed-enemy target and formula")
	var main=battler(1,100,20,5,10); var enemy=battler(8,100,9,3,10)
	var context=sim.build_context(main,{},enemy,{})
	for preset in [[0,17],[40,17],[41,21],[42,27],[43,17],[44,37],[62,40]]:
		var attack_context=sim.build_context(main,{},enemy,{"action_log":[]})
		attack_context.phase="settlement.action_damage"
		sim._execute(attack_context,attack_context.main,sim.skill_spec(preset[0],"actor"))
		expect(attack_context.enemy.t_damage==preset[1] and attack_context.main.attack_times==sim.skills[str(preset[0])].hit_count,"source active preset formula and hit count "+str(preset[0]))
	var no_support=sim.build_context(main,{},enemy,{"action_log":[]}); no_support.phase="settlement.action_damage"
	sim._execute(no_support,no_support.enemy,sim.skill_spec(46,"enemy"))
	expect(no_support.main.hp==main.hp and no_support.enemy.attack_times==0,"source support-only attack has no fallback target")
	var party_target=sim.build_context(main,battler(2,100,0,0,10),enemy,{"action_log":[]}); party_target.phase="settlement.action_damage"
	sim._execute(party_target,party_target.enemy,sim.skill_spec(45,"enemy"))
	expect(party_target.main.t_damage==1 and party_target.support.t_damage==6 and party_target.enemy.attack_times==2,"party rock applies separate 70% physical damage and attack count to both targets")
	var self_target=sim.build_context(main,{},enemy,{"action_log":[]}); self_target.phase="settlement.action_damage"
	sim._execute(self_target,self_target.enemy,sim.skill_spec(62,"enemy"))
	expect(self_target.enemy.t_damage==11 and self_target.main.t_damage==0,"Fourfold literal ENEMY target makes enemy users attack themselves")
	expect(sim._delay(context.main,5)==50 and sim._delay(context.main,60)==600,"Quick and Slow retain source stiffness intervals")
	expect(sim.skill_spec(999,"enemy").id==0 and sim.skill_spec(999,"enemy").target=="main" and sim.skill_spec(-1).kind=="wait","unknown ID falls back to original normal attack; internal wait stays distinct")
	expect(sim._actor_actions({"equip_skills":{"1":[null,41],"2":[42],"3":[43],"4":[44],"9":[62]}})=={1:41,2:42,3:43},"source prefix range and first-three active limit")
	var result=sim.predict(main,{},enemy).result
	expect(result.action_log[0].actor=="actor_1" and result.action_log[2].actor=="enemy_1","equal-delay order begins with main then retains sorted timeline order")
	main.agi=100000
	result=sim.predict(main,{},enemy).result
	expect(result.enemy_turns==0 and result.main_turns==6,"zero integer delay retains source ordering")
	main=battler(1,100,0,99,10); enemy=battler(8,100,0,99,10)
	result=sim.predict(main,{},enemy).result
	expect(result.outcome=="enemy_action_cap" and result.main_turns==79 and result.enemy_turns==80 and result.patience_delta==-1,"cap resolves after DOT and schedule; equal delays retain the previously sorted order")
	main=battler(1,100,20,0,10); main.equip_skills={"1":[41],"-1":[61]}; enemy=battler(8,100,0,3,1)
	result=sim.predict(main,{},enemy).result
	expect(result.action_log[1].damage==21 and result.action_log[2].damage==2 and result.action_log[2].phase=="settlement.reaction_damage","10% pursuit follows merged per-hit damage in reaction phase")
	var support=battler(2,100,20,0,10); support.equip_skills={"-1":[61]}; main.equip_skills={}
	result=sim.predict(main,support,enemy).result
	expect(not result.action_log.any(func(row):return row.actor=="actor_2"),"instant pursuit on support has no autonomous action window")
	main=battler(1,100,0,99,10); support=battler(2,100,20,0,10); support.equip_skills={"-1":[81]}; enemy=battler(8,100,0,0,10); enemy.actions=[action(41,0,1)]
	result=sim.predict(main,support,enemy).result
	var support_follow=result.action_log.filter(func(row):return row.actor=="actor_2" and row.kind=="follow_up")
	expect(not support_follow.is_empty() and support_follow[0].damage==16 and support_follow[0].turn==0,"support counter watches main received hit count, including zero-damage hits")
	main=battler(1,100,20,99,10); main.equip_skills={"1":[62],"2":[62],"3":[62]}; support=battler(2,100,10,0,10); support.equip_skills={"-1":[121]}; enemy=battler(8,1000,0,0,1)
	result=sim.predict(main,support,enemy).result
	var counted=result.action_log.filter(func(row):return row.actor=="actor_2" and row.kind=="follow_up")
	expect(not counted.is_empty() and counted[0].damage==15 and counted[0].skill_id==121,"12 main attack hits trigger source 150% support follow-up")
	main=battler(1,100,20,0,10); main.equip_skills={"-2":[101,101]}; support=battler(2,100,0,0,10); support.equip_skills={"-2":[101]}; enemy=battler(8,100,0,10,1)
	var attrs=sim.enemy_attributes(main,support,enemy)
	expect(is_equal_approx(attrs.defense,8.1) and attrs.attack==0 and attrs.maxhp==100,"enemy defense passive deduplicates each holder then multiplies different holders")
	var old_revision=sim.registry.revision
	expect(sim.define_skill(201,func(s):s.display("Power"); s.passive_attack_rate(1.2)).ok and sim.registry.revision==old_revision+1,"GDScript define registers a complete definition and increments revision")
	expect(sim.define_skill(203,func(s):s.extra_attack(1)).ok and sim.define_skill(204,func(s):s.extra_attack(2)).ok,"extra attack GDScript registration")
	expect(sim.define_skill(300,func(s):s.rage(func(r):r.when_patience_below(3,"power",func(e):e.add_skill(201)); r.when_patience_below(1,"upgrade",func(e):e.replace_skill(203,204)))).ok,"GDScript nested rage registration")
	expect(sim.validate().is_empty(),"source ordinary/rage references validate after later definitions")
	var resolved=sim.resolve_enemy_skills([action(203,0,0),action(300,0,0)],0)
	expect(resolved.entries[0].skill_id==204 and resolved.entries[0].base_skill_id==203 and resolved.entries[0].origin=="override","lowest patience override retains source skill identity")
	expect(resolved.entries.size()==3 and resolved.visible_entries.size()==2 and resolved.attack_rate==1.2,"fully-active rage hides only its visible row and yields attack rate")
	resolved=sim.resolve_enemy_skills([action(201,0,0),action(300,0,0)],2)
	expect(resolved.entries.size()==2 and resolved.entries[0].origin=="base" and resolved.visible_entries.size()==2,"existing source skill is never regranted or relabeled")
	expect(sim.resolve_enemy_skills([action(300,0,0)],3).entries.size()==1,"rage threshold comparison is strict")
	expect(sim.define_skill(301,func(s):s.rage(func(r):r.when_patience_below(3,"invalid",func(e):e.add_skill(0,{"default":true})))).ok and not sim.validate().is_empty(),"source rage cannot reference internal ordinary attack ID zero")
	sim.skills.erase("301")
	var revision_before=sim.registry.revision
	expect(not sim.define_skill(400,func(s):s.extra_attack(0)).ok and not sim.registry.includes(400) and sim.registry.revision==revision_before,"invalid DSL input neither registers nor advances revision")
	var second=Simulator.new(); second.configure(rules)
	expect(second.registry.includes(300) and second.registry.revision==sim.registry.revision,"module registration survives new gameplay/transaction simulator instances")
	expect(sim.define_skill(201,func(s):s.action("support",2.0)).ok and sim.skills["201"].kind=="damage" and sim.skills["201"].atk_rate==2.0,"same-ID define replaces the whole original definition")
	var db=sim.registry.database_fields(201)
	expect(db.scope==1 and db.power==20 and db.atk_f==200 and db.element_set==[31] and db.plus_state_set.is_empty(),"source database synchronization fields and support target marker")
	db=sim.registry.database_fields(45)
	expect(db.scope==2 and db.element_set==[32] and db.atk_f==70,"party target source compatibility marker")
	# Changing a previously passive skill into an action makes the old rage grant
	# invalid; remove that synthetic registration before the unrelated simulation.
	expect(not sim.validate().is_empty(),"registry replacement revalidates dependent rage category")
	sim.skills.erase("300")
	main=battler(1,100,20,0,10); main.equip_skills={"1":[41],"-2":[203,203]}; enemy=battler(8,35,0,3,1)
	result=sim.predict(main,{},enemy).result
	expect(result.main_turns==1 and result.action_log[1].damage==38 and result.enemy_damage==35,"extra ordinary segment subtracts defense separately, passive IDs deduplicate")
	var holder={"hp":20,"t_damage":0,"attacked_times":0}; var states=StatusAPI.new()
	states.add(StatusAPI.create_status("buff","stat",1,{"atk_rate":2.0,"atk_plus":3.0}))
	states.add(StatusAPI.create_status("debuff","stat",null,{"atk_rate":0.5,"atk_plus":-1.0}))
	expect(states.stat_rate("atk_rate")==1.0 and states.stat_plus("atk_plus")==2.0,"source status rates multiply and additive modifiers sum")
	states.tick_action_window(); expect(states.statuses.size()==2 and states.statuses[0].duration_windows==1,"fresh status does not lose a duration window")
	states.tick_action_window(); expect(states.statuses.size()==1 and states.statuses[0].duration_windows==null,"expired status removed while permanent status remains")
	var dot=StatusAPI.create_status("dot","dot",null,{"damage":1.75}); dot.stack_count=2; states.add(dot)
	dot.stack_count=3; expect(states.statuses.back().stack_count==3,"source status identity supports stack changes after add")
	dot.stack_count=2
	var events=states.resolve_action_end(holder)
	expect(holder.hp==17 and holder.t_damage==3 and holder.attacked_times==1 and events[0].damage==3.5,"DOT multiplies stacks before receive_damage truncation and retains original log value")
	var dot_sim=DotSimulator.new(); dot_sim.configure(rules)
	main=battler(1,100,0,99,10); enemy=battler(8,3,0,99,10)
	result=dot_sim.predict(main,{},enemy).result
	expect(result.outcome=="victory" and result.main_turns==1 and result.enemy_turns==1 and result.action_log.back().kind=="state_damage" and result.action_log.back().phase=="settlement.dot_damage","source state container participates in the actual third settlement phase")
	var cache=Cache.new(); var aura={"power":1}; var calls={"count":0}
	expect(cache.register_condition("aura",func(input):calls.count+=1; input.hp=999; return [aura.power,{"field":2}]).ok,"cache extension accepts a value provider")
	var party=[main,{}]; var before=enemy.duplicate(true)
	var tag1=cache.tag_for("10:1",party,enemy,sim.skills,sim.registry.revision)
	aura.power=2
	var tag2=Cache.new().tag_for("10:1",party,enemy,sim.skills,sim.registry.revision)
	expect(tag1.ok and tag2.ok and tag1.tag!=tag2.tag and enemy==before,"providers persist across transactions, invalidate on changed values, and cannot mutate enemy inputs")
	var before_count=int(calls.count)
	cache.with_party_snapshot(func():cache.tag_for("10:1",party,enemy,sim.skills,sim.registry.revision); aura.power=3; cache.tag_for("10:1",party,enemy,sim.skills,sim.registry.revision))
	expect(calls.count==before_count+1,"read-only batch calculates each enemy tag once")
	cache.tag_for("10:1",party,enemy,sim.skills,sim.registry.revision)
	expect(calls.count==before_count+2,"batch cache expires immediately after scoped callback")
	cache.register_condition("bad",func(input):return RefCounted.new())
	expect(not cache.tag_for("10:1",party,enemy,sim.skills,sim.registry.revision).ok,"live objects are explicitly rejected as cache conditions")
	Cache.conditions.clear()
	for message in failures: printerr("FAIL: ",message)
	print("FLASH BATTLE CORE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func battler(id: int,hp: int,atk: int,defense: int,speed: int) -> Dictionary:
	return {"id":id,"hp":hp,"maxhp":hp,"patk":atk,"pdef":defense,"agi":speed,"matk":atk,"equip_skills":{},"battle_down":false,"actions":[],"patience":99}

func action(id: int,turn: int,period: int) -> Dictionary:
	return {"kind":1,"condition_level":1,"skill_id":id,"condition_turn_a":turn,"condition_turn_b":period,"rating":5}

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

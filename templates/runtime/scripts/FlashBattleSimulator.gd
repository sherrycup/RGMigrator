extends RefCounted
## 0072 BattleSystem: SkillRegistry, EnemySkills, DatabaseAdapter, AttributeCalculator,
## BattlerRuntime, Timeline, TargetResolver, FollowUpResolver and Simulator.
## Inputs are detached values. Neither prediction nor simulation mutates live HP.
const REACTIONS=["follow_up_damage","follow_up_counter","follow_up_attack_count"]
const PASSIVES=["passive_enemy_defense_rate","passive_attack_rate","extra_attack"]
const Registry=preload("FlashBattleRegistry.gd")
const Catalog=preload("FlashBattleCatalog.gd")
const StateContainer=preload("FlashBattleStateContainer.gd")
var registry=Registry.new()
var skills: Dictionary={}
var constants: Dictionary={}
var failure=""
var catalog_failure=""

func configure(rules: Dictionary) -> void:
	var installed: Dictionary=Catalog.install_catalog(registry,rules.get("skills",{}))
	catalog_failure="" if installed.ok else installed.message
	skills=registry.definitions
	constants=rules.get("constants",{}).duplicate(true)

func validate() -> String:
	if not catalog_failure.is_empty(): return catalog_failure
	if not skills.has("0"): return "闪翼普通战斗技能注册表未加载（缺少 0073 的普攻）。"
	for key in skills:
		var skill: Variant=skills[key]
		if not skill is Dictionary or not str(key).is_valid_int() or int(key)<0: return "技能注册ID无效。"
		if not _integer(skill.get("id")) or int(skill.id)!=int(key): return "技能定义与注册 ID 不一致："+str(key)
		for field in ["hit_count","stiffness","threshold","extra_attacks"]:
			var n: Variant=skill.get(field)
			if not _integer(n) or n<0: return "技能整数参数无效："+key+"."+field
		if skill.hit_count<1 or skill.kind=="damage" and skill.stiffness<1: return "主动技能连击数/硬直必须为正数："+key
		if not _number(skill.get("atk_rate")) or skill.atk_rate<0: return "技能倍率无效："+key
		if skill.get("target") not in ["opponent","enemy","main","support","party","self","none"]: return "技能目标无效："+key
		if skill.get("kind") not in ["damage","wait","rage"]+REACTIONS+PASSIVES: return "技能类型无效："+key
		if skill.kind=="passive_attack_rate" and skill.atk_rate<=0 or skill.kind=="extra_attack" and skill.extra_attacks<=0: return "被动技能参数必须为正数："+key
		if not skill.get("instant_follow_up",false) is bool: return "追击标志必须为布尔值："+key
		if skill.kind=="rage" and (not skill.get("rage_rules") is Array or skill.rage_rules.is_empty()): return "狂暴技能缺少规则："+key
		for rule in skill.get("rage_rules",[]):
			if not rule is Dictionary or not _integer(rule.get("patience_limit")) or rule.patience_limit<1 or rule.patience_limit>100 or not rule.get("effects") is Array or rule.effects.is_empty(): return "狂暴规则无效："+key
			for effect in rule.effects:
				if not effect is Array or effect.size()!=6 or effect[0] not in ["grant","override"]: return "狂暴效果无效："+key
				if not _integer(effect[1]) or effect[1]<=0 or not skills.has(str(effect[1])) or skills[str(effect[1])].kind not in ["damage"]+REACTIONS+PASSIVES: return "狂暴引用未注册的正整数普通技能："+key
				if effect[0]=="override" and (not _integer(effect[2]) or effect[2]<=0 or effect[1]==effect[2] or not skills.has(str(effect[2])) or skills[str(effect[2])].kind not in ["damage"]+REACTIONS+PASSIVES): return "狂暴替换来源无效："+key
				if effect[0]=="grant":
					if effect[3]!=null and (not _integer(effect[3]) or effect[3]<=0) or effect[4]!=null and effect[4]!=true or effect[3]!=null and effect[4]!=null: return "狂暴行动槽无效："+key
					if not _integer(effect[5]) or effect[5]<1 or effect[5]>10: return "狂暴优先级无效："+key
					var action: bool=skills[str(effect[1])].kind=="damage"
					if action and effect[3]==null and effect[4]!=true or not action and (effect[3]!=null or effect[4]!=null): return "狂暴行动位置与技能类型不一致："+key
				if effect[0]=="override" and (skills[str(effect[1])].kind=="damage")!=(skills[str(effect[2])].kind=="damage"): return "狂暴替换改变主动/非主动类别："+key
	return ""

func define_skill(id: int,builder: Callable=Callable()) -> Dictionary:
	var result: Dictionary=registry.define_skill(id,builder)
	# The dictionary itself stays shared, so a registry replacement becomes visible
	# immediately without replacing live actor/enemy objects.
	skills=registry.definitions
	return result

func resolve_enemy_skills(actions: Array,patience: int) -> Dictionary:
	var entries: Array=[]
	for action in actions:
		var entry: Dictionary=action.duplicate(true)
		if int(entry.get("kind",0))==0: entry.skill_id=0
		entry.base_skill_id=int(entry.get("skill_id",0)); entry.origin="base"; entry.source_skill_id=null; entry.source_rule_index=null
		entries.append(entry)
	var progress: Dictionary={}; var active: Array=[]
	for order in entries.size():
		var entry: Dictionary=entries[order]; var key=str(entry.get("skill_id",0))
		if not _battle_skill(entry) or not skills.has(key) or skills[key].kind!="rage" or progress.has(key): continue
		progress[key]=[]
		for i in skills[key].get("rage_rules",[]).size():
			var rule: Dictionary=skills[key].rage_rules[i]
			progress[key].append([rule.patience_limit,rule.get("description",""),patience<rule.patience_limit])
			if patience<rule.patience_limit: active.append([-int(rule.patience_limit),order,i,int(key),rule])
	active.sort_custom(func(a,b): return a[0]<b[0] if a[0]!=b[0] else a[1]<b[1] if a[1]!=b[1] else a[2]<b[2])
	for applied in active:
		for effect in applied[4].effects:
			if effect[0]=="grant":
				if entries.any(func(e):return _battle_skill(e) and int(e.get("skill_id",0))==int(effect[1])): continue
				if effect[4]==true:
					entries=entries.filter(func(e):return int(e.get("kind",0))!=0 and not (_battle_skill(e) and _action_skill(e.get("skill_id",0)) and int(e.get("condition_turn_a",0))==0 and int(e.get("condition_turn_b",0))==1))
				entries.append({"kind":1,"condition_level":1,"skill_id":effect[1],"base_skill_id":effect[1],"condition_turn_a":effect[3] if effect[3]!=null else 0,"condition_turn_b":1 if effect[4]==true else 0,"rating":effect[5],"origin":"grant","source_skill_id":applied[3],"source_rule_index":applied[2]})
			else:
				for entry in entries:
					if _battle_skill(entry) and (entry.skill_id==effect[2] or entry.base_skill_id==effect[2]):
						entry.skill_id=effect[1]; entry.origin="override"; entry.source_skill_id=applied[3]; entry.source_rule_index=applied[2]
	var visible: Array=[]; var attack_rate=1.0; var passive_ids: Array=[]
	for entry in entries:
		var key=str(entry.skill_id); var stages: Array=progress.get(key,[])
		if not (_battle_skill(entry) and progress.has(key) and stages.all(func(stage):return stage[2])): visible.append(entry.duplicate(true))
		if _battle_skill(entry) and not passive_ids.has(entry.skill_id) and skills.get(key,{}).get("kind")=="passive_attack_rate":
			attack_rate*=float(skills[key].atk_rate); passive_ids.append(entry.skill_id)
	return {"entries":entries,"visible_entries":visible,"rage_progress":progress,"patience":patience,"attack_rate":attack_rate}

func predict(main: Dictionary,support: Dictionary,enemy: Dictionary) -> Dictionary:
	failure=validate()
	if not failure.is_empty(): return {"ok":false,"message":failure}
	for input in [main,support,enemy]:
		if input.is_empty(): continue
		for key in ["id","hp","maxhp","patk","pdef","agi"]:
			if not (_number(input.get(key)) if key=="hp" else _integer(input.get(key))) or input[key]<0: return {"ok":false,"message":"战斗输入无效："+key}
	var result=_empty_result()
	if main.is_empty() or main.get("battle_down",false): result.outcome="party_defeat"; return {"ok":true,"result":result}
	if enemy.is_empty(): return {"ok":false,"message":"未指定地图敌人。"}
	if enemy.get("defeated",false) or enemy.hp<=0: result.outcome="victory"; return {"ok":true,"result":result}
	var context=build_context(main,support,enemy,result)
	var timelines: Array=[context.main,context.enemy]
	for cycle in 1000:
		for runtime in context.runtimes: runtime.t_damage=0
		# The source timeline keeps its sorted array; equal delays retain that order.
		if timelines[1].delay<timelines[0].delay: timelines.reverse()
		var user: Dictionary=timelines[0]; var elapsed=int(user.delay)
		for runtime in timelines: runtime.delay-=elapsed
		user.turn_count+=1
		var id: int=int(context.main_actions.get(user.turn_count,0)) if user.role=="main" else int(context.enemy_actions.get(user.turn_count,context.enemy_default))
		var spec=skill_spec(id,user.side)
		context.phase="settlement.action_damage"
		_execute(context,user,spec)
		if _hp_end(context): break
		context.phase="settlement.reaction_damage"
		_follow(context,user)
		if _hp_end(context): break
		context.phase="settlement.dot_damage"
		for event in user.state_container.resolve_action_end(user): _log(context,user,event.name,0,"state_damage",event.damage)
		if _hp_end(context): break
		_tick_statuses(user)
		user.delay+=_delay(user,int(spec.stiffness))
		if context.main.turn_count>=int(constants.get("BattleSystem::MAIN_ACTION_CAP",80)): result.outcome="main_action_cap"; break
		if context.enemy.turn_count>=int(constants.get("BattleSystem::ENEMY_ACTION_CAP",80)): result.outcome="enemy_action_cap"; break
	if result.outcome==null: result.outcome="enemy_action_cap"
	result.main_turns=context.main.turn_count; result.enemy_turns=context.enemy.turn_count
	result.damage=max(main.hp-context.main.hp,0)
	result.support_damage=max(support.hp-context.support.hp,0) if not support.is_empty() else 0
	result.enemy_damage=max(enemy.hp-context.enemy.hp,0)
	result.patience_delta=0 if result.outcome=="victory" else -1
	if context.main.hp<=0: result.battle_down_actor_ids.append(main.id)
	if not support.is_empty() and context.support.hp<=0: result.battle_down_actor_ids.append(support.id)
	return {"ok":true,"result":result}

func enemy_attributes(main: Dictionary,support: Dictionary,enemy: Dictionary) -> Dictionary:
	var context=build_context(main,support,enemy,_empty_result())
	# Keep the existing display aliases alongside the original Ruby keys.
	return {"hp":context.enemy.maxhp,"maxhp":context.enemy.maxhp,"atk":_attribute(context.enemy,"atk"),"attack":_attribute(context.enemy,"atk"),"def":_attribute(context.enemy,"def"),"defense":_attribute(context.enemy,"def"),"speed":_attribute(context.enemy,"speed"),"magic_attack":enemy.get("matk",0)}

func skill_spec(id: int,side: String="actor") -> Dictionary:
	if id==-1: return {"id":-1,"name":"Wait","kind":"wait","target":"none","stiffness":5,"hit_count":1,"atk_rate":1.0,"threshold":0,"instant_follow_up":false,"extra_attacks":0}
	var spec: Dictionary=skills.get(str(id),skills.get("0",{"id":0,"name":"普通攻击","kind":"damage","target":"opponent","stiffness":20,"hit_count":1,"atk_rate":1.0,"threshold":0,"instant_follow_up":false,"extra_attacks":0})).duplicate(true)
	if spec.target=="opponent": spec.target="enemy" if side=="actor" else "main"
	return spec

func legacy_log(result: Dictionary) -> Array:
	var rows: Array=[]
	for entry in result.action_log:
		if entry.kind in ["action","follow_up"]: rows.append([entry.actor,entry.skill_id,entry.turn,1 if entry.kind=="follow_up" else 0])
	return rows

func _empty_result() -> Dictionary:
	return {"outcome":null,"damage":0,"support_damage":0,"enemy_damage":0,"main_turns":0,"enemy_turns":0,"main_actor_id":0,"support_actor_id":0,"patience_delta":0,"battle_down_actor_ids":[],"action_log":[]}

func build_context(main: Dictionary,support: Dictionary,enemy: Dictionary,result: Dictionary) -> Dictionary:
	var m=_runtime(main,"main","actor"); var s=_runtime(support,"support","actor") if not support.is_empty() else {}; var e=_runtime(enemy,"enemy","enemy")
	var runtimes=[m,e] if s.is_empty() else [m,s,e]
	var resolved=resolve_enemy_skills(enemy.get("actions",[]),int(enemy.get("patience",0)))
	e.skill_set=resolved
	result.main_actor_id=int(main.get("id",0)); result.support_actor_id=int(support.get("id",0))
	var context={"main":m,"support":s,"enemy":e,"runtimes":runtimes,"result":result,"phase":null,"main_actions":_actor_actions(main),"enemy_actions":{},"enemy_default":0}
	var candidates: Array=[]
	for i in resolved.entries.size():
		var entry: Dictionary=resolved.entries[i]
		if not _battle_skill(entry) or not _action_skill(entry.get("skill_id",0)): continue
		var turn=int(entry.get("condition_turn_a",0)); var period=int(entry.get("condition_turn_b",0))
		if turn==0 and period==1 and context.enemy_default==0: context.enemy_default=entry.skill_id
		if turn>0: candidates.append([turn,-int(entry.get("rating",5)),i,int(entry.skill_id)])
	candidates.sort_custom(func(a,b):return a[0]<b[0] if a[0]!=b[0] else a[1]<b[1] if a[1]!=b[1] else a[2]<b[2])
	for candidate in candidates:
		if not context.enemy_actions.has(candidate[0]): context.enemy_actions[candidate[0]]=candidate[3]
	for holder in runtimes:
		for skill_id in _category_ids(holder,PASSIVES):
			var spec=skill_spec(skill_id)
			match spec.kind:
				"passive_enemy_defense_rate": e.passive_defense_rate*=spec.atk_rate
				"passive_attack_rate": holder.passive_attack_rate*=spec.atk_rate
				"extra_attack": holder.extra_attacks+=int(spec.extra_attacks)
	return context

func _runtime(source: Dictionary,role: String,side: String) -> Dictionary:
	var runtime={"source":source,"role":role,"side":side,"id":int(source.get("id",0)),"maxhp":int(source.get("maxhp",0)),"hp":min(max(source.get("hp",0),0),int(source.get("maxhp",0))),"statuses":[],"turn_count":0,"attack_times":0,"attacked_times":0,"t_damage":0,"follow_counts":{},"passive_defense_rate":1.0,"passive_attack_rate":1.0,"extra_attacks":0,"skill_set":{},"delay":0}
	runtime.state_container=StateContainer.new(); runtime.statuses=runtime.state_container.statuses
	runtime.delay=_delay(runtime,int(constants.get("BattleSystem::DEFAULT_STIFFNESS",20)))
	return runtime

func _actor_actions(source: Dictionary) -> Dictionary:
	var result: Dictionary={}
	if source.get("battle_down",false): return result
	var slots: Dictionary=source.get("equip_skills",{}); var keys=slots.keys()
	keys.sort_custom(func(a,b):return int(a)<int(b))
	for key in keys:
		var turn=int(key)
		if turn<=0 or turn>int(constants.get("BattleSystem::PREFIX_ACTION_CAP",8)) or result.size()>=int(constants.get("BattleSystem::MAIN_ACTIVE_LIMIT",3)): continue
		var values: Array=slots[key] if slots[key] is Array else [slots[key]]
		for id in values:
			if id!=null and _action_skill(id): result[turn]=int(id); break
	return result

func _category_ids(holder: Dictionary,kinds: Array) -> Array:
	var ids: Array=[]
	if holder.side=="actor":
		if holder.source.get("battle_down",false): return []
		var slots: Dictionary=holder.source.get("equip_skills",{}); var keys=slots.keys()
		keys.sort_custom(func(a,b):return int(a)<int(b))
		for key in keys:
			for id in slots[key] if slots[key] is Array else [slots[key]]:
				if id!=null: ids.append(int(id))
	else:
		for entry in holder.skill_set.entries:
			if _battle_skill(entry): ids.append(int(entry.get("skill_id",0)))
	var result: Array=[]
	for id in ids:
		if skills.has(str(id)) and skills[str(id)].kind in kinds and not result.has(id): result.append(id)
	return result

func _attribute(holder: Dictionary,key: String) -> float:
	var base=float(holder.source.get({"atk":"patk","def":"pdef","speed":"agi"}[key],0))
	var rate: float=holder.state_container.stat_rate(key+"_rate"); var plus: float=holder.state_container.stat_plus(key+"_plus")
	var value=base*rate+plus
	return maxf(value,1) if key=="speed" else value*float(holder.passive_attack_rate if key=="atk" else holder.passive_defense_rate)

func _damage(attacker: Dictionary,target: Dictionary,rate: float,hits: int) -> int:
	# Source sums Float damage per hit before truncation; keep that ordering even
	# where multiplication could round differently at an integer boundary.
	var total=0.0
	for hit in maxi(hits,1): total+=maxf(_attribute(attacker,"atk")*rate-_attribute(target,"def"),0)
	return int(total)

func _delay(holder: Dictionary,stiffness: int) -> int:
	return int(float(constants.get("BattleSystem::DELAY_CONST",100))*maxi(stiffness,1)/_attribute(holder,"speed"))

func _receive(holder: Dictionary,damage: int,hits: int) -> void:
	damage=maxi(damage,0); holder.hp=max(holder.hp-damage,0)
	holder.t_damage+=damage; holder.attacked_times+=maxi(hits,1)

func _execute(context: Dictionary,user: Dictionary,spec: Dictionary) -> void:
	_log(context,user,spec.name,spec.id,"action",0)
	if spec.kind=="wait" or spec.target=="none": return
	var targets: Array=[]
	match spec.target:
		"enemy": targets=[context.enemy]
		"main": targets=[context.main]
		"support": targets=[context.support]
		"party": targets=[context.main,context.support]
		"self": targets=[user]
	for target in targets:
		if target.is_empty() or not _alive(target): continue
		var damage=_damage(user,target,float(spec.atk_rate),int(spec.hit_count))
		if user.extra_attacks>0: damage+=_damage(user,target,1.0,int(user.extra_attacks))
		var hits=maxi(int(spec.hit_count),1)+int(user.extra_attacks)
		_receive(target,damage,hits); user.attack_times+=hits
		_log(context,user,spec.name,spec.id,"damage",damage)
		if target.hp<=0 and spec.target!="party": break

func _follow(context: Dictionary,user: Dictionary) -> void:
	var order=[context.main,context.support,context.enemy] if user.side=="actor" else [context.enemy,context.support,context.main]
	for holder in order:
		if holder.is_empty() or not _alive(holder): continue
		for id in _category_ids(holder,REACTIONS):
			var spec=skill_spec(id,holder.side)
			if spec.instant_follow_up and not is_same(holder,user): continue
			var target: Dictionary=context.enemy if holder.side=="actor" else context.main
			if not _alive(target): continue
			if spec.kind=="follow_up_damage":
				# The original resolver uses 10%, independent of the DSL rate field.
				var damage=int(float(target.t_damage)*0.1)
				if damage>0:
					_receive(target,damage,1); holder.attack_times+=1; _log(context,holder,spec.name,id,"follow_up",damage)
			else:
				var watched: Dictionary=context.main if spec.kind=="follow_up_attack_count" or holder.role=="support" else holder
				var count=int(watched.attack_times if spec.kind=="follow_up_attack_count" else watched.attacked_times)
				var current=int(count/maxi(int(spec.threshold),1)); var used=int(holder.follow_counts.get(id,0))
				for i in maxi(current-used,0):
					if not _alive(target): break
					var damage=_damage(holder,target,float(spec.atk_rate),1)
					_receive(target,damage,1); holder.attack_times+=1; holder.follow_counts[id]=int(holder.follow_counts.get(id,0))+1
					_log(context,holder,spec.name,id,"follow_up",damage)
			if context.enemy.hp<=0 or context.main.hp<=0 or not context.support.is_empty() and context.support.hp<=0: return

func _tick_statuses(holder: Dictionary) -> void:
	holder.state_container.tick_action_window(); holder.statuses=holder.state_container.statuses

func _hp_end(context: Dictionary) -> bool:
	if context.enemy.hp<=0: context.result.outcome="victory"
	elif context.main.hp<=0: context.result.outcome="main_down"
	elif not context.support.is_empty() and context.support.hp<=0: context.result.outcome="support_down"
	return context.result.outcome!=null

func _log(context: Dictionary,user: Dictionary,name: String,id: int,kind: String,damage: Variant) -> void:
	context.result.action_log.append({"actor":"actor_1" if user.role=="main" else "actor_2" if user.role=="support" else "enemy_1","skill_id":id,"skill_name":name,"turn":user.turn_count,"kind":kind,"phase":context.phase,"damage":damage})

func _alive(holder: Dictionary) -> bool: return holder.hp>0 and not holder.source.get("battle_down",false)
func _battle_skill(entry: Dictionary) -> bool: return int(entry.get("kind",0))==1 and int(entry.get("condition_level",0))==1
func _action_skill(id: Variant) -> bool: return skills.has(str(id)) and skills[str(id)].kind=="damage"
static func _number(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
static func _integer(value: Variant) -> bool: return _number(value) and float(value)==floor(float(value)) and abs(float(value))<=9007199254740991.0

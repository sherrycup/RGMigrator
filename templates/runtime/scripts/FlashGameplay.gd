extends RefCounted
## Source service map: 0005 bindings, 0070/0071 enemies, 0072 PartyRoles/cache/
## EventSettlement and 0317 Actor_Init. Owned by the custom-data transaction.
const Simulator=preload("FlashBattleSimulator.gd")
const Data=preload("RuntimeData.gd")
const Enemy=preload("FlashEnemyState.gd")
const BattleCache=preload("FlashBattleCache.gd")
var rules: Dictionary={}
var simulator: RefCounted
var simulation_count=0
var cache_service=BattleCache.new()
var _custom: WeakRef

func _init(custom: RefCounted,definitions: RefCounted=null) -> void:
	_custom=weakref(custom)
	simulator=Simulator.new()
	if definitions!=null:
		# Rules and catalog definitions are read-only; prediction state stays local.
		rules=definitions.rules
		simulator.skills=definitions.simulator.skills; simulator.constants=definitions.simulator.constants
		simulator.catalog_failure=definitions.simulator.catalog_failure
		return
	rules=custom.native_value(Data.read_json("res://data/flash_gameplay.json",{}))
	simulator.configure(rules)

func role_ids(initialize_main: bool=false,synchronize: bool=false) -> Array:
	var c=_custom.get_ref(); var variables: Dictionary=c.script_variables if c.script_variables!=null else c._owner.get_ref().variables
	var key=str(rules.get("constants",{}).get("TEAMMATES",14))
	var stored: Variant=variables.get(key,[])
	var ids: Array=stored.duplicate() if stored is Array else []
	while ids.size()<2: ids.append(0)
	if int(ids[0])>0 and not initialize_main and not synchronize: return ids
	var party: Array=c.party_ids if c._draft_gold!=null else c._owner.get_ref().party
	if party.is_empty(): ids=[0,0]
	elif not party.has(int(ids[0])):
		ids=[int(ids[1]) if party.has(int(ids[1])) else int(party[0]) if initialize_main else 0,0]
	if int(ids[1])<=0 or ids[1]==ids[0] or not party.has(int(ids[1])): ids[1]=0
	variables[key]=ids
	return ids

func role_actor_ids() -> Array:
	var c=_custom.get_ref(); var ids=role_ids(); var party: Array=c.party_ids if c._draft_gold!=null else c._owner.get_ref().party
	var main_id=int(ids[0]); var support_id=int(ids[1])
	if main_id<=0:
		var index=int(c.values.system.get("main_actor_index",0))
		main_id=int(party[index]) if index>=0 and index<party.size() else int(party[0]) if not party.is_empty() else 1
	return [main_id,support_id]

func party_snapshot() -> Array:
	var c=_custom.get_ref(); var ids=role_actor_ids()
	var main_id=int(ids[0]); var support_id=int(ids[1])
	var main=c.staged_actor(main_id) if not Data.record("Actors",main_id).is_empty() else null
	var support=c.staged_actor(support_id) if support_id>0 else null
	if main!=null and main.battle_down() and support!=null and not support.battle_down(): main=support; support=null
	if support!=null and support.battle_down(): support=null
	return [actor_input(main),actor_input(support)]

func party_cache_inputs() -> Array:
	var c=_custom.get_ref(); var ids=role_actor_ids(); var result: Array=[]
	for id in ids: result.append(actor_input(c.staged_actor(int(id))) if id>0 else {})
	return result

func actor_input(actor: RefCounted) -> Dictionary:
	if actor==null: return {}
	var input={"id":actor.id,"hp":actor.hp,"states":actor.state_ids.duplicate(),"battle_down":actor.battle_down(),"equip_skills":actor.project_fields.equip_skills.duplicate(true)}
	for key in actor.PROJECT_KEYS: input[key]=actor.get_parameter(key)
	return input

func enemy_input(map_id: int,event_id: int) -> Dictionary:
	var c=_custom.get_ref(); var entry: Dictionary=c._floor(map_id).entries.get(str(event_id),{})
	if entry.is_empty(): c.reject("地图事件不是有效的闪翼怪物：%d/%d" % [map_id,event_id]); return {}
	return Enemy.new(c,entry,enemy_fields(map_id,event_id),map_id,event_id).input()

func enemy_fields(map_id: int,event_id: int) -> Dictionary:
	# Game_Enemy getters refer to the current database; per-instance edits stay
	# local. The baseline identifies edits without freezing later CE17 changes.
	var c=_custom.get_ref(); var entry: Dictionary=c._floor(map_id).entries.get(str(event_id),{})
	if entry.is_empty(): c.reject("楼层怪物不存在。"); return {}
	var live: Dictionary=c.record("Enemies",int(entry.fields.id))
	var baseline: Dictionary=entry.get("definition_baseline",Data.source_record("Enemies",int(entry.fields.id)))
	for key in entry.fields:
		if not baseline.has(key) or not c.same_value(entry.fields[key],baseline[key]): live[key]=entry.fields[key]
	return live

func predict(map_id: int,event_id: int,force: bool=false) -> Variant:
	var c=_custom.get_ref(); var enemy=enemy_input(map_id,event_id)
	if enemy.is_empty(): return null
	var battle: Dictionary=c._floor(map_id).entries[str(event_id)].battle
	if battle.pending!=null: return battle.pending.duplicate(true)
	var party=party_snapshot()
	var tagged=cache_service.tag_for("%d:%d" % [map_id,event_id],party_cache_inputs(),enemy,simulator.skills,simulator.registry.revision)
	if not tagged.ok: return c.reject(tagged.message)
	var tag: Dictionary=tagged.tag
	if force or battle.cache==null or not c.same_value(battle.cache.tag,tag):
		var computed=simulator.predict(party[0],party[1],enemy)
		if not computed.ok: return c.reject(computed.message)
		simulation_count+=1
		battle.cache={"tag":tag.duplicate(true),"result":computed.result.duplicate(true)}
	return battle.cache.result.duplicate(true)

func begin_battle(map_id: int,event_id: int) -> Variant:
	var c=_custom.get_ref(); var enemy=enemy_input(map_id,event_id)
	if enemy.is_empty(): return null
	var battle: Dictionary=c._floor(map_id).entries[str(event_id)].battle
	if battle.pending!=null: return battle.pending.duplicate(true)
	if enemy.defeated: return c.reject("不能对已经死亡的怪物重复开战。")
	var result: Variant=predict(map_id,event_id)
	if result==null: return null
	battle.pending=result.duplicate(true); battle.pending_skills=simulator.resolve_enemy_skills(enemy.actions,enemy.patience)
	battle.patience_deferred=true; battle.hp=maxi(int(battle.hp)-int(result.enemy_damage),0)
	battle.defeated=battle.hp<=0; battle.cache=null
	return result

func finish_battle(map_id: int,event_id: int) -> Variant:
	var c=_custom.get_ref(); var enemy=enemy_input(map_id,event_id)
	if enemy.is_empty(): return null
	var battle: Dictionary=c._floor(map_id).entries[str(event_id)].battle
	if battle.pending==null: return null
	var result: Dictionary=battle.pending.duplicate(true)
	if battle.patience_deferred: battle.patience=clampi(int(battle.patience)+int(result.patience_delta),0,99); battle.patience_deferred=false
	var newly_down: Array=[]
	for id in [result.main_actor_id,result.support_actor_id]:
		if id<=0 or newly_down.has(id): continue
		var actor=c.staged_actor(int(id))
		if actor!=null and actor.hp<=0: actor.inflict_battle_down(); newly_down.append(int(id))
	var ids=role_actor_ids(); var main=c.staged_actor(int(ids[0])) if ids[0]>0 else null; var support=c.staged_actor(int(ids[1])) if ids[1]>0 else null
	if main!=null and main.battle_down() and support!=null and not support.battle_down():
		c.script_variables[str(rules.get("constants",{}).get("TEAMMATES",14))]=[support.id,main.id]
		load_skill_set(support,0,"atk"); load_skill_set(main,0,"sup")
		var old=main; main=support; support=old
	var defeated=main==null or main.battle_down() and (support==null or support.battle_down())
	if defeated:
		if not Data.record("CommonEvents",12).is_empty(): c.pending_effects["common_event"]={"id":12,"source":"flash_party_defeat","actor_id":0,"target_id":0}; c.pending_effects["ending_id"]=1
		else: c.pending_effects["gameover"]=true
	else:
		for id in c.party_ids if c._draft_gold!=null else c._owner.get_ref().party:
			var actor=c.staged_actor(int(id))
			if actor!=null and actor.battle_down() and not newly_down.has(int(id)): actor.tick_battle_down_recovery()
	battle.pending=null; battle.pending_skills=null; battle.cache=null
	return result

func load_skill_set(actor: RefCounted,index: int,side: String) -> Variant:
	var c=_custom.get_ref()
	var result: Dictionary=actor.load_project_skill_set(index,side)
	return null if result.ok else c.reject(result.message)

func apply_actor_preset(actor_id: int,index: int=0) -> Variant:
	var c=_custom.get_ref(); var actor=c.staged_actor(actor_id)
	if actor==null: return null
	var preset: Dictionary=c.manifest.get("actor_presets",{}).get(str(actor_id),{}).get(str(index),{})
	for key in preset:
		var result: Dictionary
		if key in actor.PROJECT_KEYS: result=actor.set_project_parameter(key,preset[key])
		elif key=="level": result=actor.set_level(preset[key])
		elif key in ["hp","sp"]: actor.set(key,int(preset[key])); continue
		else: return c.reject("角色预设字段尚未接入："+key)
		if not result.ok: return c.reject(result.message)
	return null

func enemy_call(ref: Dictionary,name: String,args: Array) -> Variant:
	var c=_custom.get_ref(); var enemy=enemy_input(ref.id,ref.event)
	if enemy.is_empty(): return null
	if Enemy.handles(name): return Enemy.new(c,c._floor(ref.id).entries[str(ref.event)],enemy_fields(ref.id,ref.event),ref.id,ref.event).invoke(name,args)
	var battle: Dictionary=c._floor(ref.id).entries[str(ref.event)].battle
	if args.is_empty():
		if name in enemy: return enemy[name]
		match name:
			"hp": return battle.hp
			"eva": return battle.patience
			"dead?": return battle.defeated or battle.hp<=0
			"battle_state": return c.data_ref("enemy_state",ref.id,"",ref.event)
			"battle_result","simulate_battle","cal_damage": return predict(ref.id,ref.event)
			"pending_battle_result": return battle.pending.duplicate(true) if battle.pending!=null else null
			"begin_battle!": return begin_battle(ref.id,ref.event)
			"finish_battle!": return finish_battle(ref.id,ref.event)
			"got_damage","got_turn","got_list":
				var result: Variant=predict(ref.id,ref.event)
				return null if result==null else result.damage if name=="got_damage" else result.main_turns if name=="got_turn" else simulator.legacy_log(result)
			"battle_skill_set": return battle.pending_skills if battle.pending_skills!=null else simulator.resolve_enemy_skills(enemy.actions,enemy.patience)
			"invalidate_battle_cache!": battle.cache=null; return null
	if name in ["hp=","eva="] and args.size()==1:
		if not c._integer(args[0]): return c.reject("怪物HP/耐心必须为整数。")
		if name=="hp=": battle.hp=clampi(int(args[0]),0,enemy.maxhp); battle.defeated=battle.hp<=0
		else: battle.patience=clampi(int(args[0]),0,99)
		battle.cache=null; return args[0]
	if name in ["simulate_battle","set_damage"] and args.size()==1: battle.cache=null; return predict(ref.id,ref.event,true)
	return c.reject("怪物玩法接口尚未接入："+name)

func invoke(ref: Dictionary,name: String,args: Array) -> Variant:
	var c=_custom.get_ref()
	if ref.__custom_ref=="gameplay_module":
		match ref.database:
			"Actor_Init":
				if name=="load" and args.size() in [1,2]: return apply_actor_preset(int(args[0]),int(args[1]) if args.size()==2 else 0)
			"Storage":
				if args.is_empty() and rules.get("storage",{}).has(name): return rules.storage[name].duplicate(true) if rules.storage[name] is Array or rules.storage[name] is Dictionary else rules.storage[name]
				return preload("FlashItemEffects.gd").invoke(c,name,args)
			"BattleSystem::PartyRoles":
				if name in ["switch_locked?","party_defeated?"] and args.is_empty():
					var ids=role_actor_ids(); var main=c.staged_actor(int(ids[0])) if ids[0]>0 else null; var support=c.staged_actor(int(ids[1])) if ids[1]>0 else null
					return (main!=null and main.battle_down() or support!=null and support.battle_down()) if name=="switch_locked?" else (main==null or main.battle_down() and (support==null or support.battle_down()))
				if args.is_empty() and name in ["main_actor","support_actor","main_id","support_id"]:
					var ids=role_ids() if name.ends_with("id") else role_actor_ids(); var id=int(ids[0 if name.begins_with("main") else 1])
					return id if name.ends_with("id") else c.data_ref("actor",id) if id>0 and not Data.record("Actors",id).is_empty() else null
				if name=="swap_roles!" and args.is_empty():
					var ids=role_ids()
					if ids[0]<=0 or ids[1]<=0: return false
					c.script_variables[str(rules.constants.get("TEAMMATES",14))]=[ids[1],ids[0]]; return true
				if name=="sync_with_party!" and args.size()<=1: return role_ids(bool(args[0]) if not args.is_empty() else false,true)
				if name=="set_roles" and args.size()==2:
					c.script_variables[str(rules.get("constants",{}).get("TEAMMATES",14))]=[int(args[0]),int(args[1])]; return args.duplicate()
	if ref.__custom_ref=="map_event" and name=="enemy" and args.is_empty():
		var event: Variant=c.floor_entry(ref.id,ref.event)
		return event[1] if event!=null else null
	if ref.__custom_ref=="enemy_state" and args.is_empty():
		enemy_input(ref.id,ref.event)
		var battle: Dictionary=c._floor(ref.id).entries[str(ref.event)].battle
		if name=="current_hp": return battle.hp
		if name=="patience": return battle.patience
		if name=="defeated": return battle.defeated
	return c.reject("闪翼玩法服务尚未接入："+ref.__custom_ref+"."+name)

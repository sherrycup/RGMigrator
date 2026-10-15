extends RefCounted
## Source 0065–0071 plus the final 0072 enemy overrides.
## All mutable values belong to the existing floor entry, including the distinct
## legacy @hp used by inherited methods and EnemyState.current_hp used in battle.
const Battler=preload("FlashBattlerRules.gd")
const Fields=preload("FlashActorFields.gd")
const Abilities=preload("FlashEnemyAbilities.gd")
var custom: RefCounted
var entry: Dictionary
var definition: Dictionary
var attributes: Dictionary
var battle: Dictionary
var map_id: int
var event_id: int

func _init(owner: RefCounted,floor_entry: Dictionary,fields: Dictionary,map: int,event: int) -> void:
	custom=owner; entry=floor_entry; definition=fields; map_id=map; event_id=event
	if not entry.has("battler"):
		entry["battler"]={"hp":0,"sp":0,"states":[],"parameter_plus":{},"resist_plus":[0,0,0,0,0],"eva_plus":0,"damage":0,"animation_id":0,"delay_const":100}
		attributes=entry.battler
		for key in Battler.KEYS: attributes.parameter_plus[key]=0
		attributes.hp=get_parameter("maxhp"); attributes.sp=get_parameter("maxsp")
	else: attributes=entry.battler
	if not entry.has("battle"):
		entry["battle"]={"hp":attributes.hp if attributes.hp>0 else get_parameter("maxhp"),"patience":base_parameter("eva"),"defeated":false,"pending":null,"pending_skills":null,"patience_deferred":false,"cache":null}
	battle=entry.battle
	clamp_battle()

static func handles(name: String) -> bool:
	var field=name.trim_suffix("=")
	return field in Battler.KEYS or field.begins_with("base_") and field.trim_prefix("base_") in Battler.KEYS+["resist","eva"] or field in ["hp","sp","eva","resist","states","skills","skill_parameters","element","damage","animation_id","delay_const","dead?","state?","add_state","remove_state","clear_state","reset_all","state_animation_id","restriction","cant_get_exp?","cant_evade?","slip_damage?","periodic_damage","load_attrs","load_skills","load_element","drop_table","pos","x","y","troop","battle_system_legacy_hp","battle_system_legacy_eva"]

func base_parameter(key: String) -> Variant:
	var settings: Dictionary=definition.get("_custom_data",{}).get("external",{}).get("settings",{})
	var configured: Variant=settings.get(key)
	if configured!=null and (not configured is bool or configured): return configured
	if key=="resist": return [0,0,0,0,0]
	return definition.get("atk" if key in ["patk","matk"] else key,1 if key in ["maxhp","agi","int"] else 0)

func get_parameter(key: String,states: Array=[]) -> int:
	return Battler.parameter(base_parameter(key),attributes.parameter_plus.get(key,0),key,attributes.states if states.is_empty() else states,_state_record)

func _parameter_for_states(key: String,states: Array) -> int:
	return Battler.parameter(base_parameter(key),attributes.parameter_plus.get(key,0),key,states,_state_record)

func get_resist() -> Array:
	return Battler.resist(base_parameter("resist"),attributes.resist_plus,attributes.states,_state_record)

func _state_record(id: int) -> Dictionary:
	return custom.record("States",id)

func clamp_battle() -> void:
	battle.hp=min(max(battle.hp,0),get_parameter("maxhp"))
	battle.patience=min(max(battle.patience,0),99)
	if battle.hp<=0: battle.defeated=true

func input() -> Dictionary:
	clamp_battle()
	var result={"id":int(definition.id),"actions":definition.get("actions",[]).duplicate(true),"states":attributes.states.duplicate(),"equip_skills":{},"battle_down":false,"hp":battle.hp,"patience":battle.patience,"defeated":battle.defeated}
	for key in Battler.KEYS: result[key]=get_parameter(key)
	return result

func invoke(name: String,args: Array) -> Variant:
	var field=name.trim_suffix("=")
	if name.ends_with("=") and args.size()==1:
		var value: Variant=args[0]
		if field=="resist":
			if not value is Array or value.size()!=5: return custom.reject("怪物抗性必须有五个数值分量。")
			for n in value:
				if not Fields.number(n): return custom.reject("怪物抗性必须为有效数值。")
			var current=get_resist()
			for i in 5: attributes.resist_plus[i]=clampf(attributes.resist_plus[i]+value[i]-current[i],-100,100)
		elif field in Battler.KEYS:
			if not Fields.number(value): return custom.reject("怪物属性必须为有效数值。")
			var plus: Variant=attributes.parameter_plus[field]+value-get_parameter(field)
			if not Fields.number(plus): return custom.reject("怪物属性增量超过支持范围。")
			attributes.parameter_plus[field]=plus if field=="maxhp" else min(max(plus,-999999 if field=="maxsp" else -99999),999999 if field=="maxsp" else 99999)
			if field=="maxhp": attributes.hp=min(attributes.hp,get_parameter(field))
			if field=="maxsp": attributes.sp=min(attributes.sp,get_parameter(field))
		elif field in ["hp","sp","eva"]:
			if not Fields.number(value): return custom.reject("怪物生命/魔力/耐心必须为有效数值。")
			if field=="hp": battle.hp=clampi(int(value),0,get_parameter("maxhp")); battle.defeated=battle.hp<=0
			elif field=="eva": battle.patience=clampi(int(value),0,99)
			else: attributes.sp=min(max(value,0),get_parameter("maxsp"))
		else: return custom.reject("怪物字段为只读："+field)
		battle.cache=null; return value
	if args.is_empty():
		if field in Battler.KEYS: return get_parameter(field)
		if field.begins_with("base_"): return base_parameter(field.trim_prefix("base_"))
		if field in ["hp","eva"]: return battle.hp if field=="hp" else battle.patience
		if field in ["sp","states","damage","animation_id","delay_const"]: return attributes[field]
		if field in ["skills","skill_parameters","element"]: return entry.fields.get(field,[] if field!="skill_parameters" else {})
		if field=="resist": return get_resist()
		if field=="battle_system_legacy_hp": return attributes.hp
		if field=="battle_system_legacy_eva": return min(max(base_parameter("eva")+attributes.eva_plus,0),99)
		if field=="dead?": return battle.defeated or battle.hp<=0
		if field=="pos": return entry.position
		if field in ["x","y"]: return entry.position[0 if field=="x" else 1]
		if field=="troop": return custom.data_ref("floor",map_id)
		if field=="drop_table":
			var drop: Variant=definition.get("_custom_data",{}).get("external",{}).get("settings",{}).get("drop_table")
			return drop if drop is Array else null
		if field in ["state_animation_id","restriction","cant_get_exp?","cant_evade?","slip_damage?"]: return Battler.query(attributes.states,field,_state_record)
		if field=="clear_state":
			attributes.states.clear(); attributes.hp=max(min(attributes.hp,get_parameter("maxhp")),1); attributes.sp=min(attributes.sp,get_parameter("maxsp")); battle.cache=null; return null
		if field=="reset_all":
			attributes.hp=get_parameter("maxhp"); attributes.sp=get_parameter("maxsp")
			return _change_states(attributes.states.duplicate(),false,false)
		if field=="load_attrs": return null # Immutable imported source settings.
		if field=="load_skills":
			entry.fields.skills=[]
			for action in definition.get("actions",[]):
				if int(action.get("kind",0))==1 and int(action.get("condition_level",0))==10: entry.fields.skills.append(int(action.get("skill_id",0)))
			if not entry.fields.get("skill_parameters") is Dictionary: entry.fields.skill_parameters={}
			entry.fields.skill_parameters.merge(Abilities.map_parameters(definition.get("actions",[]),custom.gameplay().rules.constants),true)
			custom.rebuild_floor_indices(map_id); battle.cache=null; return null
		if field=="load_element": entry.fields.element=Abilities.elements(definition); return null
	if name in ["state?","add_state","remove_state"] and (args.size()==1 or name=="add_state" and args.size()==2):
		if not Fields.integer(args[0]) or args[0]<=0 or args.size()==2 and not args[1] is bool: return custom.reject("怪物状态参数无效。")
		if name=="state?": return attributes.states.has(int(args[0]))
		return _change_states([int(args[0])],name=="add_state",args[1] if args.size()==2 else false)
	if name=="periodic_damage" and args.size()==1:
		if not args[0] is Dictionary or args[0].get("__custom_ref","") not in ["actor","floor_enemy"]: return custom.reject("周期伤害需要角色或怪物对象。")
		var patk: Variant=custom.invoke(args[0],"patk",[]); var matk: Variant=custom.invoke(args[0],"matk",[])
		if not custom.failure.is_empty(): return null
		attributes.damage=max(patk-get_parameter("pdef"),0)+max(matk-get_parameter("mdef"),0); return attributes.damage
	return custom.reject("怪物接口参数无效："+name)

func _change_states(ids: Array,adding: bool,force: bool) -> Variant:
	var changed=Battler.change({"hp":attributes.hp,"sp":attributes.sp,"states":attributes.states},ids,adding,force,_parameter_for_states,_state_record)
	if not changed.ok: return custom.reject(changed.message)
	for key in ["hp","sp","states"]: attributes[key]=changed.state[key]
	battle.cache=null; return null

static func validate(entry: Dictionary,lookup: Callable) -> String:
	if entry.has("battler"):
		var value: Variant=entry.battler
		if not value is Dictionary or value.size()!=9: return "楼层怪物属性结构无效。"
		for key in ["hp","sp","eva_plus","damage","animation_id","delay_const"]:
			if not Fields.number(value.get(key)) or key!="eva_plus" and value[key]<0: return "楼层怪物数值无效："+key
		if not value.get("parameter_plus") is Dictionary or value.parameter_plus.size()!=8: return "楼层怪物八项增量无效。"
		for key in Battler.KEYS:
			if not Fields.number(value.parameter_plus.get(key)): return "楼层怪物属性增量无效："+key
		if not value.get("resist_plus") is Array or value.resist_plus.size()!=5: return "楼层怪物抗性结构无效。"
		for n in value.resist_plus:
			if not Fields.number(n): return "楼层怪物抗性无效。"
		if not value.get("states") is Array: return "楼层怪物状态结构无效。"
		var seen={}
		for raw in value.states:
			if not Fields.integer(raw) or raw<=0 or lookup.call("States",int(raw)).is_empty() or seen.has(int(raw)): return "楼层怪物状态引用无效。"
			seen[int(raw)]=true
	if entry.has("battle"):
		var value: Variant=entry.battle
		if not value is Dictionary: return "楼层怪物战斗状态无效。"
		for key in ["hp","patience"]:
			if not Fields.number(value.get(key)) or value[key]<0 or key=="patience" and value[key]>99: return "楼层怪物战斗数值无效："+key
		for key in ["defeated","patience_deferred"]:
			if not value.get(key) is bool: return "楼层怪物战斗标志无效。"
	return ""

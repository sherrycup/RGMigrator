extends RefCounted
## Source 0097 step order and 0098 poison/hide/manor/cotack/hook.
const MapBridge=preload("FlashMapBridge.gd")
const Character=preload("FlashCharacterBridge.gd")
const OFFSETS=[Vector2i(0,1),Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1)]
const DIRECTIONS=[2,4,6,8]

static func invoke(custom: RefCounted,name: String) -> Variant:
	if name=="after_step":
		for operation in ["poison_deal","hide_deal","manor_deal","cotack_deal","hook_deal"]:
			invoke(custom,operation)
			if not custom.failure.is_empty(): return null
		return null
	var map: Node=MapBridge.current_map(custom)
	if map==null: return null
	var state: Node=custom._owner.get_ref(); var player: Node=map.player_character
	if player==null: return custom.reject("地图怪物效果缺少玩家。")
	var constants: Dictionary=custom.gameplay().rules.constants
	var index=int(custom.values.system.get("main_actor_index",0))
	if index<0 or index>=custom.party_ids.size(): return custom.reject("地图怪物效果缺少操作角色。")
	var actor=custom.staged_actor(int(custom.party_ids[index]))
	if actor==null: return null
	if name=="poison_deal":
		var id=int(constants.POISON_STATE_ID)
		if actor.get_state_ids().has(id):
			var poison_name=str(custom.record("States",id).get("name",""))
			var matcher=RegEx.new(); matcher.compile("^[+-]?[0-9]+")
			var matched=matcher.search(poison_name.get_slice(":",1))
			var damage=int(matched.get_string()) if matched!=null else 0
			_subtract(custom,actor,damage)
			_ending(custom,actor,2)
		return null
	var prefix=name.trim_suffix("_deal")
	if prefix not in ["hide","manor","cotack","hook"]: return custom.reject("未知地图怪物效果："+name)
	if int(custom.party_call("item_number",[int(constants[prefix.to_upper()+"_ITEM_ID"])]))<=0: return null
	custom._update_floor(state.map_id)
	var floor: Dictionary=custom._floor(state.map_id)
	if name in ["hide_deal","manor_deal"]:
		for cell in floor.indices[prefix]:
			var pair: Variant=custom.floor_entry(state.map_id,cell)
			if pair==null: continue
			var event: Node=map.event_node(int(pair[0]))
			if event==null or MapBridge.is_dead(custom,state.map_id,int(pair[0])): continue
			var delta: Vector2i=event.motion.cell-player.motion.cell
			if prefix=="hide":
				var effect: Array=constants.HIDE_ITEM_EFFECT
				Character.invoke(custom,custom.data_ref("map_event",state.map_id,"",int(pair[0])),"opacity=",[int(effect[1]) if absi(delta.x)+absi(delta.y)<=int(effect[0]) else 0])
			else:
				var param: Dictionary=floor.entries[str(pair[0])].fields.skill_parameters.get("manor",{})
				if param.is_empty(): return custom.reject("领域怪物缺少源技能参数。")
				if maxi(absi(delta.x),absi(delta.y))<=int(param.range):
					_subtract(custom,actor,param.damage); _animation(custom,state.map_id,int(constants.MANOR_ANIMATION_ID)); _ending(custom,actor,1)
	elif prefix=="cotack":
		var pair_parameters: Array=[]
		for indices in [[1,2],[0,3]]: # source applies X ratio, then Y ratio, then X/Y fixed damage
			var first: Variant=custom.floor_entry(state.map_id,[player.motion.cell.x+OFFSETS[indices[0]].x,player.motion.cell.y+OFFSETS[indices[0]].y])
			var second: Variant=custom.floor_entry(state.map_id,[player.motion.cell.x+OFFSETS[indices[1]].x,player.motion.cell.y+OFFSETS[indices[1]].y])
			var param: Variant=null
			if first!=null and second!=null:
				var a: Dictionary=floor.entries[str(first[0])].fields; var b: Dictionary=floor.entries[str(second[0])].fields
				if int(a.id)==int(b.id) and a.skills.has(int(constants.COTACK_SKILL_ID)): param=a.skill_parameters.get("cotack")
			pair_parameters.append(param)
		if pair_parameters.any(func(param):return param!=null):
			_animation(custom,state.map_id,int(constants.COTACK_ANIMATION_ID))
			for param in pair_parameters:
				if param==null: continue
				var result: Dictionary=actor.set_project_parameter("maxhp",actor.get_parameter("maxhp")*(1-float(param.ratio)/100.0))
				if not result.ok: return custom.reject(result.message)
			for param in pair_parameters:
				if param!=null: _subtract(custom,actor,param.damage)
			_ending(custom,actor,1)
	elif prefix=="hook":
		for i in OFFSETS.size():
			var cell: Vector2i=player.motion.cell+OFFSETS[i]
			var pair: Variant=custom.floor_entry(state.map_id,[cell.x,cell.y])
			if pair==null: continue
			var fields: Dictionary=floor.entries[str(pair[0])].fields
			# Source omitted the hook-skill guard and dereferenced nil for ordinary enemies.
			if not fields.skills.has(int(constants.HOOK_SKILL_ID)): continue
			var event: Node=map.event_node(int(pair[0])); var param: Dictionary=fields.skill_parameters.get("hook",{})
			if event==null or param.is_empty(): continue
			custom.character_edits.append({"target":weakref(event),"map":weakref(map),"id":int(pair[0]),"field":"move_straight","value":DIRECTIONS[i]})
			_subtract(custom,actor,param.damage); _animation(custom,state.map_id,int(constants.HOOK_ANIMATION_ID)); _ending(custom,actor,1)
	return null

static func _subtract(custom: RefCounted,actor: RefCounted,value: Variant) -> void:
	var result: Dictionary=actor.set_project_parameter("maxhp",actor.get_parameter("maxhp")-value)
	if not result.ok: custom.reject(result.message)

static func _animation(custom: RefCounted,map_id: int,id: int) -> void:
	Character.invoke(custom,custom.data_ref("player",map_id),"animation_id=",[id])

static func _ending(custom: RefCounted,actor: RefCounted,id: int) -> void:
	if actor.hp!=0: return
	custom.temp_fields.ending_id=id
	custom.pending_effects["common_event"]={"id":12,"source":"flash_map_effect","actor_id":actor.id,"target_id":actor.id}

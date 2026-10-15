extends RefCounted
## Source 0052 Storage dispatch and implemented actor effects.
## Source empty branches return nil; unsupported map effects fail explicitly.
static func invoke(custom: RefCounted,name: String,args: Array) -> Variant:
	var constants: Dictionary=custom.gameplay().rules.constants
	if name=="use_item" and args.size()<=1:
		var id: Variant=args[0] if not args.is_empty() else custom.temp_fields.get("item_id",0)
		if not custom._integer(id): return custom.reject("物品编号必须为整数。")
		var names={"QUAKE_ITEM_ID":"quake","PICKAXE_ITEM_ID":"pickaxe","FREEZE_ITEM_ID":"freeze","SYMCRAFT_ITEM_ID":"symcraft","ICE_PICKAXE_ITEM_ID":"ice_pickaxe","GIANT_KEY_ID":"giant_key","STRIKE_ITEM_ID":"strike","BOMB_ITEM_ID":"bomb","UPPER_ITEM_ID":"upper","LOWER_ITEM_ID":"lower","SWORD_ITEM_ID":"sword","WILL_GATE_ITEM_ID":"will_gate","CRAFT_ITEM_ID":"craft"}
		for constant in names:
			if constants.get(constant)==id: return invoke(custom,names[constant],[])
		# Source case tests potion values before gem values; preserve collisions.
		for table in ["POTION_ITEM_ID","GEM_ITEM_ID"]:
			for key in constants.get(table,{}):
				if constants[table][key]==id: return invoke(custom,"potion" if table=="POTION_ITEM_ID" else "gem",[int(key)])
		for condition in ["poison","weak","slow","curse","slear"]:
			if constants.get(condition.to_upper()+"_ITEM_ID")==id: return invoke(custom,condition,[])
		return false
	if name in ["upper","lower","sword","will_gate","craft"] and args.is_empty(): return null # original marked 待完成
	if name in ["quake","pickaxe","freeze","symcraft","ice_pickaxe","giant_key","strike","bomb"] and args.is_empty(): return _map_effect(custom,name)
	var index=int(custom.values.system.get("main_actor_index",0))
	if index<0 or index>=custom.party_ids.size(): return custom.reject("物品效果缺少当前操作角色。")
	var actor=custom.staged_actor(int(custom.party_ids[index]))
	if actor==null: return null
	if name in ["potion","gem"] and args.size()==1 and custom._integer(args[0]):
		var key=str(int(args[0])); var storage: Dictionary=custom.gameplay().rules.storage
		var table: Dictionary=storage.potion_hp if name=="potion" else storage.gem_attr
		if not table.has(key): return false
		var item_table: Dictionary=constants["POTION_ITEM_ID" if name=="potion" else "GEM_ITEM_ID"]
		if not item_table.has(key): return custom.reject("原物品ID表未定义该效果编号："+key)
		if name=="potion":
			# Storage.potion increases MAXHP. CE2 separately adds current HP.
			var result: Dictionary=actor.set_project_parameter("maxhp",actor.get_parameter("maxhp")+int(table[key]))
			if not result.ok: return custom.reject(result.message)
		else:
			for field in table[key]:
				if field=="resist":
					var sum=preload("FlashValueExtensions.gd").vector(actor.get_resist(),table[key][field],"+")
					var result: Dictionary=actor.set_resist(sum.value) if sum.ok else sum
					if not result.ok: return custom.reject(result.message)
				elif field in actor.PROJECT_KEYS:
					var result: Dictionary=actor.set_project_parameter(field,actor.get_parameter(field)+int(table[key][field]))
					if not result.ok: return custom.reject(result.message)
				else: return custom.reject("宝石属性未迁移："+str(field))
		if actor.hp==0:
			custom.temp_fields.ending_id=1
			custom.pending_effects["common_event"]={"id":12,"source":"flash_item_ending","actor_id":actor.id,"target_id":actor.id}
		custom.party_call("lose_item",[int(item_table[key]),1])
		return true
	if name in ["poison","weak","slow","curse","slear"] and args.is_empty():
		var conditions=["poison","weak","slow","curse"] if name=="slear" else [name]
		if name!="slear" and not actor.get_state_ids().has(int(constants[name.to_upper()+"_STATE_ID"])): return false
		for condition in conditions:
			var result: Dictionary=actor.remove_state(int(constants[condition.to_upper()+"_STATE_ID"]))
			if not result.ok: return custom.reject(result.message)
		custom.party_call("lose_item",[int(constants[name.to_upper()+"_ITEM_ID"]),1])
		if name=="slear" and actor.battle_down(): actor.recover_battle_down()
		return true
	return custom.reject("Storage地图物品效果尚未迁移："+name)

static func _map_effect(custom: RefCounted,name: String) -> Variant:
	var bridge: GDScript=preload("FlashMapBridge.gd")
	var map: Node=bridge.current_map(custom)
	if map==null: return null
	var constants: Dictionary=custom.gameplay().rules.constants
	var constant={"quake":"QUAKE_ITEM_ID","pickaxe":"PICKAXE_ITEM_ID","freeze":"FREEZE_ITEM_ID","symcraft":"SYMCRAFT_ITEM_ID","ice_pickaxe":"ICE_PICKAXE_ITEM_ID","giant_key":"GIANT_KEY_ID","strike":"STRIKE_ITEM_ID","bomb":"BOMB_ITEM_ID"}[name]
	var item_id=int(constants[constant])
	if int(custom.party_call("item_number",[item_id]))<=0: return false
	var state: Node=custom._owner.get_ref(); var player: Node=map.player_character
	if player==null: return custom.reject("地图物品效果缺少玩家。")
	var storage: Dictionary=custom.gameplay().rules.storage
	var offset: Vector2i={2:Vector2i(0,1),4:Vector2i(-1,0),6:Vector2i(1,0),8:Vector2i(0,-1)}.get(player.motion.direction,Vector2i.ZERO)
	var front: Vector2i=player.motion.cell+offset
	if name=="symcraft":
		var center: Array=custom.values.system.map_center
		var aim=Vector2i(int(center[0])*2-player.motion.cell.x,int(center[1])*2-player.motion.cell.y)
		if not bridge.passable_zero(custom,map,aim.x,aim.y): return false
		custom.character_edits.append({"target":weakref(player),"map":weakref(map),"id":-1,"field":"move_to","value":[aim.x,aim.y]})
	elif name=="quake":
		for x in map.map_width():
			for y in map.map_height():
				if not custom._in_range(custom.values.system.map_range[0],x) or not custom._in_range(custom.values.system.map_range[1],y): continue
				var event_id=bridge.check_event(custom,map,x,y)
				if event_id>0 and bridge.event_name(custom,state.map_id,event_id).contains("暗墙"): _die(custom,event_id)
				var tile: Variant=bridge.read_tile(custom,map,x,y,int(storage.wall_layer))
				if _tile_matches(custom,storage.wall_data,tile): bridge.write_tile(custom,map,x,y,int(storage.wall_layer),0)
				if not custom.failure.is_empty(): return null
	elif name in ["pickaxe","freeze","ice_pickaxe"]:
		var prefix="暗墙" if name=="pickaxe" else "暗冰" if name=="ice_pickaxe" else "暗熔"
		var succeeded=false
		var event_id=bridge.check_event(custom,map,front.x,front.y)
		if event_id>0:
			var regex=RegEx.new(); regex.compile(prefix+"([Bb])*")
			var matched=regex.search(bridge.event_name(custom,state.map_id,event_id))
			if matched!=null and matched.get_start(1)<0: _die(custom,event_id); succeeded=true
		if map.valid(front.x,front.y):
			var layer=int(storage.wall_layer) if name=="pickaxe" else 2
			var table: Array=storage.wall_data if name=="pickaxe" else storage.ice_data if name=="ice_pickaxe" else storage.lava_data
			var tile: Variant=bridge.read_tile(custom,map,front.x,front.y,layer)
			if _tile_matches(custom,table,tile): bridge.write_tile(custom,map,front.x,front.y,layer,0); succeeded=true
		if not succeeded: return false
	elif name in ["strike","bomb"]:
		var succeeded=false
		var positions: Array=[front] if name=="bomb" else [player.motion.cell+Vector2i(0,1),player.motion.cell+Vector2i(0,-1),player.motion.cell+Vector2i(1,0),player.motion.cell+Vector2i(-1,0)]
		for cell in positions:
			var event_id=bridge.check_event(custom,map,cell.x,cell.y)
			if event_id<=0: continue
			var event_name=bridge.event_name(custom,state.map_id,event_id)
			if event_name.contains("怪物") and not event_name.contains("B") and not event_name.contains("b"): _die(custom,event_id); succeeded=true
		if not succeeded: return false
	elif name=="giant_key":
		if not storage.get("open_door_list") is Array: return custom.reject("缺少已生成的开门事件页宏。")
		var expression=RegEx.new(); expression.compile("^门0*1")
		# Source checks one event for each cell, in x/y order. Updating every node
		# would also update a hidden door underneath another event at that cell.
		for x in map.map_width():
			for y in map.map_height():
				if not custom._in_range(custom.values.system.map_range[0],x) or not custom._in_range(custom.values.system.map_range[1],y): continue
				var event_id=bridge.check_event(custom,map,x,y)
				if event_id<=0 or expression.search(bridge.event_name(custom,state.map_id,event_id))==null: continue
				var event: Node=map.event_node(event_id)
				if event==null: return custom.reject("开门事件已离开当前地图。")
				var pages: Dictionary=custom.values.system.event_page
				if not pages.has(str(state.map_id)): pages[str(state.map_id)]={}
				if not pages[str(state.map_id)].has(str(event_id)): pages[str(state.map_id)][str(event_id)]={}
				pages[str(state.map_id)][str(event_id)]["list"]=storage.open_door_list.duplicate(true)
				custom.character_edits.append({"target":weakref(event),"map":weakref(map),"id":event_id,"field":"refresh","value":null})
	if not custom.failure.is_empty(): return null
	# Source strike mistakenly consumes BOMB_ITEM_ID; consume its own STRIKE ID.
	custom.party_call("lose_item",[item_id,1])
	return true

static func _tile_matches(custom: RefCounted,table: Array,tile: Variant) -> bool:
	if tile==null: return false
	for value in table:
		if value is Dictionary and custom._in_range(value,int(tile)): return true
		if (value is int or value is float) and int(value)==int(tile): return true
	return false

static func _die(custom: RefCounted,event_id: int) -> void:
	custom.invoke(custom.data_ref("map_event",custom._owner.get_ref().map_id,"",event_id),"die",[])

extends RefCounted
## Source 0096 permanent name/death and 0104 damage refresh, sharing native maps.
static func invoke(custom: RefCounted,ref: Dictionary,name: String,args: Array) -> Variant:
	var state: Node=custom._owner.get_ref(); var game: Node=state.game()
	var map: Node=game.event_map() if game!=null else null
	if map==null or state.map_id!=ref.id: return custom.reject("闪翼地图接口缺少当前地图。")
	if name=="check_event":
		if args.size() not in [2,3] or not custom._integer(args[0]) or not custom._integer(args[1]): return custom.reject("check_event要求整数坐标及可选名称匹配。")
		var filter: Variant=args[2] if args.size()==3 else null
		if filter!=null and not filter is String and not (filter is Dictionary and filter.has("__ruby_regex")): return custom.reject("事件名称匹配需要字符串或RegExp。")
		var by_id: Dictionary={}
		for node in map._event_nodes: by_id[node.event_id]=node
		for id in map.map_data.events:
			var event: Node=by_id.get(int(id))
			if event==null or event.motion.cell!=Vector2i(int(args[0]),int(args[1])) or is_dead(custom,int(ref.id),int(id)): continue
			var event_title=event_name(custom,int(ref.id),int(id))
			if filter is String and not event_title.contains(filter): continue
			if filter is Dictionary:
				var matched=preload("RubyRegexValues.gd").match_value(filter.__ruby_regex,event_title)
				if not matched.ok: return custom.reject(matched.message)
				if matched.data==null: continue
			return int(id)
		return null
	if not args.is_empty(): return custom.reject("该地图调用不接受参数："+name)
	if name=="map_id": return int(ref.id)
	if name=="events": return custom.data_ref("map_events",int(ref.id))
	if name=="width": return map.map_width()
	if name=="height": return map.map_height()
	if name=="data": return custom.data_ref("map_tiles",int(ref.id))
	if name=="refresh_damage":
		var reason=custom.gameplay().simulator.validate()
		if not reason.is_empty(): return custom.reject(reason)
		# Source refresh requests presentation. Getters/battle still predict the
		# requested enemy synchronously; map-wide previews use detached worker data.
		state.get_tree().call_group("flash_damage_views","request_refresh")
		return null
	return custom.reject("地图接口尚未迁移："+name)

static func event_name(custom: RefCounted,map_id: int,event_id: int) -> String:
	var overrides: Dictionary=custom.values.system.get("event_name",{}).get(str(map_id),{})
	if overrides.has(str(event_id)): return str(overrides[str(event_id)])
	var source: Dictionary=preload("RuntimeData.gd").map(map_id).get("events",{}).get(str(event_id),{})
	return str(source.get("name",""))

static func is_dead(custom: RefCounted,map_id: int,event_id: int) -> bool:
	return event_name(custom,map_id,event_id)==str(custom.gameplay().rules.get("constants",{}).get("DEFAULT_DEAD_CODE",""))

static func set_event_name(custom: RefCounted,map_id: int,event_id: int,value: String) -> void:
	if not custom.values.system.has("event_name"): custom.reject("缺少原系统的事件名称记录。"); return
	var names: Dictionary=custom.values.system.event_name
	if not names.has(str(map_id)): names[str(map_id)]={}
	names[str(map_id)][str(event_id)]=value

static func current_map(custom: RefCounted) -> Node:
	var state: Node=custom._owner.get_ref(); var game: Node=state.game()
	var map: Node=game.event_map() if game!=null else null
	if map==null: custom.reject("地图物品效果缺少当前地图。")
	return map

static func read_tile(custom: RefCounted,map: Node,x: int,y: int,layer: int) -> Variant:
	if not map.valid(x,y) or layer<0 or layer>=int(map.map_data.data.z_size): return custom.reject("地图图块坐标无效。")
	var overrides: Dictionary=custom.values.system.get("map_data",{}).get(str(custom._owner.get_ref().map_id),{})
	return int(overrides.get("%d:%d:%d" % [x,y,layer],map.tile_id(x,y,layer)))

static func write_tile(custom: RefCounted,map: Node,x: int,y: int,layer: int,value: int) -> void:
	read_tile(custom,map,x,y,layer)
	if not custom.failure.is_empty(): return
	if value<0 or value>32767: custom.reject("图块编号超出原Table范围。"); return
	var id=str(custom._owner.get_ref().map_id)
	var changes: Dictionary=custom.values.system.map_data
	if not changes.has(id): changes[id]={}
	changes[id]["%d:%d:%d" % [x,y,layer]]=value
	custom.character_edits.append({"target":weakref(map),"map":weakref(map),"id":0,"field":"tile","value":[x,y,layer,value]})

static func check_event(custom: RefCounted,map: Node,x: int,y: int) -> int:
	for event in map._event_nodes:
		if event.motion.cell==Vector2i(x,y) and not is_dead(custom,custom._owner.get_ref().map_id,event.event_id): return int(event.event_id)
	return 0

static func passable_zero(custom: RefCounted,map: Node,x: int,y: int) -> bool:
	# Source Game_Map.passable?(x,y,0): bit=0, test full blocking and priority.
	if not map.valid(x,y): return false
	for event in map._event_nodes:
		if is_dead(custom,custom._owner.get_ref().map_id,event.event_id) or event.motion.cell!=Vector2i(x,y) or event.through or event.tile_id<0: continue
		if map._passage(event.tile_id)&15==15: return false
		if map.tile_priority(event.tile_id)==0: return true
	for layer in range(int(map.map_data.data.z_size)-1,-1,-1):
		var tile: Variant=read_tile(custom,map,x,y,layer)
		if tile==null or map._passage(int(tile))&15==15: return false
		if map.tile_priority(int(tile))==0: return true
	return true

static func validate_saved_tiles(changes: Variant) -> String:
	if not changes is Dictionary: return "地图图块覆盖必须为Hash。"
	for id in changes:
		if not str(id).is_valid_int(): return "地图图块覆盖的地图编号无效。"
		var map: Dictionary=preload("RuntimeData.gd").map(int(id))
		if map.is_empty() or not changes[id] is Dictionary: return "地图图块覆盖引用不存在。"
		for key in changes[id]:
			var parts: PackedStringArray=str(key).split(":")
			if parts.size()!=3 or not Array(parts).all(func(part):return part.is_valid_int()): return "地图图块覆盖坐标格式无效。"
			var x=int(parts[0]); var y=int(parts[1]); var z=int(parts[2]); var value: Variant=changes[id][key]
			if x<0 or y<0 or z<0 or x>=int(map.width) or y>=int(map.height) or z>=int(map.data.z_size): return "地图图块覆盖坐标越界。"
			if not (value is int or value is float) or value!=floor(value) or value<0 or value>32767: return "地图图块覆盖编号无效。"
	return ""

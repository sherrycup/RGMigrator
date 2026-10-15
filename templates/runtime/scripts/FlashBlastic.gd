extends RefCounted
## Source 0088/0214 state, 0217/0221 constraints and 0202 crystal exchange.

static func record(custom: RefCounted,id: int) -> Dictionary:
	if id<0 or id>10: custom.reject("原力器编号必须为0—10。"); return {}
	if custom.values.blastics.has(str(id)): return custom.values.blastics[str(id)]
	var storage: Dictionary=custom.gameplay().rules.storage
	var pos: Variant=storage.get("blastic_pos",{}).get(str(id))
	var lock: Variant=storage.get("blastic_lock",{}).get(str(id))
	var restrict: Variant=storage.get("blastic_restrict",{}).get(str(id))
	if not pos is Array or not lock is Array or not restrict is Array or pos.size()!=2 or lock.size()!=2 or restrict.size()!=2:
		custom.reject("原力器预设未完成，缺少孔位/锁/限制："+str(id)); return {}
	var value={"id":id,"pos":pos.duplicate(true),"lock":lock.duplicate(true),"restrict":restrict.duplicate(true),"equip":[[],[]],"element":[[0,0,0,0,0],[0,0,0,0,0]],"update_tag":false}
	for circle in 2:
		value.equip[circle].resize(pos[circle].size()); value.equip[circle].fill(null)
	custom.values.blastics[str(id)]=value
	return value

static func invoke(custom: RefCounted,id: int,name: String,args: Array) -> Variant:
	var value=record(custom,id)
	if value.is_empty(): return null
	if args.is_empty() and name in ["pos","lock","element","equip","update_tag"]: return value[name]
	if name=="update_tag=" and args.size()==1 and args[0] is bool: value.update_tag=args[0]; return args[0]
	if name in ["have_crystal?","cancel_crystal","unlock"] and args.size()==1:
		var cell=_cell(custom,value,args[0])
		if cell.is_empty(): return null
		if name=="have_crystal?": return value.equip[cell[0]][cell[1]]
		if name=="unlock": value.lock[cell[0]][cell[1]]=true; return null
		return _equip(custom,value,cell,null)
	if name=="equip_crystal" and args.size()==2:
		var cell=_cell(custom,value,args[0])
		return _equip(custom,value,cell,args[1]) if not cell.is_empty() else null
	if name in ["plus_element","minus_element"] and args.size()==2: return null # original empty body
	return custom.reject("原力器接口尚未迁移："+name)

static func exchange(custom: RefCounted,id: int,index: int,crystal_id: int) -> Dictionary:
	var value=record(custom,id)
	if value.is_empty(): return {"ok":false,"message":custom.failure}
	var cell=_cell(custom,value,index)
	if cell.is_empty(): return {"ok":false,"message":custom.failure}
	if not value.lock[cell[0]][cell[1]]: return {"ok":false,"message":"该孔位尚未解锁。"}
	var old: Variant=value.equip[cell[0]][cell[1]]
	var next: Variant=null if crystal_id==0 else crystal_id
	if next!=null:
		var crystal: Variant=custom.gameplay().rules.storage.crystal.get(str(next))
		if not crystal is Array: return {"ok":false,"message":"结晶预设不存在。"}
		if int(custom.party_call("item_number",[next]))<=0: return {"ok":false,"message":"背包没有该结晶。"}
		var restriction=int(value.restrict[cell[0]][cell[1]])
		if restriction!=0 and restriction!=int(crystal[0]): return {"ok":false,"message":"结晶属性不符合孔位限制。"}
		var functions: Dictionary={}
		for row in value.equip:
			for equipped in row:
				if equipped==null: continue
				var type=str(custom.gameplay().rules.storage.crystal[str(equipped)][1])
				functions[type]=int(functions.get(type,0))+1
		var next_type=str(crystal[1]); functions[next_type]=int(functions.get(next_type,0))+1
		if old!=null:
			var old_type=str(custom.gameplay().rules.storage.crystal[str(old)][1]); functions[old_type]-=1
		if functions.values().any(func(count):return count>1): return {"ok":false,"message":"不能装备同类型的结晶回路。"}
	if old!=null and old!=next and int(custom.party_call("item_number",[old]))>=99: return {"ok":false,"message":"背包已满，不能返还原结晶。"}
	if old!=null: custom.party_call("gain_item",[old,1,false])
	if next!=null: custom.party_call("gain_item",[next,-1,false])
	_equip(custom,value,cell,next)
	if not custom.failure.is_empty(): return {"ok":false,"message":custom.failure}
	value.update_tag=true
	return {"ok":true,"changed":old!=next,"value":next,"old":old}

static func echoes(custom: RefCounted,elements: Array,preview: bool=false) -> Array:
	# Source 0219: met thresholds, followed by at most 3 misses at distance 1..9.
	var active: Array=[]; var missing: Dictionary={}
	if elements.size()!=5: return active
	for id in custom.gameplay().rules.storage.blastic_echo:
		var spec: Array=custom.gameplay().rules.storage.blastic_echo[id]; var distance=0
		for i in 5: distance+=maxi(int(spec[1][i])-int(elements[i]),0)
		var row={"id":int(id),"name":spec[0],"required":spec[1].duplicate(),"active":distance==0,"distance":distance}
		if distance==0: active.append(row)
		elif distance<10:
			if not missing.has(distance): missing[distance]=[]
			missing[distance].append(row)
	if preview:
		var remaining=3
		for distance in range(1,10):
			for row in missing.get(distance,[]):
				if remaining==0: break
				active.append(row); remaining-=1
	return active

static func _cell(custom: RefCounted,value: Dictionary,index: Variant) -> Array:
	if not custom._integer(index) or index<0: custom.reject("原力器孔位编号无效。"); return []
	var width=int(value.pos[0].size())
	if width==0: custom.reject("原力器第一链没有孔位。"); return []
	var circle=int(index)/width; var column=int(index)%width
	if circle>1 or column>=value.pos[circle].size(): custom.reject("原力器孔位不存在。"); return []
	return [circle,column]

static func _equip(custom: RefCounted,value: Dictionary,cell: Array,id: Variant) -> Variant:
	var old: Variant=value.equip[cell[0]][cell[1]]
	var table: Dictionary=custom.gameplay().rules.storage.crystal
	if id!=null and (not custom._integer(id) or not table.has(str(id))): return custom.reject("结晶编号/预设无效。")
	# Source Scene_Map cancels before replacing; make the raw call consistent too.
	for i in 5:
		value.element[cell[0]][i]-=int(table[str(old)][2][i]) if old!=null else 0
		value.element[cell[0]][i]+=int(table[str(id)][2][i]) if id!=null else 0
	value.equip[cell[0]][cell[1]]=id
	return null

static func validate(custom: RefCounted,values: Dictionary) -> String:
	var storage: Dictionary=custom.gameplay().rules.storage
	for key in values:
		var value: Variant=values[key]
		if not str(key).is_valid_int() or int(key)<0 or int(key)>10 or not value is Dictionary or value.keys().size()!=7: return "原力器快照结构无效。"
		if value.get("id")!=int(key) or not value.get("update_tag") is bool: return "原力器编号/刷新标志无效。"
		if not custom.same_value(value.get("pos"),storage.blastic_pos.get(key)) or not custom.same_value(value.get("restrict"),storage.blastic_restrict.get(key)): return "原力器孔位/限制与原预设不一致。"
		for field in ["equip","element","lock"]:
			if not value.get(field) is Array or value[field].size()!=2: return "原力器链结构无效。"
		for circle in 2:
			if not value.equip[circle] is Array or not value.lock[circle] is Array or value.equip[circle].size()!=value.pos[circle].size() or value.lock[circle].size()!=value.pos[circle].size(): return "原力器孔位数量无效。"
			var total: Array=[0,0,0,0,0]
			for column in value.equip[circle].size():
				if not value.lock[circle][column] is bool: return "原力器孔锁必须为布尔值。"
				var id: Variant=value.equip[circle][column]
				if id==null: continue
				var spec: Variant=storage.crystal.get(str(id))
				if not custom._integer(id) or not spec is Array: return "原力器结晶引用无效。"
				for i in 5: total[i]+=int(spec[2][i])
			if not custom.same_value(value.element[circle],total): return "原力器元素合计与装备不一致。"
	return ""

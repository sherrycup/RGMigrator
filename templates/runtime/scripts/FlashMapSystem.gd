extends RefCounted
## Original 0246 Game_MapSystem, backed by RuntimeState.custom_data values.
## Only an observed completed transfer produces a connection.
const Config=preload("FlashMapConfig.gd")
const Block=preload("FlashMapBlock.gd")
const Data=preload("RuntimeData.gd")
var _custom: WeakRef
var _blocks: Dictionary={}

func _init(custom: RefCounted) -> void:
	_custom=weakref(custom)
	ensure_state()

func ensure_state() -> void:
	var owner=_custom.get_ref()
	if not owner.values.has("map_system"): owner.values["map_system"]=empty_state()

static func empty_state() -> Dictionary:
	return {"blocks":{},"connections":{},"layout_notes":[]}

func state() -> Dictionary:
	ensure_state(); return _custom.get_ref().values.map_system

func block(id: int) -> RefCounted:
	if not state().blocks.has(str(id)): return null
	if not _blocks.has(id):
		var value=state().blocks[str(id)]; var proxy=Block.new(id,int(value.tile_width),int(value.tile_height),int(value.area))
		proxy.bind(self); _blocks[id]=proxy
	return _blocks[id]

func blocks() -> Dictionary:
	var result: Dictionary={}
	for key in state().blocks: result[int(key)]=block(int(key))
	return result

func connections() -> Array:
	return state().connections.values()

func layout_notes() -> Array:
	return state().layout_notes

func area_for(id: int) -> int:
	return Config.area_for(id)

func areas() -> Dictionary:
	var result: Dictionary={}
	for item in blocks().values():
		if not result.has(item.area): result[item.area]=[]
		result[item.area].append(item.id)
	return result

func area_unlock(id: int) -> bool:
	return areas().has(id)

func maps_in_area(id: int) -> Array:
	var result: Array=[]
	for item in blocks().values():
		if item.area==id: result.append(item)
	result.sort_custom(func(a,b):return a.id<b.id)
	return result

func discover_current() -> RefCounted:
	var owner: Node=_custom.get_ref()._owner.get_ref(); var map=Data.map(owner.map_id)
	return discover_map(owner.map_id,int(map.get("width",0)),int(map.get("height",0)))

func discover_map(id: int,tiles_x: int,tiles_y: int,pos: Variant=null) -> RefCounted:
	if state().blocks.has(str(id)): return block(id)
	if id<=0 or tiles_x<=0 or tiles_y<=0:
		_custom.get_ref().reject("发现地图需要有效编号和尺寸。"); return null
	var value=Block.new(id,tiles_x,tiles_y,area_for(id))
	var candidate: Variant=Config.map_info(id).get("position")
	if candidate==null or candidate is bool and not candidate: candidate=pos
	if candidate==null or candidate is bool and not candidate: candidate=free_position(value.area)
	if not candidate is Array or candidate.size()!=2 or not _custom.get_ref()._integer(candidate[0]) or not _custom.get_ref()._integer(candidate[1]):
		_custom.get_ref().reject("地图布局位置需要两个整数。"); return null
	if occupied(value,candidate):
		layout_notes().append(["overlap",id,candidate.duplicate()]); candidate=free_position(value.area)
	value.set_position(candidate); state().blocks[str(id)]=value.record().duplicate(true)
	return block(id)

func free_position(area: int) -> Array:
	var list=maps_in_area(area)
	if list.is_empty(): return [0,0]
	var right=list[0].x+list[0].width
	for item in list: right=maxi(right,item.x+item.width)
	return [right+2,0]

func occupied(value: RefCounted,pos: Array) -> bool:
	for other in maps_in_area(value.area):
		if pos[0]<other.x+other.width and pos[0]+value.width>other.x and pos[1]<other.y+other.height and pos[1]+value.height>other.y: return true
	return false

func capture_location() -> Dictionary:
	var current=discover_current()
	if current==null: return {}
	var owner: Node=_custom.get_ref()._owner.get_ref()
	var map: Dictionary=Data.map(owner.map_id)
	return {"id":owner.map_id,"x":owner.player_x,"y":owner.player_y,"width":int(map.width),"height":int(map.height),"facing":owner.player_direction}

func departure_side(from: Dictionary,to: Dictionary) -> int:
	var side: Variant=Config.departure_override(int(from.id),int(to.id))
	if side!=null: return int(side)
	var reverse: Variant=Config.departure_override(int(to.id),int(from.id))
	if reverse!=null: return 0 if reverse==0 else 10-int(reverse)
	var candidates: Array=[]
	if from.y>=from.height-2 and to.y<=1: candidates.append(2)
	if from.y<=1 and to.y>=to.height-2: candidates.append(8)
	if from.x<=1 and to.x>=to.width-2: candidates.append(4)
	if from.x>=from.width-2 and to.x<=1: candidates.append(6)
	return int(from.facing) if candidates.has(from.facing) else int(candidates[0]) if not candidates.is_empty() else 0

func adjacent_position(source: RefCounted,target: RefCounted,from: Dictionary,to: Dictionary,side: int) -> Variant:
	var a=source.cell_at(int(from.x),int(from.y)); var b=target.cell_at(int(to.x),int(to.y))
	match side:
		2: return [source.x+a[0]-b[0],source.y+source.height]
		8: return [source.x+a[0]-b[0],source.y-target.height]
		4: return [source.x-target.width,source.y+a[1]-b[1]]
		6: return [source.x+source.width,source.y+a[1]-b[1]]
	return null

func record_transfer(from: Dictionary,to: Dictionary) -> RefCounted:
	var source=discover_map(int(from.id),int(from.width),int(from.height))
	if source==null or from.id==to.id: return source
	var side=departure_side(from,to)
	var template=Block.new(int(to.id),int(to.width),int(to.height),area_for(int(to.id)))
	var pos: Variant=adjacent_position(source,template,from,to,side) if source.area==template.area else null
	var target=discover_map(int(to.id),int(to.width),int(to.height),pos)
	if target==null: return null
	var key=JSON.stringify([from.id,from.x,from.y,to.id,to.x,to.y])
	if not state().connections.has(key):
		state().connections[key]={"from":from.duplicate(true),"to":to.duplicate(true),"side":side}
		if pos!=null and pos!=target.position(): layout_notes().append(["alignment",source.id,target.id,pos.duplicate(),target.position()])
	return target

func connected(a: int,b: int) -> bool:
	for link in connections():
		if [int(link.from.id),int(link.to.id)] in [[a,b],[b,a]]: return true
	return false

func nearest_map(area: int,px: float,py: float) -> RefCounted:
	var best: RefCounted=null; var distance: Array=[]
	for item in maps_in_area(area):
		var candidate=item.distance_key(px,py)
		if best==null or _before(candidate,distance): best=item; distance=candidate
	return best

static func _before(a: Array,b: Array) -> bool:
	for i in a.size():
		if a[i]!=b[i]: return a[i]<b[i]
	return false

func bridge(link: Dictionary) -> Variant:
	var a=block(int(link.from.id)); var b=block(int(link.to.id))
	if a==null or b==null or a.area!=b.area: return null
	var side=int(link.side); var cell=a.cell_at(int(link.from.x),int(link.from.y))
	if side==2 and a.y+a.height==b.y or side==8 and b.y+b.height==a.y:
		var low=maxi(a.x,b.x); var high=mini(a.x+a.width,b.x+b.width)-1
		if low>high: return null
		var px=clampi(a.x+int(cell[0]),low,high); var py=b.y if side==2 else a.y
		return [[px,py-1],[px,py]]
	if side==6 and a.x+a.width==b.x or side==4 and b.x+b.width==a.x:
		var low=maxi(a.y,b.y); var high=mini(a.y+a.height,b.y+b.height)-1
		if low>high: return null
		var py=clampi(a.y+int(cell[1]),low,high); var px=b.x if side==6 else a.x
		return [[px-1,py],[px,py]]
	return null

func links_for(id: int) -> Array:
	return connections().filter(func(link):return int(link.from.id)==id or int(link.to.id)==id)

func invoke(ref: Dictionary,name: String,args: Array) -> Variant:
	var custom=_custom.get_ref()
	if ref.__custom_ref=="flash_map_block":
		var value=block(int(ref.id))
		if value==null: return custom.reject("地图块尚未发现。")
		if args.is_empty():
			if name in ["id","x","y","width","height","tile_width","tile_height","area"]: return value.get(name)
			if name=="position": return value.position()
			if name=="center": return value.center()
		if name=="cell_at" and args.size()==2 and custom._integer(args[0]) and custom._integer(args[1]): return value.cell_at(int(args[0]),int(args[1]))
		if name=="set_position" and args.size()==1 and _position(args[0]): value.set_position(args[0]); return null
		return custom.reject("地图块接口尚未接入或参数无效："+name)
	if args.is_empty():
		if name=="blocks":
			var result: Dictionary={}
			for key in state().blocks: result[int(key)]=custom.data_ref("flash_map_block",int(key))
			return result
		if name=="connections": return connections().duplicate(true)
		if name=="layout_notes": return layout_notes().duplicate(true)
		if name=="areas": return areas()
		if name=="capture_location": return capture_location()
		if name=="discover_current":
			var value=discover_current(); return custom.data_ref("flash_map_block",value.id) if value!=null else null
		if name=="ensure_state": ensure_state(); return null
	if args.size()==1 and custom._integer(args[0]):
		if name=="area_for": return area_for(int(args[0]))
		if name=="area_unlock?": return area_unlock(int(args[0]))
		if name=="maps_in_area": return maps_in_area(int(args[0])).map(func(value):return custom.data_ref("flash_map_block",value.id))
		if name=="links_for": return links_for(int(args[0])).duplicate(true)
		if name=="free_position": return free_position(int(args[0]))
	if name=="connected?" and args.size()==2 and custom._integer(args[0]) and custom._integer(args[1]): return connected(int(args[0]),int(args[1]))
	if name=="discover_map" and args.size() in [3,4]:
		for value in args.slice(0,3):
			if not custom._integer(value): return custom.reject("发现地图参数必须为整数。")
		var value=discover_map(int(args[0]),int(args[1]),int(args[2]),args[3] if args.size()==4 else null)
		return custom.data_ref("flash_map_block",value.id) if value!=null else null
	if name=="nearest_map" and args.size()==3 and custom._integer(args[0]) and preload("FlashActorFields.gd").number(args[1]) and preload("FlashActorFields.gd").number(args[2]):
		var value=nearest_map(int(args[0]),float(args[1]),float(args[2])); return custom.data_ref("flash_map_block",value.id) if value!=null else null
	return custom.reject("地图系统接口尚未接入或参数无效："+name)

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.keys().size()!=3 or not value.get("blocks") is Dictionary or not value.get("connections") is Dictionary or not value.get("layout_notes") is Array: return "地图发现快照结构无效。"
	if value.blocks.size()>10000 or value.connections.size()>100000 or value.layout_notes.size()>100000: return "地图发现快照超过容量。"
	for key in value.blocks:
		var entry: Variant=value.blocks[key]
		if not str(key).is_valid_int() or not entry is Dictionary or entry.keys().size()!=8: return "地图块记录无效。"
		for field in ["id","x","y","width","height","tile_width","tile_height","area"]:
			if not _integer(entry.get(field)): return "地图块字段无效："+field
		if int(entry.id)!=int(key) or Data.map(int(key)).is_empty() or entry.tile_width<=0 or entry.tile_height<=0 or entry.width!=Config.cell_count(int(entry.tile_width),Config.CELL_WIDTH) or entry.height!=Config.cell_count(int(entry.tile_height),Config.CELL_HEIGHT): return "地图块编号或尺寸无效。"
	for key in value.connections:
		var link: Variant=value.connections[key]
		if not link is Dictionary or link.keys().size()!=3 or not _integer(link.get("side")) or int(link.side) not in [0,2,4,6,8]: return "地图连接记录无效。"
		for end in ["from","to"]:
			var location: Variant=link.get(end)
			if not location is Dictionary or location.keys().size()!=6: return "地图连接位置无效。"
			for field in ["id","x","y","width","height","facing"]:
				if not _integer(location.get(field)): return "地图连接字段无效。"
			if not value.blocks.has(str(int(location.id))) or location.width<=0 or location.height<=0 or location.x<0 or location.y<0 or location.x>=location.width or location.y>=location.height or int(location.facing) not in [2,4,6,8]: return "地图连接引用或落点无效。"
		var expected=JSON.stringify([int(link.from.id),int(link.from.x),int(link.from.y),int(link.to.id),int(link.to.x),int(link.to.y)])
		if key!=expected: return "地图连接索引与位置不一致。"
	for note in value.layout_notes:
		if not note is Array or note.is_empty() or note[0] not in ["overlap","alignment"]: return "地图布局记录无效。"
		if note[0]=="overlap":
			if note.size()!=3 or not _integer(note[1]) or not value.blocks.has(str(int(note[1]))) or not _position(note[2]): return "地图重叠记录无效。"
		else:
			if note.size()!=5 or not _integer(note[1]) or not _integer(note[2]) or not value.blocks.has(str(int(note[1]))) or not value.blocks.has(str(int(note[2]))) or not _position(note[3]) or not _position(note[4]): return "地图对齐记录无效。"
	return ""

static func _position(value: Variant) -> bool:
	return value is Array and value.size()==2 and _integer(value[0]) and _integer(value[1])

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and abs(value)<=9007199254740991

extends RefCounted
## Original 0108, with confirmed field/to_id mistakes corrected. No Ruby eval
## or source-map mutation: links are parsed from the imported event definitions.
const Data=preload("RuntimeData.gd")
const Utils=preload("FlashUtils.gd")
var region: int
var floor_number: int
var map_id: int
var links: Dictionary={}
var _custom: WeakRef

func _init(custom: RefCounted,area: int,floor_id: int) -> void:
	_custom=weakref(custom); region=area; floor_number=floor_id
	map_id=int(custom.manifest.get("floors",{}).get("lookup",{}).get("%d:%d" % [region,floor_number],0))
	if map_id<=0 or Data.map(map_id).is_empty(): custom.reject("楼层索引没有对应的地图定义。"); return
	load_links()

func load_links() -> void:
	links.clear()
	var custom=_custom.get_ref(); var definition=Data.map(map_id)
	var names: Dictionary=custom.values.system.get("event_name",{}).get(str(map_id),{})
	var positions: Dictionary=custom.values.system.get("event_position",{}).get(str(map_id),{})
	var matcher=RegEx.new(); matcher.compile("(-*\\d+):(-*\\d+):(\\[\\d+,\\d+\\])")
	for key in definition.get("events",{}):
		var event: Dictionary=definition.events[key]
		var name=str(names.get(str(key),event.get("name","")))
		var pos: Variant=positions.get(str(key),[int(event.x),int(event.y)])
		if not pos is Array or pos.size()!=2 or not custom._integer(pos[0]) or not custom._integer(pos[1]): custom.reject("楼层链接事件位置无效。"); return
		var found=matcher.search(name)
		if found==null: continue
		var area=Utils.integer_text(found.get_string(1),10); var target=Utils.integer_text(found.get_string(2),10)
		var coords: Variant=JSON.parse_string(found.get_string(3))
		links[Vector2i(int(pos[0]),int(pos[1]))]=[area.value,target.value,[int(coords[0]),int(coords[1])]]

func signature() -> Array:
	return [region,floor_number]

func transloc() -> Variant:
	var owner: Node=_custom.get_ref()._owner.get_ref()
	var position=Vector2i(owner.player_x,owner.player_y)
	return [links[position].duplicate(true)] if owner.map_id==map_id and links.has(position) else false

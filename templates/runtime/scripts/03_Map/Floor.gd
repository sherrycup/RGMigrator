## 职责：维护闪翼楼层的发现、事件和地图关联数据，提供原楼层脚本接口。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/Floor.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(custom: RefCounted, area: int, floor_id: int) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 area（int；必填）：待查询或绘制的区域。
##     参数 floor_id（int；必填）：楼层的原编号。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func load_links() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func signature() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func transloc() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted
## Original 0108, with confirmed field/to_id mistakes corrected. No Ruby eval
## or source-map mutation: links are parsed from the imported event definitions.
const Data = preload("../00_Game/RuntimeData.gd")
const Utils = preload("../10_Support/Utilities/Utils.gd")
var region: int
var floor_number: int
var map_id: int
var links: Dictionary = {}
var _custom: WeakRef


func _init(custom: RefCounted, area: int, floor_id: int) -> void:
	_custom = weakref(custom)
	region = area
	floor_number = floor_id
	map_id = int(
		custom.manifest.get("floors", {}).get("lookup", {}).get("%d:%d" % [region, floor_number], 0)
	)
	if map_id <= 0 or Data.map(map_id).is_empty():
		custom.reject("楼层索引没有对应的地图定义。")
		return
	load_links()


func load_links() -> void:
	links.clear()
	var custom = _custom.get_ref()
	var definition = Data.map(map_id)
	var names: Dictionary = custom.values.system.get("event_name", {}).get(str(map_id), {})
	var positions: Dictionary = custom.values.system.get("event_position", {}).get(str(map_id), {})
	var matcher = RegEx.new()
	matcher.compile("(-*\\d+):(-*\\d+):(\\[\\d+,\\d+\\])")
	for key in definition.get("events", {}):
		var event: Dictionary = definition.events[key]
		var name = str(names.get(str(key), event.get("name", "")))
		var pos: Variant = positions.get(str(key), [int(event.x), int(event.y)])
		if (
			not pos is Array
			or pos.size() != 2
			or not custom._integer(pos[0])
			or not custom._integer(pos[1])
		):
			custom.reject("楼层链接事件位置无效。")
			return
		var found = matcher.search(name)
		if found == null:
			continue
		var area = Utils.integer_text(found.get_string(1), 10)
		var target = Utils.integer_text(found.get_string(2), 10)
		var coords: Variant = JSON.parse_string(found.get_string(3))
		links[Vector2i(int(pos[0]), int(pos[1]))] = [
			area.value, target.value, [int(coords[0]), int(coords[1])]
		]


func signature() -> Array:
	return [region, floor_number]


func transloc() -> Variant:
	var owner: Node = _custom.get_ref()._owner.get_ref()
	var position = Vector2i(owner.player_x, owner.player_y)
	return (
		[links[position].duplicate(true)]
		if owner.map_id == map_id and links.has(position)
		else false
	)

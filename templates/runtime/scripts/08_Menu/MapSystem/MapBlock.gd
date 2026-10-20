## 职责：描述闪翼地图系统中的楼层区块及其显示与连接信息。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/MapSystem/MapBlock.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(map_id: int, tiles_x: int = 20, tiles_y: int = 15, region: int = 0) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 map_id（int；必填）：地图的原编号。
##     参数 tiles_x（int；默认值 20）：以格子计的水平偏移或尺寸。
##     参数 tiles_y（int；默认值 15）：以格子计的垂直偏移或尺寸。
##     参数 region（int；默认值 0）：地图区域对象或区域记录。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func bind(system: RefCounted) -> void
##     参数 system（RefCounted；必填）：原系统数据库或系统配置。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func record() -> Dictionary
##     用途：记录当前操作或运行现场。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func position() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func set_position(pos: Array) -> void
##     参数 pos（Array；必填）：目标位置或当前位置。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func cell_at(px: int, py: int) -> Array
##     参数 px（int；必填）：以像素计的横向坐标。
##     参数 py（int；必填）：以像素计的纵向坐标。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func center() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func distance_key(px: float, py: float) -> Array
##     参数 px（float；必填）：以像素计的横向坐标。
##     参数 py（float；必填）：以像素计的纵向坐标。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
## 接口说明结束。

extends RefCounted
## Original 0247 Game_MapBlock. A bound block reads the current shared record
## after each script transaction; a cursor cannot retain an obsolete draft.
const Config = preload("MapConfig.gd")
var id: int
var _standalone: Dictionary
var _system: WeakRef
var x: int:
	get:
		return int(record().x)
var y: int:
	get:
		return int(record().y)
var width: int:
	get:
		return int(record().width)
var height: int:
	get:
		return int(record().height)
var tile_width: int:
	get:
		return int(record().tile_width)
var tile_height: int:
	get:
		return int(record().tile_height)
var area: int:
	get:
		return int(record().area)


func _init(map_id: int, tiles_x: int = 20, tiles_y: int = 15, region: int = 0) -> void:
	id = map_id
	_standalone = {
		"id": id,
		"x": 0,
		"y": 0,
		"width": Config.cell_count(tiles_x, Config.CELL_WIDTH),
		"height": Config.cell_count(tiles_y, Config.CELL_HEIGHT),
		"tile_width": tiles_x,
		"tile_height": tiles_y,
		"area": region
	}


func bind(system: RefCounted) -> void:
	_system = weakref(system)


func record() -> Dictionary:
	return (
		_system.get_ref().state().blocks[str(id)]
		if _system != null and _system.get_ref() != null
		else _standalone
	)


func position() -> Array:
	return [x, y]


func set_position(pos: Array) -> void:
	var value = record()
	value.x = int(pos[0])
	value.y = int(pos[1])


func cell_at(px: int, py: int) -> Array:
	return [
		clampi(floori(float(px - 1) / Config.CELL_WIDTH), 0, width - 1),
		clampi(floori(float(py - 1) / Config.CELL_HEIGHT), 0, height - 1)
	]


func center() -> Array:
	return [x + width / 2.0, y + height / 2.0]


func distance_key(px: float, py: float) -> Array:
	var dx = maxf(maxf(x - px, 0), px - x - width)
	var dy = maxf(maxf(y - py, 0), py - y - height)
	var middle = center()
	return [dx * dx + dy * dy, pow(middle[0] - px, 2) + pow(middle[1] - py, 2), id]

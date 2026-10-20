## 职责：读取闪翼地图系统的布局和显示配置，统一地图页面参数。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/MapSystem/MapConfig.gd").方法名(...)。
##
## 调用接口：
##   static func map_info(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func map_name(id: int) -> String
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func area_for(id: int) -> int
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func area_name(id: int) -> String
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func area_color(id: int) -> Color
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   static func cell_count(size: int, step: int) -> int
##     参数 size（int；必填）：对象、画布或区域尺寸。
##     参数 step（int；必填）：步长或单次推进量。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func departure_override(a: int, b: int) -> Variant
##     参数 a（int；必填）：第一个操作数或参与比较的值。
##     参数 b（int；必填）：第二个操作数或参与比较的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 公开常量：CELL_WIDTH、CELL_HEIGHT、CELL_SIZE、CURSOR_SPEED、LOCK_FRAMES、PREVIEW_WIDTH、PREVIEW_HEIGHT。
## 接口说明结束。

extends RefCounted
## Original 0245 MapSystemConfig. These three editable tables are empty in the
## actual loaded Flash source; comments are examples, not real registrations.
const Data = preload("../../00_Game/RuntimeData.gd")
const CELL_WIDTH = 18
const CELL_HEIGHT = 13
const CELL_SIZE = 40
const CURSOR_SPEED = 0.125
const LOCK_FRAMES = 6
const PREVIEW_WIDTH = 240
const PREVIEW_HEIGHT = 180
static var AREAS: Dictionary = {}
static var MAPS: Dictionary = {}
static var DIRECTIONS: Dictionary = {}


static func map_info(id: int) -> Dictionary:
	return MAPS.get(id, MAPS.get(str(id), {}))


static func map_name(id: int) -> String:
	var info = map_info(id)
	if info.get("name") != null:
		return str(info.name)
	return str(
		Data.read_json("res://data/map_infos.json", {}).get(str(id), {}).get("name", "Map %d" % id)
	)


static func area_for(id: int) -> int:
	var info = map_info(id)
	if info.has("area"):
		return int(info.area)
	var matcher = RegEx.new()
	matcher.compile("^(-?\\d+):(-?\\d+)")
	var found = matcher.search(map_name(id))
	return int(found.get_string(1)) if found != null else 0


static func area_name(id: int) -> String:
	var area: Dictionary = AREAS.get(id, AREAS.get(str(id), {}))
	return str(area.get("name", "未分区" if id == 0 else "区域 %d" % id))


static func area_color(id: int) -> Color:
	var components: Array = AREAS.get(id, AREAS.get(str(id), {})).get("color", [72, 150, 128])
	return Color(
		float(components[0]) / 255.0, float(components[1]) / 255.0, float(components[2]) / 255.0
	)


static func cell_count(size: int, step: int) -> int:
	return maxi(floori(float(size - 2 + step - 1) / step), 1)


static func departure_override(a: int, b: int) -> Variant:
	return DIRECTIONS.get([a, b], DIRECTIONS.get("%d:%d" % [a, b]))

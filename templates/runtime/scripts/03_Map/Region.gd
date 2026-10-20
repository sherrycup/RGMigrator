## 职责：维护闪翼区域及楼层连接关系，记录区域发现、布局和访问状态。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/Region.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(custom: RefCounted, area: Variant) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 area（Variant；必填）：待查询或绘制的区域。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func load_floors() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func generate_structure() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_region(area: Variant) -> void
##     参数 area（Variant；必填）：待查询或绘制的区域。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## Original 0109 floor collection. generate_structure is empty in the source.
const Floor = preload("Floor.gd")
var region: Variant = null
var floors: Dictionary = {}
var _custom: WeakRef


func _init(custom: RefCounted, area: Variant) -> void:
	_custom = weakref(custom)
	region = area
	load_floors()


func load_floors() -> void:
	floors.clear()
	if region == null or region is bool and not region:
		return
	var custom = _custom.get_ref()
	for key in custom.manifest.get("floors", {}).get("lookup", {}):
		var pair = str(key).split(":")
		if int(pair[0]) == region:
			floors[int(pair[1])] = Floor.new(custom, int(pair[0]), int(pair[1]))


func generate_structure() -> void:
	pass


func set_region(area: Variant) -> void:
	if region == area:
		return
	region = area
	load_floors()

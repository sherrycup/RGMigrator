## 职责：管理闪翼地图页面的光标位置、移动和当前区块选择。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/MapSystem/MapCursor.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(owner: RefCounted, value: RefCounted) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 owner（RefCounted；必填）：持有此对象的调用方或运行状态。
##     参数 value（RefCounted；必填）：需要读取、校验或写入的值。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func select(value: RefCounted) -> void
##     参数 value（RefCounted；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func rect() -> Rect2
##     参数：无。
##     返回：Rect2 类型的对象或值，供调用方继续使用。
##
##   func update(dx: int, dy: int) -> String
##     参数 dx（int；必填）：水平移动或偏移量。
##     参数 dy（int；必填）：垂直移动或偏移量。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func change_area(step: int) -> void
##     参数 step（int；必填）：步长或单次推进量。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## Original 0251 MapSystemCursor, advanced by the UI's source 60 Hz clock.
const Config = preload("MapConfig.gd")
var system: RefCounted
var x: float
var y: float
var area: int
var selected: RefCounted
var locked = true
var idle = 0


func _init(owner: RefCounted, value: RefCounted) -> void:
	system = owner
	select(value)


func select(value: RefCounted) -> void:
	selected = value
	area = value.area
	var middle = value.center()
	x = middle[0]
	y = middle[1]
	locked = true
	idle = 0


func rect() -> Rect2:
	return (
		Rect2(selected.x, selected.y, selected.width, selected.height)
		if locked
		else Rect2(x - 0.5, y - 0.5, 1, 1)
	)


func update(dx: int, dy: int) -> String:
	if dx != 0 or dy != 0:
		locked = false
		idle = 0
		x += dx * Config.CURSOR_SPEED
		y += dy * Config.CURSOR_SPEED
		var list = system.maps_in_area(area)
		var left = list[0].x
		var top = list[0].y
		var right = left + list[0].width
		var bottom = top + list[0].height
		for value in list:
			left = mini(left, value.x)
			top = mini(top, value.y)
			right = maxi(right, value.x + value.width)
			bottom = maxi(bottom, value.y + value.height)
		x = clampf(x, left - 2, right + 2)
		y = clampf(y, top - 2, bottom + 2)
		return "move"
	if locked:
		return ""
	idle += 1
	if idle >= Config.LOCK_FRAMES:
		select(system.nearest_map(area, x, y))
		return "lock"
	return ""


func change_area(step: int) -> void:
	var ids = system.areas().keys()
	ids.sort()
	if ids.is_empty():
		return
	var index = posmod(ids.find(area) + step, ids.size())
	select(system.maps_in_area(ids[index])[0])

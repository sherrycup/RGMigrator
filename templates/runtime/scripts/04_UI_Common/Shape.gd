## 职责：提供闪翼界面所需的基础形状绘制和几何辅助操作。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/04_UI_Common/Shape.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(x: int = 0, y: int = 0, rectangles: Array = []) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 x（int；默认值 0）：横向坐标。
##     参数 y（int；默认值 0）：纵向坐标。
##     参数 rectangles（Array；默认值 []）：绘制区域或分块矩形集合。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func set_origin(point: Vector2i) -> void
##     参数 point（Vector2i；必填）：位置或几何点。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func includes(point: Vector2i) -> bool
##     参数 point（Vector2i；必填）：位置或几何点。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func each_pixel(callback: Callable) -> void
##     参数 callback（Callable；必填）：完成或处理中调用的回调。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func each_rect(callback: Callable) -> void
##     参数 callback（Callable；必填）：完成或处理中调用的回调。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fill(bitmap: RefCounted, color: Color) -> void
##     参数 bitmap（RefCounted；必填）：图像画布或 Bitmap 适配实例。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_hexagon(value: int, phase_value: float = 0) -> void
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     参数 phase_value（float；默认值 0）：演出或动画的阶段值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func twist(angle: float) -> void
##     参数 angle（float；必填）：旋转角度参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## 0030 Shape / final loaded 0031 Hexagon. The last twist definition updates
## phase, while the source scanlines do not rotate with phase.
var origin = Vector2i.ZERO
var rects: Array = []
var radius = 0
var phase = 0.0


func _init(x: int = 0, y: int = 0, rectangles: Array = []) -> void:
	origin = Vector2i(x, y)
	rects = rectangles.duplicate(true)


func set_origin(point: Vector2i) -> void:
	for i in rects.size():
		rects[i].position += point - origin
	origin = point


func includes(point: Vector2i) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false


func each_pixel(callback: Callable) -> void:
	for rect in rects:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				callback.call(x, y)


func each_rect(callback: Callable) -> void:
	for rect in rects:
		callback.call(rect)


func fill(bitmap: RefCounted, color: Color) -> void:
	for rect in rects:
		bitmap.fill_rect(rect, color)


func set_hexagon(value: int, phase_value: float = 0) -> void:
	radius = maxi(0, value)
	phase = phase_value
	rects.clear()
	for i in int(radius * sqrt(3) / 2):
		var x = int(origin.x - radius + i / sqrt(3))
		var width = radius * 2 - int(i * 2 / sqrt(3))
		rects.append(Rect2i(x, origin.y - i, width, 1))
		if i != 0:
			rects.append(Rect2i(x, origin.y + i, width, 1))


func twist(angle: float) -> void:
	if fmod(angle, 60) == 0:
		return
	set_hexagon(radius, phase + angle)

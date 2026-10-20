## 职责：管理闪翼帮助文本和短提示的内容、布局及显示。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/06_Message/HelpMessage.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init( x: int = 0, y: int = 0, width: int = 0, height: int = 0, canvas: Vector2i = Vector2i(640, 640) ) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 x（int；默认值 0）：横向坐标。
##     参数 y（int；默认值 0）：纵向坐标。
##     参数 width（int；默认值 0）：区域或画布宽度。
##     参数 height（int；默认值 0）：区域或画布高度。
##     参数 canvas（Vector2i；默认值 Vector2i(640, 640)）：用于绘制或预览的画布对象。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func make_shadow(canvas: Vector2i = Vector2i(640, 640)) -> void
##     参数 canvas（Vector2i；默认值 Vector2i(640, 640)）：用于绘制或预览的画布对象。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_text(_type: Variant) -> void
##     参数 _type（Variant；必填）：为保持原接口位置保留，本实现未读取此参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func update() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func dispose() -> void
##     用途：释放本实例管理的资源及引用。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## 0312 Help_Message is unfinished in the original. Blank shadow bitmaps have
## no visible content; retain their geometry without allocating leaked sprites.
var rect: Rect2i
var shadows: Array = []
var text = ""


func _init(
	x: int = 0, y: int = 0, width: int = 0, height: int = 0, canvas: Vector2i = Vector2i(640, 640)
) -> void:
	rect = Rect2i(x, y, width, height)
	make_shadow(canvas)


func make_shadow(canvas: Vector2i = Vector2i(640, 640)) -> void:
	var widths = [
		rect.position.x, canvas.x - rect.size.x - rect.position.x, rect.size.x, rect.size.x
	]
	var heights = [canvas.y, canvas.y, rect.position.y, canvas.x - rect.position.y - rect.size.y]
	var xs = [0, rect.position.x, rect.end.x, rect.position.x]
	var ys = [0, 0, 0, rect.end.y]
	shadows = []
	for i in 4:
		shadows.append(Rect2i(xs[i], ys[i], maxi(0, widths[i]), maxi(0, heights[i])))


func set_text(_type: Variant) -> void:
	pass  # Source empty, no tutorial invented.


func update() -> void:
	pass  # Source empty.


func dispose() -> void:
	shadows.clear()  # Only this instance owns the records.

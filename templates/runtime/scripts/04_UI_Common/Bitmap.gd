## 职责：提供闪翼 Bitmap 风格的图像画布和绘制操作，连接原显示脚本语义。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/04_UI_Common/Bitmap.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/04_UI_Common/Bitmap.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(width: int = 1, height: int = 1) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 width（int；默认值 1）：区域或画布宽度。
##     参数 height（int；默认值 1）：区域或画布高度。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func clear() -> void
##     用途：清空当前内容或状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fill_rect(rect: Rect2i, color: Color) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_pixel(x: int, y: int, color: Color) -> void
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func texture() -> ImageTexture
##     参数：无。
##     返回：ImageTexture 类型的对象或值，供调用方继续使用。
##
##   func clear_rect(rect: Rect2i) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func get_pixel(x: int, y: int) -> Color
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   func copy() -> RefCounted
##     参数：无。
##     返回：RefCounted 类型的对象或值，供调用方继续使用。
##
##   func invert() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func hue_change(degrees: float) -> void
##     参数 degrees（float；必填）：角度，单位为度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func change_tone(red: int, green: int, blue: int, _simplify: int = 1) -> void
##     参数 red（int；必填）：红色通道值。
##     参数 green（int；必填）：绿色通道值。
##     参数 blue（int；必填）：蓝色通道值。
##     参数 _simplify（int；默认值 1）：为保持原接口位置保留，本实现未读取此参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func clip_mask(mask: Image, x: int = 0, y: int = 0, outer: int = 0) -> void
##     参数 mask（Image；必填）：过渡或绘制使用的遮罩。
##     参数 x（int；默认值 0）：横向坐标。
##     参数 y（int；默认值 0）：纵向坐标。
##     参数 outer（int；默认值 0）：外层范围或外框参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func mosaic(width: int = 5, height: int = 5) -> void
##     参数 width（int；默认值 5）：区域或画布宽度。
##     参数 height（int；默认值 5）：区域或画布高度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func mosaic_rect(rect: Rect2i, width: int = 5, height: int = 5) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 width（int；默认值 5）：区域或画布宽度。
##     参数 height（int；默认值 5）：区域或画布高度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func blend_blt( x: int, y: int, source: Image, rect: Rect2i, blend_type: int = 0, opacity: int = 255 ) -> void
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 source（Image；必填）：待处理的原始文本、数据或状态。
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 blend_type（int；默认值 0）：原图像混合模式编号。
##     参数 opacity（int；默认值 255）：透明度参数，取值按对应显示接口约定。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func blur2(radius: int = 1) -> void
##     参数 radius（int；默认值 1）：效果或查询范围的半径。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func get_pixel_data() -> PackedByteArray
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func set_pixel_data(value: PackedByteArray) -> Dictionary
##     参数 value（PackedByteArray；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func png_save(path: String, _level: int = 9, _filter: int = 0) -> Dictionary
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     参数 _level（int；默认值 9）：为保持原接口位置保留，本实现未读取此参数。
##     参数 _filter（int；默认值 0）：为保持原接口位置保留，本实现未读取此参数。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func draw_rhombus(points: Array, colors: Array) -> void
##     参数 points（Array；必填）：绘制或路径使用的点集合。
##     参数 colors（Array；必填）：绘制使用的颜色集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fill_ellipse(center: Vector2i, width: int, height: int, color: Color) -> void
##     参数 center（Vector2i；必填）：区域或效果的中心位置。
##     参数 width（int；必填）：区域或画布宽度。
##     参数 height（int；必填）：区域或画布高度。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_ellipse_border(center: Vector2i, radius: int, type: int, color: Color) -> void
##     参数 center（Vector2i；必填）：区域或效果的中心位置。
##     参数 radius（int；必填）：效果或查询范围的半径。
##     参数 type（int；必填）：当前操作的类型标识。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_rounded_border(center: Rect2i, radius: int, color: Color) -> void
##     参数 center（Rect2i；必填）：区域或效果的中心位置。
##     参数 radius（int；必填）：效果或查询范围的半径。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fill_rounded_rect(rect: Rect2i, radius: int, color: Color) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 radius（int；必填）：效果或查询范围的半径。
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func gradient(rect: Rect2i, first: Color, last: Color, vertical: bool = false) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 last（Color；必填）：最后一个值或结束位置。
##     参数 vertical（bool；默认值 false）：是否按垂直方向处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func gradation_rect(rect: Rect2i, first: Color, last: Color, align: int = 0) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 last（Color；必填）：最后一个值或结束位置。
##     参数 align（int；默认值 0）：文本或元素的对齐方式。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func gradate_line( rect: Rect2i, colors: Array, indent: Vector2i = Vector2i.ZERO, vertical: bool = false ) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 colors（Array；必填）：绘制使用的颜色集合。
##     参数 indent（Vector2i；默认值 Vector2i.ZERO）：事件指令的结构缩进层级。
##     参数 vertical（bool；默认值 false）：是否按垂直方向处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func gradate_rect(rect: Rect2i, colors: Array) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 colors（Array；必填）：绘制使用的颜色集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_line( first: int, second: int, third: int, fourth: int, coordinate: int, type: int = 0, opacity: int = 255 ) -> void
##     参数 first（int；必填）：第一个值、对象或起始位置。
##     参数 second（int；必填）：第二个值或参与操作的对象。
##     参数 third（int；必填）：第三个位置参数。
##     参数 fourth（int；必填）：第四个位置参数。
##     参数 coordinate（int；必填）：地图或绘制坐标。
##     参数 type（int；默认值 0）：当前操作的类型标识。
##     参数 opacity（int；默认值 255）：透明度参数，取值按对应显示接口约定。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_line2(first: Vector2i, last: Vector2i, width: int, colors: Array) -> void
##     参数 first（Vector2i；必填）：第一个值、对象或起始位置。
##     参数 last（Vector2i；必填）：最后一个值或结束位置。
##     参数 width（int；必填）：区域或画布宽度。
##     参数 colors（Array；必填）：绘制使用的颜色集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_h8_panel_fill(rect: Rect2i) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_h8_background(rect: Rect2i, opacity: int = 160, margin: int = 16) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 opacity（int；默认值 160）：透明度参数，取值按对应显示接口约定。
##     参数 margin（int；默认值 16）：界面边距或额外留白。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_h8_outer_frame(rect: Rect2i, opacity: int = 132) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 opacity（int；默认值 132）：透明度参数，取值按对应显示接口约定。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_h8_corner_light(point: Vector2i, direction: Vector2i, opacity: int = 132) -> void
##     参数 point（Vector2i；必填）：位置或几何点。
##     参数 direction（Vector2i；必填）：当前操作使用的方向或选择移动量。
##     参数 opacity（int；默认值 132）：透明度参数，取值按对应显示接口约定。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_h8_inner_line( first: Vector2i, last: Vector2i, type: int = 0, opacity: int = 132, width: int = 1 ) -> void
##     参数 first（Vector2i；必填）：第一个值、对象或起始位置。
##     参数 last（Vector2i；必填）：最后一个值或结束位置。
##     参数 type（int；默认值 0）：当前操作的类型标识。
##     参数 opacity（int；默认值 132）：透明度参数，取值按对应显示接口约定。
##     参数 width（int；默认值 1）：区域或画布宽度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_h8_bulge(first: Vector2i, last: Vector2i, plus: bool, height: int, type: int) -> void
##     参数 first（Vector2i；必填）：第一个值、对象或起始位置。
##     参数 last（Vector2i；必填）：最后一个值或结束位置。
##     参数 plus（bool；必填）：附加的属性增量。
##     参数 height（int；必填）：区域或画布高度。
##     参数 type（int；必填）：当前操作的类型标识。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func skill_frame_colors(type: int) -> Array
##     参数 type（int；必填）：当前操作的类型标识。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func draw_skill_frame( rect: Rect2i, type: int = 1, show_turn_box: bool = false, corners: bool = true ) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 type（int；默认值 1）：当前操作的类型标识。
##     参数 show_turn_box（bool；默认值 false）：是否显示回合或行动提示框。
##     参数 corners（bool；默认值 true）：区域角点集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_turn_box(rect: Rect2i, colors: Array) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 colors（Array；必填）：绘制使用的颜色集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_item_frame(rect: Rect2i, corners: bool = true) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 corners（bool；默认值 true）：区域角点集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_hud_back(rect: Rect2i, type: int = 0) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 type（int；默认值 0）：当前操作的类型标识。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_hud_line( rect: Rect2i, value: int, maximum: int, first: Color, last: Color, type: int = 0 ) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     参数 maximum（int；必填）：允许值的上限。
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 last（Color；必填）：最后一个值或结束位置。
##     参数 type（int；默认值 0）：当前操作的类型标识。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_trapezoid_meter( rect: Rect2i, value: int, maximum: int, first: Color, last: Color ) -> void
##     参数 rect（Rect2i；必填）：目标矩形的位置与尺寸。
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     参数 maximum（int；必填）：允许值的上限。
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 last（Color；必填）：最后一个值或结束位置。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func panel_style(size: Vector2i, margin: int = 16) -> StyleBoxTexture
##     参数 size（Vector2i；必填）：对象、画布或区域尺寸。
##     参数 margin（int；默认值 16）：界面边距或额外留白。
##     返回：StyleBoxTexture 类型的对象或值，供调用方继续使用。
##
##   static func skill_style(size: Vector2i, type: int = 1, corners: bool = true) -> StyleBoxTexture
##     参数 size（Vector2i；必填）：对象、画布或区域尺寸。
##     参数 type（int；默认值 1）：当前操作的类型标识。
##     参数 corners（bool；默认值 true）：区域角点集合。
##     返回：StyleBoxTexture 类型的对象或值，供调用方继续使用。
##
## 接口说明结束。

extends RefCounted
## 0023/0027/0111 scratch bitmap drawing in pure GDScript. Every bitmap owns
## its Image; cached engine textures are only read and never modified in place.
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
var image: Image
static var _panel_cache: Dictionary = {}
static var _panel_order: Array = []


func _init(width: int = 1, height: int = 1) -> void:
	image = Image.create(clampi(width, 1, 4096), clampi(height, 1, 4096), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)


func clear() -> void:
	image.fill(Color.TRANSPARENT)


func fill_rect(rect: Rect2i, color: Color) -> void:
	if not rect.has_area():
		return
	var clipped = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if clipped.has_area():
		image.fill_rect(clipped, color)


func set_pixel(x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)


func clear_rect(rect: Rect2i) -> void:
	fill_rect(rect, Color.TRANSPARENT)


func get_pixel(x: int, y: int) -> Color:
	return (
		image.get_pixel(x, y)
		if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height()
		else Color.TRANSPARENT
	)


func copy() -> RefCounted:
	var bitmap = get_script().new(image.get_width(), image.get_height())
	bitmap.image = image.duplicate()
	return bitmap


func invert() -> void:
	var bytes = image.get_data()
	for i in range(0, bytes.size(), 4):
		bytes[i] = 255 - bytes[i]
		bytes[i + 1] = 255 - bytes[i + 1]
		bytes[i + 2] = 255 - bytes[i + 2]
	image = Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes
	)


func hue_change(degrees: float) -> void:
	if not is_finite(degrees):
		return
	for y in image.get_height():
		for x in image.get_width():
			var color = image.get_pixel(x, y)
			image.set_pixel(
				x,
				y,
				Color.from_hsv(fposmod(color.h + degrees / 360, 1.0), color.s, color.v, color.a)
			)


func change_tone(red: int, green: int, blue: int, _simplify: int = 1) -> void:
	var bytes = image.get_data()
	for i in range(0, bytes.size(), 4):
		bytes[i] = clampi(bytes[i] + red, 0, 255)
		bytes[i + 1] = clampi(bytes[i + 1] + green, 0, 255)
		bytes[i + 2] = clampi(bytes[i + 2] + blue, 0, 255)
	image = Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes
	)


func clip_mask(mask: Image, x: int = 0, y: int = 0, outer: int = 0) -> void:
	if mask == null or mask.is_empty():
		return
	var bytes = image.get_data()
	var width = image.get_width()
	var height = image.get_height()
	for py in height:
		for px in width:
			var mx = px - x
			var my = py - y
			var alpha = (
				mask.get_pixel(mx, my).a8
				if mx >= 0 and my >= 0 and mx < mask.get_width() and my < mask.get_height()
				else clampi(outer, 0, 255)
			)
			var offset = (px + py * width) * 4 + 3
			bytes[offset] = int(bytes[offset] * alpha / 255)
	image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)


func mosaic(width: int = 5, height: int = 5) -> void:
	mosaic_rect(Rect2i(Vector2i.ZERO, image.get_size()), width, height)


func mosaic_rect(rect: Rect2i, width: int = 5, height: int = 5) -> void:
	if width < 1 or height < 1:
		return
	var clipped = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var original = image.duplicate()
	for y in range(clipped.position.y, clipped.end.y, height):
		for x in range(clipped.position.x, clipped.end.x, width):
			var cell = Rect2i(x, y, mini(width, clipped.end.x - x), mini(height, clipped.end.y - y))
			var total = Color(0, 0, 0, 0)
			for py in range(cell.position.y, cell.end.y):
				for px in range(cell.position.x, cell.end.x):
					total += original.get_pixel(px, py)
			image.fill_rect(cell, total / float(cell.size.x * cell.size.y))


func blend_blt(
	x: int, y: int, source: Image, rect: Rect2i, blend_type: int = 0, opacity: int = 255
) -> void:
	if source == null or source.is_empty() or opacity <= 0 or blend_type < 0 or blend_type > 2:
		return
	var src = source.duplicate()
	var clipped = rect.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	for py in range(clipped.position.y, clipped.end.y):
		for px in range(clipped.position.x, clipped.end.x):
			var point = Vector2i(x, y) + Vector2i(px, py) - rect.position
			if (
				point.x < 0
				or point.y < 0
				or point.x >= image.get_width()
				or point.y >= image.get_height()
			):
				continue
			var color = src.get_pixel(px, py)
			color.a *= clampi(opacity, 0, 255) / 255.0
			var old = image.get_pixelv(point)
			if blend_type == 0:
				old = old.blend(color)
			else:
				var sign = 1 if blend_type == 1 else -1
				old = Color(
					clampf(old.r + sign * color.r * color.a, 0, 1),
					clampf(old.g + sign * color.g * color.a, 0, 1),
					clampf(old.b + sign * color.b * color.a, 0, 1),
					old.a
				)
			image.set_pixelv(point, old)


func blur2(radius: int = 1) -> void:
	# Portable separable box blur replaces TKTK's opaque DLL export. Source
	# caller radii/timing remain unchanged; no native memory pointer is exposed.
	radius = clampi(radius, 0, 64)
	if radius == 0:
		return
	var width = image.get_width()
	var height = image.get_height()
	var source = image.get_data()
	var work = source.duplicate()
	var target = source.duplicate()
	var divisor = radius * 2 + 1
	for y in height:
		var sums = [0, 0, 0, 0]
		for x in range(-radius, radius + 1):
			var offset = (clampi(x, 0, width - 1) + y * width) * 4
			for channel in 4:
				sums[channel] += source[offset + channel]
		for x in width:
			for channel in 4:
				work[(x + y * width) * 4 + channel] = int(sums[channel] / divisor)
			var removed = (clampi(x - radius, 0, width - 1) + y * width) * 4
			var added = (clampi(x + radius + 1, 0, width - 1) + y * width) * 4
			for channel in 4:
				sums[channel] += source[added + channel] - source[removed + channel]
	for x in width:
		var sums = [0, 0, 0, 0]
		for y in range(-radius, radius + 1):
			var offset = (x + clampi(y, 0, height - 1) * width) * 4
			for channel in 4:
				sums[channel] += work[offset + channel]
		for y in height:
			for channel in 4:
				target[(x + y * width) * 4 + channel] = int(sums[channel] / divisor)
			var removed = (x + clampi(y - radius, 0, height - 1) * width) * 4
			var added = (x + clampi(y + radius + 1, 0, height - 1) * width) * 4
			for channel in 4:
				sums[channel] += work[added + channel] - work[removed + channel]
	image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, target)


func get_pixel_data() -> PackedByteArray:
	var bytes = image.get_data()
	for i in range(0, bytes.size(), 4):
		var red = bytes[i]
		bytes[i] = bytes[i + 2]
		bytes[i + 2] = red
	return bytes


func set_pixel_data(value: PackedByteArray) -> Dictionary:
	if value.size() != image.get_width() * image.get_height() * 4:
		return {"ok": false, "message": "像素数据长度必须与位图BGRA尺寸一致。"}
	var bytes = value.duplicate()
	for i in range(0, bytes.size(), 4):
		var blue = bytes[i]
		bytes[i] = bytes[i + 2]
		bytes[i + 2] = blue
	image = Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes
	)
	return {"ok": true}


func png_save(path: String, _level: int = 9, _filter: int = 0) -> Dictionary:
	var normalized = path.replace("\\", "/")
	if (
		not normalized.begins_with("user://")
		or normalized.trim_prefix("user://").contains(":")
		or normalized.trim_prefix("user://").split("/").has("..")
	):
		return {"ok": false, "message": "图像保存路径必须位于user://。"}
	var status = image.save_png(normalized)
	return {"ok": status == OK, "message": "" if status == OK else error_string(status)}


func draw_rhombus(points: Array, colors: Array) -> void:
	if points.size() < 4 or colors.is_empty():
		return
	for i in 4:
		draw_line2(
			Vector2i(points[i]),
			Vector2i(points[(i + 1) % points.size()]),
			1,
			[colors[i % colors.size()]]
		)


func fill_ellipse(center: Vector2i, width: int, height: int, color: Color) -> void:
	for i in 181:
		var x = center.x + width / 2.0 * cos(i * PI / 180)
		var y = center.y + height / 2.0 * sin(i * PI / 180)
		fill_rect(Rect2i(int(x), int(2 * center.y - y), 1, int(2 * (y - center.y))), color)


func draw_ellipse_border(center: Vector2i, radius: int, type: int, color: Color) -> void:
	if not type in [0, 1, 2, 3] or radius < 0:
		return
	var starts = [90, 180, 270, 0]
	for i in range(starts[type], starts[type] + 90):
		var x = center.x + radius * cos(i * PI / 180)
		var y = center.y + radius * sin(i * PI / 180)
		if type == 0:
			set_pixel(int(x), int(y + (0 if i == 90 else 1)), color)
		elif type == 1:
			set_pixel(int(x), int(y), color)
		elif type == 2:
			set_pixel(int(x + 1), int(y), color)
		else:
			set_pixel(int(x + (0 if i == 0 else 1)), int(y + 1), color)


func draw_rounded_border(center: Rect2i, radius: int, color: Color) -> void:
	draw_line2(
		center.position - Vector2i(0, radius),
		center.position + Vector2i(center.size.x, -radius),
		1,
		[color]
	)
	draw_line2(
		center.position + Vector2i(0, center.size.y + radius),
		center.end + Vector2i(0, radius),
		1,
		[color]
	)
	draw_line2(
		center.position - Vector2i(radius, 0),
		center.position + Vector2i(-radius, center.size.y),
		1,
		[color]
	)
	draw_line2(
		center.position + Vector2i(center.size.x + radius, 0),
		center.end + Vector2i(radius, 0),
		1,
		[color]
	)
	for i in 4:
		draw_ellipse_border(
			(
				center.position
				+ Vector2i(center.size.x if i % 2 == 1 else 0, center.size.y if i > 1 else 0)
			),
			radius,
			[1, 2, 0, 3][i],
			color
		)


func fill_rounded_rect(rect: Rect2i, radius: int, color: Color) -> void:
	if not rect.has_area():
		return
	radius = clampi(radius, 0, int(mini(rect.size.x, rect.size.y) / 2))
	for row in rect.size.y:
		var distance = (
			radius - row - 0.5
			if row < radius
			else row - (rect.size.y - radius) + 0.5 if row >= rect.size.y - radius else 0.0
		)
		var inset = (
			radius - int(ceil(sqrt(maxf(0, radius * radius - distance * distance))))
			if distance > 0
			else 0
		)
		fill_rect(
			Rect2i(rect.position + Vector2i(inset, row), Vector2i(rect.size.x - inset * 2, 1)),
			color
		)


func gradient(rect: Rect2i, first: Color, last: Color, vertical: bool = false) -> void:
	var count = rect.size.y if vertical else rect.size.x
	for i in maxi(count, 0):
		var color = first.lerp(last, float(i) / maxi(1, count - 1))
		fill_rect(
			Rect2i(
				rect.position + Vector2i(0, i) if vertical else rect.position + Vector2i(i, 0),
				Vector2i(rect.size.x, 1) if vertical else Vector2i(1, rect.size.y)
			),
			color
		)


func gradation_rect(rect: Rect2i, first: Color, last: Color, align: int = 0) -> void:
	if align == 0 and rect.size.x < 0:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
		var color = first
		first = last
		last = color
	elif align != 0 and rect.size.y < 0:
		rect.position.y += rect.size.y
		rect.size.y = -rect.size.y
		var color = first
		first = last
		last = color
	gradient(rect, first, last, align != 0)


func gradate_line(
	rect: Rect2i, colors: Array, indent: Vector2i = Vector2i.ZERO, vertical: bool = false
) -> void:
	if colors.size() < 2 or not rect.has_area():
		return
	var length = rect.size.y if vertical else rect.size.x
	var first = clampi(indent.x, 0, length)
	var last = clampi(indent.y, 0, length - first)
	var middle = length - first - last
	fill_rect(
		Rect2i(
			rect.position,
			Vector2i(rect.size.x, first) if vertical else Vector2i(first, rect.size.y)
		),
		colors[0]
	)
	for i in middle:
		fill_rect(
			Rect2i(
				(
					rect.position + Vector2i(0, first + i)
					if vertical
					else rect.position + Vector2i(first + i, 0)
				),
				Vector2i(rect.size.x, 1) if vertical else Vector2i(1, rect.size.y)
			),
			colors[0].lerp(colors[1], float(i) / middle)
		)
	fill_rect(
		Rect2i(
			(
				rect.position + Vector2i(0, length - last)
				if vertical
				else rect.position + Vector2i(length - last, 0)
			),
			Vector2i(rect.size.x, last) if vertical else Vector2i(last, rect.size.y)
		),
		colors[1]
	)


func gradate_rect(rect: Rect2i, colors: Array) -> void:
	if colors.size() < 4 or not rect.has_area():
		return
	for y in rect.size.y:
		for x in rect.size.x:
			var top: Color = colors[0].lerp(colors[1], float(x) / rect.size.x)
			var bottom: Color = colors[2].lerp(colors[3], float(x) / rect.size.x)
			set_pixel(
				rect.position.x + x, rect.position.y + y, top.lerp(bottom, float(y) / rect.size.y)
			)


func draw_line(
	first: int,
	second: int,
	third: int,
	fourth: int,
	coordinate: int,
	type: int = 0,
	opacity: int = 255
) -> void:
	var colors = preload("Palette.gd").color_type(8 if type == 15 else int(type / 2), opacity)
	if colors.is_empty():
		return
	var points = [first, second, third, fourth]
	for i in 3:
		gradation_rect(
			(
				Rect2i(points[i], coordinate, points[i + 1] - points[i], 1)
				if type % 2 == 0 or type == 15
				else Rect2i(coordinate, points[i], 1, points[i + 1] - points[i])
			),
			colors[i],
			colors[i + 1],
			0 if type % 2 == 0 or type == 15 else 1
		)


func draw_line2(first: Vector2i, last: Vector2i, width: int, colors: Array) -> void:
	if colors.is_empty():
		return
	width = maxi(width, 1)
	var dx = absi(last.x - first.x)
	var dy = absi(last.y - first.y)
	var steps = maxi(dx, dy)
	var direction = Vector2i(1 if last.x > first.x else -1, 1 if last.y > first.y else -1)
	var point = first
	var error = dx - dy
	var d = 0 if width == 1 else int(width / 2) - 1
	for i in steps + 1:
		var rate = float(i) / maxi(1, steps) * (colors.size() - 1)
		var cell = mini(int(rate), colors.size() - 1)
		var color: Color = colors[cell].lerp(colors[mini(cell + 1, colors.size() - 1)], rate - cell)
		fill_rect(
			Rect2i(
				point - Vector2i(0, d) if dx > dy else point - Vector2i(d, 0),
				Vector2i(1, width) if dx > dy else Vector2i(width, 1)
			),
			color
		)
		var doubled = error * 2
		if doubled > -dy:
			error -= dy
			point.x += direction.x
		if doubled < dx:
			error += dx
			point.y += direction.y


func draw_h8_panel_fill(rect: Rect2i) -> void:
	for i in 15:
		fill_rect(
			Rect2i(rect.position + Vector2i(i, i), rect.size - Vector2i(i * 2, i * 2)),
			Color8(0, 16, 32, mini(150, 18 + i * 8))
		)
	if rect.size.x > 8 and rect.size.y > 8:
		fill_rect(
			Rect2i(rect.position + Vector2i(2, 2), Vector2i(rect.size.x - 4, 1)),
			Color8(72, 220, 255, 18)
		)
		fill_rect(
			Rect2i(rect.position + Vector2i(2, rect.size.y - 3), Vector2i(rect.size.x - 4, 1)),
			Color8(0, 8, 16, 64)
		)


func draw_h8_background(rect: Rect2i, opacity: int = 160, margin: int = 16) -> void:
	draw_h8_panel_fill(rect)
	margin = clampi(margin, 0, maxi(0, int((mini(rect.size.x, rect.size.y) - 6) / 2)))
	draw_h8_outer_frame(
		Rect2i(
			rect.position + Vector2i(margin, margin), rect.size - Vector2i(margin * 2, margin * 2)
		),
		opacity
	)


func draw_h8_outer_frame(rect: Rect2i, opacity: int = 132) -> void:
	if rect.size.x < 6 or rect.size.y < 6:
		return
	var weak = Color8(122, 222, 255, clampi(int(opacity * 3 / 5), 0, 255))
	var line = Color8(160, 232, 255, clampi(opacity + 20, 0, 255))
	var bright = Color8(224, 248, 255, clampi(opacity + 68, 0, 255))
	var haze = Color8(128, 225, 255, 12)
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	for ends in [
		[Vector2i(x + 2, y), Vector2i(x + w - 3, y)],
		[Vector2i(x + 2, y + h - 1), Vector2i(x + w - 3, y + h - 1)],
		[Vector2i(x, y + 2), Vector2i(x, y + h - 3)],
		[Vector2i(x + w - 1, y + 2), Vector2i(x + w - 1, y + h - 3)]
	]:
		_split_line(ends[0], ends[1], [weak, haze, weak])
	for ends in [
		[Vector2i(x + 2, y + 1), Vector2i(x + w - 3, y + 1)],
		[Vector2i(x + 2, y + h - 2), Vector2i(x + w - 3, y + h - 2)],
		[Vector2i(x + 1, y + 2), Vector2i(x + 1, y + h - 3)],
		[Vector2i(x + w - 2, y + 2), Vector2i(x + w - 2, y + h - 3)]
	]:
		_split_line(ends[0], ends[1], [bright, line, line, bright])
	for corner in [
		[Vector2i(x + 1, y + 1), Vector2i(1, 1)],
		[Vector2i(x + w - 2, y + 1), Vector2i(-1, 1)],
		[Vector2i(x + 1, y + h - 2), Vector2i(1, -1)],
		[Vector2i(x + w - 2, y + h - 2), Vector2i(-1, -1)]
	]:
		draw_h8_corner_light(corner[0], corner[1], opacity)


func draw_h8_corner_light(point: Vector2i, direction: Vector2i, opacity: int = 132) -> void:
	var bright = Color8(150, 255, 225, clampi(opacity + 95, 0, 255))
	var line = Color8(78, 255, 215, clampi(opacity + 60, 0, 255))
	fill_rect(Rect2i(point - Vector2i.ONE, Vector2i(3, 3)), bright)
	draw_line2(point, point + Vector2i(direction.x * 13, 0), 1, [bright, line])
	draw_line2(point, point + Vector2i(0, direction.y * 13), 1, [bright, line])


func draw_h8_inner_line(
	first: Vector2i, last: Vector2i, type: int = 0, opacity: int = 132, width: int = 1
) -> void:
	var fade = Color8(148, 242, 255, 0)
	var weak = Color8(122, 234, 255, clampi(int(opacity / 2), 0, 255))
	var line = Color8(138, 238, 255, clampi(opacity, 0, 255))
	var bright = Color8(232, 255, 255, clampi(opacity + 56, 0, 255))
	if type == 2:
		var length = Vector2(last - first).length()
		if length <= 0:
			return
		var gap = maxi(1, int(length / 4)) if 14 >= length else 7
		var middle = (Vector2(first) + Vector2(last)) / 2
		var offset = Vector2(last - first) * gap / length
		draw_line2(first, Vector2i(middle - offset), width, [fade, line])
		draw_line2(Vector2i(middle + offset), last, width, [line, fade])
		return
	var colors = (
		[fade, weak, bright, weak, fade]
		if type == 1
		else (
			[line, bright, line]
			if type == 4
			else [fade, weak, line, weak, fade] if type == 3 else [fade, line, fade]
		)
	)
	_split_line(first, last, colors, width)
	if type == 3:
		var center = Vector2i((first + last) / 2)
		var r = maxi(1, width) + 1
		fill_rect(Rect2i(center - Vector2i(r, 0), Vector2i(r * 2 + 1, 1)), bright)
		fill_rect(Rect2i(center - Vector2i(0, r), Vector2i(1, r * 2 + 1)), bright)


func draw_h8_bulge(first: Vector2i, last: Vector2i, plus: bool, height: int, type: int) -> void:
	if (
		height <= 0
		or type not in [0, 1]
		or (type == 0 and first.y != last.y)
		or (type == 1 and first.x != last.x)
	):
		return
	var start = mini(first.x, last.x) if type == 0 else mini(first.y, last.y)
	var finish = maxi(first.x, last.x) if type == 0 else maxi(first.y, last.y)
	if finish - start <= height * 2:
		return
	var direction = 1 if plus else -1
	var base = first.y if type == 0 else first.x
	for i in height + 1:
		fill_rect(
			(
				Rect2i(start + i, base + direction * i, finish - start - i * 2 + 1, 1)
				if type == 0
				else Rect2i(base + direction * i, start + i, 1, finish - start - i * 2 + 1)
			),
			Color8(0, 16, 32, 160)
		)
	fill_rect(
		(
			Rect2i(start, base, finish - start + 1, 1)
			if type == 0
			else Rect2i(base, start, 1, finish - start + 1)
		),
		Color8(0, 16, 32, 255)
	)
	var points = [
		Vector2i(start, base),
		Vector2i(start + height, base + direction * height),
		Vector2i(finish - height, base + direction * height),
		Vector2i(finish, base)
	]
	if type == 1:
		points = points.map(func(p): return Vector2i(p.y, p.x))
	var weak = Color8(122, 222, 255, 79)
	var line = Color8(160, 232, 255, 152)
	var bright = Color8(224, 248, 255, 200)
	draw_line2(points[0], points[1], 1, [weak, line])
	_split_line(points[1], points[2], [line, bright, line])
	draw_line2(points[2], points[3], 1, [line, weak])


static func skill_frame_colors(type: int) -> Array:
	return (
		[
			Color8(255, 196, 116, 0),
			Color8(255, 196, 116, 178),
			Color8(255, 238, 194, 230),
			Color8(224, 104, 72, 112)
		]
		if type == 2
		else (
			[
				Color8(128, 240, 176, 0),
				Color8(128, 240, 176, 178),
				Color8(224, 255, 232, 230),
				Color8(48, 180, 96, 112)
			]
			if type == 3
			else [
				Color8(132, 224, 255, 0),
				Color8(132, 224, 255, 178),
				Color8(232, 255, 255, 230),
				Color8(48, 156, 216, 112)
			]
		)
	)


func draw_skill_frame(
	rect: Rect2i, type: int = 1, show_turn_box: bool = false, corners: bool = true
) -> void:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if not rect.has_area():
		return
	var colors = skill_frame_colors(type)
	for i in 6:
		fill_rect(
			Rect2i(rect.position + Vector2i(i, i), rect.size - Vector2i(i * 2, i * 2)),
			Color8(0, 12, 24, mini(104, 22 + i * 14))
		)
	if rect.size.x > 10 and rect.size.y > 10:
		fill_rect(
			Rect2i(rect.position + Vector2i(4, 4), rect.size - Vector2i(8, 8)),
			Color8(24, 42, 58, 56)
		)
	if rect.size.x > 12 and rect.size.y > 12:
		fill_rect(
			Rect2i(rect.position + Vector2i(6, 6), rect.size - Vector2i(12, 12)),
			Color8(0, 8, 16, 52)
		)
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	if w > 6:
		fill_rect(Rect2i(x + 3, y + 2, w - 6, 1), Color8(255, 255, 255, 26))
		fill_rect(Rect2i(x + 3, y + h - 3, w - 6, 1), Color8(0, 0, 0, 82))
	if w > 12:
		_split_line(
			Vector2i(x + 5, y + 1), Vector2i(x + w - 6, y + 1), [colors[0], colors[1], colors[0]]
		)
		_split_line(
			Vector2i(x + 5, y + h - 2),
			Vector2i(x + w - 6, y + h - 2),
			[colors[0], colors[3], colors[0]]
		)
	if h > 12:
		_split_line(
			Vector2i(x + 1, y + 5), Vector2i(x + 1, y + h - 6), [colors[0], colors[1], colors[0]]
		)
		_split_line(
			Vector2i(x + w - 2, y + 5),
			Vector2i(x + w - 2, y + h - 6),
			[colors[0], colors[3], colors[0]]
		)
	if corners:
		_frame_corners(rect, type, colors)
	if show_turn_box:
		draw_turn_box(
			Rect2i(
				x + w,
				y + h - int(round(mini(w, h) * 0.4)),
				int(round(mini(w, h) * 0.4)),
				int(round(mini(w, h) * 0.4))
			),
			colors
		)


func draw_turn_box(rect: Rect2i, colors: Array) -> void:
	if rect.size.x < 5:
		return
	fill_rect(rect, Color8(0, 6, 12, 238))
	fill_rect(
		Rect2i(rect.position + Vector2i(2, 2), rect.size - Vector2i(4, 4)), Color8(0, 10, 20, 252)
	)
	draw_line2(rect.position, rect.position + Vector2i(rect.size.x - 1, 0), 1, [colors[2]])
	draw_line2(rect.position, rect.position + Vector2i(0, rect.size.y - 1), 1, [colors[2]])
	draw_line2(
		rect.position + Vector2i(rect.size.x - 1, 0),
		rect.end - Vector2i.ONE,
		1,
		[Color8(238, 255, 255, 220)]
	)
	draw_line2(
		rect.position + Vector2i(0, rect.size.y - 1),
		rect.end - Vector2i.ONE,
		1,
		[Color8(238, 255, 255, 220)]
	)


func draw_item_frame(rect: Rect2i, corners: bool = true) -> void:
	fill_rect(rect, Color8(2, 7, 20, 216))
	fill_rect(
		Rect2i(rect.position + Vector2i(2, 2), rect.size - Vector2i(4, 4)), Color8(5, 14, 28, 144)
	)
	fill_rect(
		Rect2i(rect.position + Vector2i(4, 4), rect.size - Vector2i(8, 8)), Color8(2, 6, 14, 96)
	)
	if rect.size.x > 10:
		fill_rect(
			Rect2i(rect.position + Vector2i(5, 3), Vector2i(rect.size.x - 10, 1)),
			Color8(188, 220, 244, 28)
		)
	if corners:
		_frame_corners(
			rect,
			4,
			[
				Color8(128, 240, 255, 0),
				Color8(56, 208, 232, 180),
				Color8(224, 255, 255, 230),
				Color8(16, 136, 176, 112)
			]
		)


func draw_hud_back(rect: Rect2i, type: int = 0) -> void:
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	if type == 1:
		for i in h:
			fill_rect(Rect2i(x + 2, y + 2 + i, w + h - i, 1), Color.BLACK)
			set_pixel(x + 2 + w + h - i - 1, y + 2 + i, Color.WHITE)
		fill_rect(Rect2i(x + 2, y + 2 + h, w, 1), Color.WHITE)
	else:
		fill_rect(Rect2i(x - 1, y - 1, w + 2, h + 2), Color.WHITE)
		fill_rect(rect, Color.BLACK)


func draw_hud_line(
	rect: Rect2i, value: int, maximum: int, first: Color, last: Color, type: int = 0
) -> void:
	if rect.size.x <= 0:
		return
	var length = int(rect.size.x * float(clampi(value, 0, maxi(1, maximum))) / maxi(1, maximum))
	for row in rect.size.y:
		for column in length + (rect.size.y - row if type == 1 else 0):
			var color = first.lerp(last, float(column) / rect.size.x)
			color.a = clampf(color.a - row * 24.0 / 255, 0, 1)
			set_pixel(rect.position.x + column, rect.position.y + row, color)


func draw_trapezoid_meter(
	rect: Rect2i, value: int, maximum: int, first: Color, last: Color
) -> void:
	if rect.size.x <= rect.size.y * 2 or rect.size.y <= 0:
		return
	var filled = int(rect.size.x * float(clampi(value, 0, maxi(1, maximum))) / maxi(1, maximum))
	if filled <= 0:
		return
	for column in filled + 1:
		var top = (
			rect.position.y
			+ maxi(0, maxi(rect.size.y - column, column - (rect.size.x - rect.size.y)))
		)
		fill_rect(
			Rect2i(rect.position.x + column, top, 1, rect.end.y - top + 1),
			first.lerp(last, float(column) / rect.size.x)
		)


func _split_line(first: Vector2i, last: Vector2i, colors: Array, width: int = 1) -> void:
	for i in colors.size() - 1:
		var start = Vector2i(Vector2(first).lerp(Vector2(last), float(i) / (colors.size() - 1)))
		var end = Vector2i(Vector2(first).lerp(Vector2(last), float(i + 1) / (colors.size() - 1)))
		draw_line2(start, end, width, [colors[i], colors[i + 1]])


func _frame_corners(rect: Rect2i, type: int, colors: Array) -> void:
	var source = (
		Cache.windowskin("FrameM_0%d" % type) if rect.size.x >= 12 and rect.size.y >= 12 else null
	)
	if source != null:
		var original = source.get_image()
		for part in [
			[Rect2i(0, 0, 9, 8), rect.position],
			[Rect2i(9, 0, 9, 8), rect.position + Vector2i(rect.size.x - 9, 0)],
			[Rect2i(0, 8, 9, 8), rect.position + Vector2i(0, rect.size.y - 8)],
			[Rect2i(9, 8, 9, 8), rect.end - Vector2i(9, 8)]
		]:
			image.blend_rect(original, part[0], part[1])
	elif rect.size.x >= 6 and rect.size.y >= 6:
		var corner = clampi(int(mini(rect.size.x, rect.size.y) / 3), 4, 10)
		for part in [
			[rect.position + Vector2i(2, 2), Vector2i(1, 1)],
			[rect.position + Vector2i(rect.size.x - 3, 2), Vector2i(-1, 1)],
			[rect.position + Vector2i(2, rect.size.y - 3), Vector2i(1, -1)],
			[rect.end - Vector2i(3, 3), Vector2i(-1, -1)]
		]:
			draw_line2(
				part[0], part[0] + Vector2i(part[1].x * (corner - 2), 0), 2, [colors[2], colors[1]]
			)
			draw_line2(
				part[0], part[0] + Vector2i(0, part[1].y * (corner - 2)), 2, [colors[2], colors[1]]
			)


static func panel_style(size: Vector2i, margin: int = 16) -> StyleBoxTexture:
	var key = str(size) + ":" + str(margin)
	if not _panel_cache.has(key):
		var bitmap = load("res://runtime/scripts/04_UI_Common/Bitmap.gd").new(size.x, size.y)
		bitmap.draw_h8_background(Rect2i(Vector2i.ZERO, size), 160, margin)
		var style = StyleBoxTexture.new()
		style.texture = bitmap.texture()
		_panel_cache[key] = style
		_panel_order.append(key)
		if _panel_order.size() > 64:
			_panel_cache.erase(_panel_order.pop_front())
	else:
		_panel_order.erase(key)
		_panel_order.append(key)
	return _panel_cache[key]


static func skill_style(size: Vector2i, type: int = 1, corners: bool = true) -> StyleBoxTexture:
	var key = "skill:" + str(size) + ":" + str(type) + ":" + str(corners)
	if not _panel_cache.has(key):
		var bitmap = load("res://runtime/scripts/04_UI_Common/Bitmap.gd").new(size.x, size.y)
		bitmap.draw_skill_frame(Rect2i(Vector2i.ZERO, size), type, false, corners)
		var style = StyleBoxTexture.new()
		style.texture = bitmap.texture()
		_panel_cache[key] = style
		_panel_order.append(key)
		if _panel_order.size() > 64:
			_panel_cache.erase(_panel_order.pop_front())
	else:
		_panel_order.erase(key)
		_panel_order.append(key)
	return _panel_cache[key]

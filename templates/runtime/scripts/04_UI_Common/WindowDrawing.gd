## 职责：按原Window_Base绘制渐变面板、完整行文字和四角光标；有界缓存只保存静态图形。
##
## 调用方式：
##   由原图页面的_draw回调调用静态方法；面板缓存最多32种尺寸，调用方拥有输入和时钟。
##   text保留字号高度，将过宽行按RM draw_text水平适配；每次绘制后恢复单位变换，rect为目标节点本地坐标。
##
## 调用接口：
##   static func panel(size: Vector2i) -> Texture2D
##     用途：生成或复用0111原四色线框及17层深色渐变面板。
##     参数 size（Vector2i；必填）：对象、画布或区域尺寸。
##     返回：只读面板纹理；调用方只调整绘制位置与透明度。
##
##   static func text( target: CanvasItem, font: Font, rect: Rect2, value: String, font_size: int = 18, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, shadow: bool = true ) -> void
##     用途：按真实字体宽度绘制一行及原阴影，避免方法尾字或数值被截断。
##     参数 target（CanvasItem；必填）：操作或效果作用的目标。
##     参数 font（Font；必填）：当前页面通过UIResources.font取得的正式字体。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 font_size（int；默认值 18）：字号，单位为逻辑像素。
##     参数 color（Color；默认值 Color.WHITE）：绘制或效果使用的颜色。
##     参数 align（int；默认值 HORIZONTAL_ALIGNMENT_LEFT）：文本或元素的对齐方式。
##     参数 shadow（bool；默认值 true）：阴影颜色或阴影选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func cursor( target: CanvasItem, rect: Rect2, type: int = 3, inset: Vector2 = Vector2.ZERO, opacity: float = 1.0 ) -> void
##     用途：用原FrameM图片的四个9×8角分别绘制独立光标。
##     参数 target（CanvasItem；必填）：操作或效果作用的目标。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 type（int；默认值 3）：FrameM_01—03皮肤编号；档案为3、普通选择为1。
##     参数 inset（Vector2；默认值 Vector2.ZERO）：四角光标在矩形内的横纵缩进，单位像素。
##     参数 opacity（float；默认值 1.0）：0—1透明度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## 0111的四色渐变窗口和FrameM四角光标；只缓存静态纹理，不保存游戏现场。
const Bitmap = preload("Bitmap.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
static var _panels: Dictionary = {}
static var _order: Array[String] = []


static func panel(size: Vector2i) -> Texture2D:
	var key = str(size)
	if not _panels.has(key):
		var bitmap = Bitmap.new(size.x, size.y)
		for inset in 17:
			bitmap.fill_rect(
				Rect2i(inset, inset, size.x - 2 * inset, size.y - 2 * inset),
				Color8(0, 16, 32, 6 if inset == 0 else 12 * inset)
			)
		bitmap.draw_line(0, 16, int(size.x / 5), int(size.x * 2 / 3), 16, 22)
		bitmap.draw_line(0, 16, int(size.y / 5), int(size.y * 2 / 3), 16, 13)
		bitmap.draw_line(size.x, size.x - 16, int(size.x * 4 / 5), int(size.x / 3), size.y - 16, 10)
		bitmap.draw_line(size.y, size.y - 16, int(size.y * 4 / 5), int(size.y / 3), size.x - 16, 7)
		_panels[key] = bitmap.texture()
	_order.erase(key)
	_order.append(key)
	while _order.size() > 32:
		_panels.erase(_order.pop_front())
	return _panels[key]


static func text(
	target: CanvasItem,
	font: Font,
	rect: Rect2,
	value: String,
	font_size: int = 18,
	color: Color = Color.WHITE,
	align: int = HORIZONTAL_ALIGNMENT_LEFT,
	shadow: bool = true
) -> void:
	# RGSS draw_text会水平压缩过宽的一行；Godot的width参数会裁字，因此先按真实字体宽度适配。
	var measured = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var scale_x = minf(1, rect.size.x / maxf(1, measured))
	var shift = (
		(rect.size.x - measured * scale_x) / 2
		if align == HORIZONTAL_ALIGNMENT_CENTER
		else rect.size.x - measured * scale_x if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0
	)
	var baseline = Vector2(
		0, (rect.size.y - font.get_height(font_size)) / 2 + font.get_ascent(font_size)
	)
	target.draw_set_transform(rect.position + Vector2(shift, 0), 0, Vector2(scale_x, 1))
	if shadow:
		target.draw_string(
			font,
			baseline + Vector2.ONE,
			value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.05, 0.08, 0.12, color.a * 0.75)
		)
	target.draw_string(font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	target.draw_set_transform(Vector2.ZERO)


static func cursor(
	target: CanvasItem,
	rect: Rect2,
	type: int = 3,
	inset: Vector2 = Vector2.ZERO,
	opacity: float = 1.0
) -> void:
	var texture = Cache.windowskin("FrameM_0%d" % type)
	if texture == null:
		return
	for x in 2:
		for y in 2:
			var point = (
				rect.position
				+ Vector2(
					inset.x if x == 0 else rect.size.x - 2 - inset.x - 9,
					inset.y if y == 0 else rect.size.y - 2 - inset.y - 8
				)
			)
			target.draw_texture_rect_region(
				texture,
				Rect2(point, Vector2(9, 8)),
				Rect2(x * 9, y * 8, 9, 8),
				Color(1, 1, 1, opacity)
			)

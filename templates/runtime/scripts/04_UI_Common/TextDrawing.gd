## 职责：绘制闪翼界面文本，处理字体、颜色、对齐与文本尺寸。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/04_UI_Common/TextDrawing.gd").方法名(...)。
##
## 调用接口：
##   static func draw_text( target: CanvasItem, rect: Rect2, value: String, style: Dictionary, align: int = 0, shadow: bool = false ) -> void
##     参数 target（CanvasItem；必填）：操作或效果作用的目标。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 style（Dictionary；必填）：显示或绘制样式。
##     参数 align（int；默认值 0）：文本或元素的对齐方式。
##     参数 shadow（bool；默认值 false）：阴影颜色或阴影选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func draw_text_border( target: CanvasItem, rect: Rect2, value: String, style: Dictionary, align: int = 0 ) -> void
##     参数 target（CanvasItem；必填）：操作或效果作用的目标。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 style（Dictionary；必填）：显示或绘制样式。
##     参数 align（int；默认值 0）：文本或元素的对齐方式。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func draw_delete_line_text( target: CanvasItem, rect: Rect2, value: String, style: Dictionary, align: int = 0, shadow: bool = false ) -> void
##     参数 target（CanvasItem；必填）：操作或效果作用的目标。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 style（Dictionary；必填）：显示或绘制样式。
##     参数 align（int；默认值 0）：文本或元素的对齐方式。
##     参数 shadow（bool；默认值 false）：阴影颜色或阴影选项。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func draw_rich_text( target: CanvasItem, rect: Rect2, raw: String, owner: Object, align: int = 0, memory: bool = false ) -> Dictionary
##     参数 target（CanvasItem；必填）：操作或效果作用的目标。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 raw（String；必填）：尚未解释的原始值或文本。
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 align（int；默认值 0）：文本或元素的对齐方式。
##     参数 memory（bool；默认值 false）：消息历史记录或当前历史数据。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted
## 0023 text drawing moves to CanvasItem; callers invoke from _draw(), keeping
## native fonts and owned canvas state rather than rasterizing shared textures.
const Text = preload("../06_Message/MessageText.gd")
const Palette = preload("Palette.gd")
const TextLayout = preload("UITextLayout.gd")


static func draw_text(
	target: CanvasItem,
	rect: Rect2,
	value: String,
	style: Dictionary,
	align: int = 0,
	shadow: bool = false
) -> void:
	var font = Text.font(style)
	var font_size = int(style.font_size)
	var measured = TextLayout.measure(value, style)
	var x = (
		rect.position.x + (rect.size.x - measured.x) / 2
		if align == 1
		else rect.end.x - measured.x if align == 2 else rect.position.x
	)
	var baseline = Vector2(
		x, rect.position.y + (rect.size.y - measured.y) / 2 + font.get_ascent(font_size)
	)
	var color = Text.color(int(style.get("color", -1)))
	color.a *= clampf(float(style.get("opacity", 255)) / 255, 0, 1)
	if shadow:
		var dark = (color.r + color.g + color.b) * 255 < 384
		var shade = (
			Color(128.0 / 255, 128.0 / 255, 128.0 / 255, color.a * 0.75)
			if dark
			else Color(32.0 / 255, 32.0 / 255, 32.0 / 255, color.a * 0.75)
		)
		target.draw_string(
			font,
			baseline + Vector2.ONE,
			value,
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x,
			font_size,
			shade
		)
	target.draw_string(
		font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, color
	)


static func draw_text_border(
	target: CanvasItem, rect: Rect2, value: String, style: Dictionary, align: int = 0
) -> void:
	for offset in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		draw_text(target, Rect2(rect.position + offset, rect.size), value, style, align)


static func draw_delete_line_text(
	target: CanvasItem,
	rect: Rect2,
	value: String,
	style: Dictionary,
	align: int = 0,
	shadow: bool = false
) -> void:
	# Original Ruby1/3 is integer zero, so its two strokes are y+8/y+16.
	for offset in [8, 16]:
		target.draw_line(
			Vector2(8, rect.position.y + offset),
			Vector2(rect.size.x - 24, rect.position.y + offset),
			Palette.color(17)
		)
	draw_text(target, rect, value, style, align, shadow)


static func draw_rich_text(
	target: CanvasItem,
	rect: Rect2,
	raw: String,
	owner: Object,
	align: int = 0,
	memory: bool = false
) -> Dictionary:
	var row = load("res://runtime/scripts/06_Message/TextRow.gd").new(raw, owner)
	if not row.failure.is_empty():
		return {"ok": false, "message": row.failure}
	var style = Text.defaults()
	var x = rect.position.x
	for token in row.tokens:
		if token is Array:
			if token[0].unicode_at(0) in [1, 20, 21, 23, 25, 26]:
				Text.apply_style(style, token)
				if memory and style.color == 8:
					style.color = 0
				if memory and token[0].unicode_at(0) == 21:
					style.font_size = maxi(1, style.font_size - 2)
			continue  # Source ignores other rich-text controls in this renderer.
		var measured = TextLayout.measure(token, style)
		var dy = (row.text_height - measured.y) / 2 if row.valign == 2 else 0
		draw_text(
			target, Rect2(x, rect.position.y + dy, measured.x, measured.y), token, style, align
		)
		x += measured.x
	return {"ok": true, "width": x - rect.position.x}

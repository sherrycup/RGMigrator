## 职责：共用字体缓存与真实字体度量，使用原生文字塑形按可用宽高换行和分页。
##
## 调用方式：
##   字体按字体列表、粗体及斜体共享，只读复用；缓存最多128组。
##   layout按原生塑形结果换行，按像素高度分页；\f显式分页，换行保留；不按RM事件编辑器四行容量截断。
##   pages中的TextParagraph仅用于UI绘制，不属于可保存游戏状态；单字超过可用区域时标记overflow并交由控件裁切。
##
## 调用接口：
##   static func font(style: Dictionary) -> SystemFont
##     用途：取得同一样式的共享字体。
##     参数 style（Dictionary；必填）：字体样式：font_name或font_names、font_size、bold、italic；layout另支持align及非负line_space。
##     返回：带系统后备字体的SystemFont，不应由调用方修改。
##
##   static func measure(value: String, style: Dictionary) -> Vector2
##     用途：用实际绘制字体度量单行文本。
##     参数 value（String；必填）：待度量或排版的原始正文；行的start/end按原字符串Unicode码点编号。
##     参数 style（Dictionary；必填）：字体样式：font_name或font_names、font_size、bold、italic；layout另支持align及非负line_space。
##     返回：原生字体度量的宽高Vector2。
##
##   static func layout( value: String, style: Dictionary, maximum_width: float, maximum_height: float = INF ) -> Dictionary
##     用途：塑形文本并按可用宽高生成绘制行及页面。
##     参数 value（String；必填）：待度量或排版的原始正文；行的start/end按原字符串Unicode码点编号。
##     参数 style（Dictionary；必填）：字体样式：font_name或font_names、font_size、bold、italic；layout另支持align及非负line_space。
##     参数 maximum_width（float；必填）：可用文字宽度，必须为有限正数，单位为逻辑像素。
##     参数 maximum_height（float；默认值 INF）：每页可用高度，单位为逻辑像素；默认INF表示不限制页高。
##     返回：{ok,pages,overflow}；pages各含lines及height，行含paragraph、line、原字符串start/end和y/width/height；无效宽高返回ok=false和message。
##
## 公开常量：FONT_CACHE_LIMIT。
## 接口说明结束。

extends RefCounted

static var _fonts: Dictionary = {}
static var _font_order: Array[String] = []
const FONT_CACHE_LIMIT = 128


static func font(style: Dictionary) -> SystemFont:
	var names: Array = Array(
		style.get("font_names", [str(style.get("font_name", "楷体")), "楷体", "SimSun", "Arial"])
	)
	var key = JSON.stringify(
		[names, bool(style.get("bold", false)), bool(style.get("italic", false))]
	)
	if not _fonts.has(key):
		var result = SystemFont.new()
		result.font_names = PackedStringArray(names)
		result.allow_system_fallback = true
		result.font_weight = 700 if style.get("bold", false) else 400
		result.font_italic = bool(style.get("italic", false))
		# Legacy CJK faces can contain Latin bases but lack their combining marks.
		# An explicit fallback lets the shaper resolve the complete cluster.
		var fallback = SystemFont.new()
		fallback.font_names = PackedStringArray(["Segoe UI", "Arial"])
		fallback.allow_system_fallback = true
		fallback.font_weight = result.font_weight
		fallback.font_italic = result.font_italic
		result.fallbacks = [fallback]
		_fonts[key] = result
	else:
		_font_order.erase(key)
	_font_order.append(key)
	if _font_order.size() > FONT_CACHE_LIMIT:
		_fonts.erase(_font_order.pop_front())
	return _fonts[key]


static func measure(value: String, style: Dictionary) -> Vector2:
	return font(style).get_string_size(
		value, HORIZONTAL_ALIGNMENT_LEFT, -1, clampi(int(style.get("font_size", 20)), 1, 512)
	)


static func layout(
	value: String, style: Dictionary, maximum_width: float, maximum_height: float = INF
) -> Dictionary:
	if (
		not is_finite(maximum_width)
		or maximum_width <= 0
		or is_nan(maximum_height)
		or maximum_height <= 0
	):
		return {"ok": false, "message": "文字可用宽高必须为正数。", "pages": []}
	var pages: Array = []
	var font_size = clampi(int(style.get("font_size", 20)), 1, 512)
	var spacing = maxf(0, float(style.get("line_space", 0)))
	var overflow = false
	var offset = 0
	for section in value.split("\f", true):
		var paragraph = TextParagraph.new()
		paragraph.width = maximum_width
		paragraph.alignment = clampi(int(style.get("align", 0)), 0, 2)
		paragraph.break_flags = (
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		)
		paragraph.add_string(section, font(style), font_size)
		var page = {"lines": [], "height": 0.0}
		for index in paragraph.get_line_count():
			var height = maxf(paragraph.get_line_size(index).y, font(style).get_height(font_size))
			var gap = spacing if not page.lines.is_empty() else 0.0
			if not page.lines.is_empty() and page.height + gap + height > maximum_height:
				pages.append(page)
				page = {"lines": [], "height": 0.0}
				gap = 0.0
			var span = paragraph.get_line_range(index)
			page.lines.append(
				{
					"paragraph": paragraph,
					"line": index,
					"start": offset + span.x,
					"end": offset + span.y,
					"y": page.height + gap,
					"width": paragraph.get_line_width(index),
					"height": height
				}
			)
			page.height += gap + height
			overflow = (
				overflow
				or height > maximum_height
				or paragraph.get_line_width(index) > maximum_width + 0.01
			)
		pages.append(page)
		offset += section.length() + 1
	return {"ok": true, "pages": pages, "overflow": overflow}

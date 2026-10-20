## 职责：在自身裁切区域内绘制共用塑形文本和指定页，供标题、菜单和信息窗口使用。
##
## 调用方式：
##   设置控件position/size后configure(text,style)；窗口resize时自动重排，绘制受自身矩形裁切。
##   set_page仅切换文本显示页，不推进游戏事件或Message控制器；无自动计时。
##
## 调用接口：
##   func configure(value: String, text_style: Dictionary = {}) -> void
##     用途：设置显示正文及独立样式副本，并重新排版。
##     参数 value（String；必填）：要显示的原始正文。
##     参数 text_style（Dictionary；默认值 {}）：UITextLayout字体样式，另可用font_color设置文字颜色。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_page(index: int) -> void
##     用途：切换显示页并限制在现有页范围内。
##     参数 index（int；必填）：从0开始的显示页编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func page_count() -> int
##     用途：读取当前排版的总页数。
##     参数：无。
##     返回：页数；控件没有可用面积时为0。
##
## 对外信号：
##   page_changed(page: int, total: int)：由持有方发出，通知对应状态或操作结果。
##     page：从0开始的当前显示页编号。
##     total：当前排版总页数。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _draw() -> void
##
## 接口说明结束。

extends Control
const Layout = preload("UITextLayout.gd")
signal page_changed(page: int, total: int)
var text = ""
var style: Dictionary = {}
var page = 0
var layout_data: Dictionary = {"ok": true, "pages": []}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(_rebuild)
	_rebuild()


func configure(value: String, text_style: Dictionary = {}) -> void:
	text = value
	style = text_style.duplicate(true)
	_rebuild()


func set_page(index: int) -> void:
	var selected = clampi(index, 0, maxi(0, page_count() - 1))
	if page != selected:
		page = selected
		page_changed.emit(page, page_count())
	queue_redraw()


func page_count() -> int:
	return layout_data.pages.size()


func _rebuild() -> void:
	if size.x <= 0 or size.y <= 0:
		layout_data = {"ok": true, "pages": []}
	else:
		layout_data = Layout.layout(text, style, size.x, size.y)
	set_page(page)


func _draw() -> void:
	if not layout_data.ok or layout_data.pages.is_empty():
		return
	var color: Color = style.get("font_color", Color.WHITE)
	for line in layout_data.pages[page].lines:
		line.paragraph.draw_line(get_canvas_item(), Vector2(0, line.y), line.line, color)

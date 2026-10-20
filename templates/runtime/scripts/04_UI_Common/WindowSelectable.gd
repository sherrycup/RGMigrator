## 职责：提供可选择窗口的光标、滚动和方向输入逻辑。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/04_UI_Common/WindowSelectable.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func visible_rows() -> int
##     用途：计算当前内容区能完整显示的行数。
##     参数：无。
##     返回：至少1行，按row_height与窗口留白计算。
##
##   func item_rect(value: int) -> Rect2
##     用途：计算指定项目在当前滚动视口中的矩形。
##     参数 value（int；必填）：从0开始的项目编号；按column_count排列。
##     返回：Rect2 类型的对象或值，供调用方继续使用。
##
##   func select(value: int) -> void
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func move_selection(direction: int) -> void
##     参数 direction（int；必填）：选择或调整的方向增量；正负号按当前页面的导航逻辑处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   selection_changed(index: int)：由持有方发出，通知对应状态或操作结果。
##     index：集合或列表中的位置索引。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends "res://runtime/scripts/04_UI_Common/WindowBase.gd"
signal selection_changed(index: int)
var index := 0
var item_count := 0
var row_height := 32.0
var column_count := 1
var active := true:
	set(value):
		active = value
		if _cursor != null:
			select_rect(item_rect(index), active and item_count > 0)
var scroll_row := 0


func _ready() -> void:
	super._ready()
	resized.connect(_refresh_selection)


func visible_rows() -> int:
	return maxi(1, int(Layout.content_rect(size).size.y / maxf(1, row_height)))


func item_rect(value: int) -> Rect2:
	var columns = maxi(1, column_count)
	var width = Layout.content_rect(size).size.x / columns
	return Rect2(
		value % columns * width,
		(int(value / columns) - scroll_row) * maxf(1, row_height),
		width,
		maxf(1, row_height)
	)


func _refresh_selection() -> void:
	if _cursor != null:
		select(index)


func select(value: int) -> void:
	index = clampi(value, 0, maxi(0, item_count - 1))
	var columns = maxi(1, column_count)
	var rows = ceili(float(item_count) / columns)
	var selected_row = int(index / columns)
	scroll_row = clampi(scroll_row, 0, maxi(0, rows - visible_rows()))
	if selected_row < scroll_row:
		scroll_row = selected_row
	elif selected_row >= scroll_row + visible_rows():
		scroll_row = selected_row - visible_rows() + 1
	select_rect(item_rect(index), active and item_count > 0)
	selection_changed.emit(index)


func move_selection(direction: int) -> void:
	if item_count > 0:
		select(posmod(index + direction, item_count))

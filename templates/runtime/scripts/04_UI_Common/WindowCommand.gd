## 职责：构建命令列表窗口，维护选中项、可用状态和确认取消信号。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/04_UI_Common/WindowCommand.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func configure(entries: Array, selected: int = 0) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 entries（Array；必填）：待处理的有序条目集合。
##     参数 selected（int；默认值 0）：当前选中的条目编号或状态。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func select(value: int) -> void
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func current_enabled() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 接口说明结束。

extends "res://runtime/scripts/04_UI_Common/WindowSelectable.gd"
var commands: Array[Dictionary] = []
var _rows: Array[Label] = []


func configure(entries: Array, selected: int = 0) -> void:
	commands.assign(entries)
	item_count = commands.size()
	clear_content()
	_rows.clear()
	for i in commands.size():
		_rows.append(
			label(
				str(commands[i].text),
				Rect2(4, i * row_height, size.x - 40, row_height),
				Color.WHITE if commands[i].enabled else Color("9197a8")
			)
		)
	select(selected)


func select(value: int) -> void:
	super.select(value)
	var viewport_rect = Rect2(Vector2.ZERO, Layout.content_rect(size).size)
	for i in _rows.size():
		var area = item_rect(i)
		_rows[i].position = area.position + Vector2(4, 0)
		_rows[i].size = Vector2(maxf(0, area.size.x - 8), area.size.y)
		_rows[i].visible = area.intersects(viewport_rect)


func current_enabled() -> bool:
	return item_count > 0 and bool(commands[index].enabled)

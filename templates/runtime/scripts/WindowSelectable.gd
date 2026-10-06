extends "res://runtime/scripts/WindowBase.gd"
signal selection_changed(index: int)
var index := 0
var item_count := 0
var row_height := 32.0
var active := true
var scroll_row := 0


func select(value: int) -> void:
	index = clampi(value, 0, maxi(0, item_count - 1))
	var visible_rows := maxi(1, int((size.y - 32) / row_height))
	scroll_row = clampi(scroll_row, 0, maxi(0, item_count - visible_rows))
	if index < scroll_row:
		scroll_row = index
	elif index >= scroll_row + visible_rows:
		scroll_row = index - visible_rows + 1
	select_rect(Rect2(0, (index - scroll_row) * row_height, size.x - 32, row_height), active and item_count > 0)
	selection_changed.emit(index)


func move_selection(direction: int) -> void:
	if item_count > 0:
		select(posmod(index + direction, item_count))

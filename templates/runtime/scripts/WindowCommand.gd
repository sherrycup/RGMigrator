extends "res://runtime/scripts/WindowSelectable.gd"
var commands: Array[Dictionary] = []


func configure(entries: Array, selected: int = 0) -> void:
	commands.assign(entries)
	item_count = commands.size()
	clear_content()
	for i in commands.size():
		label(str(commands[i].text), Rect2(4, i * row_height, size.x - 40, row_height), Color.WHITE if commands[i].enabled else Color("9197a8"))
	select(selected)


func current_enabled() -> bool:
	return item_count > 0 and bool(commands[index].enabled)

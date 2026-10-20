## 职责：提供通用存档位列表和读写操作界面，显示摘要及失败结果。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/07_Archive/SaveSlots.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func window(script: Script, rect: Rect2) -> Control
##     参数 script（Script；必填）：已通过编译的 GDScript 资源，不在编辑器调用事件入口。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     返回：Control 类型的对象或值，供调用方继续使用。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func navigate(direction: int) -> void
##     用途：移动当前页面的选中项。
##     参数 direction（int；必填）：选择或调整的方向增量；正负号按当前页面的导航逻辑处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func activate() -> void
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func execute() -> void
##     用途：执行该脚本或已准备的操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func back() -> void
##     用途：从当前页面或操作返回。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：由持有方发出，通知对应状态或操作结果。
##   sound_requested(key: String)：由持有方发出，通知对应状态或操作结果。
##     key：查询或写入使用的键名。
##   load_requested(slot: int)：由持有方发出，通知对应状态或操作结果。
##     slot：存档、装备或回路的槽位编号。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends Control
signal back_requested
signal sound_requested(key: String)
signal load_requested(slot: int)
const Saves = preload("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
const Base = preload("res://runtime/scripts/04_UI_Common/WindowBase.gd")
const Selectable = preload("res://runtime/scripts/04_UI_Common/WindowSelectable.gd")
const Command = preload("res://runtime/scripts/04_UI_Common/WindowCommand.gd")
var mode := "save"
var save_callback: Callable
var selected := 0
var message := ""
var _panel: Control
var _list: Control
var _confirm: Control
var _confirmation := ""
var _infos: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()


func window(script: Script, rect: Rect2) -> Control:
	var result: Control = script.new()
	result.position = rect.position
	result.size = rect.size
	_panel.add_child(result)
	return result


func refresh() -> void:
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var header := window(Base, Rect2(0, 0, size.x, 96))
	header.label(
		"保存进度" if mode == "save" else "继续游戏 · 读取进度", Rect2(0, 0, size.x - 32, 28), Color("c0e0ff")
	)
	header.label(
		"四个独立槽位；覆盖前确认，备份可恢复。" if mode == "save" else "仅支持本工具的新存档，不读取 RM 旧存档。",
		Rect2(0, 30, size.x - 32, 32),
		Color.WHITE,
		16
	)
	_list = window(Selectable, Rect2(0, 96, size.x, size.y - 160))
	_list.row_height = 72
	_list.item_count = Saves.SLOT_COUNT
	_list.select(selected)
	_infos.clear()
	for slot in range(1, Saves.SLOT_COUNT + 1):
		_infos.append(Saves.slot_info(slot))
	var rows := maxi(1, int((_list.size.y - 32) / 72))
	for index in range(_list.scroll_row, mini(Saves.SLOT_COUNT, _list.scroll_row + rows)):
		var info := _infos[index]
		var y: float = (index - int(_list.scroll_row)) * 72
		_list.label(
			"存档 %d%s" % [index + 1, "（备份）" if info.get("recovered", false) else ""],
			Rect2(0, y, 140, 28),
			Color("c0e0ff"),
			18
		)
		if info.ok:
			var seconds := int(info.play_seconds)
			_list.label(
				(
					"%s · %02d:%02d:%02d"
					% [info.saved_at, seconds / 3600, (seconds / 60) % 60, seconds % 60]
				),
				Rect2(140, y, size.x - 172, 28),
				Color.WHITE,
				16
			)
			_list.label(
				"%s · Map%03d" % [info.party if not info.party.is_empty() else "空队伍", info.map_id],
				Rect2(0, y + 28, size.x - 32, 28),
				Color.WHITE,
				16
			)
		else:
			var reason: Label = _list.label(
				info.message,
				Rect2(140, y, size.x - 172, 56),
				Color("ffb6a6") if info.exists else Color("b4bed1"),
				15
			)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reason.tooltip_text = info.message
			reason.mouse_filter = Control.MOUSE_FILTER_STOP
	var footer := window(Base, Rect2(0, size.y - 64, size.x, 64))
	footer.label(
		message if not message.is_empty() else "↑↓：选择 · Enter/Z：确认 · Esc/X：返回",
		Rect2(0, 0, size.x - 32, 36),
		Color("ffe9a8"),
		16
	)
	_confirm = null
	if not _confirmation.is_empty():
		_confirm = window(Command, Rect2(size / 2 - Vector2(150, 64), Vector2(300, 128)))
		_confirm.configure(
			[
				{"text": "确认覆盖" if _confirmation == "overwrite" else "读取上一份备份", "enabled": true},
				{"text": "取消", "enabled": true}
			],
			1
		)
		_list.active = false
		_list.select(selected)


func navigate(direction: int) -> void:
	if _confirm != null:
		_confirm.move_selection(direction)
	else:
		_list.move_selection(direction)
		selected = _list.index
		message = ""
		refresh()
	sound_requested.emit("cursor_se")


func activate() -> void:
	if _confirm != null:
		var accepted: bool = _confirm.index == 0
		_confirmation = ""
		if not accepted:
			refresh()
			return
		execute()
	elif mode == "save" and _infos[selected].exists:
		_confirmation = "overwrite"
		refresh()
	elif mode == "load" and _infos[selected].get("recovered", false):
		_confirmation = "backup"
		refresh()
	else:
		execute()


func execute() -> void:
	if mode == "save":
		var result: Dictionary = (
			save_callback.call(selected + 1)
			if save_callback.is_valid()
			else Saves.fail("存档调用上下文不可用。")
		)
		message = result.message
		sound_requested.emit("decision_se" if result.ok else "buzzer_se")
		refresh()
	elif _infos[selected].ok:
		load_requested.emit(selected + 1)
	else:
		message = _infos[selected].message
		sound_requested.emit("buzzer_se")
		refresh()


func back() -> void:
	if not _confirmation.is_empty():
		_confirmation = ""
		refresh()
	else:
		back_requested.emit()

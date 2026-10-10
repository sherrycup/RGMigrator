extends Control
signal back_requested
signal sound_requested(key: String)
signal tool_requested(page: String)
const Base = preload("res://runtime/scripts/WindowBase.gd")
const Commands = preload("res://runtime/scripts/WindowCommand.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
var selected := 0
var _panel: Control
var _commands: Control
const PAGES := ["actor_tools", "shop", "state_tools", "screen_tools", "movement_tools", "presentation_tools", "event_tools", "back"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Base.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_panel.label("测试工具 · 仅测试模式可见", Rect2(0, 0, size.x - 32, 32), Color("c0e0ff"))
	_panel.label("方向键选择，Enter/Space/Z 确认；也可直接点击按钮。", Rect2(0, 36, size.x - 32, 56), Color.WHITE, 17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commands = Commands.new()
	_commands.position = Vector2(16, 116)
	_commands.size = Vector2(size.x - 32, mini(312, size.y - 186))
	_commands.row_height = 36
	_panel.add_child(_commands)
	var names := ["角色数据与成长", "测试商店", "状态接口", "图片与屏幕", "人物与地图", "地图表现与镜头", "正式事件验收地图", "返回主菜单"]
	var entries: Array = []
	for name_value in names:
		entries.append({"text": name_value, "enabled": true})
	_commands.configure(entries, selected)
	for row in mini(names.size(), maxi(1, int((_commands.size.y - 32) / 36))):
		var button := Button.new()
		button.text = "进入"
		button.position = Vector2(size.x - 128, 132 + row * 36)
		button.size = Vector2(80, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: selected = _commands.scroll_row + row; activate())
		_panel.add_child(button)
	_panel.label("Esc/X 返回；不执行 Ruby，关闭测试模式后入口隐藏。", Rect2(0, size.y - 56, size.x - 32, 32), Color("ffe9a8"), 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func navigate(direction: int) -> void:
	selected = posmod(selected + direction, PAGES.size())
	_commands.select(selected)
	sound_requested.emit("cursor_se")


func activate() -> void:
	if selected == PAGES.size() - 1:
		back()
	else:
		sound_requested.emit("decision_se")
		tool_requested.emit(PAGES[selected])


func back() -> void:
	back_requested.emit()

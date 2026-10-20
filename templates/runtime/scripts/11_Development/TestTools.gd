## 职责：组织运行时测试工具菜单，协调各调试页面的打开与返回。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/11_Development/TestTools.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
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
##   func back() -> void
##     用途：从当前页面或操作返回。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：由持有方发出，通知对应状态或操作结果。
##   sound_requested(key: String)：由持有方发出，通知对应状态或操作结果。
##     key：查询或写入使用的键名。
##   tool_requested(page: String)：由持有方发出，通知对应状态或操作结果。
##     page：事件页或界面页数据。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 公开常量：PAGES。
## 接口说明结束。

extends Control
signal back_requested
signal sound_requested(key: String)
signal tool_requested(page: String)
const Base = preload("res://runtime/scripts/04_UI_Common/WindowBase.gd")
const Commands = preload("res://runtime/scripts/04_UI_Common/WindowCommand.gd")
const Resources = preload("res://runtime/scripts/04_UI_Common/UIResources.gd")
var selected := 0
var _panel: Control
var _commands: Control
const PAGES := [
	"actor_tools",
	"shop",
	"state_tools",
	"screen_tools",
	"movement_tools",
	"presentation_tools",
	"event_tools",
	"back"
]


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
	_panel.label("方向键选择，Enter/Space/Z 确认；也可直接点击按钮。", Rect2(0, 36, size.x - 32, 56), Color.WHITE, 17).autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
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
		button.pressed.connect(
			func() -> void:
				selected = _commands.scroll_row + row
				activate()
		)
		_panel.add_child(button)
	_panel.label("Esc/X 返回；不执行 Ruby，关闭测试模式后入口隐藏。", Rect2(0, size.y - 56, size.x - 32, 32), Color("ffe9a8"), 16).autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


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

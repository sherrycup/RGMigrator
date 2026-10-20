## 职责：提供屏幕、图片和天气效果的运行时测试操作。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/11_Development/ScreenTools.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func select_asset(name_value: String) -> void
##     参数 name_value（String；必填）：待设置的名称文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func update_labels() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func display_at(id: int, x: float) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 x（float；必填）：横向坐标。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func action(index: int) -> void
##     参数 index（int；必填）：集合或列表中的位置索引。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func navigate(direction: int) -> void
##     用途：移动当前页面的选中项。
##     参数 direction（int；必填）：选择或调整的方向增量；正负号按当前页面的导航逻辑处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func neutral_tone(tone: Array) -> bool
##     参数 tone（Array；必填）：红、绿、蓝与灰度构成的色调参数。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
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
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 公开常量：ACTIONS。
## 接口说明结束。

extends Control
## Only this testing page advances screen effects while the normal map is paused.
signal back_requested
signal sound_requested(key: String)
const Base = preload("res://runtime/scripts/04_UI_Common/WindowBase.gd")
const Resources = preload("res://runtime/scripts/04_UI_Common/UIResources.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const Screen = preload("res://runtime/scripts/00_Game/ScreenState.gd")
const ACTIONS := [
	"显示/替换",
	"追加双图",
	"移动/缩放",
	"透明/混合",
	"旋转开关",
	"切换原点",
	"图片色调",
	"地图色调",
	"屏幕闪光",
	"地图震动",
	"擦除当前",
	"全部重置"
]
var selected := 0
var number := 1
var asset_name := "@test_picture"
var assets: Array[String] = []
var message := "选择图片后显示；下方是真实地图预览，不执行事件指令。"
var _panel: Control
var _message: Label
var _status: Label
var _buttons: Array[Button] = []
var _asset_edit: OptionButton
var _refresh_seconds := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	assets = Cache.list_names("Pictures")
	assets.append("@test_picture")
	if assets.size() > 1:
		asset_name = assets[0]
	resized.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Base.new()
	_panel.size = Vector2(size.x, 312)
	add_child(_panel)
	_panel.label("图片与屏幕 · 原生接口测试", Rect2(0, 0, size.x - 144, 32), Color("c0e0ff"))
	var back_button := Button.new()
	back_button.text = "返回 · Esc/X"
	back_button.position = Vector2(size.x - 144, 16)
	back_button.size = Vector2(128, 32)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(back)
	_panel.add_child(back_button)
	var id_edit := OptionButton.new()
	for id in range(1, 51):
		id_edit.add_item("#%d" % id)
	id_edit.select(number - 1)
	id_edit.get_popup().max_size = Vector2i(80, 280)
	id_edit.position = Vector2(16, 52)
	id_edit.size = Vector2(80, 32)
	_panel.add_child(id_edit)
	id_edit.item_selected.connect(
		func(value: int) -> void:
			number = value + 1
			update_labels()
	)
	var asset_edit := OptionButton.new()
	_asset_edit = asset_edit
	asset_edit.position = Vector2(104, 52)
	asset_edit.size = Vector2(size.x - 120, 32)
	asset_edit.add_theme_font_override("font", Resources.font())
	asset_edit.add_theme_font_size_override("font_size", 16)
	asset_edit.get_popup().max_size = Vector2i(int(size.x - 120), 280)
	for entry in assets:
		asset_edit.add_item("[工具绘制] 测试色块" if entry == "@test_picture" else entry)
	asset_edit.select(maxi(0, assets.find(asset_name)))
	asset_edit.item_selected.connect(func(value: int) -> void: asset_name = assets[value])
	_panel.add_child(asset_edit)
	_buttons.clear()
	for action_index in ACTIONS.size():
		var button := Button.new()
		button.text = ACTIONS[action_index]
		button.position = Vector2(
			16 + (action_index % 4) * (size.x - 32) / 4, 96 + int(action_index / 4) * 36
		)
		button.size = Vector2((size.x - 40) / 4, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", Resources.font())
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(
			func() -> void:
				selected = action_index
				action(action_index)
		)
		_panel.add_child(button)
		_buttons.append(button)
	_status = _panel.label("", Rect2(0, 192, size.x - 32, 36), Color("c0e0ff"), 15)
	_message = _panel.label("", Rect2(0, 230, size.x - 32, 52), Color("ffe9a8"), 16)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_labels()


func select_asset(name_value: String) -> void:
	if not assets.has(name_value):
		return
	asset_name = name_value
	if _asset_edit != null:
		_asset_edit.select(assets.find(name_value))


func _process(delta: float) -> void:
	if get_tree().paused:
		RuntimeState.screen.advance(delta)
	_refresh_seconds += delta
	if _refresh_seconds >= 0.1:
		_refresh_seconds = 0.0
		update_labels()


func update_labels() -> void:
	if _message == null:
		return
	_message.text = message
	var picture: RefCounted = RuntimeState.screen.picture(number)
	var view: Dictionary = picture.snapshot() if picture != null else {}
	_status.text = (
		"#%d · %s 张图 · %s"
		% [
			number,
			RuntimeState.screen.picture_ids().size(),
			(
				"尚未显示"
				if view.is_empty()
				else (
					"原点%d (%d,%d) 缩放%d%% α%d 混合%d 角度%d°"
					% [
						view.origin,
						view.x,
						view.y,
						view.zoom_x,
						view.opacity,
						view.blend_type,
						view.angle
					]
				)
			)
		]
	)
	for index in _buttons.size():
		_buttons[index].modulate = Color("ffe38a") if selected == index else Color.WHITE


func display_at(id: int, x: float) -> Dictionary:
	var texture := Cache.picture(asset_name)
	if texture == null:
		return RuntimeState.show_picture(id, asset_name)
	var zoom := (
		minf(1, minf(160.0 / texture.get_width(), maxf(64, size.y - 336) / texture.get_height()))
		* 100
	)
	return RuntimeState.show_picture(
		id,
		asset_name,
		{"origin": 1, "x": x, "y": (size.y + 312) / 2, "zoom_x": zoom, "zoom_y": zoom}
	)


func action(index: int) -> void:
	var screen: RefCounted = RuntimeState.screen
	var result := {"ok": true}
	var picture: RefCounted = screen.picture(number)
	var view: Dictionary = picture.snapshot() if picture != null else {}
	match index:
		0:
			result = display_at(number, size.x * 0.5)
		1:
			result = display_at(number, size.x * 0.3)
			if result.ok:
				result = display_at(number % 50 + 1, size.x * 0.7)
		2:
			result = RuntimeState.move_picture(
				number,
				{
					"x": size.x * 0.7 if view.get("x", 0) < size.x * 0.6 else size.x * 0.3,
					"zoom_x": minf(180, view.get("zoom_x", 100) * 1.2),
					"zoom_y": minf(180, view.get("zoom_y", 100) * 1.2)
				},
				2.0
			)
		3:
			result = RuntimeState.move_picture(
				number,
				{
					"opacity": 140 if view.get("opacity", 255) > 200 else 255,
					"blend_type": (int(view.get("blend_type", 0)) + 1) % 3
				},
				1.0
			)
		4:
			result = RuntimeState.rotate_picture(
				number, 60 if view.get("rotate_speed", 0) == 0 else 0
			)
		5:
			result = RuntimeState.move_picture(number, {"origin": 1 - int(view.get("origin", 0))})
		6:
			result = RuntimeState.tint_picture(
				number,
				(
					[-80, 30, 50, 120]
					if neutral_tone(view.get("tone_target", [0, 0, 0, 0]))
					else [0, 0, 0, 0]
				),
				1.0
			)
		7:
			result = screen.start_tone_change(
				(
					[-80, -40, 30, 150]
					if neutral_tone(screen.effects_snapshot().tone_target)
					else [0, 0, 0, 0]
				),
				1.0
			)
		8:
			result = screen.start_flash([255, 180, 80, 200], 1.0)
		9:
			result = screen.start_shake(12, 3, 2.0)
		10:
			result = RuntimeState.erase_picture(number)
		11:
			RuntimeState.screen = Screen.new()
			message = "已清空图片并复原色调、闪光、震动；不修改地图、队伍或背包。"
	if index != 11:
		message = ("已执行：%s。普通菜单暂停，返回地图后继续；可存档。" % ACTIONS[index]) if result.ok else result.message
	sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	update_labels()


func navigate(direction: int) -> void:
	selected = posmod(selected + direction, ACTIONS.size())
	sound_requested.emit("cursor_se")
	update_labels()


func neutral_tone(tone: Array) -> bool:
	for value in tone:
		if not is_zero_approx(float(value)):
			return false
	return true


func activate() -> void:
	action(selected)


func back() -> void:
	back_requested.emit()

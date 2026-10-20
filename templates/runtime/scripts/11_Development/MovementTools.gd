## 职责：提供人物移动、路线和地图通行的运行时调试操作。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/11_Development/MovementTools.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func settings() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func apply_preview() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func has_text_focus() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func update_labels() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func action(index: int) -> void
##     参数 index（int；必填）：集合或列表中的位置索引。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
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
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 公开常量：ACTIONS。
## 接口说明结束。

extends Control
signal back_requested
signal sound_requested(key: String)
const Base = preload("res://runtime/scripts/04_UI_Common/WindowBase.gd")
const Resources = preload("res://runtime/scripts/04_UI_Common/UIResources.gd")
const Map = preload("res://runtime/scripts/03_Map/MapRuntime.gd")
const Character = preload("res://runtime/scripts/03_Map/MapCharacter.gd")
const Fixture = preload("res://runtime/scripts/11_Development/MovementFixture.gd")
var map: Node2D
var avatar: Node2D
var selected := 0
var _message: Label
var _status: Label
var _viewport: SubViewport
var _container: TextureRect
var _cooldown := 0.0
var _message_text := "草丛绿色/地形7；红地块禁止向右；柜台后有人；黄色遮挡图块。"
var _speed: SpinBox
var _checks := {}
var _buttons: Array[Button] = []
const ACTIONS := ["跳跃两格", "回到起点", "应用到玩家", "恢复默认"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Base.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.label("人物与地图 · 独立验收区", Rect2(0, 0, size.x - 144, 28), Color("c0e0ff"))
	var back_button := Button.new()
	back_button.text = "返回 · Esc/X"
	back_button.position = Vector2(size.x - 140, 16)
	back_button.size = Vector2(124, 32)
	back_button.pressed.connect(back)
	back_button.focus_mode = Control.FOCUS_NONE
	panel.add_child(back_button)
	panel.label("速度", Rect2(0, 35, 48, 28), Color.WHITE, 16)
	_speed = SpinBox.new()
	_speed.min_value = 1
	_speed.max_value = 6
	_speed.value = RuntimeState.player_motion.options.move_speed
	# A mouse-only six-value spinner must not trap the movement arrow keys.
	_speed.focus_mode = Control.FOCUS_NONE
	_speed.get_line_edit().focus_mode = Control.FOCUS_CLICK
	_speed.gui_input.connect(_release_speed_focus)
	_speed.get_line_edit().gui_input.connect(_release_speed_focus)
	_speed.position = Vector2(64, 48)
	_speed.size = Vector2(64, 28)
	panel.add_child(_speed)
	var keys := ["through", "direction_fix", "step_anime", "walk_anime"]
	var names := ["穿透", "方向固定", "踏步", "行走动画"]
	for index in keys.size():
		var check := CheckBox.new()
		check.text = names[index]
		check.position = Vector2(160 + index * (size.x - 192) / 4, 48)
		check.size = Vector2((size.x - 192) / 4, 28)
		check.add_theme_font_override("font", Resources.font())
		check.add_theme_font_size_override("font_size", 15)
		check.focus_mode = Control.FOCUS_NONE
		check.button_pressed = RuntimeState.player_motion.options[keys[index]]
		_checks[keys[index]] = check
		panel.add_child(check)
		check.toggled.connect(func(_value: bool) -> void: apply_preview())
	for index in ACTIONS.size():
		var button := Button.new()
		button.text = ACTIONS[index]
		button.position = Vector2(16 + index * (size.x - 32) / 4, 84)
		button.size = Vector2((size.x - 40) / 4, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action.bind(index))
		panel.add_child(button)
		_buttons.append(button)
	_status = panel.label("", Rect2(0, 100, size.x - 32, 24), Color("ffe9a8"), 14)
	_message = panel.label("", Rect2(0, size.y - 54, size.x - 32, 32), Color("ffe9a8"), 14)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_container = TextureRect.new()
	_container.position = Vector2(16, 144)
	_container.size = Vector2(size.x - 32, maxf(96, size.y - 192))
	_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_container.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(384, 288)
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	_container.add_child(_viewport)
	_container.texture = _viewport.get_texture()
	var fixture := Fixture.build()
	map = Map.new()
	_viewport.add_child(map)
	map.load_definition(fixture.map, fixture.tileset)
	avatar = Character.new()
	avatar.map_runtime = map
	avatar.motion.configure(RuntimeState.player_motion.options)
	map.ensure_character_layer().add_child(avatar)
	avatar.set_graphic("@movement_character")
	avatar.move_to(2, 4)
	avatar.set_process(false)
	map.player_character = avatar
	avatar.arrived.connect(
		func(_kind: String) -> void: map.trigger_player_touch(avatar.tile_position)
	)
	map.event_requested.connect(
		func(commands: Array, id: int) -> void:
			_message_text = "事件 #%d：%s" % [id, commands[0].parameters[0]]
	)
	var camera := Camera2D.new()
	camera.position = Vector2(12 * 16, 9 * 16)
	_viewport.add_child(camera)
	_speed.value_changed.connect(func(_value: float) -> void: apply_preview())
	resized.connect(_resize_preview)
	update_labels()


func settings() -> Dictionary:
	var result := {"move_speed": int(_speed.value)}
	for key in _checks:
		result[key] = _checks[key].button_pressed
	return result


func _release_speed_focus(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# SpinBox internally grabs focus before applying a mouse arrow change.
		# Release after native handling, including a click at an unchanged limit.
		_speed.get_line_edit().call_deferred("release_focus")


func apply_preview() -> void:
	if avatar != null:
		avatar.configure_motion(settings())


func _resize_preview() -> void:
	# The menu rebuilds this page after a root resize. Keep viewport valid until then.
	if _container != null:
		_container.size = Vector2(size.x - 32, maxf(96, size.y - 192))


func _process(delta: float) -> void:
	if avatar == null:
		return
	avatar.advance_motion(delta)
	_cooldown = maxf(0, _cooldown - delta)
	if avatar.is_idle() and _cooldown <= 0 and not has_text_focus():
		for role in [["ui_up", 8], ["ui_down", 2], ["ui_left", 4], ["ui_right", 6]]:
			if Input.is_action_pressed(role[0]):
				if not avatar.move_straight(role[1]):
					map.trigger_player_touch(
						avatar.tile_position + avatar.Motion.DIRECTIONS[role[1]], true
					)
					_cooldown = 0.12
				break
	update_labels()


func has_text_focus() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func update_labels() -> void:
	var cell: Vector2i = avatar.tile_position
	var status := (
		"(%d,%d) 朝向%d 帧%d · 地形%d 草丛%s 柜台%s · 方向键行走，Z确认，Q跳跃"
		% [
			cell.x,
			cell.y,
			avatar.motion.direction,
			avatar.motion.pattern,
			map.terrain_tag(cell.x, cell.y),
			"是" if map.is_bush(cell.x, cell.y) else "否",
			"是" if map.is_counter(cell.x, cell.y) else "否"
		]
	)
	if _status.text != status:
		_status.text = status
	if _message.text != _message_text:
		_message.text = _message_text
	for index in _buttons.size():
		_buttons[index].modulate = Color("ffe38a") if selected == index else Color.WHITE


func action(index: int) -> void:
	selected = index
	sound_requested.emit("decision_se")
	match index:
		0:
			var vector: Vector2i = avatar.facing * 2
			_message_text = (
				"开始跳跃；不会穿出地图或落在阻挡点。" if avatar.jump(vector.x, vector.y) else "跳跃失败：正在移动或落点不可通行。"
			)
		1:
			avatar.move_to(2, 4)
			_message_text = "返回验收区起点；原地图位置和步数没有改变。"
		2:
			RuntimeState.configure_player(settings())
			_message_text = "已应用到真实玩家，返回地图生效并可存档；没有改变真实坐标。"
		3:
			avatar.configure_motion(avatar.Motion.DEFAULTS)
			_speed.set_value_no_signal(4)
			for key in _checks:
				_checks[key].set_pressed_no_signal(key == "walk_anime")
			apply_preview()
			_message_text = "恢复验收区默认设置；需再点“应用到玩家”才修改真实玩家。"
	update_labels()


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif has_text_focus():
		return
	elif key in [KEY_Z, KEY_ENTER, KEY_SPACE] and avatar.is_idle():
		map.request_action(avatar.tile_position, avatar.facing)
	elif key == KEY_Q:
		action(0)
	elif key == KEY_TAB:
		selected = (selected + 1) % ACTIONS.size()
		update_labels()
	elif key == KEY_F5:
		action(selected)


func navigate(direction: int) -> void:
	selected = posmod(selected + direction, ACTIONS.size())
	update_labels()


func activate() -> void:
	action(selected)


func back() -> void:
	sound_requested.emit("cancel_se")
	back_requested.emit()

extends Control
## Testing-only editor; every mutation goes through production state APIs.
signal back_requested
signal sound_requested(key: String)
const Base = preload("res://runtime/scripts/WindowBase.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Rules = preload("res://runtime/scripts/ActorParameters.gd")
const ACTIONS := ["永久修正 −10", "永久修正 −1", "永久修正 ＋1", "永久修正 ＋10", "清零当前修正", "经验 −100", "经验 ＋100", "等级 −1", "等级 ＋1", "HP −10", "SP −10", "HP/SP 回满", "姓名/职业/角色图", "返回"]
var actor_id := 0
var parameter := "atk"
var selected := 2
var message := ""
var _panel: Control
var _buttons: Array[Button] = []
var _identity: Control
var _name_edit: LineEdit
var _graphic_edit: LineEdit
var _hue_edit: SpinBox
var _class_edit: OptionButton
var _identity_message: Label


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
	_panel.label("角色数据与成长 · 原生接口测试", Rect2(0, 0, size.x - 32, 32), Color("c0e0ff"))
	var ids: Array[int] = []
	for id in RuntimeState.party:
		if RuntimeState.actor(int(id)) != null:
			ids.append(int(id))
	if not ids.has(actor_id):
		actor_id = ids[0] if not ids.is_empty() else 0
	var actors := OptionButton.new()
	actors.position = Vector2(16, 52)
	actors.size = Vector2(size.x * 0.5 - 24, 36)
	actors.add_theme_font_override("font", Resources.font())
	actors.disabled = ids.is_empty()
	_panel.add_child(actors)
	for id in ids:
		actors.add_item("#%d %s" % [id, RuntimeState.actor(id).actor_name])
	actors.select(maxi(0, ids.find(actor_id)))
	actors.item_selected.connect(func(index: int) -> void: actor_id = ids[index]; refresh())
	var keys := OptionButton.new()
	keys.position = Vector2(size.x * 0.5, 52)
	keys.size = Vector2(size.x * 0.5 - 16, 36)
	keys.add_theme_font_override("font", Resources.font())
	_panel.add_child(keys)
	for key in Rules.KEYS:
		keys.add_item("%s (%s)" % [parameter_name(key), key])
	keys.select(Rules.KEYS.find(parameter))
	keys.item_selected.connect(func(index: int) -> void: parameter = Rules.KEYS[index]; message = ""; refresh())
	var actor: RefCounted = RuntimeState.actor(actor_id) if actor_id > 0 else null
	if actor != null:
		var source: Dictionary = actor.parameter_sources(parameter)
		_panel.label("数据库 %s · 装备 %s · base %s · 永久修正 %s" % [source.database, source.equipment, source.base, source.plus], Rect2(0, 88, size.x - 32, 28), Color.WHITE, 17)
		_panel.label("最终 %s = %s · 状态倍率 %s · 范围 %d–%d" % [parameter, source.value, source.state_rates, source.minimum, source.maximum], Rect2(0, 116, size.x - 32, 28), Color("ffe9a8"), 17)
		_panel.label("Lv %d · EXP %d · 距升级 %s · HP %s/%s · SP %s/%s" % [actor.level, actor.experience, actor.snapshot().next_experience, actor.hp, actor.get_parameter("maxhp"), actor.sp, actor.get_parameter("maxsp")], Rect2(0, 144, size.x - 32, 48), Color("c0e0ff"), 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_panel.label("队伍为空，不能修改角色。", Rect2(0, 96, size.x - 32, 64))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(16, 208)
	grid.size = Vector2(size.x - 32, 136)
	_panel.add_child(grid)
	_buttons.clear()
	for index in ACTIONS.size():
		var button := Button.new()
		button.text = ACTIONS[index]
		button.custom_minimum_size = Vector2((size.x - 44) / 4, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = actor == null and index != 13
		button.add_theme_font_override("font", Resources.font())
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(action.bind(index))
		grid.add_child(button)
		_buttons.append(button)
	paint_selection()
	_panel.label("方向键选择按钮 · 确认执行 · Q/E 切换属性 · Esc/X 返回", Rect2(0, size.y - 112, size.x - 32, 28), Color("c0e0ff"), 15)
	_panel.label(message if not message.is_empty() else "永久修正与最终值不是同一概念；到达上限时最终值可能不再增加。", Rect2(0, size.y - 80, size.x - 32, 64), Color("ffe9a8"), 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(_identity):
		_panel.hide()
		move_child(_identity, -1)


func parameter_name(key: String) -> String:
	return "最大 HP" if key == "maxhp" else ("最大 SP" if key == "maxsp" else Resources.word(key, key))


func paint_selection() -> void:
	for index in _buttons.size():
		_buttons[index].modulate = Color("ffe095") if index == selected else Color.WHITE


func navigate(direction: int) -> void:
	selected = posmod(selected + direction, ACTIONS.size())
	paint_selection()
	sound_requested.emit("cursor_se")


func activate() -> void:
	action(selected)


func action(index: int) -> void:
	selected = index
	if index == 13:
		back()
		return
	if actor_id == 0:
		return
	if index == 12:
		open_identity()
		return
	var result: Dictionary
	if index < 4:
		result = RuntimeState.change_actor_parameter(actor_id, parameter, [-10, -1, 1, 10][index])
	elif index == 4:
		result = RuntimeState.set_actor_parameter_plus(actor_id, parameter, 0)
	elif index in [5, 6]:
		result = RuntimeState.change_actor_experience(actor_id, -100 if index == 5 else 100)
	elif index in [7, 8]:
		result = RuntimeState.change_actor_level(actor_id, -1 if index == 7 else 1)
	elif index in [9, 10]:
		result = RuntimeState.change_actor_vital(actor_id, "hp" if index == 9 else "sp", -10)
	else:
		result = RuntimeState.recover_actor_vitals(actor_id)
	message = result.message
	sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	refresh()


func open_identity() -> void:
	if is_instance_valid(_identity):
		return
	var actor: RefCounted = RuntimeState.actor(actor_id)
	_identity = Base.new()
	_identity.position = Vector2(16, 32)
	_identity.size = size - Vector2(32, 64)
	add_child(_identity)
	_panel.hide()
	_identity.label("姓名、职业和四方向四帧角色图", Rect2(0, 0, size.x - 64, 28), Color("c0e0ff"))
	_name_edit = text_edit("姓名", actor.actor_name, 44)
	_class_edit = OptionButton.new()
	_class_edit.position = Vector2(128, 104)
	_class_edit.size = Vector2(size.x - 192, 36)
	_class_edit.add_theme_font_override("font", Resources.font())
	_identity.add_child(_class_edit)
	_identity.label("职业", Rect2(0, 88, 104, 36), Color.WHITE, 17)
	for definition in Data.database("Classes"):
		if definition is Dictionary and int(definition.get("id", 0)) > 0:
			_class_edit.add_item("#%d %s" % [definition.id, definition.get("name", "")], int(definition.id))
			if int(definition.id) == actor.class_id:
				_class_edit.select(_class_edit.item_count - 1)
	_graphic_edit = text_edit("角色图名称", actor.character_name, 140)
	_identity.label("色相 0–360", Rect2(0, 196, 112, 36), Color.WHITE, 17)
	_hue_edit = SpinBox.new()
	_hue_edit.position = Vector2(128, 212)
	_hue_edit.size = Vector2(160, 36)
	_hue_edit.min_value = 0
	_hue_edit.max_value = 360
	_hue_edit.value = actor.character_hue
	_identity.add_child(_hue_edit)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(16, 272)
	_identity.add_child(buttons)
	for entry in [["应用姓名", 0], ["应用职业", 1], ["应用角色图/色相", 2], ["关闭", 3]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", Resources.font())
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(identity_action.bind(int(entry[1])))
		buttons.add_child(button)
	_identity_message = _identity.label("文本框支持键盘输入；Esc 关闭。职业变更会收回不兼容装备。", Rect2(0, 306, size.x - 64, 72), Color("ffe9a8"), 15)
	_identity_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func text_edit(caption: String, value: String, y: float) -> LineEdit:
	_identity.label(caption, Rect2(0, y, 112, 36), Color.WHITE, 17)
	var edit := LineEdit.new()
	edit.position = Vector2(128, y + 16)
	edit.size = Vector2(size.x - 192, 36)
	edit.text = value
	edit.add_theme_font_override("font", Resources.font())
	_identity.add_child(edit)
	return edit


func identity_action(index: int) -> void:
	if index == 3:
		close_identity()
		return
	var result: Dictionary
	if index == 0:
		result = RuntimeState.rename_actor(actor_id, _name_edit.text)
	elif index == 1:
		result = RuntimeState.change_actor_class(actor_id, _class_edit.get_selected_id())
	else:
		result = RuntimeState.set_actor_graphic(actor_id, _graphic_edit.text, int(_hue_edit.value))
	_identity_message.text = result.message
	message = result.message
	sound_requested.emit("decision_se" if result.ok else "buzzer_se")


func close_identity() -> void:
	if is_instance_valid(_identity):
		_identity.queue_free()
		_identity = null
	refresh()


func has_text_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit and is_ancestor_of(focus)


func back() -> void:
	if is_instance_valid(_identity):
		close_identity()
	else:
		back_requested.emit()


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif is_instance_valid(_identity):
		return
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
		activate()
	elif key in [KEY_UP, KEY_DOWN]:
		navigate(-4 if key == KEY_UP else 4)
	elif key in [KEY_LEFT, KEY_RIGHT]:
		navigate(-1 if key == KEY_LEFT else 1)
	elif key in [KEY_Q, KEY_E]:
		parameter = Rules.KEYS[posmod(Rules.KEYS.find(parameter) + (-1 if key == KEY_Q else 1), Rules.KEYS.size())]
		refresh()

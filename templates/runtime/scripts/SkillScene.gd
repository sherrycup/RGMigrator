extends Control
## Learned skills and native common-event use; debug animation previews separate.
signal back_requested
signal sound_requested(key: String)
signal common_event_requested
const BaseWindow = preload("res://runtime/scripts/WindowBase.gd")
const Selectable = preload("res://runtime/scripts/WindowSelectable.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const RmxpPlayer = preload("res://runtime/scripts/RmxpAnimationPlayer.gd")
const Interpreter = preload("res://runtime/scripts/EventInterpreter.gd")
const AnimationLab = preload("res://runtime/scripts/AnimationLab.gd")
var actor_id := 0
var selected := 0
var _ids: Array[int] = []
var _panel: Control
var _list: Control
var _hint: Label
var _preview: Node2D
var _target: ColorRect
var _selection_id := 0
var _lab: Control
var _scroll_row := 0
var _target_selection: Control
var _target_ids: Array[int] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_list):
		_scroll_row = _list.scroll_row
	_ids = RuntimeState.skill_ids(actor_id)
	if _ids.has(_selection_id):
		selected = _ids.find(_selection_id)
	selected = clampi(selected, 0, maxi(0, _ids.size() - 1))
	_selection_id = _ids[selected] if not _ids.is_empty() else 0
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var skill := Data.record("Skills", _selection_id)
	var header := _window(BaseWindow, Rect2(0, 0, size.x, 116))
	header.label("%s · 已学特技" % RuntimeState.actor(actor_id).actor_name, Rect2(0, 0, size.x - 32, 28), Color("c0e0ff"))
	var description: Label = header.label(str(skill.get("description", "没有已学特技。")), Rect2(0, 30, size.x - 32, 68), Color.WHITE, 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer_height := 128.0 if RuntimeState.testing_enabled else 64.0
	_list = _window(Selectable, Rect2(0, 116, size.x, size.y - 116 - footer_height))
	_list.row_height = 40
	_list.item_count = _ids.size()
	_list.scroll_row = _scroll_row
	_list.select(selected)
	var rows := maxi(1, int((_list.size.y - 32) / 40))
	for index in range(_list.scroll_row, mini(_ids.size(), _list.scroll_row + rows)):
		var entry := Data.record("Skills", _ids[index])
		var y := float(index - _list.scroll_row) * 40
		var icon := TextureRect.new()
		icon.position = Vector2(0, y + 8)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = Cache.icon(str(entry.get("icon_name", "")))
		_list.content.add_child(icon)
		var prefix := "#%d " % _ids[index] if RuntimeState.testing_enabled else ""
		_list.label(prefix + str(entry.get("name", "缺失特技")), Rect2(36, y, size.x - 180, 40))
		_list.label("SP %d" % int(entry.get("sp_cost", 0)), Rect2(size.x - 140, y, 100, 40), Color("b4bed1"), 16)
	var footer := _window(BaseWindow, Rect2(0, size.y - footer_height, size.x, footer_height))
	var reason := preload("res://runtime/scripts/CommonEventUse.gd").skill_reason(RuntimeState, actor_id, _selection_id) if _selection_id > 0 else "没有已学特技。"
	_hint = footer.label("确认使用，返回地图执行公共事件；Esc/X 返回。" if reason.is_empty() else reason, Rect2(0, 0, size.x - 32, 28), Color("ffe9a8"), 15)
	if RuntimeState.testing_enabled:
		var actions := HBoxContainer.new()
		actions.position = Vector2(0, 32)
		footer.content.add_child(actions)
		for entry in [["预览动画1", 1], ["预览动画2", 2], ["学习测试特技", 3], ["遗忘测试特技", 4], ["原动画/并发", 5]]:
			var button := Button.new()
			button.text = entry[0]
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_override("font", Resources.font())
			button.add_theme_font_size_override("font_size", 15)
			button.pressed.connect(_test_action.bind(int(entry[1])))
			actions.add_child(button)
		footer.label("[测试入口] 只预览动画；学习/遗忘通过事件指令 318 验证。", Rect2(0, 67, size.x - 32, 22), Color("b4bed1"), 13)
	if is_instance_valid(_lab):
		_panel.hide()


func _window(script: Script, rectangle: Rect2) -> Control:
	var result: Control = script.new()
	result.position = rectangle.position
	result.size = rectangle.size
	_panel.add_child(result)
	return result


func navigate(direction: int) -> void:
	if is_instance_valid(_target_selection):
		_target_selection.move_selection(direction)
		sound_requested.emit("cursor_se")
		return
	if is_instance_valid(_lab):
		_lab.navigate(direction)
		return
	_list.move_selection(direction)
	selected = _list.index
	_selection_id = _ids[selected] if not _ids.is_empty() else 0
	refresh()
	sound_requested.emit("cursor_se")


func activate() -> void:
	if is_instance_valid(_lab):
		_lab.activate()
		return
	if is_instance_valid(_target_selection):
		_use_skill(_target_ids[_target_selection.index])
		return
	var reason := preload("res://runtime/scripts/CommonEventUse.gd").skill_reason(RuntimeState, actor_id, _selection_id)
	if not reason.is_empty():
		_hint.text = reason
		sound_requested.emit("buzzer_se")
		return
	var skill := Data.record("Skills", _selection_id)
	if int(skill.get("scope", 0)) != 3:
		_use_skill(actor_id if int(skill.get("scope", 0)) == 7 else 0)
		return
	_target_ids.clear()
	var entries: Array = []
	for view in RuntimeState.party_snapshots():
		_target_ids.append(int(view.id))
		entries.append({"text": "%s  HP %d/%d" % [view.name, view.hp, view.parameters.maxhp], "enabled": int(view.hp) > 0})
	_target_selection = preload("res://runtime/scripts/WindowCommand.gd").new()
	_target_selection.position = Vector2(24, 140); _target_selection.size = Vector2(size.x - 48, maxi(80, entries.size() * 40 + 32))
	add_child(_target_selection)
	_target_selection.configure(entries, 0)
	_panel.hide()

func _use_skill(target_id: int) -> void:
	var result: Dictionary = RuntimeState.use_skill(actor_id, _selection_id, target_id)
	sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	if result.ok: common_event_requested.emit()
	else:
		_hint.text = result.message
		if is_instance_valid(_target_selection):
			_target_selection.queue_free(); _target_selection = null; _panel.show()


func back() -> void:
	if is_instance_valid(_target_selection):
		_target_selection.queue_free(); _target_selection = null; _panel.show()
		return
	if is_instance_valid(_lab):
		_lab.back()
		return
	if is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
		return
	back_requested.emit()


func _test_action(action: int) -> void:
	if not RuntimeState.testing_enabled:
		return
	if action == 5:
		if is_instance_valid(_preview):
			_preview.free()
			_preview = null
		if not is_instance_valid(_lab):
			_lab = AnimationLab.new()
			_lab.back_requested.connect(func() -> void:
				_lab.queue_free()
				_lab = null
				_panel.show())
			add_child(_lab)
			_panel.hide()
		return
	if action <= 2:
		var skill := Data.record("Skills", _selection_id)
		var raw: Variant = skill.get("animation%d_id" % action, 0)
		var id := 0 if raw == null else int(raw)
		if is_instance_valid(_preview):
			_preview.free()
			_preview = null
		if id == 0:
			_hint.text = "此特技没有配置动画%d；无需播放。" % action
			return
		_preview = Node2D.new()
		add_child(_preview)
		_target = ColorRect.new()
		_target.position = size / 2 - Vector2(20, 28)
		_target.size = Vector2(40, 56)
		_target.color = Color("5796ce")
		_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview.add_child(_target)
		var result := RmxpPlayer.play(_preview, id, func() -> CanvasItem: return _target)
		_hint.text = "预览动画 #%d；Esc 关闭预览。" % id if result.ok else result.message
	else:
		var setup := Data.test_config()
		var id := int(setup.get("toggle_skill_id", 0))
		var interpreter := Interpreter.new()
		var message := "已学习测试特技 #%d。" % id if action == 3 else "已遗忘测试特技 #%d。" % id
		interpreter.diagnostic_requested.connect(func(reason: String) -> void: RuntimeState.report_diagnostic(reason))
		interpreter.start([{"code": 318, "indent": 0, "parameters": [actor_id, 0 if action == 3 else 1, id]}], 0)
		refresh()
		_hint.text = message

extends Control
## Testing-only state registration. Does not run RPG::State trigger rules.
signal back_requested
signal sound_requested(key: String)
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Base = preload("res://runtime/scripts/WindowBase.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
var actor_id := 0
var selected_state := 0
var message := ""
var _panel: Control
var _actor_ids: Array[int] = []
var _state_ids: Array[int] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()


func refresh() -> void:
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Base.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_panel.label("State 接口测试 · 不执行底层状态效果", Rect2(0, 0, size.x - 32, 32), Color("c0e0ff"))
	_actor_ids.clear()
	for id in RuntimeState.party:
		if RuntimeState.actor(int(id)) != null:
			_actor_ids.append(int(id))
	if not _actor_ids.has(actor_id):
		actor_id = 0 if _actor_ids.is_empty() else _actor_ids[0]
	var actors := selector(Vector2(16, 60), _actor_ids, true)
	actors.item_selected.connect(func(index: int) -> void: actor_id = _actor_ids[index]; refresh())
	_state_ids.clear()
	var definitions: Array = Data.database("States")
	for definition in definitions:
		if definition is Dictionary and int(definition.get("id", 0)) > 0:
			_state_ids.append(int(definition.id))
	for definition in Data.test_config().get("definitions", {}).get("States", []):
		if Data.is_test_record("States", int(definition.id)):
			_state_ids.append(int(definition.id))
	_state_ids.sort()
	if not _state_ids.has(selected_state):
		var testing_id := int(Data.test_config().get("toggle_state_id", 0))
		selected_state = testing_id if _state_ids.has(testing_id) else (0 if _state_ids.is_empty() else _state_ids[0])
	var states := selector(Vector2(16, 108), _state_ids, false)
	states.item_selected.connect(func(index: int) -> void: selected_state = _state_ids[index]; refresh())
	var actor: RefCounted = RuntimeState.actor(actor_id) if actor_id > 0 else null
	var ordinary := "—" if actor == null else str(actor.get_state_ids(false))
	var effective := "—" if actor == null else str(actor.get_state_ids())
	_panel.label("普通状态 ID：" + ordinary, Rect2(0, 144, size.x - 32, 32), Color.WHITE, 18)
	_panel.label("有效状态 ID（含装备）：" + effective, Rect2(0, 180, size.x - 32, 32), Color.WHITE, 18)
	_panel.label("现有属性倍率显示保留；不触发死亡、中毒、连锁状态或状态动画。", Rect2(0, 228, size.x - 32, 56), Color("c0e0ff"), 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.position = Vector2(16, size.y - 148)
	_panel.add_child(actions)
	for entry in [["附加状态", 0], ["解除状态", 1], ["查询是否存在", 2], ["清空普通状态", 3], ["返回", 4]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", Resources.font())
		button.add_theme_font_size_override("font_size", 15)
		button.disabled = actor == null and entry[1] != 4
		button.pressed.connect(action.bind(int(entry[1])))
		actions.add_child(button)
	_panel.label(message if not message.is_empty() else "鼠标选择角色和状态；Esc/X 返回。", Rect2(0, size.y - 112, size.x - 32, 64), Color("ffe9a8"), 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func selector(position_value: Vector2, ids: Array[int], actors: bool) -> OptionButton:
	var result := OptionButton.new()
	result.position = position_value
	result.size = Vector2(size.x - 32, 36)
	result.add_theme_font_override("font", Resources.font())
	_panel.add_child(result)
	for id in ids:
		result.add_item("#%d %s" % [id, RuntimeState.actor(id).actor_name if actors else str(Data.record("States", id).get("name", ""))])
	result.disabled = ids.is_empty()
	if not ids.is_empty():
		result.select(maxi(0, ids.find(actor_id if actors else selected_state)))
	return result


func action(value: int) -> void:
	if value == 4:
		back_requested.emit()
		return
	if actor_id == 0:
		return
	if value == 2:
		message = "角色 #%d 是否存在状态 #%d：%s" % [actor_id, selected_state, "是" if RuntimeState.has_state(actor_id, selected_state) else "否"]
	else:
		var result := RuntimeState.clear_states(actor_id) if value == 3 else RuntimeState.change_state(actor_id, selected_state, value == 0)
		message = result.message
		sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	refresh()


func navigate(_direction: int) -> void:
	pass # Mouse selectors, not a new production menu command.


func activate() -> void:
	action(2)


func back() -> void:
	back_requested.emit()

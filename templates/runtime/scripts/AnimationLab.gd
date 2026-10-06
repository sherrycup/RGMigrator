extends Control
## Testing-only viewer: original database animations, not test-skill substitution.
signal back_requested
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Player = preload("res://runtime/scripts/RmxpAnimationPlayer.gd")
const Decoder = preload("res://runtime/scripts/RmxpAnimationData.gd")
const Base = preload("res://runtime/scripts/WindowBase.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
var _ids: Array[int] = []
var _selector: OptionButton
var _status: Label
var _count: Label
var _host: Node2D
var _targets: Array[ColorRect] = []
var _instances: Array[Node] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: Control = Base.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	background.label("原工程动画 · 多实例测试", Rect2(0, 0, size.x - 32, 28), Color("c0e0ff"))
	_selector = OptionButton.new()
	_selector.position = Vector2(16, 52)
	_selector.size = Vector2(size.x - 32, 32)
	_selector.add_theme_font_override("font", Resources.font())
	add_child(_selector)
	for definition in Data.database("Animations"):
		if definition is Dictionary and int(definition.get("id", 0)) > 0:
			_ids.append(int(definition.id))
			_selector.add_item("#%d %s" % [definition.id, definition.get("name", "")])
	for index in _ids.size():
		if Decoder.resolve(_ids[index]).ok:
			_selector.select(index)
			break
	background.label("原始帧数据和素材；可重复播放，同一目标也不会取消前一个。", Rect2(0, 76, size.x - 32, 44), Color.WHITE, 15)
	_host = Node2D.new()
	add_child(_host)
	for index in 2:
		var target := ColorRect.new()
		target.position = Vector2(size.x * (0.30 if index == 0 else 0.70) - 20, size.y * 0.47 - 28)
		target.size = Vector2(40, 56)
		target.color = Color("5796ce") if index == 0 else Color("ce9657")
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_host.add_child(target)
		_targets.append(target)
	var actions := HBoxContainer.new()
	actions.position = Vector2(16, size.y - 138)
	add_child(actions)
	for entry in [["左侧播放", 0], ["右侧播放", 1], ["双位置同时", 2], ["同目标叠加", 3], ["停止全部", 4], ["返回", 5]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", Resources.font())
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(action.bind(int(entry[1])))
		actions.add_child(button)
	_count = background.label("", Rect2(0, size.y - 108, size.x - 32, 28), Color("c0e0ff"), 17)
	_status = background.label("鼠标选择动画和测试按钮；↑↓选择动画，确认在左侧追加播放，Esc 返回。", Rect2(0, size.y - 76, size.x - 32, 56), Color("ffe9a8"), 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _process(_delta: float) -> void:
	# Check raw entries before any typed callable conversion: a finished player
	# can already have been freed between rendered frames.
	for index in range(_instances.size() - 1, -1, -1):
		if not is_instance_valid(_instances[index]) or _instances[index].is_queued_for_deletion():
			_instances.remove_at(index)
	_count.text = "活动动画实例：%d（同一目标可同时存在多个）" % _instances.size()


func play_at(target_index: int, animation_id: int = 0) -> Dictionary:
	if _ids.is_empty():
		return {"ok": false, "message": "原工程没有动画定义。"}
	if _instances.size() >= 32:
		return {"ok": false, "message": "测试界面最多同时保留 32 个实例，请等待结束或停止全部。"}
	var id := _ids[_selector.selected] if animation_id == 0 else animation_id
	var target: CanvasItem = _targets[target_index]
	var result := Player.play(_host, id, func() -> CanvasItem: return target)
	if result.ok and result.has("player"):
		_instances.append(result.player)
	return result


func action(value: int) -> void:
	if value == 5:
		back()
		return
	if value == 4:
		stop_all()
		_status.text = "已停止全部测试实例。"
		return
	var result := play_at(1 if value == 1 else 0)
	if result.ok and value in [2, 3]:
		result = play_at(1 if value == 2 else 0)
	_status.text = "已追加播放原动画 #%d；已有实例继续播放。" % _ids[_selector.selected] if result.ok else result.message


func navigate(direction: int) -> void:
	if not _ids.is_empty():
		_selector.select(posmod(_selector.selected + direction, _ids.size()))


func activate() -> void:
	action(0)


func stop_all() -> void:
	for instance in _instances:
		if is_instance_valid(instance):
			instance.stop()
	_instances.clear()


func back() -> void:
	stop_all()
	back_requested.emit()

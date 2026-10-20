## 职责：将闪翼消息控制器接入地图覆盖层，管理显示节点和界面归属。
##
## 调用方式：
##   脚本由所属场景或插件挂载；下列回调由 Godot 调用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _unhandled_key_input(event: InputEvent) -> void
##     event：输入事件或当前游戏事件对象，类型见签名。
##
## 接口说明结束。

extends Control
const UIInput = preload("../04_UI_Common/UIInput.gd")
## Single renderer/60Hz driver for RuntimeState.flash_messages in Scene_Map.
var controller: RefCounted
var _views: Dictionary = {}


func _ready() -> void:
	controller = RuntimeState.flash_messages
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if controller == null:
		return
	# 历史/菜单暂停地图时保留消息现场，隐藏其绘制，避免两个文字层叠在一起。
	visible = not get_tree().paused
	controller.relayout(get_viewport().get_visible_rect().size)
	if not get_tree().paused:
		controller.advance(delta)
	var ids: Array = []
	for entry in controller.boxes:
		ids.append(entry.id)
		if not _views.has(entry.id):
			var view = preload("MessageView.gd").new()
			view.entry = entry
			add_child(view)
			_views[entry.id] = view
		_views[entry.id].entry = entry
		_views[entry.id].refresh(RuntimeState, controller.viewport_size)
	for id in _views.keys():
		if id not in ids:
			_views[id].queue_free()
			_views.erase(id)


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		controller == null
		or get_tree().paused
		or not UIInput.accepts(event, [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT])
	):
		return
	if controller.handle_key(UIInput.key(event)):
		get_viewport().set_input_as_handled()

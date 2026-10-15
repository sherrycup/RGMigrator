extends Control
## Single renderer/60Hz driver for RuntimeState.flash_messages in Scene_Map.
var controller: RefCounted
var _views: Dictionary={}

func _ready() -> void:
	controller=RuntimeState.flash_messages
	process_mode=Node.PROCESS_MODE_ALWAYS; mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if controller==null: return
	controller.viewport_size=get_viewport().get_visible_rect().size
	if not get_tree().paused: controller.advance(delta)
	var ids: Array=[]
	for entry in controller.boxes:
		ids.append(entry.id)
		if not _views.has(entry.id):
			var view=preload("FlashMessageView.gd").new(); view.entry=entry; add_child(view); _views[entry.id]=view
		_views[entry.id].entry=entry
		_views[entry.id].refresh(RuntimeState,controller.viewport_size)
	for id in _views.keys():
		if id not in ids: _views[id].queue_free(); _views.erase(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if controller==null or get_tree().paused or not event is InputEventKey or not event.pressed: return
	if event.echo and event.keycode not in [KEY_UP,KEY_DOWN]: return
	if controller.handle_key(event.keycode): get_viewport().set_input_as_handled()

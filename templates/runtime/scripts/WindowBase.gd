extends Control
## RMXP skin layout, implemented with retained Godot canvas controls.
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
var content: Control
var _cursor: Control
var _elapsed := 0.0
var _skin_root: Control
var _skin_name := "\u0001"
var _skin_overridden := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", Resources.font())
	add_theme_font_size_override("font_size", 20)
	_skin_root = Control.new()
	_skin_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_skin_root)
	_apply_skin()
	RuntimeState.system_settings_changed.connect(_refresh_skin)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16
	content.offset_top = 16
	content.offset_right = -16
	content.offset_bottom = -16
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	set_process(false)


func _refresh_skin() -> void:
	if _skin_name == RuntimeState.windowskin_name() and _skin_overridden == (RuntimeState.system_settings.windowskin_override != null): return
	var area := Rect2(_cursor.position, _cursor.size)
	var active := _cursor.visible
	remove_child(_cursor)
	_cursor.queue_free()
	for child in _skin_root.get_children():
		_skin_root.remove_child(child)
		child.queue_free()
	_apply_skin()
	_cursor.position = area.position
	_cursor.size = area.size
	_cursor.visible = active
	move_child(_cursor, 1)

func _apply_skin() -> void:
	var skin_name := RuntimeState.windowskin_name()
	_skin_name = skin_name
	_skin_overridden = RuntimeState.system_settings.windowskin_override != null
	var skin := Cache.windowskin(skin_name)
	if skin != null and skin.get_width() == 192 and skin.get_height() == 128:
		var background := TextureRect.new()
		background.texture = Cache.region("Windowskins", skin_name, Rect2(0, 0, 128, 128))
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 2
		background.offset_top = 2
		background.offset_right = -2
		background.offset_bottom = -2
		background.modulate.a = 0.9
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skin_root.add_child(background)
		var border := _patch(Cache.region("Windowskins", skin_name, Rect2(128, 0, 64, 64)), 16)
		border.draw_center = false
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_skin_root.add_child(border)
		_cursor = _patch(Cache.region("Windowskins", skin_name, Rect2(128, 64, 32, 32)), 2)
	elif skin_name.is_empty() and RuntimeState.system_settings.windowskin_override != null:
		var cursor := ColorRect.new()
		cursor.color = Color.TRANSPARENT
		_cursor = cursor
	else:
		RuntimeState.report_diagnostic("System.windowskin_name：%s 缺失或不是 192×128 窗口皮肤；使用 Godot 简易样式，不载入 RTP。" % skin_name)
		var panel := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("18264de6")
		style.border_color = Color("bcccf4")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", style)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skin_root.add_child(panel)
		var cursor := ColorRect.new()
		cursor.color = Color("80a8d966")
		_cursor = cursor
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	add_child(_cursor)


func label(text: String, rectangle: Rect2, color: Color = Color.WHITE, font_size: int = 20) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rectangle.position
	node.size = rectangle.size
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color.BLACK)
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.add_theme_font_size_override("font_size", font_size)
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(node)
	return node


func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func select_rect(rectangle: Rect2, active: bool = true) -> void:
	_cursor.position = rectangle.position + Vector2(16, 16)
	_cursor.size = rectangle.size
	_cursor.visible = active
	set_process(active)


func _process(delta: float) -> void:
	_elapsed += delta
	_cursor.modulate.a = 0.65 + 0.35 * cos(_elapsed * TAU)


func _patch(texture: Texture2D, margin: int) -> NinePatchRect:
	var node := NinePatchRect.new()
	node.texture = texture
	node.patch_margin_left = margin
	node.patch_margin_right = margin
	node.patch_margin_top = margin
	node.patch_margin_bottom = margin
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## 职责：提供通用窗口背景、内容区域和基础绘制能力，供具体游戏窗口继承。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/04_UI_Common/WindowBase.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func label( text: String, rectangle: Rect2, color: Color = Color.WHITE, font_size: int = 20 ) -> Label
##     参数 text（String；必填）：需要解析、显示或保存的文本。
##     参数 rectangle（Rect2；必填）：绘制矩形的位置与尺寸。
##     参数 color（Color；默认值 Color.WHITE）：绘制或效果使用的颜色。
##     参数 font_size（int；默认值 20）：字体尺寸。
##     返回：Label 类型的对象或值，供调用方继续使用。
##
##   func clear_content() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func select_rect(rectangle: Rect2, active: bool = true) -> void
##     参数 rectangle（Rect2；必填）：绘制矩形的位置与尺寸。
##     参数 active（bool；默认值 true）：当前活动状态或活动对象。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

extends Control
## RMXP skin layout, implemented with retained Godot canvas controls.
const Resources = preload("res://runtime/scripts/04_UI_Common/UIResources.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const Layout = preload("UILayout.gd")
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
	_skin_root.z_index = Layout.LAYER_FRAME
	_skin_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_skin_root)
	_apply_skin()
	RuntimeState.system_settings_changed.connect(_refresh_skin)
	content = Control.new()
	content.z_index = Layout.LAYER_CONTENTS
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = Layout.WINDOW_MARGIN
	content.offset_top = Layout.WINDOW_MARGIN
	content.offset_right = -Layout.WINDOW_MARGIN
	content.offset_bottom = -Layout.WINDOW_MARGIN
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	set_process(false)


func _refresh_skin() -> void:
	if (
		_skin_name == RuntimeState.windowskin_name()
		and _skin_overridden == (RuntimeState.system_settings.windowskin_override != null)
	):
		return
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
		RuntimeState.report_diagnostic(
			"System.windowskin_name：%s 缺失或不是 192×128 窗口皮肤；使用 Godot 简易样式，不载入 RTP。" % skin_name
		)
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
	_cursor.z_index = Layout.LAYER_CURSOR
	_cursor.visible = false
	add_child(_cursor)


func label(
	text: String, rectangle: Rect2, color: Color = Color.WHITE, font_size: int = 20
) -> Label:
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
	node.clip_text = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(node)
	return node


func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func select_rect(rectangle: Rect2, active: bool = true) -> void:
	var area = rectangle.intersection(Rect2(Vector2.ZERO, Layout.content_rect(size).size))
	_cursor.position = area.position + Vector2.ONE * Layout.WINDOW_MARGIN
	_cursor.size = area.size.max(Vector2.ZERO)
	_cursor.visible = active and area.has_area()
	set_process(_cursor.visible)


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + maxf(0, delta), 1.0)
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

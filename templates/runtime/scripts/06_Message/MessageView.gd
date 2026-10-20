## 职责：根据消息状态与布局绘制文字、窗口和附属元素，转发显示侧输入。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/06_Message/MessageView.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func refresh(owner: Object, viewport_size: Vector2) -> void
##     用途：按当前状态刷新显示或缓存。
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 viewport_size（Vector2；必填）：当前视口的宽度与高度，单位为像素。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _draw() -> void
##
## 接口说明结束。

extends Control
## Source TextBox/HintBox sprites. This node contains no message timing or state.
const Text = preload("MessageText.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
var entry: Dictionary = {}
var _body: Control
var _geometry: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.clip_contents = true
	add_child(_body)
	_body.draw.connect(_draw_text)


func refresh(owner: Object, viewport_size: Vector2) -> void:
	var model: RefCounted = entry.model
	var layout: RefCounted = entry.layout
	_geometry = layout.geometry(owner, viewport_size, model)
	var rect: Rect2 = _geometry.rect
	position = rect.position
	size = rect.size + Vector2(0, 50)
	pivot_offset = _geometry.point - position
	scale = Vector2.ONE * model.zoom()
	modulate.a = 1
	_body.position = layout.text_origin
	_body.size = layout.text_size
	_body.modulate.a = model.opacity()
	queue_redraw()
	_body.queue_redraw()


func _draw() -> void:
	if entry.is_empty():
		return
	var model: RefCounted = entry.model
	var layout: RefCounted = entry.layout
	var frame = Cache.windowskin("MessageBox_Frame.png")
	var opacity = model.frame_opacity()
	var contents_opacity = model.opacity()
	var rectangle = Rect2(0, 25, layout.box_size.x, layout.box_size.y)
	draw_rect(rectangle.grow(-16), Color(1, 1, 1, 230.0 / 255 * opacity))
	if frame != null:
		RenderingServer.canvas_item_add_nine_patch(
			get_canvas_item(),
			rectangle,
			Rect2(0, 0, 32, 32),
			frame.get_rid(),
			Vector2(16, 16),
			Vector2(16, 16),
			RenderingServer.NINE_PATCH_STRETCH,
			RenderingServer.NINE_PATCH_STRETCH,
			false,
			Color(1, 1, 1, opacity)
		)
	if not model.metadata.has("al") and frame != null and not _geometry.is_empty():
		draw_texture_rect_region(
			frame,
			_geometry.arrow,
			Rect2(32, 4 if _geometry.upper else 16, 16, 12),
			Color(1, 1, 1, opacity)
		)
	if not layout.face_name.is_empty():
		var face = Cache.face(layout.face_name)
		if face != null:
			draw_texture_rect_region(
				face,
				Rect2(8, 32, 96, 96),
				Rect2(layout.face_index % 4 * 96, int(layout.face_index / 4) * 96, 96, 96),
				Color(1, 1, 1, contents_opacity)
			)
	if not layout.name_text.is_empty():
		var style = Text.defaults()
		style.font_size = 24
		draw_string(
			Text.font(style),
			Vector2(layout.text_origin.x, 32 + Text.font(style).get_ascent(24)),
			layout.name_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			layout.text_size.x,
			24,
			Color(96.0 / 255, 64.0 / 255, 32.0 / 255, contents_opacity)
		)
		for row in 4:
			var width = layout.text_size.x * 0.8
			var start = Vector2(layout.text_origin.x + row, 52 + row)
			var tint = Color(
				180.0 / 255, 32.0 / 255, 32.0 / 255, (160 - row * 40) / 255.0 * contents_opacity
			)
			draw_polygon(
				PackedVector2Array(
					[
						start,
						start + Vector2(width, 0),
						start + Vector2(width, 1),
						start + Vector2(0, 1)
					]
				),
				PackedColorArray([tint, Color.TRANSPARENT, Color.TRANSPARENT, tint])
			)
	if entry.kind == "number" and model.state == 3:
		var style = Text.defaults()
		var text = str(entry.number).pad_zeros(int(entry.payload.digits))
		var font = Text.font(style)
		var input_origin = Vector2(
			layout.text_origin.x, layout.text_origin.y + layout.text_size.y + 2
		)
		var digit = int(entry.get("digit_index", 0))
		var cursor_x = (
			font.get_string_size(text.substr(0, digit), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		)
		var cursor_width = font.get_string_size(text[digit], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_rect(
			Rect2(input_origin + Vector2(cursor_x + 3, 0), Vector2(cursor_width + 2, 26)),
			Color(0.7, 0.7, 0.7, 0.5 * contents_opacity)
		)
		draw_string(
			font,
			input_origin + Vector2(4, font.get_ascent(20)),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color(0, 0, 0, contents_opacity)
		)


func _draw_text() -> void:
	if entry.is_empty():
		return
	var model: RefCounted = entry.model
	var layout: RefCounted = entry.layout
	if entry.kind == "choice" and model.state == 3:
		if int(entry.choice_index) < layout.choice_rects.size():
			var rect: Rect2 = layout.choice_rects[entry.choice_index]
			rect.position.y = float(entry.get("cursor_y", rect.position.y)) - model.page_scroll
			var phase = int(entry.get("cursor_phase", 0))
			var alpha = (32 + 4 * (phase if phase <= 24 else 48 - phase)) / 255.0
			_body.draw_rect(rect, Color(0.75, 0.75, 0.75, alpha))
	for painted in model.painted:
		if not layout.positions.has(painted.get("token_index", -1)):
			continue
		var position_value: Dictionary = layout.positions[painted.token_index]
		var point = Vector2(position_value.x, position_value.y - model.page_scroll)
		if point.y < 0:
			continue  # Source page-on clears the scrolled bitmap area.
		var style: Dictionary = painted.style
		var tint = Text.color(int(style.color))
		tint.a *= clampf(float(style.opacity) / 255, 0, 1)
		if painted.kind == "glyph":
			var font = Text.font(style)
			_body.draw_string(
				font,
				point + Vector2(0, font.get_ascent(int(style.font_size))),
				painted.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				int(style.font_size),
				tint
			)
		elif painted.kind == "icon":
			var icon = Cache.icon(painted.name)
			if icon != null:
				_body.draw_texture(
					icon, point + Vector2(2, 0), Color(1, 1, 1, float(style.opacity) / 255)
				)

## 职责：使用原标签、音量槽和四角光标绘制设置页，操作同一份应用偏好。
##
## 调用方式：
##   Title或菜单创建并加入场景树；直接使用RuntimeState.flash_preferences，不复制另一套选项。
##   单独在地图菜单使用时entrance默认16；标题通过set_title_progress设置0—16入场和返回帧，页面不重复推进父过渡。
##   方向键选择与调整，Q/E切原三页，Esc/X发出back_requested；后两页未完成设置沿用源行为。
##
## 调用接口：
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_title_progress(value: int) -> void
##     用途：由标题唯一入场时钟设置显示进度；地图单独使用时默认完成入场。
##     参数 value（int；必填）：原16帧过渡的已显示帧数，夹取到0—16。
##     返回：无返回值；更新绘制位置与透明度。
##
##   func adjust(direction: int) -> void
##     参数 direction（int；必填）：选择或调整的方向增量；正负号按当前页面的导航逻辑处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：请求持有方关闭设置页并恢复原入口光标。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _draw() -> void
##
## 接口说明结束。

extends Control
## 最终0143：原标签、十格音量、四角光标和Q/E页签；设置仍写同一个FlashPreferences。
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
const Palette = preload("../04_UI_Common/Palette.gd")
signal back_requested
var page = "flash_config"
var sheet = 1
var index = 0
var entrance = 16
var _font: Font
static var _panel_texture: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Resources.font()
	RuntimeState.flash_preferences.changed.connect(refresh)
	resized.connect(refresh)
	if _panel_texture == null:
		var bitmap = load("res://runtime/scripts/04_UI_Common/Bitmap.gd").new(592, 400)
		for inset in 17:
			bitmap.fill_rect(
				Rect2i(inset, inset, 592 - inset * 2, 400 - inset * 2),
				Color8(0, 16, 32, 6 if inset == 0 else inset * 12)
			)
		bitmap.draw_line(0, 16, 118, 394, 16, 22)
		bitmap.draw_line(0, 16, 80, 266, 16, 13)
		bitmap.draw_line(592, 576, 473, 197, 384, 10)
		bitmap.draw_line(400, 384, 320, 133, 576, 7)
		_panel_texture = bitmap.texture()
	refresh()


func refresh() -> void:
	queue_redraw()


func set_title_progress(value: int) -> void:
	entrance = clampi(value, 0, 16)
	refresh()


func adjust(direction: int) -> void:
	if sheet != 1:
		return
	var prefs = RuntimeState.flash_preferences
	if index in [0, 1]:
		prefs.set_volume(
			"bgm" if index == 0 else "se",
			clampi((prefs.bgm_volume if index == 0 else prefs.se_volume) + direction, 0, 10)
		)
	elif index == 2:
		prefs.change_window_size(direction)
	elif index == 3:
		prefs.next_run_mode()
	refresh()


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back_requested.emit()
	elif key in [KEY_Q, KEY_E]:
		sheet = posmod(sheet - 1 + (-1 if key == KEY_Q else 1), 3) + 1
		index = 0
		Resources.play_sound(self, "cursor_se")
		refresh()
	elif key in [KEY_UP, KEY_DOWN]:
		index = posmod(index + (-1 if key == KEY_UP else 1), 5 if sheet == 1 else 1)
		Resources.play_sound(self, "cursor_se")
		refresh()
	elif key in [KEY_LEFT, KEY_RIGHT]:
		adjust(-1 if key == KEY_LEFT else 1)


func _draw() -> void:
	if _font == null:
		return
	var y = 6 * (16 - entrance)
	draw_set_transform(Vector2(0, y))
	# 原背景独立于contents_opacity；这里只按页面进退整体淡入，以免离场残留底板。
	draw_texture(_panel_texture, Vector2(24, 88), Color(1, 1, 1, entrance / 16.0))
	var alpha = entrance / 16.0
	var color = Palette.color(17)
	color.a *= alpha
	if sheet == 1:
		_picture("config/label_1", Vector2(48, 112), alpha)
		_picture("config/label_2", Vector2(48, 256), alpha)
		_picture("config/label_3", Vector2(48, 368), alpha)
		var prefs = RuntimeState.flash_preferences
		_text("背景音乐", Rect2(80, 152, 120, 48), 22, color)
		_text("音效", Rect2(80, 184, 120, 48), 22, color)
		_text("窗口大小", Rect2(80, 216, 120, 48), 22, color)
		_text(
			["1 倍", "1.25 倍", "1.5 倍", "全屏"][prefs.window_resize],
			Rect2(272, 216, 240, 48),
			20,
			Color(1, 1, 1, alpha)
		)
		_text("奔跑按键设定", Rect2(80, 296, 170, 48), 22, color)
		for row in 2:
			for slot in 10:
				_picture(
					(
						"config/full"
						if slot < (prefs.bgm_volume if row == 0 else prefs.se_volume)
						else "config/empty"
					),
					Vector2(200 + 33 * slot, 174 + 32 * row),
					alpha
				)
		_text(
			"标准模式",
			Rect2(272, 296, 120, 48),
			22,
			Color(1, 1, 1, alpha * (1 if prefs.run_mode == 0 else 0.5))
		)
		_text(
			"按一次切换",
			Rect2(444, 296, 160, 48),
			22,
			Color(1, 1, 1, alpha * (1 if prefs.run_mode == 1 else 0.5))
		)
		for id in 3:
			_text(
				["Normal", "Hard", "Lunatic"][id],
				Rect2(84 + 192 * id, 408, 80, 48),
				24,
				Color(1, 1, 1, alpha),
				HORIZONTAL_ALIGNMENT_CENTER
			)
	elif sheet == 2:
		_picture("config/label_4", Vector2(48, 112), alpha)
	for id in 4:
		_picture(
			"config/" + ["Q", "Left", "Right", "E"][id],
			Vector2(252 + 24 * id + (40 if id > 1 else 0), 444 - (6 if id in [1, 2] else 0)),
			alpha
		)
	_text("%d / 3" % sheet, Rect2(300, 434, 72, 40), 14, color)
	if sheet in [1, 2]:
		_cursor(Rect2(56, [160, 192, 224, 304, 336][index] if sheet == 1 else 160, 528, 32), alpha)
	draw_set_transform(Vector2.ZERO)


func _picture(name: String, point: Vector2, alpha: float) -> void:
	var texture = Cache.title(name)
	if texture != null:
		draw_texture(texture, point, Color(1, 1, 1, alpha))


func _text(
	value: String, rect: Rect2, font_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	# RM draw_text会压缩过宽的一行；保留原字号高度，避免Godot按width截断尾字。
	var measured = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var scale_x = minf(1, rect.size.x / maxf(1, measured))
	var used_width = measured * scale_x
	var shift = (
		(rect.size.x - used_width) / 2
		if align == HORIZONTAL_ALIGNMENT_CENTER
		else rect.size.x - used_width if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0
	)
	var page_offset = Vector2(0, 6 * (16 - entrance))
	draw_set_transform(rect.position + page_offset + Vector2(shift, 0), 0, Vector2(scale_x, 1))
	draw_string(
		_font,
		Vector2(0, (rect.size.y - _font.get_height(font_size)) / 2 + _font.get_ascent(font_size)),
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
	draw_set_transform(page_offset)


func _cursor(rect: Rect2, alpha: float) -> void:
	var texture = Cache.windowskin("FrameM_01")
	if texture == null:
		return
	for column in 2:
		for row in 2:
			draw_texture_rect_region(
				texture,
				Rect2(
					(
						rect.position
						+ Vector2(
							0 if column == 0 else rect.size.x - 11,
							0 if row == 0 else rect.size.y - 10
						)
					),
					Vector2(9, 8)
				),
				Rect2(column * 9, row * 8, 9, 8),
				Color(1, 1, 1, alpha)
			)

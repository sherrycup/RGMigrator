## 职责：恢复标题音乐唱片与成就分类和示例书页；沿用源未完成的曲目与奖励边界。
##
## 调用方式：
##   创建后在加入场景树之前设置kind为music或merit；Title连接back_requested并通过set_title_progress推进父入场。
##   音乐页自身按60Hz推进28帧唱片过渡；成就页自身推进16帧分类和书本显示，父入场由标题唯一时钟负责。
##   原音乐曲目查找为空，成就书仅示例；不切换正式BGM，不发奖，不额外解锁内容。
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
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：附页请求返回标题；成就书打开时先在本页关闭书本，不立即离开分类。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _draw() -> void
##
## 接口说明结束。

extends Control
## 最终0144—0145：CD/唱针演出、成就分类和示例书。原get_new_bitmap为空，不添加试听或奖励逻辑。
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
signal back_requested
var kind = "music"
var index = 0
var book = false
var progress = 22
var old_index = 0
var angle = 0.0
var playing = false
var entrance = 16
var book_progress = 0
var merit_progress = 16
var _clock = 0.0
var _font: Font
var _lines: PackedStringArray = []
var _disc_offsets: Array[float] = [-320.0, 0.0, 320.0]
var _disc_opacities: Array[float] = [0.0, 1.0, 0.0]
var _disc_angles: Array[float] = [0.0, 0.0, 0.0]
var _disc_names: Array[String] = ["CD_1", "CD_1", "CD_1"]
var _pointer_angle = 18.0
var _merit_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _swing = 1
var _merit_from = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Resources.font()
	resized.connect(refresh)
	refresh()


func refresh() -> void:
	if kind == "music":
		var path = "res://legacy/extras/Info/Music/%03d.txt" % index
		_lines = (
			FileAccess.get_file_as_string(path).split("\n")
			if FileAccess.file_exists(path)
			else PackedStringArray()
		)
	queue_redraw()


func set_title_progress(value: int) -> void:
	entrance = clampi(value, 0, 16)
	queue_redraw()


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		if book:
			book = false
			Resources.play_sound(self, "cancel_se")
		elif book_progress == 0:
			back_requested.emit()
		return
	if entrance < 16:
		return
	if kind == "music" and progress == 28 and key in [KEY_UP, KEY_DOWN]:
		old_index = index
		index = posmod(index + (-1 if key == KEY_UP else 1), 10)
		progress = 0
		playing = false
		Resources.play_sound(self, "cursor_se")
		refresh()
	elif kind == "merit" and not book and book_progress == 0 and merit_progress == 16:
		_merit_from = index
		if key in [KEY_LEFT, KEY_RIGHT]:
			index = posmod(index + (-1 if key == KEY_LEFT else 1), 4)
		elif key in [KEY_UP, KEY_DOWN]:
			index = 1 if index > 2 else 3
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
			book = true
			Resources.play_sound(self, "decision_se")
		if index != _merit_from:
			merit_progress = 0
			Resources.play_sound(self, "cursor_se")
		queue_redraw()


func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	_clock += delta * 60
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	for i in ticks:
		if kind == "music":
			_music_tick()
		else:
			book_progress = clampi(book_progress + (1 if book else -1), 0, 16)
			merit_progress = mini(16, merit_progress + 1)
			if merit_progress == 16 and not book:
				_merit_angles[index] += 0.6 * _swing
				if absf(_merit_angles[index]) >= 15:
					_swing *= -1
	queue_redraw()


func _music_tick() -> void:
	if playing:
		_disc_angles[1] = fposmod(_disc_angles[1] + 1, 360)
		angle = _disc_angles[1]
	if progress == 28:
		return
	progress += 1
	if progress <= 6:
		_pointer_angle += 3
	elif progress <= 22:
		var side = 2 if index > old_index else 0
		var movement = -20 if side == 2 else 20
		_disc_offsets[1] += movement
		_disc_offsets[side] += movement
		_disc_opacities[1] = maxf(0, _disc_opacities[1] - 16.0 / 255)
		_disc_opacities[side] = minf(1, _disc_opacities[side] + 16.0 / 255)
	else:
		_pointer_angle -= 3
	if progress == 28:
		playing = true
		if index != old_index:
			# 原循环精灵复用；get_new_bitmap原本为空，邻盘恢复CD.png，不伪造曲目封面。
			var side = 2 if index > old_index else 0
			_disc_names = ["CD", _disc_names[side], "CD"]
			_disc_angles = [0.0, _disc_angles[side], 0.0]
			_disc_offsets = [-320.0, 0.0, 320.0]
			_disc_opacities = [0.0, 1.0, 0.0]
		old_index = index


func _draw() -> void:
	if _font == null:
		return
	if kind == "music":
		_draw_music()
	else:
		_draw_merit()


func _draw_music() -> void:
	var alpha = entrance / 16.0
	for id in 3:
		var texture = Cache.title("music/" + _disc_names[id])
		if texture != null and _disc_opacities[id] > 0:
			draw_set_transform(
				Vector2(size.x / 2 + _disc_offsets[id], 225), -deg_to_rad(_disc_angles[id])
			)
			draw_texture(texture, Vector2(-129, -129), Color(1, 1, 1, _disc_opacities[id] * alpha))
	draw_set_transform(Vector2.ZERO)
	var pointer = Cache.title("music/point")
	if pointer != null:
		draw_set_transform(Vector2(size.x / 2, -200 + 12 * entrance), -deg_to_rad(_pointer_angle))
		draw_texture(pointer, Vector2(-11, -11), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)
	var top = 576 - 12 * entrance
	draw_rect(
		Rect2(32, top, 576, 224), Color(192.0 / 255, 192.0 / 255, 192.0 / 255, 128.0 / 255 * alpha)
	)
	for row in _lines.size():
		var y = top if row == 0 else top + 26 * (row + 1)
		_text(
			_lines[row].strip_edges(),
			Rect2(32, y, 576, 32),
			20,
			Color(1, 1, 1, alpha),
			HORIZONTAL_ALIGNMENT_CENTER if row == 0 else HORIZONTAL_ALIGNMENT_LEFT
		)


func _draw_merit() -> void:
	var alpha = entrance / 16.0
	var category_alpha = maxf(0, 1 - book_progress * 16 / 255.0) * alpha
	for id in 4:
		var center = Vector2(
			128 + id % 3 * 192 if id < 3 else 320, 227 + int(id / 3) * 200 + 12 * (16 - entrance)
		)
		var raised = lerpf(
			1.0 if id == _merit_from else 0.0, 1.0 if id == index else 0.0, merit_progress / 16.0
		)
		center.y -= 8 * raised
		var texture = Cache.title("merit/chap_%d" % id)
		if texture != null:
			var zoom = 1 + 0.2 * book_progress if id == index else 1.0
			draw_set_transform(center, -deg_to_rad(_merit_angles[id]), Vector2.ONE * zoom)
			draw_texture(texture, Vector2(-96, -99), Color(1, 1, 1, category_alpha))
	draw_set_transform(Vector2.ZERO)
	if merit_progress < 16 and index != _merit_from:
		var outgoing = Cache.title("merit/merit_%d" % _merit_from)
		if outgoing != null:
			var offset = (
				Vector2(-8, 588 + 3 * merit_progress)
				if index > _merit_from
				else Vector2(-8 - 21 * merit_progress, 588)
			)
			draw_texture(outgoing, offset, Color(1, 1, 1, category_alpha))
	var caption = Cache.title("merit/merit_%d" % index)
	if caption != null:
		var progress_value = merit_progress / 16.0
		var offset = (
			Vector2(-328 + 336 * progress_value, 588)
			if index > _merit_from
			else Vector2(-8, 636 - 48 * progress_value)
		)
		if index == _merit_from:
			offset = Vector2(-8, 588)
		offset.x -= 20 * (16 - entrance)
		draw_texture(caption, offset, Color(1, 1, 1, category_alpha))
	if book_progress == 0:
		return
	var book_alpha = minf(1, book_progress * 16 / 255.0) * alpha
	var texture = Cache.title("merit/book2")
	if texture != null:
		draw_texture(texture, Vector2(0, 96), Color(1, 1, 1, book_alpha))
	var medal = Cache.title("merit/medal")
	if medal != null:
		draw_texture_rect_region(
			medal, Rect2(112, 112, 48, 63), Rect2(0, 0, 48, 63), Color(1, 1, 1, book_alpha)
		)
	# 原示例sign没有接入成品；已移植可读示例下移24px到纸面内，防止首行被书边遮住。
	for row in 4:
		var color = Color(0.25, 0.17, 0.09, book_alpha)
		_text("通过考试", Rect2(192, 112 + row * 96, 160, 48), 22, color, HORIZONTAL_ALIGNMENT_CENTER)
		_text("和艾蕾两人成功通过入会", Rect2(176, 152 + row * 96, 192, 36), 18, color)
		_text("考试", Rect2(176, 168 + row * 96, 192, 36), 18, color)
		_text("获得200金币", Rect2(120, 192 + row * 96, 273, 36), 14, color)


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
	var page_offset = Vector2.ZERO
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

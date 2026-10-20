## 职责：读取档案页快照，绘制原章节、卡片、角色摘要、截图框和自绘确认框，不执行存读档。
##
## 调用方式：
##   FlashArchivePage创建并设置page；本节点只读取目录和选择快照，不调用存档写入或读取安装。
##   标题档案和地图档案采用各自原章节位置；卡片使用240×256裁切视口和独立120×64光标。
##
## 调用接口：
##   func positions() -> Dictionary
##     用途：计算原窗口进入/退出时的本地坐标。
##     参数：无。
##     返回：kind/chapter/files/snapshot/players五个窗口的左上坐标。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_cards(target: Control) -> void
##     用途：由卡片裁切子画布绘制当前可见原卡片与插值光标。
##     参数 target（Control；必填）：操作或效果作用的目标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_confirmation(target: Control) -> void
##     用途：由最上层画布绘制原图风格的覆盖/备份确认。
##     参数 target（Control；必填）：操作或效果作用的目标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _draw() -> void
##
## 接口说明结束。

extends Control
## 最终0170—0173、0186的绘制。只读取所属页的目录快照，不读写存档或正式角色。
const Drawing = preload("../04_UI_Common/WindowDrawing.gd")
const Bitmap = preload("../04_UI_Common/Bitmap.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const Palette = preload("../04_UI_Common/Palette.gd")
const Character = preload("../03_Map/CharacterSprite.gd")


class Cards:
	extends Control
	var owner_view: Control

	func _draw() -> void:
		owner_view.draw_cards(self)


class Overlay:
	extends Control
	var owner_view: Control

	func _draw() -> void:
		owner_view.draw_confirmation(self)


var page: Control
var _font: Font
var _cards: Control
var _overlay: Control
var _preview: TextureRect
var _card: Texture2D
var _chapter_panel: Texture2D
var _meters: Texture2D
var _meter_signature = ""
var _portraits: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Resources.font()
	var chapter_bitmap = Bitmap.new(192, 112)
	chapter_bitmap.image = Drawing.panel(Vector2i(192, 112)).get_image().duplicate()
	chapter_bitmap.draw_line(0, 16, 38, 128, 48, 2)
	_chapter_panel = chapter_bitmap.texture()
	_cards = Cards.new()
	_cards.owner_view = self
	_cards.size = Vector2(240, 256)
	_cards.clip_contents = true
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	_preview = TextureRect.new()
	_preview.size = Vector2(352, 352)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.texture = page._preview_surface.get_texture()
	add_child(_preview)
	for id in 2:
		var portrait = Character.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portrait)
		_portraits.append(portrait)
	_overlay = Overlay.new()
	_overlay.owner_view = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_build_card()
	resized.connect(refresh)
	refresh()


func positions() -> Dictionary:
	var offset = 8 - page.window_process
	return {
		"kind": Vector2(8, 8 - 8 * offset),
		"chapter": Vector2(size.x - 208 if page.allow_mode_switch else 8, 8 - 8 * offset),
		"files": Vector2(16 if page.allow_mode_switch else 8, 136) - Vector2(12 * offset, 0),
		"snapshot": Vector2(size.x - 344 + 12 * offset, 136),
		"players": Vector2(80, 488 + 12 * offset)
	}


func refresh() -> void:
	if not is_inside_tree() or _cards == null:
		return
	var points = positions()
	var tint = Color(1, 1, 1, minf(1, page.window_process * 32.0 / 255))
	_cards.position = points.files + Vector2(16, 48)
	_cards.modulate = tint
	_preview.position = points.snapshot
	_preview.modulate = tint
	var rows: Array = page._current.get("players", [])
	for id in _portraits.size():
		var portrait = _portraits[id]
		portrait.visible = id < rows.size()
		if id >= rows.size():
			continue
		var row: Dictionary = rows[id]
		var signature = str(row.char_name) + ":" + str(row.char_hue)
		if portrait.get_meta("signature", "") != signature:
			portrait.configure(row.char_name, int(row.char_hue), 2, 0)
			portrait.size = portrait._frame_size
			portrait.set_meta("signature", signature)
		portrait.position = points.players + Vector2(36 + 232 * id, 56)
		portrait.modulate = tint
	_cards.queue_redraw()
	_overlay.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if _font == null or page.window_process == 0:
		return
	var points = positions()
	var alpha = minf(1, page.window_process * 32.0 / 255)
	var tint = Color(1, 1, 1, alpha)
	if page.allow_mode_switch:
		var mode_progress = page._mode_ticks / 8.0
		if mode_progress < 1:
			_draw_kind(
				points.kind - Vector2(0, 64 * mode_progress),
				page._mode_from,
				alpha * (1 - mode_progress)
			)
		_draw_kind(
			points.kind - Vector2(0, 64 * (1 - mode_progress)), page.mode, alpha * mode_progress
		)
	draw_texture(_chapter_panel, points.chapter - Vector2(8, 8), tint)
	var chapter = int(page._current.get("chapter", -1))
	if chapter == 0:
		_text(
			Rect2(points.chapter + Vector2(8, 12), Vector2(160, 25)),
			"Chapter 0",
			18,
			Palette.color(17),
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_text(
			Rect2(points.chapter + Vector2(8, 60), Vector2(112, 25)),
			"摸鱼",
			18,
			Palette.color(17),
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	elif chapter == 1:
		var rect = Rect2(points.chapter + Vector2(8, 16), Vector2(112, 25))
		_text(rect, "Chapter 1", 18, Palette.color(17), alpha, HORIZONTAL_ALIGNMENT_CENTER)
		for y in [8, 16]:
			draw_line(
				rect.position + Vector2(8, y),
				rect.position + Vector2(88, y),
				Color(0.75, 0.88, 1, alpha)
			)
	draw_texture(Drawing.panel(Vector2i(288, 336)), points.files - Vector2(8, 8), tint)
	_text(
		Rect2(points.files + Vector2(16, 16), Vector2(240, 32)), "自动存档档案编号：", 18, Color.WHITE, alpha
	)
	draw_line(
		points.files + Vector2(16, 48),
		points.files + Vector2(256, 48),
		Color(0.7, 0.9, 1, alpha * 0.5)
	)
	if page._slots.is_empty():
		_text(
			Rect2(points.files + Vector2(16, 96), Vector2(240, 48)),
			"没有档案",
			18,
			Palette.color(17),
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	draw_texture(Drawing.panel(Vector2i(352, 352)), points.snapshot - Vector2(8, 8), tint)
	if str(page._current.get("png", "")).is_empty():
		_text(
			Rect2(points.snapshot + Vector2(16, 144), Vector2(304, 40)),
			"无截图",
			18,
			Palette.color(17),
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	_draw_players(points.players, alpha)
	if not page.message.is_empty():
		# 原Tips没有接入最终Scene_Map；仅在真实失败时使用空白区显示读写诊断。
		_text(
			Rect2(Vector2(160, 16), Vector2(maxf(160, size.x - 384), 88)),
			page.message,
			14,
			Color(1, 0.7, 0.6),
			alpha
		)


func _draw_kind(point: Vector2, mode: String, alpha: float) -> void:
	draw_texture(Drawing.panel(Vector2i(144, 96)), point - Vector2(8, 8), Color(1, 1, 1, alpha))
	_text(
		Rect2(point + Vector2(8, 16), Vector2(112, 25)),
		"记录档案" if mode == "save" else "回看档案",
		20,
		Palette.color(17),
		alpha,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_text(
		Rect2(point + Vector2(8, 44), Vector2(112, 25)),
		"TAB键切换模式",
		13,
		Palette.color(17),
		alpha,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _draw_players(point: Vector2, alpha: float) -> void:
	draw_texture(Drawing.panel(Vector2i(480, 128)), point, Color(1, 1, 1, alpha))
	var rows: Array = page._current.get("players", [])
	var signature = JSON.stringify(rows)
	if signature != _meter_signature or _meters == null:
		var bitmap = Bitmap.new(480, 128)
		for id in mini(2, rows.size()):
			var row: Dictionary = rows[id]
			var x = 88 + 232 * id
			for vital in 3:
				var rect = Rect2i(x, [40, 64, 88][vital], 128, 4 if vital == 0 else 6)
				bitmap.draw_hud_back(rect, 0 if vital == 0 else 1)
				var value: Variant = row.get(["exp", "hp", "sp"][vital], 0)
				var maximum: Variant = row.get(["maxexp", "maxhp", "maxsp"][vital], 0)
				bitmap.draw_hud_line(
					rect,
					0 if value == null else value,
					1 if maximum == null else maximum,
					Palette.color([15, 9, 4][vital]),
					Palette.color([12, 3, 1][vital]),
					0 if vital == 0 else 1
				)
		_meters = bitmap.texture()
		_meter_signature = signature
	draw_texture(_meters, point, Color(1, 1, 1, alpha))
	for id in mini(2, rows.size()):
		var row: Dictionary = rows[id]
		var x = 232 * id
		_text(
			Rect2(point + Vector2(24 + x, 26), Vector2(60, 20)),
			"Lv.%d" % row.lv,
			18,
			Palette.color(12),
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		for vital in 3:
			var value: Variant = row.get(["exp", "hp", "sp"][vital], null)
			var maximum: Variant = row.get(["maxexp", "maxhp", "maxsp"][vital], null)
			_text(
				Rect2(point + Vector2(88 + x, [20, 52, 76][vital]), Vector2(128, 20)),
				(
					("" if value == null else str(value))
					+ "/"
					+ ("" if maximum == null else str(maximum))
				),
				18,
				Palette.color([12, 2, 4][vital]),
				alpha,
				HORIZONTAL_ALIGNMENT_RIGHT
			)


func _text(
	rect: Rect2,
	value: String,
	font_size: int,
	color: Color,
	alpha: float,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	color.a *= alpha
	Drawing.text(self, _font, rect, value, font_size, color, align)


func _build_card() -> void:
	var bitmap = Bitmap.new(120, 64)
	bitmap.fill_rect(Rect2i(25, 20, 91, 42), Color8(0, 0, 0, 64))
	for row in 12:
		bitmap.fill_rect(Rect2i(41 - 2 * row, 12 + row, 67 + 2 * row, 1), Color8(255, 224, 255, 64))
	bitmap.fill_rect(Rect2i(17, 24, 91, 30), Color8(255, 224, 255, 64))
	for rect in [
		Rect2i(48, 12, 60, 1),
		Rect2i(107, 12, 1, 20),
		Rect2i(107, 46, 1, 10),
		Rect2i(16, 26, 1, 28),
		Rect2i(16, 54, 44, 1)
	]:
		bitmap.fill_rect(rect, Color8(192, 224, 255))
	for rect in [
		Rect2i(56, 24, 51, 1),
		Rect2i(17, 46, 16, 1),
		Rect2i(17, 48, 28, 1),
		Rect2i(17, 50, 20, 1),
		Rect2i(17, 52, 40, 1)
	]:
		bitmap.fill_rect(rect, Color8(192, 224, 255, 128))
	for y in 11:
		for x in range(2 * y, 43):
			if (x + 3 * y) % 5 == 0:
				bitmap.fill_rect(Rect2i(64 + x, 13 + y, 1, 1), Color8(255, 255, 255, 128))
	_card = bitmap.texture()


func draw_cards(target: Control) -> void:
	for id in page._slots.size():
		var point = Vector2(int(id / 4) * 120 - page._scroll_offset, id % 4 * 64)
		if point.x < -120 or point.x >= 240:
			continue
		var info: Dictionary = page._infos[id]
		var empty = not info.exists and page.mode == "save"
		target.draw_texture(_card, point)
		var label = "New File" if empty else "File%d" % page._slots[id]
		Drawing.text(
			target,
			_font,
			Rect2(point + Vector2(12, 2), Vector2(88, 28)),
			label,
			18,
			Color(1, 1, 1, 0.5)
		)
		Drawing.text(
			target,
			_font,
			Rect2(point + Vector2(8, 0), Vector2(88, 28)),
			label,
			18,
			Palette.color(3)
		)
		if empty:
			Drawing.text(
				target,
				_font,
				Rect2(point + Vector2(0, 6), Vector2(120, 64)),
				"   CREATE",
				16,
				Palette.color(6),
				HORIZONTAL_ALIGNMENT_CENTER
			)
			target.draw_rect(Rect2(point + Vector2(98, 37), Vector2(2, 16)), Color(1, 1, 1, 0.65))
			target.draw_rect(Rect2(point + Vector2(72, 48), Vector2(32, 2)), Color(1, 1, 1, 0.65))
		else:
			var date = str(info.get("saved_at", "")).replace("-", "/")
			Drawing.text(
				target,
				_font,
				Rect2(point + Vector2(0, 28), Vector2(112, 16)),
				date.substr(0, 10) if info.ok else "不可读取",
				16,
				Palette.color(6),
				HORIZONTAL_ALIGNMENT_RIGHT
			)
			Drawing.text(
				target,
				_font,
				Rect2(point + Vector2(0, 44), Vector2(104, 16)),
				date.substr(11, 5),
				16,
				Palette.color(6),
				HORIZONTAL_ALIGNMENT_RIGHT
			)
	if not page._slots.is_empty():
		Drawing.cursor(
			target,
			Rect2(page.cursor_position() - Vector2(page._scroll_offset, 0), Vector2(120, 64)),
			3,
			Vector2(4, 2)
		)


func draw_confirmation(target: Control) -> void:
	if page._confirmation.is_empty() or _font == null:
		return
	var point = size / 2 - Vector2(160, 64)
	target.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.3))
	target.draw_texture(Drawing.panel(Vector2i(320, 128)), point)
	Drawing.text(
		target,
		_font,
		Rect2(point + Vector2(16, 16), Vector2(288, 32)),
		"确认覆盖" if page._confirmation == "overwrite" else "读取上一份备份",
		20,
		Palette.color(17),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	for i in 2:
		var rect = Rect2(point + Vector2(24 + 144 * i, 68), Vector2(128, 36))
		Drawing.text(
			target,
			_font,
			rect,
			"确认" if i == 0 else "取消",
			18,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		if (i == 0) == page._confirmation_accepted:
			Drawing.cursor(target, rect, 1)

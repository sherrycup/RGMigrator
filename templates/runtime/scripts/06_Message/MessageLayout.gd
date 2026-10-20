## 职责：按正式Message源码计算气泡、人物锚点、名字头像、像素分页和多行选项矩形。
##
## 调用方式：
##   控制器在创建或视口尺寸变化时构造；所有尺寸均为逻辑像素。排版不推进时间、事件或历史。
##   source_tokens保留原行/MR信息；tokens为实际执行顺序，positions/rows和page_breaks使用同一词元下标。
##   geometry一次计算边框、箭头及缩放支点，视图读取同一快照；模式3保留原允许出屏行为。
##
## 调用接口：
##   func _init( model: RefCounted, owner: Object, viewport_size: Vector2, choice_source_lines: Array = [], footer: int = 0 ) -> void
##     用途：解析气泡元数据并按实际可用宽高布局文字和分页。
##     参数 model（RefCounted；必填）：持有业务数据或显示状态的模型。
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 viewport_size（Vector2；必填）：当前视口的宽度与高度，单位为像素。
##     参数 choice_source_lines（Array；默认值 []）：每个选项在原始文章中的行号范围Vector2i，左闭右开；由choice_lines(payload)生成。
##     参数 footer（int；默认值 0）：为数字输入预留的底部像素高度，普通消息0、数字输入32。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func anchor(owner: Object) -> Vector2
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     返回：Vector2 类型的对象或值，供调用方继续使用。
##
##   func geometry(owner: Object, viewport_size: Vector2, model: RefCounted) -> Dictionary
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 viewport_size（Vector2；必填）：当前视口的宽度与高度，单位为像素。
##     参数 model（RefCounted；必填）：持有业务数据或显示状态的模型。
##     返回：{rect,point,upper,arrow}：未缩放气泡局部区域、画布人物锚点、朝向和局部箭头矩形。
##
##   func rectangle(owner: Object, viewport_size: Vector2, model: RefCounted) -> Rect2
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 viewport_size（Vector2；必填）：当前视口的宽度与高度，单位为像素。
##     参数 model（RefCounted；必填）：持有业务数据或显示状态的模型。
##     返回：Rect2 类型的对象或值，供调用方继续使用。
##
##   static func choice_lines(payload: Dictionary) -> Array
##     用途：计算每个分支在原始文章中的行号范围。
##     参数 payload（Dictionary；必填）：消息或调用请求的结构化内容。
##     返回：Array[Vector2i]，用于多行/自动换行后仍按分支定位光标。
##
## 接口说明结束。

extends RefCounted
## 原0149—0155的尺寸、人物锚点与源素材坐标。排版只计算，不推进消息时间。
const Text = preload("MessageText.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const UI = preload("../04_UI_Common/UILayout.gd")
const TextLayout = preload("../04_UI_Common/UITextLayout.gd")
var positions: Dictionary = {}
var rows: Array = []
var choice_rects: Array[Rect2] = []
var box_size = Vector2.ZERO
var text_origin = Vector2(8, 32)
var text_size = Vector2.ZERO
var content_height = 0.0
var name_text = ""
var face_name = ""
var face_index = 0
var anchor_event = 0
var fixed_anchor: Variant = null
var failure = ""
var footer_height = 0
var _sources: Array[int] = []
var _row_controls: Dictionary = {}


func _init(
	model: RefCounted,
	owner: Object,
	viewport_size: Vector2,
	choice_source_lines: Array = [],
	footer: int = 0
) -> void:
	footer_height = footer
	if not _metadata(model):
		return
	var available = UI.usable_rect(viewport_size, not owner.switches.get("6", false))
	var margin = 120 if not face_name.is_empty() else 16
	var overhead = 38 if not name_text.is_empty() else 14
	if available.size.x <= margin or available.size.y <= overhead + footer + 50:
		failure = "消息可用区域不足，无法容纳文字和头像。"
		return
	text_origin = Vector2(
		112 if not face_name.is_empty() else 8, 56 if not name_text.is_empty() else 32
	)
	_normalize(model)
	_measure(model, owner, available.size.x - margin)
	if not failure.is_empty():
		return
	var width = 0.0
	for row in rows:
		width = maxf(width, row.width)
	var name_style = Text.defaults()
	name_style.font_size = 24
	if not name_text.is_empty():
		width = maxf(width, maxf(96, TextLayout.measure(name_text, name_style).x))
	if footer > 0:
		width = maxf(width, 8 * 20)
	box_size.x = minf(available.size.x, maxf(32, width + margin))
	for row in rows:
		content_height += row.height + row.space
	box_size.y = minf(
		available.size.y - 50,
		maxf(content_height + overhead + footer, 110 if not face_name.is_empty() else 32)
	)
	text_size = Vector2(box_size.x - margin, maxf(1, box_size.y - overhead - footer))
	_place(model, choice_source_lines)


func anchor(owner: Object) -> Vector2:
	if fixed_anchor != null:
		return fixed_anchor
	var character = (
		owner.player()
		if anchor_event == 0
		else (owner.game().event_map().event_node(anchor_event) if owner.game() != null else null)
	)
	if character == null:
		return Vector2(owner.player_x * 32 + 16, owner.player_y * 32)
	var height = (
		character._texture.get_height() / 4.0
		if (character._texture != null and character._tile_id == 0)
		else 32.0
	)
	return character.get_global_transform_with_canvas().origin + Vector2(16, 48 - height)


func geometry(owner: Object, viewport_size: Vector2, model: RefCounted) -> Dictionary:
	var point = (anchor(owner) + model.offset).round()
	var available = UI.usable_rect(viewport_size, not owner.switches.get("6", false))
	var upper = point.y - box_size.y - 25 > available.position.y
	var origin = Vector2(point.x - box_size.x / 2, point.y - box_size.y - 50 if upper else point.y)
	if model.mode() != 3:
		origin.x = clampf(
			origin.x, available.position.x, maxf(available.position.x, available.end.x - box_size.x)
		)
		# 源边框从局部y=25开始；安全钳制保证完整边框和人物上/下箭头仍可见。
		origin.y = clampf(
			origin.y,
			available.position.y - 13,
			maxf(available.position.y - 13, available.end.y - box_size.y - 37)
		)
	var arrow_x = point.x - origin.x - 7
	if model.mode() != 3:
		arrow_x = clampf(arrow_x, 8, maxf(8, box_size.x - 24))
	return {
		"rect": Rect2(origin, box_size),
		"point": point,
		"upper": upper,
		"arrow": Rect2(arrow_x, box_size.y + 23 if upper else 16, 16, 12)
	}


func rectangle(owner: Object, viewport_size: Vector2, model: RefCounted) -> Rect2:
	return geometry(owner, viewport_size, model).rect


static func choice_lines(payload: Dictionary) -> Array:
	var result: Array = []
	var line = 0
	for text in payload.get("lines", []):
		line += str(text).count("\n") + 1
	for text in payload.get("choices", []):
		var count = str(text).count("\n") + 1
		result.append(Vector2i(line, line + count))
		line += count
	return result


func _metadata(model: RefCounted) -> bool:
	name_text = str(model.metadata.get("m", ""))
	face_name = str(model.metadata.get("f", ""))
	if model.metadata.has("fg"):
		var args = str(model.metadata.fg).rsplit(",", true, 1)
		if args.size() != 2 or not args[1].strip_edges().is_valid_int():
			failure = "消息头像分组参数无效。"
			return false
		face_name = args[0]
		face_index = int(args[1])
	if not face_name.is_empty():
		var face = Cache.face(face_name)
		if (
			face == null
			or face_index < 0
			or face_index % 4 * 96 + 96 > face.get_width()
			or int(face_index / 4) * 96 + 96 > face.get_height()
		):
			failure = "消息头像缺失或分组越界：" + face_name
			return false
	if model.metadata.has("p"):
		var args = str(model.metadata.p).split(",", true)
		if args.size() < 1 or args.size() > 2:
			failure = "消息位置参数无效。"
			return false
		for value in args:
			if not value.strip_edges().is_valid_int():
				failure = "消息位置需要整数坐标或事件ID。"
				return false
		if args.size() == 2:
			fixed_anchor = Vector2(int(args[0]), int(args[1]))
		else:
			anchor_event = int(args[0])
	return true


func _normalize(model: RefCounted) -> void:
	var normalized: Array = []
	var source_line = 0
	var merge_next = false
	for token in model.source_tokens:
		if token is Array and token[0].unicode_at(0) in [27, 28]:
			if not _row_controls.has(normalized.size()):
				_row_controls[normalized.size()] = []
			_row_controls[normalized.size()].append(token)
			continue
		if token is Array and token[0].unicode_at(0) == 18:
			merge_next = true
			continue
		if token is String and token == "\n":
			if not merge_next:
				normalized.append(token)
				_sources.append(source_line)
			source_line += 1
			merge_next = false
			continue
		merge_next = false
		normalized.append(token)
		_sources.append(source_line)
	model.tokens = normalized


func _row(style: Dictionary) -> Dictionary:
	return {
		"indices": [],
		"width": 0.0,
		"height": 0.0,
		"space": int(style.line_space),
		"align": int(style.halign),
		"valign": int(style.valign)
	}


func _measure(model: RefCounted, owner: Object, maximum: float) -> void:
	var style = Text.defaults()
	var row = _row(style)
	for index in model.tokens.size():
		# A/LS是整行设置，原TextRow在打字前取出，不能额外消耗打字逻辑帧。
		for control in _row_controls.get(index, []):
			Text.apply_style(style, control)
			row.space = int(style.line_space)
			row.align = int(style.halign)
			row.valign = int(style.valign)
		var token: Variant = model.tokens[index]
		if token is String and token == "\n":
			row.indices.append(index)
			row.height = maxf(row.height, TextLayout.measure("字", style).y)
			rows.append(row)
			style.line_space = 4
			style.halign = 0
			style.valign = 2
			row = _row(style)
			continue
		var advance = 0.0
		var height = 0.0
		var code = token[0].unicode_at(0) if token is Array else -1
		if code == 17:
			break
		if token is String or code == 2:
			var glyph = (
				token
				if token is String
				else (
					str(owner.custom_data.currency())
					+ str(
						preload("../00_Game/RuntimeData.gd").system().get("words", {}).get(
							"gold", ""
						)
					)
				)
			)
			var measured = TextLayout.measure(glyph, style)
			advance = measured.x
			height = measured.y
		elif code == 24:
			var icon = Cache.icon(str(token[1]))
			if icon == null and not str(token[1]).is_empty():
				failure = "消息图标缺失：" + str(token[1])
				return
			advance = (icon.get_width() if icon != null else 32) + 4
			height = icon.get_height() if icon != null else 32
		elif code == 22:
			advance = int(token[1])
		else:
			Text.apply_style(style, token)
			row.space = int(style.line_space)
			row.align = int(style.halign)
			row.valign = int(style.valign)
		if advance > 0 and row.width > 0 and row.width + advance > maximum:
			rows.append(row)
			row = _row(style)
		positions[index] = {"x": row.width, "height": height, "advance": advance}
		row.indices.append(index)
		row.width += advance
		row.height = maxf(row.height, height)
	if not row.indices.is_empty() or rows.is_empty():
		row.height = maxf(row.height, TextLayout.measure("字", style).y)
		rows.append(row)


func _place(model: RefCounted, choices: Array) -> void:
	model.page_targets.clear()
	model.page_breaks.clear()
	var y = 0.0
	var page_top = 0.0
	for row in rows:
		row.top = y
		if y > page_top and y + row.height + row.space - page_top > text_size.y:
			if not row.indices.is_empty():
				model.page_breaks[row.indices[0]] = y
			page_top = y
		var shift = (
			(text_size.x - row.width) / (2 if row.align == 1 else 1) if row.align in [1, 2] else 0.0
		)
		for index in row.indices:
			if not positions.has(index):
				positions[index] = {"x": 0.0, "height": 0.0, "advance": 0.0}
			var p: Dictionary = positions[index]
			p.x += shift
			p.y = (
				y
				+ row.space / 2.0
				+ (
					(row.height - p.height) / (2 if row.valign == 1 else 1)
					if row.valign in [1, 2]
					else 0.0
				)
			)
			p.row_top = y
			p.source_line = _sources[index]
			if model.tokens[index] is Array and model.tokens[index][0].unicode_at(0) == 6:
				model.page_targets[index] = y
		y += row.height + row.space
	for source_range in choices:
		var top = INF
		var bottom = 0.0
		for row in rows:
			for index in row.indices:
				if _sources[index] >= source_range.x and _sources[index] < source_range.y:
					top = minf(top, row.top)
					bottom = maxf(bottom, row.top + row.height + row.space)
		choice_rects.append(
			Rect2(
				0,
				top if is_finite(top) else 0.0,
				text_size.x,
				maxf(24, bottom - top) if is_finite(top) else 24.0
			)
		)

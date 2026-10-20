## 职责：管理功能页的持久绘图区域、裁切、富文本、原光标和过渡时钟，不修改游戏状态。
##
## 调用方式：
##   页面只创建一份Surface；refresh时依次begin、window配置区域、finish，隐藏页保留节点与绘图缓存。区域clip_contents=true，坐标均为父区域内的逻辑像素。
##   window返回的Region：line(rect,value,font_size=18,color=白,align=0,bold=false)画原文字；image(texture,rect,source=空,tint=白)画素材/图集；select(rect,type=1)推进8帧四角光标。
##   Region.rich(raw,rect,font_size=18,scroll=0,align=0,line_height=0)只解释原富文本样式、换行与只读插值，使用白色窗口默认字，不执行Message等待/声音/事件；scroll为像素偏移。
##   Region.portrait(key,name,hue,rect,direction=2)复用CharacterSprite及色相；label(key,rect,value,font_size=18,color=白)用于需要单独透明度的HP文字。
##   父菜单/灵视通过set_progress提供唯一0—8入退进度；Surface自身只推进区域切换和光标，各区有效进度取父/自身最小值，避免重复位移。
##
## 调用接口：
##   func begin() -> void
##     用途：开始一次绘制内容更新，不重建节点或推进时钟。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func window( key: String, rect: Rect2, offset: Vector2 = Vector2.ZERO, parent_key: String = "", panel: bool = true ) -> Control
##     用途：取得或创建持久的绘图/裁切区域并记录本次内容。
##     参数 key（String；必填）：稳定的绘图区域键名；同名区域复用同一节点。
##     参数 rect（Rect2；必填）：区域在父节点内的位置和尺寸；内容按这个矩形裁切。
##     参数 offset（Vector2；默认值 Vector2.ZERO）：完全退出时相对静止位置的位移；八帧内归零。
##     参数 parent_key（String；默认值 ""）：父绘图区域键名；空字符串表示Surface直接子节点。
##     参数 panel（bool；默认值 true）：true绘制原17层渐变面板；false仅提供裁切视口。
##     返回：Region控件，提供上述line/image/select/rich/portrait/label绘制接口。
##
##   func finish() -> void
##     用途：提交本次区域更新；未使用的窗口按原八帧退场。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func party(key: String, rect: Rect2, selected: int = -1, offset: Vector2 = Vector2.ZERO) -> Control
##     用途：用当前正式角色绘制原Window_State摘要和独立选择光标。
##     参数 key（String；必填）：稳定的绘图区域键名；同名区域复用同一节点。
##     参数 rect（Rect2；必填）：区域在父节点内的位置和尺寸；内容按这个矩形裁切。
##     参数 selected（int；默认值 -1）：当前角色选择索引；-1表示只显示摘要。
##     参数 offset（Vector2；默认值 Vector2.ZERO）：完全退出时相对静止位置的位移；八帧内归零。
##     返回：对应摘要Region；不捕获或写入存档。
##
##   func set_progress(value: int) -> void
##     用途：接收所属页面的父过渡，不自行补推进父时钟。
##     参数 value（int；必填）：所属页面给出的0—8逻辑帧进度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func navigation_ready() -> bool
##     用途：检查当前使用区域的独立光标是否完成八帧移动，供父菜单消费过快的重复方向键。
##     参数：无。
##     返回：true允许本次方向移动；确认和取消仍由所属页面单独路由。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

extends Control
const Drawing = preload("WindowDrawing.gd")
const Resources = preload("UIResources.gd")
const Text = preload("../06_Message/MessageText.gd")
const Layout = preload("UITextLayout.gd")
const Character = preload("../03_Map/CharacterSprite.gd")
const Bitmap = preload("Bitmap.gd")
const Palette = preload("Palette.gd")
var progress = 8
var regions: Dictionary = {}
var _clock = 0.0
var _built = false


class Region:
	extends Control
	var commands: Array = []
	var panel = true
	var resting = Vector2.ZERO
	var entering = Vector2.ZERO
	var transition = true
	var cursor_from = Rect2()
	var cursor_to = Rect2()
	var cursor_ticks = 8
	var cursor_type = 1
	var cursor_visible = false
	var rich_height = 0.0
	var rich_label: RichTextLabel
	var rich_key = 0
	var portraits: Dictionary = {}
	var meter_key = ""
	var meters: Texture2D
	var used = false
	var desired = true
	var phase = 8
	var labels: Dictionary = {}

	func label(
		key: String, rect: Rect2, value: String, font_size: int = 18, color: Color = Color.WHITE
	) -> Label:
		if not labels.has(key):
			var node = Label.new()
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_theme_font_override("font", Resources.font())
			add_child(node)
			labels[key] = node
		var node: Label = labels[key]
		node.position = rect.position
		node.size = rect.size
		node.text = value
		node.add_theme_font_size_override("font_size", font_size)
		node.add_theme_color_override("font_color", color)
		node.show()
		return node

	func portrait(key: String, name: String, hue: int, rect: Rect2, direction: int = 2) -> void:
		if not portraits.has(key):
			portraits[key] = Character.new()
			add_child(portraits[key])
		var node = portraits[key]
		var signature = str([name, hue, direction])
		if node.get_meta("signature", "") != signature:
			node.configure(name, hue, direction, 0)
			node.set_meta("signature", signature)
		node.position = rect.position
		node.size = rect.size
		node.show()

	func line(
		rect: Rect2,
		value: String,
		font_size: int = 18,
		color: Color = Color.WHITE,
		align: int = 0,
		bold: bool = false
	) -> void:
		commands.append(["text", rect, value, font_size, color, align, bold])

	func image(
		texture: Texture2D, rect: Rect2, source: Rect2 = Rect2(), tint: Color = Color.WHITE
	) -> void:
		if texture != null:
			commands.append(["image", texture, rect, source, tint])

	func fill(rect: Rect2, color: Color, solid: bool = true, width: float = 1.0) -> void:
		commands.append(["fill", rect, color, solid, width])

	func select(rect: Rect2, type: int = 1) -> void:
		cursor_visible = true
		cursor_type = type
		if cursor_to != rect:
			var initial = cursor_to.size == Vector2.ZERO
			cursor_from = rect if initial else _cursor_rect()
			cursor_to = rect
			cursor_ticks = 8 if initial else 0

	func _cursor_rect() -> Rect2:
		return Rect2(
			cursor_from.position.lerp(cursor_to.position, cursor_ticks / 8.0),
			cursor_from.size.lerp(cursor_to.size, cursor_ticks / 8.0)
		)

	func rich(
		raw: String,
		rect: Rect2,
		font_size: int = 18,
		scroll: float = 0.0,
		align: int = 0,
		line_height: int = 0
	) -> void:
		# 静态富文本只采用原样式控制，不派发Message等待、声音或事件。
		var parsed = Text.parse(raw.replace("\\n", "\n"), RuntimeState, false)
		if rich_label == null:
			rich_label = RichTextLabel.new()
			rich_label.clip_contents = true
			rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rich_label.focus_mode = Control.FOCUS_NONE
			rich_label.add_theme_font_override("normal_font", Resources.font())
			rich_label.add_theme_constant_override(
				"line_separation",
				maxi(
					0,
					(
						(line_height if line_height > 0 else font_size + 8)
						- int(Resources.font().get_height(font_size))
					)
				)
			)
			add_child(rich_label)
		rich_label.position = rect.position
		rich_label.size = rect.size
		rich_label.show()
		var key = hash([parsed.get("tokens", []), raw, rect.size, font_size, align])
		if rich_key != key:
			rich_key = key
			rich_label.clear()
			rich_label.add_theme_font_size_override("normal_font_size", font_size)
			rich_label.push_paragraph(align)
			var style = Text.defaults()
			style.font_size = font_size
			style.color = 0
			if parsed.ok:
				for token in parsed.tokens:
					if token is String:
						rich_label.push_font(Text.font(style), int(style.font_size))
						rich_label.push_color(Text.color(int(style.color)))
						rich_label.add_text(token)
						rich_label.pop()
						rich_label.pop()
					elif token[0].unicode_at(0) in [1, 20, 21, 23, 25, 26]:
						Text.apply_style(style, token)
			else:
				rich_label.add_text(raw)
			rich_label.pop()
		rich_height = rich_label.get_content_height()
		rich_label.get_v_scroll_bar().set_deferred("value", maxf(0, scroll))

	func _draw() -> void:
		if panel and size.x >= 34 and size.y >= 34:
			draw_texture(Drawing.panel(Vector2i(size)), Vector2.ZERO)
		for command in commands:
			match command[0]:
				"text":
					Drawing.text(
						self,
						Layout.font({"bold": true}) if command[6] else Resources.font(),
						command[1],
						command[2],
						command[3],
						command[4],
						command[5]
					)
				"image":
					if command[3].size == Vector2.ZERO:
						draw_texture_rect(command[1], command[2], false, command[4])
					else:
						draw_texture_rect_region(command[1], command[2], command[3], command[4])
				"fill":
					draw_rect(command[1], command[2], command[3], command[4])
		if cursor_visible:
			Drawing.cursor(self, _cursor_rect(), cursor_type)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func begin() -> void:
	for region in regions.values():
		region.used = false


func window(
	key: String,
	rect: Rect2,
	offset: Vector2 = Vector2.ZERO,
	parent_key: String = "",
	panel: bool = true
) -> Control:
	if not regions.has(key):
		var region = Region.new()
		region.mouse_filter = Control.MOUSE_FILTER_IGNORE
		region.clip_contents = true
		region.phase = 8 if not _built or not parent_key.is_empty() else 0
		(regions[parent_key] if not parent_key.is_empty() else self).add_child(region)
		regions[key] = region
	var region: Control = regions[key]
	region.used = true
	region.desired = true
	region.commands.clear()
	region.cursor_visible = false
	if region.rich_label != null:
		region.rich_label.hide()
	for portrait in region.portraits.values():
		portrait.hide()
	for label in region.labels.values():
		label.hide()
	region.resting = rect.position
	region.entering = offset
	region.transition = parent_key.is_empty()
	region.size = rect.size
	region.panel = panel
	region.show()
	region.queue_redraw()
	_apply(region)
	return region


func finish() -> void:
	for region in regions.values():
		region.desired = region.used
		if not region.transition and not region.used:
			region.hide()
		region.queue_redraw()
	_built = true


func party(key: String, rect: Rect2, selected: int = -1, offset: Vector2 = Vector2.ZERO) -> Control:
	var region = window(key, rect, offset)
	var rows = preload("../07_Archive/ArchiveData.gd").from_state(RuntimeState).players
	var signature = str([rows, rect.size])
	if region.meter_key != signature:
		region.meter_key = signature
		var bitmap = Bitmap.new(int(rect.size.x), int(rect.size.y))
		for i in rows.size():
			for vital in 3:
				var box = Rect2i(88 + i * 232, [40, 64, 88][vital], 128, 4 if vital == 0 else 6)
				bitmap.draw_hud_back(box, 0 if vital == 0 else 1)
				var value = rows[i].get(["exp", "hp", "sp"][vital], 0)
				var maximum = rows[i].get(["maxexp", "maxhp", "maxsp"][vital], 1)
				bitmap.draw_hud_line(
					box,
					0 if value == null else value,
					1 if maximum == null else maximum,
					Palette.color([15, 9, 4][vital]),
					Palette.color([12, 3, 1][vital]),
					0 if vital == 0 else 1
				)
		region.meters = bitmap.texture()
	region.image(region.meters, Rect2(Vector2.ZERO, rect.size))
	for i in rows.size():
		var row = rows[i]
		region.portrait(str(i), row.char_name, int(row.char_hue), Rect2(24 + i * 232, 48, 48, 48))
		region.line(Rect2(24 + i * 232, 20, 60, 26), "Lv.%s" % row.lv, 18, Palette.color(12), 1)
		for vital in 3:
			region.line(
				Rect2(88 + i * 232, [20, 52, 76][vital], 128, 20),
				(
					str(row.get(["exp", "hp", "sp"][vital]))
					+ "/"
					+ str(row.get(["maxexp", "maxhp", "maxsp"][vital]))
				),
				18,
				Palette.color([12, 2, 4][vital]),
				2
			)
	if selected >= 0 and selected < rows.size():
		region.select(Rect2(16 + 232 * selected, 18, 216, 88), 3)
	return region


func set_progress(value: int) -> void:
	progress = clampi(value, 0, 8)
	for region in regions.values():
		_apply(region)


func _apply(region: Control) -> void:
	var value = mini(progress, region.phase) if region.transition else 8
	region.position = (
		region.resting + region.entering * (1.0 - value / 8.0)
		if region.transition
		else region.resting
	)
	region.modulate.a = minf(1, value * 32.0 / 255) if region.transition else 1.0
	if region.transition:
		region.visible = value > 0


func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	_clock += delta * 60.0
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	for region in regions.values():
		if region.transition and region.phase != (8 if region.desired else 0):
			region.phase = clampi(region.phase + (ticks if region.desired else -ticks), 0, 8)
			_apply(region)
		if region.cursor_ticks < 8:
			region.cursor_ticks = mini(8, region.cursor_ticks + ticks)
			region.queue_redraw()


func navigation_ready() -> bool:
	for region in regions.values():
		if region.used and region.cursor_visible and region.visible and region.cursor_ticks < 8:
			return false
	return true

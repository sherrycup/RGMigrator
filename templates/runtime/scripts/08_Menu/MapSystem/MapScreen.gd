## 职责：组织闪翼地图系统页面的预览、光标和区域切换输入。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/MapSystem/MapScreen.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func center_camera() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func follow_cursor() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func point(x: float, y: float) -> Vector2
##     参数 x（float；必填）：横向坐标。
##     参数 y（float；必填）：纵向坐标。
##     返回：Vector2 类型的对象或值，供调用方继续使用。
##
##   func draw_world(target: Control) -> void
##     参数 target（Control；必填）：操作或效果作用的目标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   close_requested()：由持有方发出，通知对应状态或操作结果。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _draw() -> void
##
## 接口说明结束。

extends Control
## Original 0248 Window_Map and the active 0202 call/return lifecycle.
const Config = preload("MapConfig.gd")
const Cursor = preload("MapCursor.gd")
const Preview = preload("MapPreview.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
signal close_requested
var page = "flash_map"
var world: RefCounted
var cursor: RefCounted
var preview = Preview.new()
var camera = Vector2.ZERO
var preview_offset = Vector2.ZERO
var ticks = 0
var _clock = 0.0
var canvas: Control


class WorldCanvas:
	extends Control
	var screen: Control

	func _draw() -> void:
		screen.draw_world(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = RuntimeState.custom_data.map_system()
	var current = world.discover_current()
	if current == null:
		close_requested.emit()
		return
	cursor = Cursor.new(world, current)
	canvas = WorldCanvas.new()
	canvas.screen = self
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	resized.connect(_layout)
	_layout()
	refresh()


func _layout() -> void:
	canvas.position = Vector2(16, 56)
	canvas.size = Vector2(maxf(size.x - 32, 1), maxf(size.y - 280, 1))
	center_camera()
	queue_redraw()
	canvas.queue_redraw()


func center_camera() -> void:
	if cursor == null or canvas == null:
		return
	camera = Vector2(cursor.x, cursor.y) - canvas.size / (Config.CELL_SIZE * 2.0)


func follow_cursor() -> bool:
	var bounds: Rect2 = cursor.rect()
	var margin = 0.75
	var view = canvas.size / Config.CELL_SIZE
	var before = camera
	for axis in 2:
		if bounds.size[axis] + margin * 2 > view[axis]:
			camera[axis] = bounds.position[axis] + bounds.size[axis] / 2.0 - view[axis] / 2.0
		else:
			if bounds.position[axis] < camera[axis] + margin:
				camera[axis] = bounds.position[axis] - margin
			if bounds.end[axis] > camera[axis] + view[axis] - margin:
				camera[axis] = bounds.end[axis] + margin - view[axis]
	return before != camera


func refresh() -> void:
	if cursor == null:
		return
	preview.show_map(cursor.selected.id)
	preview_offset = Vector2.ZERO
	queue_redraw()
	canvas.queue_redraw()


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X, KEY_M]:
		close_requested.emit()
	elif key in [KEY_PAGEUP, KEY_PAGEDOWN]:
		cursor.change_area(-1 if key == KEY_PAGEUP else 1)
		center_camera()
		refresh()


func _process(delta: float) -> void:
	if cursor == null:
		return
	_clock += delta * 60.0
	var count = mini(int(_clock), 120)
	_clock -= count
	for tick in count:
		ticks += 1
		var dx = int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT))
		var dy = int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP))
		var changed = cursor.update(dx, dy)
		follow_cursor()
		if changed == "lock":
			refresh()
		preview_offset = preview.advance()
	queue_redraw()
	canvas.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("131619"))
	if cursor == null or canvas == null:
		return
	var font = Resources.font()
	var ids = world.areas().keys()
	ids.sort()
	draw_string(
		font,
		Vector2(16, 39),
		Config.area_name(cursor.area),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 132,
		22,
		Color("e6ebe7")
	)
	draw_string(
		font,
		Vector2(size.x - 112, 38),
		"%d / %d" % [ids.find(cursor.area) + 1, ids.size()],
		HORIZONTAL_ALIGNMENT_RIGHT,
		96,
		16,
		Color("e6ebe7")
	)
	var row = canvas.position.y + canvas.size.y + 28
	draw_line(Vector2(16, row - 16), Vector2(size.x - 16, row - 16), Color("44494d"))
	var block = cursor.selected
	var text_width = maxf(size.x - 32 - Config.PREVIEW_WIDTH - 20, 1)
	draw_string(
		font,
		Vector2(16, row + 20),
		Config.map_name(block.id),
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		20,
		Color("ecede8")
	)
	draw_string(
		font,
		Vector2(16, row + 54),
		"%d × %d  /  %d × %d" % [block.tile_width, block.tile_height, block.width, block.height],
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		16,
		Color("a1aca9")
	)
	var destinations: Array = []
	for link in world.links_for(block.id):
		var target = int(link.to.id) if int(link.from.id) == block.id else int(link.from.id)
		if not destinations.has(target):
			destinations.append(target)
	destinations.sort()
	for i in mini(destinations.size(), 3):
		var target = world.block(destinations[i])
		var label = Config.map_name(target.id)
		if target.area != block.area:
			label = Config.area_name(target.area) + " / " + label
		draw_string(
			font,
			Vector2(16, row + 94 + i * 26),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			text_width,
			16,
			Color("a1aca9")
		)
	var box = Rect2(
		size.x - 16 - Config.PREVIEW_WIDTH,
		size.y - 16 - Config.PREVIEW_HEIGHT,
		Config.PREVIEW_WIDTH,
		Config.PREVIEW_HEIGHT
	)
	if preview.texture != null:
		var available = Vector2(
			minf(box.size.x, preview.texture.get_width()),
			minf(box.size.y, preview.texture.get_height())
		)
		draw_texture_rect_region(
			preview.texture, Rect2(box.position, available), Rect2(preview_offset, available)
		)
	else:
		draw_string(
			font,
			box.position + Vector2(0, 24),
			"暂无预览",
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			16,
			Color("a1aca9")
		)


func point(x: float, y: float) -> Vector2:
	return Vector2(
		round((x - camera.x) * Config.CELL_SIZE), round((y - camera.y) * Config.CELL_SIZE)
	)


func draw_world(target: Control) -> void:
	target.draw_rect(Rect2(Vector2.ZERO, target.size), Color("1b1f22"))
	if cursor == null:
		return
	for block in world.maps_in_area(cursor.area):
		var box = (
			Rect2(point(block.x, block.y), Vector2(block.width, block.height) * Config.CELL_SIZE)
			. grow(-3)
		)
		target.draw_rect(box, Config.area_color(cursor.area))
		target.draw_rect(box, Color("a8c1b1"), false, 1)
		for column in range(1, block.width):
			var start = point(block.x + column, block.y) + Vector2(0, 4)
			target.draw_line(
				start, start + Vector2(0, block.height * Config.CELL_SIZE - 8), Color("2c6052")
			)
		for row in range(1, block.height):
			var start = point(block.x, block.y + row) + Vector2(4, 0)
			target.draw_line(
				start, start + Vector2(block.width * Config.CELL_SIZE - 8, 0), Color("2c6052")
			)
	for link in world.connections():
		var a = world.block(int(link.from.id))
		var b = world.block(int(link.to.id))
		if a.area != cursor.area and b.area != cursor.area:
			continue
		var bridge: Variant = world.bridge(link)
		if bridge != null:
			var start = point(bridge[0][0] + 0.5, bridge[0][1] + 0.5)
			var end = point(bridge[1][0] + 0.5, bridge[1][1] + 0.5)
			target.draw_rect(
				Rect2((start + end) / 2.0 - Vector2(5, 5), Vector2(10, 10)), Color("dbe1cf")
			)
		else:
			for block in [a, b]:
				if block.area == cursor.area:
					target.draw_rect(
						Rect2(point(block.x, block.y) + Vector2(8, 8), Vector2(6, 6)),
						Color("e7ac6d")
					)
	var selected: Rect2 = cursor.rect()
	var highlight = Rect2(
		point(selected.position.x, selected.position.y), selected.size * Config.CELL_SIZE
	)
	target.draw_rect(highlight, Color("ffebb1"), false, 2)
	var player_block = world.block(RuntimeState.map_id)
	if player_block != null and player_block.area == cursor.area:
		var cell = player_block.cell_at(RuntimeState.player_x, RuntimeState.player_y)
		var position = point(player_block.x + cell[0] + 0.5, player_block.y + cell[1] + 0.5)
		var color = Color("ffd55e")
		color.a = (144 + absi(ticks % 40 - 20) * 5) / 255.0
		target.draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 8)), color)

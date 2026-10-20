## 职责：构建闪翼楼层或区域的地图预览，绘制已发现内容和连接。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/MapSystem/MapPreview.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/MapSystem/MapPreview.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func show_map(map_id: int) -> void
##     参数 map_id（int；必填）：地图的原编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func advance() -> Vector2
##     用途：推进当前动作、等待或演出的时间状态。
##     参数：无。
##     返回：Vector2 类型的对象或值，供调用方继续使用。
##
##   static func offset(tick: int, max_x: float, max_y: float) -> Vector2
##     参数 tick（int；必填）：原逻辑帧或当前效果帧计数。
##     参数 max_x（float；必填）：允许的最大横向坐标。
##     参数 max_y（float；必填）：允许的最大纵向坐标。
##     返回：Vector2 类型的对象或值，供调用方继续使用。
##
##   static func ping_pong(tick: int, distance: float) -> float
##     参数 tick（int；必填）：原逻辑帧或当前效果帧计数。
##     参数 distance（float；必填）：移动、滚动或范围查询的距离。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func render(map_id: int) -> Dictionary
##     参数 map_id（int；必填）：地图的原编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func table_value(table: Dictionary, x: int, y: int, z: int) -> int
##     参数 table（Dictionary；必填）：RM Table 的维度与整数单元数据。
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 z（int；必填）：图块层或显示深度坐标。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func tile_image(id: int, layout: RefCounted, tileset: Dictionary) -> Image
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 layout（RefCounted；必填）：已计算的界面或文本布局。
##     参数 tileset（Dictionary；必填）：当前地图使用的图块集定义或对象。
##     返回：Image 类型的对象或值，供调用方继续使用。
##
## 公开常量：TILE_SIZE、HOLD_FRAMES、PIXELS_PER_FRAME。
## 接口说明结束。

extends RefCounted
## Original 0251 preview, including the four-image cache and reserved two-axis
## motion. Rendering reads first-page definitions and never loads a live map.
const Data = preload("../../00_Game/RuntimeData.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Layout = preload("../../03_Map/TilesetLayout.gd")
const Tiles = preload("../../03_Map/Tilemap.gd")
const Config = preload("MapConfig.gd")
const TILE_SIZE = 12
const HOLD_FRAMES = 40
const PIXELS_PER_FRAME = 0.5
var images: Dictionary = {}
var order: Array = []
var id = -1
var frame = 0
var texture: Texture2D
var error = ""
var source_kind = ""


func show_map(map_id: int) -> void:
	if id == map_id:
		return
	id = map_id
	frame = 0
	texture = null
	error = ""
	if not images.has(id):
		var rendered = render(id)
		if not rendered.ok:
			error = rendered.message
			return
		images[id] = {
			"texture": ImageTexture.create_from_image(rendered.image), "source": rendered.source
		}
	order.erase(id)
	order.append(id)
	while order.size() > 4:
		images.erase(order.pop_front())
	texture = images[id].texture
	source_kind = images[id].source


func advance() -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var point = offset(
		frame,
		maxi(texture.get_width() - Config.PREVIEW_WIDTH, 0),
		maxi(texture.get_height() - Config.PREVIEW_HEIGHT, 0)
	)
	frame += 1
	return point


static func offset(tick: int, max_x: float, max_y: float) -> Vector2:
	if max_x > 0 and max_y > 0:
		return Vector2.ZERO  # Source reserved method.
	return (
		Vector2(ping_pong(tick, max_x), 0)
		if max_x > 0
		else Vector2(0, ping_pong(tick, max_y)) if max_y > 0 else Vector2.ZERO
	)


static func ping_pong(tick: int, distance: float) -> float:
	var travel = ceili(distance / PIXELS_PER_FRAME)
	var phase = posmod(tick, 2 * (travel + HOLD_FRAMES))
	if phase < HOLD_FRAMES:
		return 0
	phase -= HOLD_FRAMES
	if phase < travel:
		return minf(phase * PIXELS_PER_FRAME, distance)
	phase -= travel
	if phase < HOLD_FRAMES:
		return distance
	return maxf(distance - (phase - HOLD_FRAMES) * PIXELS_PER_FRAME, 0)


static func render(map_id: int) -> Dictionary:
	var definition = Data.map(map_id)
	var width = int(definition.get("width", 0))
	var height = int(definition.get("height", 0))
	if width <= 0 or height <= 0 or width * TILE_SIZE > 4096 or height * TILE_SIZE > 4096:
		return {"ok": false, "message": "地图不存在或超出预览尺寸。"}
	var output = Image.create(width * TILE_SIZE, height * TILE_SIZE, false, Image.FORMAT_RGBA8)
	output.fill(Color.BLACK)
	var info: Dictionary = Data.read_json("res://data/map_infos.json", {}).get(str(map_id), {})
	var sanitizer = RegEx.new()
	sanitizer.compile("[\\\\/:*?|<>]")
	var filename = (
		"res://legacy/extras/MapSnapshots/%03d-%s.png"
		% [map_id, sanitizer.sub(str(info.get("name", "")), "_", true)]
	)
	if FileAccess.file_exists(filename):
		var bytes = FileAccess.get_file_as_bytes(filename)
		# The actual source includes a deliberately broken 33-byte snapshot.
		# Reject obvious non-PNG/truncated headers before invoking the decoder.
		if (
			bytes.size() > 45
			and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
		):
			var snapshot = Image.new()
			if snapshot.load_png_from_buffer(bytes) == OK:
				snapshot.convert(Image.FORMAT_RGBA8)
				snapshot.resize(output.get_width(), output.get_height(), Image.INTERPOLATE_NEAREST)
				return {"ok": true, "image": snapshot, "source": "snapshot"}
	var tileset = Data.record("Tilesets", int(definition.get("tileset_id", 0)))
	var layout = Layout.new()
	layout.configure(tileset, Cache.tileset)
	var jobs: Array = []
	var table: Dictionary = definition.get("data", {})
	for y in height:
		for x in width:
			for layer in int(table.get("z_size", 3)):
				var tile = table_value(table, x, y, layer)
				if tile == 0:
					continue
				var priority = table_value(tileset.get("priorities", {}), tile, 0, 0)
				jobs.append(
					[layer if priority == 0 else (y + priority + 1) * 32 + layer, x, y, tile, null]
				)
	for event in definition.get("events", {}).values():
		var pages: Array = event.get("pages", [])
		if pages.is_empty():
			continue
		var page: Dictionary = pages[0]
		var graphic: Dictionary = page.get("graphic", {})
		if (
			int(graphic.get("opacity", 255)) == 0
			or (
				int(graphic.get("tile_id", 0)) == 0
				and str(graphic.get("character_name", "")).is_empty()
			)
		):
			continue
		jobs.append(
			[
				1000000 if page.get("always_on_top", false) else (int(event.y) + 1) * 32,
				int(event.x),
				int(event.y),
				int(graphic.get("tile_id", 0)),
				graphic
			]
		)
	jobs.sort_custom(func(a, b): return a[0] < b[0])
	var tile_images: Dictionary = {}
	for job in jobs:
		var graphic: Variant = job[4]
		if int(job[3]) > 0:
			var tile = int(job[3])
			if not tile_images.has(tile):
				var resolved = tile_image(tile, layout, tileset)
				if resolved == null:
					return {"ok": false, "message": "预览缺少图块素材：%d。" % tile}
				tile_images[tile] = resolved
			var part: Image = tile_images[tile].duplicate()
			part.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
			_blend(
				output,
				part,
				Vector2i(int(job[1]) * TILE_SIZE, int(job[2]) * TILE_SIZE),
				int(graphic.get("opacity", 255)) if graphic != null else 255
			)
		else:
			var character = Cache.character(str(graphic.character_name))
			if character == null:
				return {"ok": false, "message": "预览行走图缺失：" + str(graphic.character_name)}
			var image = _image(character)
			if image == null:
				return {"ok": false, "message": "预览行走图无法读取。"}
			var w = int(image.get_width() / 4)
			var h = int(image.get_height() / 4)
			if w <= 0 or h <= 0:
				return {"ok": false, "message": "预览行走图尺寸无效。"}
			var region = Rect2i(
				int(graphic.get("pattern", 0)) * w,
				int((int(graphic.get("direction", 2)) - 2) / 2) * h,
				w,
				h
			)
			var part = image.get_region(region)
			var hue = float(graphic.get("character_hue", 0)) / 360.0
			if hue != 0:
				for py in part.get_height():
					for px in part.get_width():
						var color = part.get_pixel(px, py)
						part.set_pixel(
							px,
							py,
							Color.from_hsv(fposmod(color.h + hue, 1.0), color.s, color.v, color.a)
						)
			var ratio = TILE_SIZE / 32.0
			part.resize(
				maxi(roundi(w * ratio), 1), maxi(roundi(h * ratio), 1), Image.INTERPOLATE_NEAREST
			)
			_blend(
				output,
				part,
				Vector2i(
					roundi((int(job[1]) * 32 + 16 - w / 2.0) * ratio),
					roundi((int(job[2]) * 32 + 32 - h) * ratio)
				),
				int(graphic.get("opacity", 255))
			)
	return {"ok": true, "image": output, "source": "map_data"}


static func table_value(table: Dictionary, x: int, y: int, z: int) -> int:
	var width = int(table.get("x_size", 0))
	var height = int(table.get("y_size", 1))
	var depth = int(table.get("z_size", 1))
	if x < 0 or y < 0 or z < 0 or x >= width or y >= height or z >= depth:
		return 0
	var values: Array = table.get("values", [])
	var index = (z * height + y) * width + x
	return int(values[index]) if index < values.size() else 0


static func tile_image(id: int, layout: RefCounted, tileset: Dictionary) -> Image:
	if id >= 384:
		var found = layout.locate(id)
		if found.is_empty():
			# Original get_bitmap returns a transparent 32x32 bitmap when blt's
			# source rect is outside a valid tileset (present in actual Map006).
			if not layout.errors.is_empty():
				return null
			var blank = Image.create(32, 32, false, Image.FORMAT_RGBA8)
			blank.fill(Color.TRANSPARENT)
			return blank
		var image = _image(found.texture)
		return image.get_region(Rect2i(found.region)) if image != null else null
	var slot = int(id / 48) - 1
	var names: Array = tileset.get("autotile_names", [])
	if slot < 0 or slot >= names.size():
		return null
	var image = _image(Cache.autotile(str(names[slot])))
	if image == null:
		return null
	if image.get_height() == 32:
		return image.get_region(Rect2i(0, 0, 32, 32))
	var output = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var parts = Tiles.parts(id % 48)
	for quadrant in 4:
		var part = int(parts[quadrant]) - 1
		output.blit_rect(
			image,
			Rect2i((part % 6) * 16, int(part / 6) * 16, 16, 16),
			Vector2i((quadrant % 2) * 16, int(quadrant / 2) * 16)
		)
	return output


static func _image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image = texture.get_image()
	if image != null:
		image = image.duplicate()
	if image == null or image.is_compressed() and image.decompress() != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _blend(output: Image, part: Image, pos: Vector2i, opacity: int) -> void:
	if opacity < 255:
		for y in part.get_height():
			for x in part.get_width():
				var color = part.get_pixel(x, y)
				color.a *= opacity / 255.0
				part.set_pixel(x, y, color)
	output.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), pos)

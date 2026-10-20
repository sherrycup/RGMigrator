## 职责：验证0.58补迁的上层遮挡连通区、缓存、动态改图、重载与实际GPU透明度。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Occlusion = preload("res://runtime/scripts/03_Map/MapOcclusion.gd")
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var checks = 0
var failures: Array[String] = []
var captures = 0

class Palette extends RefCounted:
	var texture: Texture2D
	func _init() -> void:
		var image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(0, 0, 32, 32), Color(0.1, 0.3, 0.6, 1))
		image.fill_rect(Rect2i(32, 0, 32, 32), Color(0.9, 0.2, 0.1, 1))
		texture = ImageTexture.create_from_image(image)
	func locate(id: int) -> Dictionary:
		return {"texture":texture, "region":Rect2(32 if id == 385 else 0, 0, 32, 32)}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RuntimeState")
	state.playing = true
	state.map_id = 22
	state.party = [2]
	state.variables["14"] = [2, 0]
	var assets: Dictionary = Data.read_json("res://data/asset_index.json", {})
	for name in ["Audio/SE/静电声2", "Audio/SE/静电声", "Audio/SE/m魔法-爆气-重-005"]:
		var path = str(assets.get(name, ""))
		expect(not path.is_empty() and load(path) is AudioStream, "current original media is importable, rather than the outdated missing-media boundary: " + name)
	root.size = Vector2i(640, 640)
	var map = load("res://runtime/scripts/03_Map/MapRuntime.gd").new()
	root.add_child(map)
	map.set_process(false)
	state.player_motion.relocate(Vector2i(-1, -1))
	expect(map.load_map(22), "actual Map022 loads before isolated occlusion checks")
	var source_tiles = map.map_data.duplicate(true)
	var priorities = map.tileset.duplicate(true)
	var selected = Vector2i(-1, -1)
	for y in map.map_height():
		for x in map.map_width():
			for layer in [1, 2]:
				if map.tile_id(x, y, layer) != 0 and map.tile_priority(map.tile_id(x, y, layer)) != 0:
					selected = Vector2i(x, y)
	if selected.x >= 0:
		map.position = Vector2(304, 240) - Vector2(selected * 32)
		await _capture("source-roof-before")
		state.player_motion.relocate(selected)
		map._process(0.0)
		expect(is_equal_approx(map.tile_opacity(selected.x, selected.y, 1), Occlusion.OPACITY), "real source high-priority upper tile enters the original160/255 state")
		expect(map.tile_opacity(selected.x, selected.y, 0) == 1.0, "real source ground layer stays opaque")
		await _capture("source-roof-under")
		state.player_motion.relocate(Vector2i(-1, -1))
		map._process(0.0)
		await _capture("source-roof-exit")
	else:
		expect(false, "real Map022 must supply the occlusion sample, never silently skip it")
	expect(map.map_data == source_tiles and map.tileset == priorities, "source definitions and priorities remain unchanged")
	map._clear_events()
	map.map_data = {"width":8, "height":5, "data":{"x_size":8, "y_size":5, "z_size":4, "values":[]}, "events":{}}
	map.map_data.data.values.resize(8 * 5 * 4)
	map.map_data.data.values.fill(0)
	for y in 5:
		for x in 8:
			map.map_data.data.values[x + 8 * y] = 384
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(5, 1)]:
		map.map_data.data.values[cell.x + 8 * cell.y + 40] = 385
	map.map_data.data.values[2 + 8 + 80] = 384
	map.map_data.data.values[1 + 8 + 120] = 385
	map.tileset = {"priorities":{"x_size":386, "values":[]}}
	map.tileset.priorities.values.resize(386)
	map.tileset.priorities.values.fill(0)
	map.tileset.priorities.values[385] = 2
	map._normal_layout = Palette.new()
	map.position = Vector2(64, 64)
	state.player_motion.relocate(Vector2i(0, 0))
	map._build_tile_rows()
	map.queue_redraw()
	await _capture("occlusion-before")
	var before: Image = _image()
	var model = map._occlusion
	state.player_motion.relocate(Vector2i(1, 1))
	map._process(0.0)
	var active: Dictionary = model._cells
	expect(active.size() == 3 and active.has(Vector2i(2, 2)) and not active.has(Vector2i(3, 3)) and not active.has(Vector2i(5, 1)), "four-neighbour BFS fades the whole connected roof, while diagonal and distant roofs stay opaque")
	expect(map.tile_opacity(1, 1, 0) == 1.0 and map.tile_opacity(1, 1, 3) == 1.0, "only original upper layers1/2 participate, including on expanded four-layer maps")
	expect(is_equal_approx(map.tile_opacity(2, 1, 2), Occlusion.OPACITY), "priority-zero upper tiles in the active connected region also fade as in source")
	expect(is_equal_approx(map.tile_opacity(2, 2, 1), Occlusion.OPACITY), "the cache includes cells outside the current sprite row")
	await _capture("occlusion-under")
	if before != null:
		var after = _image()
		var point = Vector2i(64 + 2 * 32 + 16, 64 + 2 * 32 + 16)
		var expected = Color(0.1, 0.3, 0.6).lerp(Color(0.9, 0.2, 0.1), Occlusion.OPACITY)
		expect(before.get_pixelv(point).r > 0.85 and absf(after.get_pixelv(point).r - expected.r) < 0.03, "actual GPU upper-row draw alpha blends160/255 over the opaque ground")
		expect(after.get_pixel(64 + 5 * 32 + 16, 64 + 32 + 16).r > 0.85, "GPU disconnected upper row remains opaque")
	for index in 50:
		expect(model.update(Vector2i(1, 1)).is_empty() and is_same(model._cells, active), "idle frame keeps cache identity without a repeated BFS")
	expect(model.update(Vector2i(2, 2)).is_empty() and is_same(model._cells, active), "moving inside the same component reuses the existing result")
	state.player_motion.relocate(Vector2i(5, 1))
	map._process(0.0)
	expect(map.tile_opacity(1, 1, 1) == 1.0 and map.tile_opacity(5, 1, 1) < 1.0, "entering a different component restores the previous roof")
	state.player_motion.relocate(Vector2i(0, 0))
	map._process(0.0)
	expect(model._cells.is_empty() and map.tile_opacity(5, 1, 1) == 1.0, "leaving all roofs restores full opacity")
	await _capture("occlusion-exit")
	state.player_motion.relocate(Vector2i(1, 1))
	map._process(0.0)
	map.apply_flash_tiles({"1:1:1":0})
	expect(model._cells.is_empty() and map.tile_opacity(2, 2, 1) == 1.0, "changing a tile under a stationary player invalidates the component immediately")
	map.apply_flash_tiles({"1:1:1":385})
	expect(is_equal_approx(map.tile_opacity(2, 2, 1), Occlusion.OPACITY), "rebuilding restored tiles recovers opacity without a player movement")
	map._loaded_id = -1
	map._build_tile_rows()
	expect(model._mask.is_empty() and map.tile_opacity(1, 1, 1) == 1.0, "native/RM fixtures keep their existing rendering rules")
	map.load_map(22)
	expect(map.map_data == source_tiles and map.tile_opacity(1, 1, 0) == 1.0, "reloading the real map resets synthetic state without stale opacity")
	map.queue_free()
	await process_frame
	for message in failures: printerr("FAIL: ", message)
	print("MIGRATION GAPS V058: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks / ", captures, " GPU states")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _image() -> Image:
	return null if DisplayServer.get_name() == "headless" else root.get_texture().get_image()

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(image != null and image.save_png("res://.godot/v058-" + label + ".png") == OK, "GPU capture " + label)
	captures += 1

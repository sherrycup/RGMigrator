## 职责：对独立地图草稿执行尺寸、图块和事件操作，保持 RM Table 的原排列。
##
## 调用方式：
##   静态接口：preload("res://addons/rgm_editor/02_Map/Editor_MapOps.gd").方法名(...)。
##
## 调用接口：
##   static func tile(map: Dictionary, cell: Vector2i, layer: int) -> int
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 cell（Vector2i；必填）：图块、动画或表格的单元记录。
##     参数 layer（int；必填）：图块或显示层编号。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func valid(map: Dictionary, cell: Vector2i) -> bool
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 cell（Vector2i；必填）：图块、动画或表格的单元记录。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func paint(map: Dictionary, cells: Array, layer: int, id: int) -> void
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 cells（Array；必填）：动画或表格的单元集合。
##     参数 layer（int；必填）：图块或显示层编号。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func stamp(map: Dictionary, origins: Array, layer: int, brush: Array) -> void
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 origins（Array；必填）：与记录对应的来源信息集合。
##     参数 layer（int；必填）：图块或显示层编号。
##     参数 brush（Array；必填）：当前地图画笔的图块与形状数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func pattern( map: Dictionary, cells: Array, layer: int, brush: Array, anchor: Vector2i ) -> void
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 cells（Array；必填）：动画或表格的单元集合。
##     参数 layer（int；必填）：图块或显示层编号。
##     参数 brush（Array；必填）：当前地图画笔的图块与形状数据。
##     参数 anchor（Vector2i；必填）：窗口、气泡或图形的锚点位置。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func line_cells(start: Vector2i, end: Vector2i) -> Array
##     参数 start（Vector2i；必填）：起始位置或起始索引。
##     参数 end（Vector2i；必填）：结束位置或结束索引。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func flood_cells(map: Dictionary, start: Vector2i, layer: int) -> Array
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 start（Vector2i；必填）：起始位置或起始索引。
##     参数 layer（int；必填）：图块或显示层编号。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func resize_map(map: Dictionary, width: int, height: int) -> Dictionary
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 width（int；必填）：区域或画布宽度。
##     参数 height（int；必填）：区域或画布高度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func layer_count(map: Dictionary) -> int
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func layer_names(map: Dictionary) -> Array
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func set_layer_count(map: Dictionary, count: int) -> Dictionary
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func next_event_id(map: Dictionary) -> int
##     参数 map（Dictionary；必填）：当前接口使用的地图数据或地图对象。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
## 接口说明结束。

@tool
extends RefCounted


## Pure map operations; table layout matches RMXP x + width*(y + height*z).
static func tile(map: Dictionary, cell: Vector2i, layer: int) -> int:
	if not valid(map, cell) or layer not in range(layer_count(map)):
		return 0
	var index = cell.x + int(map.width) * (cell.y + int(map.height) * layer)
	return int(map.data.values[index])


static func valid(map: Dictionary, cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < int(map.get("width", 0))
		and cell.y < int(map.get("height", 0))
	)


static func paint(map: Dictionary, cells: Array, layer: int, id: int) -> void:
	var writes: Dictionary = {}
	for cell in cells:
		writes[cell] = id
	_write_batch(map, writes, layer)


static func stamp(map: Dictionary, origins: Array, layer: int, brush: Array) -> void:
	var writes: Dictionary = {}
	for origin in origins:
		for y in brush.size():
			for x in brush[y].size():
				writes[origin + Vector2i(x, y)] = int(brush[y][x])
	_write_batch(map, writes, layer)


static func pattern(
	map: Dictionary, cells: Array, layer: int, brush: Array, anchor: Vector2i
) -> void:
	if brush.is_empty():
		return
	var writes: Dictionary = {}
	for cell in cells:
		var row: Array = brush[posmod(cell.y - anchor.y, brush.size())]
		if not row.is_empty():
			writes[cell] = int(row[posmod(cell.x - anchor.x, row.size())])
	_write_batch(map, writes, layer)


static func line_cells(start: Vector2i, end: Vector2i) -> Array:
	var result: Array = []
	var steps = maxi(absi(end.x - start.x), absi(end.y - start.y))
	for i in steps + 1:
		var cell = Vector2i(Vector2(start).lerp(Vector2(end), float(i) / maxi(steps, 1)).round())
		if result.is_empty() or result.back() != cell:
			result.append(cell)
	return result


static func _write_batch(map: Dictionary, writes: Dictionary, layer: int) -> void:
	if layer not in range(layer_count(map)):
		return
	var touched: Dictionary = {}
	for cell in writes:
		if not valid(map, cell):
			continue
		_write_tile(map, cell, layer, int(writes[cell]))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				touched[cell + Vector2i(dx, dy)] = true
	for cell in touched:
		if not valid(map, cell):
			continue
		var old = tile(map, cell, layer)
		if old >= 48 and old < 384:
			var slot = int(old / 48)
			_write_tile(map, cell, layer, slot * 48 + _autotile_variant(map, cell, layer, slot))


static func flood_cells(map: Dictionary, start: Vector2i, layer: int) -> Array:
	if not valid(map, start):
		return []
	var old = tile(map, start, layer)
	var queue: Array = [start]
	var seen: Dictionary = {start: true}
	var result: Array = []
	var cursor = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		if not _same(tile(map, cell, layer), old):
			continue
		result.append(cell)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if valid(map, next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return result


static func resize_map(map: Dictionary, width: int, height: int) -> Dictionary:
	if width < 1 or height < 1 or width > 500 or height > 500:
		return {"ok": false, "message": "地图尺寸须为1..500。"}
	for event in map.get("events", {}).values():
		if int(event.x) >= width or int(event.y) >= height:
			return {"ok": false, "message": "缩小地图会使事件越界，请先移动事件。"}
	var depth = layer_count(map)
	var values: Array = []
	values.resize(width * height * depth)
	values.fill(0)
	for z in depth:
		for y in mini(height, int(map.height)):
			for x in mini(width, int(map.width)):
				values[x + width * (y + height * z)] = tile(map, Vector2i(x, y), z)
	map.width = width
	map.height = height
	map.data.x_size = width
	map.data.y_size = height
	map.data.z_size = depth
	map.data.values = values
	return {"ok": true}


static func layer_count(map: Dictionary) -> int:
	return maxi(1, int(map.get("data", {}).get("z_size", 3)))


static func layer_names(map: Dictionary) -> Array:
	var names: Array = map.get("layer_names", []).duplicate()
	while names.size() < layer_count(map):
		names.append(
			["下层", "中层", "上层"][names.size()] if names.size() < 3 else "图块层 %d" % (names.size() + 1)
		)
	return names.slice(0, layer_count(map))


static func set_layer_count(map: Dictionary, count: int) -> Dictionary:
	if count < 1 or count > 32:
		return {"ok": false, "message": "图块层数量须为1..32。"}
	var old = layer_count(map)
	var area = int(map.width) * int(map.height)
	if count < old:
		for i in range(area * count, area * old):
			if int(map.data.values[i]) != 0:
				return {"ok": false, "message": "要移除的图层仍有图块，请先清空。"}
	map.data.values.resize(area * count)
	if count > old:
		for i in range(area * old, area * count):
			map.data.values[i] = 0
	map.data.z_size = count
	map.data.dimensions = 3
	map.layer_names = layer_names(map)
	map["_editor_hidden_layers"] = map.get("_editor_hidden_layers", []).filter(
		func(z: Variant) -> bool: return int(z) < count
	)
	return {"ok": true}


static func next_event_id(map: Dictionary) -> int:
	var id = 1
	while map.get("events", {}).has(str(id)):
		id += 1
	return id


static func _write_tile(map: Dictionary, cell: Vector2i, layer: int, id: int) -> void:
	map.data.values[cell.x + int(map.width) * (cell.y + int(map.height) * layer)] = id


static func _same(a: int, b: int) -> bool:
	return int(a / 48) == int(b / 48) if a >= 48 and a < 384 and b >= 48 and b < 384 else a == b


static func _autotile_variant(map: Dictionary, c: Vector2i, z: int, slot: int) -> int:
	var joined = func(offset: Vector2i) -> bool:
		var n = c + offset
		return valid(map, n) and _same(tile(map, n, z), slot * 48)
	var l: bool = joined.call(Vector2i.LEFT)
	var u: bool = joined.call(Vector2i.UP)
	var r: bool = joined.call(Vector2i.RIGHT)
	var d: bool = joined.call(Vector2i.DOWN)
	var tl: bool = joined.call(Vector2i(-1, -1))
	var tr: bool = joined.call(Vector2i(1, -1))
	var bl: bool = joined.call(Vector2i(-1, 1))
	var br: bool = joined.call(Vector2i(1, 1))
	var missing = (0 if l else 1) + (0 if u else 2) + (0 if r else 4) + (0 if d else 8)
	match missing:
		0:
			return (0 if tl else 1) + (0 if tr else 2) + (0 if br else 4) + (0 if bl else 8)
		1:
			return 16 + (0 if tr else 1) + (0 if br else 2)
		2:
			return 20 + (0 if br else 1) + (0 if bl else 2)
		4:
			return 24 + (0 if bl else 1) + (0 if tl else 2)
		8:
			return 28 + (0 if tl else 1) + (0 if tr else 2)
		5:
			return 32
		10:
			return 33
		3:
			return 34 + (0 if br else 1)
		6:
			return 36 + (0 if bl else 1)
		12:
			return 38 + (0 if tl else 1)
		9:
			return 40 + (0 if tr else 1)
		7:
			return 42
		11:
			return 43
		13:
			return 44
		14:
			return 45
	return 46

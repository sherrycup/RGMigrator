## 职责：按原0026规则缓存玩家所在的上层遮挡连通区，计算160/255透明度；不改变地图数据或存档。
##
## 调用方式：
##   由MapRuntime创建并持有；地图或优先级重建时reset，地图时钟每次推进时update，绘制层仅消费opacity。
##   只处理原1、2层；地面及新增的更高层保持不透明。缓存和透明度属于派生表现，不写入存档。
##
## 调用接口：
##   func reset(map: Node, enabled: bool) -> void
##     用途：从当前图块及优先级重建遮挡掩码，清空旧地图的缓存。
##     参数 map（Node；必填）：当前正式MapRuntime；读取宽高、图块及优先级，不修改输入。
##     参数 enabled（bool；必填）：只对闪翼正式地图启用；false清空缓存并使用原生不透明表现。
##     返回：无返回值。
##
##   func update(position: Vector2i) -> Dictionary
##     用途：按玩家格坐标更新连通区，原地或同一区域复用缓存。
##     参数 position（Vector2i；必填）：玩家当前逻辑格坐标，不使用平滑像素坐标。
##     返回：透明度发生变化的格子集合（Vector2i键）；空字典表示无需重绘。
##
##   func opacity(x: int, y: int, layer: int) -> float
##     用途：查询一个图块的派生透明度。
##     参数 x（int；必填）：图块列号。
##     参数 y（int；必填）：图块行号。
##     参数 layer（int；必填）：从0开始的地图层号；仅1、2层可淡化。
##     返回：1.0为不透明；当前遮挡区的原上层返回160/255。
##
## 公开常量：OPACITY。
## 接口说明结束。

extends RefCounted

const OPACITY = 160.0 / 255.0
var _mask: Dictionary = {}
var _cells: Dictionary = {}
var _position: Variant = null


func reset(map: Node, enabled: bool) -> void:
	_mask.clear()
	_cells.clear()
	_position = null
	if not enabled:
		return
	for y in map.map_height():
		for x in map.map_width():
			for layer in range(1, mini(3, int(map.map_data.get("data", {}).get("z_size", 0)))):
				var id: int = map.tile_id(x, y, layer)
				if id != 0 and map.tile_priority(id) != 0:
					_mask[Vector2i(x, y)] = true
					break


func update(position: Vector2i) -> Dictionary:
	if _position == position:
		return {}
	_position = position
	if _cells.has(position):
		return {}
	var next: Dictionary = {}
	if _mask.has(position):
		var pending: Array[Vector2i] = [position]
		next[position] = true
		var index = 0
		while index < pending.size():
			var cell = pending[index]
			index += 1
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbour: Vector2i = cell + direction
				if _mask.has(neighbour) and not next.has(neighbour):
					next[neighbour] = true
					pending.append(neighbour)
	var changed: Dictionary = {}
	for cell in _cells:
		if not next.has(cell):
			changed[cell] = true
	for cell in next:
		if not _cells.has(cell):
			changed[cell] = true
	_cells = next
	return changed


func opacity(x: int, y: int, layer: int) -> float:
	return OPACITY if layer in [1, 2] and _cells.has(Vector2i(x, y)) else 1.0

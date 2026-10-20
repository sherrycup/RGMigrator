## 职责：加载地图图块和事件，管理地图现场、通行查询、触发调度与换图。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/MapRuntime.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func load_map(map_id: int) -> bool
##     参数 map_id（int；必填）：地图的原编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func ensure_character_layer() -> Node2D
##     参数：无。
##     返回：Node2D 类型的对象或值，供调用方继续使用。
##
##   func load_definition(definition: Dictionary, tileset_definition: Dictionary) -> void
##     参数 definition（Dictionary；必填）：对象的只读定义或原数据库记录。
##     参数 tileset_definition（Dictionary；必填）：当前图块集的只读数据库定义。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func apply_flash_tiles(changes: Dictionary, rebuild: bool = true) -> void
##     参数 changes（Dictionary；必填）：待应用的字段变化集合。
##     参数 rebuild（bool；默认值 true）：是否重新构建显示或索引。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func map_width() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func map_height() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func valid(x: int, y: int) -> bool
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func tile_id(x: int, y: int, layer: int) -> int
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 layer（int；必填）：图块或显示层编号。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func tile_priority(id: int) -> int
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func tile_texture(id: int) -> Texture2D
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：Texture2D 类型的对象或值，供调用方继续使用。
##
##   func can_overlap_trigger(cell: Vector2i) -> bool
##     参数 cell（Vector2i；必填）：图块、动画或表格的单元记录。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func terrain_tag(x: int, y: int) -> int
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func is_bush(x: int, y: int) -> bool
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func is_counter(x: int, y: int) -> bool
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func event_ids_at(x: int, y: int) -> Array[int]
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func can_move( from: Vector2i, direction: Vector2i, through: bool = false, ignore_event_id: int = -1 ) -> bool
##     参数 from（Vector2i；必填）：起始值、对象或位置。
##     参数 direction（Vector2i；必填）：当前操作使用的方向或选择移动量。
##     参数 through（bool；默认值 false）：是否允许穿透通行限制。
##     参数 ignore_event_id（int；默认值 -1）：通行或目标查询中排除的事件编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func can_stand(cell: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool
##     参数 cell（Vector2i；必填）：图块、动画或表格的单元记录。
##     参数 through（bool；默认值 false）：是否允许穿透通行限制。
##     参数 ignore_event_id（int；默认值 -1）：通行或目标查询中排除的事件编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func can_move_diagonal( from: Vector2i, offset: Vector2i, through: bool = false, ignore_event_id: int = -1 ) -> bool
##     参数 from（Vector2i；必填）：起始值、对象或位置。
##     参数 offset（Vector2i；必填）：相对基准的偏移量。
##     参数 through（bool；默认值 false）：是否允许穿透通行限制。
##     参数 ignore_event_id（int；默认值 -1）：通行或目标查询中排除的事件编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func request_action(position: Vector2i, facing: Vector2i) -> bool
##     参数 position（Vector2i；必填）：地图、屏幕或音频中的目标位置。
##     参数 facing（Vector2i；必填）：当前或目标朝向。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func trigger_player_touch(position: Vector2i, blocked: bool = false) -> bool
##     参数 position（Vector2i；必填）：地图、屏幕或音频中的目标位置。
##     参数 blocked（bool；默认值 false）：是否因通行限制而被阻挡。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func autorun_event() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func event_page(event_id: int) -> int
##     参数 event_id（int；必填）：当前地图上的事件编号；0 的具体含义由调用入口约定。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func refresh_events() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func event_contexts() -> Array[Dictionary]
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func event_node(id: int) -> Node
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：Node 类型的对象或值，供调用方继续使用。
##
##   func erase_event(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func has_erased_events() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func flush_event_refresh() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func request_event_touch(event: Node, target: Vector2i) -> bool
##     参数 event（Node；必填）：输入事件或当前游戏事件对象，类型见签名。
##     参数 target（Vector2i；必填）：操作或效果作用的目标。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func animation_target(character_id: int, current_event_id: int = 0) -> CanvasItem
##     参数 character_id（int；必填）：事件接口中的人物编号，沿用原指令约定。
##     参数 current_event_id（int；默认值 0）：执行这条指令的当前事件编号。
##     返回：CanvasItem 类型的对象或值，供调用方继续使用。
##
##   func set_character_position( target_id: int, mode: int, x: int, y: int, direction: int, current_event_id: int = 0 ) -> Dictionary
##     参数 target_id（int；必填）：目标对象的编号。
##     参数 mode（int；必填）：当前操作或显示模式。
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 current_event_id（int；默认值 0）：执行这条指令的当前事件编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func has_forced_routes() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func repeating_forced_routes() -> Array[int]
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func character_save_reason() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func cancel_character_routes() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func play_animation( animation_id: int, character_id: int = -1, current_event_id: int = 0, hit: bool = true ) -> Dictionary
##     参数 animation_id（int；必填）：动画的原数据库编号。
##     参数 character_id（int；默认值 -1）：事件接口中的人物编号，沿用原指令约定。
##     参数 current_event_id（int；默认值 0）：执行这条指令的当前事件编号。
##     参数 hit（bool；默认值 true）：本次命中或点击的目标数据。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func transfer(map_id: int, x: int, y: int, direction: int = 0) -> bool
##     参数 map_id（int；必填）：地图的原编号。
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 direction（int；默认值 0）：当前操作使用的方向或选择移动量。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func show_picture(parameters: Array) -> void
##     参数 parameters（Array；必填）：按对应接口或事件指令约定排列的参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func move_picture(parameters: Array) -> void
##     参数 parameters（Array；必填）：按对应接口或事件指令约定排列的参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func erase_picture(number: int) -> void
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func play_audio(code: int, audio: Variant) -> void
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 audio（Variant；必填）：音频名称、音量及音调等参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func stop_sound_effect() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func tile_opacity(x: int, y: int, layer: int) -> float
##     用途：读取原上层遮挡区的绘制透明度，不更改地图图块。
##     参数 x（int；必填）：地图列号。
##     参数 y（int；必填）：地图行号。
##     参数 layer（int；必填）：从0开始的地图层号。
##     返回：范围0..1的透明度；地面始终1。
##
##   func set_background_visible(value: bool) -> void
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_tile(canvas: CanvasItem, id: int, destination: Vector2, opacity: float = 1.0) -> void
##     参数 canvas（CanvasItem；必填）：用于绘制或预览的画布对象。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 destination（Vector2；必填）：输出目标、目标对象或位置。
##     参数 opacity（float；默认值 1.0）：绘制透明度，范围0..1，默认1.0；只影响此次绘制。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   event_requested(commands: Array, event_id: int)：由持有方发出，通知对应状态或操作结果。
##     commands：保持原顺序的事件指令列表。
##     event_id：当前地图上的事件编号；0 的具体含义由调用入口约定。
##   map_changed(map_id: int)：由持有方发出，通知对应状态或操作结果。
##     map_id：地图的原编号。
##   events_changed()：由持有方发出，通知对应状态或操作结果。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _draw() -> void
##
## 公开常量：TILE_SIZE、AUTOTILE_PARTS。
## 接口说明结束。

class_name MapRuntime
extends Node2D

const RuntimeData = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const MapEvent = preload("res://runtime/scripts/03_Map/MapEvent.gd")
const RmxpPlayer = preload("res://runtime/scripts/09_Effects/RmxpAnimationPlayer.gd")
const TileRow = preload("res://runtime/scripts/03_Map/MapTileRow.gd")
const Occlusion = preload("MapOcclusion.gd")
const TilesetLayout = preload("res://runtime/scripts/03_Map/TilesetLayout.gd")

signal event_requested(commands: Array, event_id: int)
signal map_changed(map_id: int)
signal events_changed
var player_trigger_request = false

const TILE_SIZE := 32
const AUTOTILE_PARTS := [
	[27, 28, 33, 34],
	[5, 28, 33, 34],
	[27, 6, 33, 34],
	[5, 6, 33, 34],
	[27, 28, 33, 12],
	[5, 28, 33, 12],
	[27, 6, 33, 12],
	[5, 6, 33, 12],
	[27, 28, 11, 34],
	[5, 28, 11, 34],
	[27, 6, 11, 34],
	[5, 6, 11, 34],
	[27, 28, 11, 12],
	[5, 28, 11, 12],
	[27, 6, 11, 12],
	[5, 6, 11, 12],
	[25, 26, 31, 32],
	[25, 6, 31, 32],
	[25, 26, 31, 12],
	[25, 6, 31, 12],
	[15, 16, 21, 22],
	[15, 16, 21, 12],
	[15, 16, 11, 22],
	[15, 16, 11, 12],
	[29, 30, 35, 36],
	[29, 30, 11, 36],
	[5, 30, 35, 36],
	[5, 30, 11, 36],
	[39, 40, 45, 46],
	[5, 40, 45, 46],
	[39, 6, 45, 46],
	[5, 6, 45, 46],
	[25, 30, 31, 36],
	[15, 16, 45, 46],
	[13, 14, 19, 20],
	[13, 14, 19, 12],
	[17, 18, 23, 24],
	[17, 18, 11, 24],
	[41, 42, 47, 48],
	[5, 42, 47, 48],
	[37, 38, 43, 44],
	[37, 6, 43, 44],
	[13, 18, 19, 24],
	[13, 14, 43, 44],
	[37, 42, 43, 48],
	[17, 18, 47, 48],
	[13, 18, 43, 48],
	[13, 18, 43, 48]
]

var map_data: Dictionary = {}
var tileset: Dictionary = {}
var _tileset_texture: Texture2D
var _normal_layout: RefCounted
var _autotile_textures: Array[Texture2D] = []
var _event_nodes: Array[MapEvent] = []
var _bgm: AudioStreamPlayer
var _bgs: AudioStreamPlayer
var player_character: Node2D
var _animations: Array[Node] = []
var character_layer: Node2D
var _events_at: Dictionary = {}
var _ground_tiles: Array[Vector4i] = []
var _tile_rows: Array[Node2D] = []
var _occlusion: RefCounted = Occlusion.new()
var _occlusion_rows: Dictionary = {}
var _autotile_seconds := 0.0
var _autotile_frame := 0
var _animated_ground := false
var _loaded_id := 0
var background_visible := true
var trigger_allowed: Callable
var generation := 0
var _erased_events: Dictionary = {}
var _page_dependencies: Dictionary = {}
var _dirty_event_ids: Dictionary = {}
var _dormant_events: Dictionary = {}


func _ready() -> void:
	RuntimeState.event_state_changed.connect(_mark_event_refresh)


func load_map(map_id: int) -> bool:
	var definition := RuntimeData.map(map_id)
	if (
		definition.is_empty()
		or int(definition.get("width", 0)) <= 0
		or int(definition.get("height", 0)) <= 0
	):
		return false
	map_data = definition.duplicate(true)
	_loaded_id = map_id
	RuntimeState.map_id = map_id
	_load_tileset()
	_finish_load()
	map_changed.emit(map_id)
	return true


func ensure_character_layer() -> Node2D:
	if character_layer == null:
		character_layer = Node2D.new()
		character_layer.y_sort_enabled = true
		add_child(character_layer)
	return character_layer


func load_definition(definition: Dictionary, tileset_definition: Dictionary) -> void:
	# Detached testing/native map input; never replaces the real database or map ID.
	map_data = definition.duplicate(true)
	tileset = tileset_definition.duplicate(true)
	_loaded_id = -1
	_load_textures()
	_finish_load()


func _finish_load() -> void:
	generation += 1
	_erased_events.clear()
	_dormant_events.clear()
	_dirty_event_ids.clear()
	for animation in _animations:
		if is_instance_valid(animation):
			animation.stop()
	_animations.clear()
	ensure_character_layer()
	_clear_events()
	if (
		RuntimeState.custom_data.manifest.get("profile") == "flash"
		and FileAccess.file_exists("res://data/flash_gameplay.json")
	):
		apply_flash_tiles(
			RuntimeState.custom_data.values.system.get("map_data", {}).get(str(_loaded_id), {}),
			false
		)
	_build_tile_rows()
	_build_events()
	queue_redraw()


func apply_flash_tiles(changes: Dictionary, rebuild: bool = true) -> void:
	var table: Dictionary = map_data.get("data", {})
	for key in changes:
		var coords: PackedStringArray = str(key).split(":")
		if coords.size() != 3:
			continue
		var x = int(coords[0])
		var y = int(coords[1])
		var z = int(coords[2])
		if not valid(x, y) or z < 0 or z >= int(table.get("z_size", 0)):
			continue
		var offset = x + y * int(table.x_size) + z * int(table.x_size) * int(table.y_size)
		table.values[offset] = int(changes[key])
	if rebuild:
		_build_tile_rows()
		queue_redraw()


func map_width() -> int:
	return int(map_data.get("width", 0))


func map_height() -> int:
	return int(map_data.get("height", 0))


func valid(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < map_width() and y < map_height()


func tile_id(x: int, y: int, layer: int) -> int:
	return _table_value(map_data.get("data", {}), x, y, layer) if valid(x, y) else 0


func tile_priority(id: int) -> int:
	return _table_value(tileset.get("priorities", {}), id, 0, 0)


func tile_texture(id: int) -> Texture2D:
	if _normal_layout == null:
		_normal_layout = TilesetLayout.new()
		_normal_layout.configure(tileset, Cache.tileset)
	return _normal_layout.tile_texture(id)


func can_overlap_trigger(cell: Vector2i) -> bool:
	# RMXP over_trigger? checks passable?(x, y, 0), including tile events.
	# Direction 0 ignores individual direction bits, but rejects fully solid tiles.
	return _passable_at(cell, 0)


func terrain_tag(x: int, y: int) -> int:
	if not valid(x, y):
		return 0
	for layer in range(int(map_data.get("data", {}).get("z_size", 0)) - 1, -1, -1):
		var tag := _table_value(tileset.get("terrain_tags", {}), tile_id(x, y, layer), 0, 0)
		if tag > 0:
			return tag
	return 0


func is_bush(x: int, y: int) -> bool:
	return _has_tile_flag(x, y, 0x40)


func is_counter(x: int, y: int) -> bool:
	return _has_tile_flag(x, y, 0x80)


func _has_tile_flag(x: int, y: int, mask: int) -> bool:
	if not valid(x, y):
		return false
	for layer in int(map_data.get("data", {}).get("z_size", 0)):
		if (_passage(tile_id(x, y, layer)) & mask) != 0:
			return true
	return false


func event_ids_at(x: int, y: int) -> Array[int]:
	var result: Array[int] = []
	for event in _events_at.get(Vector2i(x, y), []):
		if is_instance_valid(event):
			result.append(event.event_id)
	result.sort()
	return result


func can_move(
	from: Vector2i, direction: Vector2i, through: bool = false, ignore_event_id: int = -1
) -> bool:
	if _direction_bit(direction) == 0 or not valid(from.x, from.y):
		return false
	var target := from + direction
	if not valid(target.x, target.y):
		return false
	if through:
		return true
	if _blocked_by_event(target, ignore_event_id) or _blocked_by_player(target, ignore_event_id):
		return false
	var direction_bit := _direction_bit(direction)
	var reverse_bit := _direction_bit(-direction)
	return (
		_passable_at(from, direction_bit, ignore_event_id)
		and _passable_at(target, reverse_bit, ignore_event_id)
	)


func can_stand(cell: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool:
	if not valid(cell.x, cell.y):
		return false
	if through:
		return true
	if _blocked_by_event(cell, ignore_event_id) or _blocked_by_player(cell, ignore_event_id):
		return false
	for bit in [1, 2, 4, 8]:
		if _passable_at(cell, bit, ignore_event_id):
			return true
	return false


func can_move_diagonal(
	from: Vector2i, offset: Vector2i, through: bool = false, ignore_event_id: int = -1
) -> bool:
	if absi(offset.x) != 1 or absi(offset.y) != 1:
		return false
	var horizontal := Vector2i(offset.x, 0)
	var vertical := Vector2i(0, offset.y)
	return (
		(
			can_move(from, horizontal, through, ignore_event_id)
			and can_move(from + horizontal, vertical, through, ignore_event_id)
		)
		or (
			can_move(from, vertical, through, ignore_event_id)
			and can_move(from + vertical, horizontal, through, ignore_event_id)
		)
	)


func _passable_at(tile: Vector2i, bit: int, ignore_event_id: int = -1) -> bool:
	if not valid(tile.x, tile.y):
		return false
	for event in _events_at.get(tile, []):
		if event.event_id != ignore_event_id and not event.through and event.tile_id > 0:
			if (_passage(event.tile_id) & bit) != 0 or (_passage(event.tile_id) & 15) == 15:
				return false
			if tile_priority(event.tile_id) == 0:
				return true
	var table: Dictionary = map_data.get("data", {})
	var priorities: Dictionary = tileset.get("priorities", {})
	for layer in range(int(table.get("z_size", 0)) - 1, -1, -1):
		var tile_id := _table_value(table, tile.x, tile.y, layer)
		if tile_id == 0:
			continue
		if (_passage(tile_id) & bit) != 0 or (_passage(tile_id) & 15) == 15:
			return false
		if _table_value(priorities, tile_id, 0, 0) == 0:
			return true
	return true


func request_action(position: Vector2i, facing: Vector2i) -> bool:
	if _emit_at(position, [0], false):
		return true
	var target := position + facing
	if _emit_at(target, [0, 1, 2], true):
		return true
	if is_counter(target.x, target.y):
		return _emit_at(target + facing, [0, 1, 2], true)
	return false


func trigger_player_touch(position: Vector2i, blocked: bool = false) -> bool:
	return _emit_at(position, [1, 2], blocked)


func _emit_at(cell: Vector2i, triggers: Array, in_front: bool) -> bool:
	if trigger_allowed.is_valid() and not trigger_allowed.call():
		return false
	for event in _events_at.get(cell, []):
		if (
			event.trigger in triggers
			and event.front_interaction() == in_front
			and event.is_idle()
			and event.commands.size() > 1
		):
			player_trigger_request = true
			event_requested.emit(event.commands, event.event_id)
			player_trigger_request = false
			return true
	return false


func autorun_event() -> Dictionary:
	for event_node in _event_nodes:
		if event_node.trigger == 3:
			return {"commands": event_node.commands, "event_id": event_node.event_id}
	return {}


func event_page(event_id: int) -> int:
	for event_node in _event_nodes:
		if event_node.event_id == event_id:
			return event_node.page_index
	return 1


func refresh_events() -> void:
	_build_events()


func event_contexts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _event_nodes:
		result.append(
			{
				"event_id": event.event_id,
				"page": event.page_index,
				"trigger": event.trigger,
				"commands": event.commands,
				"node": event
			}
		)
	return result


func event_node(id: int) -> Node:
	for event in _event_nodes:
		if event.event_id == id:
			return event
	return null


func erase_event(id: int) -> Dictionary:
	if not map_data.get("events", {}).has(str(id)):
		return {"ok": false, "message": "当前地图事件%d不存在。" % id}
	_erased_events[id] = true
	_dirty_event_ids[id] = true
	flush_event_refresh()
	return {"ok": true}


func has_erased_events() -> bool:
	return not _erased_events.is_empty()


func flush_event_refresh() -> void:
	if _dirty_event_ids.is_empty():
		return
	var changed := _dirty_event_ids.keys()
	_dirty_event_ids.clear()
	_build_events(changed)


func request_event_touch(event: Node, target: Vector2i) -> bool:
	if (
		player_character == null
		or event.trigger != 2
		or event.motion.jumping()
		or player_character.jumping()
	):
		return false
	if target != player_character.tile_position:
		return false
	if trigger_allowed.is_valid() and not trigger_allowed.call():
		return false
	if event.commands.size() <= 1:
		return false
	event_requested.emit(event.commands, event.event_id)
	return true


func _mark_event_refresh(kind: String, key: String) -> void:
	for id in _page_dependencies.get(kind + ":" + key, []):
		_dirty_event_ids[id] = true


func animation_target(character_id: int, current_event_id: int = 0) -> CanvasItem:
	if character_id == -1:
		return player_character
	var resolved := current_event_id if character_id == 0 else character_id
	for event in _event_nodes:
		if event.event_id == resolved:
			return event
	return null


func set_character_position(
	target_id: int, mode: int, x: int, y: int, direction: int, current_event_id: int = 0
) -> Dictionary:
	var target: Node2D = animation_target(target_id, current_event_id)
	if target == null:
		return {"ok": false, "message": "位置目标人物%d不存在。" % target_id}
	var destination := Vector2i(x, y)
	var other: Node2D
	if mode == 2:
		other = animation_target(x, current_event_id)
		if other == null:
			return {"ok": false, "message": "交换目标人物%d不存在，未修改位置。" % x}
		destination = other.tile_position
	if not valid(destination.x, destination.y):
		return {"ok": false, "message": "目标位置越出地图，未修改位置。"}
	var original: Vector2i = target.tile_position
	if other != null and not valid(original.x, original.y):
		return {"ok": false, "message": "交换原位置无效，未修改位置。"}
	target.move_to(destination.x, destination.y)
	if other != null:
		other.move_to(original.x, original.y)
	if direction != 0:
		target.turn(direction)
	return {"ok": true}


func has_forced_routes() -> bool:
	if player_character != null and player_character.routes.forcing:
		return true
	for event in _event_nodes:
		if event.routes.forcing:
			return true
	return false


func repeating_forced_routes() -> Array[int]:
	var ids: Array[int] = []
	if player_character != null and player_character.routes.repeat_forced():
		ids.append(-1)
	for event in _event_nodes:
		if event.routes.repeat_forced():
			ids.append(event.event_id)
	return ids


func character_save_reason() -> String:
	# All current-map character/route state is persisted by EventPersistence.
	return ""


func cancel_character_routes() -> void:
	if player_character != null:
		player_character.cancel_move_route(true)
	for event in _event_nodes:
		event.cancel_move_route(true)


func play_animation(
	animation_id: int, character_id: int = -1, current_event_id: int = 0, hit: bool = true
) -> Dictionary:
	var target := animation_target(character_id, current_event_id)
	var reference: WeakRef = weakref(target) if target != null else null
	var provider := func() -> CanvasItem:
		var node: CanvasItem = reference.get_ref() if reference != null else null
		return (
			node
			if node != null and node.is_inside_tree() and not node.is_queued_for_deletion()
			else null
		)
	var result := RmxpPlayer.play(self, animation_id, provider, hit)
	if result.get("ok", false) and result.has("player"):
		for index in range(_animations.size() - 1, -1, -1):
			if (
				not is_instance_valid(_animations[index])
				or _animations[index].is_queued_for_deletion()
			):
				_animations.remove_at(index)
		_animations.append(result.player)
	return result


func transfer(map_id: int, x: int, y: int, direction: int = 0) -> bool:
	var candidate := RuntimeData.map(map_id)
	if (
		x < 0
		or y < 0
		or x >= int(candidate.get("width", 0))
		or y >= int(candidate.get("height", 0))
	):
		return false
	if direction not in [0, 2, 4, 6, 8]:
		return false
	var map_system: RefCounted = (
		RuntimeState.custom_data.map_system() if _flash_map_enabled() else null
	)
	var previous: Dictionary = map_system.capture_location() if map_system != null else {}
	if map_id != _loaded_id:
		if player_character != null:
			player_character.cancel_move_route()
		if not load_map(map_id):
			return false
	RuntimeState.player_motion.relocate(Vector2i(x, y))
	if direction != 0:
		RuntimeState.player_motion.turn(direction)
	if player_character != null:
		player_character._sync_position()
	if RuntimeState.flash_followers != null:
		RuntimeState.flash_followers.moveto_party_actors(x, y)
	if map_system != null and not previous.is_empty():
		map_system.record_transfer(previous, map_system.capture_location())
	return true


func _flash_map_enabled() -> bool:
	return (
		RuntimeState.custom_data.manifest.get("profile") == "flash"
		and FileAccess.file_exists("res://data/flash_gameplay.json")
		and _loaded_id > 0
	)


func show_picture(parameters: Array) -> void:
	# Legacy internal helper, not connected to an additional event command.
	RuntimeState.show_picture(
		int(_param(parameters, 0, 0)),
		str(_param(parameters, 1, "")),
		{
			"origin": int(_param(parameters, 2, 0)),
			"x": float(_param(parameters, 4, 0)),
			"y": float(_param(parameters, 5, 0)),
			"zoom_x": float(_param(parameters, 6, 100)),
			"zoom_y": float(_param(parameters, 7, 100)),
			"opacity": float(_param(parameters, 8, 255)),
			"blend_type": int(_param(parameters, 9, 0))
		}
	)


func move_picture(parameters: Array) -> void:
	RuntimeState.move_picture(
		int(_param(parameters, 0, 0)),
		{
			"origin": int(_param(parameters, 2, 0)),
			"x": float(_param(parameters, 4, 0)),
			"y": float(_param(parameters, 5, 0)),
			"zoom_x": float(_param(parameters, 6, 100)),
			"zoom_y": float(_param(parameters, 7, 100)),
			"opacity": float(_param(parameters, 8, 255)),
			"blend_type": int(_param(parameters, 9, 0))
		},
		float(_param(parameters, 1, 0)) / 40.0
	)


func erase_picture(number: int) -> void:
	RuntimeState.erase_picture(number)


func play_audio(code: int, audio: Variant) -> void:
	if not (audio is Dictionary):
		return
	var kind: String = {241: "BGM", 245: "BGS", 249: "ME", 250: "SE"}.get(code, "")
	var result: Dictionary = RuntimeState.audio.play(kind, audio)
	if not result.ok:
		RuntimeState.report_diagnostic(result.message)


func stop_sound_effect() -> void:
	RuntimeState.audio.stop("SE")


func _param(parameters: Array, index: int, fallback: Variant) -> Variant:
	return parameters[index] if index >= 0 and index < parameters.size() else fallback


func _load_tileset() -> void:
	tileset = {}
	_tileset_texture = null
	_autotile_textures.clear()
	_autotile_textures.resize(7)
	var all_tilesets: Variant = RuntimeData.database("Tilesets")
	var index := int(map_data.get("tileset_id", 0))
	if (
		all_tilesets is Array
		and index >= 0
		and index < all_tilesets.size()
		and all_tilesets[index] is Dictionary
	):
		tileset = all_tilesets[index]
	_load_textures()


func _load_textures() -> void:
	_tileset_texture = null
	_autotile_textures.clear()
	_autotile_textures.resize(7)
	var name := str(tileset.get("tileset_name", ""))
	_tileset_texture = Cache.tileset(name)
	_normal_layout = TilesetLayout.new()
	_normal_layout.configure(tileset, Cache.tileset)
	for error in _normal_layout.errors:
		RuntimeState.report_diagnostic("地图图块集：" + error)
	# Canvas draw commands keep texture RIDs, not Texture2D references. Keep the
	# resources alive for the whole map; a local load() in _draw_autotile() can
	# free them before the renderer consumes the commands, producing white tiles.
	var names: Array = tileset.get("autotile_names", [])
	for slot in mini(names.size(), _autotile_textures.size()):
		var autotile_name := str(names[slot])
		if autotile_name.is_empty():
			continue
		_autotile_textures[slot] = Cache.autotile(autotile_name)


func _clear_events() -> void:
	for event_node in _event_nodes:
		if is_instance_valid(event_node):
			if event_node.get_parent() != null:
				event_node.get_parent().remove_child(event_node)
			event_node.queue_free()
	_event_nodes.clear()
	_events_at.clear()


func _build_events(changed: Array = []) -> void:
	var events: Variant = map_data.get("events", {})
	if not (events is Dictionary):
		return
	var previous := {}
	for node in _event_nodes:
		previous[node.event_id] = node
	_event_nodes.clear()
	_page_dependencies.clear()
	for key in events:
		var event_data: Variant = events[key]
		if not (event_data is Dictionary):
			continue
		var id := int(key)
		for candidate in event_data.get("pages", []):
			if not candidate is Dictionary:
				continue
			var condition: Dictionary = candidate.get("condition", {})
			for name_value in ["switch1", "switch2", "variable", "self_switch"]:
				if not condition.get(name_value + "_valid", false):
					continue
				var dependency: String
				if name_value == "self_switch":
					dependency = (
						"self:"
						+ RuntimeState.self_switch_key(
							RuntimeState.map_id, id, str(condition.get("self_switch_ch", "A"))
						)
					)
				else:
					dependency = (
						("switch" if name_value.begins_with("switch") else "variable")
						+ ":"
						+ str(int(condition.get(name_value + "_id", 0)))
					)
				if not _page_dependencies.has(dependency):
					_page_dependencies[dependency] = []
				if id not in _page_dependencies[dependency]:
					_page_dependencies[dependency].append(id)
		if not changed.is_empty() and id not in changed and previous.has(id):
			_event_nodes.append(previous[id])
			previous.erase(id)
			continue
		if _erased_events.has(id):
			continue
		if (
			RuntimeState.custom_data.manifest.get("profile") == "flash"
			and FileAccess.file_exists("res://data/flash_gameplay.json")
			and preload("MapBridge.gd").is_dead(
				RuntimeState.custom_data, RuntimeState.map_id, id
			)
		):
			continue
		var page := _active_page(event_data, int(key))
		if page.is_empty():
			continue
		var event_node: MapEvent = previous.get(int(key))
		if event_node == null:
			event_node = MapEvent.new()
			event_node.map_runtime = self
			ensure_character_layer().add_child(event_node)
			event_node.occupancy_changed.connect(_reindex_events)
		previous.erase(int(key))
		event_node.configure(event_data, page, int(key), _loaded_id)
		if RuntimeState.custom_data.manifest.get("profile") == "flash":
			var overrides: Dictionary = (
				RuntimeState
				. custom_data
				. values
				. system
				. get("event_page", {})
				. get(str(_loaded_id), {})
				. get(str(id), {})
			)
			if overrides.get("list") is Array:
				event_node.commands = overrides.list.duplicate(true)
		if _dormant_events.has(id):
			var saved_motion: Dictionary = _dormant_events[id].motion
			event_node.move_to(int(saved_motion.cell[0]), int(saved_motion.cell[1]))
			_dormant_events.erase(id)
		event_node.page_index = event_data.get("pages", []).find(page) + 1
		_event_nodes.append(event_node)
	for removed in previous.values():
		_dormant_events[removed.event_id] = removed.persistent_data()
		removed.get_parent().remove_child(removed)
		removed.queue_free()
	# Equal foot depth uses child order. Keep the leader in front of a same-cell
	# event without a global z_index that would defeat foreground tile sorting.
	if is_instance_valid(player_character) and player_character.get_parent() == character_layer:
		character_layer.move_child(player_character, -1)
	_reindex_events()
	events_changed.emit()


func _reindex_events() -> void:
	_events_at.clear()
	for event in _event_nodes:
		for cell in event.occupied_cells():
			if not _events_at.has(cell):
				_events_at[cell] = []
			_events_at[cell].append(event)


func _active_page(event_data: Dictionary, event_id: int) -> Dictionary:
	var pages: Variant = event_data.get("pages", [])
	if not (pages is Array):
		return {}
	for index in range(pages.size() - 1, -1, -1):
		var page: Variant = pages[index]
		if page is Dictionary and _page_conditions_met(page.get("condition", {}), event_id):
			return page
	return {}


func _page_conditions_met(condition: Variant, event_id: int) -> bool:
	if not (condition is Dictionary):
		return true
	if (
		bool(condition.get("switch1_valid", false))
		and not bool(RuntimeState.switches.get(str(int(condition.get("switch1_id", 0))), false))
	):
		return false
	if (
		bool(condition.get("switch2_valid", false))
		and not bool(RuntimeState.switches.get(str(int(condition.get("switch2_id", 0))), false))
	):
		return false
	if bool(condition.get("variable_valid", false)):
		var value: Variant = RuntimeState.variables.get(
			str(int(condition.get("variable_id", 0))), 0
		)
		if not preload("res://runtime/scripts/02_Event/EventValueResolver.gd").numeric_variable(
			value
		):
			RuntimeState.report_diagnostic(
				"Map%03d 事件页数值条件引用了自定义集合变量%d。" % [_loaded_id, int(condition.get("variable_id", 0))]
			)
			return false
		if int(value) < int(condition.get("variable_value", 0)):
			return false
	if bool(condition.get("self_switch_valid", false)):
		var key := RuntimeState.self_switch_key(
			RuntimeState.map_id, event_id, str(condition.get("self_switch_ch", "A"))
		)
		if not bool(RuntimeState.self_switches.get(key, false)):
			return false
	if (
		bool(condition.get("item_valid", false))
		and int(RuntimeState.inventory.get("item:%s" % condition.get("item_id", 0), 0)) <= 0
	):
		return false
	return true


func _blocked_by_event(position: Vector2i, ignore_event_id: int = -1) -> bool:
	for event_node in _events_at.get(position, []):
		if (
			event_node.event_id != ignore_event_id
			and not event_node.through
			and event_node.blocking
		):
			return true
	return false


func _blocked_by_player(cell: Vector2i, ignore_event_id: int) -> bool:
	return (
		ignore_event_id != -1
		and player_character != null
		and not player_character.motion.options.through
		and cell in player_character.occupied_cells()
	)


func _top_tile(x: int, y: int) -> int:
	var table: Variant = map_data.get("data", {})
	if not (table is Dictionary):
		return 0
	for layer in range(max(0, int(table.get("z_size", 0)) - 1), -1, -1):
		var value := _table_value(table, x, y, layer)
		if value > 0:
			return value
	return 0


func _passage(tile_id: int) -> int:
	var table: Variant = tileset.get("passages", {})
	if not (table is Dictionary):
		return 0
	return _table_value(table, tile_id, 0, 0)


func _table_value(table: Dictionary, x: int, y: int, z: int) -> int:
	var x_size := int(table.get("x_size", 0))
	var y_size := int(table.get("y_size", 1))
	var z_size := int(table.get("z_size", 1))
	if x < 0 or y < 0 or z < 0 or x >= x_size or y >= y_size or z >= z_size:
		return 0
	var values: Variant = table.get("values", [])
	var index := x + x_size * (y + y_size * z)
	if values is Array and index >= 0 and index < values.size():
		return int(values[index])
	return 0


func _direction_bit(direction: Vector2i) -> int:
	if direction == Vector2i.DOWN:
		return 0x01
	if direction == Vector2i.LEFT:
		return 0x02
	if direction == Vector2i.RIGHT:
		return 0x04
	if direction == Vector2i.UP:
		return 0x08
	return 0


func _build_tile_rows() -> void:
	for row in _tile_rows:
		row.get_parent().remove_child(row)
		row.queue_free()
	_tile_rows.clear()
	_ground_tiles.clear()
	_occlusion_rows.clear()
	_occlusion.reset(self, _flash_map_enabled())
	_animated_ground = false
	_autotile_seconds = 0
	_autotile_frame = 0
	var rows := {}
	for layer in int(map_data.get("data", {}).get("z_size", 0)):
		for y in map_height():
			for x in map_width():
				var id := tile_id(x, y, layer)
				if id <= 0:
					continue
				var cell := Vector4i(x, y, layer, id)
				var animated := _animated_tile(id)
				var priority := tile_priority(id)
				if priority == 0:
					_ground_tiles.append(cell)
					_animated_ground = _animated_ground or animated
				else:
					var depth := y + priority
					if not rows.has(depth):
						var row := TileRow.new()
						row.map_runtime = self
						row.position.y = depth * 32 - 16
						ensure_character_layer().add_child(row)
						_tile_rows.append(row)
						rows[depth] = row
					rows[depth].cells.append(cell)
					rows[depth].animated = rows[depth].animated or animated
					if layer in [1, 2]:
						var location := Vector2i(x, y)
						if not _occlusion_rows.has(location):
							_occlusion_rows[location] = []
						if not _occlusion_rows[location].has(rows[depth]):
							_occlusion_rows[location].append(rows[depth])
	_update_occlusion()


func tile_opacity(x: int, y: int, layer: int) -> float:
	return _occlusion.opacity(x, y, layer)


func _update_occlusion() -> void:
	var changed: Dictionary = _occlusion.update(
		Vector2i(RuntimeState.player_x, RuntimeState.player_y)
	)
	if changed.is_empty():
		return
	var rows: Dictionary = {}
	for cell in changed:
		for row in _occlusion_rows.get(cell, []):
			rows[row] = true
	for row in rows:
		row.queue_redraw()
	# Upper tiles with priority zero are batched with the ground, but still fade.
	queue_redraw()


func _animated_tile(id: int) -> bool:
	var slot := int(id / 48) - 1
	if id >= 384 or slot < 0 or slot >= _autotile_textures.size():
		return false
	var texture: Texture2D = _autotile_textures[slot]
	return texture != null and texture.get_width() > (32 if texture.get_height() == 32 else 96)


func _process(delta: float) -> void:
	if (
		RuntimeState.game() != null
		and RuntimeState.game().event_map() == self
		and RuntimeState.map_time_paused()
	):
		return
	_update_occlusion()
	_autotile_seconds += delta
	var period: float = (
		preload("Tilemap.gd").ANIMATION_SECONDS if _flash_map_enabled() else 0.25
	)
	if _autotile_seconds < period:
		return
	_autotile_frame += int(_autotile_seconds / period)
	_autotile_seconds = fmod(_autotile_seconds, period)
	if _animated_ground:
		queue_redraw()
	for row in _tile_rows:
		if row.animated:
			row.queue_redraw()


func _draw() -> void:
	if background_visible:
		draw_rect(
			Rect2(Vector2.ZERO, Vector2(map_width(), map_height()) * TILE_SIZE), Color("202d37")
		)
	for cell in _ground_tiles:
		draw_tile(
			self, cell.w, Vector2(cell.x * 32, cell.y * 32), tile_opacity(cell.x, cell.y, cell.z)
		)


func set_background_visible(value: bool) -> void:
	if background_visible != value:
		background_visible = value
		queue_redraw()


func draw_tile(canvas: CanvasItem, id: int, destination: Vector2, opacity: float = 1.0) -> void:
	if id <= 0:
		return
	if id >= 384:
		if _normal_layout == null:
			return
		var found: Dictionary = _normal_layout.locate(id)
		if not found.is_empty():
			canvas.draw_texture_rect_region(
				found.texture,
				Rect2(destination, Vector2(32, 32)),
				found.region,
				Color(1, 1, 1, opacity)
			)
	elif id < 384:
		var slot := int(id / 48) - 1
		if slot < 0 or slot >= _autotile_textures.size():
			return
		var texture: Texture2D = _autotile_textures[slot]
		if texture == null:
			return
		if texture.get_height() == 32:
			var frame := _autotile_frame % maxi(1, int(texture.get_width() / 32))
			canvas.draw_texture_rect_region(
				texture,
				Rect2(destination, Vector2(32, 32)),
				Rect2(frame * 32, 0, 32, 32),
				Color(1, 1, 1, opacity)
			)
			return
		var variant := id % 48
		var frame := _autotile_frame % maxi(1, int(texture.get_width() / 96))
		var parts: Array = (
			preload("Tilemap.gd").parts(variant)
			if _flash_map_enabled()
			else AUTOTILE_PARTS[variant]
		)
		for quadrant in 4:
			var part := int(parts[quadrant]) - 1
			var source := Rect2(frame * 96 + (part % 6) * 16, int(part / 6) * 16, 16, 16)
			canvas.draw_texture_rect_region(
				texture,
				Rect2(
					destination + Vector2((quadrant % 2) * 16, int(quadrant / 2) * 16),
					Vector2(16, 16)
				),
				source,
				Color(1, 1, 1, opacity)
			)

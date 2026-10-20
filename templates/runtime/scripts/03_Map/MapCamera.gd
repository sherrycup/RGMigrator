## 职责：跟随地图人物并限制视口范围，协调地图滚动和摄像机位置。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/MapCamera.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func sync(delta: float = 0.0, snap: bool = false) -> void
##     用途：把当前状态同步到关联对象。
##     参数 delta（float；默认值 0.0）：本次推进的时间差，单位为秒。
##     参数 snap（bool；默认值 false）：已捕获的状态快照。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func scroll(direction: int, tiles: Variant, seconds: Variant) -> Dictionary
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 tiles（Variant；必填）：地图或图块集的图块数据。
##     参数 seconds（Variant；必填）：以秒计的时长。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

extends Camera2D
var model: RefCounted
var map: Node2D
var player: Node2D
var _map_id := -999
var _revision := -1


func _ready() -> void:
	# One owner of camera position. ScreenRenderer owns only shake offset.
	position_smoothing_enabled = false


func sync(delta: float = 0.0, snap: bool = false) -> void:
	if model == null or map == null or player == null:
		return
	var extent := Vector2(map.map_width(), map.map_height()) * 32
	var focus := Vector2(player.motion.visual_cell) * 32 + Vector2(16, 16)
	var changed := _map_id != int(map.get("_loaded_id"))
	# A restored model keeps its manual scroll. A real map change recenters.
	if changed and _map_id != -999:
		if model.native_follow:
			model.resume_follow()
		model.scroll_remaining = 0
		model.initialized = false
	model.advance(
		delta, focus, extent, get_viewport_rect().size, snap or (changed and not model.initialized)
	)
	_map_id = int(map.get("_loaded_id"))
	_revision = model.revision
	var rect: Rect2 = model.view_rect(get_viewport_rect().size)
	position = model.display + get_viewport_rect().size / 2 - rect.position
	# Limits remain available to callers, but manual positioning enforces view-size bounds.
	limit_enabled = false
	limit_left = int(minf(0, (extent.x - rect.size.x) / 2))
	limit_top = int(minf(0, (extent.y - rect.size.y) / 2))
	limit_right = int(maxf(extent.x, rect.size.x + limit_left))
	limit_bottom = int(maxf(extent.y, rect.size.y + limit_top))
	force_update_scroll()


func _process(delta: float) -> void:
	sync(0.0 if model == RuntimeState.map_view and RuntimeState.map_time_paused() else delta)


func scroll(direction: int, tiles: Variant, seconds: Variant) -> Dictionary:
	return model.scroll(
		direction,
		tiles,
		seconds,
		Vector2(map.map_width(), map.map_height()) * 32,
		get_viewport_rect().size
	)

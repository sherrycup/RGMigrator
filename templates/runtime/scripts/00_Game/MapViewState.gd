## 职责：维护地图视图的滚动、全景、雾与显示参数，供事件修改和渲染恢复。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/MapViewState.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/MapViewState.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   static func valid_options(value: Variant) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func configure(changes: Dictionary) -> Dictionary
##     用途：配置本实例使用的数据和依赖。
##     参数 changes（Dictionary；必填）：待应用的字段变化集合。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func view_rect(window_size: Vector2) -> Rect2
##     参数 window_size（Vector2；必填）：窗口的宽度与高度。
##     返回：Rect2 类型的对象或值，供调用方继续使用。
##
##   func follow_center(window_size: Vector2) -> Vector2
##     参数 window_size（Vector2；必填）：窗口的宽度与高度。
##     返回：Vector2 类型的对象或值，供调用方继续使用。
##
##   func bounded(point: Vector2, extent: Vector2, window_size: Vector2) -> Vector2
##     参数 point（Vector2；必填）：位置或几何点。
##     参数 extent（Vector2；必填）：区域边界或可用尺寸。
##     参数 window_size（Vector2；必填）：窗口的宽度与高度。
##     返回：Vector2 类型的对象或值，供调用方继续使用。
##
##   func advance( delta: float, focus: Vector2, extent: Vector2, window_size: Vector2, snap: bool = false ) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     参数 focus（Vector2；必填）：是否取得界面焦点。
##     参数 extent（Vector2；必填）：区域边界或可用尺寸。
##     参数 window_size（Vector2；必填）：窗口的宽度与高度。
##     参数 snap（bool；默认值 false）：已捕获的状态快照。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func scroll( direction: int, tiles: Variant, seconds: Variant, extent: Vector2, window_size: Vector2 ) -> Dictionary
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 tiles（Variant；必填）：地图或图块集的图块数据。
##     参数 seconds（Variant；必填）：以秒计的时长。
##     参数 extent（Vector2；必填）：区域边界或可用尺寸。
##     参数 window_size（Vector2；必填）：窗口的宽度与高度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func scroll_native( direction: int, tiles: int, speed: int, extent: Vector2, window_size: Vector2 ) -> Dictionary
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 tiles（int；必填）：地图或图块集的图块数据。
##     参数 speed（int；必填）：移动、播放或推进速度。
##     参数 extent（Vector2；必填）：区域边界或可用尺寸。
##     参数 window_size（Vector2；必填）：窗口的宽度与高度。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func resume_follow() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func decode(value: Variant) -> Dictionary
##     用途：解析编码数据并返回对应原值或结构。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：DEFAULTS。
## 接口说明结束。

extends RefCounted
## Display origin is in map pixels; follow_center is local to the map view, NOT the window.
const P = preload("res://runtime/scripts/00_Game/PictureState.gd")
const DEFAULTS := {"view_rect": [], "follow_center": [], "follow_enabled": true}
var options: Dictionary = DEFAULTS.duplicate(true)
var display := Vector2.ZERO
var scroll_target := Vector2.ZERO
var scroll_remaining := 0.0
var initialized := false
var revision := 0
var native_follow := false
var native_velocity := Vector2.ZERO
var _last_focus := Vector2.ZERO
var _focus_ready := false


static func valid_options(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not value.get("follow_enabled") is bool:
		return false
	for key in ["view_rect", "follow_center"]:
		if not value.get(key) is Array:
			return false
		var a: Array = value[key]
		if not a.is_empty() and a.size() != (4 if key == "view_rect" else 2):
			return false
		for number in a:
			if not P.numeric(number, 0, 100000):
				return false
	if not value.view_rect.is_empty() and (value.view_rect[2] < 1 or value.view_rect[3] < 1):
		return false
	if not value.follow_center.is_empty() and not value.view_rect.is_empty():
		if (
			value.follow_center[0] > value.view_rect[2]
			or value.follow_center[1] > value.view_rect[3]
		):
			return false
	return true


func configure(changes: Dictionary) -> Dictionary:
	var candidate := options.duplicate(true)
	for key in changes:
		if not candidate.has(key):
			return P.fail("未知镜头参数：%s" % key)
		candidate[key] = changes[key]
	if not valid_options(candidate):
		return P.fail("地图区域或跟随中心无效；使用逻辑像素，空数组代表自动。")
	options = candidate.duplicate(true)
	for key in ["view_rect", "follow_center"]:
		for index in options[key].size():
			options[key][index] = float(options[key][index])
	revision += 1
	return {"ok": true}


func view_rect(window_size: Vector2) -> Rect2:
	if options.view_rect.is_empty():
		return Rect2(Vector2.ZERO, window_size)
	var a: Array = options.view_rect
	# Resizing never leaves a zero/negative viewport. Preserve configured values.
	var pos := Vector2(
		minf(a[0], maxf(0, window_size.x - 1)), minf(a[1], maxf(0, window_size.y - 1))
	)
	return Rect2(
		pos,
		Vector2(
			maxf(1, minf(a[2], window_size.x - pos.x)), maxf(1, minf(a[3], window_size.y - pos.y))
		)
	)


func follow_center(window_size: Vector2) -> Vector2:
	var area := view_rect(window_size)
	if options.follow_center.is_empty():
		return area.size / 2
	return Vector2(options.follow_center[0], options.follow_center[1]).clamp(
		Vector2.ZERO, area.size
	)


func bounded(point: Vector2, extent: Vector2, window_size: Vector2) -> Vector2:
	var area := view_rect(window_size).size
	var result := point
	for axis in 2:
		result[axis] = (
			(extent[axis] - area[axis]) / 2
			if extent[axis] < area[axis]
			else clampf(point[axis], 0, extent[axis] - area[axis])
		)
	return result


func advance(
	delta: float, focus: Vector2, extent: Vector2, window_size: Vector2, snap: bool = false
) -> void:
	if not is_finite(delta) or delta < 0:
		return
	if scroll_remaining > 0 and not snap:
		if native_follow:
			display += native_velocity * minf(delta, scroll_remaining)
		else:
			display = display.lerp(scroll_target, minf(1, delta / scroll_remaining))
		scroll_remaining = maxf(0, scroll_remaining - delta)
		if scroll_remaining < 0.00000001:
			scroll_remaining = 0.0
	elif options.follow_enabled or not initialized or snap:
		var target := bounded(focus - follow_center(window_size), extent, window_size)
		display = target if snap or not initialized else display.lerp(target, 1 - exp(-8 * delta))
	if native_follow and _focus_ready and not snap:
		var movement := focus - _last_focus
		var center := follow_center(window_size)
		for axis in 2:
			var screen_position := focus[axis] - display[axis]
			if (
				(movement[axis] > 0 and screen_position > center[axis])
				or (movement[axis] < 0 and screen_position < center[axis])
			):
				display[axis] += movement[axis]
	_last_focus = focus
	_focus_ready = true
	display = bounded(display, extent, window_size)
	initialized = true


func scroll(
	direction: int, tiles: Variant, seconds: Variant, extent: Vector2, window_size: Vector2
) -> Dictionary:
	if (
		direction not in [2, 4, 6, 8]
		or not P.numeric(tiles, 0, 100000)
		or not P.numeric(seconds, 0, 3600)
	):
		return P.fail("滚图方向/格数/秒数无效。")
	if scroll_remaining > 0:
		return P.fail("镜头正在滚动，请等待完成或显式取消。")
	options.follow_enabled = false
	scroll_target = (
		display
		+ (
			{2: Vector2.DOWN, 4: Vector2.LEFT, 6: Vector2.RIGHT, 8: Vector2.UP}[direction]
			* float(tiles)
			* 32
		)
	)
	scroll_remaining = float(seconds)
	native_follow = false
	native_velocity = Vector2.ZERO
	if seconds == 0:
		display = bounded(scroll_target, extent, window_size)
	return {"ok": true}


func scroll_native(
	direction: int, tiles: int, speed: int, extent: Vector2, window_size: Vector2
) -> Dictionary:
	if speed < 1 or speed > 6:
		return P.fail("原生滚图速度须为1..6。")
	var result := scroll(
		direction, tiles, float(tiles) * 32 / (10 * pow(2, speed)), extent, window_size
	)
	if result.ok:
		native_follow = true
		native_velocity = (
			{2: Vector2.DOWN, 4: Vector2.LEFT, 6: Vector2.RIGHT, 8: Vector2.UP}[direction]
			* (10 * pow(2, speed))
		)
	return result


func resume_follow() -> void:
	scroll_remaining = 0
	native_follow = false
	native_velocity = Vector2.ZERO
	options.follow_enabled = true


func snapshot() -> Dictionary:
	return {
		"options": options.duplicate(true),
		"display": [display.x, display.y],
		"scroll_target": [scroll_target.x, scroll_target.y],
		"scroll_remaining": scroll_remaining,
		"initialized": initialized,
		"native_follow": native_follow,
		"native_velocity": [native_velocity.x, native_velocity.y]
	}


static func decode(value: Variant) -> Dictionary:
	if (
		not value is Dictionary
		or value.size() not in [5, 6, 7]
		or not value.get("native_follow", false) is bool
		or (value.size() >= 6 and not value.has("native_follow"))
		or not valid_options(value.get("options"))
		or not value.get("initialized") is bool
		or not P.numeric(value.get("scroll_remaining"), 0, 3600)
	):
		return P.fail("镜头存档无效。")
	var velocity: Variant = value.get("native_velocity", [0, 0])
	if (
		not velocity is Array
		or velocity.size() != 2
		or not P.numeric(velocity[0], -640, 640)
		or not P.numeric(velocity[1], -640, 640)
		or (velocity[0] != 0 and velocity[1] != 0)
	):
		return P.fail("镜头原生滚动速度无效。")
	if value.size() == 7 and not value.has("native_velocity"):
		return P.fail("镜头原生速度字段缺失。")
	for key in ["display", "scroll_target"]:
		if not value.get(key) is Array or value[key].size() != 2:
			return P.fail("镜头坐标无效。")
		for number in value[key]:
			if not P.numeric(number, -10000000, 10000000):
				return P.fail("镜头坐标无效。")
	var instance: RefCounted = load("res://runtime/scripts/00_Game/MapViewState.gd").new()
	instance.configure(value.options)
	instance.display = Vector2(value.display[0], value.display[1])
	instance.scroll_target = Vector2(value.scroll_target[0], value.scroll_target[1])
	instance.scroll_remaining = value.scroll_remaining
	instance.initialized = value.initialized
	instance.native_follow = value.get("native_follow", false)
	instance.native_velocity = Vector2(velocity[0], velocity[1])
	return {"ok": true, "value": instance}

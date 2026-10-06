extends RefCounted
## Display origin is in map pixels; follow_center is local to the map view, NOT the window.
const P = preload("res://runtime/scripts/PictureState.gd")
const DEFAULTS := {"view_rect": [], "follow_center": [], "follow_enabled": true}
var options: Dictionary = DEFAULTS.duplicate(true)
var display := Vector2.ZERO
var scroll_target := Vector2.ZERO
var scroll_remaining := 0.0
var initialized := false
var revision := 0

static func valid_options(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not value.get("follow_enabled") is bool: return false
	for key in ["view_rect", "follow_center"]:
		if not value.get(key) is Array: return false
		var a: Array = value[key]
		if not a.is_empty() and a.size() != (4 if key == "view_rect" else 2): return false
		for number in a:
			if not P.numeric(number, 0, 100000): return false
	if not value.view_rect.is_empty() and (value.view_rect[2] < 1 or value.view_rect[3] < 1): return false
	if not value.follow_center.is_empty() and not value.view_rect.is_empty():
		if value.follow_center[0] > value.view_rect[2] or value.follow_center[1] > value.view_rect[3]: return false
	return true

func configure(changes: Dictionary) -> Dictionary:
	var candidate := options.duplicate(true)
	for key in changes:
		if not candidate.has(key): return P.fail("未知镜头参数：%s" % key)
		candidate[key] = changes[key]
	if not valid_options(candidate): return P.fail("地图区域或跟随中心无效；使用逻辑像素，空数组代表自动。")
	options = candidate.duplicate(true)
	for key in ["view_rect", "follow_center"]:
		for index in options[key].size(): options[key][index] = float(options[key][index])
	revision += 1
	return {"ok": true}

func view_rect(window_size: Vector2) -> Rect2:
	if options.view_rect.is_empty(): return Rect2(Vector2.ZERO, window_size)
	var a: Array = options.view_rect
	# Resizing never leaves a zero/negative viewport. Preserve configured values.
	var pos := Vector2(minf(a[0], maxf(0, window_size.x - 1)), minf(a[1], maxf(0, window_size.y - 1)))
	return Rect2(pos, Vector2(maxf(1, minf(a[2], window_size.x - pos.x)), maxf(1, minf(a[3], window_size.y - pos.y))))

func follow_center(window_size: Vector2) -> Vector2:
	var area := view_rect(window_size)
	if options.follow_center.is_empty(): return area.size / 2
	return Vector2(options.follow_center[0], options.follow_center[1]).clamp(Vector2.ZERO, area.size)

func bounded(point: Vector2, extent: Vector2, window_size: Vector2) -> Vector2:
	var area := view_rect(window_size).size
	var result := point
	for axis in 2:
		result[axis] = (extent[axis] - area[axis]) / 2 if extent[axis] < area[axis] else clampf(point[axis], 0, extent[axis] - area[axis])
	return result

func advance(delta: float, focus: Vector2, extent: Vector2, window_size: Vector2, snap: bool = false) -> void:
	if not is_finite(delta) or delta < 0: return
	if scroll_remaining > 0 and not snap:
		display = display.lerp(bounded(scroll_target, extent, window_size), minf(1, delta / scroll_remaining))
		scroll_remaining = maxf(0, scroll_remaining - delta)
	elif options.follow_enabled or not initialized or snap:
		var target := bounded(focus - follow_center(window_size), extent, window_size)
		display = target if snap or not initialized else display.lerp(target, 1 - exp(-8 * delta))
	display = bounded(display, extent, window_size)
	initialized = true

func scroll(direction: int, tiles: Variant, seconds: Variant, extent: Vector2, window_size: Vector2) -> Dictionary:
	if direction not in [2, 4, 6, 8] or not P.numeric(tiles, 0, 100000) or not P.numeric(seconds, 0, 3600): return P.fail("滚图方向/格数/秒数无效。")
	if scroll_remaining > 0: return P.fail("镜头正在滚动，请等待完成或显式取消。")
	options.follow_enabled = false
	scroll_target = bounded(display + {2: Vector2.DOWN, 4: Vector2.LEFT, 6: Vector2.RIGHT, 8: Vector2.UP}[direction] * float(tiles) * 32, extent, window_size)
	scroll_remaining = float(seconds)
	if seconds == 0: display = scroll_target
	return {"ok": true}

func resume_follow() -> void:
	scroll_remaining = 0
	options.follow_enabled = true

func snapshot() -> Dictionary:
	return {"options": options.duplicate(true), "display": [display.x, display.y], "scroll_target": [scroll_target.x, scroll_target.y], "scroll_remaining": scroll_remaining, "initialized": initialized}

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 5 or not valid_options(value.get("options")) or not value.get("initialized") is bool or not P.numeric(value.get("scroll_remaining"), 0, 3600): return P.fail("镜头存档无效。")
	for key in ["display", "scroll_target"]:
		if not value.get(key) is Array or value[key].size() != 2: return P.fail("镜头坐标无效。")
		for number in value[key]:
			if not P.numeric(number, -10000000, 10000000): return P.fail("镜头坐标无效。")
	var instance: RefCounted = load("res://runtime/scripts/MapViewState.gd").new()
	instance.configure(value.options)
	instance.display = Vector2(value.display[0], value.display[1])
	instance.scroll_target = Vector2(value.scroll_target[0], value.scroll_target[1])
	instance.scroll_remaining = value.scroll_remaining
	instance.initialized = value.initialized
	return {"ok": true, "value": instance}

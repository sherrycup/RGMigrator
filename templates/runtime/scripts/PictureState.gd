extends RefCounted
## Native screen-space picture state. Durations are seconds; rotation is degrees/s.
const POSE := {"origin": 0, "x": 0.0, "y": 0.0, "zoom_x": 100.0, "zoom_y": 100.0, "opacity": 255.0, "blend_type": 0}
var _data: Dictionary


static func numeric(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func vector_valid(value: Variant, tone: bool = true) -> bool:
	if not value is Array or value.size() != 4: return false
	for index in 4:
		if not numeric(value[index], -255 if tone and index < 3 else 0, 255): return false
	return true


static func valid_name(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 1024 or value.is_absolute_path() or value.contains(":") or value.contains("\\"): return false
	for component in value.split("/"):
		if component in ["", ".", ".."]: return false
	for character in value:
		if character.unicode_at(0) < 32: return false
	return true


static func pose_valid(value: Variant, partial: bool = false) -> bool:
	if not value is Dictionary: return false
	if not partial and value.size() != POSE.size(): return false
	for key in value:
		if not POSE.has(key): return false
		var item: Variant = value[key]
		match key:
			"origin", "blend_type":
				if not numeric(item, 0, 1 if key == "origin" else 2) or floor(float(item)) != float(item): return false
			"x", "y":
				if not numeric(item, -1000000, 1000000): return false
			"zoom_x", "zoom_y":
				if not numeric(item, 0, 10000): return false
			"opacity":
				if not numeric(item, 0, 255): return false
	return true


static func create(number: int, name_value: String, pose: Dictionary = {}) -> RefCounted:
	if number < 1 or number > 50 or not valid_name(name_value) or not pose_valid(pose, true): return null
	var instance: RefCounted = load("res://runtime/scripts/PictureState.gd").new()
	instance._data = POSE.duplicate(true)
	instance._data.merge(pose, true)
	instance._data.merge({"number": number, "name": name_value, "tone": [0.0, 0.0, 0.0, 0.0], "angle": 0.0, "rotate_speed": 0.0,
		"move_target": instance.pose_snapshot(), "move_remaining": 0.0, "tone_target": [0.0, 0.0, 0.0, 0.0], "tone_remaining": 0.0})
	return instance


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary: return fail("图片必须为对象。")
	if value.size() != POSE.size() + 9: return fail("图片字段数量无效。")
	var pose := {}
	for key in POSE: pose[key] = value.get(key)
	if not pose_valid(pose) or not numeric(value.get("number"), 1, 50) or floor(float(value.number)) != float(value.number) or not valid_name(value.get("name")):
		return fail("图片编号、文件名或位置/缩放/混合参数无效。")
	if not pose_valid(value.get("move_target")) or not vector_valid(value.get("tone")) or not vector_valid(value.get("tone_target")):
		return fail("图片移动目标或色调无效。")
	for key in ["move_remaining", "tone_remaining", "angle", "rotate_speed"]:
		if not numeric(value.get(key), -36000 if key == "rotate_speed" else 0, 36000 if key == "rotate_speed" else (360 if key == "angle" else 3600)):
			return fail("图片 %s 无效。" % key)
	var instance: RefCounted = create(int(value.number), value.name, pose)
	instance._data = value.duplicate(true)
	instance._data.number = int(value.number)
	instance._data.origin = int(value.origin)
	instance._data.blend_type = int(value.blend_type)
	return {"ok": true, "picture": instance}


func pose_snapshot() -> Dictionary:
	var result := {}
	for key in POSE: result[key] = int(_data[key]) if key in ["origin", "blend_type"] else float(_data[key])
	return result


func snapshot() -> Dictionary:
	var result := pose_snapshot()
	result.number = int(_data.number)
	result.name = _data.name
	result.move_target = {}
	for key in POSE: result.move_target[key] = int(_data.move_target[key]) if key in ["origin", "blend_type"] else float(_data.move_target[key])
	for key in ["tone", "tone_target"]:
		result[key] = []
		for value in _data[key]: result[key].append(float(value))
	for key in ["angle", "rotate_speed", "move_remaining", "tone_remaining"]: result[key] = float(_data[key])
	return result


func move(pose: Dictionary, seconds: Variant = 0.0) -> Dictionary:
	if not pose_valid(pose, true) or not numeric(seconds, 0, 3600): return fail("移动参数无效；时长为 0–3600 秒。")
	var target := pose_snapshot()
	target.merge(pose, true)
	_data.origin = int(target.origin)
	_data.blend_type = int(target.blend_type)
	_data.move_target = target
	_data.move_remaining = float(seconds)
	if seconds == 0: _data.merge(target, true)
	return {"ok": true}


func rotate(degrees_per_second: Variant) -> Dictionary:
	if not numeric(degrees_per_second, -36000, 36000): return fail("旋转速度无效（度/秒）。")
	_data.rotate_speed = float(degrees_per_second)
	return {"ok": true}


func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if not vector_valid(tone) or not numeric(seconds, 0, 3600): return fail("图片色调或时长无效。")
	_data.tone_target = tone.duplicate()
	_data.tone_remaining = float(seconds)
	if seconds == 0: _data.tone = tone.duplicate()
	return {"ok": true}


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	if _data.move_remaining > 0:
		var fraction := minf(1.0, delta / float(_data.move_remaining))
		for key in ["x", "y", "zoom_x", "zoom_y", "opacity"]:
			_data[key] = lerpf(float(_data[key]), float(_data.move_target[key]), fraction)
		_data.move_remaining = maxf(0, _data.move_remaining - delta)
	if _data.tone_remaining > 0:
		var fraction := minf(1.0, delta / float(_data.tone_remaining))
		for index in 4: _data.tone[index] = lerpf(float(_data.tone[index]), float(_data.tone_target[index]), fraction)
		_data.tone_remaining = maxf(0, _data.tone_remaining - delta)
	_data.angle = fposmod(float(_data.angle) + float(_data.rotate_speed) * delta, 360.0)


static func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

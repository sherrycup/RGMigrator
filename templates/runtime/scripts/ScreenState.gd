extends RefCounted
## Owns map pictures 1..50, not scene nodes. Native effect units: seconds/pixels/Hz.
const Picture = preload("res://runtime/scripts/PictureState.gd")
var _pictures: Dictionary = {}
const DEFAULTS := {"tone": [0.0, 0.0, 0.0, 0.0], "tone_target": [0.0, 0.0, 0.0, 0.0], "tone_remaining": 0.0,
	"flash_color": [0.0, 0.0, 0.0, 0.0], "flash_remaining": 0.0,
	"shake_power": 0.0, "shake_speed": 0.0, "shake_remaining": 0.0, "shake_phase": 0.0, "shake": 0.0}
var _data: Dictionary = DEFAULTS.duplicate(true)
var revision := 0


func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary:
	var picture: RefCounted = Picture.create(number, name_value, pose)
	if picture == null: return Picture.fail("图片编号须为 1–50，文件名及显示参数须有效。")
	_pictures[number] = picture
	revision += 1
	return {"ok": true}


func picture(number: int) -> RefCounted:
	return _pictures.get(number)


func picture_ids() -> Array:
	var ids := _pictures.keys()
	ids.sort()
	return ids


func erase_picture(number: int) -> Dictionary:
	if number < 1 or number > 50: return Picture.fail("图片编号须为 1–50。")
	_pictures.erase(number)
	revision += 1
	return {"ok": true}


func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary:
	if picture(number) == null: return Picture.fail("图片 #%d 尚未显示。" % number)
	return picture(number).move(pose, seconds)


func rotate_picture(number: int, speed: Variant) -> Dictionary:
	if picture(number) == null: return Picture.fail("图片 #%d 尚未显示。" % number)
	return picture(number).rotate(speed)


func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if picture(number) == null: return Picture.fail("图片 #%d 尚未显示。" % number)
	return picture(number).start_tone_change(tone, seconds)


func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if not Picture.vector_valid(tone) or not Picture.numeric(seconds, 0, 3600): return Picture.fail("屏幕色调或时长无效。")
	_data.tone_target = tone.duplicate()
	_data.tone_remaining = float(seconds)
	if seconds == 0: _data.tone = tone.duplicate()
	return {"ok": true}


func start_flash(color: Array, seconds: Variant) -> Dictionary:
	if not Picture.vector_valid(color, false) or not Picture.numeric(seconds, 0, 3600): return Picture.fail("屏幕闪光颜色或时长无效。")
	_data.flash_color = color.duplicate() if seconds > 0 else [0.0, 0.0, 0.0, 0.0]
	_data.flash_remaining = float(seconds)
	return {"ok": true}


func start_shake(power: Variant, speed: Variant, seconds: Variant) -> Dictionary:
	if not Picture.numeric(power, 0, 100) or not Picture.numeric(speed, 0, 60) or not Picture.numeric(seconds, 0, 3600): return Picture.fail("震动参数无效：振幅 0–100px、频率 0–60Hz、时长 0–3600 秒。")
	_data.shake_power = float(power)
	_data.shake_speed = float(speed)
	_data.shake_remaining = float(seconds)
	_data.shake_phase = 0.0
	_data.shake = 0.0
	return {"ok": true}


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	for instance in _pictures.values(): instance.advance(delta)
	if _data.tone_remaining > 0:
		var fraction := minf(1, delta / float(_data.tone_remaining))
		for index in 4: _data.tone[index] = lerpf(float(_data.tone[index]), float(_data.tone_target[index]), fraction)
		_data.tone_remaining = maxf(0, _data.tone_remaining - delta)
	if _data.flash_remaining > 0:
		_data.flash_color[3] *= maxf(0, 1.0 - delta / float(_data.flash_remaining))
		_data.flash_remaining = maxf(0, _data.flash_remaining - delta)
	if _data.shake_remaining > 0:
		_data.shake_remaining = maxf(0, _data.shake_remaining - delta)
		_data.shake_phase = fposmod(_data.shake_phase + delta * _data.shake_speed * TAU, TAU)
		# A short release envelope avoids leaving the camera offset after finishing.
		_data.shake = sin(_data.shake_phase) * _data.shake_power * minf(1, _data.shake_remaining / 0.1)
	else:
		_data.shake = 0.0


func effects_snapshot() -> Dictionary:
	var result := {}
	for key in _data:
		if _data[key] is Array:
			result[key] = []
			for value in _data[key]: result[key].append(float(value))
		else: result[key] = float(_data[key])
	return result


func snapshot() -> Dictionary:
	var result := effects_snapshot()
	result.pictures = []
	for id in picture_ids(): result.pictures.append(picture(id).snapshot())
	return result


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary: return Picture.fail("屏幕状态必须为对象。")
	if value.size() != DEFAULTS.size() + 1: return Picture.fail("屏幕字段数量无效。")
	if not Picture.vector_valid(value.get("tone")) or not Picture.vector_valid(value.get("tone_target")) or not Picture.vector_valid(value.get("flash_color"), false): return Picture.fail("屏幕色调/闪光无效。")
	var bounds := {"tone_remaining": [0, 3600], "flash_remaining": [0, 3600], "shake_power": [0, 100], "shake_speed": [0, 60], "shake_remaining": [0, 3600], "shake_phase": [0, TAU], "shake": [-100, 100]}
	for key in bounds:
		if not Picture.numeric(value.get(key), bounds[key][0], bounds[key][1]): return Picture.fail("屏幕 %s 无效。" % key)
	if (value.flash_remaining == 0 and value.flash_color[3] != 0) or (value.shake_remaining == 0 and value.shake != 0): return Picture.fail("已结束的闪光/震动不能留下残值。")
	if not value.get("pictures") is Array or value.pictures.size() > 50: return Picture.fail("图片列表无效。")
	var instance: RefCounted = load("res://runtime/scripts/ScreenState.gd").new()
	for key in instance._data: instance._data[key] = value[key].duplicate() if value[key] is Array else float(value[key])
	for entry in value.pictures:
		var parsed := Picture.decode(entry)
		if not parsed.ok: return parsed
		var id := int(entry.number)
		if instance._pictures.has(id): return Picture.fail("图片 #%d 重复。" % id)
		instance._pictures[id] = parsed.picture
	return {"ok": true, "screen": instance}

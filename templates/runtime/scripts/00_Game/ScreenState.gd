## 职责：维护唯一屏幕效果状态，协调色调、闪烁、震动、天气和图片的时间推进。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/ScreenState.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/ScreenState.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 name_value（String；必填）：待设置的名称文本。
##     参数 pose（Dictionary；默认值 {}）：人物或图形当前姿态。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func picture(number: int) -> RefCounted
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     返回：RefCounted 类型的对象或值，供调用方继续使用。
##
##   func picture_ids() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func erase_picture(number: int) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 pose（Dictionary；必填）：人物或图形当前姿态。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func rotate_picture(number: int, speed: Variant) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 speed（Variant；必填）：移动、播放或推进速度。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 tone（Array；必填）：红、绿、蓝与灰度构成的色调参数。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary
##     参数 tone（Array；必填）：红、绿、蓝与灰度构成的色调参数。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func start_flash(color: Array, seconds: Variant) -> Dictionary
##     参数 color（Array；必填）：绘制或效果使用的颜色。
##     参数 seconds（Variant；必填）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func start_shake(power: Variant, speed: Variant, seconds: Variant) -> Dictionary
##     参数 power（Variant；必填）：效果强度或计算倍率。
##     参数 speed（Variant；必填）：移动、播放或推进速度。
##     参数 seconds（Variant；必填）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func effects_snapshot() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary
##     参数 type（int；必填）：当前操作的类型标识。
##     参数 power（Variant；必填）：效果强度或计算倍率。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func weather_snapshot() -> Dictionary
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
## Owns map pictures 1..50, not scene nodes. Native effect units: seconds/pixels/Hz.
const Picture = preload("res://runtime/scripts/00_Game/PictureState.gd")
const Weather = preload("res://runtime/scripts/00_Game/WeatherState.gd")
var weather_state: RefCounted = Weather.new()
var _pictures: Dictionary = {}
const DEFAULTS := {
	"tone": [0.0, 0.0, 0.0, 0.0],
	"tone_target": [0.0, 0.0, 0.0, 0.0],
	"tone_remaining": 0.0,
	"flash_color": [0.0, 0.0, 0.0, 0.0],
	"flash_remaining": 0.0,
	"shake_power": 0.0,
	"shake_speed": 0.0,
	"shake_remaining": 0.0,
	"shake_phase": 0.0,
	"shake": 0.0
}
var _data: Dictionary = DEFAULTS.duplicate(true)
var revision := 0


func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary:
	var picture: RefCounted = Picture.create(number, name_value, pose)
	if picture == null:
		return Picture.fail("图片编号须为 1–50，文件名及显示参数须有效。")
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
	if number < 1 or number > 50:
		return Picture.fail("图片编号须为 1–50。")
	_pictures.erase(number)
	revision += 1
	return {"ok": true}


func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary:
	if picture(number) == null:
		return Picture.fail("图片 #%d 尚未显示。" % number)
	return picture(number).move(pose, seconds)


func rotate_picture(number: int, speed: Variant) -> Dictionary:
	if picture(number) == null:
		return Picture.fail("图片 #%d 尚未显示。" % number)
	return picture(number).rotate(speed)


func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if picture(number) == null:
		return Picture.fail("图片 #%d 尚未显示。" % number)
	return picture(number).start_tone_change(tone, seconds)


func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if not Picture.vector_valid(tone) or not Picture.numeric(seconds, 0, 3600):
		return Picture.fail("屏幕色调或时长无效。")
	_data.tone_target = tone.duplicate()
	_data.tone_remaining = float(seconds)
	if seconds == 0:
		_data.tone = tone.duplicate()
	return {"ok": true}


func start_flash(color: Array, seconds: Variant) -> Dictionary:
	if not Picture.vector_valid(color, false) or not Picture.numeric(seconds, 0, 3600):
		return Picture.fail("屏幕闪光颜色或时长无效。")
	_data.flash_color = color.duplicate() if seconds > 0 else [0.0, 0.0, 0.0, 0.0]
	_data.flash_remaining = float(seconds)
	return {"ok": true}


func start_shake(power: Variant, speed: Variant, seconds: Variant) -> Dictionary:
	if (
		not Picture.numeric(power, 0, 100)
		or not Picture.numeric(speed, 0, 60)
		or not Picture.numeric(seconds, 0, 3600)
	):
		return Picture.fail("震动参数无效：振幅 0–100px、频率 0–60Hz、时长 0–3600 秒。")
	_data.shake_power = float(power)
	_data.shake_speed = float(speed)
	_data.shake_remaining = float(seconds)
	_data.shake_phase = 0.0
	_data.shake = 0.0
	return {"ok": true}


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	weather_state.advance(delta)
	for instance in _pictures.values():
		instance.advance(delta)
	if _data.tone_remaining > 0:
		var fraction := minf(1, delta / float(_data.tone_remaining))
		for index in 4:
			_data.tone[index] = lerpf(
				float(_data.tone[index]), float(_data.tone_target[index]), fraction
			)
		_data.tone_remaining = maxf(0, _data.tone_remaining - delta)
	if _data.flash_remaining > 0:
		_data.flash_color[3] *= maxf(0, 1.0 - delta / float(_data.flash_remaining))
		_data.flash_remaining = maxf(0, _data.flash_remaining - delta)
	if _data.shake_remaining > 0:
		_data.shake_remaining = maxf(0, _data.shake_remaining - delta)
		_data.shake_phase = fposmod(_data.shake_phase + delta * _data.shake_speed * TAU, TAU)
		# A short release envelope avoids leaving the camera offset after finishing.
		_data.shake = (
			sin(_data.shake_phase) * _data.shake_power * minf(1, _data.shake_remaining / 0.1)
		)
	else:
		_data.shake = 0.0


func effects_snapshot() -> Dictionary:
	var result := {}
	for key in _data:
		if _data[key] is Array:
			result[key] = []
			for value in _data[key]:
				result[key].append(float(value))
		else:
			result[key] = float(_data[key])
	return result


func snapshot() -> Dictionary:
	var result := effects_snapshot()
	result.weather = weather_snapshot()
	result.pictures = []
	for id in picture_ids():
		result.pictures.append(picture(id).snapshot())
	return result


func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary:
	return weather_state.weather(type, power, seconds)


func weather_snapshot() -> Dictionary:
	return weather_state.snapshot()


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return Picture.fail("屏幕状态必须为对象。")
	if value.size() != DEFAULTS.size() + (2 if value.has("weather") else 1):
		return Picture.fail("屏幕字段数量无效。")
	if (
		not Picture.vector_valid(value.get("tone"))
		or not Picture.vector_valid(value.get("tone_target"))
		or not Picture.vector_valid(value.get("flash_color"), false)
	):
		return Picture.fail("屏幕色调/闪光无效。")
	var bounds := {
		"tone_remaining": [0, 3600],
		"flash_remaining": [0, 3600],
		"shake_power": [0, 100],
		"shake_speed": [0, 60],
		"shake_remaining": [0, 3600],
		"shake_phase": [0, TAU],
		"shake": [-100, 100]
	}
	for key in bounds:
		if not Picture.numeric(value.get(key), bounds[key][0], bounds[key][1]):
			return Picture.fail("屏幕 %s 无效。" % key)
	if (
		(value.flash_remaining == 0 and value.flash_color[3] != 0)
		or (value.shake_remaining == 0 and value.shake != 0)
	):
		return Picture.fail("已结束的闪光/震动不能留下残值。")
	if not value.get("pictures") is Array or value.pictures.size() > 50:
		return Picture.fail("图片列表无效。")
	var instance: RefCounted = load("res://runtime/scripts/00_Game/ScreenState.gd").new()
	var weather_result := Weather.decode(value.get("weather", Weather.new().snapshot()))
	if not weather_result.ok:
		return weather_result
	instance.weather_state = weather_result.value
	for key in instance._data:
		instance._data[key] = value[key].duplicate() if value[key] is Array else float(value[key])
	for entry in value.pictures:
		var parsed := Picture.decode(entry)
		if not parsed.ok:
			return parsed
		var id := int(entry.number)
		if instance._pictures.has(id):
			return Picture.fail("图片 #%d 重复。" % id)
		instance._pictures[id] = parsed.picture
	return {"ok": true, "screen": instance}

## 职责：维护单张事件图片的素材、位置、缩放、透明度及插值变化。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/PictureState.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/PictureState.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   static func numeric(value: Variant, minimum: float, maximum: float) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 minimum（float；必填）：允许值的下限。
##     参数 maximum（float；必填）：允许值的上限。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func vector_valid(value: Variant, tone: bool = true) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 tone（bool；默认值 true）：红、绿、蓝与灰度构成的色调参数。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func valid_name(value: Variant) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func pose_valid(value: Variant, partial: bool = false) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 partial（bool；默认值 false）：是否按部分数据处理。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func create(number: int, name_value: String, pose: Dictionary = {}) -> RefCounted
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 name_value（String；必填）：待设置的名称文本。
##     参数 pose（Dictionary；默认值 {}）：人物或图形当前姿态。
##     返回：RefCounted 类型的对象或值，供调用方继续使用。
##
##   static func decode(value: Variant) -> Dictionary
##     用途：解析编码数据并返回对应原值或结构。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func pose_snapshot() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func move(pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
##     参数 pose（Dictionary；必填）：人物或图形当前姿态。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func rotate(degrees_per_second: Variant) -> Dictionary
##     参数 degrees_per_second（Variant；必填）：每秒旋转的角度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary
##     参数 tone（Array；必填）：红、绿、蓝与灰度构成的色调参数。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func fail(message: String) -> Dictionary
##     用途：构造或登记带原因的失败结果。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：POSE。
## 接口说明结束。

extends RefCounted
## Native screen-space picture state. Durations are seconds; rotation is degrees/s.
const POSE := {
	"origin": 0,
	"x": 0.0,
	"y": 0.0,
	"zoom_x": 100.0,
	"zoom_y": 100.0,
	"opacity": 255.0,
	"blend_type": 0
}
var _data: Dictionary


static func numeric(value: Variant, minimum: float, maximum: float) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
	)


static func vector_valid(value: Variant, tone: bool = true) -> bool:
	if not value is Array or value.size() != 4:
		return false
	for index in 4:
		if not numeric(value[index], -255 if tone and index < 3 else 0, 255):
			return false
	return true


static func valid_name(value: Variant) -> bool:
	if (
		not value is String
		or value.is_empty()
		or value.length() > 1024
		or value.is_absolute_path()
		or value.contains(":")
		or value.contains("\\")
	):
		return false
	for component in value.split("/"):
		if component in ["", ".", ".."]:
			return false
	for character in value:
		if character.unicode_at(0) < 32:
			return false
	return true


static func pose_valid(value: Variant, partial: bool = false) -> bool:
	if not value is Dictionary:
		return false
	if not partial and value.size() != POSE.size():
		return false
	for key in value:
		if not POSE.has(key):
			return false
		var item: Variant = value[key]
		match key:
			"origin", "blend_type":
				if (
					not numeric(item, 0, 1 if key == "origin" else 2)
					or floor(float(item)) != float(item)
				):
					return false
			"x", "y":
				if not numeric(item, -1000000, 1000000):
					return false
			"zoom_x", "zoom_y":
				if not numeric(item, 0, 10000):
					return false
			"opacity":
				if not numeric(item, 0, 255):
					return false
	return true


static func create(number: int, name_value: String, pose: Dictionary = {}) -> RefCounted:
	if number < 1 or number > 50 or not valid_name(name_value) or not pose_valid(pose, true):
		return null
	var instance: RefCounted = load("res://runtime/scripts/00_Game/PictureState.gd").new()
	instance._data = POSE.duplicate(true)
	instance._data.merge(pose, true)
	instance._data.merge(
		{
			"number": number,
			"name": name_value,
			"tone": [0.0, 0.0, 0.0, 0.0],
			"angle": 0.0,
			"rotate_speed": 0.0,
			"move_target": instance.pose_snapshot(),
			"move_remaining": 0.0,
			"tone_target": [0.0, 0.0, 0.0, 0.0],
			"tone_remaining": 0.0
		}
	)
	return instance


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return fail("图片必须为对象。")
	if value.size() != POSE.size() + 9:
		return fail("图片字段数量无效。")
	var pose := {}
	for key in POSE:
		pose[key] = value.get(key)
	if (
		not pose_valid(pose)
		or not numeric(value.get("number"), 1, 50)
		or floor(float(value.number)) != float(value.number)
		or not valid_name(value.get("name"))
	):
		return fail("图片编号、文件名或位置/缩放/混合参数无效。")
	if (
		not pose_valid(value.get("move_target"))
		or not vector_valid(value.get("tone"))
		or not vector_valid(value.get("tone_target"))
	):
		return fail("图片移动目标或色调无效。")
	for key in ["move_remaining", "tone_remaining", "angle", "rotate_speed"]:
		if not numeric(
			value.get(key),
			-36000 if key == "rotate_speed" else 0,
			36000 if key == "rotate_speed" else (360 if key == "angle" else 3600)
		):
			return fail("图片 %s 无效。" % key)
	var instance: RefCounted = create(int(value.number), value.name, pose)
	instance._data = value.duplicate(true)
	instance._data.number = int(value.number)
	instance._data.origin = int(value.origin)
	instance._data.blend_type = int(value.blend_type)
	return {"ok": true, "picture": instance}


func pose_snapshot() -> Dictionary:
	var result := {}
	for key in POSE:
		result[key] = int(_data[key]) if key in ["origin", "blend_type"] else float(_data[key])
	return result


func snapshot() -> Dictionary:
	var result := pose_snapshot()
	result.number = int(_data.number)
	result.name = _data.name
	result.move_target = {}
	for key in POSE:
		result.move_target[key] = (
			int(_data.move_target[key])
			if key in ["origin", "blend_type"]
			else float(_data.move_target[key])
		)
	for key in ["tone", "tone_target"]:
		result[key] = []
		for value in _data[key]:
			result[key].append(float(value))
	for key in ["angle", "rotate_speed", "move_remaining", "tone_remaining"]:
		result[key] = float(_data[key])
	return result


func move(pose: Dictionary, seconds: Variant = 0.0) -> Dictionary:
	if not pose_valid(pose, true) or not numeric(seconds, 0, 3600):
		return fail("移动参数无效；时长为 0–3600 秒。")
	var target := pose_snapshot()
	target.merge(pose, true)
	_data.origin = int(target.origin)
	_data.blend_type = int(target.blend_type)
	_data.move_target = target
	_data.move_remaining = float(seconds)
	if seconds == 0:
		_data.merge(target, true)
	return {"ok": true}


func rotate(degrees_per_second: Variant) -> Dictionary:
	if not numeric(degrees_per_second, -36000, 36000):
		return fail("旋转速度无效（度/秒）。")
	_data.rotate_speed = float(degrees_per_second)
	return {"ok": true}


func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if not vector_valid(tone) or not numeric(seconds, 0, 3600):
		return fail("图片色调或时长无效。")
	_data.tone_target = tone.duplicate()
	_data.tone_remaining = float(seconds)
	if seconds == 0:
		_data.tone = tone.duplicate()
	return {"ok": true}


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	if _data.move_remaining > 0:
		var fraction := minf(1.0, delta / float(_data.move_remaining))
		for key in ["x", "y", "zoom_x", "zoom_y", "opacity"]:
			_data[key] = lerpf(float(_data[key]), float(_data.move_target[key]), fraction)
		_data.move_remaining = maxf(0, _data.move_remaining - delta)
	if _data.tone_remaining > 0:
		var fraction := minf(1.0, delta / float(_data.tone_remaining))
		for index in 4:
			_data.tone[index] = lerpf(
				float(_data.tone[index]), float(_data.tone_target[index]), fraction
			)
		_data.tone_remaining = maxf(0, _data.tone_remaining - delta)
	_data.angle = fposmod(float(_data.angle) + float(_data.rotate_speed) * delta, 360.0)


static func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

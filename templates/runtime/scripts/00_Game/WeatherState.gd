## 职责：维护天气类型、强度和过渡进度，为天气绘制器提供可保存状态。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/WeatherState.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/WeatherState.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   static func validate(value: Variant) -> bool
##     用途：检查输入数据是否符合该服务的约定。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary
##     参数 type（int；必填）：当前操作的类型标识。
##     参数 power（Variant；必填）：效果强度或计算倍率。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
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
## Owned only by ScreenState. Particle nodes read this state; they never own its clock.
const P = preload("res://runtime/scripts/00_Game/PictureState.gd")
const DEFAULTS := {
	"weather_type": 0,
	"weather_power": 0.0,
	"weather_target": 0.0,
	"weather_remaining": 0.0,
	"weather_density": 0.0,
	"weather_density_target": 0.0
}
var data: Dictionary = DEFAULTS.duplicate(true)


static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size() != DEFAULTS.size():
		return false
	var bounds := {
		"weather_type": [0, 3],
		"weather_power": [0, 9],
		"weather_target": [0, 9],
		"weather_remaining": [0, 3600],
		"weather_density": [0, 40],
		"weather_density_target": [0, 40]
	}
	for key in bounds:
		if not P.numeric(value.get(key), bounds[key][0], bounds[key][1]):
			return false
	if floor(float(value.weather_type)) != float(value.weather_type):
		return false
	if (
		value.weather_type == 0
		and (value.weather_density != 0 or value.weather_density_target != 0)
	):
		return false
	if value.weather_density_target == 0:
		if value.weather_target != 0:
			return false
	elif not is_equal_approx(
		float(value.weather_density_target), (float(value.weather_target) + 1) * 4
	):
		return false
	if (
		value.weather_remaining == 0
		and (
			value.weather_density != value.weather_density_target
			or value.weather_power != value.weather_target
		)
	):
		return false
	return true


func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary:
	if type not in [0, 1, 2, 3] or not P.numeric(power, 0, 9) or not P.numeric(seconds, 0, 3600):
		return P.fail("天气类型须为0无/1雨/2暴风雨/3雪，强度0–9，时长0–3600秒。")
	if type != 0:
		data.weather_type = type
	data.weather_target = 0.0 if type == 0 else float(power)
	data.weather_density_target = 0.0 if type == 0 else (float(power) + 1) * 4
	data.weather_remaining = float(seconds)
	if seconds == 0:
		data.weather_power = data.weather_target
		data.weather_density = data.weather_density_target
		if type == 0:
			data.weather_type = 0
	return {"ok": true}


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	if data.weather_remaining > 0:
		var fraction := minf(1, delta / float(data.weather_remaining))
		data.weather_power = lerpf(data.weather_power, data.weather_target, fraction)
		data.weather_density = lerpf(data.weather_density, data.weather_density_target, fraction)
		data.weather_remaining = maxf(0, data.weather_remaining - delta)
		if data.weather_remaining < 0.00000001:
			data.weather_remaining = 0.0
			data.weather_power = data.weather_target
			data.weather_density = data.weather_density_target
	if data.weather_density == 0 and data.weather_remaining == 0:
		data.weather_type = 0


func snapshot() -> Dictionary:
	return data.duplicate(true)


static func decode(value: Variant) -> Dictionary:
	if not validate(value):
		return P.fail("屏幕天气存档无效。")
	var instance: RefCounted = load("res://runtime/scripts/00_Game/WeatherState.gd").new()
	instance.data = value.duplicate(true)
	instance.data.weather_type = int(instance.data.weather_type)
	for key in DEFAULTS:
		if key != "weather_type":
			instance.data[key] = float(instance.data[key])
	return {"ok": true, "value": instance}

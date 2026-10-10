extends RefCounted
## Owned only by ScreenState. Particle nodes read this state; they never own its clock.
const P = preload("res://runtime/scripts/PictureState.gd")
const DEFAULTS := {"weather_type": 0, "weather_power": 0.0, "weather_target": 0.0,
	"weather_remaining": 0.0, "weather_density": 0.0, "weather_density_target": 0.0}
var data: Dictionary = DEFAULTS.duplicate(true)

static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size() != DEFAULTS.size(): return false
	var bounds := {"weather_type": [0, 3], "weather_power": [0, 9], "weather_target": [0, 9],
		"weather_remaining": [0, 3600], "weather_density": [0, 40], "weather_density_target": [0, 40]}
	for key in bounds:
		if not P.numeric(value.get(key), bounds[key][0], bounds[key][1]): return false
	if floor(float(value.weather_type)) != float(value.weather_type): return false
	if value.weather_type == 0 and (value.weather_density != 0 or value.weather_density_target != 0): return false
	if value.weather_density_target == 0:
		if value.weather_target != 0: return false
	elif not is_equal_approx(float(value.weather_density_target), (float(value.weather_target) + 1) * 4): return false
	if value.weather_remaining == 0 and (value.weather_density != value.weather_density_target or value.weather_power != value.weather_target): return false
	return true

func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary:
	if type not in [0, 1, 2, 3] or not P.numeric(power, 0, 9) or not P.numeric(seconds, 0, 3600): return P.fail("天气类型须为0无/1雨/2暴风雨/3雪，强度0–9，时长0–3600秒。")
	if type != 0: data.weather_type = type
	data.weather_target = 0.0 if type == 0 else float(power)
	data.weather_density_target = 0.0 if type == 0 else (float(power) + 1) * 4
	data.weather_remaining = float(seconds)
	if seconds == 0:
		data.weather_power = data.weather_target
		data.weather_density = data.weather_density_target
		if type == 0: data.weather_type = 0
	return {"ok": true}

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	if data.weather_remaining > 0:
		var fraction := minf(1, delta / float(data.weather_remaining))
		data.weather_power = lerpf(data.weather_power, data.weather_target, fraction)
		data.weather_density = lerpf(data.weather_density, data.weather_density_target, fraction)
		data.weather_remaining = maxf(0, data.weather_remaining - delta)
		if data.weather_remaining < 0.00000001:
			data.weather_remaining = 0.0
			data.weather_power = data.weather_target
			data.weather_density = data.weather_density_target
	if data.weather_density == 0 and data.weather_remaining == 0: data.weather_type = 0

func snapshot() -> Dictionary: return data.duplicate(true)

static func decode(value: Variant) -> Dictionary:
	if not validate(value): return P.fail("屏幕天气存档无效。")
	var instance: RefCounted = load("res://runtime/scripts/WeatherState.gd").new()
	instance.data = value.duplicate(true)
	instance.data.weather_type = int(instance.data.weather_type)
	for key in DEFAULTS:
		if key != "weather_type": instance.data[key] = float(instance.data[key])
	return {"ok": true, "value": instance}

extends RefCounted
const P = preload("res://runtime/scripts/PictureState.gd")
const DEFAULTS := {"map_id": 0, "panorama_name": "", "panorama_hue": 0.0,
	"fog_name": "", "fog_hue": 0.0, "fog_opacity": 64.0, "fog_blend_type": 0,
	"fog_zoom": 200.0, "fog_sx": 0.0, "fog_sy": 0.0, "fog_ox": 0.0, "fog_oy": 0.0,
	"fog_tone": [0.0, 0.0, 0.0, 0.0], "fog_tone_target": [0.0, 0.0, 0.0, 0.0], "fog_tone_remaining": 0.0,
	"fog_opacity_target": 64.0, "fog_opacity_remaining": 0.0,
	"weather_type": 0, "weather_power": 0.0, "weather_target": 0.0, "weather_remaining": 0.0,
	"weather_density": 0.0, "weather_density_target": 0.0}
var data: Dictionary = DEFAULTS.duplicate(true)
var revision := 0

static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size() != DEFAULTS.size(): return false
	for key in ["panorama_name", "fog_name"]:
		if not value.get(key) is String or not (value[key].is_empty() or P.valid_name(value[key])): return false
	var bounds := {"map_id": [0, 10000000], "panorama_hue": [0, 360], "fog_hue": [0, 360], "fog_opacity": [0, 255], "fog_blend_type": [0, 2], "fog_zoom": [1, 10000], "fog_sx": [-10000, 10000], "fog_sy": [-10000, 10000], "fog_ox": [-10000000, 10000000], "fog_oy": [-10000000, 10000000], "fog_tone_remaining": [0, 3600], "fog_opacity_target": [0, 255], "fog_opacity_remaining": [0, 3600], "weather_type": [0, 3], "weather_power": [0, 9], "weather_target": [0, 9], "weather_remaining": [0, 3600]}
	for key in bounds:
		if not P.numeric(value.get(key), bounds[key][0], bounds[key][1]): return false
	for key in ["weather_density", "weather_density_target"]:
		if not P.numeric(value.get(key), 0, 40): return false
	for key in ["map_id", "fog_blend_type", "weather_type"]:
		if floor(float(value[key])) != float(value[key]): return false
	return P.vector_valid(value.get("fog_tone")) and P.vector_valid(value.get("fog_tone_target"))

func configure(changes: Dictionary) -> Dictionary:
	var candidate := data.duplicate(true)
	for key in changes:
		if key not in ["panorama_name", "panorama_hue", "fog_name", "fog_hue", "fog_opacity", "fog_blend_type", "fog_zoom", "fog_sx", "fog_sy"]: return P.fail("未知地图表现参数：%s" % key)
		candidate[key] = changes[key]
	if not validate(candidate): return P.fail("全景/雾参数无效。")
	if changes.has("fog_opacity"):
		candidate.fog_opacity_target = candidate.fog_opacity
		candidate.fog_opacity_remaining = 0.0
	candidate.fog_blend_type = int(candidate.fog_blend_type)
	for key in DEFAULTS:
		if DEFAULTS[key] is float: candidate[key] = float(candidate[key])
	data = candidate
	revision += 1
	return {"ok": true}

func setup_map(id: int, tileset: Dictionary) -> Dictionary:
	if int(data.map_id) == id: return {"ok": true}
	var old_weather := [data.weather_type, data.weather_power, data.weather_target, data.weather_remaining, data.weather_density, data.weather_density_target]
	data = DEFAULTS.duplicate(true)
	var values := {}
	for key in ["panorama_name", "panorama_hue", "fog_name", "fog_hue", "fog_opacity", "fog_blend_type", "fog_zoom", "fog_sx", "fog_sy"]: values[key] = tileset.get(key, DEFAULTS[key])
	var result := configure(values)
	if not result.ok:
		data = DEFAULTS.duplicate(true)
		data.map_id = id
		data.weather_type = old_weather[0]
		data.weather_power = old_weather[1]
		data.weather_target = old_weather[2]
		data.weather_remaining = old_weather[3]
		data.weather_density = old_weather[4]
		data.weather_density_target = old_weather[5]
		return result
	data.map_id = id
	data.weather_type = old_weather[0]
	data.weather_power = old_weather[1]
	data.weather_target = old_weather[2]
	data.weather_remaining = old_weather[3]
	data.weather_density = old_weather[4]
	data.weather_density_target = old_weather[5]
	return result

func tint_fog(tone: Array, seconds: Variant = 0.0) -> Dictionary:
	if not P.vector_valid(tone) or not P.numeric(seconds, 0, 3600): return P.fail("雾色调/时长无效。")
	data.fog_tone_target = tone.duplicate()
	data.fog_tone_remaining = float(seconds)
	if seconds == 0: data.fog_tone = tone.duplicate()
	return {"ok": true}

func fade_fog(opacity: Variant, seconds: Variant = 0.0) -> Dictionary:
	if not P.numeric(opacity, 0, 255) or not P.numeric(seconds, 0, 3600): return P.fail("雾透明度/时长无效。")
	data.fog_opacity_target = float(opacity)
	data.fog_opacity_remaining = float(seconds)
	if seconds == 0: data.fog_opacity = float(opacity)
	return {"ok": true}

func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary:
	if type not in [0, 1, 2, 3] or not P.numeric(power, 0, 9) or not P.numeric(seconds, 0, 3600): return P.fail("天气类型须为0无/1雨/2暴风雨/3雪，强度0–9，时长0–3600秒。")
	# Fade-out retains the old particle shape until density reaches zero.
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
	# sx/sy preserve RMXP units: /8 per 40Hz update == 5 pixels/second.
	data.fog_ox = wrapf(data.fog_ox - float(data.fog_sx) * 5 * delta, -1000000, 1000000)
	data.fog_oy = wrapf(data.fog_oy - float(data.fog_sy) * 5 * delta, -1000000, 1000000)
	if data.fog_tone_remaining > 0:
		for index in 4: data.fog_tone[index] = lerpf(data.fog_tone[index], data.fog_tone_target[index], minf(1, delta / data.fog_tone_remaining))
		data.fog_tone_remaining = maxf(0, data.fog_tone_remaining - delta)
		if data.fog_tone_remaining < 0.00000001:
			data.fog_tone_remaining = 0.0
			data.fog_tone = data.fog_tone_target.duplicate()
	for prefix in ["fog_opacity"]:
		var current: String = "fog_opacity" if prefix == "fog_opacity" else "weather_power"
		var remaining: String = prefix + "_remaining"
		if data[remaining] > 0:
			data[current] = lerpf(data[current], data[prefix + "_target"], minf(1, delta / data[remaining]))
			data[remaining] = maxf(0, data[remaining] - delta)
			if data[remaining] < 0.00000001:
				data[remaining] = 0.0
				data[current] = data[prefix + "_target"]
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
	if not validate(value): return P.fail("地图表现存档无效。")
	var instance: RefCounted = load("res://runtime/scripts/MapEffectsState.gd").new()
	instance.data = value.duplicate(true)
	for key in ["map_id", "weather_type", "fog_blend_type"]: instance.data[key] = int(instance.data[key])
	return {"ok": true, "value": instance}

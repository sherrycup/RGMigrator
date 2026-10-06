extends Node
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const Weather = preload("res://runtime/scripts/WeatherRenderer.gd")
static var _shaders: Dictionary = {}
var model: RefCounted
var view_model: RefCounted
var timer_model: RefCounted
var preview := false
var map: Node2D
var camera: Camera2D
var texture_overrides: Dictionary = {}
var panorama: ColorRect
var fog: ColorRect
var weather: Node2D
var _weather_clip: Control
var _timer: Label
var _borders: Array[ColorRect] = []
var _names := {"panorama": "!", "fog": "!"}
var _missing := {}

func _ready() -> void:
	panorama = _plane(-10)
	fog = _plane(0)
	var weather_layer := CanvasLayer.new()
	weather_layer.layer = 0
	add_child(weather_layer)
	_weather_clip = Control.new()
	_weather_clip.clip_contents = true
	_weather_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_layer.add_child(_weather_clip)
	weather = Weather.new()
	_weather_clip.add_child(weather)
	var border_layer := CanvasLayer.new()
	border_layer.layer = 2
	add_child(border_layer)
	for index in 4:
		var border := ColorRect.new()
		border.color = Color.BLACK
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border_layer.add_child(border)
		_borders.append(border)
	var timer_layer := CanvasLayer.new()
	timer_layer.layer = 9
	add_child(timer_layer)
	_timer = Label.new()
	_timer.add_theme_font_override("font", preload("res://runtime/scripts/UIResources.gd").font())
	_timer.add_theme_font_size_override("font_size", 24)
	_timer.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer.add_theme_constant_override("outline_size", 4)
	timer_layer.add_child(_timer)
	sync(0)

func _plane(layer_number: int) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = layer_number
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	return rect

static func _shader(blend: int) -> Shader:
	if not _shaders.has(blend):
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
render_mode unshaded, %s;
uniform sampler2D image : repeat_enable, filter_nearest;
uniform vec2 area;
uniform vec2 origin;
uniform float zoom = 1.0;
uniform float hue = 0.0;
uniform vec4 tone = vec4(0.0);
uniform float opacity = 1.0;
void fragment() {
 vec2 pixels = (UV * area + origin) / zoom;
 vec4 c = texture(image, pixels / vec2(textureSize(image, 0)));
 float a = hue * 6.28318530718;
 vec3 k = normalize(vec3(1.0));
 c.rgb = c.rgb * cos(a) + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - cos(a));
 float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
 c.rgb = clamp(mix(c.rgb, vec3(gray), tone.a) + tone.rgb, vec3(0.0), vec3(1.0));
 c.a *= opacity;
 COLOR = c;
}
""" % ["blend_mix", "blend_add", "blend_sub"][blend]
		_shaders[blend] = shader
	return _shaders[blend]

func _apply(rect: ColorRect, role: String, area: Rect2) -> void:
	var data: Dictionary = model.data
	var name_value := str(data[role + "_name"])
	var blend := int(data.fog_blend_type) if role == "fog" else 0
	if rect.material == null or rect.material.shader != _shader(blend):
		var material_value := ShaderMaterial.new()
		material_value.shader = _shader(blend)
		rect.material = material_value
		_names[role] = "!"
	if _names[role] != name_value:
		_names[role] = name_value
		var texture: Texture2D = texture_overrides.get(name_value)
		if texture == null and not name_value.is_empty(): texture = Cache.fog(name_value) if role == "fog" else Cache.panorama(name_value)
		rect.material.set_shader_parameter("image", texture)
		rect.set_meta("has_image", texture != null)
		if texture == null and not name_value.is_empty() and not _missing.has(role + name_value):
			_missing[role + name_value] = true
			RuntimeState.report_diagnostic("Map%03d %s 素材缺失：%s；不补取 RTP。" % [int(data.map_id), role, name_value])
	rect.visible = bool(rect.get_meta("has_image", false))
	rect.position = area.position
	rect.size = area.size
	if not rect.visible: return
	var origin: Vector2 = view_model.display * (0.5 if role == "panorama" else 1.0)
	if camera != null: origin += camera.offset
	if role == "fog": origin += Vector2(data.fog_ox, data.fog_oy)
	var material_value: ShaderMaterial = rect.material
	material_value.set_shader_parameter("area", area.size)
	material_value.set_shader_parameter("origin", origin)
	material_value.set_shader_parameter("hue", float(data[role + "_hue"]) / 360)
	material_value.set_shader_parameter("zoom", float(data.fog_zoom) / 100 if role == "fog" else 1.0)
	material_value.set_shader_parameter("opacity", float(data.fog_opacity) / 255 if role == "fog" else 1.0)
	var tone: Array = data.fog_tone if role == "fog" else [0, 0, 0, 0]
	material_value.set_shader_parameter("tone", Vector4(tone[0], tone[1], tone[2], tone[3]) / 255)

func sync(delta: float) -> void:
	if model == null or view_model == null: return
	if preview or (RuntimeState.playing and not get_tree().paused):
		model.advance(delta)
		if timer_model != null: timer_model.advance(delta)
	var window_size := get_viewport().get_visible_rect().size
	var area: Rect2 = view_model.view_rect(window_size)
	_apply(panorama, "panorama", area)
	if map != null: map.set_background_visible(not panorama.visible)
	_apply(fog, "fog", area)
	_weather_clip.position = area.position
	_weather_clip.size = area.size
	weather.area = area.size
	weather.type = int(model.data.weather_type)
	weather.power = float(model.data.weather_power)
	weather.density = float(model.data.weather_density)
	weather.display = view_model.display
	if camera != null: weather.display += camera.offset
	weather.advance(delta if preview or not get_tree().paused else 0.0)
	var bounds := [Rect2(0, 0, window_size.x, area.position.y), Rect2(0, area.end.y, window_size.x, window_size.y - area.end.y), Rect2(0, area.position.y, area.position.x, area.size.y), Rect2(area.end.x, area.position.y, window_size.x - area.end.x, area.size.y)]
	for index in 4:
		_borders[index].position = bounds[index].position
		_borders[index].size = bounds[index].size
		_borders[index].visible = bounds[index].size.x > 0 and bounds[index].size.y > 0
	_timer.visible = timer_model != null and timer_model.visible
	if _timer.visible:
		var content: String = timer_model.text()
		if _timer.text != content: _timer.text = content
		_timer.position = Vector2(area.end.x - 116, area.position.y + 8)

func _process(delta: float) -> void: sync(delta)

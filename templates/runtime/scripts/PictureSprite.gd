extends Sprite2D
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
static var _shaders: Dictionary = {}
var _picture_name := ""
var _blend := -1
var _tone := []
var _shader_material: ShaderMaterial


static func shader_for(blend: int) -> Shader:
	if not _shaders.has(blend):
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
render_mode unshaded, %s;
uniform vec4 tone = vec4(0.0);
void fragment() {
 vec4 c = COLOR;
 float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
 c.rgb = clamp(mix(c.rgb, vec3(gray), tone.a) + tone.rgb, vec3(0.0), vec3(1.0));
 COLOR = c;
}
""" % ["blend_mix", "blend_add", "blend_sub"][blend]
		_shaders[blend] = shader
	return _shaders[blend]


func apply(view: Dictionary) -> bool:
	if _picture_name != view.name:
		_picture_name = view.name
		texture = Cache.picture(_picture_name)
	if texture == null:
		visible = false
		return false
	visible = true
	centered = int(view.origin) == 1
	position = Vector2(view.x, view.y)
	scale = Vector2(view.zoom_x, view.zoom_y) / 100.0
	# RM positive angles turn counter-clockwise; Godot's positive 2D angle is clockwise.
	rotation_degrees = -float(view.angle)
	modulate.a = float(view.opacity) / 255.0
	z_index = int(view.number)
	if _blend != int(view.blend_type):
		_blend = int(view.blend_type)
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader_for(_blend)
		material = _shader_material
		_tone = []
	if _tone != view.tone:
		_tone = view.tone.duplicate()
		_shader_material.set_shader_parameter("tone", Vector4(_tone[0], _tone[1], _tone[2], _tone[3]) / 255.0)
	return true

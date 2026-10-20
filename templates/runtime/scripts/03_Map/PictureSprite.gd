## 职责：根据图片状态加载素材并绘制位置、缩放、旋转、透明度与色调。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/PictureSprite.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/03_Map/PictureSprite.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   static func shader_for(blend: int) -> Shader
##     参数 blend（int；必填）：图像的混合模式或混合参数。
##     返回：Shader 类型的对象或值，供调用方继续使用。
##
##   func apply(view: Dictionary) -> bool
##     用途：应用已选定或已准备的修改。
##     参数 view（Dictionary；必填）：显示对象或视图配置。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 接口说明结束。

extends Sprite2D
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
static var _shaders: Dictionary = {}
var _picture_name := ""
var _blend := -1
var _tone := []
var _shader_material: ShaderMaterial


static func shader_for(blend: int) -> Shader:
	if not _shaders.has(blend):
		var shader := Shader.new()
		shader.code = (
			"""shader_type canvas_item;
render_mode unshaded, %s;
uniform vec4 tone = vec4(0.0);
void fragment() {
 vec4 c = COLOR;
 float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
 c.rgb = clamp(mix(c.rgb, vec3(gray), tone.a) + tone.rgb, vec3(0.0), vec3(1.0));
 COLOR = c;
}
"""
			% ["blend_mix", "blend_add", "blend_sub"][blend]
		)
		_shaders[blend] = shader
	return _shaders[blend]


func apply(view: Dictionary) -> bool:
	if _picture_name != view.name:
		_picture_name = view.name
		texture = Cache.picture(_picture_name)
	if texture == null:
		visible = false
		return false
	visible = not bool(get_meta("flash_unravel_hidden", false))
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
		_shader_material.set_shader_parameter(
			"tone", Vector4(_tone[0], _tone[1], _tone[2], _tone[3]) / 255.0
		)
	return true

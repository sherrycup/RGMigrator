## 职责：管理闪翼页面的背景显示与场景切换时的背景资源。
##
## 调用方式：
##   脚本由所属场景或插件挂载；下列回调由 Godot 调用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

extends TextureRect
## 0203 nonblocking menu blur: eight source updates, one owned capture.
var entering = true
var blur_process = 0
var _clock = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform float radius=0.0;
varying vec4 vertex_color;
void vertex(){vertex_color=COLOR;}
void fragment(){
 vec4 c=texture(TEXTURE,UV)*0.2;
 for(int i=1;i<=4;i++){
  vec2 d=TEXTURE_PIXEL_SIZE*radius*float(i)/4.0;
  c+=(texture(TEXTURE,UV+vec2(d.x,0.0))+texture(TEXTURE,UV-vec2(d.x,0.0))+texture(TEXTURE,UV+vec2(0.0,d.y))+texture(TEXTURE,UV-vec2(0.0,d.y)))*0.05;
 }
 COLOR=c*vertex_color;
}"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material


func _process(delta: float) -> void:
	_clock += maxf(0, delta) * 60
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	blur_process = clampi(blur_process + (ticks if entering else -ticks), 0, 8)
	_material.set_shader_parameter("radius", blur_process)
	if not entering and blur_process == 0:
		queue_free()

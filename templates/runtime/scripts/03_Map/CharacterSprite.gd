## 职责：绘制人物行走图和动作帧，更新方向、透明度、深度及图形切换。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/CharacterSprite.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(character_name: String, hue: int = 0, direction: int = 2, pattern: int = 0) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 character_name（String；必填）：人物行走图名称。
##     参数 hue（int；默认值 0）：素材色相参数。
##     参数 direction（int；默认值 2）：当前操作使用的方向或选择移动量。
##     参数 pattern（int；默认值 0）：匹配模式或图形帧编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_frame(direction: int, pattern: int) -> void
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 pattern（int；必填）：匹配模式或图形帧编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 公开常量：HUE_SHADER。
## 接口说明结束。

extends TextureRect
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const HUE_SHADER = """shader_type canvas_item;
uniform float hue = 0.0;
void fragment() {
    vec4 c = COLOR;
    float hi = max(c.r, max(c.g, c.b));
    float lo = min(c.r, min(c.g, c.b));
    float delta = hi - lo;
    float h = 0.0;
    if (delta > 0.00001) {
        if (hi == c.r) { h = (c.g - c.b) / delta; }
        else if (hi == c.g) { h = 2.0 + (c.b - c.r) / delta; }
        else { h = 4.0 + (c.r - c.g) / delta; }
    }
    h = fract(h / 6.0 + hue);
    float s = hi > 0.00001 ? delta / hi : 0.0;
    vec3 wheel = clamp(abs(fract(vec3(h) + vec3(0.0, 0.66666667, 0.33333333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    COLOR = vec4(hi * mix(vec3(1.0), wheel, s), c.a);
}
"""
static var _shader: Shader
var _source_name := ""
var _frame_size := Vector2.ZERO


func configure(character_name: String, hue: int = 0, direction: int = 2, pattern: int = 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_source_name = character_name
	var source := Cache.character(_source_name)
	if source == null:
		if not character_name.is_empty():
			RuntimeState.report_diagnostic("菜单角色图缺失：%s" % character_name)
		return
	_frame_size = source.get_size() / 4.0
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_frame(direction, pattern)
	if hue % 360 != 0:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = HUE_SHADER
		var hue_material := ShaderMaterial.new()
		hue_material.shader = _shader
		hue_material.set_shader_parameter("hue", float(hue) / 360.0)
		material = hue_material
	else:
		material = null


func set_frame(direction: int, pattern: int) -> void:
	if _frame_size == Vector2.ZERO:
		return
	var row := int({2: 0, 4: 1, 6: 2, 8: 3}.get(direction, 0))
	texture = Cache.region(
		"Characters",
		_source_name,
		Rect2(Vector2(clampi(pattern, 0, 3), row) * _frame_size, _frame_size)
	)

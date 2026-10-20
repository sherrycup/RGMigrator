## 职责：将屏幕色调、闪烁和震动状态应用到当前场景绘制。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/03_Map/ScreenRenderer.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func full_rect(parent: Node) -> ColorRect
##     参数 parent（Node；必填）：父节点、父对象或继承关系的上级。
##     返回：ColorRect 类型的对象或值，供调用方继续使用。
##
##   func sync() -> void
##     用途：把当前状态同步到关联对象。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _exit_tree() -> void
##
## 接口说明结束。

extends Node
## Map tone/shake, separate screen-space pictures, flash; UI stays above them.
const PictureSprite = preload("res://runtime/scripts/03_Map/PictureSprite.gd")
var camera: Camera2D
var sprites: Dictionary = {}
var _picture_layer: CanvasLayer
var _tone_rect: ColorRect
var _flash_rect: ColorRect
var _tone_material: ShaderMaterial
var _last_tone: Array = []
var _missing: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tone_layer := CanvasLayer.new()
	tone_layer.layer = 1
	add_child(tone_layer)
	_tone_rect = full_rect(tone_layer)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 tone = vec4(0.0);
void fragment() {
 vec4 c = textureLod(scene_texture, SCREEN_UV, 0.0);
 float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
 c.rgb = clamp(mix(c.rgb, vec3(gray), tone.a) + tone.rgb, vec3(0.0), vec3(1.0));
 COLOR = c;
}
"""
	_tone_material = ShaderMaterial.new()
	_tone_material.shader = shader
	_tone_rect.material = _tone_material
	_picture_layer = CanvasLayer.new()
	_picture_layer.layer = 5
	add_child(_picture_layer)
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 8
	add_child(flash_layer)
	_flash_rect = full_rect(flash_layer)
	sync()


func full_rect(parent: Node) -> ColorRect:
	var rectangle := ColorRect.new()
	rectangle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rectangle)
	rectangle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rectangle


func _process(delta: float) -> void:
	if RuntimeState.playing and not RuntimeState.map_time_paused():
		RuntimeState.screen.advance(delta)
	sync()


func sync() -> void:
	var screen: RefCounted = RuntimeState.screen
	var area: Rect2 = RuntimeState.map_view.view_rect(get_viewport().get_visible_rect().size)
	_tone_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tone_rect.position = area.position
	_tone_rect.size = area.size
	var ids: Array = screen.picture_ids()
	for id in sprites.keys():
		if not ids.has(id):
			_picture_layer.remove_child(sprites[id])
			sprites[id].queue_free()
			sprites.erase(id)
	for id in ids:
		if not sprites.has(id):
			sprites[id] = PictureSprite.new()
			_picture_layer.add_child(sprites[id])
		var view: Dictionary = screen.picture(id).snapshot()
		if not sprites[id].apply(view) and not _missing.has(view.name):
			_missing[view.name] = true
			RuntimeState.report_diagnostic(
				"Pictures[%d] 素材缺失或无法读取：Graphics/Pictures/%s；未补取 RTP。" % [id, view.name]
			)
	var effects: Dictionary = screen.effects_snapshot()
	_tone_rect.visible = effects.tone != [0.0, 0.0, 0.0, 0.0]
	if _last_tone != effects.tone:
		_last_tone = effects.tone.duplicate()
		_tone_material.set_shader_parameter(
			"tone", Vector4(_last_tone[0], _last_tone[1], _last_tone[2], _last_tone[3]) / 255.0
		)
	var color: Array = effects.flash_color
	_flash_rect.color = Color(
		color[0] / 255.0, color[1] / 255.0, color[2] / 255.0, color[3] / 255.0
	)
	_flash_rect.visible = color[3] > 0
	if camera != null and not is_equal_approx(camera.offset.x, -float(effects.shake)):
		camera.offset.x = -float(effects.shake)
		# The test lab pauses the Camera2D's normal process, but previews must still shake.
		camera.force_update_scroll()


func _exit_tree() -> void:
	if is_instance_valid(camera):
		camera.offset.x = 0

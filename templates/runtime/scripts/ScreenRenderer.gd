extends Node
## Map tone/shake, separate screen-space pictures, flash; UI stays above them.
const PictureSprite = preload("res://runtime/scripts/PictureSprite.gd")
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
	if RuntimeState.playing and not RuntimeState.map_time_paused(): RuntimeState.screen.advance(delta)
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
			RuntimeState.report_diagnostic("Pictures[%d] 素材缺失或无法读取：Graphics/Pictures/%s；未补取 RTP。" % [id, view.name])
	var effects: Dictionary = screen.effects_snapshot()
	_tone_rect.visible = effects.tone != [0.0, 0.0, 0.0, 0.0]
	if _last_tone != effects.tone:
		_last_tone = effects.tone.duplicate()
		_tone_material.set_shader_parameter("tone", Vector4(_last_tone[0], _last_tone[1], _last_tone[2], _last_tone[3]) / 255.0)
	var color: Array = effects.flash_color
	_flash_rect.color = Color(color[0] / 255.0, color[1] / 255.0, color[2] / 255.0, color[3] / 255.0)
	_flash_rect.visible = color[3] > 0
	if camera != null and not is_equal_approx(camera.offset.x, -float(effects.shake)):
		camera.offset.x = -float(effects.shake)
		# The test lab pauses the Camera2D's normal process, but previews must still shake.
		camera.force_update_scroll()


func _exit_tree() -> void:
	if is_instance_valid(camera): camera.offset.x = 0

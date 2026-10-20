## 职责：执行事件和场景过渡的遮罩或淡入淡出绘制，维护过渡进度。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/09_Effects/TransitionRenderer.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func fade(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
##     参数 opacity（Variant；必填）：透明度参数，取值按对应显示接口约定。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func freeze_screen() -> Dictionary
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func transition(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary
##     参数 seconds（Variant；默认值 0.2）：以秒计的时长。
##     参数 name_value（String；默认值 ""）：待设置的名称文本。
##     参数 vague（Variant；默认值 40）：过渡遮罩的模糊范围参数。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func cancel() -> void
##     用途：取消当前请求、操作或等待。
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

extends CanvasLayer
## Transient screenshot ownership: never serialized. UI remains above this layer.
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const P = preload("res://runtime/scripts/00_Game/PictureState.gd")
var preview := false
var rect: ColorRect
var remaining := 0.0
var duration := 0.0
var frozen: Texture2D
var busy := false
var _fade := 0.0
var _target := 0.0
var _mode := "fade"
var _generation := 0


func _ready() -> void:
	layer = 15
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	rect.hide()


func fade(opacity: Variant, seconds: Variant = 0.0) -> Dictionary:
	if not P.numeric(opacity, 0, 255) or not P.numeric(seconds, 0, 3600):
		return P.fail("淡入淡出参数无效。")
	if busy:
		return P.fail("截图正在准备，请等待完成。")
	frozen = null
	_mode = "fade"
	rect.material = null
	_target = float(opacity) / 255
	remaining = float(seconds)
	if seconds == 0:
		_fade = _target
	_update_rect()
	return {"ok": true}


func freeze_screen() -> Dictionary:
	if busy or frozen != null or remaining > 0:
		return P.fail("画面过渡未结束，不能重复冻结。")
	if DisplayServer.get_name() == "headless":
		return P.fail("冻结画面需要真实渲染，不能在 headless 中截图。")
	busy = true
	_generation += 1
	var generation := _generation
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or generation != _generation:
		# Cancellation or a newer capture owns the state now.
		return P.fail("场景已关闭。")
	frozen = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	busy = false
	_mode = "freeze"
	_make_material(null, 40)
	rect.material.set_shader_parameter("progress", 0.0)
	rect.show()
	return {"ok": true}


func transition(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary:
	if frozen == null or busy:
		return P.fail("请先等待 freeze_screen 完成。")
	if not P.numeric(seconds, 0, 3600) or not P.numeric(vague, 0, 255):
		return P.fail("过渡时长/模糊边界无效。")
	var mask: Texture2D
	if not name_value.is_empty():
		mask = Cache.transition(name_value)
		if mask == null:
			return P.fail("Transitions 素材缺失：%s；冻结画面保留，可取消。" % name_value)
	_mode = "transition"
	_make_material(mask, float(vague))
	remaining = float(seconds)
	duration = float(seconds)
	if seconds == 0:
		cancel()
	return {"ok": true}


func _make_material(mask: Texture2D, vague: float) -> void:
	var material_value := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D frozen_image : filter_nearest;
uniform sampler2D mask_image : filter_nearest;
uniform bool masked = false;
uniform float softness = 0.156;
uniform float progress = 0.0;
void fragment() {
 vec4 c = texture(frozen_image, UV);
 float m = dot(texture(mask_image, UV).rgb, vec3(0.299, 0.587, 0.114));
 float reveal = masked ? smoothstep(m - max(softness, 0.0001), m + max(softness, 0.0001), progress * (1.0 + softness * 2.0) - softness) : progress;
 c.a *= 1.0 - reveal;
 COLOR = c;
}
"""
	material_value.shader = shader
	material_value.set_shader_parameter("frozen_image", frozen)
	material_value.set_shader_parameter("mask_image", mask)
	material_value.set_shader_parameter("masked", mask != null)
	material_value.set_shader_parameter("softness", vague / 255)
	rect.material = material_value


func cancel() -> void:
	_generation += 1
	remaining = 0
	frozen = null
	_fade = 0
	_target = 0
	_mode = "fade"
	busy = false
	if rect != null:
		rect.material = null
		rect.hide()


func _update_rect() -> void:
	rect.color = Color(0, 0, 0, _fade)
	rect.visible = _fade > 0


func _process(delta: float) -> void:
	if get_tree().paused and not preview:
		return
	if remaining <= 0:
		return
	if _mode == "fade":
		_fade = lerpf(_fade, _target, minf(1, delta / remaining))
		remaining = maxf(0, remaining - delta)
		_update_rect()
	elif _mode == "transition":
		remaining = maxf(0, remaining - delta)
		rect.material.set_shader_parameter("progress", 1.0 - remaining / duration)
		if remaining == 0:
			cancel()


func _exit_tree() -> void:
	cancel()

extends CanvasLayer
## Render-only attachment; RuntimeState owns all request and animation state.
const Cache=preload("RmxpCache.gd")
var model: RefCounted
var game: Node
var _canvas: Node2D
var _snapshot: Sprite2D
var _tree: Sprite2D
var _top: CanvasLayer
var _top_canvas: Node2D
var _particles_canvas: Node2D
var _particle_canvases: Array[Node2D]=[]
var _glitch_canvas: Node2D
var _scan_filter: ColorRect
var _blur: ShaderMaterial
var _tree_blur: ShaderMaterial
var _hidden: Dictionary={}
class EffectCanvas extends Node2D:
	var view: Node
	var top=false
	var role=""
	var particle_blend=0
	func _draw() -> void:
		if role=="particles": view.draw_particles(self,particle_blend)
		elif role=="glitch": view.draw_glitch(self)
		else: view.draw_effects(self,top)
func _ready() -> void:
	layer=8; process_mode=Node.PROCESS_MODE_ALWAYS
	_snapshot=Sprite2D.new(); _snapshot.centered=false; add_child(_snapshot)
	_tree=Sprite2D.new(); _tree.centered=false; add_child(_tree)
	var shader=Shader.new(); shader.code="""shader_type canvas_item;
render_mode unshaded;
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
	_blur=ShaderMaterial.new(); _blur.shader=shader; _snapshot.material=_blur
	_tree_blur=ShaderMaterial.new(); _tree_blur.shader=shader; _tree.material=_tree_blur
	_canvas=EffectCanvas.new(); _canvas.view=self; add_child(_canvas)
	for blend in 3:
		var particles=EffectCanvas.new(); particles.view=self; particles.role="particles"; particles.particle_blend=blend; add_child(particles)
		var material_value=CanvasItemMaterial.new(); material_value.blend_mode=[CanvasItemMaterial.BLEND_MODE_MIX,CanvasItemMaterial.BLEND_MODE_ADD,CanvasItemMaterial.BLEND_MODE_SUB][blend]; particles.material=material_value
		_particle_canvases.append(particles)
	_particles_canvas=_particle_canvases[0]
	var additive=CanvasItemMaterial.new(); additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	_top=CanvasLayer.new(); _top.layer=90; add_child(_top)
	_top_canvas=EffectCanvas.new(); _top_canvas.view=self; _top_canvas.top=true; _top.add_child(_top_canvas)
	_glitch_canvas=EffectCanvas.new(); _glitch_canvas.view=self; _glitch_canvas.role="glitch"; _glitch_canvas.material=additive; _top.add_child(_glitch_canvas)
	_scan_filter=ColorRect.new(); _scan_filter.mouse_filter=Control.MOUSE_FILTER_IGNORE; _scan_filter.color=Color8(221,136,0,80)
	var subtract=CanvasItemMaterial.new(); subtract.blend_mode=CanvasItemMaterial.BLEND_MODE_SUB; _scan_filter.material=subtract; _top.add_child(_scan_filter)
	model.bind(self)
func _process(delta: float) -> void:
	if not get_tree().paused: model.advance(delta)
func _exit_tree() -> void:
	if model!=null: model.reset()
func apply_map_visible(value: bool) -> void:
	if game==null or game._map==null: return
	game._map.visible=value
	# Original viewport1 owns panorama/fog/weather, while pictures and flash
	# belong to viewport2/3 and keep their independent visibility.
	if game._effects!=null:
		for child in game._effects.get_children():
			if child is CanvasLayer and child.layer in [-10,0]: child.visible=value
	if game._screen_renderer!=null and game._screen_renderer._tone_rect!=null: game._screen_renderer._tone_rect.get_parent().visible=value
func target_sprite(kind: String,id: int) -> Sprite2D:
	if game==null: return null
	if kind=="picture_unravel": return game._screen_renderer.sprites.get(id)
	var character: Node=game._player if id<0 else game._map.event_node(id)
	return character._sprite if character!=null and character._sprite!=null and character._sprite.texture!=null else null
func sync() -> void:
	if _canvas==null: return
	_snapshot.texture=model.blurred if model.blurred!=null else model.frozen
	_snapshot.visible=_snapshot.texture!=null and model.map_visible if model.blurred==null else _snapshot.texture!=null
	_blur.set_shader_parameter("radius",model.blur_radius)
	var wake: bool=model.transient.get("kind","")=="wake"
	_tree.visible=wake
	if wake:
		_tree.texture=model.transient.tree_texture; _tree.position=Vector2(0,model.transient.tree_y); _tree.modulate.a=model.transient.alpha/255.0; _tree_blur.set_shader_parameter("radius",model.transient.radius)
	_canvas.queue_redraw(); _top_canvas.queue_redraw()
	for canvas in _particle_canvases: canvas.queue_redraw()
	_glitch_canvas.queue_redraw()
	_scan_filter.visible=model.transient.get("kind","")=="Scanline"; _scan_filter.size=get_viewport().get_visible_rect().size
func draw_effects(canvas: Node2D,top: bool) -> void:
	var area: Vector2=get_viewport().get_visible_rect().size
	var effect: Dictionary=model.transient; var kind: String=effect.get("kind","")
	if top:
		if kind=="Scanline": _draw_scanline(canvas,effect,area)
		elif kind=="Flashback" and effect.tick>=6 and effect.tick<=35:
			canvas.draw_texture(Cache.picture("WhiteNoise/WhiteNoise_%d.png" % [posmod(int(effect.tick)-5,20)+1]),Vector2.ZERO)
		return
	if model.filter_enabled and model.map_visible: canvas.draw_rect(Rect2(Vector2.ZERO,area),Color8(225,160,0,50))
	if model.rect_amount>0:
		canvas.draw_rect(Rect2(0,model.rect_amount-74,area.x,74),Color.BLACK)
		canvas.draw_rect(Rect2(0,area.y-model.rect_amount,area.x,74),Color.BLACK)
	if model.voice_visible and model.voice!=null:
		canvas.draw_set_transform(Vector2(384,288),0,Vector2.ONE*model.voice_zoom)
		canvas.draw_texture(model.voice,Vector2(-480,-360),Color(1,1,1,model.voice_alpha/255.0)); canvas.draw_set_transform(Vector2.ZERO)
	if kind=="wake": canvas.draw_texture(Cache.picture("Engine/Eye/%d.png" % effect.picture),Vector2.ZERO,Color(1,1,1,effect.alpha/255.0))
	if model.broken!=null:
		for shard in model.broken.shards:
			canvas.draw_set_transform(shard.position,0,shard.scale); canvas.draw_texture(shard.texture,-shard.origin)
	canvas.draw_set_transform(Vector2.ZERO)
func draw_particles(canvas: Node2D,blend: int=0) -> void:
	for set in model.particle_sets:
		for part in set.model.particles:
			if int(part.blend_type)!=blend: continue
			canvas.draw_set_transform(part.position,deg_to_rad(part.angle),part.scale); canvas.draw_texture(part.texture,Vector2.ZERO,Color(1,1,1,part.opacity/255.0))
	canvas.draw_set_transform(Vector2.ZERO)
func draw_glitch(canvas: Node2D) -> void:
	var effect: Dictionary=model.transient
	if effect.get("kind","")=="Scanline" and effect.glitch_alpha>0: canvas.draw_rect(effect.glitch_rect,Color(1,1,1,128.0/255*effect.glitch_alpha/255))
func _draw_scanline(canvas: Node2D,effect: Dictionary,area: Vector2) -> void:
	var tick: int=effect.tick; var vertical: bool=effect.direction==0
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(1+sin(tick*PI/30)*0.015,1+cos(tick*PI/45)*0.012)); canvas.draw_texture(effect.texture,Vector2.ZERO); canvas.draw_set_transform(Vector2.ZERO)
	var start=64 if vertical else int(area.x/8); var end=int(area.y)-112 if vertical else int(area.x)-int(area.x/8)-48
	var position=start+int(float(tick)*(end-start)/120)
	for i in 48:
		var offset=int(sin((i+tick)*PI/12)*4)
		var source=Rect2(0,position+i,area.x,1) if vertical else Rect2(position+i,0,1,area.y)
		var target=source; target.position+=Vector2(offset,0) if vertical else Vector2(0,offset)
		canvas.draw_texture_rect_region(effect.texture,target,source,Color(1,1,1,192.0/255))
		canvas.draw_rect(source,Color8(192,192,192,32) if i%2==0 else Color8(128,128,128,16))

@tool
extends Control
## Bordered image preview. Materials and atlas regions belong to this control.
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
signal activated
signal frame_selected(direction: int, pattern: int)
var texture: Texture2D
var _image: TextureRect
var _overlay: Control
var _label: Label
var _heading: Label
var _purpose: Label
var _caption=""
const TITLES={"Characters":"行走图","Tilesets":"普通图块","Autotiles":"自动图块","Panoramas":"全景背景","Fogs":"雾覆盖图","Windowskins":"窗口皮肤","Icons":"图标","Animations":"动画图像","Pictures":"事件图片","Transitions":"过渡遮罩","Battlers":"战斗图（元数据）","Battlebacks":"战斗背景（元数据）","Titles":"标题背景","Gameovers":"游戏结束背景"}
const PURPOSES={"Characters":"地图角色外观 · 4×4 帧","Tilesets":"用于在地图上铺设图块","Autotiles":"自动连接相邻地形","Panoramas":"地图后方的背景图","Fogs":"地图上方的雾覆盖层","Windowskins":"窗口边框与背景","Icons":"物品、技能等的小图标","Animations":"动画播放使用的帧图","Pictures":"事件显示的画面图片","Transitions":"画面切换使用的遮罩","Battlers":"角色或敌人的战斗外观","Battlebacks":"战斗场景的背景图","Titles":"标题画面的背景","Gameovers":"游戏结束画面的背景"}
var _category=""
var _name=""
var _settings: Dictionary={}
var _sheet=false
var _editable=true
var _image_rect=Rect2()
var _documents: RefCounted

func configure(documents: RefCounted, category: String, asset_name: String, settings: Dictionary = {}, sheet: bool = false, editable: bool = true, caption: String = "") -> void:
	_category=category; _name=asset_name; _settings=settings.duplicate(); _sheet=sheet; _editable=editable
	_caption=caption
	_documents=documents
	texture=documents.asset_texture(category,asset_name) if documents!=null else null
	var tile_region=Rect2()
	if int(settings.get("tile_id",0))>=384 and settings.get("tileset") is Dictionary:
		var layout=preload("res://runtime/scripts/TilesetLayout.gd").new(); layout.configure(settings.tileset,func(name: String) -> Texture2D: return documents.asset_texture("Tilesets",name))
		var found: Dictionary=layout.locate(int(settings.tile_id)); texture=found.get("texture"); tile_region=found.get("region",Rect2()); asset_name=str(found.get("name",asset_name)); _name=asset_name
	if _image==null:
		custom_minimum_size=custom_minimum_size.max(Vector2(170,180)); mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		_heading=Label.new(); _heading.mouse_filter=Control.MOUSE_FILTER_IGNORE; _heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; _heading.add_theme_font_size_override("font_size",14); add_child(_heading)
		_purpose=Label.new(); _purpose.mouse_filter=Control.MOUSE_FILTER_IGNORE; _purpose.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _purpose.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; _purpose.add_theme_font_size_override("font_size",12); add_child(_purpose)
		_image=TextureRect.new(); _image.mouse_filter=Control.MOUSE_FILTER_IGNORE; _image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; _image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; add_child(_image)
		_overlay=Control.new(); _overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_overlay); _overlay.draw.connect(_draw_overlay)
		_label=Label.new(); _label.mouse_filter=Control.MOUSE_FILTER_IGNORE; _label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; add_child(_label)
		resized.connect(_layout)
		if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().filesystem_changed.connect(func() -> void: call_deferred("_reload_texture"))
	_image.texture=texture
	if texture!=null and category=="Characters" and not sheet:
		var atlas=AtlasTexture.new(); atlas.atlas=texture
		atlas.region=Rect2(Vector2(clampi(int(settings.get("pattern",0)),0,3),[2,4,6,8].find(int(settings.get("direction",2))) if int(settings.get("direction",2)) in [2,4,6,8] else 0)*texture.get_size()/4.0,texture.get_size()/4.0)
		_image.texture=atlas
	elif texture!=null and int(settings.get("tile_id",0))>=384:
		var tile=int(settings.tile_id)-384; var atlas=AtlasTexture.new(); atlas.atlas=texture; atlas.region=tile_region if tile_region.has_area() else Rect2(Vector2(tile%8,tile/8)*32,Vector2(32,32)); _image.texture=atlas
	elif texture!=null and int(settings.get("tile_id",0))>=48:
		if texture.get_height()==32:
			var atlas=AtlasTexture.new(); atlas.atlas=texture; atlas.region=Rect2(0,0,32,32); _image.texture=atlas
		else:
			var source=texture.get_image(); var composed=Image.create(32,32,false,Image.FORMAT_RGBA8)
			source.convert(Image.FORMAT_RGBA8)
			for q in 4:
				var part=int(preload("EditorMapCanvas.gd").AUTOTILE_PARTS[int(settings.tile_id)%48][q])-1
				composed.blit_rect(source,Rect2i((part%6)*16,(part/6)*16,16,16),Vector2i(q%2,q/2)*16)
			_image.texture=ImageTexture.create_from_image(composed)
	var material_instance=ShaderMaterial.new(); var shader=Shader.new(); shader.code=HUE_SHADER
	var blend=clampi(int(settings.get("blend_type",0)),0,2)
	shader.code=HUE_SHADER.replace("shader_type canvas_item;","shader_type canvas_item;\nrender_mode "+["blend_mix","blend_add","blend_sub"][blend]+";")
	material_instance.shader=shader; material_instance.set_shader_parameter("hue",float(settings.get("hue",settings.get("character_hue",0)))/360.0)
	_image.material=material_instance; _image.modulate.a=clampf(float(settings.get("opacity",255))/255.0,0.0,1.0)
	_heading.text=caption if not caption.is_empty() else str(TITLES.get(category,category))
	_purpose.text="当前地图图块集中的事件外观" if int(settings.get("tile_id",0))>0 else str(PURPOSES.get(category,"图片素材"))
	_label.text=("无素材" if asset_name.is_empty() else "素材缺失 · "+asset_name if texture==null else asset_name)+("\n双击更换素材" if editable and not sheet else "\n点击选择方向 / 帧" if category=="Characters" and sheet else "")
	tooltip_text=_heading.text+"\n"+_purpose.text+"\n"+_label.text+(" · %d × %d" % [texture.get_width(),texture.get_height()] if texture!=null else "")
	_layout()

func _reload_texture() -> void:
	if texture==null and not _name.is_empty() and is_visible_in_tree(): configure(_documents,_category,_name,_settings,_sheet,_editable,_caption)

func _layout() -> void:
	if _image==null: return
	_heading.position=Vector2(6,4); _heading.size=Vector2(maxf(0,size.x-12),24)
	_purpose.position=Vector2(6,28); _purpose.size=Vector2(maxf(0,size.x-12),20)
	_image.position=Vector2(6,50); _image.size=Vector2(maxf(0,size.x-12),maxf(0,size.y-110))
	_label.position=Vector2(6,maxf(6,size.y-52)); _label.size=Vector2(maxf(0,size.x-12),48)
	_overlay.size=size
	var shown: Texture2D=_image.texture
	_image_rect=Rect2()
	if shown!=null:
		var factor=minf(_image.size.x/shown.get_width(),_image.size.y/shown.get_height())
		var dimensions=shown.get_size()*factor
		_image_rect=Rect2(_image.position+(_image.size-dimensions)/2.0,dimensions)
	queue_redraw(); _overlay.queue_redraw()

func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel","Tree"),Rect2(Vector2.ZERO,size))
	for y in range(50,maxi(50,int(size.y)-56),16):
		for x in range(6,maxi(6,int(size.x)-6),16):
			draw_rect(Rect2(Vector2(x,y),Vector2(mini(16,int(size.x)-6-x),mini(16,int(size.y)-56-y))),Color(0.23,0.25,0.28) if (x/16+y/16)%2==0 else Color(0.17,0.19,0.22))
	draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),Color(0.5,0.58,0.68),false,1.0)

func _draw_overlay() -> void:
	if not _sheet or _category!="Characters" or texture==null: return
	var cell=_image_rect.size/4.0
	for i in range(1,4):
		_overlay.draw_line(_image_rect.position+Vector2(cell.x*i,0),_image_rect.position+Vector2(cell.x*i,_image_rect.size.y),Color(1,1,1,0.4))
		_overlay.draw_line(_image_rect.position+Vector2(0,cell.y*i),_image_rect.position+Vector2(_image_rect.size.x,cell.y*i),Color(1,1,1,0.4))
	var row=[2,4,6,8].find(int(_settings.get("direction",2))); row=maxi(0,row)
	_overlay.draw_rect(Rect2(_image_rect.position+Vector2(clampi(int(_settings.get("pattern",0)),0,3),row)*cell,cell),Color(1,0.8,0.25),false,3.0)

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed: return
	if _sheet and _category=="Characters" and texture!=null and _image_rect.has_point(event.position):
		var cell=Vector2i((event.position-_image_rect.position)/(_image_rect.size/4.0)); _settings.direction=[2,4,6,8][clampi(cell.y,0,3)]; _settings.pattern=clampi(cell.x,0,3)
		frame_selected.emit(int(_settings.direction),int(_settings.pattern)); _overlay.queue_redraw(); accept_event()
	elif _editable and event.double_click: activated.emit(); accept_event()

extends Control
## Source TextBox/HintBox sprites. This node contains no message timing or state.
const Text=preload("FlashMessageText.gd")
const Cache=preload("RmxpCache.gd")
var entry: Dictionary={}
var _body: Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_body=Control.new(); _body.mouse_filter=Control.MOUSE_FILTER_IGNORE; _body.clip_contents=true; add_child(_body)
	_body.draw.connect(_draw_text)

func refresh(owner: Object,viewport_size: Vector2) -> void:
	var model: RefCounted=entry.model; var layout: RefCounted=entry.layout
	var rect=layout.rectangle(owner,viewport_size,model)
	position=rect.position; size=rect.size+Vector2(0,50)
	pivot_offset=layout.anchor(owner)+model.offset-position
	scale=Vector2.ONE*model.zoom(); modulate.a=1
	_body.position=layout.text_origin; _body.size=layout.text_size
	_body.modulate.a=model.opacity()
	queue_redraw(); _body.queue_redraw()

func _draw() -> void:
	if entry.is_empty(): return
	var model: RefCounted=entry.model; var layout: RefCounted=entry.layout
	var frame=Cache.windowskin("MessageBox_Frame.png")
	var opacity=model.frame_opacity(); var contents_opacity=model.opacity()
	var rectangle=Rect2(0,25,layout.box_size.x,layout.box_size.y)
	draw_rect(rectangle.grow(-16),Color(1,1,1,230.0/255*opacity))
	if frame!=null:
		RenderingServer.canvas_item_add_nine_patch(get_canvas_item(),rectangle,Rect2(0,0,32,32),frame.get_rid(),Vector2(16,16),Vector2(16,16),RenderingServer.NINE_PATCH_STRETCH,RenderingServer.NINE_PATCH_STRETCH,false,Color(1,1,1,opacity))
	if not model.metadata.has("al") and frame!=null:
		var point=layout.anchor(RuntimeState)+model.offset-position
		var upper=point.y-layout.box_size.y-25>0
		draw_texture_rect_region(frame,Rect2(point.x-7,layout.box_size.y+25 if upper else 13,16,12),Rect2(32,4 if upper else 16,16,12),Color(1,1,1,opacity))
	if not layout.face_name.is_empty():
		var face=Cache.face(layout.face_name)
		if face!=null: draw_texture_rect_region(face,Rect2(8,32,96,96),Rect2(layout.face_index%4*96,int(layout.face_index/4)*96,96,96),Color(1,1,1,contents_opacity))
	if not layout.name_text.is_empty():
		var style=Text.defaults(); style.font_size=24
		draw_string(Text.font(style),Vector2(layout.text_origin.x,32+Text.font(style).get_ascent(24)),layout.name_text,HORIZONTAL_ALIGNMENT_LEFT,layout.text_size.x,24,Color(96.0/255,64.0/255,32.0/255,contents_opacity))
		for row in 4:
			var width=layout.text_size.x*0.8
			for x in int(width): draw_line(Vector2(layout.text_origin.x+x,52+row),Vector2(layout.text_origin.x+x+1,52+row),Color(180.0/255,32.0/255,32.0/255,(160-row*40)/255.0*(1-x/maxf(1,width))*contents_opacity))
	if entry.kind=="number" and model.state==3:
		var style=Text.defaults(); var text=str(entry.number).pad_zeros(int(entry.payload.digits))
		draw_rect(Rect2(layout.text_origin.x,layout.box_size.y-4,layout.text_size.x,28),Color(0.7,0.7,0.7,0.5))
		draw_string(Text.font(style),Vector2(layout.text_origin.x+4,layout.box_size.y+18),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.BLACK)

func _draw_text() -> void:
	if entry.is_empty(): return
	var model: RefCounted=entry.model; var layout: RefCounted=entry.layout
	if entry.kind=="choice" and model.state==3:
		var source_row=entry.payload.get("lines",[]).size()+int(entry.choice_index)
		if source_row<layout.rows.size():
			var indices: Array=layout.rows[source_row].indices
			if not indices.is_empty():
				var p: Dictionary=layout.positions[indices[0]]
				_body.draw_rect(Rect2(0,p.y-model.page_scroll,layout.text_size.x,maxf(28,layout.rows[source_row].height)),Color(0.7,0.7,0.7,0.4))
	for painted in model.painted:
		if not layout.positions.has(painted.get("token_index",-1)): continue
		var position_value: Dictionary=layout.positions[painted.token_index]; var point=Vector2(position_value.x,position_value.y-model.page_scroll)
		if point.y<0: continue # Source page-on clears the scrolled bitmap area.
		var style: Dictionary=painted.style; var tint=Text.color(int(style.color)); tint.a*=clampf(float(style.opacity)/255,0,1)
		if painted.kind=="glyph":
			var font=Text.font(style); _body.draw_string(font,point+Vector2(0,font.get_ascent(int(style.font_size))),painted.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(style.font_size),tint)
		elif painted.kind=="icon":
			var icon=Cache.icon(painted.name)
			if icon!=null: _body.draw_texture(icon,point+Vector2(2,0),Color(1,1,1,float(style.opacity)/255))

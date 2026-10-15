extends RefCounted
## 0023 text drawing moves to CanvasItem; callers invoke from _draw(), keeping
## native fonts and owned canvas state rather than rasterizing shared textures.
const Text=preload("FlashMessageText.gd")
const Palette=preload("FlashPalette.gd")
static func draw_text(target: CanvasItem,rect: Rect2,value: String,style: Dictionary,align: int=0,shadow: bool=false) -> void:
	var font=Text.font(style); var font_size=int(style.font_size); var measured=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var x=rect.position.x+(rect.size.x-measured.x)/2 if align==1 else rect.end.x-measured.x if align==2 else rect.position.x
	var baseline=Vector2(x,rect.position.y+(rect.size.y-measured.y)/2+font.get_ascent(font_size)); var color=Text.color(int(style.get("color",-1))); color.a*=clampf(float(style.get("opacity",255))/255,0,1)
	if shadow:
		var dark=(color.r+color.g+color.b)*255<384; var shade=Color(128.0/255,128.0/255,128.0/255,color.a*0.75) if dark else Color(32.0/255,32.0/255,32.0/255,color.a*0.75)
		target.draw_string(font,baseline+Vector2.ONE,value,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,font_size,shade)
	target.draw_string(font,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,font_size,color)
static func draw_text_border(target: CanvasItem,rect: Rect2,value: String,style: Dictionary,align: int=0) -> void:
	for offset in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]: draw_text(target,Rect2(rect.position+offset,rect.size),value,style,align)
static func draw_delete_line_text(target: CanvasItem,rect: Rect2,value: String,style: Dictionary,align: int=0,shadow: bool=false) -> void:
	# Original Ruby1/3 is integer zero, so its two strokes are y+8/y+16.
	for offset in [8,16]: target.draw_line(Vector2(8,rect.position.y+offset),Vector2(rect.size.x-24,rect.position.y+offset),Palette.color(17))
	draw_text(target,rect,value,style,align,shadow)
static func draw_rich_text(target: CanvasItem,rect: Rect2,raw: String,owner: Object,align: int=0,memory: bool=false) -> Dictionary:
	var row=load("res://runtime/scripts/FlashTextRow.gd").new(raw,owner)
	if not row.failure.is_empty(): return {"ok":false,"message":row.failure}
	var style=Text.defaults(); var x=rect.position.x
	for token in row.tokens:
		if token is Array:
			if token[0].unicode_at(0) in [1,20,21,23,25,26]:
				Text.apply_style(style,token)
				if memory and style.color==8: style.color=0
				if memory and token[0].unicode_at(0)==21: style.font_size=maxi(1,style.font_size-2)
			continue # Source ignores other rich-text controls in this renderer.
		var measured=Text.font(style).get_string_size(token,HORIZONTAL_ALIGNMENT_LEFT,-1,int(style.font_size))
		var dy=(row.text_height-measured.y)/2 if row.valign==2 else 0
		draw_text(target,Rect2(x,rect.position.y+dy,measured.x,measured.y),token,style,align); x+=measured.x
	return {"ok":true,"width":x-rect.position.x}

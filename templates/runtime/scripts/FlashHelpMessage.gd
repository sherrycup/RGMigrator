extends RefCounted
## 0312 Help_Message is unfinished in the original. Blank shadow bitmaps have
## no visible content; retain their geometry without allocating leaked sprites.
var rect: Rect2i
var shadows: Array=[]
var text=""
func _init(x: int=0,y: int=0,width: int=0,height: int=0,canvas: Vector2i=Vector2i(640,640)) -> void:
	rect=Rect2i(x,y,width,height); make_shadow(canvas)
func make_shadow(canvas: Vector2i=Vector2i(640,640)) -> void:
	var widths=[rect.position.x,canvas.x-rect.size.x-rect.position.x,rect.size.x,rect.size.x]
	var heights=[canvas.y,canvas.y,rect.position.y,canvas.x-rect.position.y-rect.size.y]
	var xs=[0,rect.position.x,rect.end.x,rect.position.x]; var ys=[0,0,0,rect.end.y]
	shadows=[]
	for i in 4: shadows.append(Rect2i(xs[i],ys[i],maxi(0,widths[i]),maxi(0,heights[i])))
func set_text(_type: Variant) -> void: pass # Source empty, no tutorial invented.
func update() -> void: pass # Source empty.
func dispose() -> void: shadows.clear() # Only this instance owns the records.

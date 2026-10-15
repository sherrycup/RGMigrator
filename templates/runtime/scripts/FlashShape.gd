extends RefCounted
## 0030 Shape / final loaded 0031 Hexagon. The last twist definition updates
## phase, while the source scanlines do not rotate with phase.
var origin=Vector2i.ZERO
var rects: Array=[]
var radius=0
var phase=0.0
func _init(x: int=0,y: int=0,rectangles: Array=[]) -> void:
	origin=Vector2i(x,y); rects=rectangles.duplicate(true)
func set_origin(point: Vector2i) -> void:
	for i in rects.size(): rects[i].position+=point-origin
	origin=point
func includes(point: Vector2i) -> bool:
	for rect in rects:
		if rect.has_point(point): return true
	return false
func each_pixel(callback: Callable) -> void:
	for rect in rects:
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y): callback.call(x,y)
func each_rect(callback: Callable) -> void:
	for rect in rects: callback.call(rect)
func fill(bitmap: RefCounted,color: Color) -> void:
	for rect in rects: bitmap.fill_rect(rect,color)
func set_hexagon(value: int,phase_value: float=0) -> void:
	radius=maxi(0,value); phase=phase_value; rects.clear()
	for i in int(radius*sqrt(3)/2):
		var x=int(origin.x-radius+i/sqrt(3)); var width=radius*2-int(i*2/sqrt(3))
		rects.append(Rect2i(x,origin.y-i,width,1))
		if i!=0: rects.append(Rect2i(x,origin.y+i,width,1))
func twist(angle: float) -> void:
	if fmod(angle,60)==0: return
	set_hexagon(radius,phase+angle)

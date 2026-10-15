extends RefCounted
## Original 0251 MapSystemCursor, advanced by the UI's source 60 Hz clock.
const Config=preload("FlashMapConfig.gd")
var system: RefCounted
var x: float
var y: float
var area: int
var selected: RefCounted
var locked=true
var idle=0

func _init(owner: RefCounted,value: RefCounted) -> void:
	system=owner; select(value)

func select(value: RefCounted) -> void:
	selected=value; area=value.area
	var middle=value.center(); x=middle[0]; y=middle[1]; locked=true; idle=0

func rect() -> Rect2:
	return Rect2(selected.x,selected.y,selected.width,selected.height) if locked else Rect2(x-0.5,y-0.5,1,1)

func update(dx: int,dy: int) -> String:
	if dx!=0 or dy!=0:
		locked=false; idle=0; x+=dx*Config.CURSOR_SPEED; y+=dy*Config.CURSOR_SPEED
		var list=system.maps_in_area(area)
		var left=list[0].x; var top=list[0].y; var right=left+list[0].width; var bottom=top+list[0].height
		for value in list:
			left=mini(left,value.x); top=mini(top,value.y); right=maxi(right,value.x+value.width); bottom=maxi(bottom,value.y+value.height)
		x=clampf(x,left-2,right+2); y=clampf(y,top-2,bottom+2)
		return "move"
	if locked: return ""
	idle+=1
	if idle>=Config.LOCK_FRAMES: select(system.nearest_map(area,x,y)); return "lock"
	return ""

func change_area(step: int) -> void:
	var ids=system.areas().keys(); ids.sort()
	if ids.is_empty(): return
	var index=posmod(ids.find(area)+step,ids.size()); select(system.maps_in_area(ids[index])[0])

extends RefCounted
## Original 0247 Game_MapBlock. A bound block reads the current shared record
## after each script transaction; a cursor cannot retain an obsolete draft.
const Config=preload("FlashMapConfig.gd")
var id: int
var _standalone: Dictionary
var _system: WeakRef
var x: int:
	get: return int(record().x)
var y: int:
	get: return int(record().y)
var width: int:
	get: return int(record().width)
var height: int:
	get: return int(record().height)
var tile_width: int:
	get: return int(record().tile_width)
var tile_height: int:
	get: return int(record().tile_height)
var area: int:
	get: return int(record().area)

func _init(map_id: int,tiles_x: int=20,tiles_y: int=15,region: int=0) -> void:
	id=map_id
	_standalone={"id":id,"x":0,"y":0,"width":Config.cell_count(tiles_x,Config.CELL_WIDTH),"height":Config.cell_count(tiles_y,Config.CELL_HEIGHT),"tile_width":tiles_x,"tile_height":tiles_y,"area":region}

func bind(system: RefCounted) -> void:
	_system=weakref(system)

func record() -> Dictionary:
	return _system.get_ref().state().blocks[str(id)] if _system!=null and _system.get_ref()!=null else _standalone

func position() -> Array:
	return [x,y]

func set_position(pos: Array) -> void:
	var value=record(); value.x=int(pos[0]); value.y=int(pos[1])

func cell_at(px: int,py: int) -> Array:
	return [clampi(floori(float(px-1)/Config.CELL_WIDTH),0,width-1),clampi(floori(float(py-1)/Config.CELL_HEIGHT),0,height-1)]

func center() -> Array:
	return [x+width/2.0,y+height/2.0]

func distance_key(px: float,py: float) -> Array:
	var dx=maxf(maxf(x-px,0),px-x-width); var dy=maxf(maxf(y-py,0),py-y-height)
	var middle=center()
	return [dx*dx+dy*dy,pow(middle[0]-px,2)+pow(middle[1]-py,2),id]

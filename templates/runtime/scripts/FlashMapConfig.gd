extends RefCounted
## Original 0245 MapSystemConfig. These three editable tables are empty in the
## actual loaded Flash source; comments are examples, not real registrations.
const Data=preload("RuntimeData.gd")
const CELL_WIDTH=18
const CELL_HEIGHT=13
const CELL_SIZE=40
const CURSOR_SPEED=0.125
const LOCK_FRAMES=6
const PREVIEW_WIDTH=240
const PREVIEW_HEIGHT=180
static var AREAS: Dictionary={}
static var MAPS: Dictionary={}
static var DIRECTIONS: Dictionary={}

static func map_info(id: int) -> Dictionary:
	return MAPS.get(id,MAPS.get(str(id),{}))

static func map_name(id: int) -> String:
	var info=map_info(id)
	if info.get("name")!=null: return str(info.name)
	return str(Data.read_json("res://data/map_infos.json",{}).get(str(id),{}).get("name","Map %d" % id))

static func area_for(id: int) -> int:
	var info=map_info(id)
	if info.has("area"): return int(info.area)
	var matcher=RegEx.new(); matcher.compile("^(-?\\d+):(-?\\d+)")
	var found=matcher.search(map_name(id))
	return int(found.get_string(1)) if found!=null else 0

static func area_name(id: int) -> String:
	var area: Dictionary=AREAS.get(id,AREAS.get(str(id),{}))
	return str(area.get("name","未分区" if id==0 else "区域 %d" % id))

static func area_color(id: int) -> Color:
	var components: Array=AREAS.get(id,AREAS.get(str(id),{})).get("color",[72,150,128])
	return Color(float(components[0])/255.0,float(components[1])/255.0,float(components[2])/255.0)

static func cell_count(size: int,step: int) -> int:
	return maxi(floori(float(size-2+step-1)/step),1)

static func departure_override(a: int,b: int) -> Variant:
	return DIRECTIONS.get([a,b],DIRECTIONS.get("%d:%d" % [a,b]))

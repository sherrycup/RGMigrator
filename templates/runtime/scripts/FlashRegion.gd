extends RefCounted
## Original 0109 floor collection. generate_structure is empty in the source.
const Floor=preload("FlashFloor.gd")
var region: Variant=null
var floors: Dictionary={}
var _custom: WeakRef

func _init(custom: RefCounted,area: Variant) -> void:
	_custom=weakref(custom); region=area; load_floors()

func load_floors() -> void:
	floors.clear()
	if region==null or region is bool and not region: return
	var custom=_custom.get_ref()
	for key in custom.manifest.get("floors",{}).get("lookup",{}):
		var pair=str(key).split(":")
		if int(pair[0])==region: floors[int(pair[1])]=Floor.new(custom,int(pair[0]),int(pair[1]))

func generate_structure() -> void:
	pass

func set_region(area: Variant) -> void:
	if region==area: return
	region=area; load_floors()

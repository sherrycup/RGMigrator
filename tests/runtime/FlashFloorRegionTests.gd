extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Floor=preload("res://runtime/scripts/FlashFloor.gd")
const Region=preload("res://runtime/scripts/FlashRegion.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState"); var custom=state.custom_data
	var source=Data.map(4).duplicate(true); var fixture=source.duplicate(true)
	fixture.events={"1":{"id":1,"name":"门 2:7:[3,4]","x":5,"y":6,"pages":[]},"2":{"id":2,"name":"plain","x":1,"y":1,"pages":[]}}
	Data._cache["res://data/maps/Map004.json"]=fixture
	var record=Floor.new(custom,1,1)
	expect(record.map_id==4 and record.signature()==[1,1] and record.links[Vector2i(5,6)]==[2,7,[3,4]],"original floor signature/lookup and finite unanchored event-name link pattern are retained")
	state.map_id=4; state.player_motion.relocate(Vector2i(5,6))
	expect(record.transloc()==[[2,7,[3,4]]],"source transloc returns its original nested destination array without executing a transfer")
	state.player_motion.relocate(Vector2i(6,6)); expect(record.transloc()==false,"non-link player position returns source false")
	state.map_id=5; state.player_motion.relocate(Vector2i(5,6)); expect(record.transloc()==false,"different current map returns source false")
	custom.values.system.event_name["4"]={"1":"-2:-3:[9,8]"}; custom.values.system.event_position["4"]={"1":[7,8]}
	expect(record.links[Vector2i(5,6)]==[2,7,[3,4]],"already constructed floor links remain unchanged until original load_links is called")
	record.load_links()
	expect(record.links.size()==1 and record.links[Vector2i(7,8)]==[-2,-3,[9,8]],"confirmed system field corrections apply actual name/position overrides and integer floor conversion")
	expect(fixture.events["1"].name=="门 2:7:[3,4]" and fixture.events["1"].x==5,"loading links never mutates the imported event definition")
	custom.values.system.event_name["4"]["1"]="--2:--3:[1,2]"; record.load_links()
	expect(record.links[Vector2i(7,8)]==[0,0,[1,2]],"original multiple-minus regex keeps Ruby to_i's zero result rather than inventing a valid negative number")
	var region=Region.new(custom,1)
	expect(region.floors.has(1) and region.floors[1].map_id==4 and not region.floors.has(2),"source region uses only actual array-key rows; flat P map connection does not invent floor2")
	var identity=region.floors[1]; region.set_region(1)
	expect(region.floors[1]==identity,"setting the same region preserves existing floor identities")
	region.set_region(99999); expect(region.floors.is_empty(),"different region reloads its own floor collection without fabricating maps")
	region.set_region(null); expect(region.floors.is_empty(),"source nil region contains no floors")
	region.generate_structure(); expect(region.floors.is_empty(),"source empty structure generator remains empty")
	custom.failure=""; Floor.new(custom,99999,99999)
	expect(not custom.failure.is_empty(),"invalid floor constructor produces an explicit source reference failure")
	custom.failure=""; custom.values.system.event_name.erase("4"); custom.values.system.event_position.erase("4"); Data._cache["res://data/maps/Map004.json"]=source
	for message in failures: printerr("FAIL: ",message)
	print("FLASH FLOOR/REGION: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Actions=preload("res://runtime/scripts/FlashActions.gd")
class Host extends Node:
	var map: Node
	func event_map() -> Node: return map
	func event_screen_transition_active() -> bool: return false
	func event_scene_transition_active() -> bool: return false
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.map_id=10
	state.actor(2)
	var host=Host.new(); root.add_child(host)
	var map: Node=load("res://runtime/scripts/MapRuntime.gd").new(); host.add_child(map); host.map=map
	map.map_data=Data.map(10).duplicate(true); map._loaded_id=10
	map.map_data.events={}; state._game_ref=weakref(host)
	var player: Node=load("res://runtime/scripts/MapCharacter.gd").new(); map.add_child(player)
	player.map_runtime=map; player.motion.relocate(Vector2i(13,9)); player.motion.direction=2; map.player_character=player
	state.player_x=13; state.player_y=9
	var original=Data.map(10).duplicate(true)
	set_tile(map,13,10,1,385); state.inventory["item:9"]=1
	var result=Actions.use_item(state,9)
	expect(result.ok and result.value==true and map.tile_id(13,10,1)==0 and state.inventory["item:9"]==0,"pickaxe removes the faced source wall and consumes its item: "+str(result.get("message","")))
	expect(state.custom_data.values.system.map_data["10"]["13:10:1"]==0 and Data.map(10)==original,"tile change is recorded separately without changing the source map definition")
	state.inventory["item:9"]=1
	result=Actions.use_item(state,9)
	expect(result.ok and result.value==false and state.inventory["item:9"]==1,"failed pickaxe target does not consume inventory")
	set_tile(map,1,1,1,385); set_tile(map,19,1,1,386); state.inventory["item:8"]=1
	result=Actions.use_item(state,8)
	expect(result.ok and result.value==true and map.tile_id(1,1,1)==0 and map.tile_id(19,1,1)==386,"quake uses the source map_range and leaves outside cells unchanged")
	set_tile(map,13,10,2,60); state.inventory["item:6"]=1
	result=Actions.use_item(state,6)
	expect(result.ok and result.value==true and map.tile_id(13,10,2)==0,"freeze includes the original lava Range 48...96")
	player.motion.relocate(Vector2i(14,9)); state.player_x=14
	for layer in 3: set_tile(map,12,9,layer,0)
	state.inventory["item:13"]=1
	result=Actions.use_item(state,13)
	expect(result.ok and result.value==true and player.motion.cell==Vector2i(12,9) and state.player_x==12 and state.inventory["item:13"]==0,"symcraft uses system center [13,9] and moves the native shared player")
	var event_id=int(original.events.keys()[0])
	var definition: Dictionary=original.events[str(event_id)].duplicate(true)
	definition.pages=[{"condition":{},"graphic":{"character_name":"","tile_id":0,"direction":2,"pattern":0,"opacity":255},"trigger":0,"list":[{"code":0,"parameters":[],"indent":0}],"move_type":0,"move_route":{"repeat":false,"skippable":false,"list":[{"code":0,"parameters":[]}]}}]
	map.map_data.events={str(event_id):definition}
	var event: Node=load("res://runtime/scripts/MapEvent.gd").new(); map.add_child(event)
	event.event_id=event_id; event.character_id=event_id; event.map_id=10; event.map_runtime=map; event.motion.relocate(Vector2i(12,10)); map._event_nodes.append(event)
	state.custom_data.values.system.event_name["10"]={str(event_id):"怪物1B"}
	state.inventory["item:19"]=1; state.inventory["item:18"]=1
	result=Actions.use_item(state,19)
	expect(result.ok and result.value==false and state.inventory["item:19"]==1 and map.event_node(event_id)!=null,"bomb preserves source B/b protection without consuming its item")
	state.custom_data.values.system.event_name["10"][str(event_id)]="怪物1"
	result=Actions.use_item(state,18)
	expect(result.ok and result.value==true and state.inventory["item:18"]==0 and state.inventory["item:19"]==1 and map.event_node(event_id)==null,"strike permanently clears an adjacent ordinary monster and consumes STRIKE rather than the source typo BOMB")
	state.custom_data.values.system.event_name["10"][str(event_id)]="门01"
	map.refresh_events()
	var giant_id=int(state.custom_data.gameplay().rules.constants.GIANT_KEY_ID)
	state.inventory["item:"+str(giant_id)]=1
	result=Actions.use_item(state,giant_id)
	var door: Node=map.event_node(event_id)
	expect(result.ok and result.value==true and door!=null and door.commands.size()>2 and state.inventory["item:"+str(giant_id)]==0,"giant key installs the normalized original door-animation macro on the native event: "+str(result.get("message","")))
	if door!=null:
		var tail: Dictionary=door.commands[-2]
		expect(tail.code==355 and tail.parameters==["_this.die"] and tail._script_binding.unit_id=="derived_0091_door_die","source-constructed door tail carries an executable GDScript binding")
	# This fixture checks persisted tile data; it does not provide an event scheduler.
	state._game_ref=null
	var saved=load("res://runtime/scripts/SaveCodec.gd").capture(state)
	var prepared=load("res://runtime/scripts/SaveCodec.gd").prepare(saved)
	expect(prepared.ok,"source tile changes validate in the detached save: "+str(prepared.get("message","")))
	saved.custom_data.system.map_data["10"]["999:1:1"]=0
	expect(not load("res://runtime/scripts/SaveCodec.gd").prepare(saved).ok,"malformed saved tile coordinates fail before restore")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MAP ITEMS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	state._game_ref=null; host.queue_free()
	quit(0 if failures.is_empty() else 1)

func set_tile(map: Node,x: int,y: int,z: int,value: int) -> void:
	var table: Dictionary=map.map_data.data
	table["values"][x+y*int(table.x_size)+z*int(table.x_size)*int(table.y_size)]=value

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

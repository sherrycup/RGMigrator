extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
const Actions=preload("res://runtime/scripts/FlashActions.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.map_id=10; state.playing=true; state.variables["14"]=[2,0]
	var actor=state.actor(2); actor.clear_states(); actor.set_project_parameter("maxhp",100); actor.hp=100
	var game: Node=load("res://runtime/scripts/Game.gd").new(); root.add_child(game)
	game._events_enabled=false; game.set_process(false); game._player.input_enabled=false
	await process_frame
	game._events_enabled=false
	var map: Node=game.event_map(); var constants: Dictionary=state.custom_data.gameplay().rules.constants
	var storage=state.custom_data.data_ref("gameplay_module",0,"Storage")
	var default_id=int(constants.POTION_ITEM_ID["1"])
	state.inventory["item:"+str(default_id)]=1; state.flash_temp_fields.item_id=default_id
	var before_max=actor.get_parameter("maxhp"); var before_hp=actor.hp
	var default_use=Scripts.call_method(storage,"use_item",[],state)
	expect(default_use.ok and default_use.value==true and actor.get_parameter("maxhp")==before_max+75 and actor.hp==before_hp and state.inventory_count("item",default_id)==0,"source use_item default reads Game_Temp.item_id and retains MAXHP potion semantics")
	var overlap_id=int(constants.GEM_ITEM_ID["1"])
	state.inventory["item:"+str(overlap_id)]=1; before_max=actor.get_parameter("maxhp"); var before_atk=actor.get_parameter("patk")
	var overlap=Actions.use_item(state,overlap_id)
	expect(overlap.ok and overlap.value==true and actor.get_parameter("maxhp")==before_max+200 and actor.get_parameter("patk")==before_atk,"source potion clause precedes gem clause when their actual IDs collide")
	for condition in ["poison","weak","slow","curse"]:
		var state_id=int(constants[condition.to_upper()+"_STATE_ID"]); var item_id=int(constants[condition.to_upper()+"_ITEM_ID"])
		actor.clear_states(); state.inventory["item:"+str(item_id)]=1
		var absent=Actions.use_item(state,item_id)
		expect(absent.ok and absent.value==false and state.inventory_count("item",item_id)==1,"source "+condition+" cure preserves item when the actor lacks that state")
		actor.add_project_state(state_id,true)
		var cured=Actions.use_item(state,item_id)
		expect(cured.ok and cured.value==true and not actor.has_state(state_id) and state.inventory_count("item",item_id)==0,"source "+condition+" cure removes the shared state and consumes once")
	for condition in ["poison","weak","slow","curse"]: actor.add_project_state(int(constants[condition.to_upper()+"_STATE_ID"]),true)
	actor.inflict_battle_down(); var slear_id=int(constants.SLEAR_ITEM_ID); state.inventory["item:"+str(slear_id)]=1
	var universal=Actions.use_item(state,slear_id)
	expect(universal.ok and universal.value==true and not actor.battle_down() and actor.get_state_ids().is_empty() and actor.hp==1 and state.inventory_count("item",slear_id)==0,"source SLEAR cures all four states and invokes actual battle-down recovery")
	for key in ["UPPER_ITEM_ID","LOWER_ITEM_ID","CRAFT_ITEM_ID","WILL_GATE_ITEM_ID","SWORD_ITEM_ID"]:
		var item_id=int(constants[key]); state.inventory["item:"+str(item_id)]=1
		var empty=Actions.use_item(state,item_id)
		expect(empty.ok and empty.value==null and state.inventory_count("item",item_id)==1,"source unfinished "+key+" returns nil and performs no invented effect or consumption")
	# Fatal case is covered in FlashFailureIsolationProbe: gem-id
	state.inventory["item:50"]=1
	var unknown=Actions.use_item(state,50)
	expect(unknown.ok and unknown.value==false and state.inventory_count("item",50)==1,"source Storage returns false for an ordinary recovery item outside its dispatch, leaving Item.Recover as the separate entry")
	# Protected faced events may still sit on a removable source tile: the
	# original success flag is replaced by the successful tile operation.
	var player: Node=game._player; player.motion.relocate(Vector2i(13,9)); player.turn(2)
	var ice: Node=map.event_node(56); ice.motion.relocate(Vector2i(13,10))
	if not state.custom_data.values.system.event_name.has("10"): state.custom_data.values.system.event_name["10"]={}
	state.custom_data.values.system.event_name["10"]["56"]="暗冰B"
	set_tile(map,13,10,2,0); var ice_id=int(constants.ICE_PICKAXE_ITEM_ID); state.inventory["item:"+str(ice_id)]=1
	var protected=Actions.use_item(state,ice_id)
	expect(protected.ok and protected.value==false and map.event_node(56)!=null and state.inventory_count("item",ice_id)==1,"source B-protected ice event alone refuses ice pickaxe and retains inventory")
	set_tile(map,13,10,2,390)
	var tile=Actions.use_item(state,ice_id)
	expect(tile.ok and tile.value==true and map.event_node(56)!=null and map.tile_id(13,10,2)==0 and state.inventory_count("item",ice_id)==0,"source removable ice tile succeeds even beside a protected event, without killing that event")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH STORAGE DISPATCH: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func set_tile(map: Node,x: int,y: int,z: int,value: int) -> void:
	var table: Dictionary=map.map_data.data
	table["values"][x+y*int(table.x_size)+z*int(table.x_size)*int(table.y_size)]=value

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

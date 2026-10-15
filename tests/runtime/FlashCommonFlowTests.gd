extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
var diagnostics: Array[String]=[]
var terminal=""
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.variables["14"]=[2,0]; state.map_id=10; state.playing=true
	var actor=state.actor(2)
	actor.set_project_parameter("maxhp",100); actor.hp=80
	actor.set_project_parameter("patk",20); actor.set_project_parameter("pdef",5); actor.set_project_parameter("agi",10)
	var game: Node=load("res://runtime/scripts/Game.gd").new(); root.add_child(game)
	game._events_enabled=false; game.set_process(false); game._player.input_enabled=false
	await process_frame
	game._events_enabled=false
	var map: Node=game.event_map()
	var original=Data.map(10).duplicate(true)
	var floor=state.custom_data._floor(10)
	var enemy_id=int(floor.entries.keys()[0])
	var original_enemy: Dictionary=original.events[str(enemy_id)]
	var interpreter: RefCounted=load("res://runtime/scripts/EventInterpreter.gd").new()
	interpreter.managed=true; interpreter.map_runtime=map; interpreter.common_events=Data.database("CommonEvents")
	interpreter.diagnostic_requested.connect(func(message):diagnostics.append(message))
	interpreter.scene_requested.connect(func(kind):terminal=kind; interpreter.cancel())
	var init_ok=await execute_common(interpreter,21,enemy_id,map)
	expect(init_ok and state.custom_data.values.system.shotcut_enabled and state.switches.get("55")==true,"complete original CE21 initialization executes through the native interpreter")
	var parallel_ok=await execute_common(interpreter,17,enemy_id,map)
	expect(parallel_ok and state.custom_data.record("Enemies",26).atk==8888 and state.custom_data.record("Enemies",27).pdef==9999,"complete original CE17 updates native shared enemy database")
	var fields: Dictionary=state.custom_data._floor(10).entries[str(enemy_id)].fields
	fields.maxhp=35; fields.atk=9; fields.pdef=3; fields.agi=10
	actor.set_experience(0); actor.project_fields.battle_animation=0
	var before_gold=state.gold
	var battle_ok=await execute_common(interpreter,1,enemy_id,map)
	expect(battle_ok and actor.hp==72 and actor.experience==int(fields.exp) and state.gold==before_gold+int(fields.gold),"complete original CE1 includes wait child, player settlement, rewards and growth: "+str(diagnostics))
	expect(state.custom_data._floor(10).entries[str(enemy_id)].battle.pending==null,"full common-event battle clears its fixed pending result")
	# Use an original bottle event, which has no floor-enemy instance.
	enemy_id=9; original_enemy=original.events[str(enemy_id)]
	# The list and source bindings are original; only the name/input fixture varies.
	var node: Node=map.event_node(enemy_id)
	map.map_data.events[str(enemy_id)].name="血瓶<7>"
	state.custom_data.values.floors.clear()
	state.flash_temp_fields.actor_id=0; state.flash_temp_fields.event_erase=true
	state.custom_data.values.system.potion_itemization=false
	var before_hp=actor.hp
	var bottle_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(bottle_ok and actor.hp==before_hp+7 and map.event_node(enemy_id)==null,"complete original name driver enters CE2 for a non-enemy bottle, defaults the actor and permanently removes the event: "+str(diagnostics))
	expect(state.flash_temp_fields.hp_addition==0 and state.custom_data.values.system.shotcut_enabled,"bottle chain resets source temporary addition and restores shortcuts")
	# Restore the same native source event for further driver branches.
	state.custom_data.values.system.event_name.get("10",{}).erase(str(enemy_id))
	map.map_data.events[str(enemy_id)]=original_enemy.duplicate(true); map.map_data.events[str(enemy_id)].name="宝石<patk:1;pdef:1;resist:[0,0,0,0,1]>"
	map.refresh_events(); await process_frame
	state.flash_temp_fields.event_erase=true
	var before_atk=actor.get_parameter("patk"); var resist=actor.get_resist()
	var gem_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(gem_ok and actor.get_parameter("patk")==before_atk+1 and actor.get_resist()[4]==resist[4]+1 and map.event_node(enemy_id)==null,"complete original gem chain applies typed expression, enters CE3 and dies: "+str(diagnostics))
	state.custom_data.values.system.event_name.get("10",{}).erase(str(enemy_id))
	map.map_data.events[str(enemy_id)]=original_enemy.duplicate(true); map.map_data.events[str(enemy_id)].name="物品1:2"
	map.refresh_events(); await process_frame
	state.flash_temp_fields.event_erase=true
	var before_keys=state.inventory_count("item",1)
	var item_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(item_ok and state.inventory_count("item",1)==before_keys+2 and map.event_node(enemy_id)==null,"complete original item-name branch grants its source quantity once")
	state.custom_data.values.system.event_name.get("10",{}).erase(str(enemy_id))
	map.map_data.events[str(enemy_id)]=original_enemy.duplicate(true); map.map_data.events[str(enemy_id)].name="门1"
	map.refresh_events(); await process_frame
	state.flash_temp_fields.event_erase=true
	var keys=state.inventory_count("item",1)
	var door_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(door_ok and state.inventory_count("item",1)==keys-1 and map.event_node(enemy_id)==null and state.flash_temp_fields.door_id==0,"complete original door chain consumes key, runs native forced route/wait and commits permanent death: "+str(diagnostics))
	state.custom_data.values.system.event_name.get("10",{}).erase(str(enemy_id))
	map.map_data.events[str(enemy_id)]=original_enemy.duplicate(true); map.map_data.events[str(enemy_id)].name="门1"
	map.refresh_events(); await process_frame
	state.inventory["item:1"]=0; state.flash_temp_fields.event_erase=true
	var locked_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(locked_ok and map.event_node(enemy_id)!=null and state.flash_temp_fields.event_erase and state.inventory_count("item",1)==0,"full no-key door branch preserves its event and resets event_erase for the next interaction")
	map.map_data.events[str(enemy_id)].name="路障1"; state.flash_temp_fields.actor_id=0
	var barrier_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(barrier_ok and actor.has_state(1) and map.event_node(enemy_id)!=null,"complete original barrier chain adds poison, runs native shake and preserves its event: "+str(diagnostics))
	map.map_data.events[str(enemy_id)].name="箱子"; node=map.event_node(enemy_id)
	node.motion.relocate(Vector2i(6,6)); node.configure_motion({"through":true})
	game._player.motion.relocate(Vector2i(6,5)); game._player.turn(2)
	var layer=int(state.custom_data.gameplay().rules.storage.aim_layer)
	map.map_data.data.values[6+7*int(map.map_data.data.x_size)+layer*int(map.map_data.data.x_size)*int(map.map_data.data.y_size)]=402
	var box_ok=await execute_common(interpreter,23,enemy_id,map)
	expect(box_ok and node.motion.target==Vector2i(6,7) and state.self_switches.get("10:"+str(enemy_id)+":A")==true,"complete original box chain reads its staged destination before applying native movement and target self-switch: "+str(diagnostics))
	state.custom_data.values.records["States:1"]={"name":"中毒:5"}
	game._player.set_process(false); game._player.configure_motion({"through":true}); game._player.motion.relocate(Vector2i(13,9))
	var maxhp=actor.get_parameter("maxhp"); var steps=state.steps
	var started: bool=game._player.move_straight(6)
	game._player.advance_motion(1.0)
	expect(started and state.steps==steps+1 and actor.get_parameter("maxhp")==maxhp-5,"actual native player arrival invokes source after-step poison once")
	var route=game._player.force_move_route({"repeat":false,"skippable":false,"list":[{"code":3,"parameters":[]},{"code":0,"parameters":[]}]})
	game._player.advance_motion(1.0); game._player.advance_motion(1.0)
	expect(route.ok and state.steps==steps+1 and actor.get_parameter("maxhp")==maxhp-5,"native forced route excludes source normal-step effects")
	actor.clear_states(); actor.set_project_parameter("maxhp",200); actor.hp=50
	state.flash_temp_fields.item_id=50; state.flash_temp_fields.actor_id=0; state.inventory["item:50"]=2
	var tool_ok=await execute_common(interpreter,9,0,map)
	expect(tool_ok and actor.hp==150 and state.inventory_count("item",50)==1 and not state.custom_data.values.system.interpretering,"complete original CE9 special item branch enters CE2, consumes once and resets interpreter flag: "+str(diagnostics))
	var inventory=state.inventory.duplicate(true)
	expect(await execute_common(interpreter,11,0,map) and state.inventory==inventory,"original CE11 currently contains only comments and does not invent an item grant")
	actor.set_level(99); var growth_ok=await execute_common(interpreter,14,0,map)
	expect(growth_ok and actor.level==99,"original growth chain safely stops when its actual source threshold table has no next entry")
	state.flash_temp_fields.ending_id=2; terminal=""
	var ending_ok=await execute_common(interpreter,12,0,map)
	expect(ending_ok and terminal=="title" and state.flash_temp_fields.ending_id==0,"original ending CE computes score, shows its native message request and requests title: "+str(ending_ok)+" / "+terminal+" / "+str(state.flash_temp_fields.ending_id)+" / "+str(diagnostics))
	for message in failures: printerr("FAIL: ",message)
	print("FLASH COMMON FLOWS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func execute_common(interpreter: RefCounted,id: int,event_id: int,map: Node) -> bool:
	diagnostics.clear()
	interpreter.start(Data.record("CommonEvents",id).list,event_id)
	interpreter.context.common_id=id
	for frame in 1200:
		if not interpreter.running: return diagnostics.is_empty()
		interpreter.advance(0.1)
		if interpreter.wait_state.kind=="message": interpreter.resume_message()
		map.flush_event_refresh()
		await process_frame
	diagnostics.append("common-event timed out: %d / %s" % [id,interpreter.wait_state.kind]); interpreter.cancel(); return false

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
const Actions=preload("res://runtime/scripts/FlashActions.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.actor(2); state.actor(3)
	var game: Node=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	state.variables["18"]=[[2,1,2,3]]; state.variables["3"]=0; state.variables["2"]=1
	var opened=game.show_flash_scene("Scene_Flytofloor"); var picker: Control=game._menus.menu
	expect(opened.ok and paused and picker.entries==[2,1,3] and picker.index==1,"actual standalone floor page deduplicates source chapter list and selects current floor")
	picker.activate()
	expect(state.variables["13"]==1 and not paused and game._menus.menu==null,"floor confirmation returns original variable13 selection without inventing a teleport")
	game.show_flash_scene("Scene_Flytofloor"); game._menus.menu.back()
	expect(state.variables["13"]=="stop","source floor cancel returns literal stop")
	game.show_flash_scene("Scene_CP"); picker=game._menus.menu; picker.index=0; picker.activate()
	expect(state.variables["12"]==1,"source actor selection returns actor.id minus one")
	game.show_flash_scene("Scene_CP"); game._menus.menu.back()
	expect(state.variables["12"]==2,"source actor cancel returns current main_id, preserving its distinct convention")
	game.show_flash_scene("Scene_Debug"); var debug: Control=game._menus.menu; debug.editing=true; debug.group=0; debug.index=2; var toggled=debug.change(0)
	expect(toggled.ok and state.switches.get("3",false),"actual source debug switch group toggles authoritative switch3")
	for i in debug.groups.size():
		if debug.groups[i].kind=="variable" and debug.groups[i].first==1: debug.group=i; break
	debug.index=6; state.variables["7"]=99999998; debug.change(10)
	expect(state.variables["7"]==99999999,"source debug increments preserve99,999,999 upper clamp")
	state.variables["7"]=-99999998; debug.change(-10)
	expect(state.variables["7"]==-99999999,"source debug decrements preserve negative clamp")
	# Fatal case is covered in FlashFailureIsolationProbe: debug
	game._menus.close_menu()
	state.inventory["weapon:1"]=2; var equipped=Actions.equip(state,2,0,1); var actor=state.actor(2); var inventory=state.inventory.duplicate()
	var equipment=game.show_flash_scene("Scene_Equip",[0,0]); var equip_page: Control=game._menus.menu
	var original=actor.equipment.duplicate(); var prediction=equip_page.preview_equipment(0)
	expect(equipped.ok and equipment.ok and original.size()==6 and actor.equipment==original and prediction.has("patk"),"standalone equipment previews against final six-slot actor and original formula without committing")
	equip_page.activate(); equip_page.index=equip_page.candidates.size()-1; var cancel=equip_page.activate()
	expect(cancel.ok and actor.equipment[0]==0 and state.inventory==inventory,"standalone equipment confirmation uses same source equip transaction and preserves its no-inventory-transfer behavior")
	game._menus.close_menu()
	actor.learn_skill(31); var sp=actor.sp; var casting=game.show_flash_scene("Scene_Skill",[0]); var skill_page: Control=game._menus.menu
	skill_page.activate()
	expect(casting.ok and skill_page.actor_id==2 and actor.sp==sp,"standalone learned-skill page is independent of configuration and unavailable legacy effects never spend SP")
	skill_page.handle_key(KEY_PAGEDOWN)
	expect(skill_page.actor_id==3,"standalone casting preserves source actor page cycling")
	game._menus.close_menu()
	var bad_scene=game.show_flash_scene("Scene_Equip",[99])
	expect(not bad_scene.ok and game._menus.menu==null and not paused,"native standalone scene validates constructor before creating a page")
	var source=Scripts.call_transaction(state,{"source":"source scene assignment"},func(env):
		var type=env.read_name("Scene_CP",{},env.root_receiver(),"Object"); var scene=env.invoke(type,"new",[])
		return env.write_name("$scene",scene,{},env.root_receiver(),"Object"))
	expect(source.ok and source.flash_scene_request.database=="Scene_CP" and game._menus.menu==null,"Ruby scene assignment produces a validated native request for the event owner")
	var interpreter=load("res://runtime/scripts/EventInterpreter.gd").new(); interpreter.managed=true; interpreter.map_runtime=game._map; interpreter.start([{"code":121,"indent":0,"parameters":[444,444,0]},{"code":0,"indent":0,"parameters":[]}],1)
	interpreter._wait_for_script(source)
	expect(interpreter.wait_kind()=="menu" and game._menus.menu.kind=="actor" and paused,"actual event owner opens standalone page and waits on its return token")
	game._menus.menu.back(); interpreter.advance(1.0/60)
	expect(state.switches.get("444",false) and interpreter.wait_kind()=="completed" and not paused,"actual standalone close releases event and executes next command once")
	interpreter.start([{"code":0,"indent":0,"parameters":[]}],1); interpreter._wait_for_script(source); var stale=game._menus._flash_scene_done; interpreter.cancel(); game._menus.close_menu(); stale.call()
	expect(not interpreter.running and interpreter.wait_kind().is_empty(),"cancelled or duplicate standalone close callbacks cannot resurrect an event")
	state.variables["18"]=0; game.show_flash_scene("Scene_Flytofloor"); picker=game._menus.menu; picker.activate()
	expect(picker.entries.is_empty() and game._menus.menu==picker,"missing original floor-selection list remains an empty page with safe confirmation")
	game._menus.close_menu(); game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH STANDALONE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

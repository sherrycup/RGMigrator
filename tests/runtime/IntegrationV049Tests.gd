## 职责：回归验证：连续执行原奖励、撤回、存档和换图事件的综合流程。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func outcome() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func event(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func transfer(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
## One uninterrupted source-event run through rewards, history, saves and transfers.
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
var state: Node
var game: Node
var Saves: Script
var samples: Array=[]
func _init() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func outcome() -> Variant:
	var actors={}
	for id in state.actors: actors[str(id)]=state.actors[id].persistent_data()
	return load("res://runtime/scripts/10_Support/Persistence/SaveGraph.gd").encode({"actors":actors,"variables":state.variables,"inventory":state.inventory,"gold":state.gold,"switches":state.switches,"self_switches":state.self_switches,"custom":state.custom_data.values}).value
func event(id: int) -> bool:
	var map=game.event_map()
	var commands: Array=map.map_data.events[str(id)].pages[0].list
	map.player_trigger_request=true
	var start=Time.get_ticks_usec()
	game._start_event(commands,id); map.player_trigger_request=false
	for frame in 900:
		if game._event_checkpoint.is_empty() and not game._interpreter.running:
			samples.append({"event":id,"elapsed_ms":(Time.get_ticks_usec()-start)/1000.0,"frames":frame})
			return true
		game._scheduler.advance(1.0/60.0,false)
		game._event_ui.pump(game.event_ui_available()); map.flush_event_refresh()
		if game._dialogue.is_open(): game._dialogue.dismiss()
		await process_frame
	return false
func transfer(id: int) -> bool:
	var request=game.begin_event_transfer(id,2,2,6,false)
	if not request.ok: return false
	for frame in 120:
		await process_frame
		var status=game.event_transfer_status(request.id)
		if not status.get("pending",false):
			# This deterministic harness drives the scheduler instead of Game._process.
			game._sync_event_input()
			return status.ok and state.map_id==id
	return false
func run() -> void:
	state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	Saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	Saves.directory_override="res://.godot/v049-integration-"+str(Time.get_ticks_usec())
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2
	state.party=[2]; state.variables["14"]=[2,0]; state.variables["25"]=0
	var actor=state.actor(2); actor.set_project_parameter("maxhp",100); actor.hp=80
	actor.set_project_parameter("patk",20); actor.set_project_parameter("pdef",5); actor.set_project_parameter("agi",10); actor.project_fields.battle_animation=0
	for id in [1,2,3]: state.inventory["item:"+str(id)]=3
	game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame
	game.reset_event_execution(); game._events_enabled=false; game._player.set_process(false); game._player.input_enabled=true
	var source_map=Data.map(10).duplicate(true)
	for entry in state.custom_data._floor(10).entries.values():
		entry.fields.maxhp=35; entry.fields.atk=9; entry.fields.pdef=3; entry.fields.agi=10
	for id in [22,9,10]:
		expect(await event(id),"complete original pickup chain "+str(id))
		expect(game.event_map().event_node(id)==null,"pickup is permanently removed "+str(id))
	expect(Saves.save_slot(1,state).ok,"save after the combined original pickup chains")
	var after_pickups=outcome()
	var hp=actor.hp; var experience=actor.experience; var gold=state.gold
	var fields=state.custom_data._floor(10).entries["70"].fields
	expect(await event(70),"actual monster event enters complete original battle/common-event chain")
	expect(state.variables["25"]==1 and game.event_map().event_node(70)==null,"player battle creates one event-before history record and removes the enemy")
	expect(actor.hp<hp and actor.experience==experience+int(fields.exp) and state.gold==gold+int(fields.gold),"battle applies damage, source experience and source gold once")
	expect(state.flash_history.undo().ok,"undo immediately after the real battle, including an asynchronous history write")
	expect(outcome()==after_pickups and game.event_map().event_node(70)!=null,"undo restores the complete pre-battle object state and monster without restoring earlier pickups")
	for id in [22,9,10]: expect(game.event_map().event_node(id)==null,"undo preserves an earlier pickup "+str(id))
	expect(await event(70),"battle can execute once again after undo")
	for pair in [[56,1],[57,2],[58,3]]:
		var before=state.inventory_count("item",pair[1])
		expect(await event(pair[0]),"complete original key-door route and wait "+str(pair[0]))
		expect(state.inventory_count("item",pair[1])==before-1 and game.event_map().event_node(pair[0])==null,"matching key is consumed once and door remains removed "+str(pair[0]))
	expect(state.variables["25"]==4,"replayed battle and three doors have continuous history numbering")
	expect(Saves.save_slot(1,state).ok,"overwrite the isolated slot with battle and three door results")
	var after_doors=outcome()
	state.gold=0; state.actor(2).hp=1; state.variables["91"]="temporary edit"
	expect(Saves.load_slot(1,state).ok and outcome()==after_doors,"load restores all combined results and discards subsequent changes")
	expect(await transfer(8),"native event transfer reaches map8")
	expect(await transfer(10),"native event transfer returns to map10")
	for id in [22,9,10,70,56,57,58]: expect(game.event_map().event_node(id)==null,"permanent event removal survives a round trip "+str(id))
	expect(state.custom_data.map_system().connections().size()>=2,"completed transfers record actual map connections")
	# Exercise the real menu coordinator's key handler after loading/transferring.
	for cycle in 5:
		var key=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true
		game._menus._input(key)
		expect(game._menus.menu!=null and paused,"ESC opens the menu after combined state restoration")
		var native_menu=game._menus.menu; native_menu.set_process(false)
		for tick in 8: native_menu._tick()
		game._menus._input(key)
		for tick in 8: native_menu._tick()
		expect(game._menus.menu==null and not paused,"ESC closes the menu and releases pause")
		await process_frame
	# The earlier valid slot is the production backup; corruption must not load a partial state.
	var primary=FileAccess.open(Saves.slot_path(1),FileAccess.WRITE); primary.store_string("broken primary"); primary.close()
	var recovered=Saves.read_slot(1)
	expect(recovered.ok and recovered.get("recovered",false),"damaged latest primary falls back to its verified pickup backup")
	expect(Saves.load_slot(1,state).ok and outcome()==after_pickups,"backup recovery restores exactly the earlier combined pickup result")
	expect(Data.map(10)==source_map,"all events, undo, saves and transfers leave original map definitions unchanged")
	expect(state.diagnostics.is_empty() and state._fatal_script_message.is_empty(),"combined happy path has no runtime diagnostics or fatal script error")
	state.flash_history.flush_pending()
	var file=FileAccess.open("res://.godot/v049-integration.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":samples},"\t")); file.close()
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH V049 INTEGRATION: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Graph=preload("res://runtime/scripts/SaveGraph.gd")
var Scripts: Script
var Actions: Script
var Maps: Script
var Store: Script
var Saves: Script
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Scripts=load("res://runtime/scripts/ScriptRuntime.gd"); Actions=load("res://runtime/scripts/FlashActions.gd"); Maps=load("res://runtime/scripts/FlashMapBridge.gd")
	Store=load("res://runtime/scripts/FlashFileStore.gd"); Saves=load("res://runtime/scripts/SaveService.gd")
	var state=root.get_node("RuntimeState")
	Saves.directory_override="res://.godot/performance-regression-%d" % Time.get_ticks_usec()
	state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2
	state.party=[2,3]; state.variables["14"]=[2,3]; state.variables["5"]=[1,1,0,1,1,0,0,1,1,1]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",1000); actor.hp=1000; state.actor(3)
	var game=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame; game.reset_event_execution(); game._player.set_process(false); game._player.input_enabled=true
	_test_graph()
	var definitions=state.custom_data.gameplay(); var draft=state.custom_data.fork()
	expect(is_same(draft.gameplay().rules,definitions.rules) and not is_same(draft.gameplay().simulator,definitions.simulator),"transactions share immutable rules and retain independent simulator state")
	draft.values.money["regression"]=1
	expect(not state.custom_data.values.money.has("regression"),"draft values remain detached despite definition reuse")
	var hud=game._flash_hud; hud._process(0); var background=hud._background; var meters=hud._meters
	for i in 20: state.record_step(); hud._process(0)
	expect(is_same(background,hud._background) and is_same(meters,hud._meters),"steps and clock notifications do not rebuild unchanged HUD textures")
	actor.hp-=1; state.state_changed.emit(); hud._process(0)
	expect(not is_same(meters,hud._meters) and hud.rows[0].hp==actor.hp,"a real HP change updates the HUD")
	expect(is_same(background,hud._background),"HP changes reuse the static HUD background")
	var before=actor.hp
	var poison=int(definitions.rules.constants.POISON_STATE_ID)
	state.inventory.clear(); actor.state_ids.clear()
	var idle=Actions.after_step(state)
	expect(idle.ok and idle.writes==0 and actor.hp==before,"ordinary steps with no enabled source effects are a no-op")
	state.custom_data.values.records["States:"+str(poison)]={"name":"毒:7"}; actor.state_ids.append(poison)
	var previous_cap=actor.get_parameter("maxhp")
	var damaged=Actions.after_step(state)
	expect(damaged.ok and state.actor(2).get_parameter("maxhp")==previous_cap-7 and state.actor(2).hp==mini(before,previous_cap-7),"poison retains the source MAXHP subtraction through the complete step transaction")
	actor=state.actor(2); actor.state_ids.clear(); before=actor.hp
	var changed=Scripts.call_transaction(state,{"source":"performance direct"},func(env):env._custom.staged_actor(2).hp-=9; return state.actor(2).hp)
	expect(changed.ok and changed.value==before-9 and state.actor(2).hp==before-9,"script business changes the live actor before returning")
	var event: Node=game._map._event_nodes[0]
	var found=Maps.invoke(state.custom_data,MapsReference(state),"check_event",[event.motion.cell.x,event.motion.cell.y])
	expect(found!=null and game._map.event_node(int(found)).motion.cell==event.motion.cell,"source check_event finds a live event at the supplied coordinates")
	expect(Maps.invoke(state.custom_data,MapsReference(state),"check_event",[-100,-100])==null,"source check_event returns nil for empty positions")
	expect(Maps.invoke(state.custom_data,MapsReference(state),"check_event",[event.motion.cell.x,event.motion.cell.y,{"__ruby_regex":{"source":".+","flags":""}}])!=null,"source event-name RegExp matching is retained")
	game._player.input_enabled=true; state.menu_disabled=false
	expect(game._menus.open_menu(),"real menu can open after map checks")
	var content=game._menus.menu._content; var selected=game._menus.menu.index
	game._menus.menu.handle_key(KEY_DOWN)
	expect(is_same(content,game._menus.menu._content) and game._menus.menu.index==posmod(selected+1,10),"menu navigation changes selection without recreating all controls")
	game._menus.close_menu()
	state.save_disabled=false; state.playing=true; state.variables["25"]=0; state.variables["600"]="before"
	game._player.motion.relocate(Vector2i(2,2)); game._player.input_enabled=true
	var history=state.flash_history; var pending=history.record_async(true)
	expect(pending.ok and pending.get("pending",false) and state.variables["25"]==1,"async record reserves its serial before event execution")
	var writer=history._writer; var skipped=history.record()
	expect(skipped.get("skipped",false) and is_same(writer,history._writer),"a same-frame explicit record skips without joining the async writer")
	state.variables["600"]="after"
	var undone=history.undo()
	expect(undone.ok and state.variables["600"]=="before" and state.variables["25"]==0,"undo uses the immutable event-before snapshot while disk work is pending")
	history.flush_pending()
	game.reset_event_execution(); game._player.input_enabled=true
	state.variables["600"]="first"; expect(history.record_async(true).ok,"first queued record is accepted")
	state.variables["600"]="second"; expect(history.record_async(true).ok,"second queued record is accepted")
	state.variables["600"]="later"; history.flush_pending()
	var first=Store.read(history.path_for(1),"undo"); var second=Store.read(history.path_for(2),"undo")
	expect(first.ok and second.ok and first.value.snapshot.variables["600"]=="first" and second.value.snapshot.variables["600"]=="second","FIFO disk records keep their separate capture times")
	expect(history._writer==null and history._jobs.is_empty(),"shutdown/save drain leaves no running history worker")
	var directory=Saves.directory_override; var blocked=directory+"-blocked"
	FileAccess.open(blocked,FileAccess.WRITE).store_string("not a directory"); Saves.directory_override=blocked+"/child"
	expect(history.record_async(true).ok,"write failure test reaches the background writer after valid capture")
	history.flush_pending()
	expect(state.diagnostics.any(func(message):return message.contains("事件前记录写入失败")),"disk failures are reported instead of claiming durable success")
	expect(history.undo().ok,"a disk failure preserves the current session's undo snapshot")
	Saves.directory_override=directory
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH PERFORMANCE REGRESSION: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func MapsReference(state: Node) -> Dictionary: return state.custom_data.data_ref("map",state.map_id)
func _test_graph() -> void:
	var a={"id":1}; var b={"id":1}; a.self=a
	var rows: Array=[]
	for i in 400: rows.append({"id":i,"link":a,"array":[i]})
	var original={"a":a,"alias":a,"distinct":b,"rows":rows}
	var cloned=Graph.clone(original)
	expect(is_same(cloned.a,cloned.alias) and is_same(cloned.a,cloned.a.self) and not is_same(cloned.a,cloned.distinct),"identity indexing preserves aliases, cycles and distinct equal containers")
	var encoded=Graph.encode(original); var decoded=Graph.decode(encoded.value)
	expect(decoded.ok and is_same(decoded.value.a,decoded.value.rows[399].link) and decoded.value.rows[399].id==399,"indexed graph encoding retains shared references throughout a large graph")
	var bad=Node.new()
	expect(not Graph.reason({"nested":[bad]}).is_empty() and not Graph.encode({"nested":[bad]}).ok,"fast graph validation retains resource rejection")
	bad.free()
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

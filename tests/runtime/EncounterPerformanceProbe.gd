## 职责：回归验证：测量原地图拾取、战斗和钥匙门完整事件的准备与帧耗时。
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
##   func record(label: String,elapsed: int) -> void
##     用途：记录当前操作或运行现场。
##     参数 label（String；必填）：界面或检查项的说明文本。
##     参数 elapsed（int；必填）：已经过的时间，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func frame_sample() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var phase="setup"
var measurements: Dictionary={}
var samples: Array=[]
var frame_gaps: Array=[]
var previous_frame=0
var no_history=false
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--no-history": no_history=true
	call_deferred("run")
func record(label: String,elapsed: int) -> void:
	var key=phase+"/"+label
	if not measurements.has(key): measurements[key]={"count":0,"total_us":0,"max_us":0}
	var row=measurements[key]; row.count+=1; row.total_us+=elapsed; row.max_us=maxi(row.max_us,elapsed)
func frame_sample() -> void:
	var now=Time.get_ticks_usec()
	if previous_frame>0: frame_gaps.append(now-previous_frame)
	previous_frame=now
func run() -> void:
	set_meta("perf_probe",self)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2
	state.party=[2,3]; state.variables["14"]=[2,3]; state.variables["5"]=[1,1,0,1,1,0,0,1,1,1]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",1000); actor.hp=800
	actor.set_project_parameter("patk",200); actor.set_project_parameter("pdef",100); actor.set_project_parameter("agi",10)
	actor.project_fields.battle_animation=0
	for id in [1,2,3]: state.inventory["item:"+str(id)]=10
	var checkpoint_clock=[0,0]
	state.flash_history.checkpoint_prepared.connect(func(_request,_result):
		if checkpoint_clock[0]>0: checkpoint_clock[1]=Time.get_ticks_usec()-checkpoint_clock[0])
	var game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame; game.reset_event_execution(); game._player.set_process(false); game._player.input_enabled=true
	game._dialogue.dismiss(); game._event_ui.cancel_all(); state.flash_history.reset()
	state.save_disabled=no_history
	var floor=state.custom_data._floor(10)
	for entry in floor.entries.values(): entry.fields.maxhp=35; entry.fields.atk=9; entry.fields.pdef=3; entry.fields.agi=10
	process_frame.connect(frame_sample)
	for event_id in [22,56,57,58,70]:
		phase=str(event_id)+"/"+str(game._map.map_data.events[str(event_id)].name)
		var commands=game._map.map_data.events[str(event_id)].pages[0].list
		game._map.player_trigger_request=true
		frame_gaps=[]; previous_frame=Time.get_ticks_usec()
		var started=Time.get_ticks_usec(); checkpoint_clock[0]=started; checkpoint_clock[1]=0
		game._start_event(commands,event_id)
		var start_us=Time.get_ticks_usec()-started; var frames=0; var checkpoint_us=0; var ticks: Array=[]; var waits={}
		if game._event_checkpoint.is_empty(): checkpoint_us=Time.get_ticks_usec()-started
		await process_frame
		for frame in 600:
			if checkpoint_us==0 and game._event_checkpoint.is_empty(): checkpoint_us=checkpoint_clock[1] if checkpoint_clock[1]>0 else Time.get_ticks_usec()-started
			if not game._interpreter.running and game._event_checkpoint.is_empty(): break
			var tick=Time.get_ticks_usec(); game._scheduler.advance(1.0/60.0,false)
			game._event_ui.pump(game.event_ui_available()); game._map.flush_event_refresh(); game._flash_hud._process(1.0/60.0)
			ticks.append(Time.get_ticks_usec()-tick); frames+=1
			var wait=game._interpreter.wait_state.kind; waits[wait]=int(waits.get(wait,0))+1
			if game._dialogue.is_open(): game._dialogue.dismiss()
			await process_frame
		frame_gaps.sort()
		var row={"event":event_id,"name":phase,"start_us":start_us,"checkpoint_us":checkpoint_us,"elapsed_us":Time.get_ticks_usec()-started,"frames":frames,"max_tick_us":ticks.max() if not ticks.is_empty() else 0,"frame_max_us":frame_gaps[-1] if not frame_gaps.is_empty() else 0,"waits":waits,"complete":not game._interpreter.running and game._event_checkpoint.is_empty(),"erased":game._map.event_node(event_id)==null}
		samples.append(row); print("ENCOUNTER SAMPLE: ",JSON.stringify(row))
		for frame in 3: await process_frame
	state.flash_history.flush_pending()
	var actors: Array=[]
	for id in state.actors: actors.append(state.actors[id].persistent_data())
	var outcome=load("res://runtime/scripts/10_Support/Persistence/SaveGraph.gd").encode({"variables":state.variables,"inventory":state.inventory,"gold":state.gold,"actors":actors,"custom":state.custom_data.values})
	var name="encounter-profile.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): name=arg.trim_prefix("--report=")
	var result={"samples":samples,"measurements":measurements,"diagnostics":state.diagnostics,"no_history":no_history,"outcome":outcome.value}
	var file=FileAccess.open("res://.godot/"+name,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	game.queue_free(); await process_frame
	var ok=samples.all(func(row):return row.complete and row.erased) and state.diagnostics.is_empty()
	print("ENCOUNTER PERFORMANCE: ","PASSED" if ok else "FAILED"); quit(0 if ok else 1)

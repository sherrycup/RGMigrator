## 职责：回归验证：测量游戏启动、移动、事件和菜单的帧耗时。
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
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func press(key: int) -> void
##     用途：模拟一次按键输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func sample(name: String,count: int) -> void
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var phase="setup"
var measurements: Dictionary={}
var frames: Dictionary={}
var actions: Dictionary={}
func _init() -> void: call_deferred("run")
func record(label: String,elapsed: int) -> void:
	var key=phase+"/"+label
	if not measurements.has(key): measurements[key]={"count":0,"total_us":0,"max_us":0}
	var row: Dictionary=measurements[key]; row.count+=1; row.total_us+=elapsed; row.max_us=maxi(row.max_us,elapsed)
func run() -> void:
	set_meta("perf_probe",self)
	root.size=Vector2i(640,640)
	print("PERF ENGINE fps=",Engine.max_fps," low_power=",OS.low_processor_usage_mode," window=",root.size," focused=",DisplayServer.window_is_focused())
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2; state.party=[2,3]; state.variables["14"]=[2,3]
	state.variables["5"]=[1,1,0,1,1,0,0,1,1,1]; state.inventory={"item:2":5}
	state.actor(2).set_project_parameter("maxhp",1000); state.actor(2).hp=1000
	var game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	game._interpreter.cancel(); game._player.input_enabled=true; game._player.through=true
	game._player.move_to(2,2)
	await sample("idle",30)
	print("PERF READY ",game._player.input_enabled," idle=",game._player.is_idle()," forcing=",game._player.routes.forcing," dialog=",game._dialogue.is_open()," paused=",paused," effects=",state.flash_effects.busy()," scene=",game._scene_pending," stop=",game._player.stop_after_step)
	print("PERF ACTIVE ",JSON.stringify(game._event_ui.active))
	game._dialogue.dismiss(); game._event_ui.cancel_all()
	game._player.input_enabled=true; game._player.stop_after_step=false
	var steps_before=state.steps
	Input.action_press("ui_right"); await sample("moving",75); Input.action_release("ui_right")
	for i in 12: await process_frame
	actions.steps=state.steps-steps_before
	phase="event"
	var event_id=0
	for event in game._map._event_nodes:
		if str(game._map.map_data.events[str(event.event_id)].name).contains("怪物"): event_id=event.event_id; break
	if event_id>0:
		game._map.player_trigger_request=true
		var started=Time.get_ticks_usec()
		game._start_event([{"code":121,"indent":0,"parameters":[190,190,0]},{"code":0,"indent":0,"parameters":[]}],event_id)
		actions.event_us=Time.get_ticks_usec()-started
		for frame in 360:
			if game._event_checkpoint.is_empty() and not game._interpreter.running: break
			game._scheduler.advance(1.0/60.0,false)
			await process_frame
		actions.event_completed=game._event_checkpoint.is_empty() and not game._interpreter.running and state.switches.get("190",false)
	game._interpreter.cancel(); game._player.input_enabled=true; state.menu_disabled=false
	print("PERF MENU ",game._menus.can_open()," idle=",game._player.is_idle()," dialog=",game._dialogue.is_open()," effects=",state.flash_effects.busy()," playing=",state.playing)
	phase="menu_open"; var started=Time.get_ticks_usec(); press(KEY_ESCAPE); actions.menu_opened=game._menus.menu!=null; actions.menu_open_us=Time.get_ticks_usec()-started
	await sample("menu_idle",30)
	phase="menu_navigation"; started=Time.get_ticks_usec()
	for i in 8:
		if game._menus.menu!=null: press(KEY_DOWN)
		await process_frame
	actions.menu_navigation_us=Time.get_ticks_usec()-started
	phase="menu_close"; started=Time.get_ticks_usec(); press(KEY_ESCAPE); actions.menu_close_us=Time.get_ticks_usec()-started
	await sample("resumed",30)
	actions.menu_closed=game._menus.menu==null and not paused and game._player.input_enabled
	actions.menu_cycles=[]
	for cycle in 3:
		phase="menu_cycle"; started=Time.get_ticks_usec(); press(KEY_ESCAPE)
		var opened=game._menus.menu!=null; var elapsed=Time.get_ticks_usec()-started
		for frame in 10: await process_frame
		if cycle==0 and DisplayServer.get_name()!="headless":
			root.get_texture().get_image().save_png("res://.godot/performance-menu.png")
		press(KEY_ESCAPE); actions.menu_cycles.append({"opened":opened,"closed":game._menus.menu==null and not paused,"open_ms":elapsed/1000.0})
		for frame in 10: await process_frame
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png("res://.godot/performance-map.png")
	var result={"frames":frames,"measurements":measurements,"actions":actions,"diagnostics":state.diagnostics}
	var path=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://.godot/performance.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FLASH PERFORMANCE: ",JSON.stringify({"frames":frames,"actions":actions}))
	game.queue_free(); await process_frame; quit()
func press(key: int) -> void:
	var event=InputEventKey.new(); event.keycode=key; event.pressed=true; root.push_input(event)
func sample(name: String,count: int) -> void:
	phase=name; var times: Array=[]; var previous=Time.get_ticks_usec()
	for i in count:
		await process_frame
		var now=Time.get_ticks_usec(); times.append(now-previous); previous=now
		if i==count-1: print("PERF MONITOR ",name," process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	times.sort(); var total=0
	for elapsed in times: total+=elapsed
	frames[name]={"frames":count,"mean_ms":float(total)/count/1000,"p95_ms":times[mini(count-1,int(count*0.95))]/1000.0,"max_ms":times[-1]/1000.0}

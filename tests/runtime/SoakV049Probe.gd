## 职责：回归验证：循环执行地图、事件、页面及存档操作，检查长时运行状态。
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
##   func press(key: int) -> void
##     用途：模拟一次按键输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func idle_frames(count: int) -> void
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
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
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var gaps: Array=[]
var stages: Array=[]
var resources: Array=[]
var checks=0
var failures: Array[String]=[]
var game: Node
var state: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func press(key: int) -> void:
	for down in [true,false]:
		var event=InputEventKey.new(); event.keycode=key; event.pressed=down; Input.parse_input_event(event); Input.flush_buffered_events()
func idle_frames(count: int) -> void:
	for i in count:
		var start=Time.get_ticks_usec(); await process_frame; gaps.append(Time.get_ticks_usec()-start)
func run() -> void:
	var seconds=300
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds=int(arg.trim_prefix("--seconds="))
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	var saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd"); saves.directory_override="res://.godot/v049-soak-"+str(Time.get_ticks_usec())
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=1
	state.party=[2]; state.variables["14"]=[2,0]; state.variables["25"]=0; state.variables["5"]=[1,1,0,1,1,0,0,1,1,1]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",1000); actor.hp=900; actor.set_project_parameter("patk",200); actor.set_project_parameter("pdef",100); actor.set_project_parameter("agi",10); actor.project_fields.battle_animation=0
	state.inventory["item:1"]=10
	game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); current_scene=game
	await process_frame; game.reset_event_execution(); game._events_enabled=true; game._player.through=true; game._player.input_enabled=true
	for entry in state.custom_data._floor(10).entries.values(): entry.fields.maxhp=35; entry.fields.atk=9; entry.fields.pdef=3; entry.fields.agi=10
	await idle_frames(60); gaps.clear()
	var started=Time.get_ticks_usec(); var cycle=0; var direction="ui_right"; var initial_steps=state.steps
	while Time.get_ticks_usec()-started<seconds*1000000:
		for i in 480:
			if game._player.motion.cell.x>=5: direction="ui_left"
			elif game._player.motion.cell.x<=2: direction="ui_right"
			Input.action_release("ui_left" if direction=="ui_right" else "ui_right"); Input.action_press(direction)
			await idle_frames(1)
		Input.action_release("ui_right"); Input.action_release("ui_left")
		await idle_frames(20)
		press(KEY_ESCAPE); await idle_frames(2)
		expect(game._menus.menu!=null and paused,"actual ESC input opens menu during sustained movement")
		if game._menus.menu!=null:
			for i in 8: press(KEY_DOWN); await idle_frames(2)
			press(KEY_ESCAPE)
		await idle_frames(3); expect(game._menus.menu==null and not paused and game._player.input_enabled,"actual ESC input releases menu and resumes player")
		var id=70 if cycle%2==0 else 56; var serial=state.variables["25"]
		game._map.player_trigger_request=true; var event_start=Time.get_ticks_usec()
		game._start_event(game._map.map_data.events[str(id)].pages[0].list,id); game._map.player_trigger_request=false
		for frame in 600:
			if game._event_checkpoint.is_empty() and not game._interpreter.running: break
			if game._dialogue.is_open(): game._dialogue.dismiss()
			await idle_frames(1)
		expect(game._event_checkpoint.is_empty() and not game._interpreter.running and game._map.event_node(id)==null,"complete original battle/door finishes while native scheduler and rendering run")
		await idle_frames(2); press(KEY_BACKSPACE); await idle_frames(3)
		expect(state.variables["25"]==serial and game._map.event_node(id)!=null,"actual BackSpace restores the just-completed event and history serial")
		var row={"cycle":cycle,"event":id,"event_ms":(Time.get_ticks_usec()-event_start)/1000.0}
		if cycle%3==0:
			var clock=Time.get_ticks_usec(); var saved=saves.save_slot(1,state); row.save_ms=(Time.get_ticks_usec()-clock)/1000.0
			expect(saved.ok,"explicit save succeeds during sustained running: "+str(saved.get("message","")))
			clock=Time.get_ticks_usec(); var loaded=saves.load_slot(1,state); row.load_ms=(Time.get_ticks_usec()-clock)/1000.0
			expect(loaded.ok,"explicit load restores sustained running state")
			await process_frame
		resources.append({"cycle":cycle,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":get_node_count(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
		stages.append(row); cycle+=1
		print("V049 SOAK PROGRESS: ",cycle," / ",snappedf((Time.get_ticks_usec()-started)/1000000.0,0.1),"s")
		if cycle==1 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.godot/v049-soak-map.png")
		if not failures.is_empty(): break
	expect(state.steps>initial_steps+30,"actual held directions continue advancing normal walking")
	expect(state.diagnostics.is_empty() and state._fatal_script_message.is_empty(),"sustained happy path has no diagnostics or fatal error")
	state.flash_history.flush_pending(); gaps.sort()
	var report={"ok":failures.is_empty(),"checks":checks,"failures":failures,"elapsed_seconds":(Time.get_ticks_usec()-started)/1000000.0,"cycles":cycle,"steps":state.steps-initial_steps,"interactive_frames":gaps.size(),"frame_median_ms":gaps[gaps.size()/2]/1000.0,"frame_p95_ms":gaps[int(gaps.size()*0.95)]/1000.0,"frame_max_ms":gaps[-1]/1000.0,"resources":resources,"stages":stages,"note":"Explicit save/load and undo handlers are reported separately; this finite run is not a whole-game or hours-long stability claim."}
	var file=FileAccess.open("res://.godot/v049-soak.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLASH V049 SOAK: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

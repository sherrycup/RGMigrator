## 职责：回归验证：通过独立写入和读取进程验证闪翼完整存档恢复。
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
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd"); var prefs=load("res://runtime/scripts/00_Game/Preferences.gd")
	var phase="write"; var directory=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase=argument.trim_prefix("--phase=")
		if argument.begins_with("--save-directory="): directory=argument.trim_prefix("--save-directory=")
	if directory.is_empty(): printerr("Restart test requires an isolated save directory"); quit(1); return
	saves.directory_override=directory; prefs.directory_override=directory
	var state=root.get_node("RuntimeState")
	if phase=="write":
		state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.actor(2); state.actor(3)
		var cycle={"value":42}; cycle.self=cycle; state.variables["80"]=cycle; state.variables["81"]=cycle; Scripts.script_data(state); state.script_session.globals["$restart"]=cycle
		Scripts.execute_unit("script_0317",state)
		state.flash_preferences.set_volume("bgm",6); state.flash_preferences.vars[21]=["unlocked"]; state.flash_preferences.music_lock=[true,null,false]; state.flash_preferences.save_preferences()
		var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game); await process_frame
		game.reset_event_execution(); game.set_process(false); game._player.set_process(false); game._events_enabled=false
		state.gold=55; state.variables["25"]=0
		var history_result: Dictionary=state.flash_history.record(true)
		expect(history_result.ok,"write original event-before snapshot: "+str(history_result.get("message","")))
		state.gold=123
		game._scheduler.start_main([{"code":101,"indent":0,"parameters":["跨进程恢复的活动消息。"]},{"code":0,"indent":0,"parameters":[]}],0,1,"restart",true)
		for frame in 120:
			game._interpreter.advance(0); game._event_ui.pump(true)
			if game._interpreter.wait_kind()=="message" and state.flash_messages.boxes.size()==1: break
			await process_frame
		expect(game._interpreter.wait_kind()=="message" and state.flash_messages.boxes.size()==1,"write fixture waits until its dialogue actually opens before capture")
		state.flash_messages.advance(13.0/60)
		game.play_flash_effect("set_rect",[]); state.flash_effects.advance(3.0/60)
		state.flash_followers.motions[0].relocate(Vector2i(2,2)); state.flash_followers.motions[0].begin_move(6); state.flash_followers.motions[0].advance(1.0/60)
		var save_result: Dictionary=saves.save_slot(12,state)
		expect(save_result.ok,"write active scene into production save envelope: "+str(save_result.get("message","")))
		game.queue_free(); await process_frame
	else:
		expect(state.flash_preferences.load_preferences().ok and state.flash_preferences.bgm_volume==6 and state.flash_preferences.vars[21]==["unlocked"] and state.flash_preferences.music_lock==[true,null,false],"new process reloads global configuration, achievements and music locks")
		var loaded=saves.load_slot(12,state)
		if not loaded.ok:
			printerr("FAIL: restore production save: ",loaded.get("message","unknown load failure"))
			quit(1)
			return
		expect(loaded.ok and state.gold==123 and is_same(state.variables["80"],state.variables["81"]) and is_same(state.variables["80"],state.script_session.globals["$restart"]),"new process restores cyclic graph links across roots")
		var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game)
		game.set_process(false); game._player.set_process(false)
		expect(game._interpreter.wait_kind()=="message" and state.flash_messages.boxes.size()==1,"new scene binds saved active dialogue to restored interpreter")
		expect(state.flash_effects.active.tick==3 and state.flash_followers.motions[0].moving(),"new scene restores active effect and mid-step follower")
		expect(state.script_session.classes.has("Actor_Init") and not state.script_session.methods.is_empty(),"new process retains generated class and alias method metadata")
		var undone=state.flash_history.undo()
		expect(undone.ok and state.gold==55 and state.variables["25"]==0 and state.flash_preferences.bgm_volume==6,"history file supports cross-process undo while preserving app settings")
		game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH SAVE RESTART: ","PASSED" if failures.is_empty() else "FAILED"," / ",phase," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

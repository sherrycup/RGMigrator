extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var saves=load("res://runtime/scripts/SaveService.gd"); var prefs=load("res://runtime/scripts/FlashPreferences.gd")
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
		var game: Node=load("res://runtime/scripts/Game.gd").new(); root.add_child(game); await process_frame
		game.reset_event_execution(); game.set_process(false); game._player.set_process(false); game._events_enabled=false
		state.gold=55; state.variables["25"]=0
		expect(state.flash_history.record(true).ok,"write original event-before snapshot")
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
		expect(saves.save_slot(12,state).ok,"write active scene into production save envelope")
		game.queue_free(); await process_frame
	else:
		expect(state.flash_preferences.load_preferences().ok and state.flash_preferences.bgm_volume==6 and state.flash_preferences.vars[21]==["unlocked"] and state.flash_preferences.music_lock==[true,null,false],"new process reloads global configuration, achievements and music locks")
		var loaded=saves.load_slot(12,state)
		expect(loaded.ok and state.gold==123 and is_same(state.variables["80"],state.variables["81"]) and is_same(state.variables["80"],state.script_session.globals["$restart"]),"new process restores cyclic graph links across roots")
		var game: Node=load("res://runtime/scripts/Game.gd").new(); root.add_child(game)
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

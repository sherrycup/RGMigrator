extends SceneTree
const Motion=preload("res://runtime/scripts/CharacterMotion.gd")
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false})
	expect(state.player_motion.options.move_speed==5 and state.player_motion.pixels_per_second()==480,"actual Flash new player preserves source constructor speed5 and RM128-units conversion at60Hz")
	var value=Motion.new(); value.relocate(Vector2i(2,2)); value.begin_move(6); value.advance(2.0/60)
	expect(value.cell==Vector2i(2,2) and value.visual_cell==Vector2(2.5,2) and value.moving(),"source speed5 advances16 visual pixels in exactly two frames while logical arrival stays pending")
	expect(value.advance(2.0/60)=="walk" and value.cell==Vector2i(3,2),"source128/2^5 four-frame cell traversal completes once")
	value.relocate(Vector2i(2,2)); value.begin_diagonal(Vector2i(1,1)); value.advance(2.0/60)
	expect(value.visual_cell==Vector2(2.5,2.5),"source diagonal preserves independent cardinal-axis distance per frame")
	value.relocate(Vector2i(2,2)); value.begin_jump(Vector2i(1,0)); value.advance(6.0/60)
	expect(value.visual_cell==Vector2(2.5,2) and is_equal_approx(value.jump_height,18),"source jumppeak10+round(distance)-speed gives6 and18px apex at six of12 frames")
	var restored=Motion.decode(JSON.parse_string(JSON.stringify(value.persistent_data())),8,8)
	expect(restored.ok and is_equal_approx(restored.value.jump_height,18) and restored.value.jumping(),"actual Flash mid-jump decode rebuilds source curve from saved duration")
	value.configure({"move_speed":6}); value.advance(1.0/60)
	expect(is_equal_approx(value.jump_height,17.5),"changing move speed during jump does not change its already captured source peak")
	expect(restored.value.advance(6.0/60)=="jump" and restored.value.jump_height==0 and restored.value.cell==Vector2i(3,2),"restored source jump completes at original total12 frames")
	value=Motion.new(); value.configure({"move_speed":1}); value.relocate(Vector2i(2,2)); value.begin_move(6)
	for i in 11: value.advance(1.0/60)
	expect(value.pattern==1,"source walking anime_count1.5 exceeds threshold16 on eleventh frame and resets")
	value=Motion.new(); value.configure({"move_speed":5,"step_anime":true})
	for i in 8: value.advance(1.0/60)
	var old=value.pattern; value.advance(1.0/60)
	expect(old==0 and value.pattern==1,"source stationary anime_count1 exceeds strict threshold8 on ninth frame")
	state.map_id=10; state.party=[2]; state.variables["14"]=[2,0]
	var game: Node=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame
	game.reset_event_execution(); game.set_process(false); game._player.set_process(false)
	var env=load("res://runtime/scripts/ScriptSemantics.gd").new(state)
	var player_ref=state.custom_data.data_ref("player",state.map_id)
	env.begin({"kind":"Flash source speed change"})
	env.invoke(player_ref,"speed_change",[3]); env.invoke(player_ref,"step_anime=",[true])
	expect(env.invoke(player_ref,"move_speed",[])==3 and game._player.move_speed==3,"source speed_change updates the live player in direct mode")
	expect(env.finish(null).ok and game._player.move_speed==3 and game._player.step_anime,"source motion options commit together to the formal player")
	# Fatal case is covered in FlashFailureIsolationProbe: motion
	var character: Node=load("res://runtime/scripts/MapCharacter.gd").new(); game._map.add_child(character); character.map_runtime=game._map; character.motion.configure({"through":true}); character.motion.relocate(Vector2i(3,3)); character.set_process(false)
	var route={"repeat":false,"skippable":false,"list":[{"code":15,"parameters":[1]},{"code":27,"parameters":[447]},{"code":0,"parameters":[]}]}
	character.routes.force(route,"Flash wait timing"); character.routes.advance(1.0/60)
	expect(not state.switches.get("447",false) and is_equal_approx(character.routes._wait,1.0/60),"source route wait1 retains first60Hz frame from its two-frame count")
	character.routes.advance(1.0/60)
	expect(state.switches.get("447",false),"source route wait1 resumes its next command on second60Hz frame")
	var autonomous={"repeat":false,"skippable":false,"list":[{"code":27,"parameters":[448]},{"code":0,"parameters":[]}]}
	character.routes.configure(3,6,autonomous,"Flash frequency6"); character.routes.advance(0)
	expect(not state.switches.get("448",false),"source maximum-frequency autonomous movement still requires stop_count greater than zero")
	character.routes.advance(1.0/60)
	expect(state.switches.get("448",false),"frequency6 autonomous route runs on first source update at60Hz")
	state.switches["448"]=false; character.routes.configure(3,5,autonomous,"Flash frequency5")
	for i in 30: character.routes.advance(1.0/60)
	expect(not state.switches.get("448",false),"frequency5 preserves strict stop_count greater than30 rather than greater-or-equal")
	character.routes.advance(1.0/60)
	expect(state.switches.get("448",false),"frequency5 runs on original thirty-first60Hz frame")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MOTION TIMING: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

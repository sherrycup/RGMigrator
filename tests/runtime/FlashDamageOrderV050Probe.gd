extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2
	state.party=[2]; state.variables["14"]=[2,0]; state.switches["3"]=true
	var actor=state.actor(2); actor.set_project_parameter("maxhp",1000); actor.hp=800
	actor.set_project_parameter("patk",12); actor.set_project_parameter("pdef",1); actor.set_project_parameter("agi",10); actor.project_fields.battle_animation=0
	var game=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame; game.reset_event_execution(); game._player.set_process(false); game._dialogue.dismiss()
	var labels=get_first_node_in_group("flash_damage_views"); var custom=state.custom_data; var entry=custom._floor(10).entries["70"]
	entry.fields.maxhp=35; entry.fields.atk=9; entry.fields.pdef=3; entry.fields.agi=10
	custom.gameplay().enemy_input(10,70)
	entry.battle.hp=35; entry.battle.defeated=false; entry.battle.cache=null
	labels.request_refresh()
	for i in 240:
		if not labels.entries.is_empty() and not labels._last_result.is_empty() and labels._last_result.revision==labels._revision: break
		await process_frame
	var prediction=custom.gameplay().predict(10,70)
	expect(prediction!=null and prediction.damage>0 and prediction.outcome=="victory","source battle fixture starts with nonzero predicted damage and victory")
	await screenshot("v050-damage-before.png")
	var dead_frames=0; var wrong_frames=0; var frames=0; var captured=false
	game._map.player_trigger_request=true; game._start_event(game._map.map_data.events["70"].pages[0].list,70); game._map.player_trigger_request=false
	for i in 600:
		game._scheduler.advance(1.0/60.0,false); game._event_ui.pump(game.event_ui_available()); game._map.flush_event_refresh()
		labels._process(0); frames+=1
		var enemy=game._map.event_node(70)
		if entry.battle.hp<=0 and enemy!=null:
			dead_frames+=1
			if labels.entries.any(func(row):return row.node.get_ref()==enemy): wrong_frames+=1
			if labels._label_alive(enemy): wrong_frames+=1
			if not captured:
				await screenshot("v050-damage-dying.png"); captured=true
		if game._dialogue.is_open(): game._dialogue.dismiss()
		if not game._interpreter.running and game._event_checkpoint.is_empty(): break
		await process_frame
	expect(dead_frames>0,"actual common-event chain exposes the lethal-to-erase interval")
	expect(wrong_frames==0,"no zero-damage or stale label is drawn between lethal result and monster disappearance")
	expect(game._map.event_node(70)==null and not game._interpreter.running,"original battle rewards and erase chain finish")
	var undo=state.flash_history.undo()
	expect(undo.ok and state.custom_data._floor(10).entries["70"].battle.hp>0,"event-before undo restores enemy after threaded label updates")
	# Undo replaces custom state; test the current service and map, not old entry references.
	labels.request_refresh()
	for i in 240:
		await process_frame
		if labels.entries.any(func(row):return row.node.get_ref()==game._map.event_node(70)): break
	expect(labels.entries.any(func(row):return row.node.get_ref()==game._map.event_node(70)),"undo publishes damage for the revived enemy")
	await screenshot("v050-damage-restored.png")
	var report={"ok":failures.is_empty(),"checks":checks,"frames":frames,"dying_frames":dead_frames,"wrong_label_frames":wrong_frames,"prediction":prediction,"undo":undo,"worker":labels._last_result,"failures":failures}
	FileAccess.open("res://.godot/v050-damage-order.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free(); await process_frame
	for failure in failures: printerr("FAIL: ",failure)
	print("FLASH V050 DAMAGE ORDER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/"+name)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

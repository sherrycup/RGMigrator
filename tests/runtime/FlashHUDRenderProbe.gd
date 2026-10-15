extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false})
	state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.switches["160"]=true
	state.actor(2).set_project_parameter("maxhp",350); state.actor(2).hp=260; state.actor(2).set_project_parameter("maxsp",45); state.actor(2).sp=32
	state.actor(2).project_fields.equip_skills={"-1":[24],"1":31,"2":32,"3":33}; state.actor(3).project_fields.equip_skills={"-1":[53],"1":31,"2":32}
	state.inventory={"item:2":3,"item:8":1}
	var game: Node=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	game._player.through=true; game._player.move_to(6,6)
	for i in 2:
		game._player.move_straight(6)
		for tick in 4:
			state.flash_followers.advance(1.0/60); game._player.advance_motion(1.0/60)
	var hud: Node=game._flash_hud; hud.set_process(false); hud._process(8.0/60)
	await capture("FlashHUDMain")
	state.variables["14"]=[3,2]; hud.refresh_rows(); await capture("FlashHUDSwapped")
	state.switches["160"]=false; hud.refresh_rows(); await capture("FlashHUDSolo")
	print("FLASH HUD RENDER: PASSED / 3 captures"); quit()
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var status=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/"+name+".png"))
	if status!=OK: printerr("FAIL: render capture ",name); quit(1)

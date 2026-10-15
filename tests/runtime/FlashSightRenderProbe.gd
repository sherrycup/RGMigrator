extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var captures=0
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2,3]; state.variables["14"]=[2,3]; state.map_id=10; state.player_x=5; state.player_y=5; state.switches["3"]=true; state.switches["6"]=true
	var actor=state.actor(2); actor.set_project_parameter("maxhp",100000); actor.hp=100000; actor.set_project_parameter("patk",500); actor.set_project_parameter("pdef",20); actor.set_project_parameter("agi",50)
	var game=load("res://runtime/scripts/Game.gd").new(); root.add_child(game); game._events_enabled=false; game._interpreter.cancel(); game._sync_event_input()
	for i in 8: await process_frame
	if not game._menus.open_flash_sight(): printerr("FAIL: sight entry"); quit(1); return
	var page: Control=game._menus.menu
	await capture("FlashSightFree")
	page.handle_key(KEY_A); await capture("FlashSightEnemyList")
	page.handle_key(KEY_ENTER); await capture("FlashSightEnemy")
	page.handle_key(KEY_ENTER); await capture("FlashSightSkill")
	page.handle_key(KEY_ESCAPE); page.handle_key(KEY_D); await capture("FlashSightActions")
	page.handle_key(KEY_ESCAPE); page.handle_key(KEY_A); await capture("FlashSightItems")
	page.handle_key(KEY_A); await capture("FlashSightBuff")
	game._menus.close_menu(); game.queue_free(); await process_frame
	print("FLASH SIGHT RENDER: PASSED / ",captures," captures"); quit()
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var status=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/"+name+".png"))
	if status!=OK: printerr("FAIL: ",name); quit(1)
	captures+=1

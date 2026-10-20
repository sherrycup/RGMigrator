## 职责：回归验证：捕获灵视列表、敌人信息与详情页面。
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
##   func capture(name: String) -> void
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var captures=0
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2,3]; state.variables["14"]=[2,3]; state.map_id=10; state.player_x=5; state.player_y=5; state.switches["3"]=true; state.switches["6"]=true
	var actor=state.actor(2); actor.set_project_parameter("maxhp",100000); actor.hp=100000; actor.set_project_parameter("patk",500); actor.set_project_parameter("pdef",20); actor.set_project_parameter("agi",50)
	var game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game); game._events_enabled=false; game._interpreter.cancel(); game._sync_event_input()
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

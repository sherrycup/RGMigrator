## 职责：回归验证：捕获闪翼地图 HUD、角色状态与提示显示。
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
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false})
	state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.switches["160"]=true
	state.actor(2).set_project_parameter("maxhp",350); state.actor(2).hp=260; state.actor(2).set_project_parameter("maxsp",45); state.actor(2).sp=32
	state.actor(2).project_fields.equip_skills={"-1":[24],"1":31,"2":32,"3":33}; state.actor(3).project_fields.equip_skills={"-1":[53],"1":31,"2":32}
	state.inventory={"item:2":3,"item:8":1}
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame
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

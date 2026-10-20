## 职责：回归验证：捕获闪翼页面及特殊演出的实际渲染。
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
##   func advance_effects(model: RefCounted) -> void
##     参数 model（RefCounted；必填）：持有业务数据或显示状态的模型。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func capture(name: String) -> void
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func fail(message: String) -> void
##     用途：构造或登记带原因的失败结果。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var captures=0
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false; state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.switches["160"]=true; state.variables["3"]=1; state.variables["18"]=[[],[1,2,3,4,5,6]]; state.variables["2"]=2
	for id in state.party: state.actor(id).set_project_parameter("maxhp",300); state.actor(id).hp=222; state.actor(id).set_project_parameter("maxsp",60); state.actor(id).sp=38
	state.actor(2).learn_skill(31); state.inventory={"weapon:1":2,"item:2":3}
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game)
	for i in 8: await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	var model=state.flash_effects; model._view.get_ref().set_process(false)
	var bars=game.play_flash_effect("set_rect",[]); model.advance(12.0/60); await capture("FlashV046Bars")
	if not bars.ok: fail(str(bars.get("message",""))); return
	game.play_flash_effect("set_rect",[1]); model.advance(12.0/60)
	var frozen=game.play_flash_effect("freeze",[null]); await advance_effects(model); await capture("FlashV046Frozen")
	if not frozen.ok: fail(str(frozen.get("message",""))); return
	game.play_flash_effect("unfreeze",[null]); model.advance(0)
	var blur=game.play_flash_effect("Blur",[true]); await advance_effects(model); await capture("FlashV046Blur")
	if not blur.ok: fail(str(blur.get("message",""))); return
	game.play_flash_effect("Blur",[false]); await advance_effects(model)
	game.play_flash_effect("Voiceover",[true]); await advance_effects(model); await capture("FlashV046Voiceover")
	game.play_flash_effect("Voiceover",[false]); await advance_effects(model)
	var unravel=game.play_flash_effect("Unravel",[])
	model.advance(1.0/60); await process_frame; model.advance(1.0/60); await capture("FlashV046Unravel")
	if not unravel.ok: fail(str(unravel.get("message",""))); return
	model.reset()
	var wake=game.play_flash_effect("wake",[]); model.advance(1.0/60); await capture("FlashV046Wake")
	if not wake.ok: fail(str(wake.get("message",""))); return
	model.reset()
	for name in ["Scene_Flytofloor","Scene_CP","Scene_Debug","Scene_Equip","Scene_Skill"]:
		var opened=game.show_flash_scene(name)
		if not opened.ok: fail(str(opened.get("message",""))); return
		for i in 8: await process_frame
		await capture("FlashV046"+name.trim_prefix("Scene_")); game._menus.close_menu(); await process_frame
	var saves: Script=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd"); saves.directory_override="res://.godot/archive-render-%d" % Time.get_ticks_usec()
	state.flash_archive_snapshot=null; await process_frame; await RenderingServer.frame_post_draw; state.flash_archive_snapshot=root.get_texture().get_image().duplicate()
	var saved=saves.save_slot(1,state)
	if not saved.ok: fail(saved.message); return
	game._menus._open_menu(-1,"save"); var page: Control=game._menus.menu; page.mode="load"; page.refresh()
	for i in 12: await process_frame
	page._process(8.0/60); await capture("FlashV046Archive"); game._menus.close_menu(); await process_frame
	saves.directory_override=""; model.reset(); game.queue_free(); await process_frame
	print("FLASH V046 RENDER: PASSED / ",captures," captures"); quit()
func advance_effects(model: RefCounted) -> void:
	for i in 150:
		model.advance(1.0/60); await process_frame
		if not model.busy(): return
	fail("effect render timed out")
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var status=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/"+name+".png"))
	if status!=OK: fail("render capture failed: "+name); return
	captures+=1
func fail(message: String) -> void: printerr("FAIL: ",message); quit(1)

## 职责：回归验证：比较闪翼保存恢复前后的实际图形输出。
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
##   func freeze_nodes(node: Node) -> void
##     参数 node（Node；必填）：场景节点或语法节点，类型见签名。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func capture(name: String) -> Image
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：Image 类型的对象或值，供调用方继续使用。
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
var checks=0
var failures: Array[String]=[]
var viewport: SubViewport
func _init() -> void:
	root.visible=false
	ProjectSettings.set_setting("rgmigrator/test_preferences_directory","res://.godot/render-preferences")
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640)
	viewport=SubViewport.new(); viewport.size=Vector2i(640,640); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false; state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.switches["160"]=true; state.variables["3"]=1
	state.actor(2).set_project_parameter("maxhp",300); state.actor(2).hp=222; state.actor(3)
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); viewport.add_child(game)
	for i in 8: await process_frame
	game.reset_event_execution(); game._events_enabled=false; freeze_nodes(game)
	var view: Node=state.flash_effects._view.get_ref()
	state.flash_messages.present({"kind":"message","lines":["保存与恢复后的消息画面"]},-1,0,true)
	state.flash_messages.advance(25.0/60); game._dialogue._flash_view._process(0)
	var before=await capture("FlashV047MessageBefore")
	var saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd"); saves.directory_override="res://.godot/render-save-%d" % Time.get_ticks_usec()
	var saved=saves.save_slot(1,state); expect(saved.ok,"save visible hint")
	state.flash_messages.advance(90.0/60); game._dialogue._flash_view._process(0)
	var loaded=saves.load_slot(1,state); expect(loaded.ok,"load visible hint")
	game.set_process(false); game._dialogue._flash_view._process(0)
	var after=await capture("FlashV047MessageAfter")
	expect(before.get_data()==after.get_data(),"GPU message pixels match after restoring model ownership")
	state.flash_messages.reset(); game._dialogue._flash_view._process(0); await process_frame
	var request=game.play_flash_effect("freeze",[null]); state.flash_effects.advance(0)
	for i in 4: await process_frame
	view.sync(); before=await capture("FlashV047FrozenBefore")
	expect(request.ok and state.flash_effects.frozen!=null,"actual Compatibility capture creates frozen image")
	saved=saves.save_slot(2,state); expect(saved.ok,"save actual frozen screenshot")
	state.flash_effects.reset(); loaded=saves.load_slot(2,state); view.sync()
	expect(loaded.ok,"restore actual frozen screenshot")
	after=await capture("FlashV047FrozenAfter")
	expect(before.get_data()==after.get_data(),"GPU frozen pixels match after PNG round trip")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH PERSISTENCE RENDER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func freeze_nodes(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze_nodes(child)
func capture(name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var image=viewport.get_texture().get_image()
	var path="res://.godot/render-output/"+name+".png"; DirAccess.make_dir_recursive_absolute(path.get_base_dir()); image.save_png(path)
	expect(image.get_size()==Vector2i(640,640),"actual640canvas "+name)
	return image
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

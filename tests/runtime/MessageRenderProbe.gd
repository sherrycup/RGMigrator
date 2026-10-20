## 职责：回归验证：捕获闪翼消息框、文本和选择显示。
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
var view: Control
var captures=0
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2]; state.variables["14"]=[2,0]; state.switches["6"]=true
	var game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game); game._events_enabled=false
	view=game._dialogue._flash_view; view.set_process(false)
	for i in 6: await process_frame
	state.flash_messages.reset()
	game._dialogue.show_message(["\\m[艾蕾]\\p[320,420]\\>\\C[8]这是一段闪翼原生对话。","\\C[5]紫色文字 \\FB[T]粗体 \\FB[F]\\FI[T]斜体\\FI[F]","\\I[2] 和 \\G"],-1)
	for i in 100: state.flash_messages.tick()
	await capture("FlashMessageDialogue")
	state.flash_messages.reset()
	game._dialogue.show_event({"kind":"choice","lines":["\\m[艾蕾]\\p[320,420]\\>接下来如何行动？"],"choices":["继续前进","查看周围","稍后决定"],"cancel":5})
	for i in 90: state.flash_messages.tick()
	state.flash_messages.handle_key(KEY_DOWN)
	await capture("FlashMessageChoices")
	state.flash_messages.reset()
	state.flash_temp_fields.unblocking_text="\\>\\mo[1]\\AL\\p[384,536]获得 黄钥匙 +1\\bo[255]\\w[20]\\t[20]"
	state.flash_messages.advance(0)
	for i in 4: state.flash_messages.tick()
	await capture("FlashMessageHint")
	if not game._menus.open_flash_history(): printerr("FAIL: actual history menu entry"); quit(1); return
	var memory: Control=game._menus.menu
	for i in 3: await process_frame
	await capture("FlashMessageHistory")
	memory.handle_key(KEY_TAB); await capture("FlashMessageHintHistory")
	game._menus.close_menu(); game.queue_free(); await process_frame
	print("FLASH MESSAGE RENDER: PASSED / ",captures," captures"); quit()
func capture(name: String) -> void:
	view._process(0); await process_frame; await RenderingServer.frame_post_draw
	var status=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/"+name+".png"))
	if status!=OK: printerr("FAIL: ",name); quit(1)
	captures+=1

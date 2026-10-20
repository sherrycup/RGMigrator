## 职责：回归验证：验证实际图形驱动下的标题输入和游戏启动。
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
##   func press(key: int) -> void
##     用途：模拟一次按键输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
func _init() -> void: call_deferred("run")
func press(key: int) -> void:
	for down in [true,false]:
		var event=InputEventKey.new(); event.keycode=key; event.pressed=down; Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	var title=load("res://scenes/05_Title/Title.tscn").instantiate(); root.add_child(title); current_scene=title
	for i in 20: await process_frame
	press(KEY_ENTER); await process_frame
	var difficulty=title._flash.page=="mode"
	press(KEY_ENTER)
	for i in 300:
		await process_frame
		if current_scene!=null and current_scene.has_method("event_map"):
			if current_scene._dialogue.is_open(): press(KEY_ENTER)
	var game=current_scene
	var ok=difficulty and game!=null and game.has_method("event_map") and state.playing and state._fatal_script_message.is_empty()
	var report={"ok":ok,"difficulty_page":difficulty,"playing":state.playing,"map":state.map_id,"party":state.party,"diagnostics":state.diagnostics,"fatal":state._fatal_script_message}
	if game!=null and game.has_method("event_map"): report.wait=game._interpreter.wait_kind()
	var file=FileAccess.open("res://.godot/v049-startup.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.godot/v049-startup.png")
	print("FLASH V049 STARTUP: ","PASSED" if ok else "FAILED"," / ",JSON.stringify(report))
	quit(0 if ok else 1)

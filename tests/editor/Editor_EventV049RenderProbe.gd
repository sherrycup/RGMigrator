## 职责：回归验证：捕获事件结构层级、脚本内容与多行指令的显示。
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
## 接口说明结束。

extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1180,720); root.content_scale_size=Vector2i(1180,720)
	var docs=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new()
	var data=docs.read("data/database/CommonEvents.json"); var source: Array=data[1].list
	var editor=load("res://addons/rgm_editor/03_Event/Editor_CommandList.gd").new(); root.add_child(editor); editor.position=Vector2(16,16); editor.size=Vector2(1148,688)
	editor.configure(source,docs)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/v049-event-battle.png")
	var condition=-1
	for i in source.size():
		if int(source[i].code)==111 and int(source[i].parameters[0])==12: condition=i; break
	var ok=condition>=0 and editor.Commands.name_for(355)=="脚本" and editor._rows[1].get_description(0)==str(source[1].parameters[0])
	if condition>=0:
		ok=ok and editor._rows[condition].get_text(0).begins_with("如果 脚本条件：") and not editor._rows[condition].get_text(0).contains("event_000003")
		editor._select_block(condition); editor._command_list.ensure_cursor_is_visible()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/v049-event-condition.png")
	ok=ok and editor.draft()==source and docs.dirty_paths().is_empty()
	print("EDITOR V049 EVENT RENDER: ","PASSED" if ok else "FAILED")
	editor.queue_free(); await process_frame; quit(0 if ok else 1)

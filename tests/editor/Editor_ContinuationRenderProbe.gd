## 职责：回归验证：捕获移动路线与脚本续行的实际编辑器列表显示。
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
	var commands=load("res://addons/rgm_editor/03_Event/Editor_Commands.gd")
	var editor: Control=load("res://addons/rgm_editor/03_Event/Editor_CommandList.gd").new(); root.add_child(editor); editor.position=Vector2(16,16); editor.size=Vector2(1148,688)
	var actions=[commands.route_command(12),commands.route_command(12),commands.route_command(14),commands.route_command(15),commands.route_command(45),commands.route_command(0)]
	actions[2].parameters=[2,0]; actions[4].parameters=["$game_variables[1] += 2"]
	var sample=[commands.command(209,0,[-1,{"repeat":false,"skippable":false,"list":actions}])]
	for action in actions.slice(0,-1): sample.append(commands.command(509,0,[action]))
	var script_start=sample.size()
	sample.append(commands.command(355,0,["damage = 20"]))
	sample[-1]._script_binding={"unit_id":"source_fragment","command_count":4,"source_sha256":"display-only"}
	sample.append(commands.command(655,0,["$game_actors[2].hp -= damage"]))
	sample.append(commands.command(655,0,[""]))
	sample.append(commands.command(355,0,["reward += 2"]))
	sample.append(commands.command(0))
	editor.configure(sample,docs)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/continuation-render")
	root.get_texture().get_image().save_png("res://.godot/continuation-render/content.png")
	editor._select_block(script_start+1)
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/continuation-render/selected.png")
	if editor.draft()!=sample or not docs.dirty_paths().is_empty(): printerr("FAIL: display changed event data"); quit(1); return
	print("EDITOR CONTINUATION RENDER: PASSED"); quit()

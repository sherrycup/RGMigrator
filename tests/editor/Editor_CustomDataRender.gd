## 职责：回归验证：捕获货币、初始选项、角色预设及楼层编辑控件。
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
## Render the real controls in a disposable document without saving definitions.
var capture_directory: String
func _init() -> void: call_deferred("run")
func run() -> void:
	capture_directory=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(capture_directory)
	root.gui_embed_subwindows=true
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	var background=ColorRect.new(); background.color=Color(0.13,0.14,0.17); background.size=Vector2(1280,800); root.add_child(background)
	var documents: RefCounted=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new()
	var dialog: Window=load("res://addons/rgm_editor/04_Database/Editor_DatabaseDialog.gd").new(); root.add_child(dialog); dialog.open(documents)
	for i in dialog._categories.item_count:
		if dialog._categories.get_item_metadata(i)=="CustomData": dialog._categories.select(i); dialog._select_category(i); break
	await capture("project-currencies")
	for i in dialog._categories.item_count:
		if dialog._categories.get_item_metadata(i)=="Actors": dialog._categories.select(i); dialog._select_category(i); break
	dialog._load_record(2)
	for i in dialog._form._tabs.get_tab_count():
		if dialog._form._tabs.get_tab_title(i)=="扩展属性": dialog._form._tabs.current_tab=i; break
	await capture("actor-attributes")
	dialog.hide(); dialog.queue_free(); await process_frame
	var state: Node=root.get_node("RuntimeState"); var data: Script=load("res://runtime/scripts/00_Game/RuntimeData.gd")
	state.begin_new_game(data.system(),{"enabled":false}); state.gain_currency("kin",50); state.gain_currency("spar:3",17)
	var menu: Control=load("res://runtime/scripts/08_Menu/Main/MenuScene.gd").new(); root.add_child(menu); await process_frame
	menu.show_currency_details(); await capture("menu-currencies")
	print("CUSTOM DATA RENDER: PASSED"); quit()
func capture(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(capture_directory.path_join(name+".png"))
	if error!=OK: printerr("FAIL: screenshot ",name); quit(1)

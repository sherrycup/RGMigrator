## 职责：回归验证：捕获脚本工作区的列表、来源、生成代码与诊断显示。
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
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var checks=0
var failures: Array[String]=[]
var viewport: SubViewport
func _init() -> void:
	root.visible=false; call_deferred("run")
func run() -> void:
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,900); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport.gui_embed_subwindows=true; root.add_child(viewport)
	var background=ColorRect.new(); background.color=Color(0.13,0.14,0.17); background.size=Vector2(1280,900); viewport.add_child(background)
	var documents: RefCounted=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new()
	var dialog: Window=load("res://addons/rgm_editor/06_Scripts/Editor_ScriptDialog.gd").new(); viewport.add_child(dialog); dialog.open(documents); dialog.size=Vector2i(1200,830); dialog.position=Vector2i(40,35)
	dialog._search.text="event_000001"; dialog._filter(); dialog._tabs.current_tab=0
	await capture("V048ScriptSource")
	expect(dialog._source.size.x>400 and dialog._source.size.y>240,"source editor has usable visible area")
	dialog._tabs.current_tab=2; await capture("V048Generated")
	dialog._search.text="script_0003"; dialog._filter(); await capture("V048ServiceSource")
	expect(not dialog._source.editable and dialog._status.text.contains("专用"),"service-adapted library explains actual edit ownership")
	dialog.hide(); dialog.queue_free(); await process_frame
	var database: Window=load("res://addons/rgm_editor/04_Database/Editor_DatabaseDialog.gd").new(); viewport.add_child(database); database.open(documents); database.position=Vector2i(80,80)
	for i in database._categories.item_count:
		if database._categories.get_item_metadata(i)=="CustomData": database._categories.select(i); database._select_category(i); break
	await capture("V048ProjectCurrencies")
	database._records.select(2); database._select_record(2); await capture("V048ActorPresets")
	database._records.select(3); database._select_record(3); await capture("V048FloorData")
	database.hide(); database.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("EDITOR SCRIPT RENDER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func capture(name: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image=viewport.get_texture().get_image(); var path="res://.godot/render-output/"+name+".png"; DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	expect(image.save_png(path)==OK and image.get_size()==Vector2i(1280,900),"actual Compatibility image "+name)
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

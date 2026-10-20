## 职责：回归验证：捕获闪翼标题、菜单及各功能页面的实际显示。
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
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2,3]; state.variables["14"]=[2,3]; state.variables["5"]=[1,1,0,1,1,0,0,1,1,1]; state.variables["10"]=[1,0,0,0,0]
	state.inventory={"item:2":3,"item:8":1,"item:110":2,"item:111":1,"item:112":1}; state.actor(2).project_fields.blastic=0
	for id in state.party:
		var actor=state.actor(id); actor.set_project_parameter("maxhp",350); actor.hp=260; actor.set_project_parameter("maxsp",45); actor.sp=32
		for skill in [31,32,33,132]: actor.learn_skill(skill)
	var requested=OS.get_cmdline_user_args()
	var pages: Array=requested if not requested.is_empty() else ["SkillPage","BlasticPage","NotePage","ConfigPage","MenuScreen","ItemPage","TitleScreen"]
	var captures=0
	for name in pages:
		var page: Control=load(preload("res://runtime/scripts/10_Support/Scripting/ScriptPaths.gd").runtime(name+".gd")).new(); root.add_child(page)
		for i in 8: await process_frame
		await capture(name)
		captures+=1
		if name=="BlasticPage": page.handle_key(KEY_ENTER); page.candidate_index=1; page.refresh(); await capture(name+"Preview"); captures+=1
		page.queue_free(); await process_frame
	for kind in (["music","merit"] if requested.is_empty() else []):
		var page: Control=load("res://runtime/scripts/05_Title/TitleExtrasPage.gd").new(); page.kind=kind; root.add_child(page)
		for i in 8: await process_frame
		await capture("FlashTitle"+kind)
		captures+=1
		page.queue_free(); await process_frame
	print("FLASH PAGES RENDER: PASSED / ",captures," captures"); quit()
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var status=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/"+name+".png"))
	if status!=OK: printerr("FAIL: render capture ",name); quit(1)

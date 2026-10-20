## 职责：回归验证：捕获闪翼地图系统的区域、楼层和连接预览。
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
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState")
	state.map_id=8; state.player_motion.relocate(Vector2i(4,4))
	var world=state.custom_data.map_system()
	var a=Data.map(8); var b=Data.map(12)
	world.record_transfer({"id":8,"x":int(a.width)-1,"y":5,"width":int(a.width),"height":int(a.height),"facing":6},{"id":12,"x":0,"y":5,"width":int(b.width),"height":int(b.height),"facing":6})
	var screen: Control=load("res://runtime/scripts/08_Menu/MapSystem/MapScreen.gd").new(); root.add_child(screen)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path=ProjectSettings.globalize_path("res://.godot/flash-map-screen.png")
	var status=image.save_png(path)
	print("FLASH MAP RENDER: ","PASSED" if status==OK else "FAILED"," / ",path)
	quit(0 if status==OK else 1)

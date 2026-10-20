## 职责：回归验证：运行数据库交互编写场景并汇总结果。
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
	var original=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new()
	var scenario=load("res://.godot/Editor_DatabaseAuthoringScenario.gd").new()
	var result: Dictionary=await scenario.run(root,original)
	var data=load("res://runtime/scripts/00_Game/RuntimeData.gd")
	var animations: Array=data.database("Animations").duplicate(true)
	while animations.size()<=int(result.animation.id): animations.append(null)
	animations[int(result.animation.id)]=result.animation
	data._cache["res://data/database/Animations.json"]=animations
	load("res://runtime/scripts/04_UI_Common/UIResources.gd")._textures["Graphics/Animations/专用预览.png"]=result.texture
	var resolved=load("res://runtime/scripts/09_Effects/RmxpAnimationData.gd").resolve(int(result.animation.id))
	scenario.expect(resolved.ok and resolved.texture==result.texture,"saved authored animation resolves through runtime asset cache")
	var target=Sprite2D.new(); root.add_child(target)
	var played=load("res://runtime/scripts/09_Effects/RmxpAnimationPlayer.gd").play(root,int(result.animation.id),func() -> CanvasItem: return target)
	scenario.expect(played.ok,"saved animation starts through the formal runtime player")
	if played.ok:
		var player=played.player; player.set_process(false)
		scenario.expect(player._cells[0].visible and player._cells[0].position==Vector2(16,-8) and player._cells[0].region_rect==Rect2(192,0,192,192) and player._cells[0].flip_h,"runtime sprite matches the saved preview cell")
		scenario.expect(player._screen_flash.visible and is_equal_approx(player._screen_color.r,0.2),"saved flash timing applies in the runtime")
		player.advance(0.05); scenario.expect(player.frame_index==1,"runtime advances saved frames at native 20 fps")
		player.stop()
	target.queue_free(); await process_frame
	for failure in scenario.failures: printerr("FAIL: ",failure)
	print("DATABASE AUTHORING TESTS: ","PASSED" if scenario.failures.is_empty() else "FAILED"," / ",scenario.checks," checks")
	quit(0 if scenario.failures.is_empty() else 1)

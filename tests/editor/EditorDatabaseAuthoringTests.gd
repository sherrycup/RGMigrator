extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var original=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var scenario=load("res://.godot/EditorDatabaseAuthoringScenario.gd").new()
	var result: Dictionary=await scenario.run(root,original)
	var data=load("res://runtime/scripts/RuntimeData.gd")
	var animations: Array=data.database("Animations").duplicate(true)
	while animations.size()<=int(result.animation.id): animations.append(null)
	animations[int(result.animation.id)]=result.animation
	data._cache["res://data/database/Animations.json"]=animations
	load("res://runtime/scripts/UIResources.gd")._textures["Graphics/Animations/专用预览.png"]=result.texture
	var resolved=load("res://runtime/scripts/RmxpAnimationData.gd").resolve(int(result.animation.id))
	scenario.expect(resolved.ok and resolved.texture==result.texture,"saved authored animation resolves through runtime asset cache")
	var target=Sprite2D.new(); root.add_child(target)
	var played=load("res://runtime/scripts/RmxpAnimationPlayer.gd").play(root,int(result.animation.id),func() -> CanvasItem: return target)
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

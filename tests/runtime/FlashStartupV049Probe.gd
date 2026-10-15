extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
func _init() -> void: call_deferred("run")
func press(key: int) -> void:
	for down in [true,false]:
		var event=InputEventKey.new(); event.keycode=key; event.pressed=down; Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	var title=load("res://scenes/Title.tscn").instantiate(); root.add_child(title); current_scene=title
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

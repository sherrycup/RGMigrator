extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1180,720); root.content_scale_size=Vector2i(1180,720)
	var docs=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var data=docs.read("data/database/CommonEvents.json"); var source: Array=data[1].list
	var editor=load("res://addons/rgm_editor/EditorCommandList.gd").new(); root.add_child(editor); editor.position=Vector2(16,16); editor.size=Vector2(1148,688)
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

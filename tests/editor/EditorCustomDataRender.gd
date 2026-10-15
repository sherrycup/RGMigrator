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
	var documents: RefCounted=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var dialog: Window=load("res://addons/rgm_editor/EditorDatabaseDialog.gd").new(); root.add_child(dialog); dialog.open(documents)
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
	var state: Node=root.get_node("RuntimeState"); var data: Script=load("res://runtime/scripts/RuntimeData.gd")
	state.begin_new_game(data.system(),{"enabled":false}); state.gain_currency("kin",50); state.gain_currency("spar:3",17)
	var menu: Control=load("res://runtime/scripts/MenuScene.gd").new(); root.add_child(menu); await process_frame
	menu.show_currency_details(); await capture("menu-currencies")
	print("CUSTOM DATA RENDER: PASSED"); quit()
func capture(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(capture_directory.path_join(name+".png"))
	if error!=OK: printerr("FAIL: screenshot ",name); quit(1)

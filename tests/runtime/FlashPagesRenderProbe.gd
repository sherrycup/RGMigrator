extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
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
	var pages: Array=requested if not requested.is_empty() else ["FlashSkillPage","FlashBlasticPage","FlashNotePage","FlashConfigPage","FlashMenuScreen","FlashItemPage","FlashTitleScreen"]
	var captures=0
	for name in pages:
		var page: Control=load("res://runtime/scripts/"+name+".gd").new(); root.add_child(page)
		for i in 8: await process_frame
		await capture(name)
		captures+=1
		if name=="FlashBlasticPage": page.handle_key(KEY_ENTER); page.candidate_index=1; page.refresh(); await capture(name+"Preview"); captures+=1
		page.queue_free(); await process_frame
	for kind in (["music","merit"] if requested.is_empty() else []):
		var page: Control=load("res://runtime/scripts/FlashTitleExtrasPage.gd").new(); page.kind=kind; root.add_child(page)
		for i in 8: await process_frame
		await capture("FlashTitle"+kind)
		captures+=1
		page.queue_free(); await process_frame
	print("FLASH PAGES RENDER: PASSED / ",captures," captures"); quit()
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var status=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/"+name+".png"))
	if status!=OK: printerr("FAIL: render capture ",name); quit(1)

## 职责：回归验证：验证闪翼菜单命令、解锁、子页进入和返回。
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
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var Saves: Script
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	Saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	Saves.directory_override="res://.godot/menu-navigation-%d" % Time.get_ticks_usec()
	var state=root.get_node("RuntimeState")
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10
	var image=Image.create(640,640,false,Image.FORMAT_RGBA8); image.fill(Color.RED)
	state.flash_archive_snapshot=image
	expect(Saves.save_slot(1,state).ok,"write a real Flash graph save with screenshot")
	image=Image.create(640,640,false,Image.FORMAT_RGBA8); image.fill(Color.BLUE); state.flash_archive_snapshot=image
	expect(Saves.save_slot(2,state).ok,"write a second real slot for navigation")
	var info=Saves.slot_info(1); var name=info.archive.players[0].name
	info.archive.players[0].name="caller mutation"
	expect(Saves.slot_info(1).archive.players[0].name==name,"cached summaries do not share mutable containers with UI callers")
	var path=Saves.slot_path(1); var original=FileAccess.get_file_as_string(path)
	var date=str(JSON.parse_string(original).saved_at)
	var changed=original.replace(date,"2222"+date.substr(4))
	expect(changed.length()==original.length(),"same-size rewrite fixture")
	Saves.write_text(path,changed)
	expect(Saves.slot_info(1).saved_at.begins_with("2222"),"content hashes invalidate same-size same-second edits")
	Saves.write_text(path,"["+original.substr(1))
	expect(not Saves.slot_info(1).ok,"same-size corruption invalidates a previously valid summary")
	var gold=state.gold
	expect(not Saves.load_slot(1,state).ok and state.gold==gold,"actual loading rereads and rejects damage without changing state")
	Saves.write_text(path,original)
	expect(Saves.slot_info(1).ok,"restored file can be validated again")
	var title: Control=load("res://runtime/scripts/05_Title/TitleScreen.gd").new(); root.add_child(title)
	await process_frame; title.set_process(false)
	var content=title._artwork; title.handle_key(KEY_DOWN)
	for tick in 16: title._tick()
	expect(title.index==2 and title._artwork==content,"native disabled chapter is selectable and drawing surface is reused")
	title.handle_key(KEY_DOWN)
	for tick in 16: title._tick()
	expect(title.index==3 and title._artwork==content,"native title navigates after16 ticks without rebuilding controls")
	title.index=0; title.handle_key(KEY_ENTER)
	for tick in 16: title._tick()
	title.handle_key(KEY_LEFT)
	for tick in 16: title._tick()
	title.handle_key(KEY_RIGHT)
	for tick in 16: title._tick()
	expect(title.page=="mode" and title.difficulty==1 and title._artwork==content,"difficulty navigation reuses artwork and source values")
	for i in 45: title._tick(); await process_frame
	expect(title._frames.size()<=32 and title._background_pending.size()<=8,"background requests and retained textures are bounded")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/menu-render")
		root.get_texture().get_image().save_png("res://.godot/menu-render/title.png")
	title.queue_free(); await process_frame
	var page: Control=load("res://runtime/scripts/07_Archive/ArchivePage.gd").new(); page.mode="load"; root.add_child(page)
	await process_frame; page.set_process(false); page._process(8.0/60.0)
	expect(page._slots==[1,2] and page.preview_process==8,"archive initializes real existing slots and completes the original eight-tick fade")
	expect(page._preview_image.get_size()==Vector2i(352,352) and page._preview_image.get_pixel(10,10).r8==255 and page._preview_image.get_pixel(9,10).a8==0,"thumbnail dimensions and inset remain unchanged")
	var first_texture=page._preview_texture
	var panel=page._panel
	page.handle_key(KEY_DOWN); page._process(8.0/60.0)
	expect(page.selected==1 and page._preview_image.get_pixel(10,10).b8==255 and page._panel==panel,"navigation selects the blue screenshot while reusing cards and panels")
	page.handle_key(KEY_UP); page._process(8.0/60.0)
	expect(page._preview_texture==first_texture,"revisiting a slot reuses its decoded image and texture")
	var catalog=page._infos[0]
	Saves.write_text(path,"["+original.substr(1))
	page.handle_key(KEY_DOWN); page.handle_key(KEY_UP)
	expect(is_same(page._infos[0],catalog) and page._infos[0].ok,"moving the cursor does not re-read files or reconstruct the save graph")
	expect(not Saves.load_slot(1,state).ok and state.gold==gold,"cached menu eligibility never bypasses actual load validation")
	page.refresh()
	expect(not page._infos[0].ok,"explicit refresh notices external file damage")
	Saves.write_text(path,original); page.refresh()
	if DisplayServer.get_name()!="headless":
		page._process(8.0/60.0); await RenderingServer.frame_post_draw
		var rendered=page._preview_surface.get_texture().get_image()
		expect(rendered.get_pixel(10,10).r8>=254 and rendered.get_pixel(9,10).a8==0,"actual GPU preview reaches the original red endpoint and transparent inset")
		root.get_texture().get_image().save_png("res://.godot/menu-render/archive.png")
		page.handle_key(KEY_DOWN); page._process(2.0/60.0); await RenderingServer.frame_post_draw
		page.handle_key(KEY_UP); page._process(8.0/60.0); await RenderingServer.frame_post_draw
		expect(page._preview_surface.get_texture().get_image().get_pixel(10,10).r8>=254,"interrupted crossfade reaches the selected slot without stale pixels")
	page.queue_free(); await process_frame
	expect(Saves.save_slot(1,state).ok,"overwriting a previously inspected slot succeeds")
	Saves.write_text(path,"broken")
	expect(Saves.slot_info(1).recovered and Saves.read_slot(1).recovered,"summary and real load retain backup recovery")
	var config: Control=load("res://runtime/scripts/05_Title/ConfigPage.gd").new(); root.add_child(config); await process_frame
	content=config._panel_texture; var volume=state.flash_preferences.bgm_volume; config.handle_key(KEY_DOWN)
	expect(config.index==1 and config._panel_texture==content and state.flash_preferences.bgm_volume==volume,"settings cursor reuses original panel texture without modifying settings")
	config.queue_free(); await process_frame
	state.variables["10"]=[1,0,0,0,0]
	var notes: Control=load("res://runtime/scripts/08_Menu/Note/NotePage.gd").new(); root.add_child(notes); await process_frame
	notes.handle_key(KEY_ENTER); content=notes._content; notes.handle_key(KEY_DOWN)
	expect(notes.index==1 and notes._content==content and notes.description=="哈哈哈哈","notes update selection and source description without rebuilding the page")
	notes.queue_free(); await process_frame
	state.inventory["item:1"]=1; state.inventory["item:2"]=1
	var items: Control=load("res://runtime/scripts/08_Menu/Item/ItemPage.gd").new(); root.add_child(items); await process_frame
	items.handle_key(KEY_ENTER); content=items._content; var item_count=state.inventory_count("item",items.selected_id()); items.handle_key(KEY_DOWN)
	expect(items._content==content and state.inventory_count("item",int(items.item_ids[0]))==item_count,"item navigation reuses list controls and does not consume items")
	items.queue_free(); await process_frame
	state.actor(int(state.party[0])).learn_skill(31); state.actor(int(state.party[0])).learn_skill(32)
	var skills: Control=load("res://runtime/scripts/08_Menu/Skill/SkillPage.gd").new(); root.add_child(skills); await process_frame
	content=skills._content; skills.handle_key(KEY_DOWN)
	expect(skills.skill_ids.size()>=2 and skills._content==content and skills._detail_nodes.get("description")!=null,"skill navigation reuses list and detail controls")
	if DisplayServer.get_name()!="headless":
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/menu-render/skills.png")
	skills.queue_free(); await process_frame
	for id in range(50,50+Saves.INFO_CACHE_LIMIT+2): Saves.slot_info(id)
	expect(Saves._info_cache.size()==Saves.INFO_CACHE_LIMIT and not Saves._info_cache.has(ProjectSettings.globalize_path(Saves.slot_path(50))),"summary cache evicts the oldest entry after exceeding its bound")
	state.flash_archive_snapshot=null
	for failure in failures: printerr("FAIL: ",failure)
	print("FLASH MENU NAVIGATION: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

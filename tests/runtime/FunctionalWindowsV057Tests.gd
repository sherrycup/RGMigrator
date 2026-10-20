## 职责：回归验证：通过真实地图、Viewport输入与GPU画面核对0.57功能页、状态读写、裁切和节点复用。
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
const Presets=preload("res://runtime/scripts/08_Menu/Item/ItemPresets.gd")
var checks=0
var failures: Array[String]=[]
var captures=0
var state: Node
var game: Node
var map: Node

func _init() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(640,640)
	root.content_scale_size=Vector2i(640,640)
	state=root.get_node("RuntimeState")
	state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false})
	state.party=[2,3]
	state.variables["14"]=[2,3]
	state.variables["5"]=[1,1,0,1,1,0,0,1,1,1]
	state.variables["10"]=[1,0,0,0,0]
	state.variables["3"]=0
	state.map_id=10
	state.player_x=5
	state.player_y=5
	state.switches["3"]=true
	state.switches["160"]=true
	for id in state.party:
		var actor=state.actor(id)
		actor.set_project_parameter("maxhp",1000)
		actor.hp=500
		actor.set_project_parameter("maxsp",40)
		actor.sp=20
		actor.set_project_parameter("patk",500)
		actor.set_project_parameter("pdef",20)
		actor.set_project_parameter("agi",50)
		for skill in [31,32,33,132]: actor.learn_skill(skill)
	state.actor(2).project_fields.blastic=0
	state.inventory={"item:110":2,"item:111":1,"item:112":1,"item:148":2}
	for id in range(1,25):
		state.inventory["item:"+str(id)]=2
		state.custom_data.values.records["Items:"+str(id)]={"description":"列表裁切检查 @ 钥匙类"}
	state.custom_data.values.records["Items:148"]={"name":"恢复测试","description":"恢复生命和魂量 @ 药品类","occasion":0,"scope":3,"recover_hp":7,"recover_hp_rate":0,"recover_sp":4,"recover_sp_rate":0}
	state.gold=1000
	game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	game._events_enabled=false
	root.add_child(game)
	await process_frame
	game.reset_event_execution()
	game.set_process(false)
	game._player.set_process(false)
	game._player.input_enabled=true
	game._flash_hud.set_process(false)
	game._flash_hud._process(8.0/60)
	map=game.event_map()
	await _items()
	await _skills()
	await _blastic()
	await _notes()
	await _sight()
	await _map_system()
	await _standalone()
	await _shop()
	expect(map==game.event_map() and game._menus.menu==null and game._menus.shop==null and not paused,"all functional returns preserve the same map and release pause/input ownership")
	game.queue_free()
	await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FUNCTION WINDOWS V057: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / ",captures," GPU states")
	quit(0 if failures.is_empty() else 1)

func _items() -> void:
	var page=await _open(0)
	expect(page.page=="flash_items" and _buttons(page)==0,"actual item page uses original drawing regions and no Godot buttons")
	expect(page._content.regions.category.position==Vector2(8,136) and page._content.regions.items.position==Vector2(200,136),"source item category/list enter from left/bottom without doubled parent progress")
	expect(not game._flash_hud.visible_target(),"item mode keeps original player HUD retracted")
	await _capture("item-category")
	_key(KEY_ENTER)
	_step(8)
	var surface=page._content
	var nodes=_nodes(page)
	for i in 17:
		_key(KEY_DOWN)
		if i==0:
			_key(KEY_DOWN)
			expect(page.index==1 and surface.regions.item_rows.cursor_ticks==0,"original eight-tick cursor consumes rapid duplicate navigation without moving twice")
		if i<16: _step(8)
	_step(4)
	expect(page.index==17 and page._content==surface and _nodes(page)==nodes,"long item selection scrolls with stable region and node identities")
	var rows=surface.regions.item_rows
	expect(rows.clip_contents and rows.size==Vector2(288,272) and rows.cursor_to.position.y<rows.size.y,"item list keeps clipped content and cursor inside the scrolling viewport")
	_step(4)
	expect(rows.cursor_ticks==8 and rows.cursor_to.position.y<rows.size.y,"scrolled item cursor settles inside original list viewport")
	await _capture("item-scroll")
	var before=state.inventory.duplicate()
	var id=page.selected_id()
	_key(KEY_A)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	expect(page.stage=="preset" and Presets.slots(state)[1][0]==id and state.inventory==before,"actual preset confirmation writes the selected shared slot without consuming inventory")
	_key(KEY_Q)
	expect(Presets.slots(state)[1]==[0,0],"original Q clears only selected preset")
	_key(KEY_ENTER)
	_step(8)
	await _capture("item-presets")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	var category=page.categories.find("药品类")
	for i in page.categories.size():
		if page.category_index==category: break
		_key(KEY_DOWN)
		_step(8)
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	_step(8)
	expect(page.stage=="target" and state.inventory["item:148"]==2 and state.actor(3).hp==500,"recovery first opens original actor summary without applying an effect")
	expect(game._flash_hud.itembar_process == 0 and not surface.regions.has("presets"),"source recovery target hides the quick-item bar after its own eight-tick exit")
	await _capture("item-target")
	_key(KEY_DOWN)
	_step(8)
	expect(page.target_index==1,"actual recovery cursor selects second original actor")
	_key(KEY_ENTER)
	expect(state.actor(3).hp==507 and state.actor(3).sp==24 and state.actor(2).hp==500 and state.inventory["item:148"]==1,"one actual target confirmation applies original recovery to the selected formal actor once: "+str([page.stage,page.active_item,page.target_index,state.actor(2).hp,state.actor(3).hp,state.actor(3).sp,state.inventory["item:148"]]))
	await _return_map()

func _skills() -> void:
	var page=await _open(8)
	expect(page.page=="flash_skills" and _buttons(page)==0,"actual skill configuration has original category/detail/help artwork without buttons")
	expect(game._flash_hud.visible_target() and game._flash_hud.window_process==8,"skill mode reopens the existing original player HUD instead of constructing another actor state")
	var surface=page._content
	var region=surface.regions.detail
	expect(region.size==Vector2(352,448) and surface.regions.category.position.x==456,"source skill card and right category use separate original windows")
	await _capture("skills")
	var count=page.skill_ids.size()
	for i in count:
		if page.selected_id()==31:break
		_key(KEY_DOWN)
		_step(8)
	_key(KEY_2)
	expect(state.actor(2).project_skill_slot(31)==[true,2],"actual number key configures skill in the existing actor's second turn")
	var configured=state.actor(2).project_fields.equip_skills.duplicate(true)
	_key(KEY_A)
	expect(page.easy and state.actor(2).project_fields.equip_skills==configured,"description mode changes no skill configuration")
	_step(8)
	await _capture("skill-configured")
	_key(KEY_TAB)
	expect(state.party[0]==3 and page.actor().id==3 and page._content==surface,"Tab switches the original party roles and reuses view regions")
	_key(KEY_TAB)
	expect(state.party[0]==2 and page.actor().id==2,"second Tab restores the original role order")
	var description=page._detail_nodes.get("description")
	expect(description!=null and description.clip_contents,"skill rich description remains within its own clipping rectangle")
	root.size=Vector2i(768,640)
	root.content_scale_size=Vector2i(768,640)
	await process_frame
	page.refresh()
	expect(surface.regions.category.position.x==584 and page._content==surface,"768-wide layout reuses the same original category without rebuilding the page")
	await _capture("skills-768")
	root.size=Vector2i(640,640)
	root.content_scale_size=Vector2i(640,640)
	await process_frame
	page.refresh()
	_key(KEY_TAB)
	await _return_map()
	expect(state.party[0]==2,"source skill cancel restores the role order captured on entry")

func _blastic() -> void:
	var page=await _open(4)
	expect(page.page=="flash_blastic" and _buttons(page)==0,"actual crystal page draws original disc, slot atlases and separate windows")
	var surface=page._content
	var original=page.value.duplicate(true)
	var inventory=state.inventory.duplicate()
	await _capture("blastic")
	_key(KEY_ENTER)
	_key(KEY_DOWN)
	_step(8)
	expect(page.choosing and page.value==original and state.inventory==inventory,"crystal candidate preview changes no saved disc or inventory")
	expect(page.preview_rows!=page.value.element and surface.regions.crystal_rows.clip_contents,"candidate uses calculated preview elements and clipped original list")
	var id=int(page.candidates[page.candidate_index])
	await _capture("blastic-preview")
	_key(KEY_ENTER)
	expect(page.choosing and page.value.equip[0][0]==id and state.inventory_count("item",id)==int(inventory.get("item:"+str(id),0))-1,"one original exchange commits the chosen crystal and exact shared inventory")
	_key(KEY_ESCAPE)
	var entered=page._content
	for i in 10:
		_key(KEY_DOWN)
		_step(8)
	expect(page._content==entered,"slot traversal reuses the existing drawing surface")
	_key(KEY_ENTER)
	if page.choosing: _key(KEY_ESCAPE)
	await _return_map()

func _notes() -> void:
	var page=await _open(3)
	expect(page.page=="flash_notes" and _buttons(page)==0,"notes use original bilingual header, lock colors and original independent list")
	_key(KEY_RIGHT)
	_key(KEY_ENTER)
	expect(page.category==1 and not page.selecting and page.entries.is_empty(),"locked note category remains selectable but cannot enter or reveal a description")
	_key(KEY_LEFT)
	_key(KEY_ENTER)
	_key(KEY_DOWN)
	expect(page.selecting and page.index==1 and page.description=="哈哈哈哈","actual note selection uses exact original Storage text")
	var surface=page._content
	_step(8)
	await _capture("notes")
	_key(KEY_DOWN)
	_step(8)
	_key(KEY_UP)
	_step(8)
	expect(page._content==surface and page._text==surface.regions.note_text.rich_label,"note navigation reuses both list region and rich text node")
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	await _return_map()

func _sight() -> void:
	_key(KEY_A)
	var page: Control=game._menus.menu
	expect(page!=null and page.page=="flash_sight" and paused,"actual map A enters source sight with map pause")
	page.set_process(false)
	var before=page.model.focus
	_key(KEY_A)
	expect(page.model.focus==before,"actual coordinator refuses focus input during source eight-tick entry")
	_step(8)
	expect(page.ready_for_input() and _buttons(page)==0,"sight entry completes once with persistent custom windows")
	await _capture("sight-free")
	_key(KEY_A)
	_step(8)
	expect(page.model.focus==1 and page.model.stage=="list" and page._content.regions.focus_rows.clip_contents,"enemy varieties use original cropped horizontal strip")
	await _capture("sight-list")
	_key(KEY_ENTER)
	_step(8)
	for attempt in page.model.enemy_groups().size():
		if page.snapshot.get("skills",[]).size()>1: break
		_key(KEY_ESCAPE)
		_key(KEY_RIGHT)
		_key(KEY_ENTER)
		_step(8)
	expect(not page.snapshot.is_empty() and page._hp_label!=null and page._detail!=null,"target shows actual enemy prediction plus original automatic skill detail")
	await _capture("sight-enemy")
	var snapshot=page.snapshot.duplicate(true)
	var count=page.snapshot.skills.size()
	expect(count>1,"actual source enemy supplies multiple skill entries for automatic-browse verification")
	if count>1:
		page._browse_clock=207
		_step(9)
		expect(page.automatic_index==1 and page.browse_alpha==0,"source 208-tick browse switches data at midpoint of sixteen-tick text fade")
		_step(8)
		expect(page.browse_alpha==1,"source browse text returns to full opacity")
		_key(KEY_Q)
		_step(16)
		expect(page.automatic_index==0 and not page._automatic,"source manual Q stops automatic browsing until another target is selected")
	_key(KEY_ENTER)
	_key(KEY_E)
	_step(8)
	expect(page.model.stage=="skills" and page.snapshot.result==snapshot.result,"skill detail input preserves the existing combat prediction")
	await _capture("sight-skill")
	_key(KEY_ESCAPE)
	_key(KEY_D)
	_step(8)
	var order=page._action_scroll
	expect(order!=null and order.rows==page.snapshot.timeline,"actual D action panel uses the shared original action sequence")
	_key(KEY_DOWN)
	expect(page._action_scroll==order,"action scrolling keeps the original diagram and nodes")
	await _capture("sight-actions")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_key(KEY_A)
	_step(8)
	expect(page.model.focus==2 and page.model.groups.size()==3,"item focus retains exactly original gem/key/recovery categories")
	await _capture("sight-items")
	_key(KEY_A)
	_step(8)
	expect(page.model.focus==3 and page.model.groups.is_empty(),"unfinished source BUFF hook does not invent an effect list")
	await _capture("sight-buff")
	_key(KEY_ESCAPE)
	expect(game._menus.menu==page and paused,"sight keeps the map paused during source exit")
	_step(8)
	expect(game._menus.menu==null and not paused and not state.switches.get("4"),"sight closes once after eight ticks and clears original mask")
	await process_frame

func _map_system() -> void:
	_key(KEY_M)
	var page: Control=game._menus.menu
	expect(page!=null and page.page=="flash_map" and paused and _buttons(page)==0,"actual M opens the original self-drawn map system")
	page.set_process(false)
	expect(page.canvas.clip_contents and page.preview.texture!=null,"map graph clips its canvas and uses an actual map preview")
	var world=page.world
	var layout=world.state().duplicate(true)
	var before=page.preview.texture
	page.refresh()
	expect(page.world==world and page.preview.texture==before and world.state()==layout,"unchanged map selection reuses preview and discovery state")
	await _capture("map-system")
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	expect(game.event_map()==map,"area navigation does not transfer the actual player")
	_key(KEY_ESCAPE)
	expect(game._menus.menu==null and not paused,"original map window returns to the same scene")
	await process_frame

func _standalone() -> void:
	expect(game.show_flash_scene("Scene_Equip",[0,0]).ok,"actual independent equipment entry remains available without enabling empty main branch")
	var page: Control=game._menus.menu
	expect(_buttons(page)==0 and page._content.regions.has("slots"),"six-slot compatibility equipment uses the shared original window/cursor artwork")
	var actor=state.actor(2)
	var original=actor.equipment.duplicate()
	_key(KEY_ENTER)
	expect(page.choosing and actor.equipment==original and not page.preview.is_empty(),"equipment preview computes against the same actor without committing")
	await _capture("equipment")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	expect(not paused and game._menus.menu==null,"independent equipment cancel returns to current map")
	await process_frame
	state.variables["18"]=[[1,2,4,5]]
	state.variables["2"]=1
	expect(game.show_flash_scene("Scene_Flytofloor").ok,"original floor selection entry is available")
	page=game._menus.menu
	expect(_buttons(page)==0 and page.entries==[1,2,4,5],"floor selection draws the original entries with an independent cursor")
	_key(KEY_RIGHT)
	_key(KEY_ENTER)
	expect(state.variables["13"]==2 and state.map_id==10 and not paused,"floor confirmation writes only original variable13 and invents no transfer")
	await process_frame

func _shop() -> void:
	state.flash_temp_fields.shop_type=0
	state.custom_data.values.records["Items:2"].price=3
	var opened=game._menus.open_shop([[0,2]])
	expect(opened.ok and paused,"actual event shop entry owns existing map pause")
	var page: Control=game._menus.shop
	expect(_buttons(page)==0 and page.mode=="commands","flash shop restores original horizontal commands without native quantity buttons")
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	expect(page.mode=="number" and page.quantity==1,"shop selection opens source quantity window")
	_key(KEY_RIGHT)
	var quantity=state.inventory_count("item",2)
	var gold=state.gold
	await _capture("shop-number")
	_key(KEY_ENTER)
	expect(page.mode=="buy" and state.inventory_count("item",2)==quantity+2 and state.gold==gold-6,"one actual quantity confirmation preserves original price and exact formal inventory")
	await _capture("shop-buy")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	expect(game._menus.shop==null and not paused,"normal shop closes through command page")
	state.flash_temp_fields.shop_type=2
	expect(game._menus.open_shop([[0,2]]).ok,"source sell-only shop entry opens")
	page=game._menus.shop
	expect(page.mode=="sell" and _buttons(page)==0,"original shop_type2 goes directly to two-column sale window")
	_key(KEY_DOWN)
	expect(page.selected==2,"original two-column sell page moves a complete row on down")
	_key(KEY_UP)
	await _capture("shop-sell")
	_key(KEY_ESCAPE)
	expect(game._menus.shop==null and not paused,"sell-only cancel returns directly to original map")
	state.flash_temp_fields.shop_type=0
	await process_frame

func _open(command: int) -> Control:
	_key(KEY_ESCAPE)
	var menu: Control=game._menus.menu
	expect(menu!=null and paused and map==game.event_map(),"open original main menu on same map")
	menu.set_process(false)
	_step(8)
	for i in command: _key(KEY_DOWN)
	_key(KEY_ENTER)
	expect(menu.child!=null and not menu.ready_for_input(),"functional page owns eight-tick parent transition")
	_step(8)
	return menu.child

func _return_map() -> void:
	var menu: Control=game._menus.menu
	for i in 5:
		if menu.child==null or menu._child_closing: break
		_key(KEY_ESCAPE)
	_step(8)
	expect(menu.child==null and paused,"functional cancel returns to original main menu with pause retained")
	_key(KEY_ESCAPE)
	_step(8)
	expect(game._menus.menu==null and not paused and game._player.input_enabled,"menu exit resumes the same formal player")
	await process_frame

func _step(count: int) -> void:
	for i in count:
		var menu: Control=game._menus.menu
		if menu!=null:
			if menu.page=="flash_menu": menu._tick()
			elif menu.page=="flash_sight": menu._process(1.0/60)
			var page: Control=menu.child if menu.page=="flash_menu" else menu
			if page!=null and page.get("_content")!=null and page._content.has_method("set_progress"):
				page._content.set_process(false)
				page._content._process(1.0/60)
		game._flash_hud._process(1.0/60)

func _key(code: int) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	root.push_input(event)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	expect(image!=null and image.save_png("res://.godot/v057-"+label+".png")==OK,"actual GPU "+label)
	captures+=1
	if label in ["skills","notes"]:
		var page=game._menus.menu.child
		var text: Control=page._detail_nodes.description if label=="skills" else page._text
		var rect=text.get_global_rect().grow(-3).intersection(Rect2(Vector2.ZERO,Vector2(image.get_size())))
		var bright=0
		for y in range(int(rect.position.y),int(rect.end.y),2):
			for x in range(int(rect.position.x),int(rect.end.x),2):
				var color=image.get_pixel(x,y)
				if color.r>0.65 and color.g>0.65 and color.b>0.65: bright+=1
		expect(bright>10,"window rich text has readable default white glyphs on the actual dark panel")

func _buttons(node: Node) -> int:
	var value=int(node is Button)
	for child in node.get_children(): value+=_buttons(child)
	return value

func _nodes(node: Node) -> int:
	var value=1
	for child in node.get_children(): value+=_nodes(child)
	return value

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

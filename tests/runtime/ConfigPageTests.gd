## 职责：回归验证：验证闪翼设置页、音量和用户偏好的读写。
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
const Config=preload("res://runtime/scripts/08_Menu/Skill/SkillConfig.gd")
const Blastic=preload("res://runtime/scripts/01_Battle/Blastic.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState")
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2,3]; state.variables["14"]=[2,3]; state.map_id=10
	for id in state.party:
		var actor=state.actor(id); actor.set_project_parameter("maxhp",100); actor.hp=100; actor.set_project_parameter("maxsp",30); actor.sp=30
		for skill in [31,32,33,132]: actor.learn_skill(skill)
	var actor=state.actor(2)
	expect(Config.category(Data.record("Skills",132))==0 and Config.category(Data.record("Skills",31))==2 and Config.category({"element_set":[7,11]})==-1,"actual source passive/active classification and unfinished magic category")
	expect(Config.available(state.custom_data,actor,132) and not Config.available(state.custom_data,state.actor(3),132),"original main-passive role tag14 is permitted on main and denied on support")
	var result=Config.set_skill(state,2,132)
	expect(result.ok and state.actor(2).project_skill_slot(132)==[true,-1],"source enter equips learned passive into original slot-1")
	expect(Config.set_skill(state,2,132,3).ok and state.actor(2).project_skill_slot(132)==[true,-1],"numeric turn does not move original passive")
	expect(Config.set_skill(state,2,132).ok and state.actor(2).project_skill_slot(132)==[false,null],"second confirmation removes original passive")
	expect(Config.set_skill(state,2,31).ok and Config.set_skill(state,2,32).ok and Config.set_skill(state,2,33).ok and state.actor(2).project_fields.equip_skills["3"]==33,"ordinary enter fills original first three free turns")
	expect(Config.set_skill(state,2,31,2).ok and state.actor(2).project_fields.equip_skills["2"]==31 and state.actor(2).project_fields.equip_skills["1"]==32,"corrected current-actor turn receiver swaps occupied active turns")
	expect(Config.set_skill(state,2,31,8).ok and state.actor(2).project_fields.equip_skills["2"]==31 and not state.actor(2).project_fields.equip_skills.has("8"),"source duplicate-active no-op into empty turn is preserved")
	# Fatal case is covered in FailureIsolationProbe: support-skill
	var roles=state.variables["14"].duplicate()
	expect(Config.switch_page_actor(state).ok and state.party==[3,2] and state.variables["14"]==roles,"source Tab changes page-party order while preserving role IDs")
	# Fatal battle-down switch coverage: FailureIsolationProbe / down-switch
	state.actor(2).recover_battle_down(); state.actor(3).recover_battle_down(); state.party=[2,3]
	var skill_page: Control=load("res://runtime/scripts/08_Menu/Skill/SkillPage.gd").new(); root.add_child(skill_page); await process_frame
	expect(skill_page.skill_ids.has(132) and skill_page.skill_ids.has(31) and skill_page.actor()==state.actor(2),"actual skill page displays the formal actor learned category list")
	skill_page.index=skill_page.skill_ids.find(132); skill_page.handle_key(KEY_ENTER)
	expect(state.actor(2).project_skill_slot(132)[0],"actual page keyboard changes the formal skill state")
	skill_page.handle_key(KEY_TAB)
	expect(skill_page.actor()==state.actor(3) and state.variables["14"]==roles,"actual page Tab refresh uses installed party actor")
	skill_page.queue_free(); await process_frame; state.party=[2,3]; state.inventory={"item:110":2,"item:112":1}
	state.actor(2).project_fields.blastic=0
	var plate: Control=load("res://runtime/scripts/08_Menu/Orbment/BlasticPage.gd").new(); root.add_child(plate); await process_frame
	expect(plate.value.pos[0].size()==5 and plate.value.pos[1].size()==4 and plate.candidates==[0,110,112],"actual circuit page reads source five/four slots and owned crystals")
	plate.handle_key(KEY_ENTER); plate.candidate_index=plate.candidates.find(110); plate.refresh()
	expect(plate.preview_elements==[3,0,0,0,0] and state.inventory["item:110"]==2 and plate.value.equip[0][0]==null,"actual circuit preview displays source element delta without consuming inventory")
	expect(plate.preview_rows==[[3,0,0,0,0],[0,0,0,0,0]] and plate.value.element==[[0,0,0,0,0],[0,0,0,0,0]],"both source chains are visible and preview changes only selected chain without committing")
	plate.candidate_index=plate.candidates.find(112); plate.refresh()
	expect(not plate.crystal_description.is_empty() and plate.crystal_description==load("res://runtime/scripts/08_Menu/Item/ItemPresets.gd").native_item(112,state).description.get_slice("@",0),"candidate help uses original RPG description rather than external Game_Item wrapper")
	plate.candidate_index=plate.candidates.find(110); plate.refresh()
	plate.handle_key(KEY_ENTER)
	expect(Blastic.record(state.custom_data,0).equip[0][0]==110 and state.inventory["item:110"]==1 and plate.choosing,"source0202 confirms shared transaction and retains the active crystal candidate window")
	plate.slot=1; plate.refresh()
	expect(not plate.candidate_allowed(112),"candidate preview grays duplicate functional crystal without consuming or simulating an exchange")
	# Deliberate invalid script calls: crystal-element / crystal-locked.
	plate.slot=2
	plate.choosing=false; plate.handle_key(KEY_ENTER)
	expect(not plate.choosing and plate.notice.contains("解锁"),"source locked slot does not open candidate UI")
	plate.slot=0; plate.candidate_index=0; result=plate.commit_choice()
	expect(result.ok and state.inventory["item:110"]==2 and Blastic.record(state.custom_data,0).equip[0][0]==null and Blastic.record(state.custom_data,0).element[0]==[0,0,0,0,0],"actual page removes crystal and returns it to the same formal backpack")
	state.custom_data.values.records["Items:110"]={"description":"@普通物品"}; plate.refresh()
	expect(not plate.candidates.has(110) and plate.candidates.has(112),"narrow source110 empty-category repair respects explicit later RPG database category edits")
	state.custom_data.values.records.erase("Items:110")
	plate.queue_free(); await process_frame
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false); await process_frame
	game._events_enabled=false; game.reset_event_execution(); game._player.input_enabled=true
	state.variables.erase("5")
	expect(game._menus.open_menu() and paused and game._menus.menu.page=="flash_menu" and state.variables["5"]==[1,1,0,0,0,0,0,1,0,1],"formal coordinator opens original Flash menu and initializes only source locks")
	var menu=game._menus.menu; menu.set_process(false)
	for tick in 8: menu._tick()
	menu.index=8; menu.activate()
	expect(menu.child==null,"source skill lock prevents opening through command and does not construct a hidden page")
	state.variables["5"][8]=1; menu.activate()
	for tick in 8: menu._tick()
	expect(menu.child!=null and menu.child.page=="flash_skills" and paused,"source unlocked command opens actual shared-state skill page while map stays paused")
	menu.handle_key(KEY_ESCAPE)
	for tick in 8: menu._tick()
	expect(menu.child==null and paused and menu.index==8,"child cancel returns to the original command cursor without unpausing map")
	state.variables["5"][4]=1; menu.index=4; menu.activate()
	for tick in 8: menu._tick()
	expect(menu.child!=null and menu.child.page=="flash_blastic","source unlocked circuit command enters migrated page")
	menu.handle_key(KEY_ESCAPE)
	for tick in 8: menu._tick()
	menu.handle_key(KEY_ESCAPE)
	for tick in 8: menu._tick()
	expect(game._menus.menu==null and not paused and game._player.input_enabled,"last source cancel restores formal game input and pause exactly once")
	game._menus.open_menu(); menu=game._menus.menu; menu.set_process(false)
	for tick in 8: menu._tick()
	menu.index=1; menu.activate()
	for tick in 8: menu._tick()
	expect(menu.child!=null and menu.child.mode=="save" and game.can_save(),"actual nested Flash save page satisfies formal Game.save_slot gate")
	state.save_disabled=true
	expect(not game.can_save(),"original save-disabled flag applies to nested Flash page")
	state.save_disabled=false; menu.back()
	for tick in 8: menu._tick()
	expect(not game.can_save(),"returning to Flash commands cannot save outside the actual slot page")
	game._menus.close_menu()
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH CONFIG PAGES: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

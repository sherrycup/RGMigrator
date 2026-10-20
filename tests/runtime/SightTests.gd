## 职责：回归验证：验证灵视数据模型、对象筛选和页面行为。
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
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2]; state.variables["14"]=[2,0]; state.map_id=10; state.player_x=5; state.player_y=5; state.switches["3"]=true; state.switches["6"]=true
	var actor=state.actor(2); actor.set_project_parameter("maxhp",100000); actor.hp=100000; actor.set_project_parameter("patk",500); actor.set_project_parameter("pdef",20); actor.set_project_parameter("agi",50)
	var game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game); game._events_enabled=false; game._interpreter.cancel(); game._sync_event_input()
	await process_frame
	expect(game._menus.open_flash_sight(),"actual map A-page entry uses Flash source mask state")
	var page: Control=game._menus.menu; var model: RefCounted=page.model
	expect(paused and state.switches.get("4")==true and state.variables.get("13")==128 and not game._player.input_enabled,"sight pauses ordinary map once and uses MASK_ENABLED/OPACITY source IDs")
	expect(model.focus==0 and model.stage=="map" and model.cursor==Vector2i(state.player_x,state.player_y),"source always enters free focus at actual player")
	var groups=model.enemy_groups()
	expect(not groups.is_empty() and groups[0].event_ids.size()>0,"enemy groups use actual original Map010 floor records and live map events")
	page.handle_key(KEY_A)
	expect(model.focus==1 and model.stage=="list" and model.focused_ids==model.groups[0].event_ids,"A source enemy list selects first current variety without changing actor state")
	var minimum=2147483647; var nearest=Vector2i.ZERO
	for event in model.events():
		if event.id not in model.focused_ids: continue
		var distance=absi(event.cell.x-state.player_x)+absi(event.cell.y-state.player_y)
		if distance<minimum: minimum=distance; nearest=event.cell
	var hp_before=actor.hp; var gold_before=state.gold; var inventory_before=state.inventory.duplicate(true)
	page.handle_key(KEY_ENTER)
	expect(model.stage=="targets" and model.cursor==nearest,"source list confirm uses nearest Manhattan same-type target")
	var snapshot=page.snapshot; var event=model.event_at_cursor(); var floor=state.custom_data._floor(10); var battle: Dictionary=floor.entries[str(event.id)].battle
	var patience_before=battle.patience; var enemy_hp=battle.hp
	expect(not snapshot.is_empty() and snapshot.result==state.custom_data.gameplay().predict(10,event.id),"actual enemy panel uses the existing ordinary BattleSystem prediction")
	expect(actor.hp==hp_before and state.gold==gold_before and state.inventory==inventory_before and battle.patience==patience_before and battle.hp==enemy_hp and battle.pending==null,"inspecting battle never consumes HP/rewards/patience or begins combat")
	expect(snapshot.attributes==state.custom_data.gameplay().simulator.enemy_attributes(state.custom_data.gameplay().party_snapshot()[0],{},snapshot.enemy),"display attributes include the same source passive/rage rates as simulation")
	expect(snapshot.skills==snapshot.skill_set.visible_entries and snapshot.timeline==state.custom_data.gameplay().simulator.legacy_log(snapshot.result),"skill list and action sequence come from shared effective skill set and simulator log")
	if not snapshot.skills.is_empty():
		page.handle_key(KEY_ENTER); expect(model.stage=="skills" and page._detail!=null,"Enter locks current target and opens selected skill description")
		var before=model.skill_index; page.handle_key(KEY_UP); expect(model.skill_index==before,"source invalid skill-cell movement stays in place")
		page.handle_key(KEY_ESCAPE); expect(model.stage=="targets","skill cancel returns to current target without changing focus")
	page.handle_key(KEY_D); expect(model.stage=="actions" and page._action_scroll!=null and page._action_scroll.rows==snapshot.timeline,"D opens actual battle action sequence with original role sprites and borders")
	page.handle_key(KEY_ESCAPE); page.handle_key(KEY_ESCAPE)
	expect(model.stage=="list" and model.cursor==Vector2i(state.player_x,state.player_y),"target cancel returns original category list with cursor back at player")
	page.handle_key(KEY_A); expect(model.focus==2 and model.groups.size()==3 and model.groups.map(func(group):return group.name)==["宝石","钥匙","药品"],"source item list retains exactly the three existing literal categories")
	page.handle_key(KEY_A); expect(model.focus==3 and model.stage=="map" and model.groups.is_empty() and model.focused_ids.is_empty(),"unfinished source BUFF hook has no invented list/status filtering")
	page.handle_key(KEY_A); expect(model.focus==0 and model.stage=="map","A wraps BUFF back to free focus")
	var bounds=model.view_bounds(Vector2(640,640)); model.cursor=bounds.position; model.move_cursor(Vector2i.LEFT,Vector2(640,640))
	expect(model.cursor.x==bounds.end.x-1,"free focus wraps within actual visible map bounds")
	state.switches["3"]=false; expect(model.enemy_groups().is_empty(),"source enemy variety list respects display-damage switch3")
	state.switches["3"]=true
	var custom=floor.entries[str(event.id)]; var original_name=state.custom_data.values.system.event_name.duplicate(true)
	state.custom_data.values.system.event_name["10"]={str(event.id):"消失"}
	var dead_code=str(state.custom_data.gameplay().rules.constants.get("DEFAULT_DEAD_CODE","")); state.custom_data.values.system.event_name["10"][str(event.id)]=dead_code
	expect(not model.events().any(func(value):return value.id==event.id),"permanent source death/name override removes inspected target")
	state.custom_data.values.system.event_name=original_name
	model.cursor=event.cell; var description_entry=state.custom_data.values.system.event_name.get("10",{}); state.custom_data.values.system.event_name["10"]=description_entry; description_entry[str(event.id)]="门5"
	expect(not model.description().is_empty(),"corrected source door5 receives the original key-color description")
	state.custom_data.values.system.event_name=original_name
	page.handle_key(KEY_ESCAPE)
	page._process(8.0/60.0)
	expect(game._menus.menu==null and not paused and state.switches.get("4")==false and game._player.input_enabled,"closing sight clears source mask and resumes actual player once")
	await process_frame
	expect(not is_instance_valid(page._marks) if is_instance_valid(page) else true,"closing frees source map markers")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH SIGHT: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

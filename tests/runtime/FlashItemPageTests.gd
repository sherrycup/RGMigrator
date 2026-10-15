extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Presets=preload("res://runtime/scripts/FlashItemPresets.gd")
const Shortcuts=preload("res://runtime/scripts/FlashMapShortcuts.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2,3]; state.variables["14"]=[2,3]; state.map_id=10
	for id in state.party:
		var actor=state.actor(id); actor.set_project_parameter("maxhp",100); actor.hp=10; actor.set_project_parameter("maxsp",20); actor.sp=0
	state.inventory={"item:1":1,"item:2":1,"item:8":1,"item:110":2}; state.variables["4"]="invalid old preset"
	expect(Presets.native_item(1,state).name=="黄钥匙" and Presets.category(Presets.native_item(1,state))=="钥匙类" and Data.record("Items",1).name=="","RPG item page preserves native source name/category while external Game_Item wrapper stays separate")
	expect(Presets.category({"description":"text @ 宝 物 类 "})=="宝物类" and Presets.category({"description":"text"})=="普通物品","source at-sign category removes whitespace and keeps original default")
	expect(Presets.normalize(state).ok and state.variables["4"].__keys.size()==9 and Presets.slots(state)==[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]],"source malformed presets normalize into a saved typed hash with exactly nine initial slots")
	expect(Presets.set_slot(state,9,110).ok and Presets.slots(state)[8]==[110,2],"ninth original quick slot uses actual shared inventory amount")
	var before=JSON.stringify(state.variables["4"])
	expect(not Presets.set_slot(state,10,110).ok and not Presets.set_slot(state,1,999).ok and JSON.stringify(state.variables["4"])==before,"invalid slot and unowned assignment preserve formal presets")
	var notifications: Array=[]; state.state_changed.connect(func():notifications.append(true))
	expect(Presets.normalize(state).ok and notifications.is_empty(),"unchanged HUD synchronization does not create another commit/notification")
	state.inventory["item:110"]=0
	expect(Presets.normalize(state).ok and Presets.slots(state)[8]==[110,0],"depleted preset retains its icon ID and synchronizes zero quantity")
	expect(Presets.set_slot(state,9,0).ok and Presets.slots(state)[8]==[0,0],"source set_null clears only selected preset slot")
	var page: Control=load("res://runtime/scripts/FlashItemPage.gd").new(); root.add_child(page); await process_frame
	expect(page.categories==["钥匙类","宝物类"] and page.item_ids==[1,2],"actual source inventory categories preserve ascending item order and omit unowned/weapon branches")
	page.handle_key(KEY_ENTER); page.handle_key(KEY_A); page.handle_key(KEY_DOWN); page.handle_key(KEY_ENTER)
	expect(page.stage=="preset" and Presets.slots(state)[1]==[1,1] and state.inventory["item:1"]==1,"actual A preset mode assigns selected item with no item consumption")
	page.handle_key(KEY_ESCAPE); page.handle_key(KEY_ESCAPE)
	expect(page.stage=="category","two cancels return from presets through items to categories")
	page.queue_free(); await process_frame
	var game: Node=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false); await process_frame; game._events_enabled=false; game.reset_event_execution(); game._player.input_enabled=true
	# Original recover formula is rate*max without /100. Configure a fixed source
	# record for meaningful UI target tests; source algorithm is not replaced.
	state.inventory["item:148"]=2; state.custom_data.values.records["Items:148"]={"name":"recover fixture","description":"恢复 @ 药品类","occasion":0,"scope":3,"recover_hp":7,"recover_hp_rate":0,"recover_sp":4,"recover_sp_rate":0}
	page=load("res://runtime/scripts/FlashItemPage.gd").new(); root.add_child(page); await process_frame
	page.category_index=page.categories.find("药品类"); page.refresh(); page.handle_key(KEY_ENTER); page.handle_key(KEY_ENTER)
	expect(page.stage=="target" and state.inventory["item:148"]==2 and state.actor(2).hp==10,"actual usable recovery confirmation opens actor target without early consumption")
	page.handle_key(KEY_DOWN); page.handle_key(KEY_ENTER)
	expect(state.actor(3).hp==17 and state.actor(3).sp==4 and state.actor(2).hp==10 and state.inventory["item:148"]==1,"actual target page uses source recovery transaction on selected formal actor: "+JSON.stringify([page.notice,state.actor(3).hp,state.actor(3).sp,state.inventory["item:148"]]))
	page.handle_key(KEY_ESCAPE); page.handle_key(KEY_A); page.handle_key(KEY_ENTER)
	expect(Presets.slots(state)[0]==[148,1],"actual source recovery item can be assigned to quick slot")
	expect(Shortcuts.use_slot(state,1).ok and state.actor(2).hp==17 and state.actor(2).sp==4 and state.inventory["item:148"]==0,"source quick item acts on party[0] and consumes exactly one shared item")
	Presets.set_slot(state,2,8); before=JSON.stringify([state.inventory,state.common_event_reservation])
	expect(Shortcuts.use_slot(state,2).ok and before==JSON.stringify([state.inventory,state.common_event_reservation]),"original tool preset key does not invent a CE9 dispatch absent from item_use")
	page.queue_free(); await process_frame
	expect(game._flash_hud!=null and game._flash_hud.slots==Presets.slots(state),"actual game creates shared-state HUD and retained zero-quantity quick slots")
	state.inventory["item:148"]=1; state.actor(2).hp=10
	var key=InputEventKey.new(); key.pressed=true; key.keycode=KEY_1; game._menus._input(key); await process_frame
	expect(state.actor(2).hp==17 and state.inventory["item:148"]==0 and game._flash_hud.slots[0]==[148,0],"actual coordinator shortcut updates HUD after transaction without nested commit or duplicated effect")
	game._menus.open_menu(); key.keycode=KEY_2; var quantity=state.inventory["item:8"]; game._menus._input(key)
	expect(state.inventory["item:8"]==quantity and paused,"menu ownership prevents map quick-key input while paused")
	game._menus.close_menu(); game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH ITEM PAGE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

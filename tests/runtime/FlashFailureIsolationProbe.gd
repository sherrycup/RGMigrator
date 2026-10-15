extends SceneTree
## Each deliberate failure runs in a separate process under the real fatal policy.
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var mode="actor"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode=arg.trim_prefix("--case=")
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]
	state.variables["3"]=1; state.variables["18"]=[[],[2,4,4]]; state.variables["13"]=4; state.variables["12"]=9
	state.actor(2); state.actor(3)
	state.actor(2).set_project_parameter("maxhp",100); state.actor(2).hp=100
	var game=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame
	game.reset_event_execution(); game._player.set_process(false)
	if mode in ["missing-scan","missing-noise"]:
		# Fault injection only: the production audio fix restored both original MP3s.
		state.flash_effects.test_capture=Image.create(640,640,false,Image.FORMAT_RGBA8)
		var index=Data.asset_index().duplicate(true)
		for key in index.keys():
			if str(key).to_lower().begins_with("audio/se/") and str(key).contains("静电声"): index.erase(key)
		Data._cache["res://data/asset_index.json"]=index
	var result={"ok":true}; var retained=true
	match mode:
		"damage-worker":
			var labels: Node=game.get_tree().get_first_node_in_group("flash_damage_views")
			labels.set_process(false); state.switches["3"]=true
			state.custom_data.gameplay().simulator.skills={}; labels.request_refresh()
			for frame in 240:
				labels._process(0)
				if not state._fatal_script_message.is_empty(): break
				await process_frame
			result={"ok":false,"message":state._fatal_script_message}
			retained=state._fatal_script_message.contains("显伤计算失败")
		"actor":
			result=Scripts.call_transaction(state,{"source":"v049 actor failure"},func(env):
				env.invoke(env._custom.data_ref("actor",2),"patk=",[35]); env.invoke(env._custom.data_ref("actor",2),"hp=",[75]); return env.fail("deliberate actor failure"))
			retained=state.actor(2).get_parameter("patk")==35 and state.actor(2).hp==75
		"motion":
			result=Scripts.call_transaction(state,{"source":"v049 motion failure"},func(env):
				var player=env._custom.data_ref("player",10); env.invoke(player,"speed_change",[6]); return env.invoke(player,"opacity=",[256]))
			retained=game._player.move_speed==6 and game._player.opacity==255
		"effect":
			result=Scripts.call_transaction(state,{"source":"v049 effect failure"},func(env):
				load("res://runtime/scripts/FlashScreenEffects.gd").stage(env._custom,"set_rect",[]); env.index_set({"__state_table":"variable"},333,9); return env.fail("deliberate effect failure"))
			retained=state.variables.get("333")==9
		"keyboard":
			state.flash_keyboard.input_provider=func(_vk): return true
			result=Scripts.call_transaction(state,{"source":"v049 keyboard failure"},func(env):
				env.invoke(env._custom.named("Kboard"),"trigger?",[65]); env.index_set({"__state_table":"variable"},93,27); return env.fail("deliberate keyboard failure"))
			retained=state.variables.get("93")==27
		"floor","fractional-floor","character":
			var actions=load("res://runtime/scripts/FlashActions.gd")
			if mode=="character": result=actions.choose_character(state,4); retained=state.variables["12"]==9
			else: result=actions.choose_floor(state,1.5 if mode=="fractional-floor" else 3); retained=state.variables["13"]==4
		"support-skill","down-switch":
			var config=load("res://runtime/scripts/FlashSkillConfig.gd")
			state.actor(3).learn_skill(132)
			if mode=="support-skill": result=config.set_skill(state,3,132)
			else:
				state.actor(2).inflict_battle_down(2); state.actor(3).inflict_battle_down(2); result=config.switch_page_actor(state)
		"debug":
			game.show_flash_scene("Scene_Debug"); var page=game._menus.menu; page.editing=true
			for i in page.groups.size():
				if page.groups[i].kind=="variable" and page.groups[i].first==11: page.group=i; break
			page.index=3; result=page.change(1); retained=state.variables["14"]==[2,3]
		"deputy": result=Scripts.new_object("Game_Deputy",[1],state)
		"unsafe-object": result=Scripts.new_object("Game_Object",["item",1,"outside.exdata","../"],state)
		"gem-id": result=Scripts.call_method(state.custom_data.data_ref("gameplay_module",0,"Storage"),"gem",[7],state)
		"gem-expression":
			game.event_map().map_data.events["70"].name="宝石<patk:Game_System.new>"
			var unit=Data.read_json("res://data/script_units.json",{}).units.event_000087
			result=Scripts.execute_bound({"unit_id":"event_000087","source_sha256":unit.source_sha256},unit.source,state,{"map_id":10,"event_id":70,"fields":{},"index":0})
		"window":
			result=Scripts.call_transaction(state,{"source":"v049 window failure"},func(env):
				env.invoke(env._custom.named("WindowScaler"),"resize",[0]); env.index_set({"__state_table":"variable"},93,27); return env.fail("deliberate window failure"))
			retained=state.variables.get("93")==27
		"shop-catalog":
			state.gold=100; state.inventory["item:4"]=0; state.custom_data.values.records["Items:4"]={"price":10}
			Data._cache["res://data/flash_gameplay.json"]=Data.read_json("res://data/flash_gameplay.json",{}).duplicate(true)
			Data._cache["res://data/flash_gameplay.json"].skills={}
			state.custom_data.gameplay().simulator.skills={}
			for entry in state.custom_data._floor(10).entries.values():
				if entry.has("battle"): entry.battle.cache=null
			result=load("res://runtime/scripts/ShopService.gd").buy(state,[[0,4]],"item",4,1)
		"shop-quantity","shop-zero","shop-buy-only","shop-sell-only":
			var shop=load("res://runtime/scripts/ShopService.gd"); state.gold=100
			state.custom_data.values.records["Items:2"]={"price":0 if mode=="shop-zero" else 3}; state.inventory["item:2"]=1
			state.flash_temp_fields.shop_type=1 if mode=="shop-buy-only" else 2 if mode=="shop-sell-only" else 0
			if mode in ["shop-zero","shop-buy-only"]: result=shop.sell(state,"item",2,1)
			else: result=shop.buy(state,[[0,2]],"item",2,99 if mode=="shop-quantity" else 1)
			retained=state.gold==100 and state.inventory_count("item",2)==1
		"crystal-duplicate","crystal-element","crystal-locked":
			var actions=load("res://runtime/scripts/FlashActions.gd")
			state.inventory={"item:71":2,"item:74":1}
			if mode=="crystal-duplicate":
				actions.exchange_crystal(state,0,0,71); result=actions.exchange_crystal(state,0,5,71)
			else: result=actions.exchange_crystal(state,0,2 if mode=="crystal-locked" else 1,71)
		"missing-scan": result=game.play_flash_effect("Scanline",[1])
		"missing-noise": result=game.play_flash_effect("Flashback",[])
		"invalid-effect": result=game.play_flash_effect("Voiceover",["true"])
		_: printerr("Unknown isolated failure: ",mode); quit(2); return
	var ok=not result.ok and retained and paused and not state._fatal_script_message.is_empty()
	if mode in ["missing-scan","missing-noise"]: ok=ok and str(result.get("message","")).contains("SE缺失")
	var report={"case":mode,"ok":ok,"retained":retained,"fatal":state._fatal_script_message,"result":result.get("message",""),"gold":state.gold,"handbook":state.inventory_count("item",4)}
	print("V049 FAILURE CHECK: ",JSON.stringify(report))
	if not ok: quit(2); return
	# Headless production mode exits1 on its deferred fatal handler.
	await process_frame

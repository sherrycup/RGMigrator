extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Graph=preload("res://runtime/scripts/SaveGraph.gd")
var Codec: Script
var Saves: Script
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Codec=load("res://runtime/scripts/SaveCodec.gd"); Saves=load("res://runtime/scripts/SaveService.gd")
	var state=root.get_node("RuntimeState")
	Saves.directory_override="res://.godot/persistence-%d" % Time.get_ticks_usec()
	preload("res://runtime/scripts/FlashPreferences.gd").directory_override=Saves.directory_override
	state.flash_preferences.vars.resize(101); state.flash_preferences.vars.fill(0); state.flash_preferences.music_lock=[]
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.actor(2); state.actor(3)
	var game: Node=load("res://runtime/scripts/Game.gd").new(); root.add_child(game); await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	var shared=[]; var cycle={"shared":shared,"large":9223372036854775806}; cycle.self=cycle; shared.append(cycle)
	var encoded=Graph.encode({"one":cycle,"two":cycle,"mixed":{4:"integer", "4":"string"}})
	var decoded=Graph.decode(JSON.parse_string(JSON.stringify(encoded.value)))
	expect(decoded.ok and is_same(decoded.value.one,decoded.value.two) and is_same(decoded.value.one.self,decoded.value.one),"disk graph preserves shared identity and cycles")
	expect(decoded.value.one.large==9223372036854775806 and decoded.value.mixed[4]=="integer" and decoded.value.mixed["4"]=="string","exact int64 and typed dictionary keys survive JSON")
	var invalid=encoded.value.duplicate(true); invalid.root=["ref",999999]
	var resource=Node.new(); var rejected=Graph.encode(resource); resource.free()
	expect(not Graph.decode(invalid).ok and not rejected.ok,"invalid references and runtime resources reject before installation")
	state.variables["80"]=cycle; state.variables["81"]=cycle
	Scripts.script_data(state); state.script_session.globals["$persisted"]=cycle
	var snapshot=Codec.capture(state); var prepared=Codec.prepare(snapshot)
	expect(prepared.ok,"full formal state validates with cyclic script object: "+str(prepared.get("message","")))
	var saved=Saves.save_slot(6,state)
	expect(saved.ok,"production save writes graph payload: "+str(saved.get("message","")))
	state.variables["80"]=null
	var loaded=Saves.load_slot(6,state)
	expect(loaded.ok and is_same(state.variables["80"],state.variables["81"]) and is_same(state.variables["80"],state.script_session.globals["$persisted"]),"slot load preserves links across variables and globals")
	var transaction=Scripts.call_transaction(state,{"source":"graph mutation"},func(env): env._variables["80"].shared.append("committed"); return true)
	expect(transaction.ok and state.variables["81"].shared.back()=="committed" and is_same(state.variables["80"],state.script_session.globals["$persisted"]),"transaction commit preserves cross-root graph identity")
	var prior=state.variables["80"]
	var direct=Scripts.call_transaction(state,{"source":"direct graph"},func(env): env._variables["80"].shared.append("direct"); return is_same(prior,env._variables["80"]))
	expect(direct.ok and direct.value and is_same(prior,state.variables["80"]) and state.variables["81"].shared.back()=="direct","direct execution retains original graph identity without replacing live aliases")
	var clone=Scripts.call_transaction(state,{"source":"DeepClone"},func(env): return env.invoke(env._custom.named("Utils"),"DeepClone",[env._variables["80"]]))
	expect(clone.ok and not is_same(clone.value,state.variables["80"]) and is_same(clone.value.self,clone.value),"Utils.DeepClone produces detached cyclic graph")
	var catalog=preload("res://runtime/scripts/FlashObjectCatalog.gd")
	var first=Scripts.new_object("Game_Item",[1],state); state.variables["82"]=first.value
	var second=Scripts.new_object("Game_Item",[1],state); state.variables["83"]=second.value
	var identities=Scripts.call_transaction(state,{"source":"object identity"},func(env): return env.binary("==",env._variables["82"],env._variables["83"]))
	expect(identities.ok and not identities.value,"separate source constructors keep distinct object identity")
	var cached=catalog.equipment_ref(state.custom_data,0,1); state.variables["84"]=cached
	expect(is_same(cached,catalog.equipment_ref(state.custom_data,0,1)),"equipment lookup preserves original cached object identity")
	cached.fields.setting["patk"]=123
	var objects_saved=Saves.save_slot(13,state); var objects_loaded=Saves.load_slot(13,state)
	expect(objects_saved.ok and objects_loaded.ok and is_same(state.variables["84"],state.custom_data.values.objects.equipment["Weapons:1"]),"equipment cache and variable aliases restore as the same object")
	expect(catalog.value(state.custom_data,"Weapons",1,"patk")==123,"owned mutable wrapper settings survive save and load")
	for key in ["82","83","84"]: state.variables.erase(key)
	var prefs=state.flash_preferences
	expect(prefs.set_volume("bgm",7) and prefs.storage_error.is_empty(),"runtime preference change is saved atomically")
	var another=preload("res://runtime/scripts/FlashPreferences.gd").new(state)
	expect(another.bgm_volume==7,"new preferences instance reads saved app configuration")
	var global_result=Scripts.call_transaction(state,{"source":"global preference"},func(env): return env.index_set(env.read_name("$global_variables",{},env.root_receiver(),"Object"),21,["chapter-unlocked"]))
	expect(global_result.ok and preload("res://runtime/scripts/FlashPreferences.gd").new(state).vars[21]==["chapter-unlocked"],"source global-variable write persists achievement data")
	var bad_pref=prefs.set_volume("bgm",99)
	expect(not bad_pref and prefs.bgm_volume==7,"native volume control retains its original range rule")
	state.variables.erase("80"); state.variables.erase("81"); state.script_session.globals.erase("$persisted")
	var effect=game.play_flash_effect("set_rect",[]); state.flash_effects.advance(4.0/60)
	var tick=state.flash_effects.active.tick; var amount=state.flash_effects.rect_amount
	var hint=state.flash_messages.present({"kind":"message","lines":["persistent hint"]},-1,0,true)
	state.flash_messages.advance(12.0/60)
	var cursor=state.flash_messages.boxes[0].model.cursor
	state.flash_followers.accept_action(6,[])
	var live=Saves.save_slot(7,state)
	expect(live.ok,"active hint, screen effect and follower history save together: "+str(live.get("message","")))
	if live.ok:
		state.flash_effects.advance(8.0/60); state.flash_messages.reset()
		var result=Saves.load_slot(7,state)
		expect(result.ok and state.flash_effects.active.tick==tick and state.flash_effects.rect_amount==amount,"active animation restores exact progress")
		expect(state.flash_messages.boxes.size()==1 and state.flash_messages.boxes[0].model.cursor==cursor and state.flash_followers.move_list[0].type==6,"hint cursor and follower action queue restore")
		state.flash_effects.advance(8.0/60)
		expect(not state.flash_effects.busy() and state.flash_effects.rect_amount==74,"restored effect continues to original endpoint")
	state.flash_effects.reset(); state.flash_messages.reset(); state.variables["25"]=0
	state.gold=10; var record=state.flash_history.record(true); state.gold=99
	expect(record.ok and state.variables["25"]==1,"automatic snapshot increments original progress variable after durable write")
	var undone=state.flash_history.undo()
	expect(undone.ok and state.gold==10 and state.variables["25"]==0 and prefs.bgm_volume==7,"undo restores progress and leaves app preferences intact")
	expect(not state.flash_history.undo().ok,"undo rejects missing prior history")
	expect(state.flash_history.eligible("怪物12") and not state.flash_history.eligible("血瓶50"),"source automatic-record category flags are preserved")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH PERSISTENCE TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

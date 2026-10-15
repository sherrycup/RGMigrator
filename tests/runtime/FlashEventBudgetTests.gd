extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Graph=preload("res://runtime/scripts/SaveGraph.gd")
const Semantics=preload("res://runtime/scripts/ScriptSemantics.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
const Custom=preload("res://runtime/scripts/CustomDataState.gd")
class BudgetMap extends Node:
	signal map_changed(id: int)
	signal events_changed
	var generation=0
	func event_node(_id: int) -> Node: return null
	func flush_event_refresh() -> void: pass
	func event_contexts() -> Array:
		return [{"event_id":1,"page":1,"trigger":4,"commands":[{"code":121,"indent":0,"parameters":[191,191,0]},{"code":106,"indent":0,"parameters":[100]},{"code":0,"indent":0,"parameters":[]}]}]
class SlowMain extends RefCounted:
	var passes=0
	var budget_owner: Node
	var running=true
	var managed=true
	var time_budget_usec=4000
	func cancel() -> void: running=false
	func advance(_delta: float,_budget: int=256) -> int:
		if Time.get_ticks_usec()>=budget_owner.event_frame_deadline(time_budget_usec): return 0
		# Stand in for one indivisible script command exceeding the frame target.
		OS.delay_usec(6000); passes+=1
		return 1
var checks=0
var failures: Array[String]=[]
var pulses=0
func _init() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func pulse() -> bool:
	pulses+=1
	if pulses%100==0: await process_frame
	return true
func cancelled() -> bool: return false
func run() -> void:
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	var saves=load("res://runtime/scripts/SaveService.gd")
	saves.directory_override="res://.godot/event-budget-%d" % Time.get_ticks_usec()
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2
	state.party=[2,3]; state.variables["14"]=[2,3]; state.actor(2); state.actor(3)
	var game=load("res://runtime/scripts/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame; game.reset_event_execution(); game._player.set_process(false); game._player.input_enabled=true
	game._event_ui.cancel_all(); game._dialogue.dismiss()
	await graph_cases()
	program_cases()
	definition_cases()
	var animations=load("res://runtime/scripts/RmxpAnimationData.gd")
	expect(animations._resolved.has(21),"source CE14 level-up animation is ready before the first battle requests it")
	var first_animation=animations.resolve(21); var again=animations.resolve(21)
	expect(first_animation.ok and again.ok and is_same(first_animation.frames,again.frames),"immutable animation data is compiled once for validation and playback")
	var overlay=Data.source_record("Animations",21).duplicate(true); overlay.frame_max=0
	Data._test_records["Animations:21"]=overlay; Data.testing_enabled=true
	expect(not animations.resolve(21).ok,"animation cache never bypasses a changed testing definition")
	Data.testing_enabled=false; Data._test_records.erase("Animations:21")
	expect(animations.resolve(21).ok,"original animation remains usable after a testing overlay is removed")
	var actor=state.actor(2); var actor_saved=actor.persistent_data(); var copied=actor.detached_copy()
	expect(copied.ok and Custom.same_value(actor_saved,copied.actor.persistent_data()),"actor copy preserves all current persisted fields")
	expect(copied.actor.id==actor.id and copied.actor.final_level==actor.final_level and copied.actor.next_level_experience()==actor.next_level_experience(),"actor copy retains identity metadata and source experience thresholds")
	expect(is_same(copied.actor.project_rules,actor.project_rules) and not is_same(copied.actor.project_fields,actor.project_fields),"actor rules stay shared and mutable fields stay detached")
	copied.actor.project_fields.tp_plus.maxhp+=7; copied.actor.state_ids.append(999)
	expect(Custom.same_value(actor_saved,actor.persistent_data()),"mutating a copied actor never changes the live actor")
	var codec=load("res://runtime/scripts/SaveCodec.gd"); var preparation=load("res://runtime/scripts/SavePreparation.gd")
	var snapshot=codec.capture(state); var event=game._map.event_node(70)
	var character=snapshot.event_state.events["70"].character
	expect(is_same(snapshot.event_state.events["70"].position,character.motion.cell),"fresh event capture keeps its position/cell alias")
	expect(not is_same(character.motion.options,event.motion.options) and not is_same(character.routes.route,event.routes._route),"fresh native character options and route trees remain detached")
	var before=Graph.clone(snapshot); var ordinary=codec.prepare(snapshot)
	expect(ordinary.ok and Custom.same_value(snapshot,before) and not is_same(ordinary.state,snapshot),"ordinary preparation leaves caller data unchanged")
	var common_source=Data.source_record("CommonEvents",23).duplicate(true)
	var another=codec.prepare(snapshot,state.custom_data)
	expect(another.ok and Custom.same_value(common_source,Data.source_record("CommonEvents",23)),"save preparation reads shared common-event definitions without mutating their original commands")
	var cooperative=await preparation.prepare_cooperatively(snapshot,state.custom_data,false,pulse)
	expect(cooperative.ok and pulses>100 and Custom.same_value(cooperative.state,ordinary.state),"cooperative preparation matches canonical normalized state across real frame boundaries")
	expect(Custom.same_value(snapshot,before),"cooperative non-owned preparation also leaves caller data unchanged")
	var invalids: Array=[]
	var invalid=Graph.clone(snapshot); invalid.player_direction=1; invalids.append(invalid)
	invalid=Graph.clone(snapshot); invalid.custom_data.party.hatred="bad"; invalids.append(invalid)
	invalid=Graph.clone(snapshot); invalid.variables["100"]=NAN; invalids.append(invalid)
	invalid=Graph.clone(snapshot); invalid.event_state.events["70"].character.motion.options.opacity=999; invalids.append(invalid)
	invalid=Graph.clone(snapshot); invalid.script_data.globals["$invalid"]={"__ruby_class":"MissingClass","fields":{}}; invalids.append(invalid)
	for value in invalids:
		var sync=codec.prepare(value); var sliced=await preparation.prepare_cooperatively(value,state.custom_data,false,pulse)
		expect(not sync.ok and not sliced.ok,"both validators reject malformed graph, actor, event or custom state")
	var stopped=await preparation.prepare_cooperatively(snapshot,state.custom_data,false,cancelled)
	expect(not stopped.ok,"cancelled validation cannot publish a prepared save")
	state.flash_history.reset(); state.variables["25"]=0; state.variables["600"]="before"; state.switches.erase("190")
	var commands=[{"code":121,"indent":0,"parameters":[190,190,0]},{"code":0,"indent":0,"parameters":[]}]
	game._map.player_trigger_request=true; game._start_event(commands,70); game._map.player_trigger_request=false
	expect(not game._event_checkpoint.is_empty() and not state.switches.get("190",false) and state.variables["25"]==0,"foreground event waits for its fully checked event-before record")
	expect(state.map_time_paused() and not game._player.input_enabled and not game.event_save_reason().is_empty() and not game._menus.can_open(),"preparation pauses map work and gates input, menus and explicit saves")
	await drain(game)
	expect(game._event_checkpoint.is_empty() and state.switches.get("190",false) and state.variables["25"]==1,"validated checkpoint starts the foreground event once and reserves one serial")
	state.variables["600"]="after"; var undo=state.flash_history.undo()
	expect(undo.ok and state.variables["600"]=="before" and not state.switches.get("190",false),"pending or written record restores the actual event-before values")
	game.reset_event_execution(); game._player.input_enabled=true; state.variables["25"]=0
	game._map.player_trigger_request=true; game._start_event(commands,70); game._map.player_trigger_request=false
	for frame in 40:
		if not state.flash_history._validators.is_empty(): break
		await process_frame
	expect(not state.flash_history._validators.is_empty() and not state.switches.get("190",false),"graph worker validates detached snapshot before any foreground event change")
	state.flash_history.reset()
	for frame in 40: await process_frame
	expect(game._event_checkpoint.is_empty() and state.variables["25"]==0 and not state.switches.get("190",false),"history reset also releases the pending foreground request without executing it")
	game._player.input_enabled=true
	game._map.player_trigger_request=true; game._start_event(commands,70); game._map.player_trigger_request=false
	game.reset_event_execution()
	for frame in 40: await process_frame
	expect(state.variables["25"]==0 and not state.switches.get("190",false) and not state.flash_history._busy,"reset cancels preparation without publishing a stale serial or event")
	game._player.input_enabled=true; game._map.player_trigger_request=true; game._start_event(commands,70); game._map.player_trigger_request=false
	await drain(game)
	expect(state.variables["25"]==1 and state.switches.get("190",false),"a new request works after cancellation")
	state.flash_history.flush_pending(); game.reset_event_execution()
	# A full command quota must also obey wall-clock time shared by interpreters.
	var interpreter=load("res://runtime/scripts/EventInterpreter.gd").new(); interpreter.managed=true; interpreter.time_budget_usec=1
	var many: Array=[]
	for i in 2000: many.append({"code":121,"indent":0,"parameters":[190,190,0]})
	many.append({"code":0,"indent":0,"parameters":[]}); interpreter.start(many,0)
	await process_frame; interpreter.advance(0,2001)
	expect(interpreter.running and interpreter.context.index<2000,"wall-clock budget yields a long instruction list before its count quota")
	interpreter.cancel()
	await scheduler_fairness(state)
	game.queue_free(); await process_frame
	for failure in failures: printerr("FAIL: ",failure)
	print("FLASH EVENT BUDGET: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func scheduler_fairness(state: Node) -> void:
	var map=BudgetMap.new(); var scheduler=load("res://runtime/scripts/EventScheduler.gd").new()
	scheduler.configure(map,[])
	var slow=SlowMain.new(); slow.running=true; slow.time_budget_usec=4000; slow.budget_owner=state; scheduler.main=slow
	state.switches.erase("191")
	for frame in 4:
		await process_frame
		scheduler.advance(1.0/60.0,false)
	expect(slow.passes>0 and state.switches.get("191",false),"an expensive foreground command cannot starve a parallel interpreter across frames")
	scheduler.dispose(); map.free()
	map=BudgetMap.new(); scheduler=load("res://runtime/scripts/EventScheduler.gd").new(); scheduler.configure(map,[])
	state.variables["193"]=0
	scheduler.start_main([{"code":122,"indent":0,"parameters":[193,193,1,0,1]},{"code":106,"indent":0,"parameters":[1]},{"code":122,"indent":0,"parameters":[193,193,1,0,1]},{"code":0,"indent":0,"parameters":[]}],0,1,"",true)
	for frame in 4:
		await process_frame
		scheduler.advance(0.02,false)
	expect(state.variables["193"]==2 and not scheduler.main.running and absf(scheduler.parallels["event:1:1"].owner.wait_state.remaining-4.94)<0.0001,"rotation advances each foreground and parallel wait exactly once per scheduler tick")
	scheduler.dispose(); map.free()
func drain(game: Node) -> void:
	for frame in 360:
		if game._event_checkpoint.is_empty() and not game._interpreter.running: return
		game._scheduler.advance(1.0/60.0,false)
		await process_frame
	expect(false,"event preparation and execution complete within the test deadline")
func graph_cases() -> void:
	var shared={"value":4}; var cycle: Array=[]; cycle.append(cycle)
	var source={"one":shared,"two":shared,"cycle":cycle}; var copy=Graph.clone(source)
	expect(not is_same(copy.one,shared) and is_same(copy.one,copy.two) and is_same(copy.cycle,copy.cycle[0]),"bulk graph clone preserves aliases/cycles and detaches containers")
	expect(Graph.reason(source).is_empty() and (await Graph.reason_cooperatively(source,pulse)).is_empty(),"both graph validators accept aliases and cycles")
	var identical: Array=[]
	for i in 20: identical.append({"a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8,"tail":i})
	var distinct=Graph.clone(identical)
	expect(distinct[0].tail==0 and distinct[19].tail==19 and not is_same(distinct[0],distinct[1]),"shallow hash collisions retain distinct container identity")
	var destination={"value":4}; var rebound=Graph.rebind(copy,[[copy.one,destination]])
	expect(is_same(rebound.one,destination) and is_same(rebound.two,destination) and is_same(rebound.cycle,rebound.cycle[0]),"graph rebinding updates aliases without breaking cycles")
	var deep: Array=[]; var cursor=deep
	for i in 130:
		var next: Array=[]; cursor.append(next); cursor=next
	expect(not Graph.reason(deep).is_empty() and not (await Graph.reason_cooperatively(deep,pulse)).is_empty(),"both graph validators enforce the depth budget")
	var resource=Node.new()
	for value in [NAN,INF,resource]: expect(not Graph.reason([value]).is_empty() and not (await Graph.reason_cooperatively([value],pulse)).is_empty(),"invalid scalar or resource cannot pass the fast scalar path")
	resource.free(); copy.cycle.clear(); cycle.clear()
	var classes={"Object":{"parent":"","kind":"class"}}
	var object={"__ruby_class":"Object","fields":{}}
	object.fields.self=object
	expect(Graph.reason(object,classes).is_empty() and (await Graph.reason_cooperatively(object,pulse,classes)).is_empty(),"combined graph validation accepts a bound cyclic object in both paths")
	object.__ruby_class="MissingClass"
	expect(not Graph.reason(object,classes).is_empty() and not (await Graph.reason_cooperatively(object,pulse,classes)).is_empty(),"combined validation rejects unbound objects before save preparation publishes data")
	object.fields.clear()
func program_cases() -> void:
	var path="res://.godot/event-program-cache.gd"
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string("extends RefCounted\nstatic func answer(): return 1\n"); file.close()
	var first=Semantics.program(path); expect(first!=null and is_same(first,Semantics.program(path)),"unchanged generated programs keep a strong compiled reference")
	file=FileAccess.open(path,FileAccess.WRITE); file.store_string("extends RefCounted\nstatic func answer(): return 2\n"); file.close()
	var second=Semantics.program(path); expect(second!=null and second.answer()==2,"same-frame source edits invalidate the compiled program cache")
func definition_cases() -> void:
	var registry={"units":{
		"first":{"origin":{"kind":"script"},"definitions":{"types":["Outer"],"methods":[{"name":"query","singleton":false}]}},
		"middle":{"origin":{"kind":"script"},"definitions":{"constants":["Outer::Thing"]}},
		"last":{"origin":{"kind":"script"},"definitions":{"types":["Outer::Thing"],"methods":[{"name":"query","singleton":false}]}}
	}}
	expect(Scripts._definition_candidates("Outer::Thing","",false,registry)==["first","middle","last"],"symbol indexing preserves original definition and reopen order")
	expect(Scripts._definition_candidates("query","Object",false,registry)==["first","last"] and Scripts._definition_candidates("query","Object",true,registry).is_empty(),"method index separates singleton signatures")
	var replacement={"units":{"new":{"origin":{"kind":"script"},"definitions":{"types":["Outer"]}}}}
	expect(Scripts._definition_candidates("Outer::Thing","",false,replacement)==["new"],"replaced runtime registry rebuilds its symbol index")

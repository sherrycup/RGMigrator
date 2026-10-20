## 职责：回归验证：验证闪翼存档、撤回和地图恢复的连续流程。
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
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
var Codec: Script
var Saves: Script
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Codec=load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd"); Saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.actor(2); state.actor(3)
	Saves.directory_override="res://.godot/flow-save-%d" % Time.get_ticks_usec()
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game); await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	game._scheduler.start_main([{"code":101,"indent":0,"parameters":["保存时仍在显示的对话。"]},{"code":125,"indent":0,"parameters":[0,0,12]},{"code":0,"indent":0,"parameters":[]}],0,1,"fixture",true)
	await process_frame
	game._interpreter.advance(0); game._event_ui.pump(true)
	state.flash_messages.advance(13.0/60)
	var old_id=game._event_ui.active.id; var cursor=state.flash_messages.boxes[0].model.cursor; var count=state.flash_messages.history().size()
	var shared={}; shared.self=shared; state.variables["90"]=shared; game._interpreter.context.script_fields["@saved"]=shared
	var saved=Saves.save_slot(8,state)
	expect(saved.ok,"active foreground dialogue and event-local cyclic data save: "+str(saved.get("message","")))
	if saved.ok:
		var loaded=Saves.load_slot(8,state)
		expect(loaded.ok and game._event_ui.active.id!=old_id and game._interpreter.wait_kind()=="message","loaded dialogue gets a new broker request identity")
		expect(state.flash_messages.boxes.size()==1 and state.flash_messages.boxes[0].model.cursor==cursor and state.flash_messages.history().size()==count,"dialogue restores cursor without appending duplicate history")
		expect(is_same(state.variables["90"],game._interpreter.context.script_fields["@saved"]),"event fields preserve shared identity with variables")
		game._event_ui.resolve(old_id)
		expect(game._interpreter.wait_kind()=="message","old request cannot resume a loaded interpreter")
		var before=state.gold
		for i in 4:
			state.flash_messages.advance(60.0/60); state.flash_messages.confirm()
		state.flash_messages.advance(12.0/60); await process_frame; game._interpreter.advance(0)
		expect(state.gold==before+12 and not game._interpreter.running,"restored message closes and its following event executes exactly once")
	state.variables.erase("90"); game.reset_event_execution(); state.flash_messages.reset()
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8); image.fill(Color.RED); state.flash_effects.test_capture=image
	var freeze=game.play_flash_effect("freeze",[null]); state.flash_effects.advance(1.0/60)
	var frozen=Saves.save_slot(9,state)
	expect(freeze.ok and frozen.ok,"owned frozen image can now be saved")
	state.flash_effects.reset(); var loaded_frozen=Saves.load_slot(9,state)
	expect(loaded_frozen.ok and state.flash_effects.frozen!=null and absf(state.flash_effects.frozen.get_image().get_pixel(0,0).r-0.299)<0.01,"frozen image pixels restore as an owned texture")
	state.flash_effects.reset()
	state.flash_effects._make_unravel(image,Vector2.ZERO,Rect2i(0,0,16,16),[0,4,0.5,"RU","S",false])
	state.flash_effects.advance(1.0/60)
	var particles=state.flash_effects.particle_sets[0].model.particles.duplicate(true)
	var particle_save=Saves.save_slot(10,state)
	expect(particle_save.ok,"active particle textures and motion data save")
	state.flash_effects.reset(); var particle_load=Saves.load_slot(10,state)
	expect(particle_load.ok and state.flash_effects.particle_sets.size()==1 and state.flash_effects.particle_sets[0].model.particles[0].position==particles[0].position,"particles restore position without restarting randomization")
	var invalid=Codec.capture(state); invalid.flash_presentation.effects.particles[0].particles[0].velocity="invalid"
	expect(not Codec.prepare(invalid).ok,"invalid particle movement rejects the complete snapshot")
	state.flash_effects.reset(); state.flash_effects.test_capture=null
	var loaded_unit=Scripts.execute_unit("script_0317",state)
	expect(loaded_unit.ok,"original generated class methods register before save")
	var class_save=Saves.save_slot(11,state)
	expect(class_save.ok,"loaded definitions save with original generated source binding")
	state.script_session=null; var class_load=Saves.load_slot(11,state)
	expect(class_load.ok and state.script_session.classes.has("Actor_Init") and not state.script_session.methods.is_empty(),"class and method versions restore without running initializers")
	var bad=Codec.capture(state); bad.script_data.methods[bad.script_data.methods.keys()[0]].path="res://legacy/unsafe.gd"
	expect(not Codec.prepare(bad).ok,"foreign method file cannot be installed by a save")
	game.reset_event_execution(); state.variables["25"]=0; state.gold=100
	var target_id=0
	for key in game._map.map_data.events:
		if str(game._map.map_data.events[key].name).contains("怪物"): target_id=int(key); break
	if target_id>0:
		var commands=[{"code":125,"indent":0,"parameters":[0,0,9]},{"code":0,"indent":0,"parameters":[]}]
		game._map.player_trigger_request=true; game._start_event(commands,target_id); game._map.player_trigger_request=false
		for frame in 360:
			if game._event_checkpoint.is_empty() and not game._interpreter.running: break
			game._scheduler.advance(1.0/60.0,false)
			await process_frame
		expect(state.variables["25"]==1 and state.gold==109,"actual player-trigger path records before executing event reward")
		var undo=state.flash_history.undo()
		expect(undo.ok and state.gold==100,"automatic event-before record restores pre-event values")
		game.reset_event_execution(); var serial=state.variables["25"]
		game._start_event(commands,target_id)
		expect(state.variables["25"]==serial,"event movement/programmatic path does not add player-only automatic records")
	else: expect(false,"original Map010 contains a monster event for automatic-record integration")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH PERSISTENCE FLOW: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

## 职责：回归验证：验证闪翼存档条目、摘要、选择及档案页面行为。
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
var Codec: Script
const Archive=preload("res://runtime/scripts/07_Archive/ArchiveData.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Saves=load("res://runtime/scripts/10_Support/Persistence/SaveService.gd"); Codec=load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	root.size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2,3]; state.variables["14"]=[2,3]; state.variables["3"]=1
	state.actor(2).set_project_parameter("maxhp",300); state.actor(2).hp=222; state.actor(3)
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	Saves.directory_override="res://.godot/archive-tests-%d" % Time.get_ticks_usec()
	var image=Image.create(640,640,false,Image.FORMAT_RGBA8); image.fill(Color.RED); state.flash_archive_snapshot=image
	var original=Codec.capture(state)
	expect(original.flash_archive.players.size()==2 and original.flash_archive.players[0].hp==222 and original.flash_archive.chapter==1,"original archive presentation reads formal actors and chapter without actor-minus-assignment bug")
	var prepared=Codec.prepare(original)
	expect(prepared.ok,"Flash capture validates with new archive metadata: "+str(prepared.get("message","")))
	state.actor(2).hp=222.5
	var fractional=Codec.capture(state)
	expect(fractional.flash_archive.players[0].hp==222.5 and Codec.prepare(fractional).ok,"archive presentation preserves source fractional HP and accepts it in the same detached save")
	state.actor(2).hp=222
	var decoded=Archive.preview(original.flash_archive)
	expect(decoded!=null and decoded.get_size()==Vector2i(640,640) and decoded.get_pixel(0,0)==Color.RED,"checksummed archive screenshot decodes as original full canvas image")
	var invalid=original.duplicate(true); invalid.flash_archive.png="invalid PNG"
	expect(not Codec.prepare(invalid).ok,"malformed archive screenshot rejects whole detached save before state installation")
	expect(Saves.existing_slots().is_empty() and Saves.maximum_slots()>4,"Flash archive starts from actual files and supports source append beyond four native slots")
	var saved=Saves.save_slot(5,state)
	expect(saved.ok and Saves.existing_slots()==[5] and Saves.has_valid_save(),"source append-style archives save and list an actual fifth slot: "+str(saved.get("message","")))
	var info=Saves.slot_info(5)
	expect(info.ok and info.archive.chapter==1 and info.archive.players[0].hp==222,"slot summary retains snapshot chapter and source role data independently of current state")
	state.actor(2).hp=200; var second=Saves.save_slot(5,state)
	expect(second.ok and FileAccess.file_exists(Saves.slot_path(5)+".bak"),"archive overwrite preserves existing verified backup behavior")
	var page: Control=load("res://runtime/scripts/07_Archive/ArchivePage.gd").new(); page.mode="load"; root.add_child(page); await process_frame; page.set_process(false); page._process(8.0/60)
	expect(page.window_process==8 and page._slots==[5] and page._current.players[0].hp==200,"actual archive page completes eight-frame entry and reads saved actor snapshot")
	expect(page.preview_process==8 and page._preview_image.get_size()==Vector2i(352,352) and page._preview_image.get_pixel(10,10).r8==255 and page._preview_image.get_pixel(9,10).a8==0,"source map screenshot fills its316square preview inset and finishes eight-frame crossfade")
	page.handle_key(KEY_TAB); page._process(8.0/60)
	expect(page.mode=="save" and page._slots==[5,1],"source Tab changes archive mode and appends one first-empty record card")
	page.selected=1; page.refresh(); var writes=0
	page.save_callback=func(slot): writes+=1; return {"ok":false,"message":"fixture reject %d" % slot}
	page.activate()
	expect(page.message=="fixture reject 1","new record activation passes its actual slot ID to authoritative save callback")
	page.selected=0; page.refresh(); page.activate()
	expect(page._confirmation=="overwrite" and page._confirm!=null,"existing archive retains native concrete overwrite confirmation")
	page.back(); page.queue_free(); await process_frame
	game._menus._open_menu(); var menu: Control=game._menus.menu; menu.set_process(false)
	for tick in 8: menu._tick()
	menu.index=1; menu.activate()
	for tick in 8: menu._tick()
	await process_frame
	expect(menu.child is Control and menu.child.get_script().resource_path.ends_with("ArchivePage.gd") and game.can_save(),"actual Flash command1 opens migrated archive and satisfies production save gate")
	menu.child.handle_key(KEY_TAB)
	expect(not game.can_save(),"switching actual nested archive into read mode disables save gate")
	game._menus.close_menu(); await process_frame; paused=false
	var keyboard=state.flash_keyboard; var down: Dictionary={"65":true}; keyboard.input_provider=func(vk): return down.get(str(vk),false)
	var query=func(name): return Scripts.call_transaction(state,{"source":"Kboard."+name},func(env):return env.invoke(env.read_name("Kboard",{},env.root_receiver(),"Object"),name,[65]))
	var first=query.call("trigger?"); var again=query.call("trigger?")
	expect(first.ok and first.value and not again.value and keyboard.key==65,"actual Kboard bridge triggers once until release and stores original virtual-key code")
	down["65"]=false; query.call("trigger?"); down["65"]=true
	expect(query.call("trigger?").value,"release resets source keyboard edge before next press")
	keyboard.reset(); var repeat_first=query.call("repeat?"); var repeats: Array=[]
	for i in 5: repeats.append(query.call("repeat?").value)
	expect(repeat_first.value and repeats==[false,false,false,false,true],"source Kboard repeat is first query plus strict greater-than-four query counter")
	# Fatal case is covered in FailureIsolationProbe: keyboard
	var globals=Scripts.call_transaction(state,{"source":"keyboard constants"},func(env):return [env.read_name("$R_Key_CTLR",{},env.root_receiver(),"Object"),env.read_name("$R_Key_F12",{},env.root_receiver(),"Object"),env.read_name("$Key",{},env.root_receiver(),"Object")])
	expect(globals.ok and globals.value==[17,123,65],"all original full-keyboard globals and source typo aliases are available without Win32API")
	keyboard.input_provider=Callable(); Saves.directory_override=""; state.flash_archive_snapshot=null; game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH ARCHIVE/KEYBOARD: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

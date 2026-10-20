## 职责：回归验证：验证闪翼原地图系统的发现、布局和访问流程。
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
var Preview: Script
const Semantics=preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Preview=load("res://runtime/scripts/08_Menu/MapSystem/MapPreview.gd")
	var state=root.get_node("RuntimeState")
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2]; state.variables["14"]=[2,0]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",100); actor.hp=100; actor.set_project_parameter("agi",10)
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame
	game._events_enabled=false; game._interpreter.cancel(); game._player.input_enabled=true
	var map: Node=game.event_map(); var world=state.custom_data.map_system()
	expect(world.blocks().is_empty(),"loading a map does not invent discovery before the original map-window/transfer entry")
	state.player_motion.relocate(Vector2i(5,5))
	var original=Data.map(10).duplicate(true)
	expect(map.transfer(8,2,2,6),"actual native map transfer succeeds")
	expect(world.block(10)!=null and world.block(8)!=null and world.connections().size()==1 and world.connections()[0].from.id==10 and world.connections()[0].to.id==8,"completed native transfer records original departure and actual arrival in one shared map system")
	var count=world.connections().size()
	expect(not map.transfer(8,-1,0,2) and world.connections().size()==count,"invalid native destination produces no connection or discovery side effect")
	expect(map.transfer(8,3,3,2) and world.connections().size()==count,"same-map relocation preserves source record_transfer early return")
	expect(Data.map(10)==original,"discovery and transfer never mutate original map definitions")
	var env=Semantics.new(state); env.begin({"kind":"map-system-source-bridge"})
	var receiver=env.invoke(env.type_ref("Game_MapSystem"),"current",[])
	var blocks=env.invoke(receiver,"blocks",[])
	var entry=env.index_get(blocks,8)
	expect(env.invoke(entry,"id",[])==8 and env.invoke(receiver,"connected?",[10,8]),"original Game_MapSystem.current and native block/connection getters share the same source state")
	expect(env.finish(null).ok,"original map-system bridge completes the shared script transaction")
	game.reset_event_execution(); game._player.input_enabled=true
	var coordinator: Node=game._menus
	var opened=coordinator.open_flash_map()
	expect(opened and paused and coordinator.menu.page=="flash_map" and not game._player.input_enabled,"actual source map page opens through coordinator and owns pause/input")
	if not opened:
		printerr("FAIL: map page unavailable: ",JSON.stringify({"paused":paused,"input":game._player.input_enabled,"idle":game._player.is_idle(),"dialogue":game._dialogue.is_open(),"interpreter":game._interpreter.running,"menu_disabled":state.menu_disabled,"transfer":game._transfer_active})); quit(1); return
	var screen: Control=coordinator.menu
	expect(screen.cursor.selected.id==8 and screen.world==state.custom_data.map_system(),"map page initially selects the actual current block and formal shared service")
	var keys=InputEventKey.new(); keys.pressed=true; keys.keycode=KEY_M
	coordinator._input(keys)
	expect(coordinator.menu==null and not paused and game._player.input_enabled,"source M return closes the actual page and resumes native game input")
	state.menu_disabled=true
	expect(not coordinator.open_flash_map(),"source disabled menu prevents opening the map page")
	state.menu_disabled=false; state.player_motion.begin_move(6)
	expect(not coordinator.open_flash_map(),"source map page refuses a player in mid-motion")
	state.player_motion.relocate(Vector2i(3,3))
	var timeline=[Preview.offset(0,10,0),Preview.offset(39,10,0),Preview.offset(41,10,0),Preview.offset(60,10,0),Preview.offset(100,10,0),Preview.offset(101,10,0),Preview.offset(120,10,0)]
	expect(timeline==[Vector2.ZERO,Vector2.ZERO,Vector2(0.5,0),Vector2(10,0),Vector2(10,0),Vector2(9.5,0),Vector2.ZERO],"source preview keeps forty-frame holds and half-pixel ping-pong travel")
	expect(Preview.offset(90,10,20)==Vector2.ZERO and Preview.offset(41,0,10)==Vector2(0,0.5),"reserved two-axis tour remains frozen while vertical-only travel works")
	var snapshots=Preview.render(8)
	expect(snapshots.ok and snapshots.source=="snapshot" and snapshots.image.get_width()==int(Data.map(8).width)*12,"actual original valid snapshot produces the fixed-scale map preview")
	var fallback=Preview.render(6)
	expect(fallback.ok and fallback.source=="map_data" and fallback.image.get_height()==int(Data.map(6).height)*12,"actual corrupt 33-byte source snapshot falls back to map tiles and first-page graphics: "+str(fallback.get("message","")))
	if fallback.ok: fallback.image.save_png("res://.godot/flash-map-preview-fallback.png")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MAP FLOW: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

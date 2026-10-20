## 职责：回归验证：执行原巨型钥匙公共事件链并检查消耗及地图结果。
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
const Actions=preload("res://runtime/scripts/01_Battle/Actions.gd")
var checks=0
var failures: Array[String]=[]
var diagnostics: Array[String]=[]
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.map_id=10; state.playing=true; state.variables["14"]=[2,0]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",100); actor.hp=100
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); root.add_child(game)
	game._events_enabled=false; game.set_process(false); game._player.input_enabled=false
	await process_frame
	game._events_enabled=false
	var map: Node=game.event_map()
	var original=Data.map(10).duplicate(true)
	var common_source=Data.record("CommonEvents",4).duplicate(true)
	var yellow: Node=map.event_node(56); var blue: Node=map.event_node(57)
	expect(yellow!=null and blue!=null and yellow.trigger==1,"fixture uses original yellow/blue door events and page triggers")
	var old_blue=blue.commands.duplicate(true)
	var item_id=int(state.custom_data.gameplay().rules.constants.GIANT_KEY_ID)
	state.inventory["item:"+str(item_id)]=1; state.inventory["item:1"]=0
	var used=Actions.use_item(state,item_id)
	expect(used.ok and used.value==true and state.inventory_count("item",item_id)==0,"giant key applies once without requiring an ordinary yellow key: "+str(used.get("message","")))
	expect(yellow.commands[-2].get("_script_binding",{}).get("unit_id")=="derived_0091_door_die" and blue.commands==old_blue and yellow.trigger==1,"only source yellow door receives bound normalized macro and its original touch trigger")
	expect(Data.map(10)==original and Data.record("CommonEvents",4)==common_source,"macro extraction and page installation leave original map and common-event definitions unchanged")
	var interpreter: RefCounted=load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	interpreter.managed=true; interpreter.map_runtime=map; interpreter.common_events=Data.database("CommonEvents")
	interpreter.diagnostic_requested.connect(func(message):diagnostics.append(message))
	interpreter.start(yellow.commands,56,yellow.page_index)
	var saw_child=false; var saw_route=false; var complete=false
	for frame in 1200:
		if not interpreter.running: complete=true; break
		interpreter.advance(0.1)
		if not interpreter.context.stack.is_empty(): saw_child=true
		if yellow.routes.forcing: saw_route=true
		# Run the real native motion route, speeding up only the test clock.
		for event in map._event_nodes: event.advance_motion(0.1)
		if interpreter.wait_state.kind=="message": interpreter.resume_message()
		map.flush_event_refresh()
		await process_frame
	expect(complete and diagnostics.is_empty() and saw_child and saw_route,"complete installed macro enters original CE5, executes native forced turn animation and exits its wait: "+str(diagnostics))
	expect(map.event_node(56)==null and state.custom_data.values.system.event_name["10"]["56"]==str(state.custom_data.gameplay().rules.constants.DEFAULT_DEAD_CODE),"derived GDScript tail commits permanent death after the original route finishes")
	expect(state.inventory_count("item",1)==0 and Data.map(10)==original,"macro does not charge a second key and leaves the source definition intact")
	# Source check_event returns the first event at a cell. A second yellow
	# door underneath the blue door must not receive an executable replacement.
	var hidden: Node=map.event_node(58)
	hidden.motion.relocate(blue.motion.cell)
	state.custom_data.values.system.event_name["10"]["58"]="门01"
	state.inventory["item:"+str(item_id)]=1
	var overlapping=Actions.use_item(state,item_id)
	expect(overlapping.ok and overlapping.value==true and not state.custom_data.values.system.event_page["10"].has("58") and state.inventory_count("item",item_id)==0,"source per-cell lookup leaves a yellow door underneath a blue event unchanged and retains unconditional key consumption")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH GIANT KEY FLOW: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

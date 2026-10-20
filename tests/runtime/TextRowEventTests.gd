## 职责：回归验证：验证原事件调用文本行接口的实际结果。
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
	var state=root.get_node("RuntimeState"); state.map_id=24; state.party=[2]; state.variables["14"]=[2,0]
	var map: Dictionary=Data.map(24)
	var commands: Array=map.events["32"].pages[0].list
	var interpreter: RefCounted=load("res://runtime/scripts/02_Event/EventInterpreter.gd").new(); interpreter.managed=true
	var diagnostics: Array=[]; interpreter.diagnostic_requested.connect(func(message: String):diagnostics.append(message))
	interpreter.start(commands,32); interpreter.advance(0)
	expect(not interpreter.running and diagnostics.is_empty(),"actual Map024 EV032 bound355 executes the freshly generated original row constructor through EventInterpreter")
	expect(state.variables.get("14")==[2,0] and state.map_id==24 and state.inventory.is_empty(),"original standalone row construction has no invented window, item or transfer effect")
	var units: Dictionary=Data.read_json("res://data/script_units.json",{}); var unit: Dictionary=units.units.event_000127
	expect(unit.origin.map=="Map024" and unit.origin.event_id==32 and unit.source_corrections.size()==1,"actual executed unit retains original event position and recorded source fix")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH TEXT ROW EVENT: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

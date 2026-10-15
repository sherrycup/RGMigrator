extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState"); state.map_id=24; state.party=[2]; state.variables["14"]=[2,0]
	var map: Dictionary=Data.map(24)
	var commands: Array=map.events["32"].pages[0].list
	var interpreter: RefCounted=load("res://runtime/scripts/EventInterpreter.gd").new(); interpreter.managed=true
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

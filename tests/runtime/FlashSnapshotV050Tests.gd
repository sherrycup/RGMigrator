extends SceneTree
const Graph=preload("res://runtime/scripts/SaveGraph.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var child={"n":1}; var cycle: Array=[]; cycle.append(cycle)
	var original={"a":child,"b":child,"cycle":cycle,"typed":[Vector2(1,2),Color.RED,StringName("source")]}
	var copied=Graph.clone_checked(original)
	expect(copied.ok and Graph.reason(copied.value).is_empty(),"bounded capture accepts supported values and cycles")
	expect(is_same(copied.value.a,copied.value.b) and not is_same(copied.value.a,child),"capture preserves aliases while detaching live values")
	expect(is_same(copied.value.cycle,copied.value.cycle[0]),"capture preserves cycle identity")
	copied.value.a.n=9; expect(child.n==1,"snapshot mutation cannot change live shared data")
	var bad=RefCounted.new()
	for value in [bad,{"nested":[bad]},NAN,INF,{"n":NAN}]:
		expect(not Graph.clone_checked(value).ok and not Graph.reason(value).is_empty(),"capture and canonical validator both reject unsafe resource/nonfinite input")
	var deep: Array=[]; var cursor=deep
	for i in Graph.MAX_DEPTH+2:
		var next: Array=[]; cursor.append(next); cursor=next
	expect(not Graph.clone_checked(deep).ok,"capture enforces depth before snapshot recursion can overflow")
	var classes={"Object":{"parent":"","kind":"class"}}
	var state=root.get_node("RuntimeState"); state.begin_new_game(load("res://runtime/scripts/RuntimeData.gd").system(),{"enabled":false})
	state.map_id=10; state.party=[2]; state.variables["14"]=[2,0]; state.actor(2)
	var codec=load("res://runtime/scripts/SaveCodec.gd"); var preparation=load("res://runtime/scripts/SavePreparation.gd")
	var snapshot=codec.capture(state)
	var malformed=Graph.clone(snapshot); malformed.variables["900"]={"__ruby_class":"Missing","fields":{}}
	var worker_check=func(value,definitions):
		var thread=Thread.new(); var result: Array=[]
		thread.start(func():result.append(Graph.reason(value,definitions)))
		while thread.is_alive(): await process_frame
		thread.wait_to_finish(); return result[0]
	var pulse=func():return true
	var sync=codec.prepare(snapshot); var async_result=await preparation.prepare_cooperatively(snapshot,state.custom_data,false,pulse,worker_check)
	expect(sync.ok and async_result.ok,"worker graph validation and canonical schema preparation agree on valid snapshot")
	var rejected=await preparation.prepare_cooperatively(malformed,state.custom_data,false,pulse,worker_check)
	expect(not codec.prepare(malformed).ok and not rejected.ok,"worker still rejects missing script class links before schema restore")
	var invalid=Graph.clone(snapshot); invalid.custom_data.money["unknown"]=1
	expect(not (await preparation.prepare_cooperatively(invalid,state.custom_data,false,pulse,worker_check)).ok,"schema checks still reject custom currency after graph validation")
	state.variables["901"]={"nested":[bad]}
	expect(codec.capture(state).has("script_error"),"ordinary save capture continues rejecting runtime resources")
	state.variables.erase("901")
	# Break the deliberate test cycles before shutdown.
	copied.value.cycle.clear(); cycle.clear()
	for failure in failures: printerr("FAIL: ",failure)
	print("FLASH V050 SNAPSHOTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

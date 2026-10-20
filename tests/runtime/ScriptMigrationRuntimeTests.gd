## 职责：回归验证：验证生成 GDScript 在实际运行工程中的加载执行。
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
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var failures: Array[String] = []
var checks := 0
var notices: Array = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	var runtime: Script = load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
	var bridge: Script = load("res://runtime/scripts/10_Support/Scripting/ScriptStateBridge.gd")
	var values: Script = load("res://runtime/scripts/02_Event/EventValueResolver.gd")
	state.begin_new_game(data.system())
	state.event_state_changed.connect(func(kind: String, key: String) -> void: notices.append([kind,key]))
	var registry: Dictionary = data.read_json("res://data/script_units.json", {})
	var chosen := ""; var variable := 0
	var reset := RegEx.new(); reset.compile("^\\$game_variables\\[([0-9]+)\\]\\s*=\\s*0$")
	for id in registry.units:
		var unit: Dictionary = registry.units[id]
		if unit.get("status") != "generated" or not unit.get("event_integrated",false): continue
		if unit.origin.get("database","CommonEvents")!="CommonEvents": continue
		var source: String = unit.get("source", "")
		var lines: Array[String] = []
		for line in source.split("\n"):
			if not line.strip_edges().is_empty() and not line.strip_edges().begins_with("#"): lines.append(line.strip_edges())
		var match_value := reset.search("\n".join(lines))
		if match_value!=null: chosen = id; variable = int(match_value.get_string(1)); break
	expect(not chosen.is_empty(),"real source case extracted with its original map/common-event origin")
	state.set_event_variable(variable,37); notices.clear()
	if not chosen.is_empty():
		var result: Dictionary = runtime.execute_unit(chosen,state)
		var expected := 0
		expect(result.ok and result.value == expected and int(state.variables[str(variable)]) == expected,"real generated script changes existing state to independent expected value")
		expect(notices==[["variable",str(variable)]],"generated write emits native event refresh once")
		expect(values.condition([1,variable,0,expected,0],null,0).value,"native event condition reads generated state")
		var codec: Script = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
		var saved: Dictionary = codec.capture(state)
		expect(int(saved.variables[str(variable)]) == expected and codec.prepare(saved).ok,"existing save snapshot includes script state and passes validation")
		# Verification must not silently restore the preserved source command.
		var origin: Dictionary = registry.units[chosen].origin
		var commands: Array
		if origin.kind == "map_event": commands = data.map(str(origin.map).trim_prefix("Map").to_int()).events[str(int(origin.event_id))].pages[int(origin.page)-1].list
		else: commands = data.database(origin.get("database","CommonEvents"))[int(origin.common_event_id)].list
		expect(commands.any(func(c: Dictionary) -> bool: return c.get("_script_binding",{}).get("unit_id")==chosen),"converted actual event restored with generated unit binding")
	var write := {"operation":"state_write","target":"variable","id":8180,"operator":"=","value":9}
	var bad := {"operation":"state_write","target":"variable","id":8181,"operator":"+=","value":1}
	state.set_event_variable(8180,5); state.set_event_variable(8181,2147483647)
	var before: Dictionary = state.variables.duplicate(true); notices.clear()
	expect(not bridge.apply(state,[write,bad],{"test":"atomic"}).ok and state.variables==before and notices.is_empty(),"later overflow rejects the whole unit without any earlier mutation or signal")
	var result: Dictionary = bridge.apply(state,[write,{"operation":"state_write","target":"switch","id":8180,"operator":"=","value":true}])
	expect(result.ok and state.variables["8180"]==9 and state.switches["8180"],"bridge writes variables and switches through native state")
	expect(bridge.apply(state,[write.merged({"operator":"-="},true)]).ok and state.variables["8180"]==0,"integer subtract semantics")
	expect(bridge.apply(state,[write.merged({"operator":"+="},true)]).ok and state.variables["8180"]==9,"integer addition semantics")
	state.variables["8180"]="bad"
	expect(not bridge.apply(state,[write.merged({"operator":"+="},true)]).ok,"unknown prior value is rejected instead of coerced to zero")
	state.variables.erase("8180")
	expect(not runtime.execute_unit("missing",state).ok,"missing generated unit does not report success")
	for id in registry.units:
		if registry.units[id].status == "unsupported":
			var rejected: Dictionary = runtime.execute_unit(id,state)
			expect(not rejected.ok and not rejected.diagnostics.is_empty(),"unsupported runtime request retains compiler diagnostic"); break
	var evidence := {"chosen_unit":chosen,"origin":registry.units.get(chosen,{}).get("origin",{}),"variable_id":variable,"expected":0,"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot"))
	var file := FileAccess.open("res://.godot/script-runtime-proof.json",FileAccess.WRITE)
	expect(file != null,"runtime verification evidence can be saved")
	evidence["checks"] = checks
	if file != null: file.store_string(JSON.stringify(evidence,"\t")); file.close()
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT RUNTIME TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / unit=",chosen)
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

## 职责：验证可读事件正文直接编译执行、角色初始化接口、原工程覆盖及简短源码的真实归属。
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
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func visit(value: Variant) -> void
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
var checks = 0
var failures: Array[String] = []
var _count = 0
var Source: Script

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func visit(value: Variant) -> void:
	if value is Array:
		for item in value: visit(item)
	elif value is Dictionary:
		var binding: Variant = value.get("_script_binding")
		if Source.is_native(binding):
			var text = str(value.parameters[1] if int(value.code) == 111 else value.parameters[0])
			expect(binding.get("source_form") == "body" and not Source.is_module(text), "migrated source is actual business body: " + str(binding.unit_id))
			expect(not text.contains("ctx.migrated") and not text.contains("env.") and not text.contains("static func") and not text.contains("## 职责"), "no runtime template in authored body: " + str(binding.unit_id))
			expect(Source.compile(text).ok and text.sha256_text() == binding.source_sha256, "same business source compiles and matches the executable binding")
			if binding.unit_id == "event_000114": expect(text.strip_edges() == "Actor_Init.load(2)", "reported example is reduced to the real one-line call")
			_count += 1
		for key in value:
			if not str(key).begins_with("_legacy") and not str(key).begins_with("_editor_original"): visit(value[key])

func run() -> void:
	Source = load("res://runtime/scripts/02_Event/NativeScriptSource.gd")
	var Data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	var state: Node = root.get_node("RuntimeState")
	state.begin_new_game(Data.system())
	var interpreter: RefCounted = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	var golden: Dictionary = load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd").execute_unit("event_000114", state)
	expect(golden.ok, "original generated initialization provides the behavior baseline")
	var preset: Dictionary = state.actor(2).snapshot()
	state.actor(2).set_project_parameter("patk", 123)
	var source = "Actor_Init.load(2)\nctx.set_variable(8191, 52)\n"
	interpreter.start([{"code":355, "indent":0, "parameters":[source], "_script_binding":Source.binding(source)}, {"code":0, "indent":0, "parameters":[]}], 1, 1)
	expect(not interpreter.running and state.variables.get("8191") == 52, "plain business body runs without extends/run or Ruby conversion")
	if state.actor(2).snapshot() != preset:
		for key in preset:
			if preset[key] != state.actor(2).snapshot().get(key): print("PRESET DIFF ",key, " before=", preset[key], " after=",state.actor(2).snapshot().get(key))
	expect(state.actor(2).snapshot() == preset, "Actor_Init.load applies the existing complete preset to the authoritative actor")
	source = "ctx.set_variable(8191, 53)\n"
	interpreter.start([{"code":355, "indent":0, "parameters":[source], "_script_binding":Source.binding(source)}, {"code":0, "indent":0, "parameters":[]}], 1, 1)
	expect(state.variables.get("8191") == 53, "edited body executes its own source rather than a hidden old program")
	state.variables["8193"] = {"__decimal_integer":"9223372036854775808123"}
	source = "ctx.variables.put(8194, ctx.api.maximum([ctx.api.at(ctx.variables, [8193]), 0]))\nctx.variables.put(8195, ctx.api.add(ctx.api.at(ctx.variables, [8193]), 1))\n"
	interpreter.start([{"code":355, "indent":0, "parameters":[source], "_script_binding":Source.binding(source)}, {"code":0, "indent":0, "parameters":[]}], 1, 1)
	expect(state.variables.get("8194") == state.variables["8193"], "collection helpers preserve original arbitrary integer representation")
	expect(state.variables.get("8195") == {"__decimal_integer":"9223372036854775808124"}, "readable arithmetic preserves exact original integer semantics")
	expect(not Source.template().contains("extends") and not Source.template().contains("run(ctx)"), "new authoring template contains no module boilerplate")
	for name in Data.manifest().maps: visit(Data.read_json("res://data/maps/"+name+".json", {}))
	visit(Data.database("CommonEvents"))
	visit(Data.read_json("res://data/flash_gameplay.json", {}))
	expect(_count == 145, "all 145 original entrance bindings use readable source")
	state.map_id = 10
	state.party = [2, 3]
	state.variables["14"] = [2, 3]
	state.actor(3)
	var game: Node = load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	root.add_child(game)
	await process_frame
	game.reset_event_execution()
	game.set_process(false)
	game._player.set_process(false)
	game._events_enabled = false
	var owner = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	owner.running = true
	source = "ctx.screen.set_rect()\nctx.temp.hp_addition = 17\nreturn true\n"
	var result: Dictionary = load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd").execute_bound(Source.binding(source), source, state, {"owner":owner, "generation":owner._native_generation, "map_id":10, "event_id":0, "index":0, "fields":{}})
	expect(result.ok and int(result.get("flash_effect_request", 0)) > 0 and state.flash_effects.busy(), "later business operations retain the actual effect request for scheduler waiting")
	owner.cancel()
	game.queue_free()
	await process_frame
	for message in failures: printerr("FAIL: ", message)
	print("READABLE EVENT V052: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks)
	quit(0 if failures.is_empty() else 1)

## 职责：回归验证：实际执行原生地图、公共事件、条件和移动路线，检查异步、重试、复制及取消。
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
##   func module(body: String) -> String
##     参数 body（String；必填）：脚本语句体或处理内容。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func command(body: String, code: int = 355) -> Dictionary
##     参数 body（String；必填）：脚本语句体或处理内容。
##     参数 code（int；默认值 355）：对应指令、按键或操作的编码。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func finish_command() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
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
const Source = preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
var Interpreter: Script
var failures: Array[String] = []
var checks = 0

class CharacterFixture extends Node:
	var character_id = 7
	var map_runtime: Node
	func is_idle() -> bool: return true
	func route_locked() -> bool: return false
	func clear_route_lock_direction() -> void: pass

func _init() -> void:
	call_deferred("run")

func module(body: String) -> String:
	return "extends RefCounted\nstatic func run(ctx):\n\t" + body.replace("\n", "\n\t") + "\n"

func command(body: String, code: int = 355) -> Dictionary:
	var source = module(body)
	return {"code":code, "indent":0, "parameters":[12, source] if code == 111 else [source], "_script_binding":Source.binding(source)}

func finish_command() -> Dictionary:
	return {"code":0, "indent":0, "parameters":[]}

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run() -> void:
	Interpreter = load("res://runtime/scripts/02_Event/EventInterpreter.gd")
	var state: Node = root.get_node("RuntimeState")
	var data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	state.begin_new_game(data.system())
	state.map_id = 1
	state.variables = {}
	state.switches = {}
	var owner = Interpreter.new()
	owner.start([command("ctx.set_variable(8100, ctx.variable(8100) + 3)\nreturn false"), {"code":121,"indent":0,"parameters":[8100,8100,0]}, finish_command()], 7)
	expect(not owner.running and state.variables.get("8100") == 3 and state.switches.get("8100", false), "native false finishes normally; same variable and switch state")
	var condition = command("return ctx.variable(8100) == 3", 111)
	owner.start([condition, {"code":121,"indent":1,"parameters":[8101,8101,0]}, {"code":411,"indent":0,"parameters":[]}, {"code":121,"indent":1,"parameters":[8102,8102,0]}, {"code":412,"indent":0,"parameters":[]}, finish_command()], 7)
	expect(state.switches.get("8101", false) and not state.switches.get("8102", false), "native condition uses its actual bool result")
	var awaited_condition = command("if not await ctx.wait(0.01): return false\nreturn true", 111)
	owner.start([awaited_condition, {"code":121,"indent":1,"parameters":[8106,8106,0]}, {"code":411,"indent":0,"parameters":[]}, {"code":121,"indent":1,"parameters":[8107,8107,0]}, {"code":412,"indent":0,"parameters":[]}, finish_command()], 7)
	expect(not state.switches.get("8106", false) and not state.switches.get("8107", false), "async condition does not choose a branch while pending")
	for frame in 120:
		owner.advance(1.0 / 60)
		if not owner.running: break
		await process_frame
	expect(state.switches.get("8106", false) and not state.switches.get("8107", false), "async condition chooses its branch after completion")
	owner.common_events = [null, {"list":[command("ctx.set_variable(8103, ctx.event_id)\nctx.set_variable(8104, ctx.common_event_id)\nctx.set_variable(8105, ctx.map_id)\nreturn null"), finish_command()]}]
	owner.start([{"code":117,"indent":0,"parameters":[1]}, finish_command()], 7)
	expect(not owner.running and state.variables.get("8103") == 7 and state.variables.get("8104") == 1 and state.variables.get("8105") == 1, "common event retains caller event, common id and actual map")
	var asynchronous = command("ctx.set_variable(8110, ctx.variable(8110) + 1)\nif not await ctx.wait(0.03): return\nctx.set_variable(8111, ctx.variable(8111) + 1)\nreturn null")
	owner.start([asynchronous, finish_command()], 7)
	expect(owner.running and state.variables.get("8110") == 1 and not state.variables.has("8111"), "await suspends without early continuation")
	var codec: Script = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	expect(codec.capture(state).has("script_error"), "suspended native coroutine cannot be serialized as a completed instruction")
	for frame in 120:
		owner.advance(1.0 / 60)
		if not owner.running: break
		await process_frame
	expect(not owner.running and state.variables.get("8110") == 1 and state.variables.get("8111") == 1, "await resumes exactly once")
	owner.start([asynchronous, finish_command()], 7)
	owner.cancel()
	for frame in 10: await process_frame
	expect(state.variables.get("8110") == 2 and state.variables.get("8111") == 1, "cancelled wait cannot modify current state")
	var second = Interpreter.new()
	owner.start([asynchronous, finish_command()], 7)
	second.start([asynchronous.duplicate(true), finish_command()], 8)
	for frame in 120:
		owner.advance(1.0 / 60)
		second.advance(1.0 / 60)
		if not owner.running and not second.running: break
		await process_frame
	expect(state.variables.get("8110") == 4 and state.variables.get("8111") == 3, "parallel callers sharing source retain separate pending tasks")
	var polling = command("ctx.fields[\"attempts\"] = ctx.fields.get(\"attempts\", 0) + 1\nif not ctx.switch(8120): return ctx.retry(0.01)\nctx.set_variable(8120, ctx.fields.attempts)\nreturn null")
	owner.start([polling, finish_command()], 7)
	expect(owner.running and owner.wait_kind() == "time", "explicit retry uses existing wait scheduler")
	state.set_event_switch(8120, true)
	owner.advance(0.02)
	expect(not owner.running and state.variables.get("8120") == 2, "retry preserves fields and reevaluates only its script")
	var copy: Dictionary = Source.copy_with_new_ids(polling)
	expect(copy._script_binding.native_id != polling._script_binding.native_id and copy.parameters == polling.parameters, "copy has independent stable identity and identical source")
	copy.parameters[0] = module("return null")
	copy._script_binding = Source.binding(copy.parameters[0], copy._script_binding)
	expect(polling.parameters[0] != copy.parameters[0], "editing copied source does not edit original")
	var character = CharacterFixture.new()
	root.add_child(character)
	character.map_runtime = root
	var route: RefCounted = load("res://runtime/scripts/02_Event/CharacterRoute.gd").new(character)
	var route_command = command("ctx.set_variable(8130, ctx.character.character_id)\nif not await ctx.wait(0.02): return\nctx.set_switch(8130, true)\nreturn null", 45)
	var route_data = {"repeat":false, "skippable":false, "list":[route_command, {"code":0,"parameters":[]}]}
	expect(route.force(route_data).ok and state.variables.get("8130") == 7 and route.forcing, "forced route uses actual character and waits")
	for frame in 120:
		route.advance(1.0 / 60)
		if not route.forcing: break
		await process_frame
	expect(not route.forcing and state.switches.get("8130", false), "forced route resumes following action once")
	state.switches.erase("8130")
	expect(route.configure(3, 6, route_data).ok, "autonomous route accepts same native command")
	for frame in 120:
		route.advance(1.0 / 60)
		if state.switches.get("8130", false): break
		await process_frame
	expect(state.switches.get("8130", false), "autonomous route executes actual native source")
	route.cancel()
	var retry_route = {"repeat":false, "skippable":false, "list":[command("ctx.fields.attempts = ctx.fields.get(\"attempts\", 0) + 1\nif not ctx.switch(8131): return ctx.retry(0.01)\nctx.set_variable(8131, ctx.fields.attempts)\nreturn null", 45), {"code":0,"parameters":[]}]}
	expect(route.force(retry_route).ok, "route explicitly retries without advancing")
	var route_snapshot: Dictionary = route.persistent_data()
	expect(route.validate_persistent(route_snapshot), "route retry and its fields can be saved")
	route.cancel()
	route.restore_persistent(JSON.parse_string(JSON.stringify(route_snapshot)))
	state.set_event_switch(8131, true)
	route.advance(0.02)
	expect(state.variables.get("8131") == 2 and not route.forcing, "restored route retry continues its saved fields")
	var interrupted = {"repeat":false, "skippable":false, "list":[command("ctx.set_variable(8133, ctx.variable(8133) + 1)\nif not await ctx.wait(0.1): return\nctx.set_switch(8133, true)\nreturn null", 45), command("ctx.set_variable(8134, ctx.variable(8134) + 1)\nreturn null", 45), {"code":0,"parameters":[]}]}
	route.configure(3, 6, interrupted)
	route.advance(2)
	var override_route = {"repeat":false, "skippable":false, "list":[command("ctx.set_switch(8135, true)\nreturn null",45), {"code":0,"parameters":[]}]}
	expect(route.force(override_route).ok, "forced route can replace an awaiting autonomous native action")
	route.advance(2)
	for frame in 12: await process_frame
	expect(state.variables.get("8133") == 1 and not state.switches.get("8133", false) and state.variables.get("8134") == 1 and state.switches.get("8135", false), "overridden coroutine is cancelled; original resumes after interrupted action without replaying earlier effects")
	route.cancel()
	var inventory_before: int = state.inventory_count("item", 1)
	state.actor(2).set_project_parameter("maxhp", 100)
	owner.start([command("ctx.gain_item(\"item\", 1, 1)\nctx.set_variable(8132, ctx.item_count(\"item\", 1))\nctx.actor(2).hp = 9\nreturn null"), finish_command()], 7)
	expect(state.variables.get("8132") == mini(99, inventory_before + 1) and state.actor(2).hp == 9, "native inventory and actor interfaces mutate the authoritative state")
	character.free()
	var persisted = command("ctx.fields.once = true\nreturn ctx.retry(0.5)")
	owner.start([persisted, finish_command()], 7)
	var persistence: Script = load("res://runtime/scripts/02_Event/EventPersistence.gd")
	var snapshot: Dictionary = persistence._interpreter(owner, false)
	expect(persistence._execution_valid(snapshot), "scheduler wait, inline source, binding and native fields can be saved")
	owner.cancel()
	var restored = Interpreter.new()
	persistence._restore_interpreter(restored, JSON.parse_string(JSON.stringify(snapshot)))
	expect(restored.running and restored.context.script_fields.get("once", false), "persisted wait restores native event fields")
	restored.cancel()
	for message in failures: printerr("FAIL: ", message)
	print("NATIVE EVENT V052: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks)
	quit(0 if failures.is_empty() else 1)

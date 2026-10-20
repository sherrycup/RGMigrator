## 职责：独立进程回归：验证原生脚本各类错误首错停止、来源定位及已发生修改保留。
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
## 接口说明结束。

extends SceneTree
const Source = preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
var mode = "runtime"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): mode = argument.trim_prefix("--case=")
	call_deferred("run")

func run() -> void:
	var state: Node = root.get_node("RuntimeState")
	state.begin_new_game(load("res://runtime/scripts/00_Game/RuntimeData.gd").system())
	state.map_id = 1
	state.variables = {}
	var body = "ctx.set_variable(8500, 73)\n\tvar missing: Variant = null\n\tmissing.absent()\n\tctx.set_variable(8501, 1)"
	if mode == "semantic": body = "ctx.set_variable(8500, 73)\n\tctx.fail(\"native intended failure\")\n\tctx.set_variable(8501, 1)"
	if mode == "condition": body = "return 7"
	if mode == "compile": body = "var ="
	var source = "extends RefCounted\nstatic func run(ctx):\n\t" + body + "\n"
	if mode == "body_runtime": source = body.replace("\n\t", "\n") + "\n"
	if mode == "body_compile": source = "# 正文错误定位\nctx.set_variable(8500, 73)\nvar =\n"
	if mode == "body_api": source = "ctx.set_variable(8500, 73)\nctx.api.binary(\"/\", 1, 0)\nctx.set_variable(8501, 1)\n"
	var binding = Source.binding(source)
	if mode == "binding": binding.source_sha256 = "0".repeat(64)
	var command = {"code":111 if mode == "condition" else 355, "parameters":[12, source] if mode == "condition" else [source], "indent":0, "_script_binding":binding}
	var owner: RefCounted = load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	var list = [command]
	if mode == "condition": list.append({"code":412,"parameters":[],"indent":0})
	list.append({"code":0,"parameters":[],"indent":0})
	owner.start(list, 87, 1)
	var first: String = state._fatal_script_message
	var ok = paused and not first.is_empty() and first.contains("87") and not state.variables.has("8501")
	if mode in ["runtime", "semantic", "body_runtime", "body_api"]: ok = ok and state.variables.get("8500") == 73
	else: ok = ok and not state.variables.has("8500")
	if mode == "body_runtime": ok = ok and first.contains(".gd:3 / run")
	if mode == "body_compile": ok = ok and first.contains("L3:C1")
	if mode == "body_api": ok = ok and first.contains("L2:C1")
	state.fatal_script_error("later error must not replace first")
	ok = ok and state._fatal_script_message == first
	var result = {"ok":ok, "case":mode, "message":first, "variables":state.variables}
	var file = FileAccess.open("res://.godot/v052-fatal-" + mode + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("NATIVE FATAL V052: ", JSON.stringify(result))
	if not ok: quit(2)

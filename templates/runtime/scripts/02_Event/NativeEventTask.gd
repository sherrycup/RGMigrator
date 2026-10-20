## 职责：管理原生事件单次调用与跨帧完成状态，避免等待重入并丢弃已取消调用的结果。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/02_Event/NativeEventTask.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func start(script: GDScript, state: Object, execution: Dictionary, binding: Dictionary) -> void
##     参数 script（GDScript；必填）：已通过编译的 GDScript 资源，不在编辑器调用事件入口。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 execution（Dictionary；必填）：当前事件或路线的调用归属、代次、地图、指令位置和字段。
##     参数 binding（Dictionary；必填）：事件入口的 GDScript 身份、源码校验值、来源与策略。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
const Context = preload("NativeEventContext.gd")
const Source = preload("NativeScriptSource.gd")
var context: RefCounted
var done = false
var result: Dictionary = {}


func start(script: GDScript, state: Object, execution: Dictionary, binding: Dictionary) -> void:
	context = Context.new(
		state, execution.merged({"native_path": script.resource_path}), binding.get("origin", {})
	)
	context.result.policy = binding.get("policy", {"false_result_waits": false})
	Source._active_origins[script.resource_path] = context._origin
	_drive(script)


func _drive(script: GDScript) -> void:
	var value: Variant = await script.run(context)
	if context._body_api != null:
		value = context.api.raw(value)
	if context.active() or not context.result.ok:
		result = context.result
		result.value = value
		if (
			context._execution.get("native_condition", false)
			and not value is bool
			and context.result.get("origin", {}).get("kind") == "native_event"
		):
			result.ok = false
			result.message = "GDScript 条件必须返回 bool。"
		result.unit_id = "native"
	else:
		result = {"ok": false, "message": "GDScript 调用已取消。"}
	if is_same(Source._active_origins.get(script.resource_path), context._origin):
		Source._active_origins.erase(script.resource_path)
	done = true

## 职责：向原生事件提供同一运行现场、角色、变量、开关、背包及可取消异步等待接口。
##
## 调用方式：
##   仅由 ScriptRuntime 为一次事件或路线调用创建；事件源码定义 static func run(ctx)。
##   ctx.state、ctx.map、ctx.character 为同一运行现场；map_id/event_id/common_event_id 为当前调用编号。
##   变量和开关使用原编号；ctx.fields 在当前解释器或路线脚本重试间保留。
##   异步等待使用 if not await ctx.wait(秒): return；返回 false 表示已取消。
##   普通 return false 正常结束；return ctx.retry(秒) 显式重试。
##
## 调用接口：
##   func _init(runtime_state: Object, execution: Dictionary, origin: Dictionary) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 runtime_state（Object；必填）：本工程当前唯一 RuntimeState 运行状态。
##     参数 execution（Dictionary；必填）：当前事件或路线的调用归属、代次、地图、指令位置和字段。
##     参数 origin（Dictionary；必填）：原脚本、地图或数据库字段的来源信息。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func active() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func actor(id: int) -> RefCounted
##     用途：按原编号取得当前运行角色实例。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：RefCounted 类型的对象或值，供调用方继续使用。
##
##   func variable(id: int, fallback: Variant = 0) -> Variant
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 fallback（Variant；默认值 0）：变量缺失或调用已取消时的默认值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func set_variable(id: int, value: Variant) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func switch(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func set_switch(id: int, value: bool) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func self_switch(letter: String, value: bool) -> bool
##     参数 letter（String；必填）：独立开关字母，只接受 A/B/C/D。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func item_count(kind: String, id: int) -> int
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func gain_item(kind: String, id: int, amount: int) -> bool
##     用途：与原生126—128共用背包增减，通知同一运行状态。
##     参数 kind（String；必填）：item、weapon或armor；对应原物品、武器或防具。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 amount（int；必填）：有符号整数，正数增加、负数扣减；最终数量限0—99。
##     返回：true为成功；失败记录首错并停止，不建立独立背包。
##
##   func wait(seconds: float) -> bool
##     用途：按游戏推进时间非阻塞等待，菜单暂停期间不累计。
##     参数 seconds（float；必填）：以秒计的时长。
##     返回：true 表示等待完成且调用仍有效，false 表示取消；调用方必须 await。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func retry(seconds: float = 0.0) -> bool
##     用途：结束当前调用，并由原解释器或路线调度器在指定秒数后重新运行本条脚本。
##     参数 seconds（float；默认值 0.0）：以秒计的时长。
##     返回：false；调用方写 return ctx.retry(seconds)，字段通过 ctx.fields 保存。
##
##   func fail(message: String) -> void
##     用途：构造或登记带原因的失败结果。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func migrated(program: Callable) -> Variant
##     用途：同步调用当前模块的迁移 program(env)，保留原 GDScript 语义和返回值。
##     参数 program（Callable；必填）：同步执行迁移 GDScript 的 Callable，参数为现有语义会话。
##     返回：迁移程序返回值；效果和失败记录在 result 中。
##
## 注意：ctx.migrated(program) 同步执行当前模块中的迁移 GDScript，沿用原公式及语义会话，不执行 Ruby。
## 注意：await 期间不支持存档，完成并由调度器接收结果后可保存；需要可保存的重试等待时使用 ctx.retry。
## 注意：取消、重开事件、路线覆盖或换图后上下文失效；异步调用应检查 wait 返回值。
## 接口说明结束。

extends RefCounted

var _state: Object
var _owner: WeakRef
var _generation: int
var _execution: Dictionary
var _origin: Dictionary
var _body_api: RefCounted
var _actor_init: RefCounted
var api: RefCounted:
	get:
		if _body_api == null:
			_body_api = preload("EventScriptAPI.gd").new(self)
		return _body_api
var actor_init: RefCounted:
	get:
		if _actor_init == null:
			_actor_init = preload("../00_Game/Game_ActorInit.gd").new(api)
		return _actor_init
var temp: Variant:
	get:
		return api.named("$game_temp")
var system: Variant:
	get:
		return api.named("$game_system")
var party: Variant:
	get:
		return api.named("$game_party")
var actors: Variant:
	get:
		return api.named("$game_actors")
var variables: Variant:
	get:
		return api.named("$game_variables")
var self_switches: Variant:
	get:
		return api.named("$game_self_switches")
var main_actor: Variant:
	get:
		return api.named("_main_actor")
var attack_actor: Variant:
	get:
		return api.named("_attack_actor")
var event: Variant:
	get:
		return api.named("_this")
var game_map: Variant:
	get:
		return api.named("$game_map")
var player: Variant:
	get:
		return api.named("$game_player")
var screen: Variant:
	get:
		return api.named("GameEngine::Screen")
var storage: Variant:
	get:
		return api.named("Storage")
var enemies: Variant:
	get:
		return api.named("$data_enemies")
var result: Dictionary = {"ok": true, "value": null, "policy": {"false_result_waits": false}}
var state: Object:
	get:
		return _state if active() else null
var map_id: int:
	get:
		return int(_execution.get("map_id", 0))
var event_id: int:
	get:
		return int(_execution.get("event_id", 0))
var common_event_id: int:
	get:
		return int(_execution.get("common_id", 0))
var fields: Dictionary:
	get:
		return _execution.get("fields", {})
var character: Node:
	get:
		if not active():
			return null
		if _execution.has("character"):
			return _execution.character
		var current_map: Node = _execution.get("map_runtime")
		return (
			current_map.event_node(event_id)
			if is_instance_valid(current_map) and event_id > 0
			else null
		)
var map: Node:
	get:
		return _execution.get("map_runtime") if active() else null


func _init(runtime_state: Object, execution: Dictionary, origin: Dictionary) -> void:
	_state = runtime_state
	_execution = execution.duplicate()
	_origin = origin.merged(
		{
			"invocation":
			{
				"map_id": execution.get("map_id", 0),
				"event_id": execution.get("event_id", 0),
				"page": execution.get("page", 0),
				"common_event_id": execution.get("common_id", 0),
				"command_index": int(execution.get("index", 0)) + 1
			}
		}
	)
	_owner = weakref(execution.owner)
	_execution.erase("owner")
	_generation = int(execution.generation)
	result.origin = _origin
	result.script_fields = fields


func active() -> bool:
	var owner: Object = _owner.get_ref()
	if owner == null or not is_instance_valid(_state) or not result.get("ok", true):
		return false
	if owner.get("running") is bool and not owner.get("running"):
		return false
	var fatal: Variant = _state.get("_fatal_script_message")
	if fatal is String and not fatal.is_empty():
		return false
	return (
		owner != null
		and is_instance_valid(_state)
		and int(owner.get("_native_generation")) == _generation
		and int(_state.map_id) == map_id
	)


func actor(id: int) -> RefCounted:
	return _state.actor(id) if active() else null


func variable(id: int, fallback: Variant = 0) -> Variant:
	return _state.variables.get(str(id), fallback) if active() else fallback


func set_variable(id: int, value: Variant) -> bool:
	if not active():
		return false
	if _state.set_event_variable(id, value):
		return true
	fail("变量编号或变量值无效：" + str(id))
	return false


func switch(id: int) -> bool:
	return active() and bool(_state.switches.get(str(id), false))


func set_switch(id: int, value: bool) -> bool:
	if not active():
		return false
	if _state.set_event_switch(id, value):
		return true
	fail("开关编号无效：" + str(id))
	return false


func self_switch(letter: String, value: bool) -> bool:
	if not active():
		return false
	if _state.set_event_self_switch(map_id, event_id, letter, value):
		return true
	fail("当前调用没有有效事件或独立开关字母无效。")
	return false


func item_count(kind: String, id: int) -> int:
	return _state.inventory_count(kind, id) if active() else 0


func gain_item(kind: String, id: int, amount: int) -> bool:
	if not active():
		return false
	var changed = preload("../00_Game/InventoryService.gd").change(_state, kind, id, amount)
	if changed.ok:
		return true
	fail(changed.message)
	return false


func wait(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0:
		fail("等待时间必须是有限非负秒数。")
		return false
	var remaining = seconds
	while active() and remaining > 0:
		await _state.get_tree().process_frame
		if active() and not _state.map_time_paused():
			remaining -= _state.get_process_delta_time()
	if active():
		preload("NativeScriptSource.gd")._active_origins[str(_execution.get("native_path", ""))] = _origin
	return active()


func retry(seconds: float = 0.0) -> bool:
	if not is_finite(seconds) or seconds < 0:
		fail("重试间隔必须是有限非负秒数。")
	result.retry = true
	result.wait_seconds = seconds
	return false


func fail(message: String) -> void:
	result.ok = false
	result.message = message
	if _state.has_method("fatal_script_error"):
		_state.fatal_script_error(message + " / " + JSON.stringify(_origin))


func migrated(program: Callable) -> Variant:
	if not active():
		return null
	var runtime: Script = load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
	var environment: RefCounted = runtime._session(_state)
	var previous: Dictionary = environment.execution_context
	environment.execution_context = _execution.merged({"policy": result.policy})
	if _origin.has("route_index"):
		environment.execution_context.index = int(_origin.route_index) - 1
	elif _origin.has("command_index"):
		environment.execution_context.index = (
			int(_origin.get("source_command_indices", [_origin.command_index])[-1]) - 1
		)
	if not environment.begin(_origin):
		result = environment.failure
		environment.execution_context = previous
		return null
	var value: Variant = program.call(environment)
	result = environment.finish(value)
	environment.execution_context = previous
	return result.get("value")

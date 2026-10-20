## 职责：捕获 GDScript 引擎错误并附加来源，协调首错停止、错误弹窗与退出。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/10_Support/Scripting/ScriptErrorLogger.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func _init(owner: Node) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 owner（Node；必填）：持有此对象的调用方或运行状态。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
## 接口说明结束。

extends Logger
## Engine script errors terminate gameplay, including errors in edited GDScript.
var _owner: WeakRef


func _init(owner: Node) -> void:
	_owner = weakref(owner)


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type != Logger.ERROR_TYPE_SCRIPT:
		return
	if preload("../../02_Event/NativeScriptSource.gd").compiling > 0:
		return
	var owner: Node = _owner.get_ref()
	if owner == null:
		return
	line = maxi(
		1, line - int(preload("../../02_Event/NativeScriptSource.gd")._line_offsets.get(file, 0))
	)
	var message = (
		"%s\n%s:%d / %s" % [rationale if not rationale.is_empty() else code, file, line, function]
	)
	var native_origin: Dictionary = (
		preload("../../02_Event/NativeScriptSource.gd")._active_origins.get(file, {})
	)
	if native_origin.is_empty():
		for trace in _backtraces:
			for index in trace.get_frame_count():
				var path = trace.get_frame_file(index)
				var origins: Dictionary = (
					preload("../../02_Event/NativeScriptSource.gd")._active_origins
				)
				if origins.has(path):
					native_origin = origins[path]
					var offset = int(
						preload("../../02_Event/NativeScriptSource.gd")._line_offsets.get(path, 0)
					)
					message += (
						"\n事件正文：%s:%d" % [path, maxi(1, trace.get_frame_line(index) - offset)]
					)
					break
			if not native_origin.is_empty():
				break
	if not native_origin.is_empty():
		message += "\n原生事件：" + JSON.stringify(native_origin)
	if Thread.is_main_thread():
		owner._script_engine_error(message)
	else:
		owner.call_deferred("_script_engine_error", message)

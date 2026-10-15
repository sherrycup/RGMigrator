extends Logger
## Engine script errors terminate gameplay, including errors in edited GDScript.
var _owner: WeakRef

func _init(owner: Node) -> void:
	_owner=weakref(owner)

func _log_error(function: String,file: String,line: int,code: String,rationale: String,_editor_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type!=Logger.ERROR_TYPE_SCRIPT: return
	var owner: Node=_owner.get_ref()
	if owner==null: return
	var message="%s\n%s:%d / %s" % [rationale if not rationale.is_empty() else code,file,line,function]
	if Thread.is_main_thread(): owner._script_engine_error(message)
	else: owner.call_deferred("_script_engine_error",message)

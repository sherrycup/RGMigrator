extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
var mode="semantic"
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode=arg.trim_prefix("--case=")
	call_deferred("run")
func native_failure() -> void:
	var missing: Variant=null
	missing.fatal_probe_invalid_call()
func run() -> void:
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false})
	var env=Scripts._session(state)
	env.execution_context={"map_id":10,"event_id":70,"common_id":1,"index":11,"fields":{}}
	env.begin({"kind":"fatal_probe","case":mode})
	env.index_set({"__state_table":"variable"},93,27)
	if mode=="native": native_failure()
	elif mode=="binding": Scripts.execute_bound({},"",state,env.execution_context)
	else: env.fail("有意触发的脚本错误："+mode)
	var result=env.finish(null)
	var valid=not result.ok and state.variables.get("93")==27 and paused and not state._fatal_script_message.is_empty()
	var first=state._fatal_script_message; state.fatal_script_error("second error")
	valid=valid and state._fatal_script_message==first
	await process_frame
	await process_frame
	valid=valid and is_instance_valid(state._fatal_script_dialog) and state._fatal_script_dialog.visible and state._fatal_script_dialog.ok_button_text=="关闭游戏"
	var report={"case":mode,"ok":valid,"paused":paused,"no_rollback":state.variables.get("93")==27,"dialog_visible":state._fatal_script_dialog.visible,"message":state._fatal_script_message}
	var file=FileAccess.open("res://.godot/fatal-"+mode+".json",FileAccess.WRITE); file.store_string(JSON.stringify(report)); file.close()
	print("FATAL PROBE: ",JSON.stringify(report))
	if not valid: quit(2); return
	# Exercise the same confirmation signal as the modal's close-game button.
	if mode=="cancel": state._fatal_script_dialog.canceled.emit()
	else: state._fatal_script_dialog.confirmed.emit()

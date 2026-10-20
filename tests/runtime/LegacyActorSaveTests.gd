## 职责：回归验证：只读检查旧版角色存档的兼容恢复。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
## Optional real ver0.15 save regression; reads the old file without rewriting it.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-save="): path = argument.trim_prefix("--legacy-save=")
	if not FileAccess.file_exists(path):
		printerr("FAIL: provide an existing disposable ver0.15 test save")
		quit(1)
		return
	var hash_before := FileAccess.get_sha256(path)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var payload: Dictionary = JSON.parse_string(envelope.payload)
	if envelope.runtime_version != "ver0.15" or payload.actors[0].has("parameter_plus"):
		printerr("FAIL: fixture must be an actual old save without new actor fields")
		quit(1)
		return
	var result: Dictionary = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd").read_path(path)
	if not result.ok:
		printerr("FAIL: old save rejected: ", result.message)
		quit(1)
		return
	var state: Node = root.get_node("RuntimeState")
	state.restore_prepared(result.prepared)
	var data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	for saved in payload.actors:
		var actor: RefCounted = state.actor(int(saved.id))
		var definition: Dictionary = data.source_record("Actors", int(saved.id))
		for key in actor.Parameters.KEYS:
			if actor.get_parameter_plus(key) != 0:
				printerr("FAIL: inferred permanent bonus from old equipment")
				quit(1)
				return
		for slot in 5:
			if actor.equipment[slot] != int(saved.equipment[slot]):
				printerr("FAIL: old equipment ID changed")
				quit(1)
				return
		if actor.hp != int(saved.hp) or actor.sp != int(saved.sp) or actor.character_name != str(definition.get("character_name", "")) or actor.character_hue != int(definition.get("character_hue", 0)):
			printerr("FAIL: old actor progress/graphic fallback changed")
			quit(1)
			return
	for key in payload.inventory:
		if int(state.inventory.get(key, -1)) != int(payload.inventory[key]):
			printerr("FAIL: old inventory progress changed")
			quit(1)
			return
	if state.gold != int(payload.gold) or state.inventory.size() != payload.inventory.size() or FileAccess.get_sha256(path) != hash_before:
		printerr("FAIL: old save progress or file changed")
		quit(1)
		return
	print("LEGACY ACTOR SAVE TESTS: PASSED; ver0.15 file unchanged")
	quit(0)

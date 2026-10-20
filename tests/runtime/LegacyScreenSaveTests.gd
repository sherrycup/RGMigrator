## 职责：回归验证：只读检查旧版屏幕和地图显示存档的兼容恢复。
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
##   func equivalent(first: Variant, second: Variant) -> bool
##     参数 first（Variant；必填）：第一个值、对象或起始位置。
##     参数 second（Variant；必填）：第二个值或参与操作的对象。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func fail(message: String) -> void
##     用途：构造或登记带原因的失败结果。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
## Read-only compatibility check against an actual previous native save.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-save="): path = argument.trim_prefix("--legacy-save=")
	var disposable_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().get_base_dir() + "/"
	if not path.begins_with(disposable_root) or not FileAccess.file_exists(path):
		fail("provide an existing disposable project-local old native test save")
		return
	var hash_before := FileAccess.get_sha256(path)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var payload: Dictionary = JSON.parse_string(envelope.payload)
	if envelope.runtime_version != "ver0.16" or payload.has("screen"):
		fail("fixture must be an actual ver0.16 save without screen fields")
		return
	var result: Dictionary = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd").read_path(path)
	if not result.ok:
		fail(result.message)
		return
	var state: Node = root.get_node("RuntimeState")
	state.restore_prepared(result.prepared)
	var restored: Dictionary = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd").capture(state)
	for key in payload:
		if not equivalent(payload[key], restored[key]):
			fail("old progress changed: " + key)
			return
	var neutral: RefCounted = load("res://runtime/scripts/00_Game/ScreenState.gd").new()
	if not equivalent(state.screen.snapshot(), neutral.snapshot()) or FileAccess.get_sha256(path) != hash_before:
		fail("screen defaults not neutral or old file changed")
		return
	print("LEGACY SCREEN SAVE TESTS: PASSED; ver0.16 file unchanged")
	quit(0)


func equivalent(first: Variant, second: Variant) -> bool:
	if (first is int or first is float) and (second is int or second is float): return is_equal_approx(float(first), float(second))
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size(): return false
		for key in first:
			if not second.has(key) or not equivalent(first[key], second[key]): return false
		return true
	if first is Array and second is Array:
		if first.size() != second.size(): return false
		for index in first.size():
			if not equivalent(first[index], second[index]): return false
		return true
	return first == second


func fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)

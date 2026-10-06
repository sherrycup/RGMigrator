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
	var result: Dictionary = load("res://runtime/scripts/SaveService.gd").read_path(path)
	if not result.ok:
		fail(result.message)
		return
	var state: Node = root.get_node("RuntimeState")
	state.restore_prepared(result.prepared)
	var restored: Dictionary = load("res://runtime/scripts/SaveCodec.gd").capture(state)
	for key in payload:
		if not equivalent(payload[key], restored[key]):
			fail("old progress changed: " + key)
			return
	var neutral: RefCounted = load("res://runtime/scripts/ScreenState.gd").new()
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

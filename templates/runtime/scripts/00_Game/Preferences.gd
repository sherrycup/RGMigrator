## 职责：管理闪翼用户音量、解锁和选项等独立偏好数据，并处理持久化。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/Preferences.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/Preferences.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(owner: Node) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 owner（Node；必填）：持有此对象的调用方或运行状态。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func set_volume(kind: String, value: int) -> bool
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func next_run_mode() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func change_window_size(direction: int) -> int
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func apply_audio() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func apply_window() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func unlock_music(name: String) -> void
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func storage_path() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func save_preferences() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func load_preferences() -> Dictionary
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func validate(value: Variant) -> String
##     用途：检查输入数据是否符合该服务的约定。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 对外信号：
##   changed()：当前模型或草稿已经变化，界面可据此刷新。
##
## 公开常量：MUSIC_BUS、EFFECT_BUS。
## 接口说明结束。

extends RefCounted
## Source 0004/0046/0047. App preferences outlive a new game/slot restore.
## App data is separate from progress slots and never imports RM settings.
signal changed
const Data = preload("RuntimeData.gd")
const MUSIC_BUS = "RGMFlashMusic"
const EFFECT_BUS = "RGMFlashEffects"
var vars: Array = []
var music_lock: Array = []
var apply_display = true
static var directory_override = ""
var storage_error = ""
var _owner: WeakRef
var bgm_volume: int:
	get:
		return int(vars[2])
var se_volume: int:
	get:
		return int(vars[3])
var run_mode: int:
	get:
		return int(vars[4])
var window_resize: int:
	get:
		return int(vars[7])


func _init(owner: Node) -> void:
	_owner = weakref(owner)
	vars.resize(101)
	vars.fill(0)
	# Fresh migration has no RM settings file. Correct the source's silent
	# first-run defaults; an existing saved zero still means intentional mute.
	vars[2] = 10
	vars[3] = 10
	for name in [MUSIC_BUS, EFFECT_BUS]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, name)
	var loaded = load_preferences()
	if not loaded.ok and FileAccess.file_exists(storage_path()):
		storage_error = loaded.message
	apply_audio()


func set_volume(kind: String, value: int) -> bool:
	if kind not in ["bgm", "se"] or value < 0 or value > 10:
		return false
	var candidate = _candidate()
	candidate.vars[2 if kind == "bgm" else 3] = value
	return _publish(candidate)


func next_run_mode() -> void:
	var candidate = _candidate()
	candidate.vars[4] = posmod(run_mode + 1, 2)
	_publish(candidate)


func change_window_size(direction: int) -> int:
	var candidate = _candidate()
	candidate.vars[7] = posmod(window_resize + direction, 4)
	_publish(candidate)
	return window_resize


func apply_audio() -> void:
	for value in [[MUSIC_BUS, bgm_volume], [EFFECT_BUS, se_volume]]:
		var index = AudioServer.get_bus_index(value[0])
		AudioServer.set_bus_mute(index, value[1] == 0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.00001, float(value[1]) / 10.0)))


func apply_window() -> void:
	if not apply_display or DisplayServer.get_name() == "headless":
		return
	var host: Node = _owner.get_ref()
	if host == null or not host.is_inside_tree():
		return
	var window = host.get_tree().root
	# Original proxy modes: 1x, 1.25x, 1.5x and borderless full screen.
	window.mode = Window.MODE_FULLSCREEN if window_resize == 3 else Window.MODE_WINDOWED
	window.borderless = window_resize == 3
	if window_resize != 3:
		window.size = Vector2i(Vector2(640, 640) * [1.0, 1.25, 1.5][window_resize])


func unlock_music(name: String) -> void:
	var names: Array = Data.read_json("res://data/flash_gameplay.json", {}).get("storage", {}).get(
		"music_name", []
	)
	var index = names.find(name.get_file().get_basename())
	if index < 0:
		return
	var candidate = _candidate()
	while candidate.music_lock.size() <= index:
		candidate.music_lock.append(null)
	if candidate.music_lock[index] == null:
		candidate.music_lock[index] = true
		_publish(candidate)


func storage_path() -> String:
	var test_path = str(ProjectSettings.get_setting("rgmigrator/test_preferences_directory", ""))
	var base = (
		directory_override
		if not directory_override.is_empty()
		else (
			test_path
			if not test_path.is_empty()
			else (
				"user://rgmigrator_preferences/"
				+ str(ProjectSettings.get_setting("rgmigrator/project_id", "")).sha256_text().left(
					24
				)
			)
		)
	)
	return base.path_join("preferences.json")


func save_preferences() -> Dictionary:
	var result = preload("../10_Support/Persistence/FileStore.gd").write(
		storage_path(), "preferences", {"vars": vars, "music_lock": music_lock}
	)
	storage_error = "" if result.ok else result.message
	return result


func load_preferences() -> Dictionary:
	var result = preload("../10_Support/Persistence/FileStore.gd").read(
		storage_path(), "preferences", validate
	)
	if not result.ok:
		return result
	var reason = validate(result.value)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	vars = result.value.vars
	music_lock = result.value.music_lock
	apply_audio()
	apply_window()
	changed.emit()
	return {"ok": true, "recovered": result.get("recovered", false)}


static func validate(value: Variant) -> String:
	if (
		not value is Dictionary
		or not value.get("vars") is Array
		or value.vars.size() != 101
		or not value.get("music_lock") is Array
		or value.music_lock.size() > 10000
	):
		return "设置数据结构无效。"
	for index in [2, 3, 4, 5, 7]:
		var limit = 10 if index in [2, 3] else 3 if index == 7 else 1
		if not value.vars[index] is int or value.vars[index] < 0 or value.vars[index] > limit:
			return "设置数值超出原范围。"
	for flag in value.music_lock:
		if flag != null and not flag is bool:
			return "音乐解锁标志无效。"
	return preload("../10_Support/Persistence/SaveGraph.gd").reason(value)


func _persist() -> void:
	var result = save_preferences()
	var owner: Node = _owner.get_ref()
	if not result.ok and owner != null:
		owner.report_diagnostic("设置保存失败：" + result.message)


func _candidate() -> Dictionary:
	return preload("../10_Support/Persistence/SaveGraph.gd").clone(
		{"vars": vars, "music_lock": music_lock}
	)


func _publish(candidate: Dictionary) -> bool:
	var reason = validate(candidate)
	if not reason.is_empty():
		storage_error = reason
		return false
	var result = preload("../10_Support/Persistence/FileStore.gd").write(
		storage_path(), "preferences", candidate
	)
	storage_error = "" if result.ok else result.message
	if not result.ok:
		var owner: Node = _owner.get_ref()
		if owner != null:
			owner.report_diagnostic("设置保存失败：" + result.message)
		return false
	vars = candidate.vars
	music_lock = candidate.music_lock
	apply_audio()
	apply_window()
	changed.emit()
	return true

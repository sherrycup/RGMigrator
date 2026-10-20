## 职责：回归验证：验证脚本分组、菜单职责、状态归属与存档源码兼容边界。
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
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
## Verify the new exported layout, authoritative state and menu responsibilities.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const MenuModel = preload("res://runtime/scripts/08_Menu/Main/MenuModel.gd")
const MenuPages = preload("res://runtime/scripts/08_Menu/Main/MenuPages.gd")
const Paths = preload("res://runtime/scripts/10_Support/Scripting/ScriptPaths.gd")
const Scripts = preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
const ProgramDocs = preload("res://runtime/scripts/10_Support/Scripting/ProgramDocumentation.gd")
var Saves: Script
var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func run() -> void:
	Saves = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	var layout: Dictionary = Data.read_json("res://data/script_layout.json", {})
	expect(not layout.is_empty(), "formal export includes source layout")
	for filename in layout.get("runtime", {}):
		var path: String = "res://runtime/scripts/" + layout.runtime[filename]
		expect(FileAccess.file_exists(path), "runtime source exists: " + path)
		expect(Paths.runtime(filename) == path, "dynamic navigation resolves actual source: " + filename)
		var source := FileAccess.get_file_as_string(path)
		expect(not source.contains("res://addons/") and not source.contains("res://scripts/importer/"), "runtime has no editor/compiler dependency: " + filename)
	for relative in layout.get("editor", {}).values():
		expect(FileAccess.file_exists("res://addons/rgm_editor/" + relative), "editor source exists: " + relative)
	for relative in layout.get("scenes", {}).values():
		expect(ResourceLoader.exists("res://scenes/" + relative), "grouped scene exists: " + relative)
	_check_save_fingerprint()
	var state := root.get_node("RuntimeState")
	state.begin_new_game(Data.system(), {"enabled": false})
	var actor = state.actor(int(state.party[0]))
	_check_program_hash(state)
	state.variables.erase("5")
	MenuModel.initialize(state)
	expect(state.variables["5"] == MenuModel.DEFAULT_LOCKS, "menu initialization writes original variable 5")
	state.variables["5"][3] = 1
	MenuModel.initialize(state)
	expect(MenuModel.enabled(state, 3), "reopening keeps existing unlocks")
	expect(not MenuModel.enabled(state, -1) and not MenuModel.enabled(state, 10), "invalid command does not access a different variable")
	expect(is_same(actor, state.actor(actor.id)), "menu model uses the same authoritative actor")
	for command in [0, 1, 3, 4, 7, 8]:
		var page = MenuPages.create(command, Callable())
		expect(page != null, "original implemented menu branch constructs: " + str(command))
		if page != null:
			page.free()
	for command in [2, 5, 6]:
		expect(MenuPages.create(command, Callable()) == null, "original empty branch stays empty: " + str(command))
	for message in failures:
		printerr("FAIL: ", message)
	print("FLASH STRUCTURE V051: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _check_save_fingerprint() -> void:
	# The runner only permits a disposable project; restore the source bytes
	# before continuing, including when an expectation fails.
	var path := "res://data/custom_data.json"
	var original := FileAccess.get_file_as_string(path)
	Saves._fingerprint = ""
	var current: String = Saves.fingerprint()
	var legacy := original.replace("runtime/scripts/00_Game/CustomDataState.gd", "runtime/scripts/CustomDataState.gd")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(legacy)
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() == current, "moving adapter source preserves existing Godot save fingerprint")
	var changed: Dictionary = JSON.parse_string(original)
	changed.profile = "modified-gameplay-profile"
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(changed, "\t", false) + "\n")
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() != current, "gameplay changes still invalidate the old fingerprint")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() == current, "original definition bytes and fingerprint are restored")
	path = "res://data/custom_units.json"
	original = FileAccess.get_file_as_string(path)
	var current_line := '"generated_line": %d,' % (15 + ProgramDocs.HEADER.count("\n"))
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original.replace(current_line, '"generated_line": 15,'))
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() == current, "exact pre-comment data-expression line mappings preserve save fingerprint")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original.replace(current_line, '"generated_line": 17,'))
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() == current, "previous one-line headers retain the same data-expression fingerprint")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original.replace(current_line, '"generated_line": 18,'))
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() != current, "arbitrary source-map edits are not accepted as the compiler banner shift")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original.replace('"source": " 0"', '"source": " 1"'))
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() != current, "data expression changes still invalidate old saves")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	Saves._fingerprint = ""
	expect(Saves.fingerprint() == current, "restoring data-expression metadata restores the exact fingerprint")


func _check_program_hash(state: Object) -> void:
	Scripts.execute_unit("script_0317", state)
	var saved: Dictionary = Scripts.script_data(state)
	expect(Scripts.validate_saved_data(saved).is_empty(), "current generated methods validate after layout move")
	var path := "res://runtime/generated/script_0317.gd"
	var original := FileAccess.get_file_as_string(path)
	var banner: String = ProgramDocs.HEADER
	expect(original.begins_with(banner), "fresh generated program starts with its responsibility comment")
	var previous := original.trim_prefix(banner)
	var previous_saved: Dictionary = saved.duplicate(true)
	previous_saved.generated_hashes[path] = previous.sha256_text()
	expect(Scripts.validate_saved_data(previous_saved).is_empty(), "pre-comment 0.51 generated methods remain compatible")
	previous_saved.generated_hashes[path] = (ProgramDocs.LEGACY_HEADER + previous).sha256_text()
	expect(Scripts.validate_saved_data(previous_saved).is_empty(), "previous one-line header source hashes remain compatible")
	previous_saved.generated_hashes[path] = previous.replace('preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")', 'preload("res://runtime/scripts/ScriptSemantics.gd")').sha256_text()
	expect(Scripts.validate_saved_data(previous_saved).is_empty(), "pre-layout 0.5 generated methods remain compatible")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original.replace("## 职责：", "## 用途："))
	file.close()
	expect(not Scripts.validate_saved_data(saved).is_empty(), "an edited banner is still checked as source")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original + "\n# source changed after save\n")
	file.close()
	expect(not Scripts.validate_saved_data(saved).is_empty(), "layout compatibility still rejects an edited generated method")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	expect(Scripts.validate_saved_data(saved).is_empty(), "restoring exact generated source restores validation")

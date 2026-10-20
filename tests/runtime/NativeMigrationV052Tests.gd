## 职责：回归验证：逐条检查原工程事件GDScript、编译和来源哈希，并确认编辑后失效的旧档兼容别名。
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
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func visit(value: Variant, path: String) -> void
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var failures: Array[String] = []
var checks = 0
var native_count = 0
var Source: Script

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func visit(value: Variant, path: String) -> void:
	if value is Array:
		for item in value: visit(item, path)
	elif value is Dictionary:
		if value.has("_script_binding"):
			var tag: Dictionary = value._script_binding
			expect(Source.is_native(tag), "native binding: " + path + ":" + str(tag.get("unit_id")))
			if Source.is_native(tag):
				var parameters: Array = value.get("parameters", [])
				var source = str(parameters[1] if int(value.get("code", 0)) == 111 else parameters[0])
				expect(tag.source_sha256 == source.sha256_text(), "exact authored source hash: " + tag.native_id)
				expect(Source.compile(source, tag.native_id).ok, "actual native module compiles: " + tag.native_id)
				native_count += 1
		for key in value:
			if not str(key).begins_with("_legacy") and not str(key).begins_with("_editor_original"):
				visit(value[key], path)

func run() -> void:
	Source = load("res://runtime/scripts/02_Event/NativeScriptSource.gd")
	var Data: Script = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	for name in Data.manifest().maps:
		visit(Data.read_json("res://data/maps/" + name + ".json", {}), name)
	visit(Data.database("CommonEvents"), "CommonEvents")
	visit(Data.read_json("res://data/flash_gameplay.json", {}), "Flash macro")
	expect(native_count >= 144, "all real event entrances audited")
	var saves: Script = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	var upgrade: Dictionary = Data.read_json("res://data/native_event_sources.json", {})
	expect(upgrade.get("entries", {}).size() == 38, "36 maps, common events and door macro have exact legacy evidence")
	for path in upgrade.get("entries", {}):
		var entry: Dictionary = upgrade.entries[path]
		expect(FileAccess.get_sha256("res://" + path) == entry.native_sha256, "published native bytes match upgrade evidence: " + path)
		expect(FileAccess.get_sha256("res://" + entry.legacy_path) == entry.legacy_sha256, "legacy source bytes retained: " + path)
		var expected = str(entry.legacy_sha256)
		if path == "data/flash_gameplay.json":
			# The generated catalog filename is registered navigation metadata;
			# its legacy JSON proof still has to match exact published bytes above.
			var legacy = FileAccess.get_file_as_string("res://" + entry.legacy_path)
			expected = legacy.replace('"path": "res://runtime/generated/skill_catalog.gd"', '"path": "res://runtime/generated/flash_skill_catalog.gd"').sha256_text()
		expect(saves._definition_hash("res://" + path) == expected, "only exact migration and registered navigation alias keep old definition hash: " + path)
	var original = FileAccess.get_file_as_string("res://data/maps/Map001.json")
	var edited = FileAccess.open("res://data/maps/Map001.json", FileAccess.WRITE)
	edited.store_string(original + " ")
	edited.close()
	expect(saves._definition_hash("res://data/maps/Map001.json") != upgrade.entries["data/maps/Map001.json"].legacy_sha256, "any unregistered JSON byte change disables old-save alias")
	edited = FileAccess.open("res://data/maps/Map001.json", FileAccess.WRITE)
	edited.store_string(original)
	edited.close()
	expect(saves.fingerprint() == "6bd0e10f60f79b11a5f6206b465d82fa0f5342aaa3832f3786a8f163a7d80eb1", "fresh original-RM export preserves the verified 0.51 definition fingerprint")
	print("V052 FINGERPRINT: ", saves.fingerprint())
	for message in failures: printerr("FAIL: ", message)
	var report = {"ok":failures.is_empty(), "checks":checks, "native_records":native_count, "fingerprint":saves.fingerprint()}
	var file = FileAccess.open("res://.godot/v052-migration-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("NATIVE MIGRATION V052: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " / records=", native_count)
	quit(0 if failures.is_empty() else 1)

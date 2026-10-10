extends SceneTree

const RmxpMarshalReader = preload("res://scripts/importer/RmxpMarshalReader.gd")
const RmxpTableDecoder = preload("res://scripts/importer/RmxpTableDecoder.gd")
const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const RmxpValidator = preload("res://scripts/importer/RmxpValidator.gd")
const MigrationPipeline = preload("res://scripts/importer/MigrationPipeline.gd")
const RmxpDataConverter = preload("res://scripts/importer/RmxpDataConverter.gd")
const TestSetupGenerator = preload("res://scripts/importer/TestSetupGenerator.gd")
const AssetCopier = preload("res://scripts/importer/RmxpAssetCopier.gd")
const Generator = preload("res://scripts/importer/ProjectGenerator.gd")

var _failures: Array[String] = []
var _exports: Array[String] = []


func _init() -> void:
	_test_marshal_scalars_and_arrays()
	_test_table_decoder()
	_test_marshal_links_and_errors()
	_test_converter_diagnostics()
	_test_codecs()
	_test_sample_preflight()
	_test_test_setup_generator()
	_test_asset_safety()
	if "--full" in OS.get_cmdline_user_args():
		_test_full_sample_migration()
		var results := FileAccess.open("res://.godot/test-results.json", FileAccess.WRITE)
		results.store_string(JSON.stringify({"exports": _exports, "failures": _failures}, "\t"))
		results.close()
	if _failures.is_empty():
		print("RGMigrator tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		quit(1)


func _test_marshal_scalars_and_arrays() -> void:
	# Ruby Marshal 4.8: [1, true, "A"]
	var bytes := PackedByteArray([4, 8, 91, 8, 105, 6, 84, 34, 6, 65])
	var reader := RmxpMarshalReader.new(RmxpTextCodec.new(936))
	var value: Variant = reader.read_bytes(bytes)
	_expect(not reader.failed, "Marshal reader should parse a basic array")
	_expect(value is Array and value.size() == 3, "Marshal array length should be three")
	_expect(value[0] == 1 and value[1] == true, "Marshal scalar values should round-trip")


func _test_test_setup_generator() -> void:
	var root := ProjectSettings.globalize_path("res://.godot/test_setup_fixture_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root.path_join("data/database"))
	var original := "[null, {\"id\":1,\"name\":\"原物品\"}, null]"
	for database in ["Items", "Weapons", "Armors", "Skills", "Animations", "States"]:
		var file := FileAccess.open(root.path_join("data/database/%s.json" % database), FileAccess.WRITE)
		file.store_string(original)
		file.close()
	for enabled in [false, true]:
		var result := TestSetupGenerator.new().generate(root, enabled)
		_expect(result.ok and result.enabled == enabled, "generator preserves requested testing flag")
		var setup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/test_setup.json")))
		_expect(setup.enabled == enabled and setup.stock.size() == 9, "persisted test setup has flag and nine supplies")
		_expect(setup.definitions.Items[0].id == 3 and setup.definitions.Weapons[0].id == 3 and setup.definitions.Armors[0].id == 3, "test IDs follow database array without filling original holes")
		_expect(setup.definitions.Skills.size() == 3 and setup.definitions.Skills[0].size() == 25, "all 25 standard skill fields retained in test fixture")
		_expect(setup.definitions.Skills[0].animation1_id == setup.definitions.Skills[1].animation1_id and setup.definitions.Skills[2].animation1_id == 0, "skills support shared and empty animation references")
		_expect(setup.definitions.Animations[0].id == 3 and setup.learn_skills.map(func(id: Variant) -> int: return int(id)) == [3, 4, 5], "separate noncolliding skill and animation overlays")
		_expect(setup.schema_version == 3 and setup.initial_gold == 2000 and setup.shop_goods.size() == 9, "shop test config prepares currency and goods")
		_expect(setup.definitions.States.size() == 2 and setup.definitions.States[0].size() == 28 and setup.definitions.States[0].id == 3, "state overlay retains 28 standard fields without overwriting source")
		_expect(setup.definitions.Items[0].price == 100 and setup.definitions.Weapons[0].price == 200, "test goods have database prices")
	for database in ["Items", "Weapons", "Armors"]:
		_expect(FileAccess.get_file_as_string(root.path_join("data/database/%s.json" % database)) == original, "generator does not rewrite database " + database)


func _test_table_decoder() -> void:
	var payload := PackedByteArray()
	for value in [3, 2, 1, 1, 2]:
		_append_i32(payload, value)
	payload.append_array(PackedByteArray([7, 0, 9, 0]))
	var table: Variant = RmxpTableDecoder.decode({
		"_rmxp_user_defined": "Table",
		"payload": payload
	})
	_expect(table.get("x_size", 0) == 2, "Table width should decode")
	_expect(table.get("values", []) == [7, 9], "Table cells should decode")


func _test_asset_safety() -> void:
	var root := ProjectSettings.globalize_path("res://.godot/asset_safety_%d" % Time.get_ticks_usec())
	var source := root.path_join("source")
	var destination := root.path_join("output")
	DirAccess.make_dir_recursive_absolute(source.path_join("Graphics/Icons"))
	DirAccess.make_dir_recursive_absolute(source.path_join("Audio/SE"))
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	var bytes := image.save_png_to_buffer()
	for name in ["icon.jpg", "icon.png"]:
		var file := FileAccess.open(source.path_join("Graphics/Icons/" + name), FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	var bad_mp3 := FileAccess.open(source.path_join("Audio/SE/invalid.mp3"), FileAccess.WRITE)
	bad_mp3.store_buffer(PackedByteArray([1, 2, 3, 4]))
	bad_mp3.close()
	var copier := AssetCopier.new()
	var result := copier.copy(source, destination)
	_expect(result.errors.is_empty(), "asset safety preserves data without copy errors")
	_expect(result.asset_index["Graphics/Icons/icon.jpg"].ends_with(".png"), "mislabeled image gets correct output extension")
	_expect(result.asset_index["Graphics/Icons/icon.jpg"] != result.asset_index["Graphics/Icons/icon.png"], "image correction never overwrites sibling")
	_expect(FileAccess.get_file_as_bytes(source.path_join("Graphics/Icons/icon.jpg")) == bytes, "image correction leaves source unchanged")
	_expect(not result.asset_index.has("Audio/SE/invalid") and FileAccess.file_exists(destination.path_join("legacy/unsupported_assets/Audio/SE/invalid.mp3")), "bad MP3 isolated and preserved, not indexed")
	Generator.new().generate(destination, "Fixture", {})
	var config := ConfigFile.new()
	config.load(destination.path_join("project.godot"))
	_expect(config.get_value("editor", "import/use_multiple_threads", true) == false, "new projects use safe serial editor import")


func _test_sample_preflight() -> void:
	var repository_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var samples_root := repository_root.path_join("rm_template")
	var validator := RmxpValidator.new()
	for project_name in ["魔塔样板7630·改", "小蛋挞(读1号存档即可)"]:
		var project_path := samples_root.path_join(project_name)
		_expect(DirAccess.dir_exists_absolute(project_path), "sample should exist: %s" % project_name)
		if not DirAccess.dir_exists_absolute(project_path):
			continue
		var result := validator.preflight(project_path, OS.get_user_data_dir(), 936)
		_expect(result.get("ok", false), "preflight should accept sample: %s" % project_name)
		_expect(not result.get("map_files", []).is_empty(), "sample should contain maps: %s" % project_name)


func _test_full_sample_migration() -> void:
	var repository_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var temporary_export := ProjectSettings.globalize_path("res://.godot/test_exports_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temporary_export)
	for sample in ["魔塔样板7630·改", "小蛋挞(读1号存档即可)"]:
		_migrate_sample(repository_root.path_join("rm_template").path_join(sample), temporary_export)


func _migrate_sample(source_path: String, temporary_export: String) -> void:
	print("Migrating: ", source_path)
	var preflight := RmxpValidator.new().preflight(source_path, temporary_export, 936)
	_expect(preflight.get("ok", false), "full migration preflight should pass")
	if not preflight.get("ok", false):
		return
	var result := MigrationPipeline.new().run(preflight)
	_expect(result.get("ok", false), "full migration should complete")
	if result.get("ok", false):
		var output_path := str(result.get("output_path", ""))
		_exports.append(output_path)
		print("EXPORTED: ", output_path)
		_expect(FileAccess.file_exists(output_path.path_join("project.godot")), "generated project.godot should exist")
		_expect(FileAccess.file_exists(output_path.path_join("runtime/scripts/Game.gd")), "runtime path must match scene and autoload paths")
		_expect(FileAccess.file_exists(output_path.path_join("data/manifest.json")), "generated manifest should exist")
		_expect(FileAccess.file_exists(output_path.path_join("migration_report.md")), "generated report should exist")
		var test_setup: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path.path_join("data/test_setup.json")))
		_expect(test_setup is Dictionary and test_setup.get("enabled", false) and test_setup.get("stock", []).size() == 9, "generated test setup contains nine separate supplies")
		var report: Dictionary = result["report"]
		_expect(report["maps"] == preflight["map_files"].size(), "all source maps must be exported")
		_expect(int(report["assets"]) == int(preflight["graphics_count"]) + int(preflight["audio_count"]), "all non-RTP assets must be copied")
		_expect(int(report["scripts"]) > 0, "Ruby scripts must be retained")
		for warning in report["warnings"]:
			_expect(not str(warning).contains("无法解析"), str(warning))
		var system: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path.path_join("data/system.json")))
		_expect(system is Dictionary and system.get("_class", "") == "RPG::System", "System must be decoded")
		if system is Dictionary:
			if source_path.contains("魔塔样板"):
				_expect(system.get("variables", [])[1] == "主战角色编号", "database UTF-8 text must not become GBK mojibake")
			var map_path := output_path.path_join("data/maps/Map%03d.json" % int(system.get("start_map_id", 0)))
			_expect(FileAccess.file_exists(map_path), "starting map must exist")
			if FileAccess.file_exists(map_path):
				var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_path))
				_expect(map.get("data", {}).get("_rmxp_type", "") == "table", "actual map Table must decode")
				_expect(map.get("data", {}).get("values", []).size() == int(map["width"]) * int(map["height"]) * 3, "actual map cell count must match dimensions")
		_expect(not RmxpValidator.new().preflight(source_path, temporary_export, 936).get("ok", true), "nonempty export directory must be refused")
		print("COUNTS: maps=%s data=%s assets=%s scripts=%s" % [report["maps"], report["data_files"], report["assets"], report["scripts"]])


func _test_codecs() -> void:
	var gbk := RmxpTextCodec.new(936)
	_expect(gbk.decode(PackedByteArray([0xd6, 0xd0, 0xb9, 0xfa])) == "中国", "GBK must decode Chinese")
	_expect(gbk.error_message.is_empty(), gbk.error_message)
	_expect(gbk.decode("中文数据库".to_utf8_buffer()) == "中文数据库", "UTF-8 database text must decode without mojibake")
	var sjis := RmxpTextCodec.new(932)
	_expect(sjis.decode(PackedByteArray([0x93, 0xfa, 0x96, 0x7b, 0xa6])) == "日本ｦ", "Shift-JIS must decode kanji and halfwidth kana")
	_expect(sjis.error_message.is_empty(), sjis.error_message)


func _test_marshal_links_and_errors() -> void:
	var reader := RmxpMarshalReader.new(RmxpTextCodec.new(936))
	# Array is object 0, float is object 1, string is object 2.
	var value: Variant = reader.read_bytes(PackedByteArray([4, 8, 91, 9, 102, 8, 49, 46, 53, 64, 6, 34, 6, 65, 64, 7]))
	_expect(not reader.failed and value[0] == value[1] and value[2] == value[3], "float and string object links must retain Marshal numbering")
	reader.read_bytes(PackedByteArray([4, 8, 34, 10]))
	_expect(reader.failed, "truncated Marshal must fail explicitly")
	var raw := PackedByteArray([4, 8, 117, 58, 10, 84, 97, 98, 108, 101, 27])
	for cell in [1, 1, 1, 1, 1]:
		_append_i32(raw, cell)
	raw.append_array(PackedByteArray([255, 255]))
	var table: Variant = RmxpTableDecoder.decode(reader.read_bytes(raw))
	_expect(not reader.failed and table.get("values", []) == [-1], "actual Marshal u tag must decode signed RGSS Table cells")


func _test_converter_diagnostics() -> void:
	var converter := RmxpDataConverter.new(RmxpTextCodec.new(936))
	converter._scan_command_list([{"code": 209, "parameters": []}, {"code": 111, "parameters": [12, "Ruby"]}, {"code": 121, "parameters": [1, 1, 0]}], "Map001", "7", 2)
	_expect(converter.unsupported_commands.size() == 2, "unsupported routes and Ruby conditions must be reported")
	_expect(converter.unsupported_commands[0]["command_index"] == 1, "diagnostic command numbers must be one-based")
	converter._scan_command_list([{"code": 318, "parameters": [1, 0, 1]}, {"code": 207, "parameters": [-1, 1]}, {"code": 111, "parameters": [4, 1, 2, 1]}, {"code": 111, "parameters": [4, 1, 3, 1]}], "Map002", "8", 1)
	_expect(converter.unsupported_commands.size() == 2, "all non-battle actor conditions are supported")
	converter.unsupported_commands.clear()
	converter._scan_command_list([{"code": 106, "parameters": [20]}, {"code": 116}, {"code": 106, "parameters": [1.5]}, {"code": 301}, {"code": 209, "parameters": [0, {"list": [{"code": 15}, {"code": 45}, {"code": 0}]}]}], "CommonEvents", "3", 1)
	_expect(converter.unsupported_commands.size() == 5, "catalog supports wait/erase and scans unsupported nested routes")
	_expect(converter.unsupported_commands[1].reason.contains("不在迁移范围"), "report explicitly excludes turn-based battle")
	_expect(converter.unsupported_commands[-1].route_index == 2 and converter.unsupported_commands[-1].route_code == 45, "nested script location retains route command index")
	converter.unsupported_commands.clear()
	var native_wait := {"code": 15, "parameters": [20]}
	var native_route := {"repeat": false, "skippable": true, "list": [native_wait, {"code": 0}]}
	converter._scan_command_list([
		{"code": 201, "parameters": [0, 1, 2, 3, 6, 1]},
		{"code": 202, "parameters": [0, 2, -1, 0, 8]},
		{"code": 208, "parameters": [0]},
		{"code": 209, "parameters": [-1, native_route]},
		{"code": 509, "parameters": [native_wait]},
		{"code": 210, "parameters": []}
	], "Map003", "9", 2)
	_expect(converter.unsupported_commands.is_empty(), "native movement commands and509 display copies must not be reported as unsupported")
	converter._scan_map_commands({"events": {"9": {"pages": [{"move_route": native_route, "list": []}]}}}, "Map003")
	_expect(converter.unsupported_commands.is_empty(), "native autonomous page route must remain supported")
	converter._scan_map_commands({"events": {"9": {"pages": [{"move_route": {"list": [{"code": 45, "parameters": ["Ruby"]}]}, "list": []}]}}}, "Map003")
	_expect(converter.unsupported_commands.size() == 1 and converter.unsupported_commands[0].command_index == 0 and converter.unsupported_commands[0].route_index == 1, "autonomous Ruby exclusion must retain page route location")
	converter._scan_command_list([{"code": 209, "parameters": {"bad": true}}], "Map004", "1", 1)
	_expect(converter.unsupported_commands.size() == 2 and converter.unsupported_commands[-1].reason.contains("数组"), "non-array event parameters must produce a diagnostic without crashing")
	var channels := PackedByteArray(); channels.resize(32)
	for index in 4: channels.encode_double(index * 8, [20.0, 30.0, 40.0, 100.0][index])
	var native_tone: Dictionary = converter._convert_value({"_rmxp_user_defined": "Tone", "payload": channels})
	var native_color: Dictionary = converter._convert_value({"_rmxp_user_defined": "Color", "payload": channels})
	_expect(native_tone.gray == 100 and native_color.alpha == 100 and not native_tone.has("alpha"), "native Marshal Tone and Color keep distinct fourth channels")
	converter.unsupported_commands.clear()
	converter._scan_command_list([
		{"code": 221, "parameters": []}, {"code": 222, "parameters": [""]},
		{"code": 223, "parameters": [native_tone, 20]}, {"code": 224, "parameters": [native_color, 20]},
		{"code": 225, "parameters": [5, 4, 20]}, {"code": 231, "parameters": [1, "picture", 0, 0, 10, 20, 100, 100, 255, 0]},
		{"code": 232, "parameters": [1, 20, 1, 1, 41, 42, 150, 100, 128, 2]}, {"code": 233, "parameters": [1, -2]},
		{"code": 234, "parameters": [1, native_tone, 20]}, {"code": 235, "parameters": [1]}, {"code": 236, "parameters": [3, 9, 20]}
	], "Map005", "3", 1)
	_expect(converter.unsupported_commands.is_empty(), "all native screen commands including converted Tone/Color are supported in migration report")
	converter._convert_value({"_rmxp_user_defined": "Table", "payload": PackedByteArray([0])})
	_expect(not converter.errors.is_empty(), "invalid Table must become a migration error")


func _append_i32(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 24) & 0xff)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

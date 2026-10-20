## 职责：回归验证：0.59命名兼容、旧定义指纹、程序生成碎屏素材和真实演出生命周期。
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
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree

const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Paths = preload("res://runtime/scripts/10_Support/Scripting/ScriptPaths.gd")
var checks = 0
var failures: Array[String] = []
var captures = 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(640, 640)
	root.content_scale_size = Vector2i(640, 640)
	var layout = Data.read_json("res://data/script_layout.json", {})
	for old in layout.get("legacy_runtime_aliases", {}):
		var path = "res://runtime/scripts/" + str(layout.legacy_runtime_aliases[old])
		expect(Paths.runtime(old) == path and FileAccess.file_exists(path), "old navigation name resolves current script: " + old)
	for path in layout.runtime.values():
		expect(not str(path).get_file().begins_with("Flash"), "runtime filename sorted by its actual function")
	var saves = load("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
	expect(saves.fingerprint() == "6bd0e10f60f79b11a5f6206b465d82fa0f5342aaa3832f3786a8f163a7d80eb1", "filename cleanup preserves original definition fingerprint")
	_check_catalog_alias(saves)
	var state = root.get_node("RuntimeState")
	state.flash_preferences.apply_display = false
	state.begin_new_game(Data.system(), {"enabled": false})
	state.map_id = 23
	state.party = [2]
	state.variables["14"] = [2, 0]
	state.player_x = 9
	state.player_y = 6
	var game = load("res://runtime/scripts/10_Support/Boot/Game.gd").new()
	game._events_enabled = false
	root.add_child(game)
	await process_frame
	game.reset_event_execution()
	game.set_process(false)
	game._player.set_process(false)
	var model = state.flash_effects
	var view = model._view.get_ref()
	view.set_process(false)
	var texture = model._broken_texture("sptx.png")
	expect(texture != null and texture.get_size() == Vector2(480, 480), "missing default uses generated480px mask")
	expect(is_same(texture, model._broken_texture("sptx")), "both default spellings share one immutable asset")
	expect(model._broken_texture("__missing_custom_mask_v059.png") == null, "unknown custom missing filenames have no fallback")
	var original = load("res://runtime/scripts/10_Support/Cache/RmxpCache.gd").picture("Causal/文本记录1.png")
	expect(original != null and is_same(original, model._broken_texture("Causal/文本记录1.png")), "available original asset takes precedence")
	var mask = texture.get_image()
	var labels: Dictionary = {}
	for y in mask.get_height():
		for x in mask.get_width():
			var pixel = mask.get_pixel(x, y)
			labels[pixel.r8] = true
			if pixel.r8 != pixel.g8 or pixel.g8 != pixel.b8 or pixel.a8 != 255:
				failures.append("mask has non-grayscale or transparent pixels")
	expect(labels.size() == 36, "mask has exactly36 opaque discrete labels")
	var mask_bytes = mask.get_data()
	var actor = state.actor(2)
	var party = state.party.duplicate()
	var gold = state.gold
	if DisplayServer.get_name() == "headless":
		model.test_capture = Image.create(640, 640, false, Image.FORMAT_RGBA8)
		model.test_capture.fill(Color(0.2, 0.5, 0.8))
	var request = game.play_flash_effect("broken", ["sptx.png"])
	expect(request.get("ok", false), "actual game effect accepts generated default")
	# The production coordinator captures after frame_post_draw on real GPU.
	var deadline = Time.get_ticks_msec() + 15000
	while model.broken == null and Time.get_ticks_msec() < deadline:
		model.advance(1.0 / 60)
		await process_frame
	expect(model.broken != null and not model.broken.shards.is_empty(), "actual screenshot is split into moving fragments")
	if model.broken != null:
		expect(model.broken.shards.size() <= 36, "fragment allocation bounded by labels")
		await _capture("broken-start")
		model.advance(20.0 / 60)
		await _capture("broken-middle")
		model.advance(90.0 / 60)
		await _capture("broken-finish")
		expect(model.broken == null and not model.busy() and model.status(request.flash_effect_request).ok, "effect completes original90 ticks and releases fragments")
	expect(mask.get_data() == mask_bytes, "shared mask stays immutable")
	expect(is_same(state.actor(2), actor) and state.party == party and state.gold == gold, "visual effect retains authoritative actor and gameplay state")
	game.queue_free()
	await process_frame
	for message in failures:
		printerr("FAIL: ", message)
	print("INTEGRATION V059: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks / ", captures, " GPU states")
	quit(0 if failures.is_empty() else 1)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	expect(image != null and image.save_png("res://.godot/v059-" + label + ".png") == OK, "actual GPU " + label)
	captures += 1


func _check_catalog_alias(saves: Script) -> void:
	var source = FileAccess.get_file_as_string("res://data/flash_gameplay.json")
	var old = source.replace("res://runtime/generated/skill_catalog.gd", "res://runtime/generated/flash_skill_catalog.gd")
	var path = "res://.godot/v059_catalog_alias.json"
	_write_alias_fixture(path, source)
	var canonical = saves._gameplay_definition_hash(path)
	_write_alias_fixture(path, old)
	expect(saves._gameplay_definition_hash(path) == canonical, "exact generated catalog navigation rename preserves its definition hash")
	_write_alias_fixture(path, source.replace('"editable": true', '"editable": false'))
	expect(saves._gameplay_definition_hash(path) != canonical, "other catalog metadata remains part of the full hash")
	_write_alias_fixture(path, source.replace("res://runtime/generated/skill_catalog.gd", "res://runtime/generated/custom_catalog.gd"))
	expect(saves._gameplay_definition_hash(path) != canonical, "unregistered catalog paths are not normalized")


func _write_alias_fixture(path: String, source: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

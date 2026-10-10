extends Node2D

const MapRuntime = preload("res://runtime/scripts/MapRuntime.gd")
const PlayerController = preload("res://runtime/scripts/PlayerController.gd")
const EventInterpreter = preload("res://runtime/scripts/EventInterpreter.gd")
const DialogueOverlay = preload("res://runtime/scripts/DialogueOverlay.gd")
const MenuCoordinator = preload("res://runtime/scripts/MenuCoordinator.gd")
const ScreenRenderer = preload("res://runtime/scripts/ScreenRenderer.gd")
const CameraRig = preload("res://runtime/scripts/MapCamera.gd")
const EffectsRenderer = preload("res://runtime/scripts/MapEffectsRenderer.gd")
const Transition = preload("res://runtime/scripts/TransitionRenderer.gd")

var _map: MapRuntime
var _player: PlayerController
var _interpreter: EventInterpreter
var _dialogue: DialogueOverlay
var _menus: CanvasLayer
var _test_label: Label
var _screen_renderer: Node
var _camera: Camera2D
var _effects: Node
var _transition: CanvasLayer
var _scheduler: RefCounted
var _event_ui: RefCounted
var _events_enabled := true
var _event_lab_backup: Dictionary = {}
var _event_lab_hud: CanvasLayer
var _transfer_serial := 0
var _transfer_active := 0
var _transfer_results: Dictionary = {}
var _transfer_revealing := false
var _scene_serial := 0
var _scene_pending := false
var _screen_serial := 0
var _screen_active := 0
var _screen_results: Dictionary = {}
var _screen_revealing := false
var _screen_frozen_request := 0


func _ready() -> void:
	RuntimeState.register_game(self)
	_map = MapRuntime.new()
	add_child(_map)
	_player = PlayerController.new()
	_map.ensure_character_layer().add_child(_player)
	_player.configure(_map)
	_map.player_character = _player
	var camera := CameraRig.new()
	camera.model = RuntimeState.map_view
	camera.map = _map
	camera.player = _player
	add_child(camera)
	_camera = camera
	get_viewport().size_changed.connect(_update_camera_limits)
	_screen_renderer = ScreenRenderer.new()
	_screen_renderer.camera = camera
	add_child(_screen_renderer)
	_effects = EffectsRenderer.new()
	_effects.map = _map
	_effects.camera = camera
	_effects.model = RuntimeState.map_effects
	_effects.view_model = RuntimeState.map_view
	_effects.timer_model = RuntimeState.timer
	_effects.screen_model = RuntimeState.screen
	add_child(_effects)
	_transition = Transition.new()
	add_child(_transition)
	_dialogue = DialogueOverlay.new()
	add_child(_dialogue)
	_scheduler = preload("res://runtime/scripts/EventScheduler.gd").new()
	_scheduler.configure(_map)
	_interpreter = _scheduler.main
	_event_ui = preload("res://runtime/scripts/EventUIBroker.gd").new()
	_event_ui.bind_interpreter(_interpreter)
	_scheduler.interpreter_created.connect(_event_ui.bind_interpreter)
	_scheduler.main_completed.connect(_on_event_completed)
	_event_ui.terminal_requested.connect(request_event_scene)
	_event_ui.requested.connect(_present_event_ui)
	_event_ui.dismissed.connect(_dismiss_event_ui)
	_dialogue.event_response.connect(_event_response)
	_dialogue.closed.connect(_sync_event_input)
	_map.event_requested.connect(_start_event)
	_map.map_changed.connect(_map_loaded)
	_map.trigger_allowed = _can_trigger_event
	RuntimeState.execution_reset.connect(reset_event_execution)
	_menus = MenuCoordinator.new()
	_menus.game = self
	add_child(_menus)
	if RuntimeState.testing_enabled:
		var badge := CanvasLayer.new()
		badge.layer = 10
		add_child(badge)
		_test_label = Label.new()
		_test_label.text = "测试模式 · Esc/X 菜单 → F6 测试工具（含人物与地图）"
		_test_label.position = Vector2(12, 8)
		_test_label.add_theme_color_override("font_color", Color("ffe9a8"))
		_test_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		badge.add_child(_test_label)
	if not _map.load_map(RuntimeState.map_id):
		_show_diagnostic("无法载入起始地图 Map%03d。" % RuntimeState.map_id)
		return
	if RuntimeState.resume_from_save:
		if RuntimeState.pending_event_state.is_empty(): _scheduler.suppress_loaded_autoruns()
		else: restore_event_state()
		RuntimeState.resume_from_save = false
		_player.resume_after_menu()
	else:
		call_deferred("_start_autorun")


func can_save() -> bool:
	return _player.is_idle() and (not RuntimeState.save_disabled or event_save_override()) and event_save_reason().is_empty() and not _dialogue.is_open() and _menus.shop == null and _menus.menu != null and _menus.menu.page == "save"

func event_save_override() -> bool:
	return not _event_ui.active.is_empty() and _event_ui.active.kind == "save" and _event_ui._valid(_event_ui.active)

func capture_event_state() -> Dictionary:
	if _map == null or _map.map_data.is_empty() or _map._loaded_id != RuntimeState.map_id: return {}
	return preload("res://runtime/scripts/EventPersistence.gd").capture(self)

func restore_event_state() -> void:
	if RuntimeState.pending_event_state.is_empty(): return
	if _map._loaded_id != RuntimeState.map_id and not _map.load_map(RuntimeState.map_id):
		_show_diagnostic("无法恢复存档地图。")
		return
	preload("res://runtime/scripts/EventPersistence.gd").restore(self, RuntimeState.pending_event_state)
	RuntimeState.pending_event_state.clear()
	RuntimeState.resume_from_save = false

func _process(delta: float) -> void:
	if _scene_pending: return
	if _screen_active > 0 and _screen_revealing and not _transition.busy and _transition.remaining <= 0:
		_record_screen_transition({"id": _screen_active, "ok": true, "pending": false})
		_screen_active = 0
		_screen_revealing = false
	if _transfer_active > 0 and _transfer_revealing and not _transition.busy and _transition.remaining <= 0:
		_record_transfer({"id": _transfer_active, "ok": true, "pending": false})
		_transfer_active = 0
		_transfer_revealing = false
	if _camera != null and _camera.model != RuntimeState.map_view:
		_camera.model = RuntimeState.map_view
		_effects.view_model = RuntimeState.map_view
		_effects.model = RuntimeState.map_effects
		_effects.timer_model = RuntimeState.timer
		_effects.screen_model = RuntimeState.screen
		RuntimeState.map_effects.setup_map(RuntimeState.map_id, _map.tileset)
		_camera.sync(0)
	if _events_enabled and not event_screen_transition_active():
		_scheduler.advance(delta, not _event_ui.busy() and _menus.menu == null and _menus.shop == null and not _dialogue.is_open())
	_event_ui.pump(event_ui_available())
	_sync_event_input()


func event_save_reason() -> String:
	if _scene_pending: return "场景切换尚未结束。"
	if not _event_lab_backup.is_empty(): return "事件验收地图不写入正式存档；请先退出验收地图。"
	if _map._loaded_id != RuntimeState.map_id: return "脱离数据库的测试地图不能写入正式存档。"
	if _transfer_active > 0: return "场所移动尚未结束。"
	if _screen_active > 0 or _transition.busy or _transition.frozen != null or _transition.remaining > 0: return "瞬时截图/过渡尚未释放，不能写入存档。"
	for owner in [_scheduler.main] + _scheduler.parallels.values().map(func(entry: Dictionary) -> RefCounted: return entry.owner):
		if owner.running and owner.wait_kind() in ["scene", "transfer", "transfer_ready", "screen_ready", "screen_transition"]: return "事件正在传送或切换画面，请等待完成后存档。"
	return ""


func event_map() -> Node:
	return _map


func event_transfer_ready() -> bool:
	return _transfer_active == 0 and _screen_active == 0 and not _transition.busy and _transition.remaining <= 0 and not _dialogue.is_open() and _menus.menu == null and _menus.shop == null and _menus.name_input == null and not _scene_pending


func event_ui_available() -> bool:
	if _scene_pending or _menus == null or _menus.menu != null or _menus.shop != null or _menus.name_input != null or RuntimeState.map_time_paused(): return false
	# RM messages can appear during motion; scene pages wait for its completion.
	return _player.is_idle() or _event_ui.next_kind() not in ["menu", "name", "shop", "save"]

func event_scene_transition_active() -> bool: return _scene_pending

func request_event_scene(kind: String) -> void:
	if kind not in ["title", "gameover"] or _scene_pending: return
	reset_event_execution()
	if _menus.menu != null: _menus.close_menu()
	if _menus.shop != null: _menus.close_shop()
	if _menus.name_input != null: _menus.close_name()
	_scene_pending = true
	_events_enabled = false
	RuntimeState.playing = false
	_player.input_enabled = false
	var serial := _scene_serial
	call_deferred("_switch_event_scene", serial, kind)

func _switch_event_scene(serial: int, kind: String) -> void:
	if not is_inside_tree() or not _scene_pending or serial != _scene_serial: return
	var path := "res://scenes/Title.tscn" if kind == "title" else "res://scenes/Gameover.tscn"
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		_scene_pending = false
		_events_enabled = true
		RuntimeState.playing = true
		_show_diagnostic("场景切换失败：%s（%d）" % [path, result])

func scroll_event_map(direction: int, tiles: int, speed: int) -> Dictionary:
	if _camera == null or _map == null: return {"ok": false, "message": "地图镜头尚未就绪。"}
	return RuntimeState.map_view.scroll_native(direction, tiles, speed, Vector2(_map.map_width(), _map.map_height()) * 32, get_viewport_rect().size)

func event_screen_transition_active() -> bool:
	return _screen_active > 0


func event_screen_transition_ready() -> bool:
	return event_transfer_ready() and not _event_ui.busy()


func begin_event_screen_transition(code: int, name_value: String = "") -> Dictionary:
	if code not in [221, 222]: return {"ok": false, "message": "画面过渡指令无效。"}
	if code == 222 and not name_value.is_empty() and preload("res://runtime/scripts/RmxpCache.gd").transition(name_value) == null: return {"ok": false, "message": "Transitions素材缺失：%s；原画面保持，不补取RTP。" % name_value}
	if not event_screen_transition_ready(): return {"ok": false, "busy": true, "message": "其他过渡、场所移动或界面未结束。"}
	_screen_serial += 1
	_screen_active = _screen_serial
	call_deferred("_perform_screen_transition", _screen_active, code, name_value)
	_sync_event_input()
	return {"ok": true, "id": _screen_active}


func event_screen_transition_status(id: int) -> Dictionary:
	if id == _screen_active: return {"ok": true, "pending": true}
	if _screen_results.has(id): return _screen_results[id].duplicate()
	return {"ok": false, "pending": false, "message": "画面过渡已取消或请求已过期。"}


func cancel_event_screen_transition(id: int = 0) -> void:
	if id != 0 and id != _screen_active and id != _screen_frozen_request: return
	if _screen_active > 0:
		_record_screen_transition({"id": _screen_active, "ok": false, "pending": false, "message": "画面过渡已取消。"})
	_screen_active = 0
	_screen_revealing = false
	_screen_frozen_request = 0
	if _transition != null: _transition.cancel()


func _record_screen_transition(result: Dictionary) -> void:
	_screen_results[int(result.id)] = result
	if _screen_results.size() > 32:
		var keys := _screen_results.keys(); keys.sort()
		_screen_results.erase(keys[0])


func _perform_screen_transition(id: int, code: int, name_value: String) -> void:
	if id != _screen_active: return
	if _transition.frozen == null:
		var result: Dictionary = await _transition.freeze_screen()
		if not is_inside_tree() or id != _screen_active: return
		if not result.ok:
			_record_screen_transition({"id": id, "ok": false, "pending": false, "message": result.message})
			_screen_active = 0
			return
	if code == 221:
		_screen_frozen_request = id
		_record_screen_transition({"id": id, "ok": true, "pending": false})
		_screen_active = 0
		return
	var result: Dictionary = _transition.transition(0.5 if name_value.is_empty() else 1.0, name_value)
	if not result.ok:
		_record_screen_transition({"id": id, "ok": false, "pending": false, "message": result.message})
		_screen_active = 0
		return
	_screen_frozen_request = 0
	_screen_revealing = true


func begin_event_transfer(map_id: int, x: int, y: int, direction: int, fade: bool) -> Dictionary:
	var candidate := preload("res://runtime/scripts/RuntimeData.gd").map(map_id)
	if direction not in [0, 2, 4, 6, 8] or x < 0 or y < 0 or x >= int(candidate.get("width", 0)) or y >= int(candidate.get("height", 0)):
		return {"ok": false, "message": "传送地图、坐标或方向无效，未换图。"}
	if not event_transfer_ready(): return {"ok": false, "busy": true, "message": "其他场所移动、消息或过渡未结束。"}
	_transfer_serial += 1
	_transfer_active = _transfer_serial
	call_deferred("_perform_event_transfer", _transfer_active, map_id, x, y, direction, fade)
	_sync_event_input()
	return {"ok": true, "id": _transfer_active}


func event_transfer_status(id: int) -> Dictionary:
	if id == _transfer_active: return {"ok": true, "pending": true}
	if _transfer_results.has(id): return _transfer_results[id].duplicate()
	return {"ok": false, "pending": false, "message": "场所移动已取消或请求已过期。"}


func _record_transfer(result: Dictionary) -> void:
	_transfer_results[int(result.id)] = result
	if _transfer_results.size() > 32:
		var keys := _transfer_results.keys()
		keys.sort()
		_transfer_results.erase(keys[0])


func cancel_event_transfer() -> void:
	if _transfer_active <= 0: return
	_record_transfer({"id": _transfer_active, "ok": false, "pending": false, "message": "场所移动已取消。"})
	_transfer_active = 0
	_transfer_revealing = false
	if _transition != null: _transition.cancel()


func _perform_event_transfer(id: int, map_id: int, x: int, y: int, direction: int, fade: bool) -> void:
	if id != _transfer_active: return
	if fade and _transition.frozen == null:
		var frozen: Dictionary = await _transition.freeze_screen()
		if id != _transfer_active or not is_inside_tree(): return
		if not frozen.ok:
			_record_transfer({"id": id, "ok": false, "pending": false, "message": frozen.message})
			_transfer_active = 0
			return
	if id != _transfer_active: return
	if not _map.transfer(map_id, x, y, direction):
		_record_transfer({"id": id, "ok": false, "pending": false, "message": "传送失败，未换图。"})
		_transfer_active = 0
		if fade: _transition.cancel()
		return
	_update_camera_limits()
	if fade:
		_screen_frozen_request = 0
		var result: Dictionary = _transition.transition(0.5)
		if not result.ok:
			_record_transfer({"id": id, "ok": false, "pending": false, "message": result.message})
			_transfer_active = 0
			_transition.cancel()
			return
		_transfer_revealing = true
	else:
		_record_transfer({"id": id, "ok": true, "pending": false})
		_transfer_active = 0


func reset_event_execution() -> void:
	_scene_serial += 1
	_scene_pending = false
	_events_enabled = false
	cancel_event_transfer()
	cancel_event_screen_transition()
	if _map != null: _map.cancel_character_routes()
	if _player != null: _player.reset_route_state()
	if _scheduler != null: _scheduler.cancel_all()
	if _event_ui != null: _event_ui.cancel_all()


func enter_event_test_map() -> Dictionary:
	if not RuntimeState.testing_enabled or not _event_lab_backup.is_empty() or _interpreter.running or _event_ui.busy() or not _player.is_idle() or _player.routes.has_runtime_state() or _transfer_active > 0 or _transition.busy or _transition.frozen: return {"ok": false, "message": "请在测试模式的空闲地图进入事件验收。"}
	var codec := preload("res://runtime/scripts/SaveCodec.gd")
	var backup: Dictionary = codec.prepare(codec.capture(RuntimeState))
	if not backup.ok: return backup
	# Keep the original map and interpreters paused in memory, including erasures
	# and parallel stacks that schema 1 cannot serialize.
	_event_lab_backup = {"state": backup, "map": _map, "scheduler": _scheduler, "diagnostics": RuntimeState.diagnostics.duplicate()}
	_map.process_mode = Node.PROCESS_MODE_DISABLED
	_map.hide()
	var fixture := preload("res://runtime/scripts/EventFixture.gd").build()
	_map = MapRuntime.new()
	add_child(_map)
	_player.reparent(_map.ensure_character_layer())
	_player.configure(_map)
	_map.player_character = _player
	_map.event_requested.connect(_start_event)
	_map.map_changed.connect(_map_loaded)
	_map.trigger_allowed = _can_trigger_event
	_camera.map = _map
	_effects.map = _map
	_map.load_definition(fixture.map, fixture.tileset)
	RuntimeState.switches = {}
	RuntimeState.variables = {}
	RuntimeState.self_switches = {}
	RuntimeState.set_event_switch(9008, true)
	RuntimeState.player_motion.relocate(Vector2i(5, 6))
	_player.set_graphic("@movement_character")
	_player._sync_position()
	_scheduler = preload("res://runtime/scripts/EventScheduler.gd").new()
	_scheduler.configure(_map, fixture.common_events)
	_interpreter = _scheduler.main
	_event_ui.bind_interpreter(_interpreter)
	_scheduler.interpreter_created.connect(_event_ui.bind_interpreter)
	_scheduler.main_completed.connect(_on_event_completed)
	RuntimeState.configure_map_effects({"panorama_name": "", "fog_name": ""})
	var size := get_viewport_rect().size
	RuntimeState.configure_map_view({"view_rect": [0, 156, size.x, size.y - 156], "follow_center": [], "follow_enabled": true})
	_update_camera_limits()
	_event_lab_hud = preload("res://runtime/scripts/EventTestHUD.gd").new()
	_event_lab_hud.game = self
	_event_lab_hud.back_requested.connect(exit_event_test_map)
	add_child(_event_lab_hud)
	if _test_label != null: _test_label.hide()
	_events_enabled = true
	return {"ok": true}


func start_event_test_scenario(name: String) -> Dictionary:
	if _event_lab_backup.is_empty() or _interpreter.running or _event_ui.busy() or _menus.menu != null or not _player.is_idle(): return {"ok": false, "message": "请先完成当前事件。"}
	if name not in ["flow", "input"]: return {"ok": false, "message": "未知验收流程。"}
	_scheduler.start_main(preload("res://runtime/scripts/EventFixture.gd").scenario(name), 0)
	_event_ui.pump(event_ui_available())
	_sync_event_input()
	return {"ok": true}


func exit_event_test_map() -> void:
	if _event_lab_backup.is_empty() or _interpreter.running or _event_ui.busy() or _menus.menu != null or _menus.shop != null: return
	reset_event_execution()
	_scheduler.dispose()
	var backup := _event_lab_backup
	_event_lab_backup = {}
	var fixture_map := _map
	_map = backup.map
	_player.reparent(_map.ensure_character_layer())
	_player.configure(_map)
	_map.player_character = _player
	_camera.map = _map
	_effects.map = _map
	RuntimeState.restore_prepared(backup.state, true)
	RuntimeState.diagnostics.assign(backup.diagnostics)
	RuntimeState.resume_from_save = false
	_scheduler = backup.scheduler
	_interpreter = _scheduler.main
	fixture_map.queue_free()
	_map.process_mode = Node.PROCESS_MODE_INHERIT
	_map.show()
	_update_camera_limits()
	_player._graphic_signature = ""
	_player._refresh_graphic()
	_player._sync_position()
	remove_child(_event_lab_hud)
	_event_lab_hud.queue_free()
	_event_lab_hud = null
	if _test_label != null: _test_label.show()
	_events_enabled = true
	_player.resume_after_menu()


func save_slot(slot: int) -> Dictionary:
	if not can_save():
		return {"ok": false, "message": event_save_reason() if not event_save_reason().is_empty() else "当前禁止存档，或事件/对话尚未结束。"}
	RuntimeState.player_direction = {Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 6, Vector2i.UP: 8}[_player.facing]
	var result: Dictionary = preload("res://runtime/scripts/SaveService.gd").save_slot(slot, RuntimeState)
	if result.ok and event_save_override(): _menus.call_deferred("close_menu")
	return result


func _start_autorun() -> void:
	if _events_enabled and _can_trigger_event():
		_scheduler.advance(0.0)
		_event_ui.pump(event_ui_available())
		_sync_event_input()


func _start_event(commands: Array, event_id: int) -> void:
	if commands.is_empty() or _scene_pending or _dialogue.is_open() or _interpreter.running or _menus.menu != null or _menus.shop != null or _menus.name_input != null:
		return
	_player.input_enabled = false
	_scheduler.start_main(commands, event_id, _map.event_page(event_id))
	_event_ui.pump(event_ui_available())
	_sync_event_input()


func _show_diagnostic(message: String) -> void:
	_event_ui.report(message)
	_event_ui.pump(event_ui_available())
	_sync_event_input()


func _on_event_completed() -> void:
	_map.flush_event_refresh()
	_sync_event_input()


func _can_trigger_event() -> bool:
	return _events_enabled and _transfer_active == 0 and _screen_active == 0 and not _interpreter.running and not _event_ui.busy() and not _dialogue.is_open() and _menus.menu == null and _menus.shop == null and _menus.name_input == null and _player.is_idle()


func _sync_event_input() -> void:
	if _menus == null: return
	var enabled: bool = _transfer_active == 0 and _screen_active == 0 and not _interpreter.running and not _event_ui.busy() and not _dialogue.is_open() and _menus.menu == null and _menus.shop == null and _menus.name_input == null and not _scene_pending
	if enabled and not _player.input_enabled: _player.resume_after_menu()
	_player.input_enabled = enabled


func _present_event_ui(kind: String, payload: Array, request_id: int) -> void:
	if kind in ["choice", "number"] and payload.size() == 1 and payload[0] is Dictionary:
		_dialogue.show_event(payload[0], request_id)
		_sync_event_input()
		return
	match kind:
		"message": _dialogue.show_message(payload[0], request_id, payload[1])
		"choice": _dialogue.show_choices(payload[0], payload[1], request_id, payload[2])
		"number": _dialogue.show_number(payload[0], payload[1], request_id, payload[2])
		"button": _dialogue.show_button(payload[0], request_id, payload[1])
		"diagnostic": _dialogue.show_diagnostic(payload[0], request_id)
		"menu":
			var result: Dictionary = _menus.open_event_menu(request_id)
			if not result.ok: _event_ui.reject(request_id, result.message)
		"save":
			var result: Dictionary = _menus.open_event_save(request_id)
			if not result.ok: _event_ui.reject(request_id, result.message)
		"name":
			var result: Dictionary = _menus.open_name(int(payload[0]), int(payload[1]), request_id)
			if not result.ok: _event_ui.reject(request_id, result.message)
		"shop":
			var result: Dictionary = _menus.open_shop(payload[0], request_id)
			if not result.ok: _event_ui.reject(request_id, result.message)
	_sync_event_input()


func _event_response(request_id: int, _kind: String, value: Variant) -> void:
	_event_ui.resolve(request_id, value)
	_event_ui.pump(event_ui_available())
	_sync_event_input()


func _dismiss_event_ui(kind: String) -> void:
	if kind == "shop": _menus.close_shop()
	elif kind in ["menu", "save"]: _menus.close_menu()
	elif kind == "name": _menus.close_name()
	else: _dialogue.dismiss()
	_sync_event_input()


func _exit_tree() -> void:
	reset_event_execution()
	if _scheduler != null: _scheduler.dispose()
	if not _event_lab_backup.is_empty(): _event_lab_backup.scheduler.dispose()


func _update_camera_limits() -> void:
	if _camera != null: _camera.sync(0)

func _map_loaded(id: int) -> void:
	_events_enabled = true
	_player._sync_position()
	var result: Dictionary = RuntimeState.map_effects.setup_map(id, _map.tileset)
	if not result.ok: RuntimeState.report_diagnostic("Map%03d: %s" % [id, result.message])
	_update_camera_limits()
	# A restored audio snapshot takes precedence over map autoplay.
	if RuntimeState.resume_from_save: return
	for kind in ["BGM", "BGS"]:
		if _map.map_data.get("autoplay_" + kind.to_lower(), false):
			var played: Dictionary = RuntimeState.audio.play(kind, _map.map_data.get(kind.to_lower(), {}))
			if not played.ok: RuntimeState.report_diagnostic(played.message)

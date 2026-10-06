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
	add_child(_effects)
	_transition = Transition.new()
	add_child(_transition)
	_dialogue = DialogueOverlay.new()
	add_child(_dialogue)
	_interpreter = EventInterpreter.new()
	_interpreter.map_runtime = _map
	_map.event_requested.connect(_start_event)
	_map.map_changed.connect(_map_loaded)
	_interpreter.message_requested.connect(_dialogue.show_message)
	_interpreter.choices_requested.connect(_dialogue.show_choices)
	_interpreter.number_requested.connect(_dialogue.show_number)
	_interpreter.shop_requested.connect(func(goods: Array) -> void:
		var result: Dictionary = _menus.open_shop(goods)
		if not result.ok:
			_interpreter.reject_shop(result.message)
	)
	_interpreter.diagnostic_requested.connect(_show_diagnostic)
	_interpreter.completed.connect(_on_event_completed)
	_dialogue.message_confirmed.connect(_interpreter.resume_message)
	_dialogue.choice_selected.connect(_interpreter.resume_choice)
	_dialogue.number_confirmed.connect(_interpreter.resume_number)
	_dialogue.closed.connect(func() -> void:
		_player.input_enabled = not _interpreter.running
		_player.resume_after_menu()
	)
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
		RuntimeState.resume_from_save = false
		_player.resume_after_menu()
	else:
		call_deferred("_start_autorun")


func can_save() -> bool:
	return _player.is_idle() and not RuntimeState.save_disabled and not _interpreter.running and not _dialogue.is_open() and _menus.shop == null and _menus.menu != null and _menus.menu.page == "save"

func _process(_delta: float) -> void:
	if _camera != null and _camera.model != RuntimeState.map_view:
		_camera.model = RuntimeState.map_view
		_effects.view_model = RuntimeState.map_view
		_effects.model = RuntimeState.map_effects
		_effects.timer_model = RuntimeState.timer
		RuntimeState.map_effects.setup_map(RuntimeState.map_id, _map.tileset)
		_camera.sync(0)


func save_slot(slot: int) -> Dictionary:
	if not can_save():
		return {"ok": false, "message": "当前禁止存档，或事件/对话尚未结束。"}
	RuntimeState.player_direction = {Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 6, Vector2i.UP: 8}[_player.facing]
	return preload("res://runtime/scripts/SaveService.gd").save_slot(slot, RuntimeState)


func _start_autorun() -> void:
	var event := _map.autorun_event()
	if not event.is_empty():
		_start_event(event.get("commands", []), int(event.get("event_id", 0)))


func _start_event(commands: Array, event_id: int) -> void:
	if commands.is_empty() or _dialogue.is_open() or _interpreter.running or _menus.menu != null or _menus.shop != null:
		return
	_player.input_enabled = false
	_interpreter.start(commands, event_id, _map.event_page(event_id))


func _show_diagnostic(message: String) -> void:
	_player.input_enabled = false
	_dialogue.show_diagnostic(message)


func _on_event_completed() -> void:
	_map.call_deferred("refresh_events")
	if not _dialogue.is_open():
		_player.input_enabled = true
		_player.resume_after_menu()


func _update_camera_limits() -> void:
	if _camera != null: _camera.sync(0)

func _map_loaded(id: int) -> void:
	_player._sync_position()
	var result: Dictionary = RuntimeState.map_effects.setup_map(id, _map.tileset)
	if not result.ok: RuntimeState.report_diagnostic("Map%03d: %s" % [id, result.message])
	_update_camera_limits()
	for kind in ["BGM", "BGS"]:
		if _map.map_data.get("autoplay_" + kind.to_lower(), false):
			var played: Dictionary = RuntimeState.audio.play(kind, _map.map_data.get(kind.to_lower(), {}))
			if not played.ok: RuntimeState.report_diagnostic(played.message)

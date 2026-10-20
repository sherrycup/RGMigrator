## 职责：启动并组织游戏地图场景，连接运行状态、界面、事件与场景切换。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/10_Support/Boot/Game.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func can_save() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func play_flash_effect(name: String, args: Array = []) -> Dictionary
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 args（Array；默认值 []）：按调用顺序排列的参数值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func unravel_picture(number: int, args: Array = []) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 args（Array；默认值 []）：按调用顺序排列的参数值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func unravel_character(event_id: int = -1, args: Array = []) -> Dictionary
##     参数 event_id（int；默认值 -1）：当前地图上的事件编号；0 的具体含义由调用入口约定。
##     参数 args（Array；默认值 []）：按调用顺序排列的参数值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func show_flash_scene(source_name: String, args: Array = []) -> Dictionary
##     参数 source_name（String；必填）：用于显示或诊断的来源名称。
##     参数 args（Array；默认值 []）：按调用顺序排列的参数值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func event_save_override() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func capture_event_state(detached_nodes: Array = []) -> Dictionary
##     参数 detached_nodes（Array；默认值 []）：已经脱离现场的对象图节点。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func script_field_roots() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func restore_event_state() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func event_save_reason(ignore_checkpoint: bool = false) -> String
##     参数 ignore_checkpoint（bool；默认值 false）：是否跳过本次事件的额外撤回记录入口。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func event_map() -> Node
##     参数：无。
##     返回：Node 类型的对象或值，供调用方继续使用。
##
##   func event_transfer_ready() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func event_ui_available() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func event_scene_transition_active() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func request_event_scene(kind: String) -> void
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func scroll_event_map(direction: int, tiles: int, speed: int) -> Dictionary
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 tiles（int；必填）：地图或图块集的图块数据。
##     参数 speed（int；必填）：移动、播放或推进速度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func event_screen_transition_active() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func event_screen_transition_ready() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func begin_event_screen_transition(code: int, name_value: String = "") -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 name_value（String；默认值 ""）：待设置的名称文本。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func event_screen_transition_status(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func cancel_event_screen_transition(id: int = 0) -> void
##     参数 id（int；默认值 0）：本接口所处理对象的编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func begin_event_transfer(map_id: int, x: int, y: int, direction: int, fade: bool) -> Dictionary
##     参数 map_id（int；必填）：地图的原编号。
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 fade（bool；必填）：淡入淡出或音频渐变参数。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func event_transfer_status(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func cancel_event_transfer() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func reset_event_execution() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func enter_event_test_map() -> Dictionary
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func start_event_test_scenario(name: String) -> Dictionary
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func exit_event_test_map() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func save_slot(slot: int) -> Dictionary
##     用途：捕获并完整校验当前游戏现场后写入存档位。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _exit_tree() -> void
##
## 接口说明结束。

extends Node2D

const MapRuntime = preload("res://runtime/scripts/03_Map/MapRuntime.gd")
const PlayerController = preload("res://runtime/scripts/03_Map/PlayerController.gd")
const EventInterpreter = preload("res://runtime/scripts/02_Event/EventInterpreter.gd")
const DialogueOverlay = preload("res://runtime/scripts/06_Message/DialogueOverlay.gd")
const MenuCoordinator = preload("res://runtime/scripts/08_Menu/Main/MenuCoordinator.gd")
const ScreenRenderer = preload("res://runtime/scripts/03_Map/ScreenRenderer.gd")
const CameraRig = preload("res://runtime/scripts/03_Map/MapCamera.gd")
const EffectsRenderer = preload("res://runtime/scripts/03_Map/MapEffectsRenderer.gd")
const Transition = preload("res://runtime/scripts/09_Effects/TransitionRenderer.gd")

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
var _flash_hud: CanvasLayer
var _flash_movie: CanvasLayer
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
var _event_checkpoint: Dictionary = {}
var _checkpoint_serial = 0


func _ready() -> void:
	if RuntimeState.custom_data.manifest.get("profile") == "flash":
		var warmed = preload("../Scripting/ScriptRuntime.gd").prewarm()
		preload("../../09_Effects/RmxpAnimationData.gd").prewarm()
		if not warmed.ok:
			RuntimeState.report_diagnostic("生成脚本预加载失败：" + str(warmed.failures))
	RuntimeState.register_game(self)
	if RuntimeState.flash_history != null:
		RuntimeState.flash_history.checkpoint_prepared.connect(_checkpoint_prepared)
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
	_scheduler = preload("res://runtime/scripts/02_Event/EventScheduler.gd").new()
	_scheduler.configure(_map)
	_interpreter = _scheduler.main
	_event_ui = preload("res://runtime/scripts/02_Event/EventUIBroker.gd").new()
	_event_ui.bind_interpreter(_interpreter)
	_scheduler.interpreter_created.connect(_event_ui.bind_interpreter)
	_scheduler.main_completed.connect(_on_event_completed)
	_scheduler.main_aborted.connect(_on_event_completed)
	_event_ui.terminal_requested.connect(request_event_scene)
	_event_ui.requested.connect(_present_event_ui)
	_event_ui.dismissed.connect(_dismiss_event_ui)
	_dialogue.event_response.connect(_event_response)
	_dialogue.event_failed.connect(_event_ui.reject)
	_dialogue.closed.connect(_sync_event_input)
	_map.event_requested.connect(_start_event)
	_map.map_changed.connect(_map_loaded)
	_map.trigger_allowed = _can_trigger_event
	RuntimeState.execution_reset.connect(reset_event_execution)
	_menus = MenuCoordinator.new()
	_menus.game = self
	add_child(_menus)
	if RuntimeState.custom_data.manifest.get("profile") == "flash":
		_flash_movie = load("res://runtime/scripts/10_Support/Utilities/MoviePlayer.gd").new()
		add_child(_flash_movie)
		_flash_hud = preload("../../03_Map/MapHUD.gd").new()
		add_child(_flash_hud)
		var effects_view = load("res://runtime/scripts/09_Effects/EffectView.gd").new()
		effects_view.model = RuntimeState.flash_effects
		effects_view.game = self
		add_child(effects_view)
		var enemy_labels = load("res://runtime/scripts/03_Map/EnemyMapLabels.gd").new()
		enemy_labels.game = self
		add_child(enemy_labels)
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
	# Hash the frozen project during startup instead of the first touched event.
	preload("../Persistence/SaveService.gd").fingerprint()
	if RuntimeState.resume_from_save:
		if RuntimeState.pending_event_state.is_empty():
			_scheduler.suppress_loaded_autoruns()
		else:
			restore_event_state()
		RuntimeState.resume_from_save = false
		_player.resume_after_menu()
	else:
		call_deferred("_start_autorun")


func can_save() -> bool:
	if (
		RuntimeState.flash_effects != null
		and not RuntimeState.flash_effects.transient_save_reason().is_empty()
	):
		return false
	if _menus.menu != null and _menus.menu.get("mode") == "load":
		return false
	var save_page: bool = (
		_menus.menu != null
		and (
			_menus.menu.page == "save"
			or (
				_menus.menu.page == "flash_menu"
				and _menus.menu.active_command == 1
				and _menus.menu.child != null
				and _menus.menu.child.mode == "save"
			)
		)
	)
	return (
		_player.is_idle()
		and (not RuntimeState.save_disabled or event_save_override())
		and event_save_reason().is_empty()
		and not _dialogue.is_open()
		and _menus.shop == null
		and save_page
	)


func play_flash_effect(name: String, args: Array = []) -> Dictionary:
	return preload("../Scripting/ScriptRuntime.gd").call_transaction(
		RuntimeState,
		{"source": "GameEngine::Screen." + name},
		func(env):
			return load("res://runtime/scripts/09_Effects/ScreenEffects.gd").stage(
				env._custom, name, args
			)
	)


func unravel_picture(number: int, args: Array = []) -> Dictionary:
	return play_flash_effect("picture_unravel", [number, args])


func unravel_character(event_id: int = -1, args: Array = []) -> Dictionary:
	return play_flash_effect("character_unravel", [event_id, args])


func show_flash_scene(source_name: String, args: Array = []) -> Dictionary:
	return _menus.open_flash_scene(source_name, args)


func event_save_override() -> bool:
	return (
		not _event_ui.active.is_empty()
		and _event_ui.active.kind == "save"
		and _event_ui._valid(_event_ui.active)
	)


func capture_event_state(detached_nodes: Array = []) -> Dictionary:
	if _map == null or _map.map_data.is_empty() or _map._loaded_id != RuntimeState.map_id:
		return {}
	return preload("res://runtime/scripts/02_Event/EventPersistence.gd").capture(
		self, detached_nodes
	)


func script_field_roots() -> Array:
	var roots = []
	if _scheduler == null:
		return roots
	for owner in (
		[_scheduler.main] + _scheduler.parallels.values().map(func(entry): return entry.owner)
	):
		roots.append(owner.context.script_fields)
		for frame in owner.context.stack:
			roots.append(frame.get("script_fields", {}))
	return roots


func restore_event_state() -> void:
	if RuntimeState.pending_event_state.is_empty():
		return
	if _map._loaded_id != RuntimeState.map_id and not _map.load_map(RuntimeState.map_id):
		_show_diagnostic("无法恢复存档地图。")
		return
	preload("res://runtime/scripts/02_Event/EventPersistence.gd").restore(
		self, RuntimeState.pending_event_state
	)
	if not RuntimeState.pending_flash_presentation.is_empty():
		preload("../../09_Effects/PresentationState.gd").restore(
			RuntimeState,
			RuntimeState.pending_flash_presentation,
			self,
			_event_ui.get_meta("restored_request_ids", {})
		)
		RuntimeState.pending_flash_presentation = {}
	RuntimeState.pending_event_state = {}
	RuntimeState.resume_from_save = false


func _process(delta: float) -> void:
	if _scene_pending:
		return
	if (
		_screen_active > 0
		and _screen_revealing
		and not _transition.busy
		and _transition.remaining <= 0
	):
		_record_screen_transition({"id": _screen_active, "ok": true, "pending": false})
		_screen_active = 0
		_screen_revealing = false
	if (
		_transfer_active > 0
		and _transfer_revealing
		and not _transition.busy
		and _transition.remaining <= 0
	):
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
	if (
		_events_enabled
		and not event_screen_transition_active()
		and not (RuntimeState.flash_effects != null and RuntimeState.flash_effects.busy())
	):
		_scheduler.advance(
			delta,
			(
				not _event_ui.busy()
				and _menus.menu == null
				and _menus.shop == null
				and not _dialogue.is_open()
			)
		)
	_event_ui.pump(event_ui_available())
	_sync_event_input()


func event_save_reason(ignore_checkpoint: bool = false) -> String:
	if not ignore_checkpoint and not _event_checkpoint.is_empty():
		return "事件前记录尚未完成。"
	if _flash_movie != null and _flash_movie.request_id > 0:
		return "视频尚未结束，请停止播放后保存。"
	if _menus != null and _menus._flash_scene_done.is_valid():
		return "脚本打开的独立页面尚未返回，请返回地图后存档。"
	if (
		RuntimeState.flash_effects != null
		and not RuntimeState.flash_effects.transient_save_reason().is_empty()
	):
		return RuntimeState.flash_effects.transient_save_reason()
	if _scene_pending:
		return "场景切换尚未结束。"
	if not _event_lab_backup.is_empty():
		return "事件验收地图不写入正式存档；请先退出验收地图。"
	if _map._loaded_id != RuntimeState.map_id:
		return "脱离数据库的测试地图不能写入正式存档。"
	if _transfer_active > 0:
		return "场所移动尚未结束。"
	if (
		_screen_active > 0
		or _transition.busy
		or _transition.frozen != null
		or _transition.remaining > 0
	):
		return "瞬时截图/过渡尚未释放，不能写入存档。"
	for owner in (
		[_scheduler.main]
		+ _scheduler.parallels.values().map(
			func(entry: Dictionary) -> RefCounted: return entry.owner
		)
	):
		if (
			owner.running
			and (
				owner.wait_kind()
				in ["scene", "transfer", "transfer_ready", "screen_ready", "screen_transition"]
			)
		):
			return "事件正在传送或切换画面，请等待完成后存档。"
	return ""


func event_map() -> Node:
	return _map


func event_transfer_ready() -> bool:
	return (
		_transfer_active == 0
		and _screen_active == 0
		and not _transition.busy
		and _transition.remaining <= 0
		and not _dialogue.is_open()
		and _menus.menu == null
		and _menus.shop == null
		and _menus.name_input == null
		and not _scene_pending
	)


func event_ui_available() -> bool:
	if (
		_scene_pending
		or _menus == null
		or _menus.menu != null
		or _menus.shop != null
		or _menus.name_input != null
		or RuntimeState.map_time_paused()
	):
		return false
	if _dialogue._open:
		return false
	if _event_ui.next_kind() in ["menu", "name", "shop", "save"] and _dialogue.is_open():
		return false
	# RM messages can appear during motion; scene pages wait for its completion.
	return _player.is_idle() or _event_ui.next_kind() not in ["menu", "name", "shop", "save"]


func event_scene_transition_active() -> bool:
	return _scene_pending


func request_event_scene(kind: String) -> void:
	if kind not in ["title", "gameover"] or _scene_pending:
		return
	reset_event_execution()
	if _menus.menu != null:
		_menus.close_menu()
	if _menus.shop != null:
		_menus.close_shop()
	if _menus.name_input != null:
		_menus.close_name()
	_scene_pending = true
	_events_enabled = false
	RuntimeState.playing = false
	_player.input_enabled = false
	var serial := _scene_serial
	call_deferred("_switch_event_scene", serial, kind)


func _switch_event_scene(serial: int, kind: String) -> void:
	if not is_inside_tree() or not _scene_pending or serial != _scene_serial:
		return
	var path := (
		"res://scenes/05_Title/Title.tscn"
		if kind == "title"
		else "res://scenes/05_Title/Gameover.tscn"
	)
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		_scene_pending = false
		_events_enabled = true
		RuntimeState.playing = true
		_show_diagnostic("场景切换失败：%s（%d）" % [path, result])


func scroll_event_map(direction: int, tiles: int, speed: int) -> Dictionary:
	if _camera == null or _map == null:
		return {"ok": false, "message": "地图镜头尚未就绪。"}
	return RuntimeState.map_view.scroll_native(
		direction,
		tiles,
		speed,
		Vector2(_map.map_width(), _map.map_height()) * 32,
		get_viewport_rect().size
	)


func event_screen_transition_active() -> bool:
	return _screen_active > 0


func event_screen_transition_ready() -> bool:
	return event_transfer_ready() and not _event_ui.busy()


func begin_event_screen_transition(code: int, name_value: String = "") -> Dictionary:
	if code not in [221, 222]:
		return {"ok": false, "message": "画面过渡指令无效。"}
	if (
		code == 222
		and not name_value.is_empty()
		and (
			preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd").transition(name_value)
			== null
		)
	):
		return {"ok": false, "message": "Transitions素材缺失：%s；原画面保持，不补取RTP。" % name_value}
	if not event_screen_transition_ready():
		return {"ok": false, "busy": true, "message": "其他过渡、场所移动或界面未结束。"}
	_screen_serial += 1
	_screen_active = _screen_serial
	call_deferred("_perform_screen_transition", _screen_active, code, name_value)
	_sync_event_input()
	return {"ok": true, "id": _screen_active}


func event_screen_transition_status(id: int) -> Dictionary:
	if id == _screen_active:
		return {"ok": true, "pending": true}
	if _screen_results.has(id):
		return _screen_results[id].duplicate()
	return {"ok": false, "pending": false, "message": "画面过渡已取消或请求已过期。"}


func cancel_event_screen_transition(id: int = 0) -> void:
	if id != 0 and id != _screen_active and id != _screen_frozen_request:
		return
	if _screen_active > 0:
		_record_screen_transition(
			{"id": _screen_active, "ok": false, "pending": false, "message": "画面过渡已取消。"}
		)
	_screen_active = 0
	_screen_revealing = false
	_screen_frozen_request = 0
	if _transition != null:
		_transition.cancel()


func _record_screen_transition(result: Dictionary) -> void:
	_screen_results[int(result.id)] = result
	if _screen_results.size() > 32:
		var keys := _screen_results.keys()
		keys.sort()
		_screen_results.erase(keys[0])


func _perform_screen_transition(id: int, code: int, name_value: String) -> void:
	if id != _screen_active:
		return
	if _transition.frozen == null:
		var result: Dictionary = await _transition.freeze_screen()
		if not is_inside_tree() or id != _screen_active:
			return
		if not result.ok:
			_record_screen_transition(
				{"id": id, "ok": false, "pending": false, "message": result.message}
			)
			_screen_active = 0
			return
	if code == 221:
		_screen_frozen_request = id
		_record_screen_transition({"id": id, "ok": true, "pending": false})
		_screen_active = 0
		return
	var result: Dictionary = _transition.transition(
		0.5 if name_value.is_empty() else 1.0, name_value
	)
	if not result.ok:
		_record_screen_transition(
			{"id": id, "ok": false, "pending": false, "message": result.message}
		)
		_screen_active = 0
		return
	_screen_frozen_request = 0
	_screen_revealing = true


func begin_event_transfer(map_id: int, x: int, y: int, direction: int, fade: bool) -> Dictionary:
	var candidate := preload("res://runtime/scripts/00_Game/RuntimeData.gd").map(map_id)
	if (
		direction not in [0, 2, 4, 6, 8]
		or x < 0
		or y < 0
		or x >= int(candidate.get("width", 0))
		or y >= int(candidate.get("height", 0))
	):
		return {"ok": false, "message": "传送地图、坐标或方向无效，未换图。"}
	if not event_transfer_ready():
		return {"ok": false, "busy": true, "message": "其他场所移动、消息或过渡未结束。"}
	_transfer_serial += 1
	_transfer_active = _transfer_serial
	call_deferred("_perform_event_transfer", _transfer_active, map_id, x, y, direction, fade)
	_sync_event_input()
	return {"ok": true, "id": _transfer_active}


func event_transfer_status(id: int) -> Dictionary:
	if id == _transfer_active:
		return {"ok": true, "pending": true}
	if _transfer_results.has(id):
		return _transfer_results[id].duplicate()
	return {"ok": false, "pending": false, "message": "场所移动已取消或请求已过期。"}


func _record_transfer(result: Dictionary) -> void:
	_transfer_results[int(result.id)] = result
	if _transfer_results.size() > 32:
		var keys := _transfer_results.keys()
		keys.sort()
		_transfer_results.erase(keys[0])


func cancel_event_transfer() -> void:
	if _transfer_active <= 0:
		return
	_record_transfer({"id": _transfer_active, "ok": false, "pending": false, "message": "场所移动已取消。"})
	_transfer_active = 0
	_transfer_revealing = false
	if _transition != null:
		_transition.cancel()


func _perform_event_transfer(
	id: int, map_id: int, x: int, y: int, direction: int, fade: bool
) -> void:
	if id != _transfer_active:
		return
	if fade and _transition.frozen == null:
		var frozen: Dictionary = await _transition.freeze_screen()
		if id != _transfer_active or not is_inside_tree():
			return
		if not frozen.ok:
			_record_transfer({"id": id, "ok": false, "pending": false, "message": frozen.message})
			_transfer_active = 0
			return
	if id != _transfer_active:
		return
	if not _map.transfer(map_id, x, y, direction):
		_record_transfer({"id": id, "ok": false, "pending": false, "message": "传送失败，未换图。"})
		_transfer_active = 0
		if fade:
			_transition.cancel()
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
	if not _event_checkpoint.is_empty() and RuntimeState.flash_history != null:
		RuntimeState.flash_history.cancel_preparation()
	_checkpoint_serial += 1
	_event_checkpoint.clear()
	if _flash_movie != null:
		_flash_movie.stop()
	_scene_serial += 1
	_scene_pending = false
	_events_enabled = false
	cancel_event_transfer()
	cancel_event_screen_transition()
	if _map != null:
		_map.cancel_character_routes()
	if _player != null:
		_player.reset_route_state()
	if _scheduler != null:
		_scheduler.cancel_all()
	if _event_ui != null:
		_event_ui.cancel_all()
	if RuntimeState.flash_messages != null:
		RuntimeState.flash_messages.reset()


func enter_event_test_map() -> Dictionary:
	if (
		not RuntimeState.testing_enabled
		or not _event_lab_backup.is_empty()
		or _interpreter.running
		or _event_ui.busy()
		or not _player.is_idle()
		or _player.routes.has_runtime_state()
		or _transfer_active > 0
		or _transition.busy
		or _transition.frozen
	):
		return {"ok": false, "message": "请在测试模式的空闲地图进入事件验收。"}
	var codec := preload("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	var backup: Dictionary = codec.prepare(codec.capture(RuntimeState))
	if not backup.ok:
		return backup
	# Keep the original map and interpreters paused in memory, including erasures
	# and parallel stacks that schema 1 cannot serialize.
	_event_lab_backup = {
		"state": backup,
		"map": _map,
		"scheduler": _scheduler,
		"diagnostics": RuntimeState.diagnostics.duplicate()
	}
	_map.process_mode = Node.PROCESS_MODE_DISABLED
	_map.hide()
	var fixture := preload("res://runtime/scripts/11_Development/EventFixture.gd").build()
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
	_scheduler = preload("res://runtime/scripts/02_Event/EventScheduler.gd").new()
	_scheduler.configure(_map, fixture.common_events)
	_interpreter = _scheduler.main
	_event_ui.bind_interpreter(_interpreter)
	_scheduler.interpreter_created.connect(_event_ui.bind_interpreter)
	_scheduler.main_completed.connect(_on_event_completed)
	RuntimeState.configure_map_effects({"panorama_name": "", "fog_name": ""})
	_scheduler.main_aborted.connect(_on_event_completed)
	var size := get_viewport_rect().size
	RuntimeState.configure_map_view(
		{"view_rect": [0, 156, size.x, size.y - 156], "follow_center": [], "follow_enabled": true}
	)
	_update_camera_limits()
	_event_lab_hud = preload("res://runtime/scripts/11_Development/EventTestHUD.gd").new()
	_event_lab_hud.game = self
	_event_lab_hud.back_requested.connect(exit_event_test_map)
	add_child(_event_lab_hud)
	if _test_label != null:
		_test_label.hide()
	_events_enabled = true
	return {"ok": true}


func start_event_test_scenario(name: String) -> Dictionary:
	if (
		_event_lab_backup.is_empty()
		or _interpreter.running
		or _event_ui.busy()
		or _menus.menu != null
		or not _player.is_idle()
	):
		return {"ok": false, "message": "请先完成当前事件。"}
	if name not in ["flow", "input"]:
		return {"ok": false, "message": "未知验收流程。"}
	_scheduler.start_main(
		preload("res://runtime/scripts/11_Development/EventFixture.gd").scenario(name), 0
	)
	_event_ui.pump(event_ui_available())
	_sync_event_input()
	return {"ok": true}


func exit_event_test_map() -> void:
	if (
		_event_lab_backup.is_empty()
		or _interpreter.running
		or _event_ui.busy()
		or _menus.menu != null
		or _menus.shop != null
	):
		return
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
	if _test_label != null:
		_test_label.show()
	_events_enabled = true
	_player.resume_after_menu()


func save_slot(slot: int) -> Dictionary:
	if not can_save():
		return {
			"ok": false,
			"message":
			event_save_reason() if not event_save_reason().is_empty() else "当前禁止存档，或事件/对话尚未结束。"
		}
	RuntimeState.player_direction = {
		Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 6, Vector2i.UP: 8
	}[_player.facing]
	var result: Dictionary = (
		preload("res://runtime/scripts/10_Support/Persistence/SaveService.gd")
		. save_slot(slot, RuntimeState)
	)
	if result.ok and event_save_override():
		if _menus.menu.has_method("ready_for_input"):
			_menus.menu.call_deferred("back")
		else:
			_menus.call_deferred("close_menu")
	return result


func _start_autorun() -> void:
	if _events_enabled and _can_trigger_event():
		_scheduler.advance(0.0)
		_event_ui.pump(event_ui_available())
		_sync_event_input()


func _start_event(commands: Array, event_id: int) -> void:
	if (
		commands.is_empty()
		or not _event_checkpoint.is_empty()
		or _scene_pending
		or _dialogue.is_open()
		or _interpreter.running
		or _menus.menu != null
		or _menus.shop != null
		or _menus.name_input != null
	):
		return
	if RuntimeState.flash_history != null and _map.player_trigger_request:
		var name = str(_map.map_data.get("events", {}).get(str(event_id), {}).get("name", ""))
		if RuntimeState.flash_history.eligible(name):
			_checkpoint_serial += 1
			_event_checkpoint = {
				"request": _checkpoint_serial,
				"commands": commands,
				"event_id": event_id,
				"generation": _map.generation
			}
			_player.input_enabled = false
			RuntimeState.flash_history.prepare_record(_checkpoint_serial)
			return
	_run_event(commands, event_id)


func _checkpoint_prepared(request_id: int, result: Dictionary) -> void:
	if _event_checkpoint.is_empty() or _event_checkpoint.request != request_id:
		return
	var pending = _event_checkpoint
	_event_checkpoint = {}
	if result.get("cancelled", false) or pending.generation != _map.generation:
		_sync_event_input()
		return
	if not result.ok and not RuntimeState.save_disabled:
		RuntimeState.report_diagnostic("事件前记录失败：" + result.message)
	_run_event(pending.commands, pending.event_id)


func _run_event(commands: Array, event_id: int) -> void:
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
	if not _event_checkpoint.is_empty():
		return false
	if RuntimeState.flash_effects != null and RuntimeState.flash_effects.busy():
		return false
	return (
		_events_enabled
		and _transfer_active == 0
		and _screen_active == 0
		and not _interpreter.running
		and not _event_ui.busy()
		and not _dialogue.is_open()
		and _menus.menu == null
		and _menus.shop == null
		and _menus.name_input == null
		and _player.is_idle()
	)


func _sync_event_input() -> void:
	if _menus == null:
		return
	var enabled: bool = (
		_transfer_active == 0
		and _screen_active == 0
		and not _interpreter.running
		and not _event_ui.busy()
		and not _dialogue.is_open()
		and _menus.menu == null
		and _menus.shop == null
		and _menus.name_input == null
		and not _scene_pending
	)
	if not _event_checkpoint.is_empty():
		enabled = false
	if RuntimeState.flash_effects != null and RuntimeState.flash_effects.busy():
		enabled = false
	if enabled and not _player.input_enabled:
		_player.resume_after_menu()
	_player.input_enabled = enabled


func _present_event_ui(kind: String, payload: Array, request_id: int) -> void:
	if kind in ["choice", "number"] and payload.size() == 1 and payload[0] is Dictionary:
		_dialogue.show_event(payload[0], request_id)
		_sync_event_input()
		return
	match kind:
		"message":
			_dialogue.show_message(payload[0], request_id, payload[1])
		"choice":
			_dialogue.show_choices(payload[0], payload[1], request_id, payload[2])
		"number":
			_dialogue.show_number(payload[0], payload[1], request_id, payload[2])
		"button":
			_dialogue.show_button(payload[0], request_id, payload[1])
		"diagnostic":
			_dialogue.show_diagnostic(payload[0], request_id)
		"menu":
			var result: Dictionary = _menus.open_event_menu(request_id)
			if not result.ok:
				_event_ui.reject(request_id, result.message)
		"save":
			var result: Dictionary = _menus.open_event_save(request_id)
			if not result.ok:
				_event_ui.reject(request_id, result.message)
		"name":
			var result: Dictionary = _menus.open_name(int(payload[0]), int(payload[1]), request_id)
			if not result.ok:
				_event_ui.reject(request_id, result.message)
		"shop":
			var result: Dictionary = _menus.open_shop(payload[0], request_id)
			if not result.ok:
				_event_ui.reject(request_id, result.message)
	_sync_event_input()


func _event_response(request_id: int, _kind: String, value: Variant) -> void:
	_event_ui.resolve(request_id, value)
	_event_ui.pump(event_ui_available())
	_sync_event_input()


func _dismiss_event_ui(kind: String) -> void:
	if kind == "shop":
		_menus.close_shop()
	elif kind in ["menu", "save"]:
		_menus.close_menu()
	elif kind == "name":
		_menus.close_name()
	else:
		_dialogue.dismiss()
	_sync_event_input()


func _exit_tree() -> void:
	reset_event_execution()
	if _scheduler != null:
		_scheduler.dispose()
	if not _event_lab_backup.is_empty():
		_event_lab_backup.scheduler.dispose()


func _update_camera_limits() -> void:
	if _camera != null:
		_camera.sync(0)


func _map_loaded(id: int) -> void:
	_events_enabled = true
	_player._sync_position()
	var result: Dictionary = RuntimeState.map_effects.setup_map(id, _map.tileset)
	if not result.ok:
		RuntimeState.report_diagnostic("Map%03d: %s" % [id, result.message])
	_update_camera_limits()
	for kind in ["BGM", "BGS"]:
		# Keep saved tracks/intentional silence; older silent snapshots may need map autoplay.
		if (
			RuntimeState.resume_from_save
			and not RuntimeState.audio.can_autoplay_after_restore(kind)
		):
			continue
		if _map.map_data.get("autoplay_" + kind.to_lower(), false):
			var played: Dictionary = RuntimeState.audio.play(
				kind, _map.map_data.get(kind.to_lower(), {})
			)
			if not played.ok:
				RuntimeState.report_diagnostic(played.message)

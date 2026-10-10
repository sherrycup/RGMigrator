extends Node

const ActorState = preload("res://runtime/scripts/ActorState.gd")
const RuntimeData = preload("res://runtime/scripts/RuntimeData.gd")
const ActorEvents = preload("res://runtime/scripts/ActorEventService.gd")
const InventoryService = preload("res://runtime/scripts/InventoryService.gd")
const ShopService = preload("res://runtime/scripts/ShopService.gd")
const ScreenState = preload("res://runtime/scripts/ScreenState.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const CharacterMotion = preload("res://runtime/scripts/CharacterMotion.gd")
const MapView = preload("res://runtime/scripts/MapViewState.gd")
const MapEffects = preload("res://runtime/scripts/MapEffectsState.gd")
const Settings = preload("res://runtime/scripts/SystemSettings.gd")
const Countdown = preload("res://runtime/scripts/GameTimer.gd")
const AudioService = preload("res://runtime/scripts/AudioRuntime.gd")
signal system_settings_changed
signal state_changed
signal event_state_changed(kind: String, key: String)
signal execution_reset
signal diagnostic_added(message: String)

var switches: Dictionary = {}
var variables: Dictionary = {}
var self_switches: Dictionary = {}
var inventory: Dictionary = {}
var gold := 0
var save_count := 0
var message_position := 2
var message_frame := 0
var party: Array = []
var map_id := 1
var player_motion: RefCounted = CharacterMotion.new()
var _player_ref: WeakRef
var player_x: int:
	get: return player_motion.cell.x
	set(value): player_motion.relocate(Vector2i(value, player_motion.cell.y))
var player_y: int:
	get: return player_motion.cell.y
	set(value): player_motion.relocate(Vector2i(player_motion.cell.x, value))
var player_direction: int:
	get: return player_motion.direction
	set(value): player_motion.turn(value, true)
var resume_from_save := false
var pending_event_state: Dictionary = {}
var common_event_reservation: Dictionary = {}
var save_disabled := false
var menu_disabled := false
var actors: Dictionary = {}
var diagnostics: Array[String] = []
var steps := 0
var play_seconds := 0.0
var playing := false
var testing_enabled := false
var _clock_second := 0
var _quitting := false
var system_settings: RefCounted = Settings.new()
var screen: RefCounted = ScreenState.new()
var map_view: RefCounted = MapView.new()
var map_effects: RefCounted = MapEffects.new()
var timer: RefCounted = Countdown.new()
var audio: Node
var _game_ref: WeakRef


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio = AudioService.new()
	add_child(audio)
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func request_quit() -> void:
	if _quitting:
		return
	_quitting = true
	playing = false
	# Allow the audio server to release playback references before process shutdown.
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.2, true).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	if playing:
		play_seconds += delta
		if int(play_seconds) != _clock_second:
			_clock_second = int(play_seconds)
			state_changed.emit()


func set_event_switch(id: int, value: bool) -> bool:
	if id <= 0: return false
	var key := str(id)
	if bool(switches.get(key, false)) == value: return true
	switches[key] = value
	event_state_changed.emit("switch", key)
	state_changed.emit()
	return true


func set_event_variable(id: int, value: int) -> bool:
	if id <= 0: return false
	var key := str(id)
	if int(variables.get(key, 0)) == value: return true
	variables[key] = value
	event_state_changed.emit("variable", key)
	state_changed.emit()
	return true


func set_event_self_switch(map: int, event: int, letter: String, value: bool) -> bool:
	if event <= 0 or letter not in ["A", "B", "C", "D"]: return false
	var key := self_switch_key(map, event, letter)
	if bool(self_switches.get(key, false)) == value: return true
	self_switches[key] = value
	event_state_changed.emit("self", key)
	state_changed.emit()
	return true


func begin_new_game(system: Dictionary, testing_override: Dictionary = {}) -> void:
	execution_reset.emit()
	pending_event_state.clear()
	common_event_reservation.clear()
	system_settings = Settings.new()
	system_settings_changed.emit()
	screen = ScreenState.new()
	map_view = MapView.new()
	var configured: Dictionary = map_view.configure({"view_rect": ProjectSettings.get_setting("rgmigrator/map_view_rect", []), "follow_center": ProjectSettings.get_setting("rgmigrator/map_follow_center", [])})
	map_effects = MapEffects.new()
	timer = Countdown.new()
	if audio != null: audio.stop_all()
	player_motion.reset()
	actors.clear()
	diagnostics.clear()
	if not configured.ok: report_diagnostic(configured.message)
	var setup := RuntimeData.configure_testing(testing_override)
	testing_enabled = bool(setup.get("enabled", false))
	for message in setup.get("errors", []):
		report_diagnostic(str(message))
	steps = 0
	play_seconds = 0.0
	_clock_second = 0
	playing = true
	switches.clear()
	variables.clear()
	self_switches.clear()
	inventory.clear()
	gold = 0
	save_count = 0
	message_position = 2
	message_frame = 0
	# JSON numbers are floats. Runtime IDs must be ints for Array.has/erase.
	party = []
	for raw_id in system.get("party_members", []):
		var actor_id := int(raw_id)
		if not party.has(actor_id):
			party.append(actor_id)
	map_id = int(system.get("start_map_id", 1))
	player_x = int(system.get("start_x", 0))
	player_y = int(system.get("start_y", 0))
	player_direction = 2
	resume_from_save = false
	save_disabled = false
	menu_disabled = false
	for actor_id in party:
		actor(int(actor_id))
	if testing_enabled:
		_prepare_testing(setup)
	state_changed.emit()


func inventory_entries() -> Array[Dictionary]:
	return InventoryService.entries(self)

func common_event_reason(id: int) -> String:
	if id <= 0 or RuntimeData.record("CommonEvents", id).is_empty(): return "公共事件%d不存在。" % id
	if game() == null or not playing: return "公共事件使用需要当前地图场景。"
	if not common_event_reservation.is_empty(): return "已有公共事件等待执行，请先返回地图。"
	return ""

func reserve_common_event(id: int, source: String = "", actor_id: int = 0, target_id: int = 0) -> Dictionary:
	var reason := common_event_reason(id)
	if not reason.is_empty(): return {"ok": false, "message": reason}
	common_event_reservation = {"id": id, "source": source, "actor_id": actor_id, "target_id": target_id}
	return {"ok": true, "common_event": id}

func use_skill(actor_id: int, skill_id: int, target_id: int = 0) -> Dictionary:
	return preload("res://runtime/scripts/CommonEventUse.gd").use_skill(self, actor_id, skill_id, target_id)


func change_skill(actor_id: int, skill_id: int, learning: bool) -> Dictionary:
	var instance := actor(actor_id)
	if instance == null:
		return {"ok": false, "message": "不存在的 Actors[%d]。" % actor_id}
	var result: Dictionary = instance.learn_skill(skill_id) if learning else instance.forget_skill(skill_id)
	if not result.ok:
		report_diagnostic(result.message)
	return result


func has_skill(actor_id: int, skill_id: int) -> bool:
	var instance := actor(actor_id)
	return instance != null and instance.has_skill(skill_id)


func skill_ids(actor_id: int) -> Array[int]:
	var instance := actor(actor_id)
	return instance.get_skill_ids() if instance != null else []


func use_item(item_id: int, target_id: int) -> Dictionary:
	return InventoryService.use_item(self, item_id, target_id)


func change_state(actor_id: int, state_id: int, adding: bool) -> Dictionary:
	var instance := actor(actor_id)
	if instance == null:
		return {"ok": false, "changed": false, "message": "不存在的 Actors[%d]。" % actor_id}
	var result: Dictionary = instance.add_state(state_id) if adding else instance.remove_state(state_id)
	if not result.ok:
		report_diagnostic(result.message)
	return result


func has_state(actor_id: int, state_id: int) -> bool:
	var instance := actor(actor_id)
	return instance != null and instance.has_state(state_id)


func state_ids_for(actor_id: int, include_equipment: bool = true) -> Array[int]:
	var instance := actor(actor_id)
	return instance.get_state_ids(include_equipment) if instance != null else []


func clear_states(actor_id: int) -> Dictionary:
	var instance := actor(actor_id)
	return instance.clear_states() if instance != null else {"ok": false, "changed": false, "message": "不存在的 Actors[%d]。" % actor_id}


func shop_buy(goods: Array, kind: String, id: int, quantity: int) -> Dictionary:
	return ShopService.buy(self, goods, kind, id, quantity)


func shop_sell(kind: String, id: int, quantity: int) -> Dictionary:
	return ShopService.sell(self, kind, id, quantity)


func inventory_count(kind: String, id: int) -> int:
	return int(inventory.get("%s:%d" % [kind, id], 0))


func equip_preview(actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	return InventoryService.equip_preview(self, actor_id, slot, equipment_id)


func equip(actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	return InventoryService.equip(self, actor_id, slot, equipment_id)


func actor_parameter_sources(actor_id: int, key: String) -> Dictionary:
	var instance := actor(actor_id)
	return instance.parameter_sources(key) if instance != null else {}


func _actor_call(actor_id: int, method: String, arguments: Array) -> Dictionary:
	var instance := actor(actor_id)
	var result: Dictionary = {"ok": false, "message": "不存在的 Actors[%d]。" % actor_id} if instance == null else instance.callv(method, arguments)
	if not result.ok:
		report_diagnostic("Actors[%d]：%s" % [actor_id, result.message])
	return result


func apply_actor_event(code: int, parameters: Array) -> Dictionary:
	return ActorEvents.execute(self, code, parameters)

func change_actor_parameter(actor_id: int, key: String, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_parameter_plus", [key, amount])


func set_actor_parameter(actor_id: int, key: String, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_parameter", [key, value])


func set_actor_parameter_plus(actor_id: int, key: String, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_parameter_plus", [key, value])


func set_actor_experience(actor_id: int, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_experience", [value])


func change_actor_experience(actor_id: int, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_experience", [amount])


func set_actor_level(actor_id: int, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_level", [value])


func change_actor_level(actor_id: int, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_level", [amount])


func set_actor_vital(actor_id: int, key: String, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_vital", [key, value])


func change_actor_vital(actor_id: int, key: String, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_vital", [key, amount])


func recover_actor_vitals(actor_id: int) -> Dictionary:
	return _actor_call(actor_id, "recover_vitals", [])


func rename_actor(actor_id: int, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "rename", [value])


func set_actor_graphic(actor_id: int, value: Variant, hue: Variant = 0) -> Dictionary:
	if value is String and not value.is_empty():
		var texture: Texture2D = Cache.character(value)
		if texture == null or texture.get_width() % 4 != 0 or texture.get_height() % 4 != 0:
			return {"ok": false, "message": "角色图缺失或不是四方向四帧格式；未修改。"}
	return _actor_call(actor_id, "set_graphic", [value, hue])


func change_actor_class(actor_id: int, value: Variant) -> Dictionary:
	var instance := actor(actor_id)
	if instance == null or not ActorState.Parameters.integer(value, 1) or RuntimeData.record("Classes", int(value)).is_empty():
		return {"ok": false, "message": "角色或目标职业不存在。"}
	var profession := RuntimeData.record("Classes", int(value))
	var proposed: Array = instance.equipment.duplicate()
	var stock := inventory.duplicate(true)
	for slot in 5:
		var equipment_id := int(proposed[slot])
		if equipment_id == 0:
			continue
		var database := "Weapons" if slot == 0 else "Armors"
		if RuntimeData.record(database, equipment_id).is_empty():
			return {"ok": false, "message": "当前装备引用缺失；职业和背包均未修改。"}
		var allowed: Array = profession.get("weapon_set" if slot == 0 else "armor_set", [])
		if RuntimeData.is_test_record(database, equipment_id) or allowed.any(func(id: Variant) -> bool: return int(id) == equipment_id):
			continue
		var key := "%s:%d" % ["weapon" if slot == 0 else "armor", equipment_id]
		var count: Variant = stock.get(key, 0)
		if not ActorState.Parameters.integer(count, 0, 98):
			return {"ok": false, "message": "不兼容装备无法收回（数量无效或已达 99）；职业和装备均未修改。"}
		stock[key] = int(count) + 1
		proposed[slot] = 0
	var preview: Dictionary = instance.snapshot(proposed)
	if preview.parameters.values().has(null):
		return {"ok": false, "message": "变更后属性无法计算；职业未修改。"}
	var modified: bool = instance.class_id != int(value) or instance.equipment != proposed
	instance.class_id = int(value)
	instance.equipment.assign(proposed)
	inventory = stock
	instance._clamp_vitals(preview.parameters)
	if modified:
		instance.changed.emit()
	return {"ok": true, "changed": modified, "message": "职业已更新，不兼容装备已收回；保留经验、等级和已学特技。"}


func _prepare_testing(setup: Dictionary) -> void:
	var initial_gold: Variant = setup.get("initial_gold", 0)
	if ShopService.integer(initial_gold, 0, ShopService.MAX_GOLD):
		gold = int(initial_gold)
	else:
		report_diagnostic("测试 initial_gold 必须为 0–9999999 的整数；未发放金币。")
	for entry in setup.get("stock", []):
		if not entry is Dictionary or not entry.get("id", 0) is float and not entry.get("id", 0) is int:
			report_diagnostic("测试 stock 条目必须包含数值 id。")
			continue
		var kind := str(entry.get("kind", ""))
		var id := int(entry.get("id", 0))
		var database := str(InventoryService.DATABASES.get(kind, ""))
		if database.is_empty() or not RuntimeData.is_test_record(database, id):
			report_diagnostic("测试 stock 引用未注册的测试物资：%s:%d" % [kind, id])
			continue
		var quantity: Variant = entry.get("quantity", 0)
		if not quantity is int and not quantity is float:
			report_diagnostic("测试物资数量必须为数字：%s:%d" % [kind, id])
			continue
		inventory["%s:%d" % [kind, id]] = clampi(int(quantity), 0, 99)
	for actor_id in party:
		var instance := actor(int(actor_id))
		if instance == null:
			continue
		for skill_id in setup.get("learn_skills", []):
			if skill_id is int or skill_id is float:
				change_skill(int(actor_id), int(skill_id), true)
		for state_id in setup.get("initial_states", []):
			if ShopService.integer(state_id, 1):
				change_state(int(actor_id), int(state_id), true)
		var view: Dictionary = instance.snapshot()
		var hp_ratio: Variant = setup.get("initial_hp_ratio", 0.5)
		var sp_ratio: Variant = setup.get("initial_sp_ratio", 0.5)
		if not hp_ratio is int and not hp_ratio is float:
			hp_ratio = 0.5
		if not sp_ratio is int and not sp_ratio is float:
			sp_ratio = 0.5
		if view.parameters.maxhp != null:
			instance.hp = maxi(1, int(int(view.parameters.maxhp) * clampf(float(hp_ratio), 0, 1)))
		if view.parameters.maxsp != null:
			instance.sp = int(int(view.parameters.maxsp) * clampf(float(sp_ratio), 0, 1))


func actor(actor_id: int, reset: bool = false) -> RefCounted:
	if actors.has(actor_id) and not reset:
		return actors[actor_id]
	var definition := RuntimeData.record("Actors", actor_id)
	if definition.is_empty():
		report_diagnostic("队伍引用了不存在的 Actors[%d]。" % actor_id)
		return null
	var instance := ActorState.new()
	instance.configure(actor_id, definition, RuntimeData.record)
	instance.changed.connect(func() -> void: state_changed.emit())
	actors[actor_id] = instance
	for message in instance.diagnostics:
		report_diagnostic(message)
	return instance


func party_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor_id in party:
		var instance := actor(int(actor_id))
		if instance != null:
			var view: Dictionary = instance.snapshot()
			result.append(view)
			for message in view.diagnostics:
				report_diagnostic(message)
	return result


func change_party(actor_id: int, adding: bool, initialize: bool = false) -> void:
	if adding:
		if actor(actor_id, initialize) == null:
			return
		if not party.has(actor_id):
			party.append(actor_id)
	else:
		party.erase(actor_id)
	state_changed.emit()


func record_step() -> void:
	steps += 1
	state_changed.emit()


func configure_player(value: Dictionary) -> Dictionary:
	var result: Dictionary = player_motion.configure(value)
	if result.ok: state_changed.emit()
	return result


func register_player(controller: Node) -> void:
	_player_ref = weakref(controller)


func player() -> Node:
	var controller: Node = null if _player_ref == null else _player_ref.get_ref()
	if not is_instance_valid(controller) or not controller.is_inside_tree(): return null
	var ancestor := controller
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return null
		ancestor = ancestor.get_parent()
	return controller


func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary:
	if number < 1 or number > 50 or not ScreenState.Picture.valid_name(name_value) or not ScreenState.Picture.pose_valid(pose, true):
		return _screen_result({"ok": false, "message": "图片编号、文件名或显示参数无效。"})
	if name_value.begins_with("@test_") and not testing_enabled:
		return _screen_result({"ok": false, "message": "测试图片只能在测试模式使用。"})
	if Cache.picture(name_value) == null:
		return _screen_result({"ok": false, "message": "Pictures[%d] 素材缺失：Graphics/Pictures/%s；原图片未替换，不补取 RTP。" % [number, name_value]})
	return _screen_result(screen.show_picture(number, name_value, pose))


func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary:
	return _screen_result(screen.move_picture(number, pose, seconds))


func rotate_picture(number: int, degrees_per_second: Variant) -> Dictionary:
	return _screen_result(screen.rotate_picture(number, degrees_per_second))


func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary:
	return _screen_result(screen.tint_picture(number, tone, seconds))


func erase_picture(number: int) -> Dictionary:
	return _screen_result(screen.erase_picture(number))


func _screen_result(result: Dictionary) -> Dictionary:
	if not result.ok: report_diagnostic(result.message)
	return result


func report_diagnostic(message: String) -> void:
	if not diagnostics.has(message):
		diagnostics.append(message)
		push_warning(message)
	diagnostic_added.emit(message)

func register_game(instance: Node) -> void: _game_ref = weakref(instance)

func game() -> Node:
	var instance: Node = _game_ref.get_ref() if _game_ref != null else null
	if instance == null or not instance.is_inside_tree() or instance.is_queued_for_deletion(): return null
	return instance

func map_time_paused() -> bool:
	return get_tree().paused or (game() != null and (game().event_screen_transition_active() or game().event_scene_transition_active()))

func windowskin_name() -> String: return system_settings.windowskin_name()

func set_windowskin(name_value: String) -> Dictionary:
	var parsed := Settings.decode({"windowskin_name": name_value})
	if not parsed.ok: return parsed
	if not name_value.is_empty():
		var skin: Texture2D = Cache.windowskin(name_value)
		if skin == null or skin.get_width() != 192 or skin.get_height() != 128: return {"ok": false, "message": "Windowskins/%s 缺失或不是192×128；原皮肤保持。" % name_value}
	system_settings = parsed.value
	system_settings_changed.emit()
	return {"ok": true}

func configure_map_view(changes: Dictionary) -> Dictionary:
	var result: Dictionary = map_view.configure(changes)
	if result.ok and game() != null: game()._camera.sync(0)
	return _screen_result(result)

func configure_map_effects(changes: Dictionary) -> Dictionary:
	for key in ["fog_name", "panorama_name"]:
		if changes.has(key) and changes[key] is String and not changes[key].is_empty():
			var texture: Texture2D = Cache.fog(changes[key]) if key == "fog_name" else Cache.panorama(changes[key])
			if texture == null: return _screen_result({"ok": false, "message": "%s 素材缺失：%s；原显示保持，不补取 RTP。" % [key, changes[key]]})
	return _screen_result(map_effects.configure(changes))

func scroll_map(direction: int, tiles: Variant, seconds: Variant = 0.0) -> Dictionary:
	if game() == null: return {"ok": false, "message": "当前没有地图。"}
	return game()._camera.scroll(direction, tiles, seconds)

func scroll_map_native(direction: int, tiles: int, speed: int) -> Dictionary:
	if game() == null: return {"ok": false, "message": "当前没有地图。"}
	return game().scroll_event_map(direction, tiles, speed)

func resume_map_follow() -> void: map_view.resume_follow()

func fade_screen(opacity: Variant, seconds: Variant = 0.0) -> Dictionary:
	if game() == null: return {"ok": false, "message": "当前没有地图画面。"}
	return game()._transition.fade(opacity, seconds)

func freeze_screen() -> Dictionary:
	if game() == null: return {"ok": false, "message": "当前没有地图画面。"}
	return await game()._transition.freeze_screen()

func transition_screen(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary:
	if game() == null: return {"ok": false, "message": "当前没有地图画面。"}
	return game()._transition.transition(seconds, name_value, vague)

func cancel_screen_transition() -> void:
	if game() != null:
		game().cancel_event_transfer()
		game().cancel_event_screen_transition()


func self_switch_key(map_value: int, event_id: int, letter: String) -> String:
	return "%d:%d:%s" % [map_value, event_id, letter]


func restore_prepared(prepared: Dictionary, preserve_audio: bool = false) -> void:
	execution_reset.emit()
	screen = prepared.screen
	map_view = prepared.map_view
	map_effects = prepared.map_effects
	timer = prepared.timer
	system_settings = prepared.system_settings
	if audio != null and not preserve_audio: audio.restore_prepared(prepared.audio)
	# SaveCodec has validated every field and built detached actors before commit.
	var saved: Dictionary = prepared.state
	pending_event_state = saved.get("event_state", {}).duplicate(true)
	common_event_reservation = saved.get("common_event_reservation", {}).duplicate(true)
	player_motion.reset()
	player_motion.configure(saved.player_options)
	RuntimeData.install_testing(saved.testing.enabled, prepared.test_records)
	testing_enabled = saved.testing.enabled
	actors = prepared.actors
	for instance in actors.values():
		instance.changed.connect(func() -> void: state_changed.emit())
	for field in ["switches", "variables", "self_switches", "inventory", "party"]:
		set(field, saved[field].duplicate(true))
	for field in ["gold", "map_id", "player_x", "player_y", "player_direction", "steps", "save_count", "message_position", "message_frame"]:
		set(field, int(saved[field]))
	play_seconds = float(saved.play_seconds)
	_clock_second = int(play_seconds)
	save_disabled = saved.save_disabled
	menu_disabled = saved.menu_disabled
	diagnostics.clear()
	playing = true
	resume_from_save = true
	system_settings_changed.emit()
	state_changed.emit()
	if not preserve_audio and game() != null and not pending_event_state.is_empty(): game().restore_event_state()

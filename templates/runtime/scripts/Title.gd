extends Control

const RuntimeData = preload("res://runtime/scripts/RuntimeData.gd")
const Saves = preload("res://runtime/scripts/SaveService.gd")
const Slots = preload("res://runtime/scripts/SaveSlots.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")

var _menu: VBoxContainer
var _slots: Control
var _flash: Control


func _ready() -> void:
	RuntimeState.playing = false
	RuntimeState.audio.stop_all()
	get_tree().paused = false
	if RuntimeState.custom_data.manifest.get("profile")=="flash":
		_flash=preload("FlashTitleScreen.gd").new()
		_flash.new_game_requested.connect(_on_flash_new_game); _flash.load_requested.connect(_load_game)
		add_child(_flash); _play_title_bgm(); return
	_build_background()
	_build_menu()
	_play_title_bgm()


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("151a24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var system := RuntimeData.system()
	var title_name := str(system.get("title_name", ""))
	var title_texture := Cache.title(title_name)
	if title_texture != null:
		var image := TextureRect.new()
		image.texture = title_texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(image)


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	center.add_child(_menu)
	var title := Label.new()
	title.text = ProjectSettings.get_setting("application/config/name", "RMXP Game")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	_menu.add_child(title)
	if bool(RuntimeData.test_config().get("enabled", false)):
		var testing := Label.new()
		testing.text = "测试模式：新游戏准备药品、装备与特技"
		testing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		testing.add_theme_font_size_override("font_size", 16)
		testing.modulate = Color("ffe9a8")
		_menu.add_child(testing)
	var new_game := Button.new()
	new_game.text = "新游戏"
	new_game.custom_minimum_size = Vector2(220, 46)
	new_game.pressed.connect(_on_new_game)
	_menu.add_child(new_game)
	var continue_game := Button.new()
	continue_game.text = "继续游戏"
	continue_game.custom_minimum_size = Vector2(220, 42)
	continue_game.disabled = not Saves.has_valid_save()
	continue_game.pressed.connect(_on_continue)
	_menu.add_child(continue_game)
	var unavailable: Array[String] = []
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var info := Saves.slot_info(slot)
		if not info.ok and info.exists:
			unavailable.append("存档 %d：%s" % [slot, info.message])
	if not unavailable.is_empty():
		var notice := Label.new()
		notice.text = "存在不可用存档：" + unavailable[0].substr(unavailable[0].find("：") + 1).left(24)
		notice.tooltip_text = "\n".join(unavailable)
		notice.mouse_filter = Control.MOUSE_FILTER_STOP
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.add_theme_font_size_override("font_size", 14)
		notice.modulate = Color("ffb6a6")
		_menu.add_child(notice)
	call_deferred("_focus_new_game", new_game)
	var quit := Button.new()
	quit.text = "退出"
	quit.custom_minimum_size = Vector2(220, 42)
	quit.pressed.connect(RuntimeState.request_quit)
	_menu.add_child(quit)


func _play_title_bgm() -> void:
	var bgm: Variant = RuntimeData.system().get("title_bgm", {})
	if not (bgm is Dictionary):
		return
	var result: Dictionary = RuntimeState.audio.play("BGM", bgm)
	if not result.ok: RuntimeState.report_diagnostic(result.message)


func _on_new_game() -> void:
	RuntimeState.begin_new_game(RuntimeData.system())
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_flash_new_game(difficulty: int) -> void:
	RuntimeState.begin_new_game(RuntimeData.system())
	var variable_id=int(RuntimeState.custom_data.gameplay().rules.constants.get("DIFFCULTY_MODE",141))
	RuntimeState.set_event_variable(variable_id,difficulty)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _focus_new_game(button: Button) -> void:
	if is_inside_tree() and is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _on_continue() -> void:
	if _slots != null:
		return
	_menu.hide()
	_slots = Slots.new()
	_slots.mode = "load"
	_slots.back_requested.connect(_close_slots)
	_slots.load_requested.connect(_load_game)
	_slots.sound_requested.connect(func(key: String) -> void: Resources.play_sound(self, key))
	add_child(_slots)


func _close_slots() -> void:
	_slots.queue_free()
	_slots = null
	_menu.show()
	for button in _menu.get_children():
		if button is Button and button.text == "继续游戏":
			button.grab_focus()


func _load_game(slot: int) -> void:
	var result := Saves.load_slot(slot, RuntimeState)
	if not result.ok:
		var slots: Control=_flash.child if _flash!=null else _slots
		if slots!=null: slots.message = result.message; slots.refresh()
		return
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if _flash!=null:
		get_viewport().set_input_as_handled(); _flash.handle_key(key); return
	if _slots != null:
		get_viewport().set_input_as_handled()
		if key in [KEY_UP, KEY_LEFT]:
			_slots.navigate(-1)
		elif key in [KEY_DOWN, KEY_RIGHT]:
			_slots.navigate(1)
		elif key in [KEY_ESCAPE, KEY_X]:
			_slots.back()
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
			_slots.activate()
	elif key == KEY_Z:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and not focus.disabled:
			get_viewport().set_input_as_handled()
			focus.pressed.emit()

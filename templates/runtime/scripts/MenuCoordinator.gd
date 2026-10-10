extends CanvasLayer
const MenuScene = preload("res://scenes/Menu.tscn")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const ShopScene = preload("res://runtime/scripts/ShopScene.gd")
const ShopService = preload("res://runtime/scripts/ShopService.gd")
var game: Node
var menu: Control
var name_input: Control
var shop: Control
var _pending_menu := false
var _event_request_id := -1
var _menu_request_id := -1
var _menu_request_kind := "menu"
var _name_request_id := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50


func can_open() -> bool:
	return menu == null and shop == null and name_input == null and not get_tree().paused and not RuntimeState.menu_disabled and game != null and game._player.input_enabled and game._player.is_idle() and not game._dialogue.is_open() and not game._interpreter.running


func _process(_delta: float) -> void:
	if not _pending_menu: return
	if game._dialogue.is_open() or game._interpreter.running or RuntimeState.menu_disabled:
		_pending_menu = false
		game._player.stop_after_step = false
	elif can_open():
		_pending_menu = false
		open_menu()


func open_menu() -> bool:
	if not can_open():
		return false
	return _open_menu()


func open_event_menu(request_id: int) -> Dictionary:
	if menu != null or shop != null or name_input != null or game == null or get_tree().paused or game._dialogue.is_open() or not game._player.is_idle(): return {"ok": false, "message": "事件菜单被其他界面或人物移动占用。"}
	return {"ok": _open_menu(request_id)}


func open_event_save(request_id: int) -> Dictionary:
	if menu != null or shop != null or name_input != null or game == null or get_tree().paused or game._dialogue.is_open() or not game._player.is_idle(): return {"ok": false, "message": "事件存档被其他界面或人物移动占用。"}
	return {"ok": _open_menu(request_id, "save")}

func _open_menu(request_id: int = -1, kind: String = "menu") -> bool:
	_menu_request_id = request_id
	_menu_request_kind = kind
	_pending_menu = false
	game._player.stop_after_step = false
	menu = MenuScene.instantiate()
	if kind == "save":
		menu.page = "save"
		menu.scene_stack.assign(["save"])
	menu.save_callback = game.save_slot
	menu.close_requested.connect(close_menu)
	menu.event_test_requested.connect(func() -> void:
		close_menu()
		var result: Dictionary = game.enter_event_test_map()
		if not result.ok: game._show_diagnostic(result.message)
	)
	menu.title_requested.connect(return_to_title)
	menu.quit_requested.connect(RuntimeState.request_quit)
	menu.sound_requested.connect(func(key: String) -> void: Resources.play_sound(self, key))
	game._player.input_enabled = false
	if game._test_label != null:
		game._test_label.hide()
	get_tree().paused = true
	add_child(menu)
	Resources.play_sound(self, "decision_se")
	return true


func close_menu() -> void:
	if menu == null: return
	remove_child(menu); menu.queue_free(); menu = null
	var request_id := _menu_request_id; _menu_request_id = -1
	get_tree().paused = false
	if game._test_label != null: game._test_label.show()
	if request_id >= 0: game._event_response(request_id, _menu_request_kind, null)
	game._sync_event_input()
	if game._player.input_enabled: game._player.resume_after_menu()

func return_to_title() -> void:
	game.request_event_scene("title")

func open_name(actor_id: int, maximum: int, request_id: int) -> Dictionary:
	if menu != null or shop != null or name_input != null or game == null or game._dialogue.is_open() or get_tree().paused: return {"ok": false, "message": "姓名输入被其他界面占用。"}
	var actor: RefCounted = RuntimeState.actor(actor_id)
	if actor == null: return {"ok": false, "message": "姓名输入角色不存在。"}
	name_input = preload("res://runtime/scripts/NameInput.gd").new()
	_name_request_id = request_id
	name_input.actor_id = actor_id; name_input.maximum = maximum; name_input.initial_name = actor.actor_name
	name_input.confirmed.connect(func(value: String) -> void: close_name(request_id, value))
	game._player.input_enabled = false
	if game._test_label != null: game._test_label.hide()
	get_tree().paused = true
	add_child(name_input)
	return {"ok": true}

func close_name(request_id: int = -1, value: Variant = null) -> void:
	if name_input == null or (request_id >= 0 and request_id != _name_request_id): return
	remove_child(name_input); name_input.queue_free(); name_input = null
	var id := _name_request_id; _name_request_id = -1
	get_tree().paused = false
	if game._test_label != null: game._test_label.show()
	if value is String: game._event_response(id, "name", value)
	game._sync_event_input()
	if game._player.input_enabled: game._player.resume_after_menu()


func open_shop(goods: Array, request_id: int = -1) -> Dictionary:
	if menu != null or shop != null or name_input != null or game == null or game._dialogue.is_open() or get_tree().paused:
		return {"ok": false, "message": "商店上下文被其他界面占用。"}
	var parsed := ShopService.catalog(goods)
	if not parsed.ok:
		return parsed
	shop = ShopScene.new()
	_event_request_id = request_id
	shop.goods = goods.duplicate(true)
	shop.back_requested.connect(close_shop)
	shop.sound_requested.connect(func(key: String) -> void: Resources.play_sound(self, key))
	game._player.input_enabled = false
	if game._test_label != null:
		game._test_label.hide()
	get_tree().paused = true
	add_child(shop)
	return {"ok": true}


func close_shop() -> void:
	if shop == null:
		return
	remove_child(shop)
	shop.queue_free()
	shop = null
	var request_id := _event_request_id
	_event_request_id = -1
	get_tree().paused = false
	if game._test_label != null:
		game._test_label.show()
	if request_id >= 0: game._event_response(request_id, "shop", null)
	game._sync_event_input()
	if game._player.input_enabled: game._player.resume_after_menu()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if name_input != null:
		if key == KEY_ESCAPE and not event.echo:
			name_input.back()
			get_viewport().set_input_as_handled()
		return
	var cancel := key in [KEY_ESCAPE, KEY_X]
	if shop != null:
		get_viewport().set_input_as_handled()
		if not event.echo or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			shop.handle_key(key)
		return
	if menu == null:
		if cancel and not event.echo and open_menu():
			get_viewport().set_input_as_handled()
		elif cancel and not event.echo and game._player.input_enabled and not game._player.is_idle() and not RuntimeState.menu_disabled:
			_pending_menu = true
			game._player.stop_after_step = true
			get_viewport().set_input_as_handled()
		return
	# Consume all keyboard input while a menu owns focus, including disabled actions.
	if menu.page in ["actor_tools", "presentation_tools"] and menu._commerce.has_text_focus():
		if key == KEY_ESCAPE and not event.echo:
			menu._commerce.back()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if menu.page in ["movement_tools", "presentation_tools"]:
		if not event.echo or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]: menu._commerce.handle_key(key)
		return
	if key == KEY_F6 and not event.echo and menu.page == "menu":
		menu.open_test_tools()
		return
	if menu.page == "shop":
		if not event.echo or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			menu._commerce.handle_key(key)
		return
	if menu.page == "actor_tools":
		if not event.echo or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			menu._commerce.handle_key(key)
		return
	if key in [KEY_UP, KEY_LEFT]:
		menu.navigate(-1)
	elif key in [KEY_DOWN, KEY_RIGHT]:
		menu.navigate(1)
	elif not event.echo and cancel:
		menu.handle_back()
	elif not event.echo and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
		menu.activate()


func _exit_tree() -> void:
	if menu != null or shop != null or name_input != null:
		get_tree().paused = false

## 职责：协调地图与菜单场景的进入、返回、暂停及物品技能后的事件预约。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/Main/MenuCoordinator.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func can_open() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func open_menu() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func open_flash_map() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func open_flash_history() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func open_flash_sight() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func open_event_menu(request_id: int) -> Dictionary
##     参数 request_id（int；必填）：用于匹配响应、取消和等待的请求编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func open_event_save(request_id: int) -> Dictionary
##     参数 request_id（int；必填）：用于匹配响应、取消和等待的请求编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func capture_flash_archive_snapshot() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func begin_flash_backdrop() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func load_flash_archive(slot: int) -> void
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func open_flash_scene( source_name: String, args: Array = [], done: Callable = Callable() ) -> Dictionary
##     参数 source_name（String；必填）：用于显示或诊断的来源名称。
##     参数 args（Array；默认值 []）：按调用顺序排列的参数值。
##     参数 done（Callable；默认值 Callable()）：异步操作结束时调用的回调。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func close_menu() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func return_to_title() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func open_name(actor_id: int, maximum: int, request_id: int) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 maximum（int；必填）：允许值的上限。
##     参数 request_id（int；必填）：用于匹配响应、取消和等待的请求编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func close_name(request_id: int = -1, value: Variant = null) -> void
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     参数 value（Variant；默认值 null）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func open_shop(goods: Array, request_id: int = -1) -> Dictionary
##     参数 goods（Array；必填）：商店商品记录列表。
##     参数 request_id（int；默认值 -1）：用于匹配响应、取消和等待的请求编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func close_shop() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(_delta: float) -> void
##     _delta：为保持原接口位置保留，本实现未读取此参数。
##   func _input(event: InputEvent) -> void
##     event：输入事件或当前游戏事件对象，类型见签名。
##   func _exit_tree() -> void
##
## 接口说明结束。

extends CanvasLayer
const MenuScene = preload("res://scenes/08_Menu/Menu.tscn")
const Resources = preload("res://runtime/scripts/04_UI_Common/UIResources.gd")
const UIInput = preload("../../04_UI_Common/UIInput.gd")
const ShopScene = preload("res://runtime/scripts/08_Menu/Shop/ShopScene.gd")
const ShopService = preload("res://runtime/scripts/08_Menu/Shop/ShopService.gd")
var game: Node
var menu: Control
var name_input: Control
var shop: Control
var _pending_menu := false
var _event_request_id := -1
var _menu_request_id := -1
var _menu_request_kind := "menu"
var _name_request_id := -1
var _flash_scene_done: Callable
var _flash_backdrop: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50


func can_open() -> bool:
	if RuntimeState.flash_effects != null and RuntimeState.flash_effects.busy():
		return false
	return (
		menu == null
		and shop == null
		and name_input == null
		and not get_tree().paused
		and not RuntimeState.menu_disabled
		and game != null
		and game._player.input_enabled
		and game._player.is_idle()
		and not game._dialogue.is_open()
		and not game._interpreter.running
	)


func _process(_delta: float) -> void:
	if not _pending_menu:
		return
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


func open_flash_map() -> bool:
	if (
		not can_open()
		or game.event_scene_transition_active()
		or game.event_screen_transition_active()
		or game._transfer_active > 0
	):
		return false
	if RuntimeState.custom_data.manifest.get("profile") != "flash":
		return false
	menu = preload("../MapSystem/MapScreen.gd").new()
	menu.close_requested.connect(close_menu)
	_pending_menu = false
	_menu_request_id = -1
	game._player.input_enabled = false
	game._player.stop_after_step = false
	if game._test_label != null:
		game._test_label.hide()
	get_tree().paused = true
	add_child(menu)
	Resources.play_sound(self, "decision_se")
	return true


func open_flash_history() -> bool:
	if RuntimeState.flash_effects != null and RuntimeState.flash_effects.busy():
		return false
	if (
		RuntimeState.flash_messages == null
		or game == null
		or menu != null
		or shop != null
		or name_input != null
		or get_tree().paused
		or game._scene_pending
		or game._transfer_active > 0
		or game.event_screen_transition_active()
	):
		return false
	menu = preload("../../06_Message/MessageMemoryPage.gd").new()
	menu.close_requested.connect(close_menu)
	_pending_menu = false
	_menu_request_id = -1
	game._player.input_enabled = false
	if game._test_label != null:
		game._test_label.hide()
	get_tree().paused = true
	add_child(menu)
	return true


func open_flash_sight() -> bool:
	if (
		RuntimeState.custom_data.manifest.get("profile") != "flash"
		or not can_open()
		or game.event_screen_transition_active()
		or game._transfer_active > 0
	):
		return false
	var opened = preload("../../10_Support/Scripting/ScriptRuntime.gd").call_transaction(
		RuntimeState,
		{"source": "0200.enter_sight"},
		func(env):
			var constants: Dictionary = env._custom.gameplay().rules.constants
			env.index_set({"__state_table": "switch"}, int(constants.get("MASK_ENABLED", 4)), true)
			env.index_set(
				{"__state_table": "variable"}, int(constants.get("MASK_OPACITY", 13)), 128
			)
			return true
	)
	if not opened.ok:
		RuntimeState.report_diagnostic(opened.message)
		return false
	menu = preload("../Sight/SightPage.gd").new()
	menu.game = game
	menu.close_requested.connect(close_menu)
	_pending_menu = false
	_menu_request_id = -1
	game._player.input_enabled = false
	if game._test_label != null:
		game._test_label.hide()
	get_tree().paused = true
	add_child(menu)
	return true


func open_event_menu(request_id: int) -> Dictionary:
	if (
		menu != null
		or shop != null
		or name_input != null
		or game == null
		or get_tree().paused
		or game._dialogue.is_open()
		or not game._player.is_idle()
	):
		return {"ok": false, "message": "事件菜单被其他界面或人物移动占用。"}
	return {"ok": _open_menu(request_id)}


func open_event_save(request_id: int) -> Dictionary:
	if (
		menu != null
		or shop != null
		or name_input != null
		or game == null
		or get_tree().paused
		or game._dialogue.is_open()
		or not game._player.is_idle()
	):
		return {"ok": false, "message": "事件存档被其他界面或人物移动占用。"}
	return {"ok": _open_menu(request_id, "save")}


func _open_menu(request_id: int = -1, kind: String = "menu") -> bool:
	_menu_request_id = request_id
	_menu_request_kind = kind
	_pending_menu = false
	game._player.stop_after_step = false
	if kind == "menu" and RuntimeState.custom_data.manifest.get("profile") == "flash":
		capture_flash_archive_snapshot()
		# 最终0200.call_menu没有开启模糊；保留地图并让原HUD自行收起，截图仅用于存档预览。
		menu = preload("MenuScreen.gd").new()
		menu.save_callback = game.save_slot
		menu.close_requested.connect(close_menu)
		menu.title_requested.connect(return_to_title)
		menu.sound_requested.connect(func(key: String): Resources.play_sound(self, key))
		menu.load_requested.connect(load_flash_archive)
		game._player.input_enabled = false
		if game._test_label != null:
			game._test_label.hide()
		get_tree().paused = true
		add_child(menu)
		Resources.play_sound(self, "decision_se")
		return true
	if kind == "save" and RuntimeState.custom_data.manifest.get("profile") == "flash":
		capture_flash_archive_snapshot()
		menu = load("res://runtime/scripts/07_Archive/ArchivePage.gd").new()
		menu.save_callback = game.save_slot
		menu.back_requested.connect(close_menu)
		menu.load_requested.connect(load_flash_archive)
		menu.sound_requested.connect(func(key): Resources.play_sound(self, key))
		game._player.input_enabled = false
		get_tree().paused = true
		add_child(menu)
		return true
	menu = MenuScene.instantiate()
	if kind == "save":
		menu.page = "save"
		menu.scene_stack.assign(["save"])
	menu.save_callback = game.save_slot
	menu.close_requested.connect(close_menu)
	menu.event_test_requested.connect(
		func() -> void:
			close_menu()
			var result: Dictionary = game.enter_event_test_map()
			if not result.ok:
				game._show_diagnostic(result.message)
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


func capture_flash_archive_snapshot() -> void:
	RuntimeState.flash_archive_snapshot = null
	if DisplayServer.get_name() == "headless" or game == null:
		return
	var image = get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		RuntimeState.flash_archive_snapshot = image.duplicate()


func begin_flash_backdrop() -> void:
	if is_instance_valid(_flash_backdrop):
		remove_child(_flash_backdrop)
		_flash_backdrop.queue_free()
	_flash_backdrop = null
	if RuntimeState.flash_archive_snapshot == null:
		return
	_flash_backdrop = load("res://runtime/scripts/04_UI_Common/SceneBackdrop.gd").new()
	_flash_backdrop.texture = ImageTexture.create_from_image(RuntimeState.flash_archive_snapshot)
	add_child(_flash_backdrop)


func load_flash_archive(slot: int) -> void:
	var progress = preload("../../10_Support/Persistence/SaveLoadProgress.gd").new()
	get_tree().root.add_child(progress)
	var result: Dictionary = await progress.read_slot(slot, self)
	if not result.ok:
		progress.close()
		if menu != null:
			if menu.has_method("resume_after_failed_load"):
				menu.resume_after_failed_load()
			var slots: Control = menu.child if menu.get("child") != null else menu
			if slots.has_method("resume_after_failed_load"):
				slots.message = result.message
				slots.resume_after_failed_load()
		RuntimeState.report_diagnostic(result.message)
		return
	close_menu()
	get_tree().paused = true
	RuntimeState.restore_prepared(result.prepared, false, false)
	get_tree().change_scene_to_packed(progress.game_scene)
	progress.finish_after_scene()


func open_flash_scene(
	source_name: String, args: Array = [], done: Callable = Callable()
) -> Dictionary:
	var registry = preload("SceneRegistry.gd")
	var reason = registry.validate(source_name, args, RuntimeState)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	if (
		RuntimeState.custom_data.manifest.get("profile") != "flash"
		or game == null
		or menu != null
		or shop != null
		or name_input != null
		or get_tree().paused
		or game._dialogue.is_open()
		or not game._player.is_idle()
		or RuntimeState.flash_effects.busy()
	):
		return {"ok": false, "message": "独立页面的地图上下文被占用。"}
	if source_name == "Scene_Shop":
		var opened = open_shop(RuntimeState.flash_temp_fields.get("shop_goods", []))
		if opened.ok:
			_flash_scene_done = done
		return opened
	menu = registry.create(source_name, args, RuntimeState)
	_flash_scene_done = done
	_menu_request_id = -1
	menu.back_requested.connect(close_menu)
	if menu.has_signal("common_event_requested"):
		menu.common_event_requested.connect(close_menu)
	if menu.has_signal("sound_requested"):
		menu.sound_requested.connect(func(key): Resources.play_sound(self, key))
	game._player.input_enabled = false
	get_tree().paused = true
	add_child(menu)
	return {"ok": true}


func close_menu() -> void:
	if menu == null:
		return
	if menu.page == "flash_sight":
		var result = preload("../../10_Support/Scripting/ScriptRuntime.gd").call_transaction(
			RuntimeState,
			{"source": "0202.exit_sight"},
			func(env):
				return env.index_set(
					{"__state_table": "switch"},
					int(env._custom.gameplay().rules.constants.get("MASK_ENABLED", 4)),
					false
				)
		)
		if not result.ok:
			RuntimeState.report_diagnostic(result.message)
	remove_child(menu)
	menu.queue_free()
	menu = null
	if is_instance_valid(_flash_backdrop):
		_flash_backdrop.entering = false
	var request_id := _menu_request_id
	_menu_request_id = -1
	get_tree().paused = false
	if game._test_label != null:
		game._test_label.show()
	if request_id >= 0:
		game._event_response(request_id, _menu_request_kind, null)
	game._sync_event_input()
	if game._player.input_enabled:
		game._player.resume_after_menu()
	var done = _flash_scene_done
	_flash_scene_done = Callable()
	if done.is_valid():
		done.call()


func return_to_title() -> void:
	game.request_event_scene("title")


func open_name(actor_id: int, maximum: int, request_id: int) -> Dictionary:
	if (
		menu != null
		or shop != null
		or name_input != null
		or game == null
		or game._dialogue.is_open()
		or get_tree().paused
	):
		return {"ok": false, "message": "姓名输入被其他界面占用。"}
	var actor: RefCounted = RuntimeState.actor(actor_id)
	if actor == null:
		return {"ok": false, "message": "姓名输入角色不存在。"}
	name_input = preload("res://runtime/scripts/06_Message/NameInput.gd").new()
	_name_request_id = request_id
	name_input.actor_id = actor_id
	name_input.maximum = maximum
	name_input.initial_name = actor.actor_name
	name_input.confirmed.connect(func(value: String) -> void: close_name(request_id, value))
	game._player.input_enabled = false
	if game._test_label != null:
		game._test_label.hide()
	get_tree().paused = true
	add_child(name_input)
	return {"ok": true}


func close_name(request_id: int = -1, value: Variant = null) -> void:
	if name_input == null or (request_id >= 0 and request_id != _name_request_id):
		return
	remove_child(name_input)
	name_input.queue_free()
	name_input = null
	var id := _name_request_id
	_name_request_id = -1
	get_tree().paused = false
	if game._test_label != null:
		game._test_label.show()
	if value is String:
		game._event_response(id, "name", value)
	game._sync_event_input()
	if game._player.input_enabled:
		game._player.resume_after_menu()


func open_shop(goods: Array, request_id: int = -1) -> Dictionary:
	if (
		menu != null
		or shop != null
		or name_input != null
		or game == null
		or game._dialogue.is_open()
		or get_tree().paused
	):
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
	if request_id >= 0:
		game._event_response(request_id, "shop", null)
	game._sync_event_input()
	if game._player.input_enabled:
		game._player.resume_after_menu()
	var done = _flash_scene_done
	_flash_scene_done = Callable()
	if done.is_valid():
		done.call()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key: int = UIInput.key(event)
	if name_input != null:
		if key == KEY_ESCAPE and not event.echo:
			name_input.back()
			get_viewport().set_input_as_handled()
		return
	var cancel := key in [KEY_ESCAPE, KEY_X]
	if shop != null:
		get_viewport().set_input_as_handled()
		if UIInput.accepts(event):
			shop.handle_key(key)
		return
	if menu == null:
		if (
			key == KEY_BACKSPACE
			and not event.echo
			and can_open()
			and RuntimeState.flash_history != null
		):
			var result = RuntimeState.flash_history.undo()
			if not result.ok:
				RuntimeState.report_diagnostic("撤回失败：" + result.message)
			get_viewport().set_input_as_handled()
			return
		if (
			key == KEY_F9
			and not event.echo
			and OS.is_debug_build()
			and can_open()
			and RuntimeState.custom_data.manifest.get("profile") == "flash"
		):
			if open_flash_scene("Scene_Debug").ok:
				get_viewport().set_input_as_handled()
			return
		if key == KEY_L and not event.echo and open_flash_history():
			get_viewport().set_input_as_handled()
			return
		if key == KEY_A and not event.echo and open_flash_sight():
			get_viewport().set_input_as_handled()
			return
		if (
			not event.echo
			and RuntimeState.custom_data.manifest.get("profile") == "flash"
			and can_open()
		):
			var result: Dictionary = {}
			if key >= KEY_1 and key <= KEY_9:
				if key <= KEY_8 and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_E)):
					result = preload("../../03_Map/MapShortcuts.gd").load_group(
						RuntimeState, key - KEY_1, "atk" if Input.is_key_pressed(KEY_W) else "sup"
					)
				else:
					result = preload("../../03_Map/MapShortcuts.gd").use_slot(
						RuntimeState, key - KEY_1 + 1
					)
			elif key in [KEY_TAB, KEY_CAPSLOCK]:
				result = preload("../../03_Map/MapShortcuts.gd").switch_roles(
					RuntimeState, key
				)
			if not result.is_empty():
				if not result.ok:
					RuntimeState.report_diagnostic(str(result.get("message", "")))
				get_viewport().set_input_as_handled()
				return
		if key == KEY_M and not event.echo and open_flash_map():
			get_viewport().set_input_as_handled()
			return
		if cancel and not event.echo and open_menu():
			get_viewport().set_input_as_handled()
		elif (
			cancel
			and not event.echo
			and game._player.input_enabled
			and not game._player.is_idle()
			and not RuntimeState.menu_disabled
		):
			_pending_menu = true
			game._player.stop_after_step = true
			get_viewport().set_input_as_handled()
		return
	if menu.has_method("handle_key"):
		get_viewport().set_input_as_handled()
		if (
			UIInput.accepts(event)
			and (not menu.has_method("ready_for_input") or menu.ready_for_input())
		):
			menu.handle_key(key)
		return
	# Consume all keyboard input while a menu owns focus, including disabled actions.
	if menu.page in ["actor_tools", "presentation_tools"] and menu._commerce.has_text_focus():
		if key == KEY_ESCAPE and not event.echo:
			menu._commerce.back()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if menu.page in ["movement_tools", "presentation_tools"]:
		if not event.echo or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			menu._commerce.handle_key(key)
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

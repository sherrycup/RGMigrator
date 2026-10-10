extends Control
signal close_requested
signal event_test_requested
signal title_requested
signal quit_requested
signal sound_requested(key: String)

const WindowBase = preload("res://runtime/scripts/WindowBase.gd")
const WindowCommand = preload("res://runtime/scripts/WindowCommand.gd")
const WindowSelectable = preload("res://runtime/scripts/WindowSelectable.gd")
const UISpriteset = preload("res://runtime/scripts/UISpriteset.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const InventoryScene = preload("res://runtime/scripts/InventoryScene.gd")
const SkillScene = preload("res://runtime/scripts/SkillScene.gd")
const SaveSlots = preload("res://runtime/scripts/SaveSlots.gd")
const ShopScene = preload("res://runtime/scripts/ShopScene.gd")
const StateTools = preload("res://runtime/scripts/StateTools.gd")
const TestTools = preload("res://runtime/scripts/TestTools.gd")
const ActorTools = preload("res://runtime/scripts/ActorTools.gd")
const ScreenTools = preload("res://runtime/scripts/ScreenTools.gd")
const MovementTools = preload("res://runtime/scripts/MovementTools.gd")
const PresentationTools = preload("res://runtime/scripts/PresentationTools.gd")
var save_callback: Callable

var page := "menu"
var actor_index := 0
var command_index := 3
var scene_stack: Array[String] = ["menu"]
var _commands: Control
var _party: Control
var _clock: Label
var _gold: Label
var _steps: Label
var _hint: Label
var _views: Array[Dictionary] = []
var _view_signature := ""
var _root_panel: Control
var _end_commands: Control
var _commerce: Control
var _dirty := true
var content_rebuilds := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	RuntimeState.state_changed.connect(_mark_dirty)
	RuntimeState.diagnostic_added.connect(func(_message: String) -> void: _mark_dirty())
	resized.connect(_layout)
	_views = RuntimeState.party_snapshots()
	_view_signature = JSON.stringify([_views, RuntimeState.inventory, RuntimeState.save_disabled])
	_layout()


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	var views := RuntimeState.party_snapshots()
	var signature := JSON.stringify([views, RuntimeState.inventory, RuntimeState.save_disabled])
	if signature != _view_signature:
		_view_signature = signature
		_views = views
		actor_index = clampi(actor_index, 0, maxi(0, _views.size() - 1))
		if _views.is_empty() and page in ["actors", "status", "equipment", "skills"]:
			page = "menu"
			scene_stack = ["menu"]
		if _commerce != null and page in ["inventory", "equipment", "skills", "shop", "state_tools", "actor_tools", "test_tools", "screen_tools", "movement_tools", "presentation_tools"]:
			if page in ["equipment", "skills"]:
				_commerce.actor_id = int(_views[actor_index].id)
			_commerce.refresh()
		else:
			_layout()
	_update_counters()


func _layout() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	content_rebuilds += 1
	if _root_panel != null:
		remove_child(_root_panel)
		_root_panel.queue_free()
	_root_panel = Control.new()
	_root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_panel)
	_commands = null
	_party = null
	_clock = null
	_gold = null
	_steps = null
	_hint = null
	_end_commands = null
	_commerce = null
	if page == "status":
		_build_status()
	elif page == "end":
		_build_end()
	elif page in ["inventory", "equipment", "skills", "save", "shop", "state_tools", "actor_tools", "test_tools", "screen_tools", "movement_tools", "presentation_tools"]:
		var script: Script = {"shop": ShopScene, "state_tools": StateTools, "save": SaveSlots, "skills": SkillScene, "actor_tools": ActorTools, "test_tools": TestTools, "screen_tools": ScreenTools, "movement_tools": MovementTools, "presentation_tools": PresentationTools}.get(page, InventoryScene)
		_commerce = script.new()
		if page in ["inventory", "skills"]: _commerce.common_event_requested.connect(func() -> void: close_requested.emit())
		if page == "test_tools":
			_commerce.tool_requested.connect(_push)
		if page == "save":
			_commerce.save_callback = save_callback
		elif page == "shop":
			_commerce.goods = Resources.RuntimeData.test_config().get("shop_goods", [])
		elif page in ["inventory", "equipment"]:
			_commerce.mode = page
		if page in ["equipment", "skills"] and not _views.is_empty():
			_commerce.actor_id = _views[actor_index].id
		_commerce.back_requested.connect(back)
		_commerce.sound_requested.connect(func(key: String) -> void: sound_requested.emit(key))
		_root_panel.add_child(_commerce)
	else:
		_build_menu()
	_update_counters()


func _window(script: Script, rectangle: Rect2) -> Control:
	var window: Control = script.new()
	window.position = rectangle.position
	window.size = rectangle.size
	_root_panel.add_child(window)
	return window


func _build_menu() -> void:
	var left := 160.0
	# Keep the standard counter windows intact at 640x480. The test entry fits
	# inside the existing footer, rather than stealing the gold window's padding.
	var hint_height := 40.0
	_commands = _window(WindowCommand, Rect2(0, 0, left, 224))
	_commands.active = page == "menu"
	_commands.configure([
		{"text": Resources.word("item", "物品"), "enabled": true},
		{"text": Resources.word("skill", "技能"), "enabled": not _views.is_empty()},
		{"text": Resources.word("equip", "装备"), "enabled": not _views.is_empty()},
		{"text": "状态", "enabled": not _views.is_empty()},
		{"text": "存档", "enabled": not RuntimeState.save_disabled},
		{"text": "结束游戏", "enabled": true}
	], command_index)
	var clock_window := _window(WindowBase, Rect2(0, 224, left, 80))
	clock_window.label("游戏时间", Rect2(0, 0, 128, 24), Color("c0e0ff"), 18)
	_clock = clock_window.label("", Rect2(0, 24, 128, 24))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var steps_window := _window(WindowBase, Rect2(0, 304, left, 72))
	steps_window.label("步数", Rect2(0, 0, 128, 20), Color("c0e0ff"), 18)
	_steps = steps_window.label("", Rect2(0, 20, 128, 20), Color.WHITE, 17)
	_steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var gold_window := _window(WindowBase, Rect2(0, 376, left, maxi(64, int(size.y - 376 - hint_height))))
	gold_window.label(Resources.word("gold", "金币"), Rect2(88, 0, 40, 32), Color("c0e0ff"), 16)
	_gold = gold_window.label("", Rect2(0, 0, 84, 32), Color.WHITE, 18)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_party = _window(WindowSelectable, Rect2(left, 0, size.x - left, size.y - hint_height))
	_party.row_height = 104.0
	_party.item_count = _views.size()
	_party.active = page == "actors"
	_party.select(actor_index)
	_draw_party()
	var hint_back := ColorRect.new()
	hint_back.position = Vector2(0, size.y - hint_height)
	hint_back.size = Vector2(size.x, hint_height)
	hint_back.color = Color("141b2bf2")
	_root_panel.add_child(hint_back)
	_hint = Label.new()
	_hint.position = Vector2(12, size.y - hint_height)
	_hint.size = Vector2(size.x - 24, hint_height)
	_hint.add_theme_font_override("font", Resources.font())
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("ffe9a8"))
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_root_panel.add_child(_hint)
	if RuntimeState.testing_enabled and page == "menu":
		_hint.size.x = size.x - 192
		var button := Button.new()
		button.text = "测试工具 · F6"
		button.position = Vector2(size.x - 176, size.y - 38)
		button.size = Vector2(160, 36)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", Resources.font())
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(open_test_tools)
		_root_panel.add_child(button)
	_update_hint()


func _draw_party() -> void:
	_party.clear_content()
	var sprites := UISpriteset.new()
	_party.content.add_child(sprites)
	if _views.is_empty():
		_party.label("队伍中没有可显示的角色。", Rect2(8, 12, _party.size.x - 40, 32))
		return
	var available := maxi(1, int((_party.size.y - 32) / _party.row_height))
	for index in range(_party.scroll_row, mini(_views.size(), _party.scroll_row + available)):
		var view := _views[index]
		var y: float = (index - _party.scroll_row) * _party.row_height
		sprites.add_character(view, Rect2(4, y + 20, 56, 72))
		var width: float = _party.size.x - 108
		_party.label("%s    %s" % [view.name, view.class_name], Rect2(72, y, width, 28))
		_party.label("Lv %d    %s" % [view.level, _states(view)], Rect2(72, y + 28, width, 26), Color("c0e0ff"), 18)
		_party.label("%s %s/%s    %s %s/%s" % [Resources.word("hp", "HP"), _number(view.hp), _number(view.parameters.maxhp), Resources.word("sp", "SP"), _number(view.sp), _number(view.parameters.maxsp)], Rect2(72, y + 58, width, 30), Color.WHITE, 18)


func _build_status() -> void:
	if _views.is_empty():
		return
	var view := _views[actor_index]
	var window := _window(WindowBase, Rect2(Vector2.ZERO, size))
	var width := size.x - 32
	var right := width * 0.53
	var sprites := UISpriteset.new()
	window.content.add_child(sprites)
	sprites.add_character(view, Rect2(8, 48, 64, 88))
	window.label(str(view.name), Rect2(4, 0, right - 12, 32))
	window.label(str(view.class_name), Rect2(right, 0, width - right, 32), Color("c0e0ff"))
	window.label("Lv %d    %s" % [view.level, _states(view)], Rect2(88, 40, right - 96, 32), Color("c0e0ff"), 18)
	window.label("%s  %s / %s" % [Resources.word("hp", "HP"), _number(view.hp), _number(view.parameters.maxhp)], Rect2(88, 80, right - 96, 28), Color.WHITE, 18)
	window.label("%s  %s / %s" % [Resources.word("sp", "SP"), _number(view.sp), _number(view.parameters.maxsp)], Rect2(88, 112, right - 96, 28), Color.WHITE, 18)
	window.label("EXP    %s" % _number(view.experience), Rect2(right, 48, width - right, 32))
	window.label("NEXT   %s" % ("-------" if view.next_experience == null else str(view.next_experience)), Rect2(right, 80, width - right, 32))
	var parameter_names := [["atk", "攻击力"], ["pdef", "物理防御"], ["mdef", "魔法防御"], ["str", "力量"], ["dex", "灵巧"], ["agi", "速度"], ["int", "魔力"]]
	for i in parameter_names.size():
		var key: String = parameter_names[i][0]
		window.label(Resources.word(key, parameter_names[i][1]), Rect2(8, 164 + i * 32, right - 96, 30), Color("c0e0ff"))
		var number: Label = window.label(_number(view.parameters[key]), Rect2(right - 88, 164 + i * 32, 64, 30))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	window.label("装备", Rect2(right, 132, width - right, 30), Color("c0e0ff"))
	var slot_names := [["weapon", "武器"], ["armor1", "盾"], ["armor2", "头部"], ["armor3", "身体"], ["armor4", "饰品"]]
	for i in view.equipment.size():
		var item: Dictionary = view.equipment[i]
		var y: int = 170 + i * 44
		window.label(Resources.word(slot_names[i][0], slot_names[i][1]), Rect2(right, y, 86, 28), Color("c0e0ff"), 17)
		var icon := TextureRect.new()
		icon.position = Vector2(right + 88, y + 2)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = Cache.icon(str(item.icon_name))
		window.content.add_child(icon)
		window.label(str(item.name), Rect2(right + 116, y, width - right - 116, 28), Color.WHITE, 18)
	var message := "Esc / X：返回角色选择"
	if not view.diagnostics.is_empty():
		message = str(view.diagnostics[0])
	var footer: Label = window.label(message, Rect2(0, size.y - 76, width, 40), Color("ffe9a8"), 15)
	footer.tooltip_text = "\n".join(view.diagnostics)


func _build_end() -> void:
	_end_commands = _window(WindowCommand, Rect2(size / 2 - Vector2(120, 64), Vector2(240, 128)))
	_end_commands.configure([{"text": "返回标题", "enabled": true}, {"text": "退出游戏", "enabled": true}, {"text": "取消", "enabled": true}], 2)


func navigate(direction: int) -> void:
	if _commerce != null:
		_commerce.navigate(direction)
		return
	if page == "menu":
		_commands.move_selection(direction)
		command_index = _commands.index
		_update_hint()
	elif page == "actors":
		_party.move_selection(direction)
		actor_index = _party.index
		_draw_party()
	elif page == "end":
		_end_commands.move_selection(direction)
	else:
		return
	sound_requested.emit("cursor_se")


func activate() -> void:
	if _commerce != null:
		_commerce.activate()
		return
	if page == "menu":
		if not _commands.current_enabled():
			_update_hint()
			sound_requested.emit("buzzer_se")
			return
		if command_index == 0:
			_push("inventory")
		elif command_index == 4:
			_push("save")
		else:
			_push("actors" if command_index in [1, 2, 3] else "end")
	elif page == "actors" and not _views.is_empty():
		_push({1: "skills", 2: "equipment", 3: "status"}[command_index])
	elif page == "end":
		match int(_end_commands.index):
			0: title_requested.emit()
			1: quit_requested.emit()
			2: back()
		return
	else:
		return
	sound_requested.emit("decision_se")


func back() -> void:
	sound_requested.emit("cancel_se")
	if scene_stack.size() == 1:
		close_requested.emit()
		return
	scene_stack.pop_back()
	page = scene_stack.back()
	_layout()


func handle_back() -> void:
	if _commerce != null:
		_commerce.back()
	else:
		back()


func _push(next_page: String) -> void:
	if next_page == "event_tools":
		event_test_requested.emit()
		return
	scene_stack.append(next_page)
	page = next_page
	_layout()


func open_test_shop() -> void:
	if RuntimeState.testing_enabled and page == "menu":
		_push("shop")


func open_state_tools() -> void:
	if RuntimeState.testing_enabled and page == "menu":
		_push("state_tools")


func open_test_tools() -> void:
	if RuntimeState.testing_enabled and page == "menu":
		_push("test_tools")


func open_actor_tools() -> void:
	if RuntimeState.testing_enabled and page == "menu":
		_push("actor_tools")


func open_screen_tools() -> void:
	if RuntimeState.testing_enabled and page == "menu":
		_push("screen_tools")


func open_movement_tools() -> void:
	if RuntimeState.testing_enabled and page == "menu":
		_push("movement_tools")


func _update_counters() -> void:
	if _clock != null:
		var seconds := int(RuntimeState.play_seconds)
		_clock.text = "%02d:%02d:%02d" % [int(seconds / 3600), int(seconds / 60) % 60, seconds % 60]
	if _gold != null:
		_gold.text = str(RuntimeState.gold)
	if _steps != null:
		_steps.text = str(RuntimeState.steps)


func _update_hint() -> void:
	if _hint == null:
		return
	if page == "actors":
		_hint.text = "选择角色 · 确认：%s · Esc / X：返回" % {1: "只读特技列表", 2: "装备界面", 3: "状态详情"}.get(command_index, "状态详情")
	elif not _commands.current_enabled():
		_hint.text = "队伍为空或角色数据缺失。" if command_index in [1, 2, 3] else "当前禁止存档。"
	elif not RuntimeState.diagnostics.is_empty():
		_hint.text = RuntimeState.diagnostics[0]
		_hint.tooltip_text = "\n".join(RuntimeState.diagnostics)
	else:
		_hint.text = "↑↓：选择 · Enter / Space / Z：确认 · Esc / X：返回"
	if RuntimeState.testing_enabled:
		_hint.text = "[测试模式] " + _hint.text


func _number(value: Variant) -> String:
	return "—" if value == null else str(value)


func _states(view: Dictionary) -> String:
	if view.hp != null and int(view.hp) == 0:
		return "无法行动"
	return "正常" if view.states.is_empty() else " / ".join(view.states)

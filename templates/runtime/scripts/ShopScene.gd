extends Control
signal back_requested
signal sound_requested(key: String)
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Service = preload("res://runtime/scripts/ShopService.gd")
const Inventory = preload("res://runtime/scripts/InventoryService.gd")
const Base = preload("res://runtime/scripts/WindowBase.gd")
const Selectable = preload("res://runtime/scripts/WindowSelectable.gd")
const Command = preload("res://runtime/scripts/WindowCommand.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
var goods: Array = [] # RMXP pairs: [0 item / 1 weapon / 2 armor, database ID].
var mode := "commands"
var command_index := 0
var selected := 0
var actor_index := 0
var quantity := 1
var message := ""
var _number_mode := ""
var _number_item: Dictionary = {}
var _panel: Control
var _commands: Control
var _list: Control
var _entries: Array[Dictionary] = []
var _quote: Dictionary = {}
var _catalog: Dictionary = {}
var _dirty := false
var content_rebuilds := 0
var _scroll_rows: Dictionary = {"buy": 0, "sell": 0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RuntimeState.state_changed.connect(func() -> void: _dirty = true)
	resized.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		# Game time signals every second; only rebuild for relevant state changes.
		var signature := JSON.stringify([RuntimeState.gold, RuntimeState.inventory, RuntimeState.party_snapshots()])
		if signature != _signature:
			refresh()


var _signature := ""


func window(script: Script, rect: Rect2) -> Control:
	var result: Control = script.new()
	result.position = rect.position
	result.size = rect.size
	_panel.add_child(result)
	return result


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	content_rebuilds += 1
	if is_instance_valid(_list):
		_scroll_rows[_number_mode if mode == "number" else mode] = _list.scroll_row
	_signature = JSON.stringify([RuntimeState.gold, RuntimeState.inventory, RuntimeState.party_snapshots()])
	_catalog = Service.catalog(goods)
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var header := window(Base, Rect2(0, 0, size.x, 96))
	header.label("标准商店 · %s" % {"commands": "购买 / 出售", "buy": "购买", "sell": "出售", "number": "选择数量"}[mode], Rect2(0, 0, size.x - 200, 28), Color("c0e0ff"))
	header.label("%d %s" % [RuntimeState.gold, Resources.word("gold", "金币")], Rect2(size.x - 216, 0, 184, 28), Color.WHITE, 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var help_label: Label = header.label("", Rect2(0, 30, size.x - 32, 34), Color("ffe9a8"), 15)
	_commands = null
	_list = null
	if mode == "commands":
		_commands = window(Command, Rect2(0, 96, 160, 128))
		_commands.configure([{"text": "购买", "enabled": _catalog.ok and not _catalog.get("entries", []).is_empty()}, {"text": "出售", "enabled": true}, {"text": "离开", "enabled": true}], command_index)
		var help_window := window(Base, Rect2(160, 96, size.x - 160, size.y - 176))
		help_window.label("购买、出售均须选择数量后确认。\n取消不修改金币和背包；只出售背包中的物品。\n角色身上的装备不会自动卸下或出售。", Rect2(0, 0, size.x - 192, 120), Color.WHITE, 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		build_list()
		if mode == "number":
			build_number()
	var help := message
	if not _catalog.ok:
		help = _catalog.message
	elif mode in ["buy", "sell", "number"] and not _entries.is_empty():
		help = str(_entries[selected].description) if help.is_empty() else help
	help_label.text = help if not help.is_empty() else "数据库价格；出售为原价的一半取整，购买不会自动装备。"
	help_label.tooltip_text = help_label.text
	help_label.mouse_filter = Control.MOUSE_FILTER_STOP
	var footer := window(Base, Rect2(0, size.y - 80, size.x, 80))
	footer.label("←→：±1 · ↑↓：±10 · 确认：交易 · Esc：取消" if mode == "number" else "↑↓：选择 · Enter/Space/Z：确认 · Esc/X：返回", Rect2(0, 0, size.x - 32, 28), Color("ffe9a8"), 16)
	footer.label("标准商品交易，不执行 Ruby 商店逻辑。", Rect2(0, 28, size.x - 32, 24), Color("c0e0ff"), 15)


func build_list() -> void:
	var selling := mode == "sell" or _number_mode == "sell" and mode == "number"
	_entries.clear()
	if selling:
		for entry in Inventory.entries(RuntimeState):
			var resolved := Service.item(entry.kind, entry.id)
			if resolved.ok:
				_entries.append(resolved.entry)
			else:
				entry["price"] = 0
				_entries.append(entry)
	elif _catalog.ok:
		_entries.assign(_catalog.entries)
	if mode == "number":
		# Track the chosen goods by identity, not a row that can move after a
		# script changes the inventory while the confirmation is on screen.
		var found := -1
		for index in _entries.size():
			if _entries[index].kind == _number_item.get("kind") and _entries[index].id == _number_item.get("id"):
				found = index
				break
		if found < 0:
			mode = _number_mode
			_number_item.clear()
			message = "待交易商品已不可用，请重新选择。"
		else:
			selected = found
	selected = clampi(selected, 0, maxi(0, _entries.size() - 1))
	var split := floorf(size.x * 0.56)
	_list = window(Selectable, Rect2(0, 96, split, size.y - 176))
	_list.item_count = _entries.size()
	_list.row_height = 40
	_list.active = mode != "number"
	_list.scroll_row = int(_scroll_rows.get("sell" if selling else "buy", 0))
	_list.select(selected)
	var rows := maxi(1, int((_list.size.y - 32) / 40))
	for index in range(_list.scroll_row, mini(_entries.size(), _list.scroll_row + rows)):
		var entry := _entries[index]
		var quote := Service.quote_sell(RuntimeState, entry.kind, entry.id) if selling else Service.quote_buy(RuntimeState, goods, entry.kind, entry.id)
		var y: float = (index - _list.scroll_row) * 40
		var icon := TextureRect.new()
		icon.position = Vector2(0, y + 6)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = Cache.icon(str(entry.icon_name))
		_list.content.add_child(icon)
		var color := Color.WHITE if quote.ok and quote.maximum > 0 else Color("9298a8")
		_list.label(entry.name, Rect2(30, y, split - 142, 36), color, 17)
		_list.label(str(quote.get("unit_price", "—")), Rect2(split - 108, y, 76, 36), color, 17).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var details := window(Base, Rect2(split, 96, size.x - split, size.y - 176))
	if _entries.is_empty():
		_list.label("没有商品。", Rect2(0, 0, split - 32, 32))
		_quote = {}
		return
	var item := _entries[selected]
	_quote = Service.quote_sell(RuntimeState, item.kind, item.id) if selling else Service.quote_buy(RuntimeState, goods, item.kind, item.id)
	details.label("持有：%d" % RuntimeState.inventory_count(item.kind, item.id), Rect2(0, 0, details.size.x - 32, 28), Color("c0e0ff"), 18)
	if item.kind == "item":
		details.label("普通物品\n购买不会自动使用。", Rect2(0, 38, details.size.x - 32, 72), Color.WHITE, 17)
		return
	var views := RuntimeState.party_snapshots()
	if views.is_empty():
		details.label("队伍为空，仍可买卖。", Rect2(0, 36, details.size.x - 32, 56), Color.WHITE, 16)
		return
	actor_index = clampi(actor_index, 0, views.size() - 1)
	var actor: RefCounted = RuntimeState.actor(int(views[actor_index].id))
	var definition := Data.record(Inventory.DATABASES[item.kind], int(item.id))
	var slot := 0 if item.kind == "weapon" else int(definition.get("kind", -1)) + 1
	var allowed: Array = Data.record("Classes", actor.class_id).get("weapon_set" if slot == 0 else "armor_set", [])
	var eligible := slot >= 0 and slot < 5 and (Data.is_test_record(Inventory.DATABASES[item.kind], int(item.id)) or allowed.any(func(value: Variant) -> bool: return int(value) == int(item.id)))
	details.label("%d/%d %s" % [actor_index + 1, views.size(), actor.actor_name], Rect2(0, 32, details.size.x - 104, 24), Color.WHITE, 16)
	for offset in 2:
		var button := Button.new()
		button.text = "‹" if offset == 0 else "›"
		button.position = Vector2(details.size.x - 88 + offset * 32, 48)
		button.size = Vector2(30, 24)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(change_actor.bind(-1 if offset == 0 else 1))
		details.add_child(button)
	details.label("可装备" if eligible else "此职业不可装备", Rect2(0, 58, details.size.x - 32, 24), Color("c0e0ff") if eligible else Color("ffb6a6"), 16)
	if not eligible:
		return
	var before: Dictionary = actor.snapshot()
	var proposed: Array = actor.equipment.duplicate()
	proposed[slot] = int(item.id)
	var after: Dictionary = actor.snapshot(proposed)
	for index in 7:
		var key: String = ["atk", "pdef", "mdef", "str", "dex", "agi", "int"][index]
		details.label(Resources.word(key, key), Rect2(0, 88 + index * 22, 104, 22), Color("c0e0ff"), 15)
		details.label("%s → %s" % [before.parameters[key] if before.parameters[key] != null else "—", after.parameters[key] if after.parameters[key] != null else "—"], Rect2(104, 88 + index * 22, details.size.x - 136, 22), Color.WHITE, 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if actor.slot_fixed(slot):
		message = "此角色装备槽固定；可购买，但不能在装备页更换。"


func build_number() -> void:
	if _entries.is_empty() or not _quote.get("ok", false) or _quote.maximum < 1:
		mode = _number_mode
		return
	quantity = clampi(quantity, 1, int(_quote.maximum))
	var box := window(Base, Rect2(size / 2 - Vector2(180, 88), Vector2(360, 176)))
	box.label(_entries[selected].name, Rect2(0, 0, 328, 28), Color("c0e0ff"), 18)
	box.label("数量 %d / %d · 总价 %d" % [quantity, _quote.maximum, quantity * int(_quote.unit_price)], Rect2(0, 36, 328, 28), Color.WHITE, 18)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(16, 104)
	box.add_child(buttons)
	for entry in [["−", -1], ["＋", 1], ["最大", 0], ["确认", 2], ["取消", 3]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", Resources.font())
		button.pressed.connect(number_action.bind(int(entry[1])))
		buttons.add_child(button)


func number_action(value: int) -> void:
	if value == 2:
		activate()
	elif value == 3:
		back()
	elif value == 0:
		quantity = int(_quote.maximum)
		refresh()
	else:
		navigate(value)


func change_actor(direction: int) -> void:
	actor_index = posmod(actor_index + direction, maxi(1, RuntimeState.party.size()))
	refresh()


func navigate(direction: int) -> void:
	if mode == "commands":
		_commands.move_selection(direction)
		command_index = _commands.index
	elif mode == "number":
		quantity = clampi(quantity + direction, 1, int(_quote.get("maximum", 1)))
	else:
		selected = posmod(selected + direction, maxi(1, _entries.size()))
	message = ""
	refresh()
	sound_requested.emit("cursor_se")


func activate() -> void:
	if mode == "commands":
		if not _commands.current_enabled():
			sound_requested.emit("buzzer_se")
			return
		if command_index == 2:
			back_requested.emit()
			return
		mode = "buy" if command_index == 0 else "sell"
		selected = 0
		_scroll_rows[mode] = 0
	elif mode == "number":
		var entry := _number_item
		if entry.is_empty():
			mode = _number_mode
			refresh()
			return
		var result := RuntimeState.shop_buy(goods, entry.kind, entry.id, quantity) if _number_mode == "buy" else RuntimeState.shop_sell(entry.kind, entry.id, quantity)
		message = result.message
		mode = _number_mode
		_number_item.clear()
		sound_requested.emit("decision_se" if result.ok else "buzzer_se")
		refresh()
		return
	elif not _entries.is_empty() and _quote.get("ok", false) and _quote.maximum > 0:
		_number_mode = mode
		_number_item = _entries[selected].duplicate()
		mode = "number"
		quantity = 1
	else:
		message = str(_quote.get("message", "没有可交易的商品。"))
		sound_requested.emit("buzzer_se")
		refresh()
		return
	message = ""
	refresh()
	sound_requested.emit("decision_se")


func back() -> void:
	if mode == "commands":
		back_requested.emit()
		return
	mode = _number_mode if mode == "number" else "commands"
	_number_item.clear()
	message = ""
	refresh()
	sound_requested.emit("cancel_se")


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
		activate()
	elif mode == "number" and key in [KEY_UP, KEY_DOWN]:
		navigate(10 if key == KEY_UP else -10)
	elif key in [KEY_UP, KEY_LEFT]:
		navigate(-1)
	elif key in [KEY_DOWN, KEY_RIGHT]:
		navigate(1)

extends Control
## Retained item/equipment view. Transactions live in RuntimeState/InventoryService.
signal back_requested
signal sound_requested(key: String)
const WindowBase = preload("res://runtime/scripts/WindowBase.gd")
const WindowSelectable = preload("res://runtime/scripts/WindowSelectable.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const Service = preload("res://runtime/scripts/InventoryService.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")

var mode := "inventory"
var actor_id := 0
var page := "list"
var list_index := 0
var target_index := 0
var slot_index := 0
var candidate_index := 0
var active_item_id := 0
var message := ""
var _panel: Control
var _selection: Control
var _entries: Array[Dictionary] = []
var _targets: Array[Dictionary] = []
var _candidates: Array[Dictionary] = []
var _preview: Dictionary = {}
var _scroll_rows: Dictionary = {}
var _selection_page := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page = "slots" if mode == "equipment" else "list"
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_selection):
		_scroll_rows[_selection_page] = _selection.scroll_row
	_entries = RuntimeState.inventory_entries()
	_targets = RuntimeState.party_snapshots()
	list_index = clampi(list_index, 0, maxi(0, _entries.size() - 1))
	target_index = clampi(target_index, 0, maxi(0, _targets.size() - 1))
	if _panel != null:
		remove_child(_panel)
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_selection = null
	if page in ["slots", "candidates"]:
		_build_equipment()
	else:
		_build_inventory()
	var footer := _window(WindowBase, Rect2(0, size.y - 64, size.x, 64))
	var text := message if not message.is_empty() else "↑↓：选择 · 确认：使用/更换 · Esc/X：返回（取消不修改数据）"
	footer.label(text, Rect2(0, 0, size.x - 32, 32), Color("ffe9a8"), 16).tooltip_text = text


func _window(script: Script, rect: Rect2) -> Control:
	var window: Control = script.new()
	window.position = rect.position
	window.size = rect.size
	_panel.add_child(window)
	return window


func _header(title: String, description: String) -> void:
	var window := _window(WindowBase, Rect2(0, 0, size.x, 96))
	window.label(("[测试模式] " if RuntimeState.testing_enabled else "") + title, Rect2(0, 0, size.x - 32, 28), Color("c0e0ff"))
	window.label(description, Rect2(0, 28, size.x - 32, 36), Color.WHITE, 16).tooltip_text = description


func _build_inventory() -> void:
	var definition: Dictionary = {}
	var title := "背包"
	var description := "背包为空。"
	if page == "target":
		definition = Data.record("Items", active_item_id)
		title = "使用 " + str(definition.get("name", "缺失物品"))
		var quantity := int(RuntimeState.inventory.get("item:%d" % active_item_id, 0))
		description = "剩余 %d · %s" % [quantity, "确认后恢复全体存活队员，只消耗一件。" if int(definition.get("scope", 0)) == 4 else "请选择要恢复的角色。"]
	elif not _entries.is_empty():
		var selected := _entries[list_index]
		description = selected.description
		if description.is_empty():
			description = "此物品没有说明。"
	_header(title, description)
	_selection = _window(WindowSelectable, Rect2(0, 96, size.x, size.y - 160))
	_selection.row_height = 40.0 if page == "list" else 64.0
	_selection.item_count = _entries.size() if page == "list" else _targets.size()
	_selection_page = page
	_selection.scroll_row = int(_scroll_rows.get(page, 0))
	_selection.select(list_index if page == "list" else target_index)
	if _selection.item_count == 0:
		_selection.label("没有可选择的物品或角色。", Rect2(4, 0, size.x - 48, 36))
		return
	var visible_rows := maxi(1, int((_selection.size.y - 32) / _selection.row_height))
	for index in range(_selection.scroll_row, mini(_selection.item_count, _selection.scroll_row + visible_rows)):
		var y: float = (index - _selection.scroll_row) * _selection.row_height
		if page == "list":
			var entry := _entries[index]
			var usable: bool = entry.kind == "item" and Service.item_reason(entry.id).is_empty()
			_icon(_selection, entry.icon_name, Vector2(4, y + 8))
			_selection.label("%s  %s" % [{"item": "物品", "weapon": "武器", "armor": "防具"}[entry.kind], entry.name], Rect2(40, y, size.x - 160, 40), Color.WHITE if usable else Color("b4bed1"))
			var quantity: Label = _selection.label("× %d" % entry.count, Rect2(size.x - 120, y, 80, 40))
			quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			var view := _targets[index]
			_selection.label("%s  Lv %d" % [view.name, view.level], Rect2(4, y, size.x - 48, 28), Color("c0e0ff"))
			_selection.label("HP %s/%s    SP %s/%s" % [_number(view.hp), _number(view.parameters.maxhp), _number(view.sp), _number(view.parameters.maxsp)], Rect2(4, y + 28, size.x - 48, 30), Color.WHITE, 18)


func _build_equipment() -> void:
	var actor: RefCounted = RuntimeState.actor(actor_id)
	if actor == null:
		_header("装备", "角色数据缺失，无法更换。")
		return
	var view: Dictionary = actor.snapshot()
	var slot_names := [Resources.word("weapon", "武器"), Resources.word("armor1", "盾"), Resources.word("armor2", "头部"), Resources.word("armor3", "身体"), Resources.word("armor4", "饰品")]
	_candidates = [{"id": 0, "name": "卸下装备", "description": "将当前装备放回背包。", "icon_name": "", "count": 0}]
	var kind := "weapon" if slot_index == 0 else "armor"
	for entry in _entries:
		if entry.kind != kind:
			continue
		var definition := Data.record(Service.DATABASES[kind], entry.id)
		if not definition.is_empty() and (slot_index == 0 or int(definition.get("kind", -1)) == slot_index - 1):
			_candidates.append(entry)
	candidate_index = clampi(candidate_index, 0, _candidates.size() - 1)
	var description := "选择装备槽；固定的槽位不可更换。"
	_preview = {}
	if page == "candidates":
		var selected := _candidates[candidate_index]
		_preview = RuntimeState.equip_preview(actor_id, slot_index, selected.id)
		description = str(selected.description) if _preview.ok else str(_preview.message)
	_header("%s · %s" % [view.name, "装备" if page == "slots" else slot_names[slot_index]], description)
	var left_width := maxf(272, size.x * 0.48)
	_selection = _window(WindowSelectable, Rect2(0, 96, left_width, size.y - 160))
	_selection.row_height = 48.0
	_selection.item_count = 5 if page == "slots" else _candidates.size()
	_selection_page = page + str(slot_index) if page == "candidates" else page
	_selection.scroll_row = int(_scroll_rows.get(_selection_page, 0))
	_selection.select(slot_index if page == "slots" else candidate_index)
	var rows := maxi(1, int((_selection.size.y - 32) / 48))
	for index in range(_selection.scroll_row, mini(_selection.item_count, _selection.scroll_row + rows)):
		var y: float = (index - _selection.scroll_row) * 48
		if page == "slots":
			_selection.label(slot_names[index] + (" [固定]" if actor.slot_fixed(index) else ""), Rect2(2, y, left_width - 40, 22), Color("c0e0ff"), 16)
			_icon(_selection, view.equipment[index].icon_name, Vector2(4, y + 24))
			_selection.label(str(view.equipment[index].name), Rect2(36, y + 22, left_width - 76, 26), Color.WHITE, 18)
		else:
			var entry := _candidates[index]
			var allowed := Service.equip_reason(RuntimeState, actor_id, slot_index, entry.id).is_empty()
			_icon(_selection, entry.icon_name, Vector2(2, y + 12))
			_selection.label(str(entry.name), Rect2(34, y, left_width - 116, 48), Color.WHITE if allowed else Color("939bad"), 18)
			_selection.label("×%d" % entry.count if entry.id != 0 else "", Rect2(left_width - 76, y, 44, 48), Color.WHITE, 17)
	var preview_window := _window(WindowBase, Rect2(left_width, 96, size.x - left_width, size.y - 160))
	preview_window.label("当前 → 更换后", Rect2(0, 0, preview_window.size.x - 32, 28), Color("c0e0ff"), 18)
	var names := [["atk", "攻击力"], ["pdef", "物理防御"], ["mdef", "魔法防御"], ["str", "力量"], ["dex", "灵巧"], ["agi", "速度"], ["int", "魔力"]]
	for index in names.size():
		var key: String = names[index][0]
		var before: Variant = view.parameters[key]
		var after: Variant = _preview.after[key] if _preview.get("ok", false) else before
		var color := Color.WHITE
		if before != null and after != null:
			color = Color("8be3a1") if after > before else (Color("ff9696") if after < before else Color.WHITE)
		preview_window.label(Resources.word(key, names[index][1]), Rect2(0, 36 + index * 34, 110, 32), Color("c0e0ff"), 17)
		var label: Label = preview_window.label("%s → %s" % [_number(before), _number(after)], Rect2(104, 36 + index * 34, preview_window.size.x - 140, 32), color, 17)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _icon(window: Control, icon_name: String, position: Vector2) -> void:
	if icon_name.is_empty():
		return
	var icon := TextureRect.new()
	icon.position = position
	icon.size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = Cache.icon(icon_name)
	window.content.add_child(icon)


func navigate(direction: int) -> void:
	if _selection == null or _selection.item_count == 0:
		return
	_selection.move_selection(direction)
	match page:
		"list": list_index = _selection.index
		"target": target_index = _selection.index
		"slots": slot_index = _selection.index
		"candidates": candidate_index = _selection.index
	message = ""
	refresh()
	sound_requested.emit("cursor_se")


func activate() -> void:
	if _selection == null or _selection.item_count == 0:
		return
	message = ""
	match page:
		"list":
			var entry := _entries[list_index]
			message = "请在装备菜单中使用武器或防具。" if entry.kind != "item" else Service.item_reason(entry.id)
			if message.is_empty():
				active_item_id = entry.id
				page = "target"
		"target":
			var result := RuntimeState.use_item(active_item_id, int(_targets[target_index].id))
			message = result.message
			sound_requested.emit("decision_se" if result.ok else "buzzer_se")
			refresh()
			return
		"slots":
			var actor: RefCounted = RuntimeState.actor(actor_id)
			if actor.slot_fixed(slot_index):
				message = "此槽位已固定，不能更换或卸下。"
			else:
				page = "candidates"
				candidate_index = 0
		"candidates":
			var result := RuntimeState.equip(actor_id, slot_index, int(_candidates[candidate_index].id))
			message = result.message
			if result.ok:
				page = "slots"
			sound_requested.emit("equip_se" if result.ok else "buzzer_se")
			refresh()
			return
	sound_requested.emit("decision_se" if message.is_empty() else "buzzer_se")
	refresh()


func back() -> void:
	message = ""
	if page == "target":
		page = "list"
	elif page == "candidates":
		page = "slots"
	else:
		back_requested.emit()
		return
	sound_requested.emit("cancel_se")
	refresh()


func _number(value: Variant) -> String:
	return "—" if value == null else str(value)

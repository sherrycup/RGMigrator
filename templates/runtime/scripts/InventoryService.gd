extends RefCounted
## All item/equipment transactions are validated before any inventory/state write.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const DATABASES := {"item": "Items", "weapon": "Weapons", "armor": "Armors"}


static func entries(state: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in state.inventory:
		var parts := str(key).split(":")
		if parts.size() != 2 or not DATABASES.has(parts[0]) or not parts[1].is_valid_int():
			continue
		var count := int(state.inventory[key])
		if count <= 0:
			continue
		var id := int(parts[1])
		var definition := Data.record(DATABASES[parts[0]], id)
		result.append({"kind": parts[0], "id": id, "count": count, "name": str(definition.get("name", "缺失数据 #%d" % id)),
			"description": str(definition.get("description", "")), "icon_name": str(definition.get("icon_name", "")), "missing": definition.is_empty()})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var kinds := ["item", "weapon", "armor"]
		return kinds.find(a.kind) < kinds.find(b.kind) if a.kind != b.kind else a.id < b.id)
	return result


static func item_reason(item_id: int) -> String:
	var item := Data.record("Items", item_id)
	if item.is_empty():
		return "Items[%d] 不存在。" % item_id
	var common_id := int(item.get("common_event_id", 0))
	if common_id != 0 and Data.record("CommonEvents", common_id).is_empty(): return "物品引用的公共事件不存在。"
	if int(item.get("occasion", 3)) not in [0, 2]:
		return "此物品不可在菜单中使用。"
	# Enemy/none scopes return directly to the map in native Scene_Item; their
	# combat effects have no menu target, while the common event still runs.
	if common_id > 0 and int(item.get("scope", 0)) in [0, 1, 2]: return ""
	if int(item.get("scope", 0)) not in [3, 4]:
		return "本版仅支持对存活队友的单体/全体 HP、SP 恢复。"
	if int(item.get("parameter_type", 0)) != 0 or not item.get("plus_state_set", []).is_empty() or not item.get("minus_state_set", []).is_empty():
		return "此物品包含尚未支持的属性或状态效果，不会部分执行或消耗。"
	if int(item.get("variance", 0)) != 0 or int(item.get("hit", 100)) != 100 or int(item.get("pdef_f", 0)) != 0 or int(item.get("mdef_f", 0)) != 0 or not item.get("element_set", []).is_empty():
		return "此物品包含尚未支持的随机、命中、防御或属性修正。"
	var has_recovery := false
	for field in ["recover_hp", "recover_hp_rate", "recover_sp", "recover_sp_rate"]:
		if int(item.get(field, 0)) < 0:
			return "本版不支持造成伤害的物品。"
		has_recovery = has_recovery or int(item.get(field, 0)) > 0
	return "" if has_recovery or common_id > 0 else "此物品没有可执行的标准恢复效果；自定义 Ruby 效果未迁移。"


static func use_item(state: Node, item_id: int, target_id: int) -> Dictionary:
	var reason := item_reason(item_id)
	if not reason.is_empty():
		return failure(reason)
	var key := "item:%d" % item_id
	if int(state.inventory.get(key, 0)) <= 0:
		return failure("物品数量不足。")
	var item := Data.record("Items", item_id)
	var common_id := int(item.get("common_event_id", 0))
	if common_id > 0:
		var common_reason: String = state.common_event_reason(common_id)
		if not common_reason.is_empty(): return failure(common_reason)
	var targets: Array = state.party.duplicate() if int(item.scope) == 4 else [target_id]
	if int(item.scope) in [0, 1, 2]: targets = []
	var changes: Array[Dictionary] = []
	var visited := {}
	var living_targets := 0
	for raw_id in targets:
		var id := int(raw_id)
		if visited.has(id):
			continue
		visited[id] = true
		if not state.party.has(id):
			return failure("目标角色不在队伍中。")
		var actor: RefCounted = state.actor(id)
		if actor == null:
			return failure("目标角色数据缺失。")
		var view: Dictionary = actor.snapshot()
		if view.hp == null or view.sp == null or view.parameters.maxhp == null or view.parameters.maxsp == null:
			return failure("目标角色属性无法计算，未消耗物品。")
		if int(view.hp) <= 0:
			continue
		living_targets += 1
		var hp_gain := int(int(view.parameters.maxhp) * int(item.get("recover_hp_rate", 0)) / 100.0) + int(item.get("recover_hp", 0))
		var sp_gain := int(int(view.parameters.maxsp) * int(item.get("recover_sp_rate", 0)) / 100.0) + int(item.get("recover_sp", 0))
		var new_hp := mini(int(view.parameters.maxhp), int(view.hp) + hp_gain)
		var new_sp := mini(int(view.parameters.maxsp), int(view.sp) + sp_gain)
		if new_hp != int(view.hp) or new_sp != int(view.sp):
			changes.append({"actor": actor, "hp": new_hp, "sp": new_sp})
	if changes.is_empty() and common_id == 0:
		return failure("没有需要恢复的有效目标，未消耗物品。")
	if common_id > 0 and int(item.scope) in [3, 4] and living_targets == 0: return failure("没有存活的有效目标，未消耗物品。")
	if common_id > 0:
		var reserved: Dictionary = state.reserve_common_event(common_id, "item:%d" % item_id, 0, target_id)
		if not reserved.ok: return reserved
	if bool(item.get("consumable", true)):
		state.inventory[key] = int(state.inventory[key]) - 1
	for change in changes:
		change.actor.hp = change.hp
		change.actor.sp = change.sp
	state.state_changed.emit()
	return {"ok": true, "message": "使用了 %s。" % item.name, "targets": changes.size(), "common_event": common_id}


static func equip_reason(state: Node, actor_id: int, slot: int, equipment_id: int) -> String:
	if slot < 0 or slot > 4 or not state.party.has(actor_id):
		return "角色或装备槽无效。"
	var actor: RefCounted = state.actor(actor_id)
	if actor == null:
		return "角色数据缺失。"
	if actor.slot_fixed(slot):
		return "此装备槽已固定，不能更换或卸下。"
	var old_id := int(actor.equipment[slot])
	if old_id == equipment_id:
		return "已经装备此物品。"
	var kind := "weapon" if slot == 0 else "armor"
	var database: String = DATABASES[kind]
	if old_id > 0:
		if Data.record(database, old_id).is_empty():
			return "当前装备引用缺失，无法安全交换。"
		if int(state.inventory.get("%s:%d" % [kind, old_id], 0)) >= 99:
			return "背包中原装备已达 99 件，无法收回；未进行更换。"
	if equipment_id == 0:
		return ""
	if int(state.inventory.get("%s:%d" % [kind, equipment_id], 0)) <= 0:
		return "背包中没有该装备。"
	var equipment := Data.record(database, equipment_id)
	if equipment.is_empty():
		return "%s[%d] 数据缺失。" % [database, equipment_id]
	if slot != 0 and int(equipment.get("kind", -1)) != slot - 1:
		return "装备类型与槽位不符。"
	var profession := Data.record("Classes", actor.class_id)
	if profession.is_empty():
		return "角色职业数据缺失。"
	# Generated test gear is available to any valid class, but never bypasses fixed slots.
	if not Data.is_test_record(database, equipment_id):
		var allowed: Array = profession.get("weapon_set" if slot == 0 else "armor_set", [])
		if not allowed.any(func(value: Variant) -> bool: return int(value) == equipment_id):
			return "当前职业不能装备此物品。"
	var state_id := int(equipment.get("auto_state_id", 0))
	if state_id > 0 and Data.record("States", state_id).is_empty():
		return "装备自动状态 States[%d] 缺失。" % state_id
	return ""


static func equip_preview(state: Node, actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	var reason := equip_reason(state, actor_id, slot, equipment_id)
	if not reason.is_empty():
		return failure(reason)
	var actor: RefCounted = state.actor(actor_id)
	var proposed: Array = actor.equipment.duplicate()
	proposed[slot] = equipment_id
	var before: Dictionary = actor.snapshot()
	var after: Dictionary = actor.snapshot(proposed)
	for value in after.parameters.values():
		if value == null:
			return failure("更换后属性无法计算；未进行更换。")
	return {"ok": true, "before": before.parameters, "after": after.parameters, "equipment": proposed}


static func equip(state: Node, actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	var preview := equip_preview(state, actor_id, slot, equipment_id)
	if not preview.ok:
		return preview
	var actor: RefCounted = state.actor(actor_id)
	var kind := "weapon" if slot == 0 else "armor"
	var old_id := int(actor.equipment[slot])
	if equipment_id > 0:
		var key := "%s:%d" % [kind, equipment_id]
		state.inventory[key] = int(state.inventory[key]) - 1
	if old_id > 0:
		var key := "%s:%d" % [kind, old_id]
		state.inventory[key] = int(state.inventory.get(key, 0)) + 1
	actor.equipment.assign(preview.equipment)
	actor.hp = mini(int(actor.hp), int(preview.after.maxhp)) if actor.hp != null else null
	actor.sp = mini(int(actor.sp), int(preview.after.maxsp)) if actor.sp != null else null
	actor.changed.emit()
	state.state_changed.emit()
	return {"ok": true, "message": "装备已更新。"}


static func failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

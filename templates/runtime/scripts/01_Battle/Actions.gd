## 职责：提供闪翼物品、技能、装备及回路等脚本业务入口，直接操作正式运行状态。
##
## 调用方式：
##   静态业务入口接收同一正式 RuntimeState；例如 equip(state, actor_id, slot, equipment_id)。
##
## 调用接口：
##   static func exchange_crystal(state: Object, id: int, index: int, crystal_id: int) -> Dictionary
##     用途：交换指定回路槽与背包中的晶石。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 id（int；必填）：需要修改回路的角色编号。
##     参数 index（int；必填）：原回路配置中的槽位索引。
##     参数 crystal_id（int；必填）：要装入的晶石物品编号，卸下规则由回路服务校验。
##     返回：操作结果字典。
##
##   static func equip(state: Object, actor_id: int, slot: int, equipment_id: int) -> Dictionary
##     用途：执行角色装备变更。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     参数 equipment_id（int；必填）：装备的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func equip_skill(state: Object, actor_id: int, skill_id: int, turn: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 turn（int；必填）：当前战斗回合或行动轮次。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func cancel_skill(state: Object, actor_id: int, skill_id: int, turn: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 turn（int；必填）：当前战斗回合或行动轮次。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func set_roles(state: Object, main_id: int, support_id: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 main_id（int；必填）：主角色的原编号。
##     参数 support_id（int；必填）：辅助角色的原编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func use_item(state: Object, item_id: int) -> Dictionary
##     用途：检查并执行物品使用效果。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 item_id（int；必填）：物品的原数据库编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func after_step(state: Object) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func recover_item(state: Object, item_id: int, actor_id: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 item_id（int；必填）：物品的原数据库编号。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func request_tool(state: Object, item_id: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 item_id（int；必填）：物品的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func save_skill_set(state: Object, actor_id: int, index: int, side: String) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 side（String；必填）：当前对象或行动所属的一方。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func load_skill_set(state: Object, actor_id: int, index: int, side: String) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 side（String；必填）：当前对象或行动所属的一方。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func switch_roles(state: Object) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func choose_floor(state: Object, floor_number: Variant) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 floor_number（Variant；必填）：楼层编号或楼层序号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func cancel_floor(state: Object) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func choose_character(state: Object, actor_id: Variant) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（Variant；必填）：角色的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func cancel_character(state: Object) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 注意：各业务使用已有角色、背包和地图服务；原数值公式及失败策略保持。
## 接口说明结束。

extends RefCounted
## Editable GDScript business entry points for source Scene_Map/Equip/Skill.
## ScriptRuntime owns the same transaction used by migrated event programs.
const Scripts = preload("../10_Support/Scripting/ScriptRuntime.gd")


static func exchange_crystal(state: Object, id: int, index: int, crystal_id: int) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("business"), "exchange_crystal", [id, index, crystal_id], state
	)


static func equip(state: Object, actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("actor", actor_id), "equip", [slot, equipment_id], state
	)


static func equip_skill(state: Object, actor_id: int, skill_id: int, turn: int) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("actor", actor_id), "equip_skill", [skill_id, turn], state
	)


static func cancel_skill(state: Object, actor_id: int, skill_id: int, turn: int) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("actor", actor_id), "cancel_skill", [skill_id, turn], state
	)


static func set_roles(state: Object, main_id: int, support_id: int) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("gameplay_module", 0, "BattleSystem::PartyRoles"),
		"set_roles",
		[main_id, support_id],
		state
	)


static func use_item(state: Object, item_id: int) -> Dictionary:
	if state.inventory_count("item", item_id) <= 0:
		return {"ok": false, "message": "背包没有该物品。"}
	return Scripts.call_method(
		state.custom_data.data_ref("gameplay_module", 0, "Storage"), "use_item", [item_id], state
	)


static func after_step(state: Object) -> Dictionary:
	# The source handlers do nothing without poison or their enabling items.
	# Real effects use the shared direct-script entry and stop on the first error.
	var game: Node = state.game()
	var custom: RefCounted = state.custom_data
	var index = int(custom.values.system.get("main_actor_index", 0))
	if (
		game != null
		and game.has_method("event_map")
		and game.event_map() != null
		and index >= 0
		and index < state.party.size()
	):
		var actor: RefCounted = state.actor(int(state.party[index]))
		var constants: Dictionary = custom.gameplay().rules.constants
		if actor != null and not actor.get_state_ids().has(int(constants.POISON_STATE_ID)):
			var inert = true
			for name in ["HIDE_ITEM_ID", "MANOR_ITEM_ID", "COTACK_ITEM_ID", "HOOK_ITEM_ID"]:
				if state.inventory_count("item", int(constants[name])) > 0:
					inert = false
					break
			if inert:
				return {"ok": true, "value": null, "writes": 0}
	return Scripts.call_method(
		state.custom_data.data_ref("player", state.map_id), "after_step", [], state
	)


static func recover_item(state: Object, item_id: int, actor_id: int) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0200.item_use/0202.update_state"},
		func(env):
			if not env._custom.party_call("in_map_use?", [item_id]):
				return env.fail("该物品不能按源地图恢复入口使用。")
			if not env._custom.party_ids.has(actor_id):
				return env.fail("恢复目标不在队伍中。")
			env._custom.temp_fields.item_id = item_id
			env._custom.temp_fields.actor_id = actor_id
			return env.invoke(env.type_ref("Item"), "Recover", [], "Item")
	)


static func request_tool(state: Object, item_id: int) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0202.update_item"},
		func(env):
			if not env._custom.party_call("item_can_use?", [item_id]):
				return env.fail("该物品当前不可使用。")
			if env._custom.party_call("in_map_use?", [item_id]):
				return env.fail("该物品需要按源恢复入口选择角色。")
			var reason: String = state.common_event_reason(9)
			if not reason.is_empty():
				return env.fail(reason)
			env._custom.temp_fields.item_id = item_id
			env._custom.pending_effects["common_event"] = {
				"id": 9, "source": "flash_tool:%d" % item_id, "actor_id": 0, "target_id": 0
			}
			return true
	)


static func save_skill_set(state: Object, actor_id: int, index: int, side: String) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("actor", actor_id), "save_skill", [index, side], state
	)


static func load_skill_set(state: Object, actor_id: int, index: int, side: String) -> Dictionary:
	return Scripts.call_method(
		state.custom_data.data_ref("actor", actor_id), "load_skill", [index, side], state
	)


static func switch_roles(state: Object) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0200.switch_battle_roles"},
		func(env):
			var ref = env._custom.data_ref("gameplay_module", 0, "BattleSystem::PartyRoles")
			if env.invoke(ref, "switch_locked?", []):
				return false
			if not env.invoke(ref, "swap_roles!", []):
				return false
			var ids = env._custom.gameplay().role_actor_ids()
			for i in 2:
				if ids[i] > 0:
					env.invoke(
						env._custom.data_ref("actor", ids[i]),
						"load_skill",
						[0, "atk" if i == 0 else "sup"]
					)
			env.invoke(env._custom.data_ref("player", state.map_id), "refresh", [])
			env.invoke(env._custom.data_ref("map", state.map_id), "refresh_damage", [])
			return true
	)


static func choose_floor(state: Object, floor_number: Variant) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0254.update_item/0117.item"},
		func(env):
			if not env._custom._integer(floor_number):
				return env.fail("楼层选择必须为整数。")
			var region: Variant = env._variables.get("3", 0)
			var regions: Variant = env._variables.get("18", 0)
			var choices: Variant = env.index_get(regions, region)
			if not env.failure.is_empty():
				return null
			if not choices is Array or not choices.has(floor_number):
				return env.fail("该楼层不在原窗口当前区域的已发现列表中。")
			return env.index_set({"__state_table": "variable"}, 13, int(floor_number))
	)


static func cancel_floor(state: Object) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0254.update_item"},
		func(env): return env.index_set({"__state_table": "variable"}, 13, "stop")
	)


static func choose_character(state: Object, actor_id: Variant) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0255.update_item/0118.item"},
		func(env):
			if not env._custom._integer(actor_id) or not env._custom.party_ids.has(int(actor_id)):
				return env.fail("角色不在原选择窗口的队伍列表中。")
			return env.index_set({"__state_table": "variable"}, 12, int(actor_id) - 1)
	)


static func cancel_character(state: Object) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0255.update_item"},
		func(env):
			var main_id: Variant = env.invoke(
				env._custom.data_ref("gameplay_module", 0, "BattleSystem::PartyRoles"),
				"main_id",
				[]
			)
			if not env.failure.is_empty():
				return null
			return env.index_set({"__state_table": "variable"}, 12, main_id)
	)

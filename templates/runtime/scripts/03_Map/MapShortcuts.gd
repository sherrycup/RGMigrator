## 职责：处理闪翼地图快捷键和页面呼叫，遵守当前场景及输入锁状态。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/MapShortcuts.gd").方法名(...)。
##
## 调用接口：
##   static func use_slot(state: Object, slot: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func load_group(state: Object, slot: int, side: String) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     参数 side（String；必填）：当前对象或行动所属的一方。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func switch_roles(state: Object, key: int) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 key（int；必填）：查询或写入使用的键名。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted
## Source 0200 W/E load, Tab/CapsLock roles and recover-only 1–9 item shortcuts.
const Presets = preload("../08_Menu/Item/ItemPresets.gd")
const Actions = preload("../01_Battle/Actions.gd")
const Scripts = preload("../10_Support/Scripting/ScriptRuntime.gd")
const Data = preload("../00_Game/RuntimeData.gd")


static func use_slot(state: Object, slot: int) -> Dictionary:
	if slot < 1 or slot > 9:
		return {"ok": false, "message": "物品槽位无效。"}
	var id = int(Presets.slots(state)[slot - 1][0])
	if id <= 0 or state.party.is_empty() or int(Data.record("Items", id).get("occasion", 3)) != 0:
		return {"ok": true, "changed": false}
	return Actions.recover_item(state, id, int(state.party[0]))


static func load_group(state: Object, slot: int, side: String) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0200.update.W/E"},
		func(env):
			if slot < 0 or slot > 7 or side not in ["atk", "sup"]:
				return env.fail("技能组或角色类型无效。")
			var ids = env._custom.gameplay().role_actor_ids()
			var actor_id = int(ids[0 if side == "atk" else 1])
			if actor_id <= 0:
				return env.fail("队伍中不存在援护角色。")
			env.invoke(env._custom.data_ref("actor", actor_id), "load_skill", [slot, side])
			if state.game() != null:
				env.invoke(env._custom.data_ref("map", state.map_id), "refresh_damage", [])
			return true
	)


static func switch_roles(state: Object, key: int) -> Dictionary:
	if (
		key == KEY_TAB
		and not state.switches.get(
			str(state.custom_data.gameplay().rules.constants.get("PARTNER_ABLE", 160)), false
		)
	):
		return {"ok": true, "changed": false}
	if key == KEY_CAPSLOCK and state.party.size() < 2:
		return {"ok": true, "changed": false}
	return Actions.switch_roles(state)

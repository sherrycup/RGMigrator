extends RefCounted
## Source 0200 W/E load, Tab/CapsLock roles and recover-only 1–9 item shortcuts.
const Presets=preload("FlashItemPresets.gd")
const Actions=preload("FlashActions.gd")
const Scripts=preload("ScriptRuntime.gd")
const Data=preload("RuntimeData.gd")

static func use_slot(state: Object,slot: int) -> Dictionary:
	if slot<1 or slot>9: return {"ok":false,"message":"物品槽位无效。"}
	var id=int(Presets.slots(state)[slot-1][0])
	if id<=0 or state.party.is_empty() or int(Data.record("Items",id).get("occasion",3))!=0: return {"ok":true,"changed":false}
	return Actions.recover_item(state,id,int(state.party[0]))

static func load_group(state: Object,slot: int,side: String) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0200.update.W/E"},func(env):
		if slot<0 or slot>7 or side not in ["atk","sup"]: return env.fail("技能组或角色类型无效。")
		var ids=env._custom.gameplay().role_actor_ids(); var actor_id=int(ids[0 if side=="atk" else 1])
		if actor_id<=0: return env.fail("队伍中不存在援护角色。")
		env.invoke(env._custom.data_ref("actor",actor_id),"load_skill",[slot,side])
		if state.game()!=null: env.invoke(env._custom.data_ref("map",state.map_id),"refresh_damage",[])
		return true)

static func switch_roles(state: Object,key: int) -> Dictionary:
	if key==KEY_TAB and not state.switches.get(str(state.custom_data.gameplay().rules.constants.get("PARTNER_ABLE",160)),false): return {"ok":true,"changed":false}
	if key==KEY_CAPSLOCK and state.party.size()<2: return {"ok":true,"changed":false}
	return Actions.switch_roles(state)

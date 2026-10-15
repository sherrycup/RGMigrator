extends RefCounted
## Editable GDScript business entry points for source Scene_Map/Equip/Skill.
## ScriptRuntime owns the same transaction used by migrated event programs.
const Scripts=preload("ScriptRuntime.gd")

static func exchange_crystal(state: Object,id: int,index: int,crystal_id: int) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("business"),"exchange_crystal",[id,index,crystal_id],state)

static func equip(state: Object,actor_id: int,slot: int,equipment_id: int) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("actor",actor_id),"equip",[slot,equipment_id],state)

static func equip_skill(state: Object,actor_id: int,skill_id: int,turn: int) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("actor",actor_id),"equip_skill",[skill_id,turn],state)

static func cancel_skill(state: Object,actor_id: int,skill_id: int,turn: int) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("actor",actor_id),"cancel_skill",[skill_id,turn],state)

static func set_roles(state: Object,main_id: int,support_id: int) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("gameplay_module",0,"BattleSystem::PartyRoles"),"set_roles",[main_id,support_id],state)

static func use_item(state: Object,item_id: int) -> Dictionary:
	if state.inventory_count("item",item_id)<=0: return {"ok":false,"message":"背包没有该物品。"}
	return Scripts.call_method(state.custom_data.data_ref("gameplay_module",0,"Storage"),"use_item",[item_id],state)

static func after_step(state: Object) -> Dictionary:
	# The source handlers do nothing without poison or their enabling items.
	# Keep real effects in the full transaction, including failure rollback.
	var game: Node=state.game()
	var custom: RefCounted=state.custom_data
	var index=int(custom.values.system.get("main_actor_index",0))
	if game!=null and game.has_method("event_map") and game.event_map()!=null and index>=0 and index<state.party.size():
		var actor: RefCounted=state.actor(int(state.party[index]))
		var constants: Dictionary=custom.gameplay().rules.constants
		if actor!=null and not actor.get_state_ids().has(int(constants.POISON_STATE_ID)):
			var inert=true
			for name in ["HIDE_ITEM_ID","MANOR_ITEM_ID","COTACK_ITEM_ID","HOOK_ITEM_ID"]:
				if state.inventory_count("item",int(constants[name]))>0: inert=false; break
			if inert: return {"ok":true,"value":null,"writes":0}
	return Scripts.call_method(state.custom_data.data_ref("player",state.map_id),"after_step",[],state)

static func recover_item(state: Object,item_id: int,actor_id: int) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0200.item_use/0202.update_state"},func(env):
		if not env._custom.party_call("in_map_use?",[item_id]): return env.fail("该物品不能按源地图恢复入口使用。")
		if not env._custom.party_ids.has(actor_id): return env.fail("恢复目标不在队伍中。")
		env._custom.temp_fields.item_id=item_id; env._custom.temp_fields.actor_id=actor_id
		return env.invoke(env.type_ref("Item"),"Recover",[],"Item"))

static func request_tool(state: Object,item_id: int) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0202.update_item"},func(env):
		if not env._custom.party_call("item_can_use?",[item_id]): return env.fail("该物品当前不可使用。")
		if env._custom.party_call("in_map_use?",[item_id]): return env.fail("该物品需要按源恢复入口选择角色。")
		var reason: String=state.common_event_reason(9)
		if not reason.is_empty(): return env.fail(reason)
		env._custom.temp_fields.item_id=item_id
		env._custom.pending_effects["common_event"]={"id":9,"source":"flash_tool:%d" % item_id,"actor_id":0,"target_id":0}
		return true)

static func save_skill_set(state: Object,actor_id: int,index: int,side: String) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("actor",actor_id),"save_skill",[index,side],state)

static func load_skill_set(state: Object,actor_id: int,index: int,side: String) -> Dictionary:
	return Scripts.call_method(state.custom_data.data_ref("actor",actor_id),"load_skill",[index,side],state)

static func switch_roles(state: Object) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0200.switch_battle_roles"},func(env):
		var ref=env._custom.data_ref("gameplay_module",0,"BattleSystem::PartyRoles")
		if env.invoke(ref,"switch_locked?",[]): return false
		if not env.invoke(ref,"swap_roles!",[]): return false
		var ids=env._custom.gameplay().role_actor_ids()
		for i in 2:
			if ids[i]>0: env.invoke(env._custom.data_ref("actor",ids[i]),"load_skill",[0,"atk" if i==0 else "sup"])
		env.invoke(env._custom.data_ref("player",state.map_id),"refresh",[])
		env.invoke(env._custom.data_ref("map",state.map_id),"refresh_damage",[])
		return true)

static func choose_floor(state: Object,floor_number: Variant) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0254.update_item/0117.item"},func(env):
		if not env._custom._integer(floor_number): return env.fail("楼层选择必须为整数。")
		var region: Variant=env._variables.get("3",0)
		var regions: Variant=env._variables.get("18",0)
		var choices: Variant=env.index_get(regions,region)
		if not env.failure.is_empty(): return null
		if not choices is Array or not choices.has(floor_number): return env.fail("该楼层不在原窗口当前区域的已发现列表中。")
		return env.index_set({"__state_table":"variable"},13,int(floor_number)))

static func cancel_floor(state: Object) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0254.update_item"},func(env):
		return env.index_set({"__state_table":"variable"},13,"stop"))

static func choose_character(state: Object,actor_id: Variant) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0255.update_item/0118.item"},func(env):
		if not env._custom._integer(actor_id) or not env._custom.party_ids.has(int(actor_id)): return env.fail("角色不在原选择窗口的队伍列表中。")
		return env.index_set({"__state_table":"variable"},12,int(actor_id)-1))

static func cancel_character(state: Object) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0255.update_item"},func(env):
		var main_id: Variant=env.invoke(env._custom.data_ref("gameplay_module",0,"BattleSystem::PartyRoles"),"main_id",[])
		if not env.failure.is_empty(): return null
		return env.index_set({"__state_table":"variable"},12,main_id))

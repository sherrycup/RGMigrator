extends RefCounted
## Original 0209 category/enable/setSkill; UI and GDScript use one transaction.
const Data=preload("RuntimeData.gd")
const Scripts=preload("ScriptRuntime.gd")

static func category(skill: Dictionary) -> int:
	var elements: Array=skill.get("element_set",[]).map(func(id):return int(id))
	if elements.has(11): return -1 # Original magic category is still empty.
	return int(elements[0])-7 if not elements.is_empty() and int(elements[0]) in [7,8,9,10] else -1

static func available(custom: RefCounted,actor: RefCounted,skill_id: int) -> bool:
	if actor==null or actor.battle_down() or not actor.has_skill(skill_id): return false
	var elements: Array=custom.record("Skills",skill_id).get("element_set",[]).map(func(id):return int(id))
	var roles=custom.gameplay().role_ids()
	if actor.id==roles[0] and (elements.has(15) or elements.has(16)): return false
	if actor.id==roles[1] and (elements.has(13) or elements.has(14)): return false
	return true

static func set_skill(state: Object,actor_id: int,skill_id: int,input: int=0) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0209.setSkill/0202.update_skill_category"},func(env):
		var custom=env._custom; var actor=custom.staged_actor(actor_id)
		if not custom.party_ids.has(actor_id) or not available(custom,actor,skill_id): return env.fail("该角色当前不能配置此技能。")
		var group=category(custom.record("Skills",skill_id))
		if group<0: return env.fail("源技能分类尚未实现。")
		var slot=actor.project_skill_slot(skill_id)
		var result: Dictionary={"ok":true,"changed":false}
		if input==0:
			if slot[0]: actor.cancel_project_skill(skill_id,int(slot[1])); result.changed=true
			else:
				var turn=-1 if group==0 else -2 if group==1 else 0
				if turn==0:
					for candidate in [1,2,3]:
						if not actor.project_fields.equip_skills.has(str(candidate)): turn=candidate; break
				if turn==0: return env.fail("前三回合已有技能，请用1—8指定回合。")
				result=actor.equip_project_skill(skill_id,turn)
		else:
			if input<1 or input>8: return env.fail("技能回合必须为1—8。")
			if group in [0,1]: return false
			var equipped: Variant=actor.project_fields.equip_skills.get(str(input))
			if equipped!=null:
				if slot[0]: result=actor.swap_project_skills(skill_id,int(equipped),int(slot[1]),input)
				else: actor.cancel_project_skill(int(equipped),input); result=actor.equip_project_skill(skill_id,input)
			else: result=actor.equip_project_skill(skill_id,input)
		if not result.ok: return env.fail(result.message)
		if state.game()!=null: env.invoke(custom.data_ref("map",state.map_id),"refresh_damage",[])
		return result.get("changed",true))

static func switch_page_actor(state: Object) -> Dictionary:
	return Scripts.call_transaction(state,{"source":"0209.update.Tab"},func(env):
		var custom=env._custom
		if custom.gameplay().invoke(custom.data_ref("gameplay_module",0,"BattleSystem::PartyRoles"),"switch_locked?",[]): return env.fail("战斗不能时不能切换角色。")
		if custom.party_ids.size()<2: return false
		var first=custom.party_ids[0]; custom.party_ids[0]=custom.party_ids[1]; custom.party_ids[1]=first
		return true)

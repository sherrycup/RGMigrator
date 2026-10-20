## 职责：组织闪翼技能配置规则与槽位数据，供技能页面和角色能力查询。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/Skill/SkillConfig.gd").方法名(...)。
##
## 调用接口：
##   static func category(skill: Dictionary) -> int
##     参数 skill（Dictionary；必填）：技能定义或技能对象。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func available(custom: RefCounted, actor: RefCounted, skill_id: int) -> bool
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 actor（RefCounted；必填）：角色实例、引用或记录。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func set_skill(state: Object, actor_id: int, skill_id: int, input: int = 0) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：进入技能配置时保存的首位角色数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 input（int；默认值 0）：输入事件、输入状态或待处理的原始值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func switch_page_actor(state: Object) -> Dictionary
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func restore_page_actor(state: Object, actor_id: int) -> Dictionary
##     用途：技能配置取消时按0202恢复进入时的前两角色顺序；不更换存档对象或修改技能。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：进入技能配置时保存的首位角色数据库编号。
##     返回：原脚本调用结果字典，ok为是否完成；变化沿用同一RuntimeState。
##
## 接口说明结束。

extends RefCounted
## Original 0209 category/enable/setSkill; UI and GDScript use one transaction.
const Data = preload("../../00_Game/RuntimeData.gd")
const Scripts = preload("../../10_Support/Scripting/ScriptRuntime.gd")


static func category(skill: Dictionary) -> int:
	var elements: Array = skill.get("element_set", []).map(func(id): return int(id))
	if elements.has(11):
		return -1  # Original magic category is still empty.
	return (
		int(elements[0]) - 7
		if not elements.is_empty() and int(elements[0]) in [7, 8, 9, 10]
		else -1
	)


static func available(custom: RefCounted, actor: RefCounted, skill_id: int) -> bool:
	if actor == null or actor.battle_down() or not actor.has_skill(skill_id):
		return false
	var elements: Array = custom.record("Skills", skill_id).get("element_set", []).map(
		func(id): return int(id)
	)
	var roles = custom.gameplay().role_ids()
	if actor.id == roles[0] and (elements.has(15) or elements.has(16)):
		return false
	if actor.id == roles[1] and (elements.has(13) or elements.has(14)):
		return false
	return true


static func set_skill(state: Object, actor_id: int, skill_id: int, input: int = 0) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0209.setSkill/0202.update_skill_category"},
		func(env):
			var custom = env._custom
			var actor = custom.staged_actor(actor_id)
			if not custom.party_ids.has(actor_id) or not available(custom, actor, skill_id):
				return env.fail("该角色当前不能配置此技能。")
			var group = category(custom.record("Skills", skill_id))
			if group < 0:
				return env.fail("源技能分类尚未实现。")
			var slot = actor.project_skill_slot(skill_id)
			var result: Dictionary = {"ok": true, "changed": false}
			if input == 0:
				if slot[0]:
					actor.cancel_project_skill(skill_id, int(slot[1]))
					result.changed = true
				else:
					var turn = -1 if group == 0 else -2 if group == 1 else 0
					if turn == 0:
						for candidate in [1, 2, 3]:
							if not actor.project_fields.equip_skills.has(str(candidate)):
								turn = candidate
								break
					if turn == 0:
						return env.fail("前三回合已有技能，请用1—8指定回合。")
					result = actor.equip_project_skill(skill_id, turn)
			else:
				if input < 1 or input > 8:
					return env.fail("技能回合必须为1—8。")
				if group in [0, 1]:
					return false
				var equipped: Variant = actor.project_fields.equip_skills.get(str(input))
				if equipped != null:
					if slot[0]:
						result = actor.swap_project_skills(
							skill_id, int(equipped), int(slot[1]), input
						)
					else:
						actor.cancel_project_skill(int(equipped), input)
						result = actor.equip_project_skill(skill_id, input)
				else:
					result = actor.equip_project_skill(skill_id, input)
			if not result.ok:
				return env.fail(result.message)
			if state.game() != null:
				env.invoke(custom.data_ref("map", state.map_id), "refresh_damage", [])
			return result.get("changed", true)
	)


static func switch_page_actor(state: Object) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0209.update.Tab"},
		func(env):
			var custom = env._custom
			if custom.gameplay().invoke(
				custom.data_ref("gameplay_module", 0, "BattleSystem::PartyRoles"),
				"switch_locked?",
				[]
			):
				return env.fail("战斗不能时不能切换角色。")
			if custom.party_ids.size() < 2:
				return false
			var first = custom.party_ids[0]
			custom.party_ids[0] = custom.party_ids[1]
			custom.party_ids[1] = first
			return true
	)


static func restore_page_actor(state: Object, actor_id: int) -> Dictionary:
	return Scripts.call_transaction(
		state,
		{"source": "0202.update_skill_category.cancel"},
		func(env):
			var ids: Array = env._custom.party_ids
			if ids.size() >= 2 and ids[0] != actor_id and ids[1] == actor_id:
				var first = ids[0]
				ids[0] = ids[1]
				ids[1] = first
			return true
	)

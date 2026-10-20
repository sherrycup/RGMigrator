## 职责：处理物品或技能使用后的公共事件预约，协调菜单返回与事件执行。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/CommonEventUse.gd").方法名(...)。
##
## 调用接口：
##   static func skill_reason(state: Node, actor_id: int, skill_id: int) -> String
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func use_skill(state: Node, actor_id: int, skill_id: int, target_id: int) -> Dictionary
##     用途：检查并执行技能使用效果。
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 target_id（int；必填）：目标对象的编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted
## Menu skill entry for native common events; unsupported effects fail before SP.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Numbers = preload("res://runtime/scripts/00_Game/ActorParameters.gd")


static func skill_reason(state: Node, actor_id: int, skill_id: int) -> String:
	var skill := Data.record("Skills", skill_id)
	var actor: RefCounted = state.actor(actor_id) if state.party.has(actor_id) else null
	if actor == null or not state.has_skill(actor_id, skill_id) or skill.is_empty():
		return "角色尚未学会此特技。"
	if actor.hp <= 0 or int(skill.get("occasion", 3)) not in [0, 2]:
		return "此特技当前不能在菜单使用。"
	if not Numbers.integer(skill.get("sp_cost", 0), 0) or actor.sp < int(skill.get("sp_cost", 0)):
		return "SP不足。"
	var common_id := int(skill.get("common_event_id", 0))
	if common_id <= 0:
		return "此特技没有公共事件使用入口；其他特技效果尚未接入。"
	var reason: String = state.common_event_reason(common_id)
	if not reason.is_empty():
		return reason
	var restriction := 0
	for id in actor.get_state_ids():
		restriction = maxi(restriction, int(Data.record("States", id).get("restriction", 0)))
	if restriction >= 2 or (restriction == 1 and int(skill.get("atk_f", 0)) == 0):
		return "角色状态禁止使用此特技。"
	if int(skill.get("scope", 0)) in [0, 1, 2]:
		return ""
	if int(skill.get("scope", 0)) not in [3, 4, 7]:
		return "此特技的目标效果尚未支持，未扣SP。"
	for key in [
		"power", "atk_f", "pdef_f", "mdef_f", "str_f", "dex_f", "agi_f", "int_f", "variance"
	]:
		if int(skill.get(key, 0)) != 0:
			return "此特技还包含尚未支持的结算效果，未扣SP。"
	if (
		int(skill.get("hit", 100)) != 100
		or not skill.get("plus_state_set", []).is_empty()
		or not skill.get("minus_state_set", []).is_empty()
		or not skill.get("element_set", []).is_empty()
	):
		return "此特技还包含尚未支持的命中、状态或属性效果，未扣SP。"
	return ""


static func use_skill(state: Node, actor_id: int, skill_id: int, target_id: int) -> Dictionary:
	var reason := skill_reason(state, actor_id, skill_id)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	var skill := Data.record("Skills", skill_id)
	if int(skill.get("scope", 0)) in [3, 7]:
		var target := actor_id if int(skill.scope) == 7 else target_id
		if (
			not state.party.has(target)
			or state.actor(target) == null
			or state.actor(target).hp <= 0
		):
			return {"ok": false, "message": "请选择存活的队员。"}
		target_id = target
	elif int(skill.get("scope", 0)) == 4:
		if not state.party.any(
			func(id: Variant) -> bool:
				return state.actor(int(id)) != null and state.actor(int(id)).hp > 0
		):
			return {"ok": false, "message": "没有存活的队员。"}
	var reserved: Dictionary = state.reserve_common_event(
		int(skill.common_event_id), "skill:%d" % skill_id, actor_id, target_id
	)
	if not reserved.ok:
		return reserved
	state.actor(actor_id).sp -= int(skill.get("sp_cost", 0))
	state.state_changed.emit()
	return {
		"ok": true,
		"message": "使用了 %s。" % str(skill.get("name", "特技")),
		"common_event": int(skill.common_event_id)
	}

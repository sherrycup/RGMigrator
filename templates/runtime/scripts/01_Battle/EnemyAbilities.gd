## 职责：解析并应用闪翼敌人能力与特殊规则，供普通战斗及地图效果查询。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/01_Battle/EnemyAbilities.gd").方法名(...)。
##
## 调用接口：
##   static func map_parameters(actions: Array, constants: Dictionary) -> Dictionary
##     参数 actions（Array；必填）：待处理的行动列表。
##     参数 constants（Dictionary；必填）：脚本常量表或计算使用的常量集合。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func elements(definition: Dictionary) -> Array
##     参数 definition（Dictionary；必填）：对象的只读定义或原数据库记录。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
## 接口说明结束。

extends RefCounted


## Source 0070 load_skills/load_element; obvious source field typos corrected.
static func map_parameters(actions: Array, constants: Dictionary) -> Dictionary:
	var parameters: Dictionary = {}
	for action in actions:
		if (
			not action is Dictionary
			or int(action.get("kind", 0)) != 1
			or int(action.get("condition_level", 0)) != 10
		):
			continue
		var id = int(action.get("skill_id", 0))
		var damage = (
			int(action.get("condition_turn_a", 0)) * 10000 + int(action.get("condition_turn_b", 0))
		)
		if id == int(constants.get("MANOR_SKILL_ID", 0)):
			parameters.manor = {
				"range": int(action.get("rating", 0)),
				"damage": int(constants.get("DEFAULT_MANOR_DAMAGE", 0)) if damage == 1 else damage
			}
		elif id == int(constants.get("COTACK_SKILL_ID", 0)):
			var ratio = int(action.get("condition_hp", 100))
			parameters.cotack = {
				"ratio": int(constants.get("DEFAULT_COTACK_RATIO", 50)) if ratio == 100 else ratio,
				"damage": int(constants.get("DEFAULT_COTACK_DAMAGE", 0)) if damage == 1 else damage
			}
		elif id == int(constants.get("HOOK_SKILL_ID", 0)):
			parameters.hook = {
				"damage": int(constants.get("DEFAULT_HOOK_DAMAGE", 0)) if damage == 1 else damage
			}
	return parameters


static func elements(definition: Dictionary) -> Array:
	var table: Dictionary = definition.get("element_ranks", {})
	var result: Array = []
	for i in range(1, int(table.get("x_size", 0))):
		if i < table.get("values", []).size() and int(table["values"][i]) == 1:
			result.append(i)
	return result

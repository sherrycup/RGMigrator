## 职责：管理战斗过程中的状态集合、叠加关系和有效能力查询。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/01_Battle/BattleStateContainer.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/01_Battle/BattleStateContainer.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   static func create_status( name: String, category: String, duration: Variant, effects: Dictionary = {} ) -> Dictionary
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 duration（Variant；必填）：持续时间，单位按该原接口约定。
##     参数 effects（Dictionary；默认值 {}）：需要应用的效果列表。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func add(status: Dictionary) -> void
##     参数 status（Dictionary；必填）：当前状态或处理状态标识。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func stat_rate(key: String) -> float
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func stat_plus(key: String) -> float
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func resolve_action_end(owner: Dictionary) -> Array
##     参数 owner（Dictionary；必填）：持有此对象的调用方或运行状态。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func tick_action_window() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## 0072 BattleStatus / StateContainer. This state exists only in one simulation;
## it is independent of the actor's persistent RGSS database states.
var statuses: Array = []


static func create_status(
	name: String, category: String, duration: Variant, effects: Dictionary = {}
) -> Dictionary:
	return {
		"name": name,
		"category": category,
		"duration_windows": duration,
		"new_this_action": true,
		"effects": effects,
		"stack_count": 1
	}


func add(status: Dictionary) -> void:
	# Like source @statuses << status, keep the simulation-owned status identity
	# so later stack/effect edits affect the status already in the container.
	statuses.append(status)


func stat_rate(key: String) -> float:
	var value = 1.0
	for status in statuses:
		var effect: Variant = status.get("effects", {}).get(key)
		if effect != null and not (effect is bool and not effect):
			value *= float(effect)
	return value


func stat_plus(key: String) -> float:
	var value = 0.0
	for status in statuses:
		var effect: Variant = status.get("effects", {}).get(key)
		if effect != null and not (effect is bool and not effect):
			value += float(effect)
	return value


func resolve_action_end(owner: Dictionary) -> Array:
	var events: Array = []
	for status in statuses:
		if status.get("category") != "dot":
			continue
		var amount: float = (
			float(status.get("effects", {}).get("damage", 0))
			* maxf(float(status.get("stack_count", 1)), 1.0)
		)
		if amount <= 0:
			continue
		# receive_damage truncates to int, but the source log retains the raw DOT.
		var damage = maxi(int(amount), 0)
		owner.hp = max(owner.hp - damage, 0)
		owner.t_damage += damage
		owner.attacked_times += 1
		events.append({"name": str(status.get("name", "")), "damage": amount})
	return events


func tick_action_window() -> void:
	for status in statuses:
		if status.get("new_this_action", true):
			status.new_this_action = false
			continue
		if status.get("duration_windows") != null:
			status.duration_windows -= 1
	statuses = statuses.filter(
		func(status): return status.get("duration_windows") == null or status.duration_windows > 0
	)

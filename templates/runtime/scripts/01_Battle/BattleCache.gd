## 职责：缓存普通战斗计算中可复用的只读定义，减少重复构造与查询。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/01_Battle/BattleCache.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/01_Battle/BattleCache.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func register_condition(name: String, provider: Callable) -> Dictionary
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 provider（Callable；必填）：提供数据或对象的回调。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func unregister_condition(name: String) -> void
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func clear_conditions() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func tag_for( key: String, party: Array, enemy: Dictionary, skills: Dictionary, skill_revision: int ) -> Dictionary
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 party（Array；必填）：按队伍顺序排列的角色编号。
##     参数 enemy（Dictionary；必填）：敌人定义、引用或运行对象。
##     参数 skills（Dictionary；必填）：技能定义或技能配置集合。
##     参数 skill_revision（int；必填）：技能配置的修订标识。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func with_party_snapshot(action: Callable) -> Variant
##     参数 action（Callable；必填）：战斗行动或当前操作的数据。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted
## 0072 Cache.register_condition / tag_for / with_party_snapshot.
## Providers consume detached enemy inputs and must return finite value trees.
## Cache conditions and batching are process-local and never serialized.
static var conditions: Dictionary = {}
static var revision = 0
var _batch_tags: Variant = null
var _batch_party: Variant = null


func register_condition(name: String, provider: Callable) -> Dictionary:
	if name.is_empty() or not provider.is_valid():
		return {"ok": false, "message": "缓存条件需要名称与有效提供函数。"}
	conditions[name] = provider
	revision += 1
	return {"ok": true}


static func unregister_condition(name: String) -> void:
	if conditions.erase(name):
		revision += 1


static func clear_conditions() -> void:
	# GDScript lambdas retain their script context. Release process-local providers
	# when the RuntimeState autoload exits, before Godot tears down those scripts.
	conditions.clear()
	revision += 1


func tag_for(
	key: String, party: Array, enemy: Dictionary, skills: Dictionary, skill_revision: int
) -> Dictionary:
	if _batch_tags != null and _batch_tags.has(key):
		return {"ok": true, "tag": _batch_tags[key].duplicate(true)}
	var extras: Dictionary = {}
	for name in conditions:
		var value: Variant = conditions[name].call(enemy.duplicate(true))
		if not _value_tree(value):
			return {"ok": false, "message": "缓存条件只能返回有限标量、Array 或字符串键 Dictionary：" + name}
		extras[name] = value
	if _batch_tags != null and _batch_party == null:
		_batch_party = party.duplicate(true)
	var tag = {
		"party": party.duplicate(true) if _batch_tags == null else _batch_party.duplicate(true),
		"enemy": enemy.duplicate(true),
		"skills": skills.duplicate(true),
		"skill_revision": skill_revision,
		"extra_conditions": extras.duplicate(true),
		"condition_revision": revision
	}
	if _batch_tags != null:
		_batch_tags[key] = tag.duplicate(true)
	return {"ok": true, "tag": tag}


func with_party_snapshot(action: Callable) -> Variant:
	if not action.is_valid():
		return null
	var previous_tags: Variant = _batch_tags
	var previous_party: Variant = _batch_party
	_batch_tags = {}
	_batch_party = null
	var result: Variant = action.call()
	_batch_tags = previous_tags
	_batch_party = previous_party
	return result


static func _value_tree(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is bool or value is String:
		return true
	if value is int or value is float:
		return is_finite(float(value))
	if value is Array:
		for item in value:
			if not _value_tree(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or not _value_tree(value[key], depth + 1):
				return false
		return true
	return false

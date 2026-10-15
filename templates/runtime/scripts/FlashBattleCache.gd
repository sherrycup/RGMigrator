extends RefCounted
## 0072 Cache.register_condition / tag_for / with_party_snapshot.
## Providers consume detached enemy inputs and must return finite value trees.
## Cache conditions and batching are process-local and never serialized.
static var conditions: Dictionary={}
static var revision=0
var _batch_tags: Variant=null
var _batch_party: Variant=null

func register_condition(name: String,provider: Callable) -> Dictionary:
	if name.is_empty() or not provider.is_valid(): return {"ok":false,"message":"缓存条件需要名称与有效提供函数。"}
	conditions[name]=provider; revision+=1
	return {"ok":true}

static func unregister_condition(name: String) -> void:
	if conditions.erase(name): revision+=1

static func clear_conditions() -> void:
	# GDScript lambdas retain their script context. Release process-local providers
	# when the RuntimeState autoload exits, before Godot tears down those scripts.
	conditions.clear(); revision+=1

func tag_for(key: String,party: Array,enemy: Dictionary,skills: Dictionary,skill_revision: int) -> Dictionary:
	if _batch_tags!=null and _batch_tags.has(key): return {"ok":true,"tag":_batch_tags[key].duplicate(true)}
	var extras: Dictionary={}
	for name in conditions:
		var value: Variant=conditions[name].call(enemy.duplicate(true))
		if not _value_tree(value): return {"ok":false,"message":"缓存条件只能返回有限标量、Array 或字符串键 Dictionary："+name}
		extras[name]=value
	if _batch_tags!=null and _batch_party==null: _batch_party=party.duplicate(true)
	var tag={"party":party.duplicate(true) if _batch_tags==null else _batch_party.duplicate(true),"enemy":enemy.duplicate(true),"skills":skills.duplicate(true),"skill_revision":skill_revision,"extra_conditions":extras.duplicate(true),"condition_revision":revision}
	if _batch_tags!=null: _batch_tags[key]=tag.duplicate(true)
	return {"ok":true,"tag":tag}

func with_party_snapshot(action: Callable) -> Variant:
	if not action.is_valid(): return null
	var previous_tags: Variant=_batch_tags; var previous_party: Variant=_batch_party
	_batch_tags={}; _batch_party=null
	var result: Variant=action.call()
	_batch_tags=previous_tags; _batch_party=previous_party
	return result

static func _value_tree(value: Variant,depth: int=0) -> bool:
	if depth>64: return false
	if value==null or value is bool or value is String: return true
	if value is int or value is float: return is_finite(float(value))
	if value is Array:
		for item in value:
			if not _value_tree(item,depth+1): return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or not _value_tree(value[key],depth+1): return false
		return true
	return false

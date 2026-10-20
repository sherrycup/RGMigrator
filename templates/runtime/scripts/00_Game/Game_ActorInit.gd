## 职责：加载角色的原工程初始化预设，供事件通过 Actor_Init.load(actor_id, index) 直接调用。
##
## 调用方式：
##   事件正文直接写 Actor_Init.load(角色编号, 预设编号)，无需 extends 或 run。
##   Actor_Init 由执行框架绑定到当前事件上下文；修改当前正式角色，不创建独立角色副本。
##
## 调用接口：
##   func _init(api: RefCounted) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 api（RefCounted；必填）：当前事件的业务接口服务，持有同一上下文的弱引用。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func load(actor_id: int, index: int = 0) -> Variant
##     用途：应用该角色在原工程定义的完整初始化预设。
##     参数 actor_id（int；必填）：角色原数据库编号，例如2。
##     参数 index（int；默认值 0）：从0开始的原预设序号，默认0。
##     返回：原接口返回null；失败沿用首错停止规则。
##
##   static func apply(custom: RefCounted, actor_id: int, index: int = 0) -> Variant
##     用途：应用已选定或已准备的修改。
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 index（int；默认值 0）：集合或列表中的位置索引。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted
var _api: WeakRef


func _init(api: RefCounted) -> void:
	_api = weakref(api)


func load(actor_id: int, index: int = 0) -> Variant:
	var api: RefCounted = _api.get_ref()
	return api.operation("actor_preset", [actor_id, index]) if api != null else null


static func apply(custom: RefCounted, actor_id: int, index: int = 0) -> Variant:
	var preset: Dictionary = custom.manifest.get("actor_presets", {}).get(str(actor_id), {}).get(
		str(index), {}
	)
	if preset.is_empty():
		return null
	var actor: RefCounted = custom.staged_actor(actor_id)
	if actor == null:
		return null
	for key in preset:
		var value: Variant = preset[key]
		# JSON parser numbers are floats; original preset literals are integral.
		if value is float and value == floor(value) and abs(value) <= 9007199254740991:
			value = int(value)
		var changed: Dictionary
		if key in actor.PROJECT_KEYS:
			changed = actor.set_project_parameter(key, value)
		elif key == "level":
			changed = actor.set_level(value)
		elif key in ["hp", "sp"]:
			actor.set(key, value)
			continue
		else:
			return custom.reject("角色预设字段尚未接入：" + key)
		if not changed.ok:
			return custom.reject(changed.message)
	return null

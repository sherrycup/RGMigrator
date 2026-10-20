## 职责：登记闪翼战斗角色、技能和状态的运行定义，连接目录与模拟器。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/01_Battle/BattleRegistry.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func is_configured() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func configure(catalog: Dictionary) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 catalog（Dictionary；必填）：对象或技能的只读目录服务。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func define_skill(id: int, builder: Callable = Callable()) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 builder（Callable；默认值 Callable()）：构造目标数据或界面的回调。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func fetch(id: int) -> Variant
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func includes(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func action_skill(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func reaction_skill(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func passive_skill(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func rage_skill(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func database_fields(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 接口说明结束。

extends RefCounted
## 0072 SkillRegistry. Definitions are detached values; registration revisions
## invalidate prediction tags. Configure installs the extracted 0073 catalog once.
const Definition = preload("BattleSkillDefinition.gd")
static var _definitions: Dictionary = {}
static var _revision = 0
static var _catalog_key = ""
var definitions: Dictionary:
	get:
		return _definitions
var revision: int:
	get:
		return _revision


func is_configured() -> bool:
	return not _catalog_key.is_empty()


func configure(catalog: Dictionary) -> void:
	var key = JSON.stringify(catalog).sha256_text()
	if key != _catalog_key:
		_catalog_key = key
		# Keep the module dictionary identity: already-created Gameplay simulators
		# must observe catalog reloads as well as same-ID define replacements.
		_definitions.clear()
		_definitions.merge(catalog.duplicate(true), true)
		_revision += 1


func define_skill(id: int, builder: Callable = Callable()) -> Dictionary:
	if id < 0:
		return {"ok": false, "message": "技能注册 ID 必须为非负整数。"}
	var definition = Definition.new(id)
	if builder.is_valid():
		builder.call(definition)
	if not definition.failure.is_empty():
		return {"ok": false, "message": definition.failure}
	# Replacement is whole-definition, as Ruby define; references may be defined
	# later and are validated together before simulation/database synchronization.
	_definitions[str(id)] = definition.to_dictionary()
	_revision += 1
	return {"ok": true, "definition": definitions[str(id)].duplicate(true), "revision": revision}


func fetch(id: int) -> Variant:
	return definitions[str(id)].duplicate(true) if definitions.has(str(id)) else null


func includes(id: int) -> bool:
	return definitions.has(str(id))


func action_skill(id: int) -> bool:
	return _kind(id) == "damage"


func reaction_skill(id: int) -> bool:
	return _kind(id) in ["follow_up_damage", "follow_up_counter", "follow_up_attack_count"]


func passive_skill(id: int) -> bool:
	return _kind(id) in ["passive_enemy_defense_rate", "passive_attack_rate", "extra_attack"]


func rage_skill(id: int) -> bool:
	return _kind(id) == "rage"


func database_fields(id: int) -> Dictionary:
	var definition: Variant = fetch(id)
	if definition == null:
		return {}
	var target = str(definition.target)
	var elements: Array = definition.get("element_set", []).duplicate()
	if target == "support" and not elements.has(31):
		elements.append(31)
	if target == "party" and not elements.has(32):
		elements.append(32)
	return {
		"id": id,
		"name": definition.get("name", ""),
		"description": definition.get("description", ""),
		"icon_name": definition.get("icon_name", ""),
		"animation1_id": definition.get("animation1_id", 0),
		"animation2_id": definition.get("animation2_id", 0),
		"scope":
		(
			definition.scope
			if definition.get("scope") != null
			else 2 if target == "party" else 3 if target == "self" else 1
		),
		"power": definition.stiffness,
		"atk_f": int(float(definition.atk_rate) * 100),
		"sp_cost": 0,
		"element_set": elements,
		"plus_state_set": [],
		"minus_state_set": []
	}


func _kind(id: int) -> String:
	return str(definitions.get(str(id), {}).get("kind", ""))

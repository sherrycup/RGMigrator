extends RefCounted
## 0072 SkillRegistry. Definitions are detached values; registration revisions
## invalidate prediction tags. Configure installs the extracted 0073 catalog once.
const Definition=preload("FlashBattleSkillDefinition.gd")
static var _definitions: Dictionary={}
static var _revision=0
static var _catalog_key=""
var definitions: Dictionary:
	get: return _definitions
var revision: int:
	get: return _revision

func is_configured() -> bool:
	return not _catalog_key.is_empty()

func configure(catalog: Dictionary) -> void:
	var key=JSON.stringify(catalog).sha256_text()
	if key!=_catalog_key:
		_catalog_key=key
		# Keep the module dictionary identity: already-created Gameplay simulators
		# must observe catalog reloads as well as same-ID define replacements.
		_definitions.clear(); _definitions.merge(catalog.duplicate(true),true); _revision+=1

func define_skill(id: int,builder: Callable=Callable()) -> Dictionary:
	if id<0: return {"ok":false,"message":"技能注册 ID 必须为非负整数。"}
	var definition=Definition.new(id)
	if builder.is_valid(): builder.call(definition)
	if not definition.failure.is_empty(): return {"ok":false,"message":definition.failure}
	# Replacement is whole-definition, as Ruby define; references may be defined
	# later and are validated together before simulation/database synchronization.
	_definitions[str(id)]=definition.to_dictionary(); _revision+=1
	return {"ok":true,"definition":definitions[str(id)].duplicate(true),"revision":revision}

func fetch(id: int) -> Variant:
	return definitions[str(id)].duplicate(true) if definitions.has(str(id)) else null

func includes(id: int) -> bool:
	return definitions.has(str(id))

func action_skill(id: int) -> bool:
	return _kind(id)=="damage"

func reaction_skill(id: int) -> bool:
	return _kind(id) in ["follow_up_damage","follow_up_counter","follow_up_attack_count"]

func passive_skill(id: int) -> bool:
	return _kind(id) in ["passive_enemy_defense_rate","passive_attack_rate","extra_attack"]

func rage_skill(id: int) -> bool:
	return _kind(id)=="rage"

func database_fields(id: int) -> Dictionary:
	var definition: Variant=fetch(id)
	if definition==null: return {}
	var target=str(definition.target); var elements: Array=definition.get("element_set",[]).duplicate()
	if target=="support" and not elements.has(31): elements.append(31)
	if target=="party" and not elements.has(32): elements.append(32)
	return {"id":id,"name":definition.get("name",""),"description":definition.get("description",""),"icon_name":definition.get("icon_name",""),"animation1_id":definition.get("animation1_id",0),"animation2_id":definition.get("animation2_id",0),"scope":definition.scope if definition.get("scope")!=null else 2 if target=="party" else 3 if target=="self" else 1,"power":definition.stiffness,"atk_f":int(float(definition.atk_rate)*100),"sp_cost":0,"element_set":elements,"plus_state_set":[],"minus_state_set":[]}

func _kind(id: int) -> String:
	return str(definitions.get(str(id),{}).get("kind",""))

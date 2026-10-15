extends RefCounted
## 0072 SkillDefinition / RageDefinition / RageRule. Editable GDScript catalog API.
var value: Dictionary
var failure=""

func _init(id: int) -> void:
	value={"id":id,"name":str(id),"description":"","icon_name":"","animation1_id":0,"animation2_id":0,"kind":"damage","target":"opponent","stiffness":20,"hit_count":1,"atk_rate":1.0,"threshold":0,"instant_follow_up":false,"scope":null,"element_set":[],"extra_attacks":0,"rage_rules":[]}

func display(name: String,description: Variant=null) -> RefCounted:
	value.name=name
	if description!=null: value.description=str(description)
	return self

func action(target: String,atk_rate: float,hit_count: int=1,stiffness: int=20) -> RefCounted:
	value.kind="damage"; value.target=target; value.atk_rate=atk_rate; value.hit_count=hit_count; value.stiffness=stiffness
	return self

func follow_up_damage(rate: float=0.0) -> RefCounted:
	value.kind="follow_up_damage"; value.target="opponent"; value.atk_rate=rate; value.instant_follow_up=true
	return self

func follow_up_counter(threshold: int,atk_rate: float) -> RefCounted:
	value.kind="follow_up_counter"; value.threshold=threshold; value.atk_rate=atk_rate
	return self

func follow_up_attack_count(threshold: int,atk_rate: float) -> RefCounted:
	value.kind="follow_up_attack_count"; value.threshold=threshold; value.atk_rate=atk_rate
	return self

func passive_enemy_defense_rate(rate: float) -> RefCounted:
	value.kind="passive_enemy_defense_rate"; value.target="enemy"; value.atk_rate=rate
	return self

func passive_attack_rate(rate: float) -> RefCounted:
	if not is_finite(rate) or rate<=0: failure="被动物攻倍率必须为正数。"; return self
	value.kind="passive_attack_rate"; value.target="self"; value.atk_rate=rate; value.stiffness=0
	return self

func extra_attack(count: int) -> RefCounted:
	if count<=0: failure="追加攻击段数必须为正整数。"; return self
	value.kind="extra_attack"; value.target="self"; value.extra_attacks=count; value.stiffness=0
	return self

func rage(builder: Callable) -> RefCounted:
	if not builder.is_valid(): failure="狂暴注册需要规则构建函数。"; return self
	var rules=RageDefinition.new(); builder.call(rules)
	if not rules.failure.is_empty(): failure=rules.failure; return self
	if rules.rules.is_empty(): failure="狂暴技能至少需要一条规则。"; return self
	value.kind="rage"; value.target="none"; value.stiffness=0; value.rage_rules=rules.rules.duplicate(true)
	return self

func to_dictionary() -> Dictionary:
	return value.duplicate(true)

class RageDefinition extends RefCounted:
	var rules: Array=[]
	var failure=""
	func when_patience_below(limit: int,description: String,builder: Callable) -> RefCounted:
		if limit<1 or limit>100: failure="狂暴耐心门槛必须为 1..100 的整数。"; return self
		if not builder.is_valid(): failure="狂暴规则需要效果构建函数。"; return self
		var rule=RageRule.new(); builder.call(rule)
		if not rule.failure.is_empty(): failure=rule.failure; return self
		if rule.effects.is_empty(): failure="狂暴规则至少需要一个效果。"; return self
		rules.append({"patience_limit":limit,"description":description,"effects":rule.effects.duplicate(true)})
		return self

class RageRule extends RefCounted:
	var effects: Array=[]
	var failure=""
	func add_skill(skill_id: int,options: Dictionary={}) -> RefCounted:
		for key in options:
			if key not in ["turn","default","rating"]: failure="狂暴新增技能只接受 turn/default/rating。"; return self
		if options.has("turn") and options.has("default"): failure="狂暴行动不能同时指定 turn 与 default。"; return self
		if options.has("turn") and (not _integer(options.turn) or options.turn<=0): failure="狂暴行动位置必须为正整数。"; return self
		if options.has("default") and options.default!=true: failure="狂暴 default 必须为 true。"; return self
		var rating: Variant=options.get("rating",5)
		if not _integer(rating) or rating<1 or rating>10: failure="狂暴优先度必须为 1..10 的整数。"; return self
		effects.append(["grant",skill_id,null,options.get("turn"),options.get("default"),int(rating)])
		return self
	func replace_skill(old_id: int,new_id: int) -> RefCounted:
		if old_id==new_id: failure="狂暴替换必须使用不同技能 ID。"; return self
		effects.append(["override",new_id,old_id,null,null,null]); return self
	static func _integer(number: Variant) -> bool:
		return (number is int or number is float) and is_finite(float(number)) and float(number)==floor(float(number))

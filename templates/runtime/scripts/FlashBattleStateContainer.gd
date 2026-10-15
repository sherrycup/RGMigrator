extends RefCounted
## 0072 BattleStatus / StateContainer. This state exists only in one simulation;
## it is independent of the actor's persistent RGSS database states.
var statuses: Array=[]

static func create_status(name: String,category: String,duration: Variant,effects: Dictionary={}) -> Dictionary:
	return {"name":name,"category":category,"duration_windows":duration,"new_this_action":true,"effects":effects,"stack_count":1}

func add(status: Dictionary) -> void:
	# Like source @statuses << status, keep the simulation-owned status identity
	# so later stack/effect edits affect the status already in the container.
	statuses.append(status)

func stat_rate(key: String) -> float:
	var value=1.0
	for status in statuses:
		var effect: Variant=status.get("effects",{}).get(key)
		if effect!=null and not (effect is bool and not effect): value*=float(effect)
	return value

func stat_plus(key: String) -> float:
	var value=0.0
	for status in statuses:
		var effect: Variant=status.get("effects",{}).get(key)
		if effect!=null and not (effect is bool and not effect): value+=float(effect)
	return value

func resolve_action_end(owner: Dictionary) -> Array:
	var events: Array=[]
	for status in statuses:
		if status.get("category")!="dot": continue
		var amount: float=float(status.get("effects",{}).get("damage",0))*maxf(float(status.get("stack_count",1)),1.0)
		if amount<=0: continue
		# receive_damage truncates to int, but the source log retains the raw DOT.
		var damage=maxi(int(amount),0)
		owner.hp=max(owner.hp-damage,0); owner.t_damage+=damage; owner.attacked_times+=1
		events.append({"name":str(status.get("name","")),"damage":amount})
	return events

func tick_action_window() -> void:
	for status in statuses:
		if status.get("new_this_action",true): status.new_this_action=false; continue
		if status.get("duration_windows")!=null: status.duration_windows-=1
	statuses=statuses.filter(func(status):return status.get("duration_windows")==null or status.duration_windows>0)

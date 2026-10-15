extends RefCounted
## Source 0070 load_skills/load_element; obvious source field typos corrected.
static func map_parameters(actions: Array,constants: Dictionary) -> Dictionary:
	var parameters: Dictionary={}
	for action in actions:
		if not action is Dictionary or int(action.get("kind",0))!=1 or int(action.get("condition_level",0))!=10: continue
		var id=int(action.get("skill_id",0))
		var damage=int(action.get("condition_turn_a",0))*10000+int(action.get("condition_turn_b",0))
		if id==int(constants.get("MANOR_SKILL_ID",0)):
			parameters.manor={"range":int(action.get("rating",0)),"damage":int(constants.get("DEFAULT_MANOR_DAMAGE",0)) if damage==1 else damage}
		elif id==int(constants.get("COTACK_SKILL_ID",0)):
			var ratio=int(action.get("condition_hp",100))
			parameters.cotack={"ratio":int(constants.get("DEFAULT_COTACK_RATIO",50)) if ratio==100 else ratio,"damage":int(constants.get("DEFAULT_COTACK_DAMAGE",0)) if damage==1 else damage}
		elif id==int(constants.get("HOOK_SKILL_ID",0)):
			parameters.hook={"damage":int(constants.get("DEFAULT_HOOK_DAMAGE",0)) if damage==1 else damage}
	return parameters

static func elements(definition: Dictionary) -> Array:
	var table: Dictionary=definition.get("element_ranks",{})
	var result: Array=[]
	for i in range(1,int(table.get("x_size",0))):
		if i<table.get("values",[]).size() and int(table["values"][i])==1: result.append(i)
	return result

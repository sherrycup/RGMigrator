@tool
extends RefCounted
## Ruby is preserved as authoring notes. Never evaluate or invent its result.
static func adapt_map(source: Dictionary) -> Dictionary:
	var result = source.duplicate(true)
	for key in result.get("events", {}):
		for page in result.events[key].get("pages", []):
			page.list = _adapt_list(page.get("list", []))
			if _has_script(page.get("move_route", {})):
				var original: Dictionary = page.move_route.duplicate(true)
				page.move_route = _adapt_route(original)
				page.list.push_front(_note("自主移动路线中的Ruby暂未转换；原代码已保留。",0,[original]))
	return result

static func adapt_common(source: Array) -> Array:
	var result:=source.duplicate(true)
	for event in result:
		if event is Dictionary and event.get("list",[]) is Array: event.list=_adapt_list(event.list)
	return result

static func _adapt_list(source: Array) -> Array:
	var result: Array = []
	var i = 0
	while i < source.size():
		var c: Dictionary = source[i].duplicate(true)
		var code = int(c.get("code",0))
		var indent = int(c.get("indent",0))
		var p: Array = c.get("parameters",[])
		if code in [355,655]:
			var originals: Array = [c.duplicate(true)]
			var text = "[Ruby暂未转换]\n" + str(p[0] if not p.is_empty() else "")
			i += 1
			while i < source.size() and int(source[i].get("code",0)) == 655:
				originals.append(source[i].duplicate(true))
				text += "\n" + str(source[i].get("parameters",[""])[0])
				i += 1
			result.append(_note(text,indent,originals))
			continue
		if code == 111 and not p.is_empty() and int(p[0]) == 12:
			var originals: Array = [c.duplicate(true)]
			i += 1
			while i < source.size():
				originals.append(source[i].duplicate(true))
				var closing = int(source[i].get("code",0)) == 412 and int(source[i].get("indent",0)) == indent
				i += 1
				if closing: break
			result.append(_note("[Ruby条件暂未转换；整个条件分支保留，等待转换后恢复]\n" + str(p[1] if p.size()>1 else ""),indent,originals))
			continue
		if code == 209 and p.size() == 2 and _has_script(p[1]):
			var original: Dictionary = p[1].duplicate(true)
			result.append(_note("[移动路线Ruby暂未转换] 原路线已保留。",indent,[c.duplicate(true)]))
			c.parameters[1] = _adapt_route(original)
		if code == 509 and p.size() == 1 and int(p[0].get("code",0)) == 45:
			i += 1
			continue
		result.append(c)
		i += 1
	return result

static func _has_script(route: Variant) -> bool:
	if not route is Dictionary: return false
	for command in route.get("list",[]):
		if int(command.get("code",0)) == 45: return true
	return false

static func _adapt_route(source: Dictionary) -> Dictionary:
	var result = source.duplicate(true)
	result["_editor_original_route"] = source.duplicate(true)
	result.list = source.get("list",[]).filter(func(c: Variant) -> bool: return int(c.get("code",0)) != 45).duplicate(true)
	return result

static func _note(text: String, indent: int, originals: Array) -> Dictionary:
	return {"_class":"RPG::EventCommand","code":108,"indent":indent,"parameters":[text],"_editor_original":originals.duplicate(true)}

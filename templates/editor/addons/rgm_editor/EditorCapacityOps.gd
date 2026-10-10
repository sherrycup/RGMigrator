@tool
extends RefCounted
## Empty indexed slots stay lightweight; shrinking never truncates live data.
const Schema = preload("EditorDatabaseSchema.gd")
const Presentation = preload("EditorPresentation.gd")
const MAXIMUM = 32767

static func resize(documents: RefCounted, category: String, values: Array, maximum: int) -> Dictionary:
	if maximum < 1 or maximum > MAXIMUM: return {"ok":false,"message":"最大编号须在1–32767之间。"}
	var names = category in ["switches","variables","elements"]
	if not names and (not Schema.CATEGORIES.has(category) or category in ["System","Troops"]): return {"ok":false,"message":"此分类不支持编号容量调整。"}
	if maximum + 1 < values.size():
		for id in range(maximum+1,values.size()):
			if values[id] != null and (not names or not str(values[id]).is_empty()): return {"ok":false,"message":"编号[%04d]仍有内容，不能缩小到%d。" % [id,maximum]}
		var setup: Variant = documents.read("data/test_setup.json")
		if setup is Dictionary:
			for entry in setup.get("definitions",{}).get(category,[]):
				if int(entry.get("id",0)) > maximum and int(entry.get("id",0)) < values.size(): return {"ok":false,"message":"缩容范围包含测试保留编号。"}
		var paths: Array = ["data/system.json"]
		var manifest: Variant = documents.read("data/manifest.json")
		if not manifest is Dictionary: return {"ok":false,"message":"无法核对工程引用，未执行缩容。"}
		for name in manifest.get("database",[]): paths.append("data/database/%s.json" % name)
		for name in manifest.get("maps",[]): paths.append("data/maps/%s.json" % name)
		for path in paths:
			var value: Variant = documents.read(path)
			if value == null: return {"ok":false,"message":"无法读取%s，未执行缩容。" % path}
			if _referenced(value,category,maximum): return {"ok":false,"message":"%s仍引用大于%d的%s编号，未执行缩容。" % [path,maximum,category]}
	var result = values.duplicate(true)
	var old_size = result.size()
	result.resize(maximum+1)
	if old_size == 0: result[0] = "" if names else null
	if names:
		for id in range(maxi(1,old_size),result.size()): result[id] = ""
	return {"ok":true,"value":result}

static func _referenced(value: Variant, category: String, maximum: int) -> bool:
	if value is Array:
		for child in value:
			if _referenced(child,category,maximum): return true
	elif value is Dictionary:
		var direct: Dictionary = Schema.REFERENCES.duplicate()
		direct.merge({"tileset_id":"Tilesets","switch_id":"switches","switch1_id":"switches","switch2_id":"switches","variable_id":"variables"},true)
		for key in value:
			if direct.get(key,"") == category and _above(value[key],maximum): return true
			if Schema.SETS.get(key,"") == category or key == "party_members" and category == "Actors":
				if value[key] is Array:
					for id in value[key]:
						if _above(id,maximum): return true
		if value.has("code") and value.get("parameters") is Array:
			var code = int(value.code); var p: Array = value.parameters
			if code in [27,28] and category == "switches" and not p.is_empty() and _above(p[0],maximum): return true
			if code >= 100:
				if Schema.Commands.Catalog.reason(code,p).is_empty():
					var hints = Presentation.parameter_hints(code,p)
					for key in hints:
						if hints[key].get("db","") == category:
							var index = str(key).to_int()
							if index < p.size() and _above(p[index],maximum): return true
				else:
					# Unknown instructions may reference IDs; refuse destructive guesses.
					for parameter in p:
						if _above(parameter,maximum): return true
				if code in [302,605] and p.size() >= 2:
					if {0:"Items",1:"Weapons",2:"Armors"}.get(int(p[0]),"") == category and _above(p[1],maximum): return true
		for child in value.values():
			if _referenced(child,category,maximum): return true
	return false

static func _above(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and float(value) > maximum

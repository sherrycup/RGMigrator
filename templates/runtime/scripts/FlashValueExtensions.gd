extends RefCounted
## 0019 Array/0021 Numeric extensions, expressed as native operations.
## No runtime Ruby eval. Existing literal clamp and arithmetic bwise patterns are mapped.
static func vector(left: Array,right: Variant,operation: String) -> Dictionary:
	var result: Array=[]
	for i in left.size():
		var a: Variant=left[i]; var b: Variant=right[i] if right is Array and i<right.size() else 1 if right is Array and operation=="*" else 0 if right is Array else right
		if not _number(a) or not _number(b): return {"ok":true,"value":left.duplicate()}
		if abs(float(a))>9007199254740991 or abs(float(b))>9007199254740991 or operation=="*" and abs(float(a)*float(b))>9007199254740991: return {"ok":false,"message":"向量运算超过JSON精确范围。"}
		if operation=="/" and b==0: return {"ok":true,"value":left.duplicate()}
		var value: Variant
		match operation:
			"+": value=a+b
			"-": value=a-b
			"*": value=a*b
			"/":
				if a is int and b is int:
					value=a/b
					if a%b!=0 and (a<0)!=(b<0): value-=1
				else: value=float(a)/float(b)
			_: return {"ok":false,"message":"向量运算未适配："+operation}
		if not is_finite(float(value)) or abs(float(value))>9007199254740991: return {"ok":false,"message":"向量运算超过JSON精确范围。"}
		result.append(value)
	return {"ok":true,"value":result}

static func bwise(values: Array,code: String) -> Dictionary:
	if code in ["[[@,0].max,100].min","[[@,-100].max,100].min"]:
		var result: Array=[]
		for value in values:
			if not _number(value): return {"ok":true,"value":values.duplicate()}
			result.append(min(max(value,-100 if code.contains("-100") else 0),100))
		return {"ok":true,"value":result}
	var pattern=RegEx.new(); pattern.compile("^([+*/-])([+-]?[0-9]+(?:\\.[0-9]+)?|\\(-1\\))$")
	var found=pattern.search(code)
	if found==null: return {"ok":false,"message":"Array.bwise的动态表达式没有GDScript映射："+code}
	var operand=found.get_string(2)
	return vector(values,float(operand) if operand.contains(".") else -1 if operand=="(-1)" else int(operand),found.get_string(1))

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

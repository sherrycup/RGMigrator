extends RefCounted
var ruby_hash=false
## Migration-time constant folding of data expressions; no file/API/game execution.
const Parser=preload("res://scripts/importer/RubyParser.gd")
var constants: Dictionary={}
var failure=""

func parse(source: String, origin: Dictionary={}) -> Dictionary:
	failure=""
	var parsed=Parser.new().parse(source,origin)
	if not parsed.ok: return {"ok":false,"diagnostics":parsed.diagnostics}
	if parsed.ast.body.size()!=1: return {"ok":false,"message":"数据值必须为一个表达式。","ast":parsed.ast}
	var value: Variant=expression(parsed.ast.body[0])
	return {"ok":failure.is_empty(),"value":value,"message":failure,"ast":parsed.ast}

func expression(n: Dictionary, locals: Dictionary={}) -> Variant:
	if not failure.is_empty(): return null
	match n.get("kind",""):
		"literal": return {"_decimal_integer":str(n.value)} if n.value is int and abs(float(n.value))>9007199254740991 else n.value
		"big_integer": return {"_decimal_integer":str(n.value)}
		"symbol": return str(n.value)
		"string":
			var s=""
			for p in n.parts:
				if p.kind!="text": return _fail("动态字符串插值不能静态折叠。")
				s+=str(p.value)
			return s
		"array":
			var result: Array=[]
			for e in n.elements: result.append(expression(e,locals))
			return result
		"hash":
			var result: Dictionary={}
			var typed={"__ruby_hash":{},"__keys":{}}; var types={}
			for pair in n.pairs:
				var key: Variant=expression(pair.key,locals)
				if not key is String and not key is int: return _fail("静态数据Hash键须为字符串或整数。")
				var value: Variant=expression(pair.value,locals)
				var encoded=str(typeof(key))+":"+JSON.stringify(key)
				typed.__ruby_hash[encoded]=value; typed.__keys[encoded]=key
				if not ruby_hash and types.has(str(key)) and types[str(key)]!=typeof(key): return _fail("此数据Hash键不能无损表示为JSON对象。")
				types[str(key)]=typeof(key); result[str(key)]=value
			return typed if ruby_hash else result
		"name":
			if locals.has(n.name): return locals[n.name]
			if constants.has(n.name): return constants[n.name]
			return _fail("依赖运行现场："+str(n.name))
		"unary":
			var value: Variant=expression(n.value,locals)
			if n.operator in ["!","not"]: return not _truth(value)
			if not value is int and not value is float: return _fail("静态数值一元运算要求数值。")
			return -value if n.operator=="-" else value if n.operator=="+" else _fail("该数据一元运算未支持。")
		"binary":
			var left: Variant=expression(n.left,locals)
			if n.operator in ["&&","and","||","or"]:
				return expression(n.right,locals) if _truth(left)==(n.operator in ["&&","and"]) else left
			var right: Variant=expression(n.right,locals)
			if n.operator=="+" and left is String and right is String: return left+right
			if n.operator in ["==","!="]: return left==right if n.operator=="==" else left!=right
			if not (left is int or left is float) or not (right is int or right is float): return _fail("静态运算需要数值。")
			if n.operator=="*" and abs(float(left)*float(right))>9007199254740991: return _fail("数据乘积超出JSON精确范围。")
			var result: Variant
			match n.operator:
				"+": result=left+right
				"-": result=left-right
				"*": result=left*right
				"/":
					if right==0: return _fail("除数为0。")
					result=_quotient(left,right) if left is int and right is int else float(left)/right
				"%":
					if right==0: return _fail("除数为0。")
					result=left-_quotient(left,right)*right if left is int and right is int else left-floor(float(left)/right)*right
				"<": return left<right
				">": return left>right
				"<=": return left<=right
				">=": return left>=right
				_: return _fail("该静态数据运算未支持："+str(n.operator))
			if not is_finite(float(result)) or abs(float(result))>9007199254740991: return _fail("数据算术超出JSON精确整数范围。")
			return result
		"range":
			var a: Variant=expression(n.left,locals); var b: Variant=expression(n.right,locals)
			if not a is int or not b is int: return _fail("数据范围要求整数。")
			return {"_integer_range":[a,b],"exclusive":n.operator=="..."}
	return _fail("表达式需要生成代码或后续适配："+str(n.get("kind","")))

func _fail(message: String) -> Variant:
	failure=message; return null

static func _truth(value: Variant) -> bool:
	return value!=null and (not value is bool or value)

static func _quotient(a: int,b: int) -> int:
	var quotient=a/b
	return quotient-1 if a%b!=0 and (a<0)!=(b<0) else quotient

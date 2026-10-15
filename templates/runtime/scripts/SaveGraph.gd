extends RefCounted
## Explicit data graph: JSON never receives a runtime object or a cyclic container.
const FORMAT="rgmigrator-object-graph"
const MAX_NODES=50000
const MAX_EDGES=500000
const MAX_DEPTH=128
var _originals: Array=[]
var _nodes: Array=[]
var _edges=0
var _error=""
var _identity: Dictionary={}
var _check_pending: Array=[]
var _object_classes: Variant=null

static func encode(value: Variant) -> Dictionary:
	var codec=new()
	var root=codec._encode(value,0)
	return {"ok":false,"message":codec._error} if not codec._error.is_empty() else {"ok":true,"value":{"format":FORMAT,"version":1,"root":root,"nodes":codec._nodes}}

static func reason(value: Variant,classes: Variant=null) -> String:
	var codec=new()
	codec._object_classes=classes
	codec._check(value,0)
	return codec._error

static func reason_cooperatively(value: Variant,pulse: Callable,classes: Variant=null) -> String:
	var codec=new(); codec._object_classes=classes; codec._begin_check(value,0)
	var batch=0
	while not codec._check_next():
		if batch==0:
			if not await pulse.call(): return "事件前记录已取消。"
			batch=32
		batch-=1
	return codec._error

func _check(value: Variant,depth: int) -> void:
	_begin_check(value,depth)
	while not _check_next(): pass

func _begin_check(value: Variant,depth: int) -> void:
	_check_pending=[[value,depth]]; _edges=1

func _check_next() -> bool:
	if _check_pending.is_empty() or not _error.is_empty(): return true
	var entry=_check_pending.pop_back(); var current: Variant=entry[0]; var level: int=entry[1]
	if not current is Array and not current is Dictionary:
		_scalar_valid(current); return _check_pending.is_empty() or not _error.is_empty()
	var signature=_shape(current)
	if _find(_identity,current,signature)>=0: return _check_pending.is_empty()
	if level>MAX_DEPTH or _originals.size()>=MAX_NODES: _error="对象图超过深度或节点预算。"; return true
	_remember(_identity,current,_originals.size(),signature); _originals.append(current)
	if _object_classes!=null and current is Dictionary and current.has("__ruby_class"):
		if not current.__ruby_class is String or not _object_classes.has(current.__ruby_class) or not current.get("fields") is Dictionary:
			_error="自定义对象的类或字段未绑定到已迁移定义。"; return true
	_edges+=current.size()*(2 if current is Dictionary else 1)
	if _edges>MAX_EDGES: _error="对象图超过元素预算。"; return true
	if current is Array:
		for i in range(current.size()-1,-1,-1):
			var child: Variant=current[i]
			if child is Array or child is Dictionary: _check_pending.append([child,level+1])
			elif typeof(child)>TYPE_STRING or child is float and not is_finite(child):
				if not _scalar_valid(child): return true
	else:
		var keys=current.keys()
		for i in range(keys.size()-1,-1,-1):
			var key: Variant=keys[i]; var child: Variant=current[key]
			if key is Array or key is Dictionary: _error="对象图字典键应为标量；Ruby组合键使用类型化Hash。"; return true
			if typeof(key)>TYPE_STRING or key is float and not is_finite(key):
				if not _scalar_valid(key): return true
			if child is Array or child is Dictionary: _check_pending.append([child,level+1])
			elif typeof(child)>TYPE_STRING or child is float and not is_finite(child):
				if not _scalar_valid(child): return true
	return _check_pending.is_empty()

func _scalar_valid(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME,TYPE_VECTOR2,TYPE_VECTOR2I,TYPE_VECTOR3,TYPE_VECTOR3I,TYPE_RECT2,TYPE_RECT2I,TYPE_COLOR: return true
		TYPE_FLOAT:
			if is_finite(value): return true
	_error="对象图包含不可保存的运行资源或非有限数值（类型%d）。" % typeof(value)
	return false

static func clone(value: Variant, graph: Array=[]) -> Variant:
	var index: Dictionary={}
	for i in graph.size(): _remember(index,graph[i][0],i)
	return _clone(value,graph,index)

static func clone_checked(value: Variant,graph: Array=[]) -> Dictionary:
	# Capture checks bounds/resources while detaching, avoiding a separate walk
	# of the live globals/custom graph immediately before this same traversal.
	var codec=new(); codec._edges=1
	for i in graph.size(): _remember(codec._identity,graph[i][0],i)
	var result=codec._clone_checked(value,graph,0)
	return {"ok":true,"value":result} if codec._error.is_empty() else {"ok":false,"message":codec._error}

func _clone_checked(value: Variant,graph: Array,depth: int) -> Variant:
	if not _error.is_empty(): return null
	if not value is Array and not value is Dictionary:
		return value if _scalar_valid(value) else null
	var signature=_shape(value); var found=_find(_identity,value,signature)
	if found>=0: return graph[found][1]
	if depth>MAX_DEPTH or graph.size()>=MAX_NODES: _error="对象图超过深度或节点预算。"; return null
	_edges+=value.size()*(2 if value is Dictionary else 1)
	if _edges>MAX_EDGES: _error="对象图超过元素预算。"; return null
	var result: Variant=[] if value is Array else {}
	result.assign(value); _remember(_identity,value,graph.size(),signature); graph.append([value,result])
	if value is Array:
		for i in value.size():
			var child: Variant=value[i]
			if child is Array or child is Dictionary: result[i]=_clone_checked(child,graph,depth+1)
			elif typeof(child)>TYPE_STRING or child is float and not is_finite(child):
				if not _scalar_valid(child): return null
	else:
		for key in value:
			if key is Array or key is Dictionary: _error="对象图字典键应为标量；Ruby组合键使用类型化Hash。"; return null
			if typeof(key)>TYPE_STRING or key is float and not is_finite(key):
				if not _scalar_valid(key): return null
			var child: Variant=value[key]
			if child is Array or child is Dictionary: result[key]=_clone_checked(child,graph,depth+1)
			elif typeof(child)>TYPE_STRING or child is float and not is_finite(child):
				if not _scalar_valid(child): return null
	return result

static func _clone(value: Variant,graph: Array,index: Dictionary) -> Variant:
	if not value is Array and not value is Dictionary: return value
	var signature=_shape(value)
	var found=_find(index,value,signature)
	if found>=0: return graph[found][1]
	var result: Variant=[] if value is Array else {}
	result.assign(value)
	_remember(index,value,graph.size(),signature)
	graph.append([value,result])
	if value is Array:
		for i in value.size():
			var child: Variant=value[i]
			if child is Array or child is Dictionary: result[i]=_clone(child,graph,index)
	else:
		for key in value:
			var child: Variant=value[key]
			if key is Array or key is Dictionary:
				result.erase(key); result[_clone(key,graph,index)]=_clone(child,graph,index)
			elif child is Array or child is Dictionary: result[key]=_clone(child,graph,index)
	return result

static func rebind(value: Variant,pairs: Array,seen: Array=[]) -> Variant:
	if pairs.is_empty(): return value
	var replacements: Dictionary={}; var visited: Dictionary={}
	for i in pairs.size(): _remember(replacements,pairs[i][0],i)
	for i in seen.size(): _remember(visited,seen[i],i)
	return _rebind(value,pairs,seen,replacements,visited)

static func _rebind(value: Variant,pairs: Array,seen: Array,replacements: Dictionary,visited: Dictionary) -> Variant:
	if not value is Array and not value is Dictionary: return value
	var signature=_shape(value)
	var replacement=_find(replacements,value,signature)
	if replacement>=0: value=pairs[replacement][1]
	if replacement>=0: signature=_shape(value)
	if _find(visited,value,signature)>=0: return value
	_remember(visited,value,seen.size(),signature)
	seen.append(value)
	if value is Array:
		for i in value.size():
			if value[i] is Array or value[i] is Dictionary: value[i]=_rebind(value[i],pairs,seen,replacements,visited)
	else:
		for key in value:
			if value[key] is Array or value[key] is Dictionary: value[key]=_rebind(value[key],pairs,seen,replacements,visited)
	return value

# Hash only immediate scalar members: recursive hashes cannot handle cycles.
# Buckets are a search accelerator; is_same remains the identity authority.
static func _shape(value: Variant) -> int:
	var signature=hash(value.size()) ^ typeof(value)
	if value is Array:
		for i in mini(value.size(),8):
			var child: Variant=value[i]
			signature=signature*31 ^ typeof(child)
			if not child is Array and not child is Dictionary: signature=signature ^ hash(child)
	else:
		var sampled=0
		for key in value:
			if sampled>=8: break
			sampled+=1; signature=signature*31
			if not key is Array and not key is Dictionary: signature=signature ^ hash(key)
			var child: Variant=value[key]
			if not child is Array and not child is Dictionary: signature=signature ^ hash(child)
	return signature

static func _find(index: Dictionary,value: Variant,signature: Variant=null) -> int:
	for entry in index.get(_shape(value) if signature==null else signature,[]):
		if is_same(entry[0],value): return entry[1]
	return -1

static func _remember(index: Dictionary,value: Variant,id: int,signature: Variant=null) -> void:
	var key=_shape(value) if signature==null else signature
	if not index.has(key): index[key]=[]
	index[key].append([value,id])

func _encode(value: Variant,depth: int) -> Variant:
	_edges+=1
	if _edges>MAX_EDGES: _error="对象图超过元素预算。"; return null
	if value is Array or value is Dictionary:
		var found=_find(_identity,value)
		if found>=0: return ["ref",found]
		if depth>MAX_DEPTH or _nodes.size()>=MAX_NODES: _error="对象图超过深度或节点预算。"; return null
		var id=_nodes.size(); var row={"kind":"array" if value is Array else "map","items":[]}
		_remember(_identity,value,id); _originals.append(value); _nodes.append(row)
		if value is Array:
			for child in value: row.items.append(_encode(child,depth+1))
		else:
			for key in value:
				if key is Array or key is Dictionary: _error="对象图字典键应为标量；Ruby组合键使用类型化Hash。"; return null
				row.items.append([_encode(key,depth+1),_encode(value[key],depth+1)])
		return ["ref",id]
	match typeof(value):
		TYPE_NIL: return ["nil"]
		TYPE_BOOL: return ["bool",value]
		TYPE_INT: return ["int",str(value)]
		TYPE_FLOAT:
			if is_finite(value): return ["float",value]
		TYPE_STRING,TYPE_STRING_NAME: return ["text",str(value)]
		TYPE_VECTOR2: return ["v2",value.x,value.y]
		TYPE_VECTOR2I: return ["v2i",value.x,value.y]
		TYPE_VECTOR3: return ["v3",value.x,value.y,value.z]
		TYPE_VECTOR3I: return ["v3i",value.x,value.y,value.z]
		TYPE_RECT2: return ["rect",value.position.x,value.position.y,value.size.x,value.size.y]
		TYPE_RECT2I: return ["recti",value.position.x,value.position.y,value.size.x,value.size.y]
		TYPE_COLOR: return ["color",value.r,value.g,value.b,value.a]
	_error="对象图包含不可保存的运行资源或非有限数值（类型%d）。" % typeof(value)
	return null

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format")!=FORMAT or value.get("version")!=1 or not value.get("nodes") is Array or value.nodes.size()>MAX_NODES: return _fail("对象图格式无效。")
	var containers: Array=[]; var edges=0
	for row in value.nodes:
		if not row is Dictionary or row.get("kind") not in ["array","map"] or not row.get("items") is Array: return _fail("对象图节点无效。")
		edges+=row.items.size()*(2 if row.kind=="map" else 1)
		if edges>MAX_EDGES: return _fail("对象图超过元素预算。")
		containers.append([] if row.kind=="array" else {})
	for i in value.nodes.size():
		var row: Dictionary=value.nodes[i]
		for item in row.items:
			if row.kind=="array":
				var parsed=_token(item,containers)
				if not parsed.ok: return parsed
				containers[i].append(parsed.value)
			else:
				if not item is Array or item.size()!=2: return _fail("对象图键值对无效。")
				var key=_token(item[0],containers); var child=_token(item[1],containers)
				if not key.ok: return key
				if not child.ok: return child
				if key.value is Array or key.value is Dictionary or containers[i].has(key.value): return _fail("对象图键类型无效或重复。")
				containers[i][key.value]=child.value
	return _token(value.get("root"),containers)

static func _token(token: Variant,containers: Array) -> Dictionary:
	if not token is Array or token.is_empty() or not token[0] is String: return _fail("对象图值无效。")
	var value: Variant
	match token[0]:
		"nil":
			if token.size()!=1: return _fail("空值无效。")
			value=null
		"ref":
			if token.size()!=2 or not _integer(token[1]) or token[1]<0 or token[1]>=containers.size(): return _fail("对象图引用越界。")
			value=containers[int(token[1])]
		"int":
			if token.size()!=2 or not token[1] is String or not token[1].is_valid_int() or str(int(token[1]))!=token[1]: return _fail("精确整数无效。")
			value=int(token[1])
		"bool":
			if token.size()!=2 or not token[1] is bool: return _fail("布尔值无效。")
			value=token[1]
		"text":
			if token.size()!=2 or not token[1] is String or token[1].length()>8*1024*1024: return _fail("文本无效。")
			value=token[1]
		"float":
			if token.size()!=2 or not _number(token[1]): return _fail("数值无效。")
			value=float(token[1])
		"v2","v2i","v3","v3i","rect","recti","color":
			var count=2 if token[0] in ["v2","v2i"] else 3 if token[0] in ["v3","v3i"] else 4
			if token.size()!=count+1: return _fail("图形数据长度无效。")
			for n in range(1,token.size()):
				if not _number(token[n]) or token[0].ends_with("i") and not _integer(token[n]): return _fail("图形数据无效。")
			match token[0]:
				"v2": value=Vector2(token[1],token[2])
				"v2i": value=Vector2i(int(token[1]),int(token[2]))
				"v3": value=Vector3(token[1],token[2],token[3])
				"v3i": value=Vector3i(int(token[1]),int(token[2]),int(token[3]))
				"rect": value=Rect2(token[1],token[2],token[3],token[4])
				"recti": value=Rect2i(int(token[1]),int(token[2]),int(token[3]),int(token[4]))
				"color": value=Color(token[1],token[2],token[3],token[4])
		_: return _fail("未知对象图值种类。")
	return {"ok":true,"value":value}

static func _number(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
static func _integer(value: Variant) -> bool: return _number(value) and floor(float(value))==float(value)
static func _fail(message: String) -> Dictionary: return {"ok":false,"message":message}

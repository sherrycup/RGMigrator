extends RefCounted
## AST-backed scopes and ordered definitions inspired by RM-sync's editor index.
## Alias binds at its declaration; method-body calls resolve after load ordering.
const FORMAT := "rgm-ruby-semantic-v2"
var _types := {}
var _latest := {}
var _definitions: Array = []
var _references: Array = []
var _scopes: Array = []
var _entry := {}
var _module_functions := {}
var _singleton_scopes := {}

func build(entries: Array) -> Dictionary:
	_types = {}; _latest = {}; _definitions = []; _references = []; _scopes = []
	_module_functions={}; _singleton_scopes={}
	for entry in entries:
		_entry = entry
		if entry.get("parsed",false): _walk(entry.ast.get("body",[]),"Object",entry.unit_id+":root",{})
	for reference in _references:
		if reference.kind=="call" and reference.receiver in ["","self"]:
			var target := _lookup(reference.owner,reference.name,reference.get("singleton",false))
			reference["definition"] = target.get("version_id","")
			reference["resolution"] = "unresolved" if target.is_empty() else ("ast_bound_generated" if target.status=="generated" else "ast_bound_dependency_not_generated")
	return {"format":FORMAT,"case_sensitive":true,"definition_policy":"all_versions_in_load_order; alias_captures_previous_version","types":_types,"scopes":_scopes,"definitions":_definitions,"references":_references,"limits":"动态接收者/反射未绑定；AST绑定不表示已加载或功能已验证。"}

func _walk(value: Variant, owner: String, scope: String, locals: Dictionary) -> void:
	if value is Array:
		for item in value: _walk(item,owner,scope,locals)
		return
	if not value is Dictionary or not value.has("kind"): return
	var node: Dictionary = value
	match node.kind:
		"class", "module":
			var name: String = node.name if owner=="Object" or node.name.contains("::") else owner+"::"+node.name
			if not _types.has(name): _types[name] = {"parent":node.parent,"kind":node.kind,"versions":[]}
			var declaration := _definition(node,name,name,"type",scope)
			_types[name].versions.append(declaration.version_id)
			_scopes.append({"id":declaration.version_id,"parent":scope,"kind":node.kind,"name":name,"span":node.span,"origin":_entry.origin})
			_walk(node.body,name,declaration.version_id,{})
		"method":
			var method_owner: String=_qualified_owner(node.receiver,owner) if node.receiver not in ["","self"] else owner
			var singleton: bool=not node.receiver.is_empty() or _singleton_scopes.get(scope,false)
			var key: String = method_owner+("." if singleton else "#")+node.name
			var declaration := _definition(node,method_owner,node.name,"method",scope); declaration["parameters"] = node.parameters; declaration["singleton"] = singleton
			_latest[key] = declaration
			_singleton_scopes[declaration.version_id]=singleton
			if not singleton and _module_functions.get(scope,false): _module_copy(node,method_owner,node.name,scope)
			var parameters := {}
			for parameter in node.parameters: parameters[parameter.name] = "parameter"
			_scopes.append({"id":declaration.version_id,"parent":scope,"kind":"method","owner":method_owner,"name":node.name,"singleton":singleton,"locals":parameters,"span":node.span,"origin":_entry.origin})
			_walk(node.body,method_owner,declaration.version_id,parameters)
		"singleton_class":
			var singleton_scope=scope+":singleton:%d:%d" % [node.span.line,node.span.column]
			_singleton_scopes[singleton_scope]=true
			_walk(node.body,owner,singleton_scope,{})
		"alias":
			var singleton: bool=_singleton_scopes.get(scope,false)
			var target := _lookup(owner,node.target,singleton); var declaration := _definition(node,owner,node.name,"alias",scope)
			declaration["singleton"]=singleton
			declaration["target_name"] = node.target; declaration["captured_version"] = target.get("captured_version",target.get("version_id",""))
			_latest[owner+("." if singleton else "#")+node.name] = declaration
		"assign":
			if node.left.kind=="name" and node.left.scope=="identifier": locals[node.left.name] = _type(node.right)
			_walk(node.left,owner,scope,locals); _walk(node.right,owner,scope,locals)
		"name":
			if node.name=="module_function": _module_functions[scope]=true
			_references.append({"kind":"name","name":node.name,"scope":scope,"owner":owner,"binding":"local" if locals.has(node.name) else node.scope,"inferred_type":locals.get(node.name,"Unknown"),"span":node.span,"origin":_entry.origin})
		"call":
			if node.receiver.is_empty() and node.name=="module_function":
				if node.arguments.is_empty(): _module_functions[scope]=true
				else:
					for argument in node.arguments:
						if argument.kind=="symbol": _module_copy(node,owner,argument.value,scope)
			_references.append({"kind":"call","name":node.name,"receiver":node.receiver.get("name","self" if node.receiver.get("kind")=="self" else ("" if node.receiver.is_empty() else "dynamic")),"scope":scope,"owner":owner,"singleton":_singleton_scopes.get(scope,false),"span":node.span,"origin":_entry.origin,"resolution":"dynamic_or_service_requires_adapter"})
			_walk(node.receiver,owner,scope,locals); _walk(node.arguments,owner,scope,locals)
			if not node.block.is_empty():
				var block_locals := locals.duplicate(); var block_scope := scope+":block:%d:%d" % [node.span.line,node.span.column]
				for parameter in node.block.parameters: block_locals[parameter] = "Unknown"
				_scopes.append({"id":block_scope,"parent":scope,"kind":"block","parameters":node.block.parameters,"span":node.block.span,"origin":_entry.origin})
				_walk(node.block.body,owner,block_scope,block_locals)
		_:
			for key in node:
				if key in ["span","origin"]: continue
				var child: Variant = node[key]
				if child is Array:
					for item in child:
						if item is Dictionary and not item.has("kind"):
							for field in item: _walk(item[field],owner,scope,locals)
						else: _walk(item,owner,scope,locals)
				elif child is Dictionary: _walk(child,owner,scope,locals)

func _definition(node: Dictionary, owner: String, name: String, kind: String, scope: String) -> Dictionary:
	var record := {"version_id":"%s:%d:%d:%s" % [_entry.unit_id,node.span.line,node.span.column,name],"unit_id":_entry.unit_id,"owner":owner,"name":name,"kind":kind,"scope":scope,"span":node.span,"origin":_entry.origin,"status":_entry.get("status","unsupported")}
	_definitions.append(record); return record

func _qualified_owner(receiver: String,owner: String) -> String:
	if receiver==owner or receiver==owner.get_slice("::",owner.get_slice_count("::")-1): return owner
	if _types.has(receiver) or not owner.contains("::"): return receiver
	var nested=owner.left(owner.rfind("::"))+"::"+receiver
	return nested if _types.has(nested) else receiver

func _module_copy(node: Dictionary,owner: String,name: String,scope: String) -> void:
	var source=_lookup(owner,name)
	if source.is_empty(): return
	var copied=_definition(node,owner,name,"module_function",scope)
	copied["version_id"]=copied.version_id+":module_function"
	copied["singleton"]=true; copied["captured_version"]=source.get("captured_version",source.version_id)
	copied["parameters"]=source.get("parameters",[])
	_latest[owner+"."+name]=copied

func _lookup(owner: String, name: String,singleton: bool=false) -> Dictionary:
	var visited := {}
	while not owner.is_empty() and not visited.has(owner):
		visited[owner] = true
		var key=owner+("." if singleton else "#")+name
		if _latest.has(key): return _latest[key]
		owner = _types.get(owner,{}).get("parent","")
	return {}

func _type(node: Dictionary) -> String:
	if node.kind=="literal":
		if node.value is int: return "Integer"
		if node.value is float: return "Float"
		if node.value is bool: return "Boolean"
		return "Nil"
	return {"array":"Array","hash":"Hash","string":"String","symbol":"Symbol"}.get(node.kind,"Unknown")

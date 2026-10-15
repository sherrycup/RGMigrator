@tool
extends RefCounted
## Keep parser, compiler, binding, service adaptation and behavior evidence separate.
static func build(root: String, registry: Dictionary, inventory: Dictionary, workspace: Dictionary) -> Dictionary:
	var lifecycle_path=root.path_join("migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.json")
	var lifecycle: Variant=JSON.parse_string(FileAccess.get_file_as_string(lifecycle_path)) if FileAccess.file_exists(lifecycle_path) else {}
	var services: Dictionary={}
	if lifecycle is Dictionary:
		for row in lifecycle.get("scripts",[]):
			if row is Dictionary: services[int(row.get("load_order",row.get("order",0)))]=row
	var rows: Array=[]; var counts={"units":0,"parsed":0,"generated":0,"bound":0,"empty":0,"excluded":0,"diagnostic_units":0,"changed":0,"manual_files":0}
	var syntax: Dictionary={}; var calls: Dictionary={}
	for id in registry.get("units",{}):
		var unit: Dictionary=registry.units[id]; var origin: Dictionary=unit.get("origin",{})
		var original_hash=workspace.get("original_hashes",{}).get(id,unit.get("source_sha256",""))
		var changed=original_hash!=unit.get("source_sha256","") or workspace.get("sources",{}).has(id)
		var service: Dictionary=services.get(int(origin.get("load_order",0)),{}) if origin.get("kind")=="script" else {}
		var row={"unit_id":id,"origin":origin,"parsed":unit.get("parsed",false),"status":unit.get("status","unsupported"),"generated":unit.get("generated",false),"bound":unit.get("event_integrated",false),"runtime_verified":unit.get("runtime_verified",false),"changed":changed,"diagnostics":unit.get("diagnostics",[]),"service_classification":service.get("classification",service.get("status","")),"service_paths":service.get("targets",[]),"generated_path":unit.get("generated_path","")}
		rows.append(row); counts.units+=1
		for key in ["parsed","generated","changed"]:
			if row[key]: counts[key]+=1
		if row.bound: counts.bound+=1
		if row.status=="empty": counts.empty+=1
		if row.status=="excluded_by_user": counts.excluded+=1
		if not row.diagnostics.is_empty(): counts.diagnostic_units+=1
		if unit.get("parsed",false):
			var ast: Dictionary=unit.get("ast",{})
			if ast.is_empty():
				var path=str(unit.get("ast_path","")).trim_prefix("res://")
				if path.begins_with("data/script_ast/") and not path.contains("..") and FileAccess.file_exists(root.path_join(path)):
					var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join(path)))
					if parsed is Dictionary: ast=parsed
			_nodes(ast,syntax)
		for call in unit.get("analysis",{}).get("calls",[]):
			var name=str(call.get("name","?"))
			if not calls.has(name): calls[name]=[]
			calls[name].append({"unit_id":id,"origin":origin,"line":call.get("line",1),"resolution":"lexical_candidate_not_behavior_proof"})
	var ownership: Array=[]
	for path in workspace.get("generated_hashes",{}):
		var manual=FileAccess.file_exists(root.path_join(path)) and FileAccess.get_sha256(root.path_join(path))!=workspace.generated_hashes[path]
		ownership.append({"path":path,"owner":"manual_changed" if manual else "generator","conflict":manual})
		if manual: counts.manual_files+=1
	return {"format":"rgm-script-coverage-v1","version":"ver0.48","counts":counts,"units":rows,"syntax_nodes":syntax,"api_candidates":calls,"ownership":ownership,"evidence_policy":"解析、生成、绑定与服务适配分别统计；用户修改后的代码需重新行为验证；不使用文件数推算游戏完成率。","source_boundaries":lifecycle.get("boundaries",[]) if lifecycle is Dictionary else []}

static func markdown(report: Dictionary) -> String:
	var c: Dictionary=report.counts
	var lines: Array[String]=["# 脚本迁移覆盖报告", "", report.evidence_policy,"", "单元 %d；AST %d；生成 %d；事件绑定 %d；空槽 %d；排除 %d；含诊断 %d；已修改 %d；手工文件 %d。" % [c.units,c.parsed,c.generated,c.bound,c.empty,c.excluded,c.diagnostic_units,c.changed,c.manual_files],"","| 单元 | 来源 | 转换 | 绑定 | 服务分类 |","| --- | --- | --- | --- | --- |"]
	for row in report.units:
		lines.append("| %s | %s | %s | %s | %s |" % [row.unit_id,JSON.stringify(row.origin).replace("|","\\|"),row.status,"是" if row.bound else "否",row.service_classification])
	lines.append_array(["","语法节点和API候选位置见 data/script_coverage.json。API候选不表示调用已实现，服务具体入口和原缺失依赖见 migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.md。"])
	return "\n".join(lines)+"\n"

static func _nodes(value: Variant, result: Dictionary) -> void:
	if value is Array:
		for entry in value: _nodes(entry,result)
	elif value is Dictionary:
		if value.has("kind"): result[value.kind]=int(result.get(value.kind,0))+1
		for key in value:
			if key!="origin": _nodes(value[key],result)

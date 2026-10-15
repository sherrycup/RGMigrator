@tool
extends RefCounted
const Transaction = preload("EditorProjectTransaction.gd")
const Coverage = preload("EditorScriptCoverage.gd")
const Adapter = preload("EditorScriptAdapter.gd")
signal changed
var _documents: RefCounted
var _root: String
var _registry: Dictionary={}
var _inventory: Dictionary={}
var _workspace: Dictionary={}
var _last_diagnostics: Array=[]
var _services: Dictionary={}

func _init(documents: RefCounted) -> void:
	_documents=documents; _root=ProjectSettings.globalize_path(documents._root).trim_suffix("/"); reload()

func reload() -> void:
	_registry=_json(_root.path_join("data/script_units.json"))
	_inventory=_json(_root.path_join("data/script_inventory.json"))
	_services.clear()
	for row in _json(_root.path_join("migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.json")).get("scripts",[]):
		if row is Dictionary: _services[int(row.get("load_order",0))]=row
	_workspace=_documents.read("data/script_workspace.json") if FileAccess.file_exists(_root.path_join("data/script_workspace.json")) else initial(_root,_registry)
	_last_diagnostics=[]; changed.emit()

static func initial(root: String, registry: Dictionary) -> Dictionary:
	var hashes: Dictionary={}; var source_hashes: Dictionary={}; var original_paths: Dictionary={}; var original_sources: Dictionary={}
	for id in registry.get("units",{}):
		var unit: Dictionary=registry.units[id]; source_hashes[id]=unit.get("source_sha256","")
		if unit.get("origin",{}).get("kind")=="script": original_paths[id]=unit.get("source_path","")
		else: original_sources[id]=unit.get("source","")
		var path=str(unit.get("generated_path","")).trim_prefix("res://")
		if path.begins_with("runtime/generated/") and FileAccess.file_exists(root.path_join(path)): hashes[path]=FileAccess.get_sha256(root.path_join(path))
	return {"format":"rgm-script-workspace-v1","sources":{},"display_names":{},"new_scripts":[],"generated_hashes":hashes,"original_hashes":source_hashes,"original_paths":original_paths,"original_sources":original_sources,"published_sources":{},"generation":0}

func entries() -> Array:
	var result: Array=[]
	for id in _registry.get("units",{}):
		var unit: Dictionary=_registry.units[id]
		result.append({"unit_id":id,"name":_workspace.get("display_names",{}).get(id,_title(id,unit.origin)),"origin":unit.origin,"status":unit.status,"service_classification":_services.get(int(unit.origin.get("load_order",0)),{}).get("classification","") if unit.origin.kind=="script" else "","editable":unit.origin.kind in ["map_event","common_event"] or unit.origin.kind=="script" and unit.status in ["generated","empty"],"changed":_workspace.get("sources",{}).has(id),"generated_path":unit.get("generated_path","")})
	for row in _workspace.get("new_scripts",[]):
		if not _registry.get("units",{}).has(row.unit_id): result.append({"unit_id":row.unit_id,"name":row.origin.name,"origin":row.origin,"status":"draft","editable":true,"changed":true,"generated_path":""})
	return result

func source(id: String, original: bool=false) -> String:
	if original and _workspace.get("original_hashes",{}).get(id,"missing")=="": return ""
	if original and _workspace.get("original_sources",{}).has(id): return str(_workspace.original_sources[id])
	if not original and _workspace.get("sources",{}).has(id): return str(_workspace.sources[id])
	var unit: Dictionary=_registry.get("units",{}).get(id,{})
	if unit.get("origin",{}).get("kind")=="script":
		var path=str(unit.get("source_path",""))
		if original: path=str(_workspace.get("original_paths",{}).get(id,path))
		return FileAccess.get_file_as_string(_root.path_join(path)) if _safe_source(path) and FileAccess.file_exists(_root.path_join(path)) else ""
	return str(unit.get("source",""))

func generated(id: String) -> String:
	var path=str(_registry.get("units",{}).get(id,{}).get("generated_path","")).trim_prefix("res://")
	return FileAccess.get_file_as_string(_root.path_join(path)) if path.begins_with("runtime/generated/") and not path.contains("..") else ""

func set_source(id: String, text: String) -> Dictionary:
	var row: Dictionary={}
	for entry in entries():
		if entry.unit_id==id: row=entry; break
	if row.is_empty() or not row.editable: return {"ok":false,"message":"该原脚本由专用GDScript/数据服务承担，原Ruby仅查看；请从覆盖报告打开实际实现。"}
	if text.length()>2000000: return {"ok":false,"message":"脚本超过编辑预算。"}
	_workspace.sources[id]=text
	return _apply()

func rename(id: String, name: String) -> Dictionary:
	if name.strip_edges().is_empty() or name.length()>200: return {"ok":false,"message":"名称须为1…200个字符。"}
	_workspace.display_names[id]=name.strip_edges(); return _apply()

func add_script(name: String="新脚本") -> Dictionary:
	var order=0
	for row in entries(): order=maxi(order,int(row.origin.get("load_order",0)))
	var id="user_script_%04d" % (order+1)
	_workspace.new_scripts.append({"unit_id":id,"origin":{"kind":"script","name":name,"script_id":id,"load_order":order+1,"source_file":"workspace"}})
	_workspace.sources[id]="# "+name+"\n"
	var result=_apply(); result["unit_id"]=id; return result

func save() -> Dictionary:
	return _documents.save_all()

func diagnostics(id: String) -> Array:
	var result: Array=_registry.get("units",{}).get(id,{}).get("diagnostics",[]).duplicate(true)
	for row in _last_diagnostics:
		if row.get("unit_id")==id: result.append(row)
	return result

func coverage() -> Dictionary:
	return Coverage.build(_root,_registry,_inventory,_workspace)

func mappings(id: String) -> Array:
	return _registry.get("units",{}).get(id,{}).get("source_map",[]).duplicate(true)

func recompile() -> Dictionary:
	_last_diagnostics=[]
	if not _documents.dirty_paths().is_empty(): return {"ok":false,"message":"请先保存地图、数据库和脚本草稿，再重新转换。"}
	if _registry.is_empty(): return {"ok":false,"message":"工程缺少脚本迁移登记。"}
	if not _workspace.get("sources") is Dictionary or not _workspace.get("new_scripts") is Array: return {"ok":false,"message":"脚本工作副本格式无效，请从备份恢复。"}
	for id in _registry.get("units",{}):
		if not str(id).is_valid_identifier() or str(id).length()>128: return {"ok":false,"message":"脚本单元编号无效。"}
	for row in _workspace.new_scripts:
		if not row is Dictionary or not str(row.get("unit_id","")).is_valid_identifier() or str(row.unit_id).length()>128: return {"ok":false,"message":"新增脚本编号无效。"}
	var compiler_path="res://addons/rgm_editor/compiler/ScriptMigrationInventory.gd"
	if not FileAccess.file_exists(compiler_path): return {"ok":false,"message":"工程缺少随附的转换器。"}
	var inventory_script: Script=load(compiler_path)
	if inventory_script==null or not inventory_script.can_instantiate(): return {"ok":false,"message":"转换器无法加载。"}
	var engine: RefCounted=inventory_script.new()
	var expected: Dictionary={}; var inputs: Dictionary={}; var scripts: Array[Dictionary]=[]
	_capture("data/script_workspace.json",expected)
	for path in ["data/script_units.json","data/script_inventory.json","data/custom_data.json","data/manifest.json","data/script_source_map.json","data/script_semantics.json","data/source_corrections.json"]:
		_capture(path,expected)
	var custom=_json(_root.path_join("data/custom_data.json")); inputs["data/custom_data.json"]=JSON.stringify(custom)
	var manifest=_json(_root.path_join("data/manifest.json"))
	for row in _inventory.get("scripts",[]):
		var id: String=row.unit_id; var unit: Dictionary=_registry.units.get(id,{})
		var path=str(unit.get("source_path",row.get("source_path","")))
		if not _safe_source(path): return {"ok":false,"message":"原脚本路径无效："+path}
		if not FileAccess.file_exists(_root.path_join(path)): return {"ok":false,"message":"脚本源码文件缺失，未发布："+path}
		if path.begins_with("data/script_sources/") and FileAccess.get_sha256(_root.path_join(path))!=unit.get("source_sha256"): return {"ok":false,"message":"已发布的工作源码被外部修改，请将修改复制到工作区后再转换："+path}
		_capture(path,expected)
		var text=source(id)
		if _workspace.sources.has(id) and unit.status not in ["generated","empty"]:
			return {"ok":false,"message":"服务适配脚本的Ruby工作副本不可发布："+id}
		var target="data/script_sources/"+id+".rb" if _workspace.sources.has(id) else path
		scripts.append({"unit_id":id,"source":text,"source_path":target,"origin":unit.origin.duplicate(true)})
	for row in _workspace.new_scripts:
		if not scripts.any(func(entry: Dictionary) -> bool: return entry.unit_id==row.unit_id): scripts.append({"unit_id":row.unit_id,"source":str(_workspace.sources.get(row.unit_id,"")),"source_path":"data/script_sources/"+row.unit_id+".rb","origin":row.origin})
	scripts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.origin.load_order)<int(b.origin.load_order))
	engine.configure_scripts(scripts)
	for name in manifest.get("maps",[]):
		if not str(name).is_valid_identifier(): return {"ok":false,"message":"地图文件编号无效。"}
		var path="data/maps/"+str(name)+".json"; _capture(path,expected)
		var map=_json(_root.path_join(path)); var restored=restore_map(map)
		if not restored.ok: return {"ok":false,"message":path+"："+restored.message}
		engine.collect_map(restored.value,str(name))
	var common_path="data/database/CommonEvents.json"; _capture(common_path,expected)
	var common: Variant=JSON.parse_string(FileAccess.get_file_as_string(_root.path_join(common_path)))
	if not common is Array: return {"ok":false,"message":"公共事件数据缺失或无效。"}
	var restored=restore_common(common)
	if not restored.ok: return restored
	engine.collect_common(restored.value)
	# Bind edits by existing unit identity. Changed editor command indices are
	# discovered again from the current documents, never from frozen RM data.
	var replaced_sources: Dictionary={}
	var used_ids: Dictionary={}; var serial=0; var adopted_sources: Dictionary={}
	for id in _registry.units:
		if str(id).begins_with("event_") and str(id).trim_prefix("event_").is_valid_int(): serial=maxi(serial,int(str(id).trim_prefix("event_")))
	for fragment in engine.fragments:
		var old_id=_matching_fragment(engine,fragment.origin,fragment.source)
		if used_ids.has(old_id): old_id=""
		var id=old_id
		if id.is_empty(): serial+=1; id="event_%06d" % serial
		used_ids[id]=true; fragment.unit_id=id
		if not old_id.is_empty() and _workspace.sources.has(old_id):
			var previous: Dictionary=_registry.units[old_id]; var working=str(_workspace.sources[old_id])
			if working.sha256_text()!=previous.source_sha256:
				if str(fragment.source).sha256_text()!=previous.source_sha256 and working!=fragment.source: return {"ok":false,"message":"工作区与事件编辑器同时修改了同一脚本，请先合并："+old_id}
				var replaced=_replace_fragment(engine,fragment,working)
				if not replaced.ok: return replaced
			else: adopted_sources[old_id]=fragment.source
			replaced_sources[old_id]=true
		var command=_fragment_command(engine,fragment.origin)
		command["_workspace_unit_id"]=id
	for id in _workspace.sources:
		if _registry.units.has(id) and _registry.units[id].origin.kind!="script" and not replaced_sources.has(id): return {"ok":false,"message":"事件脚本位置或内容已在地图/公共事件编辑器改变，请重新载入后编辑："+id}
	# Recollect after edits so source line/command indices and continuations agree.
	engine.fragments.clear(); engine.continuations.clear()
	for name in engine.raw_maps.duplicate(): engine.collect_map(engine.raw_maps[name],name)
	engine.collect_common(engine.raw_common.CommonEvents)
	var remapped: Dictionary={}
	for fragment in engine.fragments:
		var id=str(_fragment_command(engine,fragment.origin).get("_workspace_unit_id",""))
		if id.is_empty(): return {"ok":false,"message":"事件重新收集时缺少来源身份，未发布。"}
		remapped[fragment.unit_id]=id; fragment.unit_id=id
	for continuation in engine.continuations:
		var old_id=str(continuation.origin.get("retry_of","")); var new_id=str(remapped.get(old_id,old_id))
		continuation.unit_id=new_id+"_retry"; continuation.origin.retry_of=new_id
	_strip_markers(engine.raw_maps); _strip_markers(engine.raw_common)
	var stage=_root.path_join(".godot/rgm_editor/conversion/"+str(Time.get_ticks_usec()))
	for folder in ["data/maps","data/database","legacy/ruby_scripts"]:
		if DirAccess.make_dir_recursive_absolute(stage.path_join(folder))!=OK: return {"ok":false,"message":"无法建立转换暂存目录。"}
	for path in inputs:
		if not _write(stage.path_join(path),inputs[path]): return {"ok":false,"message":"无法建立转换暂存区。"}
	var result: Dictionary=engine.generate(stage,scripts)
	if not result.ok: return {"ok":false,"message":"转换产物生成失败。","errors":result.errors}
	var registry=_json(stage.path_join("data/script_units.json"))
	var old_generated: Dictionary={}
	for id in _registry.units:
		var old: Dictionary=_registry.units[id]
		if old.status=="generated": old_generated[id]=true
	for id in registry.units:
		var unit: Dictionary=registry.units[id]
		var previous: Dictionary=_registry.units.get(id,{})
		var unchanged_unsupported=not previous.is_empty() and previous.get("status")!="generated" and _location(previous.origin)==_location(unit.origin) and previous.get("source_sha256")==unit.get("source_sha256")
		var must_compile=old_generated.has(id) or _workspace.sources.has(id) or unit.origin.kind!="script" and not unchanged_unsupported
		if must_compile and unit.status not in ["generated","empty"]:
			for diagnostic in unit.get("diagnostics",[]): _last_diagnostics.append(diagnostic.merged({"unit_id":id,"origin":unit.origin}))
			if unit.get("diagnostics",[]).is_empty(): _last_diagnostics.append({"unit_id":id,"origin":unit.origin,"line":1,"column":1,"message":"脚本不可发布："+unit.status})
	if not _last_diagnostics.is_empty(): return {"ok":false,"message":"脚本转换失败，运行代码和事件绑定保持上次成功版本。","diagnostics":_last_diagnostics}
	var changes: Dictionary={}
	_collect_artifacts(stage,"data",changes); _collect_artifacts(stage,"runtime/generated",changes)
	changes["script_inventory.md"]=FileAccess.get_file_as_string(stage.path_join("script_inventory.md"))
	# The original mirror audit is provenance; working edits do not rewrite it.
	var inventory=_json(stage.path_join("data/script_inventory.json")); inventory.mirror_audit=_inventory.get("mirror_audit",{})
	changes["data/script_inventory.json"]=JSON.stringify(inventory,"\t",false)+"\n"
	var next: Dictionary=_workspace.duplicate(true)
	next.sources.merge(adopted_sources,true)
	if not next.has("original_paths"): next.original_paths={}
	for id in registry.units:
		if not next.original_hashes.has(id):
			next.original_hashes[id]=""
			if registry.units[id].origin.kind!="script": next.original_sources[id]=""
	for entry in scripts:
		if _registry.units.has(entry.unit_id) and not next.original_paths.has(entry.unit_id): next.original_paths[entry.unit_id]=_registry.units[entry.unit_id].get("source_path","")
		if entry.source_path.begins_with("data/script_sources/"): changes[entry.source_path]=entry.source
		next.published_sources[entry.unit_id]=entry.source.sha256_text()
	for path in changes:
		if not Transaction.allowed(path): return {"ok":false,"message":"转换产物超出允许范围："+path}
		if path.begins_with("runtime/generated/"):
			if FileAccess.file_exists(_root.path_join(path)) and (not next.generated_hashes.has(path) or FileAccess.get_sha256(_root.path_join(path))!=next.generated_hashes[path]): return {"ok":false,"message":"生成文件有手工修改，未覆盖："+path+"。请备份或在Godot中整理该文件后再转换。","path":path}
			var script=GDScript.new(); script.source_code=changes[path]
			if script.reload()!=OK: return {"ok":false,"message":"生成的GDScript编译失败，未发布："+path}
			next.generated_hashes[path]=str(changes[path]).sha256_text()
		if not expected.has(path): _capture(path,expected)
		if expected[path].exists and str(changes[path]).sha256_text()==expected[path].sha256: changes[path]=null
	for path in changes.keys():
		if changes[path]==null: changes.erase(path)
	next.generation=int(next.generation)+1
	# Sources are explicit working copies, even after publication; original paths
	# and hashes remain available for the immutable original view.
	changes["data/script_workspace.json"]=JSON.stringify(next,"\t",false)+"\n"
	var report=Coverage.build(_root,registry,inventory,next)
	# Hashes refer to the about-to-be-published files, not the previous generation.
	for row in report.ownership:
		if changes.has(row.path): row.owner="generator"; row.conflict=false
	report.counts.manual_files=report.ownership.filter(func(row: Dictionary) -> bool: return row.conflict).size()
	changes["data/script_coverage.json"]=JSON.stringify(report,"\t",false)+"\n"; changes["script_coverage.md"]=Coverage.markdown(report)
	for path in changes:
		if not expected.has(path): _capture(path,expected)
	# Input conflicts must be checked even if an unchanged input is not published.
	for path in expected:
		if Transaction.stamp(_root,path)!=expected[path]: return {"ok":false,"message":"转换期间输入文件改变，未发布："+path}
	result=Transaction.publish(_root,changes,expected)
	if result.ok:
		_documents.reload(); reload()
		result["summary"]=inventory.summary
	return result

static func restore_map(source_map: Dictionary) -> Dictionary:
	var map=source_map.duplicate(true)
	for event in map.get("events",{}).values():
		for page in event.get("pages",[]):
			var restored=_restore_list(page.get("list",[]))
			if not restored.ok: return restored
			page.list=restored.value
			var route=_restore_route(page.get("move_route",{}))
			if not route.ok: return route
			page.move_route=route.value
	return {"ok":true,"value":map}

static func restore_common(source_events: Array) -> Dictionary:
	var events=source_events.duplicate(true)
	for event in events:
		if event is Dictionary:
			var restored=_restore_list(event.get("list",[]))
			if not restored.ok: return restored
			event.list=restored.value
	return {"ok":true,"value":events}

static func _restore_list(commands: Array) -> Dictionary:
	var result: Array=[]; var index=0
	while index<commands.size():
		var command: Dictionary=commands[index].duplicate(true)
		if command.has("_editor_original"):
			var originals: Array=command._editor_original
			if originals.size()==1 and originals[0] is Dictionary and originals[0].has("list"):
				if command.parameters!=["自主移动路线中的Ruby暂未转换；原代码已保留。"]: return {"ok":false,"message":"自主路线源码占位已被编辑，请先恢复占位文字后转换。"}
				index+=1; continue
			var adapted: Array=Adapter._adapt_list(originals)
			if adapted.is_empty() or not _equivalent(adapted[0],command): return {"ok":false,"message":"Ruby占位已被编辑，无法安全恢复原指令；请先恢复占位再转换。"}
			if adapted.size()>1:
				if index+adapted.size()>commands.size() or not _equivalent(commands.slice(index,index+adapted.size()),adapted): return {"ok":false,"message":"保留路线与当前路线发生冲突，未覆盖编辑。"}
			result.append_array(originals.duplicate(true)); index+=adapted.size(); continue
		if command.has("_script_binding"): command["_workspace_unit_id"]=command._script_binding.get("unit_id","")
		command.erase("_script_binding")
		if int(command.get("code",0))==209 and command.get("parameters",[]).size()>1:
			var route=_restore_route(command.parameters[1])
			if not route.ok: return route
			command.parameters[1]=route.value
		result.append(command); index+=1
	return {"ok":true,"value":result}

static func _restore_route(route: Dictionary) -> Dictionary:
	var value=route.duplicate(true)
	if value.has("_editor_original_route"):
		var original: Dictionary=value._editor_original_route
		if not _equivalent(Adapter._adapt_route(original),value): return {"ok":false,"message":"保留的Ruby路线已有其它动作修改，未覆盖编辑。"}
		value=original.duplicate(true)
	value.erase("_script_runtime_route")
	for command in value.get("list",[]):
		if command.has("_script_binding"): command["_workspace_unit_id"]=command._script_binding.get("unit_id","")
		command.erase("_script_binding")
	return {"ok":true,"value":value}

func _matching_fragment(engine: RefCounted, origin: Dictionary, text: String) -> String:
	var marker=str(_fragment_command(engine,origin).get("_workspace_unit_id",""))
	if _registry.units.has(marker): return marker
	for id in _registry.units:
		var unit: Dictionary=_registry.units[id]
		if unit.origin.kind=="script": continue
		if _location(unit.origin)==_location(origin) and str(unit.get("source",""))==text: return id
	return ""

static func _fragment_command(engine: RefCounted, origin: Dictionary) -> Dictionary:
	var page: Dictionary={}; var commands: Array=[]
	if origin.kind=="map_event":
		page=engine.raw_maps[origin.map].events[str(int(origin.event_id))].pages[int(origin.page)-1]; commands=page.list
	elif origin.kind=="common_event": commands=engine.raw_common[origin.get("database","CommonEvents")][int(origin.common_event_id)].list
	if origin.has("route_index"):
		var route: Dictionary=page.get("move_route",{}) if origin.route_kind=="autonomous" else commands[int(origin.command_index)-1].parameters[1]
		return route.list[int(origin.route_index)-1]
	return commands[int(origin.command_index)-1]

static func _strip_markers(value: Variant) -> void:
	if value is Array:
		for entry in value: _strip_markers(entry)
	elif value is Dictionary:
		value.erase("_workspace_unit_id")
		for key in value: _strip_markers(value[key])

static func _location(origin: Dictionary) -> String:
	return "%s:%s:%s:%d:%d:%d:%s:%d" % [origin.get("kind",""),origin.get("database",""),origin.get("map",""),int(origin.get("event_id",origin.get("common_event_id",0))),int(origin.get("page",0)),int(origin.get("command_index",0)),origin.get("route_kind",""),int(origin.get("route_index",0))]

static func _replace_fragment(engine: RefCounted, fragment: Dictionary, text: String) -> Dictionary:
	var origin: Dictionary=fragment.origin; var page: Dictionary={}; var commands: Array=[]
	if origin.kind=="map_event":
		page=engine.raw_maps[origin.map].events[str(int(origin.event_id))].pages[int(origin.page)-1]; commands=page.list
	elif origin.kind=="common_event": commands=engine.raw_common[origin.get("database","CommonEvents")][int(origin.common_event_id)].list
	else: return {"ok":false,"message":"派生命令请修改对应原服务。"}
	if origin.has("route_index"):
		var route: Dictionary=page.get("move_route",{}) if origin.route_kind=="autonomous" else commands[int(origin.command_index)-1].parameters[1]
		route.list[int(origin.route_index)-1].parameters=[text]; return {"ok":true}
	var index=int(origin.command_index)-1
	if int(origin.command_code)==111: commands[index].parameters[1]=text; return {"ok":true}
	# Keep command slots stable for source mapping and already edited branches.
	var indices: Array=origin.get("source_command_indices",[index+1])
	commands[index].parameters=[text]
	for continuation in indices.slice(1): commands[int(continuation)-1].parameters=[""]
	return {"ok":true}

func _apply() -> Dictionary:
	var result=_documents.apply("data/script_workspace.json",_workspace,"编辑脚本工作副本")
	if result.ok: changed.emit()
	return result

func _capture(path: String, expected: Dictionary) -> void:
	if not expected.has(path): expected[path]=Transaction.stamp(_root,path)

static func _collect_artifacts(root: String, relative: String, changes: Dictionary) -> void:
	for name in DirAccess.get_files_at(root.path_join(relative)):
		var path=relative.path_join(name)
		if name.ends_with(".json") or name.ends_with(".gd"): changes[path]=FileAccess.get_file_as_string(root.path_join(path))
	for name in DirAccess.get_directories_at(root.path_join(relative)): _collect_artifacts(root,relative.path_join(name),changes)

static func _write(path: String, text: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return false
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(text); file.close(); return true

static func _json(path: String) -> Dictionary:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return value if value is Dictionary else {}

static func _safe_source(path: String) -> bool:
	return not path.contains("..") and not path.contains("\\") and not path.contains(":") and path.ends_with(".rb") and (path.begins_with("legacy/") or path.begins_with("data/script_sources/"))

static func _equivalent(left: Variant, right: Variant) -> bool:
	# JSON documents normalize integral floats; source-adapter constructors use ints.
	return JSON.parse_string(JSON.stringify(left))==JSON.parse_string(JSON.stringify(right))

static func _title(id: String, origin: Dictionary) -> String:
	if origin.kind=="script": return "%04d  %s" % [int(origin.load_order),origin.get("name",id)]
	if origin.kind=="map_event": return "%s · 事件%d · 页%d · 指令%d" % [origin.get("map",""),int(origin.get("event_id",0)),int(origin.get("page",0)),int(origin.get("command_index",0))]
	return "公共事件%d · 指令%d" % [int(origin.get("common_event_id",0)),int(origin.get("command_index",0))]

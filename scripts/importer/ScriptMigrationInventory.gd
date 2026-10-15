extends RefCounted
## Lexical dependency inventory is evidence, never a full Ruby semantic AST.
const SubsetCompiler = preload("res://scripts/importer/RubySubsetCompiler.gd")
const Compiler = preload("res://scripts/importer/RubyGDScriptCompiler.gd")
const Parser = preload("res://scripts/importer/RubyParser.gd")
const SemanticModel = preload("res://scripts/importer/RubySemanticModel.gd")
const Version = preload("res://scripts/Version.gd")
const Integrator = preload("res://scripts/importer/ScriptEventIntegrator.gd")
const FlashCorrections = preload("res://scripts/importer/FlashSourceCorrections.gd")
var raw_maps: Dictionary = {}
var raw_common: Dictionary = {}
var continuations: Array[Dictionary] = []
const FORMAT := "rgm-script-inventory-v1"
var fragments: Array[Dictionary] = []
var interpreter_policy: Dictionary = {"merge_adjacent_355": false, "false_result_waits": false, "evidence": {}}

func configure_scripts(scripts: Array[Dictionary]) -> void:
	# Bounded evidence for these RM Interpreter overrides; full method semantic
	# resolution is deliberately left to 0.41/0.42.
	var method := RegEx.new(); method.compile("(?m)^[ \\t]*def\\s+command_355\\b")
	var merge := RegEx.new(); merge.compile("@list\\s*\\[\\s*@index\\s*\\+\\s*1\\s*\\]\\s*\\.code\\s*==\\s*355\\b")
	for entry in scripts:
		var source: String = entry.source; var masked := _mask(source)
		for definition in method.search_all(masked):
			var tail := masked.substr(definition.get_start()); var next_method := RegEx.new(); next_method.compile("(?m)^\\s*def\\s+")
			var next_match := next_method.search(tail,definition.get_end()-definition.get_start())
			var body := tail.left(next_match.get_start()) if next_match != null else tail
			interpreter_policy = {"merge_adjacent_355": merge.search(body) != null, "false_result_waits": body.contains("result == false") and body.contains("return false"), "custom_binding": body.contains("__UBIND"), "evidence": entry.origin.merged(_position(masked,definition.get_start())), "status": "bounded_source_evidence_requires_semantic_review"}

func _source_frame_rate(scripts: Array[Dictionary]) -> int:
	var regex := RegEx.new(); regex.compile("(?:Graphics\\.frame_rate\\s*=\\s*|[\"\']frame_rate[\"\']\\s*=>\\s*)([0-9]+)")
	var rate := int(interpreter_policy.get("frame_rate",40))
	for entry in scripts:
		for match_value in regex.search_all(entry.source):
			var candidate := int(match_value.get_string(1))
			if candidate>=1 and candidate<=240: rate = candidate
	return rate

func collect_map(map: Dictionary, map_name: String) -> void:
	raw_maps[map_name] = map.duplicate(true)
	for event in map.get("events", {}).values():
		if not event is Dictionary: continue
		var pages: Array = event.get("pages", [])
		for index in pages.size():
			var origin := {"kind": "map_event", "map": map_name, "event_id": event.get("id", 0), "event_name": event.get("name", ""), "page": index+1}
			_collect_list(pages[index].get("list", []), origin)
			_collect_route(pages[index].get("move_route", {}), origin.merged({"command_index": 0, "route_kind": "autonomous"}))

func collect_common(events: Array, database: String = "CommonEvents") -> void:
	raw_common[database] = events.duplicate(true)
	for event in events:
		if event is Dictionary:
			_collect_list(event.get("list", []), {"kind": "common_event", "database":database,"common_event_id": event.get("id", 0), "event_name": event.get("name", ""), "page": 0})

func _collect_list(commands: Array, origin: Dictionary) -> void:
	var index := 0
	while index < commands.size():
		var command: Dictionary = commands[index]; var code := int(command.get("code", 0)); var p: Array = command.get("parameters", [])
		var location := origin.merged({"command_index": index+1, "command_code": code})
		if code in [355, 655]:
			var lines: Array[String] = []; var records: Array = []; var line_commands: Array = []
			lines.append(str(p[0]) if not p.is_empty() else ""); records.append(index+1)
			for source_line in lines[-1].split("\n"): line_commands.append(index+1)
			index += 1
			while index < commands.size() and (int(commands[index].get("code", 0)) == 655 or interpreter_policy.merge_adjacent_355 and int(commands[index].get("code", 0)) == 355):
				lines.append(str(commands[index].get("parameters", [""])[0])); records.append(index+1)
				for source_line in lines[-1].split("\n"): line_commands.append(index+1)
				index += 1
			location["source_command_indices"] = records
			location["source_line_commands"] = line_commands
			_add_fragment("\n".join(lines), location)
			if interpreter_policy.false_result_waits and records.size()>1 and int(commands[index-1].code)==355:
				continuations.append({"unit_id":fragments[-1].unit_id+"_retry","source":lines[-1],"origin":origin.merged({"command_index":index,"command_code":355,"source_command_indices":[index],"retry_of":fragments[-1].unit_id})})
			continue
		if code == 111 and p.size() > 1 and int(p[0]) == 12: _add_fragment(str(p[1]), location)
		if code == 209 and p.size() > 1: _collect_route(p[1], location.merged({"route_kind": "forced"}))
		index += 1

func _collect_route(route: Variant, origin: Dictionary) -> void:
	if not route is Dictionary: return
	var list: Array = route.get("list", [])
	for index in list.size():
		var p: Array = list[index].get("parameters", [])
		if int(list[index].get("code", 0)) == 45:
			_add_fragment(str(p[0]) if not p.is_empty() else "", origin.merged({"route_index": index+1, "route_code": 45}))

func _add_fragment(source: String, origin: Dictionary) -> void:
	fragments.append({"unit_id": "event_%06d" % (fragments.size()+1), "source": source, "origin": origin})

func generate(output_root: String, scripts: Array[Dictionary]) -> Dictionary:
	var errors: Array[String] = []; var units := {}; var records: Array = []; var providers := {}; var generated := 0
	var definitions: Array = []; var dependencies: Array = []; var parsed_count := 0
	var custom_profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output_root.path_join("data/custom_data.json"))) if FileAccess.file_exists(output_root.path_join("data/custom_data.json")) else {}
	DirAccess.make_dir_recursive_absolute(output_root.path_join("runtime/generated"))
	DirAccess.make_dir_recursive_absolute(output_root.path_join("data/script_ast"))
	interpreter_policy["frame_rate"] = _source_frame_rate(scripts)
	var all: Array = scripts.duplicate(true); all.append_array(fragments); all.append_array(continuations)
	if custom_profile.get("profile")=="flash":
		for script in scripts:
			if int(script.origin.load_order)==91 and str(script.source).contains('RPG::EventCommand.new(355, 0, ["_this.die"])'):
				var source_line=str(script.source).left(str(script.source).find('["_this.die"]')).count("\n")+1
				all.append({"unit_id":"derived_0091_door_die","source":"_this.die","origin":script.origin.merged({"kind":"derived_event_command","method":"Storage.open_door_list","source_line":source_line,"command_code":355},true)})
	var parsed_units := {}; var adapted_units := {}; var correction_records: Array=[]
	var known_methods: Array = []; var semantic_entries: Array = []; var source_mapping: Array = []
	for entry in all:
		var adapted=FlashCorrections.adapt(entry.source,entry.origin) if custom_profile.get("profile")=="flash" else {"source":entry.source,"corrections":[]}
		adapted_units[entry.unit_id]=adapted
		for correction in adapted.corrections: correction_records.append(correction.merged({"unit_id":entry.unit_id}))
		if custom_profile.get("profile")=="flash" and entry.origin.kind=="script":
			for correction in FlashCorrections.native_adaptations(entry.source,entry.origin): correction_records.append(correction.merged({"unit_id":entry.unit_id}))
		var parsed := Parser.new().parse(adapted.source,entry.origin)
		parsed_units[entry.unit_id] = parsed
		if parsed.ok: known_methods.append_array(Compiler.new().method_names(parsed.ast))
	for entry in all:
		var source: String = entry.source; var origin: Dictionary = entry.origin
		var analysis := _analyze(source, origin, entry.unit_id)
		var parsed: Dictionary = parsed_units[entry.unit_id]
		var compiled: Dictionary = SubsetCompiler.new().compile(source,origin) if Version.VERSION=="ver0.41" else Compiler.new().compile_ast(parsed.ast,"res://runtime/generated/%s.gd" % entry.unit_id,known_methods) if parsed.ok else {"ok":false,"diagnostics":parsed.diagnostics}
		# Conditions require a boolean expression; routes may have custom context.
		# Only plain 355/655 programs and script-list units are proof candidates.
		var eligible: bool = origin.kind == "script" or origin.get("command_code", 0) in [355,111] or origin.get("route_code",0)==45
		var status := "unsupported" if not compiled.ok else ("empty" if compiled.empty and origin.kind=="script" else ("generated" if eligible else "deferred_context"))
		if custom_profile.get("profile")=="flash" and origin.kind=="script" and int(origin.get("load_order",0))>=274 and int(origin.get("load_order",0))<=308 and status!="empty": status="excluded_by_user"
		var unit := {"origin": origin, "status": status, "treatment": "auto_translated" if status == "generated" else "requires_further_translation", "compiled_supported_semantics": compiled.ok, "generated": status == "generated", "event_integrated": false, "runtime_verified": false, "source_sha256": source.sha256_text(), "diagnostics": compiled.diagnostics, "analysis": analysis}
		unit["definitions"] = Integrator.definitions(parsed.ast.get("body",[])) if parsed.ok else _unparsed_definitions(analysis,source)
		# Complete AST declarations retain their actual owners even if a body or
		# initialization is unsupported. A lexical '*' must not erase that evidence.
		unit["parsed"] = parsed.ok; unit["parse_diagnostics"] = parsed.diagnostics
		unit["source_corrections"]=adapted_units[entry.unit_id].corrections
		unit["adapted_source_sha256"]=str(adapted_units[entry.unit_id].source).sha256_text()
		if status=="excluded_by_user": unit.treatment="excluded_by_user"
		unit["compiler_format"] = SubsetCompiler.FORMAT if Version.VERSION=="ver0.41" else Compiler.FORMAT
		semantic_entries.append({"unit_id":entry.unit_id,"origin":origin,"parsed":parsed.ok,"ast":parsed.ast,"status":status})
		if parsed.ok:
			parsed_count += 1
			var ast_path := "data/script_ast/%s.json" % entry.unit_id
			_write(output_root.path_join(ast_path), JSON.stringify(parsed.ast,"",false)+"\n",errors)
			unit["ast_path"] = "res://"+ast_path
		if not compiled.diagnostics.is_empty() and origin.has("source_line_commands"):
			for diagnostic in unit.diagnostics:
				var source_line := int(diagnostic.line)-1
				if source_line >= 0 and source_line < origin.source_line_commands.size(): diagnostic["command_index"] = origin.source_line_commands[source_line]
		if status == "generated":
			var path := "runtime/generated/%s.gd" % entry.unit_id
			if _write(output_root.path_join(path), compiled.generated_source, errors): generated += 1
			unit["generated_path"] = "res://" + path; unit["ast"] = compiled.ast; unit["ir"] = compiled.ir
			unit["source_map"] = compiled.get("source_map",[])
			for mapping in compiled.get("source_map",[]): source_mapping.append(mapping.merged({"unit_id":entry.unit_id,"generated_path":"res://"+path,"source_path":entry.get("source_path","")}))
		if origin.kind != "script": unit["source"] = source
		else: unit["source_path"] = entry.get("source_path", "")
		units[entry.unit_id] = unit
		var record: Dictionary = entry.duplicate(true); record.erase("source"); record["status"] = status; record["analysis"] = analysis
		records.append(record)
		for definition in analysis.definitions:
			definitions.append(definition)
			if not providers.has(definition.name): providers[definition.name] = []
			providers[definition.name].append(definition)
	for unit_id in units:
		for call in units[unit_id].analysis.calls:
			dependencies.append({"from": unit_id, "call": call, "candidate_definitions": providers.get(call.name, []), "resolution": "lexical_candidates_only"})
	var integration_common: Dictionary=raw_common.duplicate(true)
	if custom_profile.get("profile")=="flash":
		for database in integration_common:
			for event in integration_common[database]:
				if event is Dictionary: correction_records.append_array(FlashCorrections.adapt_commands(event.get("list",[]),{"kind":"common_event","database":database,"common_event_id":event.id}))
	var integrated := Integrator.integrate(output_root,raw_maps,integration_common,units,errors) if Version.VERSION not in ["ver0.40","ver0.41","ver0.42"] else 0
	if custom_profile.get("profile")=="flash": _flash_door_macro(output_root,units,errors)
	var mirror := _audit_mirror(output_root, scripts)
	_write(output_root.path_join("data/script_semantics.json"),JSON.stringify(SemanticModel.new().build(semantic_entries),"",false)+"\n",errors)
	_write(output_root.path_join("data/script_source_map.json"),JSON.stringify({"format":Compiler.FORMAT,"entries":source_mapping},"\t",false)+"\n",errors)
	_write(output_root.path_join("data/source_corrections.json"),JSON.stringify({"format":"rgm-source-corrections-v1","policy":"correct_obvious_errors_preserve_balance_formulas","entries":correction_records},"\t",false)+"\n",errors)
	var inventory := {"format": FORMAT, "tool_stage": Version.VERSION, "source_policy": "Scripts.rxdata列表是加载顺序依据；Scripts镜像只读比较并保留，不静默覆盖", "interpreter_policy": interpreter_policy, "analysis_kind": "lexical_evidence_not_semantic_resolution", "scripts": records.filter(func(r: Dictionary) -> bool: return r.origin.kind == "script"), "fragments": records.filter(func(r: Dictionary) -> bool: return r.origin.kind not in ["script","derived_event_command"]), "derived_commands":records.filter(func(r: Dictionary) -> bool:return r.origin.kind=="derived_event_command"), "definitions_in_load_order": definitions, "dependencies": dependencies, "mirror_audit": mirror, "summary": {"scripts": scripts.size(), "fragments": fragments.size(), "generated_units": generated, "parsed_units": parsed_count, "event_integrated_units": integrated, "retry_units": continuations.size(), "definitions": definitions.size(), "dependency_candidates": dependencies.size()}}
	_write(output_root.path_join("data/script_inventory.json"), JSON.stringify(inventory, "\t", false)+"\n", errors)
	_write(output_root.path_join("data/script_units.json"), JSON.stringify({"format": SubsetCompiler.FORMAT if Version.VERSION=="ver0.41" else Compiler.FORMAT, "interpreter_policy":interpreter_policy, "units": units}, "\t", false)+"\n", errors)
	_write(output_root.path_join("script_inventory.md"), _markdown(inventory, units), errors)
	return {"ok": errors.is_empty(), "errors": errors, "summary": inventory.summary, "mirror_audit": mirror}

func _flash_door_macro(root: String,units: Dictionary,errors: Array[String]) -> void:
	var path=root.path_join("data/flash_gameplay.json")
	if not FileAccess.file_exists(path) or not units.has("derived_0091_door_die"): return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var common: Array=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/database/CommonEvents.json")))
	var id=int(data.constants.get("OPEN_DOOR_COMMONEVENT_ID",4))
	if id<=0 or id>=common.size() or not common[id] is Dictionary: errors.append("开门宏缺少源公共事件。"); return
	var commands: Array=[]; var started=false; var base_indent=0
	for command in common[id].list:
		if int(command.code)==118 and not command.parameters.is_empty() and str(command.parameters[0]).contains("<门的事件动画>"):
			started=true; base_indent=int(command.indent); continue
		if not started: continue # source incorrectly returned before reaching the label
		if int(command.code)==118 or int(command.indent)<base_indent: break
		var copy: Dictionary=command.duplicate(true); copy.indent=int(copy.indent)-base_indent; commands.append(copy)
	if not started: errors.append("开门宏缺少原动画标签。"); return
	var unit: Dictionary=units.derived_0091_door_die
	if unit.status!="generated": errors.append("开门宏尾部脚本未生成。"); return
	commands.append({"code":355,"indent":0,"parameters":["_this.die"],"_script_binding":{"unit_id":"derived_0091_door_die","source_sha256":unit.source_sha256,"command_count":1}})
	commands.append({"code":0,"indent":0,"parameters":[]})
	data.storage["open_door_list"]=commands
	_write(path,JSON.stringify(data,"\t",false),errors)

func _unparsed_definitions(analysis: Dictionary, source: String) -> Dictionary:
	# Failed AST providers must not silently disappear from override resolution.
	var result := {"safe":false,"types":[],"methods":[],"constants":[]}
	for definition in analysis.definitions:
		if definition.kind in ["class","module"]: result.types.append(definition.name)
	for definition in analysis.definitions:
		if definition.kind=="method": result.methods.append({"name":str(definition.name).trim_prefix("self."),"owner":"*","owner_candidates":result.types.duplicate(),"singleton":str(definition.name).begins_with("self.")})
	var matcher := RegEx.new(); matcher.compile("(?m)^\\s*([A-Z][A-Za-z0-9_:]*)\\s*=(?!=)")
	for match_value in matcher.search_all(_mask(source)): result.constants.append(match_value.get_string(1))
	return result

func _analyze(source: String, origin: Dictionary, unit_id: String) -> Dictionary:
	var masked := _mask(source.replace("\r\n", "\n")); var definitions: Array = []; var calls: Array = []; var globals: Array = []; var features: Array = []
	var patterns := {"class": "(?m)^\\s*class\\s+([\\p{L}_][\\p{L}\\p{N}_:]*)", "module": "(?m)^\\s*module\\s+([\\p{L}_][\\p{L}\\p{N}_:]*)", "method": "(?m)^\\s*def\\s+((?:self\\.)?(?:[\\p{L}_][\\p{L}\\p{N}_!?=]*|\\[\\]=?|<=>|===?|[!~+*/%<>-]=?))", "alias": "(?m)^\\s*alias\\s+:?([\\p{L}_][\\p{L}\\p{N}_!?=]*)\\s+:?([\\p{L}_][\\p{L}\\p{N}_!?=]*)"}
	for kind in patterns:
		var regex := RegEx.new(); regex.compile(patterns[kind])
		for match_value in regex.search_all(masked):
			var position := _position(masked, match_value.get_start(1))
			definitions.append({"kind": kind, "name": match_value.get_string(1), "alias_target": match_value.get_string(2) if kind == "alias" else "", "unit_id": unit_id, "version_id": "%s:%d:%d" % [unit_id,position.line,position.column], "origin": origin, "line": position.line, "column": position.column})
	definitions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.line < b.line or a.line == b.line and a.column < b.column)
	var regex := RegEx.new(); regex.compile("(\\$[\\p{L}_][\\p{L}\\p{N}_]*|[A-Z][\\p{L}\\p{N}_:]*)\\s*\\.\\s*([\\p{L}_][\\p{L}\\p{N}_!?]*)|\\b([a-z_\\p{Han}][\\p{L}\\p{N}_!?]*)\\s*\\(")
	for match_value in regex.search_all(masked):
		var receiver := match_value.get_string(1); var name := match_value.get_string(2) if not receiver.is_empty() else match_value.get_string(3)
		var position := _position(masked, match_value.get_start())
		if definitions.any(func(d: Dictionary) -> bool: return d.kind == "method" and d.line == position.line): continue
		calls.append(position.merged({"receiver": receiver, "name": name}))
	regex.compile("\\$[\\p{L}_][\\p{L}\\p{N}_]*")
	for match_value in regex.search_all(masked):
		globals.append(_position(masked,match_value.get_start()).merged({"name": match_value.get_string()}))
	var signals := {"dynamic_eval": "\\beval\\b", "native_api": "\\b(?:Win32API|DL|Fiddle)\\b", "reflection": "\\b(?:send|__send__|method_missing|define_method|const_get)\\b", "alias": "\\balias(?:_method)?\\b", "custom_troop": "\\bGame_Troop\\b|\\$game_troop", "currency": "\\b(?:gain_currency|currency|gold|money)\\b", "gameplay": "\\b(?:battle|damage|attack|enemy|reward)[A-Za-z0-9_]*", "display": "\\b(?:Window_[A-Za-z0-9_]+|Scene_[A-Za-z0-9_]+|Bitmap|Sprite)\\b", "save": "\\b(?:Marshal|save_data|load_data|write_save_data|read_save_data)\\b"}
	for feature in signals:
		regex.compile(signals[feature])
		for match_value in regex.search_all(masked): features.append(_position(masked,match_value.get_start()).merged({"feature": feature, "token": match_value.get_string()}))
	return {"definitions": definitions, "calls": calls, "globals": globals, "features": features, "limits": "词法候选；未解析完整作用域、正则/heredoc、动态分派、alias绑定或可达性，不代表功能已迁移"}

func _position(source: String, offset: int) -> Dictionary:
	var before := source.left(offset); return {"line": before.count("\n")+1, "column": offset-before.rfind("\n")}

func _mask(source: String) -> String:
	var result := ""; var quote := ""; var escaped := false; var block_comment := false
	for line in source.split("\n"):
		if quote.is_empty() and line.begins_with("=begin"): block_comment = true
		if block_comment:
			result += " ".repeat(line.length()) + "\n"
			if line.begins_with("=end"): block_comment = false
			continue
		var comment := false
		for c in line:
			if comment: result += " "; continue
			if not quote.is_empty():
				result += " "
				if escaped: escaped = false
				elif c == "\\": escaped = true
				elif c == quote: quote = ""
			elif c == "#": comment = true; result += " "
			elif c in ["'", "\""]: quote = c; result += " "
			else: result += c
		result += "\n"
	return result.trim_suffix("\n")

func _audit_mirror(output_root: String, scripts: Array[Dictionary]) -> Dictionary:
	var files: Array[String] = []; _ruby_files(output_root.path_join("legacy/ruby_scripts"), files)
	var by_order := {}; var matched := 0; var differences: Array = []; var unmatched: Array = []
	for file in files:
		var prefix := file.get_file().get_slice("_",0)
		if prefix.is_valid_int():
			var order := int(prefix)
			if not by_order.has(order): by_order[order] = []
			by_order[order].append(file)
		else: unmatched.append(file.trim_prefix(output_root+"/"))
	for entry in scripts:
		var candidates: Array = by_order.get(int(entry.origin.load_order), [])
		if candidates.size() != 1: continue
		var text := FileAccess.get_file_as_string(candidates[0]).replace("\r\n", "\n")
		if text == str(entry.source).replace("\r\n", "\n"): matched += 1
		else: differences.append({"load_order": entry.origin.load_order, "name": entry.origin.name, "mirror_path": candidates[0].trim_prefix(output_root+"/"), "rxdata_sha256": str(entry.source).sha256_text(), "mirror_sha256": text.sha256_text(), "mirror_analysis": _analyze(text,entry.origin.merged({"kind":"mirror_reference"},true),"mirror_%04d" % entry.origin.load_order)})
	return {"ruby_files": files.size(), "matching": matched, "differences": differences, "unmatched_files": unmatched, "note": "镜像匹配仅按编号候选；不推断未匹配文件的实际加载顺序"}

func _ruby_files(root: String, files: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(root): return
	for file in DirAccess.get_files_at(root):
		if file.ends_with(".rb"): files.append(root.path_join(file))
	for directory in DirAccess.get_directories_at(root): _ruby_files(root.path_join(directory), files)

func _write(path: String, content: String, errors: Array[String]) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: errors.append("无法写入脚本迁移产物："+path); return false
	file.store_string(content); var ok := file.get_error() == OK; file.close()
	if not ok: errors.append("脚本迁移产物写入不完整："+path)
	return ok

func _markdown(inventory: Dictionary, units: Dictionary) -> String:
	var lines: Array[String] = ["# "+Version.VERSION+" 脚本盘点", "", "加载顺序来自 Data/Scripts.rxdata；Ruby不执行。词法依赖只提供候选位置，尚未完成语义绑定或游戏功能接入。", "", "脚本 %d；事件片段 %d；生成单元 %d；事件入口绑定 %d（生成和绑定不表示其全部依赖可运行）。" % [inventory.summary.scripts,inventory.summary.fragments,inventory.summary.generated_units,inventory.summary.event_integrated_units], "", "完整AST成功解析 %d 个单元；节点文件见 data/script_ast/。解析不表示可生成或可运行。" % inventory.summary.parsed_units, "", "## 脚本加载顺序", "", "| 顺序 / 原ID | 名称 | 源文件 | 状态 |", "| --- | --- | --- | --- |"]
	for record in inventory.scripts:
		lines.append("| %d / %s | %s | `%s` | %s |" % [record.origin.load_order,str(record.origin.script_id),str(record.origin.name).replace("|","\\|"),record.source_path,record.status])
	lines.append_array(["", "## 事件入口与诊断", "", "355/655、111脚本条件和路线45按已生成单元绑定；未转换的条件仍保留整段分支，未转换路线整体预检失败。原工程Interpreter覆盖证据："+JSON.stringify(inventory.interpreter_policy), "", "| 单元 | 原位置 | 源码首行 | 状态 / 首个诊断 |", "| --- | --- | --- | --- |"])
	for record in inventory.fragments:
		var unit: Dictionary = units[record.unit_id]; var diagnostic := ""
		if not unit.diagnostics.is_empty():
			var d: Dictionary = unit.diagnostics[0]; diagnostic = " L%d:C%d %s" % [d.line,d.column,d.message]
		lines.append("| %s | %s | `%s` | %s%s |" % [record.unit_id,JSON.stringify(record.origin).replace("|","\\|"),str(unit.source).get_slice("\n",0).replace("|","\\|").replace("`","'"),record.status,diagnostic])
	lines.append_array(["", "## 依赖与扩展功能证据", "", "AST作用域、各次方法定义和alias捕获版本见 data/script_semantics.json；原文到生成文件/函数/行号见 data/script_source_map.json。词法候选见 data/script_inventory.json。以下按功能词汇提供追溯入口；是否实际使用及等价适配由后续阶段确认。"])
	for record in inventory.scripts + inventory.fragments:
		var grouped := {}
		for feature in record.analysis.features:
			if not grouped.has(feature.feature): grouped[feature.feature] = []
			grouped[feature.feature].append("%s@%d:%d" % [feature.token,feature.line,feature.column])
		if not grouped.is_empty(): lines.append("- `%s` %s：%s" % [record.unit_id,JSON.stringify(record.origin),JSON.stringify(grouped)])
	lines.append_array(["", "## 镜像核对", "", JSON.stringify(inventory.mirror_audit, "\t", false), "", "生成仅代表已支持语义编译通过，运行验证记录单独保存在验证报告中。未支持源码完整保留，首个不支持的词或语法给出原位置与行列。"])
	return "\n".join(lines)+"\n"

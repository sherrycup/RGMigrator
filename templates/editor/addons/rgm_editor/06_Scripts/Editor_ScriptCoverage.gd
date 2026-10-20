## 职责：组织脚本解析、生成、绑定和服务适配的覆盖信息，提供工作区展示数据。
##
## 调用方式：
##   静态接口：preload("res://addons/rgm_editor/06_Scripts/Editor_ScriptCoverage.gd").方法名(...)。
##
## 调用接口：
##   static func audit_services(root: String, registry: Dictionary) -> Dictionary
##     用途：读取当前来源/目标审计并逐文件检查内容；未提供审计时返回空字典供历史工程沿用旧记录。
##     参数 root（String；必填）：数据根、节点根或工程根位置。
##     参数 registry（Dictionary；必填）：类、方法、技能或绑定的登记表。
##     返回：原加载序号到审计记录；current为false表示来源或实现已变更，不能继续沿用验证状态。
##
##   static func build( root: String, registry: Dictionary, inventory: Dictionary, workspace: Dictionary ) -> Dictionary
##     用途：构造该模块所需的数据或显示对象。
##     参数 root（String；必填）：数据根、节点根或工程根位置。
##     参数 registry（Dictionary；必填）：类、方法、技能或绑定的登记表。
##     参数 inventory（Dictionary；必填）：脚本迁移盘点或背包数据，类型见签名。
##     参数 workspace（Dictionary；必填）：脚本工作副本与覆盖登记数据。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func markdown(report: Dictionary) -> String
##     参数 report（Dictionary；必填）：需要显示或写出的迁移报告。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 接口说明结束。

@tool
extends RefCounted


static func audit_services(root: String, registry: Dictionary) -> Dictionary:
	var path = root.path_join("data/migration_audit.json")
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("format") != "rgm-migration-audit-v1":
		return {}
	var framework_current = true
	for snapshot in [value.get("runtime_snapshot", {}), value.get("generated_snapshot", {})]:
		for relative in snapshot:
			var valid = (
				(
					str(relative).begins_with("runtime/scripts/")
					or str(relative).begins_with("runtime/generated/")
				)
				and not str(relative).contains("..")
			)
			framework_current = (
				framework_current
				and valid
				and FileAccess.file_exists(root.path_join(relative))
				and FileAccess.get_sha256(root.path_join(relative)) == snapshot[relative]
			)
	var current_targets: Dictionary = {}
	for name in value.get("implementations", {}):
		var target: Dictionary = value.implementations[name]
		var relative = str(target.get("path", ""))
		if relative.begins_with("runtime/scripts/") and not relative.contains(".."):
			current_targets[relative] = (
				FileAccess.file_exists(root.path_join(relative))
				and FileAccess.get_sha256(root.path_join(relative)) == target.get("sha256", "")
			)
	var methods: Dictionary = {}
	for method in value.get("methods", []):
		var id = str(method.get("unit_id", ""))
		if not methods.has(id):
			methods[id] = []
		methods[id].append(method)
	var result: Dictionary = {}
	for record in value.get("scripts", []):
		var row: Dictionary = record.duplicate()
		var source = str(row.get("source_path", ""))
		var unit: Dictionary = registry.get("units", {}).get(row.get("unit_id", ""), {})
		var current = (
			source.begins_with("legacy/ordered_scripts/")
			and not source.contains("..")
			and unit.get("source_sha256", "") == row.get("sha256", "")
			and FileAccess.file_exists(root.path_join(source))
			and FileAccess.get_sha256(root.path_join(source)) == row.get("sha256", "")
		)
		for target in row.get("targets", []):
			current = current and current_targets.get(str(target), false)
		if not row.get("targets", []).is_empty():
			current = current and framework_current
		row["current"] = current
		row["methods"] = methods.get(row.unit_id, [])
		result[int(row.load_order)] = row
	return result


## Keep parser, compiler, binding, service adaptation and behavior evidence separate.
static func build(
	root: String, registry: Dictionary, inventory: Dictionary, workspace: Dictionary
) -> Dictionary:
	var lifecycle_path = root.path_join("migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.json")
	var lifecycle: Variant = (
		JSON.parse_string(FileAccess.get_file_as_string(lifecycle_path))
		if FileAccess.file_exists(lifecycle_path)
		else {}
	)
	var services: Dictionary = {}
	if lifecycle is Dictionary:
		for row in lifecycle.get("scripts", []):
			if row is Dictionary:
				services[int(row.get("load_order", row.get("order", 0)))] = row
	var audited = audit_services(root, registry)
	services.merge(audited, true)
	var rows: Array = []
	var counts = {
		"units": 0,
		"parsed": 0,
		"generated": 0,
		"bound": 0,
		"empty": 0,
		"excluded": 0,
		"diagnostic_units": 0,
		"changed": 0,
		"manual_files": 0,
		"audited_sources": 0,
		"audit_stale": 0
	}
	var syntax: Dictionary = {}
	var calls: Dictionary = {}
	for id in registry.get("units", {}):
		var unit: Dictionary = registry.units[id]
		var origin: Dictionary = unit.get("origin", {})
		var original_hash = workspace.get("original_hashes", {}).get(
			id, unit.get("source_sha256", "")
		)
		var changed = (
			original_hash != unit.get("source_sha256", "") or workspace.get("sources", {}).has(id)
		)
		var service: Dictionary = (
			services.get(int(origin.get("load_order", 0)), {})
			if origin.get("kind") == "script"
			else {}
		)
		var row = {
			"unit_id": id,
			"origin": origin,
			"parsed": unit.get("parsed", false),
			"status": unit.get("status", "unsupported"),
			"generated": unit.get("generated", false),
			"bound": unit.get("event_integrated", false),
			"runtime_verified": unit.get("runtime_verified", false),
			"changed": changed,
			"diagnostics": unit.get("diagnostics", []),
			"service_classification": service.get("classification", service.get("status", "")),
			"service_paths": service.get("targets", []),
			"audit_label": service.get("label", ""),
			"audit_current": service.get("current", false),
			"audit_entry": service.get("entry", ""),
			"audit_boundary": service.get("boundary", ""),
			"audit_methods": service.get("methods", []),
			"generated_path": unit.get("generated_path", "")
		}
		rows.append(row)
		if not row.audit_label.is_empty():
			counts.audited_sources += 1
			if not row.audit_current:
				counts.audit_stale += 1
		counts.units += 1
		for key in ["parsed", "generated", "changed"]:
			if row[key]:
				counts[key] += 1
		if row.bound:
			counts.bound += 1
		if row.status == "empty":
			counts.empty += 1
		if row.status == "excluded_by_user":
			counts.excluded += 1
		if not row.diagnostics.is_empty():
			counts.diagnostic_units += 1
		if unit.get("parsed", false):
			var ast: Dictionary = unit.get("ast", {})
			if ast.is_empty():
				var path = str(unit.get("ast_path", "")).trim_prefix("res://")
				if (
					path.begins_with("data/script_ast/")
					and not path.contains("..")
					and FileAccess.file_exists(root.path_join(path))
				):
					var parsed: Variant = JSON.parse_string(
						FileAccess.get_file_as_string(root.path_join(path))
					)
					if parsed is Dictionary:
						ast = parsed
			_nodes(ast, syntax)
		for call in unit.get("analysis", {}).get("calls", []):
			var name = str(call.get("name", "?"))
			if not calls.has(name):
				calls[name] = []
			calls[name].append(
				{
					"unit_id": id,
					"origin": origin,
					"line": call.get("line", 1),
					"resolution": "lexical_candidate_not_behavior_proof"
				}
			)
	var ownership: Array = []
	for path in workspace.get("generated_hashes", {}):
		var manual = (
			FileAccess.file_exists(root.path_join(path))
			and FileAccess.get_sha256(root.path_join(path)) != workspace.generated_hashes[path]
		)
		ownership.append(
			{"path": path, "owner": "manual_changed" if manual else "generator", "conflict": manual}
		)
		if manual:
			counts.manual_files += 1
	return {
		"format": "rgm-script-coverage-v1",
		"version": inventory.get("tool_stage", "historical"),
		"counts": counts,
		"units": rows,
		"syntax_nodes": syntax,
		"api_candidates": calls,
		"ownership": ownership,
		"evidence_policy": "解析、生成、绑定与服务适配分别统计；用户修改后的代码需重新行为验证；不使用文件数推算游戏完成率。",
		"source_boundaries": lifecycle.get("boundaries", []) if lifecycle is Dictionary else []
	}


static func markdown(report: Dictionary) -> String:
	var c: Dictionary = report.counts
	var lines: Array[String] = [
		"# 脚本迁移覆盖报告",
		"",
		report.evidence_policy,
		"",
		(
			"单元 %d；AST %d；生成 %d；事件绑定 %d；空槽 %d；排除 %d；含诊断 %d；已修改 %d；手工文件 %d。"
			% [
				c.units,
				c.parsed,
				c.generated,
				c.bound,
				c.empty,
				c.excluded,
				c.diagnostic_units,
				c.changed,
				c.manual_files
			]
		),
		"",
		(
			"职责审计 %d 个来源；其中 %d 个在审计后已变更、需复验。编译器诊断和服务实现分开统计。"
			% [c.get("audited_sources", 0), c.get("audit_stale", 0)]
		),
		"",
		"| 单元 | 来源 | 转换 | 绑定 | 服务分类 |",
		"| --- | --- | --- | --- | --- |"
	]
	for row in report.units:
		lines.append(
			(
				"| %s | %s | %s | %s | %s |"
				% [
					row.unit_id,
					JSON.stringify(row.origin).replace("|", "\\|"),
					row.status,
					"是" if row.bound else "否",
					(
						(
							row.get("audit_label", "")
							+ ("（审计后已改）" if not row.get("audit_current", true) else "")
						)
						if not row.get("audit_label", "").is_empty()
						else row.service_classification
					)
				]
			)
		)
	(
		lines
		. append_array(
			[
				"",
				"语法节点和API候选位置见 data/script_coverage.json。API候选不表示调用已实现；当前职责、覆盖关系及原缺失边界见 migration_docs/MIGRATION_AUDIT_v0.59.md 和 data/migration_audit.json；旧0.47审计仅作历史来源。"
			]
		)
	)
	return "\n".join(lines) + "\n"


static func _nodes(value: Variant, result: Dictionary) -> void:
	if value is Array:
		for entry in value:
			_nodes(entry, result)
	elif value is Dictionary:
		if value.has("kind"):
			result[value.kind] = int(result.get(value.kind, 0)) + 1
		for key in value:
			if key != "origin":
				_nodes(value[key], result)

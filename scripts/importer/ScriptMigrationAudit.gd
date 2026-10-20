## 职责：发布已审阅的0.58迁移审计，核对原脚本和实际Godot实现的内容，拒绝过时清单。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/ScriptMigrationAudit.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func generate(root: String, source: String) -> Dictionary
##     用途：只在339个原来源和已审阅Godot目标内容全部一致后发布审计；出错返回errors，不发布当前数据。
##     参数 root（String；必填）：已生成工程的绝对根目录。
##     参数 source（String；必填）：只读原RM工程根目录，读取Data/Scripts.rxdata核对SHA256。
##     返回：{ok, errors, summary}；失败不冒称服务或行为已验收。
##
## 接口说明结束。

extends RefCounted


func generate(root: String, source: String) -> Dictionary:
	var path = "res://docs/MIGRATION_AUDIT_v0.59.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("format") != "rgm-migration-audit-v1":
		return {"ok": false, "errors": ["迁移审计清单缺失或格式无效。"]}
	var report: Dictionary = parsed
	var errors: Array = []
	if (
		FileAccess.get_sha256(source.path_join("Data/Scripts.rxdata"))
		!= report.source_rxdata_sha256
	):
		errors.append("原Scripts.rxdata与已审阅迁移审计不同，须重新核对。")
	var units: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(root.path_join("data/script_units.json"))
	)
	if not units is Dictionary:
		return {"ok": false, "errors": ["迁移审计缺少脚本登记表。"]}
	var count = 0
	for id in units.get("units", {}):
		if str(id).begins_with("script_"):
			count += 1
	if report.scripts.size() != count:
		errors.append("原脚本槽数量与已审阅清单不同。")
	var seen: Dictionary = {}
	for row in report.scripts:
		var relative = str(row.source_path)
		if (
			not relative.begins_with("legacy/ordered_scripts/")
			or relative.contains("..")
			or seen.has(row.unit_id)
		):
			errors.append("迁移审计来源路径或身份无效：" + relative)
			continue
		seen[row.unit_id] = true
		if (
			FileAccess.get_sha256(root.path_join(relative)) != row.sha256
			or not units.units.has(row.unit_id)
		):
			errors.append("原脚本内容与已审阅清单不同：" + relative)
	for name in report.implementations:
		var target: Dictionary = report.implementations[name]
		var relative = str(target.path)
		if not relative.begins_with("runtime/scripts/") or relative.contains(".."):
			errors.append("迁移审计目标路径无效：" + relative)
			continue
		if FileAccess.get_sha256(root.path_join(relative)) != target.sha256:
			errors.append("Godot目标内容与已审阅清单不同：" + relative)
	for snapshot in [report.get("runtime_snapshot", {}), report.get("generated_snapshot", {})]:
		for relative in snapshot:
			if (
				not (
					str(relative).begins_with("runtime/scripts/")
					or str(relative).begins_with("runtime/generated/")
				)
				or str(relative).contains("..")
			):
				errors.append("迁移审计依赖路径无效：" + str(relative))
			elif FileAccess.get_sha256(root.path_join(relative)) != snapshot[relative]:
				errors.append("运行依赖内容与已审阅清单不同：" + str(relative))
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var file = FileAccess.open(root.path_join("data/migration_audit.json"), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["无法发布当前工程迁移审计。"]}
	file.store_string(JSON.stringify(report, "\t", false) + "\n")
	file.close()
	return {"ok": true, "errors": [], "summary": report.counts}

extends RefCounted
const Workspace = preload("res://templates/editor/addons/rgm_editor/EditorScriptWorkspace.gd")
const Coverage = preload("res://templates/editor/addons/rgm_editor/EditorScriptCoverage.gd")

func generate(root: String) -> Dictionary:
	var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/script_units.json")))
	var inventory: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/script_inventory.json")))
	if not registry is Dictionary or not inventory is Dictionary: return {"ok":false,"errors":["无法生成脚本工作区：缺少转换登记。"]}
	var workspace=Workspace.initial(root,registry)
	var report=Coverage.build(root,registry,inventory,workspace)
	var errors: Array=[]
	for path in {"data/script_workspace.json":JSON.stringify(workspace,"\t",false)+"\n","data/script_coverage.json":JSON.stringify(report,"\t",false)+"\n","script_coverage.md":Coverage.markdown(report)}:
		var text=JSON.stringify(workspace,"\t",false)+"\n" if path=="data/script_workspace.json" else JSON.stringify(report,"\t",false)+"\n" if path=="data/script_coverage.json" else Coverage.markdown(report)
		var file=FileAccess.open(root.path_join(path),FileAccess.WRITE)
		if file==null: errors.append("无法写入脚本工作区："+path); continue
		file.store_string(text); file.close()
	return {"ok":errors.is_empty(),"errors":errors,"summary":report.counts}

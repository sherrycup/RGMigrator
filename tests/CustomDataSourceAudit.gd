## 职责：回归验证：审计自定义数据与原脚本来源、初始值和字段的对应关系。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Converter=preload("res://scripts/importer/RmxpDataConverter.gd")
const Codec=preload("res://scripts/importer/RmxpTextCodec.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var workspace=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var projects: Array=[]
	for pair in [["魔塔样板7630·改","黎之闪翼（开发中）_Godot"],["小蛋挞(读1号存档即可)","二律背反_Godot"]]:
		var original=workspace.path_join("rm_template/"+pair[0]); var output=workspace.path_join("output/0.44/release/"+pair[1])
		var converter=Converter.new(Codec.new(936))
		var temporary=ProjectSettings.globalize_path("res://.godot/source_comment_audit_"+str(Time.get_ticks_usec()))
		DirAccess.make_dir_recursive_absolute(temporary)
		var converted=converter.convert(original,temporary)
		if not converted.ok: failures.append("Source conversion failed: "+original); continue
		var custom: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("data/custom_data.json")))
		var before=failures.size()
		for comment in custom.comments:
			var origin: Dictionary=comment.origin; var commands: Array
			if origin.kind=="map_event": commands=converter.script_inventory.raw_maps[origin.map].events[str(int(origin.event_id))].pages[int(origin.page)-1].list
			else: commands=converter.script_inventory.raw_common[origin.database][int(origin.common_event_id)].list
			var index=int(origin.command_index)-1; var text=""
			if index<commands.size() and int(commands[index].code)==108 and not commands[index].parameters.is_empty():
				text=str(commands[index].parameters[0]); index+=1
				while index<commands.size() and int(commands[index].code)==408:
					text+="\n"+str(commands[index].parameters[0]); index+=1
			checks+=1
			if text!=comment.text or text.sha256_text()!=comment.source_sha256: failures.append("Original comment source mismatch: "+JSON.stringify(origin))
		projects.append({"project":output,"source":original,"comments":custom.comments.size(),"ok":failures.size()==before,"manifest_sha256":FileAccess.get_sha256(output.path_join("data/custom_data.json"))})
	var file=FileAccess.open("res://.godot/test-logs/v044-source-comment-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"projects":projects,"checks":checks,"failures":failures},"\t")); file.close()
	for failure in failures: printerr("FAIL: ",failure)
	print("CUSTOM DATA SOURCE AUDIT: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

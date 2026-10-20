## 职责：回归验证：验证闪翼消息定义、文本与控制信息的静态提取。
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
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Inventory=preload("res://scripts/importer/ScriptMigrationInventory.gd")
const Corrections=preload("res://scripts/importer/SourceCorrections.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var base=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("output/0.45/delivery/黎之闪翼（开发中）_Godot")
	var source_registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("data/script_units.json")))
	var original: Dictionary=source_registry.units.event_000127
	var source: String=original.source; var origin: Dictionary=original.origin
	expect(source.sha256_text()==original.source_sha256 and source.contains("Message::TextRow.new"),"actual frozen original Map024 EV032 text-row fragment remains authoritative")
	var adapted=Corrections.adapt(source,origin)
	expect(adapted.corrections.size()==1 and adapted.corrections[0].id=="text_row_literal_escape" and adapted.corrections[0].line==1,"original Ruby control escape defect has one exact source correction")
	var parsed=preload("res://scripts/importer/RubyParser.gd").new().parse(adapted.source,origin)
	expect(parsed.ok,"actual corrected source forms a strict complete AST")
	var root=ProjectSettings.globalize_path("res://.godot/flash_message_row_"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(root.path_join("data/maps"))
	DirAccess.make_dir_recursive_absolute(root.path_join("legacy/ruby_scripts"))
	var file=FileAccess.open(root.path_join("data/custom_data.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"profile":"flash"})); file.close()
	var inv=Inventory.new(); inv.interpreter_policy={"merge_adjacent_355":false,"false_result_waits":false,"frame_rate":60}
	inv.collect_map({"id":24,"events":{"32":{"id":32,"name":"EV032","pages":[{"list":[{"code":355,"indent":0,"parameters":[source]},{"code":0,"indent":0,"parameters":[]}]}]}}},"Map024")
	inv.fragments[0].unit_id="event_000127"
	var result=inv.generate(root,[])
	expect(result.ok,"actual text row fragment freshly generates and binds without copying old compiled code")
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/script_units.json")))
	var unit: Dictionary=registry.units.event_000127
	var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/maps/Map024.json")))
	expect(unit.status=="generated" and unit.source_sha256==original.source_sha256 and unit.adapted_source_sha256!=unit.source_sha256 and map.events["32"].pages[0].list[0]._script_binding.unit_id=="event_000127","fresh native binding retains original source hash and separate corrected hash")
	file=FileAccess.open("res://.godot/v046-message-row-fixture-path.txt",FileAccess.WRITE); file.store_string(root); file.close()
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MESSAGE IMPORTER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

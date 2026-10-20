## 职责：回归验证：验证闪翼玩法、技能及外部配置的来源提取。
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
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Importer=preload("res://scripts/importer/GameplayImporter.gd")
var failures: Array[String]=[]
var checks=0
func _init() -> void: call_deferred("run")
func run() -> void:
	var source=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("output/0.44/release/黎之闪翼（开发中）_Godot")
	var fixture=ProjectSettings.globalize_path("res://.godot/flash_gameplay_data_"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(fixture.path_join("data"))
	DirAccess.copy_absolute(source.path_join("data/custom_data.json"),fixture.path_join("data/custom_data.json"))
	DirAccess.make_dir_recursive_absolute(fixture.path_join("data/maps"))
	for filename in DirAccess.get_files_at(source.path_join("data/maps")):
		if filename.ends_with(".json"): DirAccess.copy_absolute(source.path_join("data/maps").path_join(filename),fixture.path_join("data/maps").path_join(filename))
	var inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("data/script_inventory.json")))
	var entries: Array=[]
	for entry in inventory.scripts:
		entries.append({"unit_id":entry.unit_id,"origin":entry.origin,"source":FileAccess.get_file_as_string(source.path_join(entry.source_path))})
	var result=Importer.new().generate(fixture,entries)
	expect(result.ok,"original Flash source gameplay data extracts: "+JSON.stringify(result.get("diagnostics",[])))
	var data: Dictionary=preload("res://templates/runtime/scripts/00_Game/CustomDataState.gd").native_value(JSON.parse_string(FileAccess.get_file_as_string(fixture.path_join("data/flash_gameplay.json"))))
	expect(data.skills.size()==13,"all 13 actual skill registrations are preserved")
	expect(data.skills["41"].hit_count==3 and data.skills["41"].atk_rate==0.5 and data.skills["43"].stiffness==5,"source damage multipliers/hit counts/delays stay distinct")
	expect(data.skills["45"].target=="party" and data.skills["46"].target=="support","explicit party/support targeting is retained")
	expect(data.skills["61"].instant_follow_up and data.skills["81"].threshold==6 and data.skills["121"].threshold==12,"follow-up types and count thresholds retain source semantics")
	expect(data.storage.actor_exp_next["2"][1]==30 and data.storage.crystal["71"]==[3,1,[0,0,1,0,0]],"actual experience and crystal tables are extracted")
	expect(data.storage.potion_hp["4"]==1000 and data.storage.gem_attr["7"].resist==[1,0,0,0,0],"indexed source assignments retain item effect data")
	expect(data.storage.adoor_set.list[0].code==117 and data.storage.adoor_set.list[0].parameters==[23],"pure EventCommand constructors become native command data")
	expect(data.method_sources.has("BattleSystem::Simulator#run") and not data.method_sources.has("Battle_Manager#start_battle"),"ordinary battle sources are indexed while user-excluded BOSS sources are omitted")
	var catalog_path: String=fixture.path_join("runtime/generated/skill_catalog.gd")
	expect(FileAccess.file_exists(catalog_path) and data.generated_skill_catalog.editable and data.generated_skill_catalog.definitions==13,"fresh migration emits an editable GDScript skill catalog")
	var catalog: Script=load(catalog_path)
	expect(catalog!=null and preload("res://templates/runtime/scripts/00_Game/CustomDataState.gd").native_value(catalog.source_skills())==data.skills,"generated catalog exactly preserves the extracted definitions and source provenance")
	expect(data.storage.skill_description.size()==7 and data.storage.skill_easy_description.size()==1,"original long and short skill descriptions retain their separate source tables")
	expect(data.storage.note_name["0"].size()==9 and data.storage.note_desc["0"]["1"]=="哈哈哈哈" and data.storage.note_desc["1"]==null,"original finite note cases retain actual text and nil unfinished categories")
	expect(data.event_attribute_values["1"]==1 and data.event_attribute_values["[0,0,0,0,1]"]==[0,0,0,0,1] and not data.event_attribute_origins.is_empty(),"actual original map-name expressions remain available beside the new UI data tables")
	var path=FileAccess.open("res://.godot/flash-gameplay-fixture-path.txt",FileAccess.WRITE); path.store_string(fixture); path.close()
	for failure in failures: printerr("FAIL: ",failure)
	print("FLASH GAMEPLAY IMPORTER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

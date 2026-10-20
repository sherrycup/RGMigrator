## 职责：回归验证：验证冷启动时技能目录的加载和完整校验。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func write_source(source: String) -> bool
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 公开常量：SOURCE_PATH。
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Registry=preload("res://runtime/scripts/01_Battle/BattleRegistry.gd")
const Simulator=preload("res://runtime/scripts/01_Battle/BattleSimulator.gd")
const SOURCE_PATH="res://runtime/generated/skill_catalog.gd"
var failures: Array=[]
var checks=0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var registry=Registry.new()
	expect(not registry.is_configured(),"new engine process has no previous module catalog")
	var original=FileAccess.get_file_as_string(SOURCE_PATH)
	var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/flash_gameplay.json"))
	var provider: GDScript=load(SOURCE_PATH)
	var source_skills: Dictionary=provider.source_skills()
	var raw: Array=Data.read_json("res://data/database/Skills.json",[])
	var raw_before=raw.duplicate(true); var id=raw.size()+5
	var definition=source_skills["42"].duplicate(true); definition.id=id; definition.name="Cold GDS Catalog"; source_skills[str(id)]=definition
	var source="extends RefCounted\nconst INPUT_SHA = "+JSON.stringify(provider.get_script_constant_map().INPUT_SHA)+"\nstatic func source_skills() -> Dictionary:\n\treturn JSON.parse_string("+JSON.stringify(JSON.stringify(source_skills))+")\n"
	expect(write_source(source),"private source adds a real GDScript skill before any gameplay instance")
	var record=Data.record("Skills",id)
	expect(registry.is_configured() and record.get("name")=="Cold GDS Catalog","first database read cold-installs the actual GDScript catalog")
	expect(Data.database("Skills")[id].name=="Cold GDS Catalog" and Data.source_record("Skills",id).is_empty() and raw==raw_before,"cold catalog view includes new ID while source JSON remains unchanged")
	var gameplay=root.get_node("RuntimeState").custom_data.gameplay()
	expect(gameplay.simulator.skills.has(str(id)) and gameplay.simulator.validate().is_empty(),"later gameplay initialization retains the same cold-installed source definition")
	expect(write_source(original),"private generated source restored after cold-start probe")
	var sim=Simulator.new(); sim.configure(rules)
	expect(not sim.registry.includes(id) and Data.record("Skills",id).is_empty() and raw==raw_before,"restoring original catalog removes private probe without source mutation")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH BATTLE COLD CATALOG: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func write_source(source: String) -> bool:
	var file=FileAccess.open(SOURCE_PATH,FileAccess.WRITE)
	if file==null: return false
	file.store_string(source); file.close()
	var provider: GDScript=load(SOURCE_PATH)
	provider.source_code=source
	return provider.reload(true)==OK

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

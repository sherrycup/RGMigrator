## 职责：回归验证：验证实际技能目录读取、编辑重载及非法定义拒绝。
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
## Runs only in a private runtime fixture. Temporarily edits then restores its
## generated GDScript catalog; never writes original RM or historical exports.
const Simulator=preload("res://runtime/scripts/01_Battle/BattleSimulator.gd")
const Cache=preload("res://runtime/scripts/01_Battle/BattleCache.gd")
const Semantics=preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")
const SOURCE_PATH="res://runtime/generated/skill_catalog.gd"
var failures: Array=[]
var checks=0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists(SOURCE_PATH):
		printerr("FAIL: original-source generated catalog missing"); quit(1); return
	var original=FileAccess.get_file_as_string(SOURCE_PATH)
	var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/flash_gameplay.json"))
	var provider: GDScript=load(SOURCE_PATH)
	var canonical: Variant=JSON.parse_string(JSON.stringify(rules.skills))
	var sha=JSON.stringify(canonical).sha256_text()
	expect(provider.get_script_constant_map().get("INPUT_SHA")==sha,"generated source fingerprint matches actual extracted source rules")
	var provided: Dictionary=provider.source_skills()
	expect(provided.size()==13 and JSON.stringify(JSON.parse_string(JSON.stringify(provided)))==JSON.stringify(canonical),"generated GDScript preserves all original thirteen definitions")
	var sim=Simulator.new(); sim.configure(rules)
	expect(sim.validate().is_empty() and sim.skills["42"].atk_rate==1.5,"normal configure installs the actual source GDScript catalog")
	var edited_source="extends RefCounted\nconst INPUT_SHA = "+JSON.stringify(sha)+"\nstatic func source_skills() -> Dictionary:\n\tvar skills: Dictionary = JSON.parse_string("+JSON.stringify(JSON.stringify(provided))+")\n\tskills[\"42\"][\"atk_rate\"] = 2.0\n\treturn skills\n"
	var old_revision=sim.registry.revision
	var previous_sim=sim
	expect(write_source(edited_source),"private generated GDScript editing succeeds")
	sim=Simulator.new(); sim.configure(rules)
	expect(sim.validate().is_empty() and sim.skills["42"].atk_rate==2.0 and sim.registry.revision>old_revision,"GDScript edits take effect while original INPUT_SHA remains unchanged")
	expect(previous_sim.skills["42"].atk_rate==2.0,"module reload updates already-created simulator references")
	var custom=rules.duplicate(true); custom.skills["42"].atk_rate=3.0
	sim=Simulator.new(); sim.configure(custom)
	expect(sim.validate().is_empty() and sim.skills["42"].atk_rate==3.0,"unrelated standalone rules bypass mismatching generated source")
	var invalid_source="extends RefCounted\nconst INPUT_SHA = "+JSON.stringify(sha)+"\nstatic func source_skills() -> Variant:\n\treturn []\n"
	expect(write_source(invalid_source),"private invalid-return fixture loads without a parser error")
	sim=Simulator.new(); sim.configure(rules)
	expect(not sim.validate().is_empty() and sim.validate().contains("Dictionary"),"matching GDScript with invalid result fails explicitly")
	expect(write_source(original),"private source is restored exactly after all editing probes")
	sim=Simulator.new(); sim.configure(rules)
	expect(sim.validate().is_empty() and sim.skills["42"].atk_rate==1.5 and FileAccess.get_file_as_string(SOURCE_PATH)==original,"restored original catalog restores its original behavior")
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.variables["14"]=[2,0]; state.map_id=10
	var aura={"value":1}
	var env=Semantics.new(state); env.begin({"kind":"cache_transaction_test"})
	var gameplay=env._custom.gameplay(); var floor_data=env._custom._floor(10)
	var enemy_event=int(floor_data.entries.keys()[0])
	expect(gameplay.cache_service.register_condition("catalog_probe",func(enemy):return aura.value).ok,"actual gameplay registers cache extension")
	var first: Variant=gameplay.predict(10,enemy_event)
	var repeated: Variant=gameplay.predict(10,enemy_event)
	expect(first!=null and repeated==first and gameplay.simulation_count==1,"actual shared gameplay reuses unchanged extra-condition tag")
	expect(env.finish(null).ok,"cache tag commits with the ordinary custom-data transaction")
	var next_env=Semantics.new(state); next_env.begin({"kind":"cache_transaction_test"})
	var next_gameplay=next_env._custom.gameplay()
	expect(next_gameplay!=gameplay and Cache.conditions.has("catalog_probe"),"next script transaction rebuilds gameplay while retaining module conditions")
	var reused: Variant=next_gameplay.predict(10,enemy_event)
	expect(reused==first and next_gameplay.simulation_count==0,"committed cache survives a fork with unchanged registered condition")
	aura.value=2
	var changed: Variant=next_gameplay.predict(10,enemy_event)
	expect(changed!=null and next_gameplay.simulation_count==1,"changed provider value triggers actual recalculation after transaction fork")
	var actor=next_env._custom.staged_actor(2)
	var support=next_env._custom.staged_actor(3)
	support.inflict_battle_down()
	next_env._custom.script_variables["14"]=[actor.id,support.id]
	var input: Array=next_gameplay.party_cache_inputs()
	expect(input.size()==2 and input[1].id==3 and input[1].battle_down and next_gameplay.party_snapshot()[1].is_empty(),"cache keeps original unavailable support while simulation excludes it")
	next_env.finish(null)
	Cache.unregister_condition("catalog_probe")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH BATTLE CATALOG: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func write_source(source: String) -> bool:
	var file=FileAccess.open(SOURCE_PATH,FileAccess.WRITE)
	if file==null: return false
	file.store_string(source); file.close()
	var provider: Variant=ResourceLoader.load(SOURCE_PATH,"GDScript",ResourceLoader.CACHE_MODE_REPLACE)
	if not provider is GDScript: return false
	# Reload compiles the cached resource's source_code; explicitly refresh it to
	# model editor reload, rather than pretending a file write restarts the game.
	provider.source_code=source
	return provider.reload(true)==OK and provider.can_instantiate()

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)

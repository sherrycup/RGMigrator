## 职责：回归验证：验证迁移阶段的事件脚本编译与原记录绑定。
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
##   static func c(code: int, p: Array = [], indent: int = 0) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；默认值 []）：对应事件指令的参数数组。
##     参数 indent（int；默认值 0）：事件指令的结构缩进层级。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Inventory = preload("res://scripts/importer/ScriptMigrationInventory.gd")
const Generator = preload("res://scripts/importer/ProjectGenerator.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var root := ProjectSettings.globalize_path("res://.godot/script_event_fixture_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root.path_join("data/maps"))
	DirAccess.make_dir_recursive_absolute(root.path_join("data/database"))
	DirAccess.make_dir_recursive_absolute(root.path_join("legacy/ruby_scripts"))
	var generated := Generator.new().generate(root,"0.43 internal fixture",{})
	expect(generated.warnings.is_empty(),"fixture runtime generated")
	var inv := Inventory.new()
	inv.interpreter_policy = {"merge_adjacent_355":true,"false_result_waits":true,"custom_binding":false,"frame_rate":50,"evidence":{}}
	var library := "def reward(amount)\n$game_party.gain_gold(amount)\n@tag = 7\ntrue\nend\nclass Reward\n def value\n  13\n end\nend\nclass Other\n def missing_context\n  0\n end\nend"
	var list: Array = [c(355,["reward(25)"]),c(655,["@wait_count = 50"]),c(111,[12,"0"]),c(121,[1,1,0],1),c(411),c(121,[2,2,0],1),c(412),c(117,[1]),c(355,["$game_variables[4] = @tag"]),c(0)]
	var poll: Array = [c(355,["$game_variables[3] += 1"]),c(355,["$game_switches[3]"]),c(121,[4,4,0]),c(0)]
	var condition_fail: Array = [c(111,[12,"eval('unknown')"]),c(121,[5,5,0],1),c(411),c(121,[6,6,0],1),c(412),c(0)]
	var route := {"repeat":false,"skippable":false,"list":[{"code":45,"parameters":["$game_variables[5] = @x; @wait_count = 50; false"]},{"code":27,"parameters":[7]},{"code":0,"parameters":[]}]}
	var simple_route := {"repeat":false,"skippable":false,"list":[{"code":0,"parameters":[]}]}
	var map := {"id":1,"events":{"7":{"id":7,"name":"internal","pages":[{"list":list,"move_route":route},{"list":poll,"move_route":simple_route},{"list":condition_fail,"move_route":simple_route}]}}}
	var common: Array = [null,{"id":1,"list":[c(355,["$game_variables[1] = @event_id; $game_variables[2] = @map_id; @tag = 11"]),c(0)]}]
	for source in ["$game_variables[8] = 77; missing_context()","$game_variables[9] += 1\n$game_switches[9]","false","nil","[]","Reward.new.value","@wait_count = 50", "_v[10] = 10; _s[10] = true", "$game_party.gain_gold(5)"]:
		common.append({"id":common.size(),"list":[c(355,[source]),c(121,[8,8,0]),c(0)]})
	for source in ["false","nil","[]","\"\"","1"]:
		common.append({"id":common.size(),"list":[c(111,[12,source]),c(121,[20,20,0],1),c(411),c(121,[21,21,0],1),c(412),c(0)]})
	common.append({"id":16,"list":[c(355,["$game_party.gain_gold(5)"]),c(655,["false"]),c(121,[22,22,0]),c(0)]})
	common.append({"id":17,"list":[c(355,["# comment-only Ruby"]),c(121,[23,23,0]),c(0)]})
	common.append({"id":18,"list":[c(355,["$game_variables[25] = Rates::BONUS"]),c(0)]})
	inv.collect_map(map,"Map001"); inv.collect_common(common)
	inv.collect_common([null,{"id":1,"list":[c(355,["$game_variables[26] = 26"]),c(0)]}],"CommonEvent")
	var result := inv.generate(root,[{"unit_id":"script_0001","source":library,"source_path":"","origin":{"kind":"script","load_order":1,"name":"Reward library","script_id":1}},{"unit_id":"script_0002","source":"alias reward_original reward\ndef reward(amount)\nreward_original(amount)\nend","source_path":"","origin":{"kind":"script","load_order":2,"name":"Reward alias override","script_id":2}},{"unit_id":"script_0003","source":"module Rates\nBONUS = 2\nend","source_path":"","origin":{"kind":"script","load_order":3,"name":"Pure constant library","script_id":3}}])
	expect(result.ok,"fixture compilation and data binding succeeded")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/script_units.json")))
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/maps/Map001.json")))
	expect(actual.events["7"].pages[0].list[0].code==355 and actual.events["7"].pages[0].list[1].code==655,"converted merged program restored without dropping continuation")
	expect(actual.events["7"].pages[0].list[2].code==111,"compiled script condition restores entire native branch")
	expect(actual.events["7"].pages[2].list[0].code==108 and actual.events["7"].pages[2].list[0]._editor_original.size()==5,"unconverted condition preserves whole original branch")
	expect(registry.units.script_0001.definitions.safe,"library has declaration-only initialization")
	var parsed=preload("res://scripts/importer/RubyParser.gd").new().parse("class Unrelated\n def initialize\n File.open('unsupported')\n end\nend\n$startup = File.open('unsupported')")
	var declarations=preload("res://scripts/importer/ScriptEventIntegrator.gd").definitions(parsed.ast.body)
	expect(parsed.ok and not declarations.safe and declarations.methods[0].owner=="Unrelated","unsupported initialization retains complete AST method owner rather than a wildcard")
	parsed=preload("res://scripts/importer/RubyParser.gd").new().parse("module Parent\n if true\n class Conditional\n def initialize\n 1\n end\n end\n end\nend")
	declarations=preload("res://scripts/importer/ScriptEventIntegrator.gd").definitions(parsed.ast.body)
	expect(not declarations.safe and declarations.methods[0].owner=="Parent::Conditional" and "Parent::Conditional" in declarations.types,"conditional declarations retain qualified owners while staying unsafe to autoload")
	expect(inv.continuations.size()==1 and actual.events["7"].pages[1].list[1]._script_binding.unit_id.ends_with("_retry"),"false retry binds last355 tail separately")
	expect(actual.events["7"].pages[0].move_route.list[0].code==45 and actual.events["7"].pages[0].move_route.list[0].has("_script_binding"),"route45 retained and bound")
	var primary: Array = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/database/CommonEvents.json")))
	var alternate: Array = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/database/CommonEvent.json")))
	expect(primary[1].list[0]._script_binding.unit_id!=alternate[1].list[0]._script_binding.unit_id and registry.units[alternate[1].list[0]._script_binding.unit_id].origin.database=="CommonEvent","same event IDs in different source databases never collide")
	var locator := FileAccess.open("res://.godot/v043-fixture-path.txt",FileAccess.WRITE); locator.store_string(root)
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT EVENT IMPORTER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks / ",root)
	quit(0 if failures.is_empty() else 1)

static func c(code: int, p: Array = [], indent: int = 0) -> Dictionary:
	return {"code":code,"parameters":p,"indent":indent}

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

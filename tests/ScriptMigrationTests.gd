## 职责：回归验证：验证脚本盘点、编译、诊断与迁移报告。
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
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Compiler = preload("res://scripts/importer/RubySubsetCompiler.gd")
const Inventory = preload("res://scripts/importer/ScriptMigrationInventory.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var origin := {"kind":"map_event", "map":"Map003", "event_id":7, "page":2, "command_index":4, "command_code":355}
	var good := Compiler.new().compile("# 中文\n  $game_variables[7] = 3\n$game_variables[7] += 2; $game_switches[4] = false",origin)
	expect(good.ok and good.ir.size()==3,"strict multiline and semicolon assignments")
	expect(good.ast.statements[0].span.line==2 and good.ast.statements[0].span.column==3,"Unicode character based line/column")
	expect(good.ir[1].operator=="+=" and good.ir[1].value==2,"compound assignment is retained in IR")
	expect(good.generated_source.contains("Bridge.apply") and good.generated_source.contains("Map003"),"real source generation retains origin")
	for bad in ["$Game_variables[1]=2", "$game_variables[0]=2", "$game_variables[1]=1+2", "$game_variables[1]=07", "$game_switches[1]=+true", "$game_switches[1]=1", "$game_variables[1]=1.5", "$game_variables[1]=true", "if true\n$game_variables[1]=2\nend", "$game_variables[1]=2\neval('x')", "$game_variables[1]=2 if false", "$game_variables[1]=2147483648", "$game_variables[1]=0x10", "$game_variables[1] =", "$game_variables[x]=1"]:
		var result := Compiler.new().compile(bad,origin)
		expect(not result.ok and result.generated_source.is_empty() and result.ir.is_empty(),"unsupported whole unit rejected: "+bad)
		expect(not result.diagnostics.is_empty() and result.diagnostics[0].origin==origin and result.diagnostics[0].column>0,"unsupported unit diagnostic retains location")
	var bad_line := Compiler.new().compile("$game_variables[1]=2\n  foo()",origin)
	expect(bad_line.diagnostics[0].line==2 and bad_line.diagnostics[0].column==3,"failure after a valid statement gives exact position")
	var inv := Inventory.new()
	var list := [{"code":355,"parameters":["$game_variables[7]=0"]},{"code":655,"parameters":["$game_switches[4]=true"]},{"code":111,"parameters":[12,"something?"]},{"code":209,"parameters":[-1,{"list":[{"code":45,"parameters":["move()"]}]}]}]
	inv.collect_map({"events":{"7":{"id":7,"name":"入口","pages":[{"list":list,"move_route":{"list":[{"code":45,"parameters":["walk()"]}]}}]}}},"Map003")
	inv.collect_common([null,{"id":8,"name":"公共","list":[{"code":355,"parameters":["$game_variables[7]+=1"]}]}])
	expect(inv.fragments.size()==5,"collect map/program/condition/forced/autonomous/common without duplicate509")
	expect(inv.fragments[0].source.contains("\n") and inv.fragments[0].origin.source_command_indices==[1,2],"continuations retain raw command indices")
	expect(inv.fragments[2].origin.command_index==4 and inv.fragments[2].origin.route_index==1,"forced route location")
	expect(inv.fragments[3].origin.command_index==0 and inv.fragments[3].origin.route_kind=="autonomous","autonomous route location")
	var analysis: Dictionary = inv._analyze("class A\n  def Foo\n  end\n  alias old Foo\n  def Foo\n  end\nend\n# eval('x')\n\"$game_party.fake()\"\n$game_party.real()", {"kind":"script","load_order":1}, "script_0001")
	expect(analysis.definitions.size()==4 and analysis.definitions[1].version_id!=analysis.definitions[3].version_id,"redefinitions and alias retained as ordered evidence")
	expect(analysis.calls.size()==1 and analysis.calls[0].name=="real","comments and ordinary strings do not add call dependencies")
	var merge_inventory := Inventory.new()
	merge_inventory.configure_scripts([{"source":"class Interpreter\n def command_355\n if @list[@index+1].code == 655 or @list[@index+1].code == 355\n end\n if result == false\n return false\n end\n end\nend","origin":{"kind":"script","load_order":1,"name":"Interpreter"}}])
	merge_inventory.collect_common([{"id":1,"list":[{"code":355,"parameters":["$game_variables[1]=0"]},{"code":355,"parameters":["unsupported()"]},{"code":655,"parameters":["continued()"]}]}])
	expect(merge_inventory.interpreter_policy.merge_adjacent_355 and merge_inventory.interpreter_policy.false_result_waits,"custom Interpreter grouping and false-result evidence")
	expect(merge_inventory.fragments.size()==1 and merge_inventory.fragments[0].origin.source_command_indices==[1,2,3],"source contiguous355 override does not falsely generate a partial fragment")
	var unicode_analysis: Dictionary = inv._analyze("$友军列表.include?(1)\nclass A\n def [](key)\n end\nend",{},"unicode")
	expect(unicode_analysis.globals[0].name=="$友军列表" and unicode_analysis.calls[0].receiver=="$友军列表","real Unicode global identifiers remain dependency evidence")
	expect(unicode_analysis.definitions[1].name=="[]","operator method declarations are not silently omitted")
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT MIGRATION TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

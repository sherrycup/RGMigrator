extends SceneTree
const Compiler = preload("res://scripts/importer/RubyGDScriptCompiler.gd")
const Semantics = preload("res://templates/runtime/scripts/ScriptSemantics.gd")
class State extends RefCounted:
 var variables: Dictionary = {}
 var switches: Dictionary = {}
 var gold := 0
 func set_event_variable(id: int, value: Variant) -> bool:
  variables[str(id)] = value; return true
 func set_event_switch(id: int, value: bool) -> bool:
  switches[str(id)] = value; return true
var failures: Array[String] = []
var checks := 0
var serial := 0
func _init() -> void:
 var state := State.new()
 var env := Semantics.new(state)
 execute("$game_variables[2] = 1 + 2 * 3\n$game_switches[1] = 0 ? true : false",env,true)
 expect(state.variables.get("2")==7 and state.switches.get("1")==true,"shared native state and Ruby zero truth")
 execute("a = []\nb = {}\nc = \"\"\n(a && b && c) ? 9 : 0",env,9)
 execute("false && (1 / 0)\n7 || (1 / 0)",env,7)
 execute("a = -7 / 3\nb = -7 % 3\na * 10 + b",env,-28)
 execute("a = [1,2]\na[4] = 8\na[-1] + a.length",env,13)
 execute("[4,9,3].max + [4,9,3].min",env,12)
 execute("a = {:key => 7}\na[:key] + 2",env,9)
 execute("x = 3\n\"value=#{x + 2}\"",env,"value=5")
 execute('class CompactOperator\n def value()\n @number=3\n "I:"+@number.to_s\n end\nend\nCompactOperator.new.value',env,"I:3")
 execute("x = 0\nwhile x < 3\n x += 1\nend\nfor n in 1..3\n x += n\nend\nx",env,9)
 execute("class Base\n def value()\n  2\n end\nend\nclass Child < Base\n alias previous value\n def value()\n  previous() + 3\n end\nend\nx = Child.new\nx.value",env,5)
 execute("class Child\n alias saved value\n def value()\n  99\n end\nend\nx = Child.new\nx.saved",env,5)
 execute("module Helper\n def add(x, y=2, *rest)\n  x + y + rest.length\n end\nend\nclass Receiver\n include Helper\n attr_accessor :amount\n def initialize(x)\n  @amount = x\n end\nend\nx = Receiver.new(7)\nx.add(x.amount)",env,9)
 execute("def choose(x)\n if x\n  4\n else\n  8\n end\nend\nchoose(0)",env,4)
 execute("total = 0\n[1,2,3].each do |n|\n total += n\nend\ntotal",env,6)
 execute("values = [1,2,3]\nvalues.map { |n| n * 2 }",env,[2,4,6])
 execute("total = 0\n{:a => 2, :b => 3}.each do |key, value|\n total += value\nend\ntotal",env,5)
 execute("x = Receiver.new(7)\nx.amount = 8\nx.amount",env,8)
 execute("$game_party.gain_gold(7)\n$game_party.gold",env,7)
 execute("$game_party.lose_gold(20)\n$game_party.gold",env,0)
 execute('a = {:key => 7, "key" => 9}\na[:key] * 10 + a["key"]',env,79)
 execute("[false] == [0]",env,false)
 execute("class Box\n def initialize()\n  @data = []\n end\n def [](key)\n  @data[key]\n end\n def []=(key, value)\n  @data[key] = value\n end\n def size()\n  99\n end\nend\nx = Box.new\nx[3] = 7\nx[3] + x.size",env,106)
 execute("$shared_a = [1]\n$shared_b = $shared_a\n1",env,1)
 execute("$shared_a[0] = 8\n1 / 0",env,null,false)
 execute("$shared_b[0] = 3\n$shared_a[0]",env,3)
 execute("a = [1,2]\ntotal = 0\na.each do |n|\n total += n\n a[1] = 3\nend\ntotal",env,4)
 execute('"array=#{[1,2]}"',env,"array=12")
 execute("class BodyResult\n false\nend",env,false)
 execute("for n in [1,2]\n n + 1\nend",env,[1,2])
 execute("module Functions\n module_function\n def choose(x)\n  case x\n  when 1,2\n   7\n  when 3\n   9\n  else\n   4\n  end\n end\nend\nFunctions.choose(2)",env,7)
 execute("module Functions\n def later()\n  11\n end\n module_function :later\nend\nFunctions.later",env,11)
 execute("class StaticCase\n class << self\n  def value()\n   5\n  end\n end\nend\nStaticCase.value",env,5)
 execute("def pair()\n return 1, 2\nend\npair",env,[1,2])
 execute('"怪物42"[/^怪物(\\d+)/]\n$1.to_i',env,42)
 execute('/a/ =~ "中a"',env,3)
 execute('/a/ =~ "abc"',env,0)
 execute('/missing/ =~ "abc"',env,null)
 execute('/missing/ !~ "abc"',env,true)
 execute('/a(b)?/ =~ "a"\n$1',env,null)
 execute('/a(b*)/ =~ "a"\n$1',env,"")
 execute('/a.b/m =~ "a\\nb"',env,0)
 execute('/a.b/ =~ "a\\nb"',env,null)
 execute('case "怪物2"\nwhen /^怪物/\n 7\nelse\n 9\nend',env,7)
 execute('"patk:1;mdef:3;".split(/;/)',env,["patk:1","mdef:3"])
 execute('"a:b:c".split(/:/,2)',env,["a","b:c"])
 execute('" +12suffix".to_i',env,12)
 execute('"abc"[1]',env,98)
 execute('"怪物2"[0]',env,230)
 execute('"怪物2"[0,6]',env,"怪物")
 execute('"abc"[3,2]',env,"")
 execute('[1,2,3][1,2]',env,[2,3])
 execute('"abc42"[/([0-9]+)/,1]',env,"42")
 execute('"not numeric".to_i',env,0)
 execute('def inner_match()\n /x(2)/ =~ "x2"\n $1\nend\n/y(1)/ =~ "y1"\na = inner_match\na + $1',env,"21")
 var first_context={"kind":"event","fields":{}}
 var second_context={"kind":"event","fields":{}}
 env.execution_context=first_context
 execute('/x(7)/ =~ "x7"\n$1',env,"7")
 env.execution_context=second_context
 execute('$1',env,null)
 env.execution_context=first_context
 execute('$1',env,"7")
 execute('/x(9)/ =~ "x9"\n1 / 0',env,null,false)
 execute('$1',env,"7")
 env.execution_context={}
 execute("a = 1..3\na[0]",env,null,false)
 execute("if false\n x = 7\nend\nx",env,null)
 execute("for i in []\n i\nend\ni",env,null)
 execute("total = 0\nfor i in 1..2\n for j in 1..2\n  total += i * j\n end\nend\ntotal",env,9)
 execute("total = 0\nfor i in [1,2]\n total += i\nend\nfor j in [3,4]\n total += j\nend\ntotal",env,10)
 var before: Dictionary = state.variables.duplicate(true)
 var failed := execute("$game_variables[2] = 99\n1 / 0",env,null,false)
 expect(not failed.ok and state.variables==before,"failed unit commits no partial writes")
 execute("class Child\n alias missing_method absent\nend",env,null,false)
 execute("x = Child.new\nx.value",env,99)
 for source in ["begin\n1\nrescue\n2\nend", "$game_actors[1].unmigrated_method", "class A\ndef f(&b)\nyield 1\nend\nend", "[1].each { |n| return n }", "[1].each { |*args| args }", "eval('1')"]:
  var rejected := Compiler.new().compile(source)
  expect(not rejected.ok and rejected.generated_source.is_empty(),"unsupported semantics never generates a fake implementation")
 for failure in failures: printerr("FAIL: ",failure)
 print("RUBY COMPILER TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
 quit(0 if failures.is_empty() else 1)
func execute(source: String, env: RefCounted, expected: Variant, should_pass: bool = true) -> Dictionary:
 serial += 1
 var path := "res://.godot/ruby-generated-test-%d.gd" % serial
 var known: Array = []
 for key in env.methods: known.append(key.get_slice("#",1) if key.contains("#") else key.get_slice(".",1))
 var result := Compiler.new().compile(source,{"name":"fixture-%d" % serial},path,known)
 expect(result.ok,"compile: "+source.get_slice("\n",0)+" / "+JSON.stringify(result.diagnostics))
 if not result.ok: return {"ok":false}
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string(result.generated_source.replace("res://runtime/scripts/ScriptSemantics.gd","res://templates/runtime/scripts/ScriptSemantics.gd"));file.close()
 var script: GDScript = load(path)
 expect(script!=null and script.can_instantiate(),"generated GDScript compiles")
 if script==null or not script.can_instantiate(): return {"ok":false}
 var ran: Dictionary = script.execute(env.state,env)
 expect(ran.ok==should_pass and (not should_pass or (typeof(ran.value)==typeof(expected) and ran.value==expected)),"independent expected result / "+JSON.stringify(ran))
 return ran
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures.append(message)

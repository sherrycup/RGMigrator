extends SceneTree
const Parser = preload("res://scripts/importer/RubyParser.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var parsed := parse_ok("a = 1 + 2 * 3\nb = -2 ** 2\nc = a || false && nil")
	expect(parsed.body[0].right.operator == "+" and parsed.body[0].right.right.operator == "*","multiplication precedence")
	expect(parsed.body[1].right.kind == "unary" and parsed.body[1].right.value.operator == "**","Ruby exponent before unary minus")
	expect(parsed.body[2].right.operator == "||" and parsed.body[2].right.right.operator == "&&","logical precedence")
	parsed = parse_ok("class Sample < Base\n attr_accessor :value\n def compute(x, y=2, *rest, &block)\n  @value = x + y\n  @value\n end\n alias old_compute compute\nend")
	var method: Dictionary = parsed.body[0].body[1]
	expect(parsed.body[0].parent == "Base" and method.parameters.size()==4,"class and full method signature")
	expect(method.parameters[1].mode=="optional" and method.parameters[2].mode=="rest" and method.parameters[3].mode=="block","parameter kinds")
	expect(parsed.body[0].body[2].target=="compute","alias captures declaration position")
	parse_ok("=begin\ncomment\n=end")
	parse_ok("module A\n class B\n  def self.size()\n   4\n  end\n end\nend")
	parse_ok("if a > 2\n a += 3\nelsif b\n a = 7\nelse\n a = 0\nend\na -= 1 unless false")
	parse_ok("while a < 4\n a += 1\nend\nuntil a == 8\n a += 1\nend\nfor i in 1..3\n a += i\nend")
	parse_ok("values.each do |value|\n total += value\nend\nvalues.each { |value| total += value }")
	parsed = parse_ok("a = [1, nil, false]\nb = {:name => 'hello', 2 => a[0]}\nc = \"值=#{a[0] + 2}\"\nd = %w(one two)\nr = /enemy/i")
	expect(parsed.body[1].right.kind=="hash" and parsed.body[2].right.parts[1].value.kind=="binary","collections and interpolation child nodes")
	expect(parsed.body[2].right.parts[1].value.span.line==3,"interpolation source position")
	parse_ok("begin\n work()\nrescue Error => e\n recover(e)\nelse\n done()\nensure\n close()\nend")
	parse_ok("def f()\n work()\nrescue\n nil\nensure\n close()\nend")
	parse_ok("case value\nwhen 1, 2\n :small\nwhen 3\n :large\nelse\n nil\nend")
	parsed = parse_ok("module Registry\n class << self\n  def install\n   true\n  end\n end\nend")
	expect(parsed.body[0].body[0].kind=="singleton_class" and parsed.body[0].body[0].body[0].receiver=="self","singleton class retains receiver and singleton method declaration")
	parsed = parse_ok("tag, turn = actor.skill_equiped?(id)\nvalue = missing() rescue nil")
	expect(parsed.body[0].kind=="multi_assign" and parsed.body[0].targets.size()==2 and parsed.body[1].right.kind=="rescue_modifier","parallel assignment and assignment-rescue binding")
	parsed = parse_ok("def vector\n return {1 => [2,3]}\nend\nresult = values.map do |value|\n value * 2\nend.freeze")
	expect(parsed.body[0].body[0].arguments[0].kind=="hash" and parsed.body[1].right.name=="freeze" and parsed.body[1].right.receiver.block.parameters==["value"],"return hash and chained block remain attached to assignment RHS")
	parsed = parse_ok("if obj.x and obj.ready? ID\n $game_variables[1] = $1\nend\nalias :old_index :[]\ndef -@\n self\nend\nname = :hp=\nfield = :@old")
	expect(parsed.body[0].branches[0].condition.operator=="and" and parsed.body[0].branches[0].condition.right.arguments[0].name=="ID","command call inside condition preserves low precedence and")
	expect(parsed.body[1].target=="[]" and parsed.body[2].name=="-@" and parsed.body[3].right.value=="hp=" and parsed.body[4].right.value=="@old","operator aliases, unary methods and setter/instance symbols retain exact names")
	parsed = parse_ok("def values\n return objects.map do |item|\n  item.id\n end\nend\nvalue = 1 if\n true")
	expect(parsed.body[0].body[0].arguments[0].block.parameters==["item"] and parsed.body[1].kind=="modifier","return block and continued modifier conditions retain structure")
	parsed = parse_ok("$中文变量[2] = 3\nName = 1\nname = 2")
	expect(parsed.body[0].left.receiver.name=="$中文变量" and parsed.body[0].span.column==1,"Unicode and case-sensitive identifiers")
	for source in ["if true\n1", "a = (1 + )", "a = \"unfinished", "class A\ndef f(\nend", "a = <<TEXT\ntext\nTEXT", "a = 012", "class", "class a\nend", "1 = 2", "undef foo", "unless true\n1\nelsif false\n2\nend"]:
		var bad := Parser.new().parse(source,{"name":"bad"})
		expect(not bad.ok and not bad.diagnostics.is_empty() and bad.diagnostics[0].origin.name=="bad","strict incomplete/unsupported source rejected: "+source)
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("output/0.40/first-reviewed/黎之闪翼（开发中）_Godot/legacy/ordered_scripts")
	for filename in ["0064_Skill 3.rb","0085_Game_Actors.rb","0087_Game_Troops.rb"]:
		if FileAccess.file_exists(root_path.path_join(filename)): parse_ok(FileAccess.get_file_as_string(root_path.path_join(filename)))
	for failure in failures: printerr("FAIL: ",failure)
	print("RUBY AST TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func parse_ok(source: String) -> Dictionary:
	var result := Parser.new().parse(source)
	expect(result.ok,"parse: "+source.get_slice("\n",0)+" / "+JSON.stringify(result.diagnostics))
	return result.ast

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

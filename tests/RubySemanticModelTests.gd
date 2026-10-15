extends SceneTree
const Parser = preload("res://scripts/importer/RubyParser.gd")
const Model = preload("res://scripts/importer/RubySemanticModel.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var entries: Array = []
	var sources := ["class A\n def value()\n  1\n end\nend", "class A\n alias old value\n def value(x=2)\n  y = x\n  y\n end\nend", "class B < A\n alias saved old\n def call()\n  value()\n end\nend"]
	for position in sources.size():
		var parsed := Parser.new().parse(sources[position],{"load_order":position+1,"name":"fixture"})
		entries.append({"parsed":parsed.ok,"ast":parsed.ast,"origin":parsed.ast.origin,"unit_id":"script_%d" % position,"status":"generated"})
	var model := Model.new().build(entries)
	var versions: Array = model.definitions.filter(func(d: Dictionary) -> bool: return d.owner=="A" and d.name=="value")
	var aliases: Array = model.definitions.filter(func(d: Dictionary) -> bool: return d.kind=="alias")
	expect(versions.size()==2 and versions[0].version_id!=versions[1].version_id,"all method versions retained")
	expect(aliases[0].captured_version==versions[0].version_id and aliases[1].captured_version==versions[0].version_id,"alias and inherited alias preserve original implementation")
	var calls: Array = model.references.filter(func(r: Dictionary) -> bool: return r.kind=="call" and r.name=="value")
	expect(calls.size()==1 and calls[0].definition==versions[1].version_id,"method-body call sees final inherited implementation")
	expect(model.case_sensitive and model.types.has("A") and not model.types.has("a"),"case-sensitive type identity")
	expect(model.scopes.any(func(s: Dictionary) -> bool: return s.get("name")=="value" and s.get("locals",{}).has("y")),"method local scope comes from AST")
	var parsed=Parser.new().parse("module SourceHelpers\n module_function\n def read()\n  1\n end\n def SourceHelpers.explicit()\n  2\n end\n class << self\n  alias original explicit\n  def explicit()\n   3\n  end\n end\nend",{"load_order":4})
	entries.append({"parsed":parsed.ok,"ast":parsed.ast,"origin":parsed.ast.origin,"unit_id":"script_helpers","status":"generated"})
	model=Model.new().build(entries)
	var helpers: Array=model.definitions.filter(func(d):return d.owner=="SourceHelpers")
	expect(helpers.any(func(d):return d.kind=="module_function" and d.name=="read" and d.singleton),"bare module_function records the singleton copy")
	var explicit: Array=helpers.filter(func(d):return d.name=="explicit" and d.kind=="method")
	expect(explicit.size()==2 and explicit.all(func(d):return d.singleton),"qualified and singleton-class method definitions retain their actual owner")
	var original: Array=helpers.filter(func(d):return d.name=="original" and d.kind=="alias")
	expect(original.size()==1 and original[0].singleton and original[0].captured_version==explicit[0].version_id,"singleton alias captures its previous qualified implementation")
	for failure in failures: printerr("FAIL: ",failure)
	print("RUBY SEMANTIC MODEL: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

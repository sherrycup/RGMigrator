extends SceneTree
const Compiler=preload("res://scripts/importer/RubyGDScriptCompiler.gd")
func _init() -> void:
	var paths: Array=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/v044-fixture-paths.json"))
	paths.append_array(OS.get_cmdline_user_args())
	var sources={
		"data_access":"$game_variables[8188] = [1, {\"hp\" => 20}]\n$game_variables[8188][1][\"hp\"] += 5\n$data_enemies[1].maxhp = 12345678901\n$data_enemies[1].maxhp",
		"rollback":"$game_variables[8188][0] = 9\n$data_enemies[1].maxhp = 2\n$game_party.gain_gold(100)\n1 / 0",
		"big_currency":"$game_party.gain_gold(999999999999999999999999999999999999)\n$game_party.lose_gold(123)\n$game_party.gold > 999999999999999999999999999999999000",
		"flash_attributes":"$game_actors[2].tp_plus[\"patk\"] = 37\n$game_party.gain_currency(1, 50)\n$game_party.gain_spar(17, 3)\n$game_actors[2].tp_plus[\"patk\"]",
		"data_expression":"$game_variables[8190] + 2"
	}
	for root in paths:
		DirAccess.make_dir_recursive_absolute(root.path_join(".godot/v044_generated"))
		for name in sources:
			var path="runtime/generated/data_test_expression.gd" if name=="data_expression" else ".godot/v044_generated/"+name+".gd"
			var generated=Compiler.new().compile(sources[name],{"kind":"data_test","name":name},"res://"+path)
			if not generated.ok: printerr(generated.diagnostics); quit(1); return
			DirAccess.make_dir_recursive_absolute(root.path_join(path).get_base_dir())
			var file=FileAccess.open(root.path_join(path),FileAccess.WRITE); file.store_string(generated.generated_source); file.close()
	print("CUSTOM DATA TEST PREPARATION: PASSED"); quit()

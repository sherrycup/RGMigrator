## 职责：从闪翼脚本提取玩法配置与技能定义，生成对应数据及可编辑的 GDScript 技能目录。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/GameplayImporter.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func generate(output_root: String, scripts: Array) -> Dictionary
##     用途：从已校验输入生成目标数据或工程文件。
##     参数 output_root（String；必填）：生成工程的输出根目录。
##     参数 scripts（Array；必填）：原脚本来源或脚本记录集合。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted
## Pure source-data extraction for Flash gameplay. Ruby is parsed, never executed.
const Parser = preload("RubyParser.gd")
const Values = preload("RubyDataValues.gd")
const Corrections = preload("SourceCorrections.gd")
var _methods: Dictionary = {}
var _constants: Dictionary = {}
var _config: Dictionary = {}
var _diagnostics: Array = []
var _current: Dictionary = {}


func generate(output_root: String, scripts: Array) -> Dictionary:
	_methods = {}
	_constants = {}
	_diagnostics = []
	var custom: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(output_root.path_join("data/custom_data.json"))
	)
	if custom.get("profile") != "flash":
		return {"ok": true, "applied": false}
	_constants = custom.constants.duplicate(true)
	_config = {
		"format": "rgm-flash-gameplay-v1",
		"constants": {},
		"storage": {},
		"skills": {},
		"temp_defaults": {},
		"temp_deferred": [],
		"event_attribute_values": {},
		"event_attribute_origins": [],
		"sources": [],
		"method_sources": {},
		"diagnostics": [],
		"scope":
		{"excluded_boss_orders": [274, 308], "map_system": "migrate_existing_implementation"}
	}
	for entry in scripts:
		var order = int(entry.origin.load_order)
		if order >= 274 and order <= 308:
			continue
		var adapted = Corrections.adapt(entry.source, entry.origin)
		var parsed = Parser.new().parse(adapted.source, entry.origin)
		if not parsed.ok:
			continue
		_current = entry
		_index(parsed.ast.body, "")
	for owner_method in [
		"Storage#actor_exp_next",
		"Storage#actor_init_exp",
		"Storage#actor_init_animation",
		"Storage#skill_description",
		"Storage#skill_easy_description",
		"Storage#crystal",
		"Storage#blastic_pos",
		"Storage#blastic_restrict",
		"Storage#blastic_lock",
		"Storage#blastic_echo",
		"Storage#specail_echo",
		"Storage#echo_desc",
		"Storage#actor_battle_down_recovery",
		"Storage#note_name",
		"Storage#music_name"
	]:
		var method: Dictionary = _methods.get(owner_method, {})
		if method.is_empty():
			continue
		for n in method.node.body:
			if n.kind == "return" and n.arguments.size() == 1:
				var folded = _value(n.arguments[0])
				if folded.ok:
					_config.storage[owner_method.get_slice("#", 1)] = folded.value
	var notes: Dictionary = _methods.get("Storage#note_desc", {})
	if not notes.is_empty():
		_note_descriptions(notes)
	var defaults: Dictionary = _methods.get("Storage#install_system_variables", {})
	if not defaults.is_empty():
		_data_assignments(defaults.node.body, _config.storage)
	var battle_storage: Dictionary = _methods.get("Storage#install_skill_parameters", {})
	if not battle_storage.is_empty():
		_data_assignments(battle_storage.node.body, _config.storage)
	var temp: Dictionary = _methods.get("Game_Temp#initialize", {})
	if not temp.is_empty():
		for node in temp.node.body:
			if (
				node.kind != "assign"
				or node.left.kind != "name"
				or not node.left.name.begins_with("@")
			):
				continue
			var value = _value(node.right)
			if value.ok:
				_config.temp_defaults[node.left.name.trim_prefix("@")] = value.value
			else:
				_config.temp_deferred.append(
					{
						"field": node.left.name.trim_prefix("@"),
						"origin": temp.origin,
						"span": node.span,
						"message": value.message
					}
				)
		var clear: Dictionary = _methods.get("Game_Temp#attr_addition_clear", {})
		if not clear.is_empty():
			_data_assignments(clear.node.body, _config.temp_defaults)
	var registry: Dictionary = _methods.get("BattleSystem::SkillRegistry#install_defaults!", {})
	if registry.is_empty():
		_issue("skill_registry", "SkillRegistry.install_defaults!未形成完整AST。", {}, {})
	else:
		for n in registry.node.body:
			if n.kind == "call" and n.name == "define":
				_skill(n, registry.origin)
	# Respect custom registrations after the defaults, in the source load order.
	for entry in scripts:
		if int(entry.origin.load_order) != 73:
			continue
		var parsed = Parser.new().parse(entry.source, entry.origin)
		if parsed.ok:
			for n in parsed.ast.body:
				if (
					n.kind == "call"
					and n.name == "define"
					and n.receiver.get("name") == "BattleSystem::SkillRegistry"
				):
					_skill(n, entry.origin)
	_config.constants = _constants.duplicate(true)
	_collect_name_values(output_root)
	_sync_database(output_root)
	_write_skill_catalog(output_root)
	_config.diagnostics = _diagnostics
	var file = FileAccess.open(output_root.path_join("data/flash_gameplay.json"), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["无法写入闪翼玩法来源数据。"]}
	file.store_string(JSON.stringify(_config, "\t"))
	file.close()
	return {
		"ok": _diagnostics.is_empty(),
		"applied": true,
		"errors": _diagnostics.map(func(d): return d.message),
		"skills": _config.skills.size(),
		"storage_tables": _config.storage.size(),
		"diagnostics": _diagnostics
	}


func _write_skill_catalog(root: String) -> void:
	var directory = root.path_join("runtime/generated")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_issue("skill_catalog_directory", "无法创建GDScript技能源码目录。", {}, {})
		return
	var canonical: Variant = JSON.parse_string(JSON.stringify(_config.skills))
	var lines: Array[String] = [
		"## 职责：保存从闪翼原脚本提取的技能定义，供战斗目录读取并支持继续编辑。",
		"## 调用方式：BattleCatalog 读取本文件；继续开发时可编辑 source_skills 中的技能定义。",
		"## 调用接口：static func source_skills() -> Dictionary",
		"##   参数：无。",
		"##   返回：以原技能编号字符串为键的技能定义字典；每项保留原参数、效果和来源信息。",
		"## 公开常量：INPUT_SHA，迁移时原技能配置的校验标识。",
		"## 接口说明结束。",
		"",
		"extends RefCounted",
		"## Editable original Flash skill definitions; gameplay logic lives in BattleSimulator.",
		"## Change these GDScript definitions to continue developing this Godot project.",
		"const INPUT_SHA = " + JSON.stringify(JSON.stringify(canonical).sha256_text()),
		"",
		"static func source_skills() -> Dictionary:",
		"\treturn {"
	]
	var keys: Array = _config.skills.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in keys:
		var spec: Dictionary = _config.skills[key]
		var source: Dictionary = spec.get("source", {})
		lines.append(
			(
				"\t\t# Original %04d %s, L%d; skill %s."
				% [
					int(source.get("origin", {}).get("load_order", 73)),
					str(source.get("origin", {}).get("name", "SkillRegistry")),
					int(source.get("span", {}).get("line", 1)),
					str(key)
				]
			)
		)
		var definition = JSON.stringify(spec, "\t", false).split("\n")
		lines.append("\t\t" + JSON.stringify(str(key)) + ": " + definition[0])
		for line in definition.slice(1):
			lines.append("\t\t" + line)
		lines[lines.size() - 1] += ","
	lines.append("\t}")
	var file = FileAccess.open(directory.path_join("skill_catalog.gd"), FileAccess.WRITE)
	if file == null:
		_issue("skill_catalog_write", "无法写入GDScript技能注册源码。", {}, {})
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	_config["generated_skill_catalog"] = {
		"path": "res://runtime/generated/skill_catalog.gd",
		"input_sha": JSON.stringify(canonical).sha256_text(),
		"definitions": keys.size(),
		"editable": true
	}


func _sync_database(root: String) -> void:
	# Source BattleSystem.install_cant_battle_state and SkillRegistry.sync_definition.
	var state_path = root.path_join("data/database/States.json")
	var skill_path = root.path_join("data/database/Skills.json")
	if not FileAccess.file_exists(state_path) or not FileAccess.file_exists(skill_path):
		return
	var states: Array = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	var state_id = int(_constants.get("CANT_BATTLE", 0))
	if state_id > 0:
		while states.size() <= state_id:
			states.append(null)
		if not states[state_id] is Dictionary:
			states[state_id] = {"_class": "RPG::State"}
		var state: Dictionary = states[state_id]
		if not state.has("_flash_original_fields"):
			state["_flash_original_fields"] = state.duplicate(true)
		state.id = state_id
		if state.get("name", "") == null or state.get("name", "") == "":
			state.name = "战斗不能"
		state.merge(
			{
				"zero_hp": true,
				"battle_only": false,
				"cant_get_exp": true,
				"cant_evade": true,
				"slip_damage": false,
				"nonresistance": false,
				"animation_id": 0,
				"rating": 10,
				"restriction": 4,
				"hold_turn": 0,
				"auto_release_prob": 0,
				"shock_release_prob": 0,
				"eva": 0
			},
			true
		)
		for key in [
			"hit_rate",
			"maxhp_rate",
			"maxsp_rate",
			"str_rate",
			"dex_rate",
			"agi_rate",
			"int_rate",
			"atk_rate",
			"pdef_rate",
			"mdef_rate"
		]:
			state[key] = 100
		for key in ["plus_state_set", "minus_state_set", "guard_element_set"]:
			if state.get(key) == null:
				state[key] = []
	var skills: Array = JSON.parse_string(FileAccess.get_file_as_string(skill_path))
	for key in _config.skills:
		var spec: Dictionary = _config.skills[key]
		var id = int(key)
		while skills.size() <= id:
			skills.append(null)
		if not skills[id] is Dictionary:
			skills[id] = {
				"_class": "RPG::Skill",
				"occasion": 1,
				"common_event_id": 0,
				"hit": 100,
				"variance": 15,
				"menu_se": {"name": "", "volume": 80, "pitch": 100}
			}
		var skill: Dictionary = skills[id]
		if not skill.has("_flash_original_fields"):
			skill["_flash_original_fields"] = skill.duplicate(true)
		for field in ["id", "name", "description", "icon_name", "animation1_id", "animation2_id"]:
			skill[field] = spec[field]
		skill.scope = (
			spec.scope
			if spec.scope != null
			else 2 if spec.target == "party" else 3 if spec.target == "self" else 1
		)
		skill.power = spec.stiffness
		skill.atk_f = int(float(spec.atk_rate) * 100)
		skill.sp_cost = 0
		skill.element_set = spec.element_set.duplicate()
		var element = (
			int(_constants.get("BattleSystem::TARGET_SUPPORT_ELEMENT", 31))
			if spec.target == "support"
			else (
				int(_constants.get("BattleSystem::TARGET_PARTY_ELEMENT", 32))
				if spec.target == "party"
				else 0
			)
		)
		if element > 0 and not skill.element_set.has(element):
			skill.element_set.append(element)
		skill.plus_state_set = []
		skill.minus_state_set = []
	for pair in [[state_path, states], [skill_path, skills]]:
		var file = FileAccess.open(pair[0], FileAccess.WRITE)
		if file == null:
			_issue("database_sync", "无法保存源玩法数据库同步：" + str(pair[0]), {}, {})
			continue
		file.store_string(JSON.stringify(pair[1], "", false))
		file.close()


func _collect_name_values(root: String) -> void:
	# CE23 eval(code[1]) becomes a lookup of values compiled from original event names.
	# New or changed names require migration; arbitrary runtime Ruby is never evaluated.
	var gem = RegEx.new()
	gem.compile("^宝石<(.+)>")
	if not DirAccess.dir_exists_absolute(root.path_join("data/maps")):
		return
	for filename in DirAccess.get_files_at(root.path_join("data/maps")):
		if not filename.ends_with(".json"):
			continue
		var map: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(root.path_join("data/maps").path_join(filename))
		)
		for event in map.get("events", {}).values():
			var matched = gem.search(str(event.get("name", "")))
			if matched == null:
				continue
			for code in matched.get_string(1).split(";"):
				var pair = code.split(":")
				var origin = {
					"kind": "event_name",
					"map": filename,
					"event_id": event.get("id", 0),
					"event_name": event.get("name", "")
				}
				if pair.size() != 2:
					_issue("name_attribute", "宝石名称的能力项必须为属性:值。", origin, {})
					continue
				var parsed = Values.new().parse(pair[1], origin)
				if not parsed.ok:
					_issue("name_attribute", "宝石名称的表达式未迁移：" + pair[1], origin, {})
					continue
				_config.event_attribute_values[pair[1]] = parsed.value
				_config.event_attribute_origins.append(
					{
						"origin": origin,
						"attribute": pair[0],
						"source": pair[1],
						"value": parsed.value
					}
				)


func _index(body: Array, owner: String) -> void:
	for n in body:
		if n.kind in ["class", "module"]:
			_index(n.body, n.name if owner.is_empty() else owner + "::" + n.name)
		elif n.kind == "singleton_class":
			_index(n.body, owner)
		elif n.kind == "method":
			var key = owner + "#" + n.name
			_methods[key] = {"node": n, "origin": _current.origin}
			_config.method_sources[key] = {
				"origin": _current.origin,
				"span": n.span,
				"source_sha256": str(_current.source).sha256_text()
			}
		elif (
			n.kind == "assign"
			and n.left.kind == "name"
			and not n.left.name.is_empty()
			and n.left.name[0] == n.left.name[0].to_upper()
			and n.left.name[0] != n.left.name[0].to_lower()
		):
			var value = _value(n.right)
			if value.ok:
				_constants[(owner + "::" if not owner.is_empty() else "") + n.left.name] = (
					value.value
				)
				if not _constants.has(n.left.name):
					_constants[n.left.name] = value.value
		elif n.kind in ["if", "unless"]:
			# Index definitions, not conditional runtime side effects.
			for branch in n.branches:
				_index_definitions(branch.body, owner)
			_index_definitions(n.else_body, owner)


func _index_definitions(body: Array, owner: String) -> void:
	for n in body:
		if n.kind in ["class", "module", "method", "singleton_class"]:
			_index([n], owner)


func _note_descriptions(method: Dictionary) -> void:
	# Source 0224 is a finite case of literal assignments followed by return text.
	# Keep each branch, including nil unfinished categories; never execute Ruby.
	var result: Dictionary = {}
	for node in method.node.body:
		if node.kind != "case" or node.value.get("name") != "type":
			continue
		for branch in node.branches:
			var text: Variant = null
			for statement in branch.body:
				if statement.kind != "assign" or statement.left.get("name") != "text":
					_issue("note_data", "笔记说明分支含非静态语句。", method.origin, statement.span)
					return
				var value = _value(statement.right)
				if not value.ok:
					_issue("note_data", value.message, method.origin, statement.span)
					return
				text = value.value
			for pattern in branch.patterns:
				var key = _value(pattern)
				if not key.ok or not key.value is int:
					_issue("note_data", "笔记分类不是静态整数。", method.origin, pattern.span)
					return
				result[str(key.value)] = text
	_config.storage["note_desc"] = result


func _data_assignments(body: Array, target: Dictionary) -> void:
	for n in body:
		if n.kind != "assign" or n.operator != "=":
			continue
		var value = _value(n.right)
		if not value.ok:
			_issue(
				"static_data",
				value.message,
				_methods.get("Storage#install_system_variables", {}).get("origin", {}),
				n.span
			)
			continue
		if n.left.kind == "name" and n.left.name.begins_with("@"):
			target[n.left.name.trim_prefix("@")] = value.value
		elif (
			n.left.kind == "index"
			and n.left.receiver.kind == "name"
			and n.left.arguments.size() == 1
		):
			var key = _value(n.left.arguments[0])
			var name: String = n.left.receiver.name.trim_prefix("@")
			if not key.ok or not target.has(name):
				continue
			if target[name] is Dictionary:
				target[name][str(key.value)] = value.value
			elif target[name] is Array and key.value is int and key.value >= 0:
				while target[name].size() <= key.value:
					target[name].append(null)
				target[name][key.value] = value.value


func _value(node: Dictionary) -> Dictionary:
	if node.get("kind") == "name" and not _constants.has(node.name):
		var candidates: Array = []
		for key in _constants:
			if str(key).ends_with("::" + node.name):
				candidates.append(_constants[key])
		if candidates.size() == 1:
			return {"ok": true, "value": candidates[0]}
	if node.get("kind") == "index" and node.arguments.size() == 1:
		var receiver = _value(node.receiver)
		var index = _value(node.arguments[0])
		if not receiver.ok:
			return receiver
		if not index.ok:
			return index
		if receiver.value is Array and index.value is int:
			var offset: int = (
				index.value if index.value >= 0 else receiver.value.size() + index.value
			)
			return {
				"ok": true,
				"value":
				receiver.value[offset] if offset >= 0 and offset < receiver.value.size() else null
			}
		if receiver.value is Dictionary:
			return {"ok": true, "value": receiver.value.get(str(index.value))}
	if node.get("kind") == "array":
		var array: Array = []
		for n in node.elements:
			var result = _value(n)
			if not result.ok:
				return result
			array.append(result.value)
		return {"ok": true, "value": array}
	if (
		node.get("kind") == "call"
		and node.name == "new"
		and node.receiver.get("name") in ["Color", "RPG::EventCommand"]
	):
		var args: Array = []
		for n in node.arguments:
			var result = _value(n)
			if not result.ok:
				return result
			args.append(result.value)
		if node.receiver.name == "Color":
			if args.size() < 3 or args.size() > 4:
				return {"ok": false, "message": "Color构造参数无效。"}
			return {
				"ok": true, "value": {"_flash_color": args if args.size() == 4 else args + [255]}
			}
		return {
			"ok": true,
			"value":
			{
				"code": args[0] if args.size() > 0 else 0,
				"indent": args[1] if args.size() > 1 else 0,
				"parameters": args[2] if args.size() > 2 else []
			}
		}
	var values = Values.new()
	values.constants = _constants
	var folded: Variant = values.expression(node)
	return {"ok": values.failure.is_empty(), "value": folded, "message": values.failure}


func _skill(node: Dictionary, origin: Dictionary) -> void:
	if node.arguments.size() != 1 or node.block.is_empty() or node.block.parameters.size() != 1:
		_issue("skill_define", "技能define必须有确定ID与一个定义块。", origin, node.span)
		return
	var id = _value(node.arguments[0])
	if not id.ok or not id.value is int or id.value < 0:
		_issue("skill_id", "技能ID不是已确定非负整数。", origin, node.span)
		return
	var spec = {
		"id": id.value,
		"name": str(id.value),
		"description": "",
		"icon_name": "",
		"animation1_id": 0,
		"animation2_id": 0,
		"kind": "damage",
		"target": "opponent",
		"stiffness": _constants.get("BattleSystem::DEFAULT_STIFFNESS", 20),
		"hit_count": 1,
		"atk_rate": 1.0,
		"threshold": 0,
		"instant_follow_up": false,
		"scope": null,
		"element_set": [],
		"rage_rules": [],
		"extra_attacks": 0,
		"source": {"origin": origin, "span": node.span}
	}
	for n in node.block.body:
		if (
			n.kind == "assign"
			and n.left.kind == "call"
			and n.left.receiver.get("name") == node.block.parameters[0]
		):
			var value = _value(n.right)
			if value.ok and spec.has(n.left.name):
				spec[n.left.name] = value.value
			else:
				_issue("skill_field", "技能字段未静态确定：" + str(n.left.name), origin, n.span)
			continue
		if n.kind != "call" or n.receiver.get("name") != node.block.parameters[0]:
			_issue("skill_dsl", "技能块包含未处理语句。", origin, n.span)
			continue
		var args: Array = []
		for argument in n.arguments:
			var value = _value(argument)
			if not value.ok:
				_issue("skill_argument", value.message, origin, argument.span)
				return
			args.append(value.value)
		match n.name:
			"display":
				if args.size() > 0:
					spec.name = args[0]
				if args.size() > 1:
					spec.description = args[1]
			"action":
				if args.size() < 2:
					_issue("skill_action", "action参数不足。", origin, n.span)
					continue
				spec.kind = "damage"
				spec.target = args[0]
				spec.atk_rate = args[1]
				spec.hit_count = args[2] if args.size() > 2 else 1
				spec.stiffness = args[3] if args.size() > 3 else spec.stiffness
			"follow_up_damage":
				spec.kind = "follow_up_damage"
				spec.atk_rate = args[0] if not args.is_empty() else 0.0
				spec.instant_follow_up = true
			"follow_up_counter", "follow_up_attack_count":
				if args.size() != 2:
					_issue("skill_follow", "追击参数不足。", origin, n.span)
					continue
				spec.kind = n.name
				spec.threshold = args[0]
				spec.atk_rate = args[1]
			"passive_enemy_defense_rate", "passive_attack_rate":
				if args.size() != 1:
					_issue("skill_passive", "被动参数不足。", origin, n.span)
					continue
				spec.kind = n.name
				spec.atk_rate = args[0]
				spec.target = "enemy" if n.name == "passive_enemy_defense_rate" else "self"
				if n.name == "passive_attack_rate":
					spec.stiffness = 0
			"extra_attack":
				if args.size() != 1:
					_issue("skill_extra", "额外攻击参数不足。", origin, n.span)
					continue
				spec.kind = "extra_attack"
				spec.extra_attacks = args[0]
				spec.target = "self"
				spec.stiffness = 0
			"rage":
				spec.kind = "rage"
				spec.target = "none"
				spec.stiffness = 0
				spec.rage_rules = _rage(n, origin)
			_:
				_issue("skill_dsl", "技能DSL尚未处理：" + n.name, origin, n.span)
	_config.skills[str(id.value)] = spec


func _rage(call: Dictionary, origin: Dictionary) -> Array:
	var rules: Array = []
	if call.block.is_empty() or call.block.parameters.size() != 1:
		_issue("rage_block", "rage需要一个规则定义块。", origin, call.span)
		return rules
	for n in call.block.body:
		if (
			n.kind != "call"
			or n.receiver.get("name") != call.block.parameters[0]
			or n.name != "when_patience_below"
			or n.arguments.size() not in [1, 2]
			or n.block.is_empty()
			or n.block.parameters.size() != 1
		):
			_issue("rage_rule", "狂暴规则不是确定的when_patience_below定义。", origin, n.span)
			continue
		var limit = _value(n.arguments[0])
		var description = (
			_value(n.arguments[1]) if n.arguments.size() == 2 else {"ok": true, "value": ""}
		)
		if (
			not limit.ok
			or not description.ok
			or not limit.value is int
			or limit.value < 1
			or limit.value > 100
		):
			_issue("rage_limit", "狂暴门槛必须为1—100整数。", origin, n.span)
			continue
		var rule = {
			"patience_limit": limit.value, "description": str(description.value), "effects": []
		}
		for effect in n.block.body:
			if (
				effect.kind != "call"
				or effect.receiver.get("name") != n.block.parameters[0]
				or effect.name not in ["add_skill", "replace_skill"]
				or effect.arguments.size() not in [1, 2]
			):
				_issue("rage_effect", "狂暴效果尚未处理。", origin, effect.span)
				continue
			var id = _value(effect.arguments[0])
			var options = (
				_value(effect.arguments[1])
				if effect.arguments.size() == 2
				else {"ok": true, "value": {}}
			)
			if not id.ok or not options.ok:
				_issue("rage_argument", "狂暴引用没有静态确定。", origin, effect.span)
				continue
			if effect.name == "replace_skill":
				if effect.arguments.size() != 2:
					_issue("rage_replace", "替换必须指定两个ID。", origin, effect.span)
					continue
				rule.effects.append(["override", options.value, id.value, null, null, null])
			else:
				if (
					not options.value is Dictionary
					or options.value.keys().any(
						func(k): return k not in ["turn", "default", "rating"]
					)
				):
					_issue("rage_options", "狂暴add_skill选项无效。", origin, effect.span)
					continue
				rule.effects.append(
					[
						"grant",
						id.value,
						null,
						options.value.get("turn"),
						options.value.get("default"),
						options.value.get("rating", 5)
					]
				)
		if rule.effects.is_empty():
			_issue("rage_empty", "狂暴规则必须有至少一个效果。", origin, n.span)
		rules.append(rule)
	if rules.is_empty():
		_issue("rage_empty", "狂暴技能必须有至少一个规则。", origin, call.span)
	return rules


func _issue(code: String, message: String, origin: Dictionary, span: Dictionary) -> void:
	_diagnostics.append({"code": code, "message": message, "origin": origin, "span": span})

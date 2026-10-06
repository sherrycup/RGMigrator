class_name EventInterpreter
extends RefCounted

const RuntimeData = preload("res://runtime/scripts/RuntimeData.gd")
const RuntimeVersion = preload("res://runtime/scripts/RuntimeVersion.gd")

signal message_requested(lines: Array)
signal choices_requested(choices: Array, cancel_type: int)
signal number_requested(variable_id: int, digits: int)
signal shop_requested(goods: Array)
signal diagnostic_requested(message: String)
signal completed

var map_runtime
var _commands: Array = []
var _index := 0
var _event_id := 0
var _stack: Array = []
var _branches: Dictionary = {}
var _loops: Dictionary = {}
var _waiting := ""
var _waiting_indent := 0
var _shop_command_index := 0
var _source_map_id := 0
var _page := 1
var _common_id := 0
var running := false


func start(commands: Array, event_id: int, page: int = 1) -> void:
	running = true
	_commands = commands
	_index = 0
	_event_id = event_id
	_source_map_id = RuntimeState.map_id
	_page = page
	_common_id = 0
	_stack.clear()
	_branches.clear()
	_loops.clear()
	_waiting = ""
	_run()


func resume_message() -> void:
	if _waiting != "message":
		return
	_waiting = ""
	_run()


func resume_choice(choice: int) -> void:
	if _waiting != "choice":
		return
	_branches[_waiting_indent] = choice
	_waiting = ""
	_run()


func resume_number(value: int) -> void:
	if not _waiting.begins_with("number:"):
		return
	var variable_id := int(_waiting.get_slice(":", 1))
	RuntimeState.variables[str(variable_id)] = value
	_waiting = ""
	_run()


func resume_shop() -> void:
	if _waiting != "shop":
		return
	_waiting = ""
	_run()


func reject_shop(message: String) -> void:
	_command_error(302, message, _shop_command_index)


func _show_shop(parameters: Array) -> void:
	_shop_command_index = _index
	var goods: Array = [parameters.duplicate(true)]
	while _index < _commands.size() and _commands[_index] is Dictionary and int(_commands[_index].get("code", 0)) == 605:
		var raw: Variant = _commands[_index].get("parameters", [])
		goods.append(raw.duplicate(true) if raw is Array else raw)
		_index += 1
	var parsed := preload("res://runtime/scripts/ShopService.gd").catalog(goods)
	if not parsed.ok:
		var goods_index := maxi(0, int(parsed.get("goods_index", 0)))
		_command_error(302 if goods_index == 0 else 605, parsed.message, _shop_command_index + goods_index)
		return
	_waiting = "shop"
	shop_requested.emit(goods)


func _run() -> void:
	var safety := 0
	while _waiting.is_empty() and safety < 10000:
		safety += 1
		if _index >= _commands.size():
			_finish_list()
			continue
		var command: Variant = _commands[_index]
		_index += 1
		if not (command is Dictionary):
			continue
		var code := int(command.get("code", 0))
		var indent := int(command.get("indent", 0))
		var parameters: Array = command.get("parameters", [])
		match code:
			0:
				_finish_list()
			101:
				_show_message(parameters)
			102:
				_show_choices(parameters, indent)
			103:
				_show_number(parameters)
			108, 408:
				pass
			111:
				if not _condition(parameters):
					_skip_to_else_or_end(indent)
			112:
				_loops[indent] = _index
			113:
				_skip_to_loop_end(indent)
			115:
				_stack.clear()
				_complete()
			117:
				_call_common_event(parameters)
			118:
				pass
			119:
				_jump_to_label(str(_param(parameters, 0, "")))
			121:
				_change_switches(parameters)
			122:
				_change_variables(parameters)
			123:
				_change_self_switch(parameters)
			124:
				_diagnostic(code)
			125:
				RuntimeState.gold = max(0, RuntimeState.gold + _signed_amount(parameters))
				RuntimeState.state_changed.emit()
			126, 127, 128:
				_change_inventory(code, parameters)
			129:
				_change_party(parameters)
			134:
				RuntimeState.save_disabled = int(_param(parameters, 0, 0)) == 0
			135:
				RuntimeState.menu_disabled = int(_param(parameters, 0, 0)) == 0
			207:
				if parameters.size() < 2 or map_runtime == null:
					_command_error(207, "显示动画参数或地图上下文缺失。")
				else:
					var result: Dictionary = map_runtime.play_animation(int(parameters[1]), int(parameters[0]), _event_id)
					if not result.ok:
						_command_error(207, result.message)
			318:
				if parameters.size() < 3 or int(parameters[1]) not in [0, 1]:
					_command_error(318, "增减特技参数无效。")
				else:
					var result := RuntimeState.change_skill(int(parameters[0]), int(parameters[2]), int(parameters[1]) == 0)
					if not result.ok:
						_command_error(318, result.message)
			302:
				_show_shop(parameters)
			605:
				_command_error(605, "商品续行必须紧随商店处理指令 302。")
			104, 105, 106, 136, 202, 203, 204, 205, 206, 208, 209, 210, 221, 222, 223, 224, 225, 236:
				_diagnostic(code)
			201:
				_transfer(parameters)
			231, 232, 233, 234:
				_diagnostic(code)
			235:
				if map_runtime != null:
					map_runtime.erase_picture(int(_param(parameters, 0, 0)))
			241, 245, 249, 250:
				if map_runtime != null:
					map_runtime.play_audio(code, _param(parameters, 0, {}))
			251:
				if map_runtime != null:
					map_runtime.stop_sound_effect()
			301, 303, 351, 352, 353, 355, 655:
				_diagnostic(code)
			402:
				_handle_choice_branch(parameters, indent)
			403:
				if _branches.get(indent, -1) != -1:
					_skip_to_choice_end(indent)
			404:
				_branches.erase(indent)
			411:
				_skip_to_branch_end(indent)
			412:
				_branches.erase(indent)
			413:
				_index = int(_loops.get(indent, _index))
			_:
				if code > 0:
					_diagnostic(code)
	if safety >= 10000:
		diagnostic_requested.emit("事件解释器达到安全步数上限，已中断以避免死循环。")
		_complete()


func _show_message(parameters: Array) -> void:
	var lines: Array = []
	if not parameters.is_empty() and _param(parameters, 0, "") is String:
		lines.append(str(_param(parameters, 0, "")))
	while _index < _commands.size():
		var next: Variant = _commands[_index]
		if not (next is Dictionary) or int(next.get("code", 0)) != 401:
			break
		var continuation: Array = next.get("parameters", [])
		lines.append(str(_param(continuation, 0, "")))
		_index += 1
	if lines.is_empty():
		lines.append("")
	_waiting = "message"
	message_requested.emit(lines)


func _show_choices(parameters: Array, indent: int) -> void:
	var choices: Array = _param(parameters, 0, [])
	_waiting = "choice"
	_waiting_indent = indent
	choices_requested.emit(choices, int(_param(parameters, 1, -1)))


func _show_number(parameters: Array) -> void:
	var variable_id := int(_param(parameters, 0, 0))
	_waiting = "number:%d" % variable_id
	number_requested.emit(variable_id, int(_param(parameters, 1, 1)))


func _condition(parameters: Array) -> bool:
	var type := int(_param(parameters, 0, -1))
	match type:
		0:
			var expected := int(_param(parameters, 2, 0)) == 0
			return bool(RuntimeState.switches.get(str(_param(parameters, 1, 0)), false)) == expected
		1:
			var left := int(RuntimeState.variables.get(str(_param(parameters, 1, 0)), 0))
			var right := int(_param(parameters, 3, 0))
			if int(_param(parameters, 2, 0)) == 1:
				right = int(RuntimeState.variables.get(str(right), 0))
			match int(_param(parameters, 4, 0)):
				0: return left == right
				1: return left >= right
				2: return left <= right
				3: return left > right
				4: return left < right
				5: return left != right
		2:
			return bool(RuntimeState.self_switches.get(RuntimeState.self_switch_key(_source_map_id, _event_id, str(_param(parameters, 1, "A"))), false)) == (int(_param(parameters, 2, 0)) == 0)
		4:
			if parameters.size() >= 4 and int(parameters[2]) == 2:
				var actor_id := int(parameters[1])
				var skill_id := int(parameters[3])
				if RuntimeData.record("Actors", actor_id).is_empty() or RuntimeData.record("Skills", skill_id).is_empty():
					_command_error(111, "条件分支引用无效：Actors[%d] / Skills[%d]。" % [actor_id, skill_id])
					return false
				return RuntimeState.has_skill(actor_id, skill_id)
			_diagnostic(111)
		_:
			_diagnostic(111)
			return false
	return false


func _change_switches(parameters: Array) -> void:
	var value := int(_param(parameters, 2, 0)) == 0
	for switch_id in range(int(_param(parameters, 0, 0)), int(_param(parameters, 1, 0)) + 1):
		RuntimeState.switches[str(switch_id)] = value


func _command_error(code: int, reason: String, command_index: int = -1) -> void:
	_waiting = "diagnostic"
	diagnostic_requested.emit("Map%03d / 事件 %d / 第 %d 页 / 公共事件 %d / 第 %d 条指令 %d：%s" % [_source_map_id, _event_id, _page, _common_id, _index if command_index < 0 else command_index, code, reason])
	_complete()


func _change_variables(parameters: Array) -> void:
	var start := int(_param(parameters, 0, 0))
	var finish := int(_param(parameters, 1, start))
	var operation := int(_param(parameters, 2, 0))
	var operand := int(_param(parameters, 4, 0))
	if int(_param(parameters, 3, 0)) == 1:
		operand = int(RuntimeState.variables.get(str(operand), 0))
	elif int(_param(parameters, 3, 0)) == 2:
		operand = randi_range(operand, int(_param(parameters, 5, operand)))
	elif int(_param(parameters, 3, 0)) != 0:
		_diagnostic(122)
		return
	for variable_id in range(start, finish + 1):
		var current := int(RuntimeState.variables.get(str(variable_id), 0))
		match operation:
			0: current = operand
			1: current += operand
			2: current -= operand
			3: current *= operand
			4: current = int(current / operand) if operand != 0 else current
			5: current = current % operand if operand != 0 else current
		RuntimeState.variables[str(variable_id)] = current


func _change_self_switch(parameters: Array) -> void:
	var key := RuntimeState.self_switch_key(_source_map_id, _event_id, str(_param(parameters, 0, "A")))
	RuntimeState.self_switches[key] = int(_param(parameters, 1, 0)) == 0


func _signed_amount(parameters: Array) -> int:
	var amount := int(_param(parameters, 2, _param(parameters, 1, 0)))
	if int(_param(parameters, 1, 0)) == 1:
		amount = int(RuntimeState.variables.get(str(amount), 0))
	return -amount if int(_param(parameters, 0, 0)) == 1 else amount


func _change_inventory(code: int, parameters: Array) -> void:
	var kind := "item" if code == 126 else ("weapon" if code == 127 else "armor")
	var key := "%s:%d" % [kind, int(_param(parameters, 0, 0))]
	RuntimeState.inventory[key] = clampi(int(RuntimeState.inventory.get(key, 0)) + _signed_amount(parameters.slice(1)), 0, 99)


func _change_party(parameters: Array) -> void:
	var actor_id := int(_param(parameters, 0, 0))
	RuntimeState.change_party(actor_id, int(_param(parameters, 1, 0)) == 0, int(_param(parameters, 2, 0)) == 1)


func _transfer(parameters: Array) -> void:
	if map_runtime == null:
		return
	var map_id := int(_param(parameters, 1, RuntimeState.map_id))
	var x := int(_param(parameters, 2, RuntimeState.player_x))
	var y := int(_param(parameters, 3, RuntimeState.player_y))
	if int(_param(parameters, 0, 0)) == 1:
		map_id = int(RuntimeState.variables.get(str(map_id), 0))
		x = int(RuntimeState.variables.get(str(x), 0))
		y = int(RuntimeState.variables.get(str(y), 0))
	if not map_runtime.transfer(map_id, x, y):
		diagnostic_requested.emit("传送失败：Map%03d 不存在或无法读取。" % map_id)
		_complete()


func _call_common_event(parameters: Array) -> void:
	var common_events: Variant = RuntimeData.database("CommonEvents")
	if not (common_events is Array):
		common_events = RuntimeData.database("CommonEvent")
	var id := int(_param(parameters, 0, 0))
	if not (common_events is Array) or id < 0 or id >= common_events.size() or not (common_events[id] is Dictionary):
		diagnostic_requested.emit("公共事件 %d 不存在。" % id)
		_complete()
		return
	if _stack.size() >= 32:
		_diagnostic(117)
		return
	_stack.append({"commands": _commands, "index": _index, "event_id": _event_id, "branches": _branches, "loops": _loops, "common_id": _common_id})
	_commands = common_events[id].get("list", [])
	_index = 0
	_branches = {}
	_loops = {}
	_common_id = id


func _jump_to_label(label: String) -> void:
	for index in _commands.size():
		var candidate: Variant = _commands[index]
		if candidate is Dictionary and int(candidate.get("code", 0)) == 118:
			if str(_param(candidate.get("parameters", []), 0, "")) == label:
				_index = index + 1
				return


func _handle_choice_branch(parameters: Array, indent: int) -> void:
	if int(_param(parameters, 0, -1)) != int(_branches.get(indent, -1)):
		_skip_to_next_choice_branch(indent)


func _skip_to_else_or_end(indent: int) -> void:
	while _index < _commands.size():
		var candidate: Variant = _commands[_index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) in [411, 412]:
			_index += 1
			return
		_index += 1


func _skip_to_branch_end(indent: int) -> void:
	while _index < _commands.size():
		var candidate: Variant = _commands[_index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) == 412:
			_index += 1
			return
		_index += 1


func _skip_to_loop_end(indent: int) -> void:
	var loop_indent := -1
	for key in _loops:
		if int(key) < indent and int(key) > loop_indent:
			loop_indent = int(key)
	while _index < _commands.size():
		var candidate: Variant = _commands[_index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == loop_indent and int(candidate.get("code", 0)) == 413:
			_index += 1
			_loops.erase(loop_indent)
			return
		_index += 1


func _skip_to_next_choice_branch(indent: int) -> void:
	while _index < _commands.size():
		var candidate: Variant = _commands[_index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) in [402, 403, 404]:
			return
		_index += 1


func _skip_to_choice_end(indent: int) -> void:
	while _index < _commands.size():
		var candidate: Variant = _commands[_index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) == 404:
			_index += 1
			return
		_index += 1


func _finish_list() -> void:
	if _stack.is_empty():
		_complete()
		return
	var frame: Dictionary = _stack.pop_back()
	_commands = frame["commands"]
	_index = int(frame["index"])
	_event_id = int(frame["event_id"])
	_branches = frame["branches"]
	_loops = frame["loops"]
	_common_id = int(frame["common_id"])


func _diagnostic(code: int) -> void:
	var names := {301: "战斗处理", 302: "商店处理", 303: "姓名输入", 351: "菜单", 352: "存档", 353: "游戏结束", 355: "Ruby 脚本", 655: "Ruby 脚本续行"}
	var location := "Map%03d / 事件 %d / 第 %d 页" % [_source_map_id, _event_id, _page]
	if _common_id > 0:
		location += " / 公共事件 %d" % _common_id
	diagnostic_requested.emit("%s / 第 %d 条命令：%s 不支持指令 %d（%s）或其参数。该事件已中断。" % [location, _index, RuntimeVersion.VERSION, code, names.get(code, "未实现")])
	_complete()


func _complete() -> void:
	running = false
	_waiting = "completed"
	_commands = []
	_index = 0
	completed.emit()


func _param(parameters: Array, index: int, fallback: Variant) -> Variant:
	return parameters[index] if index >= 0 and index < parameters.size() else fallback

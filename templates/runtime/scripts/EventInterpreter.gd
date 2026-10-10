class_name EventInterpreter
extends RefCounted

const RuntimeData = preload("res://runtime/scripts/RuntimeData.gd")
const RuntimeVersion = preload("res://runtime/scripts/RuntimeVersion.gd")
const Values = preload("res://runtime/scripts/EventValueResolver.gd")
const Catalog = preload("res://runtime/scripts/EventCommandCatalog.gd")

signal message_requested(lines: Array)
signal choices_requested(choices: Array, cancel_type: int)
signal number_requested(variable_id: int, digits: int)
signal dialogue_requested(payload: Dictionary)
signal button_requested(variable_id: int)
signal shop_requested(goods: Array)
signal name_requested(actor_id: int, maximum: int)
signal menu_requested
signal save_requested
signal scene_requested(kind: String)
signal diagnostic_requested(message: String)
signal completed

var map_runtime
var context: RefCounted = preload("res://runtime/scripts/EventExecutionContext.gd").new()
var wait_state: RefCounted = preload("res://runtime/scripts/EventWait.gd").new()
var managed := false
var common_events: Variant = null
var _executing := false
var running := false
var _choice_count := 0
var _choice_cancel := 0
var _number_digits := 1
var _run_id := 0
var _name_actor_id := 0
var _name_maximum := 12
var _transfer_game: WeakRef
var _transfer_request := 0
var _transfer_command := 0
var _route_wait_warned := false
var _screen_game: WeakRef
var _screen_request := 0
var _screen_capture_request := 0
var _screen_command := 0
var _screen_command_index := 0


func start(commands: Array, event_id: int, page: int = 1) -> void:
	if running: cancel()
	_run_id += 1
	_screen_game = null
	_screen_request = 0
	_screen_capture_request = 0
	_transfer_game = null
	_transfer_request = 0
	context.setup(commands, event_id, RuntimeState.map_id, page)
	wait_state.clear()
	running = true
	if not managed: _run()


func resume_message(token: int = -1) -> void:
	if not running or not wait_state.accepts("message", token):
		return
	wait_state.clear()
	if not managed: _run()


func resume_choice(choice: int, token: int = -1) -> void:
	if not running or not wait_state.accepts("choice", token):
		return
	if choice < 0 and not (choice == -1 and _choice_cancel == 5): return
	if choice >= _choice_count: return
	context.branches[context.waiting_indent] = choice
	wait_state.clear()
	if not managed: _run()


func resume_number(value: int, token: int = -1) -> void:
	if not running or not wait_state.kind.begins_with("number:") or not wait_state.accepts(wait_state.kind, token):
		return
	var variable_id := int(wait_state.kind.get_slice(":", 1))
	if value < 0 or value >= int(pow(10, _number_digits)): return
	RuntimeState.set_event_variable(variable_id, value)
	wait_state.clear()
	if not managed: _run()


func resume_button(code: int, token: int = -1) -> void:
	if not running or not wait_state.kind.begins_with("button:") or not wait_state.accepts(wait_state.kind, token): return
	if not preload("res://runtime/scripts/EventInput.gd").ACTIONS.has(code): return
	RuntimeState.set_event_variable(int(wait_state.kind.get_slice(":", 1)), code)
	wait_state.clear()
	if not managed: _run()


func resume_shop(token: int = -1) -> void:
	if not running or not wait_state.accepts("shop", token):
		return
	wait_state.clear()
	if not managed: _run()


func advance(delta: float, budget: int = 256) -> int:
	if not running or delta < 0 or not is_finite(delta): return 0
	_advance_conditions()
	if not running: return 0
	wait_state.advance(delta)
	if not wait_state.kind.is_empty(): return 0
	return _run(budget) if budget > 0 else 0


func cancel() -> void:
	var screen_game: Node = _screen_game.get_ref() if _screen_game != null else null
	if screen_game != null:
		if _screen_request > 0: screen_game.cancel_event_screen_transition(_screen_request)
		elif _screen_capture_request > 0: screen_game.cancel_event_screen_transition(_screen_capture_request)
	_run_id += 1
	running = false
	wait_state.clear()
	context.commands = []
	context.stack = []
	_transfer_game = null
	_transfer_request = 0
	_screen_game = null
	_screen_request = 0
	_screen_capture_request = 0


func _advance_conditions() -> void:
	if wait_state.kind in ["screen_ready", "screen_transition"]:
		var game: Node = _screen_game.get_ref() if _screen_game != null else null
		if game == null:
			_command_error(_screen_command, "画面过渡的场景已关闭。", _screen_command_index)
		elif wait_state.kind == "screen_ready":
			if game.event_screen_transition_ready(): wait_state.clear()
		else:
			var result: Dictionary = game.event_screen_transition_status(_screen_request)
			if result.get("pending", false): return
			if not result.ok: _command_error(_screen_command, result.message, _screen_command_index)
			else:
				_screen_capture_request = _screen_request if _screen_command == 221 else 0
				_screen_request = 0
				wait_state.clear()
	elif wait_state.kind == "scroll_ready":
		if map_runtime == null or RuntimeState.game() == null: _command_error(203, "滚图的地图上下文已失效。")
		elif RuntimeState.map_view.scroll_remaining <= 0: wait_state.clear()
	elif wait_state.kind == "routes":
		if map_runtime == null:
			_command_error(210, "移动等待的地图上下文已失效。")
		elif not map_runtime.has_forced_routes(): wait_state.clear()
		elif not _route_wait_warned and not map_runtime.repeating_forced_routes().is_empty():
			_route_wait_warned = true
			RuntimeState.report_diagnostic("%s / 指令210：人物%s使用重复强制路线，将持续等待；不会自动跳过。" % [context.location(), str(map_runtime.repeating_forced_routes())])
	elif wait_state.kind == "transfer_ready":
		var game: Node = _transfer_game.get_ref() if _transfer_game != null else null
		if game == null: _command_error(201, "场所移动的场景已关闭。", _transfer_command)
		elif game.event_transfer_ready(): wait_state.clear()
	elif wait_state.kind == "transfer":
		var game: Node = _transfer_game.get_ref() if _transfer_game != null else null
		if game == null:
			_command_error(201, "场所移动的场景已关闭。", _transfer_command)
			return
		var result: Dictionary = game.event_transfer_status(_transfer_request)
		if result.get("pending", false): return
		if not result.ok: _command_error(201, result.message, _transfer_command)
		else:
			_transfer_request = 0
			wait_state.clear()


func wait_token() -> int:
	return wait_state.token


func wait_kind() -> String:
	return wait_state.kind


func reject_shop(message: String) -> void:
	_command_error(302, message, context.shop_command_index)


func _show_shop(parameters: Array) -> void:
	context.shop_command_index = context.index
	var goods: Array = [parameters.duplicate(true)]
	while context.index < context.commands.size() and context.commands[context.index] is Dictionary and int(context.commands[context.index].get("code", 0)) == 605:
		var raw: Variant = context.commands[context.index].get("parameters", [])
		goods.append(raw.duplicate(true) if raw is Array else raw)
		context.index += 1
	var parsed := preload("res://runtime/scripts/ShopService.gd").catalog(goods)
	if not parsed.ok:
		var goods_index := maxi(0, int(parsed.get("goods_index", 0)))
		_command_error(302 if goods_index == 0 else 605, parsed.message, context.shop_command_index + goods_index)
		return
	wait_state.begin("shop")
	shop_requested.emit(goods)


func _run(budget: int = 256) -> int:
	if _executing or not running: return 0
	_executing = true
	var safety := 0
	while running and wait_state.kind.is_empty() and safety < budget:
		if context.source_map_id != RuntimeState.map_id: context.event_id = 0
		if map_runtime != null: map_runtime.flush_event_refresh()
		if not running: break
		safety += 1
		if context.index >= context.commands.size():
			_finish_list()
			continue
		var command: Variant = context.commands[context.index]
		context.index += 1
		if not (command is Dictionary):
			_command_error(0, "命令记录不是Dictionary。")
			break
		var code := int(command.get("code", 0))
		var indent := int(command.get("indent", 0))
		var raw_parameters: Variant = command.get("parameters", [])
		if not raw_parameters is Array:
			_command_error(code, "命令参数不是Array。")
			break
		var parameters: Array = raw_parameters
		var unsupported := preload("res://runtime/scripts/EventCommandCatalog.gd").reason(code, parameters)
		if not unsupported.is_empty():
			_command_error(code, unsupported)
			break
		match code:
			0:
				# RM editor inserts blank 0 commands inside branches. Only the final
				# terminator ends the list; internal blanks are no-ops.
				if context.index >= context.commands.size(): _finish_list()
			101:
				_show_message(parameters)
			102:
				_show_choices(parameters, indent)
			103:
				_show_number(parameters)
			104:
				RuntimeState.message_position = int(parameters[0])
				RuntimeState.message_frame = int(parameters[1])
			105:
				wait_state.begin("button:%d" % int(parameters[0]))
				button_requested.emit(int(parameters[0]))
			106:
				if float(parameters[0]) > 0: wait_state.begin("time", float(parameters[0]) / 20.0)
			108, 408:
				pass
			111:
				if not _condition(parameters):
					_skip_to_else_or_end(indent)
			112:
				context.loops[indent] = context.index
			113:
				_skip_to_loop_end(indent)
			115:
				_finish_list()
			116:
				if map_runtime != null and context.event_id > 0:
					var erased: Dictionary = map_runtime.erase_event(context.event_id)
					if not erased.ok: _command_error(116, erased.message)
				# Native erase yields one update, but the main list continues.
				break
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
				if int(parameters[0]) == 0: RuntimeState.timer.start(int(parameters[1]))
				else: RuntimeState.timer.stop()
			125:
				RuntimeState.gold = clampi(RuntimeState.gold + _signed_amount(parameters), 0, 9999999)
				RuntimeState.state_changed.emit()
			126, 127, 128:
				_change_inventory(code, parameters)
			129, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322:
				_actor_event(code, parameters)
			134:
				RuntimeState.save_disabled = int(_param(parameters, 0, 0)) == 0
			135:
				RuntimeState.menu_disabled = int(_param(parameters, 0, 0)) == 0
			202:
				_set_event_position(parameters)
			207:
				if parameters.size() < 2 or map_runtime == null:
					_command_error(207, "显示动画参数或地图上下文缺失。")
				else:
					var result: Dictionary = map_runtime.play_animation(int(parameters[1]), int(parameters[0]), context.event_id)
					if not result.ok:
						_command_error(207, result.message)
			208:
				var result: Dictionary = RuntimeState.configure_player({"transparent": int(parameters[0]) == 0})
				if not result.ok: _command_error(208, result.message)
			209:
				_set_move_route(parameters)
			210:
				if map_runtime == null: _command_error(210, "移动等待缺少地图上下文。")
				elif map_runtime.has_forced_routes():
					_route_wait_warned = false
					wait_state.begin("routes")
					_advance_conditions()
			509:
				_command_error(509, "移动路线续行必须紧随209且匹配其路线；不能单独执行。")
			302:
				_show_shop(parameters)
			605:
				_command_error(605, "商品续行必须紧随商店处理指令 302。")
			136:
				_diagnostic(code)
			201:
				_transfer(parameters)
			221, 222:
				_screen_transition(code, parameters)
			223, 224, 225, 231, 232, 233, 234, 235, 236:
				_screen_effect(code, parameters)
			131, 203, 204, 205, 206, 241, 242, 245, 246, 247, 248, 249, 250, 251:
				_presentation(code, parameters)
			303:
				if RuntimeData.record("Actors", int(parameters[0])).is_empty(): _command_error(303, "姓名输入角色不存在。")
				else:
					_name_actor_id = int(parameters[0])
					_name_maximum = int(parameters[1])
					wait_state.begin("name")
					name_requested.emit(int(parameters[0]), int(parameters[1]))
			351:
				wait_state.begin("menu")
				menu_requested.emit()
			352:
				wait_state.begin("save")
				save_requested.emit()
			353, 354:
				_request_scene("gameover" if code == 353 else "title")
			301, 355, 655:
				_diagnostic(code)
			402:
				_handle_choice_branch(parameters, indent)
			403:
				if context.branches.get(indent, -1) != -1:
					_skip_to_choice_end(indent)
			404:
				context.branches.erase(indent)
			411:
				_skip_to_branch_end(indent)
			412:
				context.branches.erase(indent)
			413:
				if not context.loops.has(indent): _command_error(413, "循环结束缺少同级循环开始。")
				else: context.index = int(context.loops[indent])
			_:
				if code > 0:
					_diagnostic(code)
	_executing = false
	if map_runtime != null: map_runtime.flush_event_refresh()
	return safety


func _screen_transition(code: int, parameters: Array) -> void:
	var game: Node = RuntimeState.game()
	if game == null or game.event_map() != map_runtime:
		_command_error(code, "画面过渡需要当前正式地图场景。")
		return
	_screen_game = weakref(game)
	_screen_command = code
	_screen_command_index = context.index
	var result: Dictionary = game.begin_event_screen_transition(code, "" if code == 221 else str(parameters[0]))
	if not result.ok:
		if result.get("busy", false):
			context.index -= 1
			wait_state.begin("screen_ready")
		else: _command_error(code, result.message)
		return
	_screen_request = int(result.id)
	wait_state.begin("screen_transition")


func resume_scene_ui(kind: String, value: Variant = null, token: int = -1) -> void:
	if kind not in ["menu", "name", "save"] or not running or not wait_state.accepts(kind, token): return
	if kind == "name":
		if not value is String or value.is_empty() or value.length() > _name_maximum: return
		var result: Dictionary = RuntimeState.rename_actor(_name_actor_id, value)
		if not result.ok:
			reject_scene_ui(kind, result.message)
			return
	wait_state.clear()
	if not managed: _run()

func reject_scene_ui(kind: String, message: String) -> void:
	_command_error(303 if kind == "name" else (352 if kind == "save" else 351), message)

func _actor_event(code: int, p: Array) -> void:
	var result: Dictionary = RuntimeState.apply_actor_event(code, p)
	if not result.ok: _command_error(code, result.message)
	elif result.get("gameover", false): _request_scene("gameover")

func _request_scene(kind: String) -> void:
	if RuntimeState.game() == null:
		_command_error(353 if kind == "gameover" else 354, "场景切换缺少正式地图场景。")
		return
	wait_state.begin("scene")
	scene_requested.emit(kind)

func _presentation(code: int, p: Array) -> void:
	var result := {"ok": true}
	match code:
		131: result = RuntimeState.set_windowskin(p[0])
		203:
			if map_runtime == null or RuntimeState.game() == null: result = {"ok": false, "message": "滚图缺少正式地图上下文。"}
			elif RuntimeState.map_view.scroll_remaining > 0:
				context.index -= 1
				wait_state.begin("scroll_ready")
			else: result = RuntimeState.scroll_map_native(int(p[0]), int(p[1]), int(p[2]))
		204:
			var changes := {"panorama_name": p[1], "panorama_hue": p[2]} if int(p[0]) == 0 else {"fog_name": p[1], "fog_hue": p[2], "fog_opacity": p[3], "fog_blend_type": p[4], "fog_zoom": p[5], "fog_sx": p[6], "fog_sy": p[7]}
			result = RuntimeState.configure_map_effects(changes)
		205: result = RuntimeState.map_effects.tint_fog(Catalog.color_values(p[0]), float(p[1]) / 20.0)
		206: result = RuntimeState.map_effects.fade_fog(p[0], float(p[1]) / 20.0)
		241, 245, 249, 250: result = RuntimeState.audio.play({241: "BGM", 245: "BGS", 249: "ME", 250: "SE"}[code], p[0])
		242, 246: result = RuntimeState.audio.fade_out("BGM" if code == 242 else "BGS", p[0])
		247: RuntimeState.audio.memorize()
		248: result = RuntimeState.audio.restore_memory()
		251: RuntimeState.audio.stop("SE")
	if not result.ok: _command_error(code, result.message)

func _screen_effect(code: int, p: Array) -> void:
	var result := {"ok": true}
	match code:
		223: result = RuntimeState.screen.start_tone_change(Catalog.color_values(p[0]), float(p[1]) / 20.0)
		224: result = RuntimeState.screen.start_flash(Catalog.color_values(p[0], false), float(p[1]) / 20.0)
		225: result = RuntimeState.screen.start_shake(float(p[0]) * 2.0, float(p[1]) / 2.0, float(p[2]) / 20.0)
		236: result = RuntimeState.screen.weather(int(p[0]), p[1], float(p[2]) / 40.0)
		235: result = RuntimeState.erase_picture(int(p[0]))
		231, 232:
			var x: Variant = p[4] if int(p[3]) == 0 else RuntimeState.variables.get(str(int(p[4])), 0)
			var y: Variant = p[5] if int(p[3]) == 0 else RuntimeState.variables.get(str(int(p[5])), 0)
			if not preload("res://runtime/scripts/PictureState.gd").numeric(x, -1000000, 1000000) or not preload("res://runtime/scripts/PictureState.gd").numeric(y, -1000000, 1000000):
				_command_error(code, "图片坐标变量不是有效数值，原图片保持。")
				return
			var pose := {"origin": int(p[2]), "x": x, "y": y, "zoom_x": p[6], "zoom_y": p[7], "opacity": p[8], "blend_type": int(p[9])}
			if code == 231: result = RuntimeState.erase_picture(int(p[0])) if str(p[1]).is_empty() else RuntimeState.show_picture(int(p[0]), p[1], pose)
			elif RuntimeState.screen.picture(int(p[0])) != null: result = RuntimeState.move_picture(int(p[0]), pose, float(p[1]) / 20.0)
		233: if RuntimeState.screen.picture(int(p[0])) != null: result = RuntimeState.rotate_picture(int(p[0]), float(p[1]) * 20.0)
		234: if RuntimeState.screen.picture(int(p[0])) != null: result = RuntimeState.tint_picture(int(p[0]), Catalog.color_values(p[1]), float(p[2]) / 20.0)
	if not result.ok: _command_error(code, result.message)


func _show_message(parameters: Array) -> void:
	var lines: Array = [parameters[0]]
	while context.index < context.commands.size():
		var next: Variant = context.commands[context.index]
		if not next is Dictionary or int(next.get("code", 0)) != 401: break
		var raw: Variant = next.get("parameters", [])
		var reason := Catalog.reason(401, raw) if raw is Array else "文章续行参数不是数组。"
		if not reason.is_empty():
			_command_error(401, reason, context.index + 1)
			return
		lines.append(raw[0])
		context.index += 1
	if context.index < context.commands.size() and context.commands[context.index] is Dictionary:
		var next: Dictionary = context.commands[context.index]
		var code := int(next.get("code", 0))
		var p: Variant = next.get("parameters", [])
		if code in [102, 103] and p is Array and Catalog.supported(code, p):
			if (code == 102 and p[0].size() <= 4 - lines.size()) or (code == 103 and lines.size() < 4):
				context.index += 1
				if code == 102: _show_choices(p, int(next.get("indent", 0)), lines)
				else: _show_number(p, lines)
				return
	wait_state.begin("message")
	message_requested.emit(lines)


func _show_choices(parameters: Array, indent: int, lines: Array = []) -> void:
	_choice_count = parameters[0].size()
	_choice_cancel = int(parameters[1])
	wait_state.begin("choice")
	context.waiting_indent = indent
	if lines.is_empty(): choices_requested.emit(parameters[0], _choice_cancel)
	else: dialogue_requested.emit({"kind": "choice", "lines": lines, "choices": parameters[0], "cancel": _choice_cancel, "position": RuntimeState.message_position, "frame": RuntimeState.message_frame})


func _show_number(parameters: Array, lines: Array = []) -> void:
	var variable_id := int(parameters[0])
	_number_digits = int(parameters[1])
	wait_state.begin("number:%d" % variable_id)
	if lines.is_empty(): number_requested.emit(variable_id, _number_digits)
	else: dialogue_requested.emit({"kind": "number", "lines": lines, "variable": variable_id, "digits": _number_digits, "position": RuntimeState.message_position, "frame": RuntimeState.message_frame})


func _condition(parameters: Array) -> bool:
	var result := Values.condition(parameters, map_runtime, context.event_id)
	if not result.ok:
		_command_error(111, result.message)
		return false
	return result.value


func _change_switches(parameters: Array) -> void:
	var value := int(_param(parameters, 2, 0)) == 0
	for switch_id in range(int(_param(parameters, 0, 0)), int(_param(parameters, 1, 0)) + 1):
		RuntimeState.set_event_switch(switch_id, value)


func _command_error(code: int, reason: String, command_index: int = -1) -> void:
	diagnostic_requested.emit("%s：%s 第 %d 条指令 %d：%s" % [context.location(), RuntimeVersion.VERSION, context.index if command_index < 0 else command_index, code, reason])
	_complete()


func _change_variables(parameters: Array) -> void:
	# Resolve once before touching any target: ranges share one random draw.
	var operand := Values.operand(parameters, map_runtime, context.event_id)
	if not operand.ok:
		_command_error(122, operand.message)
		return
	for variable_id in range(int(parameters[0]), int(parameters[1]) + 1):
		var current := int(RuntimeState.variables.get(str(variable_id), 0))
		RuntimeState.set_event_variable(variable_id, Values.calculate(current, int(parameters[2]), operand.value))


func _change_self_switch(parameters: Array) -> void:
	if context.event_id <= 0: return
	RuntimeState.set_event_self_switch(RuntimeState.map_id, context.event_id, str(_param(parameters, 0, "A")), int(_param(parameters, 1, 0)) == 0)


func _signed_amount(parameters: Array) -> int:
	var amount := int(_param(parameters, 2, _param(parameters, 1, 0)))
	if int(_param(parameters, 1, 0)) == 1:
		amount = int(RuntimeState.variables.get(str(amount), 0))
	return -amount if int(_param(parameters, 0, 0)) == 1 else amount


func _change_inventory(code: int, parameters: Array) -> void:
	var kind: String = {126: "item", 127: "weapon", 128: "armor"}[code]
	var database: String = {126: "Items", 127: "Weapons", 128: "Armors"}[code]
	var id := int(parameters[0])
	if RuntimeData.record(database, id).is_empty():
		_command_error(code, "%s[%d] 不存在，未修改库存。" % [database, id])
		return
	var key := "%s:%d" % [kind, id]
	RuntimeState.inventory[key] = clampi(int(RuntimeState.inventory.get(key, 0)) + _signed_amount(parameters.slice(1)), 0, 99)
	RuntimeState.state_changed.emit()


func _change_party(parameters: Array) -> void:
	RuntimeState.change_party(int(_param(parameters, 0, 0)), int(_param(parameters, 1, 0)) == 0, int(_param(parameters, 2, 0)) == 1)


func _transfer(parameters: Array) -> void:
	if map_runtime == null:
		_command_error(201, "传送缺少地图上下文。")
		return
	var map_id := int(_param(parameters, 1, RuntimeState.map_id))
	var x := int(_param(parameters, 2, RuntimeState.player_x))
	var y := int(_param(parameters, 3, RuntimeState.player_y))
	if int(_param(parameters, 0, 0)) == 1:
		for id in [map_id, x, y]:
			if not preload("res://runtime/scripts/ActorParameters.gd").integer(RuntimeState.variables.get(str(id), 0)):
				_command_error(201, "传送变量须为整数，未换图。")
				return
		map_id = int(RuntimeState.variables.get(str(map_id), 0))
		x = int(RuntimeState.variables.get(str(x), 0))
		y = int(RuntimeState.variables.get(str(y), 0))
	var direction := int(parameters[4])
	var game: Node = RuntimeState.game()
	if game != null and game.event_map() == map_runtime:
		_transfer_game = weakref(game)
		_transfer_command = context.index
		var result: Dictionary = game.begin_event_transfer(map_id, x, y, direction, int(parameters[5]) == 0)
		if result.get("busy", false):
			context.index -= 1
			wait_state.begin("transfer_ready")
		elif not result.ok: _command_error(201, result.message)
		else:
			_transfer_request = int(result.id)
			wait_state.begin("transfer")
	else:
		if int(parameters[5]) == 0: _command_error(201, "有淡化的场所移动需要正式地图场景与真实渲染。")
		elif not map_runtime.transfer(map_id, x, y, direction): _command_error(201, "传送地图或坐标无效。")
		else: wait_state.begin("time", 0)


func _set_event_position(p: Array) -> void:
	if map_runtime == null:
		_command_error(202, "事件位置缺少地图上下文。")
		return
	var x := int(p[2])
	var y := int(p[3])
	if int(p[1]) == 1:
		for id in [x, y]:
			if not preload("res://runtime/scripts/ActorParameters.gd").integer(RuntimeState.variables.get(str(id), 0)):
				_command_error(202, "位置变量须为整数，未修改位置。")
				return
		x = int(RuntimeState.variables.get(str(x), 0))
		y = int(RuntimeState.variables.get(str(y), 0))
	var result: Dictionary = map_runtime.set_character_position(int(p[0]), int(p[1]), x, y, int(p[4]), context.event_id)
	if not result.ok: _command_error(202, result.message)


func _set_move_route(p: Array) -> void:
	if map_runtime == null:
		_command_error(209, "移动路线缺少地图上下文。")
		return
	var character: Node = map_runtime.animation_target(int(p[0]), context.event_id)
	if character == null:
		_command_error(209, "路线目标人物%d不存在。" % int(p[0]))
		return
	var route: Dictionary = p[1]
	var continuation: int = context.index
	var route_index := 0
	while continuation < context.commands.size():
		var command: Variant = context.commands[continuation]
		if not command is Dictionary or int(command.get("code", 0)) != 509: break
		var raw: Variant = command.get("parameters", [])
		var reason := Catalog.reason(509, raw) if raw is Array else "移动路线续行参数不是数组。"
		if reason.is_empty():
			if route_index >= route.list.size() or int(raw[0].code) != int(route.list[route_index].code) or raw[0].get("parameters", []) != route.list[route_index].get("parameters", []): reason = "509续行与209内嵌路线不匹配。"
		if not reason.is_empty():
			_command_error(509, reason, continuation + 1)
			return
		route_index += 1
		continuation += 1
	var reference: WeakRef = weakref(self)
	var generation := _run_id
	var position: int = context.index
	var source: String = context.location() + " / 指令%d（209）" % position
	var handler := func(message: String) -> bool:
		var owner: RefCounted = reference.get_ref()
		if owner == null or owner._run_id != generation or not owner.running: return false
		owner._command_error(209, message, position)
		return true
	var result: Dictionary = character.force_move_route(route, source, handler)
	if not result.ok: _command_error(209, "路线第%d条：%s" % [result.get("route_index", 0), result.message])
	else: context.index = continuation


func _call_common_event(parameters: Array) -> void:
	var definitions: Variant = common_events if common_events != null else RuntimeData.database("CommonEvents")
	if not (definitions is Array):
		definitions = RuntimeData.database("CommonEvent")
	var id := int(_param(parameters, 0, 0))
	if not (definitions is Array) or id <= 0 or id >= definitions.size() or not (definitions[id] is Dictionary):
		_command_error(117, "公共事件 %d 不存在。" % id)
		return
	if context.stack.size() >= 32:
		_diagnostic(117)
		return
	context.stack.append({"commands": context.commands, "index": context.index, "event_id": context.event_id, "branches": context.branches, "loops": context.loops, "common_id": context.common_id})
	context.commands = definitions[id].get("list", [])
	context.index = 0
	context.branches = {}
	context.loops = {}
	context.common_id = id


func _jump_to_label(label: String) -> void:
	for index in context.commands.size():
		var candidate: Variant = context.commands[index]
		if candidate is Dictionary and int(candidate.get("code", 0)) == 118:
			if str(_param(candidate.get("parameters", []), 0, "")) == label:
				# Native jump clears branches crossed by the jump.
				var low := mini(context.index - 1, index)
				var high := maxi(context.index - 1, index)
				for crossed in range(low, high + 1):
					if context.commands[crossed] is Dictionary: context.branches.erase(int(context.commands[crossed].get("indent", 0)))
				context.index = index + 1
				return
	_command_error(119, "标签不存在：" + label)


func _handle_choice_branch(parameters: Array, indent: int) -> void:
	if int(_param(parameters, 0, -1)) != int(context.branches.get(indent, -1)):
		_skip_to_next_choice_branch(indent)


func _skip_to_else_or_end(indent: int) -> void:
	while context.index < context.commands.size():
		var candidate: Variant = context.commands[context.index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) in [411, 412]:
			context.index += 1
			return
		context.index += 1


func _skip_to_branch_end(indent: int) -> void:
	while context.index < context.commands.size():
		var candidate: Variant = context.commands[context.index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) == 412:
			context.index += 1
			return
		context.index += 1


func _skip_to_loop_end(indent: int) -> void:
	var loop_indent := -1
	for key in context.loops:
		if int(key) < indent and int(key) > loop_indent:
			loop_indent = int(key)
	while context.index < context.commands.size():
		var candidate: Variant = context.commands[context.index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == loop_indent and int(candidate.get("code", 0)) == 413:
			context.index += 1
			context.loops.erase(loop_indent)
			return
		context.index += 1


func _skip_to_next_choice_branch(indent: int) -> void:
	while context.index < context.commands.size():
		var candidate: Variant = context.commands[context.index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) in [402, 403, 404]:
			return
		context.index += 1


func _skip_to_choice_end(indent: int) -> void:
	context.branches.erase(indent)
	while context.index < context.commands.size():
		var candidate: Variant = context.commands[context.index]
		if candidate is Dictionary and int(candidate.get("indent", 0)) == indent and int(candidate.get("code", 0)) == 404:
			context.index += 1
			return
		context.index += 1


func _finish_list() -> void:
	if context.stack.is_empty():
		_complete()
		return
	var frame: Dictionary = context.stack.pop_back()
	context.commands = frame["commands"]
	context.index = int(frame["index"])
	context.event_id = int(frame["event_id"])
	context.branches = frame["branches"]
	context.loops = frame["loops"]
	context.common_id = int(frame["common_id"])


func _diagnostic(code: int) -> void:
	_command_error(code, "不支持的参数或执行上下文。该事件已中断。")


func _complete() -> void:
	if not running: return
	running = false
	wait_state.clear()
	wait_state.kind = "completed"
	context.commands = []
	context.index = 0
	completed.emit()


func _param(parameters: Array, index: int, fallback: Variant) -> Variant:
	return parameters[index] if index >= 0 and index < parameters.size() else fallback

## 职责：回归验证：验证角色增减、能力修改与场景呼叫等原生事件。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func reset(members: Array = [1, 2]) -> void
##     用途：重置本服务持有的状态。
##     参数 members（Array；默认值 [1, 2]）：字段或成员名称集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func parameters() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func actor_commands() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func state_links() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func party_and_equipment() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func save_data() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func scene_ui() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func terminal_scenes() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func new_game() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func dispose_game() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func commands(list: Array) -> void
##     参数 list（Array；必填）：待编辑或处理的有序记录列表。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func execute(list: Array) -> Dictionary
##     用途：执行该脚本或已准备的操作。
##     参数 list（Array；必填）：待编辑或处理的有序记录列表。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func apply(code: int, p: Array) -> Dictionary
##     用途：应用已选定或已准备的修改。
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；必填）：对应事件指令的参数数组。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func c(code: int, p: Array = []) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；默认值 []）：对应事件指令的参数数组。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func actors_snapshot() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func frames(count: int) -> void
##     用途：让测试现场推进指定帧数。
##     参数 count（int；必填）：处理数量或重复次数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func press(key: Key, unicode: int = 0) -> void
##     用途：模拟一次按键输入。
##     参数 key（Key；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     参数 unicode（int；默认值 0）：Unicode 字符码值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(condition: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 condition（bool；必填）：是否创建须返回布尔值的脚本条件模板。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func definitions() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
var failures: Array[String] = []
var checks := 0
var data: Script
var state: Node
var catalog: Script
var interpreter: Script
var fixture: Dictionary
var game: Node

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("FAIL: actor/scene timeout"); quit(1))
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd"); state = root.get_node("RuntimeState")
	catalog = load("res://runtime/scripts/02_Event/EventCommandCatalog.gd"); interpreter = load("res://runtime/scripts/02_Event/EventInterpreter.gd")
	var original: Dictionary = data._cache.duplicate(true)
	fixture = definitions()
	for database in fixture: data._cache["res://data/database/%s.json" % database] = fixture[database]
	var immutable := JSON.stringify(fixture)
	var resources: Script = load("res://runtime/scripts/04_UI_Common/UIResources.gd")
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8); image.fill(Color("e09030"))
	resources._textures["Graphics/Characters/@actor"] = ImageTexture.create_from_image(image)
	reset(); parameters(); actor_commands(); state_links(); party_and_equipment(); save_data()
	expect(JSON.stringify(fixture) == immutable, "commands never mutate shared database definitions")
	await scene_ui()
	await terminal_scenes()
	state.audio.stop_all(); data._cache.clear(); data._cache.merge(original)
	await frames(3); await create_timer(0.2).timeout
	for failure in failures: printerr("FAIL: ", failure)
	print("EVENT ACTOR SCENE TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " / ", checks, " checks")
	quit(0 if failures.is_empty() else 1)

func reset(members: Array = [1, 2]) -> void:
	var system: Dictionary = data.system().duplicate(true); system.party_members = members
	state.begin_new_game(system, {"enabled": false})
	state.inventory = {"weapon:1": 0, "weapon:2": 2, "armor:1": 0, "armor:2": 2}

func parameters() -> void:
	var valid := [[129, [1, 0, 1]], [135, [0]], [303, [1, 8]], [311, [0, 1, 0, 50, true]], [312, [0, 0, 1, 1]],
		[313, [0, 0, 1]], [314, [0]], [315, [0, 0, 0, 20]], [316, [0, 0, 0, 2]], [317, [1, 5, 0, 0, 1]],
		[318, [1, 0, 2]], [319, [1, 0, 0]], [320, [1, "新姓名"]], [321, [1, 2]], [322, [1, "", 0, "战斗图", 360]], [351, []], [353, []], [354, []]]
	for item in valid: expect(catalog.supported(item[0], item[1]), "native shape supported %d" % item[0])
	var invalid := [[129, [1, 0, true]], [135, [2]], [303, [1, 0]], [311, [1, 1, 0, 5, 1]], [312, [1, 0, 0, -1]],
		[313, [0, 2, 1]], [314, []], [315, [1, 0, 0, 2, true]], [316, [1, 0, 0, 1.5]], [317, [1, 6, 0, 0, 1]],
		[318, [1, 0, 0]], [319, [1, 5, 0]], [320, [1, 2]], [321, [1, 0]], [322, [1, "../bad", 0, "", 0]], [351, [0]], [353, [0]], [354, [0]]]
	for item in invalid:
		var before := actors_snapshot()
		var result := execute([c(item[0], item[1]), c(122, [9600, 9600, 0, 0, 9]), c(0)])
		expect(not result.error.is_empty() and actors_snapshot() == before and state.variables.get("9600", 0) != 9, "invalid command rejects without following reward %d" % item[0])
		expect(result.error.contains("事件 7") and result.error.contains("第 2 页"), "invalid command carries source location %d" % item[0])
	expect(catalog.supported(352) and not catalog.supported(301), "event save supported and native battle remains excluded")

func actor_commands() -> void:
	reset()
	var actor: RefCounted = state.actor(1); var identity := actor.get_instance_id()
	var other: RefCounted = state.actor(2)
	state.set_event_variable(9601, 10)
	expect(apply(311, [0, 1, 1, 9601, false]).ok and actor.hp == 100 and other.hp == 100, "311 whole party variable damage")
	expect(apply(311, [1, 1, 0, 999, false]).ok and actor.hp == 1, "311 death forbidden floors living HP at1")
	expect(apply(311, [1, 1, 0, 999, true]).ok and actor.hp == 0 and actor.has_state(1) and actor.has_state(2), "311 death attaches every zero_hp state")
	expect(apply(311, [1, 0, 0, 999, false]).ok and actor.hp == 0, "311 positive HP cannot resurrect dead actor")
	expect(apply(313, [1, 1, 1]).ok and actor.hp == 0 and not actor.has_state(1), "removing one of two death states leaves HP0")
	expect(apply(313, [1, 1, 2]).ok and actor.hp == 1, "removing last ordinary death state revives atHP1")
	state.set_event_variable(9601, -5)
	expect(apply(312, [0, 0, 1, 9601]).ok and actor.sp == 16 and other.sp == 16, "312 signed variable decrement for all")
	expect(apply(312, [1, 0, 0, 9999]).ok and actor.sp == actor.maxsp, "312 clamps SP cap")
	state.variables["9601"] = 1.5
	var before := actors_snapshot()
	expect(not apply(312, [0, 0, 1, 9601]).ok and actors_snapshot() == before, "fractional variable refuses all targets atomically")
	var bad: Dictionary = fixture.Actors[2].duplicate(true); bad.parameters.values[6] = null
	fixture.Actors[2] = bad; state.actors.erase(2)
	before = actors_snapshot()
	expect(not apply(312, [0, 0, 0, 1]).ok and actors_snapshot() == before and not state.actors.has(2), "later invalid actor cannot partially change earlier target or register actor")
	fixture.Actors[2] = fixture.Actors[1].duplicate(true); fixture.Actors[2].id = 2; fixture.Actors[2].name = "角色2"
	reset(); actor = state.actor(1); other = state.actor(2); identity = actor.get_instance_id()
	var threshold: int = actor.experience_for_level(3)
	expect(apply(315, [0, 0, 0, threshold]).ok and actor.level == 3 and other.level == 3 and actor.has_skill(1) and actor.has_skill(2), "315 all EXP learns every crossed level skill")
	expect(apply(316, [0, 1, 0, 99]).ok and actor.level == 1 and actor.has_skill(2) and actor.exp == 0, "316 down to1 retains learned skills")
	expect(apply(316, [1, 0, 0, 99]).ok and actor.level == 5, "316 final level cap")
	expect(apply(315, [1, 0, 0, 99999999]).ok and actor.exp == 9999999, "315 native EXP cap")
	for index in 6:
		var key: String = load("res://runtime/scripts/00_Game/ActorEventService.gd").PARAMETER_KEYS[index]
		expect(apply(317, [1, index, 0, 0, 7]).ok and actor.get_parameter_plus(key) == 7, "317 native six index maps to " + key)
	expect(actor.atk_plus == 0 and actor.pdef_plus == 0 and actor.mdef_plus == 0, "317 six index does not modify three derived combat stats")
	expect(apply(317, [1, 2, 0, 0, 99999999]).ok and actor.str_plus == 999, "317 saturates permanent plus instead of rejecting native large increments")
	apply(317, [1, 2, 1, 0, 99999999]); expect(actor.str_plus == -999 and actor.str == 1, "317 negative clamp")
	expect(apply(318, [1, 1, 2]).ok and not actor.has_skill(2) and apply(318, [1, 0, 2]).ok and actor.has_skill(2), "318 forgetting and learning are idempotent")
	before = actor.persistent_data()
	expect(not apply(318, [1, 0, 99999]).ok and actor.persistent_data() == before, "missing skill does not mutate")
	expect(apply(320, [1, "魔塔角色"]).ok and actor.actor_name == "魔塔角色" and actor.get_instance_id() == identity, "320 keeps registered actor identity and notifies shared views")
	expect(apply(322, [1, "@actor", 90, "无需加载的战斗图", 120]).ok and actor.character_name == "@actor" and actor.battler_name == "无需加载的战斗图" and actor.battler_hue == 120, "322 all five native fields; battler is metadata only")
	before = actor.persistent_data()
	expect(not apply(322, [1, "__missing__", 0, "bad", 0]).ok and actor.persistent_data() == before, "322 preflights character asset before changing either image")
	expect(apply(322, [1, "", 360, "", 360]).ok and actor.character_hue == 0 and actor.battler_hue == 0, "322 empty images and equivalent360hue")
	reset([])
	for item in [[311, [0, 1, 0, 99, true]], [312, [0, 0, 0, 1]], [313, [0, 0, 1]], [314, [0]], [315, [0, 0, 0, 99]], [316, [0, 0, 0, 1]]]:
		var result := apply(item[0], item[1]); expect(result.ok and not result.get("gameover", false) and state.actors.is_empty(), "empty party native all target is no-op %d" % item[0])

func state_links() -> void:
	reset(); var actor: RefCounted = state.actor(1)
	expect(apply(313, [1, 0, 4]).ok and actor.has_state(3) and actor.has_state(4), "313 recursively adds native plus_state_set")
	apply(313, [1, 0, 5]); expect(actor.has_state(5) and not actor.has_state(3), "313 applies linked removals")
	apply(313, [1, 0, 3]); expect(not actor.has_state(3), "existing state unilateral minus prevents adding excluded state")
	apply(313, [1, 1, 5]); apply(313, [1, 0, 3]); expect(actor.has_state(3), "removing blocker permits state")
	var before: Dictionary = actor.persistent_data()
	expect(not apply(313, [0, 0, 6]).ok and actor.persistent_data() == before and not state.actor(2).has_state(6), "missing linked state rejects all without mutation")
	expect(not apply(313, [1, 0, 7]).ok and actor.persistent_data() == before, "malformed state definition rejects")
	apply(313, [1, 0, 8]); expect(actor.has_state(8) and actor.has_state(9), "finite reciprocal plus state links terminate")
	apply(314, [1]); apply(313, [1, 0, 10]); actor.hp = 1; actor.sp = 0
	var old_cap: int = actor.maxhp
	expect(apply(314, [1]).ok and actor.get_state_ids(false).is_empty() and actor.hp == old_cap and actor.maxhp > old_cap, "314 RM fills old caps then clears ordinary state; keeps native order")
	apply(319, [1, 1, 2]); apply(313, [1, 0, 3]); apply(313, [1, 0, 1])
	expect(apply(314, [1]).ok and actor.get_state_ids(false).is_empty() and actor.has_state(3) and actor.hp == actor.maxhp and actor.sp == actor.maxsp, "314 clears death/ordinary sources, preserves equipped automatic state")
	expect(apply(313, [1, 0, 3]).ok and actor.get_state_ids(false).is_empty(), "native313 existing armor state does not create an ordinary source")
	apply(313, [1, 1, 3]); expect(actor.has_state(3), "313 cannot remove armor automatic state")
	apply(319, [1, 1, 0]); actor.clear_states()
	fixture.Armors[2].auto_state_id = 4
	expect(apply(319, [1, 1, 2]).ok and actor.has_state(4) and actor.has_state(3) and not actor.get_state_ids(false).has(4), "new armor automatic state applies native ordinary linked states without duplicating source")
	apply(319, [1, 1, 0]); actor.clear_states(); fixture.Armors[2].auto_state_id = 1
	expect(apply(319, [1, 1, 2]).ok and actor.hp == 0 and actor.has_state(1), "zero_hp armor automatic source sets HP0")
	apply(313, [1, 1, 1]); expect(actor.hp == 0 and actor.has_state(1), "ordinary removal cannot revive armor death source")
	expect(apply(319, [1, 1, 0]).ok and actor.hp == 1 and not actor.has_state(1), "unequipping final automatic death source revives atHP1")
	fixture.Armors[2].auto_state_id = 3
	fixture.Armors[1].auto_state_id = 1
	expect(apply(129, [1, 0, 1]).ok and state.actor(1).hp == 0 and state.actor(1).has_state(1), "129 native initialization installs equipped automatic death source")
	fixture.Armors[1].auto_state_id = 0; fixture.Armors[1].erase("auto_state_id")
	apply(129, [1, 0, 1]); actor = state.actor(1)
	actor.recover_all(); var original: Dictionary = fixture.States[4].duplicate(true)
	fixture.States.append({"id": 11, "name": "解除关联HP状态", "minus_state_set": [10]})
	fixture.States[4].plus_state_set = [10, 11]
	expect(apply(313, [1, 0, 4]).ok and not actor.has_state(10) and actor.hp == int(actor.maxhp / 2), "linked temporary cap reduction retains native intermediate HP clamp")
	actor.clear_states(); fixture.States[4] = original; fixture.States.pop_back()

func party_and_equipment() -> void:
	reset([1, 2, 3, 4]); var outside: RefCounted = state.actor(5); outside.rename("保留姓名")
	expect(apply(129, [5, 0, 0]).ok and state.party == [1, 2, 3, 4] and outside.actor_name == "保留姓名", "129 native four-member cap")
	expect(apply(129, [5, 0, 1]).ok and state.party == [1, 2, 3, 4] and state.actor(5).actor_name == "角色5", "129 initialize happens before full party membership check")
	apply(129, [1, 1, 0]); apply(129, [5, 0, 0]); expect(state.party == [2, 3, 4, 5] and state.actors.has(1), "129 removal preserves actor registry, subsequent add uses freed slot")
	var actor: RefCounted = state.actor(1)
	expect(actor.slot_fixed(0) and apply(319, [1, 0, 2]).ok and actor.equipment[0] == 2 and state.inventory_count("weapon", 1) == 1, "319 native event force equips fixed/off-party/class-disallowed item with stock")
	state.inventory["weapon:1"] = 0
	expect(apply(319, [1, 0, 1]).ok and actor.equipment[0] == 2, "319 native no-stock replacement is no-op")
	state.inventory["weapon:2"] = 99
	var before: Dictionary = actor.persistent_data(); var stock: Dictionary = state.inventory.duplicate()
	expect(not apply(319, [1, 0, 0]).ok and actor.persistent_data() == before and state.inventory == stock, "319 full return stock refuses atomically instead of losing equipment")
	state.inventory["weapon:2"] = 0; actor.set_level(3)
	expect(apply(321, [1, 2]).ok and actor.class_id == 2 and actor.equipment[0] == 2 and actor.equipment[1] == 0 and actor.level == 3 and actor.has_skill(2), "321 preserves allowed equipment/EXP/skills and returns incompatible fixed armor")
	state.inventory["weapon:1"] = 1; apply(319, [1, 0, 1]); state.inventory["weapon:1"] = 99
	before = actor.persistent_data(); stock = state.inventory.duplicate()
	expect(not apply(321, [1, 2]).ok and actor.persistent_data() == before and state.inventory == stock, "321 cannot partially return gear if a later return fails")
	expect(not apply(321, [1, 99999]).ok and actor.class_id == before.class_id, "321 missing class rejects")

func save_data() -> void:
	reset(); apply(322, [1, "@actor", 90, "战斗元数据", 180]); apply(320, [1, "已改姓名"])
	var codec: Script = load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	var saved: Dictionary = codec.capture(state); var prepared: Dictionary = codec.prepare(saved)
	expect(prepared.ok and prepared.actors[1].battler_name == "战斗元数据" and prepared.actors[1].character_name == "@actor", "322 both native image overrides survive save preflight")
	var previous: Dictionary = saved.actors["1"].duplicate(true) if saved.actors is Dictionary else saved.actors[0].duplicate(true)
	var old: RefCounted = load("res://runtime/scripts/00_Game/ActorState.gd").new(); old.configure(1, fixture.Actors[1], data.record)
	previous.erase("battler_name"); previous.erase("battler_hue")
	expect(old.restore_persistent(previous).is_empty() and old.battler_name == "原战斗图", "old schema actor without battler overrides uses database defaults")
	if saved.actors is Dictionary: saved.actors["1"].battler_hue = 361
	else: saved.actors[0].battler_hue = 361
	expect(not codec.prepare(saved).ok, "corrupt battler metadata refuses before live state mutation")

func scene_ui() -> void:
	await new_game()
	game._player.move_straight(6)
	commands([c(101, ["移动途中也显示消息"]), c(0)])
	expect(game._player.moving() and game._dialogue.is_open(), "message UI preserves native display during ongoing player motion")
	var moving_id: int = game._event_ui.active.id; game._dialogue.dismiss(); game._event_response(moving_id, "message", null)
	commands([c(303, [1, 8]), c(0)])
	expect(game._menus.name_input == null and game._interpreter.wait_kind() == "name", "303 scene waits for actual movement completion without rejecting request")
	game._player.advance_motion(0.3); game._event_ui.pump(game.event_ui_available())
	expect(game._menus.name_input != null and paused, "303 pending page presents after movement ends")
	game._menus.name_input.submit()
	commands([c(135, [0]), c(351), c(122, [9610, 9610, 1, 0, 1]), c(0)])
	expect(state.menu_disabled and game._menus.menu != null and paused and game._interpreter.wait_kind() == "menu", "351 explicitly opens menu even when135 disables player menu")
	var timer: float = state.timer.remaining; game._scheduler.advance(10)
	expect(state.variables.get("9610", 0) == 0 and state.timer.remaining == timer, "event menu pauses map clock and blocked owner")
	var id: int = game._event_ui.active.id
	game._event_ui.resolve(id + 1); expect(game._interpreter.wait_kind() == "menu", "wrong request cannot resume menu owner")
	game._menus.close_menu(); game._menus.close_menu()
	expect(state.variables.get("9610", 0) == 1 and not paused and not game._menus.open_menu(), "closing menu resumes once; manual menu still disabled")
	commands([c(135, [1]), c(303, [1, 4]), c(122, [9611, 9611, 1, 0, 1]), c(0)])
	var page: Control = game._menus.name_input
	expect(page != null and paused and not game._player.input_enabled and page.edit.max_length == 4, "303 presents exclusive name input with character limit")
	id = game._event_ui.active.id
	game._event_ui.resolve(id, "太长的五个字"); expect(game._interpreter.wait_kind() == "name", "oversized response cannot complete input")
	page.edit.text = ""; page.submit(); expect(game._menus.name_input == page and not page.edit.text.is_empty(), "blank confirm restores native initial name without closing")
	page.edit.text = "勇者甲乙"; page.back(); expect(page.edit.text == "勇者甲", "escape/back deletes one Unicode character and does not cancel")
	game._menus.close_name(id + 1, "wrong"); expect(game._menus.name_input == page, "stale name page ID cannot close current input")
	page.edit.text = "XZ 空"; page.submit()
	expect(state.actor(1).actor_name == "XZ 空" and state.variables.get("9611", 0) == 1 and not paused, "303 accepts literal X/Z/space and resumes issuing event once")
	commands([c(303, [1, 8]), c(0)]); page = game._menus.name_input; page.edit.text = ""; page.edit.grab_focus()
	await press(KEY_X, 120); await press(KEY_Z, 122); await press(KEY_SPACE, 32)
	expect(page.edit.text == "xz " and game._menus.name_input == page, "actual keyboard X/Z/space reach text entry without menu hotkeys")
	await press(KEY_ESCAPE)
	expect(page.edit.text == "xz" and game._menus.name_input == page, "actual escape removes one character without closing303")
	page.edit.text = "XZ 空"; await press(KEY_ENTER)
	expect(game._menus.name_input == null and state.actor(1).actor_name == "XZ 空", "actual Enter confirms303")
	# Real queued requests from two independent interpreters share the same Game broker.
	var parallel: RefCounted = interpreter.new(); parallel.map_runtime = game._map
	game._event_ui.bind_interpreter(parallel)
	commands([c(302, [1, 2]), c(122, [9612, 9612, 1, 0, 1]), c(0)])
	parallel.start([c(303, [2, 8]), c(122, [9613, 9613, 1, 0, 1]), c(0)], 2)
	game._event_ui.pump(game.event_ui_available())
	expect(game._menus.shop != null and game._menus.name_input == null and parallel.wait_kind() == "name", "parallel name queues behind active302 shop")
	game._menus.close_shop()
	expect(state.variables.get("9612", 0) == 1 and state.variables.get("9613", 0) == 0 and game._menus.name_input != null and paused and not game._player.input_enabled, "shop closing restores correct owner while next name retains input/pause")
	game._menus.name_input.edit.text = "并行角色"; game._menus.name_input.submit()
	expect(state.actor(2).actor_name == "并行角色" and state.variables.get("9613", 0) == 1 and not game._event_ui.busy() and not paused, "queued independent name completes its original event")
	commands([c(101, ["消息占用界面"]), c(0)])
	parallel.start([c(351), c(122, [9615, 9615, 1, 0, 1]), c(0)], 2)
	expect(game._dialogue.is_open() and game._menus.menu == null, "parallel event menu queues behind message")
	id = game._event_ui.active.id; game._dialogue.dismiss(); game._event_response(id, "message", null)
	expect(game._menus.menu != null and paused and state.variables.get("9615", 0) == 0, "message completion transfers exclusive UI to original parallel menu")
	game._menus.close_menu(); expect(state.variables.get("9615", 0) == 1 and not paused, "parallel menu closure resumes its independent event once")
	commands([c(303, [1, 8]), c(122, [9614, 9614, 1, 0, 1]), c(0)])
	id = game._event_ui.active.id; game.reset_event_execution(); game._event_ui.resolve(id, "过期姓名")
	expect(game._menus.name_input == null and not paused and state.variables.get("9614", 0) == 0 and state.actor(1).actor_name == "XZ 空", "execution reset dismisses input and invalidates stale callback")
	game._events_enabled = true
	commands([c(303, [99999, 8]), c(122, [9614, 9614, 1, 0, 1]), c(0)])
	expect(not game._interpreter.running and state.variables.get("9614", 0) == 0 and game._menus.name_input == null, "missing303 actor stops with diagnostic and no following reward")
	game.reset_event_execution()
	await dispose_game()

func terminal_scenes() -> void:
	for code in [353, 354]:
		await new_game()
		var old: WeakRef = weakref(game)
		var route := {"repeat": true, "skippable": true, "list": [c(15, [20]), c(0)]}
		game._player.force_move_route(route)
		commands([c(code), c(122, [9620, 9620, 0, 0, 1]), c(0)])
		expect(game.event_scene_transition_active() and not state.playing and not game._interpreter.running and not game._event_ui.busy() and not game._player.routes.forcing, "terminal cancels execution/UI/routes immediately %d" % code)
		expect(not game.event_save_reason().is_empty() and state.variables.get("9620", 0) == 0, "terminal protects save and never executes following reward %d" % code)
		game._scheduler.advance(1); expect(game._scheduler.parallels.is_empty(), "terminal cannot restart old parallel instances %d" % code)
		await frames(4)
		expect(old.get_ref() == null and state.game() == null and not paused, "actual terminal scene frees map and clears weak references %d" % code)
		expect(current_scene != null and current_scene.scene_file_path.ends_with("Gameover.tscn" if code == 353 else "Title.tscn"), "actual native terminal destination %d" % code)
		if code == 353:
			current_scene.return_to_title(); await frames(4)
			expect(current_scene.scene_file_path.ends_with("Title.tscn"), "gameover confirmation reaches native title")
		current_scene.queue_free(); current_scene = null; game = null; await frames(3)
	await new_game()
	commands([c(311, [0, 1, 0, 9999, true]), c(122, [9621, 9621, 0, 0, 1]), c(0)])
	expect(game.event_scene_transition_active() and state.variables.get("9621", 0) == 0, "native311 all-dead automatically requests gameover before reward")
	await frames(4); expect(current_scene.scene_file_path.ends_with("Gameover.tscn"), "all-dead311 produces actual gameover")
	current_scene.queue_free(); current_scene = null; game = null; await frames(3)
	await new_game()
	commands([c(313, [0, 0, 1]), c(122, [9622, 9622, 0, 0, 1]), c(0)])
	expect(not game.event_scene_transition_active() and state.variables.get("9622", 0) == 1, "313 has native state semantics without311 automatic gameover flag")
	commands([c(354), c(0)]); reset(); await frames(3)
	expect(is_instance_valid(game) and current_scene == game and not game.event_scene_transition_active(), "new game invalidates deferred terminal transition from previous run")
	await dispose_game()

func new_game() -> void:
	reset(); state.resume_from_save = true
	game = load("res://scenes/03_Map/Game.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(3); game.reset_event_execution()
	var map_fixture: Dictionary = load("res://runtime/scripts/11_Development/MovementFixture.gd").build(); map_fixture.map.events = {}
	game._map.load_definition(map_fixture.map, map_fixture.tileset); game._scheduler.cancel_all(); game._scheduler.common_events = []
	game.set_process(false); game._player.set_process(false); game._events_enabled = true
	expect(game._player.move_to(6, 5), "scene fixture positions player inside12x9 map")
	game._sync_event_input(); state.timer.start(60)

func dispose_game() -> void:
	if is_instance_valid(game): game.queue_free()
	current_scene = null; game = null; await frames(3)

func commands(list: Array) -> void:
	game._scheduler.start_main(list, 0)
	game._event_ui.pump(game.event_ui_available()); game._sync_event_input()

func execute(list: Array) -> Dictionary:
	var owner: RefCounted = interpreter.new(); var error := {"text": ""}
	owner.diagnostic_requested.connect(func(message: String) -> void: error.text = message)
	owner.start(list, 7, 2)
	return {"error": error.text, "owner": owner}

func apply(code: int, p: Array) -> Dictionary: return state.apply_actor_event(code, p)
func c(code: int, p: Array = []) -> Dictionary: return {"code": code, "parameters": p, "indent": 0}
func actors_snapshot() -> Dictionary:
	var result := {}; for id in state.actors: result[id] = state.actors[id].persistent_data()
	return {"actors": result, "party": state.party.duplicate(), "stock": state.inventory.duplicate()}
func frames(count: int) -> void:
	for index in count: await process_frame
func press(key: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new(); event.keycode = key; event.unicode = unicode; event.pressed = true
	Input.parse_input_event(event); await frames(2)
	event = InputEventKey.new(); event.keycode = key; Input.parse_input_event(event); await frames(2)
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

static func definitions() -> Dictionary:
	var table := []; for level in 100: table.append_array([100 + level * 10, 20 + level, 10 + level, 12 + level, 14 + level, 16 + level])
	var actors := [null]
	for id in range(1, 6): actors.append({"id": id, "name": "角色%d" % id, "class_id": 1, "initial_level": 1, "final_level": 5, "exp_basis": 30, "exp_inflation": 30, "weapon_id": 1, "armor1_id": 1, "weapon_fix": true, "armor1_fix": true, "character_name": "", "battler_name": "原战斗图", "parameters": {"x_size": 6, "y_size": 100, "values": table.duplicate()}})
	return {"Actors": actors, "Classes": [null, {"id": 1, "name": "剑士", "weapon_set": [1], "armor_set": [1], "learnings": [{"level": 2, "skill_id": 1}, {"level": 3, "skill_id": 2}]}, {"id": 2, "name": "法师", "weapon_set": [2], "armor_set": [], "learnings": []}],
		"Weapons": [null, {"id": 1, "name": "剑", "price": 100, "atk": 20}, {"id": 2, "name": "杖", "price": 80, "atk": 10}], "Armors": [null, {"id": 1, "name": "盾", "kind": 0, "pdef": 5}, {"id": 2, "name": "自动状态盾", "kind": 0, "auto_state_id": 3, "pdef": 2}],
		"Skills": [null, {"id": 1, "name": "特技1"}, {"id": 2, "name": "特技2"}],
		"States": [null, {"id": 1, "name": "死亡1", "zero_hp": true}, {"id": 2, "name": "死亡2", "zero_hp": true}, {"id": 3, "name": "力量倍率", "str_rate": 200}, {"id": 4, "name": "连锁", "plus_state_set": [3]}, {"id": 5, "name": "互斥", "minus_state_set": [3]}, {"id": 6, "name": "缺失关联", "plus_state_set": [99999]}, {"id": 7, "name": "坏定义", "plus_state_set": "invalid"}, {"id": 8, "name": "环A", "plus_state_set": [9]}, {"id": 9, "name": "环B", "plus_state_set": [8]}, {"id": 10, "name": "HP倍率", "maxhp_rate": 50}]}

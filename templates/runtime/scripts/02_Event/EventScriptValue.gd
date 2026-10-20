## 职责：将现有游戏对象和集合接入可读事件接口，属性读写始终访问同一运行现场。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/02_Event/EventScriptValue.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(api: RefCounted, value: Variant) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 api（RefCounted；必填）：当前事件的业务接口服务，持有同一上下文的弱引用。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func at(index: Variant, second: Variant = null, third: Variant = null) -> Variant
##     参数 index（Variant；必填）：集合或列表中的位置索引。
##     参数 second（Variant；默认值 null）：第二个值或参与操作的对象。
##     参数 third（Variant；默认值 null）：第三个位置参数。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func put(index: Variant, value: Variant) -> Variant
##     参数 index（Variant；必填）：集合或列表中的位置索引。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func begin_battle() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func finish_battle() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func is_dead() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func is_box_in_place() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func refresh() -> Variant
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func refresh_damage() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func attr_addition_clear() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func erase() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func die() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func move_down() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func move_left() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func move_right() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func move_up() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func wake() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func freeze() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func unravel() -> Variant
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func gain_item(id: int, amount: int) -> Variant
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 amount（int；必填）：需要增加、扣除或应用的数量。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func gain_gold(amount: Variant) -> Variant
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func gain_exp(amount: Variant) -> Variant
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func add_state(id: int) -> Variant
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func learn_skill(id: int, level: int = 0) -> Variant
##     用途：使角色学会指定技能并报告变化结果。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 level（int；默认值 0）：本接口处理的level参数，含义见方法用途。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func level_up(id: int, level: int) -> Variant
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 level（int；必填）：本接口处理的level参数，含义见方法用途。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func set_rect(mode: int = 0) -> Variant
##     参数 mode（int；默认值 0）：当前操作或显示模式。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func voiceover(enabled: bool = true) -> Variant
##     参数 enabled（bool；默认值 true）：是否启用对应功能。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func check_event(x: Variant, y: Variant, pattern: Variant) -> Variant
##     参数 x（Variant；必填）：横向坐标。
##     参数 y（Variant；必填）：纵向坐标。
##     参数 pattern（Variant；必填）：匹配模式或图形帧编号。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted
var _api: WeakRef
var _value: Variant

var enemy: Variant:
	get:
		return _get("enemy")
	set(value):
		_set("enemy", value)
var event: Variant:
	get:
		return _get("event")
	set(value):
		_set("event", value)
var name: Variant:
	get:
		return _get("name")
	set(value):
		_set("name", value)
var event_erase: Variant:
	get:
		return _get("event_erase")
	set(value):
		_set("event_erase", value)
var item_id: Variant:
	get:
		return _get("item_id")
	set(value):
		_set("item_id", value)
var ending_id: Variant:
	get:
		return _get("ending_id")
	set(value):
		_set("ending_id", value)
var barrier_id: Variant:
	get:
		return _get("barrier_id")
	set(value):
		_set("barrier_id", value)
var hp: Variant:
	get:
		return _get("hp")
	set(value):
		_set("hp", value)
var potion_id: Variant:
	get:
		return _get("potion_id")
	set(value):
		_set("potion_id", value)
var hp_addition: Variant:
	get:
		return _get("hp_addition")
	set(value):
		_set("hp_addition", value)
var gem_id: Variant:
	get:
		return _get("gem_id")
	set(value):
		_set("gem_id", value)
var door_id: Variant:
	get:
		return _get("door_id")
	set(value):
		_set("door_id", value)
var shotcut_enabled: Variant:
	get:
		return _get("shotcut_enabled")
	set(value):
		_set("shotcut_enabled", value)
var ending_score: Variant:
	get:
		return _get("ending_score")
	set(value):
		_set("ending_score", value)
var attr_addtion: Variant:
	get:
		return _get("attr_addtion")
	set(value):
		_set("attr_addtion", value)
var main_actor_id: Variant:
	get:
		return _get("main_actor_id")
	set(value):
		_set("main_actor_id", value)
var exp: Variant:
	get:
		return _get("exp")
	set(value):
		_set("exp", value)
var id: Variant:
	get:
		return _get("id")
	set(value):
		_set("id", value)
var x: Variant:
	get:
		return _get("x")
	set(value):
		_set("x", value)
var y: Variant:
	get:
		return _get("y")
	set(value):
		_set("y", value)
var pdef: Variant:
	get:
		return _get("pdef")
	set(value):
		_set("pdef", value)
var events: Variant:
	get:
		return _get("events")
	set(value):
		_set("events", value)
var animation_id: Variant:
	get:
		return _get("animation_id")
	set(value):
		_set("animation_id", value)
var gold: Variant:
	get:
		return _get("gold")
	set(value):
		_set("gold", value)
var actor_id: Variant:
	get:
		return _get("actor_id")
	set(value):
		_set("actor_id", value)
var enemy_hp_addition: Variant:
	get:
		return _get("enemy_hp_addition")
	set(value):
		_set("enemy_hp_addition", value)
var pending_battle_result: Variant:
	get:
		return _get("pending_battle_result")
	set(value):
		_set("pending_battle_result", value)
var battle_animation: Variant:
	get:
		return _get("battle_animation")
	set(value):
		_set("battle_animation", value)
var opacity: Variant:
	get:
		return _get("opacity")
	set(value):
		_set("opacity", value)
var support_actor_id: Variant:
	get:
		return _get("support_actor_id")
	set(value):
		_set("support_actor_id", value)
var potion_hp: Variant:
	get:
		return _get("potion_hp")
	set(value):
		_set("potion_hp", value)
var battle_id: Variant:
	get:
		return _get("battle_id")
	set(value):
		_set("battle_id", value)
var gem_attr: Variant:
	get:
		return _get("gem_attr")
	set(value):
		_set("gem_attr", value)
var map_id: Variant:
	get:
		return _get("map_id")
	set(value):
		_set("map_id", value)
var patk: Variant:
	get:
		return _get("patk")
	set(value):
		_set("patk", value)
var matk: Variant:
	get:
		return _get("matk")
	set(value):
		_set("matk", value)
var mdef: Variant:
	get:
		return _get("mdef")
	set(value):
		_set("mdef", value)
var enemy_erase: Variant:
	get:
		return _get("enemy_erase")
	set(value):
		_set("enemy_erase", value)
var level: Variant:
	get:
		return _get("level")
	set(value):
		_set("level", value)
var next_exp: Variant:
	get:
		return _get("next_exp")
	set(value):
		_set("next_exp", value)
var atk: Variant:
	get:
		return _get("atk")
	set(value):
		_set("atk", value)
var eva: Variant:
	get:
		return _get("eva")
	set(value):
		_set("eva", value)
var potion_itemization: Variant:
	get:
		return _get("potion_itemization")
	set(value):
		_set("potion_itemization", value)
var gem_itemization: Variant:
	get:
		return _get("gem_itemization")
	set(value):
		_set("gem_itemization", value)
var direction: Variant:
	get:
		return _get("direction")
	set(value):
		_set("direction", value)
var aim_layer: Variant:
	get:
		return _get("aim_layer")
	set(value):
		_set("aim_layer", value)
var data: Variant:
	get:
		return _get("data")
	set(value):
		_set("data", value)
var aim_data: Variant:
	get:
		return _get("aim_data")
	set(value):
		_set("aim_data", value)
var actors: Variant:
	get:
		return _get("actors")
	set(value):
		_set("actors", value)
var show_playerdata: Variant:
	get:
		return _get("show_playerdata")
	set(value):
		_set("show_playerdata", value)
var show_mapname: Variant:
	get:
		return _get("show_mapname")
	set(value):
		_set("show_mapname", value)
var mdef_available: Variant:
	get:
		return _get("mdef_available")
	set(value):
		_set("mdef_available", value)
var speed_available: Variant:
	get:
		return _get("speed_available")
	set(value):
		_set("speed_available", value)
var show_greenkeys: Variant:
	get:
		return _get("show_greenkeys")
	set(value):
		_set("show_greenkeys", value)
var enemy_id: Variant:
	get:
		return _get("enemy_id")
	set(value):
		_set("enemy_id", value)
var got_damage: Variant:
	get:
		return _get("got_damage")
	set(value):
		_set("got_damage", value)
var enemy_damage: Variant:
	get:
		return _get("enemy_damage")
	set(value):
		_set("enemy_damage", value)
var battle_result: Variant:
	get:
		return _get("battle_result")
	set(value):
		_set("battle_result", value)
var maxhp: Variant:
	get:
		return _get("maxhp")
	set(value):
		_set("maxhp", value)
var maxsp: Variant:
	get:
		return _get("maxsp")
	set(value):
		_set("maxsp", value)
var sp: Variant:
	get:
		return _get("sp")
	set(value):
		_set("sp", value)
var agi: Variant:
	get:
		return _get("agi")
	set(value):
		_set("agi", value)
var intelligence: Variant:
	get:
		return _get("int")
	set(value):
		_set("int", value)
var items: Variant:
	get:
		return _get("items")
	set(value):
		_set("items", value)
var skills: Variant:
	get:
		return _get("skills")
	set(value):
		_set("skills", value)
var troop: Variant:
	get:
		return _get("troop")
	set(value):
		_set("troop", value)
var item_num: Variant:
	get:
		return _get("item_num")
	set(value):
		_set("item_num", value)


func _init(api: RefCounted, value: Variant) -> void:
	_api = weakref(api)
	_value = value


func _get(property: StringName) -> Variant:
	var api: RefCounted = _api.get_ref()
	return api.invoke(_value, str(property)) if api != null else null


func _set(property: StringName, value: Variant) -> bool:
	var api: RefCounted = _api.get_ref()
	if api != null:
		api.invoke(_value, str(property) + "=", [value])
	return true


func _call(method: String, arguments: Array = []) -> Variant:
	var api: RefCounted = _api.get_ref()
	return api.invoke(_value, method, arguments) if api != null else null


func at(index: Variant, second: Variant = null, third: Variant = null) -> Variant:
	var indexes: Array = [index]
	if second != null:
		indexes.append(second)
	if third != null:
		indexes.append(third)
	var api: RefCounted = _api.get_ref()
	return api.at(_value, indexes) if api != null else null


func put(index: Variant, value: Variant) -> Variant:
	var api: RefCounted = _api.get_ref()
	return api.put(_value, index, value) if api != null else null


func begin_battle() -> Variant:
	return _call("begin_battle!")


func finish_battle() -> Variant:
	return _call("finish_battle!")


func is_dead() -> Variant:
	return _call("dead?")


func is_box_in_place() -> Variant:
	return _call("box_in_place?")


func refresh() -> Variant:
	return _call("refresh")


func refresh_damage() -> Variant:
	return _call("refresh_damage")


func attr_addition_clear() -> Variant:
	return _call("attr_addition_clear")


func erase() -> Variant:
	return _call("erase")


func die() -> Variant:
	return _call("die")


func move_down() -> Variant:
	return _call("move_down")


func move_left() -> Variant:
	return _call("move_left")


func move_right() -> Variant:
	return _call("move_right")


func move_up() -> Variant:
	return _call("move_up")


func wake() -> Variant:
	return _call("wake")


func freeze() -> Variant:
	return _call("freeze")


func unravel() -> Variant:
	return _call("Unravel")


func gain_item(id: int, amount: int) -> Variant:
	return _call("gain_item", [id, amount])


func gain_gold(amount: Variant) -> Variant:
	return _call("gain_gold", [amount])


func gain_exp(amount: Variant) -> Variant:
	return _call("gain_exp", [amount])


func add_state(id: int) -> Variant:
	return _call("add_state", [id])


func learn_skill(id: int, level: int = 0) -> Variant:
	return _call("learn_skill", [id, level])


func level_up(id: int, level: int) -> Variant:
	return _call("level_up", [id, level])


func set_rect(mode: int = 0) -> Variant:
	return _call("set_rect", [mode])


func voiceover(enabled: bool = true) -> Variant:
	return _call("Voiceover", [enabled])


func check_event(x: Variant, y: Variant, pattern: Variant) -> Variant:
	return _call("check_event", [x, y, pattern])

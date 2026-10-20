## 职责：管理地图敌人的伤害等标签，依据实际存活状态创建、更新和移除。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/EnemyMapLabels.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/03_Map/EnemyMapLabels.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func request_refresh() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func rebuild() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func damage_grade(damage: int, hp: int) -> int
##     参数 damage（int；必填）：伤害数值或伤害计算结果。
##     参数 hp（int；必填）：生命值或生命变化量，具体语义由接口名称决定。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func draw_labels(target: Control) -> void
##     参数 target（Control；必填）：操作或效果作用的目标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _exit_tree() -> void
##   func _process(_delta: float) -> void
##     _delta：为保持原接口位置保留，本实现未读取此参数。
##
## 公开常量：COLORS。
## 接口说明结束。

extends CanvasLayer
## 0099 Sprite_Character: shared battle prediction, source damage grades and
## patience labels. Coordinates follow the live sprite; text is rebuilt only
## when authoritative state/map events change, never on each camera movement.
const Data = preload("../00_Game/RuntimeData.gd")
const Maps = preload("MapBridge.gd")
const Worker = preload("../01_Battle/DamageWorker.gd")
const COLORS = [Color.BLACK, Color.GREEN, Color.WHITE, Color.YELLOW, Color8(255, 127, 0), Color.RED]


class Labels:
	extends Control
	var view: CanvasLayer

	func _draw() -> void:
		view.draw_labels(self)


var game: Node
var entries: Array = []
var _canvas: Control
var _dirty = true
var _font: SystemFont
var _eva_font: SystemFont
var rebuild_count = 0
var _worker = Worker.new()
var _revision = 0
var _last_result: Dictionary = {}
var _last_input: Dictionary = {}
var _input_build_us = 0


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Labels.new()
	_canvas.view = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Arial Black", "Arial"])
	_eva_font = SystemFont.new()
	_eva_font.font_names = PackedStringArray(["楷体", "Arial"])
	_eva_font.font_weight = 700
	add_to_group("flash_damage_views")
	RuntimeState.state_changed.connect(request_refresh)
	game.event_map().map_changed.connect(
		func(_id):
			entries.clear()
			request_refresh()
	)
	game.event_map().events_changed.connect(request_refresh)


func _exit_tree() -> void:
	_worker.stop()


func request_refresh() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	var showing = RuntimeState.switches.get("3", false)
	var menus: Node = game._menus
	if (
		menus != null
		and (
			menus.shop != null
			or menus.name_input != null
			or menus.menu != null and menus.menu.page != "flash_sight"
		)
	):
		showing = false
	_canvas.visible = showing
	if not showing:
		return
	entries = entries.filter(func(entry): return _label_alive(entry.node.get_ref()))
	if _dirty:
		_dirty = false
		rebuild()
	_accept_result(_worker.take())
	_canvas.queue_redraw()


func rebuild() -> void:
	rebuild_count += 1
	var started = Time.get_ticks_usec()
	var custom = RuntimeState.custom_data
	var map: Node = game.event_map()
	var gameplay = custom.gameplay()
	var roles = gameplay.role_ids()
	var actor = RuntimeState.actor(int(roles[0])) if int(roles[0]) > 0 else null
	if actor == null:
		entries.clear()
		return
	var floor_data = custom._floor(RuntimeState.map_id)
	var enemies: Array = []
	for event: Node in map._event_nodes:
		if (
			map._erased_events.has(event.event_id)
			or Maps.is_dead(custom, RuntimeState.map_id, event.event_id)
			or not floor_data.entries.has(str(event.event_id))
		):
			continue
		var name = Maps.event_name(custom, RuntimeState.map_id, event.event_id)
		if not name.begins_with("怪物"):
			continue
		var input = gameplay.enemy_input(RuntimeState.map_id, event.event_id)
		if input.is_empty() or input.defeated or input.hp <= 0:
			continue
		var pending: Variant = floor_data.entries[str(event.event_id)].battle.pending
		enemies.append(
			{
				"event_id": event.event_id,
				"input": input,
				"pending": pending.duplicate(true) if pending != null else null
			}
		)
	var job = {
		"revision": _revision,
		"generation": map.generation,
		"map_id": RuntimeState.map_id,
		"hp": int(actor.hp),
		"party": gameplay.party_snapshot(),
		"enemies": enemies,
		"skills": gameplay.simulator.skills.duplicate(true),
		"constants": gameplay.simulator.constants.duplicate(true),
		"catalog_failure": gameplay.simulator.catalog_failure
	}
	_input_build_us = Time.get_ticks_usec() - started
	# Migrated read-only event calls can also emit state_changed. They must not
	# continually invalidate a running prediction with identical inputs.
	if job == _last_input:
		return
	_revision += 1
	job.revision = _revision
	_last_input = job
	if _worker.request(job) != OK:
		RuntimeState.fatal_script_error("显伤后台线程无法启动。")


func _accept_result(result: Dictionary) -> void:
	if (
		result.is_empty()
		or _dirty
		or result.revision != _revision
		or result.map_id != RuntimeState.map_id
		or result.generation != game.event_map().generation
	):
		return
	_last_result = result
	if not result.failure.is_empty():
		RuntimeState.fatal_script_error("地图显伤计算失败：" + result.failure)
		return
	var updated: Array = []
	for row in result.rows:
		var event: Node = game.event_map().event_node(row.event_id)
		if not _label_alive(event):
			continue
		updated.append(
			{
				"node": weakref(event),
				"damage": row.damage,
				"color": damage_grade(row.damage, result.hp),
				"patience": row.patience
			}
		)
	entries = updated


func _label_alive(node: Node) -> bool:
	if (
		node == null
		or node.is_queued_for_deletion()
		or game.event_map()._erased_events.has(node.event_id)
	):
		return false
	var custom = RuntimeState.custom_data
	if Maps.is_dead(custom, RuntimeState.map_id, node.event_id):
		return false
	var battle: Dictionary = (
		custom._floor(RuntimeState.map_id).entries.get(str(node.event_id), {}).get("battle", {})
	)
	return not battle.is_empty() and not battle.defeated and battle.hp > 0


static func damage_grade(damage: int, hp: int) -> int:
	var ratio = NAN if hp == 0 and damage == 0 else INF if hp == 0 else float(damage) / hp
	if ratio <= 0:
		return 1
	if ratio < 1.0 / 3:
		return 2
	if ratio < 2.0 / 3:
		return 3
	if ratio < 1:
		return 4
	return 0 if damage == 9999999 else 5


func draw_labels(target: Control) -> void:
	for entry in entries:
		var node: Node = entry.node.get_ref()
		if not _label_alive(node):
			continue
		var origin = (
			node.get_global_transform_with_canvas().origin + Vector2(0, -node.motion.jump_height)
		)
		_outline(
			target,
			str(entry.damage),
			origin + Vector2(-17, 4),
			_font,
			COLORS[entry.color],
			Color.BLACK
		)
		if entry.patience < 3:
			_outline(
				target,
				str(entry.patience),
				origin + Vector2(4, -16),
				_eva_font,
				[Color8(200, 0, 0), Color8(221, 0, 255), Color8(240, 120, 0)][clampi(
					entry.patience, 0, 2
				)],
				Color.GREEN
			)


func _outline(
	target: Control, text: String, position: Vector2, font: Font, color: Color, outline: Color
) -> void:
	var baseline = position + Vector2(0, font.get_ascent(12))
	for offset in [Vector2(2, 0), Vector2.ZERO, Vector2(2, 2), Vector2(0, 2)]:
		target.draw_string(
			font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, outline
		)
	target.draw_string(font, baseline + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

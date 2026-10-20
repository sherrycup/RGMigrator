## 职责：展示闪翼灵视列表与敌人详情，协调选择、翻页和返回。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/Sight/SightPage.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/Sight/SightPage.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func ready_for_input() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_marks(target: Node2D) -> void
##     参数 target（Node2D；必填）：操作或效果作用的目标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func hp_opacities(frame: int) -> Array
##     参数 frame（int；必填）：动画帧、逻辑帧或渲染帧数据。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
## 对外信号：
##   close_requested()：由持有方发出，通知对应状态或操作结果。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _draw() -> void
##   func _exit_tree() -> void
##
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
const View = preload("SightView.gd")
## 0231–0240/0202: actual map inspection and shared ordinary battle preview.
signal close_requested
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
var page = "flash_sight"
var game: Node
var model: RefCounted
var snapshot: Dictionary = {}
var _content: Control
var _detail: RichTextLabel
var _action_scroll: ScrollContainer
var _hp_label: Label
var _after_hp_label: Label
var _hp_clock = 0.0
var _marks: Node2D
var detail_scroll = 0.0
var window_process = 0
var _window_clock = 0.0
var _closing = false
var _closed = false
var automatic_index = 0
var browse_alpha = 1.0
var _browse_clock = 0
var _browse_transition = 0
var _pending_browse = 0
var _automatic = true
var _browse_event = -1


class Marks:
	extends Node2D
	var page_ref: WeakRef

	func _draw() -> void:
		var value = page_ref.get_ref()
		if value != null:
			value.draw_marks(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game == null:
		game = RuntimeState.game()
	if game == null:
		RuntimeState.report_diagnostic("灵视缺少当前地图。")
		return
	model = preload("SightModel.gd").new(RuntimeState, game.event_map())
	_marks = Marks.new()
	_marks.page_ref = weakref(self)
	game.event_map().ensure_character_layer().add_child(_marks)
	_marks.get_parent().move_child(_marks, 0)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func refresh() -> void:
	if model == null or not is_inside_tree() or size.x < 1:
		return
	if _content == null:
		_content = Surface.new()
		add_child(_content)
		_content.set_progress(window_process)
	_hp_label = null
	_after_hp_label = null
	_detail = null
	snapshot = model.enemy_snapshot() if model.stage != "list" else {}
	var event_id = int(snapshot.event.id) if not snapshot.is_empty() else -1
	if event_id != _browse_event:
		_browse_event = event_id
		automatic_index = 0
		_browse_clock = 0
		_browse_transition = 0
		browse_alpha = 1.0
		_automatic = true
		detail_scroll = 0.0
	View.render(self, _content)
	if _marks != null:
		_marks.queue_redraw()
	queue_redraw()


func ready_for_input() -> bool:
	return window_process == 8 and not _closing


func handle_key(key: int) -> void:
	if _closing:
		return
	if model == null:
		return
	if key in [KEY_ESCAPE, KEY_X]:
		if model.stage in ["skills", "actions"]:
			model.stage = "targets" if model.focus in [1, 2] else "map"
		elif model.stage == "targets":
			model.stage = "list"
			model.cursor = Vector2i(RuntimeState.player_x, RuntimeState.player_y)
		else:
			_closing = true
			return
	elif key == KEY_A:
		model.set_focus(model.focus + 1)
		detail_scroll = 0.0
	elif model.stage == "skills":
		if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			var target = (
				model.skill_index + ({KEY_LEFT: -1, KEY_RIGHT: 1, KEY_UP: -3, KEY_DOWN: 3}[key])
			)
			if target >= 0 and target < snapshot.get("skills", []).size():
				model.skill_index = target
				detail_scroll = 0.0
		elif key in [KEY_Q, KEY_E] and _detail != null:
			var bar = _detail.get_v_scroll_bar()
			detail_scroll = maxf(0, bar.value + (1 if key == KEY_E else -1) * bar.page)
			var maximum = maxf(0, bar.max_value - bar.page)
			if key == KEY_E and bar.value >= maximum:
				detail_scroll = 0
			elif key == KEY_Q and bar.value <= 0:
				detail_scroll = maximum
			bar.value = detail_scroll
			return
	elif key in [KEY_Q, KEY_E] and not snapshot.is_empty() and snapshot.skills.size() > 1:
		_begin_browse(-1 if key == KEY_Q else 1, true)
		return
	elif model.stage == "actions":
		if key in [KEY_UP, KEY_DOWN] and _action_scroll != null:
			_action_scroll.scroll_vertical += (1 if key == KEY_DOWN else -1) * 6
			_action_scroll.queue_redraw()
			return
	elif model.stage == "list":
		if key in [KEY_LEFT, KEY_RIGHT] and not model.groups.is_empty():
			model.list_index = posmod(
				model.list_index + (1 if key == KEY_RIGHT else -1), model.groups.size()
			)
			model.update_group()
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
			model.select_group()
	else:
		if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			model.move_cursor(
				{
					KEY_UP: Vector2i.UP,
					KEY_DOWN: Vector2i.DOWN,
					KEY_LEFT: Vector2i.LEFT,
					KEY_RIGHT: Vector2i.RIGHT
				}[key],
				size
			)
		elif (
			key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]
			and not snapshot.is_empty()
			and not snapshot.skills.is_empty()
		):
			model.stage = "skills"
			_browse_transition = 0
			browse_alpha = 1.0
			detail_scroll = 0.0
		elif key == KEY_D:
			if not snapshot.is_empty():
				model.stage = "actions"
			else:
				model.description_visible = not model.description_visible
	refresh()


func draw_marks(target: Node2D) -> void:
	if model == null:
		return
	for event in model.events():
		if event.id in model.focused_ids:
			var rect = Rect2(Vector2(event.cell) * 32, Vector2(32, 32))
			target.draw_rect(rect, Color8(0, 224, 72, 128))
			target.draw_rect(rect, Color8(112, 255, 136, 224), false, 2)
	var color = Color8(200, 200, 200, 128)
	var event = model.event_at_cursor()
	if model.cursor == Vector2i(RuntimeState.player_x, RuntimeState.player_y):
		color = Color8(50, 179, 240, 192)
	elif not event.is_empty():
		if event.name.contains("怪物"):
			color = Color8(255, 0, 0, 160)
		elif event.name.contains("物品"):
			color = Color8(0, 255, 0, 160)
		elif event.name.contains("门"):
			color = Color8(255, 255, 0, 160)
	if model.focus in [1, 2]:
		color = Color8(255, 0, 0, 160)
	var rect = Rect2(Vector2(model.cursor) * 32, Vector2(32, 32))
	target.draw_rect(rect, color)
	target.draw_rect(rect, Color.WHITE, false, 2)


func _near_tile(dimensions: Vector2) -> Vector2:
	var transform = game.event_map().get_global_transform_with_canvas()
	var point = transform * (Vector2(model.cursor) * 32)
	var candidates = [
		point + Vector2(40, 16 - dimensions.y / 2),
		point + Vector2(-dimensions.x - 8, 16 - dimensions.y / 2),
		point + Vector2(16 - dimensions.x / 2, -dimensions.y - 8),
		point + Vector2(16 - dimensions.x / 2, 40)
	]
	var tile = Rect2(point, Vector2(32, 32))
	for candidate in candidates:
		var clamped = Vector2(
			clampf(candidate.x, 8, maxf(8, size.x - dimensions.x - 8)),
			clampf(candidate.y, 88, maxf(88, size.y - dimensions.y - 56))
		)
		if not Rect2(clamped, dimensions).intersects(tile):
			return clamped
	return Vector2(8, 88)


func _process(delta: float) -> void:
	if _closed or not is_finite(delta) or delta < 0:
		return
	_window_clock += delta * 60
	var ticks = mini(120, int(_window_clock))
	_window_clock -= ticks
	window_process = clampi(window_process + (-ticks if _closing else ticks), 0, 8)
	if _content != null:
		_content.set_progress(window_process)
	for tick in ticks:
		_tick_browse()
	if _content != null and _content.regions.has("detail_body"):
		_content.regions.detail_body.modulate.a = browse_alpha
	_hp_clock = fmod(_hp_clock + delta * 60, 96)
	_update_hp()
	queue_redraw()
	if _closing and window_process == 0:
		_closed = true
		close_requested.emit()


func _update_hp() -> void:
	if _hp_label == null or snapshot.is_empty():
		return
	var hp = int(snapshot.enemy.hp)
	var maximum = maxi(1, int(snapshot.attributes.maxhp))
	var damage = maxi(0, int(snapshot.result.enemy_damage))
	var after = maxi(0, hp - damage)
	_hp_label.text = "生命 %d / %d  −%d" % [hp, maximum, damage]
	_after_hp_label.text = "战后 %d / %d  %d%%" % [after, maximum, int(after * 100 / maximum)]
	var opacity = hp_opacities(int(_hp_clock))
	_hp_label.modulate.a = opacity[0] / 255.0
	_after_hp_label.modulate.a = opacity[1] / 255.0


static func hp_opacities(frame: int) -> Array:
	frame = posmod(frame, 96)
	if frame < 16:
		return [clampi(255 - 16 * (frame + 1), 0, 255), clampi(16 * (frame + 1), 0, 255)]
	if frame < 48:
		return [0, 255]
	if frame < 64:
		return [clampi(16 * (frame - 47), 0, 255), clampi(255 - 16 * (frame - 47), 0, 255)]
	return [255, 0]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.45, 0.45, 0.5 * window_process / 8.0))


func _exit_tree() -> void:
	if _marks != null and is_instance_valid(_marks):
		_marks.queue_free()


func _begin_browse(direction: int, manual: bool) -> void:
	if snapshot.is_empty() or snapshot.skills.is_empty():
		return
	_pending_browse = posmod(automatic_index + direction, snapshot.skills.size())
	_browse_transition = 16
	_browse_clock = 0
	if manual:
		_automatic = false


func _tick_browse() -> void:
	if snapshot.is_empty() or model.stage not in ["map", "targets"] or snapshot.skills.size() < 2:
		return
	if _browse_transition > 0:
		_browse_transition -= 1
		browse_alpha = (
			[255, 195, 143, 99, 63, 35, 15, 3, 0, 3, 15, 35, 63, 99, 143, 195, 255][
				16 - _browse_transition
			]
			/ 255.0
		)
		if _browse_transition == 8:
			automatic_index = _pending_browse
			detail_scroll = 0.0
			View.render(self, _content)
	elif _automatic:
		_browse_clock += 1
		if _browse_clock >= 208:
			_begin_browse(1, false)
	# 原0235手动Q/E后的process每帧重置120，实际不会恢复自动；保持到切换敌人。

## 职责：恢复原主菜单错位文字、独立选中层、货币和八帧进退，维护子页及地图暂停归属。
##
## 调用方式：
##   MenuCoordinator在正式地图创建本页并保持暂停，save_callback仍绑定Game.save_slot。
##   window_process/child_process是0—8逻辑帧；每秒60帧，由本页唯一推进；关闭动画结束才发出close_requested。
##   菜单变量5的锁定规则保持，原装备/成就/合成空分支仍不创建新业务。
##
## 调用接口：
##   func enabled(command: int) -> bool
##     参数 command（int；必填）：0—9原命令索引，按COMMANDS两行错位排列。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func ready_for_input() -> bool
##     用途：检查入场/子页过渡是否完成、关闭或提交请求是否占用输入。
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func activate() -> void
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func resume_after_failed_load() -> void
##     用途：所属协调器在真实读档失败时恢复输入；成功切场景不调用。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func back() -> void
##     用途：从当前页面或操作返回。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   close_requested()：原8帧关闭完成，通知协调器恢复同一地图和事件调用者。
##   title_requested()：用户确认返回标题，交由正式场景切换处理。
##   sound_requested(key: String)：由持有方发出，通知对应状态或操作结果。
##     key：查询或写入使用的键名。
##   load_requested(slot: int)：请求校验并恢复真实存档；一次提交期间不重复发出。
##     slot：所选正式存档编号，由所属协调器校验和恢复。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 公开常量：COMMANDS、DEFAULT_LOCKS、ENGLISH。
## 接口说明结束。

extends Control
## 最终0198/0200—0203：原主菜单不另开Scene，保持地图暂停及其事件调用者。
const Model = preload("MenuModel.gd")
const Pages = preload("MenuPages.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Drawing = preload("../../04_UI_Common/WindowDrawing.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Palette = preload("../../04_UI_Common/Palette.gd")
const COMMANDS = Model.COMMANDS
const DEFAULT_LOCKS = Model.DEFAULT_LOCKS
const ENGLISH = [
	"Items",
	"Save&Load",
	"Equipments",
	"Notes",
	"Blastics",
	"Achieve",
	"ItemCraft",
	"Config",
	"Skills",
	"Title"
]
signal close_requested
signal title_requested
signal sound_requested(key: String)
signal load_requested(slot: int)
var page = "flash_menu"
var index = 0
var save_callback: Callable
var child: Control
var active_command = -1
var window_process = 0
var child_process = 0
var _clock = 0.0
var _closing = false
var _child_closing = false
var _submitted = false
var _close_emitted = false
var _font: Font
var _artwork: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Model.initialize(RuntimeState)
	_font = Resources.font()
	_artwork = Control.new()
	_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_artwork.z_index = 10
	_artwork.draw.connect(_draw_artwork)
	add_child(_artwork)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func enabled(command: int) -> bool:
	return Model.enabled(RuntimeState, command)


func refresh() -> void:
	if is_inside_tree() and _artwork != null:
		_artwork.queue_redraw()


func ready_for_input() -> bool:
	return (
		not _closing
		and not _child_closing
		and not _submitted
		and window_process == 8
		and (child == null or child_process == 8)
	)


func activate() -> void:
	if not ready_for_input() or child != null:
		return
	if not enabled(index):
		sound_requested.emit("buzzer_se")
		return
	# 最终0202的三个空分支保持空分支，不补造装备/成就/合成业务。
	if index in [2, 5, 6]:
		return
	if index == 9:
		_submitted = true
		sound_requested.emit("decision_se")
		title_requested.emit()
		return
	child = Pages.create(index, save_callback)
	if child == null:
		return
	child.z_index = 11
	active_command = index
	child_process = 0
	if index == 1:
		child.load_requested.connect(_request_load)
	child.back_requested.connect(back)
	if child.has_signal("sound_requested"):
		child.sound_requested.connect(func(key: String): sound_requested.emit(key))
	if child.has_signal("common_event_requested"):
		child.common_event_requested.connect(func(): close_requested.emit())
	add_child(child)
	_apply_child_transition()
	sound_requested.emit("decision_se")
	refresh()


func resume_after_failed_load() -> void:
	_submitted = false


func _request_load(slot: int) -> void:
	if _submitted:
		return
	_submitted = true
	load_requested.emit(slot)


func back() -> void:
	if _closing or _child_closing or _submitted:
		return
	if child == null:
		_closing = true
	else:
		_child_closing = true
	if child == null or child.get("_saved_successfully") != true:
		sound_requested.emit("cancel_se")


func handle_key(key: int) -> void:
	if not ready_for_input():
		return
	if child != null:
		var surface = child.get("_content")
		if (
			key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
			and surface != null
			and surface.has_method("navigation_ready")
			and not surface.navigation_ready()
		):
			return
		if child.has_method("handle_key"):
			child.handle_key(key)
		return
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		index = posmod(index + {KEY_UP: -1, KEY_DOWN: 1, KEY_LEFT: -2, KEY_RIGHT: 2}[key], 10)
		sound_requested.emit("cursor_se")
		refresh()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()


func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	_clock += delta * 60
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	for tick in ticks:
		_tick()


func _tick() -> void:
	if _close_emitted:
		return
	window_process = clampi(window_process + (-1 if _closing else 1), 0, 8)
	if child != null:
		child_process = clampi(child_process + (-1 if _child_closing else 1), 0, 8)
		_apply_child_transition()
		if _child_closing and child_process == 0:
			remove_child(child)
			child.queue_free()
			child = null
			active_command = -1
			_child_closing = false
	if _closing and window_process == 0:
		_submitted = true
		_close_emitted = true
		close_requested.emit()
	refresh()


func _apply_child_transition() -> void:
	if child.has_method("set_menu_progress"):
		child.set_menu_progress(child_process)
	elif child.has_method("set_title_progress"):
		child.set_title_progress(child_process * 2)
	else:
		child.modulate.a = child_process / 8.0
		child.position.y = (8 - child_process) * 8


func _draw_artwork() -> void:
	var show_command = (
		child == null or active_command == 7 or active_command == 0 and child.stage != "target"
	)
	var progress_value = window_process if show_command else mini(window_process, 8 - child_process)
	if progress_value > 0:
		var top = -64 + 8 * progress_value
		var alpha = minf(1, progress_value * 32.0 / 255)
		_artwork.draw_texture(
			Drawing.panel(Vector2i(544, 128)), Vector2(48, top), Color(1, 1, 1, alpha)
		)
		for command in 10:
			var column = int(command / 2)
			var row = command % 2
			var point = Vector2(64 + 96 * column + 32 * row, top + 20 + 40 * row)
			var english = point + Vector2(16 - 32 * row, 8)
			Drawing.text(
				_artwork,
				_font,
				Rect2(english, Vector2(96, 48)),
				ENGLISH[command],
				20,
				Color8(192, 192, 160, int(160 * alpha)),
				HORIZONTAL_ALIGNMENT_CENTER
			)
			Drawing.text(
				_artwork,
				_font,
				Rect2(point, Vector2(96, 48)),
				COMMANDS[command],
				20,
				Color(1, 1, 1, alpha * (1 if enabled(command) else 0.5)),
				HORIZONTAL_ALIGNMENT_CENTER
			)
		if child == null and not _closing:
			var point = Vector2(
				64 + int(index / 2) * 96 + index % 2 * 32, top + 20 + index % 2 * 40
			)
			# 独立覆盖层由原四字渐亮及下划线构成，没有原生按钮底色。
			for letter in COMMANDS[index].length():
				var tint = [
					Color8(128, 255, 224),
					Color8(160, 255, 240),
					Color8(192, 255, 255),
					Color8(160, 255, 240)
				][mini(letter, 3)]
				tint.a = alpha
				Drawing.text(
					_artwork,
					_font,
					Rect2(point + Vector2(8 + 20 * letter, 0), Vector2(20, 48)),
					COMMANDS[index][letter],
					20,
					tint,
					HORIZONTAL_ALIGNMENT_CENTER
				)
			_artwork.draw_line(
				point + Vector2(0, 40), point + Vector2(96, 40), Color(0.6, 1, 0.95, alpha * 0.7)
			)
	if child == null or _child_closing or active_command == 0:
		var currency_progress = (
			mini(window_process, 8 - child_process)
			if child != null and active_command != 0
			else window_process
		)
		var alpha = minf(1, currency_progress * 32.0 / 255)
		var base = Vector2(size.x - 32 - 12 * currency_progress, size.y - 192)
		_artwork.draw_texture(Drawing.panel(Vector2i(128, 192)), base, Color(1, 1, 1, alpha))
		var crystal = Cache.picture("Causal/耀晶石.png")
		for i in 5:
			if crystal != null:
				_artwork.draw_texture_rect_region(
					crystal,
					Rect2(base + Vector2(24, 20 + 24 * i), Vector2(16, 16)),
					Rect2(16 * i, 0, 16, 16),
					Color(1, 1, 1, alpha)
				)
			var tint = Palette.color(22 + i)
			tint.a *= alpha
			Drawing.text(
				_artwork,
				_font,
				Rect2(base + Vector2(48, 20 + 24 * i), Vector2(56, 25)),
				str(RuntimeState.custom_data.currency("spar:%d" % i)),
				18,
				tint,
				HORIZONTAL_ALIGNMENT_RIGHT
			)
		Drawing.text(
			_artwork,
			_font,
			Rect2(base + Vector2(24, 132), Vector2(80, 20)),
			"—— Point ——",
			16,
			Color(0.75, 0.88, 1, alpha),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		Drawing.text(
			_artwork,
			_font,
			Rect2(base + Vector2(24, 148), Vector2(80, 25)),
			str(RuntimeState.gold),
			18,
			Color(1, 0.85, 0.5, alpha),
			HORIZONTAL_ALIGNMENT_CENTER
		)

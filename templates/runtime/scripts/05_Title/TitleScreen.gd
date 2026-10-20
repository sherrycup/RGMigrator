## 职责：使用原背景、标志、命令图和难度卡片组织标题输入及附页生命周期。
##
## 调用方式：
##   Title场景创建并连接new_game_requested与load_requested；本节点只负责显示和请求，状态初始化与读档仍由Title处理。
##   标题主命令、难度和其它附页使用16帧；档案与Load Data页签按原8帧、40像素/帧与32透明度/帧推进；本节点拥有唯一父时钟，确认后拒绝重复提交。
##   主命令采用原图；独立副本和无有效存档的继续游戏可选中但灰显且不可确认。
##
## 调用接口：
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func ready_for_input() -> bool
##     用途：查询标题是否完成当前过渡且尚未提交开始或退出请求。
##     参数：无。
##     返回：true表示可路由一次按键；false表示过渡、返回或已提交请求。
##
##   func activate() -> void
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func resume_after_failed_load() -> void
##     用途：正式Title读取失败时调用，恢复当前档案页面的输入；成功切换场景不调用。
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
##   new_game_requested(difficulty: int)：一次确认后发出，由Title初始化正式游戏并写入原难度变量。
##     difficulty：四档原难度索引0—3，由Title写入原DIFFCULTY_MODE变量。
##   load_requested(slot: int)：一次确认后发出，由Title调用正式SaveService；失败时回调resume_after_failed_load释放输入。
##     slot：已经在正式档案页选中的存档编号；读档仍由Title/SaveService完整校验。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _draw() -> void
##
## 公开常量：COMMANDS、TAGS。
## 注意：本页面不自行加载存档或切换地图；成功提交后禁用重复输入，失败恢复仍由所属Title负责。
## 接口说明结束。

extends Control
## 最终0139—0142。命令和难度均绘制原图片；本节点唯一推进标题的60Hz逻辑帧。
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
const Saves = preload("../10_Support/Persistence/SaveService.gd")
const Layout = preload("TitleLayout.gd")
const COMMANDS = ["新游戏", "继续游戏", "独立副本", "成就一览", "音乐鉴赏", "游戏设置", "离开游戏"]
const TAGS = {0: "mode", 1: "file", 3: "merit", 4: "music", 5: "config"}
signal new_game_requested(difficulty: int)
signal load_requested(slot: int)
var index = 0
var difficulty = 1
var page = "title"
var child: Control
var frame = 0
var logo_progress = 0
var selection_ticks = 16
var mode_ticks = 16
var page_progress = 0
var title_progress = 16
var _clock = 0.0
var _background: TextureRect
var _logo: TextureRect
var _artwork: Control
var _frames: Dictionary = {}
var _order: Array = []
var _background_pending: Dictionary = {}
var _old_index = 0
var _direction = 0
var _mode_from = 1
var _tag_kind = ""
var _closing = false
var _continue_enabled = false
var _starting = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.texture = Cache.title("title_1/bg000")
	add_child(_background)
	_logo = TextureRect.new()
	_logo.texture = Cache.title("金色.png")
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_artwork = Control.new()
	_artwork.z_index = 10
	_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_artwork.draw.connect(_draw_artwork)
	add_child(_artwork)
	_continue_enabled = Saves.has_valid_save()
	index = 1 if _continue_enabled else 0
	_old_index = index
	resized.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	if _logo.texture != null:
		_logo.size = _logo.texture.get_size()
		_logo.position = Vector2((size.x - _logo.size.x) / 2, -20 + 5 * logo_progress)
		_logo.modulate.a = minf(logo_progress * 16 / 255.0, 1)
	_artwork.queue_redraw()
	queue_redraw()


func ready_for_input() -> bool:
	return (
		not _starting
		and not _closing
		and (
			selection_ticks == 16 and title_progress == 16
			if page == "title"
			else page_progress == (8 if page == "file" else 16) and mode_ticks == 16
		)
	)


func activate() -> void:
	if not ready_for_input() or child != null:
		return
	if index == 2 or index == 1 and not _continue_enabled:
		Resources.play_sound(self, "buzzer_se")
		return
	Resources.play_sound(self, "decision_se")
	if index == 6:
		_starting = true
		RuntimeState.request_quit()
		return
	_old_index = index
	_tag_kind = TAGS.get(index, "")
	page_progress = 0
	if index == 0:
		page = "mode"
		_mode_from = difficulty
		mode_ticks = 16
		return
	page = _tag_kind
	var script: Script
	if index == 1:
		script = load("res://runtime/scripts/07_Archive/ArchivePage.gd")
	elif index == 5:
		script = preload("ConfigPage.gd")
	else:
		script = preload("TitleExtrasPage.gd")
	child = script.new()
	if index == 1:
		child.z_index = 11
		child.mode = "load"
		child.allow_mode_switch = false
		child.load_requested.connect(_request_load)
		child.sound_requested.connect(func(key: String): Resources.play_sound(self, key))
	elif index in [3, 4]:
		child.kind = "merit" if index == 3 else "music"
	child.back_requested.connect(back)
	add_child(child)
	_apply_child_transition()


func resume_after_failed_load() -> void:
	_starting = false


func _request_load(slot: int) -> void:
	if _starting:
		return
	_starting = true
	load_requested.emit(slot)


func back() -> void:
	if _starting or _closing or page == "title":
		return
	Resources.play_sound(self, "cancel_se")
	_closing = true
	page = "title"


func handle_key(key: int) -> void:
	if not ready_for_input():
		return
	if child != null:
		if child.has_method("handle_key"):
			child.handle_key(key)
		elif key in [KEY_ESCAPE, KEY_X]:
			child.back()
		elif key in [KEY_UP, KEY_LEFT]:
			child.navigate(-1)
		elif key in [KEY_DOWN, KEY_RIGHT]:
			child.navigate(1)
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
			child.activate()
		return
	if page == "mode":
		if key in [KEY_ESCAPE, KEY_X]:
			back()
		elif key in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
			var next = clampi(difficulty + (-1 if key in [KEY_LEFT, KEY_UP] else 1), 0, 3)
			if next != difficulty:
				_mode_from = difficulty
				difficulty = next
				mode_ticks = 0
				Resources.play_sound(self, "cursor_se")
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
			_starting = true
			Resources.play_sound(self, "decision_se")
			new_game_requested.emit(difficulty)
	elif key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_old_index = index
		_direction = -1 if key in [KEY_UP, KEY_LEFT] else 1
		index = posmod(index + _direction, 7)
		selection_ticks = 0
		Resources.play_sound(self, "cursor_se")
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()


func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	_clock += delta * 60
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	for i in ticks:
		_tick()
	refresh()


func _tick() -> void:
	_update_background()
	logo_progress = clampi(logo_progress + (1 if page == "title" else -1), 0, 16)
	title_progress = clampi(title_progress + (1 if page == "title" else -1), 0, 16)
	page_progress = clampi(
		page_progress + (-1 if page == "title" else 1), 0, 8 if _tag_kind == "file" else 16
	)
	selection_ticks = mini(16, selection_ticks + 1)
	if selection_ticks == 16:
		_old_index = index
		_direction = 0
	mode_ticks = mini(16, mode_ticks + 1)
	if mode_ticks == 16:
		_mode_from = difficulty
	_apply_child_transition()
	if _closing and page_progress == 0:
		if child != null:
			remove_child(child)
			child.queue_free()
			child = null
		_closing = false
		_tag_kind = ""
		_continue_enabled = Saves.has_valid_save()
	refresh()


func _apply_child_transition() -> void:
	if child == null:
		return
	if child.has_method("set_title_progress"):
		child.set_title_progress(page_progress)
	else:
		child.modulate.a = page_progress / 16.0
		child.position.y = (16 - page_progress) * 6


func _draw_artwork() -> void:
	if title_progress > 0:
		var movement = _direction * selection_ticks / 16.0
		for relative in range(-2, 3):
			var id = posmod(_old_index + relative, 7)
			var pose = Layout.command_pose(relative, movement, title_progress, size)
			var texture = Cache.title("title/com_%d.png" % id)
			if texture != null and pose.opacity > 0:
				var tint = (
					Color(0.5, 0.5, 0.5, pose.opacity)
					if id == 2 or id == 1 and not _continue_enabled
					else Color(1, 1, 1, pose.opacity)
				)
				_artwork.draw_texture_rect(
					texture,
					Rect2(
						pose.position - Vector2(121, 25) * pose.zoom, texture.get_size() * pose.zoom
					),
					false,
					tint
				)
	if _tag_kind == "mode" and page_progress > 0:
		var selection = lerpf(_mode_from, difficulty, mode_ticks / 16.0)
		for id in 4:
			var pose = Layout.mode_pose(id, selection, page_progress, size)
			var texture = Cache.title("mode/mode_%d.png" % (id + 1))
			if texture != null:
				_artwork.draw_texture(
					texture, pose.position - Vector2(144, 80), Color(1, 1, 1, pose.opacity)
				)
	if not _tag_kind.is_empty() and page_progress > 0:
		var texture = Cache.title(_tag_kind + "/tag.png")
		if texture != null:
			_artwork.draw_texture_rect(
				texture,
				Layout.tag_rect(page_progress * 2 if _tag_kind == "file" else page_progress, size),
				false,
				Color(1, 1, 1, minf(1, page_progress * (32 if _tag_kind == "file" else 16) / 255.0))
			)


func _update_background() -> void:
	for id in _background_pending.keys():
		var status = ResourceLoader.load_threaded_get_status(_background_pending[id])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_frames[id] = (
			ResourceLoader.load_threaded_get(_background_pending[id])
			if status == ResourceLoader.THREAD_LOAD_LOADED
			else null
		)
		_background_pending.erase(id)
		_order.append(id)
		if _order.size() > 32:
			_frames.erase(_order.pop_front())
	for offset in 8:
		_request_background(posmod(frame + offset, 480))
	if _frames.has(frame) and _frames[frame] != null:
		_background.texture = _frames[frame]
	frame = posmod(frame + 1, 480)


func _request_background(id: int) -> void:
	if _frames.has(id) or _background_pending.has(id) or _background_pending.size() >= 8:
		return
	var path = Cache.resolve("Titles", "title_1/bg%03d" % id)
	if (
		not path.is_empty()
		and ResourceLoader.exists(path)
		and ResourceLoader.load_threaded_request(path) == OK
	):
		_background_pending[id] = path


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("131e22"))

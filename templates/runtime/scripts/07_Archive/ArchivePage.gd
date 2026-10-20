## 职责：管理档案目录、八帧选择/入场、截图缓存及一次存读档提交，读写由原SaveService负责。
##
## 调用方式：
##   标题、菜单或事件存档创建本页；设置mode及save_callback后加入场景树。SaveService是唯一存读档实现。
##   独立页面自己推进0—8帧入退；标题通过set_title_progress、菜单通过set_menu_progress提供唯一父过渡，避免重复推进。
##   选择/截图各按原8帧推进；目录仅在显式refresh时读取摘要；光标导航不重新解码存档或重建页面。
##   成功提交后等待所属页面关闭或切图；读取失败由持有方resume_after_failed_load恢复输入。
##
## 调用接口：
##   func refresh(reload_catalog: bool = true) -> void
##     用途：按当前状态刷新显示或缓存。
##     参数 reload_catalog（bool；默认值 true）：true重新核对槽位摘要并恢复可用输入；false只刷新当前绘制与选择。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func ready_for_input() -> bool
##     用途：检查入场、选择、模式切换和提交是否允许当前按键。
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func set_title_progress(value: int) -> void
##     用途：由标题唯一时钟推进原8帧档案过渡，与标题其它页16帧进退分开。
##     参数 value（int；必填）：父页面给出的原档案过渡进度；标题和菜单均为0—8。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_menu_progress(value: int) -> void
##     用途：由菜单唯一8帧时钟驱动入退，停止本页重复推进父过渡。
##     参数 value（int；必填）：父页面给出的原档案过渡进度；标题和菜单均为0—8。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func resume_after_failed_load() -> void
##     用途：在正式读档失败后释放一次提交保护，不改变游戏状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func cursor_position() -> Vector2
##     用途：计算未扣除横向滚动的插值卡片光标位置。
##     参数：无。
##     返回：以120×64原网格为单位的本地像素坐标。
##
##   func navigate(direction: int) -> void
##     用途：移动当前页面的选中项。
##     参数 direction（int；必填）：上下为-1/+1，左右为-4/+4；左右按原列及剩余行数循环。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func activate() -> void
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func execute() -> void
##     用途：执行该脚本或已准备的操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func back() -> void
##     用途：先取消确认框，否则请求父页面退场或自行完成原8帧退出。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

extends "SaveSlots.gd"
## JSON存档和校验仍归SaveService；本页只拥有目录快照、选择、动画及提交生命周期。
const Archive = preload("ArchiveData.gd")
const View = preload("ArchiveView.gd")
var page = "save"
var allow_mode_switch = true
var window_process = 0
var preview_process = 8
var preview_id = -1
var selection_ticks = 8
var _clock = 0.0
var _slots: Array = []
var _archives: Dictionary = {}
var _current: Dictionary = {}
var _catalog_ready = false
var _external_transition = false
var _closing = false
var _submitted = false
var _saved_successfully = false
var _close_emitted = false
var _confirmation_accepted = false
var _cursor_from = Vector2.ZERO
var _scroll_offset = 0.0
var _mode_from = "save"
var _mode_ticks = 8
var _view: Control
var _preview_image: Image
var _preview_texture: ImageTexture
var _next: Image
var _preview_surface: SubViewport
var _previous_view: TextureRect
var _next_view: TextureRect
var _preview_cache: Dictionary = {}
var _preview_order: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected = maxi(0, int(RuntimeState.flash_temp_fields.get("last_file_index", 0)))
	_mode_from = mode
	_ensure_preview_surface()
	_view = View.new()
	_view.page = self
	add_child(_view)
	_panel = _view
	refresh()


func refresh(reload_catalog: bool = true) -> void:
	if reload_catalog or not _catalog_ready:
		_slots = Saves.existing_slots()
		if mode == "save":
			var next = 1
			while next in _slots:
				next += 1
			if next <= Saves.maximum_slots():
				_slots.append(next)
		_infos.clear()
		_archives.clear()
		for slot in _slots:
			var info = Saves.slot_info(slot)
			_infos.append(info)
			_archives[slot] = info.get("archive", {})
		_catalog_ready = true
		_submitted = false
	selected = clampi(selected, 0, maxi(0, _slots.size() - 1))
	selection_ticks = 8
	_cursor_from = Vector2(int(selected / 4) * 120, selected % 4 * 64)
	_scroll_offset = clampf(_scroll_offset, maxf(0, _cursor_from.x - 120), _cursor_from.x)
	_confirm = _view if not _confirmation.is_empty() else null
	_update_selection()


func _update_selection() -> void:
	_current = _archives.get(_slots[selected], {}) if not _slots.is_empty() else {}
	_select_preview(_slots[selected] if not _slots.is_empty() else 0, _current)
	if _view != null:
		_view.refresh()


func ready_for_input() -> bool:
	return (
		not _closing
		and not _submitted
		and window_process == 8
		and selection_ticks == 8
		and _mode_ticks == 8
	)


func set_title_progress(value: int) -> void:
	set_menu_progress(clampi(value, 0, 8))


func set_menu_progress(value: int) -> void:
	_external_transition = true
	window_process = clampi(value, 0, 8)
	if _view != null:
		_view.refresh()


func resume_after_failed_load() -> void:
	_submitted = false
	if _view != null:
		_view.refresh()


func cursor_position() -> Vector2:
	return _cursor_from.lerp(
		Vector2(int(selected / 4) * 120, selected % 4 * 64), selection_ticks / 8.0
	)


func _process(delta: float) -> void:
	if _close_emitted or not is_finite(delta) or delta < 0:
		return
	_clock += delta * 60
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	for tick in ticks:
		if not _external_transition:
			window_process = clampi(window_process + (-1 if _closing else 1), 0, 8)
		selection_ticks = mini(8, selection_ticks + 1)
		_mode_ticks = mini(8, _mode_ticks + 1)
		var cursor = cursor_position()
		_scroll_offset = clampf(_scroll_offset, maxf(0, cursor.x - 120), cursor.x)
		if preview_process < 8:
			preview_process += 1
			_compose_preview()
		if _closing and window_process == 0:
			_submitted = true
			_close_emitted = true
			back_requested.emit()
			return
	if _view != null and ticks > 0:
		_view.refresh()


func navigate(direction: int) -> void:
	if not ready_for_input():
		return
	if not _confirmation.is_empty():
		_confirmation_accepted = not _confirmation_accepted
		_view.refresh()
		return
	if _slots.is_empty():
		return
	var next = selected
	if abs(direction) == 4:
		var column = int(selected / 4)
		var row = selected % 4
		var count = (
			int(_slots.size() / 4) + int(_slots.size() % 4 > row)
			if direction < 0
			else ceili(_slots.size() / 4.0)
		)
		next = mini(
			_slots.size() - 1,
			posmod(column + (-1 if direction < 0 else 1), maxi(1, count)) * 4 + row
		)
	else:
		next = posmod(selected + direction, _slots.size())
	if next != selected:
		_cursor_from = cursor_position()
		selected = next
		selection_ticks = 0
		_update_selection()
	sound_requested.emit("cursor_se")


func activate() -> void:
	if not ready_for_input():
		return
	if _slots.is_empty():
		sound_requested.emit("buzzer_se")
		return
	if not _confirmation.is_empty():
		var accepted = _confirmation_accepted
		_confirmation = ""
		_confirm = null
		if accepted:
			execute()
		else:
			_view.refresh()
	elif mode == "save" and _infos[selected].exists:
		_confirmation = "overwrite"
		_confirmation_accepted = false
		_confirm = _view
		_view.refresh()
	elif mode == "load" and _infos[selected].get("recovered", false):
		_confirmation = "backup"
		_confirmation_accepted = false
		_confirm = _view
		_view.refresh()
	else:
		execute()


func execute() -> void:
	if _submitted:
		return
	if mode == "load":
		if _infos[selected].ok:
			_submitted = true
			RuntimeState.flash_temp_fields.last_file_index = selected
			load_requested.emit(int(_slots[selected]))
		else:
			message = _infos[selected].message
			sound_requested.emit("buzzer_se")
			refresh()
		return
	_submitted = true
	var result: Dictionary = (
		save_callback.call(int(_slots[selected]))
		if save_callback.is_valid()
		else Saves.fail("存档调用上下文不可用。")
	)
	message = result.message
	sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	if result.ok:
		_saved_successfully = true
		RuntimeState.flash_temp_fields.last_file_index = selected
		_submitted = false
		back()
	else:
		_submitted = false
		_view.refresh()


func back() -> void:
	if not _confirmation.is_empty():
		_confirmation = ""
		_confirm = null
		sound_requested.emit("cancel_se")
		_view.refresh()
		return
	if _submitted or _closing:
		return
	if _external_transition:
		back_requested.emit()
	else:
		if not _saved_successfully:
			sound_requested.emit("cancel_se")
		_closing = true


func handle_key(key: int) -> void:
	if not ready_for_input():
		return
	if key == KEY_TAB and allow_mode_switch and _confirmation.is_empty():
		_mode_from = mode
		mode = "load" if mode == "save" else "save"
		_mode_ticks = 0
		refresh()
		sound_requested.emit("cursor_se")
	elif key in [KEY_ESCAPE, KEY_X]:
		back()
	elif key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		navigate({KEY_UP: -1, KEY_DOWN: 1, KEY_LEFT: -4, KEY_RIGHT: 4}[key])
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()


func _select_preview(id: int, data: Dictionary) -> void:
	# Refreshing an overwritten slot may change its picture without changing ID.
	var identity = str(id) + ":" + str(data.get("png", "")).sha256_text()
	if _preview_surface.get_meta("identity", "") == identity:
		return
	_preview_surface.set_meta("identity", identity)
	if preview_process < 8 and DisplayServer.get_name() != "headless":
		var current = _preview_surface.get_texture().get_image()
		_previous_view.texture = (
			ImageTexture.create_from_image(current)
			if current != null and not current.is_empty()
			else _preview_texture
		)
	else:
		_previous_view.texture = _preview_texture
	preview_id = id
	var key = str(data.get("png", "")).sha256_text()
	if not _preview_cache.has(key):
		_next = Archive.preview(data)
		var canvas = Image.create(352, 352, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		if _next != null:
			var image: Image = _next.duplicate()
			image.resize(316, 316, Image.INTERPOLATE_BILINEAR)
			canvas.blend_rect(image, Rect2i(0, 0, 316, 316), Vector2i(10, 10))
		_preview_cache[key] = {"image": canvas, "texture": ImageTexture.create_from_image(canvas)}
		_next = null
	_preview_order.erase(key)
	_preview_order.append(key)
	while _preview_order.size() > 8:
		_preview_cache.erase(_preview_order.pop_front())
	_preview_image = _preview_cache[key].image
	_preview_texture = _preview_cache[key].texture
	_next_view.texture = _preview_texture
	preview_process = 0
	_compose_preview()


func _compose_preview() -> void:
	_previous_view.modulate.a = clampi(256 - preview_process * 32, 0, 255) / 255.0
	_next_view.modulate.a = clampi(preview_process * 32, 0, 255) / 255.0
	_preview_surface.render_target_update_mode = SubViewport.UPDATE_ONCE


func _ensure_preview_surface() -> void:
	if _preview_surface != null:
		return
	_preview_surface = SubViewport.new()
	_preview_surface.size = Vector2i(352, 352)
	_preview_surface.transparent_bg = true
	_preview_surface.disable_3d = true
	_preview_surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_preview_surface)
	_previous_view = TextureRect.new()
	_previous_view.size = Vector2(352, 352)
	_preview_surface.add_child(_previous_view)
	_next_view = TextureRect.new()
	_next_view.size = Vector2(352, 352)
	_preview_surface.add_child(_next_view)

## 职责：编辑动画帧、单元和时序，协调素材预览及动画草稿提交。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/04_Database/Editor_AnimationEditor.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(value: Dictionary, documents: RefCounted) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draft() -> Dictionary
##     用途：取得可交给调用方的独立编辑草稿。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 对外信号：
##   changed(animation: Dictionary)：当前模型或草稿已经变化，界面可据此刷新。
##     animation：animation。
##   edit_requested(path: Array)：由持有方发出，通知对应状态或操作结果。
##     path：待读取、写入或定位的文件路径。
##
## 场景树回调（Godot 自动调用）：
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 公开常量：CELL_LABELS。
## 接口说明结束。

@tool
extends VBoxContainer
const Schema = preload("Editor_DatabaseSchema.gd")
const CELL_LABELS = ["图案（-1隐藏）", "X（像素）", "Y（像素）", "缩放（%）", "旋转（°）", "镜像", "不透明度（0…255）", "混合方式"]
signal changed(animation: Dictionary)
signal edit_requested(path: Array)
var _value: Dictionary = {}
var _documents: RefCounted
var _frames: ItemList
var _canvas: Control
var _cells: Tree
var _timings: Tree
var _frame = 0
var _cell = -1
var _timing = -1
var _cell_controls: Array[Control] = []
var _timing_controls: Dictionary = {}
var _se: Button
var _color: ColorPickerButton
var _status: Label
var _frame_label: Label
var _loading = false
var _playing = false
var _play: Button
var _elapsed = 0.0
var _fps: SpinBox
var _loop: CheckBox
var _hit: CheckBox
var _audio: Node


func configure(value: Dictionary, documents: RefCounted) -> void:
	_value = value.duplicate(true)
	_documents = documents
	if _canvas == null:
		_build()
	_frame = clampi(_frame, 0, maxi(0, _value.get("frames", []).size() - 1))
	_fill_frames()
	_refresh_frame()
	_fill_timings()


func draft() -> Dictionary:
	return _value.duplicate(true)


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(action)
	return button


func _build() -> void:
	_audio = preload("../05_Assets/Editor_AudioPreview.gd").new()
	add_child(_audio)
	visibility_changed.connect(
		func() -> void:
			if not is_visible_in_tree():
				_stop()
	)
	var tabs = TabContainer.new()
	tabs.use_hidden_tabs_for_min_size = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	var scroll = ScrollContainer.new()
	scroll.name = "帧与单元"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	var bar = HFlowContainer.new()
	page.add_child(bar)
	_button(bar, "追加空白帧", _add_frame.bind(false))
	_button(bar, "复制当前帧", _add_frame.bind(true))
	_button(bar, "删除当前帧", _remove_frame)
	_play = _button(bar, "播放预览", _toggle_play)
	_fps = SpinBox.new()
	_fps.min_value = 1
	_fps.max_value = 120
	_fps.step = 1
	_fps.value = 20
	_fps.suffix = "帧/秒"
	bar.add_child(_fps)
	_loop = CheckBox.new()
	_loop.text = "循环播放"
	bar.add_child(_loop)
	_hit = CheckBox.new()
	_hit.text = "模拟命中"
	_hit.button_pressed = true
	bar.add_child(_hit)
	_button(bar, "添加单元", _add_cell)
	_button(bar, "删除所选单元", _remove_cell)
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	_frames = ItemList.new()
	_frames.custom_minimum_size.x = 105
	split.add_child(_frames)
	_frames.item_selected.connect(
		func(index: int) -> void:
			_stop()
			_frame = index
			_cell = -1
			_refresh_frame()
	)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_frame_label = Label.new()
	right.add_child(_frame_label)
	var body = HSplitContainer.new()
	right.add_child(body)
	var preview_box = VBoxContainer.new()
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(preview_box)
	_canvas = preload("Editor_AnimationCanvas.gd").new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_child(_canvas)
	_cells = Tree.new()
	_cells.hide_root = true
	_cells.columns = 3
	_cells.column_titles_visible = true
	_cells.set_column_title(0, "单元")
	_cells.set_column_title(1, "图案")
	_cells.set_column_title(2, "位置（像素） / 显示")
	_cells.custom_minimum_size.y = 90
	preview_box.add_child(_cells)
	_cells.item_selected.connect(
		func() -> void:
			if not _loading:
				_cell = int(_cells.get_selected().get_metadata(0))
				_sync_cells()
	)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for column in 8:
		var label = Label.new()
		label.text = CELL_LABELS[column]
		label.add_theme_font_size_override("font_size", 12)
		grid.add_child(label)
		var control: Control
		if column in [5, 7]:
			var choice = OptionButton.new()
			control = choice
			for text in ["不镜像", "水平镜像"] if column == 5 else ["正常", "加算", "减算"]:
				choice.add_item(text)
				choice.set_item_metadata(choice.item_count - 1, choice.item_count - 1)
			choice.item_selected.connect(
				func(index: int) -> void: _set_cell(column, int(choice.get_item_metadata(index)))
			)
		else:
			var spin = SpinBox.new()
			control = spin
			spin.step = 1
			spin.min_value = -32768
			spin.max_value = 32767
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.value_changed.connect(func(n: float) -> void: _set_cell(column, int(n)))
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(control)
		_cell_controls.append(control)
	var timing_page = VBoxContainer.new()
	timing_page.name = "音效与闪光时序"
	tabs.add_child(timing_page)
	bar = HBoxContainer.new()
	timing_page.add_child(bar)
	_button(bar, "添加时序", _add_timing)
	_button(bar, "删除所选时序", _remove_timing)
	_timings = Tree.new()
	_timings.hide_root = true
	_timings.columns = 4
	_timings.column_titles_visible = true
	_timings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timing_page.add_child(_timings)
	for column in 4:
		_timings.set_column_title(column, ["帧（从1开始）", "音效", "闪光范围", "条件"][column])
	_timings.item_selected.connect(
		func() -> void:
			if not _loading:
				_timing = int(_timings.get_selected().get_metadata(0))
				_sync_timing()
	)
	grid = GridContainer.new()
	grid.columns = 4
	timing_page.add_child(grid)
	for entry in [
		["帧（从1开始）", "frame", null],
		["闪光范围", "flash_scope", ["无", "目标", "画面", "隐藏目标"]],
		["条件", "condition", ["始终", "命中", "未命中"]],
		["闪光持续（动画帧）", "flash_duration", null],
		["音量（%）", "volume", null],
		["音调（%）", "pitch", null]
	]:
		var label = Label.new()
		label.text = entry[0]
		grid.add_child(label)
		var key = str(entry[1])
		var control: Control
		if entry[2] is Array:
			var choice = OptionButton.new()
			control = choice
			for text in entry[2]:
				choice.add_item(text)
				choice.set_item_metadata(choice.item_count - 1, choice.item_count - 1)
			choice.item_selected.connect(
				func(index: int) -> void: _set_timing(key, int(choice.get_item_metadata(index)))
			)
		else:
			var spin = SpinBox.new()
			control = spin
			spin.step = 1
			spin.min_value = 1 if key == "frame" else 0
			spin.max_value = 10000
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.value_changed.connect(
				func(n: float) -> void: _set_timing(key, int(n) - 1 if key == "frame" else int(n))
			)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(control)
		_timing_controls[key] = control
	bar = HBoxContainer.new()
	timing_page.add_child(bar)
	_se = _button(
		bar,
		"选择音效…",
		func() -> void:
			if _timing >= 0:
				edit_requested.emit(["timings", _timing, "se", "name"])
	)
	_se.clip_text = true
	_se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var color_label = Label.new()
	color_label.text = "闪光颜色"
	bar.add_child(color_label)
	_color = ColorPickerButton.new()
	bar.add_child(_color)
	_color.color_changed.connect(
		func(color: Color) -> void:
			if _loading or _timing < 0:
				return
			var value: Dictionary = _value.timings[_timing].flash_color
			for key in ["red", "green", "blue", "alpha"]:
				value[key] = int(
					round(color[{"red": "r", "green": "g", "blue": "b", "alpha": "a"}[key]] * 255)
				)
			_emit()
	)
	move_child(_audio, get_child_count() - 1)
	_status = Label.new()
	_status.custom_minimum_size.x = 600
	_status.size.x = 600
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


func _fill_frames() -> void:
	_frames.clear()
	for index in _value.get("frames", []).size():
		_frames.add_item("第 %d 帧" % (index + 1))
	if not _value.get("frames", []).is_empty():
		_frames.select(_frame)
		_frames.ensure_current_is_visible()


func _refresh_frame() -> void:
	_loading = true
	_cells.clear()
	var root = _cells.create_item()
	if _value.get("frames", []).is_empty():
		_cell = -1
		_frame_label.text = "当前动画没有帧，请先追加空白帧。"
		_loading = false
		for control in _cell_controls:
			if control is SpinBox:
				control.editable = false
			else:
				control.disabled = true
		_canvas.configure({}, null, 0)
		return
	var frame: Dictionary = _value.frames[_frame]
	var table: Dictionary = frame.get("cell_data", {})
	var width = int(table.get("x_size", 0))
	_cell = (
		clampi(_cell, 0, int(frame.get("cell_max", 0)) - 1)
		if int(frame.get("cell_max", 0)) > 0
		else -1
	)
	for index in mini(int(frame.get("cell_max", 0)), width):
		var item = _cells.create_item(root)
		item.set_metadata(0, index)
		item.set_text(0, str(index + 1))
		var pattern = int(table.values[index])
		item.set_text(1, "隐藏" if pattern < 0 else "图案 %d" % pattern)
		item.set_text(
			2,
			(
				"(%d, %d) · %d%% · %d°"
				% [
					int(table.values[index + width]),
					int(table.values[index + width * 2]),
					int(table.values[index + width * 3]),
					int(table.values[index + width * 4])
				]
			)
		)
		if index == _cell:
			item.select(0)
	_frame_label.text = (
		"第 %d / %d 帧 · %d 个单元 · 图案从0开始"
		% [_frame + 1, _value.frames.size(), int(frame.get("cell_max", 0))]
	)
	_loading = false
	_sync_cells()


func _sync_cells() -> void:
	_loading = true
	for column in 8:
		var control: Control = _cell_controls[column]
		if control is SpinBox:
			control.editable = _cell >= 0
		else:
			control.disabled = _cell < 0
		if _cell < 0:
			continue
		var table: Dictionary = _value.frames[_frame].cell_data
		var value = int(table.values[_cell + column * int(table.x_size)])
		if control is SpinBox:
			control.value = value
		else:
			_choose_value(control, value, 2 if column == 5 else 3)
	_loading = false
	_canvas.configure(
		_value.frames[_frame],
		_documents.asset_texture("Animations", str(_value.get("animation_name", ""))),
		int(_value.get("animation_hue", 0)),
		_cell
	)


func _choose_value(choice: OptionButton, value: int, count: int) -> void:
	while choice.item_count > count:
		choice.remove_item(count)
	if value >= 0 and value < count:
		choice.select(value)
	else:
		choice.add_item("原值 %d" % value)
		choice.set_item_metadata(count, value)
		choice.select(count)


func _set_cell(column: int, value: int) -> void:
	if _loading or _cell < 0:
		return
	_stop()
	var table: Dictionary = _value.frames[_frame].cell_data
	table.values[_cell + column * int(table.x_size)] = value
	_refresh_frame()
	_emit()


func _add_frame(copy: bool) -> void:
	_stop()
	_value.frames.append(
		(
			_value.frames[_frame].duplicate(true)
			if copy and not _value.frames.is_empty()
			else Schema.frame()
		)
	)
	_value.frame_max = _value.frames.size()
	_frame = _value.frames.size() - 1
	_cell = -1
	_fill_frames()
	_refresh_frame()
	_emit()


func _remove_frame() -> void:
	if _value.frames.size() <= 1:
		_status.text = "动画至少保留一帧。"
		return
	for timing in _value.get("timings", []):
		if int(timing.frame) == _frame:
			_status.text = "当前帧有音效/闪光时序，请先移动或删除该时序。"
			return
	_stop()
	_value.frames.remove_at(_frame)
	_value.frame_max = _value.frames.size()
	for timing in _value.get("timings", []):
		if int(timing.frame) > _frame:
			timing.frame = int(timing.frame) - 1
	_frame = mini(_frame, _value.frames.size() - 1)
	_cell = -1
	_fill_frames()
	_refresh_frame()
	_fill_timings()
	_emit()


func _add_cell() -> void:
	if _value.get("frames", []).is_empty():
		_status.text = "请先追加空白帧。"
		return
	var frame: Dictionary = _value.frames[_frame]
	var table: Dictionary = frame.cell_data
	var width = int(table.x_size)
	var count = int(frame.cell_max)
	if count >= 16:
		_status.text = "每帧最多16个单元。"
		return
	_stop()
	var defaults = [-1, 0, 0, 100, 0, 0, 255, 0]
	if count < width:
		for column in 8:
			table.values[count + column * width] = defaults[column]
	else:
		var values: Array = []
		for column in 8:
			values.append_array(table.values.slice(column * width, (column + 1) * width))
			values.append(defaults[column])
		table.x_size = width + 1
		table.values = values
	frame.cell_max = count + 1
	_cell = count
	_refresh_frame()
	_emit()


func _remove_cell() -> void:
	if _cell < 0:
		return
	_stop()
	var frame: Dictionary = _value.frames[_frame]
	var table: Dictionary = frame.cell_data
	var width = int(table.x_size)
	var count = int(frame.cell_max)
	if width == count:
		var values: Array = []
		for column in 8:
			var row = table.values.slice(column * width, (column + 1) * width)
			row.remove_at(_cell)
			values.append_array(row)
		table.x_size = width - 1
		table.values = values
	else:
		for column in 8:
			for index in range(_cell, count - 1):
				table.values[index + column * width] = table.values[index + 1 + column * width]
	frame.cell_max = count - 1
	_cell = mini(_cell, count - 2)
	_refresh_frame()
	_emit()


func _fill_timings() -> void:
	_loading = true
	_timings.clear()
	var root = _timings.create_item()
	for index in _value.get("timings", []).size():
		var timing: Dictionary = _value.timings[index]
		var item = _timings.create_item(root)
		item.set_metadata(0, index)
		item.set_text(0, str(int(timing.frame) + 1))
		item.set_text(1, str(timing.get("se", {}).get("name", "")))
		item.set_text(
			2,
			(
				["无", "目标", "画面", "隐藏目标"][int(timing.flash_scope)]
				if int(timing.flash_scope) in range(4)
				else "原值 %s" % str(timing.flash_scope)
			)
		)
		item.set_text(
			3,
			(
				["始终", "命中", "未命中"][int(timing.condition)]
				if int(timing.condition) in range(3)
				else "原值 %s" % str(timing.condition)
			)
		)
		if index == _timing:
			item.select(0)
	_loading = false
	_sync_timing()


func _sync_timing() -> void:
	_loading = true
	var selected = _timing >= 0 and _timing < _value.get("timings", []).size()
	_se.disabled = not selected
	_color.disabled = not selected
	for key in _timing_controls:
		var control: Control = _timing_controls[key]
		if control is SpinBox:
			control.editable = selected
		else:
			control.disabled = not selected
		if not selected:
			continue
		var timing: Dictionary = _value.timings[_timing]
		var value = (
			int(timing.se.get(key, 0)) if key in ["volume", "pitch"] else int(timing.get(key, 0))
		)
		if control is SpinBox:
			control.value = value + 1 if key == "frame" else value
		else:
			_choose_value(control, value, 4 if key == "flash_scope" else 3)
	if selected:
		var timing: Dictionary = _value.timings[_timing]
		_se.text = "音效：" + str(timing.se.get("name", ""))
		var color: Dictionary = timing.flash_color
		_color.color = Color(
			float(color.get("red", 0)) / 255,
			float(color.get("green", 0)) / 255,
			float(color.get("blue", 0)) / 255,
			float(color.get("alpha", 0)) / 255
		)
	_loading = false


func _set_timing(key: String, value: int) -> void:
	if _loading or _timing < 0:
		return
	if key in ["volume", "pitch"]:
		_value.timings[_timing].se[key] = value
	else:
		_value.timings[_timing][key] = value
	_fill_timings()
	_emit()


func _add_timing() -> void:
	var timing = Schema.timing()
	timing.frame = _frame
	_value.timings.append(timing)
	_timing = _value.timings.size() - 1
	_fill_timings()
	_emit()


func _remove_timing() -> void:
	if _timing < 0:
		return
	_value.timings.remove_at(_timing)
	_timing = mini(_timing, _value.timings.size() - 1)
	_fill_timings()
	_emit()


func _emit() -> void:
	_status.text = "已修改当前条目，应用并保存后写入文件。"
	changed.emit(draft())


func _toggle_play() -> void:
	if _playing:
		_stop()
		return
	if _value.get("frames", []).is_empty():
		return
	_playing = true
	_elapsed = 0
	_frame = 0
	_frames.select(0)
	_refresh_frame()
	_play.text = "停止预览"
	_play_timing(0)


func _stop() -> void:
	_playing = false
	_play.text = "播放预览"
	if _audio != null:
		_audio.stop()


func _play_timing(frame: int) -> void:
	for timing in _value.get("timings", []):
		if int(timing.get("frame", -1)) != frame:
			continue
		var condition = int(timing.get("condition", 0))
		if condition == 1 and not _hit.button_pressed or condition == 2 and _hit.button_pressed:
			continue
		if not _audio.play(_documents, "SE", timing.get("se", {}), false):
			_status.text = _audio._error


func _process(delta: float) -> void:
	if not _playing:
		return
	if not is_visible_in_tree():
		_stop()
		return
	_elapsed += delta
	while _elapsed >= 1.0 / _fps.value and _playing:
		_elapsed -= 1.0 / _fps.value
		if _frame + 1 >= _value.frames.size():
			if not _loop.button_pressed:
				# Let the final sound finish, while the visual preview remains on its last frame.
				_playing = false
				_play.text = "播放预览"
				break
			_frame = 0
		else:
			_frame += 1
		_play_timing(_frame)
	_frames.select(_frame)
	_refresh_frame()

## 职责：浏览工程音频库并提供可调试听，供音频字段与素材页面共用。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/05_Assets/Editor_AudioBrowser.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(documents: RefCounted, category: String, value: Dictionary = {}) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 value（Dictionary；默认值 {}）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draft() -> Dictionary
##     用途：取得可交给调用方的独立编辑草稿。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func stop() -> void
##     用途：停止当前播放、动作或服务。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

@tool
extends VBoxContainer
## Shared library/selector with an isolated, live-adjustable audition.
var _documents: RefCounted
var _category = "SE"
var _value: Dictionary = {}
var _search: LineEdit
var _files: ItemList
var _name: LineEdit
var _volume: SpinBox
var _pitch: SpinBox
var _audio: Node
var _status: Label
var _loading = false


func configure(documents: RefCounted, category: String, value: Dictionary = {}) -> void:
	if _files == null:
		_build()
	stop()
	_documents = documents
	_category = category
	_value = value.duplicate(true)
	_loading = true
	_name.text = str(value.get("name", ""))
	_volume.value = float(value.get("volume", 80))
	_pitch.value = float(value.get("pitch", 100))
	_search.text = ""
	_loading = false
	_refill()
	_status.text = "%s · 选择文件后点击试听；播放中可调整音量与声调。" % category


func draft() -> Dictionary:
	var value = _value.duplicate(true)
	value.name = _name.text
	value.volume = int(_volume.value)
	value.pitch = int(_pitch.value)
	return value


func stop() -> void:
	if _audio != null:
		_audio.stop()


func _build() -> void:
	_audio = preload("Editor_AudioPreview.gd").new()
	add_child(_audio)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索音频文件"
	add_child(_search)
	_search.text_changed.connect(func(_text: String) -> void: _refill())
	_files = ItemList.new()
	_files.custom_minimum_size.y = 180
	_files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_files)
	_files.item_selected.connect(
		func(index: int) -> void:
			stop()
			_name.text = str(_files.get_item_metadata(index))
	)
	_files.item_activated.connect(func(_index: int) -> void: _preview())
	var row = HBoxContainer.new()
	add_child(row)
	var label = Label.new()
	label.text = "文件"
	row.add_child(label)
	_name = LineEdit.new()
	_name.placeholder_text = "无音频"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	_name.text_changed.connect(
		func(_text: String) -> void:
			if not _loading:
				stop()
	)
	_volume = _parameter("音量", 0, 100, 80)
	_pitch = _parameter("声调", 50, 150, 100)
	row = HBoxContainer.new()
	add_child(row)
	for entry in [["▶ 试听", _preview], ["■ 停止", stop]]:
		var button = Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		row.add_child(button)
	_status = Label.new()
	_status.custom_minimum_size.x = 580
	_status.size.x = 580
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	visibility_changed.connect(
		func() -> void:
			if not is_visible_in_tree():
				stop()
	)


func _parameter(caption: String, low: int, high: int, initial: int) -> SpinBox:
	var row = HBoxContainer.new()
	add_child(row)
	var label = Label.new()
	label.text = caption
	label.custom_minimum_size.x = 60
	row.add_child(label)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 1
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var spin = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.step = 1
	spin.value = initial
	spin.suffix = "%"
	row.add_child(spin)
	slider.value_changed.connect(func(value: float) -> void: spin.value = value)
	spin.value_changed.connect(
		func(value: float) -> void:
			slider.set_value_no_signal(value)
			if not _loading and _volume != null and _pitch != null:
				_audio.set_parameters(_volume.value, _pitch.value)
				if _status != null and not _audio._players.is_empty():
					_status.text = (
						"正在试听 %s · 音量%d%% · 声调%d%%"
						% [_name.text, int(_volume.value), int(_pitch.value)]
					)
	)
	return spin


func _refill() -> void:
	if _documents == null:
		return
	_files.clear()
	var names: Array = _documents.assets(_category)
	names.push_front("")
	for name in names:
		if (
			not _search.text.is_empty()
			and not str(name).to_lower().contains(_search.text.to_lower())
		):
			continue
		_files.add_item("无音频" if str(name).is_empty() else str(name))
		var index = _files.item_count - 1
		_files.set_item_metadata(index, name)
		if str(name) == _name.text:
			_files.select(index)


func _preview() -> void:
	var value = draft()
	if _audio.play(_documents, _category, value):
		_status.text = (
			"正在试听 %s · 音量%d%% · 声调%d%%" % [value.name, int(value.volume), int(value.pitch)]
			if not value.name.is_empty()
			else "未选择音频。"
		)
	else:
		_status.text = _audio._error

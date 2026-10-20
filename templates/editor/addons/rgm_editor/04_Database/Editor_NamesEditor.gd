## 职责：编辑开关、变量等稳定编号的名称列表，筛选时保留原编号。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/04_Database/Editor_NamesEditor.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(names: Array, kind: String, documents: RefCounted = null) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 names（Array；必填）：按原编号排列的名称列表。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 documents（RefCounted；默认值 null）：编辑器文档服务，持有独立草稿与保存接口。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draft() -> Array
##     用途：取得可交给调用方的独立编辑草稿。
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
## 对外信号：
##   changed(names: Array)：当前模型或草稿已经变化，界面可据此刷新。
##     names：按原编号排列的名称列表。
##
## 接口说明结束。

@tool
extends VBoxContainer
## Stable indexed names; filtering never renumbers entries.
signal changed(names: Array)
var _value: Array = []
var _kind = ""
var _list: ItemList
var _search: LineEdit
var _name: LineEdit
var _heading: Label
var _page: Label
var _offset = 0
var _selected = 1
var _loading = false
var _documents: RefCounted
var _capacity: ConfirmationDialog
var _maximum: SpinBox
var _jump: SpinBox
var _message: Label


func configure(names: Array, kind: String, documents: RefCounted = null) -> void:
	_value = names.duplicate(true)
	_kind = kind
	_documents = documents
	if _list == null:
		_build()
	_fill()
	_select_id(clampi(_selected, 1, maxi(1, _value.size() - 1)))


func draft() -> Array:
	return _value.duplicate(true)


func _build() -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "按编号或名称搜索"
	add_child(_search)
	_search.text_changed.connect(
		func(_text: String) -> void:
			_offset = 0
			_fill()
	)
	_list = ItemList.new()
	_list.custom_minimum_size.y = 170
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_list)
	_list.item_selected.connect(
		func(index: int) -> void: _select_id(int(_list.get_item_metadata(index)))
	)
	var pages = HBoxContainer.new()
	add_child(pages)
	for entry in [["上一组", -100], ["下一组", 100]]:
		var button = Button.new()
		button.text = entry[0]
		pages.add_child(button)
		button.pressed.connect(
			func() -> void:
				_offset = maxi(0, _offset + int(entry[1]))
				_fill()
		)
	_page = Label.new()
	pages.add_child(_page)
	_heading = Label.new()
	add_child(_heading)
	_name = LineEdit.new()
	_name.placeholder_text = "输入名称"
	add_child(_name)
	_name.text_changed.connect(_rename)
	var add = Button.new()
	add.text = "追加新编号"
	add_child(add)
	add.pressed.connect(_append_name)
	var actions = HBoxContainer.new()
	add_child(actions)
	var capacity_button = Button.new()
	capacity_button.text = "设置最大编号…"
	actions.add_child(capacity_button)
	capacity_button.pressed.connect(_open_capacity)
	_jump = SpinBox.new()
	_jump.min_value = 1
	_jump.max_value = 32767
	_jump.step = 1
	actions.add_child(_jump)
	var jump_button = Button.new()
	jump_button.text = "跳转编号"
	actions.add_child(jump_button)
	jump_button.pressed.connect(_jump_to)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_capacity = ConfirmationDialog.new()
	_capacity.title = "设置名称最大编号"
	_capacity.dialog_hide_on_ok = false
	add_child(_capacity)
	_maximum = SpinBox.new()
	_maximum.min_value = 1
	_maximum.max_value = 32767
	_maximum.step = 1
	_maximum.custom_minimum_size = Vector2(400, 60)
	_capacity.add_child(_maximum)
	_capacity.confirmed.connect(_resize_names)
	var note = Label.new()
	note.custom_minimum_size.x = 600
	note.size.x = 600
	note.text = "编号0保留。可扩展最大编号并按区间留空；清空名称不删除编号。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)


func _fill() -> void:
	_list.clear()
	var matches: Array = []
	var query = _search.text.to_lower()
	for id in range(1, _value.size()):
		var title = (
			"[%04d] %s"
			% [id, str(_value[id]) if not str(_value[id]).strip_edges().is_empty() else "未命名"]
		)
		if query.is_empty() or title.to_lower().contains(query):
			matches.append({"id": id, "title": title})
	_offset = mini(_offset, maxi(0, int((matches.size() - 1) / 100) * 100))
	for index in range(_offset, mini(_offset + 100, matches.size())):
		_list.add_item(matches[index].title)
		_list.set_item_metadata(_list.item_count - 1, matches[index].id)
		if matches[index].id == _selected:
			_list.select(_list.item_count - 1)
	_page.text = (
		"%d–%d / %d"
		% [mini(_offset + 1, matches.size()), mini(_offset + 100, matches.size()), matches.size()]
	)


func _select_id(id: int) -> void:
	_selected = id
	_loading = true
	_name.editable = id > 0 and id < _value.size()
	var text = str(_value[id]) if id > 0 and id < _value.size() else ""
	if _name.text != text:
		_name.text = text
	_heading.text = (
		"%s [%04d]"
		% [{"switches": "开关", "variables": "变量", "elements": "属性"}.get(_kind, _kind), id]
	)
	_loading = false


func _rename(text: String) -> void:
	if _loading or _selected <= 0 or _selected >= _value.size():
		return
	_value[_selected] = text
	_fill()
	changed.emit(draft())


func _append_name() -> void:
	_search.text = ""
	if _value.is_empty():
		_value.append("")
	_value.append("")
	_offset = int((_value.size() - 2) / 100) * 100
	_fill()
	_select_id(_value.size() - 1)
	changed.emit(draft())
	_name.grab_focus()


func _open_capacity() -> void:
	_maximum.value = maxi(1, _value.size() - 1)
	_capacity.popup_centered(Vector2i(460, 200))


func _resize_names() -> void:
	if _documents == null:
		_message.text = "未连接工程草稿，不能核对编号引用。"
		return
	var plan = preload("../01_Documents/Editor_CapacityOps.gd").resize(
		_documents, _kind, _value, int(_maximum.value)
	)
	if not plan.ok:
		_message.text = plan.message
		return
	_value = plan.value
	_selected = clampi(_selected, 1, _value.size() - 1)
	_search.text = ""
	_fill()
	_select_id(_selected)
	_capacity.hide()
	changed.emit(draft())


func _jump_to() -> void:
	var id = int(_jump.value)
	if id <= 0 or id >= _value.size():
		_message.text = "编号超出范围，请先扩展最大编号。"
		return
	_search.text = ""
	_offset = int((id - 1) / 100) * 100
	_fill()
	_select_id(id)

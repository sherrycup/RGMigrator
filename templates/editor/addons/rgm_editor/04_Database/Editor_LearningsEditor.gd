## 职责：编辑角色或职业的技能学习列表，维护等级与技能引用。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/04_Database/Editor_LearningsEditor.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(learnings: Array, documents: RefCounted) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 learnings（Array；必填）：按等级登记的技能学习记录。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   changed(learnings: Array)：当前模型或草稿已经变化，界面可据此刷新。
##     learnings：按等级登记的技能学习记录。
##   edit_requested(path: Array)：由持有方发出，通知对应状态或操作结果。
##     path：待读取、写入或定位的文件路径。
##
## 接口说明结束。

@tool
extends VBoxContainer
signal changed(learnings: Array)
signal edit_requested(path: Array)
var _value: Array = []
var _documents: RefCounted
var _tree: Tree
var _level: SpinBox
var _skill: Button
var _selection = -1
var _loading = false


func configure(learnings: Array, documents: RefCounted) -> void:
	_value = learnings.duplicate(true)
	_documents = documents
	if _tree == null:
		_build()
	_refresh()
	_select(clampi(_selection, 0, _value.size() - 1) if not _value.is_empty() else -1)


func _build() -> void:
	var bar = HBoxContainer.new()
	add_child(bar)
	for entry in [["添加习得", _add], ["删除所选", _remove], ["上移", _move.bind(-1)], ["下移", _move.bind(1)]]:
		var button = Button.new()
		button.text = entry[0]
		bar.add_child(button)
		button.pressed.connect(entry[1])
	_tree = Tree.new()
	_tree.columns = 2
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "习得等级")
	_tree.set_column_title(1, "特技名称 / 编号")
	_tree.set_column_custom_minimum_width(0, 100)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size.y = 150
	add_child(_tree)
	_tree.item_selected.connect(func() -> void: _select(int(_tree.get_selected().get_metadata(0))))
	var row = HBoxContainer.new()
	add_child(row)
	var label = Label.new()
	label.text = "习得等级"
	row.add_child(label)
	_level = SpinBox.new()
	_level.min_value = 1
	_level.max_value = 99
	_level.step = 1
	_level.allow_greater = true
	_level.allow_lesser = true
	row.add_child(_level)
	_level.value_changed.connect(
		func(n: float) -> void:
			if not _loading and _selection >= 0:
				_value[_selection].level = int(n)
				_refresh()
				changed.emit(_value.duplicate(true))
	)
	_skill = Button.new()
	_skill.clip_text = true
	_skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_skill)
	_skill.pressed.connect(
		func() -> void:
			if _selection >= 0:
				edit_requested.emit(["learnings", _selection, "skill_id"])
	)
	var note = Label.new()
	note.custom_minimum_size.x = 600
	note.size.x = 600
	note.text = "同等级可以习得多项特技；原顺序及额外数据保持，只有所选条目会被修改。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)


func _refresh() -> void:
	_loading = true
	_tree.clear()
	var root = _tree.create_item()
	for i in _value.size():
		var item = _tree.create_item(root)
		item.set_metadata(0, i)
		item.set_text(0, "等级 %d" % int(_value[i].get("level", 1)))
		item.set_text(1, _documents.reference_label("Skills", int(_value[i].get("skill_id", 0))))
		if i == _selection:
			item.select(0)
	_loading = false


func _select(index: int) -> void:
	if _loading:
		return
	_selection = index
	_loading = true
	_level.editable = index >= 0
	_skill.disabled = index < 0
	if index >= 0:
		_level.value = int(_value[index].get("level", 1))
		_skill.text = _documents.reference_label("Skills", int(_value[index].get("skill_id", 0)))
		_skill.tooltip_text = _skill.text
	else:
		_skill.text = "请选择习得条目"
	_loading = false


func _add() -> void:
	_value.append({"_class": "RPG::Class::Learning", "level": 1, "skill_id": 1})
	_selection = _value.size() - 1
	_refresh()
	_select(_selection)
	changed.emit(_value.duplicate(true))


func _remove() -> void:
	if _selection < 0:
		return
	_value.remove_at(_selection)
	_selection = mini(_selection, _value.size() - 1)
	_refresh()
	_select(_selection)
	changed.emit(_value.duplicate(true))


func _move(direction: int) -> void:
	var next = _selection + direction
	if _selection < 0 or next < 0 or next >= _value.size():
		return
	var old: Variant = _value[_selection]
	_value[_selection] = _value[next]
	_value[next] = old
	_selection = next
	_refresh()
	_select(next)
	changed.emit(_value.duplicate(true))
